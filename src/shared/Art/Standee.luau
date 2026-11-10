--!strict
-- A character in 3D as a standee: the character's cut-out art (Shared/Art/Cutout) on a thin
-- upright panel, readable from both sides, on a glowing base in the family accent. It replaces the
-- procedural part-built placeholder rigs (the owner's rule: never stack primitive parts into fake
-- characters) until a character's approved model exists (CharacterDef.assets.model, the Blender
-- pipeline in docs/ART_STYLE.md section 8). The model's pivot is its feet, facing -Z, about the
-- 5.5-stud height of an R15 character, so the battle stage and the Guardians place it like a rig.
local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Art = require(Config.Art)
local Cutout = require(script.Parent.Cutout)

local Standee = {}

local HEIGHT = 6.2
local WIDTH = HEIGHT * 0.75 -- the cut-out images are 384 x 512
local PPS = 64 -- SurfaceGui pixels per stud

local function face(panel: BasePart, side: Enum.NormalId, characterId: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = `Art{side.Name}`
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0.35
	gui.Brightness = 1.4
	gui.ClipsDescendants = false
	gui.Parent = panel
	-- Approved art is a 3:4 canvas with the figure fitted to its width and standing on the bottom
	-- edge (scripts/art/characters.py), so a wide figure leaves empty space on top; scaled up from
	-- the feet it stands about R15 height (the same treatment as the card's art window).
	local grow = if Cutout.isTemp(characterId) then 1 else 1.32
	for i, layer in Cutout.layers(characterId) do
		local img = Instance.new("ImageLabel")
		img.Name = layer.name
		img.Image = layer.image
		img.ImageColor3 = layer.color
		img.ImageTransparency = layer.transparency
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 1)
		img.Position = UDim2.fromScale(0.5 + layer.offset.X, 1 + layer.offset.Y)
		img.Size = UDim2.fromScale(grow, grow)
		img.ZIndex = i
		img.Parent = gui
	end
end

function Standee.build(characterId: string): Model
	local def = Characters.ById[characterId]
	assert(def, `unknown character {characterId}`)
	local accent = Color3.fromHex(Art.FamilyColors[def.family].accent)
	local model = Instance.new("Model")
	model.Name = def.displayName

	local panel = Instance.new("Part")
	panel.Name = "Panel"
	panel.Size = Vector3.new(WIDTH, HEIGHT, 0.1)
	panel.Transparency = 1
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.CastShadow = false
	panel.CFrame = CFrame.new(0, HEIGHT / 2 + 0.25, 0)
	panel.Parent = model
	face(panel, Enum.NormalId.Front, characterId)
	face(panel, Enum.NormalId.Back, characterId)

	-- The glowing base it stands on (family accent), and a soft light that lifts the art.
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.3, WIDTH * 0.95, WIDTH * 0.95)
	base.CFrame = CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = accent
	base.Material = Enum.Material.Neon
	base.Transparency = 0.35
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CastShadow = false
	base.Parent = model
	local glow = Instance.new("PointLight")
	glow.Color = accent
	glow.Range = 9
	glow.Brightness = 1.2
	glow.Shadows = false
	glow.Parent = base

	model.WorldPivot = CFrame.new() -- the feet, facing -Z (no PrimaryPart: the base is turned on its side)
	model:SetAttribute("CharacterId", characterId)
	model:SetAttribute("Placeholder", Cutout.isTemp(characterId))
	return model
end

-- The standee's height in studs (for labels and camera framing).
Standee.HEIGHT = HEIGHT

return table.freeze(Standee)
