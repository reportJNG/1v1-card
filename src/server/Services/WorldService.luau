--!strict
-- Worlds on a Hub server: builds the hub lobby and the 10 world maps, and keeps the lobby the
-- spawn point: every character spawns there (on PLAY and on respawn) and is brought back there if
-- it falls out of a map; after a battle SessionService puts it back where it stood. Handles World.Travel (unlocked
-- worlds only, checked on the profile) and World.Hub (the lobby portal in each world and the HUD's
-- Lobby button). The World attribute is 0 in the lobby, 1-10 in a world. Battle servers build no
-- worlds.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Progress = require(Shared.Domain.Progress)
local Quests = require(Shared.Domain.Quests)
local WorldLayout = require(Shared.Domain.WorldLayout)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local WorldBuilder = require(Server:WaitForChild("World").WorldBuilder)
local HubBuilder = require(Server:WaitForChild("World").HubBuilder)
local ArenaBuilder = require(Server:WaitForChild("World").ArenaBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Telemetry)

local WorldService = {}

-- The session gate (SessionService), required lazily: SessionService requires this module's peers.
local function sessionAllows(player: Player, action: string): boolean
	local SessionService = require(script.Parent.SessionService) :: any
	return SessionService.allows(player, action)
end

local function isBattleServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

local function place(player: Player, worldId: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and root then
		local s = WorldLayout.spawn(worldId)
		character:PivotTo(CFrame.new(s.x, s.y, s.z))
	end
	player:SetAttribute("World", worldId)
end

-- The hub plaza (World attribute 0): where every character spawns.
local function placeInHub(player: Player)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(CFrame.new(HubBuilder.spawnPosition()) * CFrame.Angles(0, 0, 0))
	end
	player:SetAttribute("World", 0)
end

-- The server-side position of a player's character, for range checks (never sent by the client).
function WorldService.positionOf(player: Player): WorldLayout.Point?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local p = (root :: BasePart).Position
	return { x = p.X, y = p.Y, z = p.Z }
end

function WorldService.init()
	-- The battle arena templates, on every server (battles run on hub and battle servers).
	ArenaBuilder.buildAll()
	if isBattleServer() then
		return
	end
	WorldBuilder.buildAll(workspace, workspace.Terrain)
	HubBuilder.build(workspace)

	Router.handle("World.Travel", function(player, args, profile)
		if not sessionAllows(player, "travel") then
			return Result.fail("NotPlaying")
		end
		local r = Progress.travel(profile :: any, args.worldId)
		if not r.ok then
			return r
		end
		place(player, args.worldId)
		Quests.track(profile :: any, "Travel", 1, os.time())
		Telemetry.event(player, "travel", { world = args.worldId })
		return Result.ok({ worldId = args.worldId })
	end)

	Router.handle("World.Hub", function(player, _args, _profile)
		if not sessionAllows(player, "hub") then
			return Result.fail("NotPlaying")
		end
		placeInHub(player)
		return Result.ok({ worldId = 0 })
	end)

	local function onCharacter(player: Player)
		local SessionService = require(script.Parent.SessionService) :: any
		if SessionService.isRestoring(player.UserId) then
			return -- back from a battle server: SessionService puts it on the saved spot
		end
		if PlayerDataService.getProfile(player.UserId) then
			task.defer(placeInHub, player)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
	end)
	PlayerDataService.onLoaded(function(player)
		onCharacter(player)
	end)
end

-- Characters below this height have fallen out of a map (the Celestial and Divine islands float).
local FALL_Y = -120

function WorldService.start()
	if isBattleServer() then
		return
	end
	-- After a battle the player goes back to the spot they left (SessionService, MISSION 2.4).
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then
			return
		end
		elapsed = 0
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and root.Position.Y < FALL_Y then
				placeInHub(player)
			end
		end
	end)
end

return WorldService
