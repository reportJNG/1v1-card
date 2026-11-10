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
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local ClientView = require(Shared.Domain.ClientView)
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local Persistence = script.Parent.Parent:WaitForChild("Persistence")
local SessionStore = require(Persistence.SessionStore)
local ProfileManager = require(Persistence.ProfileManager)
local InMemoryDataStore = require(Persistence.InMemoryDataStore)
local Telemetry = require(script.Parent.Telemetry)

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_INTERVAL = 60
local TICK = 10

local PlayerDataService = {}

local manager: ProfileManager.ProfileManager? = nil
local usingMemoryStore = false
local shadows: { [Player]: ClientView.View } = {} -- last view sent to each client
local sender: ((Player, string, any) -> ())? = nil -- set by NetService
local loadedCallbacks: { (Player, Types.PlayerProfile) -> () } = {}
local retainers: { (userId: number) -> boolean } = {} -- "keep this profile after the player leaves"
local retained: { [number]: boolean } = {}

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
	retained[player.UserId] = nil
	if ProfileSchema.grantStarter(loaded.value, os.time()) then
		PlayerDataService.markDirty(player.UserId)
	end
	player:SetAttribute("ProfileLoaded", true)
	player:SetAttribute("Trophies", loaded.value.trophies) -- shown on name plates (App/Nameplates)
	Telemetry.event(player, "session_start", {
		coins = loaded.value.coins,
		cards = loaded.value.nextCardSerial - 1,
		trophies = loaded.value.trophies,
	})
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, loaded.value)
	end
	PlayerDataService.push(player)
end

local function release(userId: number)
	local released = getManager():release(userId)
	if not released.ok then
		-- Kept in memory; autosaveTick retries the release (and BindToClose flushes it).
		warn(`[PlayerData] release failed for {userId}: {released.err}`)
	end
end

local function onPlayerRemoving(player: Player)
	shadows[player] = nil
	for _, keep in retainers do
		if keep(player.UserId) then
			-- In a live match: keep the session (and its lock) so the result can be settled and a
			-- quick rejoin finds the same profile. BattleService calls releaseIfAbsent afterwards.
			retained[player.UserId] = true
			return
		end
	end
	release(player.UserId)
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

-- Sends the client what changed since the last push (a full snapshot the first time).
function PlayerDataService.push(player: Player)
	local profile = PlayerDataService.getProfile(player.UserId)
	if profile == nil or sender == nil then
		return
	end
	local view = ClientView.build(profile)
	if player:GetAttribute("Trophies") ~= profile.trophies then
		player:SetAttribute("Trophies", profile.trophies)
	end
	local old = shadows[player]
	if old == nil then
		shadows[player] = view
		sender(player, "Profile.Snapshot", view)
		return
	end
	local delta = ClientView.diff(old, view)
	if delta then
		shadows[player] = view
		sender(player, "Profile.Delta", delta)
	end
end

function PlayerDataService.setSender(fn: (Player, string, any) -> ())
	sender = fn
	for player in shadows do
		shadows[player] = nil -- resend snapshots through the new sender
	end
	for _, player in Players:GetPlayers() do
		PlayerDataService.push(player)
	end
end

-- Runs `callback(player, profile)` each time a profile finishes loading.
function PlayerDataService.onLoaded(callback: (Player, Types.PlayerProfile) -> ())
	table.insert(loadedCallbacks, callback)
end

-- `keep(userId)` is asked when a player leaves; while it returns true the profile stays loaded.
function PlayerDataService.retainWhile(keep: (userId: number) -> boolean)
	table.insert(retainers, keep)
end

-- Releases a profile kept by retainWhile once its owner is no longer on this server.
function PlayerDataService.releaseIfAbsent(userId: number)
	if retained[userId] and Players:GetPlayerByUserId(userId) == nil then
		retained[userId] = nil
		release(userId)
	end
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
