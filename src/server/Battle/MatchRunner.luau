--!strict
-- One live battle as a state machine around Shared/Battle/BattleRules, with no Roblox objects in
-- it: the host (BattleService) feeds it picks and the clock, and pushes the messages it returns.
--
--   Picking   both players have `pickSeconds` to pick; a missing pick becomes Attack and counts as
--             a timeout; `maxTimeouts` timeouts forfeit the match
--   Choosing  after a KO, the owner picks the next card within `nextSeconds`, or the sensible
--             default (BattleRules.defaultNext) comes in
--   Ended     a side lost all three cards, round 30 was reached, or a side forfeited
--
-- Picks are accepted once per round, only for the current round and before the deadline. They
-- stay secret until the round resolves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)
local BattleRules = require(Shared.Battle.BattleRules)
local Rules = require(Shared.Config.Battle)

export type Phase = "Picking" | "Choosing" | "Ended"
export type EndReason = "KO" | "MaxRounds" | "Forfeit" | "Timeouts"

export type Message = { kind: string, data: { [string]: any } }

export type EndInfo = {
	winner: number, -- 1 or 2
	reason: EndReason,
	rounds: number,
	timeouts: { number },
	endedByForfeit: boolean,
}

export type Options = {
	matchId: string,
	seed: number,
	decks: { { BattleRules.UnitSpec } }, -- [1], [2]: three cards each, in entry order
	now: number,
	pickSeconds: number?,
	nextSeconds: number?,
}

local MatchRunner = {}
MatchRunner.__index = MatchRunner

export type MatchRunner = typeof(setmetatable(
	{} :: {
		matchId: string,
		match: BattleRules.Match,
		phase: Phase,
		deadline: number,
		picks: { [number]: BattleRules.Action? },
		needsNext: { [number]: boolean },
		timeouts: { number },
		ended: EndInfo?,
		_pickSeconds: number,
		_nextSeconds: number,
		_eventCursor: number,
		_outbox: { Message },
	},
	MatchRunner
))

function MatchRunner.new(options: Options): MatchRunner
	assert(#options.decks == 2 and #options.decks[1] == 3 and #options.decks[2] == 3, "two 3-card decks")
	local self = setmetatable({
		matchId = options.matchId,
		match = BattleRules.new(options.decks[1], options.decks[2], options.seed),
		phase = "Picking" :: Phase,
		deadline = 0,
		picks = {},
		needsNext = {},
		timeouts = { 0, 0 },
		ended = nil,
		_pickSeconds = options.pickSeconds or Rules.pickSeconds,
		_nextSeconds = options.nextSeconds or Rules.nextSeconds,
		_eventCursor = 0,
		_outbox = {},
	}, MatchRunner)
	self:_openRound(options.now)
	return self
end

-- What both clients may see. Picks are never included; only whether each side has picked.
function MatchRunner.view(self: MatchRunner): { [string]: any }
	local m = self.match
	local sides = {}
	for i = 1, 2 do
		local s = m.sides[i]
		local units = {}
		for slot, u in s.units do
			local status = table.clone(u.status)
			units[slot] = {
				characterId = u.characterId,
				hp = u.hp,
				maxHp = u.maxHp,
				shield = u.shield,
				status = status,
				specialCost = u.special.cost,
			}
		end
		sides[i] = {
			active = s.active,
			energy = s.energy,
			units = units,
			timeouts = self.timeouts[i],
			picked = self.picks[i] ~= nil,
			canSpecial = BattleRules.canSpecial(m, i),
			firstChance = BattleRules.firstChance(m, i),
			needsNext = self.needsNext[i] == true,
		}
	end
	return {
		matchId = self.matchId,
		phase = self.phase,
		round = m.round + 1, -- the round being picked (m.round counts resolved rounds)
		deadline = self.deadline,
		sides = sides,
	}
end

function MatchRunner._emit(self: MatchRunner, kind: string, data: { [string]: any })
	table.insert(self._outbox, { kind = kind, data = data })
end

function MatchRunner._newEvents(self: MatchRunner): { BattleRules.Event }
	local out = {}
	local events = self.match.events
	for i = self._eventCursor + 1, #events do
		table.insert(out, events[i])
	end
	self._eventCursor = #events
	return out
end

function MatchRunner._openRound(self: MatchRunner, now: number)
	self.phase = "Picking"
	self.picks = {}
	self.deadline = now + self._pickSeconds
	self:_emit("RoundOpen", { view = self:view() })
end

function MatchRunner._finish(self: MatchRunner, winner: number, reason: EndReason)
	self.phase = "Ended"
	self.deadline = math.huge
	self.ended = {
		winner = winner,
		reason = reason,
		rounds = self.match.round,
		timeouts = { self.timeouts[1], self.timeouts[2] },
		endedByForfeit = reason == "Forfeit" or reason == "Timeouts",
	}
	self:_emit("End", { result = self.ended, view = self:view() })
end

function MatchRunner.pick(
	self: MatchRunner,
	side: number,
	round: number,
	action: string,
	now: number
): Types.Result<nil>
	if side ~= 1 and side ~= 2 then
		return Result.fail("NotInMatch")
	end
	if self.phase == "Ended" then
		return Result.fail("MatchOver")
	end
	if self.phase ~= "Picking" then
		return Result.fail("NotPicking")
	end
	if round ~= self.match.round + 1 then
		return Result.fail("WrongRound")
	end
	if action ~= "Attack" and action ~= "Defend" and action ~= "Special" then
		return Result.fail("BadAction")
	end
	if self.picks[side] ~= nil then
		return Result.fail("AlreadyPicked")
	end
	if now > self.deadline then
		return Result.fail("TooLate")
	end
	-- An unaffordable Special is accepted and resolves as Attack (BattleRules.resolve).
	self.picks[side] = action :: BattleRules.Action
	return Result.ok(nil)
end

function MatchRunner.chooseNext(self: MatchRunner, side: number, slot: number, now: number): Types.Result<nil>
	if self.phase ~= "Choosing" or not self.needsNext[side] then
		return Result.fail("NotChoosing")
	end
	if now > self.deadline then
		return Result.fail("TooLate")
	end
	if not BattleRules.chooseNext(self.match, side, slot) then
		return Result.fail("BadSlot")
	end
	self.needsNext[side] = nil
	return Result.ok(nil)
end

function MatchRunner.forfeit(self: MatchRunner, side: number): Types.Result<nil>
	if side ~= 1 and side ~= 2 then
		return Result.fail("NotInMatch")
	end
	if self.phase == "Ended" then
		return Result.fail("MatchOver")
	end
	self:_finish(3 - side, "Forfeit")
	return Result.ok(nil)
end

function MatchRunner._resolveRound(self: MatchRunner, now: number)
	local acts: { BattleRules.Action } = {}
	local timedOut = { false, false }
	for i = 1, 2 do
		local picked = self.picks[i]
		if picked == nil then
			self.timeouts[i] += 1
			timedOut[i] = true
		end
		acts[i] = (picked or "Attack") :: BattleRules.Action
	end
	local outA = self.timeouts[1] >= Rules.maxTimeouts
	local outB = self.timeouts[2] >= Rules.maxTimeouts
	if outA or outB then
		self:_newEvents()
		if outA and outB then
			-- Both walked away: whoever has more HP left wins, and nobody is paid (Timeouts voids it).
			local winner = if BattleRules.hpShare(self.match, 1) >= BattleRules.hpShare(self.match, 2)
				then 1
				else 2
			self:_finish(winner, "Timeouts")
		else
			self:_finish(if outA then 2 else 1, "Timeouts")
		end
		return
	end

	BattleRules.resolve(self.match, acts[1], acts[2])
	self:_emit("Round", { round = self.match.round, events = self:_newEvents(), timedOut = timedOut })

	local winner = BattleRules.outcome(self.match)
	if winner then
		local allDown = true
		for i = 1, 2 do
			for _, u in self.match.sides[i].units do
				if u.hp > 0 and i ~= winner then
					allDown = false
				end
			end
		end
		self:_finish(winner, if allDown then "KO" else "MaxRounds")
		return
	end

	local choosing = false
	for i = 1, 2 do
		if BattleRules.needsNext(self.match, i) then
			self.needsNext[i] = true
			choosing = true
		end
	end
	if choosing then
		self.phase = "Choosing"
		self.deadline = now + self._nextSeconds
		self:_emit("ChooseNext", { view = self:view() })
	else
		self:_openRound(now)
	end
end

function MatchRunner._closeChoosing(self: MatchRunner, now: number)
	for i = 1, 2 do
		if self.needsNext[i] then
			local slot = BattleRules.defaultNext(self.match, i)
			assert(slot, "a side that needs a card has one on the bench")
			BattleRules.chooseNext(self.match, i, slot)
			self.needsNext[i] = nil
		end
	end
	self:_emit("Entered", { events = self:_newEvents() })
	self:_openRound(now)
end

-- Advances the match to `now` and returns the messages to send, oldest first.
function MatchRunner.step(self: MatchRunner, now: number): { Message }
	if self.phase == "Picking" then
		if (self.picks[1] ~= nil and self.picks[2] ~= nil) or now >= self.deadline then
			self:_resolveRound(now)
		end
	elseif self.phase == "Choosing" then
		if next(self.needsNext) == nil or now >= self.deadline then
			self:_closeChoosing(now)
		end
	end
	local out = self._outbox
	self._outbox = {}
	return out
end

function MatchRunner.isOver(self: MatchRunner): boolean
	return self.phase == "Ended"
end

return MatchRunner
