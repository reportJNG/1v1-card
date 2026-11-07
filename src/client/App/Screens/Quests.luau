--!strict
-- Daily quests (3 a day), the achievement track and the 7-day streak.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestsCfg = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)

local C = Theme.Color

local function rewardText(def: any): string
	local parts = {}
	if def.coins then
		table.insert(parts, `{Format.number(def.coins)} Coins`)
	end
	if def.gems then
		table.insert(parts, `{def.gems} Gems`)
	end
	return table.concat(parts, " · ")
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "Quests", ctx.close, UDim2.fromOffset(760, 460), "icon_quests")
	local list =
		Ui.scroll({ Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 1, -96), Parent = p.body })
	Ui.list(false, 6).Parent = list
	local streakRow = Ui.frame(
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 88), Parent = p.body },
		{
			Ui.list(true, 6),
		}
	)

	local function questRow(def: any, entry: any, order: number)
		local row = Ui.frame(
			{ Size = UDim2.new(1, -8, 0, 54), LayoutOrder = order, Parent = list },
			{ Ui.corner(8), Ui.pad(8) }
		)
		local progress = if entry then entry.progress else 0
		Ui.fit(
			Ui.text({
				Text = def.text,
				FontFace = Theme.Face.Bold,
				Size = UDim2.new(0.6, 0, 0, 18),
				Parent = row,
			}),
			Theme.Size.body
		)
		Ui.text({
			Text = `{progress}/{def.target} · {rewardText(def)}`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(0.6, 0, 0, 16),
			Parent = row,
		})
		local setBar =
			Ui.bar(row, C.Green, { Position = UDim2.new(0.6, 0, 0, 14), Size = UDim2.new(0.2, -8, 0, 10) })
		setBar(progress / def.target)
		local claimed = entry and entry.claimed
		local b = Ui.button(if claimed then "Claimed" else "Claim", "success", function()
			local reply = ctx.request("Quests.Claim", { questId = def.id })
			if reply.ok then
				ctx.toast(`Quest complete: {rewardText(def)}`, "good")
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(110, 34),
		})
		b.setEnabled(not claimed and progress >= def.target)
		b.instance.Parent = row
	end

	local function render()
		local view = ctx.state.view
		Ui.clear(list)
		Ui.clear(streakRow)
		local today = ctx.now() // 86400
		local d = view.daily
		local nextDay = if d.lastClaimDay == today - 1
			then d.streakDay % 7 + 1
			elseif d.lastClaimDay == today then d.streakDay
			else 1
		for day = 1, 7 do
			local done = (d.lastClaimDay == today and day <= d.streakDay)
				or (d.lastClaimDay == today - 1 and day <= d.streakDay)
			local f = Ui.frame({
				BackgroundColor3 = if done then C.Green else C.Raised,
				Size = UDim2.fromOffset(78, 84),
				LayoutOrder = day,
				Parent = streakRow,
			}, {
				Ui.corner(8),
				Ui.stroke(if day == nextDay and d.lastClaimDay ~= today then C.Gold else C.Stroke, 2),
			})
			Ui.text({
				Text = `Day {day}\n{if day < 7
					then `{Economy.Streak.coins[day]} Coins`
					else `{Economy.Streak.day7Gems} Gems\n+ Golden egg`}`,
				TextSize = Theme.Size.small,
				FontFace = Theme.Face.Bold,
				TextColor3 = if done then C.Background else C.Text,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = f,
			})
		end
		local claim = Ui.button(
			if d.lastClaimDay == today then "Come back tomorrow" else `Claim day {nextDay}`,
			"primary",
			function()
				local reply = ctx.request("Daily.ClaimStreak")
				if reply.ok then
					ctx.toast(`Day {reply.value.day} reward claimed!`, "good")
				end
			end,
			{ Size = UDim2.fromOffset(200, 44), LayoutOrder = 8, Name = "ClaimStreak" }
		)
		claim.setEnabled(d.lastClaimDay ~= today)
		claim.instance.Parent = streakRow

		local order = 0
		Ui.text({
			Text = "Daily quests",
			FontFace = Theme.Face.Title,
			TextSize = 16,
			LayoutOrder = order,
			Parent = list,
		})
		for _, def in QuestsCfg.Daily do
			local entry = view.quests[def.id]
			if entry and view.questDay == today then
				order += 1
				questRow(def, entry, order)
			end
		end
		order += 1
		Ui.text({
			Text = "Achievements",
			FontFace = Theme.Face.Title,
			TextSize = 16,
			LayoutOrder = order,
			Parent = list,
		})
		for _, def in QuestsCfg.Achievements do
			order += 1
			questRow(def, view.quests[def.id], order)
		end
	end

	render()
	return { destroy = function() end, refresh = render }
end
