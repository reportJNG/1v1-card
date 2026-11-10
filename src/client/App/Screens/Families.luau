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

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

-- `arg.side`: drawn beside the Deck Builder (target hd-04) instead of centred on its own.
return function(ctx: any, layer: Frame, arg: any?): any
	local side = typeof(arg) == "table" and arg.side == true
	local p =
		Ui.panel(layer, "FAMILIES", if side then nil else ctx.close, UDim2.fromOffset(330, 470), "icon_deck")
	if side then
		p.frame.Position = UDim2.new(0.5, 300, 0.5, 18)
	end
	local grid = Ui.frame({
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -54),
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(144, 38),
			CellPadding = UDim2.fromOffset(6, 5),
			FillDirection = Enum.FillDirection.Vertical,
			FillDirectionMaxCells = 8,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local function render()
		local view = ctx.state.view
		Ui.clear(grid)
		local layout = Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(144, 38),
			CellPadding = UDim2.fromOffset(6, 5),
			FillDirection = Enum.FillDirection.Vertical,
			FillDirectionMaxCells = 8,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
		layout.Parent = grid
		-- Families in the saved deck.
		local inDeck: { [string]: number } = {}
		for _, uid in view.deck do
			local card = view.cards[uid]
			if card then
				local fam = Characters.ById[card.characterId].family
				inDeck[fam] = (inDeck[fam] or 0) + 1
			end
		end
		for i, fam in ORDER do
			local def = Families.Defs[fam]
			local colors = Art.FamilyColors[fam]
			local count = inDeck[fam] or 0
			local bonus = Families.SynergyBonus[math.min(count, 3)] or 0
			local active = bonus > 0
			local accent = Color3.fromHex(colors.accent)
			-- The glowing family gem and its name; active families glow gold with their bonus,
			-- inactive ones are dimmed (target hd-04).
			local cell = Ui.glowTile("Frame", {
				Name = fam,
				LayoutOrder = i,
				Parent = grid,
			}, if active then C.Gold else accent:Lerp(C.Night, 0.7), active)
			cell:SetAttribute("Active", active)
			local gem = Kit.image(`gem_family_{string.lower(fam)}`, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(34, 34),
				ImageTransparency = if active then 0 else 0.35,
				ZIndex = 2,
				Parent = cell,
			})
			Ui.image(`family_{string.lower(fam)}`, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.5, 0.5),
				ImageTransparency = if active then 0 else 0.35,
				ZIndex = 3,
				Parent = gem,
			})
			local name = Ui.display({
				Text = string.upper(fam),
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(40, 0),
				Size = UDim2.new(1, -44, 1, 0),
				ZIndex = 2,
				Parent = cell,
			})
			name.TextColor3 = if active then C.White else C.Muted
			outline(name, 2)
			Ui.fit(name, 17, 11)
			if active then
				local plus = Ui.display({
					Name = "Bonus",
					Text = `+{math.floor(bonus * 100 + 0.5)}%`,
					TextSize = 16,
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 0),
					Size = UDim2.fromOffset(50, 38),
					ZIndex = 3,
					Parent = cell,
				})
				plus.TextColor3 = C.Green
				outline(plus, 2)
				local stat = STAT_NAME[def.bonusStat] or def.bonusStat
				cell:SetAttribute("Stat", stat)
			end
		end
	end

	-- Footer: a crown and the hint.
	local footer = Ui.glowTile("Frame", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = p.body,
	}, C.Gold, false)
	Kit.image("emblem_crown_gold", {
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 2,
		Parent = footer,
	})
	local hint = Ui.text({
		Text = "Collect more cards to activate bonuses!",
		FontFace = Theme.Face.Title,
		TextSize = 17,
		TextWrapped = true,
		Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -56, 1, 0),
		ZIndex = 2,
		Parent = footer,
	})
	outline(hint, 2)
	Ui.fit(hint, 17, 11)
	render()
	return { destroy = function() end, refresh = render }
end
