--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local Helpers = require(script.Parent.Parent.Helpers)

return function()
	describe("ProfileSchema", function()
		it("creates a valid new profile for a first-time player", function()
			local r = ProfileSchema.load(nil, 77)
			expect(r.ok).to.equal(true)
			local p = if r.ok then r.value else nil :: any
			expect(p.uidPrefix).to.equal("77")
			expect(p.schemaVersion).to.equal(ProfileSchema.CURRENT_VERSION)
			expect(ProfileSchema.validate(p :: any).ok).to.equal(true)
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
			}
			local r = ProfileSchema.load(raw, 1, migrations)
			expect(r.ok).to.equal(true)
			expect(if r.ok then r.value.coins else 0).to.equal(21)
			expect(if r.ok then r.value.schemaVersion else 0).to.equal(3)
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
