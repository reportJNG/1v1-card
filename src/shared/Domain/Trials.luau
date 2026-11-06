--!strict
-- Guardian Trials: one PvE battle per world. Clearing a world's Trial the first time grants a
-- one-time trophy bonus (the design's "Guardian Trial trophy grant"), Coins, Gems and that
-- world's first egg in Golden. Later clears pay nothing. Pure; the battle runs in BattleService.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Economy = require(Config.Economy)
local Worlds = require(Config.Worlds)
local Eggs = require(Config.Eggs)
local Guardians = require(Config.Guardians)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)
local Progress = require(script.Parent.Progress)
local Deck = require(script.Parent.Deck)
local Hatch = require(script.Parent.Hatch)

export type Reward = {
	firstClear: boolean,
	trophies: number,
	coins: number,
	gems: number,
	goldenEgg: string?, -- egg id added to the Egg Bag (Golden), nil if none or the stack was full
}

export type Start = {
	guardian: Guardians.GuardianDef,
	deck: { { characterId: string, level: number } },
}

local Trials = {}

function Trials.isCleared(profile: Types.PlayerProfile, worldId: number): boolean
	return profile.trials[tostring(worldId)] ~= nil
end

-- Checks the player may fight this world's Guardian and returns both decks.
function Trials.prepare(profile: Types.PlayerProfile, worldId: number): Types.Result<Start>
	local guardian = Guardians.ByWorld[worldId]
	if guardian == nil then
		return Result.fail("UnknownWorld")
	end
	if not Progress.isWorldUnlocked(profile, worldId) then
		return Result.fail("WorldLocked")
	end
	local specs = Deck.specs(profile)
	if not specs.ok then
		return Result.fail(specs.err)
	end
	return Result.ok({ guardian = guardian, deck = specs.value })
end

-- The world's first egg, when it has a Golden version.
local function goldenEggFor(worldId: number): string?
	local world = Worlds.ById[worldId]
	if world == nil or not Economy.Trials.goldenEggFirstClear then
		return nil
	end
	for _, eggId in world.eggs do
		local egg = Eggs.ById[eggId]
		if egg and egg.goldenAllowed then
			return eggId
		end
	end
	return nil
end

-- Records a won Trial. Idempotent: only the first win for a world pays.
function Trials.grantClear(profile: Types.PlayerProfile, worldId: number, now: number): Types.Result<Reward>
	local cfg = Economy.Trials
	local key = tostring(worldId)
	if Guardians.ByWorld[worldId] == nil then
		return Result.fail("UnknownWorld")
	end
	if profile.trials[key] ~= nil then
		return Result.ok({ firstClear = false, trophies = 0, coins = 0, gems = 0, goldenEgg = nil } :: Reward)
	end
	local coins = cfg.coinsByWorld[worldId] or 0
	local gems = cfg.gemsFirstClear
	local coinRef, gemRef = `trial:{worldId}:coins`, `trial:{worldId}:gems`

	-- Validate every fallible step before changing anything. A maxed wallet skips that currency.
	if coins > 0 and not Wallet.check(profile, "coins", coins, coinRef).ok then
		coins = 0
	end
	if gems > 0 and not Wallet.check(profile, "gems", gems, gemRef).ok then
		gems = 0
	end
	local eggId = goldenEggFor(worldId)
	if eggId then
		local stack = profile.eggBag[eggId]
		if stack and stack.golden >= Economy.EggBag.maxPerStack then
			eggId = nil
		end
	end

	if coins > 0 then
		assert(Wallet.apply(profile, "coins", coins, "TrialClear", coinRef, now).ok, "validated")
	end
	if gems > 0 then
		assert(Wallet.apply(profile, "gems", gems, "TrialClear", gemRef, now).ok, "validated")
	end
	if eggId then
		assert(Hatch.addToBag(profile, eggId, true, 1).ok, "validated")
	end
	profile.trophies += cfg.trophyGrant
	profile.highestTrophies = math.max(profile.highestTrophies, profile.trophies)
	profile.trials[key] = now
	profile.stats.trialsCleared += 1
	return Result.ok({
		firstClear = true,
		trophies = cfg.trophyGrant,
		coins = coins,
		gems = gems,
		goldenEgg = eggId,
	} :: Reward)
end

return table.freeze(Trials)
