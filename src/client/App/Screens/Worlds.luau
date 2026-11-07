--!strict
-- The world picker, opened from the lobby's Worlds portal (or the menu): ten world cards with the
-- world's art, name, the trophies it needs and whether it is unlocked (from highestTrophies, so a
-- world never re-locks) or where the player is now. Travel sends World.Travel; the server checks
-- the unlock again and moves the character to that world's spawn. Locked worlds have no Travel
-- button, and the server refuses them anyway. Guardian Trials start at the trial gate in each
-- world; the card shows whether this world's trial is cleared.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Worlds = require(Shared.Config.Worlds)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local WorldArt = require(Shared.Config.WorldArt)
local Guardians = require(Shared.Config.Guardians)
local Economy = require(Shared.Config.Economy)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)

local C = Theme.Color

local CARD = Vector2.new(146, 178)

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Choose a World", ctx.close, UDim2.fromOffset(800, 470), "icon_worlds")
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
	local grid = Ui.frame(
		{ Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = p.body },
		{
			Ui.new("UIGridLayout", {
				CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
				CellPadding = UDim2.fromOffset(8, 10),
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
	)

	local function art(parent: Instance, worldId: number, unlocked: boolean)
		local theme = WorldLayouts.ByWorld[worldId].theme
		local thumb = Ui.frame({
			Name = "Art",
			BackgroundColor3 = Color3.fromHex(theme.ground),
			Size = UDim2.new(1, 0, 0, 82),
			ClipsDescendants = true,
			Parent = parent,
		}, {
			Ui.corner(10),
			Ui.gradient(Color3.fromHex(theme.accent), Color3.fromHex(theme.ground), 90),
		})
		local image = WorldArt.thumbnails[worldId]
		if image then
			Ui.new("ImageLabel", {
				Name = "Image",
				Image = image,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Crop,
				Size = UDim2.fromScale(1, 1),
				ImageColor3 = if unlocked then C.White else Color3.fromRGB(90, 90, 110),
				Parent = thumb,
			}, { Ui.corner(10) })
		end
		-- Number badge, top-left.
		local badge = Ui.display({
			Text = tostring(worldId),
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(8, 2),
			Size = UDim2.fromOffset(40, 30),
			ZIndex = 3,
			Parent = thumb,
		}, true)
		badge.Name = "Number"
		if not unlocked then
			Ui.frame({
				Name = "Shade",
				BackgroundColor3 = C.Night,
				BackgroundTransparency = 0.35,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				Parent = thumb,
			}, { Ui.corner(10) })
			Ui.icon("icon_lock", 34, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 3,
				Parent = thumb,
			})
		end
	end

	local function render()
		local view = ctx.state.view
		Ui.clear(grid)
		if view == nil then
			return
		end
		local area = ctx.state.area
		home.instance.Visible = area ~= 0 -- already in the lobby: nothing to go back to
		for _, world in Worlds.List do
			local unlocked = view.highestTrophies >= world.trophiesToUnlock
			local here = area == world.id
			local cleared = view.trials[tostring(world.id)] ~= nil
			local card = Ui.frame({
				Name = `World{world.id}`,
				BackgroundColor3 = if unlocked then C.Raised else C.PanelDeep,
				LayoutOrder = world.id,
				Parent = grid,
			}, {
				Ui.corner(12),
				Ui.stroke(
					if here then C.Gold elseif unlocked then C.Purple else C.Stroke,
					if here then 3 else 1.5
				),
				Ui.pad(6),
			})
			card:SetAttribute("Unlocked", unlocked)
			local content = Ui.frame(
				{ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = card },
				{ Ui.list(false, 3, Enum.HorizontalAlignment.Center) }
			)
			local artHolder = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 82),
				LayoutOrder = 1,
				Parent = content,
			})
			art(artHolder, world.id, unlocked)
			if cleared then
				-- Completed: the world's Guardian Trial is cleared.
				Ui.icon("icon_check", 30, {
					Name = "Completed",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 4),
					ZIndex = 4,
					Parent = artHolder,
				})
			end
			local name = Ui.text({
				Name = "WorldName",
				Text = world.displayName,
				FontFace = Theme.Face.Title,
				TextSize = 15,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if unlocked then C.Text else C.Muted,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 2,
				Parent = content,
			})
			Ui.fit(name, 15, 10)
			local status = Ui.text({
				Name = "Status",
				Text = if here
					then "You are here"
					elseif unlocked then (if cleared
						then "Unlocked · Trial cleared"
						else `Trial: +{Economy.Trials.trophyGrant} trophies`)
					else `{Format.number(world.trophiesToUnlock)} trophies to unlock`,
				TextSize = 12,
				TextWrapped = false,
				TextColor3 = if here then C.Gold elseif unlocked then C.Green else C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 3,
				Parent = content,
			})
			Ui.fit(status, 12, 8)
			local guardian = Ui.text({
				Name = "Guardian",
				Text = `Guardian: {Guardians.ByWorld[world.id].displayName}`,
				TextSize = 11,
				TextWrapped = false,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 4,
				Parent = content,
			})
			Ui.fit(guardian, 11, 8)
			local go = Ui.button(
				if here then "Here" elseif unlocked then "Travel" else "Locked",
				"secondary",
				function()
					if not unlocked or here then
						return
					end
					local reply = ctx.request("World.Travel", { worldId = world.id })
					if reply.ok then
						ctx.close()
					end
				end,
				{ Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 5, Name = "Travel" }
			)
			go.setEnabled(unlocked and not here)
			go.instance.Parent = content
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
