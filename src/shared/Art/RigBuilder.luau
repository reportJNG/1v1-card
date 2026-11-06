--!strict
-- PLACEHOLDER character rigs. Builds a blocky, jointed stand-in model for any character from data
-- (Config/Art): role -> proportions and prop, family -> colours, rarity -> neon trim. Every part
-- carries Placeholder = true. Joints are Motor6Ds named like R15 (Neck, LeftShoulder, ...), so
-- animations can be authored against them now and the real models (CharacterDef.assets.model)
-- can replace these later without changing the battle presentation code.
--
-- This is NOT final art. Hero-quality characters need a 3D artist (see docs/DESIGN.md section 4).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)

local RigBuilder = {}

type Shape = { torso: Vector3, head: number, limb: Vector2, legLength: number, armLength: number }

-- Role silhouettes (studs).
local SHAPES: { [string]: Shape } = {
	Striker = {
		torso = Vector3.new(2, 2, 1),
		head = 1.2,
		limb = Vector2.new(0.9, 0.9),
		legLength = 2,
		armLength = 2,
	},
	Guardian = {
		torso = Vector3.new(2.6, 2.3, 1.4),
		head = 1.25,
		limb = Vector2.new(1.1, 1.1),
		legLength = 1.9,
		armLength = 2,
	},
	Skirmisher = {
		torso = Vector3.new(1.7, 1.9, 0.9),
		head = 1.15,
		limb = Vector2.new(0.75, 0.75),
		legLength = 2.2,
		armLength = 1.9,
	},
	Trickster = {
		torso = Vector3.new(1.8, 2, 0.9),
		head = 1.3,
		limb = Vector2.new(0.75, 0.75),
		legLength = 2,
		armLength = 2.1,
	},
	Support = {
		torso = Vector3.new(1.9, 2.1, 1),
		head = 1.25,
		limb = Vector2.new(0.8, 0.8),
		legLength = 2.1,
		armLength = 1.9,
	},
	Bruiser = {
		torso = Vector3.new(2.5, 2.2, 1.3),
		head = 1.15,
		limb = Vector2.new(1.15, 1.15),
		legLength = 1.8,
		armLength = 2.2,
	},
}

local SIDES: { [string]: number } = { Left = -1, Right = 1 }
local SIGNS: { number } = { -1, 1 }
local TRIM: { [string]: number } = { Common = 0, Rare = 1, Epic = 2, Legendary = 3, Mythical = 4 }

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Placeholder", true)
	p.Parent = model
	return p
end

local function joint(name: string, part0: BasePart, part1: BasePart, at: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:ToObjectSpace(at)
	m.C1 = part1.CFrame:ToObjectSpace(at)
	m.Parent = part0
end

local function prop(model: Model, role: string, hand: BasePart, color: Color3, accent: Color3)
	local h = hand.CFrame
	local p: Part
	if role == "Guardian" then
		p = part(
			model,
			"Shield",
			Vector3.new(0.3, 2.4, 2),
			h * CFrame.new(-0.6, 0, 0),
			accent,
			Enum.Material.Metal
		)
	elseif role == "Striker" then
		p = part(
			model,
			"Blade",
			Vector3.new(0.25, 0.3, 3.2),
			h * CFrame.new(0, -0.9, -1.4),
			accent,
			Enum.Material.Metal
		)
	elseif role == "Skirmisher" then
		p = part(
			model,
			"Dagger",
			Vector3.new(0.2, 0.25, 1.6),
			h * CFrame.new(0, -0.9, -0.7),
			accent,
			Enum.Material.Metal
		)
	elseif role == "Trickster" then
		p = part(
			model,
			"Orb",
			Vector3.new(0.9, 0.9, 0.9),
			h * CFrame.new(0, -1.3, -0.3),
			accent,
			Enum.Material.Neon
		)
		p.Shape = Enum.PartType.Ball
	elseif role == "Support" then
		p = part(
			model,
			"Staff",
			Vector3.new(0.25, 4.2, 0.25),
			h * CFrame.new(0, 0.6, -0.4),
			color,
			Enum.Material.Wood
		)
		local tip = part(
			model,
			"StaffTip",
			Vector3.new(0.7, 0.7, 0.7),
			p.CFrame * CFrame.new(0, 2.2, 0),
			accent,
			Enum.Material.Neon
		)
		tip.Shape = Enum.PartType.Ball
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = tip
		w.Parent = tip
	else -- Bruiser
		p = part(
			model,
			"Gauntlet",
			Vector3.new(1.4, 1, 1.4),
			h * CFrame.new(0, -0.9, 0),
			accent,
			Enum.Material.Metal
		)
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = hand
	w.Part1 = p
	w.Parent = p
end

-- Builds the rig standing at the origin, facing -Z. Returns an unparented Model.
function RigBuilder.build(characterId: string): Model
	local def = Characters.ById[characterId]
	assert(def, `unknown character {characterId}`)
	local shape = SHAPES[def.role] or SHAPES.Striker
	local colors = Art.FamilyColors[def.family] or { body = "#888888", accent = "#FFFFFF" }
	local body = Color3.fromHex(colors.body)
	local accent = Color3.fromHex(colors.accent)
	local skin = Color3.fromHex("#F2D2B6"):Lerp(body, 0.15)
	local trimLevel = TRIM[def.rarity] or 0

	local model = Instance.new("Model")
	model.Name = def.id
	model:SetAttribute("Placeholder", true)
	model:SetAttribute("CharacterId", def.id)

	local legTop = shape.legLength
	local torsoY = legTop + shape.torso.Y / 2
	local root = part(model, "HumanoidRootPart", Vector3.new(1, 1, 1), CFrame.new(0, torsoY, 0), body)
	root.Transparency = 1
	root.Anchored = true -- the rest hangs off it by joints and welds
	local torso = part(model, "UpperTorso", shape.torso, CFrame.new(0, torsoY, 0), body)
	joint("Root", root, torso, CFrame.new(0, torsoY, 0))
	local headY = torsoY + shape.torso.Y / 2 + shape.head / 2
	local head =
		part(model, "Head", Vector3.new(shape.head, shape.head, shape.head), CFrame.new(0, headY, 0), skin)
	joint("Neck", torso, head, CFrame.new(0, torsoY + shape.torso.Y / 2, 0))
	-- Hair / helm in the family accent, eyes as two small dark blocks facing -Z.
	part(
		model,
		"Hair",
		Vector3.new(shape.head + 0.1, shape.head * 0.35, shape.head + 0.1),
		CFrame.new(0, headY + shape.head * 0.4, 0.05),
		accent
	)
	for _, sign in SIGNS do
		local x = sign * 0.22
		part(
			model,
			"Eye",
			Vector3.new(0.16, 0.2, 0.05),
			CFrame.new(x * shape.head, headY + 0.05, -shape.head / 2 - 0.02),
			Color3.fromHex("#14182B")
		)
	end

	local armX = shape.torso.X / 2 + shape.limb.X / 2
	local shoulderY = torsoY + shape.torso.Y / 2 - 0.3
	local hands: { BasePart } = {}
	for side, sign in SIDES do
		local arm = part(
			model,
			`{side}UpperArm`,
			Vector3.new(shape.limb.X, shape.armLength, shape.limb.Y),
			CFrame.new(sign * armX, shoulderY - shape.armLength / 2 + 0.3, 0),
			body:Lerp(accent, 0.25)
		)
		joint(`{side}Shoulder`, torso, arm, CFrame.new(sign * armX, shoulderY, 0))
		hands[if side == "Left" then 1 else 2] = arm
		local leg = part(
			model,
			`{side}UpperLeg`,
			Vector3.new(shape.limb.X, shape.legLength, shape.limb.Y),
			CFrame.new(sign * shape.torso.X / 4, shape.legLength / 2, 0),
			body:Lerp(Color3.new(0, 0, 0), 0.35)
		)
		joint(`{side}Hip`, torso, leg, CFrame.new(sign * shape.torso.X / 4, legTop, 0))
	end
	prop(model, def.role, hands[2], body, accent)

	-- Rarity trim: a neon belt from Rare up, shoulder pads from Epic, a halo ring from Legendary,
	-- a second ring from Mythical. Same silhouette, more shine.
	local trimColor = Color3.fromHex(Art.Frames[def.rarity].colors[1])
	if trimLevel >= 1 then
		local belt = part(
			model,
			"TrimBelt",
			Vector3.new(shape.torso.X + 0.1, 0.25, shape.torso.Z + 0.1),
			CFrame.new(0, torsoY - shape.torso.Y / 2 + 0.3, 0),
			trimColor,
			Enum.Material.Neon
		)
		local w = Instance.new("WeldConstraint")
		w.Part0 = torso
		w.Part1 = belt
		w.Parent = belt
	end
	if trimLevel >= 2 then
		for _, sign in SIGNS do
			local pad = part(
				model,
				"TrimPad",
				Vector3.new(shape.limb.X + 0.3, 0.35, shape.limb.Y + 0.3),
				CFrame.new(sign * armX, shoulderY + 0.25, 0),
				trimColor,
				Enum.Material.Neon
			)
			local w = Instance.new("WeldConstraint")
			w.Part0 = torso
			w.Part1 = pad
			w.Parent = pad
		end
	end
	for ring = 1, math.max(0, trimLevel - 2) do
		local halo = part(
			model,
			"TrimHalo",
			Vector3.new(0.15, shape.head * (1.1 + ring * 0.35), shape.head * (1.1 + ring * 0.35)),
			CFrame.new(0, headY + shape.head * 0.9 + ring * 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			trimColor,
			Enum.Material.Neon
		)
		halo.Shape = Enum.PartType.Cylinder
		halo.Transparency = 0.15
		local w = Instance.new("WeldConstraint")
		w.Part0 = head
		w.Part1 = halo
		w.Parent = halo
	end

	model.PrimaryPart = root
	return model
end

-- Bounding size of a built rig, for framing it in a ViewportFrame.
function RigBuilder.extents(model: Model): Vector3
	local _, size = model:GetBoundingBox()
	return size
end

return table.freeze(RigBuilder)
