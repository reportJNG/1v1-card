--!strict
-- Pays out one finished ranked match to one player's profile: trophies, the game-paid purse and
-- the anti-farming rules. Nobody stakes anything; the purse comes from the game, never from the
-- opponent. Pure and idempotent: the matchId is remembered in `settledMatches`, so a retry after
-- a crash or a replayed message pays nothing twice.
local Types = require(script.Parent.Parent.Types)
local Economy = require(script.Parent.Parent.Config.Economy)
local Result = require(script.Parent.Result)
local Wallet = require(script.Parent.Wallet)
local Progress = require(script.Parent.Progress)

local Matches = Economy.Matches

export type Input = {
	matchId: string,
	opponentId: number, -- the opponent's UserId
	opponentTrophies: number, -- their trophies when the match was made
	won: boolean,
	rounds: number, -- rounds played when the match ended
	timeouts: number, -- this player's missed picks
	endedByForfeit: boolean, -- either side forfeited or failed to reconnect
	now: number,
}

export type VoidReason = "RepeatOpponent" | "EarlyForfeit" | "Timeouts"

export type Outcome = {
	duplicate: boolean, -- the matchId was already settled: nothing changed
	won: boolean,
	coins: number,
	trophyDelta: number, -- the change actually applied (trophies never go below 0)
	trophies: number,
	leagueBefore: string,
	leagueAfter: string,
	reward: "Full" | "Reduced" | "None",
	voidReason: VoidReason?,
}

local Settlement = {}

local DAY = 86400

-- A new UTC day resets the daily win counter and the same-opponent counts.
function Settlement.rollDay(profile: Types.PlayerProfile, now: number)
	local dayKey = now // DAY
	if profile.daily.dayKey ~= dayKey then
		profile.daily.dayKey = dayKey
		profile.daily.winsToday = 0
		profile.opponentsToday = {}
	end
end

local function truncDiv(a: number, b: number): number
	return if a >= 0 then a // b else -(-a // b)
end

-- Trophies for a result. A higher-rated opponent makes a win worth more and a loss cost less.
function Settlement.trophySwing(ownTrophies: number, opponentTrophies: number, won: boolean): number
	local swing = truncDiv(opponentTrophies - ownTrophies, Matches.trophyGapDivisor)
	if won then
		return math.clamp(Matches.trophyWin + swing, Matches.trophyWinRange[1], Matches.trophyWinRange[2])
	end
	return math.clamp(Matches.trophyLoss - swing, Matches.trophyLossRange[1], Matches.trophyLossRange[2])
end

local function validInput(input: Input): boolean
	local function whole(n: any, min: number): boolean
		return typeof(n) == "number" and n == n and n >= min and n == math.floor(n) and n < math.huge
	end
	return typeof(input.matchId) == "string"
		and #input.matchId > 0
		and #input.matchId <= 80
		and whole(input.opponentId, 1)
		and whole(input.opponentTrophies, 0)
		and typeof(input.won) == "boolean"
		and whole(input.rounds, 0)
		and whole(input.timeouts, 0)
		and typeof(input.endedByForfeit) == "boolean"
		and typeof(input.now) == "number"
end

local function pruneSettled(profile: Types.PlayerProfile)
	local entries = {}
	for id, t in profile.settledMatches do
		table.insert(entries, { id = id, t = t })
	end
	local excess = #entries - Matches.settledMemory
	if excess <= 0 then
		return
	end
	table.sort(entries, function(a, b)
		if a.t == b.t then
			return a.id < b.id
		end
		return a.t < b.t
	end)
	for i = 1, excess do
		profile.settledMatches[entries[i].id] = nil
	end
end

function Settlement.settle(profile: Types.PlayerProfile, input: Input): Types.Result<Outcome>
	if not validInput(input) then
		return Result.fail("BadSettlement")
	end
	local league = Progress.leagueFor(profile.trophies)
	if profile.settledMatches[input.matchId] ~= nil then
		return Result.ok({
			duplicate = true,
			won = input.won,
			coins = 0,
			trophyDelta = 0,
			trophies = profile.trophies,
			leagueBefore = league.id,
			leagueAfter = league.id,
			reward = "None",
			voidReason = nil,
		} :: Outcome)
	end

	Settlement.rollDay(profile, input.now)
	local opponentKey = tostring(input.opponentId)

	local voidReason: VoidReason? = nil
	if (profile.opponentsToday[opponentKey] or 0) >= Matches.maxRepeatsPerDay then
		voidReason = "RepeatOpponent"
	elseif input.endedByForfeit and input.rounds < Matches.minRoundsForReward then
		voidReason = "EarlyForfeit"
	elseif input.timeouts >= Matches.timeoutsVoidReward then
		voidReason = "Timeouts"
	end

	-- Trophies are never capped, but a voided win earns none. A voided loss still costs trophies
	-- (quitting early must not be free), except a repeat-farming match, which moves nothing.
	local delta = 0
	if input.won then
		if voidReason == nil then
			delta = Settlement.trophySwing(profile.trophies, input.opponentTrophies, true)
		end
	elseif voidReason ~= "RepeatOpponent" then
		delta = -Settlement.trophySwing(profile.trophies, input.opponentTrophies, false)
	end
	local trophiesAfter = math.max(0, profile.trophies + delta)

	local reward: "Full" | "Reduced" | "None" = "None"
	local coins = 0
	if voidReason == nil then
		local base = if input.won
			then Matches.purseByLeague[league.id]
			else Matches.lossCoinsByLeague[league.id]
		assert(base ~= nil, `no purse configured for league {league.id}`)
		if profile.daily.winsToday >= Matches.dailyFullRewardWins then
			reward = "Reduced"
			coins = math.floor(base * Matches.reducedFactor)
		else
			reward = "Full"
			coins = base
		end
	end

	-- Validate the one fallible step first; everything after it cannot fail.
	local coinRef = `match:{input.matchId}`
	if coins > 0 then
		local checked = Wallet.check(profile, "coins", coins, coinRef)
		if not checked.ok then
			if checked.err == "BalanceCap" then
				coins = 0 -- a maxed wallet forfeits the purse; the match must still settle
			else
				return Result.fail(checked.err)
			end
		end
	end
	if coins > 0 then
		local applied = Wallet.apply(
			profile,
			"coins",
			coins,
			if input.won then "MatchWin" else "MatchLoss",
			coinRef,
			input.now
		)
		assert(applied.ok, "settlement coin grant was validated")
	end

	local before = profile.trophies
	profile.trophies = trophiesAfter
	profile.highestTrophies = math.max(profile.highestTrophies, trophiesAfter)
	profile.opponentsToday[opponentKey] = (profile.opponentsToday[opponentKey] or 0) + 1
	if input.won and voidReason == nil then
		profile.daily.winsToday += 1
	end
	profile.stats.matches += 1
	if input.won then
		profile.stats.wins += 1
	else
		profile.stats.losses += 1
	end
	profile.settledMatches[input.matchId] = input.now
	pruneSettled(profile)

	return Result.ok({
		duplicate = false,
		won = input.won,
		coins = coins,
		trophyDelta = trophiesAfter - before,
		trophies = trophiesAfter,
		leagueBefore = league.id,
		leagueAfter = Progress.leagueFor(trophiesAfter).id,
		reward = if coins > 0 then reward else "None",
		voidReason = voidReason,
	} :: Outcome)
end

return table.freeze(Settlement)
