--!strict
-- Egg Shop (MISSION 7.2, boards `ui-refs-2/01` and `ui-refs/hd-02`). Every egg of the Egg Icon
-- Pack (unedited) stands on its tier pedestal in one scrollable row grouped by world: a label pill
-- in the tier colour, a price pill, an idle bob and a glow, and a "World N" lock when locked. The
-- selected egg rises and its ring brightens; the details below show its name and tier, "Drops X
-- up to Y · see Odds" (its real top rarity), the price, the gold Open x1 / x3 / x8 buttons, Odds
-- (exact % per character from Shared/Domain/Odds, the table the server rolls from), Auto-open, and
-- the Robux buttons only while the server says PaidRandomItemsAllowed = true (it re-checks every
-- offer and every receipt). The Egg Bag tab lists owned eggs with counts, Golden markers and Open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Eggs = require(Shared.Config.Eggs)
local Rarities = require(Shared.Config.Rarities)
local Worlds = require(Shared.Config.Worlds)
local Monetization = require(Shared.Config.Monetization)
local Progress = require(Shared.Domain.Progress)
local HatchRules = require(Shared.Domain.Hatch)
local Odds = require(Shared.Domain.Odds)
local EggTiers = require(Shared.Config.EggTiers)
local RunService = game:GetService("RunService")
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local Hatch = require(script.Parent.Hatch)
local OddsPopup = require(script.Parent.OddsPopup)
local Kit = require(App.Kit)

local C = Theme.Color

local RARITY_ORDER = { "Mythical", "Legendary", "Epic", "Rare", "Common" }

-- The most common rarity this egg can drop (from Shared/Domain/Odds, like the roll).
local function lowestRarity(egg: Types.EggDef): string
	local odds = Odds.forEgg(egg, false)
	for i = #RARITY_ORDER, 1, -1 do
		if (odds.rarities[RARITY_ORDER[i]] or 0) > 0 then
			return RARITY_ORDER[i]
		end
	end
	return "Common"
end

-- The rarest rarity this egg can drop.
local function bestRarity(egg: Types.EggDef): string
	local odds = Odds.forEgg(egg, false)
	for _, r in RARITY_ORDER do
		if (odds.rarities[r] or 0) > 0 then
			return r
		end
	end
	return "Common"
end

local function robuxProducts(eggId: string): { Types.RobuxEggProduct }
	local out = {}
	for _, product in Monetization.RobuxEggs do
		if product.eggId == eggId then
			table.insert(out, product)
		end
	end
	table.sort(out, function(a, b)
		return a.quantity < b.quantity
	end)
	return out
end

local TIER_KEY: { [string]: string } = {
	Common = "common",
	Rare = "rare",
	Epic = "epic",
	Legendary = "legendary",
	Mythical = "godtier",
}

local CELL = Vector2.new(112, 176)

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Egg Shop", ctx.close, UDim2.fromOffset(820, 470), "icon_shop")
	Ui.subtitle(p, "Collect Powerful Eggs")
	local today = ctx.now() // 86400
	local tab = if arg and arg.tab == "Bag" then "Bag" else "Eggs"
	local startWorld: number = if arg and arg.world
		then arg.world
		else (if view then view.currentWorld else 1)
	local selectedEgg: Types.EggDef? = nil
	local bobbing: { { obj: GuiObject, base: UDim2, phase: number } } = {}

	local function owned(eggId: string): (number, number)
		local stack = view and view.eggBag[eggId]
		return if stack then stack.normal else 0, if stack then stack.golden else 0
	end

	local function freeSlots(): number
		local v = ctx.state.view
		if v == nil then
			return 0
		end
		local n = 0
		for _ in v.cards do
			n += 1
		end
		return v.cardSlots - n
	end

	-- Buys `count` with Coins. The first call always asks the server (which explains a refusal);
	-- auto-open repeats only while the batch is affordable and fits.
	local function buyCoins(egg: Types.EggDef, count: number)
		local price = (egg.coinPrice :: number) * count
		local function once(first: boolean): { any }?
			local v = ctx.state.view
			if not first and (v == nil or v.coins < price or freeSlots() < count) then
				return nil
			end
			local reply =
				ctx.request("Shop.BuyEgg", { eggId = egg.id, requestId = ctx.guid(), count = count })
			if reply.ok then
				Ui.sound("purchase")
			end
			return if reply.ok then reply.value.cards else nil
		end
		local known = Hatch.known(ctx.state.view)
		local cards = once(true)
		if cards then
			Hatch.show(ctx, cards, egg, false, {
				known = known,
				again = function()
					return once(false)
				end,
			})
		end
	end

	-- Opens up to `qty` from the Egg Bag (as many as the stack and storage allow).
	local function openBag(egg: Types.EggDef, golden: boolean, qty: number)
		local function once(first: boolean): { any }?
			local v = ctx.state.view
			local stack = v and v.eggBag[egg.id]
			local have = if stack then (if golden then stack.golden else stack.normal) else 0
			local k = Hatch.fit(qty, math.min(have, freeSlots()))
			if k == 0 then
				if not first then
					return nil
				end
				k = 1
			end
			local reply = ctx.request("Bag.OpenEgg", { eggId = egg.id, golden = golden, count = k })
			return if reply.ok then reply.value.cards else nil
		end
		local known = Hatch.known(ctx.state.view)
		local cards = once(true)
		if cards then
			Hatch.show(ctx, cards, egg, golden, {
				known = known,
				again = function()
					return once(false)
				end,
			})
		end
	end

	-- Tabs: Eggs and Egg Bag.
	local tabs = Ui.frame({
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		Parent = p.body,
	}, { Ui.list(true, 8) })
	local content = Ui.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		Parent = p.body,
	})

	local render: () -> ()

	-- One egg on its tier pedestal (the egg image is never changed: glow and pedestal sit around it).
	local function eggCell(parent: Instance, egg: Types.EggDef, order: number, worldLocked: boolean)
		local tier = EggTiers.of(egg)
		local rdef = Rarities.Defs[tier]
		local selected = selectedEgg == egg
		local cell: TextButton = Ui.new("TextButton", {
			Name = egg.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CELL.X, CELL.Y),
			LayoutOrder = order,
			Parent = parent,
		})
		local pedestal = Kit.image(`pedestal_{TIER_KEY[tier]}`, {
			Name = "Pedestal",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, 118),
			Size = UDim2.fromOffset(108, 54),
			ImageTransparency = if selected then 0 else 0.15,
			Parent = cell,
		})
		if selected then
			Kit.image("fx_mote", {
				Name = "RingGlow",
				ImageColor3 = rdef.colors[4],
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.35),
				Size = UDim2.fromScale(1.4, 0.9),
				ScaleType = Enum.ScaleType.Stretch,
				ZIndex = 0,
				Parent = pedestal,
			})
		end
		local glow = Ui.image("egg_glow", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CELL.X / 2, 58),
			Size = UDim2.fromOffset(120, 120),
			ImageColor3 = rdef.colors[4],
			ImageTransparency = if selected then 0.15 else 0.45,
			Parent = cell,
		})
		glow.ZIndex = 1
		local icon = Visuals.egg(cell, egg, false, 84)
		icon.AnchorPoint = Vector2.new(0.5, 1)
		local base = UDim2.fromOffset(CELL.X / 2, if selected then 90 else 98) -- the selected egg rises
		icon.Position = base
		icon.ZIndex = 2
		table.insert(bobbing, { obj = icon, base = base, phase = order * 0.9 })
		-- Label pill (tier colour) and price pill.
		local label = Ui.text({
			Name = "Label",
			Text = egg.displayName,
			FontFace = Theme.Face.Title,
			TextSize = 13,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundColor3 = Color3.fromHex("#0B0720"),
			BackgroundTransparency = 0.1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(CELL.X / 2, 122),
			Size = UDim2.fromOffset(CELL.X - 4, 22),
			ZIndex = 3,
			Parent = cell,
		})
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = label })
		Ui.stroke(rdef.colors[2], 2, 0).Parent = label
		Ui.fit(label, 13, 8)
		if egg.coinPrice then
			Ui.pricePill(Format.short(egg.coinPrice), "icon_coin", 22, {
				Name = "Price",
				Position = UDim2.fromOffset(CELL.X / 2, 160),
				ZIndex = 3,
				Parent = cell,
			})
		else
			Ui.text({
				Text = "Event",
				FontFace = Theme.Face.Bold,
				TextColor3 = C.Green,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 148),
				Size = UDim2.new(1, 0, 0, 20),
				ZIndex = 3,
				Parent = cell,
			})
		end
		if worldLocked then
			local lock = Ui.frame({
				Name = "Lock",
				BackgroundColor3 = Color3.fromHex("#05040F"),
				BackgroundTransparency = 0.45,
				Size = UDim2.fromOffset(CELL.X, 120),
				ZIndex = 5,
				Parent = cell,
			}, { Ui.corner(12) })
			Kit.image("lock_overlay", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromOffset(46, 46),
				ZIndex = 6,
				Parent = lock,
			})
			local w = Ui.text({
				Text = if egg.world then `World {egg.world}` else "Event",
				FontFace = Theme.Face.Title,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0.66),
				Size = UDim2.fromOffset(90, 18),
				ZIndex = 6,
				Parent = lock,
			})
			Ui.outline(C.Night, 1.5).Parent = w
		end
		Ui.juice(cell)
		cell.Activated:Connect(function()
			Ui.sound("tick")
			selectedEgg = egg
			render()
		end)
	end

	-- The selected egg's details (bottom).
	local function renderDetail(box: Frame, egg: Types.EggDef)
		local available = view ~= nil and Progress.isEggAvailable(view :: any, egg)
		local tier = EggTiers.of(egg)
		local rdef = Rarities.Defs[tier]
		local stage = Ui.frame({
			Name = "Stage",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(150, 150),
			Parent = box,
		})
		Kit.image(`pedestal_{TIER_KEY[tier]}`, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(140, 70),
			Parent = stage,
		})
		Ui.image("light_rays", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(170, 170),
			ImageColor3 = rdef.colors[4],
			ImageTransparency = 0.55,
			Parent = stage,
		})
		local big = Visuals.egg(stage, egg, false, 110)
		big.AnchorPoint = Vector2.new(0.5, 1)
		local bigBase = UDim2.new(0.5, 0, 1, -30)
		big.Position = bigBase
		big.ZIndex = 2
		table.insert(bobbing, { obj = big, base = bigBase, phase = 0 })

		local info = Ui.frame({
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(160, 6),
			Size = UDim2.new(1, -160 - 270, 1, -12),
			Parent = box,
		}, { Ui.list(false, 4) })
		local name = Ui.display({
			Name = "Name",
			Text = egg.displayName,
			TextSize = 26,
			TextColor3 = rdef.colors[1]:Lerp(C.White, 0.3),
			TextWrapped = false,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 1,
			Parent = info,
		})
		Ui.fit(name, 26, 12)
		local tierPill = Ui.text({
			Name = "Tier",
			Text = `{rdef.displayName} egg`,
			FontFace = Theme.Face.Title,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundColor3 = Color3.fromHex("#0B0720"),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			LayoutOrder = 2,
			Parent = info,
		})
		Ui.pad(10).Parent = tierPill
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = tierPill })
		Ui.stroke(rdef.colors[2], 2, 0).Parent = tierPill
		local best = bestRarity(egg)
		Ui.text({
			Name = "Drops",
			Text = `Drops {Rarities.Defs[lowestRarity(egg)].displayName} up to {Rarities.Defs[best].displayName} · see Odds`,
			FontFace = Theme.Face.Bold,
			TextSize = 13,
			TextColor3 = Rarities.Defs[best].color,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 3,
			Parent = info,
		})
		local world = Worlds.ById[egg.world or 0]
		if egg.coinPrice then
			Ui.price(Format.number(egg.coinPrice), "icon_coin", 26, { LayoutOrder = 4, Parent = info })
		end
		if not available then
			Ui.text({
				Text = if world
					then `Unlocks at {Format.number(world.trophiesToUnlock)} trophies (World {world.id})`
					else "Granted by events",
				FontFace = Theme.Face.Bold,
				TextColor3 = C.Red,
				Size = UDim2.new(1, 0, 0, 18),
				LayoutOrder = 5,
				Parent = info,
			})
		end

		-- Right: Open x1 / x3 / x8 (gold), Auto-open, Robux.
		local actions = Ui.frame({
			Name = "Actions",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.new(0, 260, 1, -12),
			Parent = box,
		}, { Ui.list(false, 6) })
		if available and egg.coinPrice then
			local row = Ui.frame({
				Name = "Open",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 48),
				LayoutOrder = 1,
				Parent = actions,
			}, { Ui.list(true, 6) })
			local caption = Ui.text({
				Text = "OPEN",
				FontFace = Theme.Face.Title,
				TextSize = 11,
				TextColor3 = C.GoldHi,
				Size = UDim2.new(1, 0, 0, 12),
				LayoutOrder = 0,
				Parent = actions,
			})
			Ui.outline(C.Night, 1).Parent = caption
			for _, count in HatchRules.Counts do
				local total = (egg.coinPrice :: number) * count
				local b = Ui.button(`x{count}`, "primary", function()
					buyCoins(egg, count)
				end, {
					Name = `Open{count}`,
					Size = UDim2.fromOffset(80, 48),
					TextSize = 20,
					LayoutOrder = count,
				})
				b.setEnabled(view ~= nil and view.coins >= total and freeSlots() >= count)
				local priceLabel = Ui.text({
					Text = Format.short(total),
					FontFace = Theme.Face.Number,
					TextSize = 11,
					TextColor3 = Color3.fromHex("#3A2200"),
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, 0, 0, 12),
					ZIndex = 6,
					Parent = b.instance,
				})
				priceLabel.Name = "Price"
				b.instance.Parent = row
			end
		end
		local auto = Ui.button(
			if Hatch.auto then "Auto-open: On" else "Auto-open: Off",
			if Hatch.auto then "success" else "tab",
			function()
				Hatch.auto = not Hatch.auto
				render()
			end,
			{ Name = "AutoOpen", Size = UDim2.new(0.5, -3, 0, 26), TextSize = 12, LayoutOrder = 2 }
		)
		local odds = Ui.button("Odds", "secondary", function()
			OddsPopup.show(ctx, egg, false)
		end, { Name = "Odds", Size = UDim2.new(0.5, -3, 0, 26), TextSize = 13, LayoutOrder = 1 })
		local pair = Ui.frame({
			Name = "OddsAuto",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 2,
			Parent = actions,
		}, { Ui.list(true, 6) })
		odds.instance.Parent = pair
		auto.instance.Parent = pair
		-- Robux: only eggs of unlocked worlds, only while the server allows paid random items. One
		-- compact row: a button per pack size.
		if available and egg.robuxPurchasable and ctx.attr("PaidRandomItemsAllowed") == true then
			local products = robuxProducts(egg.id)
			if #products > 0 then
				local robuxRow = Ui.frame({
					Name = "Robux",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 26),
					LayoutOrder = 3,
					Parent = actions,
				}, { Ui.list(true, 4) })
				local w = (260 - 4 * (#products - 1)) / #products
				for i, product in products do
					local onSale = product.productId ~= nil
					local b = Ui.button(
						if onSale then `R$ x{product.quantity}` else `x{product.quantity} soon`,
						"robux",
						function()
							ctx.request("Shop.RequestRobuxEgg", { productKey = product.key })
						end,
						{
							LayoutOrder = i,
							Size = UDim2.fromOffset(w, 26),
							TextSize = 12,
							Name = `Robux{product.quantity}`,
						}
					)
					b.setEnabled(onSale)
					b.instance.Parent = robuxRow
				end
			end
		end
		if egg.id == "egg_basic" and view and view.daily.freeEggDay ~= today then
			local free = Ui.button("Claim free daily egg", "success", function()
				local known = Hatch.known(ctx.state.view)
				local reply = ctx.request("Daily.ClaimFreeEgg")
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, false, { known = known })
				end
			end, { LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 26), TextSize = 12, Name = "FreeEgg" })
			free.instance.Parent = info
		end
	end

	-- Eggs tab: the row of all eggs grouped by world, and the details.
	local function renderEggs()
		local row = Ui.new("ScrollingFrame", {
			Name = "EggRow",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 4,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			Size = UDim2.new(1, 0, 0, CELL.Y + 26),
			Parent = content,
		}, { Ui.list(true, 14) })
		local highest = if view then view.highestTrophies else 0
		local scrollTo: GuiObject? = nil
		local order = 0
		local function group(label: string, list: { Types.EggDef }, locked: boolean, key: number)
			local g = Ui.frame({
				Name = `Group{key}`,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, CELL.Y + 22),
				LayoutOrder = key,
				Parent = row,
			})
			local head = Ui.text({
				Text = label,
				FontFace = Theme.Face.Title,
				TextSize = 12,
				TextColor3 = if locked then C.Muted else C.GoldHi,
				Size = UDim2.fromOffset(200, 16),
				Parent = g,
			})
			Ui.outline(C.Night, 1).Parent = head
			local eggsRow = Ui.frame({
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Position = UDim2.fromOffset(0, 18),
				Size = UDim2.fromOffset(0, CELL.Y),
				Parent = g,
			}, { Ui.list(true, 4) })
			for _, egg in list do
				order += 1
				if selectedEgg == nil and egg.world == startWorld then
					selectedEgg = egg
				end
				local hidden = egg.hiddenUntilQuest ~= nil
					and not (view ~= nil and Progress.isEggAvailable(view :: any, egg))
				if not hidden then
					eggCell(eggsRow, egg, order, locked)
				end
				if egg == selectedEgg then
					scrollTo = g
				end
			end
		end
		for _, world in Worlds.List do
			local list = {}
			for _, egg in Eggs.List do
				if egg.world == world.id then
					table.insert(list, egg)
				end
			end
			if #list > 0 then
				group(
					`World {world.id} · {world.displayName}`,
					list,
					highest < world.trophiesToUnlock,
					world.id
				)
			end
		end
		local events = {}
		for _, egg in Eggs.List do
			if egg.world == nil then
				table.insert(events, egg)
			end
		end
		if #events > 0 then
			group("Event", events, false, 99)
		end
		if selectedEgg == nil then
			selectedEgg = Eggs.List[1]
		end
		local detailBox = Ui.glowTile("Frame", {
			Name = "DetailBox",
			Position = UDim2.fromOffset(0, CELL.Y + 32),
			Size = UDim2.new(1, 0, 1, -(CELL.Y + 32)),
			Parent = content,
		}, Rarities.Defs[EggTiers.of(selectedEgg :: Types.EggDef)].colors[2], true)
		renderDetail(detailBox, selectedEgg :: Types.EggDef)
		if scrollTo then
			task.defer(function()
				local target = scrollTo :: GuiObject
				if target.Parent then
					row.CanvasPosition = Vector2.new(
						math.max(
							0,
							target.AbsolutePosition.X - row.AbsolutePosition.X + row.CanvasPosition.X - 8
						),
						0
					)
				end
			end)
		end
	end

	-- Egg Bag tab: owned eggs with counts, Golden markers and Open buttons.
	local function renderBag()
		local grid = Ui.scroll({ Size = UDim2.fromScale(1, 1), Parent = content })
		Ui.grid(Vector2.new(124, 150), 10).Parent = grid
		Ui.pad(4).Parent = grid
		local any = false
		for i, egg in Eggs.List do
			local n, g = owned(egg.id)
			for _, golden in { false, true } do
				local count = if golden then g else n
				if count <= 0 then
					continue
				end
				any = true
				local tile = Ui.glowTile("Frame", {
					Name = if golden then `{egg.id}_golden` else egg.id,
					LayoutOrder = i * 2 + (if golden then 1 else 0),
					Parent = grid,
				}, if golden then C.Gold else Rarities.Defs[EggTiers.of(egg)].colors[2], golden)
				local icon = Visuals.egg(tile, egg, golden, 40)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 8)
				local label = Ui.text({
					Text = if golden then `Golden {egg.displayName}` else egg.displayName,
					FontFace = Theme.Face.Bold,
					TextSize = 12,
					TextWrapped = false,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(4, 54),
					Size = UDim2.new(1, -8, 0, 16),
					ZIndex = 2,
					Parent = tile,
				})
				Ui.fit(label, 12, 8)
				Ui.text({
					Text = `x{count}`,
					FontFace = Theme.Face.Number,
					TextSize = 16,
					TextColor3 = if golden then C.GoldHi else C.Text,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 72),
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 2,
					Parent = tile,
				})
				local k = math.max(Hatch.fit(math.min(count, 8), count), 1)
				local open = Ui.button(
					if k == 1 then "Open" else `Open x{k}`,
					if golden then "primary" else "success",
					function()
						openBag(egg, golden, k)
					end,
					{
						Name = "Open",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -6),
						Size = UDim2.new(1, -12, 0, 30),
						TextSize = 13,
						ZIndex = 2,
					}
				)
				open.instance.Parent = tile
				if golden then
					local goldenOdds = Ui.button("Odds", "ghost", function()
						OddsPopup.show(ctx, egg, true)
					end, {
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -4, 0, 4),
						Size = UDim2.fromOffset(46, 22),
						TextSize = 11,
						ZIndex = 3,
					})
					goldenOdds.instance.Parent = tile
				end
			end
		end
		if not any then
			Ui.text({
				Text = "Your Egg Bag is empty. Eggs from rewards and the daily free egg land here.",
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 40),
				Parent = grid,
			})
		end
	end

	local function renderTabs()
		Ui.clear(tabs)
		Ui.list(true, 8).Parent = tabs
		local bagCount = 0
		for id in Eggs.ById do
			local n, g = owned(id)
			bagCount += n + g
		end
		for i, t in { { "Eggs", "Eggs" }, { "Bag", `Egg Bag ({bagCount})` } } do
			local b = Ui.button(t[2], if tab == t[1] then "purple" else "tab", function()
				tab = t[1]
				Ui.sound("tick")
				render()
			end, {
				Name = `Tab{t[1]}`,
				Size = UDim2.fromOffset(if i == 1 then 90 else 140, 30),
				LayoutOrder = i,
			})
			b.instance.Parent = tabs
		end
	end

	render = function()
		view = ctx.state.view
		bobbing = {}
		Ui.clear(content)
		renderTabs()
		if tab == "Bag" then
			renderBag()
		else
			renderEggs()
		end
	end

	render()
	Ui.stagger(content, ctx.reducedMotion())
	-- Idle bob, out of phase per egg (MISSION 10).
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		if ctx.reducedMotion() then
			return
		end
		local t = os.clock() - t0
		for _, b in bobbing do
			if b.obj.Parent then
				b.obj.Position = b.base + UDim2.fromOffset(0, math.sin(t * 2 + b.phase) * 3)
			end
		end
	end)
	return {
		destroy = function()
			conn:Disconnect()
		end,
		refresh = render,
	}
end
