--!strict
-- Matchmaking tickets in a MemoryStore sorted map (key = UserId, sort key = time queued).
-- Only servers write tickets; the client can only ask to join or leave.
--
--   join    writes a fresh ticket that expires after `ttl` seconds unless refreshed
--   leave   marks the ticket left (if it was not matched yet), then deletes it
--   claim   the matchmaker stamps both tickets with the match, each with UpdateAsync, so a
--           ticket that left or was already matched is never claimed; if the second claim
--           fails the first is reverted
--   get     the owning server polls its players' tickets for an assignment
--
-- Every MemoryStore call can throw (throttling, outages); all of them are wrapped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)

export type Assignment = { matchId: string, accessCode: string? }

export type Ticket = {
	userId: number,
	trophies: number,
	league: string,
	queuedAt: number,
	server: string, -- JobId of the Hub server the player is on
	match: Assignment?,
	left: boolean?,
}

export type Map = {
	SetAsync: (self: any, key: string, value: any, expiration: number, sortKey: any?) -> boolean,
	GetAsync: (self: any, key: string) -> (any, any),
	RemoveAsync: (self: any, key: string) -> (),
	UpdateAsync: (
		self: any,
		key: string,
		transform: (old: any, sortKey: any) -> (any, any),
		expiration: number
	) -> any,
	GetRangeAsync: (
		self: any,
		direction: any,
		count: number,
		lower: any?,
		upper: any?
	) -> { { key: string, value: any, sortKey: any } },
}

export type Options = { ttl: number, ascending: any }

local Queue = {}
Queue.__index = Queue

export type Queue = typeof(setmetatable({} :: { _map: Map, _ttl: number, _ascending: any }, Queue))

function Queue.new(map: Map, options: Options): Queue
	return setmetatable({ _map = map, _ttl = options.ttl, _ascending = options.ascending }, Queue)
end

-- Rejects anything that is not a well-formed ticket (corrupt or foreign data).
function Queue.parse(raw: any): Ticket?
	if typeof(raw) ~= "table" then
		return nil
	end
	if
		typeof(raw.userId) ~= "number"
		or typeof(raw.trophies) ~= "number"
		or typeof(raw.league) ~= "string"
		or typeof(raw.queuedAt) ~= "number"
		or typeof(raw.server) ~= "string"
	then
		return nil
	end
	if raw.match ~= nil and (typeof(raw.match) ~= "table" or typeof(raw.match.matchId) ~= "string") then
		return nil
	end
	return raw :: Ticket
end

local function key(userId: number): string
	return tostring(userId)
end

function Queue.join(self: Queue, ticket: Ticket): Types.Result<nil>
	local ok, err = pcall(function()
		self._map:SetAsync(key(ticket.userId), ticket, self._ttl, ticket.queuedAt)
	end)
	return if ok then Result.ok(nil) else Result.fail(`StoreError:{err}`)
end

-- Keeps a waiting ticket alive. Never resurrects one that was matched, left or removed.
function Queue.refresh(self: Queue, userId: number): Types.Result<nil>
	local ok, err = pcall(function()
		self._map:UpdateAsync(key(userId), function(old: any, sortKey: any)
			local t = Queue.parse(old)
			if t == nil or t.match or t.left then
				return nil
			end
			return t, sortKey
		end, self._ttl)
	end)
	return if ok then Result.ok(nil) else Result.fail(`StoreError:{err}`)
end

-- Ok("Left") when the ticket is gone; Ok("Matched") when a match was already assigned.
function Queue.leave(self: Queue, userId: number): Types.Result<string>
	local matched = false
	local ok, err = pcall(function()
		self._map:UpdateAsync(key(userId), function(old: any, sortKey: any)
			local t = Queue.parse(old)
			if t == nil then
				return nil
			end
			if t.match then
				matched = true
				return nil
			end
			t.left = true
			return t, sortKey
		end, self._ttl)
		if not matched then
			self._map:RemoveAsync(key(userId))
		end
	end)
	if not ok then
		return Result.fail(`StoreError:{err}`)
	end
	return Result.ok(if matched then "Matched" else "Left")
end

-- Removes a ticket outright (after its owner acted on the assignment).
function Queue.remove(self: Queue, userId: number)
	pcall(function()
		self._map:RemoveAsync(key(userId))
	end)
end

function Queue.get(self: Queue, userId: number): Types.Result<Ticket?>
	local ok, raw = pcall(function()
		return (self._map:GetAsync(key(userId)))
	end)
	if not ok then
		return Result.fail(`StoreError:{raw}`)
	end
	return Result.ok(Queue.parse(raw))
end

-- Waiting tickets, oldest first.
function Queue.waiting(self: Queue, limit: number): Types.Result<{ Ticket }>
	local ok, rows = pcall(function()
		return self._map:GetRangeAsync(self._ascending, limit)
	end)
	if not ok then
		return Result.fail(`StoreError:{rows}`)
	end
	local out = {}
	for _, row in rows :: { any } do
		local t = Queue.parse(row.value)
		if t and not t.match and not t.left then
			table.insert(out, t)
		end
	end
	return Result.ok(out)
end

local function stamp(self: Queue, userId: number, assignment: Assignment): boolean
	local claimed = false
	local ok = pcall(function()
		self._map:UpdateAsync(key(userId), function(old: any, sortKey: any)
			local t = Queue.parse(old)
			if t == nil or t.match or t.left then
				return nil
			end
			t.match = assignment
			claimed = true
			return t, sortKey
		end, self._ttl)
	end)
	return ok and claimed
end

local function unstamp(self: Queue, userId: number, matchId: string)
	pcall(function()
		self._map:UpdateAsync(key(userId), function(old: any, sortKey: any)
			local t = Queue.parse(old)
			if t == nil or t.match == nil or t.match.matchId ~= matchId then
				return nil
			end
			t.match = nil
			return t, sortKey
		end, self._ttl)
	end)
end

-- Claims both tickets for one match, or neither.
function Queue.claim(self: Queue, a: number, b: number, assignment: Assignment): boolean
	if a == b or not stamp(self, a, assignment) then
		return false
	end
	if not stamp(self, b, assignment) then
		unstamp(self, a, assignment.matchId)
		return false
	end
	return true
end

return Queue
