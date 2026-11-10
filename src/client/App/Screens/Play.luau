--!strict
-- 1v1 Arena (`hd-05`, with no bet area): league, trophies, the game-paid win purse and the level
-- cap on the left, with Find Match (a queue timer and Cancel while searching); on the right the
-- player's lead card versus the opponent's "?" silhouette in a red aura, the fiery VS between.
-- No entry fee and no wagers: wins pay a purse from the game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Power = require(Shared.Domain.Power)
local Progress = require(Shared.Domain.Progress)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)
local Kit = require(App.Kit)
local TweenService = game:GetService("TweenService")

local C = Theme.Color

-- Matches the server's band (Server/Matchmaking/Pairing): ±100, +50 every 10 s, up to ±400.
local function band(waited: number): number
	return math.min(400, 100 + 50 * (math.max(0, waited) // 10))
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "1v1 Arena", ctx.close, UDim2.fromOffset(720, 420), "icon_play")
	-- Left: league, trophies, the win purse, the level cap, Find Match / queue timer + Cancel.
	local left = Ui.frame({
		Name = "Left",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 290, 1, 0),
		Parent = p.body,
	}, { Ui.list(false, 8) })
	-- Right: the split VS scene.
	local scene = Ui.frame({
		Name = "Scene",
		BackgroundColor3 = Color3.fromHex("#0B0720"),
		ClipsDescendants = true,
		Position = UDim2.fromOffset(300, 0),
		Size = UDim2.new(1, -300, 1, 0),
		Parent = p.body,
	}, { Ui.corner(12) })
	local running = true

	local queueText: TextLabel
	local function render()
		local view = ctx.state.view
		Ui.clear(left)
		Ui.list(false, 8).Parent = left
		Ui.clear(scene)
		Ui.corner(12).Parent = scene
		local specs = {}
		local lead: any = nil
		for _, uid in view.deck do
			local card = view.cards[uid]
			if card then
				table.insert(specs, { characterId = card.characterId, level = card.level })
				if
					lead == nil
					or Power.card(card.characterId, card.level) > Power.card(lead.characterId, lead.level)
				then
					lead = card
				end
			end
		end
		local q = ctx.state.queue

		-- The scene: your side glows violet, the opponent's side red; the fiery VS between.
		for side = 1, 2 do
			Ui.frame({
				Name = if side == 1 then "You" else "Foe",
				BackgroundColor3 = if side == 1 then Color3.fromHex("#3A1680") else Color3.fromHex("#5A0A1A"),
				Position = UDim2.fromScale(if side == 1 then 0 else 0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
				Parent = scene,
			}, {
				Ui.new("UIGradient", {
					Rotation = if side == 1 then 0 else 180,
					Transparency = NumberSequence.new(0.1, 0.8),
				}),
			})
			Ui.image("light_rays", {
				ImageColor3 = if side == 1 then C.Purple else C.Red,
				ImageTransparency = 0.55,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(if side == 1 then 0.26 else 0.74, 0.5),
				Size = UDim2.fromOffset(300, 300),
				Parent = scene,
			})
		end
		if lead then
			local you = Visuals.portrait(
				scene,
				lead.characterId,
				lead.golden,
				Vector2.new(150, 210),
				true,
				lead.level
			)
			you.AnchorPoint = Vector2.new(0.5, 0.5)
			you.Position = UDim2.fromScale(0.26, 0.5)
		end
		-- The opponent: a dark "?" silhouette in a red aura while searching.
		local foe = Ui.frame({
			Name = "Opponent",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.74, 0.5),
			Size = UDim2.fromOffset(150, 210),
			Parent = scene,
		})
		Kit.image("aura_ur", {
			ImageColor3 = Color3.fromHex("#FF4040"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 300),
			ScaleType = Enum.ScaleType.Stretch,
			Parent = foe,
		})
		Kit.image("card_back_n", {
			ImageColor3 = Color3.fromHex("#B04050"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.16, 1.14),
			ScaleType = Enum.ScaleType.Stretch,
			Parent = foe,
		})
		local mark = Ui.display({
			Text = if q.state == "Found" then "!" else "?",
			TextSize = 80,
			TextColor3 = Color3.fromHex("#FF6A6A"),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Parent = foe,
		})
		mark.TextXAlignment = Enum.TextXAlignment.Center
		local vs = Ui.image("vs_badge", {
			Name = "VS",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(130, 82),
			ZIndex = 5,
			Parent = scene,
		})
		if not ctx.reducedMotion() then
			local s = Ui.new("UIScale", { Scale = 1.8, Parent = vs })
			TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end

		-- Left column.
		local league = Progress.leagueFor(view.trophies)
		local purse = Economy.Matches.purseByLeague[league.id]
		local badge = Ui.frame({
			Name = "League",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = 1,
			Parent = left,
		})
		Ui.icon("icon_trophy", 46, { Position = UDim2.fromScale(0, 0.5), Parent = badge })
		local leagueName = Ui.display({
			Text = `{string.upper(league.id)} LEAGUE`,
			TextSize = 22,
			TextColor3 = C.GoldHi,
			Position = UDim2.fromOffset(54, 2),
			Size = UDim2.new(1, -54, 0, 26),
			Parent = badge,
		})
		leagueName.TextXAlignment = Enum.TextXAlignment.Left
		Ui.text({
			Text = `{Format.number(view.trophies)} trophies`,
			FontFace = Theme.Face.Bold,
			TextSize = 20,
			Position = UDim2.fromOffset(54, 28),
			Size = UDim2.new(1, -54, 0, 18),
			Parent = badge,
		})
		-- What a win pays, as big chips (no sentences): Coins, trophies, the level cap.
		local rows = Ui.frame({
			Name = "Rewards",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 96),
			LayoutOrder = 2,
			Parent = left,
		}, { Ui.list(true, 8, Enum.HorizontalAlignment.Center) })
		local function chip(icon: string, value: string, color: Color3, order: number)
			local c = Ui.glowTile("Frame", {
				LayoutOrder = order,
				Size = UDim2.fromOffset(90, 86),
				Parent = rows,
			}, color, false)
			Ui.icon(icon, 44, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 6),
				ZIndex = 2,
				Parent = c,
			})
			local t = Ui.display({
				Text = value,
				TextSize = 24,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -6),
				Size = UDim2.new(1, -8, 0, 30),
				ZIndex = 2,
				Parent = c,
			})
			t.TextColor3 = C.White
			Ui.outline(C.Night, 3).Parent = t
			Ui.fit(t, 24, 14)
		end
		chip("icon_coin", `+{Format.short(purse)}`, C.Gold, 1)
		chip("icon_trophy", `+{Economy.Matches.trophyWin}`, C.Purple, 2)
		chip("icon_power", `LV {league.rankedLevelCap}`, C.Blue, 3)
		queueText = Ui.text({
			Text = "",
			FontFace = Theme.Face.Bold,
			TextSize = 20,
			TextColor3 = C.Blue,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 3,
			Name = "QueueStatus",
			Parent = left,
		})
		if q.state == "Searching" then
			local cancel = Ui.button("CANCEL", "danger", function()
				ctx.request("Queue.Leave")
			end, { Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 4, Name = "CancelQueue" })
			cancel.instance.Parent = left
		elseif #specs < 3 then
			local build = Ui.button("BUILD A DECK", "secondary", function()
				ctx.open("Deck")
			end, { Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 4 })
			build.instance.Parent = left
		else
			local find = Ui.button("FIND MATCH", "primary", function()
				ctx.request("Queue.Join")
			end, { Size = UDim2.new(1, 0, 0, 66), LayoutOrder = 4, Name = "FindMatch" })
			find.label.FontFace = Theme.Face.Display
			local cap = find.label:FindFirstChildOfClass("UITextSizeConstraint")
			if cap then
				cap.MaxTextSize = 34
			end
			find.instance.Parent = left
		end
		-- nothing at stake: the purse is paid by the game
		local fee = Ui.display({
			Name = "NoFee",
			Text = "NO ENTRY FEE",
			TextSize = 20,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = 5,
			Parent = left,
		})
		fee.TextColor3 = C.Green
		Ui.outline(C.Night, 2).Parent = fee
	end

	render()
	local disconnect = ctx.state.changed:connect(function(what)
		if what == "queue" then
			render()
		end
	end)
	local lastState = ctx.state.queue.state
	local lastTick = 0
	task.spawn(function()
		while running do
			local q = ctx.state.queue
			-- Matchmaking sounds: a soft tick each second while searching, a chime when found.
			if q.state == "Found" and lastState ~= "Found" then
				Ui.sound("queue_found")
			elseif q.state == "Searching" and os.clock() - lastTick >= 1 then
				lastTick = os.clock()
				Ui.sound("queue_search")
			end
			lastState = q.state
			if queueText and queueText.Parent then
				if q.state == "Searching" and q.since then
					local waited = ctx.now() - q.since
					queueText.Text = `Searching... {Format.seconds(waited)} · ±{band(waited)} trophies`
				elseif q.state == "Found" then
					queueText.Text = "Match found! Getting ready..."
				elseif q.state == "Cancelled" then
					queueText.Text = "That match was cancelled. Search again?"
				else
					queueText.Text = ""
				end
			end
			task.wait(0.5)
		end
	end)
	return {
		destroy = function()
			running = false
			disconnect()
		end,
		refresh = render,
	}
end
