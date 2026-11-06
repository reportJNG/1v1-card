--!strict
-- The battle screen. Shows both active cards (HP, shield, status), both benches, both energy
-- bars, the round timer and the act-first chance; sends picks (Attack / Defend / Special) and
-- KO replacements. It only animates the result packets the server sends: nothing about the
-- outcome is computed here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rules = require(Shared.Config.Battle)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)

local C = Theme.Color

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

function Battle.open(ctx: any, start: any): Handle
	local you: number = start.you
	local them = 3 - you
	local view = start.view
	local picked = false
	local closed = false
	local log: { string } = {}

	local handle: Handle
	local layer: Frame = nil :: any
	local screen = ctx.overlay(function(l)
		layer = l
		l.Name = "Battle"
		Ui.frame({
			BackgroundColor3 = C.Background,
			Size = UDim2.fromScale(4, 4),
			Position = UDim2.fromScale(-1.5, -1.5),
			Parent = l,
		}, { Ui.gradient(C.Panel, C.Background, 90) })
		return { destroy = function() end }
	end)

	local header = Ui.text({
		Text = "",
		FontFace = Theme.Face.Title,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 26),
		Parent = layer,
	})
	local timer = Ui.text({
		Text = "",
		FontFace = Theme.Face.Title,
		TextSize = 34,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 40),
		Name = "Timer",
		Parent = layer,
	})
	local first = Ui.text({
		Text = "",
		FontFace = Theme.Face.Bold,
		TextColor3 = C.Blue,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 20),
		Parent = layer,
	})
	local names = { start.seats[you].name, start.seats[them].name }
	local sideFrames: { Frame } = {}
	for i, side in { you, them } do
		sideFrames[side] = Ui.frame({
			BackgroundColor3 = C.Panel,
			Position = UDim2.fromOffset(if i == 1 then 40 else 600, 100),
			Size = UDim2.fromOffset(320, 300),
			Name = if i == 1 then "You" else "Opponent",
			Parent = layer,
		}, { Ui.corner(14), Ui.stroke(if i == 1 then C.Blue else C.Red, 2, 0.3), Ui.pad(10) })
	end
	local logBox = Ui.text({
		Text = "",
		TextSize = Theme.Size.small,
		TextColor3 = C.Muted,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(370, 110),
		Size = UDim2.fromOffset(220, 280),
		Parent = layer,
	})
	local actionRow = Ui.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(620, 64),
		Parent = layer,
	}, { Ui.list(true, 14, Enum.HorizontalAlignment.Center) })
	local status = Ui.text({
		Text = "",
		FontFace = Theme.Face.Bold,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -92),
		Size = UDim2.fromOffset(600, 22),
		Parent = layer,
	})
	local chooser = Ui.frame({
		BackgroundColor3 = C.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 260),
		Visible = false,
		ZIndex = 10,
		Parent = layer,
	}, { Ui.corner(14), Ui.stroke(C.Gold, 2), Ui.pad(12) })

	local forfeit = Ui.button("Forfeit", "ghost", function()
		ctx.confirm("Forfeit?", "Forfeiting counts as a loss.", "Forfeit", function()
			ctx.request("Battle.Forfeit")
		end)
	end, { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(90, 30), TextSize = 13 })
	forfeit.instance.Parent = layer

	local buttons: { [string]: any } = {}
	local figures: { [number]: ViewportFrame? } = {}

	local function renderSide(side: number)
		local f = sideFrames[side]
		Ui.clear(f)
		local s = view.sides[side]
		local u = s.units[s.active]
		local def = Characters.ById[u.characterId]
		Ui.text({
			Text = `{if side == you then "You" else "Opponent"}: {names[if side == you then 1 else 2]}`,
			FontFace = Theme.Face.Bold,
			TextColor3 = if side == you then C.Blue else C.Red,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = f,
		})
		local portrait = Visuals.portrait(f, u.characterId, false, Vector2.new(110, 140), true)
		portrait.Position = UDim2.fromOffset(0, 24)
		figures[side] = portrait:FindFirstChild("Figure") :: ViewportFrame?
		local info = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(120, 24),
			Size = UDim2.new(1, -120, 0, 140),
			Parent = f,
		}, { Ui.list(false, 4) })
		Ui.text({
			Text = def.displayName,
			FontFace = Theme.Face.Title,
			TextSize = 16,
			LayoutOrder = 1,
			Parent = info,
		})
		Ui.text({
			Text = `HP {u.hp}/{u.maxHp}{if u.shield > 0 then ` · 🛡 {u.shield}` else ""}`,
			FontFace = Theme.Face.Bold,
			LayoutOrder = 2,
			Parent = info,
		})
		local setHp = Ui.bar(
			info,
			if u.hp / u.maxHp > 0.35 then C.Green else C.Red,
			{ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 12) }
		)
		setHp(u.hp / u.maxHp)
		local statuses = {}
		for name, left in u.status do
			table.insert(statuses, `{name} {left}`)
		end
		Ui.text({
			Text = if #statuses > 0 then table.concat(statuses, " · ") else " ",
			TextSize = Theme.Size.small,
			TextColor3 = C.Purple,
			LayoutOrder = 4,
			Parent = info,
		})
		Ui.text({
			Text = `Special: {def.special.displayName} ({u.specialCost})`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			LayoutOrder = 5,
			Parent = info,
		})
		-- Energy pips: both players see both bars, so a ready Special is a visible threat.
		local pips = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 172),
			Size = UDim2.new(1, 0, 0, 18),
			Name = "Energy",
			Parent = f,
		}, { Ui.list(true, 4) })
		for i = 1, Rules.energyMax do
			Ui.frame({
				BackgroundColor3 = if i <= s.energy then C.Gold else C.Background,
				Size = UDim2.fromOffset(32, 14),
				LayoutOrder = i,
				Parent = pips,
			}, { Ui.corner(4), Ui.stroke(C.Stroke, 1) })
		end
		Ui.text({
			Text = `Energy {s.energy}/{Rules.energyMax}{if s.canSpecial then " · Special ready!" else ""}`,
			TextSize = Theme.Size.small,
			TextColor3 = if s.canSpecial then C.Gold else C.Muted,
			Position = UDim2.fromOffset(0, 194),
			Size = UDim2.new(1, 0, 0, 16),
			Parent = f,
		})
		local bench = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 216),
			Size = UDim2.new(1, 0, 0, 60),
			Parent = f,
		}, { Ui.list(true, 6) })
		for slot, bu in s.units do
			if slot ~= s.active then
				local chip = Ui.frame({
					BackgroundColor3 = if bu.hp > 0 then C.Raised else C.Background,
					Size = UDim2.fromOffset(140, 56),
					LayoutOrder = slot,
					Parent = bench,
				}, { Ui.corner(8), Ui.pad(6) })
				Ui.text({
					Text = `{nameOf(bu.characterId)}\n{if bu.hp > 0 then `HP {bu.hp}/{bu.maxHp}` else "KO"}`,
					TextSize = Theme.Size.small,
					TextColor3 = if bu.hp > 0 then C.Text else C.Muted,
					Size = UDim2.fromScale(1, 1),
					Parent = chip,
				})
			end
		end
	end

	local function setButtons()
		local mine = view.sides[you]
		local unit = mine.units[mine.active]
		local open = view.phase == "Picking" and not picked and not closed
		buttons.Attack.setEnabled(open)
		buttons.Defend.setEnabled(open)
		buttons.Special.setEnabled(open and mine.canSpecial)
		buttons.Special.setText(`Special ({unit.specialCost}⚡)`)
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
		local b = Ui.button(
			action,
			if action == "Attack" then "danger" elseif action == "Defend" then "secondary" else "primary",
			function()
				pick(action)
			end,
			{ Size = UDim2.fromOffset(190, 56), LayoutOrder = i, Name = action, TextSize = 20 }
		)
		b.instance.Parent = actionRow
		buttons[action] = b
	end

	local function renderAll()
		header.Text = `{if start.mode == "Trial" then "Guardian Trial" else "Ranked"} · Round {math.min(
			view.round,
			Rules.maxRounds
		)}`
		renderSide(you)
		renderSide(them)
		first.Text = `You act first: {Format.percent(view.sides[you].firstChance)} (Defend always goes first)`
		logBox.Text = table.concat(log, "\n")
		setButtons()
	end

	local function showChooser()
		Ui.clear(chooser)
		local mine = view.sides[you]
		if not mine.needsNext then
			chooser.Visible = false
			status.Text = "Your opponent is choosing their next card..."
			return
		end
		chooser.Visible = true
		Ui.text({
			Text = "Your card was knocked out. Choose who comes in next:",
			FontFace = Theme.Face.Bold,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = chooser,
		})
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 48),
			Size = UDim2.new(1, 0, 0, 160),
			Parent = chooser,
		}, { Ui.list(true, 12, Enum.HorizontalAlignment.Center) })
		for slot, u in mine.units do
			if u.hp > 0 and slot ~= mine.active then
				local b = Ui.button(`{nameOf(u.characterId)}\nHP {u.hp}/{u.maxHp}`, "secondary", function()
					chooser.Visible = false
					ctx.request("Battle.ChooseNext", { slot = slot })
				end, { Size = UDim2.fromOffset(190, 70), LayoutOrder = slot, TextSize = 14 })
				b.instance.Parent = row
			end
		end
	end

	local running = true
	task.spawn(function()
		while running do
			local left = view.deadline - ctx.now()
			if view.phase == "Picking" or view.phase == "Choosing" then
				timer.Text = Format.seconds(left)
				timer.TextColor3 = if left <= 4 then C.Red else C.Gold
			else
				timer.Text = ""
			end
			task.wait(0.2)
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
			if msg.kind == "RoundOpen" then
				picked = false
				chooser.Visible = false
				status.Text = "Pick your action."
			elseif msg.kind == "Round" or msg.kind == "Entered" then
				for _, e in data.events do
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
			renderAll()
			if msg.kind == "Round" and not ctx.reducedMotion() then
				local n = 0
				for _, e in data.events do
					if e[1] == "Hit" then
						local fig = figures[e[2]]
						if fig then
							task.delay(n * 0.3, Visuals.lunge, fig, if e[2] == you then 1 else -1)
						end
						n += 1
					end
				end
			end
		end,
		finish = function(data)
			closed = true
			running = false
			view = data.view or view
			renderAll()
			chooser.Visible = false
			-- The match is over: show the rounds actually played and stop the clock and prompts.
			header.Text =
				`{if start.mode == "Trial" then "Guardian Trial" else "Ranked"} · {data.result.rounds} rounds`
			timer.Text = ""
			status.Text = ""
			local won = data.result.winner == you
			local reward: any = data.reward or {}
			resultBox = Ui.frame({
				BackgroundColor3 = C.Panel,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(460, 300),
				ZIndex = 20,
				Name = "Result",
				Parent = layer,
			}, { Ui.corner(16), Ui.stroke(if won then C.Gold else C.Red, 3), Ui.pad(16) })
			local content = Ui.frame(
				{ BackgroundTransparency = 1, Parent = resultBox },
				{ Ui.list(false, 8, Enum.HorizontalAlignment.Center) }
			)
			Ui.text({
				Text = if won then "Victory!" else "Defeat",
				FontFace = Theme.Face.Title,
				TextSize = 40,
				TextColor3 = if won then C.Gold else C.Red,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 48),
				LayoutOrder = 1,
				Parent = content,
			})
			local reasons = {
				KO = "All cards knocked out",
				MaxRounds = "Round limit: most HP left wins",
				Forfeit = "Forfeit",
				Timeouts = "Too many missed picks",
			}
			Ui.text({
				Text = `{reasons[data.result.reason] or data.result.reason} · {data.result.rounds} rounds`,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 2,
				Parent = content,
			})
			local lines = {}
			if start.mode == "Ranked" then
				if (reward.coins or 0) > 0 then
					table.insert(
						lines,
						`💰 +{Format.number(reward.coins)}{if reward.reward == "Reduced"
							then " (daily limit reached: reduced)"
							else ""}`
					)
				end
				if reward.trophyDelta then
					table.insert(
						lines,
						`🏆 {if reward.trophyDelta >= 0 then "+" else ""}{reward.trophyDelta} → {reward.trophies}`
					)
				end
				if reward.leagueAfter and reward.leagueAfter ~= reward.leagueBefore then
					table.insert(lines, `League: {reward.leagueBefore} → {reward.leagueAfter}`)
				end
				local voids = {
					RepeatOpponent = "No reward: you've played this opponent too often today.",
					EarlyForfeit = "No reward: the match ended by forfeit before round 3.",
					Timeouts = "No reward: too many missed picks.",
				}
				if reward.voidReason then
					table.insert(lines, voids[reward.voidReason] or reward.voidReason)
				end
			elseif reward.firstClear then
				table.insert(
					lines,
					`First clear! 🏆 +{reward.trophies} · 💰 +{Format.number(reward.coins)} · 💎 +{reward.gems}`
				)
				if reward.goldenEgg then
					table.insert(lines, "A Golden egg was added to your Egg Bag.")
				end
			elseif won then
				table.insert(lines, "Guardian defeated again (first-clear rewards are paid once).")
			end
			Ui.text({
				Text = table.concat(lines, "\n"),
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.new(1, 0, 0, 100),
				LayoutOrder = 3,
				Parent = content,
			})
			local done = Ui.button("Continue", "primary", function()
				handle.destroy()
			end, { Size = UDim2.fromOffset(220, 44), LayoutOrder = 4, Name = "Continue" })
			done.instance.Parent = content
			local scale =
				Ui.new("UIScale", { Scale = if ctx.reducedMotion() then 1 else 0.6, Parent = resultBox })
			if not ctx.reducedMotion() then
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end,
		destroy = function()
			running = false
			screen.destroy()
			ctx.state:setBattle(nil)
		end,
	}
	ctx.state:setBattle({ matchId = start.matchId })
	return handle
end

return Battle
