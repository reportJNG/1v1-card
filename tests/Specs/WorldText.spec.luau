--!strict
-- World text and pops (BAD_GUI_THINKING_AND_UI section 4): pooled, never more than the cap active.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PopPool = require(Shared.Ui.PopPool)
local Moments = require(Shared.Ui.Moments)

return function()
	describe("PopPool", function()
		it("reuses released pops instead of making new ones", function()
			local made = 0
			local pool = PopPool.new(20, function()
				made += 1
				return { id = made }
			end)
			local a, _, use = pool:acquire()
			pool:release(a, use)
			local b = pool:acquire()
			expect(b).to.equal(a)
			expect(pool:createdCount()).to.equal(1)
		end)

		it("never has more than the cap active, recycling the oldest", function()
			local n = 0
			local pool = PopPool.new(20, function()
				n += 1
				return { id = n }
			end)
			local first = pool:acquire()
			for _ = 2, 20 do
				pool:acquire()
			end
			expect(pool:activeCount()).to.equal(20)
			local extra, recycled = pool:acquire()
			expect(pool:activeCount()).to.equal(20)
			expect(recycled).to.equal(first)
			expect(extra).to.equal(first)
			expect(pool:createdCount()).to.equal(20)
		end)

		it("ignores the late release of a recycled pop's old use", function()
			local pool = PopPool.new(1, function()
				return {}
			end)
			local a, _, oldUse = pool:acquire()
			local b, recycled, newUse = pool:acquire() -- the same pop, shown again
			expect(b).to.equal(a)
			expect(recycled).to.equal(a)
			expect(pool:current(a, oldUse)).to.equal(false)
			expect(pool:current(b, newUse)).to.equal(true)
			pool:release(a, oldUse) -- the first animation ends late
			expect(pool:activeCount()).to.equal(1)
			pool:release(b, newUse)
			expect(pool:activeCount()).to.equal(0)
			expect(pool:createdCount()).to.equal(1)
		end)
	end)
	describe("Moments", function()
		local function view(highest: number, quests: { [string]: { progress: number, claimed: boolean } })
			return { highestTrophies = highest, quests = quests }
		end

		it("finds nothing on the first snapshot", function()
			expect(#Moments.diff(nil, view(0, {}))).to.equal(0)
		end)

		it("reports quest progress, then completion once", function()
			local before = Moments.snap(view(0, { d_harvest30 = { progress = 10, claimed = false } }))
			local m = Moments.diff(before, view(0, { d_harvest30 = { progress = 12, claimed = false } }))
			expect(#m).to.equal(1)
			expect(m[1].kind).to.equal("questProgress")
			expect((m[1] :: any).delta).to.equal(2)
			before = Moments.snap(view(0, { d_harvest30 = { progress = 29, claimed = false } }))
			m = Moments.diff(before, view(0, { d_harvest30 = { progress = 31, claimed = false } }))
			expect(#m).to.equal(1)
			expect(m[1].kind).to.equal("questComplete")
			before = Moments.snap(view(0, { d_harvest30 = { progress = 31, claimed = false } }))
			expect(#Moments.diff(before, view(0, { d_harvest30 = { progress = 33, claimed = false } }))).to.equal(
				0
			)
		end)

		it("ignores a new day's quests arriving", function()
			local before = Moments.snap(view(0, {}))
			expect(#Moments.diff(before, view(0, { d_hatch3 = { progress = 0, claimed = false } }))).to.equal(
				0
			)
		end)

		it("reports each world a trophy gain unlocks", function()
			local before = Moments.snap(view(90, {}))
			local m = Moments.diff(before, view(260, {}))
			expect(#m).to.equal(2)
			expect((m[1] :: any).world).to.equal(2)
			expect((m[2] :: any).world).to.equal(3)
		end)
	end)
end
