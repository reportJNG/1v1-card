--!strict
-- Deck Builder (BAD_GUI_6_DECK_AND_INVENTORY.md; target ui-refs/hd-04, layout only: its card art is
-- copyrighted), with the Families panel beside it:
--   three equal slot cards, art first (no names), each with a power plate (sword + big number); tap
--   a slot to pick it, then a card in the strip below to put there (it flies in)
--   DECK POWER in big type with a count-up and a green / red arrow when it changes
--   the family bonus chips and the ranked level cap as chips
--   a paged strip of the best copy of each character (no scrollbar)
--   SAVE DECK, gold, grey while nothing changed
-- Saving sends the three uids; the server checks ownership, 3 different characters and enabled
-- cards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Power = require(Shared.Domain.Power)
local Progress = require(Shared.Domain.Progress)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Card = require(App.Card)
local Kit = require(App.Kit)
local Format = require(App.Format)
local TweenService = game:GetService("TweenService")

local C = Theme.Color

local STAT_NAME = { hp = "HP", atk = "ATK", def = "DEF", spd = "SPD", crit = "CRIT" }
local PICK = Vector2.new(64, 90)
local PER_PAGE = 7

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

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = Theme.Face.Display
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "DECK BUILDER", ctx.close, UDim2.fromOffset(600, 490), "icon_deck")
	p.frame.Position = UDim2.new(0.5, -170, 0.5, 18) -- the Families panel stands to the right
	local families = require(script.Parent.Families)(ctx, layer, { side = true })
	local slots: { string? } = { view.deck[1], view.deck[2], view.deck[3] }
	local active = 1
	local page = 1
	local lastPower: number? = nil

	local slotRow = Ui.frame({
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 178),
		Parent = p.body,
	})
	local summary = Ui.frame({
		Name = "Summary",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 0, 70),
		Parent = p.body,
	})
	local strip = Ui.frame({
		Name = "Picker",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 258),
		Size = UDim2.new(1, 0, 0, PICK.Y + 6),
		Parent = p.body,
	})
	local saveHolder = Ui.frame({
		Name = "SaveRow",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = p.body,
	})

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

	local function changed(): boolean
		for i = 1, 3 do
			if slots[i] ~= view.deck[i] then
				return true
			end
		end
		return false
	end

	local function renderSlots()
		for i = 1, 3 do
			local uid = slots[i]
			local card = uid and view.cards[uid]
			local def = card and Characters.ById[card.characterId]
			local slot = Ui.glowTile("TextButton", {
				Size = UDim2.fromOffset(126, 176),
				LayoutOrder = i,
				Name = `Slot{i}`,
				Parent = slotRow,
			}, if def then Theme.Rarity[def.rarity] else C.Purple, active == i)
			if card then
				local holder = Ui.frame({
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(4, 4),
					Size = UDim2.new(1, -8, 1, -8),
					Parent = slot,
				})
				Card.build(holder, {
					characterId = card.characterId,
					golden = card.golden,
					level = card.level,
					size = Vector2.new(118, 165),
					stats = false,
					bare = true,
				})
				local plate = Ui.frame({
					Name = "PowerPlate",
					BackgroundColor3 = C.Night,
					BackgroundTransparency = 0.15,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -8),
					Size = UDim2.new(1, -22, 0, 36),
					ZIndex = 70,
					Parent = slot,
				}, { Ui.corner(10), Ui.stroke(C.Gold, 2, 0.2) })
				Ui.icon(
					"icon_power",
					28,
					{ Position = UDim2.new(0, 18, 0.5, 0), ZIndex = 71, Parent = plate }
				)
				local n = Ui.display({
					Name = "Power",
					Text = Format.number(Power.card(card.characterId, card.level)),
					TextSize = 26,
					Position = UDim2.fromOffset(32, 0),
					Size = UDim2.new(1, -36, 1, 0),
					ZIndex = 71,
					Parent = plate,
				})
				n.TextColor3 = C.White
				outline(n, 3)
				Ui.fit(n, 26, 14)
			else
				-- An empty slot: the dashed glowing outline with a "+".
				Kit.image("empty_slot", {
					Name = "Empty",
					Position = UDim2.fromOffset(8, 8),
					Size = UDim2.new(1, -16, 1, -16),
					Parent = slot,
				})
			end
			slot.Activated:Connect(function()
				active = i
				render()
			end)
		end
	end

	-- A chip in the summary row: an optional gem, a few big words.
	local function chip(row: Instance, order: number, gem: string?, text: string, color: Color3)
		local c = Ui.frame({
			BackgroundColor3 = Color3.fromHex("#2A1F5E"),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			LayoutOrder = order,
			Parent = row,
		}, { Ui.corner(15), Ui.stroke(color, 2, 0.1), Ui.list(true, 4) })
		Ui.pad(8).Parent = c
		local list = c:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		if gem then
			Kit.image(gem, { Size = UDim2.fromOffset(24, 24), LayoutOrder = 1, Parent = c })
		end
		local t = Ui.display({
			Text = text,
			TextSize = 18,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 30),
			LayoutOrder = 2,
			Parent = c,
		})
		t.TextColor3 = color
		outline(t, 2)
	end

	local function renderSummary()
		local s = specs()
		if s == nil then
			return
		end
		local preview = Power.deck(s)
		local league = Progress.leagueFor(view.trophies)
		local powerRow = Ui.frame({
			Name = "DeckPower",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = 1,
			Parent = summary,
		}, { Ui.list(true, 10, Enum.HorizontalAlignment.Center) })
		local label = Ui.display({
			Text = "DECK POWER",
			TextSize = 26,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = 1,
			Parent = powerRow,
		})
		label.TextColor3 = C.White
		outline(label, 3)
		local value = Ui.display({
			Name = "Value",
			Text = Format.number(preview.total),
			TextSize = 30,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			LayoutOrder = 2,
			Parent = powerRow,
		})
		value.TextColor3 = C.Green
		outline(value, 3)
		if lastPower and preview.total ~= lastPower then
			if not ctx.reducedMotion() then
				Ui.countUp(value, lastPower, preview.total, Format.number)
			end
			local up = preview.total > lastPower
			local arrow = Kit.image("icon_upgrade", {
				Name = if up then "Up" else "Down",
				ImageColor3 = if up then C.Green else C.Red,
				Rotation = if up then 0 else 180,
				Size = UDim2.fromOffset(28, 28),
				LayoutOrder = 3,
				Parent = powerRow,
			})
			Ui.pulse(arrow, 0.3)
		end
		lastPower = preview.total
		local chipRow = Ui.frame({
			Name = "FamilyBonus",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 2,
			Parent = summary,
		}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
		if #preview.families == 0 then
			chip(chipRow, 1, nil, "NO FAMILY BONUS", C.Muted)
		end
		for i, f in preview.families do
			chip(
				chipRow,
				i,
				`gem_family_{string.lower(f.family)}`,
				`{string.upper(f.family)} +{math.floor(f.value * 100 + 0.5)}% {STAT_NAME[f.stat] or f.stat}`,
				C.Green
			)
		end
		chip(chipRow, 9, nil, `LV CAP {league.rankedLevelCap}`, C.Blue)
	end

	-- The picker: the best copy of each character (a deck takes one copy per character), paged.
	local function renderPicker()
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
		local pages = math.max(1, math.ceil(#cards / PER_PAGE))
		page = math.clamp(page, 1, pages)
		local row = Ui.frame({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, -110, 1, 0),
			Parent = strip,
		}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
		for i = (page - 1) * PER_PAGE + 1, math.min(#cards, page * PER_PAGE) do
			local card = cards[i]
			local usedAt = table.find(slots, card.uid)
			local tile: TextButton = Ui.new("TextButton", {
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(PICK.X, PICK.Y),
				LayoutOrder = i,
				Parent = row,
			})
			local built = Card.build(tile, {
				characterId = card.characterId,
				golden = card.golden,
				level = card.level,
				size = PICK,
				stats = false,
				bare = true,
				hover = true,
			})
			if usedAt then
				local mark = Ui.display({
					Text = tostring(usedAt),
					TextSize = 20,
					BackgroundColor3 = C.Gold,
					BackgroundTransparency = 0,
					AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, 2, 1, 2),
					Size = UDim2.fromOffset(24, 24),
					ZIndex = 80,
					Parent = tile,
				})
				mark.TextColor3 = C.GoldInk
				Ui.corner(6).Parent = mark
			end
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
					flyIn(layer, card, built, slotObj :: GuiObject, ctx.reducedMotion())
				end
			end)
		end
		if #cards == 0 then
			local t = Ui.display({
				Text = "HATCH EGGS FOR CARDS",
				TextSize = 24,
				Size = UDim2.fromScale(1, 1),
				Parent = row,
			})
			t.TextColor3 = C.White
			outline(t, 2)
		end
		if pages > 1 then
			for side = -1, 1, 2 do
				local a = Ui.button(if side < 0 then "◀" else "▶", "secondary", function()
					page += side
					render()
				end, {
					Name = if side < 0 then "Prev" else "Next",
					AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5),
					Position = UDim2.fromScale(if side < 0 then 0 else 1, 0.5),
					Size = UDim2.fromOffset(44, 60),
				})
				bigLabel(a, 26)
				a.setEnabled(if side < 0 then page > 1 else page < pages)
				a.instance.Parent = strip
			end
		end
	end

	render = function()
		view = ctx.state.view
		Ui.clear(slotRow)
		Ui.list(true, 16, Enum.HorizontalAlignment.Center).Parent = slotRow
		Ui.clear(summary)
		Ui.list(false, 4, Enum.HorizontalAlignment.Center).Parent = summary
		Ui.clear(strip)
		Ui.clear(saveHolder)
		renderSlots()
		renderSummary()
		renderPicker()
		local save = Ui.button("SAVE DECK", "primary", function()
			local reply = ctx.request("Deck.Set", { uids = { slots[1], slots[2], slots[3] } })
			if reply.ok then
				ctx.cheer("SAVED!", "icon_check")
			end
		end, {
			Name = "SaveDeck",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(260, 48),
		})
		bigLabel(save, 28)
		save.setEnabled(specs() ~= nil and changed())
		save.instance.Parent = saveHolder
		families.refresh()
	end

	render()
	Ui.stagger(slotRow, ctx.reducedMotion())
	return {
		destroy = function()
			families.destroy()
		end,
		refresh = render,
	}
end
