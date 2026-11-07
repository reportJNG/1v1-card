--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Domain.Cards)
local Deck = require(Shared.Domain.Deck)
local Economy = require(Shared.Config.Economy)
local Helpers = require(script.Parent.Parent.Helpers)

return function()
	describe("Cards.merge", function()
		it("levels a card with spare copies and charges the configured fee", function()
			local p = Helpers.profile({ coins = 1000 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3) -- Common: 1 point each
			local r = Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(p.cards[uids[1]].level).to.equal(2) -- 2 points reach level 2
			expect(p.cards[uids[1]].mergePoints).to.equal(0)
			expect(p.cards[uids[2]]).to.equal(nil)
			expect(p.coins).to.equal(1000 - Economy.Progression.coinFeeToNext[1])
		end)

		it("keeps leftover points toward the next level", function()
			local p = Helpers.profile({ coins = 1000 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 4)
			Cards.merge(p, uids[1], { uids[2], uids[3], uids[4] }, Helpers.tx(), Helpers.NOW)
			expect(p.cards[uids[1]].level).to.equal(2)
			expect(p.cards[uids[1]].mergePoints).to.equal(1)
		end)

		it("changes nothing when the fee can't be paid", function()
			local p = Helpers.profile({ coins = 0 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			local r = Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			expect(if r.ok then "" else r.err).to.equal("InsufficientFunds")
			expect(Cards.count(p)).to.equal(3)
			expect(p.cards[uids[1]].level).to.equal(1)
		end)

		it("rejects different characters, deck spares, the target itself and duplicates", function()
			local p = Helpers.profile({ coins = 1e6 })
			local rai = Helpers.giveCards(p, "rai_stormvolt", 2)
			local ren = Helpers.giveCards(p, "ren_emberfang", 1)
			local yuki = Helpers.giveCards(p, "yuki_frostveil", 1)
			expect(Cards.planMerge(p, rai[1], { ren[1] }).ok).to.equal(false)
			expect(Cards.planMerge(p, rai[1], { rai[1] }).ok).to.equal(false)
			expect(Cards.planMerge(p, rai[1], { rai[2], rai[2] }).ok).to.equal(false)
			expect(Deck.set(p, { rai[2], ren[1], yuki[1] }).ok).to.equal(true)
			local r = Cards.planMerge(p, rai[1], { rai[2] })
			expect(if r.ok then "" else r.err).to.equal("SpareInDeck")
		end)

		it("stops at max level 15 and refuses wasted spares", function()
			local p = Helpers.profile({ coins = 1e7, cardSlots = 1000 })
			local uids = Helpers.giveCards(p, "aurelia_dawn", 15) -- Mythical: 15 points each, 194 needed
			local spares = table.move(uids, 2, 14, 1, {}) -- 13 spares = 195 points
			local r = Cards.merge(p, uids[1], spares, Helpers.tx(), Helpers.NOW)
			expect(r.ok).to.equal(true)
			expect(p.cards[uids[1]].level).to.equal(15)
			expect(p.cards[uids[1]].mergePoints).to.equal(0)
			local more = Cards.planMerge(p, uids[1], { uids[15] })
			expect(if more.ok then "" else more.err).to.equal("AlreadyMaxLevel")

			local q = Helpers.profile({ coins = 1e7, cardSlots = 1000 })
			local extra = Helpers.giveCards(q, "aurelia_dawn", 16)
			local tooMany = table.move(extra, 2, 16, 1, {}) -- 15 spares: the 15th adds nothing
			local refused = Cards.planMerge(q, extra[1], tooMany)
			expect(if refused.ok then "" else refused.err).to.equal("TooManySpares")
		end)
	end)

	describe("Card provenance", function()
		it("marks a card paid when a Robux copy is merged into it", function()
			local p = Helpers.profile({ coins = 1e6 })
			local earned = Helpers.giveCards(p, "rai_stormvolt", 1, "Coins")
			local paid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-9")
			local daily = Helpers.giveCards(p, "rai_stormvolt", 1, "Daily")
			Cards.merge(p, earned[1], { paid[1], daily[1] }, Helpers.tx(), Helpers.NOW)
			local card = p.cards[earned[1]]
			expect(card.origin).to.equal("Coins") -- a copy's own origin never changes
			expect(card.provenance.paidLineage).to.equal(true)
			expect(card.provenance.paidRefs[1]).to.equal("PURCHASE-9")
			expect(card.provenance.absorbed.Robux).to.equal(1)
			expect(card.provenance.absorbed.Daily).to.equal(1)
		end)

		it("keeps paid lineage through later merges", function()
			local p = Helpers.profile({ coins = 1e6 })
			local a = Helpers.giveCards(p, "rai_stormvolt", 1, "Coins")
			local paid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-C")
			local more = Helpers.giveCards(p, "rai_stormvolt", 3, "Reward")
			Cards.merge(p, a[1], { paid[1], more[1] }, Helpers.tx(), Helpers.NOW) -- level 2, now paid lineage
			Cards.merge(p, a[1], { more[2], more[3] }, Helpers.tx(), Helpers.NOW) -- earned spares only
			local card = p.cards[a[1]]
			expect(card.level).to.equal(2)
			expect(card.provenance.paidLineage).to.equal(true)
			expect(table.find(card.provenance.paidRefs, "PURCHASE-C")).to.be.ok()
			expect(card.provenance.absorbed.Robux).to.equal(1)
			expect(card.provenance.absorbed.Reward).to.equal(3)
		end)

		it("refuses an upgraded card, or a card with merge points, as merge material", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 5)
			Cards.merge(p, uids[2], { uids[3], uids[4] }, Helpers.tx(), Helpers.NOW) -- uids[2] is level 2
			local upgraded = Cards.planMerge(p, uids[1], { uids[2] })
			expect(if upgraded.ok then "" else upgraded.err).to.equal("SpareNotBaseCopy")
			expect(p.cards[uids[2]]).to.be.ok() -- the upgraded card stays a separate owned copy
			local q = Helpers.profile({ coins = 1e6 })
			local qs = Helpers.giveCards(q, "rai_stormvolt", 3)
			Cards.merge(q, qs[2], { qs[3] }, Helpers.tx(), Helpers.NOW) -- level 1 with 1 merge point
			expect(q.cards[qs[2]].level).to.equal(1)
			local withPoints = Cards.planMerge(q, qs[1], { qs[2] })
			expect(if withPoints.ok then "" else withPoints.err).to.equal("SpareNotBaseCopy")
		end)

		it("checks level and merge points on their own, not only merge history", function()
			-- Copies that never absorbed anything but are not level-1/0-point (e.g. a future reward
			-- granted at a higher level) are still not merge material.
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			p.cards[uids[2]].level = 3
			p.cards[uids[3]].mergePoints = 1
			for _, spare in { uids[2], uids[3] } do
				local plan = Cards.planMerge(p, uids[1], { spare })
				expect(if plan.ok then "" else plan.err).to.equal("SpareNotBaseCopy")
			end
			expect(Cards.isBaseCopy(p.cards[uids[1]])).to.equal(true)
		end)

		it("values every spare at exactly its rarity's merge points", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "vesper_shade", 3) -- Legendary: 8 points each
			local plan = Cards.planMerge(p, uids[1], { uids[2], uids[3] })
			expect(if plan.ok then plan.value.pointsAdded else 0).to.equal(16)
		end)

		it("keeps an earned card unpaid when only earned copies are merged", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3, "Coins")
			Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			expect(p.cards[uids[1]].provenance.paidLineage).to.equal(false)
		end)

		it("keeps the Golden foil when a Golden copy is merged in", function()
			local p = Helpers.profile({ coins = 1e6 })
			local plain = Helpers.giveCards(p, "rai_stormvolt", 1)
			local made = Cards.create(p, "rai_stormvolt", "Reward", "egg_basic", true, Helpers.NOW)
			local golden = if made.ok then made.value.uid else ""
			local third = Helpers.giveCards(p, "rai_stormvolt", 1)
			Cards.merge(p, plain[1], { golden, third[1] }, Helpers.tx(), Helpers.NOW)
			expect(p.cards[plain[1]].golden).to.equal(true)
		end)
	end)

	describe("Favourites", function()
		it("marks and unmarks an owned copy and refuses one that isn't owned", function()
			local p = Helpers.profile({})
			local uids = Helpers.giveCards(p, "rai_stormvolt", 1)
			expect(Cards.setFavorite(p, uids[1], true).ok).to.equal(true)
			expect(p.cards[uids[1]].favorite).to.equal(true)
			expect(Cards.setFavorite(p, uids[1], false).ok).to.equal(true)
			expect(p.cards[uids[1]].favorite).to.equal(nil)
			local r = Cards.setFavorite(p, "999-1", true)
			expect(if r.ok then "" else r.err).to.equal("NotOwned")
		end)

		it("refuses a favourite as a merge spare but still levels a favourite target", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			Cards.setFavorite(p, uids[2], true)
			local r = Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			expect(if r.ok then "" else r.err).to.equal("SpareFavorite")
			expect(Cards.count(p)).to.equal(3)
			Cards.setFavorite(p, uids[2], false)
			Cards.setFavorite(p, uids[1], true)
			expect(Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW).ok).to.equal(true)
			expect(p.cards[uids[1]].favorite).to.equal(true)
		end)

		it("refuses to sell a favourite and sells it once unmarked", function()
			local p = Helpers.profile({ coins = 0 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 2)
			p.cards[uids[1]].level = Economy.Progression.maxLevel -- a maxed copy makes the other a sellable spare
			Cards.setFavorite(p, uids[2], true)
			local r = Cards.sellSpares(p, { uids[2] }, Helpers.tx(), Helpers.NOW)
			expect(if r.ok then "" else r.err).to.equal("CardFavorite")
			expect(p.cards[uids[2]]).to.be.ok()
			Cards.setFavorite(p, uids[2], false)
			expect(Cards.sellSpares(p, { uids[2] }, Helpers.tx(), Helpers.NOW).ok).to.equal(true)
		end)
	end)

	describe("Card storage", function()
		it("starts at the configured size and expands at configured prices up to the max", function()
			local cfg = Economy.CardStorage
			local p = Helpers.profile({ coins = 1e9 })
			expect(p.cardSlots).to.equal(cfg.startSlots)
			local spent = 0
			for i, price in cfg.expansionPrices do
				local r = Cards.expandStorage(p, `exp{i}`, Helpers.NOW)
				expect(r.ok).to.equal(true)
				spent += price
			end
			expect(p.cardSlots).to.equal(cfg.maxSlots)
			expect(p.coins).to.equal(1e9 - spent)
			expect(Cards.expandStorage(p, "exp-over", Helpers.NOW).ok).to.equal(false)
		end)

		it("gives every copy a unique uid that is never reused", function()
			local p = Helpers.profile({ coins = 1e6 })
			local uids = Helpers.giveCards(p, "rai_stormvolt", 3)
			Cards.merge(p, uids[1], { uids[2], uids[3] }, Helpers.tx(), Helpers.NOW)
			local fresh = Helpers.giveCards(p, "rai_stormvolt", 1)[1]
			expect(fresh).to.equal("123456-4")
		end)

		it("adds +0.75% stats per level, +10.5% at level 15", function()
			local l1 = Cards.statsAt("rai_stormvolt", 1)
			local l15 = Cards.statsAt("rai_stormvolt", 15)
			expect(l1.atk).to.equal(300)
			expect(l15.atk).to.equal(math.round(300 * 1.105))
		end)
	end)
end
