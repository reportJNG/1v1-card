--!strict
-- The battle result over the arena (Victory / Defeat): the banner, the lead card, the team, the
-- rewards the server settled and a Continue button. MASTER_FIX_PLAN Phase 10 (BAD_GUI_7) rebuilds
-- this screen; it was split out of Screens/Battle unchanged.
local TweenService = game:GetService("TweenService")
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)

local C = Theme.Color
local F = Theme.Face

local BattleResult = {}

function BattleResult.show(
	parent: Frame,
	start: any,
	data: any,
	view: any,
	reduced: boolean,
	onClose: () -> ()
): Frame
	local you: number = start.you
	local won = data.result.winner == you
	local reward: any = data.reward or {}
	Ui.sound(if won then "victory" else "defeat")

	local resultBox = Ui.frame({
		Name = "Result",
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.35,
		Position = UDim2.fromScale(-0.5, -0.5),
		Size = UDim2.fromScale(2, 2),
		ZIndex = 20,
		Parent = parent,
	})
	local centre = Ui.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 490),
		ZIndex = 21,
		Parent = resultBox,
	})
	-- The lead card behind the banner (`hd-06`): the strongest card of the player's team, in
	-- light rays, tilted in from the side.
	local leadUnit: any = nil
	for _, u in view.sides[you].units do
		if leadUnit == nil or (u.level or 1) > (leadUnit.level or 1) then
			leadUnit = u
		end
	end
	if leadUnit then
		local behind = Visuals.portrait(
			centre,
			leadUnit.characterId,
			false,
			Vector2.new(170, 238),
			false,
			leadUnit.level
		)
		behind.AnchorPoint = Vector2.new(0.5, 0.5)
		behind.Position = UDim2.fromOffset(-20, 220)
		behind.Rotation = -8
		for _, d in behind:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 20
			end
		end
		if not won then
			local dim = Ui.frame({
				BackgroundColor3 = Color3.fromHex("#0A1020"),
				BackgroundTransparency = 0.45,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 60,
				Parent = behind,
			})
			dim.Name = "Steel"
		end
		if not reduced then
			behind.Position = UDim2.fromOffset(-220, 220)
			TweenService:Create(
				behind,
				TweenInfo.new(0.5, Enum.EasingStyle.Back),
				{ Position = UDim2.fromOffset(-20, 220) }
			):Play()
		end
	end
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
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset(440, 70),
		ZIndex = 23,
		Parent = banner,
	}, won)
	-- The banner drops in with a bounce (MISSION 10).
	if not reduced then
		banner.Position = UDim2.fromOffset(320, -200)
		TweenService
			:Create(
				banner,
				TweenInfo.new(0.55, Enum.EasingStyle.Bounce),
				{ Position = UDim2.fromOffset(320, 0) }
			)
			:Play()
	end
	local reasons = {
		KO = "All cards knocked out",
		MaxRounds = "Round limit: most HP left wins",
		Forfeit = "Forfeit",
		Timeouts = "Too many missed picks",
	}
	local sub = Ui.text({
		Text = if won then "You won the match!" else "So close! Tune your deck and try again.",
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
	table.insert(
		notes,
		1,
		`{reasons[data.result.reason] or data.result.reason} · {data.result.rounds} rounds`
	)
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
		onClose()
	end, {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(320, 432),
		Size = UDim2.fromOffset(240, 50),
		ZIndex = 22,
	})
	done.instance.Parent = centre
	Ui.popIn(done.instance, reduced)
	return resultBox
end

return BattleResult
