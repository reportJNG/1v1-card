--!strict
-- Farm.Harvest and Merchant.SellItem. The character position comes from the server's own copy of
-- the character, never from the client; node respawn timers are kept per player on this server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Farming = require(Shared.Domain.Farming)
local Inventory = require(Shared.Domain.Inventory)
local Quests = require(Shared.Domain.Quests)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local WorldService = require(script.Parent.WorldService)
local Telemetry = require(script.Parent.Telemetry)

local FarmService = {}

-- The session gate (SessionService, MISSION 2.5), required lazily to avoid a require cycle.
local function sessionAllows(player: Player, action: string): boolean
	local SessionService = require(script.Parent.SessionService) :: any
	return SessionService.allows(player, action)
end

local rng = Random.new()

function FarmService.init()
	Router.handle("Farm.Harvest", function(player, args, profile)
		if not sessionAllows(player, "harvest") then
			return Result.fail("NotPlaying")
		end
		local now = os.time()
		local r = Farming.harvest(profile :: any, args.nodeId, {
			playerPosition = WorldService.positionOf(player),
			now = now,
			rng = rng :: any,
		})
		if not r.ok then
			return r
		end
		local total = r.value.count + r.value.rareCount
		Quests.track(profile :: any, "Harvest", total, now, (profile :: any).currentWorld)
		Telemetry.increment("harvest") -- high frequency: counted, not sent to analytics per event
		return Result.ok({
			nodeId = r.value.nodeId,
			itemId = r.value.itemId,
			count = r.value.count,
			rareItemId = r.value.rareItemId,
			rareCount = r.value.rareCount,
			readyIn = r.value.readyAt - now,
		})
	end)

	Router.handle("Merchant.SellItem", function(player, args, profile)
		if not sessionAllows(player, "sell") then
			return Result.fail("NotPlaying")
		end
		local area = player:GetAttribute("World") -- set by the server (WorldService), never the client
		if
			not Farming.nearMerchant(
				profile :: any,
				WorldService.positionOf(player),
				if type(area) == "number" then area else nil
			)
		then
			return Result.fail("NotNearMerchant")
		end
		local r = Inventory.sell(profile :: any, args.itemId, args.count, `item:{args.requestId}`, os.time())
		if r.ok then
			Quests.track(profile :: any, "SellItems", args.count, os.time())
			Telemetry.event(player, "sell_items", { item = args.itemId, count = args.count, coins = r.value })
		end
		return r
	end)
end

return FarmService
