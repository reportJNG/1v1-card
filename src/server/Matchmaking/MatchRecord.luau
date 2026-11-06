--!strict
-- The match record the matchmaker writes to MemoryStore for a battle server. The battle server
-- reads it by its own PrivateServerId, never from teleport data (a client can forge that). Decks
-- are not in the record: the battle server rebuilds them from the loaded profiles, so a card
-- sold or merged while teleporting can't be used.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Leagues = require(Shared.Config.Leagues)

export type Seat = { userId: number, trophies: number }

export type Record = {
	matchId: string,
	league: string,
	seed: number,
	seats: { Seat },
	accessCode: string?,
	privateServerId: string?,
	createdAt: number,
}

local MatchRecord = {}

MatchRecord.ARRIVAL_SECONDS = 30 -- both players must arrive within this, or the match is cancelled
MatchRecord.TTL = 60 * 60 -- seconds the record lives in MemoryStore

function MatchRecord.new(
	matchId: string,
	seed: number,
	a: { userId: number, trophies: number, league: string },
	b: { userId: number, trophies: number, league: string },
	now: number
): Record
	assert(a.league == b.league, "pairs are always in the same league")
	return {
		matchId = matchId,
		league = a.league,
		seed = seed,
		seats = { { userId = a.userId, trophies = a.trophies }, { userId = b.userId, trophies = b.trophies } },
		createdAt = now,
	}
end

function MatchRecord.parse(raw: any): Record?
	if typeof(raw) ~= "table" then
		return nil
	end
	if
		typeof(raw.matchId) ~= "string"
		or typeof(raw.seed) ~= "number"
		or typeof(raw.createdAt) ~= "number"
	then
		return nil
	end
	local leagueOk = false
	for _, league in Leagues.List do
		if league.id == raw.league then
			leagueOk = true
		end
	end
	if not leagueOk or typeof(raw.seats) ~= "table" or #raw.seats ~= 2 then
		return nil
	end
	for _, seat in raw.seats do
		if
			typeof(seat) ~= "table"
			or typeof(seat.userId) ~= "number"
			or typeof(seat.trophies) ~= "number"
		then
			return nil
		end
	end
	if raw.seats[1].userId == raw.seats[2].userId then
		return nil
	end
	return raw :: Record
end

function MatchRecord.sideOf(record: Record, userId: number): number?
	for side, seat in record.seats do
		if seat.userId == userId then
			return side
		end
	end
	return nil
end

function MatchRecord.levelCap(record: Record): number
	for _, league in Leagues.List do
		if league.id == record.league then
			return league.rankedLevelCap
		end
	end
	error(`unknown league {record.league}`)
end

return table.freeze(MatchRecord)
