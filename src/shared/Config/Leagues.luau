--!strict
-- Ranked leagues. Card levels above a league's cap count as the cap in ranked matches.
local Types = require(script.Parent.Parent.Types)

return table.freeze({
	List = table.freeze({
		{ id = "Bronze", minTrophies = 0, rankedLevelCap = 4 },
		{ id = "Silver", minTrophies = 700, rankedLevelCap = 8 },
		{ id = "Gold", minTrophies = 1350, rankedLevelCap = 12 },
		{ id = "Diamond", minTrophies = 2200, rankedLevelCap = 15 },
	} :: { Types.LeagueDef }),
})
