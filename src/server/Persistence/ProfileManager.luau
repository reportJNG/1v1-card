--!strict
-- Loaded-profile lifecycle on top of SessionStore. No Roblox events in here: PlayerDataService
-- wires it to Players/BindToClose, and tests drive it directly with a mock DataStore.
--
--   load        on join; refuses while another server holds a live lock
--   saveNow     after purchases and other critical changes; also refreshes the lock heartbeat
--   autosaveTick periodic: saves every session older than the interval (dirty or not, so the
--               lock never goes stale while the player is here) and retries failed releases
--   release     on leave: final save and lock release; on failure it is retried, not dropped
--   releaseAll  on shutdown (BindToClose): flushes and releases every session
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Result = require(Shared.Domain.Result)

type Store = {
	load: (self: any, userId: number) -> Types.Result<Types.PlayerProfile>,
	save: (self: any, userId: number, profile: Types.PlayerProfile) -> Types.Result<nil>,
	release: (self: any, userId: number, profile: Types.PlayerProfile) -> Types.Result<nil>,
}

type Session = {
	profile: Types.PlayerProfile,
	lastSaved: number,
	dirty: boolean,
	releasePending: boolean,
	lockLost: boolean,
}

export type Options = {
	now: () -> number,
	yield: (() -> ())?, -- waits while another save of the same profile is running
	autosaveInterval: number?, -- seconds (default 60)
}

local ProfileManager = {}
ProfileManager.__index = ProfileManager

export type ProfileManager = typeof(setmetatable(
	{} :: {
		_store: Store,
		_now: () -> number,
		_yield: () -> (),
		_interval: number,
		_sessions: { [number]: Session },
		_saving: { [number]: boolean },
	},
	ProfileManager
))

function ProfileManager.new(store: Store, options: Options): ProfileManager
	return setmetatable({
		_store = store,
		_now = options.now,
		_yield = options.yield or function() end,
		_interval = options.autosaveInterval or 60,
		_sessions = {},
		_saving = {},
	}, ProfileManager)
end

function ProfileManager.load(self: ProfileManager, userId: number): Types.Result<Types.PlayerProfile>
	-- A save or release of this profile may still be running (e.g. the player left and rejoined
	-- this server within seconds). Wait for it, then decide from what it left behind.
	while self._saving[userId] do
		self._yield()
	end
	local existing = self._sessions[userId]
	if existing then
		if existing.lockLost then
			self._sessions[userId] = nil -- stale copy; load the owner's version from the store
		else
			-- Still ours (the release never ran or failed, so we still hold the lock): keep it.
			existing.releasePending = false
			return Result.ok(existing.profile)
		end
	end
	local loaded = self._store:load(userId)
	if loaded.ok then
		self._sessions[userId] = {
			profile = loaded.value,
			lastSaved = self._now(),
			dirty = false,
			releasePending = false,
			lockLost = false,
		}
	end
	return loaded
end

function ProfileManager.get(self: ProfileManager, userId: number): Types.PlayerProfile?
	local session = self._sessions[userId]
	if session == nil or session.releasePending or session.lockLost then
		return nil
	end
	return session.profile
end

function ProfileManager.isLockLost(self: ProfileManager, userId: number): boolean
	local session = self._sessions[userId]
	return session ~= nil and session.lockLost
end

function ProfileManager.markDirty(self: ProfileManager, userId: number)
	local session = self._sessions[userId]
	if session then
		session.dirty = true
	end
end

-- Serialises saves of one profile: a second save waits for the first instead of racing it.
local function exclusive(self: ProfileManager, userId: number, fn: () -> Types.Result<nil>): Types.Result<nil>
	while self._saving[userId] do
		self._yield()
	end
	self._saving[userId] = true
	local ok, result = pcall(fn)
	self._saving[userId] = nil
	if not ok then
		return Result.fail(`SaveError:{result}`)
	end
	return result
end

function ProfileManager.saveNow(self: ProfileManager, userId: number): Types.Result<nil>
	local session = self._sessions[userId]
	if session == nil then
		return Result.fail("NotLoaded")
	end
	if session.lockLost then
		return Result.fail("LockLost")
	end
	return exclusive(self, userId, function()
		local saved = self._store:save(userId, session.profile)
		if saved.ok then
			session.dirty = false
			session.lastSaved = self._now()
		elseif saved.err == "LockLost" then
			session.lockLost = true -- another server owns this profile now; never write again
		end
		return saved
	end)
end

function ProfileManager.release(self: ProfileManager, userId: number): Types.Result<nil>
	local session = self._sessions[userId]
	if session == nil then
		return Result.ok(nil)
	end
	if session.lockLost then
		self._sessions[userId] = nil -- nothing of ours to write
		return Result.fail("LockLost")
	end
	session.releasePending = true
	local released = exclusive(self, userId, function()
		if self._sessions[userId] ~= session or not session.releasePending then
			return Result.ok(nil) -- already released, or cancelled because the player rejoined
		end
		local result = self._store:release(userId, session.profile)
		if result.ok or result.err == "LockLost" then
			self._sessions[userId] = nil
		end
		return result
	end)
	return released
end

-- Returns the number of sessions it saved or released.
function ProfileManager.autosaveTick(self: ProfileManager): number
	local done = 0
	local now = self._now()
	local ids = {}
	for userId in self._sessions do
		table.insert(ids, userId)
	end
	for _, userId in ids do
		local session = self._sessions[userId]
		if session == nil then
			continue
		elseif session.releasePending then
			if self:release(userId).ok then
				done += 1
			end
		elseif not session.lockLost and now - session.lastSaved >= self._interval then
			if self:saveNow(userId).ok then
				done += 1
			end
		end
	end
	return done
end

-- Shutdown: flush and release everything. Returns userIds that could not be released.
function ProfileManager.releaseAll(self: ProfileManager, attempts: number?): { number }
	local failed: { number } = {}
	for _ = 1, attempts or 3 do
		failed = {}
		local ids = {}
		for userId in self._sessions do
			table.insert(ids, userId)
		end
		for _, userId in ids do
			local released = self:release(userId)
			if not released.ok and released.err ~= "LockLost" then
				table.insert(failed, userId)
			end
		end
		if #failed == 0 then
			break
		end
	end
	return failed
end

function ProfileManager.count(self: ProfileManager): number
	local n = 0
	for _ in self._sessions do
		n += 1
	end
	return n
end

return ProfileManager
