--!strict
-- The hatch reveal (ART_STYLE section 7), shown only after the server has rolled AND saved the
-- result (the reply carries the cards): the world blurs, the egg sits on its pedestal in light
-- rays, shakes harder three times while cracks spread, flashes white, bursts in the colour of
-- the best rarity, then each card flips from its back with a rarity callout. Epic and above add
-- sparkles; Golden hatches are gold throughout. Reduced motion skips straight to the cards.
local Lighting = game:GetService("Lighting")
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

local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
local CALLOUT = {
	Common = "Common",
	Rare = "Rare!",
	Epic = "Epic!",
	Legendary = "LEGENDARY!",
	Mythical = "MYTHICAL!!",
}

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

-- Sparkles that pop around a point (Epic and above).
local function sparkles(parent: GuiObject, color: Color3, count: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local dist = 110 + math.random() * 70
		local s = Ui.image("sparkle", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			ImageColor3 = color:Lerp(C.White, 0.4),
			ZIndex = 8,
			Parent = parent,
		})
		task.delay(i * 0.03, function()
			tween(s, 0.5, {
				Position = UDim2.new(0.5, math.cos(angle) * dist, 0.5, math.sin(angle) * dist),
				Size = UDim2.fromOffset(28, 28),
				Rotation = 90,
			}, Enum.EasingStyle.Quart)
			task.wait(0.45)
			tween(s, 0.4, { ImageTransparency = 1, Size = UDim2.fromOffset(6, 6) })
			task.wait(0.4)
			s:Destroy()
		end)
	end
end

function Hatch.show(ctx: any, cards: { any }, egg: Types.EggDef, golden: boolean)
	local best = "Common"
	for _, card in cards do
		local def = Characters.ById[card.characterId]
		if RANK[def.rarity] > RANK[best] then
			best = def.rarity
		end
	end
	local bestColor = if golden then C.Gold else Theme.Rarity[best]
	local reduced = ctx.reducedMotion()
	local blur: BlurEffect? = nil
	local spin: Tween? = nil

	local handle
	handle = ctx.overlay(function(layer)
		-- Camera focus: blur the world behind the hatch.
		local b = Instance.new("BlurEffect")
		b.Name = "HatchBlur"
		b.Size = 0
		b.Parent = Lighting
		blur = b
		tween(b, 0.4, { Size = 18 })

		local bg = Ui.frame({
			BackgroundColor3 = C.Night,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			Parent = layer,
		})
		tween(bg, 0.4, { BackgroundTransparency = 0.25 })
		local stage = Ui.frame({ Name = "HatchStage", BackgroundTransparency = 1, Parent = layer })
		local rays = Ui.image("light_rays", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(520, 520),
			ImageColor3 = if golden then C.Gold else C.Purple,
			ImageTransparency = 0.45,
			Parent = stage,
		})
		if not reduced then
			local t = TweenService:Create(
				rays,
				TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			t:Play()
			spin = t
		end
		local title = Ui.display({
			Text = if golden then "GOLDEN HATCH" else "HATCHING...",
			TextSize = 40,
			Position = UDim2.fromOffset(0, 34),
			Size = UDim2.new(1, 0, 0, 50),
			Parent = stage,
		}, golden)
		Ui.image("egg_pedestal", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 92),
			Size = UDim2.fromOffset(340, 170),
			Parent = stage,
		})
		local glow = Ui.image("egg_glow", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(260, 260),
			ImageColor3 = if golden then C.Gold else C.Purple,
			ImageTransparency = 0.35,
			Parent = stage,
		})
		local eggHolder = Ui.frame({
			Name = "Egg",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(190, 190),
			Parent = stage,
		})
		Visuals.egg(eggHolder, egg, golden, 190)
		local crack = Ui.image("crack_overlay", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(170, 170),
			ImageTransparency = 1,
			ImageColor3 = bestColor:Lerp(C.White, 0.5),
			ZIndex = 3,
			Parent = eggHolder,
		})
		local flash = Ui.frame({
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			ZIndex = 9,
			Parent = layer,
		})
		local callout = Ui.display({
			Text = CALLOUT[best],
			TextSize = 46,
			TextColor3 = bestColor,
			Visible = false,
			Position = UDim2.new(0, 0, 1, -150),
			Size = UDim2.new(1, 0, 0, 56),
			ZIndex = 7,
			Parent = stage,
		}, golden)
		local revealRow = Ui.frame({
			Name = "Reveal",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.47),
			Size = UDim2.fromOffset(#cards * 186, 250),
			Visible = false,
			ZIndex = 6,
			Parent = stage,
		}, { Ui.list(true, 16, Enum.HorizontalAlignment.Center) })
		local doneButton = Ui.button("Continue", "primary", function()
			handle.destroy()
		end, {
			Name = "Continue",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(240, 48),
			Visible = false,
		})
		doneButton.instance.Parent = stage

		-- Each card shows its back, then flips (scale X through 0) to its face.
		local function flipIn(card: any, i: number)
			local def = Characters.ById[card.characterId]
			local slot = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(170, 250),
				LayoutOrder = i,
				Parent = revealRow,
			})
			local back = Ui.image("card_back", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.45),
				Size = UDim2.fromOffset(160, 224),
				ScaleType = Enum.ScaleType.Stretch,
				Parent = slot,
			})
			local face = Visuals.portrait(slot, card.characterId, card.golden, Vector2.new(160, 224), true)
			face.AnchorPoint = Vector2.new(0.5, 0.5)
			face.Position = UDim2.fromScale(0.5, 0.45)
			face.Visible = reduced
			back.Visible = not reduced
			local label = Ui.text({
				Text = `{def.displayName} · {def.rarity}{if card.golden then " · Golden" else ""}`,
				FontFace = Theme.Face.Bold,
				TextSize = Theme.Size.small + 1,
				TextColor3 = if card.golden then C.Gold else Theme.Rarity[def.rarity],
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 1, -18),
				Size = UDim2.new(1, 0, 0, 18),
				Parent = slot,
			})
			Ui.outline(C.Night, 1).Parent = label
			if reduced then
				return
			end
			task.wait(0.15 + (i - 1) * 0.25)
			local half = tween(back, 0.14, { Size = UDim2.fromOffset(2, 224) }, Enum.EasingStyle.Quad)
			half.Completed:Wait()
			back.Visible = false
			face.Visible = true
			local faceCard = face:FindFirstChild("Face") :: Frame
			faceCard.Size = UDim2.fromOffset(2, 224)
			tween(faceCard, 0.22, { Size = UDim2.fromOffset(160, 224) }, Enum.EasingStyle.Back)
			if RANK[def.rarity] >= RANK.Epic or card.golden then
				sparkles(slot, if card.golden then C.Gold else Theme.Rarity[def.rarity], 10)
			end
		end

		local function reveal()
			eggHolder.Visible = false
			glow.ImageColor3 = bestColor
			rays.ImageColor3 = bestColor
			revealRow.Visible = true
			callout.Visible = true
			title.Text = if golden then "GOLDEN!" elseif #cards > 1 then "NEW CARDS!" else "NEW CARD!"
			Ui.sound(if RANK[best] >= RANK.Epic then "reveal_rare" else "reveal")
			if not reduced then
				Ui.popIn(callout)
				Ui.pulse(glow, 0.6)
			end
			for i, card in cards do
				task.spawn(flipIn, card, i)
			end
			task.delay(if reduced then 0 else 0.4 + #cards * 0.25, function()
				doneButton.instance.Visible = true
				Ui.popIn(doneButton.instance, reduced)
			end)
		end

		if reduced then
			reveal()
		else
			task.spawn(function()
				-- Three shakes, each stronger, with the cracks spreading.
				for i = 1, 3 do
					Ui.sound("hatch_shake")
					local amp = 6 + i * 5
					for _ = 1, 2 + i do
						tween(eggHolder, 0.05, { Rotation = amp }).Completed:Wait()
						tween(eggHolder, 0.05, { Rotation = -amp }).Completed:Wait()
					end
					tween(eggHolder, 0.06, { Rotation = 0 })
					tween(crack, 0.15, { ImageTransparency = 1 - i * 0.3 })
					Ui.pulse(eggHolder, 0.05 * i)
					task.wait(0.28)
				end
				Ui.sound("hatch_crack")
				tween(eggHolder, 0.12, { Size = UDim2.fromOffset(230, 230) }).Completed:Wait()
				tween(flash, 0.1, { BackgroundTransparency = 0 }).Completed:Wait()
				if stage.Parent then
					reveal()
				end
				flash.BackgroundColor3 = bestColor
				tween(flash, 0.5, { BackgroundTransparency = 1 })
			end)
		end
		return {
			destroy = function()
				if spin then
					spin:Cancel()
				end
				if blur then
					local fade = tween(blur, 0.25, { Size = 0 })
					local bl = blur
					fade.Completed:Connect(function()
						bl:Destroy()
					end)
				end
			end,
		}
	end)
end

return Hatch
