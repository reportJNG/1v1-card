--!strict
-- Every remote in the game, in one place. Requests are RemoteFunctions (client -> server,
-- answered with { ok, value } or { ok = false, err }); pushes are RemoteEvents (server -> client).
-- `parse` validates and cleans a payload; the server rejects anything it returns nil for.
-- `rate` is requests per second, `burst` the bucket size (server-enforced per player).
local Check = require(script.Parent.Check)

export type RequestDef = {
	rate: number,
	burst: number,
	parse: (payload: unknown) -> { [string]: any }?,
}

local function shape(keys: { string }, build: (t: { [string]: any }) -> { [string]: any }?)
	return function(payload: unknown): { [string]: any }?
		local t = Check.shape(payload, keys)
		if t == nil then
			return nil
		end
		return build(t)
	end
end

local function empty(payload: unknown): { [string]: any }?
	if payload == nil then
		return {}
	end
	if Check.shape(payload, {}) == nil then
		return nil
	end
	return {}
end

local Requests: { [string]: RequestDef } = {
	["Shop.BuyEgg"] = {
		rate = 4,
		burst = 4,
		parse = shape({ "eggId", "requestId" }, function(t)
			local eggId, requestId = Check.id(t.eggId), Check.id(t.requestId, 40)
			return if eggId and requestId then { eggId = eggId, requestId = requestId } else nil
		end),
	},
	["Shop.RequestRobuxEgg"] = {
		rate = 0.5,
		burst = 1,
		parse = shape({ "productKey" }, function(t)
			local key = Check.id(t.productKey)
			return if key then { productKey = key } else nil
		end),
	},
	["Bag.OpenEgg"] = {
		rate = 4,
		burst = 4,
		parse = shape({ "eggId", "golden" }, function(t)
			local eggId, golden = Check.id(t.eggId), Check.bool(t.golden)
			return if eggId and golden ~= nil then { eggId = eggId, golden = golden } else nil
		end),
	},
	["Daily.ClaimFreeEgg"] = { rate = 1, burst = 2, parse = empty },
	["Daily.ClaimStreak"] = { rate = 1, burst = 2, parse = empty },
	["Cards.Merge"] = {
		rate = 2,
		burst = 3,
		parse = shape({ "targetUid", "spareUids", "requestId" }, function(t)
			local target, spares, requestId =
				Check.id(t.targetUid), Check.idList(t.spareUids, 200), Check.id(t.requestId, 40)
			return if target
					and spares
					and requestId
				then { targetUid = target, spareUids = spares, requestId = requestId }
				else nil
		end),
	},
	["Cards.Sell"] = {
		rate = 2,
		burst = 3,
		parse = shape({ "uids", "requestId" }, function(t)
			local uids, requestId = Check.idList(t.uids, 100), Check.id(t.requestId, 40)
			return if uids and requestId then { uids = uids, requestId = requestId } else nil
		end),
	},
	["Cards.ExpandStorage"] = {
		rate = 1,
		burst = 2,
		parse = shape({ "requestId" }, function(t)
			local requestId = Check.id(t.requestId, 40)
			return if requestId then { requestId = requestId } else nil
		end),
	},
	["Inventory.Expand"] = {
		rate = 1,
		burst = 2,
		parse = shape({ "requestId" }, function(t)
			local requestId = Check.id(t.requestId, 40)
			return if requestId then { requestId = requestId } else nil
		end),
	},
	["Deck.Set"] = {
		rate = 2,
		burst = 3,
		parse = shape({ "uids" }, function(t)
			local uids = Check.idList(t.uids, 3)
			return if uids and #uids == 3 then { uids = uids } else nil
		end),
	},
	["Farm.Harvest"] = {
		rate = 6,
		burst = 6,
		parse = shape({ "nodeId" }, function(t)
			local nodeId = Check.id(t.nodeId)
			return if nodeId then { nodeId = nodeId } else nil
		end),
	},
	["Merchant.SellItem"] = {
		rate = 3,
		burst = 4,
		parse = shape({ "itemId", "count", "requestId" }, function(t)
			local itemId, count, requestId =
				Check.id(t.itemId), Check.int(t.count, 1, 50 * 30), Check.id(t.requestId, 40)
			return if itemId
					and count
					and requestId
				then { itemId = itemId, count = count, requestId = requestId }
				else nil
		end),
	},
	["Quests.Claim"] = {
		rate = 2,
		burst = 4,
		parse = shape({ "questId" }, function(t)
			local questId = Check.id(t.questId)
			return if questId then { questId = questId } else nil
		end),
	},
	["World.Travel"] = {
		rate = 1,
		burst = 2,
		parse = shape({ "worldId" }, function(t)
			local worldId = Check.int(t.worldId, 1, 10)
			return if worldId then { worldId = worldId } else nil
		end),
	},
	["Queue.Join"] = { rate = 1, burst = 2, parse = empty },
	["Queue.Leave"] = { rate = 1, burst = 2, parse = empty },
	["Trial.Start"] = {
		rate = 0.5,
		burst = 1,
		parse = shape({ "worldId" }, function(t)
			local worldId = Check.int(t.worldId, 1, 10)
			return if worldId then { worldId = worldId } else nil
		end),
	},
	["Battle.Pick"] = {
		rate = 4,
		burst = 4,
		parse = shape({ "round", "action" }, function(t)
			local round = Check.int(t.round, 1, 100)
			local action = t.action
			if action ~= "Attack" and action ~= "Defend" and action ~= "Special" then
				return nil
			end
			return if round then { round = round, action = action } else nil
		end),
	},
	["Battle.ChooseNext"] = {
		rate = 4,
		burst = 4,
		parse = shape({ "slot" }, function(t)
			local slot = Check.int(t.slot, 1, 3)
			return if slot then { slot = slot } else nil
		end),
	},
	["Battle.Forfeit"] = { rate = 1, burst = 1, parse = empty },
}

-- Server -> client pushes.
local Pushes = table.freeze({
	"Profile.Snapshot", -- full client view, on load
	"Profile.Delta", -- changed fields and cards
	"Queue.Status", -- { state = "Idle" | "Searching" | "Found", since?, band? }
	"Battle.Start", -- match setup
	"Battle.Round", -- one round's result
	"Battle.End", -- result and rewards
	"Notice", -- { kind, text } short toasts
})

return table.freeze({
	Requests = table.freeze(Requests),
	Pushes = Pushes,
	FOLDER = "Remotes",
})
