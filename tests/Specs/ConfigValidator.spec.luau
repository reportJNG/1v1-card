--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ConfigValidator = require(Shared.Domain.ConfigValidator)
local Eggs = require(Shared.Config.Eggs)
local Characters = require(Shared.Config.Characters)
local Monetization = require(Shared.Config.Monetization)
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local WorldProps = require(Shared.Config.WorldProps)
local ItemArt = require(Shared.Domain.ItemArt)

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

		it(
			"refuses a release build while UI images are TEMP stand-ins, and only warns in development",
			function()
				local release = ConfigValidator.validate({ release = true })
				local tempErrors = 0
				for _, message in release.errors do
					if string.find(message, "TEMP stand-in", 1, true) then
						tempErrors += 1
					end
				end
				expect(tempErrors > 0).to.equal(true)
				local dev = ConfigValidator.validate()
				for _, message in dev.errors do
					expect((string.find(message, "UiAssets", 1, true))).to.equal(nil)
				end
			end
		)
	end)

	describe("Art briefs", function()
		it("gives every character a complete look with three #RRGGBB colours led by its family", function()
			local Art = require(Shared.Config.Art)
			for _, c in Characters.List do
				expect(c.look).to.be.ok()
				expect(#c.look.colors).to.equal(3)
				expect(c.look.colors[1]).to.equal(Art.FamilyColors[c.family].body)
				expect(c.look.colors[2]).to.equal(Art.FamilyColors[c.family].accent)
				expect(#c.look.outfit > 0 and #c.look.weapon > 0 and #c.look.silhouette > 0).to.equal(true)
			end
		end)
	end)

	describe("Character catalog", function()
		it("ships the full 100-character roster, launch characters first and unchanged in order", function()
			expect(#Characters.List).to.equal(100)
			expect(Characters.MaxCatalogSize).to.equal(100)
			local launch = {
				"ren_emberfang",
				"yuki_frostveil",
				"rai_stormvolt",
				"vesper_shade",
				"aurelia_dawn",
				"brannok_ironhide",
				"taren_ashscale",
			}
			for i, id in launch do
				expect(Characters.List[i].id).to.equal(id)
			end
		end)

		it("puts every character in 6-10 character egg pools, each in at least one egg", function()
			local seen = {}
			for _, egg in Eggs.List do
				local n = 0
				for rarity, ids in egg.pool do
					for _, id in ids do
						n += 1
						seen[id] = true
						expect(Characters.ById[id].rarity).to.equal(rarity)
					end
				end
				expect(n >= 6 and n <= 10).to.equal(true)
			end
			for _, c in Characters.List do
				expect(seen[c.id]).to.equal(true)
			end
		end)
	end)

	describe("Item icons", function()
		it("gives every item its own icon slot and its own resource-node model", function()
			local icons: { [string]: string } = {}
			local models: { [string]: string } = {}
			for _, item in Items.List do
				expect(icons[item.icon]).to.equal(nil)
				icons[item.icon] = item.id
				local model = ItemArt.nodeModel(item.id)
				expect(model).to.be.ok()
				expect(WorldProps.Models[model :: string]).to.be.ok()
				expect(models[model :: string]).to.equal(nil)
				models[model :: string] = item.id
			end
		end)

		it("shows the Oak Log as the oak-log pile, never a crystal", function()
			local model = ItemArt.nodeModel("item_oak_log") :: string
			expect(model).to.equal("w1_oak_log")
			local note = string.lower(WorldProps.Models[model].note)
			expect((string.find(note, "crystal", 1, true))).to.equal(nil)
		end)
	end)

	describe("UI kit", function()
		it("draws every kit piece: LIVE with its image, TEMP with a real fallback slot", function()
			local UiKit = require(Shared.Config.UiKit)
			local UiAssets = require(Shared.Config.UiAssets)
			local n = 0
			for _, piece in UiKit.Pieces do
				n += 1
				expect(piece.id ~= nil or UiAssets[piece.fallback :: string] ~= nil).to.equal(true)
			end
			expect(n > 0).to.equal(true)
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
