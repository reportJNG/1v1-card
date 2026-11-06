--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hatch = require(Shared.Domain.Hatch)
local Cards = require(Shared.Domain.Cards)
local SessionStore = require(ServerScriptService:WaitForChild("Server").Persistence.SessionStore)
local MockDataStore = require(script.Parent.Parent.Mocks.MockDataStore)

local USER = 4242

local function makeServer(store: any, jobId: string, clock: { t: number })
	return SessionStore.new(store, {
		jobId = jobId,
		now = function()
			return clock.t
		end,
		sleep = function(seconds)
			clock.t += seconds
		end,
		lockTimeout = 600,
	})
end

local function err(r: any): string
	return if r.ok then "" else r.err
end

return function()
	describe("SessionStore save and load", function()
		it("creates, saves and reloads a profile with its cards and provenance intact", function()
			local store = MockDataStore.new()
			local clock = { t = 1000 }
			local a = makeServer(store, "server-A", clock)
			local loaded = a:load(USER)
			expect(loaded.ok).to.equal(true)
			local p = if loaded.ok then loaded.value else nil :: any
			p.coins = 5000
			local product = { key = "egg_basic_x1", eggId = "egg_basic", quantity = 1, productId = 1 }
			Hatch.grantRobux(p, product, "PURCHASE-77", Random.new(1), clock.t)
			expect(a:release(USER, p).ok).to.equal(true)

			local b = makeServer(store, "server-B", clock)
			local again = b:load(USER)
			expect(again.ok).to.equal(true)
			local q = if again.ok then again.value else nil :: any
			expect(q.coins).to.equal(5000)
			expect(Cards.count(q)).to.equal(1)
			for _, card in q.cards do
				expect(card.origin).to.equal("Robux")
				expect(card.provenance.paidLineage).to.equal(true)
				expect(card.provenance.paidRefs[1]).to.equal("PURCHASE-77")
			end
			expect(q.processedReceipts["PURCHASE-77"]).to.be.ok()
		end)

		it("blocks a second server while the first holds a live lock", function()
			local store = MockDataStore.new()
			local clock = { t = 1000 }
			makeServer(store, "server-A", clock):load(USER)
			local b = makeServer(store, "server-B", { t = 1001 })
			expect(err(b:load(USER))).to.equal("SessionLocked")
		end)

		it("takes over a stale lock from a crashed server", function()
			local store = MockDataStore.new()
			makeServer(store, "server-A", { t = 1000 }):load(USER)
			local b = makeServer(store, "server-B", { t = 1000 + 601 })
			expect(b:load(USER).ok).to.equal(true)
			expect(store:peek(`player_{USER}`).meta.lock.jobId).to.equal("server-B")
		end)

		it("stops a server that lost its lock from overwriting newer data", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			local pa = a:load(USER)
			local b = makeServer(store, "server-B", { t = 2000 })
			local pb = b:load(USER) -- stale-lock takeover
			expect(pb.ok).to.equal(true)
			local profileA = if pa.ok then pa.value else nil :: any
			profileA.coins = 999999
			expect(err(a:save(USER, profileA))).to.equal("LockLost")
			expect(store:peek(`player_{USER}`).data.coins).to.equal(0)
		end)

		it("lets the next server load right after a release", function()
			local store = MockDataStore.new()
			local clock = { t = 1000 }
			local a = makeServer(store, "server-A", clock)
			local p = a:load(USER)
			a:release(USER, if p.ok then p.value else nil :: any)
			expect(makeServer(store, "server-B", { t = 1001 }):load(USER).ok).to.equal(true)
		end)

		it("retries transient failures", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			store:failNext(2)
			expect(a:load(USER).ok).to.equal(true)
		end)

		it("counts a write that reported failure but landed as saved", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			local loaded = a:load(USER)
			local p = if loaded.ok then loaded.value else nil :: any
			p.coins = 321
			store:failAfterWrite(1)
			store:failNext(0)
			-- First attempt writes then errors; the retry sees our own lock and writes again.
			expect(a:save(USER, p).ok).to.equal(true)
			expect(store:peek(`player_{USER}`).data.coins).to.equal(321)
		end)

		it("verifies by reading back when every attempt reports failure", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			local loaded = a:load(USER)
			local p = if loaded.ok then loaded.value else nil :: any
			p.coins = 55
			store:failAfterWrite(4) -- all 4 attempts land, all report failure
			expect(a:save(USER, p).ok).to.equal(true)
			expect(store:peek(`player_{USER}`).data.coins).to.equal(55)
		end)

		it("reports failure when the store is down and nothing landed", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			local loaded = a:load(USER)
			local p = if loaded.ok then loaded.value else nil :: any
			store:failNext(10)
			store:failGets(1)
			expect(err(a:save(USER, p))).to.equal("DataStoreUnavailable")
		end)

		it("never writes an invalid profile", function()
			local store = MockDataStore.new()
			local a = makeServer(store, "server-A", { t = 1000 })
			local loaded = a:load(USER)
			local p = if loaded.ok then loaded.value else nil :: any
			p.coins = -1
			local found = string.find(err(a:save(USER, p)), "InvalidProfile", 1, true)
			expect(found).to.be.ok()
			expect(store:peek(`player_{USER}`).data.coins).to.equal(0)
		end)

		it("refuses to load, and leaves untouched, data from a newer version", function()
			local store = MockDataStore.new()
			store:poke(`player_{USER}`, { meta = {}, data = { schemaVersion = 99 } })
			local a = makeServer(store, "server-A", { t = 1000 })
			expect(err(a:load(USER))).to.equal("ProfileFromNewerVersion")
			expect(store:peek(`player_{USER}`).data.schemaVersion).to.equal(99)
			expect(store:peek(`player_{USER}`).meta.lock).to.equal(nil)
		end)
	end)
end
