--!strict
-- Inventory (BAD_GUI_9 sections 3 and 4): the bag, opened by the HUD's bag button. Items and eggs
-- only; cards live in the Cards screen, so this screen never shows card stats.
--   header   the bag icon, a big INVENTORY title, search, and the bag slots (used / slots) with a gold
--            "+" that buys another slot
--   tabs     ALL, ITEMS, EGGS: an icon with a big outlined word under it and a count badge on the
--            corner
--   grid     item tiles (icon, "xN", name, price) and egg tiles (egg, name, OPEN), paged
--   inspect  only while something is selected (otherwise the grid fills the space):
--            an item: its icon on a tier tile, the name, "xN", the price each, a quantity picker and
--            a painted SELL, and one "SOLD AT" line; an egg: the egg, its name, "xN" and OPEN
-- Selling and opening are requests: the server checks the merchant range, counts and prices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Eggs = require(Shared.Config.Eggs)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local ItemIcon = require(App.ItemIcon)
local Kit = require(App.Kit)
local Hatch = require(script.Parent.Hatch)

local C = Theme.Color
local CELL = Vector2.new(118, 150)
local GAP = 10
local BODY = Vector2.new(828, 424) -- the panel's body (860 x 500 panel)
local SIDEBAR = 80

local function matches(text: string, query: string): boolean
	return query == "" or string.find(string.lower(text), query, 1, true) ~= nil
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = Theme.Face.Display
end

export type Entry = {
	kind: "item" | "egg",
	key: string,
	itemId: string?,
	egg: any, -- the EggDef for eggs
	golden: boolean,
	count: number,
}

-- Items the player holds (stacks of one item summed) and the eggs in the bag, in display order.
local function entries(view: any, tab: string, query: string): { Entry }
	local out: { Entry } = {}
	if tab == "All" or tab == "Items" then
		local totals: { [string]: number } = {}
		local order: { string } = {}
		for _, stack in view.items.stacks do
			if totals[stack.itemId] == nil then
				table.insert(order, stack.itemId)
			end
			totals[stack.itemId] = (totals[stack.itemId] or 0) + stack.count
		end
		for _, id in order do
			if matches(Items.ById[id].displayName, query) then
				table.insert(
					out,
					{ kind = "item", key = id, itemId = id, golden = false, count = totals[id] }
				)
			end
		end
	end
	if tab == "All" or tab == "Eggs" then
		for _, egg in Eggs.List do
			local b = view.eggBag[egg.id]
			if b and matches(egg.displayName, query) then
				if (b.golden or 0) > 0 then
					table.insert(
						out,
						{ kind = "egg", key = `{egg.id}_golden`, egg = egg, golden = true, count = b.golden }
					)
				end
				if (b.normal or 0) > 0 then
					table.insert(
						out,
						{ kind = "egg", key = egg.id, egg = egg, golden = false, count = b.normal }
					)
				end
			end
		end
	end
	return out
end

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p =
		Ui.panel(layer, "INVENTORY", ctx.close, UDim2.fromOffset(BODY.X + 32, BODY.Y + 76), "icon_cards")
	local tab = if arg and arg.tab then arg.tab else "All"
	local page = 1
	local selected: string? = if arg then arg.select else nil -- an item id or egg key to open on
	local query = ""
	local qty = 1
	local render: () -> ()

	local sidebar = Ui.frame({
		Name = "Sidebar",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, SIDEBAR - 8, 1, 0),
		Parent = p.body,
	}, { Ui.list(false, 10) })
	local left = Ui.frame({
		Name = "Bag",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(SIDEBAR, 0),
		Size = UDim2.new(1, -SIDEBAR, 1, 0),
		Parent = p.body,
	})
	local inspectBox = Ui.glowTile("Frame", {
		Name = "InspectBox",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.42, 1),
		Visible = false,
		Parent = p.body,
	}, C.Purple, false)
	local inspect =
		Ui.frame({ Name = "Inspect", BackgroundTransparency = 1, ZIndex = 2, Parent = inspectBox })

	-- Header: the bag slots with a gold "+", and the search bar.
	local slots = Ui.pricePill("0/0", "icon_cards", 36, {
		Name = "Slots",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -108, 0.5, 0),
		ZIndex = 3,
		Parent = p.header,
	})
	local slotsAmount = slots:FindFirstChild("Amount") :: TextLabel
	slotsAmount.FontFace = Theme.Face.Display
	slotsAmount.TextSize = 22
	local expand: ImageButton = Ui.new("ImageButton", {
		Name = "Expand",
		Image = Kit.id("plus_gold"),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 4,
		Parent = p.header,
	})
	Ui.juice(expand)
	expand.Activated:Connect(function()
		Ui.sound("click")
		local v = ctx.state.view
		local idx = (v.items.slots - Economy.ItemInventory.startSlots)
				// Economy.ItemInventory.slotsPerExpansion
			+ 1
		local price = Economy.ItemInventory.expansionPrices[idx]
		if price == nil then
			ctx.fail("StorageAtMax")
			return
		end
		ctx.confirm("More bag space", `Add a bag slot for {Format.number(price)} Coins?`, "Expand", function()
			if ctx.request("Inventory.Expand", { requestId = ctx.guid() }).ok then
				Ui.sound("purchase")
			end
		end)
	end)
	local search: TextBox = Ui.new("TextBox", {
		Name = "Search",
		Text = "",
		PlaceholderText = "SEARCH",
		ClearTextOnFocus = false,
		FontFace = Theme.Face.Title,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.Text,
		PlaceholderColor3 = C.Muted,
		BackgroundColor3 = C.PanelDeep,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -270, 0.5, 0),
		Size = UDim2.fromOffset(200, 36),
		ZIndex = 3,
		Parent = p.header,
	}, { Ui.corner(18), Ui.stroke(C.Purple, 2, 0.2), Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 40) }) })
	Ui.icon("icon_search", 26, { Position = UDim2.new(0, -24, 0.5, 0), ZIndex = 4, Parent = search })
	search.FocusLost:Connect(function()
		if string.lower(search.Text) ~= query then
			query = string.lower(search.Text)
			page = 1
			render()
		end
	end)

	-- One tab: an icon on a bright tile, the big word under it, the count in a badge on the corner.
	local function tabTile(
		id: string,
		icon: string,
		word: string,
		badge: number?,
		accent: Color3,
		order: number
	)
		local active = tab == id
		local b: TextButton = Ui.new("TextButton", {
			Name = `Tab{id}`,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			LayoutOrder = order,
			Size = UDim2.fromOffset(SIDEBAR - 8, 78),
			Parent = sidebar,
		}, {
			Ui.new("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Ui.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, accent:Lerp(C.White, 0.2)),
					ColorSequenceKeypoint.new(1, accent:Lerp(C.Night, if active then 0.25 else 0.6)),
				}),
			}),
			Ui.new("UIStroke", {
				Color = if active then C.Gold else C.Night,
				Thickness = if active then 3 else 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		})
		Ui.icon(icon, 40, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			ZIndex = 2,
			Parent = b,
		})
		local label = Ui.display({
			Name = "Label",
			Text = word,
			TextSize = 18,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, 4, 0, 22),
			ZIndex = 3,
			Parent = b,
		})
		label.TextColor3 = C.White
		Ui.fit(label, 18, 12)
		if badge and badge > 0 then
			local n = Ui.display({
				Name = "Count",
				Text = tostring(badge),
				TextSize = 15,
				BackgroundColor3 = if active then C.Gold else C.Red,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(26, 24),
				ZIndex = 4,
				Parent = b,
			})
			n.TextColor3 = if active then C.GoldInk else C.White
			Ui.corner(12).Parent = n
			Ui.fit(n, 15, 10)
		end
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("click")
			tab = id
			page = 1
			selected = nil
			render()
		end)
	end

	local function renderTabs(v: any)
		Ui.clear(sidebar)
		local itemCount = #entries(v, "Items", "")
		local eggCount = 0
		for _, b in v.eggBag do
			eggCount += (b.normal or 0) + (b.golden or 0)
		end
		tabTile("All", "icon_check", "ALL", nil, Color3.fromHex("#8D9BC4"), 1)
		tabTile("Items", "icon_energy", "ITEMS", itemCount, Color3.fromHex("#2FD6E0"), 2)
		tabTile("Eggs", "icon_shop", "EGGS", eggCount, Color3.fromHex("#FF6FC8"), 3)
	end

	local function itemTile(parent: Instance, e: Entry, order: number)
		local item = Items.ById[e.itemId :: string]
		local tile: TextButton = Ui.new("TextButton", {
			Name = e.key,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		})
		Ui.skin(tile, if selected == e.key or item.rare then "tile_selected" else "tile", 0.5)
		ItemIcon.new(e.key, 80, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			ZIndex = 2,
			Parent = tile,
		}, true)
		Ui.display({
			Name = "Count",
			Text = `x{e.count}`,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 62),
			Size = UDim2.fromOffset(60, 24),
			ZIndex = 3,
			Parent = tile,
		}, true)
		local name = Ui.display({
			Name = "ItemName",
			Text = item.displayName,
			TextSize = 16,
			Position = UDim2.fromOffset(3, 92),
			Size = UDim2.new(1, -6, 0, 20),
			ZIndex = 2,
			Parent = tile,
		})
		name.TextColor3 = C.White
		Ui.fit(name, 16, 11)
		Ui.pricePill(Format.number(item.sellPrice), "icon_coin", 24, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 120),
			ZIndex = 2,
			Parent = tile,
		})
		if selected == e.key then
			Ui.stroke(C.GoldHi, 3, 0).Parent = tile
		end
		Ui.juice(tile)
		tile.Activated:Connect(function()
			Ui.sound("tick")
			selected = if selected == e.key then nil else e.key
			qty = e.count
			render()
		end)
	end

	local function eggTile(parent: Instance, e: Entry, order: number)
		local tile: TextButton = Ui.new("TextButton", {
			Name = e.key,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		})
		Ui.skin(tile, if e.golden or selected == e.key then "tile_selected" else "tile", 0.5)
		local icon = Visuals.egg(tile, e.egg, e.golden, 78)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0.02)
		Ui.display({
			Name = "Count",
			Text = `x{e.count}`,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 62),
			Size = UDim2.fromOffset(60, 24),
			ZIndex = 3,
			Parent = tile,
		}, true)
		local label = Ui.display({
			Name = "EggName",
			Text = if e.golden then `Golden {e.egg.displayName}` else e.egg.displayName,
			TextSize = 16,
			Position = UDim2.fromOffset(3, 92),
			Size = UDim2.new(1, -6, 0, 20),
			ZIndex = 2,
			Parent = tile,
		})
		label.TextColor3 = if e.golden then C.GoldHi else C.White
		Ui.fit(label, 16, 10)
		local tag = Ui.display({
			Name = "Open",
			Text = "OPEN",
			TextSize = 18,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 120),
			Size = UDim2.new(1, -10, 0, 24),
			ZIndex = 2,
			Parent = tile,
		})
		tag.TextColor3 = C.Green
		if selected == e.key then
			Ui.stroke(C.GoldHi, 3, 0).Parent = tile
		end
		Ui.juice(tile)
		tile.Activated:Connect(function()
			Ui.sound("tick")
			selected = if selected == e.key then nil else e.key
			render()
		end)
	end

	local function openEgg(e: Entry)
		local known = Hatch.known(ctx.state.view)
		local reply = ctx.request("Bag.OpenEgg", { eggId = e.egg.id, golden = e.golden })
		if reply.ok then
			Hatch.show(ctx, reply.value.cards, e.egg, e.golden, { known = known })
		end
	end

	local function sell(e: Entry, from: GuiObject)
		local n = math.clamp(qty, 1, e.count)
		local reply =
			ctx.request("Merchant.SellItem", { itemId = e.itemId, count = n, requestId = ctx.guid() })
		if reply.ok and reply.value > 0 then
			Ui.sound("purchase")
			ctx.near(from, { text = `+{Format.number(reply.value)}`, icon = "icon_coin", tone = "gold" })
			ctx.fly(from, "coins", { icon = "icon_coin", count = math.clamp(reply.value // 20 + 2, 3, 6) })
		end
	end

	-- The inspect panel for the selected item or egg (never a card).
	local function renderInspect(e: Entry)
		Ui.clear(inspect)
		Ui.pad(12).Parent = inspect
		local isItem = e.kind == "item"
		local item = if isItem then Items.ById[e.itemId :: string] else nil
		local plate = Ui.frame({
			Name = "IconTile",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(132, 132),
			Parent = inspect,
		})
		Ui.skin(plate, if (item and item.rare) or e.golden then "tile_selected" else "tile", 0.6)
		if item then
			ItemIcon.new(e.key, 104, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 2,
				Parent = plate,
			}, true)
		else
			local egg = Visuals.egg(plate, e.egg, e.golden, 104)
			egg.AnchorPoint = Vector2.new(0.5, 0.5)
			egg.Position = UDim2.fromScale(0.5, 0.5)
		end
		local count = Ui.display({
			Name = "Count",
			Text = `x{e.count}`,
			TextSize = 32,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 8, 1, 4),
			Size = UDim2.fromOffset(70, 34),
			ZIndex = 4,
			Parent = plate,
		}, true)
		count.TextXAlignment = Enum.TextXAlignment.Right
		local name = Ui.display({
			Name = "Name",
			Text = if item
				then string.upper(item.displayName)
				else string.upper(if e.golden then `Golden {e.egg.displayName}` else e.egg.displayName),
			TextSize = 30,
			Position = UDim2.fromOffset(0, 140),
			Size = UDim2.new(1, 0, 0, 36),
			Parent = inspect,
		})
		name.TextColor3 = C.White
		Ui.fit(name, 30, 18)

		local bottom = Ui.frame({
			Name = "Actions",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 182),
			Size = UDim2.new(1, 0, 1, -182),
			Parent = inspect,
		}, { Ui.list(false, 8) });
		(bottom:FindFirstChildOfClass("UIListLayout") :: UIListLayout).HorizontalAlignment =
			Enum.HorizontalAlignment.Center
		if item then
			Ui.pricePill(`{Format.number(item.sellPrice)} EACH`, "icon_coin", 32, {
				Name = "Price",
				AnchorPoint = Vector2.zero,
				LayoutOrder = 1,
				Parent = bottom,
			})
			-- the quantity picker: - N + MAX
			local picker = Ui.frame({
				Name = "Quantity",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 40),
				LayoutOrder = 2,
				Parent = bottom,
			}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
			local n = math.clamp(qty, 1, e.count)
			local minus = Ui.button("−", "secondary", function()
				qty = math.max(1, n - 1)
				render()
			end, { Name = "Minus", Size = UDim2.fromOffset(44, 40), LayoutOrder = 1 })
			bigLabel(minus, 26)
			minus.setEnabled(n > 1)
			minus.instance.Parent = picker
			local shown = Ui.display({
				Name = "Amount",
				Text = tostring(n),
				TextSize = 28,
				Size = UDim2.fromOffset(56, 40),
				LayoutOrder = 2,
				Parent = picker,
			})
			shown.TextColor3 = C.White
			local plus = Ui.button("+", "secondary", function()
				qty = math.min(e.count, n + 1)
				render()
			end, { Name = "Plus", Size = UDim2.fromOffset(44, 40), LayoutOrder = 3 })
			bigLabel(plus, 26)
			plus.setEnabled(n < e.count)
			plus.instance.Parent = picker
			local max = Ui.button("MAX", "ghost", function()
				qty = e.count
				render()
			end, { Name = "Max", Size = UDim2.fromOffset(64, 40), LayoutOrder = 4 })
			bigLabel(max, 18)
			max.instance.Parent = picker
			local sellButton: any
			sellButton = Ui.button(`SELL  {Format.number(n * item.sellPrice)}`, "primary", function()
				sell(e, sellButton.instance)
			end, { Name = "Sell", Size = UDim2.fromOffset(200, 48), LayoutOrder = 3 })
			bigLabel(sellButton, 26)
			sellButton.instance.Parent = bottom
			Ui.icon(
				"icon_coin",
				30,
				{ Position = UDim2.new(1, -24, 0.5, 0), ZIndex = 5, Parent = sellButton.instance }
			)
			-- one line: where it sells
			local at = Ui.frame({
				Name = "SoldAt",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 4,
				Parent = bottom,
			}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
			Ui.icon("icon_coin", 26, { AnchorPoint = Vector2.zero, LayoutOrder = 1, Parent = at })
			local where = Ui.display({
				Text = "SOLD AT ANY MERCHANT",
				TextSize = 18,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				LayoutOrder = 2,
				Parent = at,
			})
			where.TextColor3 = C.Muted
		else
			local open = Ui.button("OPEN", if e.golden then "primary" else "success", function()
				openEgg(e)
			end, { Name = "OpenEgg", Size = UDim2.fromOffset(200, 52), LayoutOrder = 1 })
			bigLabel(open, 30)
			open.instance.Parent = bottom
		end
	end

	render = function()
		view = ctx.state.view
		if view == nil then
			return
		end
		slotsAmount.Text = `{#view.items.stacks}/{view.items.slots}`
		renderTabs(view)
		Ui.clear(left)
		local list = entries(view, tab, query)
		local chosen: Entry? = nil
		for _, e in list do
			if e.key == selected then
				chosen = e
			end
		end
		if chosen == nil then
			selected = nil
		end
		-- With nothing selected the inspect panel hides and the grid takes its space.
		inspectBox.Visible = chosen ~= nil
		local width = BODY.X - SIDEBAR - (if chosen then math.floor(BODY.X * 0.42) + 10 else 0)
		left.Size = UDim2.new(0, width, 1, 0)
		local cols = math.max(1, (width + GAP) // (CELL.X + GAP))
		local rows = math.max(1, (BODY.Y - 50 + GAP) // (CELL.Y + GAP))
		local per = cols * rows
		local pages = math.max(1, math.ceil(#list / per))
		page = math.clamp(page, 1, pages)
		local grid = Ui.frame({
			Name = "Grid",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -50),
			Parent = left,
		})
		Ui.grid(CELL, GAP).Parent = grid
		for i = (page - 1) * per + 1, math.min(#list, page * per) do
			local e = list[i]
			if e.kind == "item" then
				itemTile(grid, e, i)
			else
				eggTile(grid, e, i)
			end
		end
		if #list == 0 then
			-- the empty bag: one big icon and 1-3 big words in the middle (outside the grid layout)
			local empty = Ui.frame({
				Name = "Empty",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(420, 180),
				Parent = left,
			})
			Ui.icon(if tab == "Eggs" then "icon_shop" else "icon_cards", 110, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Parent = empty,
			})
			local words = Ui.display({
				Name = "Words",
				Text = if query ~= ""
					then "NO MATCH"
					elseif tab == "Eggs" then "NO EGGS YET"
					else "HARVEST IN A WORLD!",
				TextSize = 34,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 44),
				Parent = empty,
			}, true)
			Ui.fit(words, 34, 20)
		end
		if pages > 1 then
			local pager = Ui.frame({
				Name = "Pager",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 42),
				Parent = left,
			}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
			local prev = Ui.button("◀", "secondary", function()
				page -= 1
				render()
			end, { Size = UDim2.fromOffset(48, 40), LayoutOrder = 1, Name = "Prev" })
			bigLabel(prev, 22)
			prev.setEnabled(page > 1)
			prev.instance.Parent = pager
			local label = Ui.display({
				Text = `{page}/{pages}`,
				TextSize = 24,
				Size = UDim2.fromOffset(90, 40),
				LayoutOrder = 2,
				Parent = pager,
			}, true)
			label.TextXAlignment = Enum.TextXAlignment.Center
			local nextButton = Ui.button("▶", "secondary", function()
				page += 1
				render()
			end, { Size = UDim2.fromOffset(48, 40), LayoutOrder = 3, Name = "Next" })
			bigLabel(nextButton, 22)
			nextButton.setEnabled(page < pages)
			nextButton.instance.Parent = pager
		end
		if chosen then
			renderInspect(chosen)
		else
			Ui.clear(inspect)
		end
	end

	render()
	Ui.stagger(sidebar, ctx.reducedMotion())
	local firstGrid = left:FindFirstChild("Grid")
	if firstGrid then
		Ui.stagger(firstGrid, ctx.reducedMotion())
	end
	return { destroy = function() end, refresh = render }
end
