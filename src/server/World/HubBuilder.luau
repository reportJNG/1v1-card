--!strict
-- Builds the lobby from Config/HubLayout (FIX_LOBBY.md): the ground, paths, steps, river,
-- fountain and card statue, stalls and shrine as simple shapes (Shared/Art/ArenaKit.prim); every
-- generated mesh (one MeshPart each, loaded once per mesh with AssetService and cloned); the egg
-- pedestals with the pack eggs; lantern and brazier lights; fire, fountain spray, fireflies and
-- petals; the Worlds portal core; world text over every place; interaction prompts and the
-- spawn. The ground and spawn exist on return; the meshes stream in on a background thread.
-- Idempotent: rebuilding replaces the previous hub. Runs on Hub servers only.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared.Config.HubLayout)
local WorldProps = require(Shared.Config.WorldProps)
local Eggs = require(Shared.Config.Eggs)
local EggTiers = require(Shared.Config.EggTiers)
local Rarities = require(Shared.Config.Rarities)
local ArenaKit = require(Shared.Art.ArenaKit)
local UiAssets = require(Shared.Config.UiAssets)
local Billboard = require(Shared.Ui.Billboard)
local MeshLibrary = require(script.Parent.MeshLibrary)

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

local light: (BasePart, Vector3, string, number, number) -> ()
local life: (Vector3, Instance) -> ()
local eggPedestals: (Vector3, Instance) -> ()

-- One model piece at `origin + at`, standing on the ground.
local function place(piece: HubLayout.Piece, i: number, origin: Vector3, parent: Instance)
	local def = HubLayout.Models[piece.model] or WorldProps.Models[piece.model]
	local m = MeshLibrary.place(piece.model, def, origin + v(piece.at), piece.rotY, piece.scale)
	if m == nil then
		return
	end
	local size = m.Size
	m.Name = `{piece.model}_{i}`
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
	local gui = Billboard.make({
		name = "Sign",
		text = text,
		icon = icon,
		gradient = Billboard.Gold,
		studs = width / 4.2,
		maxDistance = Billboard.Kind.place.maxDistance,
	})
	gui.Parent = anchor
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

local function prompt(
	at: Vector3,
	def: { name: string, action: string, object: string, height: number? },
	icon: string?,
	parent: Instance
)
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
	pp.MaxActivationDistance = 22 -- the anchors sit inside the arena, portal and stall meshes
	pp.HoldDuration = 0
	if icon then
		pp:SetAttribute("Icon", icon) -- App/Prompts draws it after the word (BAD_GUI_9 section 1)
	end
	if def.height then
		pp:SetAttribute("Height", def.height)
	end
	pp.Style = Enum.ProximityPromptStyle.Custom -- drawn by the client (App/Prompts)
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

-- A small particle emitter on an invisible part (fire, spray, fireflies).
local function emitter(name: string, at: Vector3, size: Vector3, spec: { [string]: any }, parent: Instance)
	local holder = slab({
		Name = name,
		Size = size,
		Position = at,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	local e = Instance.new("ParticleEmitter")
	e.Texture = asset(spec.texture or "sparkle")
	e.Rate = spec.rate
	e.Lifetime = spec.lifetime
	e.Speed = spec.speed
	e.LightEmission = 1
	e.Color = spec.color
	e.Size = spec.size
	e.EmissionDirection = spec.direction or Enum.NormalId.Top
	e.SpreadAngle = spec.spread or Vector2.new(10, 10)
	e.Acceleration = spec.acceleration or Vector3.zero
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = holder
end

-- The lobby's life: fire in every brazier, spray over the fountain, fireflies along the river.
function life(origin: Vector3, architecture: Instance)
	for _, d in architecture:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Fx") == "Brazier" then
			emitter("Fire", d.Position + Vector3.new(0, 0.8, 0), Vector3.new(2, 0.2, 2), {
				rate = 26,
				lifetime = NumberRange.new(0.5, 0.9),
				speed = NumberRange.new(3, 6),
				color = ColorSequence.new(Color3.fromHex("#FFE08A"), Color3.fromHex("#FF4A1E")),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1.4),
					NumberSequenceKeypoint.new(1, 0),
				}),
				acceleration = Vector3.new(0, 3, 0),
			}, d)
		end
	end
	emitter("FountainSpray", origin + Vector3.new(0, 5.4, 0), Vector3.new(3, 0.2, 3), {
		rate = 18,
		lifetime = NumberRange.new(0.8, 1.2),
		speed = NumberRange.new(5, 8),
		spread = Vector2.new(25, 25),
		color = ColorSequence.new(Color3.fromHex("#E6F6FF"), Color3.fromHex("#7CC8FF")),
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) }),
		acceleration = Vector3.new(0, -14, 0),
	}, architecture)
	-- FIX_LOBBY_2: water jets arcing into the pool, mist where the waterfalls leave the shelf, and
	-- gold motes drifting over the arena terrace (tagged shapes in Config/LobbyDecor).
	for _, d in architecture:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local fx = d:GetAttribute("Fx")
		if fx == "Jet" then
			local outward = Vector3.new(d.Position.X - origin.X, 0, d.Position.Z - origin.Z).Unit
			emitter("Jet", d.Position, Vector3.new(0.6, 0.2, 0.6), {
				rate = 14,
				lifetime = NumberRange.new(0.9, 1.1),
				speed = NumberRange.new(7, 8),
				spread = Vector2.new(4, 4),
				color = ColorSequence.new(Color3.fromHex("#F2FBFF"), Color3.fromHex("#8FD3FF")),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.45),
					NumberSequenceKeypoint.new(1, 0.25),
				}),
				acceleration = Vector3.new(0, -16, 0) - outward * 6,
			}, d)
		elseif fx == "Mist" then
			emitter("Mist", d.Position, d.Size, {
				rate = 6,
				lifetime = NumberRange.new(3, 5),
				speed = NumberRange.new(1, 3),
				spread = Vector2.new(60, 60),
				color = ColorSequence.new(Color3.fromHex("#E8F6FF"), Color3.fromHex("#B8C8FF")),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 3),
					NumberSequenceKeypoint.new(1, 7),
				}),
				acceleration = Vector3.new(0, 0.6, 0),
			}, d)
		elseif fx == "GoldMotes" then
			emitter("GoldMotes", d.Position, d.Size, {
				rate = 10,
				lifetime = NumberRange.new(5, 8),
				speed = NumberRange.new(0.4, 1.2),
				spread = Vector2.new(180, 180),
				color = ColorSequence.new(Color3.fromHex("#FFF1B8"), Color3.fromHex("#FFC54B")),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(1, 0.15),
				}),
				acceleration = Vector3.new(0, 0.5, 0),
			}, d)
		end
	end
	local f = HubLayout.FIREFLIES
	emitter("Fireflies", origin + v(f.at), Vector3.new(f.area[1], 1, f.area[2]), {
		rate = f.rate,
		lifetime = NumberRange.new(4, 7),
		speed = NumberRange.new(0.3, 1),
		spread = Vector2.new(180, 180),
		color = ColorSequence.new(Color3.fromHex("#F4FF9A"), Color3.fromHex("#9AFF7A")),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
		acceleration = Vector3.new(0, 0.3, 0),
	}, architecture)
end

-- The egg pavilion's pedestals: a pedestal per egg glowing in the egg's tier colour with a turning
-- ring, the egg's pack image (unedited) and its Coin price floating over it.
function eggPedestals(origin: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "EggPedestals"
	for _, spot in HubLayout.EggPedestals do
		local egg = Eggs.ById[spot.egg]
		if egg then
			local at = origin + v(spot.at)
			local tier = Rarities.Defs[EggTiers.of(egg)].colors[4]
			slab({
				Name = egg.id,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2, 3.4, 3.4),
				CFrame = CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromHex("#5B5088"),
				Material = Enum.Material.Marble,
			}, folder)
			local glow = slab({
				Name = "Glow",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.15, 3.7, 3.7),
				CFrame = CFrame.new(at + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0, math.rad(90)),
				Color = tier,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
				CanCollide = false,
				CastShadow = false,
			}, folder)
			ArenaKit.prim({
				shape = "Ring",
				size = { 4.6, 0.12, 20 },
				at = { at.X, at.Y + 0.5, at.Z },
				color = tier:ToHex(),
				material = "Neon",
				transparency = 0.15,
				tag = "Spin",
			}, 0, glow)
			local gui = Instance.new("BillboardGui")
			gui.Name = "Egg"
			gui.Size = UDim2.fromScale(4, 4.6)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 140
			gui.AlwaysOnTop = false -- see Shared/Ui/Billboard
			gui.Parent = glow
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = egg.icon.normalAssetId or ""
			img.ScaleType = Enum.ScaleType.Fit
			img.Size = UDim2.fromScale(1, 1)
			img.Parent = gui
			if egg.coinPrice then
				local price = Billboard.make({
					name = "Price",
					text = tostring(egg.coinPrice),
					icon = "icon_coin",
					gradient = Billboard.Gold,
					studs = 1.2,
					maxDistance = 90,
				})
				price.StudsOffsetWorldSpace = Vector3.new(0, 5.9, 0)
				price.Parent = glow
			end
		end
	end
	folder.Parent = parent
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

	-- Ground, paths, steps, the fountain and card statue, the stalls: simple shapes from data.
	-- A shape with a `group` goes in that landmark's model, streamed as one piece (Atomic).
	local architecture = Instance.new("Folder")
	architecture.Name = "Architecture"
	local groups: { [string]: Model } = {}
	for i, spec in HubLayout.Prims do
		local shifted = table.clone(spec)
		shifted.at = { spec.at[1] + origin.X, spec.at[2] + origin.Y, spec.at[3] + origin.Z }
		local into: Instance = architecture
		local name = spec.group
		if name then
			local g: Model? = groups[name]
			if not g then
				local made = Instance.new("Model")
				made.Name = name
				made.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				made.Parent = architecture
				groups[name] = made
				g = made
			end
			into = g :: Model
		end
		ArenaKit.prim(shifted, i, into)
	end
	architecture.Parent = hub
	life(origin, architecture)
	eggPedestals(origin, hub)

	-- Models.
	local models = Instance.new("Folder")
	models.Name = "Models"
	models.Parent = hub
	-- Meshes load over several seconds: do it in the background so the floor and the spawn
	-- exist at once and server boot (WorldService.init) never waits on the asset service.
	task.spawn(function()
		for i, piece in HubLayout.Pieces do
			place(piece, i, origin, models)
		end
	end)

	-- Interactive features.
	for key, f in HubLayout.Features do
		local at = origin + v(f.at)
		if key == "portal" then
			portalCore(at, f.rotY or 0, HubLayout.PORTAL_CORE_RADIUS, hub)
		end
		if f.prompt then
			-- At chest height, whatever the feature's height (the portal core floats at 16 studs,
			-- which put its prompt at the edge of its range).
			prompt(Vector3.new(at.X, origin.Y + 3, at.Z), f.prompt, if f.sign then f.sign.icon else nil, hub)
		end
		if key == "quests" then
			-- a big "!" over the board while a quest is ready to claim (App/WorldInteraction)
			local alert = Billboard.make({
				name = "QuestAlert",
				text = "!",
				gradient = { Color3.fromHex("#FFE08A"), Color3.fromHex("#FF4A5E") },
				studs = 4,
				maxDistance = Billboard.Kind.place.maxDistance,
			})
			alert.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
			alert.Enabled = false
			local holder = slab({
				Name = "QuestAlert",
				Size = Vector3.one,
				Position = at,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			}, hub)
			alert.Parent = holder
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
	return hub
end

return HubBuilder
