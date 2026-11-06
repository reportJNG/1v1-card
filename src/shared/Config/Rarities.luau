--!strict
-- Five rarities. Rarity sets drop odds (see OddsBands), a small stat budget,
-- merge value and presentation. It never sets the level ceiling (Q2: all rarities max at 15).
local Types = require(script.Parent.Parent.Types)

local Rarities = {}

local ORDER: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
table.freeze(ORDER)
Rarities.Order = ORDER

Rarities.Defs = table.freeze({
	Common = { order = 1, color = Color3.fromHex("#B9C7DC"), statBudget = 0.00, mergePoints = 1 },
	Rare = { order = 2, color = Color3.fromHex("#45BEFF"), statBudget = 0.02, mergePoints = 2 },
	Epic = { order = 3, color = Color3.fromHex("#A469FF"), statBudget = 0.04, mergePoints = 4 },
	Legendary = { order = 4, color = Color3.fromHex("#FFC54B"), statBudget = 0.06, mergePoints = 8 },
	Mythical = { order = 5, color = Color3.fromHex("#FF668F"), statBudget = 0.08, mergePoints = 15 },
}) :: { [string]: Types.RarityDef }

return table.freeze(Rarities)
