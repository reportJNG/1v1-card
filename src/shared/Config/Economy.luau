--!strict
-- Economy tunables. Every price, cap and fee lives here, so balancing never touches code.
-- Values are starting points; the M3 economy simulation tunes them.

return table.freeze({
	StartingCoins = 500, -- every new profile starts with this
	-- Three different active characters (Config/Roster) given once to a brand-new profile and set as
	-- its deck, so a first session can battle at once (a deck needs 3 different characters).
	StarterCards = table.freeze({ "rai_stormvolt", "ren_emberfang", "yuki_frostveil" }) :: { string },

	-- Ranked rewards. No entry fee and no stakes: the purse is paid by the game, never by the
	-- opponent (Roblox bans simulated gambling, so players never wager against each other).
	Matches = table.freeze({
		purseByLeague = table.freeze({ Bronze = 120, Silver = 220, Gold = 360, Diamond = 550 }) :: { [string]: number },
		lossCoinsByLeague = table.freeze({ Bronze = 25, Silver = 40, Gold = 60, Diamond = 80 }) :: { [string]: number },
		dailyFullRewardWins = 10, -- after this many wins in a UTC day, Coins pay reducedFactor
		reducedFactor = 0.25,
		trophyWin = 30,
		trophyLoss = 20,
		trophyGapDivisor = 25, -- each 25 trophies of gap moves the swing by 1
		trophyWinRange = table.freeze({ 20, 40 }),
		trophyLossRange = table.freeze({ 10, 30 }),
		minRoundsForReward = 3, -- forfeits before round 3 pay nothing
		maxRepeatsPerDay = 3, -- the same two players: only the first 3 matches a day pay
		timeoutsVoidReward = 3, -- a player who timed out this many rounds earns nothing
		settledMemory = 300, -- matchIds kept for idempotency; the oldest are dropped past this
	}),

	-- First-clear rewards for each world's Guardian Trial.
	Trials = table.freeze({
		trophyGrant = 40,
		coinsByWorld = table.freeze({ 300, 450, 650, 900, 1200, 1600, 2100, 2700, 3400, 4200 }),
		gemsFirstClear = 25,
		goldenEggFirstClear = true, -- the world's first egg, Golden, into the Egg Bag
		retryCooldown = 30, -- seconds between attempts
	}),

	-- Card storage holds individual card copies.
	CardStorage = table.freeze({
		startSlots = 300,
		slotsPerExpansion = 50,
		maxSlots = 1000,
		-- Coin price of expansion n (1-based). Length must equal (maxSlots - startSlots) / slotsPerExpansion.
		expansionPrices = table.freeze({
			5_000,
			6_500,
			8_500,
			11_000,
			14_500,
			18_500,
			24_000,
			31_500,
			41_000,
			53_000,
			69_000,
			89_500,
			116_500,
			151_500,
		}),
	}),

	-- Item inventory: one stack of a farmed item per slot.
	ItemInventory = table.freeze({
		startSlots = 5,
		slotsPerExpansion = 1,
		maxSlots = 30,
		expansionPrices = table.freeze({
			1_000,
			1_200,
			1_600,
			2_000,
			2_400,
			3_100,
			3_800,
			4_800,
			6_000,
			7_500,
			9_300,
			11_600,
			14_600,
			18_200,
			22_700,
			28_400,
			35_500,
			44_400,
			55_500,
			69_400,
			86_700,
			108_400,
			135_500,
			169_400,
			211_800,
		}),
	}),

	-- Levels and merging. Index n is the cost to go from level n to n + 1 (n = 1..MaxLevel-1).
	Progression = table.freeze({
		maxLevel = 15,
		statPerLevel = 0.0075, -- +0.75% to all stats per level above 1 (max +10.5%)
		mergePointsToNext = table.freeze({
			2,
			3,
			4,
			5,
			6,
			8,
			10,
			12,
			15,
			18,
			21,
			25,
			30,
			35,
		}),
		coinFeeToNext = table.freeze({
			100,
			200,
			350,
			500,
			750,
			1_000,
			1_500,
			2_000,
			3_000,
			4_000,
			5_500,
			7_500,
			10_000,
			13_000,
		}),
	}),

	-- Currency hard limits; the wallet rejects anything outside them.
	Wallet = table.freeze({
		maxCoins = 1e12,
		maxGems = 1e9,
		ledgerLength = 200, -- last N currency events kept on the profile for support
		recentTxLength = 500, -- request ids remembered for idempotency
	}),

	EggBag = table.freeze({ maxPerStack = 99 }),

	-- 7-day login streak: Coins on days 1-6, then Gems and a Golden egg on day 7. Missing a day
	-- restarts at day 1; after day 7 the streak starts over.
	Streak = table.freeze({
		coins = table.freeze({ 100, 150, 200, 250, 300, 400 }),
		day7Gems = 10,
		day7Egg = "egg_basic", -- Golden
	}),

	-- NPC merchant price for a spare copy of a character the player already has at max level.
	CardSale = table.freeze({
		Common = 150,
		Rare = 400,
		Epic = 1_000,
		Legendary = 2_500,
		Mythical = 6_000,
	}) :: { [string]: number },
})
