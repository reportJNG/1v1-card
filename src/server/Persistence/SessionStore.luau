--!strict
-- Session-locked player data on a DataStore (design doc section 6).
--
--   * One key per player holding { meta = { lock, saveNonce, savedAt }, data = profile }.
--   * load() takes the lock; a lock held by another live server blocks the load. A lock whose
--     heartbeat is older than `lockTimeout` (crashed server) may be taken over.
--   * save() writes only while this server holds the lock; release() saves and drops it.
--   * Every write uses UpdateAsync. A write that reports failure is re-read (uncached): if our
--     save nonce landed, the save counts as done (Roblox notes failed writes can still land).
--   * Invalid profiles are never written.
--
-- The DataStore and clock are injected, so tests run against tests/Mocks/MockDataStore.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)
local ProfileSchema = require(Shared.Domain.ProfileSchema)

export type Options = {
	jobId: string,
	now: () -> number,
	sleep: (seconds: number) -> (),
	lockTimeout: number?, -- seconds without heartbeat before a lock counts as stale (default 600)
	retries: number?, -- attempts per DataStore call (default 4)
	lockRetries: number?, -- load attempts while another server holds the lock (default 3)
	keyPrefix: string?,
	getOptions: any?, -- DataStoreGetOptions with UseCache = false, for write verification
}

export type SessionStore = {
	load: (self: SessionStore, userId: number) -> Types.Result<Types.PlayerProfile>,
	save: (self: SessionStore, userId: number, profile: Types.PlayerProfile) -> Types.Result<nil>,
	release: (self: SessionStore, userId: number, profile: Types.PlayerProfile) -> Types.Result<nil>,
}

local SessionStore = {}
SessionStore.__index = SessionStore

type Self = typeof(setmetatable(
	{} :: {
		_store: any,
		_jobId: string,
		_now: () -> number,
		_sleep: (number) -> (),
		_lockTimeout: number,
		_retries: number,
		_lockRetries: number,
		_prefix: string,
		_getOptions: any,
		_nonce: number,
	},
	SessionStore
))

function SessionStore.new(store: any, options: Options): SessionStore
	local self = setmetatable({
		_store = store,
		_jobId = options.jobId,
		_now = options.now,
		_sleep = options.sleep,
		_lockTimeout = options.lockTimeout or 600,
		_retries = options.retries or 4,
		_lockRetries = options.lockRetries or 3,
		_prefix = options.keyPrefix or "player_",
		_getOptions = options.getOptions,
		_nonce = 0,
	}, SessionStore)
	return (self :: any) :: SessionStore
end

local function key(self: Self, userId: number): string
	return `{self._prefix}{userId}`
end

-- Runs a DataStore call with exponential backoff. Returns (ok, result-or-error).
local function withRetry(self: Self, fn: () -> any): (boolean, any)
	local lastErr: any = nil
	for attempt = 1, self._retries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < self._retries then
			self._sleep(2 ^ (attempt - 1))
		end
	end
	return false, lastErr
end

function SessionStore.load(self: Self, userId: number): Types.Result<Types.PlayerProfile>
	for attempt = 1, self._lockRetries do
		local outcome = "unknown"
		local loaded: Types.PlayerProfile? = nil
		local now = self._now()
		local ok, callErr = withRetry(self, function()
			return self._store:UpdateAsync(key(self, userId), function(current: any)
				local record = if typeof(current) == "table" then current else { meta = {}, data = nil }
				record.meta = if typeof(record.meta) == "table" then record.meta else {}
				local lock = record.meta.lock
				if
					typeof(lock) == "table"
					and lock.jobId ~= self._jobId
					and now - (lock.at or 0) < self._lockTimeout
				then
					outcome = "SessionLocked"
					return nil
				end
				local migrated = ProfileSchema.load(record.data, userId)
				if not migrated.ok then
					outcome = migrated.err
					return nil
				end
				record.data = migrated.value
				record.meta.lock = { jobId = self._jobId, at = now }
				outcome = "ok"
				loaded = migrated.value
				return record
			end)
		end)
		if not ok then
			return Result.fail(`DataStoreUnavailable:{callErr}`)
		end
		if outcome == "ok" and loaded then
			return Result.ok(loaded :: Types.PlayerProfile)
		end
		if outcome ~= "SessionLocked" then
			return Result.fail(outcome)
		end
		if attempt < self._lockRetries then
			self._sleep(5)
		end
	end
	return Result.fail("SessionLocked")
end

local function write(
	self: Self,
	userId: number,
	profile: Types.PlayerProfile,
	release: boolean
): Types.Result<nil>
	local valid = ProfileSchema.validate(profile :: any)
	if not valid.ok then
		return Result.fail(`InvalidProfile:{valid.err}`)
	end
	self._nonce += 1
	local nonce = `{self._jobId}:{self._nonce}`
	local now = self._now()
	local outcome = "unknown"
	local ok = withRetry(self, function()
		return self._store:UpdateAsync(key(self, userId), function(current: any)
			if typeof(current) ~= "table" or typeof(current.meta) ~= "table" then
				outcome = "NoRecord"
				return nil
			end
			local lock = current.meta.lock
			if typeof(lock) ~= "table" or lock.jobId ~= self._jobId then
				outcome = "LockLost"
				return nil
			end
			current.data = profile
			current.meta.lock = if release then nil else { jobId = self._jobId, at = now }
			current.meta.saveNonce = nonce
			current.meta.savedAt = now
			outcome = "ok"
			return current
		end)
	end)
	if ok then
		return if outcome == "ok" then Result.ok(nil) else Result.fail(outcome)
	end
	-- The call reported failure: check whether our write landed anyway.
	local readOk, stored = pcall(function()
		return self._store:GetAsync(key(self, userId), self._getOptions)
	end)
	if
		readOk
		and typeof(stored) == "table"
		and typeof(stored.meta) == "table"
		and stored.meta.saveNonce == nonce
	then
		return Result.ok(nil)
	end
	return Result.fail("DataStoreUnavailable")
end

function SessionStore.save(self: Self, userId: number, profile: Types.PlayerProfile): Types.Result<nil>
	return write(self, userId, profile, false)
end

function SessionStore.release(self: Self, userId: number, profile: Types.PlayerProfile): Types.Result<nil>
	return write(self, userId, profile, true)
end

return SessionStore
