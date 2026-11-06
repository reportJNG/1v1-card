--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigValidator = require(Shared.Domain.ConfigValidator)
local Eggs = require(Shared.Config.Eggs)
local Characters = require(Shared.Config.Characters)
local Monetization = require(Shared.Config.Monetization)
local Economy = require(Shared.Config.Economy)

-- The 24 egg types as named in the icon pack folder (independent of the config file).
local PACK_EGG_NAMES = {
	"Angel Egg",
	"AngelDemon Egg",
	"Basic Egg",
	"Black Hole Egg",
	"Cat Egg",
	"Coconut Egg",
	"Cracked Egg",
	"Demon Egg",
	"Dog Egg",
	"Dominus Egg",
	"Dragon Egg",
	"Glitched Egg",
	"Ice Egg",
	"Kraken Egg",
	"Legendary Egg",
	"Mine Egg",
	"Mythical Egg",
	"Party Egg",
	"Rainbow Egg",
	"Royal Egg",
	"Sandcastle Egg",
	"Secret Egg",
	"Spotted Egg",
	"Yeti Egg",
}

return function()
	describe("ConfigValidator", function()
		it("finds no errors in the shipped config", function()
			local report = ConfigValidator.validate()
			expect(#report.errors).to.equal(0)
		end)

		it("reports unfinished launch data as warnings in development", function()
			local report = ConfigValidator.validate()
			expect(#report.warnings > 0).to.equal(true)
		end)

		it("turns unfinished launch data into errors in release mode", function()
			local report = ConfigValidator.validate({ release = true })
			expect(#report.errors > 0).to.equal(true)
		end)
	end)

	describe("Egg catalog", function()
		it("contains exactly the 24 eggs of the icon pack", function()
			expect(#Eggs.List).to.equal(24)
			for _, name in PACK_EGG_NAMES do
				local found = false
				for _, egg in Eggs.List do
					if string.find(egg.icon.normalFile, `/{name}/`, 1, true) then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)

		it("has no Golden Rainbow, and every other egg has Golden art", function()
			for _, egg in Eggs.List do
				expect(egg.goldenAllowed).to.equal(egg.id ~= "egg_rainbow")
			end
		end)

		it("sells every world egg for Robux in 1 and 3 packs, never the event egg", function()
			local worldEggs = 0
			for _, egg in Eggs.List do
				if egg.world then
					worldEggs += 1
				end
			end
			expect(worldEggs).to.equal(23)
			expect(#Monetization.RobuxEggs).to.equal(23 * 2)
			for _, product in Monetization.RobuxEggs do
				expect(product.eggId).never.to.equal("egg_party")
			end
		end)
	end)

	describe("World eggs and the event egg", function()
		it("has 23 world eggs and Party as the only event egg", function()
			local worldEggs, eventEggs = 0, {}
			for _, egg in Eggs.List do
				if egg.world ~= nil then
					worldEggs += 1
				else
					table.insert(eventEggs, egg.id)
				end
			end
			expect(worldEggs).to.equal(23)
			expect(#eventEggs).to.equal(1)
			expect(eventEggs[1]).to.equal("egg_party")
		end)

		it("never sells the event egg for Coins or Robux", function()
			local party = Eggs.ById.egg_party
			expect(party.coinPrice).to.equal(nil)
			expect(party.robuxPurchasable).to.equal(false)
			expect(party.oddsBand).to.equal("Event")
			for _, product in Monetization.RobuxEggs do
				expect(product.eggId).never.to.equal("egg_party")
			end
		end)
	end)

	describe("Placeholder content", function()
		it("marks all 24 eggs as placeholder until the roster and pools are designed", function()
			for _, egg in Eggs.List do
				expect(egg.status).to.equal("Placeholder")
			end
		end)

		it("warns about placeholder content in development", function()
			local report = ConfigValidator.validate()
			local found = false
			for _, message in report.warnings do
				if string.find(message, "Placeholder", 1, true) then
					found = true
				end
			end
			expect(found).to.equal(true)
		end)

		it("refuses to start a release build with placeholder eggs", function()
			local report = ConfigValidator.validate({ release = true })
			local eggErrors = 0
			for _, message in report.errors do
				if string.find(message, "placeholder", 1, true) and string.find(message, "egg_", 1, true) then
					eggErrors += 1
				end
			end
			expect(eggErrors).to.equal(24)
		end)
	end)

	describe("Character catalog", function()
		it("ships the seven launch characters with room for 100", function()
			expect(#Characters.List).to.equal(7)
			expect(Characters.MaxCatalogSize).to.equal(100)
		end)
	end)

	describe("Economy config", function()
		it("prices every card storage expansion between start and max", function()
			local cfg = Economy.CardStorage
			expect(#cfg.expansionPrices).to.equal((cfg.maxSlots - cfg.startSlots) / cfg.slotsPerExpansion)
		end)

		it("needs 194 merge points from level 1 to 15", function()
			local total = 0
			for _, n in Economy.Progression.mergePointsToNext do
				total += n
			end
			expect(total).to.equal(194)
			expect(Economy.Progression.maxLevel).to.equal(15)
		end)
	end)
end
