--!strict
-- Which 3D model shows an item until its painted icon is live: the item's own resource node from
-- Config/WorldLayouts (an Oak Log shows the oak-log pile, never a crystal). Pure lookup, built once.
local Config = script.Parent.Parent.Config
local WorldLayouts = require(Config.WorldLayouts)

local nodeModel: { [string]: string } = {}
for _, layout in WorldLayouts.List do
	for _, res in layout.resources do
		if nodeModel[res.itemId] == nil then
			nodeModel[res.itemId] = res.model
		end
	end
end

local ItemArt = {}

-- The Config/WorldProps key of the node this item is harvested from, or nil.
function ItemArt.nodeModel(itemId: string): string?
	return nodeModel[itemId]
end

return table.freeze(ItemArt)
