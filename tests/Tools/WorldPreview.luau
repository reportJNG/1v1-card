--!strict
-- Studio-only (dev.project.json): previews the lobby and the worlds in Edit mode, for screenshots
-- and art passes. Command Bar / MCP execute_luau:
--   local W = require(game.ServerScriptService.Tests.Tools.WorldPreview)
--   W.build()        -- the hub and all 10 worlds with terrain; waits for every mesh
--   W.show(3)        -- World 3's lighting, sky and the camera on its overview shot
--   W.show(0)        -- the lobby
-- Returns the camera position and target so a capture tool can reuse them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local WorldLayout = require(ReplicatedStorage.Shared.Domain.WorldLayout)
local Server = ServerScriptService:WaitForChild("Server")
local WorldBuilder = require(Server.World.WorldBuilder) :: any
local HubBuilder = require(Server.World.HubBuilder) :: any

local WorldPreview = {}

local function areaFx(): any
	local client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	return require(client.App.AreaFx) :: any
end

function WorldPreview.build(): string
	WorldBuilder.buildAll(workspace, workspace.Terrain)
	HubBuilder.build(workspace)
	local expected = 0
	for w = 1, 10 do
		expected += #WorldLayout.decor(w) + #WorldLayout.nodes(w) + 3
	end
	local n = 0
	for _ = 1, 90 do
		task.wait(1)
		n = 0
		for _, d in workspace.Worlds:GetDescendants() do
			if d:IsA("MeshPart") then
				n += 1
			end
		end
		if n >= expected then
			break
		end
	end
	return `{n}/{expected} world meshes`
end

-- The overview shot of a world: from behind the spawn, high, toward the field.
function WorldPreview.shot(worldId: number): (Vector3, Vector3)
	if worldId == 0 then
		local s = HubBuilder.spawnPosition()
		return s + Vector3.new(-30, 34, 40), s + Vector3.new(10, 0, -110)
	end
	local o = WorldLayout.origin(worldId)
	local origin = Vector3.new(o.x, o.y, o.z)
	return origin + Vector3.new(-40, 58, 118), origin + Vector3.new(20, 0, -70)
end

-- The arrival shot (Phase 12): from just behind the spawn, over the gate into the field.
function WorldPreview.arrival(worldId: number): (Vector3, Vector3)
	local o = WorldLayout.origin(worldId)
	local origin = Vector3.new(o.x, o.y, o.z)
	return origin + Vector3.new(-14, 30, 178), origin + Vector3.new(6, 0, 20)
end

function WorldPreview.show(worldId: number): { number }
	areaFx().apply(if worldId == 0 then "hub" else `world{worldId}`, true)
	local sky = Lighting:FindFirstChild("AreaSky")
	if sky then
		ContentProvider:PreloadAsync({ sky })
	end
	task.wait(1.5)
	local cam, at = WorldPreview.shot(worldId)
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(cam, at)
	return { cam.X, cam.Y, cam.Z, at.X, at.Y, at.Z }
end

return WorldPreview
