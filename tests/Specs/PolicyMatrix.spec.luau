--!strict
-- The four PolicyService combinations, checked on every operation that depends on them.
-- (Unit level. The same four are also tested live in Studio's Player Emulator; see README.)
--
--   restricted | trading | Robux eggs | paid-origin cards tradable
--   false      | false   | allowed    | no
--   false      | true    | allowed    | yes
--   true       | false   | blocked    | no
--   true       | true    | blocked    | yes
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Cards = require(Shared.Domain.Cards)
local Hatch = require(Shared.Domain.Hatch)
local PolicyRules = require(Shared.Domain.PolicyRules)
local ReceiptProcessor = require(ServerScriptService:WaitForChild("Server").Purchases.ReceiptProcessor)
local Helpers = require(script.Parent.Parent.Helpers)

local PRODUCT = { key = "egg_basic_x1", eggId = "egg_basic", quantity = 1, productId = 5555 }

local CASES = {
	{ restricted = false, trading = false, buy = true, trade = false },
	{ restricted = false, trading = true, buy = true, trade = true },
	{ restricted = true, trading = false, buy = false, trade = false },
	{ restricted = true, trading = true, buy = false, trade = true },
}

local function deliver(profile: any, policy: any, purchaseId: string): (string, string)
	return ReceiptProcessor.process({ PlayerId = 1, ProductId = 5555, PurchaseId = purchaseId }, {
		getProfile = function()
			return profile
		end,
		getPolicy = function()
			return policy
		end,
		saveNow = function()
			return Result.ok(nil)
		end,
		markDirty = function() end,
		products = { [5555] = PRODUCT },
		rng = Random.new(3),
		now = function()
			return Helpers.NOW
		end,
	})
end

return function()
	for _, case in CASES do
		describe(`restricted={case.restricted} trading={case.trading}`, function()
			local policy = PolicyRules.fromPolicyInfo({
				ArePaidRandomItemsRestricted = case.restricted,
				IsPaidItemTradingAllowed = case.trading,
			})

			it(if case.buy then "offers Robux eggs" else "never offers Robux eggs", function()
				local p = Helpers.profile()
				expect(PolicyRules.robuxEggOffer(policy, p, PRODUCT).ok).to.equal(case.buy)
			end)

			it(
				if case.buy then "delivers a Robux egg receipt" else "holds a Robux egg receipt ungranted",
				function()
					local p = Helpers.profile()
					local decision, reason = deliver(p, policy, "P-M")
					if case.buy then
						expect(decision).to.equal("Granted")
						expect(Cards.count(p)).to.equal(1)
					else
						expect(decision).to.equal("NotProcessedYet")
						expect(reason).to.equal("PaidRandomItemsRestricted")
						expect(Cards.count(p)).to.equal(0)
						expect(p.processedReceipts["P-M"]).to.equal(nil)
						expect(p.heldReceipts["P-M"]).to.be.ok()
					end
				end
			)

			it("always allows the Coin path to the same egg", function()
				local p = Helpers.profile({ coins = 1_000_000 })
				expect(Hatch.buyWithCoins(p, "egg_basic", Helpers.tx(), Random.new(1), Helpers.NOW).ok).to.equal(
					true
				)
			end)

			it(
				if case.trade
					then "marks paid-origin cards tradable"
					else "marks paid-origin cards untradable",
				function()
					local p = Helpers.profile({ coins = 1_000_000 })
					local paid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-M")[1]
					local earned = Helpers.giveCards(p, "rai_stormvolt", 3, "Coins")
					expect(PolicyRules.isCopyTradeEligible(policy, p.cards[paid])).to.equal(case.trade)
					expect(PolicyRules.isCopyTradeEligible(policy, p.cards[earned[1]])).to.equal(true)
					-- An earned card that absorbs a paid spare becomes paid-origin for trading.
					local merged = Cards.merge(p, earned[2], { paid, earned[3] }, Helpers.tx(), Helpers.NOW)
					expect(merged.ok).to.equal(true)
					expect(PolicyRules.isCopyTradeEligible(policy, p.cards[earned[2]])).to.equal(case.trade)
				end
			)
		end)
	end

	describe("unknown policy (lookup failed or not answered yet)", function()
		it("blocks Robux eggs, holds receipts and treats paid cards as untradable", function()
			local p = Helpers.profile()
			expect(PolicyRules.robuxEggOffer(PolicyRules.UNKNOWN, p, PRODUCT).ok).to.equal(false)
			expect((deliver(p, PolicyRules.UNKNOWN, "P-U"))).to.equal("NotProcessedYet")
			local paid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-U")[1]
			expect(PolicyRules.isCopyTradeEligible(PolicyRules.UNKNOWN, p.cards[paid])).to.equal(false)
		end)
	end)
end
