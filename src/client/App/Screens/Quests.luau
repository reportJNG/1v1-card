--!strict
-- Quests (BAD_GUI_2_PANELS section 5, the merchant template): the 7-day streak, today's 3 daily
-- quests and the achievement track ("GOALS"), as painted-style cards with icons, big text, thick
-- bars and reward pills. No scrolling: dailies fit one row; goals page 3 at a time. Claiming goes
-- through the server (Quests.Claim, Daily.ClaimStreak); rewards fly to their bars (App/WorldText).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestsCfg = require(Shared.Config.Quests)
local Economy = require(Shared.Config.Economy)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)

local C = Theme.Color
local F = Theme.Face

-- An icon per quest kind (one look per kind of task).
local KIND_ICON: { [string]: string } = {
	WinRanked = "icon_trophy",
	PlayRanked = "icon_play",
	Harvest = "icon_worlds",
	Hatch = "icon_shop",
	SellItems = "icon_coin",
	Merge = "icon_cards",
	TrialWin = "icon_power",
	TrialFirstClear = "icon_power",
}

local PER_PAGE = 3

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

local function bigLabel(b: any, max: number)
	local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = max
	end
	b.label.FontFace = F.Display
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "QUESTS", ctx.close, UDim2.fromOffset(800, 470), "icon_quests")
	local tab = "Daily"
	local page = 1
	local streak = Ui.glowTile("Frame", {
		Name = "Streak",
		Size = UDim2.new(1, 0, 0, 120),
		Parent = p.body,
	}, C.Gold, false)
	local tabs = Ui.frame({
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 130),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = p.body,
	})
	local list = Ui.frame({
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 1, -178),
		Parent = p.body,
	})

	local render: () -> ()

	local function questCard(def: any, entry: any, order: number)
		local progress = math.min(if entry then entry.progress else 0, def.target)
		local claimed = entry ~= nil and entry.claimed
		local ready = not claimed and progress >= def.target
		local accent = if claimed then C.Green elseif ready then C.Gold else C.Purple
		local card = Ui.glowTile("Frame", {
			Name = def.id,
			LayoutOrder = order,
			Size = UDim2.fromOffset(240, 200),
			Parent = list,
		}, accent, ready)
		Ui.icon(KIND_ICON[def.kind] or "icon_quests", 52, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			ZIndex = 2,
			Parent = card,
		})
		local text = Ui.text({
			Name = "Task",
			Text = def.text,
			FontFace = F.Title,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = true,
			Position = UDim2.fromOffset(10, 62),
			Size = UDim2.new(1, -20, 0, 46),
			ZIndex = 2,
			Parent = card,
		})
		outline(text, 2)
		Ui.fit(text, 20, 13)
		local setBar = Ui.bar(card, if claimed then C.Green else C.Gold, {
			Position = UDim2.fromOffset(14, 112),
			Size = UDim2.new(1, -28, 0, 14),
			ZIndex = 2,
		})
		setBar(progress / def.target)
		local count = Ui.display({
			Name = "Count",
			Text = `{Format.short(progress)}/{Format.short(def.target)}`,
			TextSize = 18,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 108),
			Size = UDim2.fromOffset(100, 22),
			ZIndex = 3,
			Parent = card,
		})
		count.TextColor3 = C.White
		outline(count, 2)
		local reward = Ui.pricePill(
			if def.coins then Format.short(def.coins) else tostring(def.gems or 0),
			if def.coins then "icon_coin" else "icon_gem",
			26,
			{ Position = UDim2.new(0.5, 0, 0, 132), ZIndex = 3, Parent = card }
		)
		local amount = reward:FindFirstChild("Amount") :: TextLabel
		amount.FontFace = F.Display
		local b = Ui.button(
			if claimed then "DONE" elseif ready then "CLAIM" else "GO",
			if ready then "primary" elseif claimed then "success" else "tab",
			function()
				if not ready then
					return
				end
				local from = Ui.lastPressed
				local reply = ctx.request("Quests.Claim", { questId = def.id })
				if reply.ok then
					if def.coins then
						ctx.near(
							from,
							{ text = `+{Format.number(def.coins)}`, icon = "icon_coin", tone = "gold" }
						)
						ctx.fly(from, "coins", { icon = "icon_coin", count = 5 })
					end
					if def.gems then
						ctx.near(from, { text = `+{def.gems}`, icon = "icon_gem", tone = "cyan" })
						ctx.fly(from, "gems", { icon = "icon_gem", count = 4 })
					end
				end
			end,
			{
				Name = "Claim",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -24, 0, 34),
				ZIndex = 3,
			}
		)
		bigLabel(b, 22)
		b.setEnabled(ready)
		b.instance.Parent = card
		b.instance.Visible = ready or claimed -- no idle button on an unfinished quest
	end

	local function renderStreak(view: any)
		for _, c in streak:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local today = ctx.now() // 86400
		local d = view.daily
		local nextDay = if d.lastClaimDay == today - 1
			then d.streakDay % 7 + 1
			elseif d.lastClaimDay == today then d.streakDay
			else 1
		local row = Ui.frame({
			Name = "Days",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -200, 1, -20),
			ZIndex = 2,
			Parent = streak,
		}, { Ui.list(true, 6) })
		for day = 1, 7 do
			local done = (d.lastClaimDay == today and day <= d.streakDay)
				or (d.lastClaimDay == today - 1 and day <= d.streakDay)
			local isNext = day == nextDay and d.lastClaimDay ~= today
			local t = Ui.glowTile("Frame", {
				Name = `Day{day}`,
				LayoutOrder = day,
				Size = UDim2.fromOffset(78, 100),
				ZIndex = 2,
				Parent = row,
			}, if done then C.Green elseif isNext then C.Gold else C.Purple, isNext)
			local n = Ui.display({
				Text = `DAY {day}`,
				TextSize = 16,
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.new(1, 0, 0, 20),
				ZIndex = 3,
				Parent = t,
			})
			n.TextColor3 = C.White
			outline(n, 2)
			local gem = day == 7
			Ui.icon(if done then "icon_check" elseif gem then "icon_gem" else "icon_coin", 40, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 50),
				ZIndex = 3,
				Parent = t,
			})
			local amount = Ui.display({
				Text = if gem then `{Economy.Streak.day7Gems}+EGG` else tostring(Economy.Streak.coins[day]),
				TextSize = 18,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -4),
				Size = UDim2.new(1, -6, 0, 22),
				ZIndex = 3,
				Parent = t,
			})
			amount.TextColor3 = if gem then C.Blue else C.GoldHi
			outline(amount, 2)
			Ui.fit(amount, 18, 11)
		end
		local claim = Ui.button(
			if d.lastClaimDay == today then "TOMORROW" else `CLAIM DAY {nextDay}`,
			"primary",
			function()
				local reply = ctx.request("Daily.ClaimStreak")
				if reply.ok then
					ctx.say(`DAY {reply.value.day}!`, "gold", "icon_calendar")
					if reply.value.day < 7 then
						ctx.fly(Ui.lastPressed, "coins", { icon = "icon_coin", count = 5 })
					else
						ctx.fly(Ui.lastPressed, "gems", { icon = "icon_gem", count = 4 })
					end
				end
			end,
			{
				Name = "ClaimStreak",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(176, 64),
				ZIndex = 3,
			}
		)
		bigLabel(claim, 26)
		claim.setEnabled(d.lastClaimDay ~= today)
		claim.instance.Parent = streak
	end

	render = function()
		local view = ctx.state.view
		local today = ctx.now() // 86400
		renderStreak(view)
		Ui.clear(tabs)
		for i, t in { { "Daily", "DAILY" }, { "Goals", "GOALS" } } do
			local b = Ui.button(t[2], if tab == t[1] then "purple" else "tab", function()
				tab = t[1]
				page = 1
				Ui.sound("tick")
				render()
			end, {
				Name = `Tab{t[1]}`,
				Position = UDim2.fromOffset((i - 1) * 140, 0),
				Size = UDim2.fromOffset(130, 40),
			})
			bigLabel(b, 22)
			b.instance.Parent = tabs
		end
		Ui.clear(list)
		Ui.list(true, 12, Enum.HorizontalAlignment.Center).Parent = list
		local defs: { { def: any, entry: any } } = {}
		if tab == "Daily" then
			for _, def in QuestsCfg.Daily do
				local entry = view.quests[def.id]
				if entry and view.questDay == today then
					table.insert(defs, { def = def, entry = entry })
				end
			end
		else
			for _, def in QuestsCfg.Achievements do
				table.insert(defs, { def = def, entry = view.quests[def.id] })
			end
		end
		local pages = math.max(1, math.ceil(#defs / PER_PAGE))
		page = math.clamp(page, 1, pages)
		for i = (page - 1) * PER_PAGE + 1, math.min(#defs, page * PER_PAGE) do
			questCard(defs[i].def, defs[i].entry, i)
		end
		if pages > 1 then
			local pager = Ui.frame({
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(200, 40),
				Parent = tabs,
			})
			for side = -1, 1, 2 do
				local a = Ui.button(if side < 0 then "◀" else "▶", "secondary", function()
					page += side
					render()
				end, {
					Name = if side < 0 then "Prev" else "Next",
					AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0),
					Position = UDim2.fromScale(if side < 0 then 0 else 1, 0),
					Size = UDim2.fromOffset(48, 40),
				})
				bigLabel(a, 26)
				a.setEnabled(if side < 0 then page > 1 else page < pages)
				a.instance.Parent = pager
			end
			local label = Ui.display({
				Text = `{page}/{pages}`,
				TextSize = 24,
				Position = UDim2.fromOffset(52, 0),
				Size = UDim2.new(1, -104, 1, 0),
				Parent = pager,
			}, true)
			outline(label, 2)
		end
		Ui.stagger(list, ctx.reducedMotion())
	end

	render()
	return { destroy = function() end, refresh = render }
end
