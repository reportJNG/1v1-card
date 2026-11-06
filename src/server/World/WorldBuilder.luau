--!strict
-- Builds the 10 worlds as blockouts from Config/WorldLayouts + Shared/Domain/WorldLayout:
-- ground, resource nodes (with a Harvest prompt), the merchant and the Guardian, each at the
-- exact position the server range-checks against. Every built part carries Placeholder = true
-- until world art replaces it (ContentStatus: worldArt). Idempotent: rebuilding replaces the
-- previous build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayouts = require(Shared.Config.WorldLayouts)
local Worlds = require(Shared.Config.Worlds)
local Items = require(Shared.Config.Items)
local Guardians = require(Shared.Config.Guardians)
local WorldLayout = require(Shared.Domain.WorldLayout)

local WorldBuilder = {}

local function v3(p: WorldLayout.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function material(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p:SetAttribute("Placeholder", true)
	p.Parent = parent
	return p
end

local function label(adornee: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, adornee.Size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.4
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Parent = gui
	gui.Parent = adornee
end

local function prompt(parent: BasePart, action: string, object: string, range: number, name: string)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.MaxActivationDistance = range
	pp.HoldDuration = 0
	pp.RequiresLineOfSight = false
	pp.Parent = parent
end

function WorldBuilder.buildWorld(worldId: number, root: Instance): Model
	local layout = WorldLayouts.ByWorld[worldId]
	local world = Worlds.ById[worldId]
	assert(layout and world, `no layout for world {worldId}`)
	local model = Instance.new("Model")
	model.Name = `World{worldId}`
	model:SetAttribute("WorldId", worldId)
	model:SetAttribute("DisplayName", world.displayName)
	model:SetAttribute("Sky", layout.theme.sky)

	local o = WorldLayout.origin(worldId)
	local size = WorldLayouts.WORLD_SIZE
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(size, 4, size),
		Position = Vector3.new(o.x, -2, o.z),
		Color = Color3.fromHex(layout.theme.ground),
		Material = material(layout.theme.material),
	}, model)
	ground:SetAttribute("WorldId", worldId)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = worldId == 1 -- everyone spawns in World 1; WorldService moves them to their world
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = v3(WorldLayout.spawn(worldId)) - Vector3.new(0, 3.5, 0)
	spawn.Color = Color3.fromHex(layout.theme.accent)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn:SetAttribute("Placeholder", true)
	spawn.Parent = model

	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = model
	for _, node in WorldLayout.nodes(worldId) do
		local item = Items.ById[node.resource.itemId]
		local rare = node.resource.rareItemId == nil
		local p = part({
			Name = node.id,
			Shape = if rare then Enum.PartType.Ball else Enum.PartType.Block,
			Size = Vector3.new(4, 4, 4),
			Position = v3(node.position),
			Color = if rare
				then Color3.fromHex(layout.theme.accent)
				else Color3.fromHex(layout.theme.ground):Lerp(Color3.new(1, 1, 1), 0.35),
			Material = if rare then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		}, nodes)
		p:SetAttribute("NodeId", node.id)
		p:SetAttribute("ItemId", item.id)
		p:SetAttribute("RespawnSeconds", node.resource.respawnSeconds)
		prompt(p, "Harvest", item.displayName, WorldLayouts.HARVEST_RANGE - 2, "Harvest")
	end

	local merchant = part({
		Name = "Merchant",
		Size = Vector3.new(4, 7, 4),
		Position = v3(WorldLayout.merchant(worldId)) + Vector3.new(0, 2.5, 0),
		Color = Color3.fromHex("#F2C14E"),
		Material = Enum.Material.SmoothPlastic,
	}, model)
	merchant:SetAttribute("Npc", "Merchant")
	label(merchant, layout.merchantName, Color3.fromHex("#F2C14E"))
	prompt(merchant, "Sell items", layout.merchantName, WorldLayouts.MERCHANT_RANGE - 2, "Sell")

	local guardianDef = Guardians.ByWorld[worldId]
	local guardian = part({
		Name = "Guardian",
		Size = Vector3.new(5, 9, 5),
		Position = v3(WorldLayout.guardian(worldId)) + Vector3.new(0, 3.5, 0),
		Color = Color3.fromHex("#8B5CF6"),
		Material = Enum.Material.Neon,
	}, model)
	guardian:SetAttribute("Npc", "Guardian")
	label(guardian, `{guardianDef.displayName} (Guardian Trial)`, Color3.fromHex("#C4B5FD"))
	prompt(guardian, "Challenge", guardianDef.displayName, 14, "Challenge")

	model.Parent = root
	return model
end

function WorldBuilder.buildAll(parent: Instance): Folder
	local existing = parent:FindFirstChild("Worlds")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Worlds"
	for _, world in Worlds.List do
		WorldBuilder.buildWorld(world.id, root)
	end
	root.Parent = parent
	return root
end

return WorldBuilder
