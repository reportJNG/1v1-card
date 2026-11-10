--!strict
-- The UI kit. Two halves:
--   Kit.piece(name)  the painted UI pieces (MASTER_FIX_PLAN Phase 3: owner sheets cut by
--                    scripts/art/cut_sheet.py, Config/UiKit): the only way screens get a panel,
--                    button, tile or banner image by name; a piece that isn't LIVE yet draws its
--                    TEMP Config/UiAssets slot. (The plan calls this "App/Ui/Kit".)
--   Kit.id/image     the step-5 card and egg kit (Config/CardKit, CARDS_EGGS_MISSION): image ids by
--                    slot, the kit size for a card of a given height, and the shared frame geometry. Card frames, glows, energy
-- strokes, panels and the Golden overlay all share one canvas per size, so every layer of a card
-- is the same full-canvas ImageLabel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CardKit = require(Shared.Config.CardKit)
local UiKit = require(Shared.Config.UiKit)
local UiAssets = require(Shared.Config.UiAssets)
local Rarities = require(Shared.Config.Rarities)

local Kit = {}

export type Size = "large" | "medium" | "small"

-- A painted piece ready to draw: its image, its native size and (if it stretches) its 9-slice
-- centre as a SliceCenter rect. `live` is false while the TEMP fallback is drawn.
export type Piece = { image: string, size: Vector2, slice: Rect?, live: boolean }

function Kit.piece(name: string): Piece
	local p = UiKit.Pieces[name]
	assert(p, `unknown UI kit piece {name}`)
	if p.id and p.size then
		local m = p.slice
		return {
			image = p.id,
			size = Vector2.new(p.size[1], p.size[2]),
			slice = if m then Rect.new(m[1], m[2], p.size[1] - m[3], p.size[2] - m[4]) else nil,
			live = true,
		}
	end
	local def = UiAssets[p.fallback :: string]
	assert(def, `kit piece {name}: unknown fallback slot {p.fallback}`)
	local s = def.slice
	return {
		image = if def.final and def.final ~= "" then def.final else def.temp,
		size = Vector2.new(def.size[1], def.size[2]),
		slice = if s then Rect.new(s[1], s[2], s[3], s[4]) else nil,
		live = false,
	}
end

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
