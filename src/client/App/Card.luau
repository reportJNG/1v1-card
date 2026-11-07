--!strict
-- The layered trading card (docs/ART_STYLE.md section 4, owner brief "card visual upgrade"). One
-- 5:7 silhouette for every rarity, built from layers, back to front:
--   shadow, glow      a soft drop shadow, and an outer glow in the rarity colour
--   background        the family background (card_bg_<family>)
--   rim               the family accent glowing behind the character
--   character         the character's transparent cutout (assets.cardArt) or, until it exists, a
--                     clearly marked TEMP cutout: the role silhouette in 4 layers tinted with the
--                     character's look colours, with a rim light in the family accent
--   fx                shine sweep, sparkles, rising particles, holo foil (by rarity)
--   frame             card_border, tinted and animated per rarity:
--                       Common     clean silver, soft shadow
--                       Rare       bright blue, periodic shine sweep
--                       Epic       purple, animated gradient border and glow
--                       Legendary  gold, sparkles, pulsing glow
--                       Mythical   prismatic animated frame, holo foil, floating particles
--   golden            the gold foil over any rarity and a GOLDEN tag
--   plates            rarity banner (word, in its colour), level badge (crown at level 15 with a
--                     stronger glow), family icon, name, and the stats at the card's level
-- Background, character and fx shift with the pointer, press or device tilt (2.5D parallax) on
-- interactive cards. Animation runs in App/CardFx, only while the card is on screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)
local Economy = require(Shared.Config.Economy)
local BattleRules = require(Shared.Battle.BattleRules)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local CardFx = require(script.Parent.CardFx)

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

-- Where the frame's plates sit (fractions of the card, matching card_border).
local P = {
	inset = 0.047, -- art window inset (x)
	banner = { x0 = 0.19, x1 = 0.81, y0 = 0.012, y1 = 0.088 },
	level = Vector2.new(0.113, 0.115),
	family = Vector2.new(0.887, 0.115),
	socket = 0.13, -- socket diameter / card width
	name = { y0 = 0.778, y1 = 0.868 },
	stats = { y0 = 0.878, y1 = 0.958 },
}

local function img(slot: string, props: { [string]: any }): ImageLabel
	return Ui.image(slot, props)
end

-- The stats the card would fight with at `level` (the same numbers as a battle, BattleRules).
function Card.stats(characterId: string, level: number): { hp: number, atk: number, def: number, spd: number }
	local u = BattleRules.preview({ { characterId = characterId, level = level } })[1]
	return {
		hp = u.maxHp,
		atk = math.floor(u.atk + 0.5),
		def = math.floor(u.def + 0.5),
		spd = math.floor(u.spd + 0.5),
	}
end

-- The TEMP cutout: the role's 4 layers, tinted with the character's look colours (outfit = its
-- first colour, accent = its second), plus a rim light in the family accent behind it.
local function tempCutout(parent: Instance, def: any, accent: Color3): Frame
	local role = string.lower(def.role)
	local colors = def.look and def.look.colors or {}
	local outfit = if colors[1]
		then Color3.fromHex(colors[1])
		else Color3.fromHex(Art.FamilyColors[def.family].body)
	local trim = if colors[2] then Color3.fromHex(colors[2]) else accent
	local holder = Ui.frame({ Name = "Cutout", BackgroundTransparency = 1, Parent = parent })
	img(`cutout_{role}_line`, {
		Name = "Rim",
		ImageColor3 = accent,
		ImageTransparency = 0.15,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromScale(0.018, -0.012),
		Size = UDim2.fromScale(1, 1),
		Parent = holder,
	})
	for _, layer in { "line", "outfit", "skin", "accent" } do
		img(`cutout_{role}_{layer}`, {
			Name = layer,
			ImageColor3 = if layer == "outfit" then outfit elseif layer == "accent" then trim else C.White,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
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

	-- Art window: background, rim glow, character, fx.
	local inset = math.max(2, math.floor(w * P.inset))
	local art = Ui.frame({
		Name = "Art",
		BackgroundColor3 = Color3.fromHex(fam.body),
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = face,
	}, { Ui.corner(math.floor(w * 0.06)) })
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
		Position = UDim2.fromScale(0.5, 0.84),
		Size = UDim2.fromScale(1.02, 0.78),
		Parent = art,
	})
	local placeholder = def.assets.cardArt == nil
	if placeholder then
		tempCutout(character, def, accent)
	else
		Ui.new("ImageLabel", {
			Name = "CardArt",
			Image = def.assets.cardArt,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			Parent = character,
		})
	end
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

	-- The frame, tinted per rarity.
	local frame = img("card_border", {
		Name = "Frame",
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = face,
	})
	local frameGrad = Ui.new("UIGradient", { Color = seq(style.frame), Rotation = 90, Parent = frame })
	local foilGrad: UIGradient? = nil
	if golden then
		local foil = img("card_golden_foil", {
			Name = "Foil",
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
			Parent = face,
		})
		foilGrad = Ui.new("UIGradient", {
			Color = seq({ "#FFE08A", "#FFFFFF", "#FFC54B", "#FFE08A" }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0.1),
			}),
			Parent = foil,
		})
	end

	-- Plates: rarity banner, level badge, family icon, name, stats.
	local textBase = math.max(8, math.floor(h * 0.062))
	local banner = Ui.display({
		Name = "Rarity",
		Text = if golden then `GOLDEN {string.upper(def.rarity)}` else string.upper(def.rarity),
		TextSize = textBase,
		TextColor3 = if golden then C.GoldHi else rarityColor:Lerp(C.White, 0.25),
		Position = UDim2.fromScale(P.banner.x0, P.banner.y0),
		Size = UDim2.fromScale(P.banner.x1 - P.banner.x0, P.banner.y1 - P.banner.y0),
		ZIndex = 9,
		Parent = face,
	})
	Ui.fit(banner, textBase, 6)
	local socket = math.floor(w * P.socket)
	local badge = img("badge_level", {
		Name = "Level",
		ImageColor3 = if maxed then C.Gold else rarityColor,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(P.level.X, P.level.Y),
		Size = UDim2.fromOffset(socket, socket),
		ZIndex = 9,
		Parent = face,
	})
	local lvl = Ui.text({
		Name = "Value",
		Text = tostring(level),
		FontFace = Theme.Face.Number,
		TextSize = math.max(8, math.floor(socket * 0.5)),
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = badge,
	})
	Ui.outline(C.Night, 1.5).Parent = lvl
	if maxed then
		img("badge_crown", {
			Name = "Crown",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.18),
			Size = UDim2.fromOffset(math.floor(socket * 0.95), math.floor(socket * 0.7)),
			ZIndex = 11,
			Parent = badge,
		})
	end
	img(`family_{string.lower(def.family)}`, {
		Name = "Family",
		ImageColor3 = accent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(P.family.X, P.family.Y),
		Size = UDim2.fromOffset(math.floor(socket * 0.72), math.floor(socket * 0.72)),
		ZIndex = 9,
		Parent = face,
	})
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
		local st = Card.stats(def.id, level)
		local row = Ui.frame({
			Name = "Stats",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.07, P.stats.y0),
			Size = UDim2.fromScale(0.86, P.stats.y1 - P.stats.y0),
			ZIndex = 9,
			Parent = face,
		}, { Ui.list(true, math.floor(w * 0.04), Enum.HorizontalAlignment.Center) })
		local iconSize = math.floor(h * 0.06)
		local cells: { { icon: string, value: number, color: Color3 } } = {
			{ icon = "icon_power", value = st.atk, color = C.Gold },
			{ icon = "icon_hp", value = st.hp, color = C.Green },
		}
		for i, pair in cells do
			local cell = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.47, 1),
				LayoutOrder = i,
				Parent = row,
			})
			Ui.icon(pair.icon, iconSize, { Position = UDim2.fromScale(0, 0.5), ZIndex = 10, Parent = cell })
			local v = Ui.text({
				Text = tostring(pair.value),
				FontFace = Theme.Face.Number,
				TextSize = math.max(8, math.floor(h * 0.068)),
				TextColor3 = pair.color,
				TextWrapped = false,
				Position = UDim2.fromOffset(iconSize + 2, 0),
				Size = UDim2.new(1, -iconSize - 2, 1, 0),
				ZIndex = 10,
				Parent = cell,
			})
			Ui.outline(C.Night, 1.5).Parent = v
			Ui.fit(v, math.max(8, math.floor(h * 0.068)), 6)
		end
	end

	-- Animation and parallax (App/CardFx; nothing runs while the card is off screen).
	local depth = math.max(2, math.floor(w * 0.06))
	CardFx.add({
		root = holder,
		frameGrad = frameGrad,
		glowGrad = if style.spin ~= 0 then glowGrad else nil,
		frameSpin = style.spin,
		glow = if glow.Visible then glow else nil,
		glowBase = glowT,
		glowPulse = style.pulse + (if maxed then 0.15 else 0),
		shine = shine,
		shineEvery = style.shine or 3,
		holoGrad = holoGrad,
		foilGrad = foilGrad,
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
