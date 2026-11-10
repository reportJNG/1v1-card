--!strict
-- The 5 battle arenas (BAD_GUI_8 section 5). Every battle, ranked or Guardian Trial, is fought in
-- one of them, picked by the server from the match seed (Shared/Domain/ArenaLayout.pick), so both
-- players see the same map. All maps share one core (ArenaLayout.core: a 40-stud platform, two
-- light pads, spawn and camera points), so gameplay and camera angles never change; only the
-- surroundings differ:
--   dressing   original generated meshes already in the game (Config/HubLayout.Models and
--              Config/WorldProps): no new uploads, no Creator Store models
--   prims      simple shapes for ground, water, lava, cloud banks, banners and light rings
--   city       a generated skyline far below (Storm Rooftop)
--   particles  the map's ambient particles (one emitter; ART_STYLE budget)
--   fx         client-side map effects: "lightning" (flash + thunder), "spin" (light rings)
-- Lighting presets are Config/Lighting `arena_<id>`; music slots are Config/Sounds. Positions are
-- studs from the arena centre (platform top at y = 0); the camera looks toward -Z.

export type Vec = { number }

export type Piece = {
	model: string, -- a Config/HubLayout.Models or Config/WorldProps key
	at: Vec,
	rotY: number?,
	scale: number?,
	light: { color: string, range: number, brightness: number, height: number }?,
}

export type Prim = {
	shape: "Block" | "Cylinder" | "Ball" | "Ring",
	-- Block / Ball: { x, y, z }; Cylinder: { diameter, height } (upright);
	-- Ring: { diameter, thickness, segments } (a flat ring of blocks)
	size: Vec,
	at: Vec,
	color: string,
	material: string, -- Enum.Material name
	transparency: number?,
	rot: Vec?, -- degrees
	tag: string?, -- "Spin": turned slowly by the client
	image: string?, -- a Config/UiAssets slot shown on both faces
	collide: boolean?, -- solid to players (default: not)
	name: string?,
	light: { color: string, range: number, brightness: number }?,
}

export type Particles = {
	texture: string, -- Config/UiAssets slot
	colors: { string },
	rate: number,
	direction: "fall" | "rise" | "drift" | "rain",
	size: number,
}

export type Arena = {
	id: string,
	displayName: string,
	weight: number, -- relative chance (all equal: a uniform pick)
	lighting: string, -- Config/Lighting preset
	music: string, -- Config/Sounds slot
	platform: { color: string, material: string, rim: string, inner: string, pad: string },
	dressing: { Piece },
	prims: { Prim },
	city: { count: number, radius: { number }, y: number, height: { number }, glow: { string } }?,
	particles: Particles,
	fx: { string },
}

local WARM = "#FFB45A"

local function lantern(x: number, z: number): Piece
	return {
		model = "stone_lantern",
		at = { x, 0, z },
		scale = 1.1,
		light = { color = WARM, range = 16, brightness = 2.4, height = 4.6 },
	}
end

local List: { Arena } = {
	{
		id = "sakura",
		displayName = "Sakura Courtyard",
		weight = 1,
		lighting = "arena_sakura",
		music = "music_arena_sakura",
		platform = {
			color = "#2B2347",
			material = "Slate",
			rim = "#FF8CC6",
			inner = "#A469FF",
			pad = "#FFE9F4",
		},
		dressing = {
			{ model = "torii", at = { 0, 0, -36 }, scale = 1.35 },
			{ model = "cherry_tree", at = { -32, 0, -38 }, rotY = 40, scale = 0.95 },
			{ model = "cherry_tree", at = { 34, 0, -40 }, rotY = 220, scale = 0.9 },
			{ model = "cherry_tree", at = { -46, 0, 6 }, rotY = 120, scale = 0.8 },
			{ model = "cherry_tree", at = { 48, 0, 10 }, rotY = 300, scale = 0.8 },
			{ model = "pagoda", at = { -54, 0, -76 }, rotY = 20, scale = 1.2 },
			{ model = "pagoda", at = { 58, 0, -80 }, rotY = -20, scale = 1.05 },
			lantern(-24, -22),
			lantern(24, -22),
			lantern(-28, 14),
			lantern(28, 14),
			{ model = "sky_island", at = { -70, 46, -150 }, rotY = 60, scale = 2.4 },
			{ model = "sky_island", at = { 80, 64, -170 }, rotY = 200, scale = 2.8 },
		},
		prims = {
			-- the courtyard paving
			{
				shape = "Cylinder",
				size = { 150, 2 },
				at = { 0, -1.3, -20 },
				color = "#221B36",
				material = "Slate",
			},
			-- the koi pond edge (back left)
			{
				shape = "Cylinder",
				size = { 20, 0.6 },
				at = { -30, -0.15, -16 },
				color = "#3B3456",
				material = "Cobblestone",
			},
			{
				shape = "Cylinder",
				size = { 18, 0.6 },
				at = { -30, 0.05, -16 },
				color = "#2E5D8A",
				material = "Glass",
				transparency = 0.15,
				light = { color = "#6FB8FF", range = 14, brightness = 1.2 },
			},
		},
		particles = {
			texture = "petal",
			colors = { "#FFD6EC", "#FFB3D9" },
			rate = 9,
			direction = "fall",
			size = 0.55,
		},
		fx = {},
	},
	{
		id = "frozen",
		displayName = "Frozen Shrine",
		weight = 1,
		lighting = "arena_frozen",
		music = "music_arena_frozen",
		platform = {
			color = "#5E93BE",
			material = "Ice",
			rim = "#7CE8FF",
			inner = "#C8F4FF",
			pad = "#E8FBFF",
		},
		dressing = {
			{ model = "guardian_gate", at = { 0, 0, -38 }, scale = 1.5 },
			{ model = "w4_spire", at = { -28, 0, -30 }, rotY = 20, scale = 1.1 },
			{ model = "w4_spire", at = { 30, 0, -32 }, rotY = 200, scale = 1.2 },
			{ model = "w4_spire", at = { -52, 0, -60 }, rotY = 80, scale = 1.6 },
			{ model = "w4_spire", at = { 54, 0, -62 }, rotY = 140, scale = 1.5 },
			{ model = "w4_glacier_shard", at = { -22, 0, -12 }, rotY = 30, scale = 1.3 },
			{ model = "w4_glacier_shard", at = { 23, 0, -14 }, rotY = 160, scale = 1.2 },
			{ model = "w4_glacier_shard", at = { -24, 0, 16 }, rotY = 250 },
			{ model = "w4_glacier_shard", at = { 25, 0, 18 }, rotY = 300 },
			{ model = "w4_pine", at = { -62, 0, -36 }, rotY = 10, scale = 1.2 },
			{ model = "w4_pine", at = { 64, 0, -40 }, rotY = 90, scale = 1.3 },
			{ model = "w4_pine", at = { -42, 0, -86 }, rotY = 40, scale = 1.4 },
			{ model = "w4_pine", at = { 46, 0, -90 }, rotY = 200, scale = 1.4 },
			{ model = "w4_pine", at = { -50, 0, 20 }, rotY = 300 },
			{ model = "w4_pine", at = { 52, 0, 24 }, rotY = 120 },
		},
		prims = {
			-- the glacier and its mirror-ice floor
			{
				shape = "Cylinder",
				size = { 160, 2 },
				at = { 0, -1.3, -20 },
				color = "#DCEFFA",
				material = "Glacier",
			},
			-- crystal pillars at the platform edge
			{
				shape = "Cylinder",
				size = { 1.2, 12 },
				at = { -19, 6, -8 },
				color = "#8FEFFF",
				material = "Neon",
				transparency = 0.35,
			},
			{
				shape = "Cylinder",
				size = { 1.2, 12 },
				at = { 19, 6, -8 },
				color = "#8FEFFF",
				material = "Neon",
				transparency = 0.35,
			},
			-- the aurora ribbons
			{
				shape = "Block",
				size = { 220, 22, 1 },
				at = { -20, 90, -240 },
				rot = { 0, 8, -6 },
				color = "#59FFC2",
				material = "Neon",
				transparency = 0.82,
			},
			{
				shape = "Block",
				size = { 200, 14, 1 },
				at = { 40, 112, -250 },
				rot = { 0, -10, 5 },
				color = "#7C9BFF",
				material = "Neon",
				transparency = 0.85,
			},
		},
		particles = {
			texture = "sparkle",
			colors = { "#FFFFFF", "#D8F2FF" },
			rate = 16,
			direction = "fall",
			size = 0.35,
		},
		fx = {},
	},
	{
		id = "volcano",
		displayName = "Volcano Forge",
		weight = 1,
		lighting = "arena_volcano",
		music = "music_arena_volcano",
		platform = {
			color = "#2A2026",
			material = "Basalt",
			rim = "#FF6A2A",
			inner = "#FFB03A",
			pad = "#FFE2C2",
		},
		dressing = {
			{ model = "w5_spire", at = { -38, -8, -44 }, rotY = 30, scale = 1.1 },
			{ model = "w5_spire", at = { 42, -8, -48 }, rotY = 200, scale = 1.2 },
			{ model = "w5_spire", at = { -70, -8, -80 }, rotY = 90, scale = 1.6 },
			{ model = "w5_spire", at = { 74, -8, -84 }, rotY = 160, scale = 1.5 },
			{ model = "w5_obsidian", at = { -22, 0, -14 }, rotY = 20, scale = 1.4 },
			{ model = "w5_obsidian", at = { 22, 0, -16 }, rotY = 210, scale = 1.3 },
			{ model = "w5_obsidian", at = { -24, 0, 14 }, rotY = 120 },
			{ model = "w5_obsidian", at = { 24, 0, 16 }, rotY = 300 },
			{ model = "w5_vent", at = { -40, -8, -16 }, scale = 1.2 },
			{ model = "w5_vent", at = { 44, -8, -10 }, scale = 1.1 },
			{ model = "w5_dead_tree", at = { -54, -8, 4 }, rotY = 70, scale = 1.2 },
			{ model = "w5_dead_tree", at = { 58, -8, 0 }, rotY = 250, scale = 1.1 },
			{ model = "w5_magma_heart", at = { 0, 0, -26 }, scale = 1.6 },
		},
		prims = {
			-- the obsidian rock under the platform and the lava sea around it
			{
				shape = "Cylinder",
				size = { 48, 10 },
				at = { 0, -5.2, 0 },
				color = "#1A1418",
				material = "Basalt",
			},
			{
				shape = "Cylinder",
				size = { 260, 1 },
				at = { 0, -8.5, -40 },
				color = "#FF5A1E",
				material = "CrackedLava",
				light = { color = "#FF6A2A", range = 40, brightness = 2 },
			},
			-- glowing cracks across the platform
			{
				shape = "Block",
				size = { 14, 0.08, 0.35 },
				at = { -4, 0.06, -9 },
				rot = { 0, 24, 0 },
				color = "#FF7A2A",
				material = "Neon",
			},
			{
				shape = "Block",
				size = { 10, 0.08, 0.3 },
				at = { 7, 0.06, 8 },
				rot = { 0, -32, 0 },
				color = "#FF7A2A",
				material = "Neon",
			},
			-- forge anvils and their chains
			{
				shape = "Block",
				size = { 4, 2.2, 2 },
				at = { -16, 1.1, -16 },
				rot = { 0, 30, 0 },
				color = "#3A3438",
				material = "DiamondPlate",
			},
			{
				shape = "Block",
				size = { 4, 2.2, 2 },
				at = { 16, 1.1, -17 },
				rot = { 0, -30, 0 },
				color = "#3A3438",
				material = "DiamondPlate",
			},
			{
				shape = "Cylinder",
				size = { 0.6, 60 },
				at = { -24, 30, -26 },
				color = "#2C2A2E",
				material = "Metal",
			},
			{
				shape = "Cylinder",
				size = { 0.6, 60 },
				at = { 24, 30, -26 },
				color = "#2C2A2E",
				material = "Metal",
			},
		},
		particles = {
			texture = "sparkle",
			colors = { "#FFD27A", "#FF5A1E" },
			rate = 18,
			direction = "rise",
			size = 0.4,
		},
		fx = {},
	},
	{
		id = "celestial",
		displayName = "Celestial Isle",
		weight = 1,
		lighting = "arena_celestial",
		music = "music_arena_celestial",
		platform = {
			color = "#D9CDB4",
			material = "Marble",
			rim = "#FFD36A",
			inner = "#FFF1B8",
			pad = "#FFFBE8",
		},
		dressing = {
			{ model = "w10_statue", at = { 0, 0, -34 }, scale = 1.4 },
			{ model = "w10_pillar", at = { -21, 0, -16 }, scale = 1.1 },
			{ model = "w10_pillar", at = { 21, 0, -16 }, scale = 1.1 },
			{ model = "w10_pillar", at = { -26, 0, 4 }, scale = 1.1 },
			{ model = "w10_pillar", at = { 26, 0, 4 }, scale = 1.1 },
			{ model = "w7_pavilion", at = { -58, -6, -64 }, rotY = 30, scale = 1.3 },
			{ model = "w7_tree", at = { 60, -4, -58 }, rotY = 200, scale = 1.2 },
			{ model = "w7_crystal", at = { 34, 16, -46 }, rotY = 20 },
			{ model = "w7_crystal", at = { -38, 22, -52 }, rotY = 70, scale = 0.8 },
			{ model = "sky_island", at = { -80, 10, -120 }, rotY = 60, scale = 2.2 },
			{ model = "sky_island", at = { 90, 26, -140 }, rotY = 200, scale = 2.6 },
			{ model = "w10_tree", at = { -50, -6, 18 }, rotY = 100 },
			{ model = "w10_tree", at = { 52, -6, 20 }, rotY = 280 },
		},
		prims = {
			-- the floating white-gold isle under the platform
			{
				shape = "Cylinder",
				size = { 60, 6 },
				at = { 0, -3.2, -6 },
				color = "#E8E0CC",
				material = "Marble",
			},
			{
				shape = "Ball",
				size = { 46, 24, 46 },
				at = { 0, -18, -6 },
				color = "#C9B88F",
				material = "Sandstone",
			},
			-- isles for the pavilion and the trees
			{
				shape = "Cylinder",
				size = { 30, 4 },
				at = { -58, -8, -64 },
				color = "#E8E0CC",
				material = "Marble",
			},
			{
				shape = "Cylinder",
				size = { 26, 4 },
				at = { 60, -6, -58 },
				color = "#E8E0CC",
				material = "Marble",
			},
			-- waterfalls from the isles into the clouds
			{
				shape = "Block",
				size = { 5, 60, 0.6 },
				at = { -50, -40, -52 },
				color = "#CFF2FF",
				material = "Neon",
				transparency = 0.55,
			},
			{
				shape = "Block",
				size = { 4, 56, 0.6 },
				at = { 66, -36, -48 },
				color = "#CFF2FF",
				material = "Neon",
				transparency = 0.55,
			},
			-- the cloud sea
			{
				shape = "Ball",
				size = { 140, 18, 90 },
				at = { -60, -46, -90 },
				color = "#FFF4E6",
				material = "SmoothPlastic",
				transparency = 0.1,
			},
			{
				shape = "Ball",
				size = { 160, 20, 100 },
				at = { 70, -50, -110 },
				color = "#FFE9D2",
				material = "SmoothPlastic",
				transparency = 0.1,
			},
			{
				shape = "Ball",
				size = { 120, 16, 80 },
				at = { 0, -54, 40 },
				color = "#FFF4E6",
				material = "SmoothPlastic",
				transparency = 0.1,
			},
			-- the rotating light rings: halos behind the winged statue
			{
				shape = "Ring",
				size = { 34, 0.5, 36 },
				at = { 0, 16, -40 },
				rot = { 90, 0, 0 },
				color = "#FFE08A",
				material = "Neon",
				transparency = 0.3,
				tag = "Spin",
			},
			{
				shape = "Ring",
				size = { 48, 0.4, 44 },
				at = { 0, 16, -42 },
				rot = { 90, 0, 14 },
				color = "#FFF6D0",
				material = "Neon",
				transparency = 0.45,
				tag = "Spin",
			},
		},
		particles = {
			texture = "sparkle",
			colors = { "#FFF1B8", "#FFFFFF" },
			rate = 10,
			direction = "drift",
			size = 0.45,
		},
		fx = { "spin" },
	},
	{
		id = "storm",
		displayName = "Storm Rooftop",
		weight = 1,
		lighting = "arena_storm",
		music = "music_arena_storm",
		platform = {
			color = "#22263A",
			material = "Slate",
			rim = "#4FA8FF",
			inner = "#9FD0FF",
			pad = "#E6F2FF",
		},
		dressing = {
			{ model = "torii", at = { 0, 0, -30 }, scale = 1.1 },
			{
				model = "lantern_post",
				at = { -24, 0, -22 },
				rotY = 30,
				light = { color = WARM, range = 14, brightness = 2, height = 7 },
			},
			{
				model = "lantern_post",
				at = { 24, 0, -22 },
				rotY = -30,
				light = { color = WARM, range = 14, brightness = 2, height = 7 },
			},
			{ model = "lantern_post", at = { -26, 0, 16 }, rotY = 150 },
			{ model = "lantern_post", at = { 26, 0, 16 }, rotY = 210 },
			{ model = "pagoda", at = { -78, -34, -120 }, rotY = 20, scale = 1.6 },
			{ model = "pagoda", at = { 88, -40, -140 }, rotY = -30, scale = 1.8 },
		},
		prims = {
			-- the pagoda roof the platform stands on
			{
				shape = "Block",
				size = { 64, 3, 56 },
				at = { 0, -1.6, -6 },
				color = "#2A2E44",
				material = "Slate",
			},
			{
				shape = "Block",
				size = { 70, 1.2, 62 },
				at = { 0, -3.4, -6 },
				color = "#6B2230",
				material = "Wood",
			},
			{
				shape = "Block",
				size = { 56, 40, 48 },
				at = { 0, -24, -6 },
				color = "#1A1C28",
				material = "Brick",
			},
			-- roof-edge banners
			{
				shape = "Block",
				size = { 3, 10, 0.2 },
				at = { -31, 5, -30 },
				color = "#C4283C",
				material = "Fabric",
			},
			{
				shape = "Block",
				size = { 3, 10, 0.2 },
				at = { 31, 5, -30 },
				color = "#2A5BC4",
				material = "Fabric",
			},
			{
				shape = "Cylinder",
				size = { 0.4, 14 },
				at = { -31, 7, -30.4 },
				color = "#3A2A20",
				material = "Wood",
			},
			{
				shape = "Cylinder",
				size = { 0.4, 14 },
				at = { 31, 7, -30.4 },
				color = "#3A2A20",
				material = "Wood",
			},
		},
		city = {
			count = 46,
			radius = { 90, 260 },
			y = -70,
			height = { 40, 110 },
			glow = { "#4FA8FF", "#FF5AA8", "#FFC84A" },
		},
		particles = {
			texture = "sparkle",
			colors = { "#CFE6FF", "#9FC4FF" },
			rate = 60,
			direction = "rain",
			size = 0.25,
		},
		fx = { "lightning" },
	},
}

local ById: { [string]: Arena } = {}
for _, a in List do
	ById[a.id] = a
end

return table.freeze({
	List = table.freeze(List),
	ById = table.freeze(ById),
})
