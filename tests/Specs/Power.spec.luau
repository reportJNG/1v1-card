--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Power = require(Shared.Domain.Power)
local Characters = require(Shared.Config.Characters)
local Remotes = require(Shared.Net.Remotes)

return function()
	describe("Power (UI numbers)", function()
		it("grows with level", function()
			local id = Characters.List[1].id
			expect(Power.card(id, 15) > Power.card(id, 1)).to.equal(true)
		end)

		it("sums a deck and reports the family bonus a battle would apply", function()
			local deck = {
				{ characterId = "ren_emberfang", level = 5 },
				{ characterId = "yuki_frostveil", level = 5 },
				{ characterId = "rai_stormvolt", level = 5 },
			}
			local p = Power.deck(deck)
			expect(#p.units).to.equal(3)
			expect(p.total).to.equal(p.units[1].power + p.units[2].power + p.units[3].power)
			for _, f in p.families do
				expect(f.count >= 2).to.equal(true)
			end
		end)
	end)

	describe("Settings.Set payload", function()
		it("accepts the volumes as whole percentages from 0 to 100", function()
			local parse = Remotes.Requests["Settings.Set"].parse
			expect(parse({ key = "musicVolume", value = 40 })).to.be.ok()
			expect(parse({ key = "sfxVolume", value = 0 })).to.be.ok()
			expect(parse({ key = "musicVolume", value = 101 })).to.equal(nil)
			expect(parse({ key = "sfxVolume", value = 0.5 })).to.equal(nil)
			expect(parse({ key = "musicVolume", value = true })).to.equal(nil)
			expect(parse({ key = "music", value = 50 })).to.equal(nil)
		end)

		it("accepts only the known boolean settings", function()
			local parse = Remotes.Requests["Settings.Set"].parse
			expect(parse({ key = "music", value = false })).to.be.ok()
			expect(parse({ key = "reducedMotion", value = true })).to.be.ok()
			expect(parse({ key = "coins", value = true })).to.equal(nil)
			expect(parse({ key = "music", value = "yes" })).to.equal(nil)
			expect(parse({ key = "music", value = true, extra = 1 })).to.equal(nil)
		end)
	end)
end
