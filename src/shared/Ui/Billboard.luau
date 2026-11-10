--!strict
-- The one look for text that sits on objects in the world (BAD_GUI_THINKING_AND_UI section 4):
-- portal and merchant signs, NPC and Guardian names, node labels, player names. Built by the
-- server builders (World/WorldBuilder, World/HubBuilder) and by the client (App/WorldText), so
-- every billboard in the game reads the same:
--   big Luckiest Guy text with a thick dark stroke, an icon on the left, a gradient where the
--   colour means something, LightInfluence 0, a MaxDistance by kind.
-- Never AlwaysOnTop: with this game's lighting (Future + the UI blur) always-on-top billboards
-- are not drawn at all (found in Play on 2026-11-10; App/Prompts saw the same), so labels sit
-- high enough above their object to stay clear of it.
-- Not pure (it builds Instances); it only reads Config.
local Config = script.Parent.Parent.Config
local UiAssets = require(Config.UiAssets)

local Billboard = {}

export type Spec = {
	text: string,
	icon: string?, -- Config/UiAssets slot
	color: Color3?, -- text colour (white when a gradient is given)
	gradient: { Color3 }?, -- { top, bottom }
	studs: number?, -- text height in studs (default 3)
	offset: Vector3?, -- StudsOffset
	maxDistance: number?,
	name: string?,
}

-- Kinds with their distance and draw rule, so call sites don't pick numbers.
Billboard.Kind = table.freeze({
	place = { maxDistance = 260 }, -- portals, arena gate, shop pavilion
	npc = { maxDistance = 90 }, -- merchants, Guardians
	node = { maxDistance = 45 }, -- resource nodes
	player = { maxDistance = 70 },
})

local INK = Color3.fromHex("#05070F")

local function asset(slot: string): string?
	local def = UiAssets[slot]
	if def == nil then
		return nil
	end
	return if def.final and def.final ~= "" then def.final else def.temp
end

function Billboard.make(spec: Spec): BillboardGui
	local h = spec.studs or 3
	local iconId = spec.icon and asset(spec.icon)
	local textW = math.max(1, utf8.len(spec.text) or #spec.text) * h * 0.62
	local iconW = if iconId then h * 1.15 else 0
	local gui = Instance.new("BillboardGui")
	gui.Name = spec.name or "Billboard"
	gui.Size = UDim2.fromScale(textW + iconW, h)
	gui.StudsOffset = spec.offset or Vector3.zero
	gui.LightInfluence = 0
	gui.MaxDistance = spec.maxDistance or 90
	gui.AlwaysOnTop = false -- see the header
	gui.ResetOnSpawn = false
	if iconId then
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.Image = iconId
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.Size = UDim2.fromScale(iconW / (textW + iconW), 1)
		img.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Text = spec.text
	label.FontFace = Font.fromEnum(Enum.Font.LuckiestGuy)
	label.TextScaled = true
	label.TextColor3 = if spec.gradient then Color3.new(1, 1, 1) else (spec.color or Color3.new(1, 1, 1))
	label.Position = UDim2.fromScale(iconW / (textW + iconW), 0)
	label.Size = UDim2.fromScale(textW / (textW + iconW), 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = math.clamp(h * 0.9, 2, 4)
	stroke.Parent = label
	if spec.gradient then
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new(spec.gradient[1], spec.gradient[2] or spec.gradient[1])
		g.Parent = label
	end
	return gui
end

-- Colour pairs that carry meaning (rule 7): gold = coins and places, cyan = gems, green = gain.
Billboard.Gold = table.freeze({ Color3.fromHex("#FFF3B0"), Color3.fromHex("#FFB300") })
Billboard.Cyan = table.freeze({ Color3.fromHex("#D6FBFF"), Color3.fromHex("#2FB7FF") })
Billboard.Green = table.freeze({ Color3.fromHex("#E2FFD6"), Color3.fromHex("#33D17A") })
Billboard.Violet = table.freeze({ Color3.fromHex("#F1E2FF"), Color3.fromHex("#A469FF") })

return Billboard
