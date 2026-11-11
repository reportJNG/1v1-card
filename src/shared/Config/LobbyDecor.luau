--!strict
-- The lobby's second pass (FIX_LOBBY_2.md section B): the spawn shrine with its summoning circle
-- and lantern pillars, the tiled stone path with its koi stream, the giant double torii's red
-- carpet, the WORLDS temple gate with orbiting rune stones and its light pillar, the two-floor
-- egg pagoda with the giant golden egg, the fountain's pool and floating cards, a tiled plaza,
-- benches, planters, flower beds, low walls, and the shelf's edge (cliffs, waterfalls, mist).
-- Merged into Config/HubLayout (Pieces, Prims) and built by Server/World/HubBuilder like the rest.
-- Only simple shapes, the game's existing generated meshes and existing images: no new uploads.
-- Positions are studs from the hub origin; north is -Z; models face +Z at rotY = 0.
local Arenas = require(script.Parent.Arenas)

export type Vec = { number }
export type Prim = Arenas.Prim
export type Piece = {
	model: string,
	at: Vec,
	rotY: number?,
	scale: number?,
	light: { offset: Vec, color: string, range: number, brightness: number }?,
}

-- The landmark the next shapes belong to (one Atomic model each in the built lobby).
local group: string? = nil

local function p(
	shape: string,
	size: { number },
	at: Vec,
	color: string,
	material: string,
	extra: { [string]: any }?
): Prim
	local out: { [string]: any } =
		{ shape = shape, size = size, at = at, color = color, material = material, group = group }
	if extra then
		for k, v in extra do
			out[k] = v
		end
	end
	return out :: any
end

local Prims: { Prim } = {}
local Pieces: { Piece } = {}

local function add(list: { Prim })
	for _, prim in list do
		table.insert(Prims, prim)
	end
end

-- A small deterministic random stream (the same lobby on every server).
local seed = 20261110
local function rand(): number
	seed = (seed * 48271) % 2147483647
	return seed / 2147483647
end

-- (dx, dz) turned by yaw degrees around the Y axis.
local function turn(dx: number, dz: number, yaw: number): (number, number)
	local a = math.rad(yaw)
	return dx * math.cos(a) + dz * math.sin(a), -dx * math.sin(a) + dz * math.cos(a)
end

------------------------------------------------------------------------------------- generators

-- Square stone tiles over a rectangle, alternating two colours.
local function tiles(
	x0: number,
	x1: number,
	z0: number,
	z1: number,
	y: number,
	size: number,
	colors: { string }
)
	local nx = math.floor((x1 - x0) / size + 0.5)
	local nz = math.floor((z1 - z0) / size + 0.5)
	for i = 0, nx - 1 do
		for j = 0, nz - 1 do
			table.insert(
				Prims,
				p(
					"Block",
					{ size - 0.18, 0.05, size - 0.18 },
					{ x0 + (i + 0.5) * size, y, z0 + (j + 0.5) * size },
					colors[(i + j) % #colors + 1],
					"Slate"
				)
			)
		end
	end
end

-- Curved tiles in rings around a centre (the plaza), alternating colours.
local function ringTiles(
	cx: number,
	cz: number,
	r0: number,
	r1: number,
	width: number,
	y: number,
	colors: { string }
)
	local ring = 0
	local r = r0 + width / 2
	while r < r1 do
		local n = math.max(8, math.floor(2 * math.pi * r / width))
		local arc = 2 * math.pi * r / n
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * 360
			local dx, dz = turn(0, r, a)
			table.insert(
				Prims,
				p(
					"Block",
					{ arc - 0.2, 0.05, width - 0.2 },
					{ cx + dx, y, cz + dz },
					colors[(k + ring) % #colors + 1],
					"Slate",
					{ rot = { 0, a, 0 } }
				)
			)
		end
		ring += 1
		r += width
	end
end

-- A low stone wall with a cap from (x0, z0) to (x1, z1), in segments, skipping gaps.
local function wall(x0: number, z0: number, x1: number, z1: number, gaps: { { number } })
	local dx, dz = x1 - x0, z1 - z0
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.floor(len / 6)
	local yaw = math.deg(math.atan2(dx, dz))
	for k = 0, n - 1 do
		local t = (k + 0.5) / n
		local x, z = x0 + dx * t, z0 + dz * t
		local skip = false
		for _, g in gaps do
			if math.abs(x - g[1]) < g[3] and math.abs(z - g[2]) < g[3] then
				skip = true
			end
		end
		if not skip then
			table.insert(
				Prims,
				p(
					"Block",
					{ 1, 1.4, len / n - 0.3 },
					{ x, 0.7, z },
					"#4A4272",
					"Slate",
					{ rot = { 0, yaw, 0 }, collide = true }
				)
			)
			table.insert(
				Prims,
				p(
					"Block",
					{ 1.4, 0.3, len / n },
					{ x, 1.55, z },
					"#8E84BE",
					"Marble",
					{ rot = { 0, yaw, 0 } }
				)
			)
			if k % 4 == 0 then
				table.insert(
					Prims,
					p("Ball", { 0.8, 1, 0.8 }, { x, 2.2, z }, "#FF9A4A", "Neon", { transparency = 0.1 })
				)
			end
		end
	end
end

-- A bench facing `yaw` (the seat's front looks along +Z turned by yaw).
local function bench(x: number, z: number, yaw: number)
	type Board = { size: { number }, at: { number }, color: string, material: string }
	local boards: { Board } = {
		{ size = { 6, 0.4, 1.8 }, at = { 0, 1.4, 0 }, color = "#7A4A2E", material = "WoodPlanks" },
		{ size = { 6, 1.6, 0.3 }, at = { 0, 2.4, -0.9 }, color = "#7A4A2E", material = "WoodPlanks" },
		{ size = { 0.4, 1.2, 1.6 }, at = { -2.6, 0.75, 0 }, color = "#3A2A20", material = "Wood" },
		{ size = { 0.4, 1.2, 1.6 }, at = { 2.6, 0.75, 0 }, color = "#3A2A20", material = "Wood" },
	}
	for _, b in boards do
		local ox, oz = turn(b.at[1], b.at[3], yaw)
		table.insert(
			Prims,
			p(
				"Block",
				b.size,
				{ x + ox, b.at[2], z + oz },
				b.color,
				b.material,
				{ rot = { 0, yaw, 0 }, collide = true }
			)
		)
	end
end

local FLOWERS = { "#FF8CC6", "#FFFFFF", "#FFD86A", "#C59BFF", "#FF6A8A" }

-- A round flower bed on moss.
local function flowerBed(x: number, z: number, r: number, count: number)
	table.insert(Prims, p("Cylinder", { r * 2, 0.4 }, { x, 0.2, z }, "#3E6E44", "Grass"))
	for _ = 1, count do
		local a, d = rand() * 360, math.sqrt(rand()) * (r - 0.5)
		local dx, dz = turn(0, d, a)
		table.insert(
			Prims,
			p(
				"Ball",
				{ 0.7, 0.7, 0.7 },
				{ x + dx, 0.65, z + dz },
				FLOWERS[math.floor(rand() * #FLOWERS) + 1],
				"SmoothPlastic"
			)
		)
	end
end

-- A stone planter with flowers.
local function planter(x: number, z: number)
	table.insert(Prims, p("Cylinder", { 4, 1.6 }, { x, 0.8, z }, "#4A3F6E", "Brick", { collide = true }))
	table.insert(Prims, p("Cylinder", { 3.6, 0.2 }, { x, 1.65, z }, "#3E6E44", "Grass"))
	for k = 1, 6 do
		local dx, dz = turn(0, 1.1, k * 60)
		table.insert(
			Prims,
			p("Ball", { 0.7, 0.7, 0.7 }, { x + dx, 2, z + dz }, FLOWERS[k % #FLOWERS + 1], "SmoothPlastic")
		)
	end
end

-- A tall lantern pillar with three hanging paper lanterns; the top one lights the ground.
local function lanternPillar(x: number, z: number)
	add({
		p("Block", { 2.4, 1, 2.4 }, { x, 0.5, z }, "#4A4272", "Slate", { collide = true }),
		p("Cylinder", { 1.4, 14 }, { x, 7.5, z }, "#8A2A3A", "Wood", { collide = true }),
		p("Block", { 3.2, 0.6, 3.2 }, { x, 14.8, z }, "#FFC54B", "Metal"),
		p("Block", { 3.8, 0.4, 0.4 }, { x, 13.6, z }, "#3A2A20", "Wood"),
		p("Ball", { 1.4, 1.8, 1.4 }, { x - 1.6, 12.4, z }, "#FF6A4A", "Neon", {
			light = { color = "#FFB45A", range = 20, brightness = 1.7 },
		}),
		p("Ball", { 1.3, 1.6, 1.3 }, { x + 1.6, 12.5, z }, "#FF9A4A", "Neon"),
		p("Ball", { 1.1, 1.4, 1.1 }, { x, 10.6, z }, "#FF7A8A", "Neon"),
	})
end

-- A gable roof: two sloped slabs meeting at a ridge, running along X.
local function gable(
	cx: number,
	y: number,
	cz: number,
	length: number,
	depth: number,
	pitch: number,
	color: string
)
	local half = depth / 2
	local rise = math.tan(math.rad(pitch)) * half / 2
	for _, side in { -1, 1 } do
		table.insert(
			Prims,
			p(
				"Block",
				{ length, 0.8, half / math.cos(math.rad(pitch)) + 0.6 },
				{ cx, y + rise, cz + side * half / 2 },
				color,
				"Slate",
				{
					rot = { side * pitch, 0, 0 },
				}
			)
		)
	end
	table.insert(
		Prims,
		p("Block", { length + 0.4, 0.6, 1 }, { cx, y + rise * 2 + 0.3, cz }, "#FFC54B", "Metal")
	)
end

--------------------------------------------------------------------------- B1: the spawn shrine

local SX, SZ = 0, 96
group = "SpawnShrine"
add({
	-- three raised tiers with gold inlay rings
	p("Cylinder", { 28, 0.6 }, { SX, 0.3, SZ }, "#3E3568", "Slate", { collide = true, name = "SpawnShrine" }),
	p("Ring", { 28.4, 0.15, 48 }, { SX, 0.62, SZ }, "#FFC54B", "Metal"),
	p("Cylinder", { 24, 0.5 }, { SX, 0.85, SZ }, "#4A4078", "Slate", { collide = true }),
	p("Ring", { 24.2, 0.15, 44 }, { SX, 1.12, SZ }, "#FFC54B", "Metal"),
	p("Cylinder", { 20, 0.4 }, { SX, 1.3, SZ }, "#5B5088", "Marble", { collide = true }),
	p("Ring", { 20.3, 0.12, 40 }, { SX, 1.52, SZ }, "#CFC6E8", "Marble"),
	-- the glowing summoning circle: a pulsing disc, two turning rune rings and eight rune stones
	p("Cylinder", { 16, 0.05 }, { SX, 1.53, SZ }, "#8A4BFF", "Neon", { transparency = 0.86, tag = "Pulse" }),
	p("Ring", { 14, 0.1, 36 }, { SX, 1.56, SZ }, "#C77DFF", "Neon", { transparency = 0.2, tag = "Spin" }),
	p("Ring", { 9, 0.1, 28 }, { SX, 1.57, SZ }, "#FFC54B", "Neon", { transparency = 0.25, tag = "Spin" }),
})
for k = 0, 7 do
	local dx, dz = turn(0, 5.8, k * 45)
	table.insert(
		Prims,
		p(
			"Block",
			{ 0.8, 0.08, 1.6 },
			{ SX + dx, 1.57, SZ + dz },
			"#FFE08A",
			"Neon",
			{ rot = { 0, k * 45, 0 } }
		)
	)
end
lanternPillar(-11, 85)
lanternPillar(11, 85)
lanternPillar(-11, 107)
lanternPillar(11, 107)
group = nil

-------------------------------------------------------------- B1: the path, lanterns, koi stream

local PATH = { "#6E5FA6", "#5B4E8E" }
tiles(-7, 7, 36, 66, 0.33, 2, PATH)
tiles(-7, 7, 78, 82, 0.33, 2, PATH)
for _, z in { 40, 48, 56, 62 } do
	table.insert(Pieces, { model = "stone_lantern", at = { 10, 0, z }, scale = 1.1 })
	table.insert(Pieces, { model = "stone_lantern", at = { -15, 0, z }, scale = 1.1 })
end
-- cherry trees arching over the path and the shrine
for _, t in { { -17, 58, 40 }, { 17, 56, 220 }, { -34, 100, 140 }, { 34, 102, 300 } } do
	table.insert(Pieces, { model = "cherry_tree", at = { t[1], 0, t[2] }, rotY = t[3], scale = 0.8 })
end
-- the koi stream along the path's west side, flowing into the river
add({
	p("Block", { 3, 0.3, 28 }, { -10.5, 0.12, 52 }, "#2F6FBF", "Glass", { transparency = 0.25 }),
	p("Block", { 0.6, 0.6, 28 }, { -12.3, 0.3, 52 }, "#4A4270", "Cobblestone", { collide = true }),
	p("Block", { 0.6, 0.6, 28 }, { -8.7, 0.3, 52 }, "#4A4270", "Cobblestone", { collide = true }),
})
for k = 1, 5 do
	table.insert(
		Prims,
		p(
			"Block",
			{ 0.4, 0.2, 1 },
			{ -10.5 + (k % 2 - 0.5), 0.33, 40 + k * 4.5 },
			if k % 2 == 0 then "#FFFFFF" else "#FF8A3D",
			"Neon",
			{
				tag = "Koi",
				attrs = { z0 = 39, z1 = 65 },
			}
		)
	)
end

--------------------------------------------------------------- B2: the arena's grand stairway

add({
	p("Block", { 8, 0.06, 2.5 }, { 0, 0.53, -50.25 }, "#B8202E", "Fabric"),
	p("Block", { 8, 0.06, 2.5 }, { 0, 1.03, -52.75 }, "#B8202E", "Fabric"),
	p("Block", { 8, 0.06, 2.5 }, { 0, 1.53, -55.25 }, "#B8202E", "Fabric"),
	p("Block", { 8, 0.06, 30 }, { 0, 2.03, -71.5 }, "#B8202E", "Fabric"),
	p("Block", { 0.3, 0.08, 30 }, { -4.15, 2.05, -71.5 }, "#FFC54B", "Metal"),
	p("Block", { 0.3, 0.08, 30 }, { 4.15, 2.05, -71.5 }, "#FFC54B", "Metal"),
	-- gold motes drifting over the terrace
	p(
		"Block",
		{ 60, 1, 40 },
		{ 0, 4, -84 },
		"#FFFFFF",
		"SmoothPlastic",
		{ transparency = 1, tag = "GoldMotes" }
	),
})

---------------------------------------------- B2: the WORLDS temple gate, rune stones, light pillar

local GX = 79
group = "WorldsGate"
add({
	p("Block", { 5, 2, 5 }, { GX, 1, -19 }, "#4A4272", "Slate", { collide = true }),
	p("Block", { 5, 2, 5 }, { GX, 1, 19 }, "#4A4272", "Slate", { collide = true }),
	p("Block", { 3.5, 46, 3.5 }, { GX, 25, -19 }, "#8A2A3A", "Wood", { collide = true }),
	p("Block", { 3.5, 46, 3.5 }, { GX, 25, 19 }, "#8A2A3A", "Wood", { collide = true }),
	p("Block", { 5, 3, 48 }, { GX, 49.5, 0 }, "#8A2A3A", "Wood"),
	p("Block", { 5.2, 0.5, 48.2 }, { GX, 47.8, 0 }, "#FFC54B", "Metal"),
	p("Block", { 10, 1.4, 56 }, { GX, 51.7, 0 }, "#2E2440", "Slate"),
	p("Block", { 10, 1.2, 7 }, { GX, 52.6, -30 }, "#2E2440", "Slate", { rot = { -16, 0, 0 } }),
	p("Block", { 10, 1.2, 7 }, { GX, 52.6, 30 }, "#2E2440", "Slate", { rot = { 16, 0, 0 } }),
	-- the light pillar into the sky, visible from anywhere
	p("Cylinder", { 6, 900 }, { 86, 452, 0 }, "#C77DFF", "Neon", { transparency = 0.72, tag = "Pulse" }),
	p("Cylinder", { 2, 900 }, { 86, 452, 0 }, "#F1E2FF", "Neon", { transparency = 0.45 }),
})
for k = 0, 7 do
	local a = math.rad(k * 45)
	table.insert(
		Prims,
		p("Block", { 0.8, 2.6, 1.6 }, { 72, 22 + math.sin(a) * 19, math.cos(a) * 19 }, "#6A2CE0", "Neon", {
			transparency = 0.25,
			tag = "Orbit",
			attrs = { axis = "X", cx = 72, cy = 22, cz = 0, speed = 0.25 },
		})
	)
end

---------------------------------------------- B2: the two-floor egg pagoda and the golden egg

group = nil

local EX = -70
group = "EggPagoda"
for _, c in { { -54, -17 }, { -54, 17 }, { -84, -17 }, { -84, 17 } } do
	table.insert(
		Prims,
		p("Cylinder", { 1.6, 12 }, { c[1], 6.4, c[2] }, "#8A2A3A", "Wood", { collide = true })
	)
end
gable(EX, 12.6, 0, 36, 40, 22, "#7A2236")
add({
	p("Block", { 36.2, 0.3, 0.3 }, { EX, 12.3, -19.8 }, "#FFC54B", "Neon"),
	p("Block", { 36.2, 0.3, 0.3 }, { EX, 12.3, 19.8 }, "#FFC54B", "Neon"),
	-- the upper floor with lit windows facing the plaza
	p("Block", { 20, 7, 20 }, { EX - 2, 21.6, 0 }, "#5A2A3A", "WoodPlanks"),
	p("Block", { 0.2, 2.6, 3 }, { EX + 8.1, 21.6, -6 }, "#FFC27A", "Neon"),
	p("Block", { 0.2, 2.6, 3 }, { EX + 8.1, 21.6, -2 }, "#FFC27A", "Neon"),
	p("Block", { 0.2, 2.6, 3 }, { EX + 8.1, 21.6, 2 }, "#FFC27A", "Neon"),
	p("Block", { 0.2, 2.6, 3 }, { EX + 8.1, 21.6, 6 }, "#FFC27A", "Neon"),
})
gable(EX - 2, 25.2, 0, 24, 26, 26, "#7A2236")
add({
	-- the giant golden egg on the roof
	p("Cylinder", { 5, 1 }, { EX - 2, 31.5, 0 }, "#FFC54B", "Metal"),
	p("Ball", { 8, 11, 8 }, { EX - 2, 37.5, 0 }, "#FFC54B", "Foil", {
		name = "GoldenEgg",
		tag = "Bob",
		light = { color = "#FFD27A", range = 30, brightness = 2.4 },
	}),
	-- paper lanterns under the eaves
	p("Ball", { 1.3, 1.6, 1.3 }, { -58, 10.4, 18.6 }, "#FF6A4A", "Neon", {
		light = { color = "#FFB45A", range = 16, brightness = 1.4 },
	}),
	p("Ball", { 1.3, 1.6, 1.3 }, { -70, 10.4, 18.6 }, "#FF9A4A", "Neon"),
	p("Ball", { 1.3, 1.6, 1.3 }, { -82, 10.4, 18.6 }, "#FF6A4A", "Neon"),
	p("Ball", { 1.3, 1.6, 1.3 }, { -58, 10.4, -18.6 }, "#FF9A4A", "Neon", {
		light = { color = "#FFB45A", range = 16, brightness = 1.4 },
	}),
	p("Ball", { 1.3, 1.6, 1.3 }, { -70, 10.4, -18.6 }, "#FF6A4A", "Neon"),
	p("Ball", { 1.3, 1.6, 1.3 }, { -82, 10.4, -18.6 }, "#FF9A4A", "Neon"),
})
group = nil

------------------------------------------------- B2: the plaza (pool, floating cards, tiles, seats)

add({
	p(
		"Cylinder",
		{ 26, 0.5 },
		{ 0, 0.5, 0 },
		"#2C5FA8",
		"Glass",
		{ transparency = 0.4, name = "FountainPool" }
	),
	p("Ring", { 26.4, 0.7, 48 }, { 0, 0.55, 0 }, "#D8D0F0", "Marble"),
	-- water jets around the basin (Server/World/HubBuilder adds the spray)
	p(
		"Block",
		{ 0.5, 0.5, 0.5 },
		{ 0, 1.9, 7.5 },
		"#FFFFFF",
		"SmoothPlastic",
		{ transparency = 1, tag = "Jet" }
	),
	p(
		"Block",
		{ 0.5, 0.5, 0.5 },
		{ 7.5, 1.9, 0 },
		"#FFFFFF",
		"SmoothPlastic",
		{ transparency = 1, tag = "Jet" }
	),
	p(
		"Block",
		{ 0.5, 0.5, 0.5 },
		{ 0, 1.9, -7.5 },
		"#FFFFFF",
		"SmoothPlastic",
		{ transparency = 1, tag = "Jet" }
	),
	p(
		"Block",
		{ 0.5, 0.5, 0.5 },
		{ -7.5, 1.9, 0 },
		"#FFFFFF",
		"SmoothPlastic",
		{ transparency = 1, tag = "Jet" }
	),
})
for k = 0, 2 do
	local a = k * 120
	local dx, dz = turn(0, 9, a)
	table.insert(
		Prims,
		p("Block", { 3.6, 5, 0.3 }, { dx, 13, dz }, "#FFC54B", "Foil", {
			image = "card_back",
			transparency = 0,
			rot = { 0, a, 0 },
			tag = "Orbit",
			attrs = { axis = "Y", cx = 0, cy = 13, cz = 0, speed = 0.18, bob = 1 },
		})
	)
end
ringTiles(0, 0, 13.5, 35, 3.6, 0.38, { "#665A96", "#54497E", "#5E5290" })
tiles(36, 54, -6, 6, 0.33, 2, PATH)
tiles(-54, -36, -6, 6, 0.33, 2, PATH)
tiles(-8, 8, -49, -35, 0.33, 2, PATH)
for _, a in { 45, 135, 225, 315 } do
	local dx, dz = turn(0, 32, a)
	bench(dx, dz, a + 180)
end
for _, a in { 45, 135, 225, 315 } do
	local dx, dz = turn(0, 47, a)
	planter(dx, dz)
end
for _, a in { 30, 60, 120, 150, 210, 240, 300, 330 } do
	local dx, dz = turn(0, 46, a)
	flowerBed(dx, dz, 3, 11)
end
-- flower beds by the shrine and moss along the walls
flowerBed(-26, 96, 4, 14)
flowerBed(26, 96, 4, 14)
for _, m in { { -100, -100 }, { 100, -102 }, { -104, 60 }, { 104, 64 }, { -60, -118 }, { 62, 104 } } do
	table.insert(Prims, p("Cylinder", { 5, 0.1 }, { m[1], 0.2, m[2] }, "#4E8A3A", "Grass"))
end

------------------------------------------- B3: patterned ground (terrace, border, shrine surround)

-- the arena terrace: big carved slabs on either side of the carpet
tiles(-40, -4, -136, -57, 2.03, 4, { "#5A4E8C", "#4E4380" })
tiles(4, 40, -136, -57, 2.03, 4, { "#5A4E8C", "#4E4380" })
-- a tiled border band inside the courtyard walls
tiles(-116, 116, 104, 110, 0.18, 3, { "#57497F", "#4B3F73" })
tiles(-116, -110, -122, 104, 0.18, 3, { "#57497F", "#4B3F73" })
tiles(110, 116, -122, 104, 0.18, 3, { "#57497F", "#4B3F73" })
-- cobbles around the spawn shrine
ringTiles(SX, SZ, 14.2, 19.4, 2.6, 0.2, { "#6A5C9C", "#5A4E8A" })
-- planks across the bridge
for k = 0, 11 do
	table.insert(
		Prims,
		p(
			"Block",
			{ 13.6, 0.12, 0.9 },
			{ 0, 0.96, 66.5 + k },
			if k % 2 == 0 then "#8A5A3A" else "#7A4A2E",
			"WoodPlanks"
		)
	)
end
-- clipped bushes along the inside of the walls
for k = 0, 36 do
	local t = -112 + k * 6.2
	if math.abs(t) > 24 then
		table.insert(
			Prims,
			p(
				"Ball",
				{ 3.4, 2.6, 3.4 },
				{ t, 1.1, 106.5 },
				if k % 2 == 0 then "#2F5A3A" else "#386842",
				"Grass"
			)
		)
	end
	if t < 100 and (t < -98 or t > -60) then
		table.insert(
			Prims,
			p(
				"Ball",
				{ 3.4, 2.6, 3.4 },
				{ -112.5, 1.1, t },
				if k % 2 == 0 then "#386842" else "#2F5A3A",
				"Grass"
			)
		)
		table.insert(
			Prims,
			p(
				"Ball",
				{ 3.4, 2.6, 3.4 },
				{ 112.5, 1.1, t },
				if k % 2 == 0 then "#2F5A3A" else "#386842",
				"Grass"
			)
		)
	end
end

--------------------------------------------------------- B3: low walls around the courtyard

wall(-118, 112, 118, 112, { { 0, 112, 20 } })
wall(-118, -124, 118, -124, { { 0, -124, 44 } })
wall(-118, -124, -118, 112, {})
wall(118, -124, 118, 112, {})

------------------------------------------------- B3: the shelf's edge: cliffs, waterfalls, mist

local EDGE = 210
for k = 0, 39 do
	local side = k % 4
	local t = (math.floor(k / 4) + rand() * 0.6) / 10 * 2 - 1
	local x = if side == 0 then -EDGE elseif side == 1 then EDGE else t * EDGE
	local z = if side == 2 then -EDGE elseif side == 3 then EDGE else t * EDGE
	local s = 24 + rand() * 26
	table.insert(Prims, p("Ball", { s, s * 0.8, s }, { x, -s * 0.25, z - 10 }, "#2A2244", "Slate"))
end
for _, m in { { -110, -110 }, { 110, -110 }, { -110, 100 }, { 110, 100 } } do
	table.insert(Prims, p("Ball", { 300, 120, 300 }, { m[1], -75, m[2] }, "#1E1838", "Slate"))
end
for _, side in { -1, 1 } do
	add({
		p("Block", { 1.2, 160, 10 }, { side * (EDGE + 0.6), -80, 72 }, "#9FD8FF", "Neon", {
			transparency = 0.45,
			name = "Waterfall",
		}),
		p(
			"Block",
			{ 4, 1, 12 },
			{ side * (EDGE - 1), 0.4, 72 },
			"#FFFFFF",
			"SmoothPlastic",
			{ transparency = 1, tag = "Mist" }
		),
	})
end
for _, m in { { -40, -160, -60 }, { 180, -170, -200 }, { -200, -160, 140 } } do
	table.insert(
		Prims,
		p("Ball", { 320, 40, 220 }, { m[1], m[2], m[3] }, "#4A3C8A", "SmoothPlastic", { transparency = 0.55 })
	)
end
-- invisible walls inside the edge (the fall-out rescue stays as a backup)
for _, w in { { 0, -172, 360, 1 }, { 0, 172, 360, 1 }, { -172, 0, 1, 360 }, { 172, 0, 1, 360 } } do
	table.insert(
		Prims,
		p(
			"Block",
			{ w[3], 40, w[4] },
			{ w[1], 20, w[2] },
			"#FFFFFF",
			"SmoothPlastic",
			{ transparency = 1, collide = true }
		)
	)
end
-- grass tufts outside the courtyard
for _ = 1, 700 do
	local x, z = (rand() * 2 - 1) * 168, (rand() * 2 - 1) * 168
	if math.abs(x) > 122 or z > 116 or z < -128 then
		local s = 0.8 + rand() * 0.9
		table.insert(
			Prims,
			p(
				"Ball",
				{ s * 1.6, s, s * 1.6 },
				{ x, 0.1, z },
				if rand() > 0.5 then "#3A5E3E" else "#46704A",
				"Grass"
			)
		)
	end
end

-- Ambient sound zones (Config/Sounds slots), played by the client near each spot.
local Ambient: { { sound: string, at: Vec, range: number } } = {
	{ sound = "ambient_fountain", at = { 0, 3, 0 }, range = 60 },
	{ sound = "ambient_waterfall", at = { -EDGE, 2, 72 }, range = 110 },
	{ sound = "ambient_waterfall", at = { EDGE, 2, 72 }, range = 110 },
	{ sound = "ambient_chimes", at = { 0, 6, 96 }, range = 50 },
	{ sound = "ambient_wind", at = { 0, 10, -160 }, range = 120 },
	{ sound = "ambient_wind", at = { -160, 10, 0 }, range = 120 },
	{ sound = "ambient_wind", at = { 160, 10, 0 }, range = 120 },
}

return table.freeze({
	Pieces = table.freeze(Pieces),
	Prims = table.freeze(Prims),
	Ambient = table.freeze(Ambient),
})
