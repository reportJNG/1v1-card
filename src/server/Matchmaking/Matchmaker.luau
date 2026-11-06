--!strict
-- One matchmaker tick, run by every Hub server about every 2 seconds. Only the server holding
-- the lease does any work:
--   1. read waiting tickets (oldest first) and pair them (Pairing)
--   2. for each pair: reserve a battle server, write the match record, then claim both tickets
--      (if the claim fails, the record just expires unused and the players stay queued)
-- The owning servers see the assignment on their players' tickets and teleport them.
local Pairing = require(script.Parent.Pairing)
local Lease = require(script.Parent.Lease)
local Queue = require(script.Parent.Queue)
local MatchRecord = require(script.Parent.MatchRecord)

export type Deps = {
	queue: Queue.Queue,
	leaseStore: Lease.Store,
	jobId: string,
	now: () -> number,
	-- Reserves a battle server; returns (accessCode, privateServerId), or nil to run the match on
	-- this server (Studio, where TeleportService is unavailable).
	reserve: () -> (string?, string?),
	writeRecord: (record: MatchRecord.Record) -> boolean,
	newMatchId: () -> string,
	newSeed: () -> number,
	leaseSeconds: number?,
	batch: number?,
}

local Matchmaker = {}
Matchmaker.__index = Matchmaker

Matchmaker.LEASE_KEY = "matchmaker-lease"

export type Matchmaker = typeof(setmetatable({} :: { _deps: Deps }, Matchmaker))

function Matchmaker.new(deps: Deps): Matchmaker
	return setmetatable({ _deps = deps }, Matchmaker)
end

function Matchmaker.isLeader(self: Matchmaker): boolean
	local d = self._deps
	return Lease.tryAcquire(d.leaseStore, Matchmaker.LEASE_KEY, d.jobId, d.now(), d.leaseSeconds or 6)
end

-- Returns the matches created this tick.
function Matchmaker.tick(self: Matchmaker): { MatchRecord.Record }
	local d = self._deps
	local created: { MatchRecord.Record } = {}
	if not self:isLeader() then
		return created
	end
	local waiting = d.queue:waiting(d.batch or 200)
	if not waiting.ok then
		return created
	end
	local now = d.now()
	for _, pair in Pairing.pair(waiting.value :: any, now) do
		local a, b = pair[1] :: any, pair[2] :: any
		local okReserve, accessCode, privateServerId = pcall(d.reserve)
		if not okReserve then
			continue -- ReserveServer failed; both stay queued for the next tick
		end
		local record = MatchRecord.new(d.newMatchId(), d.newSeed(), a, b, now)
		record.accessCode = accessCode
		record.privateServerId = privateServerId
		if not d.writeRecord(record) then
			continue
		end
		if d.queue:claim(a.userId, b.userId, { matchId = record.matchId, accessCode = accessCode }) then
			table.insert(created, record)
		end
	end
	return created
end

return Matchmaker
