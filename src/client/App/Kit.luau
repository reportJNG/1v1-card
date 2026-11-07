--!strict
-- The step-5 card and egg kit (Config/CardKit, CARDS_EGGS_MISSION): image ids by slot, the kit
-- size for a card of a given height, and the shared frame geometry. Card frames, glows, energy
-- strokes, panels and the Golden overlay all share one canvas per size, so every layer of a card
-- is the same full-canvas ImageLabel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardKit = require(Shared.Config.CardKit)
local Rarities = require(Shared.Config.Rarities)

local Kit = {}

export type Size = "large" | "medium" | "small"

function Kit.id(slot: string): string
	local s = CardKit.Slots[slot]
	assert(s, `unknown kit slot {slot}`)
	return s.id
end

function Kit.has(slot: string): boolean
	return CardKit.Slots[slot] ~= nil
end

-- A plain kit image.
function Kit.image(slot: string, props: { [string]: any }): ImageLabel
	local img = Instance.new("ImageLabel")
	img.Image = Kit.id(slot)
	img.BackgroundTransparency = 1
	img.ScaleType = Enum.ScaleType.Fit
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			(img :: any)[k] = v
		end
	end
	img.Parent = parent
	return img
end

-- The kit size for a card `h` design px tall. Small cards get their own, simpler art (thicker lines,
-- fewer flourishes); images are never just scaled down.
function Kit.sizeFor(h: number): Size
	if h >= 220 then
		return "large"
	elseif h >= 110 then
		return "medium"
	end
	return "small"
end

-- Rarity tag (n / r / sr / ssr / ur) for kit slot names.
function Kit.tag(rarity: string): string
	return Rarities.Defs[rarity].tag
end

-- Canvas size and offset for a card face of w x h: the canvas is larger (bleed for flourishes
-- and glow) and placed so its card rect lands exactly on the face. Returns Size and Position
-- UDim2s relative to the face.
function Kit.canvas(size: Size, w: number, h: number): (UDim2, UDim2)
	local g = CardKit.Geometry[size]
	local cw, ch = w / g.card[3], h / g.card[4]
	return UDim2.fromOffset(cw, ch), UDim2.fromOffset(-g.card[1] * cw, -g.card[2] * ch)
end

-- The art window as fractions of the card face (x, y, w, h).
function Kit.window(size: Size): (number, number, number, number)
	local g = CardKit.Geometry[size]
	local c, win = g.card, g.window
	return (win[1] - c[1]) / c[3], (win[2] - c[2]) / c[4], win[3] / c[3], win[4] / c[4]
end

return table.freeze(Kit)
