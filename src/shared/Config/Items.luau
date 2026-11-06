--!strict
-- Farmable items. World 1 resources are defined now; worlds 2-10 are added in M6.
local Types = require(script.Parent.Parent.Types)

local List: { Types.ItemDef } = {
	{ id = "item_greenleaf", displayName = "Greenleaf", world = 1, maxStack = 50, sellPrice = 4 },
	{ id = "item_oak_log", displayName = "Oak Log", world = 1, maxStack = 50, sellPrice = 6 },
	{ id = "item_meadow_crystal", displayName = "Meadow Crystal", world = 1, maxStack = 50, sellPrice = 25 },
}

local ById: { [string]: Types.ItemDef } = {}
for _, def in List do
	ById[def.id] = def
end

return table.freeze({ List = table.freeze(List), ById = table.freeze(ById) })
