--!strict
-- Egg and character visuals. Uses the uploaded asset when one exists; otherwise draws a clearly
-- labelled placeholder (the egg icon pack is never edited or recoloured: until its files are
-- uploaded as-is, the UI shows a neutral silhouette, not an imitation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)
local RigBuilder = require(Shared.Art.RigBuilder)
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

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

local function sequence(hexes: { string }): ColorSequence
	local keys = {}
	for i, hex in hexes do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #hexes - 1), Color3.fromHex(hex)))
	end
	return ColorSequence.new(keys)
end

-- The rarity card frame (Config/Art.Frames), with a gold foil for Golden copies. Same card
-- silhouette for every rarity; only the border, gradient and shine change (design rule 6).
function Visuals.frame(card: GuiObject, rarity: string, golden: boolean, animate: boolean?)
	local style = Art.Frames[rarity] or Art.Frames.Common
	local stroke = Ui.new("UIStroke", {
		Thickness = style.border + (if golden then 1 else 0),
		Color = Color3.new(1, 1, 1),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = card,
	})
	local gradient = Ui.new("UIGradient", {
		Color = sequence(if golden then Art.GoldenFoil.colors else style.colors),
		Rotation = 45,
		Parent = stroke,
	})
	if style.inner then
		Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 1, -8),
			Parent = card,
		}, { Ui.corner(6), Ui.stroke(Color3.fromHex(style.colors[#style.colors]), 1, 0.4) })
	end
	if (style.shine or golden) and animate ~= false then
		gradient.Offset = Vector2.new(-1, 0)
		TweenService:Create(
			gradient,
			TweenInfo.new(
				if golden then 1.6 else 2.4,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.InOut,
				-1,
				false,
				0.6
			),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	end
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

-- A card portrait: rarity frame, initials and the rarity in text (never colour alone).
function Visuals.portrait(
	parent: Instance,
	characterId: string,
	golden: boolean,
	size: Vector2,
	withFigure: boolean?
): Frame
	local def = Characters.ById[characterId]
	local rarityColor = Theme.Rarity[def.rarity] or C.Muted
	local card = Ui.frame({
		BackgroundColor3 = C.Raised,
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Ui.corner(8),
		Ui.gradient(C.Raised, C.Background, 90),
	})
	-- Shine only on large cards: a grid of hundreds must not run hundreds of endless tweens.
	Visuals.frame(card, def.rarity, golden, size.Y >= 140)
	local initials = ""
	for word in string.gmatch(def.displayName, "%a+") do
		initials ..= string.sub(word, 1, 1)
	end
	if withFigure then
		local fig = Visuals.figure(card, characterId, Vector2.new(size.X - 8, math.floor(size.Y * 0.62)))
		fig.Name = "Figure"
		fig.Position = UDim2.fromOffset(4, math.floor(size.Y * 0.1))
	end
	Ui.text({
		Visible = not withFigure,
		Text = initials,
		FontFace = Theme.Face.Title,
		TextSize = math.floor(size.Y * 0.32),
		TextColor3 = rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.45),
		Parent = card,
	})
	local rarityLabel = Ui.text({
		Text = def.rarity:upper() .. (if golden then " · GOLDEN" else ""),
		FontFace = Theme.Face.Bold,
		TextSize = math.max(9, math.floor(size.Y * 0.075)),
		TextColor3 = if golden then C.Gold else rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.03),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = card,
	})
	local nameLabel = Ui.text({
		Text = def.displayName,
		FontFace = Theme.Face.Bold,
		TextSize = math.max(10, math.floor(size.Y * 0.085)),
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 2, 1, -math.floor(size.Y * 0.3)),
		Size = UDim2.new(1, -4, 0, math.floor(size.Y * 0.2)),
		Parent = card,
	})
	Ui.fit(rarityLabel, math.max(9, math.floor(size.Y * 0.075)))
	Ui.fit(nameLabel, math.max(10, math.floor(size.Y * 0.085)))
	card:SetAttribute("Placeholder", def.assets.portrait == nil)
	return card
end

return Visuals
