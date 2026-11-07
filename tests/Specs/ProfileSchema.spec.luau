--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local Helpers = require(script.Parent.Parent.Helpers)
local Economy = require(Shared.Config.Economy)

return function()
	describe("ProfileSchema", function()
		it("accepts the optional favourite flag only as true", function()
			local p = Helpers.profile({})
			local uid = Helpers.giveCards(p, "rai_stormvolt", 1)[1]
			p.cards[uid].favorite = true
			expect(ProfileSchema.validate(p :: any).ok).to.equal(true)
			local loose: any = p.cards[uid]
			loose.favorite = "yes"
			expect(ProfileSchema.validate(p :: any).ok).to.equal(false)
		end)

		it("creates a valid new profile for a first-time player", function()
			local r = ProfileSchema.load(nil, 77)
			expect(r.ok).to.equal(true)
			local p = if r.ok then r.value else nil :: any
			expect(p.uidPrefix).to.equal("77")
			expect(p.schemaVersion).to.equal(ProfileSchema.CURRENT_VERSION)
			expect(ProfileSchema.validate(p :: any).ok).to.equal(true)
		end)

		it("gives a player who never owned a card 3 different starter cards as a valid deck, once", function()
			local Deck = require(Shared.Domain.Deck)
			local Cards = require(Shared.Domain.Cards)
			local p = ProfileSchema.new(77)
			expect(ProfileSchema.grantStarter(p, Helpers.NOW)).to.equal(true)
			expect(#p.deck).to.equal(#Economy.StarterCards)
			for i, uid in p.deck do
				local card = p.cards[uid]
				expect(card.characterId).to.equal(Economy.StarterCards[i])
				expect(card.origin).to.equal("Reward")
				expect(card.provenance.paidLineage).to.equal(false)
			end
			expect(Deck.validate(p, p.deck).ok).to.equal(true)
			expect(ProfileSchema.validate(p).ok).to.equal(true)
			expect(ProfileSchema.grantStarter(p, Helpers.NOW)).to.equal(false)
			expect(Cards.count(p)).to.equal(#Economy.StarterCards)
			-- someone who ever had a card (even one since sold) is never topped up
			local veteran = ProfileSchema.new(78)
			veteran.nextCardSerial = 5
			expect(ProfileSchema.grantStarter(veteran, Helpers.NOW)).to.equal(false)
			expect(Cards.count(veteran)).to.equal(0)
		end)

		it("gives new players the starting Coins", function()
			expect(ProfileSchema.new(1).coins).to.equal(Economy.StartingCoins)
			expect(Economy.StartingCoins).to.equal(500)
		end)

		it("upgrades a version 1 save to version 2 without touching its Coins or cards", function()
			local v1: any = ProfileSchema.new(77)
			for _, key in { "currentWorld", "opponentsToday", "questDay", "trials", "stats", "settings" } do
				v1[key] = nil
			end
			v1.schemaVersion = 1
			v1.coins = 1234
			local loaded = ProfileSchema.load(v1, 77)
			expect(loaded.ok).to.equal(true)
			local p = (loaded :: any).value
			expect(p.schemaVersion).to.equal(ProfileSchema.CURRENT_VERSION)
			expect(p.coins).to.equal(1234)
			expect(p.currentWorld).to.equal(1)
			expect(p.stats.matches).to.equal(0)
			expect(p.settings.sfx).to.equal(true)
		end)

		it("upgrades a version 2 save with empty harvest timers", function()
			local v2: any = ProfileSchema.new(78)
			v2.harvests = nil
			v2.schemaVersion = 2
			v2.gems = 42
			local loaded = ProfileSchema.load(v2, 78)
			assert(loaded.ok, "load")
			expect(loaded.value.schemaVersion).to.equal(ProfileSchema.CURRENT_VERSION)
			expect(loaded.value.gems).to.equal(42)
			expect((next(loaded.value.harvests))).to.equal(nil)
		end)

		it("upgrades a version 3 save to version 4 with default volumes, keeping the switches", function()
			local v3: any = ProfileSchema.new(79)
			v3.settings = { music = false, sfx = true, reducedMotion = true }
			v3.schemaVersion = 3
			local loaded = ProfileSchema.load(v3, 79)
			assert(loaded.ok, "load")
			local settings = loaded.value.settings
			expect(loaded.value.schemaVersion).to.equal(4)
			expect(settings.music).to.equal(false)
			expect(settings.reducedMotion).to.equal(true)
			expect(settings.musicVolume).to.equal(80)
			expect(settings.sfxVolume).to.equal(100)
		end)

		it("runs migrations in order", function()
			local raw = Helpers.profile() :: any
			raw.schemaVersion = 1
			raw.coins = 10
			local migrations = {
				[1] = function(d: any): any
					d.coins *= 2
					return d
				end,
				[2] = function(d: any): any
					d.coins += 1
					return d
				end,
				[3] = function(d: any): any
					d.coins *= 10
					return d
				end,
			}
			local r = ProfileSchema.load(raw, 1, migrations)
			expect(r.ok).to.equal(true)
			expect(if r.ok then r.value.coins else 0).to.equal(210)
			expect(if r.ok then r.value.schemaVersion else 0).to.equal(4)
		end)

		it("refuses data saved by a newer game version", function()
			local raw = Helpers.profile() :: any
			raw.schemaVersion = ProfileSchema.CURRENT_VERSION + 1
			local r = ProfileSchema.load(raw, 1)
			expect(if r.ok then "" else r.err).to.equal("ProfileFromNewerVersion")
		end)

		it("fills fields that older saves don't have", function()
			local raw = Helpers.profile() :: any
			raw.processedReceipts = nil
			raw.items.slots = nil
			local r = ProfileSchema.load(raw, 1)
			expect(r.ok).to.equal(true)
			expect(if r.ok then typeof(r.value.processedReceipts) else "").to.equal("table")
			expect(if r.ok then r.value.items.slots else 0).to.equal(5)
		end)

		it("rejects corrupt data and a Robux card without paid lineage", function()
			expect(ProfileSchema.load("garbage", 1).ok).to.equal(false)
			local raw = Helpers.profile() :: any
			raw.coins = -5
			expect(ProfileSchema.load(raw, 1).ok).to.equal(false)
			local p = Helpers.profile()
			local uid = Helpers.giveCards(p, "rai_stormvolt", 1, "Robux", "PURCHASE-1")[1]
			p.cards[uid].provenance.paidLineage = false
			local v = ProfileSchema.validate(p :: any)
			expect(if v.ok then "" else v.err).to.equal(`LostPaidLineage:{uid}`)
		end)
	end)
end
