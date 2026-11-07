--!strict
-- A short info panel opened by the HUD's "+" buttons. Coins and Gems are earned, never sold
-- (CLAUDE.md), so "+" explains where they come from instead of opening a store.
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)

local C = Theme.Color

local TIPS: { [string]: { title: string, icon: string, lines: { string }, go: { label: string, screen: string }? } } =
	{
		coins = {
			title = "How to earn Coins",
			icon = "icon_coin",
			lines = {
				"Win ranked battles in the 1v1 Arena: the game pays the purse.",
				"Harvest resources in the worlds and sell them to the merchant.",
				"Finish daily quests and claim your 7-day streak.",
				"Coins are never sold for Robux.",
			},
			go = { label = "Go to Worlds", screen = "Worlds" },
		},
		gems = {
			title = "What Gems are for",
			icon = "icon_gem",
			lines = {
				"Earn Gems from achievements, Guardian Trials and the day-7 streak reward.",
				"Gems only buy cosmetics, never cards or eggs. The cosmetics shop opens in a later update.",
				"Gems are never sold for Robux.",
			},
			go = { label = "See Quests", screen = "Quests" },
		},
	}

return function(ctx: any, layer: Frame, arg: any?): any
	local tip = TIPS[if arg and arg.kind then arg.kind else "coins"] or TIPS.coins
	local p = Ui.panel(layer, tip.title, ctx.close, UDim2.fromOffset(460, 300), tip.icon)
	local list = Ui.frame({
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -54),
		Parent = p.body,
	}, { Ui.list(false, 8) })
	for i, line in tip.lines do
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = i,
			Parent = list,
		})
		Ui.frame({
			BackgroundColor3 = C.Gold,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(2, 9),
			Size = UDim2.fromOffset(7, 7),
			Parent = row,
		}, { Ui.corner(4) })
		Ui.text({
			Text = line,
			TextSize = 14,
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(1, -16, 1, 0),
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
	end
	if tip.go then
		local go = tip.go
		local b = Ui.button(go.label, "primary", function()
			ctx.open(go.screen)
		end, {
			Name = "Go",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(220, 42),
		})
		b.instance.Parent = p.body
	end
	return { destroy = function() end }
end
