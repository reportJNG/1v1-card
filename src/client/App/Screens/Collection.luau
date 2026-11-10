--!strict
-- Inventory (the concept board's Inventory and Card Inspect): tabs All / Cards / Items / Eggs, a
-- search box, rarity filters for cards, storage counts with the expand buttons, and the inspect
-- panel: a big 2.5D card, stats, the family bonus it brings, merge, equip (into the deck) and sell
-- spares. Eggs in the bag open from here. Every action is a request: the server re-checks
-- ownership, deck rules and prices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Eggs = require(Shared.Config.Eggs)
local Families = require(Shared.Config.Families)
local Power = require(Shared.Domain.Power)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local ItemIcon = require(App.ItemIcon)
local CardActions = require(App.CardActions)
local Card = require(App.Card)
local Kit = require(App.Kit)
local CardStats = require(script.Parent.CardStats)
local Hatch = require(script.Parent.Hatch)

local C = Theme.Color
local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local STAT_NAME = { hp = "HP", atk = "Attack", def = "Defence", spd = "Speed", crit = "Crit" }

local function matches(text: string, query: string): boolean
	return query == "" or string.find(string.lower(text), query, 1, true) ~= nil
end

local function sortedCards(view: any, filter: string?, query: string): { any }
	local out = {}
	for _, card in view.cards do
		local def = Characters.ById[card.characterId]
		if
			def
			and (filter == nil or def.rarity == filter)
			and (matches(def.displayName, query) or matches(def.family, query))
		then
			table.insert(out, card)
		end
	end
	table.sort(out, function(a, b)
		local ra = Rarities.Defs[Characters.ById[a.characterId].rarity].order
		local rb = Rarities.Defs[Characters.ById[b.characterId].rarity].order
		if ra ~= rb then
			return ra > rb
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		if a.characterId ~= b.characterId then
			return a.characterId < b.characterId
		end
		return a.uid < b.uid
	end)
	return out
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = Theme.Face.Display
end

local inDeck = CardActions.inDeck
local spares = CardActions.spares

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

export type Bagged = { egg: any, golden: boolean, count: number }

-- Eggs in the bag: one entry per egg and variant (Golden copies open separately).
local function bagged(view: any, query: string): { Bagged }
	local out: { Bagged } = {}
	for _, egg in Eggs.List do
		local b = view.eggBag[egg.id]
		if b and matches(egg.displayName, query) then
			if (b.golden or 0) > 0 then
				table.insert(out, { egg = egg, golden = true, count = b.golden })
			end
			if (b.normal or 0) > 0 then
				table.insert(out, { egg = egg, golden = false, count = b.normal })
			end
		end
	end
	return out
end

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "INVENTORY", ctx.close, UDim2.fromOffset(800, 480), "icon_cards")
	local tab = if arg and arg.tab then arg.tab else "All"
	local page = 1
	local PAGE_SIZE = 60 -- storage holds up to 1,000 copies; never build them all at once
	local filter: string? = nil
	local selected: string? = nil
	local query = ""

	-- Left: the icon sidebar (All / Cards / Items / Eggs, then "+" for more storage).
	local header = Ui.frame({
		Name = "Sidebar",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 56, 1, 0),
		Parent = p.body,
	}, { Ui.list(false, 6) })
	local left = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(64, 0),
		Size = UDim2.new(0.52, -72, 1, 0),
		Parent = p.body,
	})
	-- The glow frame stays; renderInspect clears only the content inside it.
	local inspectBox = Ui.glowTile("Frame", {
		Name = "InspectBox",
		Position = UDim2.fromScale(0.52, 0),
		Size = UDim2.fromScale(0.48, 1),
		Parent = p.body,
	}, C.Purple, false)
	local inspect =
		Ui.frame({ Name = "Inspect", BackgroundTransparency = 1, ZIndex = 2, Parent = inspectBox })

	local render: () -> ()

	-- The storage count in the header (target hd-03): cards held / card slots.
	local storage = Ui.pricePill("0/0", "icon_cards", 36, {
		Name = "Storage",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -64, 0.5, 0),
		ZIndex = 3,
		Parent = p.header,
	})
	local storageAmount = storage:FindFirstChild("Amount") :: TextLabel
	storageAmount.FontFace = Theme.Face.Display
	-- The search bar in the header (target hd-03), with its magnifier.
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
		Position = UDim2.new(1, -230, 0.5, 0),
		Size = UDim2.fromOffset(210, 36),
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

	-- The inspect pane (`hd-03`): the large card on the left; name, rarity pill and family, a
	-- one-line description, Power / Health / Skill rows with icons, the family bonus in green, and
	-- Equip / Merge / Card Stats. The full stats panel (board 05) opens from the card or the button.
	local function renderInspect()
		Ui.clear(inspect)
		Ui.pad(10).Parent = inspect
		local card = selected and view.cards[selected]
		if card == nil and (tab == "All" or tab == "Cards") then
			local first = sortedCards(view, filter, query)[1]
			if first then
				selected = first.uid
				card = first
			end
		end
		if card == nil then
			Ui.text({
				Text = if tab == "Items"
					then "Sell items at any world's merchant."
					elseif tab == "Eggs" then "Open eggs from your bag: each one hatches a card."
					else "Hatch eggs to get cards.",
				FontFace = Theme.Face.Title,
				TextSize = 22,
				TextColor3 = C.Text,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = inspect,
			})
			return
		end
		local def = Characters.ById[card.characterId]
		local rdef = Rarities.Defs[def.rarity]
		local portrait = Card.build(inspect, {
			characterId = card.characterId,
			golden = card.golden,
			level = card.level,
			favorite = card.favorite,
			size = Vector2.new(150, 210),
			interactive = true,
		})
		portrait.Name = "InspectCard"
		portrait.Position = UDim2.fromOffset(4, 14)
		local open = Ui.new("TextButton", {
			Name = "OpenStats",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 50,
			Parent = portrait,
		})
		open.Activated:Connect(function()
			Ui.sound("click")
			CardStats.show(ctx, card.uid)
		end)
		local info = Ui.frame({
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(164, 0),
			Size = UDim2.new(1, -164, 1, -40),
			Parent = inspect,
		}, { Ui.list(false, 5) })
		local name = Ui.text({
			Name = "Name",
			Text = def.displayName,
			FontFace = Theme.Face.Display,
			TextSize = 28,
			TextWrapped = false,
			Size = UDim2.new(1, 0, 0, 32),
			LayoutOrder = 1,
			Parent = info,
		})
		Ui.fit(name, 28, 14)
		Ui.outline(C.Night, 3).Parent = name
		local tags = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2,
			Parent = info,
		}, { Ui.list(true, 8) })
		local pill = Ui.text({
			Name = "RarityPill",
			Text = rdef.badge,
			FontFace = Theme.Face.Display,
			TextSize = 18,
			TextColor3 = C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundColor3 = rdef.colors[2],
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			Parent = tags,
		})
		Ui.pad(7).Parent = pill
		Ui.corner(6).Parent = pill
		Ui.outline(C.Night, 1).Parent = pill
		Ui.text({
			Text = `{string.upper(def.family)}`,
			FontFace = Theme.Face.Display,
			TextSize = 18,
			TextColor3 = rdef.color,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			Parent = tags,
		})
		Ui.text({
			Name = "Description",
			Text = def.passive.description,
			FontFace = Theme.Face.Bold,
			TextSize = 17,
			TextColor3 = C.Text,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 3,
			Parent = info,
		})
		local stats = Power.deck({ { characterId = card.characterId, level = card.level } }).units[1]
		local function statRow(icon: string, label: string, value: string, order: number)
			local row = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = order,
				Parent = info,
			})
			Kit.image(
				icon,
				{ Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(0, 1), Parent = row }
			)
			local t = Ui.text({
				Text = `<font color="#9EAED3">{label}:</font> {value}`,
				RichText = true,
				FontFace = Theme.Face.Title,
				TextSize = 20,
				TextWrapped = false,
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.new(1, -32, 1, 0),
				Parent = row,
			})
			Ui.fit(t, 20, 12)
		end
		statRow("icon_atk", "Power", Format.number(stats.power), 4)
		statRow("icon_hp", "Health", Format.number(stats.hp), 5)
		statRow("icon_energy", "Skill", def.special.displayName, 6)
		local famDef = Families.Defs[def.family]
		local statName = STAT_NAME[famDef.bonusStat] or famDef.bonusStat
		local bonus = Ui.text({
			Name = "FamilyBonus",
			Text = `<b>FAMILY BONUS</b>\n+2% {statName} (x2) · +3% (x3)`,
			RichText = true,
			FontFace = Theme.Face.Title,
			TextSize = 17,
			TextColor3 = C.Green,
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 46),
			LayoutOrder = 7,
			Parent = info,
		})
		bonus.TextWrapped = true
		if card.paid then
			Ui.text({
				Text = "From a Robux egg",
				TextSize = 11,
				TextColor3 = C.Purple,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 8,
				Parent = info,
			})
		end

		-- Actions under the card and info: Equip / Equipped (purple), Merge, Card Stats.
		local actions = Ui.frame({
			Name = "Actions",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = inspect,
		}, { Ui.list(true, 6) })
		local here = inDeck(view, card.uid)
		local equip = Ui.button(if here then "EQUIPPED" else "EQUIP", "purple", function()
			if not here then
				CardActions.equip(ctx, card)
			end
		end, { LayoutOrder = 1, Size = UDim2.fromOffset(120, 40), Name = "Equip" })
		bigLabel(equip, 20)
		equip.setEnabled(not card.locked)
		equip.instance.Parent = actions
		local plan = CardActions.mergePlan(view, card)
		if plan and #plan.use > 0 then
			local merge = Ui.button(`MERGE {#plan.use}`, "primary", function()
				CardActions.merge(ctx, card)
			end, { LayoutOrder = 2, Size = UDim2.fromOffset(110, 40), Name = "Merge" })
			bigLabel(merge, 20)
			merge.setEnabled(#plan.use > 0 and view.coins >= plan.fee)
			merge.instance.Parent = actions
		end
		local details = Ui.button("STATS", "secondary", function()
			CardStats.show(ctx, card.uid)
		end, { LayoutOrder = 3, Size = UDim2.fromOffset(110, 40), Name = "Details" })
		bigLabel(details, 20)
		details.instance.Parent = actions
		local spareList = spares(view, card)
		local hasMax = false
		for _, c in view.cards do
			if c.characterId == card.characterId and c.level >= Economy.Progression.maxLevel then
				hasMax = true
			end
		end
		if hasMax and #spareList > 0 then
			local price = Economy.CardSale[def.rarity] or 0
			local sell = Ui.button(`SELL {#spareList}`, "ghost", function()
				ctx.confirm(
					"Sell spares",
					`Sell {#spareList} spare {def.displayName} copies for {Format.number(price * #spareList)} Coins?`,
					"Sell",
					function()
						ctx.request("Cards.Sell", { uids = spareList, requestId = ctx.guid() })
					end
				)
			end, { LayoutOrder = 4, Size = UDim2.fromOffset(84, 40), Name = "Sell" })
			bigLabel(sell, 20)
			sell.instance.Parent = actions
		end
	end

	local function cardTile(parent: Instance, card: any, order: number)
		local tile = Ui.new("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Name = card.uid,
			Parent = parent,
		})
		local portrait = Card.build(tile, {
			characterId = card.characterId,
			golden = card.golden,
			level = card.level,
			favorite = card.favorite,
			size = Vector2.new(88, 120),
			hover = true,
			bare = true,
			stats = false,
		})
		if selected == card.uid then
			Ui.stroke(C.GoldHi, 3).Parent = portrait
		end
		-- a big level top-right, and the deck slot (gold box) when it is in the deck
		local lv = Ui.display({
			Name = "Level",
			Text = `LV{card.level}`,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(52, 22),
			ZIndex = 60,
			Parent = tile,
		})
		lv.TextColor3 = C.White
		Ui.outline(C.Night, 3).Parent = lv
		local slot = table.find(view.deck, card.uid)
		if slot then
			local mark = Ui.display({
				Name = "DeckSlot",
				Text = tostring(slot),
				TextSize = 18,
				BackgroundColor3 = C.Gold,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 2, 1, 0),
				Size = UDim2.fromOffset(24, 24),
				ZIndex = 61,
				Parent = tile,
			})
			mark.TextColor3 = C.GoldInk
			Ui.corner(6).Parent = mark
		end
		tile.Activated:Connect(function()
			selected = card.uid
			render()
		end)
	end

	local function eggTile(parent: Instance, entry: Bagged, order: number)
		local tile = Ui.frame({
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Name = if entry.golden then `{entry.egg.id}_golden` else entry.egg.id,
			Parent = parent,
		})
		Ui.skin(tile, if entry.golden then "tile_selected" else "tile", 0.5)
		local icon = Visuals.egg(tile, entry.egg, entry.golden, 58)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0.02)
		local label = Ui.text({
			Text = if entry.golden then `Golden {entry.egg.displayName}` else entry.egg.displayName,
			FontFace = Theme.Face.Display,
			TextSize = 15,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 60),
			Size = UDim2.new(1, -4, 0, 18),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.outline(C.Night, 2).Parent = label
		Ui.fit(label, 15, 10)
		local golden = entry.golden
		local open = Ui.button(`OPEN x{entry.count}`, if golden then "primary" else "success", function()
			local known = Hatch.known(ctx.state.view)
			local reply = ctx.request("Bag.OpenEgg", { eggId = entry.egg.id, golden = golden })
			if reply.ok then
				Hatch.show(ctx, reply.value.cards, entry.egg, golden, { known = known })
			end
		end, {
			Name = "Open",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -10, 0, 30),
			ZIndex = 2,
		})
		bigLabel(open, 18)
		open.instance.Parent = tile
	end

	local function itemTile(parent: Instance, stack: any, order: number)
		local item = Items.ById[stack.itemId]
		local tile = Ui.frame({
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Name = stack.itemId,
			Parent = parent,
		})
		Ui.skin(tile, "tile", 0.5)
		ItemIcon.new(stack.itemId, 60, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 4),
			ZIndex = 2,
			Parent = tile,
		}, true)
		Ui.display({
			Name = "Count",
			Text = `×{stack.count}`,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 44),
			Size = UDim2.fromOffset(60, 22),
			ZIndex = 3,
			Parent = tile,
		}, true)
		local name = Ui.text({
			Name = "ItemName",
			Text = item.displayName,
			FontFace = Theme.Face.Title,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			Position = UDim2.fromOffset(3, 68),
			Size = UDim2.new(1, -6, 0, 18),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.outline(C.Night, 1.5).Parent = name
		Ui.fit(name, 13, 9)
		Ui.pricePill(Format.number(item.sellPrice), "icon_coin", 22, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 90),
			ZIndex = 2,
			Parent = tile,
		})
	end

	local function renderGrid()
		-- Filters row: rarity buttons (cards) and the search box.
		local filters = Ui.frame(
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = left },
			{ Ui.list(true, 4) }
		)
		if tab == "Cards" or tab == "All" then
			local allButton = Ui.button("ALL", if filter == nil then "purple" else "ghost", function()
				filter = nil
				page = 1
				render()
			end, { Size = UDim2.fromOffset(46, 30), LayoutOrder = 1, Name = "FilterAll" })
			bigLabel(allButton, 16)
			allButton.instance.Parent = filters
			-- Rarity chips (kit filter_chip_<rarity>) with the badge letters in the rarity colour.
			for i, r in RARITY_ORDER do
				local rdef = Rarities.Defs[r]
				local active = filter == r
				local chip: ImageButton = Ui.new("ImageButton", {
					Name = `Filter{string.sub(r, 1, 4)}`,
					Image = Kit.id(`filter_chip_{rdef.tag}`),
					BackgroundTransparency = 1,
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(40, 24, 152, 40),
					SliceScale = 0.45,
					ImageTransparency = if active then 0 else 0.35,
					Size = UDim2.fromOffset(if #rdef.badge > 2 then 40 else 34, 28),
					LayoutOrder = i + 1,
					Parent = filters,
				})
				local label = Ui.display({
					Text = rdef.badge,
					TextSize = 17,
					TextColor3 = if active then C.White else rdef.colors[1],
					Size = UDim2.fromScale(1, 1),
					ZIndex = 2,
					Parent = chip,
				})
				label.TextXAlignment = Enum.TextXAlignment.Center
				if active then
					Ui.stroke(C.GoldHi, 2, 0).Parent = chip
				end
				Ui.juice(chip)
				chip.Activated:Connect(function()
					Ui.sound("tick")
					filter = if active then nil else r
					page = 1
					render()
				end)
			end
		end
		local grid =
			Ui.scroll({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -76), Parent = left })
		grid.ScrollBarThickness = 3 -- a thin handle only (60 cards a page)
		Ui.grid(Vector2.new(88, 120), 8).Parent = grid
		-- Room for the rarity badge, which overhangs the top of each card.
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 4), Parent = grid })
		local order = 0
		local total = 0
		if tab == "All" or tab == "Eggs" then
			for _, entry in bagged(view, query) do
				order += 1
				total += 1
				eggTile(grid, entry, order)
			end
		end
		if tab == "All" or tab == "Cards" then
			local cards = sortedCards(view, filter, query)
			local pages = math.max(1, math.ceil(#cards / PAGE_SIZE))
			page = math.clamp(page, 1, pages)
			total += #cards
			for i = (page - 1) * PAGE_SIZE + 1, math.min(#cards, page * PAGE_SIZE) do
				order += 1
				cardTile(grid, cards[i], order)
			end
			-- Pager (cards only).
			local pager = Ui.frame({
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 1, -34),
				Size = UDim2.new(1, 0, 0, 32),
				Parent = left,
			}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
			local prev = Ui.button("◀", "secondary", function()
				page -= 1
				render()
			end, { Size = UDim2.fromOffset(44, 32), LayoutOrder = 1 })
			bigLabel(prev, 22)
			prev.setEnabled(page > 1)
			prev.instance.Parent = pager
			local pageLabel = Ui.display({
				Text = `{page}/{pages}`,
				TextSize = 22,
				Size = UDim2.fromOffset(110, 32),
				LayoutOrder = 2,
				Parent = pager,
			}, true)
			Ui.outline(C.Night, 2).Parent = pageLabel
			local nextButton = Ui.button("▶", "secondary", function()
				page += 1
				render()
			end, { Size = UDim2.fromOffset(44, 32), LayoutOrder = 3 })
			bigLabel(nextButton, 22)
			nextButton.setEnabled(page < pages)
			nextButton.instance.Parent = pager
		end
		if tab == "All" or tab == "Items" then
			for _, stack in view.items.stacks do
				if matches(Items.ById[stack.itemId].displayName, query) then
					order += 1
					total += 1
					itemTile(grid, stack, order)
				end
			end
		end
		if total == 0 then
			Ui.text({
				Text = if query ~= ""
					then "Nothing matches your search."
					elseif
						tab == "Eggs"
					then "No eggs in your bag. Golden eggs come from Trials and the 7-day streak."
					elseif tab == "Items" then "No items yet. Harvest resource nodes in your world."
					else "Hatch eggs in the Shop to get cards.",
				FontFace = Theme.Face.Title,
				TextSize = 20,
				TextColor3 = C.Text,
				Size = UDim2.new(1, 0, 0, 60),
				Parent = grid,
			})
		end
	end

	-- One sidebar tile: an icon on a bright tile, a short label (a count), gold edge when active.
	local function sideTile(
		name: string,
		icon: string,
		label: string,
		accent: Color3,
		active: boolean,
		onClick: () -> ()
	)
		local b: TextButton = Ui.new("TextButton", {
			Name = name,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			Size = UDim2.fromOffset(56, 56),
			Parent = header,
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
		Ui.icon(icon, 34, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			ZIndex = 2,
			Parent = b,
		})
		local tag = Ui.display({
			Text = label,
			TextSize = 16,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.new(1, 6, 0, 18),
			ZIndex = 3,
			Parent = b,
		})
		tag.TextColor3 = C.White
		Ui.outline(C.Night, 2).Parent = tag
		Ui.fit(tag, 16, 10)
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("click")
			onClick()
		end)
		return b
	end

	local function renderHeader()
		Ui.clear(header)
		local eggs = 0
		for _, b in view.eggBag do
			eggs += (b.normal or 0) + (b.golden or 0)
		end
		local tabs = {
			{ id = "All", icon = "icon_check", label = "All", accent = Color3.fromHex("#8D9BC4") },
			{
				id = "Cards",
				icon = "icon_cards",
				label = `{count(view.cards)}`,
				accent = Color3.fromHex("#A469FF"),
			},
			{
				id = "Items",
				icon = "icon_energy",
				label = `{#view.items.stacks}/{view.items.slots}`,
				accent = Color3.fromHex("#2FD6E0"),
			},
			{ id = "Eggs", icon = "icon_shop", label = `{eggs}`, accent = Color3.fromHex("#FF6FC8") },
		}
		for i, t in tabs do
			local b = sideTile(`Tab{t.id}`, t.icon, t.label, t.accent, tab == t.id, function()
				tab = t.id
				page = 1
				render()
			end)
			b.LayoutOrder = i
		end
		if tab == "All" or tab == "Cards" then
			local idx = (view.cardSlots - Economy.CardStorage.startSlots)
					// Economy.CardStorage.slotsPerExpansion
				+ 1
			local price = Economy.CardStorage.expansionPrices[idx]
			if price then
				local b = sideTile(
					"Expand",
					"button_plus",
					`+{Economy.CardStorage.slotsPerExpansion}`,
					C.Gold,
					false,
					function()
						ctx.confirm(
							"Expand card storage",
							`Add {Economy.CardStorage.slotsPerExpansion} card slots for {Format.number(price)} Coins?`,
							"Expand",
							function()
								if ctx.request("Cards.ExpandStorage", { requestId = ctx.guid() }).ok then
									Ui.sound("purchase")
								end
							end
						)
					end
				)
				b.LayoutOrder = 9
			end
		elseif tab == "Items" then
			local idx = (view.items.slots - Economy.ItemInventory.startSlots)
					// Economy.ItemInventory.slotsPerExpansion
				+ 1
			local price = Economy.ItemInventory.expansionPrices[idx]
			if price then
				local b = sideTile("Expand", "button_plus", "+1", C.Gold, false, function()
					ctx.confirm(
						"Expand inventory",
						`Add an item slot for {Format.number(price)} Coins?`,
						"Expand",
						function()
							if ctx.request("Inventory.Expand", { requestId = ctx.guid() }).ok then
								Ui.sound("purchase")
							end
						end
					)
				end)
				b.LayoutOrder = 9
			end
		end
	end

	render = function()
		view = ctx.state.view
		if view == nil then
			return
		end
		storageAmount.Text = `{count(view.cards)}/{view.cardSlots}`
		if selected and view.cards[selected] == nil then
			selected = nil
		end
		Ui.clear(left)
		renderHeader()
		renderGrid()
		renderInspect()
	end

	render()
	-- First open only: the sidebar and the grid pop in (later refreshes just redraw).
	Ui.stagger(header, ctx.reducedMotion())
	local firstGrid = left:FindFirstChildWhichIsA("ScrollingFrame")
	if firstGrid then
		Ui.stagger(firstGrid, ctx.reducedMotion())
	end
	return { destroy = function() end, refresh = render }
end
