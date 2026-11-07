--!strict
-- Where a player goes back to after a battle (MISSION 2.4): the exact spot they stood on when the
-- battle started, in the same world. If that spot is no longer valid (the world is locked now, or
-- the spot is outside its play area), the world's spawn; if the world itself is not valid, the
-- lobby. Pure: the server passes the unlock check, and the lobby spawn.
local Shared = script.Parent.Parent
local WorldLayout = require(script.Parent.WorldLayout)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local Worlds = require(Shared.Config.Worlds)
local HubLayout = require(Shared.Config.HubLayout)

local ReturnSpot = {}

-- world 0 = the lobby. yaw in radians (the facing to restore).
export type Spot = { world: number, x: number, y: number, z: number, yaw: number }
export type Choice = { kind: "spot" | "worldSpawn" | "lobby", spot: Spot }

local Y_MIN, Y_MAX = -60, 400 -- above the fall-out line, below the sky
local LOBBY_HALF = 160 -- the lobby plaza's walkable half-size around its origin

local function finite(n: any): boolean
	return typeof(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- A well-formed spot (numbers, an integer world 0-10): teleport data is client-held, so it is
-- checked like any client value.
function ReturnSpot.isWellFormed(s: any): boolean
	return typeof(s) == "table"
		and finite(s.world)
		and s.world == math.floor(s.world)
		and (s.world == 0 or Worlds.ById[s.world] ~= nil)
		and finite(s.x)
		and finite(s.y)
		and finite(s.z)
		and finite(s.yaw)
end

-- Whether a point lies in the world's play area (or the lobby plaza for world 0).
function ReturnSpot.inBounds(s: Spot): boolean
	if s.y < Y_MIN or s.y > Y_MAX then
		return false
	end
	if s.world == 0 then
		local o = HubLayout.ORIGIN
		return math.abs(s.x - o[1]) <= LOBBY_HALF and math.abs(s.z - o[3]) <= LOBBY_HALF
	end
	local o = WorldLayout.origin(s.world)
	local half = WorldLayouts.WORLD_SIZE / 2 - 4
	return math.abs(s.x - o.x) <= half and math.abs(s.z - o.z) <= half
end

function ReturnSpot.lobby(): Spot
	local o, s = HubLayout.ORIGIN, HubLayout.SPAWN
	return { world = 0, x = o[1] + s[1], y = o[2] + s[2] + 3, z = o[3] + s[3], yaw = 0 }
end

function ReturnSpot.worldSpawn(world: number): Spot
	local p = WorldLayout.spawn(world)
	return { world = world, x = p.x, y = p.y, z = p.z, yaw = 0 }
end

-- The spot to restore. `isUnlocked(world)` is the player's current unlock state.
function ReturnSpot.choose(saved: any, isUnlocked: (number) -> boolean): Choice
	if not ReturnSpot.isWellFormed(saved) then
		return { kind = "lobby", spot = ReturnSpot.lobby() }
	end
	local s = saved :: Spot
	if s.world ~= 0 and not isUnlocked(s.world) then
		return { kind = "lobby", spot = ReturnSpot.lobby() }
	end
	if ReturnSpot.inBounds(s) then
		return { kind = "spot", spot = { world = s.world, x = s.x, y = s.y, z = s.z, yaw = s.yaw } }
	end
	if s.world == 0 then
		return { kind = "lobby", spot = ReturnSpot.lobby() }
	end
	return { kind = "worldSpawn", spot = ReturnSpot.worldSpawn(s.world) }
end

return table.freeze(ReturnSpot)
