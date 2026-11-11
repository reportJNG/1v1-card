--!strict
-- Cards (BAD_GUI_9 section 2): the card collection, opened by the HUD's CARDS button. Items and eggs
-- live in the Inventory (the bag button); this screen shows cards only.
--   header   the cards icon, a big CARDS title, search, and the storage count (N / 300) with a gold
--            "+" that expands storage
--   chips    rarity (each rarity's gem and name; tap the lit one again for all), FAMILY (cycles
--            the families you own), SORT (rarity / level / power) and ALL (clears the filters)
--   grid     art-first small cards: the rarity frame, a big level, the family gem and a power plate;
--            no names on small cards. Paged, no scrollbar
--   inspect  the large card (tap it for the full stats panel), the full display name, the rarity
--            name in its colour, POWER and HEALTH (Power.stats: the same numbers as the card plate),
--            the Skill as an icon + name with its one-line effect, the family bonus as a chip, and
--            EQUIP / UPGRADE (merge) / FAVORITE
--   DECK     a big shortcut to the Deck Builder
-- Every action is a request: the server re-checks ownership, deck rules and prices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Families = require(Shared.Config.Families)
local Power = require(Shared.Domain.Power)
local AbilityText = require(Shared.Domain.AbilityText)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local CardActions = require(App.CardActions)
local Card = require(App.Card)
local Kit = require(App.Kit)
local CardStats = require(script.Parent.CardStats)

local C = Theme.Color
local STAT_WORD = { hp = "HP", atk = "ATK", def = "DEF", spd = "SPD", crit = "CRIT" }
local SORTS = { "RARITY", "LEVEL", "POWER" }
local COLS, ROWS = 5, 2
local PAGE_SIZE = COLS * ROWS
local TILE = Vector2.new(86, 120)

local function matches(text: string, query: string): boolean
	return query == "" or string.find(string.lower(text), query, 1, true) ~= nil
end

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = Theme.Face.Display
end

export type Filter = { rarity: string?, family: string?, sort: string, query: string }

-- The cards shown for a filter, best first.
local function sortedCards(view: any, f: Filter): { any }
	local out = {}
	for _, card in view.cards do
		local def = Characters.ById[card.characterId]
		if
			def
			and (f.rarity == nil or def.rarity == f.rarity)
			and (f.family == nil or def.family == f.family)
			and (matches(def.displayName, f.query) or matches(def.family, f.query))
		then
			table.insert(out, card)
		end
	end
	local powerOf: { [string]: number } = {}
	for _, card in out do
		powerOf[card.uid] = Power.stats(card.characterId, card.level).power
	end
	table.sort(out, function(a, b)
		local ra = Rarities.Defs[Characters.ById[a.characterId].rarity].order
		local rb = Rarities.Defs[Characters.ById[b.characterId].rarity].order
		if f.sort == "POWER" and powerOf[a.uid] ~= powerOf[b.uid] then
			return powerOf[a.uid] > powerOf[b.uid]
		end
		if f.sort == "LEVEL" and a.level ~= b.level then
			return a.level > b.level
		end
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

-- Families the player owns, in a stable order (the FAMILY chip cycles through them).
local function ownedFamilies(view: any): { string }
	local seen: { [string]: boolean } = {}
	local out = {}
	for _, card in view.cards do
		local def = Characters.ById[card.characterId]
		if def and not seen[def.family] then
			seen[def.family] = true
			table.insert(out, def.family)
		end
	end
	table.sort(out)
	return out
end

-- A family gem with the family's icon on it.
local function familyGem(family: string, size: number, props: { [string]: any }): ImageLabel
	local gem = Kit.image(`gem_family_{string.lower(family)}`, props)
	gem.Size = UDim2.fromOffset(size, size)
	Ui.image(`family_{string.lower(family)}`, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		ImageColor3 = C.White,
		ZIndex = gem.ZIndex + 1,
		Parent = gem,
	})
	return gem
end

local function screen(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "CARDS", ctx.close, UDim2.fromOffset(880, 500), "icon_cards")
	-- the header's icon plate: fanned cards, not the bag (the bag is the Inventory)
	local oldIcon = p.header:FindFirstChild("Icon")
	if oldIcon then
		oldIcon:Destroy()
	end
	Kit.cardsIcon(50, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		ZIndex = 3,
		Parent = p.header,
	})
	local filter: Filter = { rarity = nil, family = nil, sort = "RARITY", query = "" }
	local page = 1
	local selected: string? = if arg then arg.uid else nil -- a card to open on
	local render: () -> ()

	-- Header: search, then the storage count with its gold "+".
	local storage = Ui.pricePill("0/0", "icon_cards", 36, {
		Name = "Storage",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -108, 0.5, 0),
		ZIndex = 3,
		Parent = p.header,
	})
	-- the pill's icon is the bag slot; storage counts cards, so it gets the fanned cards instead
	local pillIcon = storage:FindFirstChild("Icon", true)
	if pillIcon and pillIcon:IsA("ImageLabel") then
		pillIcon.ImageTransparency = 1
		Kit.cardsIcon(30, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = pillIcon.ZIndex + 1,
			Parent = pillIcon,
		})
	end
	local storageAmount = storage:FindFirstChild("Amount") :: TextLabel
	storageAmount.FontFace = Theme.Face.Display
	storageAmount.TextSize = 22
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
		local idx = (v.cardSlots - Economy.CardStorage.startSlots) // Economy.CardStorage.slotsPerExpansion
			+ 1
		local price = Economy.CardStorage.expansionPrices[idx]
		if price == nil then
			ctx.fail("StorageAtMax")
			return
		end
		ctx.confirm(
			"More card storage",
			`Add {Economy.CardStorage.slotsPerExpansion} card slots for {Format.number(price)} Coins?`,
			"Expand",
			function()
				if ctx.request("Cards.ExpandStorage", { requestId = ctx.guid() }).ok then
					Ui.sound("purchase")
				end
			end
		)
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
		if string.lower(search.Text) ~= filter.query then
			filter.query = string.lower(search.Text)
			page = 1
			render()
		end
	end)

	local left = Ui.frame({
		Name = "Collection",
		BackgroundTransparency = 1,
		Size = UDim2.new(0.56, -8, 1, 0),
		Parent = p.body,
	})
	local inspectBox = Ui.glowTile("Frame", {
		Name = "InspectBox",
		Position = UDim2.fromScale(0.56, 0),
		Size = UDim2.fromScale(0.44, 1),
		Parent = p.body,
	}, C.Purple, false)
	local inspect =
		Ui.frame({ Name = "Inspect", BackgroundTransparency = 1, ZIndex = 2, Parent = inspectBox })

	-- A chip: a painted pill (kit filter_chip_<tag>) with an optional gem or icon and a big word.
	local function chip(
		parent: Instance,
		name: string,
		tag: string,
		text: string,
		active: boolean,
		order: number,
		decorate: ((ImageButton) -> number)?,
		onClick: () -> ()
	): ImageButton
		local b: ImageButton = Ui.new("ImageButton", {
			Name = name,
			Image = Kit.id(`filter_chip_{tag}`),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(40, 24, 152, 40),
			SliceScale = 0.45,
			ImageTransparency = if active then 0 else 0.3,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 32),
			LayoutOrder = order,
			Parent = parent,
		}, { Ui.list(true, 4, Enum.HorizontalAlignment.Center) })
		local layout = b:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 9), Parent = b })
		if decorate then
			decorate(b)
		end
		local label = Ui.display({
			Name = "Label",
			Text = text,
			TextSize = 16,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			LayoutOrder = 2,
			ZIndex = 2,
			Parent = b,
		})
		label.TextColor3 = if active then C.White else C.Text
		if active then
			Ui.stroke(C.GoldHi, 2, 0).Parent = b
		end
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("tick")
			onClick()
		end)
		return b
	end

	local function renderChips()
		local rarityRow = Ui.frame({
			Name = "RarityChips",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 32),
			Parent = left,
		}, { Ui.list(true, 4) })
		for i, r in Rarities.Order do
			local rdef = Rarities.Defs[r]
			local active = filter.rarity == r
			chip(rarityRow, `Filter{r}`, rdef.tag, string.upper(rdef.displayName), active, i + 1, function(b)
				Kit.image(`corner_gem_{rdef.tag}`, {
					Name = "Gem",
					Size = UDim2.fromOffset(20, 20),
					LayoutOrder = 1,
					ZIndex = 2,
					Parent = b,
				})
				return 20
			end, function()
				filter.rarity = if active then nil else r
				page = 1
				render()
			end)
		end
		for _, b in rarityRow:GetChildren() do
			local label = b:FindFirstChild("Label")
			if label and label:IsA("TextLabel") then
				label.TextSize = 13 -- five chips share one row; the gem carries the colour
			end
		end
		local sortRow = Ui.frame({
			Name = "SortChips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 32),
			Parent = left,
		}, { Ui.list(true, 6) })
		local fam = filter.family
		chip(
			sortRow,
			"FilterFamily",
			"sr",
			if fam then string.upper(fam) else "ALL FAMILIES",
			fam ~= nil,
			1,
			function(b)
				if fam then
					familyGem(fam, 24, { Name = "Gem", LayoutOrder = 1, ZIndex = 2, Parent = b })
				else
					Ui.icon(
						"icon_check",
						22,
						{ AnchorPoint = Vector2.zero, LayoutOrder = 1, ZIndex = 2, Parent = b }
					)
				end
				return 24
			end,
			function()
				local owned = ownedFamilies(ctx.state.view)
				local at = if fam then table.find(owned, fam) else 0
				filter.family = owned[(at or 0) + 1] -- past the last family: back to all
				page = 1
				render()
			end
		)
		if filter.rarity or filter.family then
			chip(sortRow, "FilterAll", "n", "ALL", false, 0, nil, function()
				filter.rarity = nil
				filter.family = nil
				page = 1
				render()
			end)
		end
		chip(sortRow, "Sort", "ssr", `SORT: {filter.sort}`, false, 2, function(b)
			Ui.icon("icon_odds", 22, { AnchorPoint = Vector2.zero, LayoutOrder = 1, ZIndex = 2, Parent = b })
			return 22
		end, function()
			local at = table.find(SORTS, filter.sort) or 1
			filter.sort = SORTS[at % #SORTS + 1]
			page = 1
			render()
		end)
	end

	local function cardTile(parent: Instance, card: any, order: number)
		local def = Characters.ById[card.characterId]
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
			size = TILE,
			hover = true,
			bare = true,
			stats = false,
		})
		if selected == card.uid then
			Ui.stroke(C.GoldHi, 3).Parent = portrait
		end
		local lv = Ui.display({
			Name = "Level",
			Text = `LV{card.level}`,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 4),
			Size = UDim2.fromOffset(52, 22),
			ZIndex = 60,
			Parent = tile,
		})
		lv.TextColor3 = C.White
		familyGem(def.family, 26, {
			Name = "FamilyGem",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 2, 1, -24),
			ZIndex = 60,
			Parent = tile,
		})
		-- the power plate: the same number as the inspect panel (Power.stats)
		local plate =
			Ui.pricePill(Format.number(Power.stats(card.characterId, card.level).power), "icon_power", 24, {
				Name = "PowerPlate",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 2),
				ZIndex = 60,
				Parent = tile,
			})
		for _, d in plate:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = 61
			end
		end
		-- the sword, as on the big card's POWER row (the pill's own slot is a shield)
		local plateIcon = plate:FindFirstChild("Icon", true)
		if plateIcon and plateIcon:IsA("ImageLabel") then
			plateIcon.Image = Kit.id("icon_atk")
		end
		local slot = table.find(ctx.state.view.deck, card.uid)
		if slot then
			local mark = Ui.display({
				Name = "DeckSlot",
				Text = tostring(slot),
				TextSize = 18,
				BackgroundColor3 = C.Gold,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, 2, 1, -24),
				Size = UDim2.fromOffset(24, 24),
				ZIndex = 62,
				Parent = tile,
			})
			mark.TextColor3 = C.GoldInk
			Ui.corner(6).Parent = mark
		end
		tile.Activated:Connect(function()
			Ui.sound("tick")
			selected = card.uid
			render()
		end)
	end

	local function renderGrid()
		renderChips()
		local grid = Ui.frame({
			Name = "Grid",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.new(1, 0, 1, -128),
			Parent = left,
		})
		Ui.grid(TILE, 8).Parent = grid
		local cards = sortedCards(view, filter)
		local pages = math.max(1, math.ceil(#cards / PAGE_SIZE))
		page = math.clamp(page, 1, pages)
		for i = (page - 1) * PAGE_SIZE + 1, math.min(#cards, page * PAGE_SIZE) do
			cardTile(grid, cards[i], i)
		end
		if #cards == 0 then
			-- no cards: a big card fan and 1-2 big words in the middle (outside the grid layout)
			local empty = Ui.frame({
				Name = "Empty",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(360, 170),
				Parent = left,
			})
			Kit.cardsIcon(
				100,
				{ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = empty }
			)
			local words = Ui.display({
				Name = "Words",
				Text = if filter.query ~= ""
						or filter.rarity
						or filter.family
					then "NO MATCH"
					else "HATCH EGGS!",
				TextSize = 34,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.new(1, 0, 0, 44),
				Parent = empty,
			}, true)
			Ui.fit(words, 34, 20)
		end
		-- Bottom row: the big DECK shortcut, then the pager.
		local bottom = Ui.frame({
			Name = "Bottom",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 44),
			Parent = left,
		})
		local deck = Ui.button("DECK", "primary", function()
			ctx.open("Deck")
		end, { Name = "DeckButton", Size = UDim2.fromOffset(150, 44) })
		bigLabel(deck, 26)
		deck.instance.Parent = bottom
		Ui.icon("icon_deck", 34, {
			Position = UDim2.new(0, 6, 0.5, 0),
			ZIndex = 5,
			Parent = deck.instance,
		})
		local pager = Ui.frame({
			Name = "Pager",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(220, 44),
			Parent = bottom,
		}, { Ui.list(true, 8, Enum.HorizontalAlignment.Right) })
		local prev = Ui.button("◀", "secondary", function()
			page -= 1
			render()
		end, { Size = UDim2.fromOffset(48, 40), LayoutOrder = 1, Name = "Prev" })
		bigLabel(prev, 22)
		prev.setEnabled(page > 1)
		prev.instance.Parent = pager
		local pageLabel = Ui.display({
			Name = "Page",
			Text = `{page}/{pages}`,
			TextSize = 24,
			Size = UDim2.fromOffset(90, 40),
			LayoutOrder = 2,
			Parent = pager,
		}, true)
		pageLabel.TextXAlignment = Enum.TextXAlignment.Center
		local nextButton = Ui.button("▶", "secondary", function()
			page += 1
			render()
		end, { Size = UDim2.fromOffset(48, 40), LayoutOrder = 3, Name = "Next" })
		bigLabel(nextButton, 22)
		nextButton.setEnabled(page < pages)
		nextButton.instance.Parent = pager
		return cards
	end

	-- One stat row in the inspect panel: icon, word, big number.
	local function statRow(parent: Instance, icon: string, word: string, value: string, order: number)
		local row = Ui.frame({
			Name = word,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = order,
			Parent = parent,
		})
		Kit.image(icon, { Size = UDim2.fromOffset(30, 30), Parent = row })
		local t = Ui.display({
			Name = "Value",
			Text = `{word} <font color="#FFFFFF">{value}</font>`,
			RichText = true,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -38, 1, 0),
			Parent = row,
		})
		t.TextColor3 = Color3.fromHex("#9EAED3")
	end

	local function renderInspect(card: any?)
		Ui.clear(inspect)
		inspectBox.Visible = card ~= nil
		left.Size = if card then UDim2.new(0.56, -8, 1, 0) else UDim2.fromScale(1, 1)
		if card == nil then
			return
		end
		Ui.pad(10).Parent = inspect
		local v = ctx.state.view
		local def = Characters.ById[card.characterId]
		local rdef = Rarities.Defs[def.rarity]
		local st = Power.stats(card.characterId, card.level)
		local portrait = Card.build(inspect, {
			characterId = card.characterId,
			golden = card.golden,
			level = card.level,
			favorite = card.favorite,
			size = Vector2.new(150, 210),
			interactive = true,
		})
		portrait.Name = "InspectCard"
		portrait.Position = UDim2.fromOffset(0, 4)
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
			Position = UDim2.fromOffset(160, 0),
			Size = UDim2.new(1, -160, 0, 214),
			Parent = inspect,
		}, { Ui.list(false, 6) })
		-- the full display name, the same as on the card (BAD_GUI_9: one name everywhere)
		local name = Ui.display({
			Name = "Name",
			Text = def.displayName,
			TextSize = 26,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 58),
			LayoutOrder = 1,
			Parent = info,
		})
		name.TextColor3 = C.White
		Ui.fit(name, 26, 16)
		local tags = Ui.frame({
			Name = "Tags",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2,
			Parent = info,
		}, { Ui.list(true, 6) })
		Kit.image(
			`corner_gem_{rdef.tag}`,
			{ Name = "RarityGem", Size = UDim2.fromOffset(24, 24), Parent = tags }
		)
		local rarity = Ui.display({
			Name = "Rarity",
			Text = string.upper(if card.golden then `Golden {rdef.displayName}` else rdef.displayName),
			TextSize = 22,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			Parent = tags,
		})
		rarity.TextColor3 = rdef.colors[2]
		if card.paid then
			local paid = Ui.display({
				Name = "Paid",
				Text = "ROBUX",
				TextSize = 16,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				Parent = tags,
			})
			paid.TextColor3 = C.Purple
		end
		statRow(info, "icon_atk", "POWER", Format.number(st.power), 3)
		statRow(info, "icon_hp", "HEALTH", Format.number(st.hp), 4)
		-- the family bonus as a chip: family gem + "+2%" (two in a deck; three give +3%)
		local famDef = Families.Defs[def.family]
		local chipRow = Ui.frame({
			Name = "FamilyBonus",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 5,
			Parent = info,
		}, { Ui.list(true, 6) })
		familyGem(def.family, 30, { Name = "Gem", Parent = chipRow })
		local bonus = Ui.display({
			Name = "Bonus",
			Text = `+{math.floor(Families.SynergyBonus[2] * 100 + 0.5)}% {STAT_WORD[famDef.bonusStat] or famDef.bonusStat}`,
			TextSize = 22,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			Parent = chipRow,
		})
		bonus.TextColor3 = C.Green

		-- the Skill: icon + name, then its one-line effect at 20 px
		local skill = Ui.frame({
			Name = "Skill",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 222),
			Size = UDim2.new(1, 0, 0, 84),
			Parent = inspect,
		})
		Kit.image("icon_energy", { Size = UDim2.fromOffset(30, 30), Parent = skill })
		local skillName = Ui.display({
			Name = "SkillName",
			Text = string.upper(def.special.displayName),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -38, 0, 30),
			Parent = skill,
		})
		skillName.TextColor3 = C.GoldHi
		Ui.fit(skillName, 22, 16)
		local effect = Ui.text({
			Name = "Effect",
			Text = AbilityText.short(def.special),
			FontFace = Theme.Face.Title,
			TextSize = 20, -- never under 20 px (BAD_GUI_9); a long effect wraps to a second line
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 32),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = skill,
		})
		Ui.outline(C.Night, 1.5).Parent = effect

		-- EQUIP / UPGRADE / FAVORITE
		local actions = Ui.frame({
			Name = "Actions",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 46),
			Parent = inspect,
		}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
		-- spares of a character already at max level can be sold (the 4th, smaller button)
		local spareList = CardActions.spares(v, card)
		local hasMax = false
		for _, c in v.cards do
			if c.characterId == card.characterId and c.level >= Economy.Progression.maxLevel then
				hasMax = true
			end
		end
		local canSell = hasMax and #spareList > 0
		local wide = if canSell then 0.82 else 1
		local here = CardActions.inDeck(v, card.uid)
		local equip = Ui.button(if here then "EQUIPPED" else "EQUIP", "purple", function()
			if not here then
				CardActions.equip(ctx, card)
			end
		end, { LayoutOrder = 1, Size = UDim2.fromOffset(math.floor(118 * wide), 46), Name = "Equip" })
		bigLabel(equip, 20)
		equip.setEnabled(not card.locked)
		equip.instance.Parent = actions
		local plan = CardActions.mergePlan(v, card)
		local spares = if plan then #plan.use else 0
		local upgrade = Ui.button("UPGRADE", "primary", function()
			if plan == nil then
				ctx.fail("AlreadyMaxLevel")
			elseif spares == 0 then
				ctx.fail("NoSpares")
			else
				CardActions.merge(ctx, card)
			end
		end, { LayoutOrder = 2, Size = UDim2.fromOffset(math.floor(130 * wide), 46), Name = "Upgrade" })
		bigLabel(upgrade, 20)
		upgrade.setEnabled(spares > 0 and v.coins >= (plan and plan.fee or 0))
		upgrade.instance:SetAttribute("Spares", spares)
		upgrade.instance.Parent = actions
		if spares > 0 then
			local spareBadge = Ui.display({
				Name = "SpareCount",
				Text = tostring(spares),
				TextSize = 16,
				BackgroundColor3 = C.Red,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -4, 0, 4),
				Size = UDim2.fromOffset(24, 24),
				ZIndex = 8,
				Parent = upgrade.instance,
			})
			spareBadge.TextColor3 = C.White
			Ui.corner(12).Parent = spareBadge
		end
		local fav: ImageButton = Ui.new("ImageButton", {
			Name = "Favorite",
			Image = Kit.id(if card.favorite then "icon_favorite_on" else "icon_favorite_off"),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Size = UDim2.fromOffset(46, 46),
			Parent = actions,
		})
		Ui.juice(fav)
		fav.Activated:Connect(function()
			CardActions.setFavorite(ctx, card, not card.favorite)
		end)
		if canSell then
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
			end, { LayoutOrder = 4, Size = UDim2.fromOffset(72, 46), Name = "Sell" })
			bigLabel(sell, 18)
			sell.instance.Parent = actions
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
		local cards = renderGrid()
		if selected == nil and cards[1] then
			selected = cards[1].uid
		end
		local card = if selected then view.cards[selected] else nil
		renderInspect(card)
		local grid = left:FindFirstChild("Grid")
		if grid and card == nil then
			-- no inspect panel: the grid fills the space
			(grid :: any).Size = UDim2.new(1, 0, 1, -128)
		end
	end

	render()
	local firstGrid = left:FindFirstChild("Grid")
	if firstGrid then
		Ui.stagger(firstGrid, ctx.reducedMotion())
	end
	return { destroy = function() end, refresh = render }
end

return screen
