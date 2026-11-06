--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Hatch = require(Shared.Domain.Hatch)
local Cards = require(Shared.Domain.Cards)
local Characters = require(Shared.Config.Characters)
local Eggs = require(Shared.Config.Eggs)
local Helpers = require(script.Parent.Parent.Helpers)

local function product(eggId: string, quantity: number): Types.RobuxEggProduct
	return { key = `{eggId}_x{quantity}`, eggId = eggId, quantity = quantity, productId = 1000 + quantity }
end

return function()
	describe("Hatch.buyWithCoins", function()
		it("charges the configured price and creates a Coins copy", function()
			local p = Helpers.profile({ coins = 1000 })
			local r = Hatch.buyWithCoins(p, "egg_basic", "req-1", Random.new(1), Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(p.coins).to.equal(1000 - (Eggs.ById.egg_basic.coinPrice :: number))
			expect(Cards.count(p)).to.equal(1)
			local card = if r.ok then r.value.cards[1] else nil :: any
			expect(card.origin).to.equal("Coins")
			expect(card.provenance.paidLineage).to.equal(false)
		end)

		it("refuses eggs from locked worlds without charging", function()
			local p = Helpers.profile({ coins = 1e6 })
			local r = Hatch.buyWithCoins(p, "egg_dragon", "req-1", Random.new(1), Helpers.NOW)
			expect(if r.ok then "" else r.err).to.equal("EggLocked")
			expect(p.coins).to.equal(1e6)
			p.highestTrophies = 700
			expect(Hatch.buyWithCoins(p, "egg_dragon", "req-2", Random.new(1), Helpers.NOW).ok).to.equal(true)
		end)

		it("refuses when card storage is full, without charging", function()
			local p = Helpers.profile({ coins = 1000, cardSlots = 2 })
			Helpers.giveCards(p, "rai_stormvolt", 2)
			local r = Hatch.buyWithCoins(p, "egg_basic", "req-1", Random.new(1), Helpers.NOW)
			expect(if r.ok then "" else r.err).to.equal("CardStorageFull")
			expect(p.coins).to.equal(1000)
		end)

		it("charges once for a repeated request id", function()
			local p = Helpers.profile({ coins = 1000 })
			Hatch.buyWithCoins(p, "egg_basic", "req-1", Random.new(1), Helpers.NOW)
			local again = Hatch.buyWithCoins(p, "egg_basic", "req-1", Random.new(1), Helpers.NOW)
			expect(again.ok).to.equal(false)
			expect(Cards.count(p)).to.equal(1)
		end)

		it("hides the Secret Egg until its quest is claimed, and never sells the event egg", function()
			local p = Helpers.profile({ coins = 1e7, highestTrophies = 5000 })
			expect(Hatch.buyWithCoins(p, "egg_secret", "a", Random.new(1), Helpers.NOW).ok).to.equal(false)
			p.quests.quest_reveal_secret_egg = { progress = 1, claimed = true }
			expect(Hatch.buyWithCoins(p, "egg_secret", "b", Random.new(1), Helpers.NOW).ok).to.equal(true)
			expect(Hatch.buyWithCoins(p, "egg_party", "c", Random.new(1), Helpers.NOW).ok).to.equal(false)
		end)
	end)

	describe("Hatch.grantRobux", function()
		it("creates Robux copies carrying their PurchaseId as paid lineage", function()
			local p = Helpers.profile()
			local r = Hatch.grantRobux(p, product("egg_basic", 3), "PURCHASE-1", Random.new(3), Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(Cards.count(p)).to.equal(3)
			for _, card in p.cards do
				expect(card.origin).to.equal("Robux")
				expect(card.originRef).to.equal("PURCHASE-1")
				expect(card.provenance.paidLineage).to.equal(true)
				expect(card.provenance.paidRefs[1]).to.equal("PURCHASE-1")
			end
		end)

		it("grants a replayed receipt only once", function()
			local p = Helpers.profile()
			Hatch.grantRobux(p, product("egg_basic", 1), "PURCHASE-1", Random.new(3), Helpers.NOW)
			local again =
				Hatch.grantRobux(p, product("egg_basic", 1), "PURCHASE-1", Random.new(3), Helpers.NOW)
			expect(again.ok).to.equal(true)
			expect(if again.ok then again.value.alreadyProcessed else false).to.equal(true)
			expect(Cards.count(p)).to.equal(1)
		end)

		it("honours a paid receipt even if storage filled after the prompt", function()
			local p = Helpers.profile({ cardSlots = 1 })
			Helpers.giveCards(p, "rai_stormvolt", 1)
			local r = Hatch.grantRobux(p, product("egg_basic", 3), "PURCHASE-2", Random.new(3), Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(Cards.count(p)).to.equal(4)
			expect(Cards.freeSlots(p)).to.equal(0)
		end)
	end)

	describe("Hatch from the Egg Bag and daily claim", function()
		it("never rolls Common from a Golden egg", function()
			local p = Helpers.profile({ cardSlots = 1000 })
			expect(Hatch.addToBag(p, "egg_basic", true, 99).ok).to.equal(true)
			local rng = Random.new(9)
			for _ = 1, 99 do
				local r = Hatch.openFromBag(p, "egg_basic", true, rng, Helpers.NOW)
				expect(r.ok).to.equal(true)
				local id = if r.ok then r.value.cards[1].characterId else ""
				expect(Characters.ById[id].rarity).never.to.equal("Common")
				expect(if r.ok then r.value.cards[1].golden else false).to.equal(true)
			end
			expect(p.eggBag.egg_basic).to.equal(nil)
		end)

		it("rejects a Golden Rainbow and bag overflow", function()
			local p = Helpers.profile()
			expect(Hatch.addToBag(p, "egg_rainbow", true, 1).ok).to.equal(false)
			expect(Hatch.addToBag(p, "egg_basic", false, 99).ok).to.equal(true)
			expect(Hatch.addToBag(p, "egg_basic", false, 1).ok).to.equal(false)
		end)

		it("gives one free daily egg per day", function()
			local p = Helpers.profile()
			expect(Hatch.claimDailyFree(p, 20000, Random.new(1), Helpers.NOW).ok).to.equal(true)
			expect(Hatch.claimDailyFree(p, 20000, Random.new(1), Helpers.NOW).ok).to.equal(false)
			expect(Hatch.claimDailyFree(p, 20001, Random.new(1), Helpers.NOW).ok).to.equal(true)
			for _, card in p.cards do
				expect(card.origin).to.equal("Daily")
			end
		end)
	end)
end
