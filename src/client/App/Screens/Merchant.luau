--!strict
-- The merchant: sell farmed items for Coins at the configured price. The server checks the
-- player is standing at the merchant and owns the items. Layout (owner step 3): a gold "sell
-- everything" bar with the total, then one glow tile per item (rare resources in gold) with its
-- count, price each and its own sell button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local ItemIcon = require(App.ItemIcon)

local C = Theme.Color

local COMMON_ACCENT = Color3.fromHex("#2FD6E0")

return function(ctx: any, layer: Frame, arg: any?): any
	-- The merchant in the world (the Sell prompt's part): sale pops appear over its head.
	local source = if typeof(arg) == "table" then arg.source else nil
	local view = ctx.state.view
	local layout = WorldLayouts.ByWorld[view.currentWorld]
	local p = Ui.panel(
		layer,
		layout and layout.merchantName or "Merchant",
		ctx.close,
		UDim2.fromOffset(640, 440),
		"icon_shop"
	)
	local bar = Ui.glowTile("Frame", {
		Name = "SellBar",
		Size = UDim2.new(1, 0, 0, 64),
		Parent = p.body,
	}, C.Gold, false)
	local grid = Ui.scroll({
		Name = "Goods",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -74),
		Parent = p.body,
	})
	local gridLayout = Ui.grid(Vector2.new(136, 178), 10)
	gridLayout.Parent = grid
	Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4),
		Parent = grid,
	})

	local busy = false

	-- Items the player holds, summed over stacks, in first-seen order.
	local function holdings(): ({ string }, { [string]: number })
		local totals: { [string]: number } = {}
		local order: { string } = {}
		for _, stack in view.items.stacks do
			if totals[stack.itemId] == nil then
				table.insert(order, stack.itemId)
			end
			totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count
		end
		return order, totals
	end

	local function sell(itemId: string, count: number): number
		local reply =
			ctx.request("Merchant.SellItem", { itemId = itemId, count = count, requestId = ctx.guid() })
		if reply.ok then
			return reply.value
		end
		return 0
	end

	-- A sale: "+N" with a coin over the merchant, a "THANKS!" from them, coins flying from the
	-- pressed button to the Coins bar (BAD_GUI_THINKING_AND_UI section 3).
	local function done(coins: number, from: GuiObject?)
		if coins <= 0 then
			return
		end
		Ui.sound("purchase")
		if source then
			ctx.popAt(
				source,
				{ text = `+{Format.number(coins)}`, icon = "icon_coin", tone = "gold", size = 40 }
			)
			task.delay(0.35, function()
				ctx.popAt(
					source.Position + Vector3.new(0, 4, 0),
					{ text = "THANKS!", tone = "white", size = 26 }
				)
			end)
		else
			ctx.near(from, { text = `+{Format.number(coins)}`, icon = "icon_coin", tone = "gold" })
		end
		ctx.fly(from, "coins", { icon = "icon_coin", count = math.clamp(coins // 20 + 2, 3, 6) })
	end

	local function renderBar(order: { string }, totals: { [string]: number })
		for _, c in bar:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local total = 0
		for _, itemId in order do
			total += Items.ById[itemId].sellPrice * totals[itemId]
		end
		Ui.icon("icon_coin", 46, { Position = UDim2.new(0, 12, 0.5, 0), ZIndex = 2, Parent = bar })
		Ui.display({
			Text = "Sell your harvest",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(68, 8),
			Size = UDim2.new(0.5, 0, 0, 26),
			ZIndex = 2,
			Parent = bar,
		})
		Ui.text({
			Text = "Every merchant buys every item.",
			TextSize = 13,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(68, 36),
			Size = UDim2.new(0.5, 0, 0, 16),
			ZIndex = 2,
			Parent = bar,
		})
		if total > 0 then
			Ui.pricePill(Format.number(total), "icon_coin", 30, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -196, 0.5, 0),
				ZIndex = 2,
				Parent = bar,
			})
		end
		local all = Ui.button("Sell all", "primary", function()
			if busy then
				return
			end
			busy = true
			local coins = 0
			local o, t = holdings()
			for _, itemId in o do
				coins += sell(itemId, t[itemId])
			end
			busy = false
			done(coins, Ui.lastPressed)
		end, {
			Name = "SellAll",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 46),
			ZIndex = 2,
		})
		all.instance.Parent = bar
		all.setEnabled(total > 0)
	end

	local function tile(itemId: string, n: number, order: number)
		local item = Items.ById[itemId]
		local accent = if item.rare then C.Gold else COMMON_ACCENT
		local t = Ui.glowTile("Frame", { Name = itemId, LayoutOrder = order, Parent = grid }, accent, false)
		Ui.image("egg_glow", {
			Name = "Glow",
			ImageColor3 = accent,
			ImageTransparency = 0.45,
			ScaleType = Enum.ScaleType.Stretch,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 40),
			Size = UDim2.fromOffset(96, 76),
			ZIndex = 2,
			Parent = t,
		})
		ItemIcon.new(itemId, 64, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 40),
			ZIndex = 3,
			Parent = t,
		})
		if item.rare then
			local tag = Ui.frame({
				Name = "Rare",
				BackgroundColor3 = C.White,
				Position = UDim2.fromOffset(6, 6),
				Size = UDim2.fromOffset(46, 18),
				ZIndex = 4,
				Parent = t,
			}, {
				Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
				Ui.stroke(C.Night, 1.5),
				Ui.gradient(C.GoldHi, C.GoldLo),
			})
			Ui.display({
				Text = "RARE",
				TextSize = 12,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
				Parent = tag,
			})
		end
		Ui.display({
			Name = "Count",
			Text = `×{n}`,
			TextSize = 20,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 52),
			Size = UDim2.fromOffset(60, 22),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 4,
			Parent = t,
		}, true)
		local name = Ui.text({
			Name = "ItemName",
			Text = item.displayName,
			FontFace = Theme.Face.Title,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(4, 80),
			Size = UDim2.new(1, -8, 0, 20),
			ZIndex = 3,
			Parent = t,
		})
		Ui.outline(C.Night, 1.5).Parent = name
		Ui.fit(name, 15, 9)
		Ui.pricePill(`{Format.number(item.sellPrice)} each`, "icon_coin", 20, {
			Position = UDim2.new(0.5, 0, 0, 104),
			ZIndex = 3,
			Parent = t,
		})
		local b = Ui.button(`Sell {Format.number(item.sellPrice * n)}`, "success", function()
			if busy then
				return
			end
			busy = true
			local from = Ui.lastPressed
			local coins = sell(itemId, n)
			busy = false
			done(coins, from)
		end, {
			Name = "Sell",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, -16, 0, 34),
			ZIndex = 3,
		})
		b.instance.Parent = t
	end

	local function render()
		view = ctx.state.view
		local order, totals = holdings()
		renderBar(order, totals)
		Ui.clear(grid)
		for i, itemId in order do
			tile(itemId, totals[itemId], i)
		end
		if #order == 0 then
			local empty =
				Ui.frame({ Name = "Empty", BackgroundTransparency = 1, Size = UDim2.fromOffset(600, 170) })
			empty.Parent = grid
			gridLayout.CellSize = UDim2.fromOffset(600, 170)
			Ui.icon("icon_coin", 72, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 12),
				ImageTransparency = 0.4,
				Parent = empty,
			})
			Ui.display({
				Text = "Nothing to sell yet",
				TextSize = 24,
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 28),
				Parent = empty,
			})
			Ui.text({
				Text = "Harvest the glowing nodes in any world, then come back here.",
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 126),
				Size = UDim2.new(1, 0, 0, 20),
				Parent = empty,
			})
		else
			gridLayout.CellSize = UDim2.fromOffset(136, 178)
		end
	end

	render()
	Ui.stagger(grid, ctx.reducedMotion())
	return { destroy = function() end, refresh = render }
end
