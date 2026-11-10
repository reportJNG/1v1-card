--!strict
-- The arena maps as pure data (Config/Arenas): which map a match is fought in, the shared core
-- every map is built on, and the generated skyline. Both the server (which picks the map and
-- builds the templates) and the client (which builds its own copy of the stage) read positions
-- from here, so the core can never differ between maps. No Instances: positions are { x, y, z }
-- studs from the arena centre, platform top at y = 0.
local Config = script.Parent.Parent.Config
local Arenas = require(Config.Arenas)
local HubLayout = require(Config.HubLayout)
local WorldProps = require(Config.WorldProps)

local ArenaLayout = {}

ArenaLayout.PLATFORM = 40 -- platform diameter in studs
ArenaLayout.MARK = 11 -- studs from the centre to each fighter's pad
ArenaLayout.PAD = 7 -- light pad diameter
-- The wide camera (position, look-at) and the start of the intro sweep.
ArenaLayout.CAMERA = { at = { 0, 7.5, 27 }, look = { 0, 3.2, 0 } }
ArenaLayout.INTRO = { at = { 30, 16, -26 }, look = { 0, 3, 0 } }

-- The core parts every map has, by name (BAD_GUI_8 section 5: "ArenaCore").
ArenaLayout.CORE_NAMES = table.freeze({
	"Platform",
	"Rim",
	"Top",
	"InnerRing",
	"InnerTop",
	"PadA",
	"PadB",
	"SpawnA",
	"SpawnB",
	"CamHome",
	"CamIntro",
})

export type CorePart = {
	name: string,
	kind: "Cylinder" | "Point",
	at: { number },
	size: { number }?, -- Cylinder: { diameter, height }
	color: string?,
	material: string?,
	transparency: number?,
}

-- A deterministic number in [0, 2^31 - 1) from a match seed (Park-Miller steps: exact in doubles,
-- the same in every Luau runtime, unlike Random).
local function mix(seed: number): number
	local x = math.floor(math.abs(seed)) % 2147483646 + 1
	for _ = 1, 3 do
		x = (x * 48271) % 2147483647
	end
	return x
end

-- The map for a match: a weighted pick from the match seed, so both players (and a reconnect)
-- always get the same map.
function ArenaLayout.pick(seed: number): string
	local total = 0
	for _, a in Arenas.List do
		total += a.weight
	end
	local roll = (mix(seed) % 1_000_000) / 1_000_000 * total
	for _, a in Arenas.List do
		roll -= a.weight
		if roll < 0 then
			return a.id
		end
	end
	return Arenas.List[#Arenas.List].id
end

-- The shared core for one map, in its palette.
function ArenaLayout.core(arena: Arenas.Arena): { CorePart }
	local p = arena.platform
	local d = ArenaLayout.PLATFORM
	local m = ArenaLayout.MARK
	local cam, intro = ArenaLayout.CAMERA, ArenaLayout.INTRO
	return {
		{
			name = "Platform",
			kind = "Cylinder",
			at = { 0, -1, 0 },
			size = { d, 2 },
			color = p.color,
			material = p.material,
		},
		-- the glowing rim and the inner ring are thin neon discs, covered so they read as lines
		{
			name = "Rim",
			kind = "Cylinder",
			at = { 0, 0.01, 0 },
			size = { d + 0.8, 0.12 },
			color = p.rim,
			material = "Neon",
		},
		{
			name = "Top",
			kind = "Cylinder",
			at = { 0, 0.03, 0 },
			size = { d - 0.4, 0.14 },
			color = p.color,
			material = p.material,
		},
		{
			name = "InnerRing",
			kind = "Cylinder",
			at = { 0, 0.05, 0 },
			size = { 26, 0.12 },
			color = p.inner,
			material = "Neon",
			transparency = 0.2,
		},
		{
			name = "InnerTop",
			kind = "Cylinder",
			at = { 0, 0.07, 0 },
			size = { 25.4, 0.12 },
			color = p.color,
			material = p.material,
		},
		{
			name = "PadA",
			kind = "Cylinder",
			at = { -m, 0.12, 0 },
			size = { ArenaLayout.PAD, 0.16 },
			color = p.pad,
			material = "Neon",
			transparency = 0.15,
		},
		{
			name = "PadB",
			kind = "Cylinder",
			at = { m, 0.12, 0 },
			size = { ArenaLayout.PAD, 0.16 },
			color = p.pad,
			material = "Neon",
			transparency = 0.15,
		},
		{ name = "SpawnA", kind = "Point", at = { -m, 0, 0 } },
		{ name = "SpawnB", kind = "Point", at = { m, 0, 0 } },
		{ name = "CamHome", kind = "Point", at = cam.at },
		{ name = "CamIntro", kind = "Point", at = intro.at },
	}
end

-- A dressing piece's mesh definition (Config/HubLayout.Models or Config/WorldProps).
function ArenaLayout.modelDef(key: string): { mesh: string, texture: string, size: { number }, note: string }?
	return HubLayout.Models[key] or WorldProps.Models[key]
end

-- The map's simple shapes plus its generated skyline (towers far below, each with a glowing
-- window strip): deterministic, so every client builds the same city.
function ArenaLayout.prims(arena: Arenas.Arena): { Arenas.Prim }
	local out = table.clone(arena.prims)
	local city = arena.city
	if city then
		local x = 7
		local function nextUnit(): number
			x = (x * 48271) % 2147483647
			return x / 2147483647
		end
		for i = 1, city.count do
			-- spread around the back and the sides (the camera looks toward -Z)
			local angle = math.rad(-170 + (i - 1) / city.count * 160 + nextUnit() * 4)
			local r = city.radius[1] + nextUnit() * (city.radius[2] - city.radius[1])
			local h = city.height[1] + nextUnit() * (city.height[2] - city.height[1])
			local w = 10 + nextUnit() * 14
			local cx, cz = math.cos(angle) * r, math.sin(angle) * r
			table.insert(out, {
				shape = "Block",
				size = { w, h, w },
				at = { cx, city.y + h / 2, cz },
				color = "#3C4A7A",
				material = "Glass",
			})
			-- two thin lit window bands per tower, in one of the city's colours
			local glow = city.glow[(i - 1) % #city.glow + 1]
			for band = 1, 2 do
				table.insert(out, {
					shape = "Block",
					size = { w + 0.2, 0.45, w + 0.2 },
					at = { cx, city.y + h * (0.45 + band * 0.18 + nextUnit() * 0.08), cz },
					color = glow,
					material = "Neon",
					transparency = 0.2,
				})
			end
		end
	end
	return out
end

return table.freeze(ArenaLayout)
