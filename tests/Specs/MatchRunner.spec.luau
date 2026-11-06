--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rules = require(Shared.Config.Battle)
local BattleRules = require(Shared.Battle.BattleRules)
local MatchRunner = require(ServerScriptService.Server.Battle.MatchRunner)

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

local function new(seed: number?): MatchRunner.MatchRunner
	return MatchRunner.new({ matchId = "t", seed = seed or 42, decks = { DECK_A, DECK_B }, now = 0 })
end

local function kinds(msgs: { MatchRunner.Message }): string
	local out = {}
	for _, msg in msgs do
		table.insert(out, msg.kind)
	end
	return table.concat(out, ",")
end

-- Both sides pick Attack at once until the match is over; KO replacements use the default.
local function playOut(r: MatchRunner.MatchRunner)
	local t = 0
	for _ = 1, 500 do
		if r:isOver() then
			return
		end
		if r.phase == "Picking" then
			local round = r.match.round + 1
			r:pick(1, round, "Attack", t)
			r:pick(2, round, "Attack", t)
			r:step(t)
		else
			r:step(r.deadline)
		end
		t += 1
	end
end

-- Plays Attack/Attack until a KO puts the match into the replacement phase.
local function untilChoosing(r: MatchRunner.MatchRunner): number
	local t = 0
	while r.phase ~= "Choosing" and not r:isOver() do
		local round = r.match.round + 1
		r:pick(1, round, "Attack", t)
		r:pick(2, round, "Attack", t)
		r:step(t)
		t += 1
	end
	return t - 1
end

return function()
	describe("MatchRunner", function()
		it("opens round 1 with a 12 s pick deadline", function()
			local r = new()
			local msgs = r:step(0)
			expect(kinds(msgs)).to.equal("RoundOpen")
			expect(r.phase).to.equal("Picking")
			expect(r.deadline).to.equal(Rules.pickSeconds)
			expect(msgs[1].data.view.round).to.equal(1)
		end)

		it("resolves as soon as both picks are in", function()
			local r = new()
			r:step(0)
			expect(r:pick(1, 1, "Attack", 1).ok).to.equal(true)
			expect(#r:step(1)).to.equal(0) -- still waiting for side 2
			expect(r:pick(2, 1, "Defend", 2).ok).to.equal(true)
			local msgs = r:step(2)
			expect(msgs[1].kind).to.equal("Round")
			expect(msgs[1].data.round).to.equal(1)
			expect(msgs[2].kind).to.equal("RoundOpen")
			expect(r.deadline).to.equal(2 + Rules.pickSeconds)
		end)

		it(
			"accepts one pick per player per round, only for the current round, before the deadline",
			function()
				local r = new()
				r:step(0)
				expect(r:pick(1, 2, "Attack", 1).ok).to.equal(false) -- future round
				expect(r:pick(1, 0, "Attack", 1).ok).to.equal(false) -- past round
				expect(r:pick(3, 1, "Attack", 1).ok).to.equal(false) -- not a side
				expect(r:pick(1, 1, "Heal", 1).ok).to.equal(false) -- not an action
				expect(r:pick(1, 1, "Attack", 1).ok).to.equal(true)
				local again = r:pick(1, 1, "Special", 1)
				expect(if again.ok then "" else again.err).to.equal("AlreadyPicked")
				local late = r:pick(2, 1, "Attack", Rules.pickSeconds + 0.5)
				expect(if late.ok then "" else late.err).to.equal("TooLate")
			end
		)

		it("keeps picks secret in the view", function()
			local r = new()
			r:step(0)
			r:pick(1, 1, "Defend", 1)
			local view = r:view()
			expect(view.sides[1].picked).to.equal(true)
			expect(view.sides[2].picked).to.equal(false)
			for _, side in view.sides do
				expect(side.pick).to.equal(nil)
			end
		end)

		it("turns a missed pick into Attack and counts a timeout", function()
			local r = new()
			r:step(0)
			r:pick(1, 1, "Defend", 1)
			local msgs = r:step(Rules.pickSeconds)
			expect(msgs[1].kind).to.equal("Round")
			expect(msgs[1].data.timedOut[2]).to.equal(true)
			expect(msgs[1].data.timedOut[1]).to.equal(false)
			expect(r.timeouts[2]).to.equal(1)
			local roundEvent = msgs[1].data.events[1]
			expect(roundEvent[1]).to.equal("Round")
			expect(roundEvent[3]).to.equal("Defend")
			expect(roundEvent[4]).to.equal("Attack")
		end)

		it("forfeits a player on their third timeout", function()
			local r = new()
			r:step(0)
			for _ = 1, Rules.maxTimeouts do
				if r:isOver() then
					break
				end
				local t = r.deadline - 1
				r:pick(1, r.match.round + 1, "Defend", t)
				r:step(r.deadline)
			end
			expect(r:isOver()).to.equal(true)
			local ended = r.ended :: MatchRunner.EndInfo
			expect(ended.winner).to.equal(1)
			expect(ended.reason).to.equal("Timeouts")
			expect(ended.endedByForfeit).to.equal(true)
			expect(ended.timeouts[2]).to.equal(Rules.maxTimeouts)
		end)

		it("ends a match on forfeit and refuses further picks", function()
			local r = new()
			r:step(0)
			expect(r:forfeit(1).ok).to.equal(true)
			local msgs = r:step(1)
			expect(kinds(msgs)).to.equal("End")
			expect(msgs[1].data.result.winner).to.equal(2)
			expect(msgs[1].data.result.reason).to.equal("Forfeit")
			local late = r:pick(2, 1, "Attack", 1)
			expect(if late.ok then "" else late.err).to.equal("MatchOver")
			expect(r:forfeit(2).ok).to.equal(false)
		end)

		it("gives a 5 s replacement pick after a KO, then brings in the default", function()
			local r = new(7)
			r:step(0)
			local t = untilChoosing(r)
			expect(r.phase).to.equal("Choosing")
			local side = if r.needsNext[1] then 1 else 2
			expect(r.deadline).to.equal(t + Rules.nextSeconds)
			local expected = BattleRules.defaultNext(r.match, side)
			local msgs = r:step(r.deadline)
			expect(msgs[1].kind).to.equal("Entered")
			expect(msgs[2].kind).to.equal("RoundOpen")
			expect(r.match.sides[side].active).to.equal(expected)
		end)

		it("lets the owner choose the next card, and only from their living bench", function()
			local r = new(7)
			r:step(0)
			local t = untilChoosing(r)
			local side = if r.needsNext[1] then 1 else 2
			local dead = r.match.sides[side].active
			expect(r:chooseNext(side, dead, t).ok).to.equal(false)
			expect(r:chooseNext(side, 1, t + Rules.nextSeconds + 1).ok).to.equal(false) -- too late
			local bench = BattleRules.bench(r.match, side)
			local choice = bench[#bench]
			expect(r:chooseNext(side, choice, t).ok).to.equal(true)
			expect(r:chooseNext(side, choice, t).ok).to.equal(false) -- only once
			if not r.needsNext[3 - side] then
				local msgs = r:step(t)
				expect(msgs[#msgs].kind).to.equal("RoundOpen")
			end
			expect(r.match.sides[side].active).to.equal(choice)
		end)

		it("plays full matches to a KO or the round limit", function()
			for seed = 1, 20 do
				local r = new(seed)
				r:step(0)
				playOut(r)
				expect(r:isOver()).to.equal(true)
				local ended = r.ended :: MatchRunner.EndInfo
				expect(ended.reason == "KO" or ended.reason == "MaxRounds").to.equal(true)
				expect(ended.rounds <= Rules.maxRounds).to.equal(true)
				expect(BattleRules.outcome(r.match)).to.equal(ended.winner)
			end
		end)

		it("reproduces the engine exactly for the same seed and picks", function()
			local r = new(99)
			r:step(0)
			playOut(r)
			local m = BattleRules.new(DECK_A, DECK_B, 99)
			while BattleRules.outcome(m) == nil do
				BattleRules.resolve(m, "Attack", "Attack")
				for side = 1, 2 do
					if BattleRules.needsNext(m, side) then
						BattleRules.chooseNext(m, side, BattleRules.defaultNext(m, side) :: number)
					end
				end
			end
			expect(BattleRules.signature(r.match)).to.equal(BattleRules.signature(m))
		end)

		it("shows the act-first chance from the card speeds, capped at 20-80%", function()
			local r = new()
			local v = r:view()
			local a, b = v.sides[1].firstChance, v.sides[2].firstChance
			expect(math.abs(a + b - 1) < 1e-9).to.equal(true)
			expect(a >= 0.2 and a <= 0.8).to.equal(true)
		end)
	end)
end
