--!strict
-- Persistence scenarios required before M1: two servers, lock expiry and recovery, crashes
-- during saves, failed and retried requests, and shutdown with unsaved changes.
local ServerScriptService = game:GetService("ServerScriptService")
local Persistence = ServerScriptService:WaitForChild("Server").Persistence
local SessionStore = require(Persistence.SessionStore)
local ProfileManager = require(Persistence.ProfileManager)
local MockDataStore = require(script.Parent.Parent.Mocks.MockDataStore)

local USER = 4242
local KEY = `player_{USER}`

-- One shared clock: every simulated server sees the same time.
local function server(store: any, jobId: string, clock: { t: number }): any
	local now = function()
		return clock.t
	end
	local sessions = SessionStore.new(store, {
		jobId = jobId,
		now = now,
		sleep = function(seconds)
			clock.t += seconds
		end,
		lockTimeout = 600,
	})
	return ProfileManager.new(sessions :: any, { now = now, autosaveInterval = 60 })
end

local function value(r: any): any
	assert(r.ok, if r.ok then "" else r.err)
	return r.value
end

local function err(r: any): string
	return if r.ok then "ok" else r.err
end

return function()
	describe("Two servers and the same profile", function()
		it("refuses the second server while the first holds the lock, then hands over on release", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a, b = server(store, "A", clock), server(store, "B", clock)
			value(a:load(USER)).coins = 750
			expect(err(b:load(USER))).to.equal("SessionLocked")
			expect(a:release(USER).ok).to.equal(true)
			expect(value(b:load(USER)).coins).to.equal(750)
			expect(store:peek(KEY).meta.lock.jobId).to.equal("B")
		end)

		it("keeps the lock alive with autosave heartbeats while the player stays", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a, b = server(store, "A", clock), server(store, "B", clock)
			a:load(USER)
			for _ = 1, 20 do -- 20 minutes of play, well past the 600 s lock timeout
				clock.t += 60
				a:autosaveTick()
			end
			expect(err(b:load(USER))).to.equal("SessionLocked")
			expect(a:get(USER)).to.be.ok()
		end)
	end)

	describe("Lock expiry and recovery", function()
		it("lets a new server take over after a crash and stops the old one writing", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			local pa = value(a:load(USER))
			pa.coins = 100
			expect(a:saveNow(USER).ok).to.equal(true)
			pa.coins = 999 -- unsaved when server A "crashes" (stops heartbeating)

			clock.t += 601
			local b = server(store, "B", clock)
			local pb = value(b:load(USER))
			expect(pb.coins).to.equal(100) -- last good save

			-- Server A comes back to life: it must not overwrite B's session.
			expect(err(a:saveNow(USER))).to.equal("LockLost")
			expect(a:get(USER)).to.equal(nil)
			expect(a:isLockLost(USER)).to.equal(true)
			expect(err(a:saveNow(USER))).to.equal("LockLost")
			expect(store:peek(KEY).data.coins).to.equal(100)
			expect(store:peek(KEY).meta.lock.jobId).to.equal("B")
		end)

		it("does not take over a lock that is still inside the timeout", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			server(store, "A", clock):load(USER)
			clock.t += 500
			-- B waits and retries (3 attempts, 5 s apart): still inside the timeout.
			expect(err(server(store, "B", clock):load(USER))).to.equal("SessionLocked")
		end)
	end)

	describe("Crash or failure during a save", function()
		it("keeps the last good save when the write never lands", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			local pa = value(a:load(USER))
			pa.coins = 100
			a:saveNow(USER)
			pa.coins = 500
			store:failNext(100) -- DataStore down; server dies with this save in flight
			expect(err(a:saveNow(USER))).to.equal("DataStoreUnavailable")
			store:failNext(0)

			clock.t += 601
			local pb = value(server(store, "B", clock):load(USER))
			expect(pb.coins).to.equal(100)
			expect(pb.schemaVersion).to.be.ok()
		end)

		it("counts a write that landed but reported failure as saved", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			value(a:load(USER)).coins = 321
			store:failAfterWrite(4) -- every attempt writes, then errors
			expect(a:saveNow(USER).ok).to.equal(true)
			expect(store:peek(KEY).data.coins).to.equal(321)
		end)

		it("retries transient DataStore failures", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			value(a:load(USER)).coins = 42
			store:failNext(2)
			local before = store.updateCalls
			expect(a:saveNow(USER).ok).to.equal(true)
			expect(store.updateCalls - before).to.equal(3)
			expect(store:peek(KEY).data.coins).to.equal(42)
		end)
	end)

	describe("Leaving and rejoining", function()
		it("retries a failed release from the autosave loop instead of dropping the data", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			value(a:load(USER)).coins = 77
			store:failNext(4)
			expect(a:release(USER).ok).to.equal(false)
			expect(a:get(USER)).to.equal(nil) -- not usable while leaving
			expect(a:count()).to.equal(1) -- but still held in memory
			expect(a:autosaveTick()).to.equal(1)
			expect(a:count()).to.equal(0)
			expect(store:peek(KEY).data.coins).to.equal(77)
			expect(store:peek(KEY).meta.lock).to.equal(nil)
		end)

		it("keeps the in-memory profile when the player rejoins before a failed release", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			local first = value(a:load(USER))
			first.coins = 55
			store:failNext(4)
			a:release(USER)
			local again = value(a:load(USER))
			expect(again).to.equal(first)
			expect(a:saveNow(USER).ok).to.equal(true) -- we still hold the lock
			expect(store:peek(KEY).data.coins).to.equal(55)
		end)

		it("loads fresh data when the player rejoins after a completed release", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			local first = value(a:load(USER))
			first.coins = 66
			a:release(USER)
			local again = value(a:load(USER))
			expect(again).never.to.equal(first)
			expect(again.coins).to.equal(66)
		end)
	end)

	describe("Shutdown with unsaved changes", function()
		it("saves and releases every profile, retrying a transient failure", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			for i = 1, 3 do
				value(a:load(i)).coins = i * 100
				a:markDirty(i)
			end
			store:failNext(4) -- the first release of the shutdown fails completely
			local failed = a:releaseAll(3)
			expect(#failed).to.equal(0)
			expect(a:count()).to.equal(0)
			for i = 1, 3 do
				local record = store:peek(`player_{i}`)
				expect(record.data.coins).to.equal(i * 100)
				expect(record.meta.lock).to.equal(nil)
			end
		end)

		it("reports the profiles it could not save", function()
			local store, clock = MockDataStore.new(), { t = 1000 }
			local a = server(store, "A", clock)
			value(a:load(USER)).coins = 1
			store:failNext(1000)
			local failed = a:releaseAll(2)
			expect(#failed).to.equal(1)
			expect(failed[1]).to.equal(USER)
		end)
	end)
end
