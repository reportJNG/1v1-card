--!strict
-- The four-screen flow on the server (MISSION section 2): each player is on the main menu,
-- playing, or battling (Domain/PlayState), shown to the client as the "Session" attribute.
--   join          menu: no character (CharacterAutoLoads is off on Hub servers); the lobby streams
--                 in around the menu camera (ReplicationFocus on the hub spawn)
--   Session.Play  menu -> playing: a fresh character at the lobby spawn (WorldService places it)
--   Session.Leave anything -> menu: forfeit a battle (the normal forfeit path), leave the queue,
--                 remove the character, save the profile
--   battle start  the spot the player stands on is saved; after the battle (ranked or Trial) they
--                 go back to it (Domain/ReturnSpot: else the world's spawn, else the lobby)
--   ranked on another server: the spot travels in the teleport data both ways and is restored on
--                 arrival back here, straight into playing (no main menu)
-- World actions (travel, harvest, sell, queue, Trial) refuse players who aren't playing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local PlayState = require(Shared.Domain.PlayState)
local ReturnSpot = require(Shared.Domain.ReturnSpot)
local Progress = require(Shared.Domain.Progress)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Telemetry)

local SessionService = {}

local states: { [number]: PlayState.State } = {}
local spots: { [number]: ReturnSpot.Spot } = {} -- saved at battle start, used once at battle end
local resume: { [number]: ReturnSpot.Spot } = {} -- arrived back from a battle server

local function isBattleServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function setState(player: Player, s: PlayState.State)
	states[player.UserId] = s
	player:SetAttribute("Session", s)
end

function SessionService.state(userId: number): PlayState.State
	return states[userId] or "menu"
end

-- Whether the player may do a world action now (World.Travel, Farm.Harvest, Queue.Join, ...).
function SessionService.allows(player: Player, action: string): boolean
	if isBattleServer() then
		return true
	end
	return PlayState.allows(SessionService.state(player.UserId), action)
end

-- The spot the player's character stands on now (world 0 = lobby), or nil without a character.
function SessionService.captureSpot(player: Player): ReturnSpot.Spot?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return nil
	end
	local cf = (root :: BasePart).CFrame
	local world = player:GetAttribute("World")
	local look = cf.LookVector
	return {
		world = if typeof(world) == "number" then world else 0,
		x = cf.X,
		y = cf.Y,
		z = cf.Z,
		yaw = math.atan2(-look.X, -look.Z),
	}
end

-- Puts the character on the spot ReturnSpot chooses for `saved`.
local function restore(player: Player, saved: any)
	local profile = PlayerDataService.getProfile(player.UserId)
	local choice = ReturnSpot.choose(saved, function(world: number): boolean
		return profile ~= nil and Progress.isWorldUnlocked(profile :: any, world)
	end)
	local s = choice.spot
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(CFrame.new(s.x, s.y, s.z) * CFrame.Angles(0, s.yaw, 0))
	end
	player:SetAttribute("World", s.world)
	return choice.kind
end

local function lobbyFocus(player: Player)
	local spawn = ReturnSpot.lobby()
	local anchor = workspace:FindFirstChild("MenuFocus") :: BasePart?
	if anchor == nil then
		local part = Instance.new("Part")
		part.Name = "MenuFocus"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = Vector3.new(spawn.x, spawn.y, spawn.z)
		part.Parent = workspace
		anchor = part
	end
	player.ReplicationFocus = anchor
end

local function spawnCharacter(player: Player)
	player.ReplicationFocus = nil
	player:LoadCharacterAsync()
end

-- Back to the main menu, like quitting: forfeit, leave the queue, remove the character, save.
local function leave(player: Player)
	local userId = player.UserId
	local BattleService = require(script.Parent.BattleService) :: any
	local MatchmakingService = require(script.Parent.MatchmakingService) :: any
	if BattleService.isInMatch(userId) then
		BattleService.forfeit(userId)
	end
	MatchmakingService.cancel(player)
	spots[userId] = nil
	resume[userId] = nil
	setState(player, "menu")
	player:SetAttribute("World", 0) -- world music, lighting and the HUD follow it
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
	lobbyFocus(player)
	PlayerDataService.markDirty(userId)
	local saved = PlayerDataService.saveNow(userId)
	if not saved.ok then
		warn(`[Session] save on leave deferred for {userId}: {saved.err}`)
	end
end

function SessionService.init()
	if isBattleServer() then
		return
	end
	Players.CharacterAutoLoads = false

	Router.handle("Session.Play", function(player)
		local s = SessionService.state(player.UserId)
		if s ~= "menu" then
			return Result.ok({ state = s }) -- a double PLAY is harmless
		end
		setState(player, PlayState.next(s, "play"))
		spawnCharacter(player)
		Telemetry.event(player, "play", {})
		return Result.ok({ state = "playing" })
	end, { mutates = false })

	Router.handle("Session.Leave", function(player)
		leave(player)
		Telemetry.event(player, "leave_to_menu", {})
		return Result.ok({ state = "menu" })
	end, { mutates = false, needsProfile = false })

	Players.PlayerAdded:Connect(function(player)
		-- Back from a ranked match on a battle server: straight to playing at the saved spot.
		local ok, data = pcall(function()
			return player:GetJoinData()
		end)
		local tp = ok and data and data.TeleportData
		if
			typeof(tp) == "table"
			and tp.fromBattle == true
			and data.SourcePlaceId == game.PlaceId
			and ReturnSpot.isWellFormed(tp.returnSpot)
		then
			resume[player.UserId] = tp.returnSpot
		end
		setState(player, "menu")
		lobbyFocus(player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.Died:Connect(function()
					task.delay(Players.RespawnTime, function()
						if player.Parent and SessionService.state(player.UserId) == "playing" then
							spawnCharacter(player)
						end
					end)
				end)
			end
		end)
	end)
	PlayerDataService.onLoaded(function(player)
		local spot = resume[player.UserId]
		if spot then
			setState(player, "playing")
			spawnCharacter(player) -- yields until the character exists; WorldService skips the lobby
			task.wait()
			restore(player, spot)
			resume[player.UserId] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player.UserId] = nil
		spots[player.UserId] = nil
		resume[player.UserId] = nil
	end)
end

function SessionService.start()
	if isBattleServer() then
		return
	end
	local BattleService = require(script.Parent.BattleService) :: any
	BattleService.onMatchStart(function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			return
		end
		spots[userId] = SessionService.captureSpot(player) or spots[userId]
		setState(player, PlayState.next(SessionService.state(userId), "battleStart"))
	end)
	BattleService.onMatchEnd(function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if player == nil then
			spots[userId] = nil
			return
		end
		local before: PlayState.State = SessionService.state(userId)
		setState(player, PlayState.next(before, "battleEnd"))
		if before == "battling" then
			local kind = restore(player, spots[userId])
			Telemetry.event(player, "battle_return", { to = kind })
		end
		spots[userId] = nil
	end)
end

-- For WorldService: whether a character that just spawned should be placed in the lobby (a normal
-- PLAY or respawn) or is being restored to a saved spot (back from a battle server).
function SessionService.isRestoring(userId: number): boolean
	return resume[userId] ~= nil
end

return SessionService
