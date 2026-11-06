--!strict
-- Owns player profiles on this server: load on join (session-locked), autosave, save on leave,
-- flush on shutdown. Other services read profiles through here and call saveNow() after
-- critical changes (purchases). Logic lives in Persistence/ProfileManager + SessionStore,
-- which are tested against a mock DataStore; this file only wires Roblox events.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local Persistence = script.Parent.Parent:WaitForChild("Persistence")
local SessionStore = require(Persistence.SessionStore)
local ProfileManager = require(Persistence.ProfileManager)
local InMemoryDataStore = require(Persistence.InMemoryDataStore)

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_INTERVAL = 60
local TICK = 10

local PlayerDataService = {}

local manager: ProfileManager.ProfileManager? = nil
local usingMemoryStore = false

local function getManager(): ProfileManager.ProfileManager
	assert(manager, "PlayerDataService not initialised")
	return manager
end

local function resolveStore(): any
	local ok, storeOrErr = pcall(function()
		local store = DataStoreService:GetDataStore(STORE_NAME)
		store:GetAsync("__probe") -- fails fast when Studio API access is off
		return store
	end)
	if ok then
		return storeOrErr
	end
	if RunService:IsStudio() then
		usingMemoryStore = true
		warn(
			`[PlayerData] DataStore unavailable in Studio ({storeOrErr}). USING AN IN-MEMORY STORE:`
				.. " nothing will persist. Enable Game Settings > Security > Studio Access to API Services"
				.. " to test real saving."
		)
		return InMemoryDataStore.new()
	end
	-- Live server: never fall back. Loads will fail and players are kicked rather than given an
	-- empty profile that could overwrite their real one later.
	warn(`[PlayerData] DataStore unavailable: {storeOrErr}`)
	return DataStoreService:GetDataStore(STORE_NAME)
end

local function onPlayerAdded(player: Player)
	local loaded = getManager():load(player.UserId)
	if not loaded.ok then
		warn(`[PlayerData] load failed for {player.UserId}: {loaded.err}`)
		if player.Parent then
			player:Kick(
				if loaded.err == "SessionLocked"
					then "Your data is still open on another server. Please rejoin in a minute."
					else "Couldn't load your data. Please rejoin."
			)
		end
		return
	end
	if not player.Parent then
		getManager():release(player.UserId) -- left while loading
		return
	end
	player:SetAttribute("ProfileLoaded", true)
end

local function onPlayerRemoving(player: Player)
	local released = getManager():release(player.UserId)
	if not released.ok then
		-- Kept in memory; autosaveTick retries the release (and BindToClose flushes it).
		warn(`[PlayerData] release failed for {player.UserId}: {released.err}`)
	end
end

function PlayerDataService.getProfile(userId: number): Types.PlayerProfile?
	return if manager then manager:get(userId) else nil
end

-- Waits (yielding) until the player's profile is loaded or the timeout passes.
function PlayerDataService.waitForProfile(userId: number, timeout: number): Types.PlayerProfile?
	local deadline = os.clock() + timeout
	repeat
		local profile = PlayerDataService.getProfile(userId)
		if profile then
			return profile
		end
		task.wait(0.25)
	until os.clock() >= deadline or Players:GetPlayerByUserId(userId) == nil
	return PlayerDataService.getProfile(userId)
end

function PlayerDataService.markDirty(userId: number)
	getManager():markDirty(userId)
end

function PlayerDataService.saveNow(userId: number): Types.Result<nil>
	return getManager():saveNow(userId)
end

function PlayerDataService.isUsingMemoryStore(): boolean
	return usingMemoryStore
end

function PlayerDataService.init()
	local jobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`
	local getOptions = Instance.new("DataStoreGetOptions")
	getOptions.UseCache = false
	local sessions = SessionStore.new(resolveStore(), {
		jobId = jobId,
		now = os.time,
		sleep = function(seconds: number)
			task.wait(seconds)
		end,
		getOptions = getOptions,
	})
	manager = ProfileManager.new(sessions :: any, {
		now = os.time,
		yield = function()
			task.wait()
		end,
		autosaveInterval = AUTOSAVE_INTERVAL,
	})

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		local failed = getManager():releaseAll(3)
		if #failed > 0 then
			warn(
				`[PlayerData] shutdown: {#failed} profile(s) could not be saved: {table.concat(failed, ", ")}`
			)
		end
	end)
end

function PlayerDataService.start()
	while true do
		task.wait(TICK)
		getManager():autosaveTick()
	end
end

return PlayerDataService
