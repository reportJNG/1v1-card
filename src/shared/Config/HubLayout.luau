--!strict
-- The hub plaza (docs/ART_STYLE.md section 6, the concept board's lobby): where players spawn,
-- with the 1v1 Arena, the Worlds portal and the egg stall. Built at runtime by
-- Server/World/HubBuilder from this data. Every model is an original mesh made with Roblox's
-- generate_mesh tool (docs/ASSETS.md), referenced by its uploaded mesh and texture ids; nothing
-- is stacked from primitives except the plaza floor slabs. Positions are studs from the hub
-- origin; models face +Z (toward the spawn) at rotY = 0.

export type Vec = { number } -- { x, y, z }

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

local function lantern(x: number, z: number): Piece
	return {
		model = "stone_lantern",
		at = { x, 0, z },
		scale = 1.5,
		light = { offset = { 0, 6.2, 0 }, color = WARM, range = 16, brightness = 1.6 },
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

local Pieces: { Piece } = {
	-- The approach: two torii over the path, lanterns on both sides.
	{ model = "torii", at = { 0, 0, 34 }, scale = 1.25 },
	{ model = "torii", at = { 0, 0, -6 }, scale = 0.95 },
	lantern(-13, 54),
	lantern(13, 54),
	lantern(-13, 14),
	lantern(13, 14),
	lantern(-13, -26),
	lantern(13, -26),
	post(-27, 42, 0),
	post(27, 42, 0),
	post(-27, 0, 0),
	post(27, 0, 0),
	-- The three destinations (concept board): the Arena left, the Worlds portal right, the
	-- egg stall by the entrance.
	{ model = "arena", at = { -50, 0, -54 }, rotY = 20, scale = 1.35 },
	{
		model = "portal",
		at = { 50, 0, -54 },
		rotY = -20,
		scale = 2.2,
		light = { offset = { 0, 16, 0 }, color = "#C77DFF", range = 42, brightness = 4 },
	},
	{ model = "egg_stall", at = { -36, 0, 22 }, rotY = 90, scale = 1.15 },
	-- Temple backdrop.
	{ model = "pagoda", at = { 0, 0, -122 }, scale = 1.45 },
	{ model = "pagoda", at = { -86, 0, -96 }, rotY = 25, scale = 1.1 },
	{ model = "pagoda", at = { 88, 0, -100 }, rotY = -25, scale = 0.95 },
	-- Cherry trees.
	{ model = "cherry_tree", at = { -30, 0, -24 }, rotY = 30, scale = 0.9 },
	{ model = "cherry_tree", at = { 30, 0, -26 }, rotY = 200, scale = 0.85 },
	{ model = "cherry_tree", at = { -76, 0, -12 }, rotY = 90, scale = 1.05 },
	{ model = "cherry_tree", at = { 78, 0, -8 }, rotY = 10, scale = 1.0 },
	{ model = "cherry_tree", at = { -62, 0, 70 }, rotY = 150, scale = 0.8 },
	{ model = "cherry_tree", at = { 64, 0, 66 }, rotY = 270, scale = 0.9 },
	{ model = "cherry_tree", at = { -96, 0, 30 }, rotY = 60, scale = 1.1 },
	{ model = "cherry_tree", at = { 98, 0, 34 }, rotY = 300, scale = 0.95 },
	-- Floating islands on the horizon.
	{ model = "sky_island", at = { -170, 60, -230 }, rotY = 40, scale = 2.5 },
	{ model = "sky_island", at = { 185, 85, -270 }, rotY = 200, scale = 3 },
	{ model = "sky_island", at = { 10, 120, -380 }, rotY = 110, scale = 3.5 },
	{ model = "sky_island", at = { -270, 35, -70 }, rotY = 300, scale = 2 },
	{ model = "sky_island", at = { 280, 50, -40 }, rotY = 15, scale = 2.2 },
}

-- Interactive spots. Prompts only open a screen on the client (Play, Worlds, Shop); every
-- action behind them goes through the normal server-checked remotes.
local Features: { [string]: Feature } = {
	arena = {
		at = { -44, 3, -34 },
		prompt = { name = "HubArena", action = "Enter", object = "1v1 Arena" },
		sign = { text = "1v1 ARENA", icon = "icon_play", height = 44, size = 30 },
	},
	portal = {
		at = { 50, 16, -54 },
		rotY = -20,
		prompt = { name = "HubPortal", action = "Travel", object = "Worlds" },
		sign = { text = "WORLDS", icon = "icon_worlds", height = 38, size = 24 },
	},
	egg_stall = {
		at = { -30, 3, 22 },
		prompt = { name = "HubShop", action = "Browse", object = "Egg Shop" },
		sign = { text = "EGG SHOP", icon = "icon_shop", height = 20, size = 14 },
	},
}

return table.freeze({
	ORIGIN = { -2400, 0, 0 } :: Vec, -- west of World 1 (worlds start at X = 0)
	SPAWN = { 0, 0.5, 74 } :: Vec,
	PLAZA = { size = { 190, 210 }, center = { 0, -10 }, path = { width = 18, from = 76, to = -70 } },
	PETALS = { area = { 220, 220 }, height = 46, rate = 22 },
	PORTAL_CORE_RADIUS = 9,
	Models = table.freeze(Models),
	Pieces = table.freeze(Pieces),
	Features = table.freeze(Features),
})
