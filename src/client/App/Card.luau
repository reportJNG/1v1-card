--!strict
-- The layered trading card (docs/ART_STYLE.md section 4, owner brief "card visual upgrade"). One
-- 5:7 silhouette for every rarity, built from layers, back to front:
--   shadow, glow      a soft drop shadow, and an outer glow in the rarity colour
--   frame             a rounded border drawn in code, in the rarity's colours and animated:
--                       Common     clean silver, soft shadow
--                       Rare       bright blue, periodic shine sweep
--                       Epic       purple, turning gradient border and glow
--                       Legendary  gold, sparkles, pulsing glow
--                       Mythical   prismatic turning border, holo foil, floating particles
--                     A Golden copy's border is gold with a white glint sweeping across it.
--   background        the family background (card_bg_<family>), full bleed
--   rim               the family accent glowing behind the character
--   character         the character's transparent cutout (assets.cardArt) or, until it exists, a
--                     clearly marked TEMP cutout: the role silhouette in 4 layers tinted with the
--                     character's look colours, with a rim light in the family accent
--   fx                shine sweep, sparkles, rising particles, holo foil (by rarity)
--   plates            top: level socket (crown at level 15), rarity pill (the word, in its colour;
--                     "GOLDEN ..." in gold), family socket. Bottom: the art fades to night under
--                     the name and the card's power (the same Power number as the deck builder)
-- Background, character and fx shift with the pointer, press or device tilt (2.5D parallax) on
-- interactive cards. Animation runs in App/CardFx, only while the card is on screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)
local Economy = require(Shared.Config.Economy)
local Power = require(Shared.Domain.Power)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local CardFx = require(script.Parent.CardFx)
local Cutout = require(Shared.Art.Cutout)

local C = Theme.Color

local Card = {}

export type Options = {
	characterId: string,
	golden: boolean?,
	level: number?,
	size: Vector2, -- the card keeps 5:7 inside this box
	interactive: boolean?, -- parallax on hover / press / tilt (big single cards)
	stats: boolean?, -- show the stat strip (default: when the card is tall enough)
}

local function seq(hexes: { string }): ColorSequence
	if #hexes == 1 then
		return ColorSequence.new(Color3.fromHex(hexes[1]))
	end
	local keys = {}
	for i, hex in hexes do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #hexes - 1), Color3.fromHex(hex)))
	end
	return ColorSequence.new(keys)
end

-- Per rarity: frame tint, how fast it turns, glow colour(s), resting glow transparency and pulse.
local STYLE: {
	[string]: {
		frame: { string },
		spin: number,
		glow: { string },
		glowT: number,
		pulse: number,
		shine: number?,
	},
} =
	{
		Common = {
			frame = { "#FFFFFF", "#D6DEEA", "#9AA6BA" },
			spin = 0,
			glow = { "#B9C7DC" },
			glowT = 1,
			pulse = 0,
		},
		Rare = {
			frame = { "#C8F0FF", "#45BEFF", "#1E6FB8" },
			spin = 0,
			glow = { "#45BEFF" },
			glowT = 0.55,
			pulse = 0,
			shine = 3.6,
		},
		Epic = {
			frame = { "#F0E2FF", "#A469FF", "#6A35C9", "#C9A2FF", "#F0E2FF" },
			spin = 70,
			glow = { "#C9A2FF", "#7B3CFF", "#C9A2FF" },
			glowT = 0.4,
			pulse = 0,
			shine = 3.2,
		},
		Legendary = {
			frame = { "#FFF6D0", "#FFC54B", "#B8791A", "#FFE27A" },
			spin = 0,
			glow = { "#FFC54B" },
			glowT = 0.3,
			pulse = 0.35,
			shine = 2.8,
		},
		Mythical = {
			frame = { "#FF668F", "#FFB347", "#FFE14D", "#48DA97", "#45BEFF", "#A469FF", "#FF668F" },
			spin = 90,
			glow = { "#FF668F", "#A469FF", "#45BEFF", "#48DA97", "#FF668F" },
			glowT = 0.2,
			pulse = 0.25,
			shine = 2.4,
		},
	}

-- A Golden copy's border: gold with a white highlight that sweeps across it (CardFx foil).
local GOLDEN_FRAME = { "#E08A00", "#FFC54B", "#FFFFFF", "#FFC54B", "#E08A00" }

-- The card face (owner step 3, the concept board's cards): a bright rarity border drawn in code,
-- full-bleed art, a rarity pill and level / family sockets on top, and a dark plate at the bottom
-- with the name and the card's power. Fractions of the card.
local P = {
	border = 0.045, -- border thickness / card width
	corner = 0.08, -- corner radius / card width
	socket = 0.16, -- level and family socket diameter / card width
	top = 0.035, -- socket and pill margin from the top / card height
	plate = 0.66, -- where the bottom plate's fade starts / card height
	name = { y0 = 0.735, y1 = 0.815 },
	power = { y0 = 0.82, y1 = 0.94 },
}

local function img(slot: string, props: { [string]: any }): ImageLabel
	return Ui.image(slot, props)
end

-- The character's cut-out (Shared/Art/Cutout: its card art, or the TEMP role silhouette tinted
-- with its colours), with the rim light behind it.
local function cutout(parent: Instance, characterId: string): Frame
	local holder = Ui.frame({ Name = "Cutout", BackgroundTransparency = 1, Parent = parent })
	for i, layer in Cutout.layers(characterId) do
		Ui.new("ImageLabel", {
			Name = layer.name,
			Image = layer.image,
			ImageColor3 = layer.color,
			ImageTransparency = layer.transparency,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromScale(layer.offset.X, layer.offset.Y),
			Size = UDim2.fromScale(1, 1),
			ZIndex = i,
			Parent = holder,
		})
	end
	return holder
end

function Card.build(parent: Instance, o: Options): Frame
	local def = Characters.ById[o.characterId]
	assert(def, `unknown character {o.characterId}`)
	local level = o.level or 1
	local golden = o.golden == true
	local maxed = level >= Economy.Progression.maxLevel
	local style = STYLE[def.rarity] or STYLE.Common
	local fam = Art.FamilyColors[def.family]
	local accent = Color3.fromHex(fam.accent)
	local rarityColor = Theme.Rarity[def.rarity] or C.Muted

	local holder = Ui.frame({
		Name = "Card",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(o.size.X, o.size.Y),
		Parent = parent,
	})
	local w = math.min(o.size.X, math.floor(o.size.Y * 5 / 7))
	local h = math.floor(w * 7 / 5)
	local small = h < 120
	local face = Ui.frame({
		Name = "Face",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		Parent = holder,
	})

	-- Shadow and glow (behind everything).
	img("card_glow", {
		Name = "Shadow",
		ImageColor3 = C.Night,
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, math.max(3, math.floor(h * 0.035))),
		Size = UDim2.fromScale(1.18, 1.14),
		ZIndex = 0,
		Parent = face,
	})
	local glowT = math.max(0, style.glowT - (if maxed then 0.25 else 0))
	local glow = img("card_glow", {
		Name = "Glow",
		ImageTransparency = glowT,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(if maxed then 1.34 else 1.26, if maxed then 1.26 else 1.2),
		Visible = glowT < 1,
		ZIndex = 0,
		Parent = face,
	})
	local glowGrad = Ui.new("UIGradient", { Color = seq(style.glow), Parent = glow })

	-- The border: a rounded plate in the rarity colours (gold for Golden) behind the art window.
	local radius = math.max(4, math.floor(w * P.corner))
	local inset = math.max(2, math.floor(w * P.border))
	local frame = Ui.frame({
		Name = "Frame",
		BackgroundColor3 = C.White,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = face,
	}, { Ui.corner(radius), Ui.stroke(C.Night, math.max(1, math.floor(w * 0.012)), 0.2) })
	local frameGrad = Ui.new(
		"UIGradient",
		{ Color = seq(if golden then GOLDEN_FRAME else style.frame), Rotation = 90, Parent = frame }
	)

	-- Art window: background, rim glow, character, fx.
	local art = Ui.frame({
		Name = "Art",
		BackgroundColor3 = Color3.fromHex(fam.body),
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = face,
	}, { Ui.corner(math.max(2, radius - inset)), Ui.stroke(C.Night, 1, 0.3) })
	local bg = img(`card_bg_{string.lower(def.family)}`, {
		Name = "Background",
		ScaleType = Enum.ScaleType.Crop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.1, 1.1),
		Parent = art,
	})
	img("egg_glow", {
		Name = "RimGlow",
		ImageColor3 = accent,
		ImageTransparency = 0.35,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(1.2, 0.9),
		Parent = art,
	})
	local character = Ui.frame({
		Name = "Character",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.86),
		Size = UDim2.fromScale(1.06, 0.8),
		Parent = art,
	})
	local placeholder = Cutout.isTemp(def.id)
	cutout(character, def.id)
	local fx = Ui.frame({ Name = "Fx", BackgroundTransparency = 1, ZIndex = 3, Parent = art })

	local shine: GuiObject? = nil
	if (style.shine or golden) and not small then
		shine = img("card_shine", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.4, 0.5),
			Size = UDim2.fromScale(0.5, 1.3),
			Rotation = 12,
			ScaleType = Enum.ScaleType.Stretch,
			ImageTransparency = 0.3,
			ZIndex = 4,
			Parent = fx,
		})
	end
	local holoGrad: UIGradient? = nil
	if def.rarity == "Mythical" then
		local holo = img("card_holo", {
			Name = "Holo",
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
			ImageTransparency = 0.35,
			ZIndex = 4,
			Parent = fx,
		})
		holoGrad = Ui.new("UIGradient", {
			Color = seq({ "#FF7BD5", "#FFE14D", "#48DA97", "#45BEFF", "#A469FF", "#FF7BD5" }),
			Rotation = 35,
			Parent = holo,
		})
	end
	local sparks: { ImageLabel } = {}
	local sparkMode: "twinkle" | "rise" | "none" = "none"
	if def.rarity == "Legendary" or def.rarity == "Mythical" or maxed then
		sparkMode = if def.rarity == "Mythical" then "rise" else "twinkle"
		local n = if small then 3 else (if sparkMode == "rise" then 8 else 6)
		for k = 1, n do
			local s = math.max(8, math.floor(w * (if sparkMode == "rise" then 0.08 else 0.13)))
			table.insert(
				sparks,
				img("sparkle", {
					Name = "Spark",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(
						0.15 + ((k * 0.618) % 1) * 0.7,
						0.12 + ((k * 0.382) % 1) * 0.6
					),
					Size = UDim2.fromOffset(s, s),
					ImageColor3 = if sparkMode == "rise"
						then Color3.fromHex(style.glow[(k % #style.glow) + 1])
						else C.GoldHi,
					ImageTransparency = 0.2,
					ZIndex = 5,
					Parent = fx,
				})
			)
		end
	end
	if placeholder and h >= 150 then
		Ui.text({
			Name = "TempTag",
			Text = "TEMP ART",
			FontFace = Theme.Face.Bold,
			TextSize = 9,
			TextColor3 = C.Muted,
			TextTransparency = 0.25,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0.66, 0),
			Size = UDim2.fromOffset(60, 12),
			ZIndex = 6,
			Parent = art,
		})
	end

	-- The bottom plate: the art fades to night so the name and power read on any background.
	Ui.frame({
		Name = "Plate",
		BackgroundColor3 = C.Night,
		Position = UDim2.fromScale(0, P.plate),
		Size = UDim2.fromScale(1, 1 - P.plate),
		ZIndex = 6,
		Parent = art,
	}, {
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.35, 0.25),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
		}),
	})

	-- Top row: level socket (left), rarity pill, family socket (right).
	local socket = math.max(12, math.floor(w * P.socket))
	local top = math.floor(h * P.top) + inset
	local ring = math.max(1, math.floor(socket * 0.09))
	local badge = Ui.frame({
		Name = "Level",
		BackgroundColor3 = C.White,
		Position = UDim2.fromOffset(inset + math.floor(w * 0.025), top),
		Size = UDim2.fromOffset(socket, socket),
		ZIndex = 9,
		Parent = face,
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ui.stroke(C.Night, ring),
		Ui.gradient(
			(if maxed then C.GoldHi else rarityColor:Lerp(C.White, 0.3)),
			(if maxed then C.GoldLo else rarityColor:Lerp(C.Night, 0.35))
		),
	})
	local lvl = Ui.text({
		Name = "Value",
		Text = tostring(level),
		FontFace = Theme.Face.Number,
		TextSize = math.max(8, math.floor(socket * 0.58)),
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = badge,
	})
	Ui.outline(C.Night, math.max(1, ring)).Parent = lvl
	if maxed then
		img("badge_crown", {
			Name = "Crown",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.fromOffset(math.floor(socket * 0.95), math.floor(socket * 0.7)),
			ZIndex = 11,
			Parent = badge,
		})
	end
	local famSocket = Ui.frame({
		Name = "FamilySocket",
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.25,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -inset - math.floor(w * 0.025), 0, top),
		Size = UDim2.fromOffset(socket, socket),
		ZIndex = 9,
		Parent = face,
	}, { Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), Ui.stroke(accent, ring, 0.1) })
	img(`family_{string.lower(def.family)}`, {
		Name = "Family",
		ImageColor3 = accent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.68, 0.68),
		ZIndex = 10,
		Parent = famSocket,
	})

	-- The rarity pill, in its colour (gold for Golden), always with the word (never colour alone).
	local word = if golden then `GOLDEN {string.upper(def.rarity)}` else string.upper(def.rarity)
	local room = w - 2 * (inset + math.floor(w * 0.025) + socket + math.floor(w * 0.035))
	local pillH = math.max(10, math.floor(socket * 0.72))
	local pill = Ui.frame({
		Name = "RarityPill",
		BackgroundColor3 = C.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, top + math.floor(socket / 2)),
		Size = UDim2.fromOffset(math.min(room, math.floor(w * 0.1) + #word * math.floor(pillH * 0.5)), pillH),
		ZIndex = 9,
		Parent = face,
	}, {
		Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Ui.stroke(C.Night, ring),
		Ui.gradient(
			if golden then C.GoldHi else rarityColor:Lerp(C.White, 0.35),
			if golden then C.GoldLo else rarityColor:Lerp(C.Night, 0.3)
		),
	})
	local banner = Ui.display({
		Name = "Rarity",
		Text = word,
		TextSize = math.floor(pillH * 0.7),
		TextColor3 = C.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, -pillH, 0.74, 0),
		ZIndex = 10,
		Parent = pill,
	})
	local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	if bannerStroke then
		bannerStroke.Thickness = math.max(1, ring)
	end
	-- Sized from the word's length rather than TextScaled, which would wrap "LEGENDARY" on small
	-- cards. The display face's capitals are about 0.68 em wide (with the outline).
	banner.TextSize =
		math.max(5, math.min(banner.TextSize, math.floor((pill.Size.X.Offset - pillH) / (#word * 0.68))))

	-- Name and power on the bottom plate.
	local name = Ui.text({
		Name = "Name",
		Text = def.displayName,
		FontFace = Theme.Face.Title,
		TextSize = math.max(8, math.floor(h * 0.07)),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		Position = UDim2.fromScale(0.08, P.name.y0),
		Size = UDim2.fromScale(0.84, P.name.y1 - P.name.y0),
		ZIndex = 9,
		Parent = face,
	})
	Ui.outline(C.Night, 1.5).Parent = name
	Ui.fit(name, math.max(8, math.floor(h * 0.07)), 6)
	local showStats = if o.stats ~= nil then o.stats else not small
	if showStats then
		local row = Ui.frame({
			Name = "Stats",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.08, P.power.y0),
			Size = UDim2.fromScale(0.84, P.power.y1 - P.power.y0),
			ZIndex = 9,
			Parent = face,
		}, { Ui.list(true, math.max(2, math.floor(w * 0.025)), Enum.HorizontalAlignment.Center) })
		local rowH = math.floor(h * (P.power.y1 - P.power.y0))
		Ui.icon("icon_play", math.floor(rowH * 0.95), {
			AnchorPoint = Vector2.zero,
			LayoutOrder = 1,
			ZIndex = 10,
			Parent = row,
		})
		local v = Ui.text({
			Name = "Power",
			Text = tostring(Power.card(def.id, level)),
			FontFace = Theme.Face.Number,
			TextSize = math.max(9, math.floor(rowH * 0.92)),
			TextColor3 = C.White,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, rowH),
			LayoutOrder = 2,
			ZIndex = 10,
			Parent = row,
		})
		Ui.goldText().Parent = v
		Ui.outline(C.Night, math.max(1.5, ring)).Parent = v
	end

	-- Animation and parallax (App/CardFx; nothing runs while the card is off screen).
	local depth = math.max(2, math.floor(w * 0.06))
	CardFx.add({
		root = holder,
		frameGrad = if golden then nil else frameGrad,
		glowGrad = if style.spin ~= 0 then glowGrad else nil,
		frameSpin = style.spin,
		glow = if glow.Visible then glow else nil,
		glowBase = glowT,
		glowPulse = style.pulse + (if maxed then 0.15 else 0),
		shine = shine,
		shineEvery = style.shine or 3,
		holoGrad = holoGrad,
		foilGrad = if golden then frameGrad else nil,
		sparks = sparks,
		sparkMode = sparkMode,
		layers = {
			{ obj = bg, base = bg.Position, depth = -depth * 0.6 },
			{ obj = character, base = character.Position, depth = depth },
			{ obj = fx, base = fx.Position, depth = depth * 1.4 },
		},
		tilt = Vector2.zero,
		target = Vector2.zero,
		held = false,
		interactive = o.interactive == true,
		visible = true,
		phase = (#def.id * 0.37) % 3,
	}, face)
	holder:SetAttribute("Placeholder", placeholder)
	holder:SetAttribute("Rarity", def.rarity)
	holder:SetAttribute("Level", level)
	return holder
end

return Card
