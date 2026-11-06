--!strict
-- Role base stats at level 1, Common rarity. Validated by the battle balance model
-- (design doc section 3). Rarity adds Rarities.Defs[r].statBudget on top.
local Types = require(script.Parent.Parent.Types)

return table.freeze({
	Striker = { base = { hp = 585, atk = 340, def = 90, spd = 110 } },
	Guardian = { base = { hp = 748, atk = 260, def = 140, spd = 85 } },
	Skirmisher = { base = { hp = 553, atk = 300, def = 90, spd = 135 } },
	Trickster = { base = { hp = 585, atk = 300, def = 100, spd = 120 } },
	Support = { base = { hp = 650, atk = 260, def = 110, spd = 100 } },
	Bruiser = { base = { hp = 683, atk = 320, def = 110, spd = 95 } },
}) :: { [string]: Types.RoleDef }
