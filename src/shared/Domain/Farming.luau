--!strict
-- Harvesting a resource node (design doc "Farming"). Pure: the server passes where the player's
-- character actually is, when this player last harvested the node, the clock and an RNG.
-- Checks: the node exists, the player is in that world (and it is unlocked), within range,
-- the node has respawned for this player, and the inventory has room.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local WorldLayouts = require(Config.WorldLayouts)
local Result = require(script.Parent.Result)
local Inventory = require(script.Parent.Inventory)
local Progress = require(script.Parent.Progress)
local WorldLayout = require(script.Parent.WorldLayout)

export type Rng = {
	NextInteger: (self: any, min: number, max: number) -> number,
	NextNumber: (self: any) -> number,
}

export type Context = {
	playerPosition: WorldLayout.Point?, -- nil when the character isn't spawned
	lastHarvest: number?, -- when this player last harvested this node
	now: number,
	rng: Rng,
}

export type Harvest = {
	nodeId: string,
	itemId: string,
	count: number,
	rareItemId: string?,
	rareCount: number,
	readyAt: number,
}

local Farming = {}

function Farming.harvest(profile: Types.PlayerProfile, nodeId: string, ctx: Context): Types.Result<Harvest>
	local node = WorldLayout.node(nodeId)
	if node == nil then
		return Result.fail("UnknownNode")
	end
	if profile.currentWorld ~= node.world or not Progress.isWorldUnlocked(profile, node.world) then
		return Result.fail("WrongWorld")
	end
	local pos = ctx.playerPosition
	if pos == nil or WorldLayout.distance(pos, node.position) > WorldLayouts.HARVEST_RANGE then
		return Result.fail("TooFar")
	end
	local resource = node.resource
	if ctx.lastHarvest ~= nil and ctx.now - ctx.lastHarvest < resource.respawnSeconds then
		return Result.fail("NotReady")
	end
	if Inventory.spaceFor(profile, resource.itemId) < 1 then
		return Result.fail("InventoryFull")
	end

	local count = ctx.rng:NextInteger(resource.yield[1], resource.yield[2])
	local added = Inventory.add(profile, resource.itemId, count)
	assert(added.ok, "space was checked")
	local rareCount = 0
	local rareId = resource.rareItemId
	if rareId and ctx.rng:NextNumber() < (resource.rareChance or 0) then
		local rare = Inventory.add(profile, rareId, 1)
		if rare.ok then
			rareCount = rare.value.added
		end
	end
	return Result.ok({
		nodeId = nodeId,
		itemId = resource.itemId,
		count = added.value.added,
		rareItemId = if rareCount > 0 then rareId else nil,
		rareCount = rareCount,
		readyAt = ctx.now + resource.respawnSeconds,
	})
end

-- Is the player close enough to their current world's merchant to trade?
function Farming.nearMerchant(profile: Types.PlayerProfile, position: WorldLayout.Point?): boolean
	if position == nil then
		return false
	end
	return WorldLayout.distance(position, WorldLayout.merchant(profile.currentWorld))
		<= WorldLayouts.MERCHANT_RANGE
end

return table.freeze(Farming)
