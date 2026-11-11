--!strict
-- Builds one arena map (Config/Arenas) as a Model whose pivot is the arena centre:
--   ArenaCore  the shared core from Shared/Domain/ArenaLayout.core (platform, rim, light pads,
--              spawn and camera points), identical in every map
--   Dressing   the map's simple shapes, skyline, lights and ambient particles; the server adds the
--              map's meshes here too (Server/World/ArenaBuilder), because only the server can
--              load meshes
-- Used by the server for the shared templates (ReplicatedStorage.Arenas) and by the client when a
-- template hasn't arrived yet (then the map has no meshes, but the same core and look).
local Config = script.Parent.Parent.Config
local Domain = script.Parent.Parent.Domain
local Arenas = require(Config.Arenas)
local UiAssets = require(Config.UiAssets)
local ArenaLayout = require(Domain.ArenaLayout)

local ArenaKit = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function asset(slot: string): string
	local def = UiAssets[slot]
	return if def.final and def.final ~= "" then def.final else def.temp
end

local function part(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function material(name: string?): Enum.Material
	local ok, m = pcall(function()
		return (Enum.Material :: any)[name or "SmoothPlastic"]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

-- An upright cylinder (Roblox cylinders lie along X).
local function cylinder(name: string, at: Vector3, diameter: number, height: number, parent: Instance): Part
	local p = part(name, parent)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

local function addLight(p: BasePart, color: string, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

function ArenaKit.core(arena: Arenas.Arena, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ArenaCore"
	for _, c in ArenaLayout.core(arena) do
		local at = v3(c.at)
		if c.kind == "Point" then
			local p = part(c.name, folder)
			p.Size = Vector3.one
			p.Transparency = 1
			p.CFrame = if c.name == "CamHome"
				then CFrame.lookAt(at, v3(ArenaLayout.CAMERA.look))
				elseif c.name == "CamIntro" then CFrame.lookAt(at, v3(ArenaLayout.INTRO.look))
				else CFrame.new(at)
		else
			local size = c.size :: { number }
			local p = cylinder(c.name, at, size[1], size[2], folder)
			p.Color = Color3.fromHex(c.color :: string)
			p.Material = material(c.material)
			p.Transparency = c.transparency or 0
			p.Reflectance = if c.material == "Ice" or c.material == "Marble" then 0.12 else 0
			p.CanCollide = c.name == "Platform"
		end
	end
	folder.Parent = parent
	return folder
end

-- One simple shape from data (Config/Arenas, Config/HubLayout): blocks, upright cylinders, balls
-- and flat rings, with an optional light, face image (a UiAssets slot on both faces), collision
-- and an "Fx" tag the client animates.
function ArenaKit.prim(spec: Arenas.Prim, i: number, parent: Instance)
	local at = v3(spec.at)
	local rot = spec.rot or { 0, 0, 0 }
	local turn = CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
	local color = Color3.fromHex(spec.color)
	local mat = material(spec.material)
	if spec.shape == "Ring" then
		-- a flat ring of short blocks around the centre, as one model so the client can turn it
		local ring = Instance.new("Model")
		ring.Name = `Ring{i}`
		local d, thick, n = spec.size[1], spec.size[2], spec.size[3]
		local seg = math.pi * d / n * 1.04
		for s = 1, n do
			local a = (s - 1) / n * math.pi * 2
			local p = part("Segment", ring)
			p.Size = Vector3.new(seg, thick, thick * 2)
			p.CFrame = CFrame.new(at) * turn * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, d / 2)
			p.Color = color
			p.Material = mat
			p.Transparency = spec.transparency or 0
		end
		ring.WorldPivot = CFrame.new(at) * turn
		if spec.tag then
			ring:SetAttribute("Fx", spec.tag)
		end
		ring.Parent = parent
		return
	end
	local p: Part
	if spec.shape == "Cylinder" then
		p = cylinder(`Prim{i}`, at, spec.size[1], spec.size[2], parent)
		p.CFrame = CFrame.new(at) * turn * CFrame.Angles(0, 0, math.rad(90))
	else
		p = part(`Prim{i}`, parent)
		local size = spec.size
		local round = spec.shape == "Ball"
		local stretched = round and (size[1] ~= size[2] or size[2] ~= size[3])
		-- a Ball part is always a sphere: a stretched one (an egg, a lantern) is a block with a
		-- sphere mesh, which takes the block's size
		p.Shape = if round and not stretched then Enum.PartType.Ball else Enum.PartType.Block
		p.Size = v3(size)
		p.CFrame = CFrame.new(at) * turn
		if stretched then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	p.Color = color
	p.Material = mat
	p.Transparency = spec.transparency or 0
	p.CanCollide = spec.collide == true
	if spec.name then
		p.Name = spec.name
	end
	if spec.tag then
		p:SetAttribute("Fx", spec.tag)
	end
	if spec.attrs then
		for k, val in spec.attrs do
			p:SetAttribute(k, val)
		end
	end
	if spec.image then
		local faces: { Enum.NormalId } = if spec.shape == "Cylinder"
			then { Enum.NormalId.Left, Enum.NormalId.Right }
			else { Enum.NormalId.Front, Enum.NormalId.Back }
		for _, face in faces do
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Image"
			gui.Face = face
			gui.LightInfluence = 0.3
			gui.CanvasSize = Vector2.new(256, 256)
			gui.Parent = p
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = asset(spec.image)
			img.ScaleType = Enum.ScaleType.Fit
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.5)
			img.Size = UDim2.fromScale(0.8, 0.8)
			img.Parent = gui
		end
	end
	if spec.light then
		addLight(p, spec.light.color, spec.light.range, spec.light.brightness)
	end
end

-- The map's ambient particles: one emitter over the arena (ART_STYLE particle budget).
function ArenaKit.particles(arena: Arenas.Arena, parent: Instance): ParticleEmitter
	local spec = arena.particles
	local high = spec.direction == "fall" or spec.direction == "rain"
	local holder = part("Ambience", parent)
	holder.Size = Vector3.new(90, 1, 70)
	holder.Position = Vector3.new(0, if high then 36 else -2, -10)
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = asset(spec.texture)
	e.Rate = spec.rate
	e.LightEmission = if spec.texture == "petal" then 0.15 else 0.8
	local keys = {}
	for i, hex in spec.colors do
		table.insert(
			keys,
			ColorSequenceKeypoint.new((i - 1) / math.max(1, #spec.colors - 1), Color3.fromHex(hex))
		)
	end
	e.Color = ColorSequence.new(keys)
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.1, spec.size),
		NumberSequenceKeypoint.new(0.85, spec.size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Rotation = NumberRange.new(0, 360)
	if spec.direction == "rain" then
		-- thin fast streaks
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Speed = NumberRange.new(70, 90)
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Rotation = NumberRange.new(0, 0)
		e.Squash = NumberSequence.new(-2.6)
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Transparency = NumberSequence.new(0.35)
	elseif spec.direction == "fall" then
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Speed = NumberRange.new(2, 5)
		e.Lifetime = NumberRange.new(9, 14)
		e.Acceleration = Vector3.new(0.8, -0.4, 0.4)
		e.RotSpeed = NumberRange.new(-80, 80)
	elseif spec.direction == "rise" then
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(3, 7)
		e.Lifetime = NumberRange.new(4, 7)
		e.Acceleration = Vector3.new(0.4, 1.2, 0)
		e.RotSpeed = NumberRange.new(-40, 40)
	else
		e.EmissionDirection = Enum.NormalId.Top
		e.Speed = NumberRange.new(0.5, 2)
		e.Lifetime = NumberRange.new(6, 10)
		e.Acceleration = Vector3.new(0.5, 0.6, 0.3)
		e.RotSpeed = NumberRange.new(-40, 40)
	end
	e.Parent = holder
	return e
end

-- The whole map without meshes: core, shapes, skyline and particles. Pivot = arena centre.
function ArenaKit.build(arena: Arenas.Arena): Model
	local model = Instance.new("Model")
	model.Name = arena.id
	model:SetAttribute("ArenaId", arena.id)
	ArenaKit.core(arena, model)
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	for i, spec in ArenaLayout.prims(arena) do
		ArenaKit.prim(spec, i, dressing)
	end
	ArenaKit.particles(arena, dressing)
	dressing.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

-- A scene without meshes from data (the main menu's stage, Config/MenuStage): its simple shapes in a
-- "Dressing" folder and one emitter per particle spec. Pivot = scene centre.
function ArenaKit.scene(name: string, prims: { Arenas.Prim }, particles: { Arenas.Particles }): Model
	local model = Instance.new("Model")
	model.Name = name
	local dressing = Instance.new("Folder")
	dressing.Name = "Dressing"
	for i, spec in prims do
		ArenaKit.prim(spec, i, dressing)
	end
	for _, spec in particles do
		ArenaKit.particles({ particles = spec } :: any, dressing)
	end
	dressing.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

return table.freeze(ArenaKit)
