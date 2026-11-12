--!strict
-- A 3D fighter (MAKE_3D_EGGS_AND_FIGHTERS.md section 2): Roblox's standard R15 rig, made from a
-- HumanoidDescription (no body mesh of ours), in the fighter's BodyColors, with its identity meshes
-- (Config/Fighters: hair, coat, scarf, armour, weapon; made in Blender) welded to their R15 parts.
-- The default face decal is removed: the eyes are part of the head mesh (determined, closed mouth).
-- Only built for fighters whose meshes are all uploaded (Fighters.ready); everyone else stays a
-- standee. The model is anchored, its pivot is the feet facing -Z, like Shared/Art/Standee.
local Players = game:GetService("Players")
local Config = script.Parent.Parent.Config
local Fighters = require(Config.Fighters)

local FighterRig = {}

local R15_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local function colour(desc: HumanoidDescription, def: Fighters.Fighter)
	local c = def.colors
	desc.HeadColor = Color3.fromHex(c.head)
	desc.TorsoColor = Color3.fromHex(c.torso)
	desc.LeftArmColor = Color3.fromHex(c.arms)
	desc.RightArmColor = Color3.fromHex(c.arms)
	desc.LeftLegColor = Color3.fromHex(c.legs)
	desc.RightLegColor = Color3.fromHex(c.legs)
end

-- Builds the rig for a fighter definition. `theme` tints the Guardian's glowing parts. `bare` skips
-- the identity meshes (Studio pose previews only; the game never shows a bare rig).
function FighterRig.fromDef(def: Fighters.Fighter, name: string, theme: Color3?, bare: boolean?): Model
	local desc = Instance.new("HumanoidDescription")
	colour(desc, def)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	local head = model:FindFirstChild("Head")
	local face = head and head:FindFirstChildOfClass("Decal")
	if face then
		face:Destroy()
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	if not bare then
		for partName, p in def.parts do
			local host = model:FindFirstChild(p.attach)
			if host and host:IsA("BasePart") and p.mesh and p.mesh ~= "" then
				local piece = Instance.new("Part")
				piece.Name = partName
				piece.Size = host.Size
				piece.CanCollide = false
				piece.CanQuery = false
				piece.CanTouch = false
				piece.Massless = true
				piece.CastShadow = true
				piece.CFrame = host.CFrame
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.FileMesh
				mesh.MeshId = p.mesh
				mesh.TextureId = p.texture or ""
				mesh.Parent = piece
				if theme and p.texture == nil then
					piece.Color = theme
				end
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = host
				weld.Part1 = piece
				weld.Parent = piece
				piece.Parent = model
			end
		end
	end
	if def.scale ~= 1 then
		model:ScaleTo(def.scale)
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local feet = root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
	model.WorldPivot = feet
	model:SetAttribute("Rig", "R15")
	return model
end

-- The 3D fighter for a character, or nil while its meshes aren't all uploaded (use the standee).
function FighterRig.build(characterId: string): Model?
	local def = Fighters.ById[characterId]
	if not Fighters.ready(def) then
		return nil
	end
	return FighterRig.fromDef(def :: Fighters.Fighter, characterId)
end

-- The Guardian in its world's colour, or nil until its meshes are uploaded.
function FighterRig.guardian(worldId: number): Model?
	if not Fighters.ready(Fighters.Guardian) then
		return nil
	end
	local theme = Fighters.GuardianTheme[worldId] or Fighters.GuardianTheme[1]
	return FighterRig.fromDef(Fighters.Guardian, "Guardian", Color3.fromHex(theme))
end

FighterRig.PARTS = table.freeze(R15_PARTS)

return table.freeze(FighterRig)
