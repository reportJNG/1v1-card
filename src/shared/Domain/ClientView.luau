--!strict
-- What the client is allowed to know about its own profile, and the diff the server pushes
-- after each change. Provenance details, receipts, ledger and idempotency memory stay server-side.
local Types = require(script.Parent.Parent.Types)

export type CardView = {
	uid: string,
	characterId: string,
	level: number,
	mergePoints: number,
	golden: boolean,
	paid: boolean, -- came from (or absorbed) a Robux egg; the UI shows it, the server enforces it
	locked: boolean,
	obtainedAt: number,
}

export type View = {
	coins: number,
	gems: number,
	trophies: number,
	highestTrophies: number,
	cardSlots: number,
	deck: { string },
	eggBag: { [string]: { normal: number, golden: number } },
	items: { slots: number, stacks: { Types.ItemStack } },
	daily: { [string]: number },
	quests: { [string]: { progress: number, claimed: boolean } },
	flags: { [string]: any },
	cards: { [string]: CardView },
}

export type Delta = {
	set: { [string]: any }, -- top-level fields replaced wholesale
	cards: { [string]: CardView | false }, -- false = removed
}

local ClientView = {}

local function deepCopy(v: any): any
	if typeof(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function equal(a: any, b: any): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function ClientView.card(copy: Types.CardCopy): CardView
	return {
		uid = copy.uid,
		characterId = copy.characterId,
		level = copy.level,
		mergePoints = copy.mergePoints,
		golden = copy.golden,
		paid = copy.provenance.paidLineage,
		locked = copy.lockedBy ~= nil,
		obtainedAt = copy.obtainedAt,
	}
end

local SCALARS = { "coins", "gems", "trophies", "highestTrophies", "cardSlots" }
local TABLES = { "deck", "eggBag", "items", "daily", "quests", "flags" }

function ClientView.build(profile: Types.PlayerProfile): View
	local p = profile :: any
	local view: any = { cards = {} }
	for _, key in SCALARS do
		view[key] = p[key]
	end
	for _, key in TABLES do
		view[key] = deepCopy(p[key])
	end
	for uid, copy in profile.cards do
		view.cards[uid] = ClientView.card(copy)
	end
	return view :: View
end

function ClientView.diff(old: View, new: View): Delta?
	local delta: Delta = { set = {}, cards = {} }
	local changed = false
	for _, key in SCALARS do
		if (old :: any)[key] ~= (new :: any)[key] then
			delta.set[key] = (new :: any)[key]
			changed = true
		end
	end
	for _, key in TABLES do
		if not equal((old :: any)[key], (new :: any)[key]) then
			delta.set[key] = deepCopy((new :: any)[key])
			changed = true
		end
	end
	for uid, card in new.cards do
		if not equal(old.cards[uid], card) then
			delta.cards[uid] = card
			changed = true
		end
	end
	for uid in old.cards do
		if new.cards[uid] == nil then
			delta.cards[uid] = false
			changed = true
		end
	end
	return if changed then delta else nil
end

-- Client side: applies a delta to the local copy in place.
function ClientView.apply(view: View, delta: Delta)
	for key, value in delta.set do
		(view :: any)[key] = value
	end
	for uid, card in delta.cards do
		if card == false then
			view.cards[uid] = nil
		else
			view.cards[uid] = card :: any
		end
	end
end

return table.freeze(ClientView)
