--!strict
-- Daily quests (3 a day, rolled per player per UTC day) and the achievement track (one-time).
-- `kind` is what counts toward the quest; `world` limits it to one world. Rewards: dailies pay
-- Coins, achievements pay Gems (Gems are earned, and only buy cosmetics). Values are starting
-- values (ContentStatus: questRewards).

export type QuestDef = {
	id: string,
	kind: string, -- "WinRanked" | "PlayRanked" | "Harvest" | "Hatch" | "SellItems" | "Merge" | "TrialWin" | "TrialFirstClear"
	target: number,
	world: number?,
	text: string,
	coins: number?,
	gems: number?,
	egg: { id: string, golden: boolean }?,
}

local Daily: { QuestDef } = {
	{ id = "d_win2", kind = "WinRanked", target = 2, text = "Win 2 ranked battles", coins = 300 },
	{ id = "d_play3", kind = "PlayRanked", target = 3, text = "Play 3 ranked battles", coins = 200 },
	{ id = "d_harvest30", kind = "Harvest", target = 30, text = "Harvest 30 resources", coins = 250 },
	{ id = "d_hatch3", kind = "Hatch", target = 3, text = "Hatch 3 eggs", coins = 250 },
	{ id = "d_sell20", kind = "SellItems", target = 20, text = "Sell 20 items to a merchant", coins = 150 },
	{ id = "d_merge1", kind = "Merge", target = 1, text = "Level up a card by merging", coins = 200 },
	{ id = "d_trial1", kind = "TrialWin", target = 1, text = "Win a Guardian Trial", coins = 300 },
}

local Achievements: { QuestDef } = {
	{ id = "a_first_win", kind = "WinRanked", target = 1, text = "Win your first ranked battle", gems = 10 },
	{ id = "a_wins_25", kind = "WinRanked", target = 25, text = "Win 25 ranked battles", gems = 25 },
	{ id = "a_wins_100", kind = "WinRanked", target = 100, text = "Win 100 ranked battles", gems = 60 },
	{ id = "a_harvest_500", kind = "Harvest", target = 500, text = "Harvest 500 resources", gems = 20 },
	{ id = "a_hatch_50", kind = "Hatch", target = 50, text = "Hatch 50 eggs", gems = 20 },
	{ id = "a_trials_3", kind = "TrialFirstClear", target = 3, text = "Clear 3 Guardian Trials", gems = 30 },
	{
		id = "a_trials_10",
		kind = "TrialFirstClear",
		target = 10,
		text = "Clear all 10 Guardian Trials",
		gems = 100,
	},
	{
		id = "quest_reveal_secret_egg",
		kind = "Harvest",
		world = 9,
		target = 150,
		text = "Harvest 150 resources in the Shadow Dimension to reveal the Secret Egg",
		gems = 15,
	},
}

local ById: { [string]: QuestDef } = {}
for _, q in Daily do
	ById[q.id] = q
end
for _, q in Achievements do
	ById[q.id] = q
end

return table.freeze({
	Daily = table.freeze(Daily),
	Achievements = table.freeze(Achievements),
	ById = table.freeze(ById),
	dailyCount = 3,
})
