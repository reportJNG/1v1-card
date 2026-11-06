--!strict
-- Daily quests and achievements. Progress is only ever added by the server, from things that
-- really happened (a settled match, a harvest, a hatch); the client can only ask to claim.
--   roll   on a new UTC day: drop yesterday's dailies and pick today's 3 (seeded by day and
--          player, so a reconnect can't reroll them)
--   track  adds progress to every matching, unclaimed daily and achievement
--   claim  pays a completed quest once
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local QuestsCfg = require(Config.Quests)
local Economy = require(Config.Economy)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)
local Hatch = require(script.Parent.Hatch)
local Prng = require(script.Parent.Parent.Battle.Prng)

local Quests = {}

local DAY = 86400

local function isDaily(id: string): boolean
	return string.sub(id, 1, 2) == "d_"
end

-- Today's daily quest ids for this player, in a stable order.
function Quests.dailyFor(profile: Types.PlayerProfile, dayKey: number): { string }
	local seed = (dayKey * 7919 + (tonumber(profile.uidPrefix) or 0)) % 2147483647
	local g = Prng.new(seed + 1)
	local pool = {}
	for _, q in QuestsCfg.Daily do
		table.insert(pool, q.id)
	end
	local out = {}
	for _ = 1, math.min(QuestsCfg.dailyCount, #pool) do
		local i = math.floor(g:next() * #pool) + 1
		table.insert(out, table.remove(pool, i) :: string)
	end
	return out
end

function Quests.roll(profile: Types.PlayerProfile, now: number)
	local dayKey = now // DAY
	if profile.questDay == dayKey then
		return
	end
	for id in profile.quests do
		if isDaily(id) then
			profile.quests[id] = nil
		end
	end
	for _, id in Quests.dailyFor(profile, dayKey) do
		profile.quests[id] = { progress = 0, claimed = false }
	end
	profile.questDay = dayKey
end

-- Adds `amount` to every active quest of this kind. `world` is where it happened (Harvest).
function Quests.track(profile: Types.PlayerProfile, kind: string, amount: number, now: number, world: number?)
	if amount <= 0 then
		return
	end
	Quests.roll(profile, now)
	local function add(def: QuestsCfg.QuestDef)
		if def.kind ~= kind or (def.world ~= nil and def.world ~= world) then
			return
		end
		local entry = profile.quests[def.id]
		if entry == nil then
			if isDaily(def.id) then
				return -- not one of today's dailies
			end
			entry = { progress = 0, claimed = false }
			profile.quests[def.id] = entry
		end
		local e = entry :: { progress: number, claimed: boolean }
		if not e.claimed then
			e.progress = math.min(def.target, e.progress + amount)
		end
	end
	for _, def in QuestsCfg.Daily do
		add(def)
	end
	for _, def in QuestsCfg.Achievements do
		add(def)
	end
end

export type Claim = { questId: string, coins: number, gems: number, egg: string? }

function Quests.claim(profile: Types.PlayerProfile, questId: string, now: number): Types.Result<Claim>
	Quests.roll(profile, now)
	local def = QuestsCfg.ById[questId]
	local entry = profile.quests[questId]
	if def == nil or entry == nil then
		return Result.fail("UnknownQuest")
	end
	if entry.claimed then
		return Result.fail("AlreadyClaimed")
	end
	if entry.progress < def.target then
		return Result.fail("NotComplete")
	end
	local suffix = if isDaily(questId) then tostring(profile.questDay) else "a"
	local coins, gems = def.coins or 0, def.gems or 0
	local coinRef, gemRef = `quest:{questId}:{suffix}:c`, `quest:{questId}:{suffix}:g`
	if coins > 0 then
		local c = Wallet.check(profile, "coins", coins, coinRef)
		if not c.ok then
			return Result.fail(c.err)
		end
	end
	if gems > 0 then
		local g = Wallet.check(profile, "gems", gems, gemRef)
		if not g.ok then
			return Result.fail(g.err)
		end
	end
	local egg = def.egg
	if egg then
		local stack = profile.eggBag[egg.id]
		local have = if stack then (if egg.golden then stack.golden else stack.normal) else 0
		if have >= Economy.EggBag.maxPerStack then
			return Result.fail("EggBagFull")
		end
	end
	if coins > 0 then
		assert(Wallet.apply(profile, "coins", coins, "Quest", coinRef, now).ok, "validated")
	end
	if gems > 0 then
		assert(Wallet.apply(profile, "gems", gems, "Quest", gemRef, now).ok, "validated")
	end
	if egg then
		assert(Hatch.addToBag(profile, egg.id, egg.golden, 1).ok, "validated")
	end
	entry.claimed = true
	return Result.ok({ questId = questId, coins = coins, gems = gems, egg = if egg then egg.id else nil })
end

return table.freeze(Quests)
