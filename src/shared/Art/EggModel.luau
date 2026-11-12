--!strict
-- One 3D egg as a Model, for the lobby pedestals (Server/World/HubBuilder) and the hatch
-- (Screens/Hatch, in a viewport). Config/EggModels says what it looks like:
--   approved  the uploaded Blender mesh and its baked texture (a SpecialMesh, scriptable on both sides)
--   TEMP      until then: an egg-shaped ellipsoid in the egg's body colour with a band in its accent
--             colour, marked Placeholder
-- Golden copies use the gold colour and sparkles on the same shape. The model's pivot is the bottom
-- centre of the egg; its primary part is "Egg".
local Config = script.Parent.Parent.Config
local EggModels = require(Config.EggModels)

local EggModel = {}

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Whether the egg has its approved 3D mesh yet.
function EggModel.isTemp(eggId: string): boolean
	local def = EggModels.ById[eggId]
	return def == nil or def.mesh == nil or def.mesh == ""
end

-- A model of the egg `height` studs tall, standing at the origin (move it with :PivotTo).
function EggModel.build(eggId: string, golden: boolean?, height: number?): Model
	local def = EggModels.ById[eggId] or EggModels.ById.egg_basic
	local h = height or EggModels.HEIGHT
	local w = h / 1.3
	local model = Instance.new("Model")
	model.Name = eggId
	local body = Color3.fromHex(if golden then EggModels.Gold else def.body)
	local egg = part("Egg", Vector3.new(w, h, w), CFrame.new(0, h / 2, 0), body, model)
	local mesh = Instance.new("SpecialMesh")
	if EggModel.isTemp(eggId) then
		mesh.MeshType = Enum.MeshType.Sphere
		-- the band in the accent colour, a third of the way up
		local band = part(
			"Band",
			Vector3.new(h * 0.06, w * 0.97, w * 0.97),
			CFrame.new(0, h * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromHex(if golden then "#FFF2A8" else def.accent),
			model
		)
		band.Shape = Enum.PartType.Cylinder
		model:SetAttribute("Placeholder", true)
	else
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = def.mesh :: string
		mesh.TextureId = if golden then "" else (def.texture or "")
		mesh.Scale = Vector3.new(w, h, w)
		egg.Size = Vector3.new(w, h, w)
	end
	mesh.Parent = egg
	if golden then
		egg.Material = Enum.Material.Foil
		egg.Reflectance = 0.15
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "GoldenSparkle"
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.fromHex("#FFF2A8"))
		sparkles.Size = NumberSequence.new(0.35)
		sparkles.Lifetime = NumberRange.new(0.6, 1.1)
		sparkles.Rate = 6
		sparkles.Speed = NumberRange.new(0.5, 1)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.LightEmission = 1
		sparkles.Parent = egg
	end
	model:SetAttribute("Golden", golden == true)
	model.PrimaryPart = egg
	model.WorldPivot = CFrame.new(0, 0, 0)
	return model
end

return table.freeze(EggModel)
