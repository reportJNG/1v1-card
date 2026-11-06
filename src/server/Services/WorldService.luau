--!strict
-- Worlds on a Hub server: builds the hub plaza and the 10 blockout worlds, spawns each character
-- in the hub (World attribute 0), and handles World.Travel (unlocked worlds only) and World.Hub
-- (back to the plaza). Battle servers build no worlds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Result = require(Shared.Domain.Result)
local Progress = require(Shared.Domain.Progress)
local WorldLayout = require(Shared.Domain.WorldLayout)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local WorldBuilder = require(Server:WaitForChild("World").WorldBuilder)
local HubBuilder = require(Server:WaitForChild("World").HubBuilder)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Telemetry)

local WorldService = {}

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
	if isBattleServer() then
		return
	end
	WorldBuilder.buildAll(workspace)
	HubBuilder.build(workspace)

	Router.handle("World.Travel", function(player, args, profile)
		local r = Progress.travel(profile :: any, args.worldId)
		if not r.ok then
			return r
		end
		place(player, args.worldId)
		Telemetry.event(player, "travel", { world = args.worldId })
		return Result.ok({ worldId = args.worldId })
	end)

	Router.handle("World.Hub", function(player, _args, _profile)
		placeInHub(player)
		return Result.ok({ worldId = 0 })
	end)

	local function onCharacter(player: Player)
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

return WorldService
