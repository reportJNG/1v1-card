--!strict
-- Fifteen families. Two of a family in a deck give +2% to its bonus stat, three give +3%.
-- Crit families add percentage points of crit chance instead.
local Types = require(script.Parent.Parent.Types)

local Families = {}

Families.Defs = table.freeze({
	Dragon = { bonusStat = "atk" },
	Flame = { bonusStat = "atk" },
	Warrior = { bonusStat = "atk" },
	Shadow = { bonusStat = "spd" },
	Lightning = { bonusStat = "spd" },
	Ninja = { bonusStat = "spd" },
	Ice = { bonusStat = "def" },
	Beast = { bonusStat = "def" },
	Ancient = { bonusStat = "def" },
	Divine = { bonusStat = "hp" },
	Spirit = { bonusStat = "hp" },
	Royal = { bonusStat = "hp" },
	Demon = { bonusStat = "crit" },
	Cosmic = { bonusStat = "crit" },
	Mystic = { bonusStat = "crit" },
}) :: { [string]: Types.FamilyDef }

-- Bonus by number of deck cards sharing a family (1 = no bonus).
Families.SynergyBonus = table.freeze({ [1] = 0, [2] = 0.02, [3] = 0.03 }) :: { [number]: number }

return table.freeze(Families)
