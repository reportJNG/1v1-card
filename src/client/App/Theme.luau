--!strict
-- Design tokens from docs/ART_STYLE.md (which extends docs/brief/05-ui-design-system.md). UI code
-- uses these, never raw colours or fonts.
local Theme = {}

Theme.Color = table.freeze({
	Night = Color3.fromHex("#05070F"),
	Background = Color3.fromHex("#080B18"),
	Panel = Color3.fromHex("#12192E"),
	PanelDeep = Color3.fromHex("#0C1124"),
	Raised = Color3.fromHex("#1A2340"),
	RaisedHi = Color3.fromHex("#243058"),
	Purple = Color3.fromHex("#A469FF"),
	Violet = Color3.fromHex("#7B3CFF"),
	Blue = Color3.fromHex("#45BEFF"),
	Pink = Color3.fromHex("#FF7BD5"),
	Gold = Color3.fromHex("#FFC54B"),
	GoldHi = Color3.fromHex("#FFE27A"),
	GoldLo = Color3.fromHex("#E08A00"),
	GoldInk = Color3.fromHex("#3A2200"),
	Green = Color3.fromHex("#48DA97"),
	Red = Color3.fromHex("#FF668F"),
	Text = Color3.fromHex("#F2F5FF"),
	Muted = Color3.fromHex("#9EAED3"),
	Stroke = Color3.fromHex("#2A3760"),
	Black = Color3.new(0, 0, 0),
	White = Color3.new(1, 1, 1),
})

-- Rarity colours; the UI always shows the rarity name too (never colour alone).
Theme.Rarity = table.freeze({
	Common = Color3.fromHex("#B9C7DC"),
	Rare = Color3.fromHex("#45BEFF"),
	Epic = Color3.fromHex("#A469FF"),
	Legendary = Color3.fromHex("#FFC54B"),
	Mythical = Color3.fromHex("#FF668F"),
}) :: { [string]: Color3 }

local BUILDER = "rbxasset://fonts/families/BuilderSans.json"

-- Typography (ART_STYLE section 3): Luckiest Guy for display moments, Builder Sans for the rest.
Theme.Face = table.freeze({
	Display = Font.fromEnum(Enum.Font.LuckiestGuy),
	Title = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
	Number = Font.new(BUILDER, Enum.FontWeight.Heavy),
	Bold = Font.new(BUILDER, Enum.FontWeight.Bold),
	Body = Font.new(BUILDER, Enum.FontWeight.Medium),
})

-- Sizes in the 960 x 540 design space; a UIScale fits it to the device (mobile first).
Theme.Size = table.freeze({
	base = Vector2.new(960, 540),
	display = 48,
	title = 24,
	heading = 18,
	body = 15,
	small = 12,
	button = 40,
	corner = 10,
	pad = 10,
	tap = 44, -- minimum tap target
})

-- Motion (ART_STYLE section 4).
Theme.Motion = table.freeze({
	open = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	close = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	hover = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	spring = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	count = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
})

return table.freeze(Theme)
