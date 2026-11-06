--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Odds = require(Shared.Domain.Odds)
local Eggs = require(Shared.Config.Eggs)

local function total(odds: Odds.EggOdds): number
	local sum = 0
	for _, entry in odds.characters do
		sum += entry.percent
	end
	return sum
end

return function()
	describe("Odds.forEgg", function()
		it("totals 100% for every egg, normal and Golden", function()
			for _, egg in Eggs.List do
				expect(total(Odds.forEgg(egg, false))).to.be.near(100, 1e-9)
				if egg.goldenAllowed then
					expect(total(Odds.forEgg(egg, true))).to.be.near(100, 1e-9)
				end
			end
		end)

		it("uses the band odds and splits a rarity equally inside the pool", function()
			local egg = Eggs.ById.egg_dragon -- band C: every rarity has characters in its pool
			local odds = Odds.forEgg(egg, false)
			expect(odds.rarities.Common).to.be.near(45, 1e-9)
			expect(odds.rarities.Mythical).to.be.near(0.5, 1e-9)
			for _, entry in odds.characters do
				local share = odds.rarities[entry.rarity] / #egg.pool[entry.rarity]
				expect(entry.percent).to.be.near(share, 1e-9)
			end
		end)

		it("removes Common for Golden eggs and redistributes proportionally", function()
			local odds = Odds.forEgg(Eggs.ById.egg_basic, true) -- band A: 72/24/3.6/0.4/0
			expect(odds.rarities.Common).to.equal(0)
			expect(odds.rarities.Rare).to.be.near(24 / 28 * 100, 1e-9)
			expect(odds.rarities.Epic).to.be.near(3.6 / 28 * 100, 1e-9)
			expect(odds.rarities.Legendary).to.be.near(0.4 / 28 * 100, 1e-9)
		end)

		it("omits zero-chance characters (no Mythical in band A)", function()
			for _, entry in Odds.forEgg(Eggs.ById.egg_basic, false).characters do
				expect(entry.rarity).never.to.equal("Mythical")
			end
		end)

		it("redistributes a rarity whose pool is empty", function()
			local egg: Types.EggDef = table.clone(Eggs.ById.egg_dragon)
			egg.pool = { Common = { "rai_stormvolt" }, Rare = { "ren_emberfang" } } :: any
			local odds = Odds.forEgg(egg, false)
			expect(odds.rarities.Common).to.be.near(45 / 81 * 100, 1e-9)
			expect(odds.rarities.Rare).to.be.near(36 / 81 * 100, 1e-9)
			expect(total(odds)).to.be.near(100, 1e-9)
		end)

		it("refuses a Golden Rainbow", function()
			expect(function()
				Odds.forEgg(Eggs.ById.egg_rainbow, true)
			end).to.throw()
		end)
	end)

	describe("Odds.roll", function()
		it("matches the disclosed odds over 200,000 rolls", function()
			local egg = Eggs.ById.egg_mythical -- band E, every rarity present
			local odds = Odds.forEgg(egg, false)
			local rng = Random.new(42)
			local n = 200000
			local counts: { [string]: number } = {}
			for _ = 1, n do
				local id = Odds.roll(egg, false, rng).characterId
				counts[id] = (counts[id] or 0) + 1
			end
			for _, entry in odds.characters do
				local p = entry.percent / 100
				local expected = n * p
				local sigma = math.sqrt(n * p * (1 - p))
				expect(math.abs((counts[entry.characterId] or 0) - expected) < 4 * sigma).to.equal(true)
			end
		end)

		it("is reproducible for the same seed", function()
			local a, b = Random.new(7), Random.new(7)
			for _ = 1, 50 do
				expect(Odds.roll(Eggs.ById.egg_ice, false, a).characterId).to.equal(
					Odds.roll(Eggs.ById.egg_ice, false, b).characterId
				)
			end
		end)
	end)

	describe("Odds.display", function()
		it("formats whole and fractional percentages", function()
			expect((Odds.formatPercent(36))).to.equal("36%")
			expect((Odds.formatPercent(22.5))).to.equal("22.5%")
			local text, rounded = Odds.formatPercent(100 / 7)
			expect(text).to.equal("14.286%")
			expect(rounded).to.equal(true)
			expect((Odds.formatPercent(0.05))).to.equal("0.05%")
		end)

		it("lists every possible character before purchase", function()
			local egg = Eggs.ById.egg_mythical
			local rows = Odds.display(egg, false)
			local n = 0
			for _, ids in egg.pool do
				n += #ids
			end
			expect(#rows).to.equal(n)
		end)
	end)
end
