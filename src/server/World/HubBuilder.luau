--!strict
-- Builds the hub plaza from Config/HubLayout: the plaza floor with glowing path edges, every
-- generated mesh model (one MeshPart each, loaded once per mesh with AssetService and cloned),
-- lantern lights, the Worlds portal core, signs, interaction prompts, falling petals and the
-- spawn. Idempotent: rebuilding replaces the previous hub. Runs on Hub servers only.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared.Config.HubLayout)
local UiAssets = require(Shared.Config.UiAssets)

local HubBuilder = {}

local function asset(slot: string): string
	local def = UiAssets[slot]
	return if def.final and def.final ~= "" then def.final else def.temp
end

function HubBuilder.origin(): Vector3
	local o = HubLayout.ORIGIN
	return Vector3.new(o[1], o[2], o[3])
end

function HubBuilder.spawnPosition(): Vector3
	local s = HubLayout.SPAWN
	return HubBuilder.origin() + Vector3.new(s[1], s[2] + 3, s[3])
end

local function v(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function slab(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, val in props do
		(p :: any)[k] = val
	end
	p.Parent = parent
	return p
end

-- One template MeshPart per model, loaded once (a failed load is reported, never retried in a
-- loop, so a bad id can't stall the server).
local templates: { [string]: MeshPart | false } = {}

local function template(name: string): MeshPart?
	local cached = templates[name]
	if cached == false then
		return nil
	elseif cached ~= nil then
		return cached :: MeshPart
	end
	local def = HubLayout.Models[name]
	local ok, mesh = pcall(function()
		return AssetService:CreateMeshPartAsync(def.mesh)
	end)
	if not ok or mesh == nil then
		warn(`[HubBuilder] could not load mesh for {name}: {mesh}`)
		templates[name] = false
		return nil
	end
	local mp = mesh :: MeshPart
	mp.TextureID = def.texture
	mp.Anchored = true
	mp.Name = name
	templates[name] = mp
	return mp
end

local light: (BasePart, Vector3, string, number, number) -> ()

-- One model piece at `origin + at`, standing on the ground.
local function place(piece: HubLayout.Piece, i: number, origin: Vector3, parent: Instance)
	local t = template(piece.model)
	if t == nil then
		return
	end
	local def = HubLayout.Models[piece.model]
	local scale = piece.scale or 1
	local size = v(def.size) * scale
	local m = t:Clone()
	m.Name = `{piece.model}_{i}`
	m.Size = size
	m.CFrame = CFrame.new(origin + v(piece.at) + Vector3.new(0, size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(piece.rotY or 0), 0)
	local far = piece.model == "sky_island"
	m.CanCollide = not far
	m.CastShadow = not far
	if piece.light then
		local l = piece.light
		light(m, v(l.offset) - Vector3.new(0, size.Y / 2, 0), l.color, l.range, l.brightness)
	end
	m.Parent = parent
end

function light(parent: BasePart, offset: Vector3, color: string, range: number, brightness: number)
	local a = Instance.new("Attachment")
	a.Position = offset
	a.Parent = parent
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false -- lantern budget (ART_STYLE section 6)
	l.Parent = a
end

local function sign(at: Vector3, text: string, icon: string?, width: number, parent: Instance)
	local anchor = slab({
		Name = `Sign_{text}`,
		Size = Vector3.new(1, 1, 1),
		Position = at,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width, width / 4)
	gui.LightInfluence = 0
	gui.MaxDistance = 260
	gui.Parent = anchor
	if icon then
		local img = Instance.new("ImageLabel")
		img.Image = asset(icon)
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(0.24, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextScaled = true
	label.TextColor3 = Color3.fromHex("#FFE27A")
	label.Position = UDim2.fromScale(if icon then 0.26 else 0, 0)
	label.Size = UDim2.fromScale(if icon then 0.74 else 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#05070F")
	stroke.Thickness = 3
	stroke.Parent = label
end

local function portalCore(at: Vector3, rotY: number, radius: number, parent: Instance)
	local core = slab({
		Name = "PortalCore",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, radius * 2, radius * 2),
		CFrame = CFrame.new(at) * CFrame.Angles(0, math.rad(rotY + 90), 0),
		Color = Color3.fromHex("#A469FF"),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	}, parent)
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
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = gui
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = asset("sparkle")
	sparks.Rate = 14
	sparks.Lifetime = NumberRange.new(1.2, 2)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparks.Color = ColorSequence.new(Color3.fromHex("#FF7BD5"), Color3.fromHex("#A469FF"))
	sparks.Parent = core
end

local function prompt(at: Vector3, def: { name: string, action: string, object: string }, parent: Instance)
	local p = slab({
		Name = def.name,
		Size = Vector3.new(2, 2, 2),
		Position = at,
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
	}, parent)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = def.name
	pp.ActionText = def.action
	pp.ObjectText = def.object
	pp.MaxActivationDistance = 16
	pp.HoldDuration = 0
	pp.RequiresLineOfSight = false
	pp.Parent = p
end

local function petals(origin: Vector3, parent: Instance)
	local cfg = HubLayout.PETALS
	local area = slab({
		Name = "Petals",
		Size = Vector3.new(cfg.area[1], 1, cfg.area[2]),
		Position = origin + Vector3.new(0, cfg.height, -10),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	local e = Instance.new("ParticleEmitter")
	e.Texture = asset("petal")
	e.Rate = cfg.rate
	e.Lifetime = NumberRange.new(14, 20)
	e.Speed = NumberRange.new(1, 3)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0.6, -0.5, 0.3)
	e.Drag = 0.3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-80, 80)
	e.Size = NumberSequence.new(0.55)
	e.LightEmission = 0.15
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.08, 0),
		NumberSequenceKeypoint.new(0.9, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = area
end

function HubBuilder.build(parent: Instance): Model
	local old = parent:FindFirstChild("Hub")
	if old then
		old:Destroy()
	end
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub:SetAttribute("WorldId", 0)
	local origin = HubBuilder.origin()

	-- Floor: an outer ground, the plaza slab, the path and its glowing edges.
	local plaza = HubLayout.PLAZA
	local centre = origin + Vector3.new(plaza.center[1], 0, plaza.center[2])
	slab({
		Name = "Ground",
		Size = Vector3.new(900, 2, 900),
		Position = centre - Vector3.new(0, 1.4, 0),
		Color = Color3.fromHex("#241B44"),
		Material = Enum.Material.Ground,
	}, hub)
	slab({
		Name = "Plaza",
		Size = Vector3.new(plaza.size[1], 2, plaza.size[2]),
		Position = centre - Vector3.new(0, 1, 0),
		Color = Color3.fromHex("#463D6E"),
		Material = Enum.Material.Slate,
	}, hub)
	local path = plaza.path
	local length = path.from - path.to
	local pathCentre = origin + Vector3.new(0, 0, (path.from + path.to) / 2)
	slab({
		Name = "Path",
		Size = Vector3.new(path.width, 0.2, length),
		Position = pathCentre + Vector3.new(0, 0.05, 0),
		Color = Color3.fromHex("#6A5C9C"),
		Material = Enum.Material.Pavement,
	}, hub)
	for _, side in { -1, 1 } do
		slab({
			Name = "PathEdge",
			Size = Vector3.new(0.35, 0.25, length),
			Position = pathCentre + Vector3.new(side * (path.width / 2 + 0.2), 0.1, 0),
			Color = Color3.fromHex("#A469FF"),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, hub)
	end

	-- Models.
	local models = Instance.new("Folder")
	models.Name = "Models"
	models.Parent = hub
	for i, piece in HubLayout.Pieces do
		place(piece, i, origin, models)
	end

	-- Interactive features.
	for key, f in HubLayout.Features do
		local at = origin + v(f.at)
		if key == "portal" then
			portalCore(at, f.rotY or 0, HubLayout.PORTAL_CORE_RADIUS, hub)
		end
		if f.prompt then
			prompt(at, f.prompt, hub)
		end
		if f.sign then
			sign(
				Vector3.new(at.X, origin.Y + f.sign.height, at.Z),
				f.sign.text,
				f.sign.icon,
				f.sign.size,
				hub
			)
		end
	end

	petals(origin, hub)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = HubBuilder.spawnPosition() - Vector3.new(0, 3.5, 0)
	spawn.Transparency = 1
	spawn.Parent = hub

	hub.Parent = parent
	HubBuilder.buildStageProps()
	return hub
end

-- The battle stage backdrop, shared through ReplicatedStorage (clients clone it locally around
-- their own stage). Its pivot is the stage centre.
function HubBuilder.buildStageProps(): Model
	local old = ReplicatedStorage:FindFirstChild("StageProps")
	if old then
		old:Destroy()
	end
	local props = Instance.new("Model")
	props.Name = "StageProps"
	for i, piece in HubLayout.StageProps do
		place(piece, i, Vector3.zero, props)
	end
	props.WorldPivot = CFrame.new()
	props.Parent = ReplicatedStorage
	return props
end

return HubBuilder
