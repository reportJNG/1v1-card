--!strict
-- The merchant: sell farmed items for Coins at the configured price. The server checks the
-- player is standing at the merchant and owns the items.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)

local C = Theme.Color

return function(ctx: any, layer: Frame, _arg: any?): any
	local view = ctx.state.view
	local layout = WorldLayouts.ByWorld[view.currentWorld]
	local p =
		Ui.panel(layer, layout and layout.merchantName or "Merchant", ctx.close, UDim2.fromOffset(560, 420))
	local list = Ui.scroll({ Parent = p.body })
	Ui.list(false, 6).Parent = list

	local function render()
		view = ctx.state.view
		Ui.clear(list)
		local totals: { [string]: number } = {}
		local order: { string } = {}
		for _, stack in view.items.stacks do
			if totals[stack.itemId] == nil then
				table.insert(order, stack.itemId)
			end
			totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count
		end
		for i, itemId in order do
			local item = Items.ById[itemId]
			local n = totals[itemId]
			local row = Ui.frame(
				{ Size = UDim2.new(1, -8, 0, 46), LayoutOrder = i, Parent = list },
				{ Ui.corner(8), Ui.pad(8) }
			)
			Ui.text({
				Text = `{item.displayName} ×{n}`,
				FontFace = Theme.Face.Bold,
				Size = UDim2.fromScale(0.5, 1),
				Parent = row,
			})
			local all = Ui.button(
				`Sell all · 💰 {Format.number(item.sellPrice * n)}`,
				"primary",
				function()
					local reply = ctx.request(
						"Merchant.SellItem",
						{ itemId = itemId, count = n, requestId = ctx.guid() }
					)
					if reply.ok then
						ctx.toast(`Sold for 💰 {Format.number(reply.value)}`, "good")
					end
				end,
				{
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(200, 32),
					TextSize = 13,
				}
			)
			all.instance.Parent = row
		end
		if #order == 0 then
			Ui.text({
				Text = "Nothing to sell. Harvest resource nodes first.",
				TextColor3 = C.Muted,
				Parent = list,
			})
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
