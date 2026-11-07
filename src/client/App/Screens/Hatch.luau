--!strict
-- The hatch reveal (ART_STYLE section 7, POLISH_MISSION H), shown only after the server has rolled
-- AND saved the result (the reply carries the cards):
--   the world blurs, the egg sits on its pedestal in light rays, shakes harder three times while
--   cracks spread, cracks open with a flash, bursts in the colour of the best rarity, then each
--   card flips from its back (frame, name, rarity banner, stats). x3 and x8 show a grid.
-- Bigger rarities get bigger moments:
--   Legendary adds a slow-mo beat and a gold flash.
--   Mythical adds rainbow shockwaves and a screen shake.
--   Golden eggs are gold throughout.
-- Skip fast-forwards to the cards. "New!" marks the first copy of a character. With auto-open on,
-- a finished reveal opens the next batch by itself (opts.again), until the player stops it, a
-- request fails, or a Legendary or better pauses the run so it is seen. Every beat has a sound
-- slot (Config/Sounds). Reduced motion skips straight to the cards.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
local HatchRules = require(Shared.Domain.Hatch)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Visuals = require(App.Visuals)

local C = Theme.Color

local Hatch = {}

export type Options = {
	-- Character ids the player owned before the request (Hatch.known), for the "New!" tags.
	known: { [string]: boolean }?,
	-- Opens one more batch with the same egg, count and currency; nil when it can't (auto-open).
	again: (() -> { any }?)?,
}

-- The auto-open setting (per session). The shop shows the toggle.
Hatch.auto = false

local RANK = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
local CALLOUT = {
	Common = "Common",
	Rare = "Rare!",
	Epic = "Epic!",
	Legendary = "LEGENDARY!",
	Mythical = "MYTHICAL!!",
}
local AUTO_DELAY = 1.4 -- seconds the finished grid stays up before auto-open continues

-- The ids the player owns now, taken from the view before a request (the reply arrives after the
-- server has added the new cards).
function Hatch.known(view: any): { [string]: boolean }
	local known: { [string]: boolean } = {}
	if view then
		for _, c in view.cards do
			known[c.characterId] = true
		end
	end
	return known
end

-- The largest open count (1, 3 or 8) within both the chosen count and what is available; 0 if none.
function Hatch.fit(want: number, have: number): number
	local best = 0
	for _, n in HatchRules.Counts do
		if n <= want and n <= have then
			best = n
		end
	end
	return best
end

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

-- Card size and grid columns for a batch.
local function layout(n: number): (Vector2, number)
	if n <= 1 then
		return Vector2.new(176, 246), 1
	elseif n <= 3 then
		return Vector2.new(160, 224), 3
	end
	return Vector2.new(112, 157), 4
end

-- Sparkles that pop around the centre of `parent` (Epic and above).
local function sparkles(parent: GuiObject, color: Color3, count: number, reach: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local dist = reach * (0.7 + math.random() * 0.45)
		local s = Ui.image("sparkle", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(10, 10),
			ImageColor3 = color:Lerp(C.White, 0.4),
			ZIndex = 18,
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

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHSV(0.00, 0.65, 1)),
	ColorSequenceKeypoint.new(0.2, Color3.fromHSV(0.12, 0.65, 1)),
	ColorSequenceKeypoint.new(0.4, Color3.fromHSV(0.33, 0.6, 1)),
	ColorSequenceKeypoint.new(0.6, Color3.fromHSV(0.52, 0.65, 1)),
	ColorSequenceKeypoint.new(0.8, Color3.fromHSV(0.72, 0.6, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromHSV(0.88, 0.6, 1)),
})

-- An expanding ring from the egg (the Mythical shockwave): rainbow, or gold for a Golden hatch.
local function shockwave(parent: GuiObject, golden: boolean, delay: number)
	local ring = Ui.frame({
		Name = "Shockwave",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = parent,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	local stroke = Ui.new("UIStroke", { Thickness = 16, Color = C.White, Parent = ring })
	local grad = Ui.new("UIGradient", {
		Color = if golden then ColorSequence.new(C.Gold, C.Gold:Lerp(C.White, 0.5)) else RAINBOW,
		Parent = stroke,
	})
	task.delay(delay, function()
		tween(ring, 0.8, { Size = UDim2.fromOffset(1400, 1400) }, Enum.EasingStyle.Quart)
		tween(stroke, 0.8, { Thickness = 3, Transparency = 1 }, Enum.EasingStyle.Quad)
		tween(grad, 0.8, { Rotation = 240 }, Enum.EasingStyle.Linear)
		task.wait(0.85)
		ring:Destroy()
	end)
end

-- A short screen shake (Mythical).
local function shake(target: GuiObject, seconds: number)
	local steps = math.floor(seconds / 0.035)
	for i = 1, steps do
		local amp = 14 * (1 - i / steps)
		target.Position =
			UDim2.fromOffset(math.random(-100, 100) / 100 * amp, math.random(-100, 100) / 100 * amp)
		task.wait(0.035)
	end
	target.Position = UDim2.fromOffset(0, 0)
end

local function bestOf(cards: { any }): string
	local best = "Common"
	for _, card in cards do
		local def = Characters.ById[card.characterId]
		if RANK[def.rarity] > RANK[best] then
			best = def.rarity
		end
	end
	return best
end

function Hatch.show(ctx: any, firstCards: { any }, egg: Types.EggDef, golden: boolean, opts: Options?)
	local options: Options = opts or {}
	local known: { [string]: boolean } = table.clone(options.known or {})
	local reduced = ctx.reducedMotion()
	local blur: BlurEffect? = nil
	local spin: Tween? = nil

	local handle
	if ctx.ui then
		ctx.ui("hatchStart") -- the hub HUD hides; the panel it came from stays under the hatch
	end
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
		tween(bg, 0.4, { BackgroundTransparency = 0.12 })
		local stage = Ui.frame({ Name = "HatchStage", BackgroundTransparency = 1, Parent = layer })
		local rays = Ui.image("light_rays", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(520, 520),
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
			Name = "Title",
			TextSize = 40,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 50),
			ZIndex = 7,
			Parent = stage,
		}, golden)
		local pedestal = Ui.image("egg_pedestal", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 92),
			Size = UDim2.fromOffset(340, 170),
			Parent = stage,
		})
		local glow = Ui.image("egg_glow", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromOffset(260, 260),
			ImageTransparency = 0.35,
			Parent = stage,
		})
		local flash = Ui.frame({
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			ZIndex = 9,
			Parent = layer,
		})
		-- Per-batch content (egg, cracks, callout, card grid) lives on the board, rebuilt by auto-open.
		local board = Ui.frame({ Name = "Board", BackgroundTransparency = 1, Parent = stage })

		local skipped = false
		local token = 0
		local skipButton = Ui.button("Skip", "ghost", function()
			skipped = true
		end, {
			Name = "Skip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -24, 1, -34),
			Size = UDim2.fromOffset(120, 40),
			ZIndex = 12,
		})
		skipButton.instance.Parent = stage
		local doneButton = Ui.button("Continue", "primary", function()
			handle.destroy()
		end, {
			Name = "Continue",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(240, 48),
			Visible = false,
			ZIndex = 12,
		})
		doneButton.instance.Parent = stage
		local stopButton = Ui.button("Stop auto-open", "secondary", function()
			Hatch.auto = false
		end, {
			Name = "StopAuto",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -34),
			Size = UDim2.fromOffset(240, 48),
			Visible = false,
			ZIndex = 12,
		})
		stopButton.instance.Parent = stage

		local function alive(my: number): boolean
			return stage.Parent ~= nil and token == my
		end
		-- Waits up to `seconds`, returning early once Skip is pressed.
		local function pause(seconds: number)
			local left = seconds
			while left > 0 and not skipped do
				left -= task.wait()
			end
		end

		local play: (cards: { any }) -> ()

		local function finished(my: number, best: string)
			skipButton.instance.Visible = false
			local auto = Hatch.auto and options.again ~= nil and RANK[best] < RANK.Legendary
			if not auto then
				doneButton.instance.Visible = true
				Ui.popIn(doneButton.instance, reduced)
				return
			end
			stopButton.instance.Visible = true
			local left = AUTO_DELAY
			while left > 0 and Hatch.auto and alive(my) do
				left -= task.wait()
			end
			stopButton.instance.Visible = false
			if not alive(my) then
				return
			end
			local again = options.again
			local nextCards = if Hatch.auto and again then again() else nil
			if nextCards and alive(my) then
				play(nextCards)
			elseif alive(my) then
				doneButton.instance.Visible = true
				Ui.popIn(doneButton.instance, reduced)
			end
		end

		play = function(cards: { any })
			token += 1
			local my = token
			skipped = reduced
			Ui.clear(board)
			doneButton.instance.Visible = false
			stopButton.instance.Visible = false
			skipButton.instance.Visible = not reduced

			local best = bestOf(cards)
			local bestColor = if golden then C.Gold else Theme.Rarity[best]
			local legendary = RANK[best] >= RANK.Legendary
			local mythical = best == "Mythical"
			local multi = #cards > 1
			rays.ImageColor3 = if golden then C.Gold else C.Purple
			glow.ImageColor3 = if golden then C.Gold else C.Purple
			glow.Visible = true
			pedestal.Visible = true
			pedestal.ImageColor3 = if golden then C.Gold:Lerp(C.White, 0.35) else C.White
			title.Text = if golden
				then "GOLDEN HATCH"
				else if multi then `HATCHING x{#cards}...` else "HATCHING..."
			title.TextColor3 = C.White

			-- "New!" for the first copy of a character, counting earlier cards in the same batch.
			local isNew: { boolean } = {}
			for i, card in cards do
				isNew[i] = not known[card.characterId]
				known[card.characterId] = true
			end

			local eggHolder = Ui.frame({
				Name = "Egg",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(190, 190),
				Parent = board,
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
			local callout = Ui.display({
				Name = "Callout",
				Text = CALLOUT[best],
				TextSize = 46,
				TextColor3 = bestColor,
				Visible = false,
				Position = UDim2.new(0, 0, 1, -150),
				Size = UDim2.new(1, 0, 0, 56),
				ZIndex = 7,
				Parent = board,
			}, golden)

			local size, columns = layout(#cards)
			local small = #cards > 3
			-- The 8-card grid has no caption: the small card already shows name, rarity and stats.
			local slotSize = Vector2.new(size.X + 10, size.Y + (if small then 8 else 22))
			local rows = math.ceil(#cards / columns)
			local cols = math.min(columns, #cards)
			local grid = Ui.frame({
				Name = "Reveal",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, if small then 0.5 else 0.47),
				Size = UDim2.fromOffset(
					cols * slotSize.X + (cols - 1) * 16,
					rows * slotSize.Y + (rows - 1) * 10
				),
				Visible = false,
				ZIndex = 6,
				Parent = board,
			}, {
				Ui.new("UIGridLayout", {
					CellSize = UDim2.fromOffset(slotSize.X, slotSize.Y),
					CellPadding = UDim2.fromOffset(16, 10),
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})

			local flipped = 0
			-- Each card shows its back, then flips (scale X through 0) to its face.
			local function flipIn(card: any, i: number)
				local def = Characters.ById[card.characterId]
				local slot =
					Ui.frame({ Name = `Card{i}`, BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
				local back = Ui.image("card_back", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromOffset(size.X, size.Y),
					ScaleType = Enum.ScaleType.Stretch,
					Parent = slot,
				})
				local face = Visuals.portrait(slot, card.characterId, card.golden, size, true, card.level)
				face.AnchorPoint = Vector2.new(0.5, 0)
				face.Position = UDim2.fromScale(0.5, 0)
				face.Visible = false
				local faceCard = face:FindFirstChild("Face") :: Frame?
				local label = Ui.text({
					Text = if small
						then def.displayName
						else `{def.displayName} · {def.rarity}{if card.golden then " · Golden" else ""}`,
					FontFace = Theme.Face.Bold,
					TextSize = Theme.Size.small + 1,
					TextColor3 = if card.golden then C.Gold else Theme.Rarity[def.rarity],
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.new(0, 0, 1, -18),
					Size = UDim2.new(1, 0, 0, 18),
					Visible = false,
					Parent = slot,
				})
				Ui.outline(C.Night, 1).Parent = label
				Ui.fit(label, Theme.Size.small + 1, 8)
				local tag: Frame? = nil
				if isNew[i] then
					local t = Ui.frame({
						Name = "New",
						BackgroundColor3 = C.Green,
						Position = UDim2.new(0, -10, 0.3, 0), -- the left edge, clear of the rarity banner and level badge
						Size = UDim2.fromOffset(if small then 40 else 50, if small then 18 else 22),
						Rotation = -8,
						Visible = false,
						ZIndex = 20,
						Parent = slot,
					}, { Ui.corner(6), Ui.stroke(C.Night, 2) })
					local word = Ui.display({
						Text = "NEW!",
						TextSize = if small then 13 else 16,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 21,
						Parent = t,
					})
					word.TextColor3 = C.White
					tag = t
				end
				local flip: Tween? = nil
				local function land()
					if flip then
						flip:Cancel()
					end
					back.Visible = false
					face.Visible = true
					if faceCard then
						faceCard.Size = UDim2.fromOffset(size.X, size.Y)
					end
					label.Visible = not small
					if tag then
						tag.Visible = true
					end
				end
				local function counted()
					flipped += 1
					if flipped == #cards and alive(my) then
						task.spawn(finished, my, best)
					end
				end
				if skipped then
					land()
					counted()
					return
				end
				pause(0.15 + (i - 1) * (if small then 0.16 else 0.25))
				if not alive(my) then
					return
				end
				if skipped then
					land()
					counted()
					return
				end
				Ui.sound("card_flip")
				local half = tween(back, 0.14, { Size = UDim2.fromOffset(2, size.Y) }, Enum.EasingStyle.Quad)
				half.Completed:Wait()
				if not alive(my) then
					return
				end
				back.Visible = false
				face.Visible = true
				label.Visible = not small
				if faceCard and not skipped then
					faceCard.Size = UDim2.fromOffset(2, size.Y)
					flip = tween(
						faceCard,
						0.22,
						{ Size = UDim2.fromOffset(size.X, size.Y) },
						Enum.EasingStyle.Back
					)
				else
					land()
				end
				if tag then
					tag.Visible = true
					Ui.popIn(tag)
				end
				if RANK[def.rarity] >= RANK.Epic or card.golden then
					local color = if card.golden then C.Gold else Theme.Rarity[def.rarity]
					sparkles(slot, color, if small then 6 else 10, if small then 70 else 130)
				end
				counted()
			end

			local function reveal()
				eggHolder.Visible = false
				pedestal.Visible = false
				glow.ImageColor3 = bestColor
				rays.ImageColor3 = bestColor
				grid.Visible = true
				if multi and small then
					-- No room under an 8-card grid: the title carries the callout.
					title.Text = CALLOUT[best]
					title.TextColor3 = bestColor
				else
					title.Text = if golden then "GOLDEN!" elseif multi then "NEW CARDS!" else "NEW CARD!"
					callout.Visible = true
				end
				Ui.sound(`reveal_{string.lower(best)}`)
				if not skipped then
					Ui.popIn(if small then title else callout)
					Ui.pulse(glow, 0.6)
				end
				for i, card in cards do
					task.spawn(flipIn, card, i)
				end
			end

			if skipped then
				reveal()
				return
			end
			task.spawn(function()
				-- Three shakes, each stronger, with the cracks spreading.
				for i = 1, 3 do
					if skipped or not alive(my) then
						break
					end
					Ui.sound("hatch_shake")
					local amp = 6 + i * 5
					for _ = 1, 2 + i do
						tween(eggHolder, 0.05, { Rotation = amp }).Completed:Wait()
						tween(eggHolder, 0.05, { Rotation = -amp }).Completed:Wait()
					end
					tween(eggHolder, 0.06, { Rotation = 0 })
					tween(crack, 0.15, { ImageTransparency = 1 - i * 0.3 })
					Ui.pulse(eggHolder, 0.05 * i)
					pause(0.28)
				end
				if not alive(my) then
					return
				end
				-- Legendary and up: time slows, the room darkens, the cracks glow gold.
				if legendary and not skipped then
					tween(bg, 0.3, { BackgroundTransparency = 0.05 })
					tween(rays, 0.8, { ImageColor3 = C.Gold, ImageTransparency = 0.15 })
					tween(
						glow,
						0.9,
						{ ImageColor3 = C.Gold, Size = UDim2.fromOffset(340, 340) },
						Enum.EasingStyle.Sine
					)
					tween(crack, 0.6, { ImageColor3 = C.Gold, ImageTransparency = 0 })
					tween(
						eggHolder,
						1.0,
						{ Size = UDim2.fromOffset(236, 236), Rotation = 3 },
						Enum.EasingStyle.Sine
					)
					pause(1.05)
					tween(bg, 0.4, { BackgroundTransparency = 0.12 })
				end
				if not alive(my) then
					return
				end
				if not skipped then
					Ui.sound("hatch_crack")
					tween(eggHolder, 0.12, { Size = UDim2.fromOffset(250, 250), Rotation = 0 }).Completed:Wait()
					flash.BackgroundColor3 = if legendary or golden then C.Gold else C.White
					tween(flash, 0.1, { BackgroundTransparency = 0 }).Completed:Wait()
				end
				if not alive(my) then
					return
				end
				-- The burst in the rarity colour.
				Ui.sound("hatch_burst")
				local burst = Ui.image("egg_glow", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.46),
					Size = UDim2.fromOffset(190, 190),
					ImageColor3 = bestColor,
					ImageTransparency = 0.05,
					ZIndex = 5,
					Parent = board,
				})
				tween(
					burst,
					0.7,
					{ Size = UDim2.fromOffset(900, 900), ImageTransparency = 1 },
					Enum.EasingStyle.Quart
				)
				if RANK[best] >= RANK.Epic or golden then
					sparkles(board, bestColor, 16, 240)
				end
				if mythical and not skipped then
					shockwave(layer, golden, 0)
					shockwave(layer, golden, 0.18)
					shockwave(layer, golden, 0.36)
					task.spawn(shake, stage, 0.55)
				end
				reveal()
				flash.BackgroundColor3 = bestColor
				flash.BackgroundTransparency = math.max(flash.BackgroundTransparency, 0.35)
				tween(flash, if legendary then 0.8 else 0.5, { BackgroundTransparency = 1 })
			end)
		end

		play(firstCards)
		return {
			destroy = function()
				token += 1
				if ctx.ui then
					ctx.ui("hatchEnd")
				end
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
