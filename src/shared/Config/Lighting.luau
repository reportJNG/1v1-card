--!strict
-- Lighting presets per area (docs/ART_STYLE.md section 6). The client applies the preset for
-- where its player is (hub, a farming world, a battle) and tweens between them. Technology is
-- Future, set in the Rojo project files (scripts can't change it). The hub sky is an original
-- skybox drawn by scripts/art/make_sky.py.

export type Preset = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: string,
	outdoorAmbient: string,
	envDiffuse: number,
	envSpecular: number,
	atmosphere: { density: number, offset: number, color: string, decay: string, glare: number, haze: number },
	bloom: { intensity: number, size: number, threshold: number },
	color: { brightness: number, contrast: number, saturation: number, tint: string },
	sunRays: { intensity: number, spread: number },
	sky: {
		ft: string,
		bk: string,
		lf: string,
		rt: string,
		up: string,
		dn: string,
		stars: number,
		moon: number?,
	}?,
}

local HUB_SKY = {
	ft = "rbxassetid://134018590902104",
	bk = "rbxassetid://93318322842132",
	lf = "rbxassetid://90147874879939",
	rt = "rbxassetid://90639169867213",
	up = "rbxassetid://102373425404745",
	dn = "rbxassetid://78110207209561",
	stars = 0,
	moon = 16, -- Roblox's built-in moon (no upload), angular size
}

local Presets: { [string]: Preset } = {
	hub = {
		clockTime = 20.5,
		brightness = 3,
		exposure = 0.35,
		ambient = "#3B2F6B",
		outdoorAmbient = "#6A55B0",
		envDiffuse = 0.5,
		envSpecular = 0.6,
		atmosphere = {
			density = 0.24,
			offset = 0.12,
			color = "#6E4BC4",
			decay = "#2A1450",
			glare = 0.3,
			haze = 1.2,
		},
		bloom = { intensity = 0.8, size = 28, threshold = 1.4 },
		color = { brightness = 0.04, contrast = 0.12, saturation = 0.18, tint = "#F2ECFF" },
		sunRays = { intensity = 0.06, spread = 0.6 },
		sky = HUB_SKY,
	},
	-- The main menu's own scene (Config/MenuStage): a starry purple night, the moon is a 3D disc in
	-- the scene, warm lantern light on the platform.
	menu = {
		clockTime = 0,
		brightness = 1.6,
		exposure = 0.45,
		ambient = "#3A2F6E",
		outdoorAmbient = "#5A48A8",
		envDiffuse = 0.5,
		envSpecular = 0.7,
		atmosphere = {
			density = 0.32,
			offset = 0.05,
			color = "#5A3C9E",
			decay = "#1E1046",
			glare = 0.2,
			haze = 1.6,
		},
		bloom = { intensity = 1.1, size = 30, threshold = 1.15 },
		color = { brightness = 0.03, contrast = 0.16, saturation = 0.22, tint = "#F4EEFF" },
		sunRays = { intensity = 0, spread = 0 },
		sky = {
			ft = HUB_SKY.ft,
			bk = HUB_SKY.bk,
			lf = HUB_SKY.lf,
			rt = HUB_SKY.rt,
			up = HUB_SKY.up,
			dn = HUB_SKY.dn,
			stars = 3000,
		},
	},
	arena = {
		clockTime = 20.5,
		brightness = 2,
		exposure = 0.4,
		ambient = "#3A2F66",
		outdoorAmbient = "#4A3C8A",
		envDiffuse = 0.4,
		envSpecular = 0.7,
		atmosphere = {
			density = 0.45,
			offset = 0.1,
			color = "#3A2470",
			decay = "#140A2E",
			glare = 0,
			haze = 2.2,
		},
		bloom = { intensity = 1.0, size = 32, threshold = 1.2 },
		color = { brightness = 0, contrast = 0.18, saturation = 0.22, tint = "#FFFFFF" },
		sunRays = { intensity = 0, spread = 0 },
		sky = HUB_SKY,
	},
}

-- One preset per farming world, "world<n>" (docs/ART_STYLE.md section 6: worlds 1-3 day-lit and
-- saturated, darker and more neon from world 5). Skies are drawn by scripts/art/make_sky.py
-- (world mode), ids in art/sky/ids.json.
local function sky(ft: string, bk: string, lf: string, rt: string, up: string, dn: string)
	return { ft = ft, bk = bk, lf = lf, rt = rt, up = up, dn = dn, stars = 0 }
end

local function world(
	clock: number,
	brightness: number,
	ambient: { string }, -- { Ambient, OutdoorAmbient }
	atmosphere: { any }, -- { density, color, decay, haze, glare }
	color: { any }, -- { contrast, saturation, tint, exposure }
	bloom: number,
	rays: number,
	worldSky: any
): Preset
	return {
		clockTime = clock,
		brightness = brightness,
		exposure = color[4] or 0,
		ambient = ambient[1],
		outdoorAmbient = ambient[2],
		envDiffuse = 0.7,
		envSpecular = 0.6,
		atmosphere = {
			density = atmosphere[1],
			offset = 0.2,
			color = atmosphere[2],
			decay = atmosphere[3],
			haze = atmosphere[4],
			glare = atmosphere[5],
		},
		bloom = { intensity = bloom, size = 26, threshold = 1.4 },
		color = { brightness = 0.02, contrast = color[1], saturation = color[2], tint = color[3] },
		sunRays = { intensity = rays, spread = 0.7 },
		sky = worldSky,
	}
end

Presets.world1 = world(
	14,
	2.6,
	{ "#5A6A7A", "#8A9AB0" },
	{ 0.24, "#CFE8FF", "#8FB8E0", 0.8, 0.3 },
	{ 0.1, 0.25, "#FFFDF4" },
	0.5,
	0.1,
	sky(
		"rbxassetid://98982950516711",
		"rbxassetid://105072157112572",
		"rbxassetid://110586097553669",
		"rbxassetid://73061165559884",
		"rbxassetid://134403471903442",
		"rbxassetid://97209244090774"
	)
)
Presets.world2 = world(
	17.6,
	2.2,
	{ "#4A3A7A", "#7A6AB0" },
	{ 0.28, "#B07CD8", "#3A2A6A", 0.9, 0.2 },
	{ 0.16, 0.32, "#F4ECFF" },
	0.8,
	0.06,
	sky(
		"rbxassetid://107888646817327",
		"rbxassetid://77801997105453",
		"rbxassetid://120289086887461",
		"rbxassetid://76773214706851",
		"rbxassetid://79734195900396",
		"rbxassetid://73953330993832"
	)
)
Presets.world3 = world(
	13,
	2.8,
	{ "#7A6A50", "#B09A78" },
	{ 0.22, "#FFE2B0", "#E0B070", 0.8, 0.4 },
	{ 0.14, 0.24, "#FFF6E6", -0.1 },
	0.5,
	0.14,
	sky(
		"rbxassetid://116112236117044",
		"rbxassetid://125579908830680",
		"rbxassetid://120602377739188",
		"rbxassetid://123567460047086",
		"rbxassetid://102794194574402",
		"rbxassetid://75326749418391"
	)
)
Presets.world4 = world(
	15.5,
	2.4,
	{ "#5A6A8A", "#9AB0D0" },
	{ 0.26, "#E6F4FF", "#9FC4E8", 0.9, 0.3 },
	{ 0.16, 0.18, "#F0F8FF", -0.15 },
	0.5,
	0.1,
	sky(
		"rbxassetid://109427756514765",
		"rbxassetid://103798396942406",
		"rbxassetid://127144889939950",
		"rbxassetid://86589748911840",
		"rbxassetid://133871028306445",
		"rbxassetid://107136009697026"
	)
)
Presets.world5 = world(
	17.8,
	2.4,
	{ "#8A4A30", "#B06A44" },
	{ 0.28, "#8A3A20", "#2A0E06", 1.0, 0.2 },
	{ 0.18, 0.15, "#FFF0E6" },
	0.9,
	0.12,
	sky(
		"rbxassetid://127226897556085",
		"rbxassetid://99035555445924",
		"rbxassetid://80498119072053",
		"rbxassetid://132577684591291",
		"rbxassetid://130145891354120",
		"rbxassetid://96862622063790"
	)
)
Presets.world6 = world(
	17.5,
	3,
	{ "#A05A7A", "#C07090" },
	{ 0.16, "#A04A6A", "#3A1020", 0.5, 0.2 },
	{ 0.2, 0.1, "#FFE6EE", 0.4 },
	0.9,
	0.04,
	sky(
		"rbxassetid://72719645584560",
		"rbxassetid://98903869532718",
		"rbxassetid://122647014153059",
		"rbxassetid://139172340701105",
		"rbxassetid://84411904654915",
		"rbxassetid://72155719328078"
	)
)
Presets.world7 = world(
	12,
	2.2,
	{ "#7A8AA8", "#B0C4E8" },
	{ 0.2, "#FFFFFF", "#CFE4FF", 0.6, 0.3 },
	{ 0.16, 0.25, "#FFFFF4", -0.3 },
	0.4,
	0.12,
	sky(
		"rbxassetid://102432478612923",
		"rbxassetid://110880250592206",
		"rbxassetid://114069738973229",
		"rbxassetid://136152770924675",
		"rbxassetid://139121252969793",
		"rbxassetid://117159923234760"
	)
)
Presets.world8 = world(
	16.8,
	2.4,
	{ "#6A5038", "#A88A60" },
	{ 0.22, "#FFC98A", "#B87A50", 0.8, 0.3 },
	{ 0.16, 0.26, "#FFF0DC" },
	0.6,
	0.16,
	sky(
		"rbxassetid://81428548952495",
		"rbxassetid://106472169213256",
		"rbxassetid://134095904172977",
		"rbxassetid://106605010623996",
		"rbxassetid://128326433407550",
		"rbxassetid://78486891048513"
	)
)
Presets.world9 = world(
	0,
	2.2,
	{ "#7A6AC0", "#8A7AD8" },
	{ 0.2, "#4A3A8A", "#0A0418", 0.7, 0.1 },
	{ 0.22, 0.3, "#EDE6FF", 0.45 },
	1.1,
	0,
	sky(
		"rbxassetid://130452168371962",
		"rbxassetid://123457209411585",
		"rbxassetid://132194691447164",
		"rbxassetid://73259108289480",
		"rbxassetid://121849505429113",
		"rbxassetid://115328538786740"
	)
)
Presets.world10 = world(
	13,
	2.6,
	{ "#8A7A60", "#D0C098" },
	{ 0.22, "#FFF0C8", "#E0C080", 0.7, 0.4 },
	{ 0.18, 0.22, "#FFFBEA", -0.3 },
	0.6,
	0.16,
	sky(
		"rbxassetid://112665634830239",
		"rbxassetid://117072080474088",
		"rbxassetid://84840356244799",
		"rbxassetid://122851940592421",
		"rbxassetid://112926565435479",
		"rbxassetid://132255223074190"
	)
)

-- One preset per battle arena (Config/Arenas, BAD_GUI_8 section 5): night and focused, with the
-- fighters lit by the stage's key lights. Skies reuse the hub's and the worlds' drawn skyboxes.
local function arena(
	clock: number,
	brightness: number,
	ambient: { string }, -- { Ambient, OutdoorAmbient }
	atmosphere: { any }, -- { density, color, decay, haze, glare }
	color: { any }, -- { contrast, saturation, tint, exposure, brightness }
	bloom: number,
	arenaSky: any
): Preset
	return {
		clockTime = clock,
		brightness = brightness,
		exposure = color[4] or 0,
		ambient = ambient[1],
		outdoorAmbient = ambient[2],
		envDiffuse = 0.45,
		envSpecular = 0.8,
		atmosphere = {
			density = atmosphere[1],
			offset = 0.1,
			color = atmosphere[2],
			decay = atmosphere[3],
			haze = atmosphere[4],
			glare = atmosphere[5],
		},
		bloom = { intensity = bloom, size = 30, threshold = 1.2 },
		color = { brightness = color[5] or 0, contrast = color[1], saturation = color[2], tint = color[3] },
		sunRays = { intensity = 0, spread = 0 },
		sky = arenaSky,
	}
end

-- purple night, warm lantern pools
Presets.arena_sakura = arena(
	20.5,
	2,
	{ "#3A2F66", "#4A3C8A" },
	{ 0.4, "#3A2470", "#140A2E", 2, 0 },
	{ 0.18, 0.22, "#FFF4FA", 0.4 },
	1,
	HUB_SKY
)
-- cold blue glacier night under the aurora
Presets.arena_frozen = arena(
	21,
	2.2,
	{ "#3E5A86", "#6A8CC0" },
	{ 0.3, "#9CC8F0", "#2A4A7A", 1.4, 0.2 },
	{ 0.16, 0.12, "#EAF6FF", 0.3 },
	0.9,
	Presets.world4.sky
)
-- red-orange underglow from the lava
Presets.arena_volcano = arena(
	19,
	1.8,
	{ "#5A2A20", "#8A3A24" },
	{ 0.42, "#8A3A20", "#2A0E06", 1.8, 0.2 },
	{ 0.2, 0.2, "#FFF0E2", 0.3 },
	1.1,
	Presets.world5.sky
)
-- golden sunset over the clouds
Presets.arena_celestial = arena(
	17.6,
	2.6,
	{ "#7A6A58", "#C0A27A" },
	{ 0.24, "#FFD9A0", "#C07A50", 1, 0.5 },
	{ 0.12, 0.2, "#FFF4E0", 0.1, 0.02 },
	0.8,
	Presets.world10.sky
)
-- dark blue storm night over the city
Presets.arena_storm = arena(
	0,
	1.6,
	{ "#2A3050", "#3A4470" },
	{ 0.36, "#2A3A6A", "#0A0E1E", 1.6, 0 },
	{ 0.2, 0.1, "#E6EEFF", 0.45 },
	1.1,
	Presets.world9.sky
)

return table.freeze(Presets)
