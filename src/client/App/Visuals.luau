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

-- A trading card (ART_STYLE section 4, "Cards"): one 5:7 silhouette for every rarity. The art
-- fills the card (the character's card art when uploaded, else a 3D placeholder figure or the
-- initials), and the rarity frame image overlays it with the rarity word, the family badge and
-- the name plate. Golden copies add the foil and a ribbon. The card keeps 5:7 inside `size`.
function Visuals.portrait(
	parent: Instance,
	characterId: string,
	golden: boolean,
	size: Vector2,
	withFigure: boolean?
): Frame
	local def = Characters.ById[characterId]
	local rarityColor = Theme.Rarity[def.rarity] or C.Muted
	local family = Art.FamilyColors[def.family]
	local body = Color3.fromHex(family.body)
	local accent = Color3.fromHex(family.accent)
	local holder = Ui.frame({
		Name = "Card",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size.X, size.Y),
		Parent = parent,
	})
	local w = math.min(size.X, math.floor(size.Y * 5 / 7))
	local h = math.floor(w * 7 / 5)
	local card = Ui.frame({
		Name = "Face",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		Parent = holder,
	})
	-- Art window (inside the frame border): family-coloured backdrop.
	local inset = math.max(3, math.floor(w * 0.035))
	local art = Ui.frame({
		Name = "Art",
		BackgroundColor3 = body,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		ClipsDescendants = true,
		Parent = card,
	}, {
		Ui.corner(math.floor(w * 0.06)),
		Ui.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, body:Lerp(accent, 0.25)),
				ColorSequenceKeypoint.new(0.55, body:Lerp(C.Night, 0.45)),
				ColorSequenceKeypoint.new(1, C.Night),
			}),
			Rotation = 90,
		}),
	})
	Ui.image("egg_glow", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(1.3, 1.3 * 5 / 7),
		ImageColor3 = accent,
		ImageTransparency = 0.55,
		ScaleType = Enum.ScaleType.Stretch,
		Parent = art,
	})
	if def.assets.cardArt then
		Ui.new("ImageLabel", {
			Name = "CardArt",
			Image = def.assets.cardArt,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(1, 1),
			Parent = art,
		})
	elseif withFigure then
		local fig = Visuals.figure(art, characterId, Vector2.new(w - 2 * inset, math.floor(h * 0.74)))
		fig.Name = "Figure"
		fig.Position = UDim2.fromOffset(0, math.floor(h * 0.07))
	else
		local initials = ""
		for word in string.gmatch(def.displayName, "%a+") do
			initials ..= string.sub(word, 1, 1)
		end
		local mark = Ui.display({
			Text = initials,
			TextSize = math.floor(h * 0.3),
			TextColor3 = accent,
			Position = UDim2.fromScale(0, 0.18),
			Size = UDim2.fromScale(1, 0.42),
			Parent = art,
		})
		Ui.fit(mark, math.floor(h * 0.3), 8)
	end
	-- Light sweep on big Legendary/Mythical/Golden cards only (grids must not run endless tweens).
	if (def.rarity == "Legendary" or def.rarity == "Mythical" or golden) and h >= 140 then
		local shine = Ui.image("card_shine", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.4, 0.5),
			Size = UDim2.fromScale(0.5, 1.2),
			ScaleType = Enum.ScaleType.Stretch,
			ImageTransparency = 0.35,
			ZIndex = 3,
			Parent = art,
		})
		TweenService:Create(
			shine,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.2),
			{ Position = UDim2.fromScale(1.4, 0.5) }
		):Play()
	end
	-- The frame image on top.
	Ui.image(`card_frame_{string.lower(def.rarity)}`, {
		Name = "Frame",
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = card,
	})
	if golden then
		Ui.image("card_golden_foil", {
			Name = "Foil",
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = card,
		})
	end
	-- Rarity word in the top-left plate, family initial in the top-right badge (words, never
	-- colour alone).
	local small = math.max(8, math.floor(h * 0.05))
	local rarityLabel = Ui.text({
		Name = "Rarity",
		Text = if golden then `{string.upper(def.rarity)} · GOLD` else string.upper(def.rarity),
		FontFace = Theme.Face.Title,
		TextSize = small,
		TextColor3 = if golden then C.GoldHi else rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromScale(0.05, 0.035),
		Size = UDim2.fromScale(0.27, 0.058),
		ZIndex = 6,
		Parent = card,
	})
	Ui.fit(rarityLabel, small, 6)
	local badge = Ui.text({
		Name = "Family",
		Text = string.sub(def.family, 1, 1),
		FontFace = Theme.Face.Display,
		TextSize = small + 2,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.855, 0.087),
		Size = UDim2.fromScale(0.11, 0.08),
		ZIndex = 6,
		Parent = card,
	})
	Ui.outline(C.Night, 1).Parent = badge
	local nameLabel = Ui.text({
		Name = "Name",
		Text = def.displayName,
		FontFace = Theme.Face.Title,
		TextSize = math.max(9, math.floor(h * 0.075)),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromScale(0.08, 0.83),
		Size = UDim2.fromScale(0.84, 0.1),
		ZIndex = 6,
		Parent = card,
	})
	Ui.outline(C.Night, 1.5).Parent = nameLabel
	Ui.fit(nameLabel, math.max(9, math.floor(h * 0.075)), 6)
	holder:SetAttribute("Placeholder", def.assets.cardArt == nil)
	return holder
end

return Visuals
