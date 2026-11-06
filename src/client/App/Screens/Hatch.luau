--!strict
-- The hatch reveal, shown only after the server has rolled AND saved the result (the reply
-- carries the cards). Egg shake, flash, then the card(s) pop in. Golden hatches get a gold
-- treatment. "Reduced motion" skips straight to the reveal.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Visuals = require(App.Visuals)

local C = Theme.Color

local Hatch = {}

local function tween(
	inst: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?
): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), goal)
	t:Play()
	return t
end

function Hatch.show(ctx: any, cards: { any }, egg: Types.EggDef, golden: boolean)
	local handle
	handle = ctx.overlay(function(layer)
		local bg = Ui.frame({
			BackgroundColor3 = C.Background,
			BackgroundTransparency = 0.1,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			Parent = layer,
		})
		local stage = Ui.frame({ BackgroundTransparency = 1, Parent = layer })
		local title = Ui.text({
			Text = if golden then "GOLDEN HATCH" else "Hatching...",
			Font = Theme.Font.Title,
			TextSize = 30,
			TextColor3 = if golden then C.Gold else C.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 40),
			Parent = stage,
		})
		local eggHolder = Ui.frame({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromOffset(180, 180),
			Parent = stage,
		})
		Visuals.egg(eggHolder, egg, golden, 180)
		local flash = Ui.frame({
			BackgroundColor3 = if golden then C.Gold else Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			ZIndex = 5,
			Parent = layer,
		})
		local revealRow = Ui.frame({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(#cards * 170, 230),
			Visible = false,
			Parent = stage,
		}, { Ui.list(true, 14, Enum.HorizontalAlignment.Center) })
		local doneButton = Ui.button("Continue", "primary", function()
			handle.destroy()
		end, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -40),
			Size = UDim2.fromOffset(220, 44),
			Visible = false,
		})
		doneButton.instance.Parent = stage

		local function reveal()
			eggHolder.Visible = false
			revealRow.Visible = true
			for i, card in cards do
				local def = Characters.ById[card.characterId]
				local slot = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(150, 230),
					LayoutOrder = i,
					Parent = revealRow,
				})
				local scale =
					Ui.new("UIScale", { Scale = if ctx.reducedMotion() then 1 else 0.2, Parent = slot })
				Visuals.portrait(slot, card.characterId, card.golden, Vector2.new(150, 200))
				Ui.text({
					Text = `{def.displayName} · {def.rarity}`,
					Font = Theme.Font.Bold,
					TextSize = Theme.Size.small,
					TextColor3 = Theme.Rarity[def.rarity],
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 206),
					Size = UDim2.new(1, 0, 0, 20),
					Parent = slot,
				})
				if not ctx.reducedMotion() then
					tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
			title.Text = if golden then "GOLDEN!" elseif #cards > 1 then "New cards!" else "New card!"
			doneButton.instance.Visible = true
		end

		if ctx.reducedMotion() then
			reveal()
		else
			task.spawn(function()
				for i = 1, 3 do
					tween(eggHolder, 0.12, { Rotation = 10 + i * 3 }).Completed:Wait()
					tween(eggHolder, 0.12, { Rotation = -10 - i * 3 }).Completed:Wait()
				end
				tween(eggHolder, 0.1, { Rotation = 0 }).Completed:Wait()
				tween(flash, 0.15, { BackgroundTransparency = 0 }).Completed:Wait()
				if bg.Parent then
					reveal()
				end
				tween(flash, 0.4, { BackgroundTransparency = 1 })
			end)
		end
		return { destroy = function() end }
	end)
end

return Hatch
