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
	sky: { ft: string, bk: string, lf: string, rt: string, up: string, dn: string, stars: number }?,
}

local HUB_SKY = {
	ft = "rbxassetid://134018590902104",
	bk = "rbxassetid://93318322842132",
	lf = "rbxassetid://90147874879939",
	rt = "rbxassetid://90639169867213",
	up = "rbxassetid://102373425404745",
	dn = "rbxassetid://78110207209561",
	stars = 0,
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
	-- Farming worlds until each world gets its own block (docs/ART_STYLE.md: worlds 1-3 day-lit).
	world = {
		clockTime = 14,
		brightness = 2.4,
		exposure = 0,
		ambient = "#4A4A66",
		outdoorAmbient = "#7A7A9A",
		envDiffuse = 0.7,
		envSpecular = 0.6,
		atmosphere = {
			density = 0.28,
			offset = 0.2,
			color = "#C7D3FF",
			decay = "#6E7FB8",
			glare = 0.2,
			haze = 1.2,
		},
		bloom = { intensity = 0.5, size = 24, threshold = 1.6 },
		color = { brightness = 0.03, contrast = 0.1, saturation = 0.2, tint = "#FFFFFF" },
		sunRays = { intensity = 0.08, spread = 0.7 },
		sky = nil,
	},
}

return table.freeze(Presets)
