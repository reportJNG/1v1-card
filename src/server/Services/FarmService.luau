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

local rng = Random.new()

function FarmService.init()
	Router.handle("Farm.Harvest", function(player, args, profile)
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
		if not Farming.nearMerchant(profile :: any, WorldService.positionOf(player)) then
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
