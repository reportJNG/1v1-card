--!strict
-- Egg and character visuals. Uses the uploaded asset when one exists; otherwise draws a clearly
-- labelled placeholder (the egg icon pack is never edited or recoloured: until its files are
-- uploaded as-is, the UI shows a neutral silhouette, not an imitation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
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

-- The egg's icon from the Egg Icon Pack, unedited (MISSION 7.1): the 64 px file for small views,
-- the 256 px file otherwise, never shown bigger than about 256 physical px (128 design px at the
-- 1080p scale): big moments get glow, rays and pedestals around the egg instead.
local EGG_MAX = 128
local SMALL_UP_TO = 40 -- design px (about 80 physical px on PC, 56 on phones)

function Visuals.egg(parent: Instance, egg: Types.EggDef, golden: boolean, size: number): GuiObject
	size = math.min(size, EGG_MAX)
	local small = size <= SMALL_UP_TO
	local assetId = if golden
		then (if small then egg.icon.goldenSmallAssetId else nil) or egg.icon.goldenAssetId
		else (if small then egg.icon.smallAssetId else nil) or egg.icon.normalAssetId
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
