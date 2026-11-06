--!strict
-- Collection: every card copy, filters by rarity, the card inspect panel (stats, Special,
-- passive, level and merge progress), merge, sell spares and storage expansion; plus the item
-- inventory. Every action is a request: the server re-checks ownership, deck use and prices.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Items = require(Shared.Config.Items)
local Power = require(Shared.Domain.Power)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)

local C = Theme.Color
local RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

local function sortedCards(view: any, filter: string?): { any }
	local out = {}
	for _, card in view.cards do
		local def = Characters.ById[card.characterId]
		if def and (filter == nil or def.rarity == filter) then
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

return function(ctx: any, layer: Frame, _arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Collection", ctx.close, UDim2.fromOffset(820, 470))
	local tab = "Cards"
	local filter: string? = nil
	local selected: string? = nil

	local header = Ui.frame(
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = p.body },
		{ Ui.list(true, 6) }
	)
	local left = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.6, -8, 1, -40),
		Parent = p.body,
	})
	local inspect = Ui.frame({
		BackgroundColor3 = C.Raised,
		Position = UDim2.new(0.6, 0, 0, 40),
		Size = UDim2.new(0.4, 0, 1, -40),
		Parent = p.body,
	}, { Ui.corner(12), Ui.stroke(C.Purple, 1.5, 0.3), Ui.pad(10) })

	local render: () -> ()

	local function renderInspect()
		Ui.clear(inspect)
		local card = selected and view.cards[selected]
		if tab ~= "Cards" or card == nil then
			Ui.text({
				Text = if tab == "Cards"
					then "Pick a card to inspect it."
					else "Sell items at any world's merchant.",
				TextColor3 = C.Muted,
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Parent = inspect,
			})
			return
		end
		local def = Characters.ById[card.characterId]
		local portrait = Visuals.portrait(inspect, card.characterId, card.golden, Vector2.new(110, 150))
		portrait.Position = UDim2.fromOffset(0, 0)
		local info = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(120, 0),
			Size = UDim2.new(1, -120, 0, 150),
			Parent = inspect,
		}, { Ui.list(false, 2) })
		Ui.text({
			Text = def.displayName,
			Font = Theme.Font.Title,
			TextSize = 18,
			LayoutOrder = 1,
			Parent = info,
		})
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
			Font = Theme.Font.Bold,
			LayoutOrder = 3,
			Parent = info,
		})
		Ui.text({
			Text = `HP {stats.hp}  ATK {stats.atk}  DEF {stats.def}  SPD {stats.spd}`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			LayoutOrder = 4,
			Parent = info,
		})
		local need = Economy.Progression.mergePointsToNext[card.level]
		if need then
			Ui.text({
				Text = `Merge points {card.mergePoints}/{need}`,
				TextSize = Theme.Size.small,
				LayoutOrder = 5,
				Parent = info,
			})
			local setBar = Ui.bar(info, C.Purple, { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 8) })
			setBar(card.mergePoints / need)
		end
		if card.paid then
			Ui.text({
				Text = "From a Robux egg",
				TextSize = Theme.Size.small,
				TextColor3 = C.Purple,
				LayoutOrder = 7,
				Parent = info,
			})
		end
		Ui.text({
			Text = `Special: {def.special.displayName} ({def.special.cost} energy)\nPassive: {def.passive.displayName}: {def.passive.description}`,
			TextSize = Theme.Size.small,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(0, 156),
			Size = UDim2.new(1, 0, 0, 52),
			Parent = inspect,
		})
		local actions = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 212),
			Size = UDim2.new(1, 0, 1, -212),
			Parent = inspect,
		}, { Ui.list(false, 6) })
		local spareList = spares(view, card)
		if need then
			local per = Rarities.Defs[def.rarity].mergePoints
			local wanted = math.max(1, math.ceil((need - card.mergePoints) / per))
			local use = {}
			for i = 1, math.min(wanted, #spareList) do
				use[i] = spareList[i]
			end
			local fee = Economy.Progression.coinFeeToNext[card.level]
			local merge = Ui.button(
				`Merge {#use} spare{if #use == 1 then "" else "s"} · 💰 {Format.number(fee)}`,
				"primary",
				function()
					local reply = ctx.request(
						"Cards.Merge",
						{ targetUid = card.uid, spareUids = use, requestId = ctx.guid() }
					)
					if reply.ok then
						ctx.toast(`{def.displayName} is now level {reply.value.toLevel}!`, "good")
					end
				end,
				{ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 36), Name = "Merge" }
			)
			merge.setEnabled(#use > 0 and view.coins >= fee)
			merge.instance.Parent = actions
		end
		local hasMax = false
		for _, c in view.cards do
			if c.characterId == card.characterId and c.level >= Economy.Progression.maxLevel then
				hasMax = true
			end
		end
		if hasMax and #spareList > 0 then
			local price = Economy.CardSale[def.rarity] or 0
			local sell = Ui.button(
				`Sell {#spareList} spare(s) · 💰 {Format.number(price * #spareList)}`,
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
				{ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 32) }
			)
			sell.instance.Parent = actions
		end
		Ui.text({
			Text = if inDeck(view, card.uid)
				then "In your deck"
				else `{#spareList} spare cop{if #spareList == 1 then "y" else "ies"}`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			LayoutOrder = 3,
			Parent = actions,
		})
	end

	local function renderCards()
		local grid =
			Ui.scroll({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), Parent = left })
		Ui.grid(Vector2.new(88, 120), 8).Parent = grid
		local filters = Ui.frame(
			{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28), Parent = left },
			{ Ui.list(true, 4) }
		)
		local all = { "All" }
		for _, r in RARITY_ORDER do
			table.insert(all, r)
		end
		for i, name in all do
			local active = (filter == nil and name == "All") or filter == name
			local b = Ui.button(name, if active then "purple" else "ghost", function()
				filter = if name == "All" then nil else name
				render()
			end, {
				Size = UDim2.fromOffset(if name == "Legendary" then 82 else 66, 28),
				LayoutOrder = i,
				TextSize = 12,
			})
			b.instance.Parent = filters
		end
		for i, card in sortedCards(view, filter) do
			local tile = Ui.new("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Name = card.uid,
				Parent = grid,
			})
			local portrait = Visuals.portrait(tile, card.characterId, card.golden, Vector2.new(88, 104))
			if selected == card.uid then
				Ui.stroke(C.Text, 3).Parent = portrait
			end
			Ui.text({
				Text = `Lv {card.level}{if inDeck(view, card.uid) then " · ⚔" else ""}`,
				Font = Theme.Font.Bold,
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
	end

	local function renderItems()
		local list = Ui.scroll({ Parent = left })
		Ui.list(false, 6).Parent = list
		for i, stack in view.items.stacks do
			local item = Items.ById[stack.itemId]
			local row = Ui.frame(
				{ Size = UDim2.new(1, -8, 0, 40), LayoutOrder = i, Parent = list },
				{ Ui.corner(8), Ui.pad(8) }
			)
			Ui.text({
				Text = `{item.displayName}  ×{stack.count}`,
				Font = Theme.Font.Bold,
				Size = UDim2.fromScale(0.6, 1),
				Parent = row,
			})
			Ui.text({
				Text = `💰 {item.sellPrice} each · World {item.world}`,
				TextSize = Theme.Size.small,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.6, 0),
				Size = UDim2.fromScale(0.4, 1),
				Parent = row,
			})
		end
		if #view.items.stacks == 0 then
			Ui.text({
				Text = "No items yet. Harvest resource nodes in your world.",
				TextColor3 = C.Muted,
				Parent = list,
			})
		end
	end

	local function renderHeader()
		Ui.clear(header)
		local cardsTab = Ui.button(
			`Cards {count(view.cards)}/{view.cardSlots}`,
			if tab == "Cards" then "purple" else "ghost",
			function()
				tab = "Cards"
				render()
			end,
			{ Size = UDim2.fromOffset(150, 30), LayoutOrder = 1 }
		)
		cardsTab.instance.Parent = header
		local itemsTab = Ui.button(
			`Items {#view.items.stacks}/{view.items.slots}`,
			if tab == "Items" then "purple" else "ghost",
			function()
				tab = "Items"
				render()
			end,
			{ Size = UDim2.fromOffset(130, 30), LayoutOrder = 2 }
		)
		itemsTab.instance.Parent = header
		if tab == "Cards" then
			local idx = (view.cardSlots - Economy.CardStorage.startSlots)
					// Economy.CardStorage.slotsPerExpansion
				+ 1
			local price = Economy.CardStorage.expansionPrices[idx]
			if price then
				local b = Ui.button(
					`+{Economy.CardStorage.slotsPerExpansion} slots · 💰 {Format.number(price)}`,
					"ghost",
					function()
						ctx.confirm(
							"Expand card storage",
							`Add {Economy.CardStorage.slotsPerExpansion} card slots for {Format.number(price)} Coins?`,
							"Expand",
							function()
								ctx.request("Cards.ExpandStorage", { requestId = ctx.guid() })
							end
						)
					end,
					{ Size = UDim2.fromOffset(190, 30), LayoutOrder = 3, TextSize = 13 }
				)
				b.instance.Parent = header
			end
		else
			local idx = (view.items.slots - Economy.ItemInventory.startSlots)
					// Economy.ItemInventory.slotsPerExpansion
				+ 1
			local price = Economy.ItemInventory.expansionPrices[idx]
			if price then
				local b = Ui.button(`+1 slot · 💰 {Format.number(price)}`, "ghost", function()
					ctx.confirm(
						"Expand inventory",
						`Add an item slot for {Format.number(price)} Coins?`,
						"Expand",
						function()
							ctx.request("Inventory.Expand", { requestId = ctx.guid() })
						end
					)
				end, { Size = UDim2.fromOffset(160, 30), LayoutOrder = 3, TextSize = 13 })
				b.instance.Parent = header
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
		if tab == "Cards" then
			renderCards()
		else
			renderItems()
		end
		renderInspect()
	end

	render()
	return { destroy = function() end, refresh = render }
end
