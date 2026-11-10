--!strict
-- The merchant (BAD_GUI_2_PANELS.md section 4; target docs/brief/bad-gui/04-merchant-target.png):
-- the template every other panel follows.
--   header   the merchant's name in big type, the live Coins pill, the close button
--   banner   gold: a coin pile, "SELL YOUR HARVEST" in heavy italic (SELL in gold), a short italic
--            subtitle, and a big gold SELL ALL with the total (greyed when there is nothing to sell)
--   cards    one tall card per item in its tier colour (rare = gold, common = blue): a RARE ribbon,
--            the item's own icon (App/ItemIcon) with sparkles, a big italic "xN", a dark name plate,
--            an "N each" price pill and its own sell button; free space shows the empty state
-- The server checks the player is at the merchant and owns the items; a sale pops "+N" over the
-- merchant and flies coins to the Coins pill (App/WorldText). Images are today's kit (TEMP) until the
-- owner's merchant kit sheet and the pieces cut from the target are approved and live.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local WorldLayouts = require(Shared.Config.WorldLayouts)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local ItemIcon = require(App.ItemIcon)

local C = Theme.Color
local F = Theme.Face

local COMMON = Color3.fromHex("#2F8BFF")
local CARD = Vector2.new(160, 236)
local COLS = 4

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = F.Display
end

return function(ctx: any, layer: Frame, arg: any?): any
	-- The merchant in the world (the Sell prompt's part): sale pops appear over its head.
	local source = if typeof(arg) == "table" then arg.source else nil
	local view = ctx.state.view
	local layout = WorldLayouts.ByWorld[view.currentWorld]
	local p = Ui.panel(
		layer,
		string.upper(layout and layout.merchantName or "Merchant"),
		ctx.close,
		UDim2.fromOffset(4 * CARD.X + 3 * 12 + 40, 430),
		"icon_coin"
	)
	-- the live Coins pill in the header
	local coinPill = Ui.pricePill(Format.short(view.coins), "icon_coin", 36, {
		Name = "Coins",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -64, 0.5, 0),
		ZIndex = 3,
		Parent = p.header,
	})
	local coinAmount = coinPill:FindFirstChild("Amount") :: TextLabel
	coinAmount.FontFace = F.Display

	local banner = Ui.glowTile("Frame", {
		Name = "SellBar",
		Size = UDim2.new(1, 0, 0, 84),
		Parent = p.body,
	}, C.Gold, false)
	local grid = Ui.frame({
		Name = "Goods",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 1, -96),
		Parent = p.body,
	})
	local gridLayout = Ui.grid(CARD, 12)
	gridLayout.Parent = grid

	local busy = false
	local page = 1
	local arrows: { any } = {}

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

	local function renderBanner(order: { string }, totals: { [string]: number })
		-- (only the contents: the banner's own gradient and edge are children too)
		for _, c in banner:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local total = 0
		for _, itemId in order do
			total += Items.ById[itemId].sellPrice * totals[itemId]
		end
		-- a coin pile on the left
		for i, at in { { 30, 50, 58 }, { 58, 40, 50 }, { 44, 26, 46 } } do
			Ui.icon("icon_coin", at[3], {
				Name = `Coin{i}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(at[1] + 10, at[2]),
				Rotation = (i - 2) * 14,
				ZIndex = 2 + i,
				Parent = banner,
			})
		end
		local head = Ui.text({
			Name = "Title",
			RichText = true,
			Text = `<font color="#FFC54B">SELL</font> YOUR HARVEST`,
			FontFace = F.Italic,
			TextSize = 34,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(108, 8),
			Size = UDim2.new(1, -330, 0, 40),
			ZIndex = 3,
			Parent = banner,
		})
		head.TextColor3 = C.White
		outline(head, 3)
		Ui.fit(head, 34, 20)
		local sub = Ui.text({
			Name = "Subtitle",
			Text = "Every merchant buys every item.",
			FontFace = F.Italic,
			TextSize = 20,
			TextColor3 = C.White,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(110, 48),
			Size = UDim2.new(1, -330, 0, 24),
			ZIndex = 3,
			Parent = banner,
		})
		outline(sub, 2)
		Ui.fit(sub, 20, 14)
		local all = Ui.button(
			if total > 0 then `SELL ALL · {Format.short(total)}` else "SELL ALL",
			"primary",
			function()
				if busy then
					return
				end
				busy = true
				local from = Ui.lastPressed
				local coins = 0
				local o, t = holdings()
				for _, itemId in o do
					coins += sell(itemId, t[itemId])
				end
				busy = false
				done(coins, from)
			end,
			{
				Name = "SellAll",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -14, 0.5, 0),
				Size = UDim2.fromOffset(210, 58),
				ZIndex = 3,
			}
		)
		bigLabel(all, 26)
		all.label.Position = UDim2.fromOffset(34, 0)
		all.label.Size = UDim2.new(1, -40, 1, 0)
		Ui.icon("icon_coin", 34, { Position = UDim2.new(0, 26, 0.5, 0), ZIndex = 6, Parent = all.instance })
		all.instance.Parent = banner
		all.setEnabled(total > 0)
	end

	-- One tall item card in its tier colour.
	local function card(itemId: string, n: number, order: number)
		local item = Items.ById[itemId]
		local accent = if item.rare then C.Gold else COMMON
		local t =
			Ui.glowTile("Frame", { Name = itemId, LayoutOrder = order, Parent = grid }, accent, item.rare)
		Ui.image("egg_glow", {
			Name = "Glow",
			ImageColor3 = accent,
			ImageTransparency = 0.35,
			ScaleType = Enum.ScaleType.Stretch,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 72),
			Size = UDim2.fromOffset(130, 100),
			ZIndex = 2,
			Parent = t,
		})
		ItemIcon.new(itemId, 92, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 72),
			ZIndex = 3,
			Parent = t,
		})
		for i, at in { { 0.2, 34 }, { 0.82, 96 } } do -- sparkles
			Ui.image("sparkle", {
				Name = `Sparkle{i}`,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(at[1], 0, 0, at[2]),
				Size = UDim2.fromOffset(18, 18),
				ImageColor3 = C.White,
				ZIndex = 4,
				Parent = t,
			})
		end
		if item.rare then
			local ribbon = Ui.display({
				Name = "Rare",
				Text = "RARE",
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundColor3 = C.GoldLo,
				BackgroundTransparency = 0,
				Position = UDim2.fromOffset(-4, 8),
				Size = UDim2.fromOffset(84, 26),
				ZIndex = 6,
				Parent = t,
			}, true)
			outline(ribbon, 2)
			Ui.corner(6).Parent = ribbon
			Ui.stroke(C.Night, 2).Parent = ribbon
			Ui.new("UIPadding", { PaddingRight = UDim.new(0, 8), Parent = ribbon })
			Ui.icon("icon_trophy", 22, { Position = UDim2.fromOffset(10, 13), ZIndex = 7, Parent = ribbon })
		end
		local count = Ui.text({
			Name = "Count",
			Text = `x{n}`,
			FontFace = F.Italic,
			TextSize = 34,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 92),
			Size = UDim2.fromOffset(80, 36),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 5,
			Parent = t,
		})
		count.TextColor3 = C.White
		Ui.gradient(C.GoldHi, C.Gold).Parent = count
		outline(count, 3)
		local plate = Ui.frame({
			Name = "NamePlate",
			BackgroundColor3 = C.Night,
			BackgroundTransparency = 0.25,
			Position = UDim2.fromOffset(8, 128),
			Size = UDim2.new(1, -16, 0, 30),
			ZIndex = 4,
			Parent = t,
		}, { Ui.corner(8) })
		local name = Ui.text({
			Name = "ItemName",
			Text = item.displayName,
			FontFace = F.Title,
			TextSize = 20,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = plate,
		})
		outline(name, 2)
		Ui.fit(name, 20, 12)
		local each = Ui.pricePill(`{Format.number(item.sellPrice)} each`, "icon_coin", 28, {
			Name = "Each",
			Position = UDim2.new(0.5, 0, 0, 162),
			ZIndex = 5,
			Parent = t,
		});
		(each:FindFirstChild("Amount") :: TextLabel).FontFace = F.Italic
		local b = Ui.button(
			`SELL {Format.short(item.sellPrice * n)}`,
			if item.rare then "primary" else "success",
			function()
				if busy then
					return
				end
				busy = true
				local from = Ui.lastPressed
				local coins = sell(itemId, n)
				busy = false
				done(coins, from)
			end,
			{
				Name = "Sell",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -16, 0, 42),
				ZIndex = 5,
			}
		)
		bigLabel(b, 22)
		b.instance.Parent = t
	end

	-- The empty state: fills the free space beside the cards (or the whole grid).
	local function emptyState(span: number)
		local e = Ui.frame({
			Name = "Empty",
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(span * CARD.X + (span - 1) * 12, CARD.Y),
			Parent = grid,
		})
		Ui.icon("icon_coin", 120, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			ImageTransparency = 0.55,
			ImageColor3 = Color3.fromHex("#8A6BD6"),
			Parent = e,
		})
		local t = Ui.text({
			Text = "Harvest in any world, then sell here",
			FontFace = F.Italic,
			TextSize = 22,
			TextColor3 = Color3.fromHex("#C9B8FF"),
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.new(1, -16, 0, 28),
			Parent = e,
		})
		Ui.fit(t, 22, 14)
	end

	local render: () -> ()
	render = function()
		view = ctx.state.view
		coinAmount.Text = Format.short(view.coins)
		local order, totals = holdings()
		renderBanner(order, totals)
		Ui.clear(grid)
		gridLayout = Ui.grid(CARD, 12)
		gridLayout.Parent = grid
		-- one row of cards fits the panel: more than four items page with arrows at the sides
		local pages = math.max(1, math.ceil(#order / COLS))
		page = math.clamp(page, 1, pages)
		local shown = {}
		for i = (page - 1) * COLS + 1, math.min(#order, page * COLS) do
			table.insert(shown, order[i])
		end
		for i, itemId in shown do
			card(itemId, totals[itemId], i)
		end
		for _, arrow in arrows do
			arrow.instance:Destroy()
		end
		table.clear(arrows)
		if pages > 1 then
			for side = -1, 1, 2 do
				local a = Ui.button(if side < 0 then "◀" else "▶", "secondary", function()
					page += side
					render()
				end, {
					Name = if side < 0 then "Prev" else "Next",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(if side < 0 then 0 else 1, side * 6, 0, 96 + CARD.Y / 2),
					Size = UDim2.fromOffset(44, 64),
					ZIndex = 10,
				})
				bigLabel(a, 28)
				a.setEnabled(if side < 0 then page > 1 else page < pages)
				a.instance.Parent = p.body
				table.insert(arrows, a)
			end
		end
		order = shown
		local used = #order % COLS
		if #order == 0 then
			gridLayout.CellSize = UDim2.fromOffset(COLS * CARD.X + (COLS - 1) * 12, CARD.Y)
			emptyState(COLS)
		elseif used ~= 0 and #order < COLS then
			-- one wide empty state beside a short list (as in the target)
			for k = 1, COLS - used do
				local e = Ui.frame({
					Name = `Free{k}`,
					BackgroundTransparency = 1,
					LayoutOrder = #order + k,
					Parent = grid,
				})
				if k == 1 then
					Ui.icon("icon_coin", 96, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.38),
						ImageTransparency = 0.55,
						ImageColor3 = Color3.fromHex("#8A6BD6"),
						Parent = e,
					})
					local hint = Ui.text({
						Text = "Select an item to sell",
						FontFace = F.Italic,
						TextSize = 20,
						TextColor3 = Color3.fromHex("#C9B8FF"),
						TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.fromScale(0.5, 0.66),
						Size = UDim2.new(1, -8, 0, 48),
						Parent = e,
					})
					hint.TextWrapped = true
				end
			end
		end
	end

	render()
	Ui.stagger(grid, ctx.reducedMotion())
	-- the pill counts up when coins change (the sale fly-in lands on the HUD pill too)
	local last = view.coins
	local conn = ctx.state.changed:connect(function(what: string)
		if what == "profile" and ctx.state.view and ctx.state.view.coins ~= last then
			last = ctx.state.view.coins
			if not ctx.reducedMotion() then
				local s = coinPill:FindFirstChildOfClass("UIScale")
					or Ui.new("UIScale", { Parent = coinPill })
				s.Scale = 1.15
				TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end
	end)
	return { destroy = conn, refresh = render }
end
