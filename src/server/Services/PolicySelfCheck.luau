--!strict
-- Studio only. After PolicyGate settles for a player, runs the real server-side checks for every
-- operation that depends on PolicyService, on a throwaway profile (never the player's own), and
-- prints one line per player:
--
--   [PolicySelfCheck] restricted=true trading=false | offer=BLOCKED(PaidRandomItemsRestricted)
--     receipt=NotProcessedYet(PaidRandomItemsRestricted) coinEgg=ALLOWED paidCopy=UNTRADABLE
--     earnedCopy=TRADABLE | MATCH
--
-- MATCH means every result equals the four-combination table in CLAUDE.md. Use it with
-- Test > Player Emulator > Policies to verify each combination (README "Testing PolicyService").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Cards = require(Shared.Domain.Cards)
local Hatch = require(Shared.Domain.Hatch)
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local PolicyRules = require(Shared.Domain.PolicyRules)
local ReceiptProcessor = require(script.Parent.Parent:WaitForChild("Purchases").ReceiptProcessor)
local PolicyGate = require(script.Parent.PolicyGate)

local TEST_PRODUCT_ID = -1 -- never a real Developer Product
local PRODUCT = { key = "selfcheck", eggId = "egg_basic", quantity = 1, productId = TEST_PRODUCT_ID }

local PolicySelfCheck = {}

local function run(player: Player)
	local state = PolicyGate.waitUntilSettled(player, 30)
	if not player.Parent then
		return
	end
	local scratch = ProfileSchema.new(player.UserId)
	scratch.coins = 1_000_000

	local offer = PolicyRules.robuxEggOffer(state, scratch, PRODUCT)
	local decision, reason = ReceiptProcessor.process(
		{ PlayerId = player.UserId, ProductId = TEST_PRODUCT_ID, PurchaseId = "selfcheck" },
		{
			getProfile = function()
				return scratch
			end,
			getPolicy = function()
				return state
			end,
			saveNow = function()
				return Result.ok(nil)
			end,
			markDirty = function() end,
			products = { [TEST_PRODUCT_ID] = PRODUCT },
			rng = Random.new(1),
			now = os.time,
		}
	)
	local coin = Hatch.buyWithCoins(scratch, "egg_basic", "selfcheck-coin", Random.new(2), os.time())
	local paid = Cards.create(scratch, "rai_stormvolt", "Robux", "selfcheck-paid", false, os.time())
	local earned = Cards.create(scratch, "rai_stormvolt", "Coins", "selfcheck-earned", false, os.time())
	local paidTradable = paid.ok and PolicyRules.isCopyTradeEligible(state, paid.value)
	local earnedTradable = earned.ok and PolicyRules.isCopyTradeEligible(state, earned.value)

	local buyAllowed = state.known and not state.paidRandomItemsRestricted
	local tradeAllowed = state.known and state.paidItemTradingAllowed
	local match = offer.ok == buyAllowed
		and (decision == "Granted") == buyAllowed
		and coin.ok
		and paidTradable == tradeAllowed
		and earnedTradable

	print(
		`[PolicySelfCheck] {player.Name} known={state.known} restricted={state.paidRandomItemsRestricted}`
			.. ` trading={state.paidItemTradingAllowed}`
			.. ` | offer={if offer.ok then "ALLOWED" else `BLOCKED({offer.err})`}`
			.. ` receipt={decision}({reason})`
			.. ` coinEgg={if coin.ok then "ALLOWED" else `BLOCKED({coin.err})`}`
			.. ` paidCopy={if paidTradable then "TRADABLE" else "UNTRADABLE"}`
			.. ` earnedCopy={if earnedTradable then "TRADABLE" else "UNTRADABLE"}`
			.. ` | {if match then "MATCH" else "MISMATCH"}`
	)
end

function PolicySelfCheck.init()
	if not RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(run, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(run, player)
	end
end

return PolicySelfCheck
