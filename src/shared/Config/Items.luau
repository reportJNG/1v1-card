--!strict
-- Farmable items: per world, two common resources and one rare one. Sold to that world's NPC
-- merchant at `sellPrice` Coins each. Prices are starting values (ContentStatus: items).
local Types = require(script.Parent.Parent.Types)

local function item(
	id: string,
	displayName: string,
	world: number,
	sellPrice: number,
	rare: boolean?
): Types.ItemDef
	return {
		id = id,
		displayName = displayName,
		world = world,
		maxStack = if rare then 25 else 50,
		sellPrice = sellPrice,
		rare = rare == true,
	}
end

local List: { Types.ItemDef } = {
	item("item_greenleaf", "Greenleaf", 1, 4),
	item("item_oak_log", "Oak Log", 1, 6),
	item("item_meadow_crystal", "Meadow Crystal", 1, 25, true),

	item("item_moonpetal", "Moonpetal", 2, 5),
	item("item_elderwood", "Elderwood", 2, 8),
	item("item_sprite_dust", "Sprite Dust", 2, 40, true),

	item("item_sunstone_sand", "Sunstone Sand", 3, 7),
	item("item_cactus_fruit", "Cactus Fruit", 3, 10),
	item("item_desert_ruby", "Desert Ruby", 3, 60, true),

	item("item_frost_lichen", "Frost Lichen", 4, 10),
	item("item_glacier_shard", "Glacier Shard", 4, 14),
	item("item_aurora_pearl", "Aurora Pearl", 4, 90, true),

	item("item_ash_coal", "Ash Coal", 5, 14),
	item("item_obsidian", "Obsidian", 5, 20),
	item("item_magma_heart", "Magma Heart", 5, 130, true),

	item("item_brimroot", "Brimroot", 6, 18),
	item("item_hexbone", "Hexbone", 6, 26),
	item("item_void_ember", "Void Ember", 6, 180, true),

	item("item_cloud_cotton", "Cloud Cotton", 7, 24),
	item("item_skyglass", "Skyglass", 7, 34),
	item("item_star_feather", "Star Feather", 7, 240, true),

	item("item_relic_clay", "Relic Clay", 8, 30),
	item("item_runestone", "Runestone", 8, 44),
	item("item_kings_coin", "King's Coin", 8, 320, true),

	item("item_umbral_moss", "Umbral Moss", 9, 38),
	item("item_null_quartz", "Null Quartz", 9, 56),
	item("item_rift_eye", "Rift Eye", 9, 420, true),

	item("item_halo_bloom", "Halo Bloom", 10, 48),
	item("item_seraph_gold", "Seraph Gold", 10, 70),
	item("item_divine_tear", "Divine Tear", 10, 550, true),
}

local ById: { [string]: Types.ItemDef } = {}
for _, def in List do
	ById[def.id] = def
end

return table.freeze({ List = table.freeze(List), ById = table.freeze(ById) })
