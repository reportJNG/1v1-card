--!strict
-- Settings, saved on the server (Settings.Set): music and sound-effect switches and volume
-- sliders, reduced motion, a graphics hint, and how the game works with money (what Robux can
-- and can't buy).
local UserInputService = game:GetService("UserInputService")
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)

local C = Theme.Color

local SWITCHES = {
	{ key = "music", label = "Music" },
	{ key = "sfx", label = "Sound effects" },
	{ key = "reducedMotion", label = "Reduced motion" },
}

local SLIDERS = {
	{ key = "musicVolume", label = "Music volume", default = 80 },
	{ key = "sfxVolume", label = "Effects volume", default = 100 },
}

-- A 0-100 slider: drag (mouse or touch) or click anywhere on the track. `onRelease` gets the final
-- value; nothing is sent while dragging.
local function slider(parent: Instance, value: number, order: number, onRelease: (number) -> ()): Frame
	local holder = Ui.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(300, 40),
		LayoutOrder = order,
		Parent = parent,
	})
	local track: TextButton = Ui.new("TextButton", {
		Name = "Track",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.PanelDeep,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, -90, 0, 16),
		Parent = holder,
	}, { Ui.corner(8), Ui.stroke(C.Night, 2) })
	local fill = Ui.frame({
		Name = "Fill",
		BackgroundColor3 = C.Gold,
		Size = UDim2.fromScale(value / 100, 1),
		Parent = track,
	}, { Ui.corner(8), Ui.gradient(C.GoldHi, C.GoldLo, 90) })
	local knob = Ui.frame({
		Name = "Knob",
		BackgroundColor3 = C.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value / 100, 0.5),
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 2,
		Parent = track,
	}, { Ui.corner(16), Ui.stroke(C.Gold, 4) })
	local readout = Ui.display({
		Text = `{value}%`,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(62, 28),
		Parent = holder,
	})
	readout.TextColor3 = C.White
	Ui.outline(C.Night, 2).Parent = readout
	local current = value
	local dragging = false
	local function setFrom(x: number)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		current = math.floor(rel * 20 + 0.5) * 5 -- steps of 5%
		fill.Size = UDim2.fromScale(current / 100, 1)
		knob.Position = UDim2.fromScale(current / 100, 0.5)
		readout.Text = `{current}%`
	end
	track.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	local moved = UserInputService.InputChanged:Connect(function(input: InputObject)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch) then
			setFrom(input.Position.X)
		end
	end)
	local ended = UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if dragging and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
			dragging = false
			onRelease(current)
		end
	end)
	holder.Destroying:Connect(function()
		moved:Disconnect()
		ended:Disconnect()
	end)
	return holder
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = Theme.Face.Display
end

local ICONS: { [string]: string } =
	{ music = "icon_energy", sfx = "icon_energy", reducedMotion = "icon_settings" }

local VERSION = "v0.5 · ten worlds · original characters"

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "SETTINGS", ctx.close, UDim2.fromOffset(680, 470), "icon_settings")
	local tab = "Sound"
	local tabs = Ui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = p.body })
	local list = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		Parent = p.body,
	}, { Ui.list(false, 10) })

	local render: () -> ()

	local function row(order: number, icon: string, label: string, control: number): Frame
		local r = Ui.glowTile("Frame", {
			Size = UDim2.new(1, 0, 0, 58),
			LayoutOrder = order,
			Parent = list,
		}, C.Purple, false)
		Ui.icon(icon, 40, { Position = UDim2.new(0, 34, 0.5, 0), ZIndex = 2, Parent = r })
		local t = Ui.text({
			Text = label,
			FontFace = Theme.Face.Title,
			TextSize = 22,
			TextWrapped = false,
			Position = UDim2.fromOffset(72, 0),
			Size = UDim2.new(1, -control - 90, 1, 0),
			ZIndex = 2,
			Parent = r,
		})
		Ui.outline(C.Night, 2).Parent = t
		Ui.fit(t, 22, 14)
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 12), Parent = r })
		return r
	end

	-- A block of explanation (only the INFO tab has sentences, as settings may).
	local function info(order: number, icon: string, title: string, body: string, height: number)
		local box = Ui.glowTile("Frame", {
			Size = UDim2.new(1, 0, 0, height),
			LayoutOrder = order,
			Parent = list,
		}, C.Blue, false)
		Ui.icon(icon, 34, { Position = UDim2.fromOffset(28, 24), ZIndex = 2, Parent = box })
		local h = Ui.display({
			Text = title,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(52, 8),
			Size = UDim2.new(1, -60, 0, 30),
			ZIndex = 2,
			Parent = box,
		})
		h.TextColor3 = C.White
		Ui.outline(C.Night, 2).Parent = h
		local t = Ui.text({
			Text = body,
			FontFace = Theme.Face.Bold,
			TextSize = 17,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(16, 40),
			Size = UDim2.new(1, -28, 1, -46),
			ZIndex = 2,
			Parent = box,
		})
		Ui.fit(t, 17, 11)
	end

	local function renderSound(view: any)
		local order = 0
		for _, opt in SWITCHES do
			order += 1
			local on = view.settings[opt.key] == true
			local r = row(order, ICONS[opt.key], opt.label, 110)
			local b = Ui.button(if on then "ON" else "OFF", if on then "success" else "tab", function()
				ctx.request("Settings.Set", { key = opt.key, value = not on })
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(110, 42),
				Name = opt.key,
				ZIndex = 2,
			})
			bigLabel(b, 24)
			b.instance.Parent = r
			if opt.key == "music" or opt.key == "sfx" then
				local sdef = SLIDERS[if opt.key == "music" then 1 else 2]
				order += 1
				local sr = row(order, ICONS[opt.key], sdef.label, 300)
				local value = view.settings[sdef.key]
				local sl = slider(
					sr,
					if typeof(value) == "number" then value else sdef.default,
					1,
					function(v)
						ctx.request("Settings.Set", { key = sdef.key, value = v })
					end
				)
				sl.Name = sdef.key
				sl.ZIndex = 2
			end
		end
	end

	local function renderInfo()
		info(
			1,
			"icon_coin",
			"HOW PURCHASES WORK",
			"• Coins are earned by playing and are never sold.\n"
				.. "• Robux buys eggs from worlds you have unlocked, and cosmetics. Every egg shows its exact odds first.\n"
				.. "• Golden eggs are earned only. Gems are earned and buy cosmetics only.\n"
				.. "• Matches have no entry fee; nobody can lose Coins in a match.",
			150
		)
		info(
			2,
			"icon_settings",
			"GRAPHICS",
			"Roblox menu (Esc) > Settings > Graphics Quality. A lower setting keeps older phones smooth.",
			80
		)
		info(
			3,
			"icon_trophy",
			"CREDITS",
			"Eggs and HUD icons: Eggs Icon Pack v2 and Free Icon Pack by @gvesster, used unedited. "
				.. "Fonts: Luckiest Guy (Apache 2.0), Titan One (OFL), Builder Sans (Roblox). "
				.. `Music and sounds: APM Music and ProSoundEffects (Roblox Creator Store). {VERSION}`,
			110
		)
	end

	render = function()
		local view = ctx.state.view
		Ui.clear(tabs)
		for i, t in { { "Sound", "SOUND" }, { "Info", "INFO" } } do
			local b = Ui.button(t[2], if tab == t[1] then "purple" else "tab", function()
				tab = t[1]
				Ui.sound("tick")
				render()
			end, {
				Name = `Tab{t[1]}`,
				Position = UDim2.fromOffset((i - 1) * 140, 0),
				Size = UDim2.fromOffset(130, 40),
			})
			bigLabel(b, 22)
			b.instance.Parent = tabs
		end
		Ui.clear(list)
		Ui.list(false, 10).Parent = list
		if tab == "Sound" then
			renderSound(view)
		else
			renderInfo()
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
