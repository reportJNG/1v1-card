--!strict
-- Positions of everything in a world, computed from Config/WorldLayouts. Pure (plain {x, y, z}
-- tables, no Instances), so the builder that places the parts and the server that range-checks a
-- harvest use the same numbers.
local Config = script.Parent.Parent.Config
local WorldLayouts = require(Config.WorldLayouts)

export type Point = { x: number, y: number, z: number }

export type Node = {
	id: string, -- "w<world>_<itemId>_<n>", stable
	world: number,
	resource: WorldLayouts.Resource,
	position: Point,
}

local WorldLayout = {}

function WorldLayout.origin(world: number): Point
	return { x = (world - 1) * WorldLayouts.WORLD_SPACING, y = 0, z = 0 }
end

function WorldLayout.spawn(world: number): Point
	local o = WorldLayout.origin(world)
	return { x = o.x, y = 4, z = o.z + 130 }
end

function WorldLayout.merchant(world: number): Point
	local o = WorldLayout.origin(world)
	return { x = o.x - 40, y = 1, z = o.z + 100 }
end

function WorldLayout.guardian(world: number): Point
	local o = WorldLayout.origin(world)
	return { x = o.x + 40, y = 1, z = o.z + 100 }
end

-- The Back to Lobby portal, just behind the spawn.
function WorldLayout.lobbyPortal(world: number): Point
	local o = WorldLayout.origin(world)
	return { x = o.x, y = 0, z = o.z + 158 }
end

-- The middle of the farm field (node rings, and the pond / lake / lava pool feature).
function WorldLayout.fieldCentre(world: number): Point
	local o = WorldLayout.origin(world)
	return { x = o.x, y = 0, z = o.z - 60 }
end

-- Nodes are laid out on rings around the field centre: commons on the inner rings, the rare
-- resource on the outer edge, so it takes a walk.
local cache: { [number]: { Node } } = {}

function WorldLayout.nodes(world: number): { Node }
	local cached = cache[world]
	if cached then
		return cached
	end
	local def = WorldLayouts.ByWorld[world]
	local out: { Node } = {}
	if def == nil then
		return out
	end
	local o = WorldLayout.origin(world)
	for r, resource in def.resources do
		local radius = 40 + (r - 1) * 40
		for n = 1, resource.nodes do
			local angle = (n - 1) / resource.nodes * 2 * math.pi + r * 0.6
			table.insert(out, {
				id = `w{world}_{resource.itemId}_{n}`,
				world = world,
				resource = resource,
				position = {
					x = o.x + math.round(math.cos(angle) * radius),
					y = 2,
					z = o.z - 60 + math.round(math.sin(angle) * radius),
				},
			})
		end
	end
	cache[world] = out
	return out
end

local byId: { [string]: Node }? = nil

function WorldLayout.node(id: string): Node?
	if byId == nil then
		local map: { [string]: Node } = {}
		for _, def in WorldLayouts.List do
			for _, node in WorldLayout.nodes(def.world) do
				map[node.id] = node
			end
		end
		byId = map
	end
	return (byId :: { [string]: Node })[id]
end

function WorldLayout.distance(a: Point, b: Point): number
	local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function flat(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

export type Placement = { model: string, position: Point, rotY: number, scale: number }

-- Clearances (studs, on the ground plane) that decor keeps from what players walk to.
WorldLayout.CLEAR_NODE = 10
WorldLayout.CLEAR_SPOT = 20 -- spawn, merchant, Guardian, lobby portal

-- Scenery positions for a world, from its decor list (Config/WorldLayouts): "edge" props on the
-- outer ring inside the walls, "field" props between the node rings. Deterministic per world (a
-- seeded LCG), so every server builds the same map, and kept clear of nodes, NPCs, the spawn,
-- the lobby portal, the path and the field's centre feature.
local decorCache: { [number]: { Placement } } = {}

function WorldLayout.decor(world: number): { Placement }
	local cached = decorCache[world]
	if cached then
		return cached
	end
	local def = WorldLayouts.ByWorld[world]
	local out: { Placement } = {}
	if def == nil then
		return out
	end
	local seed = world * 7919 + 17
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local o = WorldLayout.origin(world)
	local centre = WorldLayout.fieldCentre(world)
	local spots = {
		WorldLayout.spawn(world),
		WorldLayout.merchant(world),
		WorldLayout.guardian(world),
		WorldLayout.lobbyPortal(world),
	}
	local feature = def.theme.terrain.centre
	local half = WorldLayouts.WORLD_SIZE / 2
	local function clear(p: Point, radius: number): boolean
		for _, node in WorldLayout.nodes(world) do
			if flat(p, node.position) < WorldLayout.CLEAR_NODE + radius then
				return false
			end
		end
		for _, s in spots do
			if flat(p, s) < WorldLayout.CLEAR_SPOT + radius then
				return false
			end
		end
		if feature and flat(p, centre) < feature.radius + 6 + radius then
			return false
		end
		if math.abs(p.x - o.x) < 12 + radius and p.z > centre.z then -- the path to the field
			return false
		end
		for _, other in out do
			if flat(p, other.position) < 8 + radius then
				return false
			end
		end
		return true
	end
	for _, d in def.theme.decor do
		local placed, tries = 0, 0
		while placed < d.count and tries < d.count * 60 do
			tries += 1
			local angle = rand() * 2 * math.pi
			local scale = d.scale[1] + (d.scale[2] - d.scale[1]) * rand()
			local p: Point
			if d.zone == "edge" then
				local r = half - 36 + rand() * 18
				p = { x = o.x + math.cos(angle) * r, y = 0, z = o.z + math.sin(angle) * r }
			else
				local r = 20 + rand() * 120
				p = { x = centre.x + math.cos(angle) * r, y = 0, z = centre.z + math.sin(angle) * r }
			end
			local radius = if d.zone == "edge" then 4 else 3
			local inside = math.abs(p.x - o.x) < half - 8 and math.abs(p.z - o.z) < half - 8
			if inside and clear(p, radius) then
				p.x, p.z = math.round(p.x * 10) / 10, math.round(p.z * 10) / 10
				table.insert(
					out,
					{ model = d.model, position = p, rotY = math.floor(rand() * 360), scale = scale }
				)
				placed += 1
			end
		end
	end
	decorCache[world] = out
	return out
end

return table.freeze(WorldLayout)
