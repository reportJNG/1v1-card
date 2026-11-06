--!strict
-- Runs every live match on this server: routes picks from players to their match, plays the
-- Guardian AI, keeps a dropped player's seat for the reconnect window, and hands finished
-- matches to `onEnd` for settlement. No Roblox objects: BattleService wires it to remotes and
-- the clock, and tests drive it with mocks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)
local BattleRules = require(Shared.Battle.BattleRules)
local Prng = require(Shared.Battle.Prng)
local MatchRunner = require(script.Parent.MatchRunner)
local BattleAI = require(script.Parent.BattleAI)

export type Mode = "Ranked" | "Trial"

export type SeatSpec = {
	userId: number?, -- nil for the AI
	name: string,
	deck: { BattleRules.UnitSpec },
	trophies: number?,
}

export type Record = {
	matchId: string,
	mode: Mode,
	seed: number,
	seats: { SeatSpec }, -- [1], [2]
	worldId: number?, -- Trial
}

type Live = {
	record: Record,
	runner: MatchRunner.MatchRunner,
	ai: { [number]: { policy: BattleAI.Policy, rng: Prng.Prng } },
	droppedAt: { [number]: number },
}

export type Deps = {
	now: () -> number,
	send: (userId: number, push: string, data: any) -> (),
	-- Settles a finished match; returns what each human seat earned, keyed by userId.
	onEnd: (record: Record, result: MatchRunner.EndInfo) -> { [number]: any },
	reconnectSeconds: number,
}

local MatchHost = {}
MatchHost.__index = MatchHost

export type MatchHost = typeof(setmetatable(
	{} :: {
		_deps: Deps,
		_matches: { [string]: Live },
		_seatOf: { [number]: { matchId: string, side: number } },
	},
	MatchHost
))

function MatchHost.new(deps: Deps): MatchHost
	return setmetatable({ _deps = deps, _matches = {}, _seatOf = {} }, MatchHost)
end

local function startPacket(live: Live, side: number): { [string]: any }
	local seats = {}
	for i, seat in live.record.seats do
		seats[i] = { name = seat.name, trophies = seat.trophies, ai = seat.userId == nil }
	end
	return {
		matchId = live.record.matchId,
		mode = live.record.mode,
		worldId = live.record.worldId,
		you = side,
		seats = seats,
		view = live.runner:view(),
	}
end

function MatchHost.create(self: MatchHost, record: Record): Types.Result<nil>
	if self._matches[record.matchId] then
		return Result.fail("MatchExists")
	end
	if #record.seats ~= 2 then
		return Result.fail("BadMatch")
	end
	for _, seat in record.seats do
		if seat.userId and self._seatOf[seat.userId] then
			return Result.fail("AlreadyInMatch")
		end
		if #seat.deck ~= 3 then
			return Result.fail("BadDeck")
		end
	end
	local now = self._deps.now()
	local live: Live = {
		record = record,
		runner = MatchRunner.new({
			matchId = record.matchId,
			seed = record.seed,
			decks = { record.seats[1].deck, record.seats[2].deck },
			now = now,
		}),
		ai = {},
		droppedAt = {},
	}
	for side, seat in record.seats do
		if seat.userId then
			self._seatOf[seat.userId] = { matchId = record.matchId, side = side }
		else
			live.ai[side] = { policy = BattleAI.reader(), rng = Prng.new(record.seed * 7 + side) }
		end
	end
	self._matches[record.matchId] = live
	for side, seat in record.seats do
		if seat.userId then
			self._deps.send(seat.userId, "Battle.Start", startPacket(live, side))
		end
	end
	self:_flush(live)
	return Result.ok(nil)
end

function MatchHost.seatOf(self: MatchHost, userId: number): (string?, number?)
	local seat = self._seatOf[userId]
	if seat == nil then
		return nil, nil
	end
	return seat.matchId, seat.side
end

function MatchHost.isInMatch(self: MatchHost, userId: number): boolean
	return self._seatOf[userId] ~= nil
end

function MatchHost.count(self: MatchHost): number
	local n = 0
	for _ in self._matches do
		n += 1
	end
	return n
end

local function liveFor(self: MatchHost, userId: number): (Live?, number)
	local seat = self._seatOf[userId]
	if seat == nil then
		return nil, 0
	end
	return self._matches[seat.matchId], seat.side
end

function MatchHost.pick(self: MatchHost, userId: number, round: number, action: string): Types.Result<nil>
	local live, side = liveFor(self, userId)
	if live == nil then
		return Result.fail("NotInMatch")
	end
	local r = live.runner:pick(side, round, action, self._deps.now())
	if r.ok then
		self:_flush(live) -- resolves at once when both picks are in
	end
	return r
end

function MatchHost.chooseNext(self: MatchHost, userId: number, slot: number): Types.Result<nil>
	local live, side = liveFor(self, userId)
	if live == nil then
		return Result.fail("NotInMatch")
	end
	local r = live.runner:chooseNext(side, slot, self._deps.now())
	if r.ok then
		self:_flush(live)
	end
	return r
end

function MatchHost.forfeit(self: MatchHost, userId: number): Types.Result<nil>
	local live, side = liveFor(self, userId)
	if live == nil then
		return Result.fail("NotInMatch")
	end
	local r = live.runner:forfeit(side)
	if r.ok then
		self:_flush(live)
	end
	return r
end

-- The player left the server. Their timer keeps running (missed picks become Attack); after the
-- reconnect window they forfeit.
function MatchHost.disconnected(self: MatchHost, userId: number)
	local live, side = liveFor(self, userId)
	if live and live.droppedAt[side] == nil then
		live.droppedAt[side] = self._deps.now()
	end
end

-- The player is back inside the window: resend the full state.
function MatchHost.reconnected(self: MatchHost, userId: number): boolean
	local live, side = liveFor(self, userId)
	if live == nil then
		return false
	end
	live.droppedAt[side] = nil
	self._deps.send(userId, "Battle.Start", startPacket(live, side))
	return true
end

function MatchHost._aiAct(self: MatchHost, live: Live, kind: string)
	local now = self._deps.now()
	for side, brain in live.ai do
		local runner = live.runner
		if kind == "RoundOpen" and runner.phase == "Picking" and runner.picks[side] == nil then
			local action = brain.policy(runner.match, side, brain.rng)
			runner:pick(side, runner.match.round + 1, action, now)
		elseif kind == "ChooseNext" and runner.needsNext[side] then
			runner:chooseNext(side, BattleRules.defaultNext(runner.match, side) :: number, now)
		end
	end
end

-- Sends everything the runner produced, lets the AI react, and repeats until it settles.
function MatchHost._flush(self: MatchHost, live: Live)
	for _ = 1, 8 do
		local msgs = live.runner:step(self._deps.now())
		if #msgs == 0 then
			return
		end
		for _, msg in msgs do
			if msg.kind == "End" then
				self:_end(live, msg.data)
				return
			end
			for side, seat in live.record.seats do
				if seat.userId and live.droppedAt[side] == nil then
					self._deps.send(
						seat.userId,
						"Battle.Round",
						{ kind = msg.kind, you = side, data = msg.data }
					)
				end
			end
			self:_aiAct(live, msg.kind)
		end
	end
end

function MatchHost._end(self: MatchHost, live: Live, data: { [string]: any })
	local record = live.record
	self._matches[record.matchId] = nil
	for _, seat in record.seats do
		if seat.userId then
			self._seatOf[seat.userId] = nil
		end
	end
	local okEnd, rewards = pcall(self._deps.onEnd, record, live.runner.ended :: MatchRunner.EndInfo)
	if not okEnd then
		warn(`[Battle] settlement failed for {record.matchId}: {rewards}`)
		rewards = {}
	end
	for side, seat in record.seats do
		if seat.userId then
			self._deps.send(seat.userId, "Battle.End", {
				matchId = record.matchId,
				mode = record.mode,
				you = side,
				result = data.result,
				view = data.view,
				reward = rewards[seat.userId],
			})
		end
	end
end

-- Called every frame: timers, AI picks and reconnect windows.
function MatchHost.tick(self: MatchHost)
	local now = self._deps.now()
	local ids = {}
	for id in self._matches do
		table.insert(ids, id)
	end
	for _, id in ids do
		local live = self._matches[id]
		if live == nil then
			continue
		end
		for side, at in live.droppedAt do
			if now - at >= self._deps.reconnectSeconds and not live.runner:isOver() then
				live.runner:forfeit(side)
			end
		end
		self:_flush(live)
	end
end

return MatchHost
