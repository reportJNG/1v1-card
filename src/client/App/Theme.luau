--!strict
-- Design tokens from docs/brief/05-ui-design-system.md. UI code uses these, never raw colours.
local Theme = {}

Theme.Color = table.freeze({
	Background = Color3.fromHex("#080B18"),
	Panel = Color3.fromHex("#12192E"),
	Raised = Color3.fromHex("#1A2340"),
	Purple = Color3.fromHex("#A469FF"),
	Blue = Color3.fromHex("#45BEFF"),
	Gold = Color3.fromHex("#FFC54B"),
	Green = Color3.fromHex("#48DA97"),
	Red = Color3.fromHex("#FF668F"),
	Text = Color3.fromHex("#F2F5FF"),
	Muted = Color3.fromHex("#9EAED3"),
	Stroke = Color3.fromHex("#2A3760"),
	Black = Color3.new(0, 0, 0),
})

-- Rarity colours; the UI always shows the rarity name too (never colour alone).
Theme.Rarity = table.freeze({
	Common = Color3.fromHex("#B9C7DC"),
	Rare = Color3.fromHex("#45BEFF"),
	Epic = Color3.fromHex("#A469FF"),
	Legendary = Color3.fromHex("#FFC54B"),
	Mythical = Color3.fromHex("#FF668F"),
}) :: { [string]: Color3 }

Theme.Font = table.freeze({
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
})

-- Sizes in the 960 x 540 design space; a UIScale fits it to the device (mobile first).
Theme.Size = table.freeze({
	base = Vector2.new(960, 540),
	title = 24,
	heading = 18,
	body = 15,
	small = 12,
	button = 40,
	corner = 10,
	pad = 10,
})

return table.freeze(Theme)
