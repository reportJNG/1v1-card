--!strict
-- "5-card mode" (PLAN.md section 5): only Config/Roster.active characters drop from eggs, start a
-- new profile's deck or fight as Guardians; the odds shown are the odds rolled.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Odds = require(Shared.Domain.Odds)
local Eggs = require(Shared.Config.Eggs)
local Roster = require(Shared.Config.Roster)
local Economy = require(Shared.Config.Economy)
local Guardians = require(Shared.Config.Guardians)
local Characters = require(Shared.Config.Characters)
local OddsBands = require(Shared.Config.OddsBands)

local ACTIVE: { [string]: boolean } = {}
for _, id in Roster.active do
	ACTIVE[id] = true
end

local function each(fn: (any, boolean) -> ())
	for _, egg in Eggs.List do
		fn(egg, false)
		if egg.goldenAllowed then
			fn(egg, true)
		end
	end
end

return function()
	describe("Roster.active", function()
		it("lists known, enabled, different characters covering every rarity (five plus set 02)", function()
			expect(#Roster.active).to.equal(8)
			local seen: { [string]: boolean } = {}
			local rarities: { [string]: boolean } = {}
			for _, id in Roster.active do
				local def = Characters.ById[id]
				expect(def).to.be.ok()
				expect(def.enabled).to.equal(true)
				expect(seen[id]).to.equal(nil)
				seen[id] = true
				rarities[def.rarity] = true
			end
			for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
				expect(rarities[rarity]).to.equal(true)
			end
		end)

		it(
			"shows the names from NEW_5_CHARACTERS.md and NEW_ASSETS_LEVEL1.md set 02, ids unchanged",
			function()
				local names = {
					rai_stormvolt = "Zephyr Volt",
					ren_emberfang = "Rook Emberforge",
					yuki_frostveil = "Halvard Frostwarden",
					vesper_shade = "Nox Veilstrider",
					aurelia_dawn = "Solaris Dawnbringer",
					brann_cinderfall = "Brann Cinderfall",
					kael_voidbinder = "Kael Voidbinder",
					aurex_sunforge = "Aurex Sunforge",
				}
				for _, id in Roster.active do
					expect(Characters.ById[id].displayName).to.equal(names[id])
				end
			end
		)
	end)

	describe("egg odds with the active roster", function()
		it("drops only active characters, from every egg, normal and Golden", function()
			each(function(egg, golden)
				for _, entry in Odds.forEgg(egg, golden).characters do
					expect(ACTIVE[entry.characterId]).to.equal(true)
				end
			end)
		end)

		it("totals 100% for every egg, normal and Golden", function()
			each(function(egg, golden)
				local sum = 0
				for _, entry in Odds.forEgg(egg, golden).characters do
					sum += entry.percent
				end
				expect(sum).to.be.near(100, 1e-9)
			end)
		end)

		it("keeps each egg's band odds for every rarity its pool lists and the roster has", function()
			each(function(egg, golden)
				local band = OddsBands[egg.oddsBand]
				local odds = Odds.forEgg(egg, golden)
				local total = 0
				for rarity, ids in egg.pool do
					if #ids > 0 and not (golden and rarity == "Common") then
						total += band[rarity] or 0
					end
				end
				for rarity, ids in egg.pool do
					if #ids > 0 and not (golden and rarity == "Common") and (band[rarity] or 0) > 0 then
						expect(odds.rarities[rarity]).to.be.near(band[rarity] / total * 100, 1e-9)
					end
				end
			end)
		end)

		it("never adds a rarity the egg's own pool doesn't list", function()
			each(function(egg, golden)
				local odds = Odds.forEgg(egg, golden)
				for rarity, percent in odds.rarities do
					if percent > 0 then
						expect(egg.pool[rarity] ~= nil and #egg.pool[rarity] > 0).to.equal(true)
					end
				end
			end)
		end)

		it("rolls only active characters, matching the shown odds", function()
			local egg = Eggs.ById.egg_basic
			local rng = Random.new(7)
			local seen: { [string]: number } = {}
			for _ = 1, 4000 do
				local entry = Odds.roll(egg, false, rng)
				expect(ACTIVE[entry.characterId]).to.equal(true)
				seen[entry.characterId] = (seen[entry.characterId] or 0) + 1
			end
			for _, entry in Odds.forEgg(egg, false).characters do
				if entry.percent >= 10 then
					expect((seen[entry.characterId] or 0) / 4000 * 100).to.be.near(entry.percent, 3)
				end
			end
		end)
	end)

	describe("starter deck and Guardians", function()
		it("gives three different active characters as the starter deck", function()
			expect(#Economy.StarterCards).to.equal(3)
			local seen: { [string]: boolean } = {}
			for _, id in Economy.StarterCards do
				expect(ACTIVE[id]).to.equal(true)
				expect(seen[id]).to.equal(nil)
				seen[id] = true
			end
		end)

		it("fields only active characters in every Guardian deck", function()
			for _, guardian in Guardians.List do
				expect(#guardian.deck).to.equal(3)
				for _, spec in guardian.deck do
					expect(ACTIVE[spec.characterId]).to.equal(true)
				end
			end
		end)
	end)
end
