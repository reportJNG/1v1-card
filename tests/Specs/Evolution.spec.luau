--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Evolution = require(Shared.Domain.Evolution)
local Progression = require(Shared.Config.Progression)
local Economy = require(Shared.Config.Economy)
local Rarities = require(Shared.Config.Rarities)
local Characters = require(Shared.Config.Characters)
local AbilityText = require(Shared.Domain.AbilityText)

return function()
	describe("Evolution stages", function()
		it("maps levels 1-15 onto Base, Awakened, Ascended and Max", function()
			local expected = {
				[1] = "base",
				[4] = "base",
				[5] = "awakened",
				[9] = "awakened",
				[10] = "ascended",
				[14] = "ascended",
				[15] = "max",
			}
			for level, id in expected do
				expect(Evolution.stageAt(level).id).to.equal(id)
			end
		end)

		it("starts at level 1, rises strictly and ends exactly at the max level", function()
			local stages = Progression.evolutionStages
			expect(stages[1].minLevel).to.equal(1)
			for i = 2, #stages do
				expect(stages[i].minLevel > stages[i - 1].minLevel).to.equal(true)
			end
			expect(stages[#stages].minLevel).to.equal(Economy.Progression.maxLevel)
		end)

		it("names the next stage and none after Max", function()
			local nxt = Evolution.next(1)
			expect(nxt and nxt.id).to.equal("awakened")
			expect(Evolution.next(15)).to.equal(nil)
		end)
	end)

	describe("Rarity display", function()
		it("gives every rarity a badge, display name, palette, emblem and kit tag", function()
			local badges = { Common = "N", Rare = "R", Epic = "SR", Legendary = "SSR", Mythical = "UR" }
			for _, name in Rarities.Order do
				local def = Rarities.Defs[name]
				expect(def.badge).to.equal(badges[name])
				expect(#def.colors).to.equal(4)
				expect(def.emblem == "star" or def.emblem == "crown").to.equal(true)
				expect(def.tag).to.equal(string.lower(def.badge))
			end
			expect(Rarities.Defs.Mythical.displayName).to.equal("God-tier")
			expect(Rarities.label("Mythical")).to.equal("UR · God-tier")
		end)
	end)

	describe("Special descriptions", function()
		it("describes every character's Special from its numbers, with no gaps", function()
			for _, c in Characters.List do
				local text = AbilityText.special(c.special)
				expect(#text > 12).to.equal(true)
				expect(string.find(text, "nil", 1, true) == nil).to.equal(true)
			end
		end)
	end)
end
