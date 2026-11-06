--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Trials = require(Shared.Domain.Trials)
local Deck = require(Shared.Domain.Deck)
local Economy = require(Shared.Config.Economy)
local Guardians = require(Shared.Config.Guardians)
local Worlds = require(Shared.Config.Worlds)
local Characters = require(Shared.Config.Characters)
local Rules = require(Shared.Config.Battle)
local Helpers = require(script.Parent.Parent.Helpers)

local function withDeck(): any
	local p = Helpers.profile()
	local uids = {}
	for i = 1, 3 do
		table.insert(uids, Helpers.giveCards(p, Characters.List[i].id, 1)[1])
	end
	assert(Deck.set(p, uids).ok, "deck")
	return p
end

return function()
	describe("Guardian Trials", function()
		it("has a Guardian for each of the 10 worlds with a valid 3-card deck", function()
			for _, world in Worlds.List do
				local g = Guardians.ByWorld[world.id]
				expect(g).to.be.ok()
				expect(#g.deck).to.equal(3)
				local seen = {}
				for _, spec in g.deck do
					expect(Characters.ById[spec.characterId]).to.be.ok()
					expect(seen[spec.characterId]).to.equal(nil)
					seen[spec.characterId] = true
					expect(spec.level >= 1 and spec.level <= Economy.Progression.maxLevel).to.equal(true)
				end
			end
		end)

		it("only starts in an unlocked world, with a valid deck", function()
			local noDeck = Helpers.profile()
			local r1 = Trials.prepare(noDeck, 1)
			expect(if r1.ok then "" else r1.err).to.equal("NoDeck")
			local p = withDeck()
			expect(Trials.prepare(p, 1).ok).to.equal(true)
			local locked = Trials.prepare(p, 2)
			expect(if locked.ok then "" else locked.err).to.equal("WorldLocked")
			local unknown = Trials.prepare(p, 11)
			expect(if unknown.ok then "" else unknown.err).to.equal("UnknownWorld")
		end)

		it("uses the player's real card levels", function()
			local p = withDeck()
			p.cards[p.deck[1]].level = 9
			local r = Trials.prepare(p, 1)
			assert(r.ok, "prepare")
			expect(r.value.deck[1].level).to.equal(9)
		end)

		it("grants the first clear once: trophies, Coins, Gems and a Golden egg", function()
			local p = withDeck()
			local r = Trials.grantClear(p, 1, Helpers.NOW)
			assert(r.ok, if r.ok then "" else r.err)
			expect(r.value.firstClear).to.equal(true)
			expect(p.trophies).to.equal(Economy.Trials.trophyGrant)
			expect(p.highestTrophies).to.equal(Economy.Trials.trophyGrant)
			expect(p.coins).to.equal(Economy.Trials.coinsByWorld[1])
			expect(p.gems).to.equal(Economy.Trials.gemsFirstClear)
			expect(r.value.goldenEgg).to.equal(Worlds.ById[1].eggs[1])
			expect(p.eggBag[Worlds.ById[1].eggs[1]].golden).to.equal(1)
			expect(p.stats.trialsCleared).to.equal(1)

			local again = Trials.grantClear(p, 1, Helpers.NOW + 60)
			assert(again.ok, "again")
			expect(again.value.firstClear).to.equal(false)
			expect(p.trophies).to.equal(Economy.Trials.trophyGrant)
			expect(p.coins).to.equal(Economy.Trials.coinsByWorld[1])
			expect(p.eggBag[Worlds.ById[1].eggs[1]].golden).to.equal(1)
		end)

		it("skips the egg, not the clear, when the Golden stack is full", function()
			local p = withDeck()
			local eggId = Worlds.ById[1].eggs[1]
			p.eggBag[eggId] = { normal = 0, golden = Economy.EggBag.maxPerStack }
			local r = Trials.grantClear(p, 1, Helpers.NOW)
			assert(r.ok, "grant")
			expect(r.value.goldenEgg).to.equal(nil)
			expect(Trials.isCleared(p, 1)).to.equal(true)
		end)

		it("lets a trophy grant unlock the next world", function()
			local p = withDeck()
			p.trophies = Worlds.ById[2].trophiesToUnlock - 10
			p.highestTrophies = p.trophies
			expect(Trials.prepare(p, 2).ok).to.equal(false)
			Trials.grantClear(p, 1, Helpers.NOW)
			expect(Trials.prepare(p, 2).ok).to.equal(true)
		end)

		it("reads its timers from the battle config", function()
			expect(Rules.pickSeconds).to.equal(12)
			expect(Rules.nextSeconds).to.equal(5)
			expect(Rules.maxTimeouts).to.equal(3)
		end)
	end)
end
