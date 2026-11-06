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

local C = Theme.Color

local STAT_NAME = { hp = "HP", atk = "ATK", def = "DEF", spd = "SPD", crit = "crit" }

return function(ctx: any, layer: Frame, _arg: any?): any
	local view = ctx.state.view
	local p = Ui.panel(layer, "Deck Builder", ctx.close, UDim2.fromOffset(770, 470), "icon_deck")
	local slots: { string? } = { view.deck[1], view.deck[2], view.deck[3] }
	local active = 1

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
			local slot = Ui.new("TextButton", {
				Text = "",
				BackgroundColor3 = C.Raised,
				Size = UDim2.fromOffset(130, 210),
				LayoutOrder = i,
				Name = `Slot{i}`,
				Parent = slotRow,
			}, {
				Ui.corner(10),
				Ui.stroke(if active == i then C.Gold else C.Stroke, if active == i then 2.5 else 1),
			})
			if card then
				local portrait =
					Visuals.portrait(slot, card.characterId, card.golden, Vector2.new(118, 160), true)
				portrait.Position = UDim2.fromOffset(6, 6)
				Ui.text({
					Text = `Lv {card.level} · ⚡ {Power.card(card.characterId, card.level)}`,
					FontFace = Theme.Face.Bold,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 172),
					Size = UDim2.new(1, 0, 0, 20),
					Parent = slot,
				})
			else
				Ui.text({
					Text = `Slot {i}\nPick a card`,
					TextColor3 = C.Muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.fromScale(1, 1),
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
			Ui.text({
				Text = `Deck Power: {preview.total}`,
				FontFace = Theme.Face.Title,
				TextSize = 20,
				TextColor3 = C.Green,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 1,
				Parent = summary,
			})
			local bonusText = "Family bonus: none (2+ cards of one family give a bonus)"
			if #preview.families > 0 then
				local parts = {}
				for _, f in preview.families do
					table.insert(
						parts,
						`{f.family} ×{f.count}: +{math.floor(f.value * 100 + 0.5)}% {STAT_NAME[f.stat] or f.stat}`
					)
				end
				bonusText = "Family bonus: " .. table.concat(parts, ", ")
			end
			Ui.text({
				Text = bonusText,
				TextSize = Theme.Size.small,
				TextColor3 = C.Purple,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 2,
				Parent = summary,
			})
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
				ctx.toast("Deck saved.", "good")
			end
		end, { Size = UDim2.fromOffset(220, 40), LayoutOrder = 4, Name = "SaveDeck" })
		save.setEnabled(s ~= nil)
		save.instance.Parent = summary

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
			local portrait = Visuals.portrait(tile, card.characterId, card.golden, Vector2.new(76, 92))
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
				slots[active] = card.uid
				active = active % 3 + 1
				render()
			end)
		end
		if #cards == 0 then
			Ui.text({ Text = "Hatch eggs in the Shop to get cards.", TextColor3 = C.Muted, Parent = pickList })
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
