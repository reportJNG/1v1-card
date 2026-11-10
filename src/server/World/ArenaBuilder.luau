--!strict
-- Builds the 5 arena map templates (Config/Arenas) into ReplicatedStorage.Arenas, and the main
-- menu's stage (Config/MenuStage) into ReplicatedStorage.MenuStage. Each arena is the
-- shared Shared/Art/ArenaKit model (ArenaCore + Dressing) plus the map's meshes, which only the
-- server can load (Server/World/MeshLibrary). Clients clone the template for their match's map
-- around their own battle stage, so every player gets their own copy and nothing in it is
-- replicated game state. Runs on every server (hub and battle servers); meshes stream in on a
-- background thread so boot never waits on the asset service.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Arenas = require(Shared.Config.Arenas)
local MenuStage = require(Shared.Config.MenuStage)
local ArenaLayout = require(Shared.Domain.ArenaLayout)
local ArenaKit = require(Shared.Art.ArenaKit)
local MeshLibrary = require(script.Parent.MeshLibrary)

local ArenaBuilder = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function dress(pieces: { MenuStage.Piece }, dressing: Instance)
	for i, piece in pieces do
		local def = ArenaLayout.modelDef(piece.model)
		local m = def and MeshLibrary.place(piece.model, def :: any, v3(piece.at), piece.rotY, piece.scale)
		if m then
			m.Name = `{piece.model}_{i}`
			m.CanCollide = false
			m.CanQuery = false
			m.CanTouch = false
			m.CastShadow = v3(piece.at).Magnitude < 70
			if piece.light then
				local l = piece.light
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(0, l.height - m.Size.Y / 2, 0)
				a.Parent = m
				local pl = Instance.new("PointLight")
				pl.Color = Color3.fromHex(l.color)
				pl.Range = l.range
				pl.Brightness = l.brightness
				pl.Shadows = false
				pl.Parent = a
			end
			m.Parent = dressing
		end
	end
end

-- Builds every template (replacing old ones). The core and shapes exist on return; meshes follow.
function ArenaBuilder.buildAll(): Folder
	local old = ReplicatedStorage:FindFirstChild("Arenas")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arenas"
	local models = {}
	for _, arena in Arenas.List do
		local model = ArenaKit.build(arena)
		model.Parent = folder
		models[arena.id] = model
	end
	folder.Parent = ReplicatedStorage
	task.spawn(function()
		for _, arena in Arenas.List do
			dress(arena.dressing, models[arena.id]:FindFirstChild("Dressing") :: Instance)
			models[arena.id]:SetAttribute("Dressed", true)
		end
	end)
	return folder
end

-- The main menu's stage (FIX_LOBBY_2 section A): shapes and particles at once, meshes after. Each
-- client clones it far from the lobby while the menu is open (App/MenuScene).
function ArenaBuilder.buildMenuStage(): Model
	local old = ReplicatedStorage:FindFirstChild("MenuStage")
	if old then
		old:Destroy()
	end
	local model = ArenaKit.scene("MenuStage", MenuStage.Prims, MenuStage.Particles)
	model.Parent = ReplicatedStorage
	task.spawn(function()
		dress(MenuStage.Pieces, model:FindFirstChild("Dressing") :: Instance)
		model:SetAttribute("Dressed", true)
	end)
	return model
end

return ArenaBuilder
