--!strict
-- The trading card (CARDS_EGGS_MISSION sections 4.1-4.6, boards docs/brief/ui-refs-2/03, 04, 06,
-- 07, 08). One 5:7 card in three kit sizes (large, medium, small: Kit.sizeFor), built from image
-- layers that share one canvas, back to front:
--   aura      a rotating flame ring in the rarity colour (R and up; any rarity from Awakened)
--   orbit     a light ribbon orbiting the card (Legendary, Mythical)
--   glow      the frame's outer glow (breathes)
--   panel     the dark violet inner panel
--   window    with character art: light rays in the rarity colour, the cut-out, a vignette;
--             without art (the clean template, board 06): the big glowing emblem (star for N and R,
--             crown for SR and up)
--   fx        shine sweep, sparkles (SR+), embers (SSR), emerald motes (UR)
--   energy    the frame's lightning strokes (flicker in bursts; crackle from Ascended)
--   frame     the ornate rarity frame; Golden copies add the gold foil overlay
--   marks     evolution: corner gems (Awakened), gold inner line (Ascended), crown + MAX ribbon (Max)
--   badge     N / R / SR / SSR / UR, top-left over the frame; the crown top-right for SR and up
--   text      name, rarity name, "Lv. N", ATK and DEF chips, the family gem
-- Rarity names, colours, badges and emblems come from Config/Rarities; evolution stages from
-- Domain/Evolution. Animation runs in App/CardFx, only while the card is on screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Cards = require(Shared.Domain.Cards)
local Evolution = require(Shared.Domain.Evolution)
local Cutout = require(Shared.Art.Cutout)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.Kit)
local Format = require(script.Parent.Format)
local CardFx = require(script.Parent.CardFx)

local C = Theme.Color

local Card = {}

export type Options = {
	characterId: string,
	golden: boolean?,
	level: number?,
	size: Vector2, -- the card keeps 5:7 inside this box
	interactive: boolean?, -- parallax on hover / press / tilt (big single cards)
	hover: boolean?, -- lift and brighten on hover (grid cards); auras wait for the hover
	stats: boolean?, -- show the ATK / DEF chips (default: medium and large cards)
	sticker: ("new" | "dup" | "max")?,
	favorite: boolean?,
}

-- Per rarity: aura and glow strength, particles, and how often the shine sweeps.
local FX: {
	[string]: {
		aura: number,
		glow: number,
		pulse: number,
		particles: string?,
		shine: number?,
		orbit: boolean,
		energy: number,
	},
} =
	{
		Common = {
			aura = 0,
			glow = 0.45,
			pulse = 0.08,
			particles = nil,
			shine = nil,
			orbit = false,
			energy = 0.55,
		},
		Rare = {
			aura = 0.55,
			glow = 0.3,
			pulse = 0.12,
			particles = nil,
			shine = 5.2,
			orbit = false,
			energy = 0.4,
		},
		Epic = {
			aura = 0.45,
			glow = 0.2,
			pulse = 0.16,
			particles = "fx_sparkle",
			shine = 4.8,
			orbit = false,
			energy = 0.3,
		},
		Legendary = {
			aura = 0.35,
			glow = 0.12,
			pulse = 0.2,
			particles = "fx_ember",
			shine = 4.4,
			orbit = true,
			energy = 0.2,
		},
		Mythical = {
			aura = 0.25,
			glow = 0.05,
			pulse = 0.22,
			particles = "fx_mote",
			shine = 4,
			orbit = true,
			energy = 0.1,
		},
	}

-- Layout as fractions of the card face (board 06 / 03): name band, rarity line, level, stats.
local L = {
	emblem = { x = 0.5, y = 0.335, s = 0.58 },
	nameY = { 0.615, 0.695 },
	rarityY = { 0.695, 0.745 },
	levelY = { 0.765, 0.84 },
	gemY = { 0.85, 0.95 },
	atkY = { 0.765, 0.845 },
	defY = { 0.85, 0.93 },
}

local function full(slot: string, z: number, parent: Instance, props: { [string]: any }?): ImageLabel
	local p: { [string]: any } = {
		Name = slot,
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = parent,
	}
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	return Kit.image(slot, p)
end

local function label(props: { [string]: any }, stroke: number?): TextLabel
	local t = Ui.text(props)
	t.TextWrapped = false
	Ui.outline(C.Night, stroke or 1.5).Parent = t
	return t
end

-- The art window's contents with the character's cut-out art (board 03).
local function artWindow(win: Frame, def: any, rdef: any, z: number): { GuiObject }
	local glow = rdef.colors[4]
	local rays = Kit.image("light_rays", {
		Name = "Rays",
		ImageColor3 = glow,
		ImageTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(1.6, 1.15),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = z,
		Parent = win,
	})
	local character = Ui.frame({
		Name = "Character",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1.02),
		Size = UDim2.fromScale(1.04, 1.0),
		ZIndex = z + 1,
		Parent = win,
	})
	for i, layer in Cutout.layers(def.id) do
		Ui.new("ImageLabel", {
			Name = layer.name,
			Image = layer.image,
			ImageColor3 = layer.color,
			ImageTransparency = layer.transparency,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Position = UDim2.fromScale(layer.offset.X, layer.offset.Y),
			Size = UDim2.fromScale(1, 1),
			ZIndex = z + i,
			Parent = character,
		})
	end
	-- The vignette: the lower part fades to night so the name and stats read on any art.
	Ui.frame({
		Name = "Vignette",
		BackgroundColor3 = C.Night,
		Position = UDim2.fromScale(0, 0.45),
		Size = UDim2.fromScale(1, 0.55),
		ZIndex = z + 8,
		Parent = win,
	}, {
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 0.35),
				NumberSequenceKeypoint.new(1, 0.08),
			}),
		}),
	})
	return { rays, character }
end

-- The clean template's emblem (board 06): star for N and R, crown for SR and up, glowing.
local function emblemWindow(face: Frame, def: any, rdef: any, z: number): GuiObject
	local slot = if rdef.emblem == "crown"
		then "emblem_crown_gold"
		elseif def.rarity == "Rare" then "emblem_star_blue"
		else "emblem_star_silver"
	local s = L.emblem.s
	local holder = Ui.frame({
		Name = "Emblem",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(L.emblem.x, L.emblem.y),
		Size = UDim2.fromScale(s, s * 5 / 7),
		ZIndex = z,
		Parent = face,
	}, { Ui.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Kit.image("fx_mote", {
		Name = "Halo",
		ImageColor3 = rdef.colors[4],
		ImageTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.9, 1.9),
		ZIndex = z,
		Parent = holder,
	})
	Kit.image(slot, {
		Name = "Mark",
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 1,
		Parent = holder,
	})
	return holder
end

local function statChip(face: Frame, icon: string, value: number, ys: { number }, z: number, h: number)
	local rowH = (ys[2] - ys[1]) * h
	local row = Ui.frame({
		Name = icon,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.9, ys[1]),
		Size = UDim2.fromScale(0.42, ys[2] - ys[1]),
		ZIndex = z,
		Parent = face,
	}, { Ui.list(true, math.max(2, math.floor(rowH * 0.12)), Enum.HorizontalAlignment.Right) })
	Kit.image(icon, {
		Size = UDim2.fromOffset(math.floor(rowH * 1.05), math.floor(rowH * 1.05)),
		LayoutOrder = 1,
		ZIndex = z,
		Parent = row,
	})
	local v = label({
		Name = "Value",
		Text = Format.number(value),
		FontFace = Theme.Face.Number,
		TextSize = math.max(8, math.floor(rowH * 0.86)),
		TextColor3 = C.White,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, rowH),
		LayoutOrder = 2,
		ZIndex = z,
		Parent = row,
	}, math.max(1, rowH * 0.08))
	v.TextXAlignment = Enum.TextXAlignment.Right
end

function Card.build(parent: Instance, o: Options): Frame
	local def = Characters.ById[o.characterId]
	assert(def, `unknown character {o.characterId}`)
	local rdef = Rarities.Defs[def.rarity]
	local level = o.level or 1
	local golden = o.golden == true
	local stage, stageIndex = Evolution.stageAt(level)
	local fx = FX[def.rarity] or FX.Common

	local holder = Ui.frame({
		Name = "Card",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(o.size.X, o.size.Y),
		Parent = parent,
	})
	local w = math.min(o.size.X, math.floor(o.size.Y * 5 / 7))
	local h = math.floor(w * 7 / 5)
	local size: Kit.Size = Kit.sizeFor(h)
	local small = size == "small"
	local tag = rdef.tag
	local face = Ui.frame({
		Name = "Face",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		Parent = holder,
	})
	local lift = Ui.new("UIScale", { Scale = 1, Parent = face })
	local canvasSize, canvasPos = Kit.canvas(size, w, h)

	-- Aura and orbit (behind everything). Grid cards keep them hidden until hovered.
	-- Aura transparency: the rarity's own (none for Common), and each stage from Awakened up makes
	-- it stronger, so a higher stage never looks weaker than a lower one.
	local auraStrength = fx.aura
	if stageIndex >= 2 then
		auraStrength = math.min(if auraStrength > 0 then auraStrength else 1, 0.55) - 0.12 * (stageIndex - 1)
	end
	local aura: ImageLabel? = nil
	if auraStrength > 0 and (not small or stageIndex >= 2) then
		aura = Kit.image(`aura_{tag}`, {
			Name = "Aura",
			ImageTransparency = math.clamp(auraStrength, 0, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			-- square, 1.55x the card height: the image's ring is a tall ellipse that then hugs the card
			Size = UDim2.fromOffset(math.floor(h * 1.55), math.floor(h * 1.55)),
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 0,
			Parent = face,
		})
	end
	local orbit: ImageLabel? = nil
	if fx.orbit and not small then
		orbit = Kit.image("ribbon_orbit", {
			Name = "Orbit",
			ImageColor3 = rdef.colors[4],
			ImageTransparency = 0.1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.68),
			Size = UDim2.fromScale(1.55, 0.46),
			ScaleType = Enum.ScaleType.Stretch,
			Rotation = -12,
			ZIndex = 1,
			Parent = face,
		})
		-- The far side of the orbit: the same arc turned half a turn, so the ribbon reads as a ring
		-- around the card (board 07).
		Kit.image("ribbon_orbit", {
			Name = "OrbitBack",
			ImageColor3 = rdef.colors[1],
			ImageTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ScaleType = Enum.ScaleType.Stretch,
			Rotation = 180,
			ZIndex = 1,
			Parent = orbit,
		})
	end

	local canvas = Ui.frame({
		Name = "Canvas",
		BackgroundTransparency = 1,
		Position = canvasPos,
		Size = canvasSize,
		ZIndex = 1,
		Parent = face,
	})
	local glowBase = math.max(0, fx.glow - (stageIndex - 1) * 0.08)
	local glow = full(`glow_{tag}_{size}`, 1, canvas, { ImageTransparency = glowBase })
	full(`panel_{tag}_{size}`, 2, canvas)

	-- The art window, clipped to its rectangle (the frame's corner plates cover its corners).
	local wx, wy, ww, wh = Kit.window(size)
	local win = Ui.frame({
		Name = "Window",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromScale(wx, wy),
		Size = UDim2.fromScale(ww, wh),
		ZIndex = 3,
		Parent = face,
	})
	local hasArt = not Cutout.isTemp(def.id)
	local parallax: { GuiObject } = {}
	if hasArt then
		parallax = artWindow(win, def, rdef, 3)
	else
		table.insert(parallax, emblemWindow(face, def, rdef, 4))
	end
	local fxLayer = Ui.frame({
		Name = "Fx",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
		Parent = win,
	})
	local shine: ImageLabel? = nil
	if (fx.shine or golden or stageIndex == 4) and not small then
		shine = Ui.image("card_shine", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(-0.5, 0.5),
			Size = UDim2.fromScale(0.45, 1.4),
			Rotation = 14,
			ScaleType = Enum.ScaleType.Stretch,
			ImageColor3 = if golden then C.GoldHi else C.White,
			ImageTransparency = 0.35,
			ZIndex = 13,
			Parent = fxLayer,
		})
	end
	local particles: { ImageLabel } = {}
	if fx.particles and not small then
		local n = if def.rarity == "Mythical" then 9 else 7
		for k = 1, n do
			local s = math.max(6, math.floor(w * (if fx.particles == "fx_sparkle" then 0.12 else 0.07)))
			table.insert(
				particles,
				Kit.image(fx.particles, {
					Name = "Particle",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(
						0.12 + ((k * 0.618) % 1) * 0.76,
						0.1 + ((k * 0.382) % 1) * 0.6
					),
					Size = UDim2.fromOffset(s, s),
					ImageColor3 = if fx.particles == "fx_sparkle" then C.White else rdef.colors[1],
					ImageTransparency = 0.3,
					ZIndex = 14,
					Parent = fxLayer,
				})
			)
		end
	end

	local energy = full(`energy_{tag}_{size}`, 20, canvas, { ImageTransparency = fx.energy })
	full(`frame_{tag}_{size}`, 21, canvas)
	if golden then
		full(`golden_{size}`, 22, canvas)
	end
	if stageIndex >= 3 then
		full(`inner_gold_{size}`, 22, canvas)
	end
	if stageIndex >= 2 then
		local gs = math.floor(w * (if small then 0.18 else 0.15))
		for _, p in
			{
				Vector2.new(0.05, 0.035),
				Vector2.new(0.95, 0.035),
				Vector2.new(0.05, 0.965),
				Vector2.new(0.95, 0.965),
			}
		do
			Kit.image(`corner_gem_{tag}`, {
				Name = "CornerGem",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(p.X, p.Y),
				Size = UDim2.fromOffset(gs, gs),
				ZIndex = 23,
				Parent = face,
			})
		end
	end

	-- Badge (top-left, over the frame) and, for SR and up, the crown (top-right).
	local badgeW = math.floor(w * (if small then 0.6 else 0.46))
	local badge = Kit.image(`badge_{tag}_{if size == "large" then "large" else "small"}`, {
		Name = "Badge",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(-math.floor(w * 0.06), math.floor(h * 0.02)),
		Size = UDim2.fromOffset(badgeW, math.floor(badgeW / 2)),
		ZIndex = 30,
		Parent = face,
	})
	if stageIndex == 4 then
		Kit.image("emblem_crown_gold", {
			Name = "MaxCrown",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.42, 0.3),
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 31,
			Parent = badge,
		})
	end
	if rdef.emblem == "crown" and not small then
		Kit.image("emblem_crown_gold", {
			Name = "Crown",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, math.floor(w * 0.05), 0, math.floor(h * 0.02)),
			Size = UDim2.fromOffset(math.floor(w * 0.2), math.floor(w * 0.2)),
			Rotation = 12,
			ZIndex = 30,
			Parent = face,
		})
	end

	-- Text: name, rarity name, level, stats, family gem.
	local name = label({
		Name = "Name",
		Text = def.displayName,
		FontFace = Theme.Face.Title,
		TextSize = math.max(8, math.floor(h * (if small then 0.1 else 0.07))),
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, if small then 0.66 else L.nameY[1]),
		Size = UDim2.fromScale(0.82, if small then 0.12 else L.nameY[2] - L.nameY[1]),
		ZIndex = 32,
		Parent = face,
	}, math.max(1, h * 0.006))
	Ui.fit(name, name.TextSize, 6)
	if not hasArt and not small then
		-- Board 06's name plate: a dark band edged in the rarity colour.
		Ui.frame({
			Name = "NamePlate",
			BackgroundColor3 = C.Night,
			BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, L.nameY[1]),
			Size = UDim2.fromScale(0.78, L.nameY[2] - L.nameY[1]),
			ZIndex = 31,
			Parent = face,
		}, { Ui.corner(math.max(2, math.floor(h * 0.012))), Ui.stroke(rdef.colors[2], 1, 0.35) })
	end
	local rarityText = if golden then `Golden {rdef.displayName}` else rdef.displayName
	label({
		Name = "Rarity",
		Text = rarityText,
		FontFace = Theme.Face.Bold,
		TextSize = math.max(7, math.floor(h * (if small then 0.075 else 0.048))),
		TextColor3 = if golden then C.GoldHi else rdef.colors[1]:Lerp(rdef.colors[2], 0.5),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, if small then 0.78 else L.rarityY[1]),
		Size = UDim2.fromScale(0.8, if small then 0.08 else L.rarityY[2] - L.rarityY[1]),
		ZIndex = 32,
		Parent = face,
	}, 1)
	local lvl = label({
		Name = "Level",
		Text = `Lv. {level}`,
		FontFace = Theme.Face.Number,
		TextSize = math.max(7, math.floor(h * (if small then 0.075 else 0.062))),
		TextColor3 = if stageIndex == 4 then C.GoldHi else C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(if small then 0.1 else 0.11, if small then 0.865 else L.levelY[1]),
		Size = UDim2.fromScale(0.4, if small then 0.08 else L.levelY[2] - L.levelY[1]),
		ZIndex = 32,
		Parent = face,
	}, math.max(1, h * 0.006))
	lvl:SetAttribute("Stage", stage.id)
	if not small then
		local gs = math.floor((L.gemY[2] - L.gemY[1]) * h)
		local gem = Kit.image(`gem_family_{string.lower(def.family)}`, {
			Name = "FamilyGem",
			Position = UDim2.fromScale(0.1, L.gemY[1]),
			Size = UDim2.fromOffset(gs, gs),
			ZIndex = 32,
			Parent = face,
		})
		Ui.image(`family_{string.lower(def.family)}`, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			ImageColor3 = C.White,
			ZIndex = 33,
			Parent = gem,
		})
	end
	local showStats = if o.stats ~= nil then o.stats else not small
	if showStats then
		local st = Cards.statsAt(def.id, level)
		statChip(face, "icon_atk", st.atk, L.atkY, 32, h)
		statChip(face, "icon_def", st.def, L.defY, 32, h)
	end

	if stageIndex == 4 and not small then
		Kit.image("ribbon_max", {
			Name = "MaxRibbon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.985),
			Size = UDim2.fromOffset(math.floor(w * 0.62), math.floor(w * 0.155)),
			ZIndex = 34,
			Parent = face,
		})
	end
	if o.sticker then
		local sw = math.floor(w * (if small then 0.62 else 0.5))
		Kit.image(`sticker_{o.sticker}`, {
			Name = "Sticker",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, math.floor(w * 0.1), 0, math.floor(h * 0.04)),
			Size = UDim2.fromOffset(sw, math.floor(sw / 2)),
			ZIndex = 40,
			Parent = face,
		})
	end
	if o.favorite then
		local fs = math.floor(w * (if small then 0.24 else 0.14))
		Kit.image("icon_favorite_on", {
			Name = "Favorite",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(0.94, if small then 0.66 else 0.6),
			Size = UDim2.fromOffset(fs, fs),
			ZIndex = 40,
			Parent = face,
		})
	end

	-- Animation, hover and parallax (App/CardFx; nothing runs while the card is off screen).
	local depth = math.max(2, math.floor(w * 0.05))
	local layers: { CardFx.Layer } = {}
	for _, obj in parallax do
		table.insert(layers, { obj = obj, base = obj.Position, depth = depth })
	end
	table.insert(layers, { obj = fxLayer :: GuiObject, base = fxLayer.Position, depth = depth * 1.4 })
	CardFx.add({
		root = holder,
		big = not small,
		aura = aura,
		auraBase = if aura then aura.ImageTransparency else 1,
		auraIdle = o.hover == true, -- grid cards: aura only while hovered
		orbit = orbit,
		glow = glow,
		glowBase = glowBase,
		glowPulse = fx.pulse + (stageIndex - 1) * 0.04,
		energy = energy,
		energyBase = fx.energy,
		crackle = stageIndex >= 3,
		shine = shine,
		shineEvery = if stageIndex == 4 then 2.6 else (fx.shine or 5),
		particles = particles,
		particleMode = if fx.particles == "fx_sparkle"
			then "twinkle"
			elseif fx.particles then "rise"
			else "none",
		layers = layers,
		tilt = Vector2.zero,
		target = Vector2.zero,
		held = false,
		interactive = o.interactive == true,
		hover = o.hover == true,
		hovered = false,
		lift = lift,
		visible = true,
		phase = (#def.id * 0.37) % 3,
		seed = #def.id * 13 + level,
		priority = w * h * (1 + stageIndex * 0.1 + rdef.order * 0.05),
	}, face)
	holder:SetAttribute("Placeholder", not hasArt)
	holder:SetAttribute("Rarity", def.rarity)
	holder:SetAttribute("Level", level)
	holder:SetAttribute("Stage", stage.id)
	holder:SetAttribute("KitSize", size)
	return holder
end

return Card
