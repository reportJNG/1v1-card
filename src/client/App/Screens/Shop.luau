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
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local Hatch = require(script.Parent.Hatch)
local OddsPopup = require(script.Parent.OddsPopup)

local C = Theme.Color

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
	local p = Ui.panel(layer, "Egg Shop", ctx.close, UDim2.fromOffset(800, 460))
	local today = ctx.now() // 86400

	-- World tabs: unlocked worlds plus the next locked one (so players see what's coming).
	local worldId: number = if arg and arg.world then arg.world else (if view then view.currentWorld else 1)
	local selectedEgg: Types.EggDef? = nil

	local tabs = Ui.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), Parent = p.body }, {
		Ui.list(true, 6),
	})
	local grid = Ui.scroll({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.62, -8, 1, -40),
		Parent = p.body,
	})
	Ui.grid(Vector2.new(146, 168), 8).Parent = grid
	local detailBox = Ui.frame({
		BackgroundColor3 = C.Raised,
		Position = UDim2.new(0.62, 0, 0, 40),
		Size = UDim2.new(0.38, 0, 1, -40),
		Parent = p.body,
	}, { Ui.corner(12), Ui.stroke(C.Gold, 1.5, 0.3), Ui.pad(10) })
	local detail = Ui.scroll({ Parent = detailBox })

	local function owned(eggId: string): (number, number)
		local stack = view and view.eggBag[eggId]
		return if stack then stack.normal else 0, if stack then stack.golden else 0
	end

	local renderDetail: () -> ()

	local function renderGrid()
		Ui.clear(grid)
		for i, egg in Eggs.List do
			if egg.world ~= worldId then
				continue
			end
			local available = view ~= nil and Progress.isEggAvailable(view :: any, egg)
			local hidden = egg.hiddenUntilQuest ~= nil and not available
			local tile = Ui.new("TextButton", {
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = if selectedEgg == egg then C.Stroke else C.Raised,
				LayoutOrder = i,
				Parent = grid,
			}, { Ui.corner(10), Ui.stroke(if selectedEgg == egg then C.Gold else C.Stroke, 1.5) })
			local icon = Visuals.egg(tile, egg, false, 84)
			icon.Position = UDim2.fromOffset(31, 26)
			Ui.text({
				Text = if hidden then "???" else egg.displayName,
				Font = Theme.Font.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.new(1, 0, 0, 20),
				Parent = tile,
			})
			local n, g = owned(egg.id)
			Ui.text({
				Text = if egg.coinPrice then `💰 {Format.number(egg.coinPrice)}` else "Event egg",
				Font = Theme.Font.Bold,
				TextColor3 = C.Gold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 1, -42),
				Size = UDim2.new(1, 0, 0, 18),
				Parent = tile,
			})
			Ui.text({
				Text = if available
					then `Owned {n}{if g > 0 then ` · Golden {g}` else ""}`
					else "🔒 Locked",
				TextSize = Theme.Size.small,
				TextColor3 = if available then C.Muted else C.Red,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 1, -22),
				Size = UDim2.new(1, 0, 0, 16),
				Parent = tile,
			})
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
		Ui.text({
			Text = egg.displayName,
			Font = Theme.Font.Title,
			TextSize = Theme.Size.heading + 2,
			TextColor3 = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			Parent = content,
		})
		local iconRow = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 96),
			LayoutOrder = 2,
			Parent = content,
		})
		local icon = Visuals.egg(iconRow, egg, false, 96)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.fromScale(0.5, 0)
		local world = Worlds.ById[egg.world or 0]
		Ui.text({
			Text = if world then `World {world.id}: {world.displayName}` else "Event egg",
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
			Parent = content,
		})
		local oddsButton = Ui.button("Odds", "secondary", function()
			OddsPopup.show(ctx, egg, false)
		end, { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 32), Name = "Odds" })
		oddsButton.instance.Parent = content

		if available and egg.coinPrice then
			local buy = Ui.button(`Buy for 💰 {Format.number(egg.coinPrice)}`, "primary", function()
				local reply = ctx.request("Shop.BuyEgg", { eggId = egg.id, requestId = ctx.guid() })
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, false)
				end
			end, { LayoutOrder = 5, Name = "BuyCoins" })
			buy.setEnabled(view ~= nil and view.coins >= egg.coinPrice)
			buy.instance.Parent = content
		elseif not available then
			Ui.text({
				Text = if world
					then `🔒 Unlocks at {Format.number(world.trophiesToUnlock)} trophies`
					else "Granted by events",
				Font = Theme.Font.Bold,
				TextColor3 = C.Red,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 5,
				Parent = content,
			})
		end

		-- Robux: only eggs of unlocked worlds, only while the server allows paid random items.
		if available and egg.robuxPurchasable and ctx.attr("PaidRandomItemsAllowed") == true then
			for i, product in robuxProducts(egg.id) do
				local b = Ui.button(`Buy {product.quantity} with Robux`, "purple", function()
					ctx.request("Shop.RequestRobuxEgg", { productKey = product.key })
				end, {
					LayoutOrder = 5 + i,
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

		local n, g = owned(egg.id)
		if n > 0 then
			local open = Ui.button(`Open from Egg Bag ({n})`, "success", function()
				local reply = ctx.request("Bag.OpenEgg", { eggId = egg.id, golden = false })
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, false)
				end
			end, { LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 34) })
			open.instance.Parent = content
		end
		if g > 0 then
			local openG = Ui.button(`Open Golden ({g})`, "primary", function()
				local reply = ctx.request("Bag.OpenEgg", { eggId = egg.id, golden = true })
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, true)
				end
			end, { LayoutOrder = 10, Size = UDim2.new(1, 0, 0, 34) })
			openG.instance.Parent = content
			local goldenOdds = Ui.button("Golden Odds", "ghost", function()
				OddsPopup.show(ctx, egg, true)
			end, { LayoutOrder = 11, Size = UDim2.new(1, 0, 0, 28) })
			goldenOdds.instance.Parent = content
		end
		if egg.id == "egg_basic" and view and view.daily.freeEggDay ~= today then
			local free = Ui.button("Claim free daily egg", "success", function()
				local reply = ctx.request("Daily.ClaimFreeEgg")
				if reply.ok then
					Hatch.show(ctx, reply.value.cards, egg, false)
				end
			end, { LayoutOrder = 12, Size = UDim2.new(1, 0, 0, 34), Name = "FreeEgg" })
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
				`{if unlocked then "" else "🔒"}{world.id}`,
				if world.id == worldId then "purple" else "ghost",
				function()
					worldId = world.id
					selectedEgg = nil
					renderTabs()
					renderGrid()
					renderDetail()
				end,
				{ Size = UDim2.fromOffset(52, 30), LayoutOrder = world.id }
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
