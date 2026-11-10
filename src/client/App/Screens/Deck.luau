--!strict
-- Deck builder: three visually equal slots (design rule 5), deck power and the family bonus
-- shown separately. Saving sends the three uids; the server checks ownership, 3 different
-- characters and enabled cards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Power = require(Shared.Domain.Power)
local Progress = require(Shared.Domain.Progress)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Visuals = require(App.Visuals)
local Card = require(App.Card)
local Kit = require(App.Kit)
local Format = require(App.Format)
local TweenService = game:GetService("TweenService")

local C = Theme.Color

local STAT_NAME = { hp = "HP", atk = "ATK", def = "DEF", spd = "SPD", crit = "crit" }

-- Equip (CARDS_EGGS_MISSION 4.5): a copy of the card flies from the picker into its slot, leaving
-- a fading trail of light in its rarity colour. Screen-space, on the ScreenGui itself.
local function flyIn(gui: Instance, card: any, from: GuiObject, to: GuiObject, reduced: boolean)
	if reduced then
		return
	end
	local screen = gui:FindFirstAncestorWhichIsA("ScreenGui")
	if not screen then
		return
	end
	local a0, s0 = from.AbsolutePosition, from.AbsoluteSize
	local a1, s1 = to.AbsolutePosition, to.AbsoluteSize
	local ghost = Ui.frame({
		Name = "EquipFly",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(a0.X, a0.Y),
		Size = UDim2.fromOffset(s0.X, s0.Y),
		ZIndex = 200,
		Parent = screen,
	})
	local built = Card.build(ghost, {
		characterId = card.characterId,
		golden = card.golden,
		level = card.level,
		size = s0,
		stats = false,
	})
	built.Size = UDim2.fromScale(1, 1)
	local color = Rarities.Defs[Characters.ById[card.characterId].rarity].colors[4]
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(ghost, info, {
		Position = UDim2.fromOffset(a1.X, a1.Y),
		Size = UDim2.fromOffset(s1.X, s1.Y),
	}):Play()
	for k = 1, 6 do
		task.delay(k * 0.05, function()
			local t = k * 0.05 / 0.35
			local p = a0:Lerp(a1, t * t) + s0:Lerp(s1, t) / 2
			local dot = Kit.image("fx_mote", {
				ImageColor3 = color,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(p.X, p.Y),
				Size = UDim2.fromOffset(46, 46),
				ZIndex = 199,
				Parent = screen,
			})
			TweenService
				:Create(dot, TweenInfo.new(0.4), { ImageTransparency = 1, Size = UDim2.fromOffset(10, 10) })
				:Play()
			task.delay(0.45, dot.Destroy, dot)
		end)
	end
	task.delay(0.36, function()
		ghost:Destroy()
		Ui.sound("card_flip")
	end)
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Deck Builder", ctx.close, UDim2.fromOffset(770, 470), "icon_deck")
	local slots: { string? } = { view.deck[1], view.deck[2], view.deck[3] }
	local active = 1
	local lastPower: number? = nil

	local slotRow = Ui.frame(
		{ BackgroundTransparency = 1, Size = UDim2.new(0.55, 0, 0, 220), Parent = p.body },
		{
			Ui.list(true, 12, Enum.HorizontalAlignment.Center),
		}
	)
	local summary = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 228),
		Size = UDim2.new(0.55, 0, 1, -228),
		Parent = p.body,
	}, { Ui.list(false, 6, Enum.HorizontalAlignment.Center) })
	local pickList = Ui.scroll({
		Position = UDim2.fromScale(0.57, 0),
		Size = UDim2.fromScale(0.43, 1),
		Parent = p.body,
	})
	Ui.grid(Vector2.new(76, 108), 6).Parent = pickList
	-- Room for the rarity badge, which overhangs the top of each card.
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 4), Parent = pickList })

	local render: () -> ()

	local function specs(): { { characterId: string, level: number } }?
		local out = {}
		for i = 1, 3 do
			local uid = slots[i]
			local card = uid and view.cards[uid]
			if card == nil then
				return nil
			end
			out[i] = { characterId = card.characterId, level = card.level }
		end
		return out
	end

	render = function()
		view = ctx.state.view
		Ui.clear(slotRow)
		Ui.clear(summary)
		Ui.clear(pickList)
		for i = 1, 3 do
			local uid = slots[i]
			local card = uid and view.cards[uid]
			local def = card and Characters.ById[card.characterId]
			local slot = Ui.glowTile("TextButton", {
				Size = UDim2.fromOffset(130, 178),
				LayoutOrder = i,
				Name = `Slot{i}`,
				Parent = slotRow,
			}, if def then Theme.Rarity[def.rarity] else C.Purple, active == i)
			if card then
				local portrait = Visuals.portrait(
					slot,
					card.characterId,
					card.golden,
					Vector2.new(118, 160),
					true,
					card.level
				)
				-- The card shows its own power on its bottom plate.
				portrait.Position = UDim2.fromOffset(6, 6)
			else
				-- An empty slot: the dashed glowing outline with a "+" (kit `empty_slot`).
				Kit.image("empty_slot", {
					Name = "Empty",
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.new(1, -12, 1, -12),
					Parent = slot,
				})
				Ui.text({
					Text = `Slot {i}`,
					TextColor3 = C.Muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, -18),
					Size = UDim2.new(1, 0, 0, 16),
					Parent = slot,
				})
			end
			slot.Activated:Connect(function()
				active = i
				render()
			end)
		end

		local s = specs()
		if s then
			local preview = Power.deck(s)
			local league = Progress.leagueFor(view.trophies)
			-- "Deck Power: 2,770" with a count-up and a green arrow when it improves (`hd-04`).
			local powerRow = Ui.frame({
				Name = "DeckPower",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 30),
				LayoutOrder = 1,
				Parent = summary,
			}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
			Ui.text({
				Text = "Deck Power:",
				FontFace = Theme.Face.Title,
				TextSize = 18,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				LayoutOrder = 1,
				Parent = powerRow,
			})
			local value = Ui.text({
				Name = "Value",
				Text = Format.number(preview.total),
				FontFace = Theme.Face.Number,
				TextSize = 24,
				TextColor3 = C.Green,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				LayoutOrder = 2,
				Parent = powerRow,
			})
			Ui.outline(C.Night, 1.5).Parent = value
			if lastPower and preview.total ~= lastPower and not ctx.reducedMotion() then
				Ui.countUp(value, lastPower, preview.total, Format.number)
			end
			if lastPower and preview.total > lastPower then
				local arrow = Kit.image("icon_upgrade", {
					Name = "Up",
					ImageColor3 = C.Green,
					Size = UDim2.fromOffset(22, 22),
					LayoutOrder = 3,
					Parent = powerRow,
				})
				Ui.pulse(arrow, 0.3)
			end
			lastPower = preview.total
			-- The family bonus chip: the family gem, its name and "+2%".
			local chipRow = Ui.frame({
				Name = "FamilyBonus",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 26),
				LayoutOrder = 2,
				Parent = summary,
			}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
			Ui.text({
				Text = "Family Bonus:",
				FontFace = Theme.Face.Bold,
				TextSize = 13,
				TextColor3 = C.Muted,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 26),
				LayoutOrder = 0,
				Parent = chipRow,
			})
			if #preview.families == 0 then
				Ui.text({
					Text = "none yet (2 of one family)",
					TextSize = 12,
					TextColor3 = C.Muted,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 26),
					LayoutOrder = 1,
					Parent = chipRow,
				})
			end
			for i, f in preview.families do
				local chip = Ui.frame({
					BackgroundColor3 = Color3.fromHex("#2A1F5E"),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 24),
					LayoutOrder = i,
					Parent = chipRow,
				}, { Ui.corner(12), Ui.stroke(C.Purple, 1.5, 0.2), Ui.list(true, 4) })
				Ui.pad(6).Parent = chip
				Kit.image(
					`gem_family_{string.lower(f.family)}`,
					{ Size = UDim2.fromOffset(20, 20), LayoutOrder = 1, Parent = chip }
				)
				Ui.text({
					Text = f.family,
					FontFace = Theme.Face.Bold,
					TextSize = 12,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 24),
					LayoutOrder = 2,
					Parent = chip,
				})
				Ui.text({
					Text = `+{math.floor(f.value * 100 + 0.5)}% {STAT_NAME[f.stat] or f.stat}`,
					FontFace = Theme.Face.Number,
					TextSize = 12,
					TextColor3 = C.Green,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 24),
					LayoutOrder = 3,
					Parent = chip,
				})
			end
			Ui.text({
				Text = `Ranked in {league.id}: cards above level {league.rankedLevelCap} fight at level {league.rankedLevelCap}.`,
				TextSize = Theme.Size.small,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 3,
				Parent = summary,
			})
		end
		local save = Ui.button("Save Deck", "primary", function()
			local reply = ctx.request("Deck.Set", { uids = { slots[1], slots[2], slots[3] } })
			if reply.ok then
				ctx.cheer("SAVED!", "icon_check")
			end
		end, { Size = UDim2.fromOffset(220, 40), LayoutOrder = 4, Name = "SaveDeck" })
		save.setEnabled(s ~= nil)
		save.instance.Parent = summary
		local fams = Ui.button("Families", "secondary", function()
			ctx.open("Families")
		end, { Size = UDim2.fromOffset(160, 34), LayoutOrder = 5, Name = "Families" })
		fams.instance.Parent = summary

		-- The best copy of each character only (a deck takes one copy per character): at most 100
		-- tiles however many copies the player owns.
		local best: { [string]: any } = {}
		for _, c in view.cards do
			local b = best[c.characterId]
			if b == nil or c.level > b.level then
				best[c.characterId] = c
			end
		end
		for _, uid in slots do
			local c = uid and view.cards[uid :: string]
			if c then
				best[c.characterId] = c -- always show the copy that is actually in a slot
			end
		end
		local cards = {}
		for _, c in best do
			table.insert(cards, c)
		end
		table.sort(cards, function(a, b)
			local ra = Rarities.Defs[Characters.ById[a.characterId].rarity].order
			local rb = Rarities.Defs[Characters.ById[b.characterId].rarity].order
			if ra ~= rb then
				return ra > rb
			end
			if a.level ~= b.level then
				return a.level > b.level
			end
			return a.uid < b.uid
		end)
		for i, card in cards do
			local usedAt = table.find(slots, card.uid)
			local tile = Ui.new(
				"TextButton",
				{ Text = "", BackgroundTransparency = 1, LayoutOrder = i, Parent = pickList }
			)
			local portrait =
				Visuals.portrait(tile, card.characterId, card.golden, Vector2.new(76, 92), false, card.level)
			if usedAt then
				portrait.BackgroundColor3 = C.Stroke
			end
			Ui.text({
				Text = if usedAt then `Slot {usedAt}` else `Lv {card.level}`,
				TextSize = Theme.Size.small,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 92),
				Size = UDim2.new(1, 0, 0, 16),
				Parent = tile,
			})
			tile.Activated:Connect(function()
				-- One copy per character: replace any slot holding the same character.
				for j = 1, 3 do
					local other = slots[j] and view.cards[slots[j] :: string]
					if other and other.characterId == card.characterId then
						slots[j] = nil
					end
				end
				local target = active
				slots[target] = card.uid
				active = active % 3 + 1
				render()
				local slotObj = slotRow:FindFirstChild(`Slot{target}`)
				if slotObj then
					flyIn(layer, card, portrait, slotObj :: GuiObject, ctx.reducedMotion())
				end
			end)
		end
		if #cards == 0 then
			Ui.text({ Text = "Hatch eggs in the Shop to get cards.", TextColor3 = C.Muted, Parent = pickList })
		end
	end

	render()
	Ui.stagger(slotRow, ctx.reducedMotion())
	Ui.stagger(pickList, ctx.reducedMotion())
	return { destroy = function() end, refresh = render }
end
