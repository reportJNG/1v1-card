--!strict
-- The card stats panel (CARDS_EGGS_MISSION 4.4, board docs/brief/ui-refs-2/05-card-stats.png), a
-- pop-up over the Inventory: the large card on the left, the stats panel in the middle, and the
-- five purple action buttons on the right.
--   header    crown (or star) icon, name, rarity name in its colour
--   level     "Lv. N / 15" and the real merge progress bar ("x / y" merge points), MAX at the cap
--   stats     big ATK and DEF, HP and SPD underneath (Cards.statsAt, K / M only above 9,999)
--   abilities the Special (energy cost) and the passive, with their real descriptions
--   family    the family bonus when it is active in the deck, else what it would give
--   buttons   Upgrade (merge), Evolve (stages by level), Equip (deck), Favorite, Preview
-- Everything is a request the server validates; the panel refreshes from the profile view.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Economy = require(Shared.Config.Economy)
local Families = require(Shared.Config.Families)
local Progression = require(Shared.Config.Progression)
local Cards = require(Shared.Domain.Cards)
local Evolution = require(Shared.Domain.Evolution)
local AbilityText = require(Shared.Domain.AbilityText)
local Cutout = require(Shared.Art.Cutout)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Kit = require(App.Kit)
local Card = require(App.Card)
local Format = require(App.Format)
local CardActions = require(App.CardActions)

local C = Theme.Color

local CardStats = {}

local STAT_NAME = { atk = "ATK", def = "DEF", spd = "SPD", hp = "HP", crit = "crit" }

local function glass(props: { [string]: any }, accent: Color3): Frame
	local f = Ui.frame(props, {
		Ui.corner(12),
		Ui.stroke(accent, 2, 0.15),
		Ui.gradient(Color3.fromHex("#1D1645"), Color3.fromHex("#0B0924")),
	})
	f.BackgroundColor3 = C.White
	return f
end

-- A purple glass action button with an icon and a label (board 05's right column).
local function actionButton(
	parent: Instance,
	icon: string,
	text: string,
	order: number,
	onClick: () -> ()
): TextButton
	local b: TextButton = Ui.new("TextButton", {
		Name = text,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.White,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Ui.corner(10),
		Ui.stroke(Color3.fromHex("#B98CFF"), 2, 0.1),
		Ui.gradient(Color3.fromHex("#6A2FD8"), Color3.fromHex("#3A1490")),
	})
	Kit.image(icon, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Parent = b,
	})
	local label = Ui.text({
		Name = "Label",
		Text = text,
		FontFace = Theme.Face.Title,
		TextSize = 17,
		TextWrapped = false,
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -56, 1, 0),
		Parent = b,
	})
	Ui.outline(C.Night, 1.5).Parent = label
	b.Activated:Connect(function()
		Ui.sound("click")
		onClick()
	end)
	Ui.juice(b)
	return b
end

local function statLine(
	parent: Instance,
	icon: string,
	label: string,
	value: number,
	size: number,
	order: number
)
	local row = Ui.frame({
		Name = label,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(150, size),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.list(true, 8) })
	Kit.image(icon, { Size = UDim2.fromOffset(size, size), LayoutOrder = 1, Parent = row })
	local v = Ui.text({
		Name = "Value",
		Text = Format.number(value),
		FontFace = Theme.Face.Number,
		TextSize = math.floor(size * 0.86),
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size),
		LayoutOrder = 2,
		Parent = row,
	})
	Ui.outline(C.Night, 1.5).Parent = v
	Ui.text({
		Name = "Label",
		Text = label,
		FontFace = Theme.Face.Bold,
		TextSize = math.max(11, math.floor(size * 0.42)),
		TextColor3 = C.Muted,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size),
		LayoutOrder = 3,
		Parent = row,
	})
end

local function ability(
	parent: Instance,
	icon: string,
	title: string,
	body: string,
	color: Color3,
	order: number
)
	local box = Ui.frame({
		Name = title,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = order,
		Parent = parent,
	})
	Kit.image(icon, { Size = UDim2.fromOffset(28, 28), Parent = box })
	local t = Ui.text({
		Name = "Title",
		Text = title,
		FontFace = Theme.Face.Title,
		TextSize = 15,
		TextColor3 = color,
		TextWrapped = false,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -36, 0, 16),
		Parent = box,
	})
	Ui.fit(t, 15, 10)
	Ui.text({
		Name = "Body",
		Text = body,
		TextSize = 12,
		TextColor3 = C.Text,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(36, 17),
		Size = UDim2.new(1, -36, 0, 14),
		Parent = box,
	})
end

-- How many deck cards share this card's family (only when this card is in the deck).
local function familyInDeck(view: any, card: any): number
	if not CardActions.inDeck(view, card.uid) then
		return 0
	end
	local family = Characters.ById[card.characterId].family
	local n = 0
	for _, uid in view.deck do
		local c = view.cards[uid]
		if c and Characters.ById[c.characterId].family == family then
			n += 1
		end
	end
	return n
end

-- A ring burst, "+N" and a level-up sound over `target` (4.5 level up).
local function levelUpFx(target: GuiObject, gained: number, color: Color3)
	local ring = Kit.image("shockwave_ring", {
		Name = "LevelRing",
		ImageColor3 = color,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.3, 0.3),
		ZIndex = 60,
		Parent = target,
	})
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
		Size = UDim2.fromScale(1.8, 1.8),
		ImageTransparency = 1,
	}):Play()
	local plus = Ui.display({
		Name = "PlusLevel",
		Text = "+0",
		TextSize = 44,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 0.25),
		ZIndex = 61,
		Parent = target,
	}, true)
	local n = Instance.new("NumberValue")
	n.Changed:Connect(function(v: number)
		plus.Text = `+{math.floor(v + 0.5)}`
	end)
	TweenService:Create(n, TweenInfo.new(0.5), { Value = gained }):Play()
	TweenService:Create(plus, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
		Position = UDim2.fromScale(0.5, 0.2),
		TextTransparency = 1,
	}):Play()
	task.delay(1.2, function()
		ring:Destroy()
		plus:Destroy()
		n:Destroy()
	end)
end

-- The full-screen showcase (Preview): the card slowly turning with its aura, and the battle standee.
local function preview(ctx: any, card: any)
	local box
	box = ctx.overlay(function(layer)
		local shade = Ui.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromHex("#05040F"),
			BackgroundTransparency = 0.08,
			Size = UDim2.fromScale(1, 1),
			Parent = layer,
		})
		local rdef = Rarities.Defs[Characters.ById[card.characterId].rarity]
		Kit.image("light_rays", {
			Name = "Rays",
			ImageColor3 = rdef.colors[4],
			ImageTransparency = 0.5,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.36, 0.5),
			Size = UDim2.fromOffset(620, 620),
			Parent = shade,
		})
		local spin = Ui.frame({
			Name = "Spin",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.36, 0.5),
			Size = UDim2.fromOffset(300, 420),
			Parent = shade,
		})
		Card.build(spin, {
			characterId = card.characterId,
			level = card.level,
			golden = card.golden,
			favorite = card.favorite,
			size = Vector2.new(300, 420),
			interactive = true,
		})
		-- The battle standee: the same cut-out layers the 3D standee shows in battle (Shared/Art/Cutout),
		-- drawn in 2D because SurfaceGuis (the standee's art) don't render inside a ViewportFrame.
		local standee = Ui.frame({
			Name = "Standee",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.74, 0.5),
			Size = UDim2.fromOffset(260, 400),
			Parent = shade,
		})
		Kit.image("fx_mote", {
			Name = "Base",
			ImageColor3 = rdef.colors[4],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.95),
			Size = UDim2.new(1, 0, 0, 70),
			ScaleType = Enum.ScaleType.Stretch,
			Parent = standee,
		})
		for i, cut in Cutout.layers(card.characterId) do
			Ui.new("ImageLabel", {
				Name = cut.name,
				Image = cut.image,
				ImageColor3 = cut.color,
				ImageTransparency = cut.transparency,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				Position = UDim2.fromScale(cut.offset.X, cut.offset.Y),
				Size = UDim2.fromScale(1, 0.92),
				ZIndex = i + 1,
				Parent = standee,
			})
		end
		Ui.text({
			Text = "Battle standee",
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 6),
			Size = UDim2.fromOffset(200, 18),
			Parent = standee,
		})
		Ui.text({
			Text = "Tap anywhere to close",
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -16),
			Size = UDim2.fromOffset(300, 20),
			Parent = shade,
		})
		-- A slow turn: scale X by the cosine of the angle (a 2D card turning about its vertical axis).
		local t0 = os.clock()
		local conn = RunService.RenderStepped:Connect(function()
			local a = (os.clock() - t0) * 0.6
			spin.Size = UDim2.fromOffset(math.max(8, math.abs(math.cos(a)) * 300), 420)
			standee.Rotation = math.sin(a * 0.7) * 3
		end)
		shade.Activated:Connect(function()
			box.destroy()
		end)
		return {
			destroy = function()
				conn:Disconnect()
			end,
		}
	end)
end

function CardStats.show(ctx: any, uid: string)
	local box
	box = ctx.overlay(function(layer)
		Ui.frame({
			BackgroundColor3 = C.Black,
			BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			Parent = layer,
		})
		local p = Ui.panel(layer, "Card Stats", function()
			box.destroy()
		end, UDim2.fromOffset(820, 470), "icon_cards")
		local mode = "stats" -- or "evolve"
		local lastLevel: number? = nil
		local cardHolder = Ui.frame({
			Name = "CardHolder",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.fromOffset(262, 366),
			Parent = p.body,
		})
		local middle = Ui.frame({
			Name = "Middle",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(276, 0),
			Size = UDim2.new(1, -276 - 170, 1, 0),
			Parent = p.body,
		})
		local buttons = Ui.frame({
			Name = "Buttons",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 158, 1, 0),
			Parent = p.body,
		}, { Ui.list(false, 10) })

		local function render()
			local view = ctx.state.view
			local card = view.cards[uid]
			Ui.clear(cardHolder)
			Ui.clear(middle)
			Ui.clear(buttons)
			Ui.list(false, 10).Parent = buttons
			if card == nil then
				box.destroy()
				return
			end
			local def = Characters.ById[card.characterId]
			local rdef = Rarities.Defs[def.rarity]
			Card.build(cardHolder, {
				characterId = card.characterId,
				level = card.level,
				golden = card.golden,
				favorite = card.favorite,
				size = Vector2.new(262, 366),
				interactive = true,
			})
			if lastLevel and card.level > lastLevel then
				levelUpFx(cardHolder, card.level - lastLevel, rdef.colors[4])
			end
			lastLevel = card.level

			local panel =
				glass({ Name = "StatsPanel", Size = UDim2.fromScale(1, 1), Parent = middle }, rdef.colors[2])
			local inner = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Parent = panel,
			}, { Ui.pad(14), Ui.list(false, 8) })

			-- Header: crown or star, name, rarity name.
			local head = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 46),
				LayoutOrder = 1,
				Parent = inner,
			})
			Kit.image(
				if rdef.emblem == "crown"
					then "emblem_crown_gold"
					elseif def.rarity == "Rare" then "emblem_star_blue"
					else "emblem_star_silver",
				{
					Size = UDim2.fromOffset(44, 44),
					Parent = head,
				}
			)
			local name = Ui.text({
				Name = "Name",
				Text = def.displayName,
				FontFace = Theme.Face.Title,
				TextSize = 24,
				TextWrapped = false,
				Position = UDim2.fromOffset(52, -2),
				Size = UDim2.new(1, -52, 0, 26),
				Parent = head,
			})
			Ui.fit(name, 24, 14)
			Ui.outline(C.Night, 1.5).Parent = name
			Ui.text({
				Name = "Rarity",
				Text = `{if card.golden then "Golden " else ""}{rdef.displayName} · {def.family} · {def.role}`,
				FontFace = Theme.Face.Bold,
				TextSize = 14,
				TextColor3 = if card.golden then C.GoldHi else rdef.color,
				Position = UDim2.fromOffset(52, 26),
				Size = UDim2.new(1, -52, 0, 18),
				Parent = head,
			})

			if mode == "evolve" then
				local stage, index = Evolution.stageAt(card.level)
				local nxt = Evolution.next(card.level)
				Ui.text({
					Name = "EvolveInfo",
					Text = if nxt
						then `Stage: {stage.name}. Next: {nxt.name} at level {nxt.minLevel}. Stages follow the card's level: merge spare copies to level up.`
						else `Stage: {stage.name}, the final stage.`,
					TextSize = 13,
					TextYAlignment = Enum.TextYAlignment.Top,
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = 2,
					Parent = inner,
				})
				local row = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 220),
					LayoutOrder = 3,
					Parent = inner,
				}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
				for i, s in Progression.evolutionStages do
					local cell = Ui.frame({
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(88, 220),
						LayoutOrder = i,
						Parent = row,
					})
					local mini = Card.build(cell, {
						characterId = card.characterId,
						level = s.minLevel,
						golden = card.golden,
						size = Vector2.new(88, 124),
						stats = false,
					})
					mini.Position = UDim2.fromOffset(0, 18)
					Ui.text({
						Text = s.name,
						FontFace = Theme.Face.Bold,
						TextSize = 13,
						TextColor3 = if i == index then C.GoldHi else C.Muted,
						TextXAlignment = Enum.TextXAlignment.Center,
						Position = UDim2.fromOffset(0, 150),
						Size = UDim2.new(1, 0, 0, 16),
						Parent = cell,
					})
					local hi = s.minLevel
					local nextStage = Progression.evolutionStages[i + 1]
					Ui.text({
						Text = if nextStage then `Lv. {hi}-{nextStage.minLevel - 1}` else `Lv. {hi}`,
						TextSize = 12,
						TextColor3 = C.Muted,
						TextXAlignment = Enum.TextXAlignment.Center,
						Position = UDim2.fromOffset(0, 168),
						Size = UDim2.new(1, 0, 0, 14),
						Parent = cell,
					})
					if i == index then
						Ui.text({
							Text = "Current",
							FontFace = Theme.Face.Bold,
							TextSize = 12,
							TextColor3 = C.Green,
							TextXAlignment = Enum.TextXAlignment.Center,
							Position = UDim2.fromOffset(0, 0),
							Size = UDim2.new(1, 0, 0, 14),
							Parent = cell,
						})
					end
				end
			else
				-- Level and merge progress.
				local need = Economy.Progression.mergePointsToNext[card.level]
				local lv = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 44),
					LayoutOrder = 2,
					Parent = inner,
				})
				local lvText = Ui.text({
					Name = "Level",
					Text = `<b>Lv. {card.level}</b> <font color="#9EAED3">/ {Economy.Progression.maxLevel}</font>`,
					RichText = true,
					FontFace = Theme.Face.Number,
					TextSize = 20,
					Size = UDim2.new(1, 0, 0, 22),
					Parent = lv,
				})
				Ui.outline(C.Night, 1).Parent = lvText
				local bar = Ui.frame({
					Name = "Bar",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, 26),
					Size = UDim2.new(1, 0, 0, 16),
					Parent = lv,
				})
				local bg = Kit.image("bar_level_bg", {
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(24, 0, 232, 32),
					SliceScale = 0.5,
					Size = UDim2.fromScale(1, 1),
					Parent = bar,
				})
				local frac = if need then math.clamp(card.mergePoints / need, 0, 1) else 1
				local fill = Kit.image("bar_level_fill", {
					Name = "Fill",
					ImageColor3 = rdef.colors[2],
					ScaleType = Enum.ScaleType.Slice,
					SliceCenter = Rect.new(24, 0, 232, 32),
					SliceScale = 0.5,
					Size = UDim2.fromScale(0, 1),
					Parent = bg,
				})
				TweenService:Create(
					fill,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad),
					{ Size = UDim2.fromScale(math.max(frac, 0.06), 1) }
				):Play()
				Ui.text({
					Name = "Points",
					Text = if need then `{card.mergePoints} / {need}` else "MAX",
					FontFace = Theme.Face.Bold,
					TextSize = 12,
					TextXAlignment = Enum.TextXAlignment.Right,
					Position = UDim2.new(0, 0, 0, 0),
					Size = UDim2.new(1, -8, 1, 0),
					ZIndex = 3,
					Parent = bar,
				})

				-- Stats: big ATK and DEF, HP and SPD underneath.
				local st = Cards.statsAt(card.characterId, card.level)
				local big = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = 3,
					Parent = inner,
				}, { Ui.list(true, 12) })
				statLine(big, "icon_atk", "ATK", math.floor(st.atk + 0.5), 30, 1)
				statLine(big, "icon_def", "DEF", math.floor(st.def + 0.5), 30, 2)
				local small = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
					LayoutOrder = 4,
					Parent = inner,
				}, { Ui.list(true, 12) })
				statLine(small, "icon_hp", "HP", math.floor(st.hp + 0.5), 22, 1)
				statLine(small, "icon_spd", "SPD", math.floor(st.spd + 0.5), 22, 2)

				ability(
					inner,
					"icon_energy",
					`Special: {def.special.displayName} · {def.special.cost} energy`,
					AbilityText.special(def.special),
					C.GoldHi,
					5
				)
				ability(
					inner,
					"icon_passive",
					`Passive: {def.passive.displayName}`,
					def.passive.description,
					Color3.fromHex("#C9A2FF"),
					6
				)

				local famDef = Families.Defs[def.family]
				local n = familyInDeck(view, card)
				local bonus = Families.SynergyBonus[math.min(n, 3)] or 0
				Ui.text({
					Name = "FamilyBonus",
					Text = if bonus > 0
						then `Family bonus active: {def.family} ×{n} in your deck, +{math.floor(
							bonus * 100 + 0.5
						)}% {STAT_NAME[famDef.bonusStat] or famDef.bonusStat}`
						else `{def.family} family: 2 / 3 in a deck give +2% / +3% {STAT_NAME[famDef.bonusStat] or famDef.bonusStat}`,
					FontFace = Theme.Face.Bold,
					TextSize = 12,
					TextColor3 = if bonus > 0 then C.Green else C.Muted,
					Size = UDim2.new(1, 0, 0, 30),
					LayoutOrder = 7,
					Parent = inner,
				})
			end

			-- The five actions.
			local plan = CardActions.mergePlan(view, card)
			local up = actionButton(buttons, "icon_upgrade", "Upgrade", 1, function()
				if plan == nil then
					ctx.fail("AlreadyMaxLevel")
				elseif #plan.use == 0 then
					ctx.fail("NoSpares")
				elseif view.coins < plan.fee then
					ctx.fail("InsufficientFunds")
				else
					ctx.confirm(
						"Upgrade",
						`Merge {#plan.use} spare cop{if #plan.use == 1 then "y" else "ies"} into {def.displayName} for {Format.number(
							plan.fee
						)} Coins?`,
						"Merge",
						function()
							CardActions.merge(ctx, card)
						end
					)
				end
			end)
			up:SetAttribute("Spares", if plan then #plan.use else 0)
			actionButton(buttons, "icon_evolve", if mode == "evolve" then "Stats" else "Evolve", 2, function()
				mode = if mode == "evolve" then "stats" else "evolve"
				render()
			end)
			local here = CardActions.inDeck(view, card.uid)
			actionButton(buttons, "icon_equip", if here then "Equipped" else "Equip", 3, function()
				if here then
					ctx.cheer("IN DECK!", "icon_deck")
				else
					CardActions.equip(ctx, card)
				end
			end)
			actionButton(
				buttons,
				if card.favorite then "icon_favorite_on" else "icon_favorite_off",
				if card.favorite then "Favorited" else "Favorite",
				4,
				function()
					CardActions.setFavorite(ctx, card, not card.favorite)
				end
			)
			actionButton(buttons, "icon_preview", "Preview", 5, function()
				preview(ctx, card)
			end)
			if card.paid then
				Ui.text({
					Text = "From a Robux egg",
					TextSize = 12,
					TextColor3 = C.Purple,
					Size = UDim2.new(1, 0, 0, 16),
					LayoutOrder = 6,
					Parent = buttons,
				})
			end
		end

		render()
		return { destroy = function() end, refresh = render }
	end)
	return box
end

return CardStats
