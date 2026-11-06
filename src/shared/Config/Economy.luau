--!strict
-- Economy tunables. Every price, cap and fee lives here, so balancing never touches code.
-- Values are starting points; the M3 economy simulation tunes them.

return table.freeze({
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
})
