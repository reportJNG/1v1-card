--!strict
-- The main menu's own scene (FIX_LOBBY_2.md section A): a small cinematic set built only for the
-- menu camera, far from the lobby, the worlds and the battle arenas, so the menu never shows the
-- lobby and the lobby never shows it. Each client builds its own copy while the menu is open
-- (App/MenuScene) from the server's template (Server/World/ArenaBuilder.buildMenuStage, which adds
-- the meshes). Positions are studs from the stage centre (platform top at y = 0); the camera looks
-- toward -Z. Meshes are the game's existing generated ones (Config/HubLayout.Models,
-- Config/WorldProps): no new uploads.
local Arenas = require(script.Parent.Arenas)

export type Vec = { number }

export type Piece = {
	model: string, -- a Config/HubLayout.Models or Config/WorldProps key
	at: Vec,
	rotY: number?,
	scale: number?,
	light: { color: string, range: number, brightness: number, height: number }?,
}

local WARM = "#FFB45A"

local function p(
	shape: string,
	size: { number },
	at: Vec,
	color: string,
	material: string,
	extra: { [string]: any }?
): Arenas.Prim
	local out: { [string]: any } = { shape = shape, size = size, at = at, color = color, material = material }
	if extra then
		for k, v in extra do
			out[k] = v
		end
	end
	return out :: any
end

local Pieces: { Piece } = {
	-- cherry trees at the platform's back edge and two stone lanterns at its front
	{ model = "cherry_tree", at = { -15, 0, -12 }, rotY = 40, scale = 0.8 },
	{ model = "cherry_tree", at = { 17, 0, -14 }, rotY = 220, scale = 0.72 },
	{ model = "cherry_tree", at = { 32, -1, -18 }, rotY = 120, scale = 0.6 },
	{
		model = "stone_lantern",
		at = { -14, 0, -2 },
		scale = 1.3,
		light = { color = WARM, range = 16, brightness = 1.8, height = 5.4 },
	},
	{
		model = "stone_lantern",
		at = { 24, 0, -8 },
		scale = 1.3,
		light = { color = WARM, range = 16, brightness = 1.8, height = 5.4 },
	},
	-- floating islands in the distance
	{ model = "sky_island", at = { -70, 10, -120 }, rotY = 60, scale = 2.2 },
	{ model = "sky_island", at = { 80, 30, -170 }, rotY = 200, scale = 2.8 },
	{ model = "sky_island", at = { -150, 40, -260 }, rotY = 10, scale = 3.2 },
	{ model = "sky_island", at = { 160, -10, -110 }, rotY = 300, scale = 1.8 },
	{ model = "sky_island", at = { 20, 60, -330 }, rotY = 130, scale = 3.6 },
}

local Prims: { Arenas.Prim } = {
	-- the cliff the platform stands on, falling away into the void
	p("Cylinder", { 46, 70 }, { 3, -35.6, -4 }, "#1E1838", "Slate"),
	p("Ball", { 40, 30, 40 }, { -14, -48, 4 }, "#241C40", "Slate"),
	p("Ball", { 34, 28, 34 }, { 20, -56, -12 }, "#1A1430", "Slate"),
	-- the glowing stone platform with carved rings
	p("Cylinder", { 44, 1.2 }, { 3, -0.6, -4 }, "#3A3166", "Cobblestone"),
	p("Ring", { 44.4, 0.8, 56 }, { 3, -0.3, -4 }, "#8E84BE", "Marble"),
	p("Ring", { 36, 0.12, 48 }, { 3, 0.08, -4 }, "#A469FF", "Neon", { transparency = 0.35, tag = "Spin" }),
	p("Ring", { 26, 0.12, 40 }, { 3, 0.1, -4 }, "#FFC54B", "Neon", { transparency = 0.45, tag = "Spin" }),
	-- the light pool where the hero stands (the avatar is drawn over the scene by MainMenu)
	p("Cylinder", { 6.5, 0.1 }, { 10, 0.12, 14 }, "#FFD9A8", "Neon", { transparency = 0.78 }),
	p("Ball", { 0.5, 0.5, 0.5 }, { 10, 12, 18 }, "#FFE6C2", "Neon", {
		transparency = 1,
		light = { color = "#FFE0BC", range = 22, brightness = 2.6 },
	}),
	-- the moon, far behind
	p("Ball", { 190, 190, 190 }, { -260, 330, -1400 }, "#F4ECFF", "Neon", {
		transparency = 0.05,
		name = "Moon",
	}),
	-- mist banks below the cliff
	p("Ball", { 260, 30, 160 }, { -40, -70, -140 }, "#4A3C8A", "SmoothPlastic", { transparency = 0.55 }),
	p("Ball", { 300, 34, 180 }, { 120, -80, -220 }, "#3A2E70", "SmoothPlastic", { transparency = 0.55 }),
}

return table.freeze({
	-- Far below the battle arenas' and the worlds' X/Z range and far from the lobby
	-- (HubLayout.ORIGIN -2400, 0, 0): nothing of the lobby is in view from here, or the reverse.
	ORIGIN = { 0, 3000, -20000 } :: Vec,
	-- The menu shot: low over the platform, the hero (drawn by MainMenu, centre-right) standing in
	-- the light pool, looking out past the trees to the islands and the moon.
	CAMERA = { at = { 6, 3.8, 24 }, look = { 1, 4.6, -20 } },
	SWAY = 0.35, -- studs of slow drift
	Pieces = table.freeze(Pieces),
	Prims = table.freeze(Prims),
	Particles = table.freeze({
		{ texture = "petal", colors = { "#FFD6EC", "#FFB3D9" }, rate = 10, direction = "fall", size = 0.55 },
		{ texture = "sparkle", colors = { "#FFF1B8", "#C9B6FF" }, rate = 8, direction = "drift", size = 0.4 },
	} :: { Arenas.Particles }),
})
