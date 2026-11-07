--!strict
-- Families (the concept board's Families list): all 15 families with their glyph, the stat their
-- bonus raises (2 in a deck: +2%, 3: +3%), how many of their characters the player owns, and
-- which are active in the saved deck. Opened from the Deck Builder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Families = require(Shared.Config.Families)
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Kit = require(App.Kit)

local C = Theme.Color

local STAT_NAME = { hp = "HP", atk = "Attack", def = "Defence", spd = "Speed", crit = "Crit chance" }

local ORDER = {
	"Flame",
	"Ice",
	"Lightning",
	"Shadow",
	"Divine",
	"Beast",
	"Dragon",
	"Warrior",
	"Ninja",
	"Royal",
	"Cosmic",
	"Ancient",
	"Mystic",
	"Spirit",
	"Demon",
}

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Families", ctx.close, UDim2.fromOffset(560, 470), "icon_deck")
	local back = Ui.button("Deck Builder", "secondary", function()
		ctx.open("Deck")
	end, {
		Name = "BackToDeck",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -60, 0.5, 0),
		Size = UDim2.fromOffset(150, 34),
	})
	back.instance.Parent = p.header
	Ui.text({
		Text = "Two cards of one family in your deck: +2% to its stat. Three: +3%. Crit families add crit chance.",
		TextSize = Theme.Size.small,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = p.body,
	})
	local grid = Ui.frame({
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -70),
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(255, 33),
			CellPadding = UDim2.fromOffset(8, 4),
			FillDirection = Enum.FillDirection.Vertical,
			FillDirectionMaxCells = 8,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function render()
		local view = ctx.state.view
		Ui.clear(grid)
		-- Families in the saved deck, and owned characters per family.
		local inDeck: { [string]: number } = {}
		for _, uid in view.deck do
			local card = view.cards[uid]
			if card then
				local fam = Characters.ById[card.characterId].family
				inDeck[fam] = (inDeck[fam] or 0) + 1
			end
		end
		-- Different characters owned per family (copies of one character count once).
		local seen: { [string]: boolean } = {}
		local owned: { [string]: number } = {}
		for _, card in view.cards do
			if not seen[card.characterId] then
				seen[card.characterId] = true
				local fam = Characters.ById[card.characterId].family
				owned[fam] = (owned[fam] or 0) + 1
			end
		end
		local total: { [string]: number } = {}
		for _, c in Characters.List do
			if c.enabled then
				total[c.family] = (total[c.family] or 0) + 1
			end
		end
		for i, fam in ORDER do
			local def = Families.Defs[fam]
			local colors = Art.FamilyColors[fam]
			local count = inDeck[fam] or 0
			local bonus = Families.SynergyBonus[math.min(count, 3)] or 0
			local active = bonus > 0
			local accent = Color3.fromHex(colors.accent)
			-- A list row (`hd-04`): the glowing family gem and name; active families glow gold,
			-- inactive ones are dimmed.
			local cell = Ui.frame({
				Name = fam,
				BackgroundColor3 = if active then Color3.fromHex("#3A2A10") else Color3.fromHex("#140F30"),
				BackgroundTransparency = if active then 0.1 else 0.35,
				LayoutOrder = i,
				Parent = grid,
			}, {
				Ui.corner(8),
				Ui.stroke(
					if active then C.Gold else accent:Lerp(C.Stroke, 0.6),
					if active then 2 else 1,
					if active then 0 else 0.4
				),
			})
			cell:SetAttribute("Active", active)
			local gem = Kit.image(`gem_family_{string.lower(fam)}`, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 4, 0.5, 0),
				Size = UDim2.fromOffset(32, 32),
				ImageTransparency = if active then 0 else 0.45,
				Parent = cell,
			})
			Ui.image(`family_{string.lower(fam)}`, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				ImageTransparency = if active then 0 else 0.4,
				ZIndex = 2,
				Parent = gem,
			})
			local name = Ui.text({
				Text = fam,
				FontFace = Theme.Face.Title,
				TextSize = 15,
				TextColor3 = if active then C.White else C.Muted,
				TextWrapped = false,
				Position = UDim2.fromOffset(42, 1),
				Size = UDim2.new(1, -48, 0, 18),
				Parent = cell,
			})
			Ui.outline(C.Night, 1, 0.3).Parent = name
			local stat = STAT_NAME[def.bonusStat] or def.bonusStat
			Ui.text({
				Name = "Status",
				Text = if active
					then `ACTIVE x{count} · +{math.floor(bonus * 100 + 0.5)}% {stat}`
					else `+2/3% {stat} · owned {owned[fam] or 0}/{total[fam] or 0}`,
				FontFace = Theme.Face.Bold,
				TextSize = 11,
				TextColor3 = if active then C.GoldHi else C.Muted,
				TextWrapped = false,
				Position = UDim2.fromOffset(42, 18),
				Size = UDim2.new(1, -48, 0, 13),
				Parent = cell,
			})
		end
	end

	-- Footer: a crown and the hint.
	local footer = Ui.frame({
		Name = "Footer",
		BackgroundColor3 = Color3.fromHex("#140F30"),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = p.body,
	}, { Ui.corner(10), Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
	Kit.image("emblem_crown_gold", { Size = UDim2.fromOffset(32, 32), LayoutOrder = 1, Parent = footer })
	Ui.text({
		Text = "Collect more cards to activate bonuses!",
		FontFace = Theme.Face.Bold,
		TextSize = 14,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = 2,
		Parent = footer,
	})
	render()
	return { destroy = function() end, refresh = render }
end
