--!strict
-- The battle screen over the 3D stage (App/BattleStage). Top plates show both active cards
-- (HP, shield, status, energy pips, bench); the centre shows the 12 s timer ring, the round and
-- the act-first chance; the bottom has the Attack / Defend / Special buttons. It sends picks and
-- KO replacements and only animates the result packets the server sends: nothing about the
-- outcome is computed here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local Rules = require(Shared.Config.Battle)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local BattleStage = require(App.BattleStage)

local C = Theme.Color
local F = Theme.Face

local Battle = {}

export type Handle = {
	round: (msg: { kind: string, you: number, data: any }) -> (),
	finish: (data: any) -> (),
	destroy: () -> (),
}

local function nameOf(characterId: string): string
	local def = Characters.ById[characterId]
	return if def then def.displayName else characterId
end

-- One line per event, from the side of the player watching.
function Battle.describe(e: { any }, you: number, view: any): string?
	local kind = e[1]
	local function who(side: number): string
		return if side == you then "You" else "Opponent"
	end
	local function unitName(side: number): string
		local s = view.sides[side]
		return nameOf(s.units[s.active].characterId)
	end
	if kind == "Round" then
		local mine, theirs = e[2 + you], e[2 + (3 - you)]
		return `Round {e[2]}: you {string.lower(mine)}, they {string.lower(theirs)}. {who(e[5])} acted first.`
	elseif kind == "Hit" then
		return `{unitName(e[2])} hits for {e[3]}{if e[4] == 1 then " (critical!)" else ""}.`
	elseif kind == "Parry" then
		return `{who(e[2])} parried the Special!`
	elseif kind == "Heal" then
		return `{unitName(e[2])} heals to {e[3]} HP.`
	elseif kind == "Shield" then
		return `{unitName(e[2])} raises a {e[3]} shield.`
	elseif kind == "Absorb" then
		return `Shield absorbs {e[3]}.`
	elseif kind == "Burn" then
		return `{unitName(e[2])} burns for {e[3]}.`
	elseif kind == "Recoil" then
		return `{unitName(e[2])} takes {e[3]} recoil.`
	elseif kind == "Reflect" then
		return `{who(e[2])} reflected {e[3]} damage.`
	elseif kind == "Stance" then
		return `{unitName(e[2])} takes a guard stance.`
	elseif kind == "KO" then
		return `{if e[2] == you then "Your" else "Their"} card is knocked out!`
	elseif kind == "Enter" then
		local s = view.sides[e[2]]
		return `{who(e[2])} send{if e[2] == you then "" else "s"} in {nameOf(s.units[e[3]].characterId)}.`
	end
	return nil
end

local RING_SEGMENTS = 24

-- The segmented 12 s timer ring: segments switch off as time runs down.
local function timerRing(parent: Instance): (Frame, (number, number) -> (), TextLabel)
	local holder = Ui.frame({
		Name = "TimerRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(82, 82),
		Parent = parent,
	})
	Ui.image("timer_ring_bg", { Size = UDim2.fromScale(1, 1), Parent = holder })
	local segs: { Frame } = {}
	for i = 1, RING_SEGMENTS do
		local a = (i - 0.5) / RING_SEGMENTS * math.pi * 2
		local seg = Ui.frame({
			BackgroundColor3 = C.Gold,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(a) * 33, 0.5, -math.cos(a) * 33),
			Size = UDim2.fromOffset(5, 10),
			Rotation = math.deg(a),
			ZIndex = 2,
			Parent = holder,
		}, { Ui.corner(3) })
		segs[i] = seg
	end
	local label = Ui.text({
		Name = "Timer",
		Text = "",
		FontFace = F.Display,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = holder,
	})
	Ui.outline(C.Night, 2).Parent = label
	return holder,
		function(left: number, total: number)
			local lit = math.clamp(math.ceil(left / total * RING_SEGMENTS), 0, RING_SEGMENTS)
			local color = if left <= 4 then C.Red else C.Gold
			for i, seg in segs do
				seg.Visible = i <= lit
				seg.BackgroundColor3 = color
			end
			label.TextColor3 = if left <= 4 then C.Red else C.White
		end,
		label
end

function Battle.open(ctx: any, start: any): Handle
	local you: number = start.you
	local them = 3 - you
	local view = start.view
	local picked = false
	local closed = false
	local log: { string } = {}
	local reduced = ctx.reducedMotion()

	local stage = BattleStage.new(you, {
		[1] = view.sides[1].units[view.sides[1].active].characterId,
		[2] = view.sides[2].units[view.sides[2].active].characterId,
	}, reduced)
	local onStage: { [number]: string } = {
		[1] = view.sides[1].units[view.sides[1].active].characterId,
		[2] = view.sides[2].units[view.sides[2].active].characterId,
	}

	local handle: Handle
	local layer: Frame = nil :: any
	local screen = ctx.overlay(function(l)
		layer = l
		l.Name = "Battle"
		-- A light vignette at the top and bottom so the UI reads over the stage.
		for _, edge in { { 0, 0 }, { 1, 180 } } do
			Ui.frame({
				BackgroundColor3 = C.Night,
				AnchorPoint = Vector2.new(0, edge[1]),
				Position = UDim2.fromScale(-0.5, edge[1]),
				Size = UDim2.new(2, 0, 0, 150),
				Parent = l,
			}, {
				Ui.new("UIGradient", {
					Rotation = 90 + edge[2],
					Transparency = NumberSequence.new(0.25, 1),
				}),
			})
		end
		return { destroy = function() end }
	end)
	Ui.sound("open")

	local _ring, setRing, _timerLabel = timerRing(layer)
	local header = Ui.text({
		Name = "Round",
		Text = "",
		FontFace = F.Title,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(260, 20),
		Parent = layer,
	})
	Ui.outline(C.Night, 1.5).Parent = header
	local firstChip = Ui.frame({
		Name = "FirstChance",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 114),
		Size = UDim2.fromOffset(230, 26),
		Parent = layer,
	})
	Ui.skin(firstChip, "toast", 0.36)
	local first = Ui.text({
		Text = "",
		FontFace = F.Bold,
		TextSize = 13,
		TextColor3 = C.Blue,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = firstChip,
	})

	local names = { [you] = start.seats[you].name, [them] = start.seats[them].name }
	local trophies = { [you] = start.seats[you].trophies, [them] = start.seats[them].trophies }
	local plates: { [number]: Frame } = {}
	for _, side in { you, them } do
		local mine = side == you
		local plate = Ui.frame({
			Name = if mine then "You" else "Opponent",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(if mine then 0 else 1, 0),
			Position = if mine then UDim2.fromOffset(14, 10) else UDim2.new(1, -14, 0, 10),
			Size = UDim2.fromOffset(330, 126),
			Parent = layer,
		})
		Ui.skin(plate, "panel", 0.55)
		plates[side] = plate
	end

	local feed = Ui.text({
		Name = "Feed",
		Text = "",
		FontFace = F.Bold,
		TextSize = 13,
		TextColor3 = C.Text,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(300, 90),
		Parent = layer,
	})
	Ui.outline(C.Night, 1.5, 0.2).Parent = feed

	local status = Ui.text({
		Name = "Status",
		Text = "",
		FontFace = F.Title,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -148),
		Size = UDim2.fromOffset(600, 22),
		Parent = layer,
	})
	Ui.outline(C.Night, 1.5).Parent = status

	local actionRow = Ui.frame({
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(420, 132),
		Parent = layer,
	}, { Ui.list(true, 22, Enum.HorizontalAlignment.Center) })

	local chooser = Ui.frame({
		Name = "Chooser",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(470, 300),
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

	local forfeit = Ui.button("Forfeit", "danger", function()
		ctx.confirm("Forfeit?", "Forfeiting counts as a loss.", "Forfeit", function()
			ctx.request("Battle.Forfeit")
		end)
	end, {
		Name = "Forfeit",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(110, 34),
	})
	forfeit.instance.Parent = layer

	-- Action buttons: round art from UiAssets with the label and the Special cost underneath.
	type Action = { button: ImageButton, label: TextLabel, enabled: boolean }
	local actions: { [string]: Action } = {}
	local function setAction(name: string, on: boolean, text: string?)
		local a = actions[name]
		a.enabled = on
		a.button.ImageTransparency = if on then 0 else 0.55
		a.button.ImageColor3 = if on then C.White else Color3.fromRGB(140, 140, 160)
		a.label.TextColor3 = if on then C.White else C.Muted
		if text then
			a.label.Text = text
		end
	end

	local function renderPlate(side: number)
		local plate = plates[side]
		Ui.clear(plate)
		local mine = side == you
		local s = view.sides[side]
		local u = s.units[s.active]
		local def = Characters.ById[u.characterId]
		local card = Visuals.portrait(plate, u.characterId, false, Vector2.new(70, 98), false, u.level)
		card.Position = if mine then UDim2.fromOffset(12, 14) else UDim2.new(1, -82, 0, 14)
		card.ZIndex = 2
		local x = if mine then 92 else 12
		local nameLabel = Ui.text({
			Text = def.displayName,
			FontFace = F.Title,
			TextSize = 17,
			TextWrapped = false,
			TextXAlignment = if mine then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(x, 10),
			Size = UDim2.fromOffset(226, 20),
			ZIndex = 2,
			Parent = plate,
		})
		Ui.outline(C.Night, 1.5).Parent = nameLabel
		Ui.fit(nameLabel, 17, 10)
		Ui.text({
			Text = `{names[side]}{if trophies[side]
				then ` · {Format.number(trophies[side])} trophies`
				else ""} · {Rarities.Defs[def.rarity].displayName} {def.family}`,
			TextSize = 11,
			TextColor3 = if mine then C.Blue else C.Red,
			TextWrapped = false,
			TextXAlignment = if mine then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(x, 30),
			Size = UDim2.fromOffset(226, 14),
			ZIndex = 2,
			Parent = plate,
		})
		local frac = u.hp / u.maxHp
		local setHp = Ui.bar(plate, if frac > 0.5 then C.Green elseif frac > 0.25 then C.Gold else C.Red, {
			Name = "Hp",
			Position = UDim2.fromOffset(x, 48),
			Size = UDim2.fromOffset(226, 16),
			ZIndex = 2,
		})
		setHp(frac)
		local hpText = Ui.text({
			Text = `{u.hp} / {u.maxHp}{if u.shield > 0 then `  +{u.shield} shield` else ""}`,
			FontFace = F.Number,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(x, 48),
			Size = UDim2.fromOffset(226, 16),
			ZIndex = 4,
			Parent = plate,
		})
		Ui.outline(C.Night, 1.5).Parent = hpText
		-- Energy pips: both players see both bars, so a ready Special is a visible threat.
		local pips = Ui.frame({
			Name = "Energy",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 68),
			Size = UDim2.fromOffset(226, 20),
			ZIndex = 2,
			Parent = plate,
		}, {
			Ui.list(true, 2, if mine then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right),
		})
		for i = 1, Rules.energyMax do
			Ui.image(if i <= s.energy then "energy_pip_on" else "energy_pip_off", {
				Size = UDim2.fromOffset(20, 20),
				LayoutOrder = if mine then i else -i,
				ZIndex = 2,
				Parent = pips,
			})
		end
		local statuses = {}
		for name, left in u.status do
			table.insert(statuses, `{name} {left}`)
		end
		Ui.text({
			Text = if s.canSpecial
				then `SPECIAL READY{if #statuses > 0 then "  ·  " .. table.concat(statuses, " · ") else ""}`
				else (if #statuses > 0
					then table.concat(statuses, " · ")
					else `Special: {def.special.displayName}`),
			FontFace = F.Bold,
			TextSize = 11,
			TextColor3 = if s.canSpecial then C.Gold elseif #statuses > 0 then C.Purple else C.Muted,
			TextWrapped = false,
			TextXAlignment = if mine then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(x, 90),
			Size = UDim2.fromOffset(226, 14),
			ZIndex = 2,
			Parent = plate,
		})
		-- Bench: the other two cards, dimmed when knocked out.
		local bench = Ui.frame({
			Name = "Bench",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 104),
			Size = UDim2.fromOffset(226, 16),
			ZIndex = 2,
			Parent = plate,
		}, {
			Ui.list(true, 8, if mine then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right),
		})
		for slot, bu in s.units do
			if slot ~= s.active then
				Ui.text({
					Text = `{nameOf(bu.characterId)} {if bu.hp > 0
						then `{math.floor(bu.hp / bu.maxHp * 100)}%`
						else "KO"}`,
					TextSize = 10,
					TextColor3 = if bu.hp > 0 then C.Text else C.Muted,
					TextWrapped = false,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 16),
					LayoutOrder = slot,
					ZIndex = 2,
					Parent = bench,
				})
			end
		end
	end

	local function setButtons()
		local mine = view.sides[you]
		local unit = mine.units[mine.active]
		local open = view.phase == "Picking" and not picked and not closed
		setAction("Attack", open)
		setAction("Defend", open)
		setAction("Special", open and mine.canSpecial, `SPECIAL · {unit.specialCost} energy`)
	end

	local function pick(action: string)
		if picked then
			return
		end
		picked = true
		setButtons()
		status.Text = "Waiting for your opponent..."
		local reply = ctx.request("Battle.Pick", { round = view.round, action = action }, true)
		if not reply.ok then
			picked = false
			status.Text = Format.error(reply.err)
			setButtons()
		end
	end
	for i, action in { "Attack", "Defend", "Special" } do
		local slot = Ui.frame({
			Name = `{action}Slot`,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(112, 132),
			LayoutOrder = i,
			Parent = actionRow,
		})
		local b: ImageButton = Ui.new("ImageButton", {
			Name = action,
			Image = Ui.asset(`action_{string.lower(action)}`),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(104, 104),
			Parent = slot,
		})
		local label = Ui.text({
			Text = string.upper(action),
			FontFace = F.Title,
			TextSize = 15,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, 106),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = slot,
		})
		Ui.outline(C.Night, 1.5).Parent = label
		Ui.juice(b)
		actions[action] = { button = b, label = label, enabled = true }
		b.Activated:Connect(function()
			if actions[action].enabled then
				Ui.sound("click")
				pick(action)
			else
				Ui.sound("error")
			end
		end)
	end

	local function renderAll()
		header.Text = `{if start.mode == "Trial" then "GUARDIAN TRIAL" else "RANKED"} · ROUND {math.min(
			view.round,
			Rules.maxRounds
		)}`
		renderPlate(you)
		renderPlate(them)
		first.Text = `You act first: {Format.percent(view.sides[you].firstChance)}`
		local lines = {}
		for i = math.max(1, #log - 3), #log do
			table.insert(lines, log[i])
		end
		feed.Text = table.concat(lines, "\n")
		setButtons()
		-- Keep the stage in step with who is actually on each mark.
		for side = 1, 2 do
			local s = view.sides[side]
			local id = s.units[s.active].characterId
			if onStage[side] ~= id and s.units[s.active].hp > 0 then
				onStage[side] = id
				stage:enter(side, id)
			end
		end
	end

	local function showChooser()
		Ui.clear(chooserBody)
		local mine = view.sides[you]
		if not mine.needsNext then
			chooser.Visible = false
			status.Text = "Your opponent is choosing their next card..."
			return
		end
		chooser.Visible = true
		Ui.popIn(chooser, reduced)
		Ui.text({
			Text = "Knocked out! Choose who comes in next:",
			FontFace = F.Title,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 30),
			ZIndex = 11,
			Parent = chooserBody,
		})
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 1, -40),
			ZIndex = 11,
			Parent = chooserBody,
		}, { Ui.list(true, 16, Enum.HorizontalAlignment.Center) })
		for slot, u in mine.units do
			if u.hp > 0 and slot ~= mine.active then
				local b: TextButton = Ui.new("TextButton", {
					Name = `Next{slot}`,
					Text = "",
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(140, 220),
					LayoutOrder = slot,
					ZIndex = 11,
					Parent = row,
				})
				local card = Visuals.portrait(b, u.characterId, false, Vector2.new(140, 196), true, u.level)
				card.ZIndex = 12
				Ui.text({
					Text = `HP {u.hp}/{u.maxHp}`,
					FontFace = F.Bold,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(0, 198),
					Size = UDim2.new(1, 0, 0, 20),
					ZIndex = 12,
					Parent = b,
				})
				Ui.juice(b)
				b.Activated:Connect(function()
					Ui.sound("click")
					chooser.Visible = false
					ctx.request("Battle.ChooseNext", { slot = slot })
				end)
			end
		end
	end

	local running = true
	local lastSecond = -1
	task.spawn(function()
		while running do
			local left = math.max(0, view.deadline - ctx.now())
			if view.phase == "Picking" or view.phase == "Choosing" then
				local total = if view.phase == "Picking" then Rules.pickSeconds else Rules.nextSeconds
				setRing(left, total)
				_timerLabel.Text = tostring(math.ceil(left))
				local sec = math.ceil(left)
				if sec ~= lastSecond and sec <= 4 and sec > 0 then
					Ui.sound("tick")
				end
				lastSecond = sec
			else
				setRing(0, 1)
				_timerLabel.Text = ""
			end
			task.wait(0.1)
		end
	end)

	renderAll()

	local resultBox: any = nil
	handle = {
		round = function(msg)
			local data = msg.data
			if data.view then
				view = data.view
			end
			local special: { [number]: boolean } = {}
			if msg.kind == "RoundOpen" then
				picked = false
				chooser.Visible = false
				status.Text = "Pick your action!"
			elseif msg.kind == "Round" or msg.kind == "Entered" then
				for _, e in data.events do
					if e[1] == "Round" then
						special[1] = e[3] == "Special"
						special[2] = e[4] == "Special"
					end
					local line = Battle.describe(e, you, view)
					if line then
						table.insert(log, line)
					end
				end
				while #log > 12 do
					table.remove(log, 1)
				end
				if msg.kind == "Round" and data.timedOut and data.timedOut[you] then
					table.insert(log, "You ran out of time: your pick became Attack.")
				end
			elseif msg.kind == "ChooseNext" then
				showChooser()
			end
			if msg.kind == "Round" then
				stage:play(data.events, special)
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
			renderAll()
			chooser.Visible = false
			header.Text =
				`{if start.mode == "Trial" then "GUARDIAN TRIAL" else "RANKED"} · {data.result.rounds} ROUNDS`
			_timerLabel.Text = ""
			setRing(0, 1)
			status.Text = ""
			actionRow.Visible = false
			forfeit.instance.Visible = false
			local won = data.result.winner == you
			local reward: any = data.reward or {}
			Ui.sound(if won then "victory" else "defeat")

			resultBox = Ui.frame({
				Name = "Result",
				BackgroundColor3 = C.Night,
				BackgroundTransparency = 0.35,
				Position = UDim2.fromScale(-0.5, -0.5),
				Size = UDim2.fromScale(2, 2),
				ZIndex = 20,
				Parent = layer,
			})
			local centre = Ui.frame({
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(640, 490),
				ZIndex = 21,
				Parent = resultBox,
			})
			if won then
				local rays = Ui.image("light_rays", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(320, 94),
					Size = UDim2.fromOffset(520, 520),
					ImageColor3 = C.Gold,
					ImageTransparency = 0.5,
					ZIndex = 21,
					Parent = centre,
				})
				if not reduced then
					TweenService:Create(
						rays,
						TweenInfo.new(16, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
						{ Rotation = 360 }
					):Play()
				end
			end
			local banner = Ui.image(if won then "banner_victory" else "banner_defeat", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(320, 0),
				Size = UDim2.fromOffset(500, 188),
				ZIndex = 22,
				Parent = centre,
			})
			Ui.display({
				Text = if won then "Victory!" else "Defeat",
				TextSize = 54,
				TextColor3 = if won then C.White else Color3.fromHex("#C9D2E8"),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.6),
				Size = UDim2.fromOffset(440, 70),
				ZIndex = 23,
				Parent = banner,
			}, won)
			Ui.popIn(banner, reduced)
			local reasons = {
				KO = "All cards knocked out",
				MaxRounds = "Round limit: most HP left wins",
				Forfeit = "Forfeit",
				Timeouts = "Too many missed picks",
			}
			local sub = Ui.text({
				Text = if won
					then `You won the match! {reasons[data.result.reason] or data.result.reason} · {data.result.rounds} rounds`
					else `{reasons[data.result.reason] or data.result.reason} · {data.result.rounds} rounds`,
				FontFace = F.Title,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 182),
				Size = UDim2.new(1, 0, 0, 26),
				ZIndex = 22,
				Parent = centre,
			})
			Ui.outline(C.Night, 1.5).Parent = sub

			-- Your team, on their cards (knocked-out cards are dimmed).
			local team = Ui.frame({
				Name = "Team",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 214),
				Size = UDim2.new(1, 0, 0, 126),
				ZIndex = 22,
				Parent = centre,
			}, { Ui.list(true, 12, Enum.HorizontalAlignment.Center) })
			for slot, u in view.sides[you].units do
				local cell = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(90, 126),
					LayoutOrder = slot,
					ZIndex = 22,
					Parent = team,
				})
				Visuals.portrait(cell, u.characterId, false, Vector2.new(90, 126), true, u.level)
				if u.hp <= 0 then
					Ui.frame({
						BackgroundColor3 = C.Night,
						BackgroundTransparency = 0.45,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 30,
						Parent = cell,
					}, { Ui.corner(8) })
					Ui.display({
						Text = "KO",
						TextSize = 30,
						TextColor3 = C.Red,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 31,
						Parent = cell,
					})
				end
			end

			-- Reward chips (count up), then any notes.
			local chips = Ui.frame({
				Name = "Rewards",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, 348),
				Size = UDim2.new(1, 0, 0, 44),
				ZIndex = 22,
				Parent = centre,
			}, { Ui.list(true, 14, Enum.HorizontalAlignment.Center) })
			local function chip(icon: string, from: number, to: number, signed: boolean, order: number)
				local f = Ui.frame({
					BackgroundTransparency = 1,
					Size = UDim2.fromOffset(170, 42),
					LayoutOrder = order,
					ZIndex = 22,
					Parent = chips,
				})
				Ui.skin(f, "reward_chip", 0.58, { ZIndex = 22 })
				Ui.icon(icon, 34, { Position = UDim2.new(0, 6, 0.5, 0), ZIndex = 23, Parent = f })
				local label = Ui.text({
					Text = "",
					FontFace = F.Number,
					TextSize = 22,
					TextColor3 = if to < 0 then C.Red else C.Gold,
					TextWrapped = false,
					TextXAlignment = Enum.TextXAlignment.Center,
					Position = UDim2.fromOffset(40, 0),
					Size = UDim2.new(1, -46, 1, 0),
					ZIndex = 23,
					Parent = f,
				})
				Ui.outline(C.Night, 1.5).Parent = label
				local function fmt(n: number): string
					return (if signed and n >= 0 then "+" else "") .. Format.number(n)
				end
				if reduced then
					label.Text = fmt(to)
				else
					Ui.countUp(label, from, to, fmt)
				end
			end
			local notes = {}
			if start.mode == "Ranked" then
				chip("icon_coin", 0, reward.coins or 0, true, 1)
				if reward.trophyDelta then
					chip("icon_trophy", 0, reward.trophyDelta, true, 2)
				end
				if (reward.coins or 0) > 0 and reward.reward == "Reduced" then
					table.insert(notes, "Daily limit reached: reduced Coins.")
				end
				if reward.trophies then
					table.insert(notes, `Trophies: {Format.number(reward.trophies)}`)
				end
				if reward.leagueAfter and reward.leagueAfter ~= reward.leagueBefore then
					table.insert(notes, `League: {reward.leagueBefore} → {reward.leagueAfter}`)
				end
				local voids = {
					RepeatOpponent = "No reward: you've played this opponent too often today.",
					EarlyForfeit = "No reward: the match ended by forfeit before round 3.",
					Timeouts = "No reward: too many missed picks.",
				}
				if reward.voidReason then
					table.insert(notes, voids[reward.voidReason] or reward.voidReason)
				end
			elseif reward.firstClear then
				chip("icon_trophy", 0, reward.trophies or 0, true, 1)
				chip("icon_coin", 0, reward.coins or 0, true, 2)
				chip("icon_gem", 0, reward.gems or 0, true, 3)
				table.insert(notes, "First clear!")
				if reward.goldenEgg then
					table.insert(notes, "A Golden egg was added to your Egg Bag.")
				end
			elseif won then
				table.insert(notes, "Guardian defeated again (first-clear rewards are paid once).")
			end
			Ui.text({
				Text = table.concat(notes, "  ·  "),
				FontFace = F.Bold,
				TextSize = 14,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 394),
				Size = UDim2.new(1, 0, 0, 32),
				ZIndex = 22,
				Parent = centre,
			})
			local done = Ui.button("Continue", "primary", function()
				handle.destroy()
			end, {
				Name = "Continue",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromOffset(320, 432),
				Size = UDim2.fromOffset(240, 50),
				ZIndex = 22,
			})
			done.instance.Parent = centre
			Ui.popIn(done.instance, reduced)
		end,
		destroy = function()
			running = false
			stage:destroy()
			screen.destroy()
			ctx.state:setBattle(nil)
		end,
	}
	ctx.state:setBattle({ matchId = start.matchId })
	return handle
end

return Battle
