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
	{ key = "reducedMotion", label = "Reduced motion (fewer shakes and bounces)" },
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
		Size = UDim2.fromOffset(260, 30),
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
		Size = UDim2.new(1, -54, 0, 10),
		Parent = holder,
	}, { Ui.corner(5), Ui.stroke(C.Stroke, 1) })
	local fill = Ui.frame({
		Name = "Fill",
		BackgroundColor3 = C.Gold,
		Size = UDim2.fromScale(value / 100, 1),
		Parent = track,
	}, { Ui.corner(5), Ui.gradient(C.GoldHi, C.GoldLo, 90) })
	local knob = Ui.frame({
		Name = "Knob",
		BackgroundColor3 = C.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(value / 100, 0.5),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 2,
		Parent = track,
	}, { Ui.corner(11), Ui.stroke(C.Gold, 3) })
	local readout = Ui.text({
		Text = `{value}%`,
		FontFace = Theme.Face.Number,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(46, 24),
		Parent = holder,
	})
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

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Settings", ctx.close, UDim2.fromOffset(640, 460), "icon_settings")
	local list = Ui.frame({ BackgroundTransparency = 1, Parent = p.body }, { Ui.list(false, 8) })

	local function row(order: number, label: string, control: number): Frame
		local r = Ui.frame(
			{ Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order, Parent = list },
			{ Ui.corner(8), Ui.pad(8) }
		)
		Ui.text({
			Text = label,
			FontFace = Theme.Face.Bold,
			Size = UDim2.new(1, -control - 12, 1, 0),
			Parent = r,
		})
		return r
	end

	local function render()
		local view = ctx.state.view
		Ui.clear(list)
		local order = 0
		for _, opt in SWITCHES do
			order += 1
			local on = view.settings[opt.key] == true
			local r = row(order, opt.label, 100)
			local b = Ui.button(if on then "On" else "Off", if on then "success" else "ghost", function()
				ctx.request("Settings.Set", { key = opt.key, value = not on })
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(100, 30),
				Name = opt.key,
			})
			b.instance.Parent = r
			if opt.key == "music" or opt.key == "sfx" then
				-- the matching volume slider sits right under its switch
				local s = SLIDERS[if opt.key == "music" then 1 else 2]
				order += 1
				local sr = row(order, s.label, 260)
				local value = view.settings[s.key]
				local sl = slider(sr, if typeof(value) == "number" then value else s.default, 1, function(v)
					ctx.request("Settings.Set", { key = s.key, value = v })
				end)
				sl.Name = s.key
			end
		end
		order += 1
		Ui.text({
			Text = "Graphics: open the Roblox menu (Esc) > Settings > Graphics Quality. "
				.. "On older phones, a lower setting keeps the game smooth.",
			TextSize = Theme.Size.small,
			TextColor3 = C.Blue,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = order,
			Parent = list,
		})
		Ui.text({
			Text = "How purchases work\n"
				.. "• Coins are earned by playing and are never sold.\n"
				.. "• Robux can buy eggs from worlds you have unlocked and cosmetics. Every egg shows its exact odds before you buy.\n"
				.. "• Golden eggs are earned only. Gems are earned and buy cosmetics only.\n"
				.. "• Matches have no entry fee and nobody can lose Coins in a match.",
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 96),
			LayoutOrder = order + 1,
			Parent = list,
		})
	end

	render()
	return { destroy = function() end, refresh = render }
end
