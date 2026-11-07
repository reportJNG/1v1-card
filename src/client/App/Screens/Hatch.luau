--!strict
-- The egg opening (MISSION 7.3, board `ui-refs-2/02`), shown only after the server has rolled AND
-- saved the result (the reply carries the cards), so the animation only shows it: no fake
-- "almost" moments, and every tint is the real rarity being revealed.
--   1 Summon  the screen dims and blurs; the pack egg rises out of a glowing summoning circle with
--             turning runes while the view pushes in (0.9 s)
--   2 Crack   rising shakes; crack sprites (our own, on a layer over the unedited egg) spread; the
--             glow shifts from neutral to the rarity colour (1.0 s, +0.4 s slow-mo for SSR and up)
--   3 Break   the egg hides; tier-tinted shard sprites burst out with a flash, a shockwave ring and
--             a short screen shake (0.5 s)
--   4 Reveal  black silhouettes rise in an aura of their rarity colour with light rays; the badge
--             slams in (0.8 s; UR +0.6 s with a light pillar)
--   5 Get card the silhouettes turn into the cards, which flip in, with "NEW!" or "+1"; confetti
--             for SSR and up; Continue, Open Again, and Equip for a single new card
-- x3 / x8 run stages 1-3 once and reveal a row or grid. Tap anywhere (or Skip) jumps to stage 5.
-- Golden eggs are gold throughout. With auto-open on, a finished reveal opens the next batch by
-- itself (opts.again) until the player stops it, a request fails, or SSR+ pauses the run.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local HatchRules = require(Shared.Domain.Hatch)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Visuals = require(App.Visuals)
local Kit = require(App.Kit)
local CardActions = require(App.CardActions)
local EggTiers = require(Shared.Config.EggTiers)
local Cutout = require(Shared.Art.Cutout)

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
	Common = "COMMON",
	Rare = "RARE!",
	Epic = "EPIC!",
	Legendary = "LEGENDARY!",
	Mythical = "GOD-TIER!!",
}
local TIER_KEY: { [string]: string } = {
	Common = "common",
	Rare = "rare",
	Epic = "epic",
	Legendary = "legendary",
	Mythical = "godtier",
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

-- Confetti that falls across the screen (SSR and up): pieces of the kit's confetti strip.
local function confetti(parent: GuiObject, color: Color3)
	local palette = { color, C.GoldHi, C.Pink, C.Blue, C.Green, C.White }
	for k = 1, 36 do
		local piece = Kit.image("confetti_set", {
			ImageRectSize = Vector2.new(64, 64),
			ImageRectOffset = Vector2.new((k % 4) * 64, 0),
			ImageColor3 = palette[(k % #palette) + 1],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, -0.05, -math.random(0, 60)),
			Size = UDim2.fromOffset(14, 14),
			Rotation = math.random(0, 360),
			ZIndex = 25,
			Parent = parent,
		})
		tween(piece, 1.6 + math.random() * 0.8, {
			Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.05),
			Rotation = piece.Rotation + math.random(-360, 360),
		}, Enum.EasingStyle.Sine)
		task.delay(2.5, piece.Destroy, piece)
	end
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
		local againButton = Ui.button("Open Again", "secondary", function() end, {
			Name = "OpenAgain",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(0.5, -132, 1, -34),
			Size = UDim2.fromOffset(170, 48),
			Visible = false,
			ZIndex = 12,
		})
		againButton.instance.Parent = stage
		local equipButton = Ui.button("Equip", "secondary", function() end, {
			Name = "Equip",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 132, 1, -34),
			Size = UDim2.fromOffset(150, 48),
			Visible = false,
			ZIndex = 12,
		})
		equipButton.instance.Parent = stage
		-- Tap anywhere to skip to the cards.
		local tapSkip = Ui.new("TextButton", {
			Name = "TapSkip",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
			Parent = stage,
		})
		tapSkip.Activated:Connect(function()
			skipped = true
		end)

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

		local function finished(my: number, best: string, cards: { any }, isNew: { boolean })
			skipButton.instance.Visible = false
			tapSkip.Visible = false
			local auto = Hatch.auto and options.again ~= nil and RANK[best] < RANK.Legendary
			local function showButtons()
				doneButton.instance.Visible = true
				Ui.popIn(doneButton.instance, reduced)
				againButton.instance.Visible = options.again ~= nil
				local single = #cards == 1 and isNew[1] == true
				equipButton.instance.Visible = single
				againButton.setOnClick(function()
					local again = options.again
					local nextCards = if again then again() else nil
					if nextCards and alive(my) then
						play(nextCards)
					end
				end)
				equipButton.setOnClick(function()
					local v = ctx.state.view
					local copy = v and cards[1].uid and v.cards[cards[1].uid]
					if copy and CardActions.equip(ctx, copy) then
						equipButton.instance.Visible = false
					end
				end)
			end
			if not auto then
				showButtons()
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
				showButtons()
			end
		end

		play = function(cards: { any })
			token += 1
			local my = token
			skipped = reduced
			Ui.clear(board)
			doneButton.instance.Visible = false
			stopButton.instance.Visible = false
			againButton.instance.Visible = false
			equipButton.instance.Visible = false
			skipButton.instance.Visible = not reduced
			tapSkip.Visible = not reduced

			local best = bestOf(cards)
			local bdef = Rarities.Defs[best]
			local bestColor = if golden then C.Gold else bdef.colors[4]
			local tierColor = if golden then C.Gold else Rarities.Defs[EggTiers.of(egg)].colors[4]
			local neutral = Color3.fromHex("#B9A8FF")
			local legendary = RANK[best] >= RANK.Legendary
			local mythical = best == "Mythical"
			local multi = #cards > 1
			rays.ImageColor3 = neutral
			rays.ImageTransparency = 0.6
			glow.ImageColor3 = neutral
			glow.Visible = true
			pedestal.Visible = false
			title.Text = if golden then "GOLDEN SUMMON" else if multi then `SUMMON x{#cards}` else "SUMMON"
			title.TextColor3 = C.White

			-- "New!" for the first copy of a character, counting earlier cards in the same batch.
			local isNew: { boolean } = {}
			for i, card in cards do
				isNew[i] = not known[card.characterId]
				known[card.characterId] = true
			end

			-- Stage 1, summon: a glowing circle with turning runes; the egg rises out of it.
			local circle = Kit.image("summon_circle", {
				Name = "SummonCircle",
				ImageColor3 = tierColor,
				ImageTransparency = 0.1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.66),
				Size = UDim2.fromOffset(380, 150),
				ScaleType = Enum.ScaleType.Stretch,
				Parent = board,
			})
			local runes = Kit.image("summon_runes", {
				Name = "SummonRunes",
				ImageColor3 = tierColor:Lerp(C.White, 0.3),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.66),
				Size = UDim2.fromOffset(330, 130),
				ScaleType = Enum.ScaleType.Stretch,
				Parent = board,
			})
			local eggHolder = Ui.frame({
				Name = "Egg",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.66),
				Size = UDim2.fromOffset(128, 128),
				ZIndex = 3,
				Parent = board,
			})
			local eggImage = Visuals.egg(eggHolder, egg, golden, 128) :: ImageLabel
			eggImage.ZIndex = 3
			local cracks: { ImageLabel } = {}
			for k = 1, 3 do
				table.insert(
					cracks,
					Kit.image(`crack_overlay_{k}`, {
						Name = `Crack{k}`,
						ImageColor3 = neutral,
						ImageTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.95, 0.95),
						ZIndex = 4,
						Parent = eggHolder,
					})
				)
			end

			local size, columns = layout(#cards)
			local small = #cards > 3
			local slotSize = Vector2.new(size.X + 10, size.Y + (if small then 8 else 22))
			local rows = math.ceil(#cards / columns)
			local cols = math.min(columns, #cards)
			local gridSize =
				Vector2.new(cols * slotSize.X + (cols - 1) * 16, rows * slotSize.Y + (rows - 1) * 10)
			local grid = Ui.frame({
				Name = "Reveal",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, if small then 0.5 else 0.47),
				Size = UDim2.fromOffset(gridSize.X, gridSize.Y),
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

			-- Stage 4 and 5 share the slots: a silhouette first, then the card flips in.
			local slots: { Frame } = {}
			local silhouettes: { Frame } = {}
			for i, card in cards do
				local def = Characters.ById[card.characterId]
				local slot =
					Ui.frame({ Name = `Card{i}`, BackgroundTransparency = 1, LayoutOrder = i, Parent = grid })
				slots[i] = slot
				local sil = Ui.frame({
					Name = "Silhouette",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(size.X, size.Y),
					Visible = false,
					Parent = slot,
				})
				local aura = Kit.image(`aura_{Rarities.Defs[def.rarity].tag}`, {
					Name = "Aura",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.6),
					Size = UDim2.fromOffset(size.Y * 1.3, size.Y * 1.3),
					ImageTransparency = 0.2,
					ScaleType = Enum.ScaleType.Stretch,
					Parent = sil,
				})
				aura:SetAttribute("Rise", true)
				for k, cut in Cutout.layers(card.characterId) do
					Ui.new("ImageLabel", {
						Name = cut.name,
						Image = cut.image,
						ImageColor3 = Color3.new(0, 0, 0), -- a black silhouette with the aura as its rim light
						ImageTransparency = math.min(cut.transparency, 0.05),
						BackgroundTransparency = 1,
						ScaleType = Enum.ScaleType.Fit,
						Position = UDim2.fromScale(cut.offset.X, cut.offset.Y),
						Size = UDim2.fromScale(1, 0.92),
						ZIndex = 2 + k,
						Parent = sil,
					})
				end
				Kit.image(`badge_{Rarities.Defs[def.rarity].tag}_large`, {
					Name = "Badge",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.02),
					Size = UDim2.fromOffset(size.X * 0.8, size.X * 0.4),
					Visible = false,
					ZIndex = 9,
					Parent = sil,
				})
				silhouettes[i] = sil
			end

			local flipped = 0
			local function counted()
				flipped += 1
				if flipped == #cards and alive(my) then
					task.spawn(finished, my, best, cards, isNew)
				end
			end
			-- Stage 5: each silhouette turns into its card, which flips in.
			local function flipIn(card: any, i: number)
				local def = Characters.ById[card.characterId]
				local slot = slots[i]
				local sil = silhouettes[i]
				local face = Visuals.portrait(slot, card.characterId, card.golden, size, true, card.level)
				face.AnchorPoint = Vector2.new(0.5, 0)
				face.Position = UDim2.fromScale(0.5, 0)
				face.Visible = false
				local faceCard = face:FindFirstChild("Face") :: Frame?
				local label = Ui.text({
					Text = if small
						then def.displayName
						else `{def.displayName} · {Rarities.Defs[def.rarity].displayName}{if card.golden
							then " · Golden"
							else ""}`,
					FontFace = Theme.Face.Bold,
					TextSize = Theme.Size.small + 1,
					TextColor3 = if card.golden then C.Gold else Rarities.Defs[def.rarity].color,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.new(0, 0, 1, -18),
					Size = UDim2.new(1, 0, 0, 18),
					Visible = false,
					Parent = slot,
				})
				Ui.outline(C.Night, 1).Parent = label
				Ui.fit(label, Theme.Size.small + 1, 8)
				-- "NEW!" for a first copy, "+1" otherwise.
				local stickerW = if small then 56 else 84
				local sticker = Kit.image(if isNew[i] then "sticker_new" else "sticker_dup", {
					Name = if isNew[i] then "New" else "Dup",
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 14, 0, 6),
					Size = UDim2.fromOffset(stickerW, stickerW / 2),
					Visible = false,
					ZIndex = 30,
					Parent = slot,
				})
				local function land()
					sil.Visible = false
					face.Visible = true
					if faceCard then
						faceCard.Size = UDim2.fromOffset(size.X, size.Y)
					end
					label.Visible = not small
					sticker.Visible = true
				end
				if skipped then
					land()
					counted()
					return
				end
				pause(0.12 + (i - 1) * (if small then 0.14 else 0.22))
				if not alive(my) then
					return
				end
				if skipped then
					land()
					counted()
					return
				end
				Ui.sound("card_flip")
				local half = tween(
					sil,
					0.14,
					{ Size = UDim2.fromOffset(2, size.Y), Position = UDim2.fromOffset(size.X / 2, 0) }
				)
				half.Completed:Wait()
				if not alive(my) then
					return
				end
				sil.Visible = false
				face.Visible = true
				label.Visible = not small
				if faceCard and not skipped then
					faceCard.Size = UDim2.fromOffset(2, size.Y)
					tween(faceCard, 0.24, { Size = UDim2.fromOffset(size.X, size.Y) }, Enum.EasingStyle.Back)
				else
					land()
				end
				sticker.Visible = true
				Ui.popIn(sticker)
				if RANK[def.rarity] >= RANK.Epic or card.golden then
					sparkles(
						slot,
						if card.golden then C.Gold else Rarities.Defs[def.rarity].colors[4],
						if small then 6 else 10,
						if small then 70 else 130
					)
					Ui.sound("sparkle")
				end
				counted()
			end

			-- Stage 4: the silhouettes stand in a rising aura with light rays; the badge slams in.
			local function revealSilhouettes()
				circle.Visible = false
				runes.Visible = false
				eggHolder.Visible = false
				grid.Visible = true
				rays.ImageColor3 = bestColor
				glow.ImageColor3 = bestColor
				title.Text = CALLOUT[best]
				title.TextColor3 = bestColor
				Ui.sound(`reveal_{string.lower(best)}`)
				if mythical and not skipped then
					local pillar = Kit.image("light_pillar", {
						Name = "Pillar",
						ImageColor3 = bestColor,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.45),
						Size = UDim2.fromOffset(gridSize.X * 0.9, 0),
						ScaleType = Enum.ScaleType.Stretch,
						ZIndex = 2,
						Parent = board,
					})
					tween(
						pillar,
						0.5,
						{ Size = UDim2.fromOffset(math.max(160, gridSize.X * 0.9), 900) },
						Enum.EasingStyle.Quart
					)
				end
				for _, sil in silhouettes do
					sil.Visible = true
					local aura = sil:FindFirstChild("Aura") :: ImageLabel
					local badge = sil:FindFirstChild("Badge") :: ImageLabel
					if not skipped then
						aura.Position = UDim2.fromScale(0.5, 0.9)
						aura.ImageTransparency = 0.9
						tween(
							aura,
							0.6,
							{ Position = UDim2.fromScale(0.5, 0.55), ImageTransparency = 0.15 },
							Enum.EasingStyle.Quart
						)
						task.delay(0.35, function()
							if badge.Parent then
								badge.Visible = true
								local s = Ui.new("UIScale", { Scale = 2.4, Parent = badge })
								tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
							end
						end)
					else
						badge.Visible = true
					end
				end
				pause(if mythical then 1.4 else 0.8)
				if not alive(my) then
					return
				end
				-- Confetti for Legendary and up.
				if legendary and not reduced then
					confetti(stage, bestColor)
				end
				title.Text = if golden
					then "GOLDEN!"
					else if table.find(isNew, true)
						then (if multi then "NEW CARDS!" else "NEW CARD!")
						else "YOU GOT"
				title.TextColor3 = if golden then C.GoldHi else C.White
				for i, card in cards do
					task.spawn(flipIn, card, i)
				end
			end

			if skipped then
				revealSilhouettes()
				return
			end
			task.spawn(function()
				-- Stage 1, summon (0.9 s): the circle pulses, the runes turn, the egg rises; push in.
				Ui.sound("hatch_summon")
				local push = Ui.new("UIScale", { Scale = 0.92, Parent = board })
				tween(push, 0.9, { Scale = 1 }, Enum.EasingStyle.Sine)
				eggImage.ImageTransparency = 1
				eggHolder.Position = UDim2.new(0.5, 0, 0.66, 60)
				tween(eggHolder, 0.8, { Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Back)
				tween(eggImage, 0.5, { ImageTransparency = 0 })
				tween(runes, 0.9, { Rotation = 120 }, Enum.EasingStyle.Linear)
				circle.Size = UDim2.fromOffset(300, 118)
				tween(circle, 0.45, { Size = UDim2.fromOffset(400, 158) }, Enum.EasingStyle.Back)
				pause(0.9)
				if not alive(my) then
					return
				end
				-- Stage 2, crack (1.0 s, +0.4 s slow-mo for Legendary and up): rising shakes, the
				-- cracks spread, and the glow shifts from neutral toward the real rarity colour.
				title.Text = "..."
				tween(glow, 1.0, { ImageColor3 = bestColor, ImageTransparency = 0.2 })
				tween(rays, 1.0, { ImageColor3 = bestColor, ImageTransparency = 0.4 })
				for i = 1, 3 do
					if skipped or not alive(my) then
						break
					end
					Ui.sound("hatch_shake")
					local amp = 4 + i * 4
					for _ = 1, 1 + i do
						tween(eggHolder, 0.04, { Rotation = amp }).Completed:Wait()
						tween(eggHolder, 0.04, { Rotation = -amp }).Completed:Wait()
					end
					tween(eggHolder, 0.05, { Rotation = 0 })
					cracks[i].ImageTransparency = 0
					tween(cracks[i], 0.25, { ImageColor3 = bestColor:Lerp(C.White, 0.3) })
					pause(0.12)
				end
				if legendary and not skipped and alive(my) then
					tween(bg, 0.3, { BackgroundTransparency = 0.04 })
					tween(eggHolder, 0.4, { Size = UDim2.fromOffset(150, 150) }, Enum.EasingStyle.Sine)
					pause(0.4)
					tween(bg, 0.3, { BackgroundTransparency = 0.12 })
				end
				if not alive(my) then
					return
				end
				-- Stage 3, break (0.5 s): shards burst out, a flash, a shockwave ring, a short shake.
				if not skipped then
					Ui.sound("hatch_burst")
					eggHolder.Visible = false
					local shardTier = if golden then "legendary" else TIER_KEY[best]
					for k = 1, 14 do
						local a = (k / 14) * math.pi * 2 + math.random() * 0.3
						local d = 160 + math.random() * 140
						local shard = Kit.image(`shard_set_{shardTier}`, {
							ImageRectSize = Vector2.new(64, 64),
							ImageRectOffset = Vector2.new(((k - 1) % 6) * 64, 0),
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.56),
							Size = UDim2.fromOffset(34, 34),
							Rotation = math.random(0, 360),
							ZIndex = 8,
							Parent = board,
						})
						tween(shard, 0.6, {
							Position = UDim2.new(0.5, math.cos(a) * d, 0.56, math.sin(a) * d * 0.7),
							Rotation = shard.Rotation + math.random(-220, 220),
							ImageTransparency = 1,
						}, Enum.EasingStyle.Quart)
						task.delay(0.65, shard.Destroy, shard)
					end
					local ring = Kit.image("shockwave_ring", {
						ImageColor3 = bestColor,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.56),
						Size = UDim2.fromOffset(60, 60),
						ZIndex = 7,
						Parent = board,
					})
					tween(
						ring,
						0.5,
						{ Size = UDim2.fromOffset(700, 700), ImageTransparency = 1 },
						Enum.EasingStyle.Quart
					)
					flash.BackgroundColor3 = if legendary or golden then C.GoldHi else C.White
					flash.BackgroundTransparency = 0.1
					tween(flash, 0.45, { BackgroundTransparency = 1 })
					task.spawn(shake, stage, if mythical then 0.5 else 0.3)
					if mythical then
						shockwave(layer, golden, 0.05)
						shockwave(layer, golden, 0.2)
					end
					pause(0.5)
				end
				if not alive(my) then
					return
				end
				revealSilhouettes()
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
