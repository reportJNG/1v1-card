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

local function inDeck(view: any, uid: string): boolean
	return table.find(view.deck, uid) ~= nil
end

-- Level-1, never-merged spares of the same character, not in the deck or locked.
local function spares(view: any, target: any): { string }
	local out = {}
	for _, c in view.cards do
		if
			c.uid ~= target.uid
			and c.characterId == target.characterId
			and c.level == 1
			and c.mergePoints == 0
			and not c.locked
			and not inDeck(view, c.uid)
		then
			table.insert(out, c.uid)
		end
	end
	table.sort(out)
	return out
end

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

-- The deck after equipping `card`: it replaces a copy of the same character, else takes an empty
-- slot, else the weakest card's place. A deck is always 3 different characters, so an incomplete
-- deck is filled with the strongest other characters owned. Nil when there aren't 3 different
-- characters yet. The server validates the result (Deck.Set).
local function equipped(view: any, card: any): { string }?
	local deck: { string } = {}
	local used: { [string]: boolean } = { [card.characterId] = true }
	for _, uid in view.deck do
		local other = view.cards[uid]
		if other and not used[other.characterId] then
			used[other.characterId] = true
			table.insert(deck, uid)
		end
	end
	if #deck >= 3 then
		local weakest, weakestPower = 1, math.huge
		for i, uid in deck do
			local other = view.cards[uid]
			local pw = Power.card(other.characterId, other.level)
			if pw < weakestPower then
				weakest, weakestPower = i, pw
			end
		end
		table.remove(deck, weakest)
	end
	table.insert(deck, 1, card.uid)
	if #deck < 3 then
		local pool = {}
		for _, c in view.cards do
			if not used[c.characterId] and not c.locked then
				table.insert(pool, c)
			end
		end
		table.sort(pool, function(a, b)
			return Power.card(a.characterId, a.level) > Power.card(b.characterId, b.level)
		end)
		for _, c in pool do
			if #deck >= 3 then
				break
			end
			if not used[c.characterId] then
				used[c.characterId] = true
				table.insert(deck, c.uid)
			end
		end
	end
	return if #deck == 3 then deck else nil
end

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Inventory", ctx.close, UDim2.fromOffset(800, 480), "icon_cards")
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
		Size = UDim2.new(0.56, -72, 1, 0),
		Parent = p.body,
	})
	-- The glow frame stays; renderInspect clears only the content inside it.
	local inspectBox = Ui.glowTile("Frame", {
		Name = "InspectBox",
		Position = UDim2.fromScale(0.56, 0),
		Size = UDim2.fromScale(0.44, 1),
		Parent = p.body,
	}, C.Purple, false)
	local inspect = Ui.frame(
		{ Name = "Inspect", BackgroundTransparency = 1, ZIndex = 2, Parent = inspectBox },
		{ Ui.pad(10) }
	)

	local render: () -> ()

	local function renderInspect()
		Ui.clear(inspect)
		local card = selected and view.cards[selected]
		if card == nil then
			Ui.text({
				Text = if tab == "Items"
					then "Sell items at any world's merchant."
					elseif tab == "Eggs" then "Open eggs from your bag: each one hatches a card."
					else "Pick a card to inspect it.",
				TextColor3 = C.Muted,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = inspect,
			})
			return
		end
		local def = Characters.ById[card.characterId]
		local portrait =
			Visuals.portrait(inspect, card.characterId, card.golden, Vector2.new(150, 210), true, card.level)
		portrait.Name = "InspectCard"
		portrait.Position = UDim2.fromOffset(0, 0)
		local info = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(158, 0),
			Size = UDim2.new(1, -158, 0, 210),
			Parent = inspect,
		}, { Ui.list(false, 3) })
		local name = Ui.text({
			Text = def.displayName,
			FontFace = Theme.Face.Title,
			TextSize = 18,
			TextWrapped = false,
			LayoutOrder = 1,
			Parent = info,
		})
		Ui.fit(name, 18, 11)
		Ui.text({
			Text = `{def.rarity} · {def.family} · {def.role}`,
			TextSize = Theme.Size.small,
			TextColor3 = Theme.Rarity[def.rarity],
			LayoutOrder = 2,
			Parent = info,
		})
		local stats = Power.deck({ { characterId = card.characterId, level = card.level } }).units[1]
		Ui.text({
			Text = `Level {card.level}/{Economy.Progression.maxLevel} · Power {stats.power}`,
			FontFace = Theme.Face.Bold,
			LayoutOrder = 3,
			Parent = info,
		})
		local grid = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 40),
			LayoutOrder = 4,
			Parent = info,
		}, { Ui.grid(Vector2.new(68, 18), 2) })
		local statCells: { { label: string, value: number } } = {
			{ label = "HP", value = stats.hp },
			{ label = "ATK", value = math.floor(stats.atk + 0.5) },
			{ label = "DEF", value = math.floor(stats.def + 0.5) },
			{ label = "SPD", value = math.floor(stats.spd + 0.5) },
		}
		for _, pair in statCells do
			Ui.text({
				Text = `{pair.label} {pair.value}`,
				FontFace = Theme.Face.Number,
				TextSize = 13,
				TextColor3 = C.Text,
				Parent = grid,
			})
		end
		local famDef = Families.Defs[def.family]
		Ui.text({
			Name = "FamilyBonus",
			Text = `{def.family} family: with 2 / 3 in your deck, +2% / +3% {STAT_NAME[famDef.bonusStat] or famDef.bonusStat}`,
			TextSize = 12,
			TextColor3 = C.Purple,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 5,
			Parent = info,
		})
		local need = Economy.Progression.mergePointsToNext[card.level]
		if need then
			Ui.text({
				Text = `Merge points {card.mergePoints}/{need}`,
				TextSize = Theme.Size.small,
				LayoutOrder = 6,
				Parent = info,
			})
			local setBar = Ui.bar(info, C.Purple, { LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 8) })
			setBar(card.mergePoints / need)
		end
		if card.paid then
			Ui.text({
				Text = "From a Robux egg",
				TextSize = Theme.Size.small,
				TextColor3 = C.Purple,
				LayoutOrder = 8,
				Parent = info,
			})
		end
		Ui.text({
			Text = `Special: {def.special.displayName} ({def.special.cost} energy)\nPassive: {def.passive.displayName}: {def.passive.description}`,
			TextSize = Theme.Size.small,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 216),
			Size = UDim2.new(1, 0, 0, 44),
			Parent = inspect,
		})
		local actions = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 264),
			Size = UDim2.new(1, 0, 1, -264),
			Parent = inspect,
		}, { Ui.list(false, 6) })
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = 1,
			Parent = actions,
		}, { Ui.list(true, 6) })
		local spareList = spares(view, card)
		if need then
			local per = Rarities.Defs[def.rarity].mergePoints
			local wanted = math.max(1, math.ceil((need - card.mergePoints) / per))
			local use = {}
			for i = 1, math.min(wanted, #spareList) do
				use[i] = spareList[i]
			end
			local fee = Economy.Progression.coinFeeToNext[card.level]
			local merge = Ui.button(`Merge {#use} · {Format.number(fee)} Coins`, "primary", function()
				local reply = ctx.request(
					"Cards.Merge",
					{ targetUid = card.uid, spareUids = use, requestId = ctx.guid() }
				)
				if reply.ok then
					Ui.sound("merge")
					if reply.value.toLevel > card.level then
						task.delay(0.4, Ui.sound, "level_up")
					end
					ctx.toast(`{def.displayName} is now level {reply.value.toLevel}!`, "good")
				end
			end, { LayoutOrder = 1, Size = UDim2.fromOffset(170, 36), Name = "Merge", TextSize = 14 })
			merge.setEnabled(#use > 0 and view.coins >= fee)
			merge.instance.Parent = row
		end
		local here = inDeck(view, card.uid)
		local equip = Ui.button(if here then "Equipped" else "Equip", "secondary", function()
			local deck = equipped(view, card)
			if deck == nil then
				ctx.toast("A deck needs 3 different characters: hatch more eggs first.", "error")
				return
			end
			local reply = ctx.request("Deck.Set", { uids = deck })
			if reply.ok then
				ctx.toast(`{def.displayName} is in your deck.`, "good")
			end
		end, { LayoutOrder = 2, Size = UDim2.fromOffset(150, 36), Name = "Equip", TextSize = 14 })
		equip.setEnabled(not here and not card.locked)
		equip.instance.Parent = row
		local hasMax = false
		for _, c in view.cards do
			if c.characterId == card.characterId and c.level >= Economy.Progression.maxLevel then
				hasMax = true
			end
		end
		if hasMax and #spareList > 0 then
			local price = Economy.CardSale[def.rarity] or 0
			local sell = Ui.button(
				`Sell {#spareList} spare(s) · {Format.number(price * #spareList)} Coins`,
				"ghost",
				function()
					ctx.confirm(
						"Sell spares",
						`Sell {#spareList} spare {def.displayName} copies?`,
						"Sell",
						function()
							ctx.request("Cards.Sell", { uids = spareList, requestId = ctx.guid() })
						end
					)
				end,
				{ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 30) }
			)
			sell.instance.Parent = actions
		end
		Ui.text({
			Text = if here
				then "In your deck"
				else `{#spareList} spare cop{if #spareList == 1 then "y" else "ies"} · max level copies sell spares`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			LayoutOrder = 3,
			Parent = actions,
		})
	end

	local function cardTile(parent: Instance, card: any, order: number)
		local tile = Ui.new("TextButton", {
			Text = "",
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Name = card.uid,
			Parent = parent,
		})
		local portrait =
			Visuals.portrait(tile, card.characterId, card.golden, Vector2.new(88, 104), false, card.level)
		if selected == card.uid then
			Ui.stroke(C.Text, 3).Parent = portrait
		end
		Ui.text({
			Text = `Lv {card.level}{if inDeck(view, card.uid) then " · In deck" else ""}`,
			FontFace = Theme.Face.Bold,
			TextSize = Theme.Size.small,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = tile,
		})
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
			FontFace = Theme.Face.Bold,
			TextSize = 11,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(2, 60),
			Size = UDim2.new(1, -4, 0, 14),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.fit(label, 11, 8)
		local golden = entry.golden
		local open = Ui.button(`Open ×{entry.count}`, if golden then "primary" else "success", function()
			local known = Hatch.known(ctx.state.view)
			local reply = ctx.request("Bag.OpenEgg", { eggId = entry.egg.id, golden = golden })
			if reply.ok then
				Hatch.show(ctx, reply.value.cards, entry.egg, golden, { known = known })
			end
		end, {
			Name = "Open",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, -10, 0, 26),
			TextSize = 12,
			ZIndex = 2,
		})
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
		local name = Ui.text({
			Text = item.displayName,
			FontFace = Theme.Face.Bold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 10),
			Size = UDim2.new(1, -8, 0, 34),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.fit(name, 12, 8)
		Ui.text({
			Text = `×{stack.count}`,
			FontFace = Theme.Face.Number,
			TextSize = 20,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 46),
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.text({
			Text = `{item.sellPrice} Coins each`,
			TextSize = 11,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 76),
			Size = UDim2.new(1, 0, 0, 14),
			ZIndex = 2,
			Parent = tile,
		})
		Ui.text({
			Text = `World {item.world}`,
			TextSize = 11,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 92),
			Size = UDim2.new(1, 0, 0, 14),
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
			local all = { "All" }
			for _, r in RARITY_ORDER do
				table.insert(all, string.sub(r, 1, 4))
			end
			for i, short in all do
				local full = if short == "All" then nil else RARITY_ORDER[i - 1]
				local active = filter == full
				local b = Ui.button(short, if active then "purple" else "ghost", function()
					filter = full
					page = 1
					render()
				end, {
					Size = UDim2.fromOffset(40, 28),
					LayoutOrder = i,
					TextSize = 11,
					Name = `Filter{short}`,
				})
				b.instance.Parent = filters
			end
		end
		local search: TextBox = Ui.new("TextBox", {
			Name = "Search",
			Text = query,
			PlaceholderText = "Search…",
			ClearTextOnFocus = false,
			FontFace = Theme.Face.Bold,
			TextSize = 13,
			TextColor3 = C.Text,
			PlaceholderColor3 = C.Muted,
			BackgroundColor3 = C.PanelDeep,
			Size = UDim2.fromOffset(if tab == "Cards" or tab == "All" then 100 else 280, 28),
			LayoutOrder = 10,
			Parent = filters,
		}, { Ui.corner(8), Ui.stroke(C.Stroke, 1), Ui.pad(6) })
		search.FocusLost:Connect(function()
			if search.Text ~= query then
				query = string.lower(search.Text)
				page = 1
				render()
			end
		end)

		local grid =
			Ui.scroll({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -72), Parent = left })
		Ui.grid(Vector2.new(88, 120), 8).Parent = grid
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
				Position = UDim2.new(0, 0, 1, -32),
				Size = UDim2.new(1, 0, 0, 30),
				Parent = left,
			}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
			local prev = Ui.button("<", "ghost", function()
				page -= 1
				render()
			end, { Size = UDim2.fromOffset(40, 28), LayoutOrder = 1 })
			prev.setEnabled(page > 1)
			prev.instance.Parent = pager
			Ui.text({
				Text = `Page {page}/{pages} · {#cards} cards`,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromOffset(170, 28),
				LayoutOrder = 2,
				Parent = pager,
			})
			local nextButton = Ui.button(">", "ghost", function()
				page += 1
				render()
			end, { Size = UDim2.fromOffset(40, 28), LayoutOrder = 3 })
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
				TextColor3 = C.Muted,
				Size = UDim2.new(1, 0, 0, 40),
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
		Ui.display({
			Text = label,
			TextSize = 11,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 1),
			Size = UDim2.new(1, 4, 0, 13),
			ZIndex = 3,
			Parent = b,
		})
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
