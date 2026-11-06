--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared.Config.Battle)
local MatchHost = require(ServerScriptService.Server.Battle.MatchHost)

local DECK_A = {
	{ characterId = "ren_emberfang", level = 5 },
	{ characterId = "yuki_frostveil", level = 5 },
	{ characterId = "rai_stormvolt", level = 5 },
}
local DECK_B = {
	{ characterId = "vesper_shade", level = 5 },
	{ characterId = "aurelia_dawn", level = 5 },
	{ characterId = "brannok_ironhide", level = 5 },
}

type Harness = {
	host: MatchHost.MatchHost,
	clock: { t: number },
	sent: { { userId: number, push: string, data: any } },
	ended: { any },
}

local function harness(): Harness
	local clock = { t = 0 }
	local sent = {}
	local ended = {}
	local host = MatchHost.new({
		now = function()
			return clock.t
		end,
		send = function(userId, push, data)
			table.insert(sent, { userId = userId, push = push, data = data })
		end,
		onEnd = function(record, result)
			table.insert(ended, { record = record, result = result })
			local out = {}
			for _, seat in record.seats do
				if seat.userId then
					out[seat.userId] = { coins = 1 }
				end
			end
			return out
		end,
		reconnectSeconds = 30,
	})
	return { host = host, clock = clock, sent = sent, ended = ended }
end

local function ranked(h: Harness, id: string?)
	local r = h.host:create({
		matchId = id or "m1",
		mode = "Ranked",
		seed = 11,
		seats = {
			{ userId = 1, name = "A", deck = DECK_A, trophies = 0 },
			{ userId = 2, name = "B", deck = DECK_B, trophies = 0 },
		},
	})
	assert(r.ok, if r.ok then "" else r.err)
end

local function lastTo(h: Harness, userId: number, push: string): any
	for i = #h.sent, 1, -1 do
		local s = h.sent[i]
		if s.userId == userId and s.push == push then
			return s.data
		end
	end
	return nil
end

local function round(h: Harness): number
	local _, side = h.host:seatOf(1)
	assert(side, "in match")
	local packet = lastTo(h, 1, "Battle.Round")
	return packet.data.view.round
end

return function()
	describe("MatchHost", function()
		it("sends both players the start packet with their own side", function()
			local h = harness()
			ranked(h)
			expect(lastTo(h, 1, "Battle.Start").you).to.equal(1)
			expect(lastTo(h, 2, "Battle.Start").you).to.equal(2)
			expect(lastTo(h, 1, "Battle.Round").kind).to.equal("RoundOpen")
			expect(h.host:isInMatch(1)).to.equal(true)
		end)

		it("refuses a player who is already in a match, and a duplicate matchId", function()
			local h = harness()
			ranked(h)
			local again = h.host:create({
				matchId = "m2",
				mode = "Ranked",
				seed = 1,
				seats = {
					{ userId = 1, name = "A", deck = DECK_A },
					{ userId = 3, name = "C", deck = DECK_B },
				},
			})
			expect(if again.ok then "" else again.err).to.equal("AlreadyInMatch")
			local dup = h.host:create({
				matchId = "m1",
				mode = "Ranked",
				seed = 1,
				seats = {
					{ userId = 4, name = "D", deck = DECK_A },
					{ userId = 5, name = "E", deck = DECK_B },
				},
			})
			expect(if dup.ok then "" else dup.err).to.equal("MatchExists")
		end)

		it("only accepts picks from the two players in the match", function()
			local h = harness()
			ranked(h)
			local r = h.host:pick(99, 1, "Attack")
			expect(if r.ok then "" else r.err).to.equal("NotInMatch")
			expect(h.host:pick(1, 1, "Attack").ok).to.equal(true)
			expect(h.host:pick(2, 1, "Attack").ok).to.equal(true)
			expect(lastTo(h, 2, "Battle.Round").kind).to.equal("RoundOpen")
			expect(round(h)).to.equal(2)
		end)

		it("plays a Guardian Trial against the AI, which picks on its own", function()
			local h = harness()
			local r = h.host:create({
				matchId = "trial",
				mode = "Trial",
				worldId = 1,
				seed = 5,
				seats = {
					{ userId = 1, name = "A", deck = DECK_A },
					{ name = "Warden Moss", deck = DECK_B },
				},
			})
			assert(r.ok, "create")
			for _ = 1, 200 do
				if not h.host:isInMatch(1) then
					break
				end
				local packet = lastTo(h, 1, "Battle.Round")
				if packet.data.view and packet.data.view.phase == "Picking" then
					h.host:pick(1, packet.data.view.round, "Attack")
				else
					h.clock.t += Rules.nextSeconds
					h.host:tick()
				end
			end
			expect(h.host:isInMatch(1)).to.equal(false)
			expect(#h.ended).to.equal(1)
			expect(h.ended[1].record.mode).to.equal("Trial")
			local fin = lastTo(h, 1, "Battle.End")
			expect(fin.reward.coins).to.equal(1)
			expect(fin.result.reason == "KO" or fin.result.reason == "MaxRounds").to.equal(true)
		end)

		it("forfeits a player who stays disconnected past the reconnect window", function()
			local h = harness()
			ranked(h)
			h.host:disconnected(2)
			h.clock.t = 29
			h.host:tick()
			expect(#h.ended).to.equal(0) -- still inside the window; the missed pick became Attack
			h.clock.t = 30
			h.host:tick()
			expect(#h.ended).to.equal(1)
			expect(h.ended[1].result.winner).to.equal(1)
			expect(h.ended[1].result.endedByForfeit).to.equal(true)
			expect(h.host:isInMatch(1)).to.equal(false)
			expect(h.host:isInMatch(2)).to.equal(false)
		end)

		it("keeps the seat for a player who reconnects inside the window", function()
			local h = harness()
			ranked(h)
			h.host:disconnected(2)
			h.clock.t = 10
			h.host:tick()
			local before = #h.sent
			expect(h.host:reconnected(2)).to.equal(true)
			expect(#h.sent).to.equal(before + 1)
			expect(lastTo(h, 2, "Battle.Start").you).to.equal(2)
			h.clock.t = 45
			h.host:tick()
			expect(h.host:isInMatch(2)).to.equal(true)
		end)

		it("ends the match on a forfeit request and settles exactly once", function()
			local h = harness()
			ranked(h)
			expect(h.host:forfeit(1).ok).to.equal(true)
			expect(h.host:forfeit(1).ok).to.equal(false)
			h.host:tick()
			expect(#h.ended).to.equal(1)
			expect(lastTo(h, 1, "Battle.End").result.winner).to.equal(2)
			expect(lastTo(h, 2, "Battle.End").reward.coins).to.equal(1)
		end)

		it("survives a settlement error without losing the end packet", function()
			local sent = {}
			local host = MatchHost.new({
				now = function()
					return 0
				end,
				send = function(userId, push, data)
					table.insert(sent, { userId = userId, push = push, data = data })
				end,
				onEnd = function()
					error("store down")
				end,
				reconnectSeconds = 30,
			})
			host:create({
				matchId = "x",
				mode = "Ranked",
				seed = 1,
				seats = {
					{ userId = 1, name = "A", deck = DECK_A },
					{ userId = 2, name = "B", deck = DECK_B },
				},
			})
			host:forfeit(2)
			local last = sent[#sent]
			expect(last.push).to.equal("Battle.End")
			expect(host:isInMatch(1)).to.equal(false)
		end)
	end)
end
