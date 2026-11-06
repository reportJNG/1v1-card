--!strict
-- 1v1 Arena: your deck and league, Find Match / Cancel, and the queue status (searching time
-- and the widening trophy band). No entry fee and no wagers: wins pay a purse from the game.
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

local C = Theme.Color

-- Matches the server's band (Server/Matchmaking/Pairing): ±100, +50 every 10 s, up to ±400.
local function band(waited: number): number
	return math.min(400, 100 + 50 * (math.max(0, waited) // 10))
end

return function(ctx: any, layer: Frame, _arg: any?): any
	local p = Ui.panel(layer, "1v1 Arena", ctx.close, UDim2.fromOffset(700, 430), "icon_play")
	local deckRow = Ui.frame(
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 170), Parent = p.body },
		{
			Ui.list(true, 12, Enum.HorizontalAlignment.Center),
		}
	)
	local info = Ui.frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 178),
		Size = UDim2.new(1, 0, 1, -178),
		Parent = p.body,
	}, { Ui.list(false, 8, Enum.HorizontalAlignment.Center) })
	local running = true

	local queueText: TextLabel
	local function render()
		local view = ctx.state.view
		Ui.clear(deckRow)
		Ui.clear(info)
		local specs = {}
		for i, uid in view.deck do
			local card = view.cards[uid]
			if card then
				Visuals.portrait(deckRow, card.characterId, card.golden, Vector2.new(110, 150), true).LayoutOrder =
					i
				table.insert(specs, { characterId = card.characterId, level = card.level })
			end
		end
		local league = Progress.leagueFor(view.trophies)
		local purse = Economy.Matches.purseByLeague[league.id]
		Ui.text({
			Text = `{league.id} League · 🏆 {Format.number(view.trophies)} · cards fight at up to level {league.rankedLevelCap}`,
			FontFace = Theme.Face.Bold,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 1,
			Parent = info,
		})
		Ui.text({
			Text = `Win: 💰 {purse} purse (paid by the game) and about +{Economy.Matches.trophyWin} trophies. No entry fee, nothing at stake.`,
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
			Parent = info,
		})
		if #specs == 3 then
			Ui.text({
				Text = `Deck Power {Power.deck(specs).total}`,
				TextColor3 = C.Green,
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 3,
				Parent = info,
			})
		end
		queueText = Ui.text({
			Text = "",
			FontFace = Theme.Face.Bold,
			TextColor3 = C.Blue,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 4,
			Name = "QueueStatus",
			Parent = info,
		})
		local q = ctx.state.queue
		if q.state == "Searching" then
			local cancel = Ui.button("Cancel search", "ghost", function()
				ctx.request("Queue.Leave")
			end, { Size = UDim2.fromOffset(240, 44), LayoutOrder = 5, Name = "CancelQueue" })
			cancel.instance.Parent = info
		elseif #specs < 3 then
			local build = Ui.button("Build a deck first", "secondary", function()
				ctx.open("Deck")
			end, { Size = UDim2.fromOffset(260, 44), LayoutOrder = 5 })
			build.instance.Parent = info
		else
			local find = Ui.button("Find Match", "primary", function()
				ctx.request("Queue.Join")
			end, { Size = UDim2.fromOffset(260, 48), LayoutOrder = 5, Name = "FindMatch" })
			find.instance.Parent = info
		end
		Ui.text({
			Text = "Or challenge a Guardian in Worlds (PvE).",
			TextSize = Theme.Size.small,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 6,
			Parent = info,
		})
	end

	render()
	local disconnect = ctx.state.changed:connect(function(what)
		if what == "queue" then
			render()
		end
	end)
	task.spawn(function()
		while running do
			local q = ctx.state.queue
			if queueText and queueText.Parent then
				if q.state == "Searching" and q.since then
					local waited = ctx.now() - q.since
					queueText.Text = `Searching... {Format.seconds(waited)} · trophy range ±{band(waited)}`
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
