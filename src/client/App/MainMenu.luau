--!strict
-- The main menu (POLISH_MISSION B, owner step 3): its own full screen, not the lobby. An opaque key
-- art backdrop (a deep violet gradient, slowly turning light rays, drifting card backs and
-- sparkles), the 1V1 CARD logo, a fanned showcase of three cards, one big PLAY and four icon
-- shortcuts (Cards, Eggs, Deck, Settings). While the profile loads it shows a loading line instead
-- of the buttons. PLAY always takes the player to the lobby (App sends World.Hub) and the menu
-- fades away; the HUD's Menu button comes back here.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Visuals = require(script.Parent.Visuals)

local C = Theme.Color

local MainMenu = {}

export type Menu = {
	frame: Frame,
	setLoading: (loading: boolean) -> (),
	show: (on: boolean) -> (),
}

local VERSION = "v0.4 · Ten worlds · 100 original characters"

-- The showcase: one card of each top rarity, from the original roster.
local SHOWCASE = {
	{ id = "vesper_shade", rot = -12, x = -150, y = 18 },
	{ id = "aurelia_dawn", rot = 0, x = 0, y = 0 },
	{ id = "taren_ashscale", rot = 12, x = 150, y = 18 },
}

local SHORTCUTS = {
	{ id = "Collection", icon = "icon_cards", label = "Cards", accent = Color3.fromHex("#A469FF") },
	{ id = "Shop", icon = "icon_shop", label = "Eggs", accent = Color3.fromHex("#FF6FC8") },
	{ id = "Deck", icon = "icon_deck", label = "Deck", accent = Color3.fromHex("#3FA9FF") },
	{ id = "Settings", icon = "icon_settings", label = "Settings", accent = Color3.fromHex("#8D9BC4") },
}

local function tile(item: any, size: number, onClick: () -> ()): TextButton
	local b: TextButton = Ui.new("TextButton", {
		Name = item.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.White,
		Size = UDim2.fromOffset(size, size),
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Ui.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, item.accent:Lerp(C.White, 0.25)),
				ColorSequenceKeypoint.new(0.55, item.accent),
				ColorSequenceKeypoint.new(1, item.accent:Lerp(C.Night, 0.45)),
			}),
		}),
		Ui.new(
			"UIStroke",
			{ Color = C.Night, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }
		),
	})
	Ui.frame({
		Name = "Gloss",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.78,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0.42, 0),
		ZIndex = 2,
		Parent = b,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	Ui.icon(item.icon, math.floor(size * 0.62), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.42, 0),
		ZIndex = 3,
		Parent = b,
	})
	Ui.display({
		Text = item.label,
		TextSize = 13,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.new(1, 8, 0, 16),
		ZIndex = 4,
		Parent = b,
	})
	Ui.juice(b)
	b.Activated:Connect(function()
		Ui.sound("click")
		onClick()
	end)
	return b
end

function MainMenu.build(
	parent: Instance,
	actions: { play: () -> (), open: (name: string) -> () },
	reduced: () -> boolean
): Menu
	local frame = Ui.frame({
		Name = "MainMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	local group = Ui.new("CanvasGroup", {
		Name = "Group",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 0,
		Parent = frame,
	})

	-- Backdrop: opaque, so the menu never shows the lobby behind it.
	local backdrop = Ui.frame({
		Name = "Backdrop",
		BackgroundColor3 = C.White,
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	})
	local sky = Ui.new("UIGradient", {
		Rotation = 35,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHex("#1A0B3D")),
			ColorSequenceKeypoint.new(0.45, Color3.fromHex("#3B1676")),
			ColorSequenceKeypoint.new(0.8, Color3.fromHex("#7A1F7E")),
			ColorSequenceKeypoint.new(1, Color3.fromHex("#C2306F")),
		}),
		Parent = backdrop,
	})
	local rays = Ui.image("light_rays", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -250, 0.48, 0),
		Size = UDim2.fromOffset(900, 900),
		ImageColor3 = Color3.fromHex("#FFB3F0"),
		ImageTransparency = 0.82,
		Parent = group,
	})
	Ui.image("egg_glow", {
		Name = "Glow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -250, 0.5, 0),
		Size = UDim2.fromOffset(560, 560),
		ImageColor3 = Color3.fromHex("#FF7BD5"),
		ImageTransparency = 0.45,
		Parent = group,
	})
	-- Drifting card backs (bottom to top, slowly turning).
	local drifters: { { img: ImageLabel, x: number, speed: number, phase: number, spin: number } } = {}
	for i = 1, 9 do
		local img = Ui.image("card_back", {
			Name = `Drift{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(46 + (i % 3) * 14, (46 + (i % 3) * 14) * 1.4),
			ScaleType = Enum.ScaleType.Stretch,
			ImageTransparency = 0.55 + (i % 3) * 0.12,
			Parent = group,
		})
		table.insert(drifters, {
			img = img,
			x = 0.08 + (i - 1) * 0.105,
			speed = 0.018 + (i % 4) * 0.006,
			phase = (i * 0.37) % 1,
			spin = (if i % 2 == 0 then 1 else -1) * (8 + i * 2),
		})
	end
	-- A dark band on the left keeps the logo and buttons readable.
	Ui.frame({
		Name = "Shade",
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.2,
		Size = UDim2.fromScale(0.62, 1),
		Parent = group,
	}, {
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.7, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Showcase: three fanned cards on the right, gently floating.
	local showcase = Ui.frame({
		Name = "Showcase",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -250, 0.5, 0),
		Size = UDim2.fromOffset(440, 300),
		Parent = group,
	})
	for i, item in SHOWCASE do
		local holder = Ui.frame({
			Name = `Card{i}`,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, item.x, 0.5, item.y),
			Size = UDim2.fromOffset(150, 210),
			Rotation = item.rot,
			ZIndex = if i == 2 then 3 else 2,
			Parent = showcase,
		})
		local face =
			Visuals.portrait(holder, item.id, i == 2, Vector2.new(150, 210), false, if i == 2 then 15 else 1)
		face.AnchorPoint = Vector2.new(0.5, 0.5)
		face.Position = UDim2.fromScale(0.5, 0.5)
	end

	-- Logo (left): gold "1V1" over white "CARD", with a glow.
	local logo = Ui.frame({
		Name = "Logo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 64, 0.27, 0),
		Size = UDim2.fromOffset(420, 190),
		Parent = group,
	})
	Ui.image("egg_glow", {
		ImageColor3 = C.Purple,
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.42, 0.5),
		Size = UDim2.fromScale(1.3, 1.5),
		Parent = logo,
	})
	Ui.display({
		Name = "One",
		Text = "1V1",
		TextSize = 112,
		Rotation = -4,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 112),
		Parent = logo,
	}, true)
	Ui.display({
		Name = "Card",
		Text = "CARD",
		TextSize = 78,
		Rotation = -4,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 100),
		Size = UDim2.new(1, 0, 0, 80),
		Parent = logo,
	})
	local tagline = Ui.text({
		Text = "Collect · Build your deck · Win the arena",
		FontFace = Theme.Face.Title,
		TextSize = 18,
		TextColor3 = C.Pink,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 72, 0.27, 112),
		Size = UDim2.fromOffset(420, 24),
		Parent = group,
	})
	Ui.outline(C.Night, 1.5).Parent = tagline

	-- PLAY (big, gold) and the icon shortcuts under it.
	local buttons = Ui.frame({
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 64, 0.27, 146),
		Size = UDim2.fromOffset(312, 170),
		Parent = group,
	}, { Ui.list(false, 12) })
	local play = Ui.button("PLAY", "primary", actions.play, {
		Name = "Play",
		Size = UDim2.fromOffset(312, 68),
		LayoutOrder = 1,
		TextSize = 32,
	})
	play.label.FontFace = Theme.Face.Display
	local cap = play.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = 38 -- the one big call to action (buttons cap their text at 22)
	end
	play.instance.Parent = buttons
	local row = Ui.frame({
		Name = "Frame",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(312, 72),
		LayoutOrder = 2,
		Parent = buttons,
	}, { Ui.list(true, 8) })
	for i, item in SHORTCUTS do
		local b = tile(item, 72, function()
			actions.open(item.id)
		end)
		b.LayoutOrder = i
		b.Parent = row
	end

	local loading = Ui.text({
		Name = "Loading",
		Text = "Loading your cards…",
		FontFace = Theme.Face.Title,
		TextSize = 20,
		TextColor3 = C.Muted,
		Visible = false,
		Position = UDim2.new(0, 64, 0.27, 160),
		Size = UDim2.fromOffset(300, 30),
		Parent = group,
	})
	Ui.outline(C.Night, 1.5).Parent = loading

	local news = Ui.text({
		Name = "News",
		Text = VERSION,
		FontFace = Theme.Face.Bold,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextWrapped = false,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 64, 1, -18),
		Size = UDim2.fromOffset(500, 18),
		Parent = group,
	})
	Ui.outline(C.Night, 1, 0.4).Parent = news

	-- Motion: rays turn, the sky shifts, card backs drift up, the showcase floats. One loop, only
	-- while the menu is on screen; reduced motion keeps everything still.
	local loop: RBXScriptConnection? = nil
	local function setMotion(on: boolean)
		if loop then
			loop:Disconnect()
			loop = nil
		end
		for _, d in drifters do
			d.img.Visible = on or reduced()
			d.img.Position = UDim2.fromScale(d.x, 1 - d.phase)
		end
		if not on or reduced() then
			return
		end
		local t0 = os.clock()
		loop = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			rays.Rotation = t * 4
			sky.Rotation = 35 + math.sin(t * 0.2) * 8
			showcase.Position = UDim2.new(1, -250, 0.5, math.sin(t * 1.1) * 6)
			for _, d in drifters do
				local y = 1.15 - ((d.phase + t * d.speed) % 1.3)
				d.img.Position = UDim2.fromScale(d.x + math.sin(t * 0.6 + d.phase * 6) * 0.01, y)
				d.img.Rotation = t * d.spin
			end
		end)
	end

	-- PLAY breathes gently so the next step is obvious.
	local pulse: Tween? = nil
	local function setPulse(on: boolean)
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		local scale = play.instance:FindFirstChildOfClass("UIScale")
			or Ui.new("UIScale", { Parent = play.instance })
		scale.Scale = 1
		if on and not reduced() then
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.05 }
			)
			tween:Play()
			pulse = tween
		end
	end

	local menu: Menu = {
		frame = frame,
		setLoading = function(isLoading: boolean)
			loading.Visible = isLoading
			buttons.Visible = not isLoading
			setPulse(not isLoading and frame.Visible)
		end,
		show = function(on: boolean)
			local info = TweenInfo.new(
				if reduced() then 0.01 else 0.35,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			if on then
				frame.Visible = true
				group.GroupTransparency = 1
				TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
				setPulse(buttons.Visible)
				setMotion(true)
			else
				setPulse(false)
				local fade = TweenService:Create(group, info, { GroupTransparency = 1 })
				fade.Completed:Connect(function()
					if group.GroupTransparency >= 0.99 then
						frame.Visible = false
						setMotion(false)
					end
				end)
				fade:Play()
			end
		end,
	}
	return menu
end

return MainMenu
