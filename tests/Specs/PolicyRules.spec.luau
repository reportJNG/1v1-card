--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local PolicyRules = require(Shared.Domain.PolicyRules)
local Hatch = require(Shared.Domain.Hatch)
local Helpers = require(script.Parent.Parent.Helpers)

local function product(eggId: string, productId: number?): Types.RobuxEggProduct
	return { key = `{eggId}_x1`, eggId = eggId, quantity = 1, productId = productId }
end

local function err(r: any): string
	return if r.ok then "" else r.err
end

return function()
	describe("PolicyRules: the four PolicyService combinations", function()
		local cases = {
			{ restricted = false, trading = true, purchase = true, trade = true },
			{ restricted = false, trading = false, purchase = true, trade = false },
			{ restricted = true, trading = true, purchase = false, trade = true },
			{ restricted = true, trading = false, purchase = false, trade = false },
		}
		for _, case in cases do
			it(`restricted={case.restricted} trading={case.trading}`, function()
				local state = PolicyRules.fromPolicyInfo({
					ArePaidRandomItemsRestricted = case.restricted,
					IsPaidItemTradingAllowed = case.trading,
				})
				expect(PolicyRules.canPurchasePaidRandomItems(state)).to.equal(case.purchase)
				expect(PolicyRules.canTradePaidItems(state)).to.equal(case.trade)
			end)
		end

		it("fails closed when policy info is missing or malformed", function()
			local unknown = PolicyRules.fromPolicyInfo(nil)
			expect(unknown.known).to.equal(false)
			expect(PolicyRules.canPurchasePaidRandomItems(unknown)).to.equal(false)
			expect(PolicyRules.canTradePaidItems(unknown)).to.equal(false)
			for _, info in
				{ "oops", {}, { ArePaidRandomItemsRestricted = "no", IsPaidItemTradingAllowed = 1 } } :: { any }
			do
				local state = PolicyRules.fromPolicyInfo(info)
				expect(PolicyRules.canPurchasePaidRandomItems(state)).to.equal(false)
				expect(PolicyRules.canTradePaidItems(state)).to.equal(false)
			end
		end)
	end)

	describe("PolicyRules.robuxEggOffer", function()
		local allowed = PolicyRules.fromPolicyInfo({
			ArePaidRandomItemsRestricted = false,
			IsPaidItemTradingAllowed = true,
		})
		local restricted = PolicyRules.fromPolicyInfo({
			ArePaidRandomItemsRestricted = true,
			IsPaidItemTradingAllowed = true,
		})

		it("offers a published Robux egg from an unlocked world", function()
			expect(PolicyRules.robuxEggOffer(allowed, Helpers.profile(), product("egg_basic", 1)).ok).to.equal(
				true
			)
		end)

		it("never offers Robux eggs to restricted players", function()
			expect(err(PolicyRules.robuxEggOffer(restricted, Helpers.profile(), product("egg_basic", 1)))).to.equal(
				"PaidRandomItemsRestricted"
			)
		end)

		it("keeps the Coin path to the same egg open for restricted players", function()
			local p = Helpers.profile({ coins = 1000 })
			expect(Hatch.buyWithCoins(p, "egg_basic", "r1", Random.new(1), Helpers.NOW).ok).to.equal(true)
		end)

		it("only offers eggs from unlocked worlds (Q10)", function()
			local p = Helpers.profile()
			expect(err(PolicyRules.robuxEggOffer(allowed, p, product("egg_dragon", 1)))).to.equal("EggLocked")
			p.highestTrophies = 700
			expect(PolicyRules.robuxEggOffer(allowed, p, product("egg_dragon", 1)).ok).to.equal(true)
		end)

		it("never offers an unpublished product, the event egg, or into full storage", function()
			expect(err(PolicyRules.robuxEggOffer(allowed, Helpers.profile(), product("egg_basic", nil)))).to.equal(
				"ProductNotPublished"
			)
			expect(err(PolicyRules.robuxEggOffer(allowed, Helpers.profile(), product("egg_party", 1)))).to.equal(
				"NotARobuxEgg"
			)
			local full = Helpers.profile({ cardSlots = 1 })
			Helpers.giveCards(full, "rai_stormvolt", 1)
			expect(err(PolicyRules.robuxEggOffer(allowed, full, product("egg_basic", 1)))).to.equal(
				"CardStorageFull"
			)
		end)
	end)

	describe("PolicyRules.isCopyTradeEligible (V2 store rule)", function()
		it("separates paid-item trading from paid-random-item purchasing", function()
			local p = Helpers.profile({ coins = 1e6 })
			local earned = Helpers.giveCards(p, "rai_stormvolt", 1, "Coins")[1]
			local paid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-1")[1]
			-- Can't buy Robux eggs, but may trade paid items: paid copies are tradable.
			local buyNoTradeYes = PolicyRules.fromPolicyInfo({
				ArePaidRandomItemsRestricted = true,
				IsPaidItemTradingAllowed = true,
			})
			-- May buy Robux eggs, but may not trade paid items: paid copies are not tradable.
			local buyYesTradeNo = PolicyRules.fromPolicyInfo({
				ArePaidRandomItemsRestricted = false,
				IsPaidItemTradingAllowed = false,
			})
			expect(PolicyRules.isCopyTradeEligible(buyNoTradeYes, p.cards[paid])).to.equal(true)
			expect(PolicyRules.isCopyTradeEligible(buyYesTradeNo, p.cards[paid])).to.equal(false)
			expect(PolicyRules.isCopyTradeEligible(buyYesTradeNo, p.cards[earned])).to.equal(true)
		end)
	end)
end
