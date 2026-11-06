--!strict
-- The 10 worlds: unlock trophies, travel, Guardian Trial status and challenge.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local Guardians = require(Shared.Config.Guardians)
local Economy = require(Shared.Config.Economy)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)

local C = Theme.Color

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Worlds", ctx.close, UDim2.fromOffset(770, 420), "icon_worlds")
	local home = Ui.button("Back to Hub", "secondary", function()
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
	local strip = Ui.scroll({
		Size = UDim2.fromScale(1, 1),
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		Parent = p.body,
	})
	Ui.list(true, 8).Parent = strip

	local function render()
		local view = ctx.state.view
		Ui.clear(strip)
		for _, world in Worlds.List do
			local unlocked = view.highestTrophies >= world.trophiesToUnlock
			local here = view.currentWorld == world.id
			local cleared = view.trials[tostring(world.id)] ~= nil
			local theme = WorldLayouts.ByWorld[world.id].theme
			local card = Ui.frame({
				BackgroundColor3 = if unlocked
					then Color3.fromHex(theme.ground):Lerp(C.Panel, 0.6)
					else C.Raised,
				Size = UDim2.fromOffset(150, 330),
				LayoutOrder = world.id,
				Name = `World{world.id}`,
				Parent = strip,
			}, {
				Ui.corner(12),
				Ui.stroke(
					if here then C.Gold elseif unlocked then C.Green else C.Stroke,
					if here then 3 else 1.5
				),
				Ui.gradient(Color3.new(1, 1, 1), Color3.new(0.55, 0.55, 0.65), 90),
				Ui.pad(8),
			})
			local content = Ui.frame(
				{ BackgroundTransparency = 1, Parent = card },
				{ Ui.list(false, 6, Enum.HorizontalAlignment.Center) }
			)
			Ui.text({
				Text = `{if unlocked then "" else "🔒 "}{world.id}`,
				FontFace = Theme.Face.Title,
				TextSize = 28,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 34),
				LayoutOrder = 1,
				Parent = content,
			})
			Ui.text({
				Text = world.displayName,
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 2,
				Parent = content,
			})
			Ui.text({
				Text = if unlocked
					then (if here then "You are here" else "Unlocked")
					else `🏆 {Format.number(world.trophiesToUnlock)} to unlock`,
				TextSize = Theme.Size.small,
				TextColor3 = if unlocked then C.Green else C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 3,
				Parent = content,
			})
			Ui.text({
				Text = `Guardian: {Guardians.ByWorld[world.id].displayName}\n{if cleared
					then "✓ Trial cleared"
					else `First clear: 🏆 +{Economy.Trials.trophyGrant}`}`,
				TextSize = Theme.Size.small,
				TextColor3 = if cleared then C.Green else C.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 52),
				LayoutOrder = 4,
				Parent = content,
			})
			if unlocked and not here then
				local go = Ui.button("Travel", "secondary", function()
					local reply = ctx.request("World.Travel", { worldId = world.id })
					if reply.ok then
						ctx.close()
					end
				end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Name = "Travel" })
				go.instance.Parent = content
			end
			if unlocked then
				local trial = Ui.button("Guardian Trial", "purple", function()
					ctx.request("Trial.Start", { worldId = world.id })
				end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 6, Name = "Trial", TextSize = 14 })
				trial.instance.Parent = content
				local shop = Ui.button("Eggs", "ghost", function()
					ctx.open("Shop", { world = world.id })
				end, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 7, TextSize = 13 })
				shop.instance.Parent = content
			end
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
