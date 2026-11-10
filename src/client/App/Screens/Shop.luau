--!strict
-- Egg Shop (BAD_GUI_3_EGG_SHOP.md section 5; targets docs/brief/bad-gui/06-egg-shop-target.png and
-- ui-refs/hd-02-egg-shop.png). No scrollbars, no tiny labels, no placeholder buttons:
--   header     EGGS and EGG BAG tabs; big page arrows with the page's worlds ("WORLDS 1-4")
--   left       a 4 x 2 grid of tier-coloured egg tiles: the name on top, the egg (Egg Icon Pack,
--              unedited) bobbing in a glow, a price pill built into the bottom edge, a lock with
--              "WORLD N" when its world is locked, a FREE ribbon on the Basic egg while today's free
--              egg is waiting; the selected tile lifts and glows
--   right      the featured egg: a big gold title, the egg on its pedestal with rays, one line
--              "COMMON → LEGENDARY" (its real range, from Shared/Domain/Odds) with the ODDS pill (exact
--              % per character, the table the server rolls from), a big price and chunky x1 / x3 / x8
--              buttons (grey when unaffordable); the FREE gift button while the daily egg waits; the
--              Robux buttons only while the server allows paid random items and a product is on sale;
--              AUTO (auto-open) as a small toggle
--   Egg Bag    the same tiles for owned eggs: a big "x3", Golden markers, OPEN
-- Tiles and frames are today's kit (TEMP) until the owner's Sheets A and B are approved and live.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
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
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local Kit = require(App.Kit)
local Hatch = require(script.Parent.Hatch)
local OddsPopup = require(script.Parent.OddsPopup)

local C = Theme.Color
local F = Theme.Face

local RARITY_ORDER = { "Mythical", "Legendary", "Epic", "Rare", "Common" }
local PAGE = 8 -- eggs per page (4 x 2)
local TILE = Vector2.new(120, 158)
local GAP = 10

local TIER_KEY: { [string]: string } = {
	Common = "common",
	Rare = "rare",
	Epic = "epic",
	Legendary = "legendary",
	Mythical = "godtier",
}

-- The most and least common rarity this egg can drop (from Shared/Domain/Odds, like the roll).
local function range(egg: Types.EggDef): (string, string)
	local odds = Odds.forEgg(egg, false)
	local best, low = "Common", "Common"
	for _, r in RARITY_ORDER do
		if (odds.rarities[r] or 0) > 0 then
			best = r
			break
		end
	end
	for i = #RARITY_ORDER, 1, -1 do
		if (odds.rarities[RARITY_ORDER[i]] or 0) > 0 then
			low = RARITY_ORDER[i]
			break
		end
	end
	return low, best
end

local function robuxProducts(eggId: string): { Types.RobuxEggProduct }
	local out = {}
	for _, product in Monetization.RobuxEggs do
		if product.eggId == eggId and product.productId ~= nil then -- on sale only: never a "soon" button
			table.insert(out, product)
		end
	end
	table.sort(out, function(a, b)
		return a.quantity < b.quantity
	end)
	return out
end

-- Lets a button's label grow past the kit's 22 px cap (the button already has its size constraint).
local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
end

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

-- The shop's eggs in page order: by world, then the event egg; Secret stays hidden until revealed.
local function shopEggs(view: any): { Types.EggDef }
	local list = {}
	for _, world in Worlds.List do
		for _, egg in Eggs.List do
			if egg.world == world.id then
				local hidden = egg.hiddenUntilQuest ~= nil
					and not (view ~= nil and Progress.isEggAvailable(view :: any, egg))
				if not hidden then
					table.insert(list, egg)
				end
			end
		end
	end
	for _, egg in Eggs.List do
		if egg.world == nil then
			table.insert(list, egg)
		end
	end
	return list
end

return function(ctx: any, layer: Frame, arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "EGG SHOP", ctx.close, UDim2.fromOffset(840, 480), "icon_shop")
	local today = ctx.now() // 86400
	local tab = if arg and arg.tab == "Bag" then "Bag" else "Eggs"
	local startWorld: number = if arg and arg.world
		then arg.world
		else (if view then view.currentWorld else 1)
	local selectedEgg: Types.EggDef? = nil
	local page = 1
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

	local function freeEggReady(): boolean
		local v = ctx.state.view
		return v ~= nil and v.daily.freeEggDay ~= today
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

	local function claimFree(egg: Types.EggDef)
		local known = Hatch.known(ctx.state.view)
		local reply = ctx.request("Daily.ClaimFreeEgg")
		if reply.ok then
			Hatch.show(ctx, reply.value.cards, egg, false, { known = known })
		end
	end

	-- Header row: tabs on the left, the pager on the right.
	local headRow = Ui.frame({
		Name = "HeadRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = p.body,
	})
	local content = Ui.frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
		Parent = p.body,
	})

	local render: () -> ()

	-- A tile: tier-coloured frame, name on top, the egg, and whatever `bottom` puts in its edge.
	local function tile(
		parent: Instance,
		order: number,
		egg: Types.EggDef,
		golden: boolean,
		selected: boolean,
		onClick: () -> ()
	): TextButton
		local tier = EggTiers.of(egg)
		local rdef = Rarities.Defs[tier]
		local accent = if golden then C.Gold else rdef.colors[2]
		local t: TextButton = Ui.glowTile("TextButton", {
			Name = if golden then `{egg.id}_golden` else egg.id,
			LayoutOrder = order,
			Parent = parent,
		}, accent, selected)
		Ui.image("egg_glow", {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(TILE.X / 2, 74),
			Size = UDim2.fromOffset(112, 104),
			ScaleType = Enum.ScaleType.Stretch,
			ImageColor3 = rdef.colors[4],
			ImageTransparency = if selected then 0.1 else 0.4,
			ZIndex = 1,
			Parent = t,
		})
		local icon = Visuals.egg(t, egg, golden, 76)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		local base = UDim2.fromOffset(TILE.X / 2, if selected then 70 else 76) -- the selected egg rises
		icon.Position = base
		icon.ZIndex = 2
		table.insert(bobbing, { obj = icon, base = base, phase = order * 0.9 })
		local name = Ui.display({
			Name = "Name",
			Text = string.upper(if golden then `Golden {egg.displayName}` else egg.displayName),
			TextSize = 16,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(TILE.X / 2, 6),
			Size = UDim2.fromOffset(TILE.X - 10, 20),
			ZIndex = 3,
			Parent = t,
		})
		name.TextColor3 = if golden then C.GoldHi else C.White
		outline(name, 2)
		Ui.fit(name, 16, 10)
		t.Activated:Connect(onClick)
		return t
	end

	-- A gold "FREE" ribbon on a tile's top-right corner.
	local function freeRibbon(t: GuiObject)
		local r = Ui.display({
			Name = "Free",
			Text = "FREE",
			TextSize = 18,
			BackgroundColor3 = C.Green,
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, 30),
			Size = UDim2.fromOffset(58, 24),
			Rotation = 12,
			ZIndex = 6,
			Parent = t,
		})
		r.TextColor3 = C.White
		outline(r, 2)
		Ui.corner(6).Parent = r
		Ui.stroke(C.Night, 2).Parent = r
		Ui.pulse(r, 0.1)
	end

	local function grid(): Frame
		local g = Ui.frame({
			Name = "Grid",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(4 * TILE.X + 3 * GAP, 2 * TILE.Y + GAP),
			Parent = content,
		})
		Ui.grid(TILE, GAP).Parent = g
		return g
	end

	-- The featured egg (right).
	local function renderFeatured(egg: Types.EggDef)
		local available = view ~= nil and Progress.isEggAvailable(view :: any, egg)
		local tier = EggTiers.of(egg)
		local rdef = Rarities.Defs[tier]
		local box = Ui.glowTile("Frame", {
			Name = "Featured",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -(4 * TILE.X + 3 * GAP + 14), 1, 0),
			Parent = content,
		}, C.Gold, true)
		local title = Ui.display({
			Name = "Name",
			Text = string.upper(egg.displayName),
			TextSize = 28,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.new(1, -16, 0, 32),
			ZIndex = 3,
			Parent = box,
		}, true)
		outline(title, 3)
		Ui.fit(title, 28, 16)
		-- the egg on its pedestal, rays behind it, rising in with a burst
		local stage = Ui.frame({
			Name = "Stage",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 38),
			Size = UDim2.fromOffset(170, 128),
			ZIndex = 2,
			Parent = box,
		})
		local rays = Ui.image("light_rays", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(200, 200),
			ImageColor3 = rdef.colors[4],
			ImageTransparency = 0.45,
			ZIndex = 2,
			Parent = stage,
		})
		Kit.image(`pedestal_{TIER_KEY[tier]}`, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(130, 64),
			ZIndex = 3,
			Parent = stage,
		})
		local big = Visuals.egg(stage, egg, false, 100)
		big.AnchorPoint = Vector2.new(0.5, 1)
		local bigBase = UDim2.new(0.5, 0, 1, -30)
		big.Position = bigBase
		big.ZIndex = 4
		table.insert(bobbing, { obj = big, base = bigBase, phase = 0 })
		if not ctx.reducedMotion() then
			local s = Ui.new("UIScale", { Scale = 0.6, Parent = big })
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			TweenService
				:Create(rays, TweenInfo.new(18, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {
					Rotation = 360,
				})
				:Play()
		end
		-- the drop range and the Odds pill
		local low, best = range(egg)
		local rangeRow = Ui.frame({
			Name = "Range",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 168),
			Size = UDim2.new(1, -20, 0, 34),
			ZIndex = 3,
			Parent = box,
		}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) });
		(rangeRow:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment =
			Enum.VerticalAlignment.Center
		local words = Ui.text({
			Name = "Drops",
			RichText = true,
			Text = `<font color="#{Rarities.Defs[low].color:ToHex()}">{string.upper(
				Rarities.Defs[low].displayName
			)}</font> → <font color="#{Rarities.Defs[best].color:ToHex()}">{string.upper(
				Rarities.Defs[best].displayName
			)}</font>`,
			FontFace = F.Display,
			TextSize = 17,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = 1,
			ZIndex = 3,
			Parent = rangeRow,
		})
		outline(words, 2)
		local odds = Ui.button("ODDS", "secondary", function()
			OddsPopup.show(ctx, egg, false)
		end, { Name = "Odds", Size = UDim2.fromOffset(84, 34), LayoutOrder = 2, ZIndex = 3 })
		bigLabel(odds, 20)
		odds.label.FontFace = F.Display
		odds.instance.Parent = rangeRow
		-- price and buttons
		local actions = Ui.frame({
			Name = "Actions",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 206),
			Size = UDim2.new(1, -20, 1, -210),
			ZIndex = 3,
			Parent = box,
		}, { Ui.list(false, 8, Enum.HorizontalAlignment.Center) })
		if not available then
			local world = Worlds.ById[egg.world or 0]
			local lock = Ui.display({
				Name = "Locked",
				Text = if world then `WORLD {world.id}` else "EVENT ONLY",
				TextSize = 26,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 1,
				ZIndex = 3,
				Parent = actions,
			})
			lock.TextColor3 = C.Red
			outline(lock, 3)
			if world then
				Ui.price(
					Format.short(world.trophiesToUnlock),
					"icon_trophy",
					30,
					{ LayoutOrder = 2, Parent = actions }
				)
			end
		elseif egg.coinPrice then
			Ui.price(
				Format.number(egg.coinPrice),
				"icon_coin",
				30,
				{ Name = "Price", LayoutOrder = 1, Parent = actions }
			)
			local row = Ui.frame({
				Name = "Open",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 56),
				LayoutOrder = 2,
				ZIndex = 3,
				Parent = actions,
			}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
			for _, count in HatchRules.Counts do
				local total = (egg.coinPrice :: number) * count
				local b = Ui.button(
					`x{count}`,
					"primary",
					function()
						buyCoins(egg, count)
					end,
					{ Name = `Open{count}`, Size = UDim2.fromOffset(74, 52), LayoutOrder = count, ZIndex = 3 }
				)
				b.label.FontFace = F.Display
				b.label.Position = UDim2.fromOffset(6, -6)
				b.setEnabled(view ~= nil and view.coins >= total and freeSlots() >= count)
				local sub = Ui.text({
					Name = "Price",
					Text = Format.short(total),
					FontFace = F.Number,
					TextSize = 14,
					TextColor3 = C.GoldInk,
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, 0, 0, 14),
					ZIndex = 6,
					Parent = b.instance,
				})
				sub.Name = "Price"
				b.instance.Parent = row
			end
		end
		if egg.id == "egg_basic" and freeEggReady() then
			local free = Ui.button("FREE EGG", "success", function()
				claimFree(egg)
			end, { Name = "FreeEgg", Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 3, ZIndex = 3 })
			free.label.FontFace = F.Display
			bigLabel(free, 24)
			Ui.icon(
				"icon_gift",
				30,
				{ Position = UDim2.new(0, 22, 0.5, 0), ZIndex = 6, Parent = free.instance }
			)
			free.instance.Parent = actions
		end
		-- Robux: only eggs of unlocked worlds, only while the server allows paid random items, and
		-- only products that are on sale.
		if available and egg.robuxPurchasable and ctx.attr("PaidRandomItemsAllowed") == true then
			local products = robuxProducts(egg.id)
			if #products > 0 then
				local robuxRow = Ui.frame({
					Name = "Robux",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = 4,
					ZIndex = 3,
					Parent = actions,
				}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
				for i, product in products do
					local b = Ui.button(`R$ x{product.quantity}`, "robux", function()
						ctx.request("Shop.RequestRobuxEgg", { productKey = product.key })
					end, {
						LayoutOrder = i,
						Size = UDim2.fromOffset(100, 34),
						Name = `Robux{product.quantity}`,
						ZIndex = 3,
					})
					b.instance.Parent = robuxRow
				end
			end
		end
		-- AUTO (auto-open) as a small toggle in the corner.
		local auto = Ui.button("AUTO", if Hatch.auto then "success" else "tab", function()
			Hatch.auto = not Hatch.auto
			render()
		end, {
			Name = "AutoOpen",
			Position = UDim2.fromOffset(8, 44),
			Size = UDim2.fromOffset(60, 26),
			ZIndex = 4,
		})
		auto.label.FontFace = F.Display
		auto.instance.Parent = box
	end

	local pagerLabel: TextLabel
	local prevB: any
	local nextB: any

	-- Eggs tab: one page of 8 tiles and the featured egg.
	local function renderEggs(list: { Types.EggDef })
		local pages = math.max(1, math.ceil(#list / PAGE))
		page = math.clamp(page, 1, pages)
		local g = grid()
		local highest = if view then view.highestTrophies else 0
		local lo, hi = math.huge, 0
		for i = (page - 1) * PAGE + 1, math.min(#list, page * PAGE) do
			local egg = list[i]
			if egg.world then
				lo, hi = math.min(lo, egg.world), math.max(hi, egg.world)
			end
			local world = Worlds.ById[egg.world or 0]
			local locked = world ~= nil and highest < world.trophiesToUnlock
			local t = tile(g, i, egg, false, selectedEgg == egg, function()
				Ui.sound("tick")
				selectedEgg = egg
				render()
			end)
			if egg.coinPrice then
				local pill = Ui.pricePill(Format.short(egg.coinPrice), "icon_coin", 28, {
					Name = "Price",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 1, -14),
					ZIndex = 4,
					Parent = t,
				})
				local amount = pill:FindFirstChild("Amount") :: TextLabel?
				if amount then
					amount.FontFace = F.Display
				end
			else
				local ev = Ui.display({
					Text = "EVENT",
					TextSize = 18,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, 0, 0, 22),
					ZIndex = 4,
					Parent = t,
				})
				ev.TextColor3 = C.Green
				outline(ev, 2)
			end
			if locked then
				local lock = Ui.frame({
					Name = "Lock",
					BackgroundColor3 = Color3.fromHex("#05040F"),
					BackgroundTransparency = 0.35,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 7,
					Parent = t,
				}, { Ui.corner(12) })
				Kit.image("lock_overlay", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.fromOffset(52, 52),
					ZIndex = 8,
					Parent = lock,
				})
				local w = Ui.display({
					Text = `WORLD {(world :: any).id}`,
					TextSize = 20,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0.64),
					Size = UDim2.new(1, -8, 0, 24),
					ZIndex = 8,
					Parent = lock,
				})
				w.TextColor3 = C.White
				outline(w, 2)
			end
			if egg.id == "egg_basic" and freeEggReady() then
				freeRibbon(t)
			end
		end
		pagerLabel.Text = if hi == 0 then "EVENT" elseif lo == hi then `WORLD {lo}` else `WORLDS {lo}-{hi}`
		prevB.setEnabled(page > 1)
		nextB.setEnabled(page < pages)
		renderFeatured(selectedEgg :: Types.EggDef)
	end

	-- Egg Bag tab: the same tiles for owned eggs, with counts and OPEN.
	local function renderBag()
		local owners: { { egg: Types.EggDef, golden: boolean, count: number } } = {}
		for _, egg in Eggs.List do
			local n, g = owned(egg.id)
			if n > 0 then
				table.insert(owners, { egg = egg, golden = false, count = n })
			end
			if g > 0 then
				table.insert(owners, { egg = egg, golden = true, count = g })
			end
		end
		local pages = math.max(1, math.ceil(#owners / PAGE))
		page = math.clamp(page, 1, pages)
		pagerLabel.Text = `BAG {page}/{pages}`
		prevB.setEnabled(page > 1)
		nextB.setEnabled(page < pages)
		if #owners == 0 then
			local empty = Ui.display({
				Text = "NO EGGS YET",
				TextSize = 34,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.4),
				Size = UDim2.new(1, 0, 0, 40),
				Parent = content,
			})
			empty.TextColor3 = C.White
			outline(empty, 3)
			Ui.icon("icon_gift", 72, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.3),
				ImageTransparency = 0.2,
				Parent = content,
			})
			return
		end
		local g = grid()
		g.Size = UDim2.fromScale(1, 1)
		local layoutGrid = g:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layoutGrid.CellSize = UDim2.fromOffset(TILE.X + 70, TILE.Y)
		for i = (page - 1) * PAGE + 1, math.min(#owners, page * PAGE) do
			local o = owners[i]
			local t = tile(g, i, o.egg, o.golden, false, function() end)
			local count = Ui.display({
				Name = "Count",
				Text = `x{o.count}`,
				TextSize = 30,
				Rotation = -6,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 30),
				Size = UDim2.fromOffset(70, 34),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 4,
				Parent = t,
			}, true)
			outline(count, 3)
			local k = math.max(Hatch.fit(math.min(o.count, 8), o.count), 1)
			local open = Ui.button(
				if k == 1 then "OPEN" else `OPEN x{k}`,
				if o.golden then "primary" else "success",
				function()
					openBag(o.egg, o.golden, k)
				end,
				{
					Name = "Open",
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.new(1, -16, 0, 36),
					ZIndex = 4,
				}
			)
			open.label.FontFace = F.Display
			bigLabel(open, 24)
			open.instance.Parent = t
			if o.golden then
				local goldenOdds = Ui.button("ODDS", "secondary", function()
					OddsPopup.show(ctx, o.egg, true)
				end, {
					AnchorPoint = Vector2.new(0, 0),
					Position = UDim2.fromOffset(6, 30),
					Size = UDim2.fromOffset(64, 28),
					ZIndex = 5,
				})
				goldenOdds.label.FontFace = F.Display
				bigLabel(goldenOdds, 16)
				goldenOdds.instance.Parent = t
			end
		end
	end

	-- The header row: tabs and the pager.
	local function renderHead(bagCount: number)
		Ui.clear(headRow)
		local tabs = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.5, 1),
			Parent = headRow,
		}, { Ui.list(true, 8) })
		for i, t in { { "Eggs", "EGGS" }, { "Bag", `EGG BAG ({bagCount})` } } do
			local b = Ui.button(t[2], if tab == t[1] then "purple" else "tab", function()
				tab = t[1]
				page = 1
				Ui.sound("tick")
				render()
			end, {
				Name = `Tab{t[1]}`,
				Size = UDim2.fromOffset(if i == 1 then 110 else 170, 40),
				LayoutOrder = i,
			})
			b.label.FontFace = F.Display
			bigLabel(b, 22)
			b.instance.Parent = tabs
		end
		local pager = Ui.frame({
			Name = "Pager",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(330, 44),
			Parent = headRow,
		})
		prevB = Ui.button("◀", "secondary", function()
			page -= 1
			render()
		end, { Name = "Prev", Size = UDim2.fromOffset(48, 40) })
		prevB.label.FontFace = F.Display
		bigLabel(prevB, 28)
		prevB.instance.Parent = pager
		nextB = Ui.button("▶", "secondary", function()
			page += 1
			render()
		end, {
			Name = "Next",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(48, 40),
		})
		nextB.label.FontFace = F.Display
		bigLabel(nextB, 28)
		nextB.instance.Parent = pager
		pagerLabel = Ui.display({
			Name = "Page",
			Text = "",
			TextSize = 26,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -104, 1, 0),
			Parent = pager,
		}, true)
		outline(pagerLabel, 3)
	end

	render = function()
		view = ctx.state.view
		bobbing = {}
		Ui.clear(content)
		local bagCount = 0
		for id in Eggs.ById do
			local n, g = owned(id)
			bagCount += n + g
		end
		renderHead(bagCount)
		if tab == "Bag" then
			renderBag()
		else
			local list = shopEggs(view)
			if selectedEgg == nil then
				for i, egg in list do
					if egg.world == startWorld then
						selectedEgg = egg
						page = (i - 1) // PAGE + 1
						break
					end
				end
				selectedEgg = selectedEgg or list[1]
			end
			renderEggs(list)
		end
	end

	render()
	Ui.stagger(content, ctx.reducedMotion())
	-- Idle bob, out of phase per egg.
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
