--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Deck = require(Shared.Domain.Deck)
local Helpers = require(script.Parent.Parent.Helpers)

local function err(r: any): string
	return if r.ok then "" else r.err
end

return function()
	describe("Deck validation", function()
		local p: Types.PlayerProfile, rai: { string }, ren: string, yuki: string, taren: string
		beforeEach(function()
			p = Helpers.profile()
			rai = Helpers.giveCards(p, "rai_stormvolt", 2)
			ren = Helpers.giveCards(p, "ren_emberfang", 1)[1]
			yuki = Helpers.giveCards(p, "yuki_frostveil", 1)[1]
			taren = Helpers.giveCards(p, "taren_ashscale", 1)[1]
		end)

		it("accepts three owned copies of different characters", function()
			expect(Deck.set(p, { rai[1], ren, yuki }).ok).to.equal(true)
			expect(p.deck[3]).to.equal(yuki)
		end)

		it("requires exactly three cards", function()
			expect(err(Deck.validate(p, { rai[1], ren }))).to.equal("DeckSize")
			expect(err(Deck.validate(p, { rai[1], ren, yuki, taren }))).to.equal("DeckSize")
			expect(err(Deck.validate(p, { [1] = rai[1], [2] = ren, [3] = yuki, x = taren } :: any))).to.equal(
				"DeckSize"
			)
		end)

		it("rejects the same copy twice and two copies of one character", function()
			expect(err(Deck.validate(p, { ren, ren, yuki }))).to.equal("DuplicateCard")
			expect(err(Deck.validate(p, { rai[1], rai[2], yuki }))).to.equal("DuplicateCharacter")
		end)

		it("rejects cards the player doesn't own, bad ids and locked copies", function()
			expect(err(Deck.validate(p, { ren, yuki, "999-1" }))).to.equal("NotOwned")
			local mixed: { any } = { ren, yuki, 42 }
			expect(err(Deck.validate(p, mixed))).to.equal("BadUid")
			p.cards[taren].lockedBy = "listing-1"
			expect(err(Deck.validate(p, { ren, yuki, taren }))).to.equal("CardLocked")
		end)

		it("leaves the old deck in place when the new one is invalid", function()
			Deck.set(p, { rai[1], ren, yuki })
			Deck.set(p, { rai[1], rai[2], yuki })
			expect(p.deck[2]).to.equal(ren)
		end)
	end)
end
