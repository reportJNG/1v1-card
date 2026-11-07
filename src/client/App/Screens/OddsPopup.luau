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
		Ui.frame({ BackgroundColor3 = C.Black, BackgroundTransparency = 0.4, Parent = layer })
		local p = Ui.panel(layer, `Odds: {egg.displayName}{if golden then " (Golden)" else ""}`, function()
			box.destroy()
		end, UDim2.fromOffset(460, 400))
		local rows, rounded = Odds.display(egg, golden)
		local list = Ui.scroll({ Size = UDim2.new(1, 0, 1, -40), Parent = p.body })
		Ui.list(false, 4).Parent = list
		for i, row in rows do
			local def = Characters.ById[row.characterId]
			local r = Ui.frame({
				BackgroundColor3 = C.Raised,
				Size = UDim2.new(1, -8, 0, 30),
				LayoutOrder = i,
				Parent = list,
			}, {
				Ui.corner(6),
			})
			Ui.text({
				Text = def.displayName,
				FontFace = Theme.Face.Bold,
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.fromScale(0.5, 1),
				Parent = r,
			})
			Ui.text({
				Text = Rarities.label(row.rarity),
				TextColor3 = Theme.Rarity[row.rarity],
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.25, 1),
				Parent = r,
			})
			Ui.text({
				Text = row.text,
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.fromScale(0.75, 0),
				Size = UDim2.new(0.25, -10, 1, 0),
				Parent = r,
			})
		end
		Ui.text({
			Text = if rounded
				then "Exact chance per character. Shown values are rounded, so they may not add up to exactly 100%."
				else "Exact chance per character for every open of this egg.",
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			Position = UDim2.new(0, 0, 1, -34),
			Size = UDim2.new(1, 0, 0, 34),
			Parent = p.body,
		})
		return { destroy = function() end }
	end)
end

return OddsPopup
