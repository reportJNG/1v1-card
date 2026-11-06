--!strict
-- What each world contains, as data: its look, its farming resources and its NPCs. The world
-- builder (Server/World/WorldBuilder) and the farming rules (Shared/Domain/Farming) both read
-- node positions from Shared/Domain/WorldLayout, so the server's range check always matches what
-- was built. Geometry is a blockout until world art exists (ContentStatus: worldArt).

export type Resource = {
	itemId: string,
	nodes: number, -- how many nodes of this resource the world has
	respawnSeconds: number, -- per player: a harvested node is ready again after this
	yield: { number }, -- { min, max } items per harvest
	rareItemId: string?, -- optional rare drop from this node
	rareChance: number?,
}

export type Layout = {
	world: number,
	theme: { ground: string, accent: string, material: string, sky: string },
	resources: { Resource },
	merchantName: string,
}

local function layout(
	world: number,
	theme: { ground: string, accent: string, material: string, sky: string },
	common: { string },
	rare: string,
	respawn: number,
	merchantName: string
): Layout
	return {
		world = world,
		theme = theme,
		resources = {
			{
				itemId = common[1],
				nodes = 6,
				respawnSeconds = respawn,
				yield = { 1, 3 },
				rareItemId = rare,
				rareChance = 0.03,
			},
			{
				itemId = common[2],
				nodes = 5,
				respawnSeconds = respawn + 10,
				yield = { 1, 2 },
				rareItemId = rare,
				rareChance = 0.03,
			},
			{ itemId = rare, nodes = 2, respawnSeconds = 120, yield = { 1, 1 } },
		},
		merchantName = merchantName,
	}
end

local List: { Layout } = {
	layout(1, { ground = "#5BA84A", accent = "#8FD16A", material = "Grass", sky = "#9AD7FF" }, {
		"item_greenleaf",
		"item_oak_log",
	}, "item_meadow_crystal", 20, "Farmer Tobb"),
	layout(2, { ground = "#2F6B45", accent = "#B98CFF", material = "LeafyGrass", sky = "#5D7FB8" }, {
		"item_moonpetal",
		"item_elderwood",
	}, "item_sprite_dust", 22, "Willow the Herbalist"),
	layout(3, { ground = "#D9B36C", accent = "#F2D49B", material = "Sand", sky = "#FFD9A0" }, {
		"item_sunstone_sand",
		"item_cactus_fruit",
	}, "item_desert_ruby", 24, "Trader Qasim"),
	layout(4, { ground = "#DCEBF5", accent = "#8CC8F0", material = "Snow", sky = "#B8D8F0" }, {
		"item_frost_lichen",
		"item_glacier_shard",
	}, "item_aurora_pearl", 26, "Old Nanuk"),
	layout(5, { ground = "#3A2A26", accent = "#FF6A2B", material = "Basalt", sky = "#5A2A1E" }, {
		"item_ash_coal",
		"item_obsidian",
	}, "item_magma_heart", 28, "Smith Brann"),
	layout(6, { ground = "#3B1730", accent = "#E03A6A", material = "CrackedLava", sky = "#2A0E1E" }, {
		"item_brimroot",
		"item_hexbone",
	}, "item_void_ember", 30, "The Ashen Broker"),
	layout(7, { ground = "#EAF2FF", accent = "#FFE58A", material = "SmoothPlastic", sky = "#C9E4FF" }, {
		"item_cloud_cotton",
		"item_skyglass",
	}, "item_star_feather", 32, "Skykeeper Lumi"),
	layout(8, { ground = "#8C7A5B", accent = "#D9B44A", material = "Cobblestone", sky = "#C2A878" }, {
		"item_relic_clay",
		"item_runestone",
	}, "item_kings_coin", 34, "Curator Hessen"),
	layout(9, { ground = "#1C1830", accent = "#7C5CFF", material = "Slate", sky = "#0E0B1C" }, {
		"item_umbral_moss",
		"item_null_quartz",
	}, "item_rift_eye", 36, "The Hollow Peddler"),
	layout(10, { ground = "#FFF6E0", accent = "#FFD45C", material = "Marble", sky = "#FFF0C8" }, {
		"item_halo_bloom",
		"item_seraph_gold",
	}, "item_divine_tear", 38, "Archivist Seraphine"),
}

local ByWorld: { [number]: Layout } = {}
for _, def in List do
	ByWorld[def.world] = def
end

return table.freeze({
	List = table.freeze(List),
	ByWorld = table.freeze(ByWorld),
	HARVEST_RANGE = 12, -- studs; the server rejects harvests from farther away
	MERCHANT_RANGE = 16,
	WORLD_SPACING = 2000, -- studs between world origins along X
	WORLD_SIZE = 360, -- side of each world's play area
})
