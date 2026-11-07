--!strict
-- Builds the 10 worlds as separate maps from Config/WorldLayouts + Shared/Domain/WorldLayout,
-- each one self-contained under Workspace.Worlds.World01..World10:
--   Spawn          where World.Travel puts the character
--   Farm/Nodes     resource nodes (an invisible prompt part at the exact server range-check
--                  position, with the generated mesh standing on the ground under it)
--   Merchant       the merchant cart and its Sell prompt
--   GuardianTrial  the trial gate, the Guardian's figure and the Challenge prompt
--   LobbyPortal    the Back to Lobby portal (World.Hub)
--   Decor          generated scenery meshes (Config/WorldProps)
--   Bounds         invisible walls at the edge of the play area (WorldService returns anyone who
--                  still falls out of the map to the hub)
--   Ambience       the world's ambient particles
-- plus the world's terrain (Terrain is one object per place, so it is generated from the
-- world's TerrainSpec instead of living in the model). Everything players use exists when
-- buildWorld returns; the meshes stream in on a background thread so server boot never waits on
-- the asset service. The art is a first pass (ContentStatus: worldArt): every built instance
-- carries Placeholder = true. Idempotent: rebuilding replaces the previous build.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local WorldLayouts = require(Shared.Config.WorldLayouts)
local WorldProps = require(Shared.Config.WorldProps)
local HubLayout = require(Shared.Config.HubLayout)
local UiAssets = require(Shared.Config.UiAssets)
local Worlds = require(Shared.Config.Worlds)
local Items = require(Shared.Config.Items)
local Guardians = require(Shared.Config.Guardians)
local WorldLayout = require(Shared.Domain.WorldLayout)
local Standee = require(Shared.Art.Standee)
local MeshLibrary = require(script.Parent.MeshLibrary)

local WorldBuilder = {}

local function v3(p: WorldLayout.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function asset(slot: string): string
	local def = UiAssets[slot]
	return if def.final and def.final ~= "" then def.final else def.temp
end

local function material(name: string): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

-- The model name for a world: World01..World10.
function WorldBuilder.modelName(worldId: number): string
	return string.format("World%02d", worldId)
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

-- An invisible anchor part (prompts, labels, lights hang off it).
local function anchor(name: string, at: Vector3, size: Vector3, parent: Instance): Part
	return part({
		Name = name,
		Size = size,
		Position = at,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
end

local function label(
	adornee: BasePart,
	text: string,
	color: Color3,
	height: number,
	distance: number?,
	studs: number?
)
	local gui = Instance.new("BillboardGui")
	local h = studs or 3.2 -- text height in studs
	gui.Size = UDim2.fromScale(text:len() * h * 0.28 + h, h)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = distance or 90
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color
	t.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	t.TextScaled = true
	t.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#05070F")
	stroke.Thickness = 2.5
	stroke.Parent = t
	gui.Parent = adornee
end

local function prompt(parent: BasePart, action: string, object: string, range: number, name: string)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.MaxActivationDistance = range
	pp.HoldDuration = 0
	pp.Style = Enum.ProximityPromptStyle.Custom -- drawn by the client (App/Prompts)
	pp.RequiresLineOfSight = false
	pp.Parent = parent
end

local function light(parent: BasePart, color: string, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

-- A generated mesh from Config/WorldProps (or the hub's models) standing at `base`. Nil when the
-- key or the mesh is missing; callers keep working without the visual.
local function prop(key: string, base: Vector3, rotY: number?, scale: number?, parent: Instance): MeshPart?
	local def = WorldProps.Models[key] or HubLayout.Models[key]
	if def == nil then
		warn(`[WorldBuilder] no model {key}`)
		return nil
	end
	local m = MeshLibrary.place(key, def, base, rotY, scale)
	if m == nil then
		return nil
	end
	m:SetAttribute("Placeholder", true)
	m.Parent = parent
	return m
end

------------------------------------------------------------------------------------- terrain

-- Generates (or regenerates) a world's terrain: the field slab or floating island, the path from
-- the spawn, the centre feature, the ring of hills outside the walls and any floating rocks.
function WorldBuilder.terrain(worldId: number, terrain: Terrain)
	local spec = WorldLayouts.ByWorld[worldId].theme.terrain
	local o = v3(WorldLayout.origin(worldId))
	local half = WorldLayouts.WORLD_SIZE / 2
	for name, hex in spec.colors do
		pcall(function()
			terrain:SetMaterialColor(material(name), Color3.fromHex(hex))
		end)
	end
	-- Clear this world's volume first, so a rebuild never stacks on the last one.
	terrain:FillBlock(CFrame.new(o + Vector3.new(0, 40, 0)), Vector3.new(720, 260, 720), Enum.Material.Air)

	local ground = material(spec.ground)
	if spec.island then
		terrain:FillCylinder(CFrame.new(o - Vector3.new(0, 6, 0)), 12, half + 28, ground)
		-- Rocky underside tapering into the void.
		-- (Every fill stays below the field's underside, y = -12, so the field stays flat.)
		for i = 0, 7 do
			local a = i / 8 * 2 * math.pi
			local r = half * 0.55
			terrain:FillBall(o + Vector3.new(math.cos(a) * r, -54, math.sin(a) * r), 40, material(spec.hills))
		end
		terrain:FillBall(o - Vector3.new(0, 110, 0), 96, material(spec.hills))
		terrain:FillCylinder(CFrame.new(o - Vector3.new(0, 6, 0)), 12, half + 28, ground)
	else
		terrain:FillBlock(CFrame.new(o - Vector3.new(0, 8, 0)), Vector3.new(560, 16, 560), ground)
	end

	-- The path from the spawn to the field, flush with the ground.
	local centre = v3(WorldLayout.fieldCentre(worldId))
	local spawn = v3(WorldLayout.spawn(worldId))
	local pathLen = spawn.Z + 30 - centre.Z
	terrain:FillBlock(
		CFrame.new(o.X, -2, (spawn.Z + 30 + centre.Z) / 2),
		Vector3.new(14, 4, pathLen),
		material(spec.path)
	)
	terrain:FillCylinder(CFrame.new(spawn.X, -2, spawn.Z + 10), 4, 26, material(spec.path))

	-- The centre feature: a pond, a frozen lake, a lava pool or a lawn.
	if spec.centre then
		local m = material(spec.centre.material)
		local r = spec.centre.radius
		if m == Enum.Material.Water then
			terrain:FillCylinder(CFrame.new(centre - Vector3.new(0, 2, 0)), 4, r + 5, material(spec.path))
			terrain:FillCylinder(CFrame.new(centre - Vector3.new(0, 3, 0)), 6, r, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(centre - Vector3.new(0, 4.5, 0)), 5, r, m)
		else
			terrain:FillCylinder(CFrame.new(centre - Vector3.new(0, 2, 0)), 4, r, m)
		end
	end

	-- Hills ringing the play area, outside the walls (a floating island gets low rocky rims).
	local seed = worldId * 104729 + 3
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local hills = material(spec.hills)
	local count = if spec.island then 18 else 34
	for i = 1, count do
		local a = (i + rand() * 0.6) / count * 2 * math.pi
		local dist = (if spec.island then half + 18 else half + 44) + rand() * 30
		local radius = (if spec.island then 14 else 28) + rand() * spec.hillHeight * 0.4
		local height = spec.hillHeight * (0.55 + rand() * 0.45)
		local p = o + Vector3.new(math.cos(a) * dist, height - radius, math.sin(a) * dist)
		terrain:FillBall(p, radius, hills)
	end
	-- Floating rocks in the sky.
	for _ = 1, spec.floating or 0 do
		local a = rand() * 2 * math.pi
		local dist = half * (0.6 + rand() * 0.8)
		local p = o + Vector3.new(math.cos(a) * dist, 60 + rand() * 70, math.sin(a) * dist)
		local r = 14 + rand() * 10
		terrain:FillBall(p, r, hills)
		terrain:FillBall(p - Vector3.new(0, r * 0.8, 0), r * 0.55, hills)
	end
end

------------------------------------------------------------------------------------- the world

local function buildSpawn(worldId: number, model: Model, accent: string)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = false -- everyone spawns in the hub (HubBuilder); travel moves them here
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = v3(WorldLayout.spawn(worldId)) - Vector3.new(0, 3.5, 0)
	spawn.Color = Color3.fromHex(accent)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.8
	spawn.Duration = 0
	spawn:SetAttribute("Placeholder", true)
	spawn.Parent = model
	local world = Worlds.ById[worldId]
	local sign = anchor("WorldSign", spawn.Position + Vector3.new(0, 10, -40), Vector3.one, model)
	label(
		sign,
		`WORLD {worldId} · {string.upper(world.displayName)}`,
		Color3.fromHex("#FFE27A"),
		0,
		160,
		2.4
	)
end

local function buildNodes(worldId: number, farm: Folder, accent: string): { () -> () }
	local nodes = Instance.new("Folder")
	nodes.Name = "Nodes"
	nodes.Parent = farm
	local visuals: { () -> () } = {}
	for _, node in WorldLayout.nodes(worldId) do
		local item = Items.ById[node.resource.itemId]
		local rare = node.resource.rareItemId == nil
		local p = anchor(node.id, v3(node.position), Vector3.new(4, 4, 4), nodes)
		p:SetAttribute("NodeId", node.id)
		p:SetAttribute("ItemId", item.id)
		p:SetAttribute("RespawnSeconds", node.resource.respawnSeconds)
		prompt(p, "Harvest", item.displayName, WorldLayouts.HARVEST_RANGE - 2, "Harvest")
		if rare then
			light(p, accent, 14, 1.4)
		end
		local base = Vector3.new(node.position.x, 0, node.position.z)
		local rot = (#visuals * 47) % 360
		table.insert(visuals, function()
			local m = prop(node.resource.model, base, rot, if rare then 1.15 else 1, p)
			if m then
				m.Name = "Visual"
				m.CanCollide = false
				m.CanQuery = false
			end
		end)
	end
	return visuals
end

local function buildMerchant(worldId: number, model: Model, name: string): () -> ()
	local folder = Instance.new("Model")
	folder.Name = "Merchant"
	folder.Parent = model
	local at = v3(WorldLayout.merchant(worldId))
	local npc = anchor("Merchant", at + Vector3.new(0, 3.5, 0), Vector3.new(4, 7, 4), folder)
	npc:SetAttribute("Npc", "Merchant")
	label(npc, name, Color3.fromHex("#F2C14E"), 13) -- above the cart
	prompt(npc, "Sell items", name, WorldLayouts.MERCHANT_RANGE - 2, "Sell")
	light(npc, "#FFB45A", 18, 1.5)
	return function()
		local cart = prop("merchant_cart", Vector3.new(at.X, 0, at.Z - 4), 160, 1.5, folder)
		if cart then
			cart.Name = "Cart"
		end
	end
end

local function buildGuardian(worldId: number, model: Model, accent: string): () -> ()
	local folder = Instance.new("Model")
	folder.Name = "GuardianTrial"
	folder.Parent = model
	local def = Guardians.ByWorld[worldId]
	local at = v3(WorldLayout.guardian(worldId))
	local npc = anchor("Guardian", at + Vector3.new(0, 4.5, 0), Vector3.new(5, 9, 5), folder)
	npc:SetAttribute("Npc", "Guardian")
	label(npc, `{def.displayName}`, Color3.fromHex("#C4B5FD"), 12)
	label(npc, "GUARDIAN TRIAL", Color3.fromHex(accent), 9.5)
	prompt(npc, "Challenge", def.displayName, 14, "Challenge")
	light(npc, "#A469FF", 22, 2.2)
	-- The Guardian stands in the gate: a standee of its lead card (Shared/Art/Standee), scaled up,
	-- facing the spawn.
	local ok, standee = pcall(Standee.build, def.deck[1].characterId)
	if ok and standee then
		local figure = standee :: Model
		figure.Name = "Figure"
		figure:ScaleTo(1.6)
		figure:PivotTo(CFrame.new(at.X, 0, at.Z - 2) * CFrame.Angles(0, math.rad(200), 0))
		figure.Parent = folder
	end
	return function()
		local gate = prop("guardian_gate", Vector3.new(at.X, 0, at.Z - 4), 160, 1.6, folder)
		if gate then
			gate.Name = "Gate"
		end
	end
end

local function buildLobbyPortal(worldId: number, model: Model): () -> ()
	local folder = Instance.new("Model")
	folder.Name = "LobbyPortal"
	folder.Parent = model
	local at = v3(WorldLayout.lobbyPortal(worldId))
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 13, 13),
		CFrame = CFrame.new(at + Vector3.new(0, 8.5, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromHex("#A469FF"),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	}, folder)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Swirl"
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.CanvasSize = Vector2.new(512, 512)
		gui.Parent = core
		local img = Instance.new("ImageLabel")
		img.Name = "Swirl"
		img.Image = asset("portal_swirl")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = gui
	end
	light(core, "#C77DFF", 26, 3)
	local trigger = anchor("Lobby", at + Vector3.new(0, 4, 0), Vector3.new(4, 4, 4), folder)
	prompt(trigger, "Return", "Back to Lobby", 14, "WorldLobby")
	label(trigger, "BACK TO LOBBY", Color3.fromHex("#FFE27A"), 13)
	return function()
		local ring = prop("portal", at, 180, 1.4, folder)
		if ring then
			ring.Name = "Ring"
		end
	end
end

local function buildBounds(worldId: number, model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Bounds"
	folder.Parent = model
	local o = v3(WorldLayout.origin(worldId))
	local half = WorldLayouts.WORLD_SIZE / 2
	for i, side in
		{ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	do
		local along = if side.X ~= 0
			then Vector3.new(2, 200, half * 2 + 4)
			else Vector3.new(half * 2 + 4, 200, 2)
		part({
			Name = `Wall{i}`,
			Size = along,
			Position = o + side * (half + 1) + Vector3.new(0, 90, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
		}, folder)
	end
end

local function buildAmbience(worldId: number, model: Model, spec: WorldLayouts.Ambience)
	local o = v3(WorldLayout.origin(worldId))
	local size = WorldLayouts.WORLD_SIZE
	local height = if spec.direction == "fall" then 46 else 1
	local emitterPart = anchor("Ambience", o + Vector3.new(0, height, -20), Vector3.new(size, 1, size), model)
	emitterPart.CanQuery = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = asset(spec.texture)
	e.Rate = spec.rate
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, spec.size),
		NumberSequenceKeypoint.new(0.8, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	local keys = {}
	for i, hex in spec.colors do
		table.insert(
			keys,
			ColorSequenceKeypoint.new((i - 1) / math.max(1, #spec.colors - 1), Color3.fromHex(hex))
		)
	end
	e.Color = ColorSequence.new(keys)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-40, 40)
	if spec.direction == "fall" then
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Speed = NumberRange.new(3, 6)
		e.Lifetime = NumberRange.new(8, 12)
		e.Acceleration = Vector3.new(0.8, 0, 0.4)
	elseif spec.direction == "rise" then
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(2, 5)
		e.Lifetime = NumberRange.new(5, 9)
	else
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(0.5, 2)
		e.Lifetime = NumberRange.new(6, 10)
		e.Acceleration = Vector3.new(0.5, 0.6, 0.3)
	end
	e.Parent = emitterPart
end

-- Builds one world's model (and its terrain when `terrain` is given) under `root`. Returns the
-- model and a function that places the generated meshes (it yields on the asset service).
function WorldBuilder.buildWorld(worldId: number, root: Instance, terrain: Terrain?): (Model, () -> ())
	local layout = WorldLayouts.ByWorld[worldId]
	local world = Worlds.ById[worldId]
	assert(layout and world, `no layout for world {worldId}`)
	local name = WorldBuilder.modelName(worldId)
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Default
	model:SetAttribute("WorldId", worldId)
	model:SetAttribute("DisplayName", world.displayName)
	model:SetAttribute("Placeholder", true)
	local accent = layout.theme.accent

	if terrain then
		WorldBuilder.terrain(worldId, terrain)
	end
	buildSpawn(worldId, model, accent)
	local farm = Instance.new("Folder")
	farm.Name = "Farm"
	farm.Parent = model
	local visuals = buildNodes(worldId, farm, accent)
	table.insert(visuals, buildMerchant(worldId, model, layout.merchantName))
	table.insert(visuals, buildGuardian(worldId, model, accent))
	table.insert(visuals, buildLobbyPortal(worldId, model))
	buildBounds(worldId, model)
	buildAmbience(worldId, model, layout.theme.ambience)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	for i, d in WorldLayout.decor(worldId) do
		table.insert(visuals, function()
			local m = prop(d.model, v3(d.position), d.rotY, d.scale, decor)
			if m then
				m.Name = `{d.model}_{i}`
			end
		end)
	end
	model.Parent = root
	return model,
		function()
			for _, place in visuals do
				if model.Parent == nil then
					return -- rebuilt or removed meanwhile
				end
				place()
			end
		end
end

-- Builds every world under Workspace.Worlds, with terrain. The meshes load in the background.
function WorldBuilder.buildAll(parent: Instance, terrain: Terrain?): Folder
	local existing = parent:FindFirstChild("Worlds")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "Worlds"
	local loaders = {}
	for _, world in Worlds.List do
		local _, load = WorldBuilder.buildWorld(world.id, root, terrain)
		table.insert(loaders, load)
	end
	root.Parent = parent
	task.spawn(function()
		for _, load in loaders do
			load()
		end
	end)
	return root
end

return WorldBuilder
