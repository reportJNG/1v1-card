--!strict
-- Card copies: creation, capacity, merging and provenance.
--
-- Merge rule (V1): only base copies can be consumed: level 1, no merge points, nothing merged into
-- them. An upgraded card is never merge material; it stays a separate owned copy. Every spare is
-- worth exactly its rarity's merge points, so costs stay predictable.
--
-- Provenance rule: a copy's `origin` never changes, and merging copies into a card adds their
-- origins, their paid refs and their paid lineage to the target. Nothing that came from a Robux
-- egg can become anonymous by being merged or upgraded.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Rarities = require(Config.Rarities)
local Economy = require(Config.Economy)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)

export type MergePlan = {
	targetUid: string,
	spareUids: { string },
	pointsAdded: number,
	fromLevel: number,
	toLevel: number,
	mergePointsAfter: number,
	coinFee: number,
}

local Cards = {}

local Progression = Economy.Progression

function Cards.count(profile: Types.PlayerProfile): number
	local n = 0
	for _ in profile.cards do
		n += 1
	end
	return n
end

function Cards.freeSlots(profile: Types.PlayerProfile): number
	return math.max(0, profile.cardSlots - Cards.count(profile))
end

function Cards.isInDeck(profile: Types.PlayerProfile, uid: string): boolean
	return table.find(profile.deck, uid) ~= nil
end

local function newProvenance(origin: Types.Origin, originRef: string?): Types.Provenance
	local paid = origin == "Robux"
	assert(not paid or originRef ~= nil, "Robux copies need their PurchaseId")
	return {
		absorbed = {},
		paidRefs = if paid then { originRef :: string } else {},
		paidLineage = paid,
	}
end

-- Creates a level 1 copy. `allowOverflow` is only for paid grants that were already charged
-- (a Robux receipt must never be lost because storage filled up between prompt and receipt).
function Cards.create(
	profile: Types.PlayerProfile,
	characterId: string,
	origin: Types.Origin,
	originRef: string?,
	golden: boolean,
	now: number,
	allowOverflow: boolean?
): Types.Result<Types.CardCopy>
	if Characters.ById[characterId] == nil then
		return Result.fail("UnknownCharacter")
	end
	if not allowOverflow and Cards.freeSlots(profile) < 1 then
		return Result.fail("CardStorageFull")
	end
	local uid = `{profile.uidPrefix}-{profile.nextCardSerial}`
	profile.nextCardSerial += 1
	local copy: Types.CardCopy = {
		uid = uid,
		characterId = characterId,
		level = 1,
		mergePoints = 0,
		golden = golden,
		origin = origin,
		originRef = originRef,
		obtainedAt = now,
		provenance = newProvenance(origin, originRef),
		lockedBy = nil,
	}
	profile.cards[uid] = copy
	return Result.ok(copy)
end

-- A base copy is an untouched duplicate: level 1, no merge points, nothing merged into it.
function Cards.isBaseCopy(copy: Types.CardCopy): boolean
	return copy.level == 1 and copy.mergePoints == 0 and next(copy.provenance.absorbed) == nil
end

local function pointsToMax(level: number, mergePoints: number): number
	local total = -mergePoints
	for l = level, Progression.maxLevel - 1 do
		total += Progression.mergePointsToNext[l]
	end
	return math.max(0, total)
end

-- Validates a merge and computes its outcome without changing anything.
function Cards.planMerge(
	profile: Types.PlayerProfile,
	targetUid: string,
	spareUids: { string }
): Types.Result<MergePlan>
	local target = profile.cards[targetUid]
	if target == nil then
		return Result.fail("NotOwned")
	end
	if target.lockedBy ~= nil then
		return Result.fail("CardLocked")
	end
	if #spareUids == 0 then
		return Result.fail("NoSpares")
	end
	if target.level >= Progression.maxLevel then
		return Result.fail("AlreadyMaxLevel")
	end
	local character = Characters.ById[target.characterId]
	local value = Rarities.Defs[character.rarity].mergePoints
	local seen: { [string]: boolean } = {}
	for _, uid in spareUids do
		if typeof(uid) ~= "string" or seen[uid] or uid == targetUid then
			return Result.fail("BadSpareList")
		end
		seen[uid] = true
		local spare = profile.cards[uid]
		if spare == nil then
			return Result.fail("NotOwned")
		end
		if spare.characterId ~= target.characterId then
			return Result.fail("DifferentCharacter")
		end
		if spare.lockedBy ~= nil then
			return Result.fail("CardLocked")
		end
		if Cards.isInDeck(profile, uid) then
			return Result.fail("SpareInDeck")
		end
		if spare.favorite then
			return Result.fail("SpareFavorite")
		end
		if not Cards.isBaseCopy(spare) then
			return Result.fail("SpareNotBaseCopy")
		end
	end
	local points = #spareUids * value
	-- Every spare must contribute: reject a list whose last spare would be wasted entirely.
	local needed = pointsToMax(target.level, target.mergePoints)
	if points - value >= needed then
		return Result.fail("TooManySpares")
	end

	local level = target.level
	local carry = target.mergePoints + points
	local fee = 0
	while level < Progression.maxLevel and carry >= Progression.mergePointsToNext[level] do
		carry -= Progression.mergePointsToNext[level]
		fee += Progression.coinFeeToNext[level]
		level += 1
	end
	if level >= Progression.maxLevel then
		carry = 0 -- points past the cap are not kept
	end
	return Result.ok({
		targetUid = targetUid,
		spareUids = table.clone(spareUids),
		pointsAdded = points,
		fromLevel = target.level,
		toLevel = level,
		mergePointsAfter = carry,
		coinFee = fee,
	})
end

-- Merges spare copies into a target. All checks (including the coin fee) happen before any change.
function Cards.merge(
	profile: Types.PlayerProfile,
	targetUid: string,
	spareUids: { string },
	txRef: string,
	now: number
): Types.Result<MergePlan>
	local planned = Cards.planMerge(profile, targetUid, spareUids)
	if not planned.ok then
		return planned
	end
	local plan = planned.value
	if plan.coinFee > 0 then
		local check = Wallet.check(profile, "coins", -plan.coinFee, txRef)
		if not check.ok then
			return Result.fail(check.err)
		end
		Wallet.apply(profile, "coins", -plan.coinFee, "merge_fee", txRef, now)
	end

	local target = profile.cards[targetUid]
	local prov = target.provenance
	for _, uid in plan.spareUids do
		local spare = profile.cards[uid]
		local sp = spare.provenance
		prov.absorbed[spare.origin] = (prov.absorbed[spare.origin] or 0) + 1
		for origin, n in sp.absorbed do
			prov.absorbed[origin] = (prov.absorbed[origin] or 0) + n
		end
		for _, ref in sp.paidRefs do
			if not table.find(prov.paidRefs, ref) then
				table.insert(prov.paidRefs, ref)
			end
		end
		prov.paidLineage = prov.paidLineage or sp.paidLineage
		if spare.golden then
			target.golden = true -- the foil is kept, never lost by merging
		end
		profile.cards[uid] = nil
	end
	target.level = plan.toLevel
	target.mergePoints = plan.mergePointsAfter
	return Result.ok(plan)
end

-- Buys the next card-storage expansion at its configured price.
function Cards.expandStorage(profile: Types.PlayerProfile, txRef: string, now: number): Types.Result<number>
	local cfg = Economy.CardStorage
	if profile.cardSlots >= cfg.maxSlots then
		return Result.fail("StorageAtMax")
	end
	local index = (profile.cardSlots - cfg.startSlots) // cfg.slotsPerExpansion + 1
	local price = cfg.expansionPrices[index]
	if price == nil then
		return Result.fail("NoPriceConfigured")
	end
	local paid = Wallet.apply(profile, "coins", -price, "card_storage_expansion", txRef, now)
	if not paid.ok then
		return Result.fail(paid.err)
	end
	profile.cardSlots = math.min(cfg.maxSlots, profile.cardSlots + cfg.slotsPerExpansion)
	return Result.ok(profile.cardSlots)
end

-- True if the player owns a max-level copy of this character (other than `exceptUid`).
function Cards.hasMaxedCopy(profile: Types.PlayerProfile, characterId: string, exceptUid: string?): boolean
	for uid, copy in profile.cards do
		if uid ~= exceptUid and copy.characterId == characterId and copy.level >= Progression.maxLevel then
			return true
		end
	end
	return false
end

-- Marks or unmarks a copy as a favourite (CARDS_EGGS_MISSION 4.4). Favourites can't be sold or used
-- as merge spares; they can still be merge targets and deck cards. Returns the new state.
function Cards.setFavorite(profile: Types.PlayerProfile, uid: string, on: boolean): Types.Result<boolean>
	local copy = profile.cards[uid]
	if copy == nil then
		return Result.fail("NotOwned")
	end
	copy.favorite = if on then true else nil
	return Result.ok(on)
end

-- Sells spare copies to the NPC merchant. Only spares of characters the player already has at
-- max level qualify, so selling never removes the last way to level a card. All checks first.
function Cards.sellSpares(
	profile: Types.PlayerProfile,
	uids: { string },
	txRef: string,
	now: number
): Types.Result<number>
	if #uids == 0 or #uids > 100 then
		return Result.fail("BadCardList")
	end
	local seen: { [string]: boolean } = {}
	local total = 0
	for _, uid in uids do
		if typeof(uid) ~= "string" or seen[uid] then
			return Result.fail("BadCardList")
		end
		seen[uid] = true
		local copy = profile.cards[uid]
		if copy == nil then
			return Result.fail("NotOwned")
		end
		if copy.lockedBy ~= nil then
			return Result.fail("CardLocked")
		end
		if Cards.isInDeck(profile, uid) then
			return Result.fail("CardInDeck")
		end
		if copy.favorite then
			return Result.fail("CardFavorite")
		end
		if not Cards.isBaseCopy(copy) then
			return Result.fail("NotASpare")
		end
		if not Cards.hasMaxedCopy(profile, copy.characterId, uid) then
			return Result.fail("NoMaxedCopy")
		end
		total += Economy.CardSale[Characters.ById[copy.characterId].rarity]
	end
	local check = Wallet.check(profile, "coins", total, txRef)
	if not check.ok then
		return Result.fail(check.err)
	end
	for _, uid in uids do
		profile.cards[uid] = nil
	end
	Wallet.apply(profile, "coins", total, "card_sale", txRef, now)
	return Result.ok(total)
end

-- Effective stats of a copy at a given level (ranked passes a league-capped level).
function Cards.statsAt(characterId: string, level: number): Types.Stats
	local Roles = require(Config.Roles)
	local def = Characters.ById[characterId]
	local base = Roles[def.role].base
	local mult = (1 + Rarities.Defs[def.rarity].statBudget) * (1 + Progression.statPerLevel * (level - 1))
	return {
		hp = math.round(base.hp * mult),
		atk = math.round(base.atk * mult),
		def = math.round(base.def * mult),
		spd = math.round(base.spd * mult),
	}
end

return table.freeze(Cards)
