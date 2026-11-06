--!strict
-- Farm.Harvest and Merchant.SellItem. The character position comes from the server's own copy of
-- the character, never from the client; node respawn timers are kept per player on this server.
local Players = game:GetService("Players")
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

local lastHarvest: { [number]: { [string]: number } } = {} -- userId -> nodeId -> os.clock()
local rng = Random.new()

function FarmService.init()
	Router.handle("Farm.Harvest", function(player, args, profile)
		local userId = player.UserId
		local mine = lastHarvest[userId]
		if mine == nil then
			mine = {}
			lastHarvest[userId] = mine
		end
		local now = os.clock()
		local r = Farming.harvest(profile :: any, args.nodeId, {
			playerPosition = WorldService.positionOf(player),
			lastHarvest = (mine :: any)[args.nodeId],
			now = now,
			rng = rng :: any,
		})
		if not r.ok then
			return r
		end
		(mine :: any)[args.nodeId] = now
		local total = r.value.count + r.value.rareCount
		Quests.track(profile :: any, "Harvest", total, os.time(), (profile :: any).currentWorld)
		Telemetry.event(player, "harvest", { item = r.value.itemId, count = total })
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

	Players.PlayerRemoving:Connect(function(player)
		lastHarvest[player.UserId] = nil
	end)
end

return FarmService
