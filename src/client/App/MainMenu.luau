--!strict
-- The main menu (POLISH_MISSION B): the first thing a player sees, a separate screen over the
-- lobby's cinematic camera shot (App/UiEffects drifts the camera, blurs and grades it). The 1v1
-- CARD logo, PLAY, Collection, Shop and Settings, and a news/version line. While the profile is
-- still loading it shows a loading line instead of the buttons. PLAY flies the camera in to the
-- character and the HUD slides in; the HUD's Menu button comes back here.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local C = Theme.Color

local MainMenu = {}

export type Menu = {
	frame: Frame,
	setLoading: (loading: boolean) -> (),
	show: (on: boolean) -> (),
}

local VERSION = "v0.3 · Ten worlds to explore, brighter cards"

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
	-- A soft vignette so the logo and buttons stay readable over any part of the lobby.
	Ui.frame({
		Name = "Vignette",
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromScale(1, 1),
		Parent = group,
	}, {
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.45, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Logo (left-centre): the display face, gold "1V1" over white "CARD", with a glow.
	local logo = Ui.frame({
		Name = "Logo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 64, 0.3, 0),
		Size = UDim2.fromOffset(420, 190),
		Parent = group,
	})
	Ui.image("egg_glow", {
		ImageColor3 = C.Purple,
		ImageTransparency = 0.45,
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
		Position = UDim2.new(0, 72, 0.3, 112),
		Size = UDim2.fromOffset(420, 24),
		Parent = group,
	})
	Ui.outline(C.Night, 1.5).Parent = tagline

	-- Buttons (left, under the logo): PLAY big and gold, the rest secondary.
	local buttons = Ui.frame({
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 64, 0.3, 150),
		Size = UDim2.fromOffset(300, 220),
		Parent = group,
	}, { Ui.list(false, 10) })
	local play = Ui.button("PLAY", "primary", actions.play, {
		Name = "Play",
		Size = UDim2.fromOffset(300, 64),
		LayoutOrder = 1,
		TextSize = 30,
	})
	play.label.FontFace = Theme.Face.Display
	local cap = play.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = 36 -- the one big call to action (buttons cap their text at 22)
	end
	play.instance.Parent = buttons
	local row = Ui.frame({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 44),
		LayoutOrder = 2,
		Parent = buttons,
	}, { Ui.list(true, 8) })
	for i, item in { { "Collection", "Cards" }, { "Shop", "Shop" }, { "Settings", "Settings" } } do
		local b = Ui.button(item[2], "secondary", function()
			actions.open(item[1])
		end, { Name = item[1], Size = UDim2.fromOffset(94, 44), LayoutOrder = i, TextSize = 15 })
		b.instance.Parent = row
	end

	local loading = Ui.text({
		Name = "Loading",
		Text = "Loading your cards…",
		FontFace = Theme.Face.Title,
		TextSize = 20,
		TextColor3 = C.Muted,
		Visible = false,
		Position = UDim2.new(0, 64, 0.3, 160),
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
				if reduced() then 0.01 else 0.3,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			if on then
				frame.Visible = true
				group.GroupTransparency = 1
				TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
				setPulse(buttons.Visible)
			else
				setPulse(false)
				local fade = TweenService:Create(group, info, { GroupTransparency = 1 })
				fade.Completed:Connect(function()
					if group.GroupTransparency >= 0.99 then
						frame.Visible = false
					end
				end)
				fade:Play()
			end
		end,
	}
	return menu
end

return MainMenu
