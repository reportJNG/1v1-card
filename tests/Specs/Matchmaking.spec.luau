--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local MM = ServerScriptService.Server.Matchmaking
local Pairing = require(MM.Pairing)
local Lease = require(MM.Lease)
local Queue = require(MM.Queue)
local MatchRecord = require(MM.MatchRecord)
local Matchmaker = require(MM.Matchmaker)
local MockMemoryStore = require(script.Parent.Parent.Mocks.MockMemoryStore)

local function ticket(userId: number, trophies: number, queuedAt: number, league: string?): any
	return {
		userId = userId,
		trophies = trophies,
		league = league or "Bronze",
		queuedAt = queuedAt,
		server = "hub-1",
	}
end

local function pairIds(pairs: { { any } }): string
	local out = {}
	for _, p in pairs do
		local a, b = p[1].userId, p[2].userId
		table.insert(out, `{math.min(a, b)}-{math.max(a, b)}`)
	end
	table.sort(out)
	return table.concat(out, ",")
end

local function newQueue(clock: { t: number }): (any, any)
	local map = MockMemoryStore.new(clock)
	return Queue.new(map :: any, { ttl = 120, ascending = MockMemoryStore.Ascending }), map
end

return function()
	describe("Pairing", function()
		it("widens the trophy band by 50 every 10 s, from ±100 to ±400", function()
			expect(Pairing.band(0)).to.equal(100)
			expect(Pairing.band(9.9)).to.equal(100)
			expect(Pairing.band(10)).to.equal(150)
			expect(Pairing.band(35)).to.equal(250)
			expect(Pairing.band(60)).to.equal(400)
			expect(Pairing.band(600)).to.equal(400)
		end)

		it("pairs within the band and leaves a lone or distant player waiting", function()
			local t = { ticket(1, 1000, 0), ticket(2, 1090, 0), ticket(3, 1500, 0) }
			expect(pairIds(Pairing.pair(t, 0))).to.equal("1-2")
			expect(#Pairing.pair({ ticket(1, 0, 0) }, 0)).to.equal(0)
			expect(#Pairing.pair({ ticket(1, 0, 0), ticket(2, 150, 0) }, 0)).to.equal(0)
		end)

		it("pairs distant players once one of them has waited long enough", function()
			local t = { ticket(1, 0, 0), ticket(2, 250, 30) }
			expect(#Pairing.pair(t, 29)).to.equal(0) -- ticket 1 has waited 29 s: band ±200
			expect(#Pairing.pair(t, 30)).to.equal(1) -- 30 s: band ±250
		end)

		it("never pairs across leagues, even at the widest band", function()
			local t = { ticket(1, 690, 0, "Bronze"), ticket(2, 700, 0, "Silver") }
			expect(#Pairing.pair(t, 600)).to.equal(0)
		end)

		it("serves the oldest ticket first with its closest opponent", function()
			local t = { ticket(1, 1000, 0), ticket(2, 1080, 5), ticket(3, 1010, 5), ticket(4, 1090, 6) }
			expect(pairIds(Pairing.pair(t, 6))).to.equal("1-3,2-4")
		end)

		it("never pairs a player with themselves", function()
			expect(#Pairing.pair({ ticket(1, 0, 0), ticket(1, 0, 0) }, 0)).to.equal(0)
		end)
	end)

	describe("Lease", function()
		it("gives the lease to one server, renews it for the holder, and hands it over on expiry", function()
			local clock = { t = 0 }
			local store = MockMemoryStore.new(clock)
			expect(Lease.tryAcquire(store :: any, "k", "A", 0, 6)).to.equal(true)
			expect(Lease.tryAcquire(store :: any, "k", "B", 1, 6)).to.equal(false)
			expect(Lease.tryAcquire(store :: any, "k", "A", 5, 6)).to.equal(true) -- renewed to 11
			clock.t = 10
			expect(Lease.tryAcquire(store :: any, "k", "B", 10, 6)).to.equal(false)
			clock.t = 11
			expect(Lease.tryAcquire(store :: any, "k", "B", 11, 6)).to.equal(true)
		end)

		it("reports no lease when MemoryStore fails", function()
			local store = MockMemoryStore.new({ t = 0 })
			store:failNext(1)
			expect(Lease.tryAcquire(store :: any, "k", "A", 0, 6)).to.equal(false)
		end)
	end)

	describe("Queue", function()
		it("lists waiting tickets oldest first, and expires them after the TTL", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			q:join(ticket(2, 0, 5))
			q:join(ticket(1, 0, 1))
			local w = q:waiting(10)
			assert(w.ok, "waiting")
			expect(w.value[1].userId).to.equal(1)
			expect(w.value[2].userId).to.equal(2)
			clock.t = 200
			local later = q:waiting(10)
			assert(later.ok, "waiting")
			expect(#later.value).to.equal(0)
		end)

		it("claims both tickets or neither", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			q:join(ticket(1, 0, 0))
			q:join(ticket(2, 0, 0))
			expect(q:claim(1, 2, { matchId = "m1" })).to.equal(true)
			local t1 = q:get(1)
			assert(t1.ok and t1.value, "ticket")
			expect((t1.value :: any).match.matchId).to.equal("m1")
			-- already claimed: a second match can't take either player
			q:join(ticket(3, 0, 0))
			expect(q:claim(3, 1, { matchId = "m2" })).to.equal(false)
			local t3 = q:get(3)
			assert(t3.ok and t3.value, "ticket")
			expect((t3.value :: any).match).to.equal(nil) -- reverted
		end)

		it("never claims a ticket whose player left; leave after a claim reports Matched", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			q:join(ticket(1, 0, 0))
			q:join(ticket(2, 0, 0))
			local left = q:leave(2)
			assert(left.ok, "leave")
			expect(left.value).to.equal("Left")
			expect(q:claim(1, 2, { matchId = "m1" })).to.equal(false)
			q:join(ticket(2, 0, 0))
			expect(q:claim(1, 2, { matchId = "m1" })).to.equal(true)
			local late = q:leave(1)
			assert(late.ok, "leave")
			expect(late.value).to.equal("Matched")
		end)

		it("refresh keeps a waiting ticket alive but never revives a matched or removed one", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			q:join(ticket(1, 0, 0))
			clock.t = 100
			q:refresh(1)
			clock.t = 200
			local t = q:get(1)
			assert(t.ok, "get")
			expect(t.value ~= nil).to.equal(true)
			q:remove(1)
			q:refresh(1)
			local gone = q:get(1)
			assert(gone.ok, "get")
			expect(gone.value).to.equal(nil)
		end)

		it("ignores malformed tickets", function()
			local clock = { t = 0 }
			local q, map = newQueue(clock)
			map:SetAsync("9", { userId = "nope" }, 120, 0)
			map:SetAsync("8", "garbage", 120, 0)
			q:join(ticket(1, 0, 0))
			local w = q:waiting(10)
			assert(w.ok, "waiting")
			expect(#w.value).to.equal(1)
		end)

		it("returns StoreError instead of throwing when MemoryStore fails", function()
			local q, map = newQueue({ t = 0 })
			map:failNext(1)
			local r = q:join(ticket(1, 0, 0))
			expect(r.ok).to.equal(false)
			map:failNext(1)
			expect(q:claim(1, 2, { matchId = "x" })).to.equal(false)
		end)
	end)

	describe("MatchRecord", function()
		it("parses only well-formed records", function()
			local r = MatchRecord.new("m", 7, ticket(1, 10, 0), ticket(2, 20, 0), 100)
			expect(MatchRecord.parse(r)).to.be.ok()
			expect(MatchRecord.parse(nil)).to.equal(nil)
			expect(MatchRecord.parse({ matchId = "m" })).to.equal(nil)
			local bad = table.clone(r) :: any
			bad.league = "Platinum"
			expect(MatchRecord.parse(bad)).to.equal(nil)
			local same = table.clone(r) :: any
			same.seats = { { userId = 1, trophies = 0 }, { userId = 1, trophies = 0 } }
			expect(MatchRecord.parse(same)).to.equal(nil)
		end)

		it("gives each player their side and the league level cap", function()
			local r = MatchRecord.new("m", 7, ticket(5, 10, 0), ticket(6, 20, 0), 100)
			expect(MatchRecord.sideOf(r, 5)).to.equal(1)
			expect(MatchRecord.sideOf(r, 6)).to.equal(2)
			expect(MatchRecord.sideOf(r, 7)).to.equal(nil)
			expect(MatchRecord.levelCap(r)).to.equal(4)
			local gold = MatchRecord.new("g", 1, ticket(1, 1400, 0, "Gold"), ticket(2, 1400, 0, "Gold"), 0)
			expect(MatchRecord.levelCap(gold)).to.equal(12)
		end)
	end)

	describe("Matchmaker", function()
		local function setup(jobId: string, clock: { t: number }, queue: any, lease: any, records: { any })
			local n = 0
			return Matchmaker.new({
				queue = queue,
				leaseStore = lease,
				jobId = jobId,
				now = function()
					return clock.t
				end,
				reserve = function()
					return `code-{jobId}`, `ps-{jobId}`
				end,
				writeRecord = function(record)
					table.insert(records, record)
					return true
				end,
				newMatchId = function()
					n += 1
					return `{jobId}-m{n}`
				end,
				newSeed = function()
					return 42
				end,
			})
		end

		it("matches each queued pair exactly once, even with two Hub servers ticking", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			local lease = MockMemoryStore.new(clock)
			local records = {}
			local hubA = setup("A", clock, q, lease, records)
			local hubB = setup("B", clock, q, lease, records)
			for i = 1, 6 do
				q:join(ticket(i, 1000 + i, 0))
			end
			local made = 0
			for _ = 1, 3 do
				made += #hubA:tick()
				made += #hubB:tick()
				clock.t += 2
			end
			expect(made).to.equal(3)
			local seen = {}
			for i = 1, 6 do
				local t = q:get(i)
				assert(t.ok and t.value, "ticket")
				local m = (t.value :: any).match
				expect(m).to.be.ok()
				expect(m.accessCode).to.equal("code-A") -- only the lease holder made matches
				seen[m.matchId] = (seen[m.matchId] or 0) + 1
			end
			for _, count in seen do
				expect(count).to.equal(2)
			end
		end)

		it("leaves both players queued when ReserveServer fails", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			local records = {}
			local mm = Matchmaker.new({
				queue = q,
				leaseStore = MockMemoryStore.new(clock) :: any,
				jobId = "A",
				now = function()
					return clock.t
				end,
				reserve = function(): (string?, string?)
					error("HTTP 503")
				end,
				writeRecord = function(record)
					table.insert(records, record)
					return true
				end,
				newMatchId = function()
					return "m"
				end,
				newSeed = function()
					return 1
				end,
			})
			q:join(ticket(1, 0, 0))
			q:join(ticket(2, 0, 0))
			expect(#mm:tick()).to.equal(0)
			expect(#records).to.equal(0)
			local w = q:waiting(10)
			assert(w.ok, "waiting")
			expect(#w.value).to.equal(2)
		end)

		it("writes the match record before claiming, so a claimed pair always has one", function()
			local clock = { t = 0 }
			local q = newQueue(clock)
			local records = {}
			local mm = setup("A", clock, q, MockMemoryStore.new(clock), records)
			q:join(ticket(1, 0, 0))
			q:join(ticket(2, 0, 0))
			local made = mm:tick()
			expect(#made).to.equal(1)
			expect(#records).to.equal(1)
			expect(records[1].matchId).to.equal(made[1].matchId)
			expect(records[1].privateServerId).to.equal("ps-A")
			expect(MatchRecord.parse(records[1])).to.be.ok()
		end)
	end)
end
