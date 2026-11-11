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
local Billboard = require(Shared.Ui.Billboard)
local Power = require(Shared.Domain.Power)
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

-- The generated ground's surface height. Terrain snaps to 4-stud voxels, so the field filled up to
-- y = 0 comes out at y = 2 (measured in every world, 2026-11-10; a build-time raycast can't see
-- terrain written in the same frame). Node meshes, their rings and the gate stand on it.
local GROUND_Y = 2
local function groundY(_x: number, _z: number): number
	return GROUND_Y
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

-- 12345 -> "12,345" for billboards.
local function thousands(n: number): string
	local s = tostring(n)
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- World text on an object (Shared/Ui/Billboard: one look for every billboard in the game).
local function label(adornee: BasePart, spec: Billboard.Spec, kind: { maxDistance: number })
	local full = table.clone(spec) :: any
	full.maxDistance = full.maxDistance or kind.maxDistance
	Billboard.make(full).Parent = adornee
end

-- An interact prompt, drawn by the client (App/Prompts) as a billboard: the key plate, `action` as
-- one big word, and `icon` (an icon slot) or the node's item icon (BAD_GUI_9 section 1). `hold` makes
-- it a hold (a ring fills around the key plate).
local function prompt(
	parent: BasePart,
	action: string,
	object: string,
	range: number,
	name: string,
	icon: string?,
	hold: number?
): ProximityPrompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = name
	pp.ActionText = action
	pp.ObjectText = object
	pp.MaxActivationDistance = range
	pp.HoldDuration = hold or 0
	if icon then
		pp:SetAttribute("Icon", icon)
	end
	pp.Style = Enum.ProximityPromptStyle.Custom -- drawn by the client (App/Prompts)
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	return pp
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
	-- Paths from the spawn to the merchant and the Guardian.
	for _, target in { v3(WorldLayout.merchant(worldId)), v3(WorldLayout.guardian(worldId)) } do
		local from = Vector3.new(spawn.X, -2, spawn.Z)
		local to = Vector3.new(target.X, -2, target.Z)
		local mid = (from + to) / 2
		terrain:FillBlock(
			CFrame.lookAt(mid, to),
			Vector3.new(8, 4, (to - from).Magnitude),
			material(spec.path)
		)
	end

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

-- The landmark at the spawn (Phase 12): a paved plaza with an accent ring, a welcome arch over the
-- path into the field (lit pillars, a glowing trim) and two big copies of the world's signature mesh
-- flanking it. Returns where the world's name sign goes (over the arch).
local function buildGate(worldId: number, model: Model, accent: string, gate: WorldLayouts.Gate): Vector3
	local folder = Instance.new("Folder")
	folder.Name = "Gate"
	folder.Parent = model
	local s = v3(WorldLayout.spawn(worldId))
	local a = v3(WorldLayout.arch(worldId))
	local g = groundY(a.X, a.Z)
	local stone = Color3.fromHex(gate.stone)
	local mat = material(gate.material)
	local glow = Color3.fromHex(gate.ring or accent)
	part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 30, 30),
		CFrame = CFrame.new(s.X, g + 0.1, s.Z + 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = stone:Lerp(Color3.new(0, 0, 0), 0.15),
		Material = mat,
		CanCollide = true,
	}, folder)
	part({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 31, 31),
		CFrame = CFrame.new(s.X, g + 0.14, s.Z + 2) * CFrame.Angles(0, 0, math.rad(90)),
		Color = glow,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	}, folder)
	for _, side in { -1, 1 } do
		local pillar = part({
			Name = "Pillar",
			Size = Vector3.new(3, 16, 3),
			Position = Vector3.new(a.X + side * 10, g + 8, a.Z),
			Color = stone,
			Material = mat,
			CanCollide = true,
		}, folder)
		light(pillar, accent, 18, 1.6)
		part({
			Name = "PillarCap",
			Size = Vector3.new(3.8, 1, 3.8),
			Position = Vector3.new(a.X + side * 10, g + 0.5, a.Z),
			Color = stone:Lerp(Color3.new(0, 0, 0), 0.25),
			Material = mat,
			CanCollide = true,
		}, folder)
	end
	part({
		Name = "Lintel",
		Size = Vector3.new(26, 2.4, 3.6),
		Position = Vector3.new(a.X, g + 17.2, a.Z),
		Color = stone,
		Material = mat,
		CanCollide = true,
	}, folder)
	part({
		Name = "Trim",
		Size = Vector3.new(26.2, 0.5, 3.8),
		Position = Vector3.new(a.X, g + 15.8, a.Z),
		Color = glow,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, folder)
	-- the two landmark meshes stream in with the rest of the world's meshes
	local spots = WorldLayout.landmarks(worldId)
	task.spawn(function()
		for i, p in spots do
			local m = prop(
				gate.landmark,
				v3(p) + Vector3.new(0, g, 0),
				if i == 1 then 20 else -20,
				gate.scale,
				folder
			)
			if m then
				m.Name = `Landmark{i}`
				m.CanCollide = true
			end
		end
	end)
	return Vector3.new(a.X, g + 22, a.Z)
end

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
	local gate = WorldLayouts.ByWorld[worldId].theme.gate
	local signAt = spawn.Position + Vector3.new(0, 10, -40)
	if gate then
		signAt = buildGate(worldId, model, accent, gate)
	end
	local sign = anchor("WorldSign", signAt, Vector3.one, model)
	label(sign, {
		name = "WorldName",
		text = string.upper(world.displayName),
		icon = "icon_worlds",
		gradient = Billboard.Gold,
		studs = 3.2,
		maxDistance = 160,
	}, Billboard.Kind.place)
end

local function buildNodes(worldId: number, farm: Folder, accent: string): { () -> () }
	local gate = WorldLayouts.ByWorld[worldId].theme.gate
	local ringColour = if gate and gate.ring then gate.ring else "#F4F8FF"
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
		local pp = prompt(p, "Harvest", item.displayName, WorldLayouts.HARVEST_RANGE - 2, "Harvest", nil, 0.4)
		pp:SetAttribute("ItemId", item.id)
		local yield = node.resource.yield
		pp:SetAttribute("Yield", if yield[1] == yield[2] then `x{yield[1]}` else `x{yield[1]}-{yield[2]}`)
		if rare then
			light(p, accent, 14, 1.4)
		end
		-- a glowing ring on the ground, so a node reads from across the field (gold for rare ones)
		part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 8, 8),
			CFrame = CFrame.new(
				node.position.x,
				groundY(node.position.x, node.position.z) + 0.12,
				node.position.z
			) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if rare then Color3.fromHex("#FFC54B") else Color3.fromHex(ringColour),
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanQuery = false,
			CanCollide = false,
			CastShadow = false,
		}, p)
		-- The node's name floats over it; the client hides it while the node is spent for that player.
		label(p, {
			name = "NodeLabel",
			text = item.displayName,
			gradient = if rare then Billboard.Gold else Billboard.Green,
			studs = 1.5,
			offset = Vector3.new(0, if rare then 5.6 else 4.4, 0),
		}, Billboard.Kind.node)
		local base = Vector3.new(node.position.x, groundY(node.position.x, node.position.z), node.position.z)
		local rot = (#visuals * 47) % 360
		table.insert(visuals, function()
			local m = prop(node.resource.model, base, rot, if rare then 1.9 else 1.6, p)
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
	label(npc, {
		name = "MerchantName",
		text = name,
		icon = "icon_coin",
		gradient = Billboard.Gold,
		studs = 2.6,
		offset = Vector3.new(0, 17, 0), -- above the cart and its SELL prompt
	}, Billboard.Kind.npc)
	prompt(npc, "Sell", name, WorldLayouts.MERCHANT_RANGE - 2, "Sell", "icon_coin"):SetAttribute(
		"Height",
		10.5
	) -- over the cart
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
	local power = 0
	for _, unit in def.deck do
		power += Power.card(unit.characterId, unit.level)
	end
	label(npc, {
		name = "GuardianName",
		text = def.displayName,
		gradient = Billboard.Violet,
		studs = 2.6,
		offset = Vector3.new(0, 12.5, 0),
	}, Billboard.Kind.npc)
	label(npc, {
		name = "GuardianPower",
		text = thousands(math.floor(power)),
		icon = "icon_power",
		color = Color3.fromHex(accent),
		studs = 2.2,
		offset = Vector3.new(0, 9.6, 0),
	}, Billboard.Kind.npc)
	prompt(npc, "Fight", def.displayName, 14, "Challenge", "icon_play")
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
	prompt(trigger, "Enter", "Back to Lobby", 14, "WorldLobby", "icon_home")
	label(trigger, {
		name = "LobbySign",
		text = "LOBBY",
		icon = "icon_home",
		gradient = Billboard.Gold,
		studs = 3,
		offset = Vector3.new(0, 13, 0),
	}, Billboard.Kind.place)
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
