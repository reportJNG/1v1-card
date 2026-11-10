--!strict
-- The one way screens show an item: its painted icon (Config/UiAssets slot `item.icon`) once that
-- slot is live, otherwise (TEMP) the item's own resource-node mesh in a small viewport, lit and
-- slowly turning. Every item therefore always looks like itself (MASTER_FIX_PLAN Phase 1: the
-- Oak Log once showed a crystal).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local UiAssets = require(Shared.Config.UiAssets)
local WorldProps = require(Shared.Config.WorldProps)
local ItemArt = require(Shared.Domain.ItemArt)
local Ui = require(script.Parent.Ui)

local ItemIcon = {}

local spinning: { [Model]: boolean } = {}
local spinConn: RBXScriptConnection? = nil

local function spin(model: Model)
	spinning[model] = true
	model.Destroying:Connect(function()
		spinning[model] = nil
	end)
	if spinConn then
		return
	end
	spinConn = RunService.RenderStepped:Connect(function(dt: number)
		for m in spinning do
			if m.Parent and (m.Parent :: any).Visible ~= false then
				m:PivotTo(m:GetPivot() * CFrame.Angles(0, dt * 0.6, 0))
			end
		end
	end)
end

-- A square icon `size` px wide. `props` go on the returned GuiObject (Position, AnchorPoint…).
function ItemIcon.new(itemId: string, size: number, props: { [string]: any }?, still: boolean?): GuiObject
	local item = Items.ById[itemId]
	assert(item, `unknown item {itemId}`)
	local slot = UiAssets[item.icon]
	if slot then
		return Ui.icon(item.icon, size, props)
	end
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		Name = "ItemIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Ambient = Color3.fromRGB(150, 150, 165),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1.2, -0.8),
	})
	local key = ItemArt.nodeModel(itemId)
	local def = key and WorldProps.Models[key]
	if def then
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Anchored = true
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 0
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = def.mesh
		mesh.TextureId = def.texture
		mesh.Parent = part
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = vp
		local extent = math.max(def.size[1], def.size[2], def.size[3])
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dist = extent * 2.1
		cam.CFrame = CFrame.lookAt(Vector3.new(0, extent * 0.35, dist), Vector3.new(0, 0, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam
		model:PivotTo(CFrame.Angles(0, math.rad(-25), 0))
		if not still then
			spin(model)
		end
	end
	if props then
		for k, v in props do
			(vp :: any)[k] = v
		end
	end
	return vp
end

return ItemIcon
