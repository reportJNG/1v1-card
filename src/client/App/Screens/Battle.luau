--!strict
-- The battle screen over the 3D arena (App/BattleStage), laid out like the target
-- (docs/brief/bad-gui/18-target-battle-screen.png, BAD_GUI_8):
--   top     two long HP bars meeting at a hexagon timer medallion with a ROUND plate; under each
--           bar only the fighter's name (+ status icons), rarity badge, an HP sub-bar with numbers
--           and the energy diamonds
--   bottom  three tall action cards (ATTACK / DEFEND / SPECIAL) on a glass tray with the energy
--           pips toward the Special; a small FORFEIT in the corner
--   moments the arena intro (map name, VS), ROUND N, LOCKED IN, the reveal of both picks over the
--           medallion, who acts first, K.O.!
-- It sends picks and KO replacements and only animates the result packets the server sends:
-- nothing about the outcome is computed here. There is no battle log; events are big pops in the
-- arena (BattleStage).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Arenas = require(Shared.Config.Arenas)
local Rules = require(Shared.Config.Battle)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Kit = require(App.Kit)
local Visuals = require(App.Visuals)
local BattleStage = require(App.BattleStage)
local BattleResult = require(script.Parent.BattleResult)

local C = Theme.Color
local F = Theme.Face

local Battle = {}

export type Handle = {
	round: (msg: { kind: string, you: number, data: any }) -> (),
	finish: (data: any) -> (),
	destroy: () -> (),
}

local MEDAL_Y = 50 -- centre of the timer medallion (design px)
local BAR_W = 300
local BAR_GAP = 52 -- from the screen centre to each bar's inner end
local RING_SEGMENTS = 24

-- Each action's colour and icon (the card kit's sword and shield, the Lightning family bolt).
local ACTIONS = {
	{ name = "Attack", color = Color3.fromHex("#FF4A5E"), icon = "icon_atk", kit = true },
	{ name = "Defend", color = Color3.fromHex("#3FA9FF"), icon = "icon_def", kit = true },
	{ name = "Special", color = Color3.fromHex("#B36BFF"), icon = "family_lightning", kit = false },
}
local ACTION_BY: { [string]: any } = {}
for _, a in ACTIONS do
	ACTION_BY[a.name] = a
end

-- Status effects as icons next to the name (no text).
local STATUS_ICON: { [string]: { slot: string, color: Color3 } } = {
	Burn = { slot = "family_flame", color = Color3.fromHex("#FF8A3D") },
	Chill = { slot = "family_ice", color = Color3.fromHex("#9FE6FF") },
	Weaken = { slot = "family_shadow", color = Color3.fromHex("#C59BFF") },
}

local function actionIcon(a: any, size: number, props: { [string]: any }): ImageLabel
	local base = {
		Size = UDim2.fromOffset(size, size),
		ImageColor3 = if a.kit then a.color:Lerp(C.White, 0.25) else C.GoldHi,
	}
	for k, v in props do
		(base :: any)[k] = v
	end
	if a.kit then
		return Kit.image(a.icon, base)
	end
	return Ui.image(a.icon, base)
end

-- A regular hexagon from three turned rectangles (a TEMP medallion until the painted H2 piece).
local function hexagon(parent: Instance, radius: number, color: Color3, z: number, name: string): Frame
	local holder = Ui.frame({
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(radius * 2, radius * 2),
		ZIndex = z,
		Parent = parent,
	})
	for i = 0, 2 do
		Ui.frame({
			BackgroundColor3 = color,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(radius, radius * math.sqrt(3)),
			Rotation = 30 + i * 60,
			ZIndex = z,
			Parent = holder,
		})
	end
	return holder
end

local function popScale(obj: GuiObject, from: number, reduced: boolean, time: number?)
	local scale = obj:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = obj })
	if reduced then
		scale.Scale = 1
		return
	end
	scale.Scale = from
	TweenService:Create(scale, TweenInfo.new(time or 0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function fadeOut(obj: GuiObject, delay: number, time: number)
	task.delay(delay, function()
		if obj.Parent == nil then
			return
		end
		local info = TweenInfo.new(time)
		local all: { Instance } = obj:GetDescendants()
		table.insert(all, obj)
		for _, d in all do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(time + 0.05, function()
			obj:Destroy()
		end)
	end)
end

function Battle.open(ctx: any, start: any): Handle
	local you: number = start.you
	local them = 3 - you
	local view = start.view
	local picked = false
	local chosen: string? = nil
	local closed = false
	local animating = 0
	local reduced = ctx.reducedMotion()
	local arena = Arenas.ById[start.arena or ""] or Arenas.List[1]

	local stage = BattleStage.new(you, {
		[1] = view.sides[1].units[view.sides[1].active].characterId,
		[2] = view.sides[2].units[view.sides[2].active].characterId,
	}, reduced, arena.id)
	local onStage: { [number]: string } = {
		[1] = view.sides[1].units[view.sides[1].active].characterId,
		[2] = view.sides[2].units[view.sides[2].active].characterId,
	}

	local handle: Handle
	local layer: Frame = nil :: any
	local screen = ctx.overlay(function(l)
		layer = l
		l.Name = "Battle"
		-- A soft vignette at the top and bottom so the bars and the tray read over the arena.
		for _, edge in { { 0, 0 }, { 1, 180 } } do
			Ui.frame({
				BackgroundColor3 = C.Night,
				AnchorPoint = Vector2.new(0, edge[1]),
				Position = UDim2.fromScale(-0.5, edge[1]),
				Size = UDim2.new(2, 0, 0, 130),
				Parent = l,
			}, {
				Ui.new("UIGradient", {
					Rotation = 90 + edge[2],
					Transparency = NumberSequence.new(0.35, 1),
				}),
			})
		end
		return { destroy = function() end }
	end)
	Ui.sound("open")

	------------------------------------------------------------------------------------------
	-- Top: the hexagon timer medallion and the ROUND plate
	------------------------------------------------------------------------------------------
	local medal = Ui.frame({
		Name = "Medallion",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, MEDAL_Y),
		Size = UDim2.fromOffset(92, 92),
		ZIndex = 5,
		Parent = layer,
	})
	hexagon(medal, 46, Color3.fromHex("#C9D4F0"), 5, "Steel")
	hexagon(medal, 42, Color3.fromHex("#3B4670"), 6, "Bevel")
	hexagon(medal, 37, Color3.fromHex("#0D1430"), 7, "Face")
	local segs: { Frame } = {}
	for i = 1, RING_SEGMENTS do
		local a = (i - 0.5) / RING_SEGMENTS * math.pi * 2
		segs[i] = Ui.frame({
			BackgroundColor3 = C.Blue,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * 29, 0.5, -math.cos(a) * 29),
			Size = UDim2.fromOffset(4, 8),
			Rotation = math.deg(a),
			ZIndex = 8,
			Parent = medal,
		}, { Ui.corner(2) })
	end
	local timerLabel = Ui.display({
		Name = "Timer",
		Text = "",
		TextSize = 40,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 9,
		Parent = medal,
	})
	timerLabel.TextColor3 = C.White
	Ui.outline(C.Night, 3).Parent = timerLabel
	local medalScale = Ui.new("UIScale", { Parent = medal })

	local plate = Ui.frame({
		Name = "RoundPlate",
		BackgroundColor3 = Color3.fromHex("#141B38"),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, MEDAL_Y + 44),
		Size = UDim2.fromOffset(112, 24),
		ZIndex = 6,
		Parent = layer,
	}, { Ui.corner(6), Ui.stroke(Color3.fromHex("#9AA8D0"), 2, 0.1) })
	local roundLabel = Ui.display({
		Name = "Round",
		Text = "",
		TextSize = 18,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
		Parent = plate,
	})
	roundLabel.TextColor3 = C.Text
	Ui.outline(C.Night, 2).Parent = roundLabel

	------------------------------------------------------------------------------------------
	-- Top: one bar and info column per side (the player on the left)
	------------------------------------------------------------------------------------------
	type SideUi = {
		fill: Frame,
		chip: Frame,
		bar: Frame,
		name: TextLabel,
		statusRow: Frame,
		badge: TextLabel,
		subFill: Frame,
		subText: TextLabel,
		pips: { ImageLabel },
		info: Frame,
		hp: number,
		maxHp: number,
		energy: number,
		status: { [string]: boolean },
		characterId: string,
	}
	local ui: { [number]: SideUi } = {}
	for _, side in { you, them } do
		local left = side == you
		local fillColor = if left then Color3.fromHex("#FF4FB8") else Color3.fromHex("#FFB52E")
		local fillHi = if left then Color3.fromHex("#FF9ADF") else Color3.fromHex("#FFE58A")
		local bar = Ui.frame({
			Name = if left then "YouBar" else "OpponentBar",
			BackgroundColor3 = Color3.fromHex("#0C1028"),
			BackgroundTransparency = 0.1,
			AnchorPoint = Vector2.new(if left then 1 else 0, 0.5),
			Position = UDim2.new(0.5, if left then -BAR_GAP else BAR_GAP, 0, MEDAL_Y - 12),
			Size = UDim2.fromOffset(BAR_W, 24),
			ClipsDescendants = true,
			ZIndex = 3,
			Parent = layer,
		}, { Ui.corner(5) })
		Ui.stroke(Color3.fromHex("#B8C4E6"), 2.5, 0).Parent = bar
		-- Both bars drain toward the screen edge, from the medallion side.
		local anchorX = if left then 1 else 0
		local chip = Ui.frame({
			Name = "Chip",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.15,
			AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.fromScale(anchorX, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = bar,
		})
		local fill = Ui.frame({
			Name = "Fill",
			BackgroundColor3 = C.White,
			AnchorPoint = Vector2.new(anchorX, 0),
			Position = UDim2.fromScale(anchorX, 0),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = bar,
		}, {
			Ui.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new(fillHi, fillColor),
			}),
		})
		-- a glossy line along the top of the bar
		Ui.frame({
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.7,
			Position = UDim2.fromOffset(0, 3),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 5,
			Parent = bar,
		})

		local align = if left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right
		local info = Ui.frame({
			Name = if left then "YouInfo" else "OpponentInfo",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(if left then 1 else 0, 0),
			Position = UDim2.new(0.5, if left then -BAR_GAP else BAR_GAP, 0, MEDAL_Y + 4),
			Size = UDim2.fromOffset(BAR_W, 84),
			ZIndex = 3,
			Parent = layer,
		})
		-- name + status icons
		local nameRow = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 28),
			ZIndex = 3,
			Parent = info,
		}, { Ui.list(true, 6, align) });
		(nameRow:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment =
			Enum.VerticalAlignment.Center
		local name = Ui.display({
			Name = "Name",
			Text = "",
			TextSize = 24,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			LayoutOrder = if left then 1 else 3,
			ZIndex = 3,
			Parent = nameRow,
		})
		name.TextColor3 = C.White
		Ui.outline(C.Night, 3).Parent = name
		local statusRow = Ui.frame({
			Name = "Status",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 26),
			LayoutOrder = 2,
			ZIndex = 3,
			Parent = nameRow,
		}, { Ui.list(true, 3, align) })
		-- rarity badge + HP sub-bar with numbers
		local subRow = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 22),
			ZIndex = 3,
			Parent = info,
		}, { Ui.list(true, 6, align) });
		(subRow:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment =
			Enum.VerticalAlignment.Center
		local badge = Ui.text({
			Name = "Rarity",
			Text = "",
			FontFace = F.Italic,
			TextSize = 22,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(42, 22),
			LayoutOrder = if left then 1 else 3,
			ZIndex = 3,
			Parent = subRow,
		})
		Ui.outline(C.Night, 2.5).Parent = badge
		local sub = Ui.frame({
			Name = "HpSub",
			BackgroundColor3 = Color3.fromHex("#0C1028"),
			BackgroundTransparency = 0.15,
			Size = UDim2.fromOffset(236, 20),
			ClipsDescendants = true,
			LayoutOrder = 2,
			ZIndex = 3,
			Parent = subRow,
		}, { Ui.corner(10), Ui.stroke(fillColor, 1.5, 0.2) })
		local subFill = Ui.frame({
			Name = "Fill",
			BackgroundColor3 = fillColor,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = sub,
		}, { Ui.corner(10) })
		local subText = Ui.text({
			Name = "Hp",
			Text = "",
			FontFace = F.Number,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Parent = sub,
		})
		Ui.outline(C.Night, 2).Parent = subText
		-- energy diamonds
		local pipRow = Ui.frame({
			Name = "Energy",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(if left then 44 else -44, 56),
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 3,
			Parent = info,
		}, { Ui.list(true, 2, align) })
		local pips = {}
		for i = 1, Rules.energyMax do
			pips[i] = Ui.image("energy_pip_off", {
				Size = UDim2.fromOffset(24, 24),
				LayoutOrder = if left then i else -i,
				ZIndex = 3,
				Parent = pipRow,
			})
		end
		ui[side] = {
			fill = fill,
			chip = chip,
			bar = bar,
			name = name,
			statusRow = statusRow,
			badge = badge,
			subFill = subFill,
			subText = subText,
			pips = pips,
			info = info,
			hp = -1,
			maxHp = 1,
			energy = -1,
			status = {},
			characterId = "",
		}
	end

	local function setHp(side: number, hp: number, maxHp: number, animate: boolean)
		local s = ui[side]
		local frac = math.clamp(hp / math.max(1, maxHp), 0, 1)
		local dropped = s.hp >= 0 and hp < s.hp
		s.hp, s.maxHp = hp, maxHp
		s.subText.Text = `{hp} / {maxHp}`
		if animate and not reduced then
			TweenService
				:Create(
					s.fill,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad),
					{ Size = UDim2.fromScale(frac, 1) }
				)
				:Play()
			TweenService:Create(s.subFill, TweenInfo.new(0.18), { Size = UDim2.fromScale(frac, 1) }):Play()
			-- the white chip trail drains after the real drop
			task.delay(if dropped then 0.4 else 0, function()
				TweenService:Create(
					s.chip,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad),
					{ Size = UDim2.fromScale(frac, 1) }
				):Play()
			end)
			if dropped then
				local home = s.bar.Position
				task.spawn(function()
					for _, dx in { 5, -4, 3, -2, 0 } do
						s.bar.Position = home + UDim2.fromOffset(dx, 0)
						task.wait(0.03)
					end
					s.bar.Position = home
				end)
			end
		else
			s.fill.Size = UDim2.fromScale(frac, 1)
			s.subFill.Size = UDim2.fromScale(frac, 1)
			s.chip.Size = UDim2.fromScale(frac, 1)
		end
	end

	local function setEnergy(side: number, energy: number, animate: boolean)
		local s = ui[side]
		for i, pip in s.pips do
			local on = i <= energy
			pip.Image = Ui.asset(if on then "energy_pip_on" else "energy_pip_off")
			if on and animate and i > s.energy and s.energy >= 0 then
				popScale(pip, 1.8, reduced, 0.35)
			end
		end
		s.energy = energy
	end

	local function setStatus(side: number, status: { [string]: number })
		local s = ui[side]
		local now: { [string]: boolean } = {}
		for _, child in s.statusRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local order = 0
		for _, name in { "Burn", "Chill", "Weaken" } do
			if status[name] then
				order += 1
				now[name] = true
				local spec = STATUS_ICON[name]
				local icon = Ui.image(spec.slot, {
					Name = name,
					Size = UDim2.fromOffset(26, 26),
					ImageColor3 = spec.color,
					LayoutOrder = order,
					ZIndex = 3,
					Parent = s.statusRow,
				})
				if not s.status[name] then
					popScale(icon, 2, reduced, 0.35)
				end
			end
		end
		s.status = now
	end

	local function setUnit(side: number)
		local sv = view.sides[side]
		local u = sv.units[sv.active]
		local s = ui[side]
		if s.characterId ~= u.characterId then
			s.characterId = u.characterId
			local def = Characters.ById[u.characterId]
			s.name.Text = string.upper(def.displayName)
			local rdef = Rarities.Defs[def.rarity]
			s.badge.Text = rdef.badge
			s.badge.TextColor3 = Theme.Rarity[def.rarity]
			s.hp = -1
		end
	end

	-- Brings every display in step with the latest view (HP, energy and status only when no
	-- round is animating, so a bar never jumps ahead of the hit that drains it).
	local function syncSides()
		for side = 1, 2 do
			setUnit(side)
			if animating == 0 then
				local sv = view.sides[side]
				local u = sv.units[sv.active]
				setHp(side, u.hp, u.maxHp, ui[side].hp >= 0)
				setEnergy(side, sv.energy, true)
				setStatus(side, u.status)
				stage.hp[side] = u.hp
			end
		end
	end

	------------------------------------------------------------------------------------------
	-- Moments: big words over the arena
	------------------------------------------------------------------------------------------
	local function bigWord(
		text: string,
		y: number,
		size: number,
		color: Color3,
		strokeColor: Color3,
		hold: number
	)
		local word = Ui.display({
			Name = "Moment",
			Text = text,
			TextSize = size,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(600, size + 20),
			ZIndex = 30,
			Parent = layer,
		})
		word.TextColor3 = color
		Ui.outline(strokeColor, math.max(3, size / 14)).Parent = word
		popScale(word, 2.2, reduced, 0.35)
		fadeOut(word, hold, 0.3)
		return word
	end

	------------------------------------------------------------------------------------------
	-- Reveal: both picks flip in beside the medallion, then who acts first
	------------------------------------------------------------------------------------------
	local function revealIcon(side: number, action: string)
		local a = ACTION_BY[action]
		if a == nil then
			return
		end
		local left = side == you
		local tile = Ui.glowTile("Frame", {
			Name = `Reveal{if left then "You" else "Them"}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, if left then -40 else 40, 0, MEDAL_Y + 112),
			Size = UDim2.fromOffset(62, 62),
			ZIndex = 12,
			Parent = layer,
		}, a.color, false)
		actionIcon(a, 46, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 13,
			Parent = tile,
		})
		if not reduced then
			-- a card flip: squeezed to nothing, then open
			tile.Size = UDim2.fromOffset(0, 62)
			TweenService
				:Create(tile, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(62, 62) })
				:Play()
		end
		fadeOut(tile, 1.6, 0.3)
	end

	local function firstMark(side: number)
		local s = ui[side]
		local left = side == you
		local mark = Ui.frame({
			Name = "First",
			BackgroundColor3 = C.Gold,
			-- at the medallion end of the diamond row
			AnchorPoint = Vector2.new(if left then 1 else 0, 0),
			Position = UDim2.new(if left then 1 else 0, if left then -64 else 64, 0, 56),
			Size = UDim2.fromOffset(40, 24),
			ZIndex = 4,
			Parent = s.info,
		}, { Ui.corner(6), Ui.stroke(C.GoldHi, 2, 0) })
		local t = Ui.display({
			Text = "1ST",
			TextSize = 18,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = mark,
		})
		t.TextColor3 = C.GoldInk
		popScale(mark, 1.8, reduced, 0.3)
		fadeOut(mark, 1.8, 0.3)
		-- the side's bar flashes gold
		local edge = s.bar:FindFirstChildOfClass("UIStroke")
		if edge and not reduced then
			edge.Color = C.GoldHi
			edge.Thickness = 4
			task.delay(0.6, function()
				edge.Color = Color3.fromHex("#B8C4E6")
				edge.Thickness = 2.5
			end)
		end
	end

	------------------------------------------------------------------------------------------
	-- Bottom: the opponent's "?" card, the action tray and the corner FORFEIT
	------------------------------------------------------------------------------------------
	local mystery = Ui.glowTile("Frame", {
		Name = "OpponentPick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 150),
		Size = UDim2.fromOffset(62, 82),
		Visible = false,
		ZIndex = 4,
		Parent = layer,
	}, C.Gold, false)
	local q = Ui.display(
		{ Text = "?", TextSize = 48, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = mystery },
		true
	)
	Ui.outline(C.Night, 3).Parent = q
	if not reduced then
		local ms = Ui.new("UIScale", { Parent = mystery })
		TweenService:Create(
			ms,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.08 }
		):Play()
	end

	local trayHolder = Ui.frame({
		Name = "Tray",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(440, 200),
		Parent = layer,
	})
	local tray = Ui.frame({
		Name = "Glass",
		BackgroundColor3 = Color3.fromHex("#1A2246"),
		BackgroundTransparency = 0.35,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(430, 40),
		Parent = trayHolder,
	}, {
		Ui.corner(10),
		Ui.stroke(Color3.fromHex("#9AB4FF"), 1.5, 0.45),
		Ui.new("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new(0.1, 0.6),
		}),
	})
	local specialPips = Ui.frame({
		Name = "SpecialPips",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(200, 8),
		ZIndex = 2,
		Parent = tray,
	}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
	local cardRow = Ui.frame({
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(410, 156),
		ZIndex = 3,
		Parent = trayHolder,
	})

	type Card = {
		button: TextButton,
		label: TextLabel,
		dim: Frame,
		lock: ImageLabel,
		scale: UIScale,
		edge: UIStroke,
		home: UDim2,
		enabled: boolean,
		color: Color3,
	}
	local cards: { [string]: Card } = {}
	local stamp: TextLabel? = nil

	local function setCard(name: string, state: "open" | "chosen" | "dim" | "locked" | "off")
		local c = cards[name]
		c.enabled = state == "open"
		c.lock.Visible = state == "locked"
		c.dim.BackgroundTransparency = if state == "open" or state == "chosen"
			then 1
			elseif state == "locked" then 0.4
			else 0.5
		local lift = state == "chosen"
		local goalPos = if lift then c.home - UDim2.fromOffset(0, 16) else c.home
		local goalScale = if lift then 1.06 else 1
		c.edge.Color = if lift then C.GoldHi else c.color:Lerp(C.White, 0.15)
		c.edge.Thickness = if lift then 4 else 2.5
		if reduced then
			c.button.Position = goalPos
			c.scale.Scale = goalScale
		else
			TweenService:Create(c.button, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { Position = goalPos })
				:Play()
			TweenService:Create(c.scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = goalScale })
				:Play()
		end
	end

	local function setButtons()
		local mine = view.sides[you]
		local unit = mine.units[mine.active]
		local open = view.phase == "Picking" and not picked and not closed
		for _, a in ACTIONS do
			local state: any = if chosen == a.name
				then "chosen"
				elseif chosen ~= nil then "dim"
				elseif a.name == "Special" and not mine.canSpecial then "locked"
				elseif open then "open"
				else "off"
			setCard(a.name, state)
		end
		cards.Special.label.Text = `SPECIAL ({unit.specialCost})`
		-- the pips under the tray: energy toward the Special's cost
		for _, child in specialPips:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i = 1, unit.specialCost do
			Ui.frame({
				BackgroundColor3 = if i <= mine.energy then C.White else Color3.fromHex("#3A4470"),
				Size = UDim2.fromOffset(30, 6),
				LayoutOrder = i,
				ZIndex = 2,
				Parent = specialPips,
			}, { Ui.corner(3) })
		end
	end

	local function lockedIn()
		if stamp then
			stamp:Destroy()
		end
		local s = Ui.display({
			Name = "LockedIn",
			Text = "LOCKED IN",
			TextSize = 34,
			Rotation = -6,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.fromOffset(260, 44),
			ZIndex = 20,
			Parent = trayHolder,
		}, true)
		Ui.outline(C.Night, 4).Parent = s
		popScale(s, 2, reduced, 0.25)
		stamp = s
	end

	local function clearStamp()
		if stamp then
			fadeOut(stamp, 0, 0.2)
			stamp = nil
		end
	end

	local function pick(action: string)
		if picked then
			return
		end
		picked = true
		chosen = action
		setButtons()
		lockedIn()
		Ui.sound(`pick_{string.lower(action)}`)
		local reply = ctx.request("Battle.Pick", { round = view.round, action = action }, true)
		if not reply.ok then
			picked = false
			chosen = nil
			clearStamp()
			ctx.fail(reply.err)
			setButtons()
		end
	end

	for i, a in ACTIONS do
		local x = (i - 2) * 136
		local home = UDim2.new(0.5, x, 1, 0)
		local b: TextButton = Ui.glowTile("TextButton", {
			Name = a.name,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = home,
			Size = UDim2.fromOffset(118, 150),
			ZIndex = 3,
			Parent = cardRow,
		}, a.color, false)
		local edge = b:FindFirstChild("Edge") :: UIStroke
		edge.Thickness = 2.5
		-- the icon's glow
		Ui.image("sparkle", {
			ImageColor3 = a.color,
			ImageTransparency = 0.35,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 58),
			Size = UDim2.fromOffset(104, 104),
			ZIndex = 3,
			Parent = b,
		})
		actionIcon(a, 72, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 58),
			ZIndex = 4,
			Parent = b,
		})
		local label = Ui.display({
			Name = "Label",
			Text = string.upper(a.name),
			TextSize = 21,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -8, 0, 26),
			ZIndex = 5,
			Parent = b,
		})
		label.TextColor3 = C.White
		Ui.outline(C.Night, 2.5).Parent = label
		Ui.fit(label, 21, 14)
		local dim = Ui.frame({
			Name = "Dim",
			BackgroundColor3 = C.Night,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6,
			Parent = b,
		}, { Ui.corner(12) })
		local lock = Ui.icon("icon_lock", 34, {
			Name = "Lock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 58),
			Visible = false,
			ZIndex = 7,
			Parent = b,
		})
		cards[a.name] = {
			button = b,
			label = label,
			dim = dim,
			lock = lock,
			scale = b:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = b }),
			edge = edge,
			home = home,
			enabled = true,
			color = a.color,
		}
		b.Activated:Connect(function()
			if cards[a.name].enabled then
				pick(a.name)
			else
				Ui.sound("error")
			end
		end)
	end

	-- A small dark FORFEIT in the corner (TEMP: drawn until the painted H2 piece), with a confirm.
	local forfeit: TextButton = Ui.new("TextButton", {
		Name = "Forfeit",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromHex("#151A30"),
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(104, 32),
		Parent = layer,
	}, { Ui.corner(6), Ui.stroke(Color3.fromHex("#8A7A5A"), 1.5, 0.2) })
	local forfeitLabel = Ui.display({
		Text = "FORFEIT",
		TextSize = 17,
		Size = UDim2.fromScale(1, 1),
		Parent = forfeit,
	})
	forfeitLabel.TextColor3 = Color3.fromHex("#D8CFB8")
	Ui.juice(forfeit)
	forfeit.Activated:Connect(function()
		Ui.sound("click")
		ctx.confirm("Forfeit?", "Forfeit counts as a loss.", "Forfeit", function()
			ctx.request("Battle.Forfeit")
		end)
	end)

	------------------------------------------------------------------------------------------
	-- The KO replacement picker
	------------------------------------------------------------------------------------------
	local chooser = Ui.frame({
		Name = "Chooser",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(470, 310),
		Visible = false,
		ZIndex = 10,
		Parent = layer,
	})
	Ui.skin(chooser, "panel", 0.8)
	local chooserBody = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 1, -28),
		ZIndex = 11,
		Parent = chooser,
	})
	local waitWord: TextLabel? = nil

	local function showChooser()
		Ui.clear(chooserBody)
		local mine = view.sides[you]
		if not mine.needsNext then
			chooser.Visible = false
			if waitWord == nil then
				local w = Ui.display({
					Name = "OpponentChoosing",
					Text = "OPPONENT IS CHOOSING",
					TextSize = 30,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.42),
					Size = UDim2.fromOffset(520, 40),
					ZIndex = 9,
					Parent = layer,
				})
				Ui.outline(C.Night, 3).Parent = w
				waitWord = w
			end
			return
		end
		chooser.Visible = true
		Ui.popIn(chooser, reduced)
		local title = Ui.display({
			Text = "CHOOSE YOUR NEXT FIGHTER",
			TextSize = 28,
			Size = UDim2.new(1, 0, 0, 36),
			ZIndex = 11,
			Parent = chooserBody,
		})
		Ui.outline(C.Night, 3).Parent = title
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 1, -44),
			ZIndex = 11,
			Parent = chooserBody,
		}, { Ui.list(true, 16, Enum.HorizontalAlignment.Center) })
		for slot, u in mine.units do
			if u.hp > 0 and slot ~= mine.active then
				local b: TextButton = Ui.new("TextButton", {
					Name = `Next{slot}`,
					Text = "",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(140, 226),
					LayoutOrder = slot,
					ZIndex = 11,
					Parent = row,
				})
				local card = Visuals.portrait(b, u.characterId, false, Vector2.new(140, 196), true, u.level)
				card.ZIndex = 12
				local hp = Ui.text({
					Text = `{u.hp} / {u.maxHp}`,
					FontFace = F.Number,
					TextSize = 20,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 198),
					Size = UDim2.new(1, 0, 0, 26),
					ZIndex = 12,
					Parent = b,
				})
				Ui.outline(C.Night, 2).Parent = hp
				Ui.juice(b)
				b.Activated:Connect(function()
					Ui.sound("click")
					chooser.Visible = false
					ctx.request("Battle.ChooseNext", { slot = slot })
				end)
			end
		end
	end

	------------------------------------------------------------------------------------------
	-- The timer
	------------------------------------------------------------------------------------------
	local running = true
	local lastSecond = -1
	task.spawn(function()
		while running do
			local left = math.max(0, view.deadline - ctx.now())
			if view.phase == "Picking" or view.phase == "Choosing" then
				local total = if view.phase == "Picking" then Rules.pickSeconds else Rules.nextSeconds
				local lit = math.clamp(math.ceil(left / total * RING_SEGMENTS), 0, RING_SEGMENTS)
				local urgent = left <= 3
				for i, seg in segs do
					seg.Visible = i <= lit
					seg.BackgroundColor3 = if urgent then C.Red else C.Blue
				end
				local sec = math.ceil(left)
				timerLabel.Text = tostring(sec)
				timerLabel.TextColor3 = if urgent then C.Red else C.White
				if sec ~= lastSecond and urgent and sec > 0 then
					Ui.sound("tick")
					if not reduced then
						medalScale.Scale = 1.12
						TweenService
							:Create(medalScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = 1 })
							:Play()
					end
				end
				lastSecond = sec
			else
				for _, seg in segs do
					seg.Visible = false
				end
				timerLabel.Text = ""
			end
			task.wait(0.1)
		end
	end)

	local function renderAll()
		roundLabel.Text = `ROUND {math.min(view.round, Rules.maxRounds)}`
		syncSides()
		setButtons()
		-- Keep the stage in step with who is actually on each pad.
		for side = 1, 2 do
			local s = view.sides[side]
			local id = s.units[s.active].characterId
			if onStage[side] ~= id and s.units[s.active].hp > 0 then
				onStage[side] = id
				stage:enter(side, id)
			end
		end
	end

	------------------------------------------------------------------------------------------
	-- The arena intro: map name, the fighters drop in, VS (skippable)
	------------------------------------------------------------------------------------------
	local function intro()
		local band = Ui.frame({
			Name = "ArenaName",
			BackgroundColor3 = C.Night,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.new(2, 0, 0, 78),
			ZIndex = 40,
			Parent = layer,
		}, {
			Ui.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.35, 0.25),
					NumberSequenceKeypoint.new(0.65, 0.25),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
		local mapName = Ui.display({
			Text = string.upper(arena.displayName),
			TextSize = 52,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 41,
			Parent = band,
		}, true)
		Ui.outline(C.Night, 4).Parent = mapName
		if reduced then
			fadeOut(band, 1.2, 0.3)
			return
		end
		trayHolder.Position = UDim2.new(0.5, 0, 1, 220)
		local skipButton: TextButton = Ui.new("TextButton", {
			Name = "SkipIntro",
			Text = "",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(-0.5, -0.5),
			Size = UDim2.fromScale(2, 2),
			ZIndex = 45,
			Parent = layer,
		})
		local stageSkip = stage:intro()
		local vs: ImageLabel? = nil
		local over = false
		local function finish()
			if over then
				return
			end
			over = true
			stageSkip()
			skipButton:Destroy()
			if band.Parent then
				fadeOut(band, 0, 0.25)
			end
			if vs and vs.Parent then
				fadeOut(vs, 0, 0.25)
			end
			TweenService:Create(
				trayHolder,
				TweenInfo.new(0.35, Enum.EasingStyle.Back),
				{ Position = UDim2.fromScale(0.5, 1) }
			):Play()
		end
		skipButton.Activated:Connect(finish)
		band.Position = UDim2.fromScale(-1.2, 0.36)
		TweenService
			:Create(
				band,
				TweenInfo.new(0.45, Enum.EasingStyle.Quint),
				{ Position = UDim2.fromScale(0.5, 0.36) }
			)
			:Play()
		task.delay(1.25, function()
			if over then
				return
			end
			local badge = Ui.image("vs_badge", {
				Name = "VS",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.56),
				Size = UDim2.fromOffset(150, 150),
				ZIndex = 42,
				Parent = layer,
			})
			vs = badge
			popScale(badge, 2.6, false, 0.3)
			Ui.sound("hit_special")
		end)
		task.delay(2.5, finish)
	end

	renderAll()
	if view.phase == "Picking" then
		mystery.Visible = true
	end
	intro()

	local chooserPending = false
	handle = {
		round = function(msg)
			local data = msg.data
			if data.view then
				view = data.view
			end
			if msg.kind == "RoundOpen" then
				picked = false
				chosen = nil
				chooserPending = false
				clearStamp()
				chooser.Visible = false
				if waitWord then
					waitWord:Destroy()
					waitWord = nil
				end
				mystery.Visible = true
				local r = math.min(view.round, Rules.maxRounds)
				if r > 1 then
					bigWord(`ROUND {r}`, MEDAL_Y + 215, 44, C.White, C.Violet, 0.9)
					popScale(plate, 1.4, reduced, 0.25)
				end
			elseif msg.kind == "Round" then
				local special: { [number]: boolean } = {}
				for _, e in data.events do
					if e[1] == "Round" then
						special[1] = e[3] == "Special"
						special[2] = e[4] == "Special"
					end
				end
				if data.timedOut and data.timedOut[you] then
					ctx.warn("Time's up: your pick became Attack.")
				end
				animating += 1
				stage:play(data.events, special, function(e)
					local kind = e[1]
					if kind == "Round" then
						mystery.Visible = false
						clearStamp()
						revealIcon(you, e[2 + you])
						revealIcon(them, e[2 + them])
						firstMark(e[5])
						setEnergy(1, e[6], true)
						setEnergy(2, e[7], true)
					elseif kind == "Hit" then
						local target = 3 - e[2]
						setHp(target, e[5], ui[target].maxHp, true)
					elseif kind == "Heal" then
						setHp(e[2], e[3], ui[e[2]].maxHp, true)
					elseif kind == "Burn" or kind == "Recoil" then
						setHp(e[2], e[4], ui[e[2]].maxHp, true)
					elseif kind == "Reflect" then
						setHp(3 - e[2], e[4], ui[3 - e[2]].maxHp, true)
					elseif kind == "KO" then
						setHp(e[2], 0, ui[e[2]].maxHp, true)
						bigWord("K.O.!", 230, 110, C.White, C.Red, 1.1)
					end
				end, function()
					animating -= 1
					if not closed then
						renderAll()
						if chooserPending and animating == 0 then
							chooserPending = false
							showChooser()
						end
					end
				end)
			elseif msg.kind == "ChooseNext" then
				mystery.Visible = false
				-- after the knock-out has played
				if animating > 0 then
					chooserPending = true
				else
					showChooser()
				end
			elseif msg.kind == "Entered" then
				if waitWord then
					waitWord:Destroy()
					waitWord = nil
				end
			end
			renderAll()
		end,
		finish = function(data)
			if ctx.ui then
				ctx.ui("battleEnd")
			end
			closed = true
			running = false
			view = data.view or view
			chooser.Visible = false
			mystery.Visible = false
			clearStamp()
			if waitWord then
				waitWord:Destroy()
				waitWord = nil
			end
			timerLabel.Text = ""
			for _, seg in segs do
				seg.Visible = false
			end
			trayHolder.Visible = false
			forfeit.Visible = false
			-- let the last round's hits land before the result covers the arena
			task.spawn(function()
				local waited = 0
				while animating > 0 and waited < 6 do
					waited += task.wait(0.1)
				end
				renderAll()
				BattleResult.show(layer, start, data, view, reduced, function()
					handle.destroy()
				end)
			end)
		end,
		destroy = function()
			running = false
			stage:destroy()
			screen.destroy()
			ctx.state:setBattle(nil)
		end,
	}
	ctx.state:setBattle({ matchId = start.matchId, arena = arena.id })
	return handle
end

return Battle
