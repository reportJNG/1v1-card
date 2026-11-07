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
	local p = Ui.panel(layer, "Families", ctx.close, UDim2.fromOffset(780, 470), "icon_deck")
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
		Size = UDim2.new(1, 0, 1, -24),
		Parent = p.body,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(142, 72),
			CellPadding = UDim2.fromOffset(8, 8),
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
			local cell = Ui.frame({
				Name = fam,
				BackgroundColor3 = Color3.fromHex(colors.body):Lerp(C.Panel, 0.55),
				LayoutOrder = i,
				Parent = grid,
			}, {
				Ui.corner(10),
				Ui.stroke(if active then C.Gold else accent:Lerp(C.Stroke, 0.5), if active then 2.5 else 1.2),
				Ui.gradient(Color3.new(1, 1, 1), Color3.new(0.6, 0.6, 0.7), 90),
			})
			cell:SetAttribute("Active", active)
			Ui.image(`family_{string.lower(fam)}`, {
				ImageColor3 = accent,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(36, 36),
				Parent = cell,
			})
			local name = Ui.text({
				Text = fam,
				FontFace = Theme.Face.Title,
				TextSize = 15,
				TextWrapped = false,
				Position = UDim2.fromOffset(50, 6),
				Size = UDim2.new(1, -56, 0, 20),
				Parent = cell,
			})
			Ui.outline(C.Night, 1, 0.3).Parent = name
			Ui.text({
				Text = `+2/3% {STAT_NAME[def.bonusStat] or def.bonusStat}`,
				TextSize = 12,
				TextColor3 = C.Text,
				TextWrapped = false,
				Position = UDim2.fromOffset(50, 26),
				Size = UDim2.new(1, -56, 0, 16),
				Parent = cell,
			})
			local status = if active
				then `ACTIVE ×{count} · +{math.floor(bonus * 100 + 0.5)}%`
				else `Owned {owned[fam] or 0}/{total[fam] or 0}`
			Ui.text({
				Name = "Status",
				Text = status,
				FontFace = Theme.Face.Bold,
				TextSize = 12,
				TextColor3 = if active then C.Gold else C.Muted,
				TextWrapped = false,
				Position = UDim2.fromOffset(50, 44),
				Size = UDim2.new(1, -56, 0, 16),
				Parent = cell,
			})
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
