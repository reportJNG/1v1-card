--!strict
-- The battle result over the arena (BAD_GUI_7, target docs/brief/bad-gui/16-target-battle-result.png):
--   top      the VICTORY / DEFEAT banner (slams down with a shake and sparks or shards), the
--            player's panel top-left and the opponent's top-right: lead card, name, trophies,
--            HP bar and deck pips only
--   sides    each side's MVP card (the card that dealt the most damage), the loser's dimmed
--   arena    both fighters back on their pads in victory / defeat poses (App/BattleStage)
--   centre   one short line, the player's 3 deck cards with rarity auras (knocked-out ones
--            darkened and cracked), the reward chips counting up, a reason pill only when it
--            matters, and a big CONTINUE (back to the player's saved spot) plus PLAY AGAIN after a
--            ranked match
-- Everything shown comes from the server's end packet (result, settled reward, final view). No
-- battle log.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Rarities = require(Shared.Config.Rarities)
local App = script.Parent.Parent
local Theme = require(App.Theme)
local Ui = require(App.Ui)
local Format = require(App.Format)
local Visuals = require(App.Visuals)

local C = Theme.Color
local F = Theme.Face

local BattleResult = {}

export type Info = {
	dealt: { [number]: { [number]: number } }, -- damage dealt per side and deck slot
	stage: any, -- App/BattleStage
	onClose: () -> (),
}

local REASONS: { [string]: string } = {
	KO = "All cards knocked out",
	MaxRounds = "Round limit: most HP left wins",
	Forfeit = "Forfeit",
	Timeouts = "Too many missed picks",
}

local VOIDS: { [string]: string } = {
	RepeatOpponent = "No reward: same opponent too often today",
	EarlyForfeit = "No reward: forfeit before round 3",
	Timeouts = "No reward: too many missed picks",
}

-- The side's MVP slot: the card that dealt the most damage (the highest level if none did).
local function mvpSlot(side: any, dealt: { [number]: number }?): number
	local best, bestValue = 1, -1
	for slot, u in side.units do
		local value = (dealt and dealt[slot] or 0) * 100 + (u.level or 1)
		if value > bestValue then
			best, bestValue = slot, value
		end
	end
	return best
end

local function outlined(label: TextLabel, thickness: number?): TextLabel
	Ui.outline(C.Night, thickness or 3).Parent = label
	return label
end

-- A rarity-coloured glow behind a card (TEMP until the G2 flame aura sprites).
local function auraBehind(
	parent: Instance,
	rarity: string,
	size: Vector2,
	at: UDim2,
	z: number,
	reduced: boolean
)
	local color = Theme.Rarity[rarity] or C.Purple
	local glow = Ui.image("light_rays", {
		Name = "Aura",
		ImageColor3 = color,
		ImageTransparency = if rarity == "Common" then 0.65 else 0.35,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at,
		Size = UDim2.fromOffset(size.X * 1.9, size.X * 1.9),
		ZIndex = z,
		Parent = parent,
	})
	if not reduced then
		TweenService:Create(
			glow,
			TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 360 }
		):Play()
	end
end

-- A dark crack overlay with "KO" over a knocked-out card (TEMP until the G2 crack piece).
local function knockedOut(card: GuiObject, z: number)
	local cover = Ui.frame({
		Name = "KO",
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = card,
	}, { Ui.corner(8) })
	for i, spec in { { 0.35, 0.3, 38 }, { 0.6, 0.55, -52 }, { 0.45, 0.72, 20 } } do
		Ui.frame({
			Name = `Crack{i}`,
			BackgroundColor3 = Color3.fromHex("#DDE6FF"),
			BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spec[1], spec[2]),
			Size = UDim2.new(0.7, 0, 0, 2),
			Rotation = spec[3],
			ZIndex = z + 1,
			Parent = cover,
		})
	end
	local ko = Ui.display({
		Text = "KO",
		TextSize = 34,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = cover,
	})
	ko.TextColor3 = C.Red
	outlined(ko)
end

-- Reward chips pop in one after another.
local function popScaleIn(obj: GuiObject, reduced: boolean, order: number)
	if reduced then
		return
	end
	local s = obj:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = obj })
	s.Scale = 0
	task.delay(0.5 + order * 0.15, function()
		TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

function BattleResult.show(
	ctx: any,
	parent: Frame,
	start: any,
	data: any,
	view: any,
	reduced: boolean,
	info: Info
): Frame
	local you: number = start.you
	local them = 3 - you
	local won = data.result.winner == you
	local mode = data.mode or start.mode
	local reward: any = data.reward or {}
	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	Ui.sound(if won then "victory" else "defeat")

	local box = Ui.frame({
		Name = "Result",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = parent,
	})
	-- light vignettes only: the arena and both fighters stay visible
	for _, edge in { { 0, 0, 170 }, { 1, 180, 200 } } do
		Ui.frame({
			BackgroundColor3 = C.Night,
			AnchorPoint = Vector2.new(0, edge[1]),
			Position = UDim2.fromScale(-0.5, edge[1]),
			Size = UDim2.new(2, 0, 0, edge[3]),
			ZIndex = 20,
			Parent = box,
		}, { Ui.new("UIGradient", { Rotation = 90 + edge[2], Transparency = NumberSequence.new(0.2, 1) }) })
	end

	-- The fighters in the arena.
	local mvp = {
		[you] = mvpSlot(view.sides[you], info.dealt[you]),
		[them] = mvpSlot(view.sides[them], info.dealt[them]),
	}
	local seat = function(side: number): any
		return start.seats[side] or {}
	end
	if info.stage then
		local sides = {}
		for side = 1, 2 do
			local s = seat(side)
			sides[side] = {
				userId = if s.ai then nil else s.userId,
				characterId = view.sides[side].units[mvp[side]].characterId,
				name = s.name or "",
				won = data.result.winner == side,
			}
		end
		task.spawn(function()
			info.stage:showResult(sides, mobile)
		end)
	end

	------------------------------------------------------------------------------------------
	-- Top: the banner and the two panels
	------------------------------------------------------------------------------------------
	local banner = Ui.image(if won then "banner_victory" else "banner_defeat", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 36),
		Size = UDim2.fromOffset(350, 132),
		ZIndex = 24,
		Parent = box,
	})
	local word = Ui.display({
		Text = if won then "VICTORY" else "DEFEAT",
		TextSize = 54,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(330, 66),
		ZIndex = 25,
		Parent = banner,
	}, won)
	if not won then
		word.TextColor3 = Color3.fromHex("#D6E2FF")
	end
	outlined(word, 4)
	local slam = Ui.new("UIScale", { Parent = banner })
	if not reduced then
		slam.Scale = 2.2
		banner.ImageTransparency = 1
		TweenService:Create(banner, TweenInfo.new(0.18), { ImageTransparency = 0 }):Play()
		local t = TweenService:Create(slam, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 })
		t.Completed:Connect(function()
			if info.stage then
				info.stage:addShake(1.2)
				info.stage:flash(0.2)
			end
		end)
		t:Play()
	end

	local function panel(side: number)
		local left = side == you
		local s = view.sides[side]
		local st = seat(side)
		local lead = s.units[mvp[side]]
		local def = Characters.ById[lead.characterId]
		local tile = Ui.glowTile("Frame", {
			Name = if left then "YouPanel" else "OpponentPanel",
			AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = if left then UDim2.fromOffset(14, 46) else UDim2.new(1, -14, 0, 46),
			Size = UDim2.fromOffset(262, 92),
			BackgroundTransparency = 0.1,
			ZIndex = 22,
			Parent = box,
		}, if left then C.Pink else C.Gold, false)
		local card = Visuals.portrait(tile, lead.characterId, false, Vector2.new(56, 78), false, lead.level)
		card.Position = if left then UDim2.fromOffset(8, 7) else UDim2.new(1, -64, 0, 7)
		for _, d in card:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 22
			end
		end
		card.ZIndex += 22
		local x = if left then 72 else 10
		local align = if left then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		local name = Ui.display({
			Text = string.upper(st.name or def.displayName),
			TextSize = 22,
			TextWrapped = false,
			TextXAlignment = align,
			Position = UDim2.fromOffset(x, 6),
			Size = UDim2.fromOffset(180, 26),
			ZIndex = 23,
			Parent = tile,
		})
		outlined(name)
		Ui.fit(name, 22, 14)
		-- trophies (or GUARDIAN for the Trial's AI)
		local row = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, 32),
			Size = UDim2.fromOffset(180, 22),
			ZIndex = 23,
			Parent = tile,
		}, {
			Ui.list(true, 4, if left then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Right),
		})
		if st.ai then
			local g = Ui.display({
				Text = "GUARDIAN",
				TextSize = 18,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 22),
				ZIndex = 23,
				Parent = row,
			})
			g.TextColor3 = C.GoldHi
			outlined(g, 2)
		else
			Ui.icon(
				"icon_trophy",
				22,
				{ AnchorPoint = Vector2.zero, LayoutOrder = if left then 1 else 2, ZIndex = 23, Parent = row }
			)
			local tro = Ui.text({
				Text = Format.number(
					if left
							and mode == "Ranked"
							and reward.trophies
						then reward.trophies
						else (st.trophies or 0)
				),
				FontFace = F.Number,
				TextSize = 20,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 22),
				LayoutOrder = if left then 2 else 1,
				ZIndex = 23,
				Parent = row,
			})
			tro.TextColor3 = C.GoldHi
			outlined(tro, 2)
		end
		-- HP bar of the card that finished on the pad, with big numbers
		local active = s.units[s.active]
		local frac = math.clamp(active.hp / math.max(1, active.maxHp), 0, 1)
		local bar = Ui.frame({
			Name = "Hp",
			BackgroundColor3 = Color3.fromHex("#0C1028"),
			Position = UDim2.fromOffset(if left then x else 68, 58),
			Size = UDim2.fromOffset(122, 20),
			ClipsDescendants = true,
			ZIndex = 23,
			Parent = tile,
		}, { Ui.corner(10), Ui.stroke(Color3.fromHex("#B8C4E6"), 1.5, 0.2) })
		Ui.frame({
			BackgroundColor3 = if frac > 0.5 then C.Green elseif frac > 0.25 then C.Gold else C.Red,
			AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = UDim2.fromScale(if left then 0 else 1, 0),
			Size = UDim2.fromScale(frac, 1),
			ZIndex = 23,
			Parent = bar,
		}, { Ui.corner(10) })
		local hpText = Ui.text({
			Text = `{active.hp} / {active.maxHp}`,
			FontFace = F.Number,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 24,
			Parent = bar,
		})
		outlined(hpText, 2)
		-- deck pips: filled for cards still standing
		local pips = Ui.frame({
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(if left then x + 128 else 10, 59),
			Size = UDim2.fromOffset(54, 18),
			ZIndex = 23,
			Parent = tile,
		}, { Ui.list(true, 4, Enum.HorizontalAlignment.Center) })
		for slot, u in s.units do
			Ui.frame({
				BackgroundColor3 = if u.hp > 0
					then (if left then C.Pink else C.Gold)
					else Color3.fromHex("#2A3150"),
				Size = UDim2.fromOffset(14, 14),
				LayoutOrder = slot,
				ZIndex = 23,
				Parent = pips,
			}, { Ui.corner(7), Ui.stroke(C.Night, 1.5, 0) })
		end
	end
	panel(you)
	panel(them)

	------------------------------------------------------------------------------------------
	-- The MVP cards at the sides (the loser's dimmed)
	------------------------------------------------------------------------------------------
	local function mvpCard(side: number)
		local left = side == you
		local u = view.sides[side].units[mvp[side]]
		local def = Characters.ById[u.characterId]
		local winner = data.result.winner == side
		local size = if left then Vector2.new(150, 210) else Vector2.new(116, 162)
		local holder = Ui.frame({
			Name = if left then "YouMvp" else "OpponentMvp",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = if left then UDim2.new(0, 104, 0.5, 34) else UDim2.new(1, -88, 0.5, 34),
			Size = UDim2.fromOffset(size.X, size.Y),
			Rotation = if left then -7 else 6,
			ZIndex = 21,
			Parent = box,
		})
		auraBehind(holder, def.rarity, size, UDim2.fromScale(0.5, 0.5), 21, reduced)
		local card = Visuals.portrait(holder, u.characterId, false, size, true, u.level)
		for _, d in card:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 21
			end
		end
		card.ZIndex += 21
		if not winner then
			Ui.frame({
				Name = "Dim",
				BackgroundColor3 = Color3.fromHex("#0A1020"),
				BackgroundTransparency = 0.4,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 80,
				Parent = holder,
			}, { Ui.corner(10) })
		end
		local tag = Ui.display({
			Text = "MVP",
			TextSize = 22,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.fromOffset(80, 26),
			ZIndex = 81,
			Parent = holder,
		}, true)
		outlined(tag)
		if not reduced then
			holder.Position = holder.Position + UDim2.fromOffset(if left then -260 else 260, 0)
			TweenService:Create(
				holder,
				TweenInfo.new(0.5, Enum.EasingStyle.Back),
				{ Position = holder.Position + UDim2.fromOffset(if left then 260 else -260, 0) }
			):Play()
		end
	end
	mvpCard(you)
	mvpCard(them)

	------------------------------------------------------------------------------------------
	-- Centre: the line, the deck, the rewards, the reason
	------------------------------------------------------------------------------------------
	local line = Ui.display({
		Text = if won then "YOU WON THE MATCH!" else "SO CLOSE! TUNE YOUR DECK AND TRY AGAIN.",
		TextSize = 26,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 178),
		Size = UDim2.fromOffset(540, 32),
		ZIndex = 22,
		Parent = box,
	})
	line.TextColor3 = C.White
	outlined(line)
	Ui.fit(line, 26, 16)

	local deck = Ui.frame({
		Name = "Team",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 216),
		Size = UDim2.fromOffset(330, 130),
		ZIndex = 22,
		Parent = box,
	}, { Ui.list(true, 14, Enum.HorizontalAlignment.Center) })
	for slot, u in view.sides[you].units do
		local def = Characters.ById[u.characterId]
		local cell = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(88, 124),
			LayoutOrder = slot,
			ZIndex = 22,
			Parent = deck,
		})
		if u.hp > 0 and Rarities.Defs[def.rarity].order >= 2 then
			auraBehind(cell, def.rarity, Vector2.new(70, 100), UDim2.fromScale(0.5, 0.5), 22, reduced)
		end
		local card = Visuals.portrait(cell, u.characterId, false, Vector2.new(88, 124), true, u.level)
		for _, d in card:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex += 22
			end
		end
		card.ZIndex += 22
		if u.hp <= 0 then
			knockedOut(cell, 70)
		end
		if not reduced then
			Ui.popIn(cell, reduced)
		end
	end

	local chips = Ui.frame({
		Name = "Rewards",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 352),
		Size = UDim2.fromOffset(600, 48),
		ZIndex = 22,
		Parent = box,
	}, { Ui.list(true, 12, Enum.HorizontalAlignment.Center) })
	local function chip(icon: string, to: number, order: number, text: string?)
		local f = Ui.frame({
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(if text then 210 else 150, 46),
			LayoutOrder = order,
			ZIndex = 22,
			Parent = chips,
		})
		Ui.skin(f, "reward_chip", 0.62, { ZIndex = 22 })
		Ui.icon(icon, 36, { Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 23, Parent = f })
		local label = Ui.display({
			Text = text or "",
			TextSize = 26,
			TextWrapped = false,
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -54, 1, 0),
			ZIndex = 23,
			Parent = f,
		})
		label.TextColor3 = if to < 0 then C.Red else C.GoldHi
		outlined(label)
		Ui.fit(label, 26, 14)
		if text == nil then
			local function fmt(n: number): string
				return (if n >= 0 then "+" else "") .. Format.number(math.round(n))
			end
			if reduced then
				label.Text = fmt(to)
			else
				Ui.countUp(label, 0, to, fmt)
			end
		end
		popScaleIn(f, reduced, order)
	end
	local notes: { string } = {}
	local coins = 0
	if mode == "Ranked" then
		coins = reward.coins or 0
		chip("icon_coin", coins, 1)
		if reward.trophyDelta then
			chip("icon_trophy", reward.trophyDelta, 2)
		end
		if reward.voidReason then
			table.insert(notes, VOIDS[reward.voidReason] or reward.voidReason)
		elseif coins > 0 and reward.reward == "Reduced" then
			table.insert(notes, "Daily limit reached: reduced Coins")
		end
		if reward.leagueAfter and reward.leagueAfter ~= reward.leagueBefore then
			chip("icon_trophy", 0, 3, `{string.upper(reward.leagueAfter)} LEAGUE`)
		end
	elseif reward.firstClear then
		coins = reward.coins or 0
		chip("icon_trophy", reward.trophies or 0, 1)
		chip("icon_coin", coins, 2)
		if (reward.gems or 0) > 0 then
			chip("icon_gem", reward.gems, 3)
		end
		if reward.goldenEgg then
			chip("icon_gift", 0, 4, "GOLDEN EGG")
		end
	elseif won then
		chip("icon_check", 0, 1, "CLEARED BEFORE")
	else
		-- a lost Trial pays nothing: say so instead of leaving the row empty
		chip("icon_lock", 0, 1, "NO REWARD")
	end

	-- the reason pill, only when it matters (not for a plain KO)
	local reason = data.result.reason
	if reason ~= "KO" then
		table.insert(notes, 1, `{REASONS[reason] or reason} · {data.result.rounds} rounds`)
	end
	if #notes > 0 then
		local pill = Ui.frame({
			Name = "Reason",
			BackgroundColor3 = Color3.fromHex("#141A34"),
			BackgroundTransparency = 0.1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 408),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			ZIndex = 22,
			Parent = box,
		}, {
			Ui.corner(17),
			Ui.stroke(C.Gold, 2, 0.2),
			Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
			Ui.list(true, 10, Enum.HorizontalAlignment.Center),
		});
		(pill:FindFirstChildOfClass("UIListLayout") :: UIListLayout).VerticalAlignment =
			Enum.VerticalAlignment.Center
		for i, text in { "!!!", table.concat(notes, " · "), "!!!" } do
			local t = Ui.display({
				Text = text,
				TextSize = if i == 2 then 19 else 22,
				TextWrapped = false,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				LayoutOrder = i,
				ZIndex = 23,
				Parent = pill,
			})
			t.TextColor3 = if i == 2 then C.Text else Color3.fromHex("#FFB23A")
			outlined(t, 2)
		end
	end

	------------------------------------------------------------------------------------------
	-- CONTINUE (and PLAY AGAIN after a ranked match)
	------------------------------------------------------------------------------------------
	local closed = false
	local function close(then_: (() -> ())?)
		if closed then
			return
		end
		closed = true
		Ui.sound("confirm")
		info.onClose()
		-- the Coins won fly to the currency pill once the HUD is back
		if coins > 0 then
			task.delay(0.45, function()
				ctx.fly("center", "coins", { icon = "icon_coin", count = coins })
			end)
		end
		if then_ then
			task.delay(0.3, then_)
		end
	end
	local done = Ui.button("CONTINUE", "primary", function()
		close(nil)
	end, {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(290, 62),
		ZIndex = 24,
	})
	done.label.FontFace = F.Display
	local cap = done.label:FindFirstChildOfClass("UITextSizeConstraint")
	if cap then
		cap.MaxTextSize = 34
	end
	done.instance.Parent = box
	-- a shine sweeping across the button
	local shine = Ui.frame({
		Name = "Shine",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 26,
		Parent = done.instance,
	}, {
		Ui.corner(18),
		Ui.new("UIGradient", {
			Rotation = 20,
			Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(0.55, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	if not reduced then
		local grad = shine:FindFirstChildOfClass("UIGradient") :: UIGradient
		TweenService:Create(
			grad,
			TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1.2),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	else
		shine.Visible = false
	end
	Ui.popIn(done.instance, reduced)
	if mode == "Ranked" then
		local again = Ui.button("PLAY AGAIN", "secondary", function()
			close(function()
				ctx.open("Play")
			end)
		end, {
			Name = "PlayAgain",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 160, 1, -18),
			Size = UDim2.fromOffset(150, 48),
			ZIndex = 24,
		})
		again.label.FontFace = F.Display
		again.instance.Parent = box
	end
	return box
end

return BattleResult
