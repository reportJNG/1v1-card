--!strict
-- Egg and character visuals. Uses the uploaded asset when one exists; otherwise draws a clearly
-- labelled placeholder (the egg icon pack is never edited or recoloured: until its files are
-- uploaded as-is, the UI shows a neutral silhouette, not an imitation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
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

-- A card portrait: rarity frame, initials and the rarity in text (never colour alone).
function Visuals.portrait(parent: Instance, characterId: string, golden: boolean, size: Vector2): Frame
	local def = Characters.ById[characterId]
	local rarityColor = Theme.Rarity[def.rarity] or C.Muted
	local card = Ui.frame({
		BackgroundColor3 = C.Raised,
		Size = UDim2.fromOffset(size.X, size.Y),
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Ui.corner(8),
		Ui.stroke(if golden then C.Gold else rarityColor, if golden then 3 else 2),
		Ui.gradient(C.Raised, C.Background, 90),
	})
	local initials = ""
	for word in string.gmatch(def.displayName, "%a+") do
		initials ..= string.sub(word, 1, 1)
	end
	Ui.text({
		Text = initials,
		Font = Theme.Font.Title,
		TextSize = math.floor(size.Y * 0.32),
		TextColor3 = rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.45),
		Parent = card,
	})
	local rarityLabel = Ui.text({
		Text = def.rarity:upper() .. (if golden then " · GOLDEN" else ""),
		Font = Theme.Font.Bold,
		TextSize = math.max(9, math.floor(size.Y * 0.075)),
		TextColor3 = if golden then C.Gold else rarityColor,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromScale(0, 0.03),
		Size = UDim2.new(1, 0, 0, 14),
		Parent = card,
	})
	local nameLabel = Ui.text({
		Text = def.displayName,
		Font = Theme.Font.Bold,
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
