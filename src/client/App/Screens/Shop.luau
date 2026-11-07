--!strict
-- Egg Shop. Eggs of each world, with name, odds band, price and owned count visible before
-- buying (design rule 2), a labelled "Odds" button showing the exact % per character from
-- Shared/Domain/Odds (the same table the server rolls from), the Egg Bag and the daily free egg.
-- The Robux button exists only while the server says PaidRandomItemsAllowed = true; the server
-- re-checks eligibility on every offer and every receipt regardless.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Eggs = require(Shared.Config.Eggs)
local Worlds = require(Shared.Config.Worlds)
local Monetization = require(Shared.Config.Monetization)
local Progress = require(Shared.Domain.Progress)
local HatchRules = require(Shared.Domain.Hatch)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local Hatch = require(script.Parent.Hatch)
local OddsPopup = require(script.Parent.OddsPopup)

local C = Theme.Color

-- Glow behind each egg, by odds band (the egg art itself is never tinted or edited).
local BAND_GLOW: { [string]: Color3 } = {
	A = Theme.Rarity.Common,
	B = Theme.Rarity.Rare,
	C = Theme.Rarity.Epic,
	D = Theme.Rarity.Legendary,
	E = Theme.Rarity.Mythical,
	Event = C.Green,
}
local RARITY_ORDER = { "Mythical", "Legendary", "Epic", "Rare", "Common" }

-- The most common rarity this egg can drop (its pool keys).
local function lowestRarity(egg: Types.EggDef): string
	for i = #RARITY_ORDER, 1, -1 do
		local ids = (egg.pool :: any)[RARITY_ORDER[i]]
		if ids and #ids > 0 then
			return RARITY_ORDER[i]
		end
	end
	return "Common"
end

-- The rarest rarity this egg can drop (its pool keys).
local function bestRarity(egg: Types.EggDef): string
	for _, r in RARITY_ORDER do
		local ids = (egg.pool :: any)[r]
		if ids and #ids > 0 then
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

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Egg Shop", ctx.close, UDim2.fromOffset(770, 460), "icon_shop")
	local today = ctx.now() // 86400

	-- World tabs: unlocked worlds plus the next locked one (so players see what's coming).
	local worldId: number = if arg and arg.world then arg.world else (if view then view.currentWorld else 1)
	local selectedEgg: Types.EggDef? = nil
	local qty = 1 -- x1 / x3 / x8 for Coin buys and bag opens

	local tabs = Ui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = p.body }, {
		Ui.list(true, 6),
	})
	local grid = Ui.scroll({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.62, -8, 1, -40),
		Parent = p.body,
	})
	Ui.grid(Vector2.new(140, 176), 10).Parent = grid
	Ui.pad(4).Parent = grid
	-- The featured pane (gold-edged, like the board's "Legendary Egg" panel).
	local detailBox = Ui.glowTile("Frame", {
		Name = "DetailBox",
		Position = UDim2.new(0.62, 0, 0, 40),
		Size = UDim2.new(0.38, 0, 1, -40),
		Parent = p.body,
	}, C.Gold, true)
	Ui.pad(10).Parent = detailBox
	local detail = Ui.scroll({ Parent = detailBox })

	local function owned(eggId: string): (number, number)
		local stack = view and view.eggBag[eggId]
		return if stack then stack.normal else 0, if stack then stack.golden else 0
	end

	local renderDetail: () -> ()

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

	-- Opens up to the chosen count from the Egg Bag (as many of 1/3/8 as the stack and storage allow).
	local function openBag(egg: Types.EggDef, golden: boolean)
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

	local function renderGrid()
		Ui.clear(grid)
		for i, egg in Eggs.List do
			if egg.world ~= worldId then
				continue
			end
			local available = view ~= nil and Progress.isEggAvailable(view :: any, egg)
			local hidden = egg.hiddenUntilQuest ~= nil and not available
			local accent = BAND_GLOW[egg.oddsBand] or C.Purple
			local tile = Ui.glowTile("TextButton", {
				LayoutOrder = i,
				Name = egg.id,
				Parent = grid,
			}, accent, selectedEgg == egg)
			local glow = Ui.image("egg_glow", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 78),
				Size = UDim2.fromOffset(120, 120),
				ImageColor3 = BAND_GLOW[egg.oddsBand] or C.Purple,
				ImageTransparency = 0.3,
				Parent = tile,
			})
			glow.ZIndex = 1
			local icon = Visuals.egg(tile, egg, false, 92)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.new(0.5, 0, 0, 80)
			icon.ZIndex = 2
			local nameLabel = Ui.text({
				Text = if hidden then "???" else egg.displayName,
				FontFace = Theme.Face.Title,
				TextSize = 15,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(4, 6),
				Size = UDim2.new(1, -8, 0, 20),
				ZIndex = 2,
				Parent = tile,
			})
			Ui.outline(C.Night, 1, 0.3).Parent = nameLabel
			Ui.fit(nameLabel, 15, 9)
			local n, g = owned(egg.id)
			if egg.coinPrice then
				Ui.pricePill(Format.number(egg.coinPrice), "icon_coin", 24, {
					Position = UDim2.new(0.5, 0, 1, -50),
					ZIndex = 2,
					Parent = tile,
				})
			else
				Ui.text({
					Text = "Event egg",
					FontFace = Theme.Face.Bold,
					TextColor3 = C.Green,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.new(0, 0, 1, -46),
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 2,
					Parent = tile,
				})
			end
			Ui.text({
				Text = if available then `Owned {n}{if g > 0 then ` · Golden {g}` else ""}` else "Locked",
				TextSize = Theme.Size.small,
				TextColor3 = if available then C.Muted else C.Red,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 1, -24),
				Size = UDim2.new(1, 0, 0, 16),
				ZIndex = 2,
				Parent = tile,
			})
			if not available then
				Ui.icon("icon_lock", 30, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 26),
					ZIndex = 3,
					Parent = tile,
				})
			end
			tile.Activated:Connect(function()
				selectedEgg = egg
				renderGrid()
				renderDetail()
			end)
			if selectedEgg == nil then
				selectedEgg = egg
			end
		end
	end

	renderDetail = function()
		Ui.clear(detail)
		local egg = selectedEgg
		if egg == nil then
			return
		end
		local available = view ~= nil and Progress.isEggAvailable(view :: any, egg)
		local content = Ui.frame({
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, -8, 0, 0),
			Parent = detail,
		}, { Ui.list(false, 6) })
		local title = Ui.display({
			Text = egg.displayName,
			TextColor3 = (BAND_GLOW[egg.oddsBand] or C.Gold):Lerp(C.White, 0.35),
			TextSize = 26,
			TextWrapped = false,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 1,
			Parent = content,
		}, true)
		Ui.fit(title, 26, 12)
		local stage = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 128),
			LayoutOrder = 2,
			Parent = content,
		})
		Ui.image("egg_pedestal", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.fromOffset(210, 105),
			Parent = stage,
		})
		Ui.image("egg_glow", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(190, 190),
			ImageColor3 = BAND_GLOW[egg.oddsBand] or C.Purple,
			ImageTransparency = 0.35,
			Parent = stage,
		})
		local icon = Visuals.egg(stage, egg, false, 108)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.42)
		local world = Worlds.ById[egg.world or 0]
		local best = bestRarity(egg)
		Ui.text({
			Text = `Drops {lowestRarity(egg)} up to {best} (see Odds) · {if world
				then `World {world.id}`
				else "Event"}`,
			FontFace = Theme.Face.Bold,
			TextSize = 13,
			TextColor3 = Theme.Rarity[best] or C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 34), -- two lines: the world name wraps under the rarity range
			LayoutOrder = 3,
			Parent = content,
		})
		local oddsButton = Ui.button("Odds", "secondary", function()
			OddsPopup.show(ctx, egg, false)
		end, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 34), Name = "Odds" })
		oddsButton.instance.Parent = content

		local n, g = owned(egg.id)
		if available and (egg.coinPrice or n > 0 or g > 0) then
			-- x1 / x3 / x8 (one charge per batch; the server checks the count, Coins and storage).
			local qtyRow = Ui.frame({
				Name = "Quantity",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 5,
				Parent = content,
			}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
			for _, count in HatchRules.Counts do
				local b = Ui.button(`x{count}`, if count == qty then "purple" else "tab", function()
					qty = count
					renderDetail()
				end, { Name = `Qty{count}`, Size = UDim2.fromOffset(44, 30), LayoutOrder = count })
				b.instance.Parent = qtyRow
			end
			local auto = Ui.button(
				if Hatch.auto then "Auto: On" else "Auto: Off",
				if Hatch.auto then "success" else "tab",
				function()
					Hatch.auto = not Hatch.auto
					renderDetail()
				end,
				{ Name = "AutoOpen", Size = UDim2.fromOffset(78, 30), LayoutOrder = 9 }
			)
			auto.instance.Parent = qtyRow
		end
		if available and egg.coinPrice then
			local total = (egg.coinPrice :: number) * qty
			Ui.price(Format.number(total), "icon_coin", 26, { LayoutOrder = 6, Parent = content })
			local buy = Ui.button(if qty == 1 then "Buy" else `Buy x{qty}`, "primary", function()
				buyCoins(egg, qty)
			end, { LayoutOrder = 7, Name = "BuyCoins", Size = UDim2.new(1, 0, 0, 46) })
			buy.setEnabled(view ~= nil and view.coins >= total and freeSlots() >= qty)
			buy.instance.Parent = content
		elseif not available then
			Ui.text({
				Text = if world
					then `Unlocks at {Format.number(world.trophiesToUnlock)} trophies`
					else "Granted by events",
				FontFace = Theme.Face.Bold,
				TextColor3 = C.Red,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 5,
				Parent = content,
			})
		end

		-- Robux: only eggs of unlocked worlds, only while the server allows paid random items.
		if available and egg.robuxPurchasable and ctx.attr("PaidRandomItemsAllowed") == true then
			for i, product in robuxProducts(egg.id) do
				local b = Ui.button(`Buy {product.quantity} with Robux`, "robux", function()
					ctx.request("Shop.RequestRobuxEgg", { productKey = product.key })
				end, {
					LayoutOrder = 8 + i,
					Size = UDim2.new(1, 0, 0, 34),
					Name = `Robux{product.quantity}`,
				})
				b.setEnabled(product.productId ~= nil)
				if product.productId == nil then
					b.setText(`Robux x{product.quantity} (not on sale yet)`)
				end
				b.instance.Parent = content
			end
		end

		if n > 0 then
			local k = math.max(Hatch.fit(qty, n), 1)
			local open = Ui.button(
				if k == 1 then `Open from Egg Bag ({n})` else `Open x{k} from Egg Bag ({n})`,
				"success",
				function()
					openBag(egg, false)
				end,
				{ LayoutOrder = 12, Size = UDim2.new(1, 0, 0, 34), Name = "OpenBag" }
			)
			open.instance.Parent = content
		end
		if g > 0 then
			local k = math.max(Hatch.fit(qty, g), 1)
			local openG = Ui.button(
				if k == 1 then `Open Golden ({g})` else `Open x{k} Golden ({g})`,
				"primary",
				function()
					openBag(egg, true)
				end,
				{ LayoutOrder = 13, Size = UDim2.new(1, 0, 0, 34), Name = "OpenGolden" }
			)
			openG.instance.Parent = content
			local goldenOdds = Ui.button("Golden Odds", "ghost", function()
				OddsPopup.show(ctx, egg, true)
			end, { LayoutOrder = 14, Size = UDim2.new(1, 0, 0, 28) })
			goldenOdds.instance.Parent = content
		end
		if egg.id == "egg_basic" and view and view.daily.freeEggDay ~= today then
			local free = Ui.button("Claim free daily egg", "success", function()
				local known = Hatch.known(ctx.state.view)
				local reply = ctx.request("Daily.ClaimFreeEgg")
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, false, { known = known })
				end
			end, { LayoutOrder = 15, Size = UDim2.new(1, 0, 0, 34), Name = "FreeEgg" })
			free.instance.Parent = content
		end
	end

	local function renderTabs()
		Ui.clear(tabs)
		local highest = if view then view.highestTrophies else 0
		local shownLocked = false
		for _, world in Worlds.List do
			local unlocked = highest >= world.trophiesToUnlock
			if not unlocked then
				if shownLocked then
					break
				end
				shownLocked = true
			end
			local b = Ui.button(
				if unlocked then `World {world.id}` else `World {world.id} (locked)`,
				if world.id == worldId then "purple" else "tab",
				function()
					worldId = world.id
					selectedEgg = nil
					renderTabs()
					renderGrid()
					renderDetail()
				end,
				{ Size = UDim2.fromOffset(if unlocked then 84 else 128, 32), LayoutOrder = world.id }
			)
			b.instance.Parent = tabs
		end
	end

	renderTabs()
	renderGrid()
	renderDetail()
	return {
		destroy = function() end,
		refresh = function()
			view = ctx.state.view
			renderGrid()
			renderDetail()
		end,
	}
end
