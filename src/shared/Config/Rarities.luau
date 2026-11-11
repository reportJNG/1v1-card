--!strict
-- Five rarities. Rarity sets drop odds (see OddsBands), a small stat budget,
-- merge value and presentation. It never sets the level ceiling (Q2: all rarities max at 15).
--
-- Display (CARDS_EGGS_MISSION section 2, display only: ids and saves never change): every UI
-- shows a rarity through these fields, never a hard-coded colour or name.
--   displayName  the name players read: the locked names Common / Rare / Epic / Legendary /
--                Mythical (BAD_GUI_9: no N / R / SR / SSR / UR letters anywhere; a card shows its
--                rarity as this name or as its coloured gem, kit corner_gem_<tag>)
--   color        the main colour (text, pills, odds rows)
--   colors       { light, main, deep, glow } for gradients, frames and auras
--   emblem       the template card / egg emblem: "star" (Common, Rare) or "crown" (Epic and up)
--   tag          the kit image suffix (art/ui/kit/frame_<tag>_<size>.png and friends)
local Types = require(script.Parent.Parent.Types)

local Rarities = {}

local ORDER: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
table.freeze(ORDER)
Rarities.Order = ORDER

local function palette(light: string, main: string, deep: string, glow: string): { Color3 }
	return table.freeze({
		Color3.fromHex(light),
		Color3.fromHex(main),
		Color3.fromHex(deep),
		Color3.fromHex(glow),
	})
end

Rarities.Defs = table.freeze({
	Common = {
		order = 1,
		color = Color3.fromHex("#E4E2F0"),
		colors = palette("#FFFFFF", "#E4E2F0", "#9080C0", "#E8E6FF"),
		statBudget = 0.00,
		mergePoints = 1,
		displayName = "Common",
		emblem = "star",
		tag = "n",
	},
	Rare = {
		order = 2,
		color = Color3.fromHex("#2AA8FF"),
		colors = palette("#9BE4FF", "#00A0F0", "#0060C0", "#1EA8FF"),
		statBudget = 0.02,
		mergePoints = 2,
		displayName = "Rare",
		emblem = "star",
		tag = "r",
	},
	Epic = {
		order = 3,
		color = Color3.fromHex("#B36BFF"),
		colors = palette("#E090F0", "#9B4DFF", "#5A1FB0", "#B45CFF"),
		statBudget = 0.04,
		mergePoints = 4,
		displayName = "Epic",
		emblem = "crown",
		tag = "sr",
	},
	Legendary = {
		order = 4,
		color = Color3.fromHex("#F5C518"),
		colors = palette("#FFE680", "#F0C010", "#B87800", "#FFB01E"),
		statBudget = 0.06,
		mergePoints = 8,
		displayName = "Legendary",
		emblem = "crown",
		tag = "ssr",
	},
	Mythical = {
		order = 5,
		color = Color3.fromHex("#14D282"),
		colors = palette("#9CFFD6", "#00C070", "#007A48", "#18E890"),
		statBudget = 0.08,
		mergePoints = 15,
		displayName = "Mythical",
		emblem = "crown",
		tag = "ur",
	},
}) :: { [string]: Types.RarityDef }

-- The name players read for a rarity (the Odds panel and labels).
function Rarities.label(rarity: string): string
	local def = Rarities.Defs[rarity]
	return if def then def.displayName else rarity
end

return table.freeze(Rarities)
