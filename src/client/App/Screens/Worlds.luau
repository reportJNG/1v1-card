--!strict
-- The world picker (`hd-07`), opened from the lobby's Worlds portal or the HUD: one strip of ten
-- tall world cards with the world's art, big number and name; locked worlds are darkened with a
-- lock and their trophy requirement, cleared worlds have a green "Completed" tick, and the current
-- world is highlighted (unlock state from highestTrophies, so a world never re-locks). Travel sends World.Travel; the server checks
-- the unlock again and moves the character to that world's spawn. Locked worlds have no Travel
-- button, and the server refuses them anyway. Guardian Trials start at the trial gate in each
-- world; the card shows whether this world's trial is cleared.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local WorldArt = require(Shared.Config.WorldArt)
local Guardians = require(Shared.Config.Guardians)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Kit = require(App.Kit)

local C = Theme.Color

local CARD = Vector2.new(77, 240)

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Worlds", ctx.close, UDim2.fromOffset(860, 400), "icon_worlds")
	Ui.subtitle(p, "Earn trophies to unlock new worlds")
	local home = Ui.button("Back to Lobby", "secondary", function()
		local reply = ctx.request("World.Hub")
		if reply.ok then
			ctx.close()
		end
	end, {
		Name = "Hub",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
	})
	home.instance.Parent = p.header
	-- One strip of tall world cards (`hd-07`), scrolling sideways on narrow screens.
	local strip = Ui.new("ScrollingFrame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Size = UDim2.new(1, 0, 0, CARD.Y + 40),
		Parent = p.body,
	}, { Ui.list(true, 6), Ui.pad(2) })
	local detail = Ui.text({
		Name = "Detail",
		Text = "",
		FontFace = Theme.Face.Bold,
		TextSize = 13,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = p.body,
	})

	local function render()
		local view = ctx.state.view
		Ui.clear(strip)
		Ui.list(true, 6).Parent = strip
		Ui.pad(2).Parent = strip
		if view == nil then
			return
		end
		local area = ctx.state.area
		home.instance.Visible = area ~= 0
		detail.Text = if area == 0
			then "Tap a world to travel. Guardian Trials start at the trial gate in each world."
			else `You are in World {area}. Guardian Trials start at its trial gate.`
		for _, world in Worlds.List do
			local unlocked = view.highestTrophies >= world.trophiesToUnlock
			local here = area == world.id
			local cleared = view.trials[tostring(world.id)] ~= nil
			local theme = WorldLayouts.ByWorld[world.id].theme
			local col = Ui.frame({
				Name = `World{world.id}`,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(CARD.X, CARD.Y + 34),
				LayoutOrder = world.id,
				Parent = strip,
			})
			col:SetAttribute("Unlocked", unlocked)
			local card: TextButton = Ui.new("TextButton", {
				Name = "Card",
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.fromHex(theme.ground),
				Size = UDim2.fromOffset(CARD.X, CARD.Y),
				ClipsDescendants = true,
				Parent = col,
			}, {
				Ui.corner(10),
				Ui.stroke(
					if here
						then C.GoldHi
						elseif cleared then C.Green
						elseif unlocked then Color3.fromHex(theme.accent)
						else C.Stroke,
					if here then 3 else 2,
					0
				),
				Ui.gradient(Color3.fromHex(theme.accent), Color3.fromHex(theme.ground), 90),
			})
			local image = WorldArt.thumbnails[world.id]
			if image then
				Ui.new("ImageLabel", {
					Name = "Image",
					Image = image,
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Crop,
					Size = UDim2.fromScale(1, 0.72),
					ImageColor3 = if unlocked then C.White else Color3.fromRGB(70, 60, 100),
					Parent = card,
				})
			end
			-- A fade to night under the number and name.
			Ui.frame({
				BackgroundColor3 = C.Night,
				Position = UDim2.fromScale(0, 0.4),
				Size = UDim2.fromScale(1, 0.6),
				ZIndex = 2,
				Parent = card,
			}, {
				Ui.new("UIGradient", {
					Rotation = 90,
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.45, 0.25),
						NumberSequenceKeypoint.new(1, 0.1),
					}),
				}),
			})
			local number = Ui.display({
				Name = "Number",
				Text = tostring(world.id),
				TextSize = 38,
				TextColor3 = if unlocked then C.GoldHi else C.Muted,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.new(1, 0, 0, 36),
				ZIndex = 3,
				Parent = card,
			})
			number.TextXAlignment = Enum.TextXAlignment.Center
			local name = Ui.text({
				Name = "WorldName",
				Text = world.displayName,
				FontFace = Theme.Face.Title,
				TextSize = 15,
				TextColor3 = if unlocked then C.White else C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Top,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.73),
				Size = UDim2.new(1, -6, 0, 40),
				ZIndex = 3,
				Parent = card,
			})
			name.TextWrapped = true
			Ui.outline(C.Night, 1.5).Parent = name
			if not unlocked then
				Kit.image("lock_overlay", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.32),
					Size = UDim2.fromOffset(46, 46),
					ZIndex = 4,
					Parent = card,
				})
			end
			if cleared then
				Ui.icon("icon_check", 26, {
					Name = "Completed",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 4),
					ZIndex = 4,
					Parent = card,
				})
			end
			if here then
				local tag = Ui.text({
					Text = "HERE",
					FontFace = Theme.Face.Title,
					TextSize = 11,
					TextColor3 = C.GoldInk,
					TextXAlignment = Enum.TextXAlignment.Center,
					BackgroundColor3 = C.GoldHi,
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.fromOffset(42, 16),
					ZIndex = 5,
					Parent = card,
				})
				Ui.corner(5).Parent = tag
			end
			-- The status chip below: Completed, trophies needed, or Travel.
			local status = Ui.text({
				Name = "Status",
				Text = if here
					then "You are here"
					elseif cleared then "    Done"
					elseif unlocked then "Travel"
					else `    {Format.short(world.trophiesToUnlock)}`,
				FontFace = Theme.Face.Bold,
				TextSize = 13,
				TextColor3 = if cleared then C.Green elseif unlocked then C.White else C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundColor3 = if unlocked and not here
					then Color3.fromHex("#3A2580")
					else Color3.fromHex("#140F30"),
				Position = UDim2.fromOffset(0, CARD.Y + 6),
				Size = UDim2.fromOffset(CARD.X, 24),
				Parent = col,
			})
			Ui.corner(8).Parent = status
			if cleared and not here then
				Ui.icon("icon_check", 16, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 3, 0.5, 0),
					Parent = status,
				})
			end
			if not unlocked then
				Ui.icon("icon_trophy", 16, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 3, 0.5, 0),
					Parent = status,
				})
			end
			card:SetAttribute("Guardian", Guardians.ByWorld[world.id].displayName)
			Ui.juice(card)
			card.Activated:Connect(function()
				if not unlocked then
					Ui.sound("error")
					ctx.toast(`World {world.id} unlocks at {Format.number(world.trophiesToUnlock)} trophies.`)
					return
				end
				if here then
					return
				end
				Ui.sound("click")
				local reply = ctx.request("World.Travel", { worldId = world.id })
				if reply.ok then
					ctx.close()
				end
			end)
		end
	end

	render()
	Ui.stagger(strip, ctx.reducedMotion())
	return { destroy = function() end, refresh = render }
end
