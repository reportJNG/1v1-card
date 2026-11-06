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

-- Nodes are laid out on rings around the world centre: commons on the inner rings, the rare
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

return table.freeze(WorldLayout)
