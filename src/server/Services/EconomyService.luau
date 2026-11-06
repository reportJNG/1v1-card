--!strict
-- Coin and card actions: buy and open eggs, daily free egg, merge, sell spares, decks and
-- storage. All rules live in Shared/Domain; this file only maps remotes to them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)
local Hatch = require(Shared.Domain.Hatch)
local Cards = require(Shared.Domain.Cards)
local Deck = require(Shared.Domain.Deck)
local Inventory = require(Shared.Domain.Inventory)
local ClientView = require(Shared.Domain.ClientView)
local Quests = require(Shared.Domain.Quests)
local Router = require(script.Parent.Parent:WaitForChild("Net").Router)
local Telemetry = require(script.Parent.Telemetry)

local EconomyService = {}

local rng = Random.new()

local function views(cards: { Types.CardCopy }): { ClientView.CardView }
	local out = {}
	for _, copy in cards do
		table.insert(out, ClientView.card(copy))
	end
	return out
end

local function hatchReply(
	player: Player,
	profile: Types.PlayerProfile,
	eggId: string,
	source: string,
	r: Types.Result<Hatch.HatchResult>
): Types.Result<any>
	if not r.ok then
		return Result.fail(r.err)
	end
	Quests.track(profile, "Hatch", #r.value.cards, os.time())
	for _, copy in r.value.cards do
		Telemetry.event(
			player,
			"hatch",
			{ egg = eggId, source = source, character = copy.characterId, golden = copy.golden }
		)
	end
	return Result.ok({ cards = views(r.value.cards) })
end

function EconomyService.init()
	Router.handle("Shop.BuyEgg", function(player, args, profile)
		local r = Hatch.buyWithCoins(profile :: any, args.eggId, `egg:{args.requestId}`, rng, os.time())
		return hatchReply(player, profile :: any, args.eggId, "coins", r)
	end, { saveNow = true })

	Router.handle("Bag.OpenEgg", function(player, args, profile)
		local r = Hatch.openFromBag(profile :: any, args.eggId, args.golden, rng, os.time())
		return hatchReply(player, profile :: any, args.eggId, if args.golden then "bag_golden" else "bag", r)
	end, { saveNow = true })

	Router.handle("Daily.ClaimFreeEgg", function(player, _args, profile)
		local r = Hatch.claimDailyFree(profile :: any, os.time() // 86400, rng, os.time())
		return hatchReply(player, profile :: any, "daily", "daily", r)
	end, { saveNow = true })

	Router.handle("Cards.Merge", function(player, args, profile)
		local r =
			Cards.merge(profile :: any, args.targetUid, args.spareUids, `merge:{args.requestId}`, os.time())
		if r.ok then
			Quests.track(profile :: any, "Merge", 1, os.time())
			Telemetry.event(player, "merge", { to = r.value.toLevel, fee = r.value.coinFee })
		end
		return r
	end)

	Router.handle("Cards.Sell", function(_player, args, profile)
		return Cards.sellSpares(profile :: any, args.uids, `sell:{args.requestId}`, os.time())
	end)

	Router.handle("Cards.ExpandStorage", function(_player, args, profile)
		return Cards.expandStorage(profile :: any, `storage:{args.requestId}`, os.time())
	end)

	Router.handle("Inventory.Expand", function(_player, args, profile)
		return Inventory.expand(profile :: any, `slots:{args.requestId}`, os.time())
	end)

	Router.handle("Deck.Set", function(_player, args, profile)
		return Deck.set(profile :: any, args.uids)
	end)

	Router.handle("Settings.Set", function(_player, args, profile)
		(profile :: any).settings[args.key] = args.value
		return Result.ok(nil)
	end)
end

return EconomyService
