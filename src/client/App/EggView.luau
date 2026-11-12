--!strict
-- A 3D egg in a ViewportFrame (MAKE_3D_EGGS_AND_FIGHTERS section 1: the hatch uses the same 3D egg
-- as the lobby pedestals). The egg is Shared/Art/EggModel, lit warm from the upper left and turning
-- slowly while it is on screen. The 2D pack icons stay in the menus (Shop, Inventory).
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local EggModel = require(Shared.Art.EggModel)

local EggView = {}

-- A square viewport `size` px wide showing the egg; props go on the viewport.
function EggView.new(eggId: string, golden: boolean, size: number, props: { [string]: any }?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Egg3D"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromOffset(size, size)
	vp.Ambient = Color3.fromRGB(170, 160, 190)
	vp.LightColor = Color3.fromRGB(255, 244, 228)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	local model = EggModel.build(eggId, golden, 3.4)
	model:PivotTo(CFrame.new(0, -1.7, 0))
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 8.2), Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	if props then
		for k, v in props do
			(vp :: any)[k] = v
		end
	end
	local turn = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if vp.Parent == nil then
			if conn then
				conn:Disconnect()
			end
			return
		end
		if vp.Visible then
			turn += dt * 0.9
			model:PivotTo(CFrame.new(0, -1.7, 0) * CFrame.Angles(0, turn, 0))
		end
	end)
	return vp
end

return table.freeze(EggView)
