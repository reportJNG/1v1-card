--!strict
-- Egg and character visuals. Uses the uploaded asset when one exists; otherwise draws a clearly
-- labelled placeholder (the egg icon pack is never edited or recoloured: until its files are
-- uploaded as-is, the UI shows a neutral silhouette, not an imitation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local RigBuilder = require(Shared.Art.RigBuilder)
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Card = require(script.Parent.Card)

local C = Theme.Color

local Visuals = {}

local BAND_TINT: { [string]: Color3 } = {
	A = Color3.fromHex("#8FA3C7"),
	B = Color3.fromHex("#45BEFF"),
	C = Color3.fromHex("#A469FF"),
	D = Color3.fromHex("#FFC54B"),
	E = Color3.fromHex("#FF668F"),
	Event = Color3.fromHex("#48DA97"),
}

function Visuals.egg(parent: Instance, egg: Types.EggDef, golden: boolean, size: number): GuiObject
	local assetId = if golden then egg.icon.goldenAssetId else egg.icon.normalAssetId
	if assetId then
		return Ui.new("ImageLabel", {
			Image = assetId,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(size, size),
			ScaleType = Enum.ScaleType.Fit,
			Parent = parent,
		})
	end
	local tint = if golden then C.Gold else BAND_TINT[egg.oddsBand] or C.Muted
	local holder =
		Ui.frame({ BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), Parent = parent })
	Ui.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.62, 0.8),
		BackgroundColor3 = tint,
		Parent = holder,
	}, {
		Ui.corner(math.floor(size * 0.4)),
		Ui.gradient(Color3.new(1, 1, 1), tint, 90),
		Ui.stroke(if golden then C.Gold else C.Stroke, 2),
	})
	Ui.text({
		Text = "art pending",
		TextSize = 9,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = holder,
	})
	return holder
end

-- A 3D figure of the character in a ViewportFrame: the placeholder rig (Shared/Art/RigBuilder)
-- until the character's approved model exists. Used where one or a few show at once (inspect,
-- deck slots, battle, hatch), never in long grids, to keep mobile rendering cheap.
function Visuals.figure(parent: Instance, characterId: string, size: Vector2): ViewportFrame
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Ambient = Color3.fromRGB(170, 170, 190),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-0.4, -1, -0.6),
		Parent = parent,
	})
	local model = RigBuilder.build(characterId)
	model.Parent = vp
	local cf, ext = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local distance = math.max(ext.Y, ext.X) / (2 * math.tan(math.rad(15))) * 1.15
	local target = cf.Position
	camera.CFrame = CFrame.lookAt(target + Vector3.new(distance * 0.35, distance * 0.12, -distance), target)
	camera.Parent = vp
	vp.CurrentCamera = camera
	vp:SetAttribute("Placeholder", true)
	return vp
end

-- A short lunge toward the opponent: the battle screen plays it on the attacker's figure.
function Visuals.lunge(vp: ViewportFrame, toward: number)
	local model = vp:FindFirstChildOfClass("Model")
	if model == nil then
		return
	end
	local start = model:GetPivot()
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(v)
		if model.Parent then
			model:PivotTo(start * CFrame.new(toward * v, 0, -v))
		end
	end)
	local out = TweenService:Create(value, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Value = 1.4 })
	out.Completed:Connect(function()
		TweenService:Create(value, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Value = 0 }):Play()
	end)
	out:Play()
end

-- A trading card: the layered card (App/Card) for a copy at `level`. `interactive` turns on the
-- 2.5D parallax (big single cards: inspect, deck slots, hatch reveal, results). The card keeps 5:7
-- inside `size`.
function Visuals.portrait(
	parent: Instance,
	characterId: string,
	golden: boolean,
	size: Vector2,
	interactive: boolean?,
	level: number?
): Frame
	return Card.build(parent, {
		characterId = characterId,
		golden = golden,
		level = level or 1,
		size = size,
		interactive = interactive,
	})
end

return Visuals
