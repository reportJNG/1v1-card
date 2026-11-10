--!strict
-- The "Odds" pop-up shown before any Coin or Robux egg purchase: the exact chance of every
-- character, from Shared/Domain/Odds (the same table the server rolls from).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Odds = require(Shared.Domain.Odds)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)

local C = Theme.Color

local OddsPopup = {}

-- The odds pop-up: every character's exact chance, for the normal or Golden version.
function OddsPopup.show(ctx: any, egg: Types.EggDef, golden: boolean)
	local box
	box = ctx.overlay(function(layer)
		local rows, rounded = Odds.display(egg, golden)
		Ui.frame({ BackgroundColor3 = C.Black, BackgroundTransparency = 0.4, Parent = layer })
		local p = Ui.panel(
			layer,
			`ODDS: {string.upper(egg.displayName)}{if golden then " (GOLDEN)" else ""}`,
			function()
				box.destroy()
			end,
			UDim2.fromOffset(520, 470),
			"icon_odds"
		)

		local list = Ui.scroll({ Size = UDim2.new(1, 0, 1, -44), Parent = p.body })
		list.ScrollBarThickness = 0
		Ui.list(false, 6).Parent = list
		for i, row in rows do
			local def = Characters.ById[row.characterId]
			local color = Theme.Rarity[row.rarity]
			local r = Ui.glowTile("Frame", {
				Size = UDim2.new(1, -4, 0, 44),
				LayoutOrder = i,
				Parent = list,
			}, color, false)
			local name = Ui.text({
				Text = def.displayName,
				FontFace = Theme.Face.Title,
				TextSize = 20,
				TextWrapped = false,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(0.5, -12, 1, 0),
				ZIndex = 2,
				Parent = r,
			})
			Ui.outline(C.Night, 2).Parent = name
			Ui.fit(name, 20, 12)
			local rar = Ui.display({
				Text = string.upper(Rarities.label(row.rarity)),
				TextSize = 18,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.26, 1),
				ZIndex = 2,
				Parent = r,
			})
			rar.TextColor3 = color
			Ui.outline(C.Night, 2).Parent = rar
			Ui.fit(rar, 18, 10)
			local pct = Ui.display({
				Text = row.text,
				TextSize = 24,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.76, 0),
				Size = UDim2.new(0.24, -12, 1, 0),
				ZIndex = 2,
				Parent = r,
			})
			pct.TextColor3 = C.White
			Ui.outline(C.Night, 3).Parent = pct
		end
		local note = Ui.text({
			Text = if rounded
				then "Exact chance per character. Rounded, so they may not add up to exactly 100%."
				else "Exact chance per character for every open of this egg.",
			FontFace = Theme.Face.Bold,
			TextSize = 16,
			TextColor3 = C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -38),
			Size = UDim2.new(1, 0, 0, 38),
			Parent = p.body,
		})
		Ui.fit(note, 16, 11)
		return { destroy = function() end }
	end)
end

return OddsPopup
