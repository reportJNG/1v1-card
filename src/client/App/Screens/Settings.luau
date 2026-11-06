--!strict
-- Settings (saved on the server) and how the game works with money: what Robux can and can't buy.
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)

local C = Theme.Color

local OPTIONS = {
	{ key = "music", label = "Music" },
	{ key = "sfx", label = "Sound effects" },
	{ key = "reducedMotion", label = "Reduced motion (skip hatch and result animations)" },
}

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Settings", ctx.close, UDim2.fromOffset(620, 420), "icon_settings")
	local list = Ui.frame({ BackgroundTransparency = 1, Parent = p.body }, { Ui.list(false, 8) })

	local function render()
		local view = ctx.state.view
		Ui.clear(list)
		for i, opt in OPTIONS do
			local on = view.settings[opt.key] == true
			local row = Ui.frame(
				{ Size = UDim2.new(1, 0, 0, 44), LayoutOrder = i, Parent = list },
				{ Ui.corner(8), Ui.pad(8) }
			)
			Ui.text({
				Text = opt.label,
				FontFace = Theme.Face.Bold,
				Size = UDim2.new(1, -120, 1, 0),
				Parent = row,
			})
			local b = Ui.button(if on then "On" else "Off", if on then "success" else "ghost", function()
				ctx.request("Settings.Set", { key = opt.key, value = not on })
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(100, 30),
				Name = opt.key,
			})
			b.instance.Parent = row
		end
		Ui.text({
			Text = "How purchases work\n"
				.. "• Coins are earned by playing and are never sold.\n"
				.. "• Robux can buy eggs from worlds you have unlocked and cosmetics. Every egg shows its exact odds before you buy.\n"
				.. "• Golden eggs are earned only. Gems are earned and buy cosmetics only.\n"
				.. "• Matches have no entry fee and nobody can lose Coins in a match.",
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 120),
			LayoutOrder = 10,
			Parent = list,
		})
	end

	render()
	return { destroy = function() end, refresh = render }
end
