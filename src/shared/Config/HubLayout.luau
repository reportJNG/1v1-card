--!strict
-- The lobby (FIX_LOBBY.md section 3): a night sakura temple plaza where players spawn. Zones:
-- the spawn (south) facing north over the river bridge to the round plaza with the fountain and
-- the golden card statue; the 1v1 ARENA gate on its terrace (north); the WORLDS portal on its
-- dais (east); the egg pavilion with its pedestals (west); the merchant (south-west), the quest
-- board and the daily shrine (south-east). Built at runtime by Server/World/HubBuilder from this
-- data. Models are original meshes made with Roblox's generate_mesh (docs/ASSETS.md); the
-- architecture (ground, paths, steps, fountain, signs, stalls) is simple parts. Positions are
-- studs from the hub origin; north is -Z; models face +Z (toward the spawn) at rotY = 0.
local Arenas = require(script.Parent.Arenas)
local LobbyDecor = require(script.Parent.LobbyDecor)

export type Vec = { number } -- { x, y, z }
export type Prim = Arenas.Prim

export type ModelDef = {
	mesh: string,
	texture: string,
	size: Vec, -- the mesh's native size in studs (scale 1)
	note: string,
}

export type Piece = {
	model: string,
	at: Vec,
	rotY: number?, -- degrees
	scale: number?,
	light: { offset: Vec, color: string, range: number, brightness: number }?,
}

export type Feature = {
	at: Vec,
	rotY: number?,
	prompt: { name: string, action: string, object: string }?,
	sign: { text: string, icon: string?, height: number, size: number }?, -- size: width in studs
}

local Models: { [string]: ModelDef } = {
	torii = {
		mesh = "rbxassetid://138127000240516",
		texture = "rbxassetid://104005221765615",
		size = { 23.09, 22, 3.75 },
		note = "vermilion torii gate",
	},
	stone_lantern = {
		mesh = "rbxassetid://109848804615944",
		texture = "rbxassetid://108408962041665",
		size = { 4, 5.6, 3.76 },
		note = "stone toro lantern",
	},
	pagoda = {
		mesh = "rbxassetid://104043512113261",
		texture = "rbxassetid://118302930204062",
		size = { 30, 41.92, 29.75 },
		note = "three-tier pagoda, violet roofs",
	},
	portal = {
		mesh = "rbxassetid://79896909448972",
		texture = "rbxassetid://124301083779520",
		size = { 13.62, 14.34, 8 },
		note = "rune-stone portal ring",
	},
	arena = {
		mesh = "rbxassetid://122652870592090",
		texture = "rbxassetid://124121732817210",
		size = { 30.24, 28.57, 30 },
		note = "arena hall, red and black roof",
	},
	egg_stall = {
		mesh = "rbxassetid://127204934830226",
		texture = "rbxassetid://88267860513211",
		size = { 15.11, 14, 9.37 },
		note = "egg market stall, purple awning",
	},
	cherry_tree = {
		mesh = "rbxassetid://107670497033603",
		texture = "rbxassetid://83193632355922",
		size = { 26, 27.11, 25.93 },
		note = "cherry blossom tree",
	},
	lantern_post = {
		mesh = "rbxassetid://73686400801830",
		texture = "rbxassetid://138853853468308",
		size = { 6, 9, 2.34 },
		note = "post with three paper lanterns",
	},
	sky_island = {
		mesh = "rbxassetid://99889481361002",
		texture = "rbxassetid://79896407781887",
		size = { 26.1, 40, 24.71 },
		note = "floating rock island with shrine",
	},
}

local WARM = "#FFB45A"

-- Simple shapes (built by Shared/Art/ArenaKit.prim): ground, paths, steps, the fountain, the
-- card statue, signs, crates, the quest board, the shrine. Architecture, never characters.
local function p(
	shape: string,
	size: { number },
	at: Vec,
	color: string,
	material: string,
	extra: { [string]: any }?
): Prim
	local out: { [string]: any } = { shape = shape, size = size, at = at, color = color, material = material }
	if extra then
		for k, v in extra do
			out[k] = v
		end
	end
	return out :: any
end

local function lantern(x: number, z: number): Piece
	return {
		model = "stone_lantern",
		at = { x, 0, z },
		scale = 1.4,
		light = { offset = { 0, 5.8, 0 }, color = WARM, range = 16, brightness = 1.6 },
	}
end

local function post(x: number, z: number, rot: number): Piece
	return {
		model = "lantern_post",
		at = { x, 0, z },
		rotY = rot,
		scale = 1.3,
		light = { offset = { 0, 9, 0 }, color = "#FF7A45", range = 18, brightness = 1.4 },
	}
end

-- A brazier: an iron post and a fire bowl (the fire is tagged "Brazier").
local function brazier(x: number, y: number, z: number): { Prim }
	return {
		p("Cylinder", { 1, 3.5 }, { x, y + 1.75, z }, "#3A3438", "Metal"),
		p("Cylinder", { 3.2, 1 }, { x, y + 4, z }, "#2C2A2E", "Metal", {
			tag = "Brazier",
			light = { color = "#FF8A3D", range = 18, brightness = 2.2 },
		}),
	}
end

-- Paper lanterns on a string over the path.
local function lanternString(z: number): { Prim }
	local out = { p("Block", { 22, 0.15, 0.15 }, { 0, 8.6, z }, "#2A2030", "SmoothPlastic") }
	for i, x in { -8, -4, 0, 4, 8 } do
		table.insert(
			out,
			p("Ball", { 1.1, 1.4, 1.1 }, { x, 7.8, z }, if i % 2 == 0 then "#FF6A8A" else "#FF9A4A", "Neon")
		)
	end
	return out
end

local Pieces: { Piece } = {
	-- North: the 1v1 ARENA gate on its terrace, the arena hall behind it, two guardian statues.
	-- (FIX_LOBBY_2 B2: a giant double torii, 3x, and a bigger hall)
	{ model = "torii", at = { 0, 2, -64 }, scale = 3.0 },
	{ model = "torii", at = { 0, 2, -78 }, scale = 2.3 },
	{ model = "arena", at = { 0, 2, -112 }, scale = 1.7 },
	{ model = "w8_statue", at = { -33, 2, -62 }, scale = 1.3 },
	{ model = "w8_statue", at = { 33, 2, -62 }, scale = 1.3 },
	-- East: the WORLDS portal on its dais, facing the plaza.
	{
		model = "portal",
		at = { 76, 1.2, 0 },
		rotY = -90,
		scale = 2.4,
		light = { offset = { 0, 18, 0 }, color = "#C77DFF", range = 42, brightness = 4 },
	},
	-- West: the egg pavilion, facing the plaza.
	{ model = "egg_stall", at = { -76, 0.4, 0 }, rotY = 90, scale = 0.85 },
	-- South-west: the merchant's cart.
	{ model = "merchant_cart", at = { -48, 0, 56 }, rotY = 40, scale = 1.3 },
	-- Lanterns around the plaza (between the four paths) and posts along the spawn path.
	lantern(15, 37),
	lantern(-15, 37),
	lantern(37, 15),
	lantern(37, -15),
	lantern(-37, 15),
	lantern(-37, -15),
	lantern(15, -37),
	lantern(-15, -37),
	post(-16, 82, 0),
	post(16, 82, 0),
	-- Temple backdrop.
	{ model = "pagoda", at = { -58, 0, -104 }, rotY = 20, scale = 1.15 },
	{ model = "pagoda", at = { 60, 0, -108 }, rotY = -20, scale = 1.05 },
	{ model = "pagoda", at = { -144, 0, -40 }, rotY = 60, scale = 1.0 },
	{ model = "pagoda", at = { 146, 0, -36 }, rotY = -60, scale = 0.95 },
	-- The cherry grove.
	{ model = "cherry_tree", at = { -38, 0, -36 }, rotY = 30, scale = 0.85 },
	{ model = "cherry_tree", at = { 38, 0, -38 }, rotY = 200, scale = 0.85 },
	{ model = "cherry_tree", at = { -94, 0, 22 }, rotY = 90, scale = 1.05 },
	{ model = "cherry_tree", at = { 96, 0, 26 }, rotY = 10, scale = 1.0 },
	{ model = "cherry_tree", at = { -74, 0, 88 }, rotY = 150, scale = 0.9 },
	{ model = "cherry_tree", at = { 76, 0, 90 }, rotY = 270, scale = 0.9 },
	{ model = "cherry_tree", at = { -104, 0, -82 }, rotY = 60, scale = 1.1 },
	{ model = "cherry_tree", at = { 106, 0, -84 }, rotY = 300, scale = 1.05 },
	{ model = "cherry_tree", at = { -28, 0, 44 }, rotY = 120, scale = 0.6 },
	{ model = "cherry_tree", at = { 28, 0, 44 }, rotY = 240, scale = 0.6 },
	-- The outer grove and far pagodas, so the lobby has no empty edge.
	{ model = "cherry_tree", at = { -134, 0, 8 }, rotY = 20, scale = 1.2 },
	{ model = "cherry_tree", at = { 136, 0, -4 }, rotY = 200, scale = 1.2 },
	{ model = "cherry_tree", at = { -142, 0, 74 }, rotY = 80, scale = 1.1 },
	{ model = "cherry_tree", at = { 144, 0, 70 }, rotY = 160, scale = 1.1 },
	{ model = "cherry_tree", at = { -62, 0, 132 }, rotY = 300, scale = 1.0 },
	{ model = "cherry_tree", at = { 64, 0, 130 }, rotY = 40, scale = 1.0 },
	{ model = "cherry_tree", at = { -150, 0, -130 }, rotY = 110, scale = 1.3 },
	{ model = "cherry_tree", at = { 152, 0, -128 }, rotY = 250, scale = 1.3 },
	{ model = "pagoda", at = { -58, 0, -164 }, rotY = 10, scale = 1.3 },
	{ model = "pagoda", at = { 62, 0, -168 }, rotY = -10, scale = 1.2 },
	-- Floating islands on the horizon.
	{ model = "sky_island", at = { -170, 60, -230 }, rotY = 40, scale = 2.5 },
	{ model = "sky_island", at = { 185, 85, -270 }, rotY = 200, scale = 3 },
	{ model = "sky_island", at = { 10, 120, -380 }, rotY = 110, scale = 3.5 },
	{ model = "sky_island", at = { -270, 35, -70 }, rotY = 300, scale = 2 },
	{ model = "sky_island", at = { 280, 50, -40 }, rotY = 15, scale = 2.2 },
}

local Prims: { Prim } = {
	-- Ground: night grass, the courtyard, the round plaza and its inlays.
	p("Block", { 420, 2, 420 }, { 0, -1.05, 0 }, "#2A2450", "Grass", { collide = true, name = "Ground" }),
	p("Block", { 236, 0.3, 236 }, { 0, 0.0, -6 }, "#3B3364", "Slate", { collide = true, name = "Courtyard" }),
	p("Cylinder", { 72, 0.3 }, { 0, 0.2, 0 }, "#5B5088", "Cobblestone", { collide = true, name = "Plaza" }),
	p("Ring", { 73, 0.7, 48 }, { 0, 0.4, 0 }, "#8E84BE", "Marble"),
	p("Ring", { 58, 0.1, 48 }, { 0, 0.36, 0 }, "#A469FF", "Neon", { transparency = 0.55 }),
	p("Ring", { 44, 0.12, 40 }, { 0, 0.36, 0 }, "#CFC6E8", "Marble"),
	-- The fountain with the golden card statue (an original trophy: a giant card on a pedestal).
	p("Cylinder", { 18, 1.4 }, { 0, 1, 0 }, "#D8D0F0", "Marble", { collide = true, name = "Fountain" }),
	p("Cylinder", { 16.2, 0.2 }, { 0, 1.65, 0 }, "#5AB4FF", "Glass", {
		transparency = 0.2,
		name = "FountainWater",
		light = { color = "#6FC8FF", range = 16, brightness = 1.4 },
	}),
	p("Ring", { 18, 0.4, 32 }, { 0, 1.75, 0 }, "#FFC54B", "Metal"),
	p("Cylinder", { 4.4, 4.6 }, { 0, 3.9, 0 }, "#E6E0F6", "Marble", { collide = true }),
	p("Cylinder", { 5.6, 0.6 }, { 0, 6.5, 0 }, "#FFC54B", "Metal"),
	p("Block", { 9, 13, 0.7 }, { 0, 13.4, 0 }, "#FFC54B", "Foil", {
		image = "card_back",
		tag = "Spin",
		name = "CardStatue",
		light = { color = "#FFD27A", range = 28, brightness = 2 },
	}),
	-- The spawn circle and the path north over the river.
	p("Block", { 14, 0.2, 30 }, { 0, 0.2, 51 }, "#6E5FA6", "Brick", { collide = true }),
	p("Block", { 14, 0.2, 10 }, { 0, 0.2, 83 }, "#6E5FA6", "Brick", { collide = true }),
	-- The river and its banks, with a wooden bridge.
	p("Block", { 420, 0.3, 10 }, { 0, 0.1, 72 }, "#2F6FBF", "Glass", { transparency = 0.25, name = "River" }),
	p("Block", { 420, 0.6, 1.2 }, { 0, 0.3, 66.4 }, "#4A4270", "Cobblestone"),
	p("Block", { 420, 0.6, 1.2 }, { 0, 0.3, 77.6 }, "#4A4270", "Cobblestone"),
	p("Block", { 14, 0.6, 13 }, { 0, 0.6, 72 }, "#7A4A2E", "WoodPlanks", { collide = true, name = "Bridge" }),
	p("Block", { 0.5, 1.4, 13 }, { -7.2, 1.6, 72 }, "#5A3420", "Wood", { collide = true }),
	p("Block", { 0.5, 1.4, 13 }, { 7.2, 1.6, 72 }, "#5A3420", "Wood", { collide = true }),
	p("Block", { 0.9, 2.4, 0.9 }, { -7.2, 1.5, 65.6 }, "#B83A4A", "Wood"),
	p("Block", { 0.9, 2.4, 0.9 }, { 7.2, 1.5, 65.6 }, "#B83A4A", "Wood"),
	p("Block", { 0.9, 2.4, 0.9 }, { -7.2, 1.5, 78.4 }, "#B83A4A", "Wood"),
	p("Block", { 0.9, 2.4, 0.9 }, { 7.2, 1.5, 78.4 }, "#B83A4A", "Wood"),
	-- North: a short path, three steps and the arena terrace, with banners and the round sign.
	p("Block", { 16, 0.2, 14 }, { 0, 0.2, -42 }, "#6E5FA6", "Brick", { collide = true }),
	p("Block", { 30, 0.5, 2.5 }, { 0, 0.25, -50.25 }, "#7A6FAA", "Slate", { collide = true }),
	p("Block", { 30, 1.0, 2.5 }, { 0, 0.5, -52.75 }, "#7A6FAA", "Slate", { collide = true }),
	p("Block", { 30, 1.5, 2.5 }, { 0, 0.75, -55.25 }, "#7A6FAA", "Slate", { collide = true }),
	p("Block", { 80, 2, 80 }, { 0, 1, -96.5 }, "#4A3F78", "Slate", { collide = true, name = "ArenaTerrace" }),
	p("Block", { 80, 0.3, 1.2 }, { 0, 2.1, -56.9 }, "#FFC54B", "Metal"),
	p("Cylinder", { 15, 1.2 }, { 0, 38.5, -61.2 }, "#8A5A34", "WoodPlanks", {
		rot = { 90, 0, 0 },
		image = "icon_play",
		name = "ArenaSign",
	}),
	p("Cylinder", { 0.5, 13 }, { -39, 8.5, -60 }, "#3A2A20", "Wood"),
	p("Cylinder", { 0.5, 13 }, { 39, 8.5, -60 }, "#3A2A20", "Wood"),
	p("Block", { 3.6, 8, 0.2 }, { -39, 9.6, -59.6 }, "#C4283C", "Fabric", { tag = "Sway" }),
	p("Block", { 3.6, 8, 0.2 }, { 39, 9.6, -59.6 }, "#7B3CFF", "Fabric", { tag = "Sway" }),
	-- East: the path and the two-tier dais under the portal.
	p("Block", { 18, 0.2, 12 }, { 45, 0.2, 0 }, "#6E5FA6", "Brick", { collide = true }),
	p("Cylinder", { 32, 0.6 }, { 70, 0.3, 0 }, "#4A3F78", "Slate", { collide = true }),
	p("Cylinder", { 24, 0.6 }, { 72, 0.9, 0 }, "#6A5FA0", "Marble", { collide = true }),
	p("Ring", { 24.4, 0.2, 40 }, { 72, 1.25, 0 }, "#C77DFF", "Neon", { transparency = 0.3 }),
	-- West: the path and the pavilion floor (five egg pedestals are added by the builder).
	p("Block", { 18, 0.2, 12 }, { -45, 0.2, 0 }, "#6E5FA6", "Brick", { collide = true }),
	p("Cylinder", { 30, 0.4 }, { -68, 0.2, 0 }, "#6B4A34", "WoodPlanks", { collide = true }),
	-- South-west: the merchant's corner.
	p("Cylinder", { 16, 0.25 }, { -46, 0.15, 54 }, "#6E5FA6", "Brick", { collide = true }),
	p("Block", { 2.4, 2.4, 2.4 }, { -38, 1.2, 50 }, "#8A5A34", "WoodPlanks", { collide = true }),
	p(
		"Block",
		{ 2.4, 2.4, 2.4 },
		{ -36, 1.2, 53 },
		"#7A4A2E",
		"WoodPlanks",
		{ rot = { 0, 20, 0 }, collide = true }
	),
	p("Block", { 1.8, 1.8, 1.8 }, { -37.4, 3.3, 51.2 }, "#8A5A34", "WoodPlanks", { rot = { 0, 35, 0 } }),
	p("Ball", { 2, 2.4, 2 }, { -54, 1.1, 50 }, "#C9A46A", "Fabric"),
	p("Ball", { 2, 2.4, 2 }, { -55.6, 1.1, 52.6 }, "#B8925A", "Fabric"),
	-- South-east: the quest board.
	p("Cylinder", { 0.7, 7 }, { 39.5, 3.5, 54 }, "#5A3420", "Wood"),
	p("Cylinder", { 0.7, 7 }, { 48.5, 3.5, 54 }, "#5A3420", "Wood"),
	p(
		"Block",
		{ 10, 6, 0.6 },
		{ 44, 4.6, 54 },
		"#8A5A34",
		"WoodPlanks",
		{ collide = true, name = "QuestBoard" }
	),
	p("Block", { 12, 0.6, 2.4 }, { 44, 8, 54 }, "#5A2A3A", "Wood", {
		light = { color = "#FFD27A", range = 12, brightness = 1 },
	}),
	p("Block", { 2.4, 2.8, 0.1 }, { 41.6, 4.8, 53.65 }, "#F2E8D0", "SmoothPlastic"),
	p("Block", { 2.4, 2.4, 0.1 }, { 45.2, 5.2, 53.65 }, "#F2E8D0", "SmoothPlastic"),
	p("Block", { 1.8, 2.2, 0.1 }, { 47.4, 3.6, 53.65 }, "#F2E8D0", "SmoothPlastic"),
	p("Ball", { 0.6, 0.6, 0.6 }, { 41.6, 6, 53.5 }, "#FFC54B", "Neon"),
	p("Ball", { 0.6, 0.6, 0.6 }, { 45.2, 6.2, 53.5 }, "#FF7BD5", "Neon"),
	p("Ball", { 0.6, 0.6, 0.6 }, { 47.4, 4.6, 53.5 }, "#45BEFF", "Neon"),
	-- East of the spawn path: the daily shrine and its gift chest (it glows when the reward is ready).
	p("Block", { 10, 1, 8 }, { 66, 0.5, 46 }, "#D8D0F0", "Marble", { collide = true }),
	p("Cylinder", { 0.9, 6 }, { 62.5, 4, 43 }, "#B83A4A", "Wood"),
	p("Cylinder", { 0.9, 6 }, { 69.5, 4, 43 }, "#B83A4A", "Wood"),
	p("Cylinder", { 0.9, 6 }, { 62.5, 4, 49 }, "#B83A4A", "Wood"),
	p("Cylinder", { 0.9, 6 }, { 69.5, 4, 49 }, "#B83A4A", "Wood"),
	p("Block", { 12, 0.8, 10 }, { 66, 7.4, 46 }, "#5A2A3A", "Wood"),
	p("Block", { 8, 0.6, 6 }, { 66, 8.1, 46 }, "#7A3A4A", "Wood"),
	p("Block", { 3, 2, 2 }, { 66, 2, 46 }, "#FFC54B", "Foil", {
		name = "DailyChest",
		light = { color = "#FFD27A", range = 14, brightness = 0 },
	}),
}
for _, list in { brazier(-16, 2, -59), brazier(16, 2, -59), brazier(62, 1.2, -11), brazier(62, 1.2, 11) } do
	for _, prim in list do
		table.insert(Prims, prim)
	end
end
for _, z in { 44, 58 } do
	for _, prim in lanternString(z) do
		table.insert(Prims, prim)
	end
end
-- FIX_LOBBY_2 section B: the spawn shrine, the tiled path and koi stream, the carpet, the temple
-- gate, the egg pagoda, the plaza's pool, cards, tiles and seats, walls and the shelf's edge.
for _, prim in LobbyDecor.Prims do
	table.insert(Prims, prim)
end
for _, piece in LobbyDecor.Pieces do
	table.insert(Pieces, piece)
end

-- The eggs on the pavilion's pedestals: World 1's eggs (the real pack images, unedited), each
-- with its Coin price over it.
local EggPedestals: { { egg: string, at: Vec } } = {
	{ egg = "egg_basic", at = { -58, 0.4, 0 } },
	{ egg = "egg_spotted", at = { -59.5, 0.4, -7 } },
	{ egg = "egg_cracked", at = { -59.5, 0.4, 7 } },
	{ egg = "egg_cat", at = { -63, 0.4, -12.5 } },
	{ egg = "egg_dog", at = { -63, 0.4, 12.5 } },
}

-- Interactive spots. Prompts only open a screen on the client (Play, Worlds, Shop, Quests,
-- Merchant); every action behind them goes through the normal server-checked remotes.
local Features: { [string]: Feature } = {
	arena = {
		at = { 0, 4, -60 },
		prompt = { name = "HubArena", action = "Enter", object = "1v1 Arena" },
		sign = { text = "1v1 ARENA", icon = "icon_play", height = 74, size = 56 },
	},
	portal = {
		at = { 75, 19.5, 0 },
		rotY = -90,
		prompt = { name = "HubPortal", action = "Travel", object = "Worlds" },
		sign = { text = "WORLDS", icon = "icon_worlds", height = 68, size = 44 },
	},
	egg_stall = {
		at = { -66, 3, 0 },
		prompt = { name = "HubShop", action = "Browse", object = "Egg Shop" },
		sign = { text = "EGGS", icon = "icon_shop", height = 48, size = 30 },
	},
	merchant = {
		at = { -46, 3, 54 },
		prompt = { name = "Sell", action = "Sell", object = "Lantern Trader" },
		sign = { text = "LANTERN TRADER", icon = "icon_coin", height = 14, size = 14 },
	},
	quests = {
		at = { 44, 3, 56 },
		prompt = { name = "HubQuests", action = "Open", object = "Quests" },
		sign = { text = "QUESTS", icon = "icon_quests", height = 12, size = 13 },
	},
	daily = {
		at = { 66, 3, 48 },
		prompt = { name = "HubDaily", action = "Claim", object = "Daily Reward" },
		sign = { text = "DAILY", icon = "icon_gift", height = 19, size = 12 },
	},
}

return table.freeze({
	ORIGIN = { -2400, 0, 0 } :: Vec, -- west of World 1 (worlds start at X = 0)
	SPAWN = { 0, 1.5, 96 } :: Vec, -- on top of the spawn shrine (LobbyDecor), facing north: the plaza, the arena gate and the portal
	MERCHANT = { -46, 1, 54 } :: Vec, -- the lobby merchant (the server's sell range check)
	PETALS = { area = { 220, 220 }, height = 46, rate = 22 },
	FIREFLIES = { at = { 0, 2, 72 }, area = { 200, 14 }, rate = 10 },
	PORTAL_CORE_RADIUS = 9.8,
	Models = table.freeze(Models),
	Pieces = table.freeze(Pieces),
	Prims = table.freeze(Prims),
	EggPedestals = table.freeze(EggPedestals),
	Features = table.freeze(Features),
	Ambient = LobbyDecor.Ambient,
})
