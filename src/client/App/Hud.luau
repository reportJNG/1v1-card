--!strict
-- The in-game HUD (MISSION section 3, docs/brief/ui-refs-3/01-ingame-hud.png): clean, light and
-- mostly icons, so the screen stays game world.
--   left          a 2 x 3 grid of chunky square buttons, each its own colour, no labels (a tooltip
--                 on hover or long press): Inventory, Eggs, Deck, Daily, Worlds, Settings
--   top-left      a small Menu button (the leaving screen)
--   top-right     two big currency bars, Coins and Gems, short amounts (1.04K), "+" buttons
--   bottom centre the deck bar: the 3 equipped cards with level, stage stars and slot number;
--                 the 1v1 Arena button beside it
--   right         a compact quest card (title, done / total, two task rows with a check box and a
--                 thin bar); it collapses to a trophy with a progress ring when tapped or after
--                 10 s idle
--   world only    a Lobby button under the grid
-- Buttons are about 68 px on PC and 56 px on phones (never under 44 px). Pieces slide off their
-- nearest edge for the UiFlow HUD modes (full / currencies / hidden); battles hide everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Evolution = require(Shared.Domain.Evolution)
local HudBadges = require(Shared.Ui.HudBadges)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.Kit)
local Card = require(script.Parent.Card)
local Format = require(script.Parent.Format)
local Sfx = require(script.Parent.Sfx)

local C = Theme.Color
local F = Theme.Face

local Hud = {}

export type Hud = {
	refresh: () -> (),
	select: (id: string?) -> (),
	setMode: (mode: string, instant: boolean?) -> (),
	layout: (width: number, scale: number?) -> (),
	-- Where gains fly to (App/WorldText): "coins", "gems", "bag", "worlds", "quests", "deck".
	target: (name: string) -> GuiObject?,
}

-- The six grid buttons (MISSION 3.1 colours). `badge` is the HudBadges dot that lights it.
local GRID: { { id: string, icon: string, tip: string, color: string, badge: string? } } = {
	{ id = "Collection", icon = "icon_cards", tip = "Inventory", color = "red", badge = nil },
	{ id = "Shop", icon = "icon_shop", tip = "Eggs", color = "orange", badge = "Shop" },
	{ id = "Deck", icon = "icon_deck", tip = "Deck", color = "teal", badge = "Deck" },
	{ id = "Quests", icon = "icon_gift", tip = "Daily", color = "green", badge = "Quests" },
	{ id = "Worlds", icon = "icon_worlds", tip = "Worlds", color = "purple", badge = nil },
	{ id = "Settings", icon = "icon_settings", tip = "Settings", color = "blue", badge = nil },
}

local IDLE_COLLAPSE = 10 -- s

local function outline(label: TextLabel, thickness: number?)
	Ui.outline(C.Night, thickness or 2).Parent = label
end

function Hud.build(ctx: any, root: Frame): Hud
	local B = 52 -- button size in design px (set by layout)
	local reduced = ctx.reducedMotion()

	-- A chunky square button: coloured base, big icon, notification dot, tooltip.
	local function squareButton(
		name: string,
		color: string,
		icon: string,
		tip: string,
		onClick: () -> ()
	): (ImageButton, Frame)
		local b: ImageButton = Ui.new("ImageButton", {
			Name = name,
			Image = Kit.id(`hud_btn_{color}`),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromOffset(B, B),
		})
		Ui.icon(icon, math.floor(B * 0.62), {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.48),
			Size = UDim2.fromScale(0.62, 0.62),
			ZIndex = 2,
			Parent = b,
		})
		local dot = Ui.frame({
			Name = "Dot",
			BackgroundColor3 = C.Red,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(14, 14),
			Visible = false,
			ZIndex = 4,
			Parent = b,
		}, { Ui.corner(7), Ui.stroke(C.Night, 2) })
		if not reduced then
			local beat = Ui.new("UIScale", { Parent = dot })
			TweenService:Create(
				beat,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.2),
				{ Scale = 1.3 }
			):Play()
		end
		-- Tooltip: hover (PC) or long press (touch).
		local tipLabel = Ui.text({
			Name = "Tip",
			Text = tip,
			FontFace = F.Title,
			TextSize = 14,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.Night,
			BackgroundTransparency = 0.2,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 8, 0.5, 0),
			Size = UDim2.fromOffset(0, 24),
			Visible = false,
			ZIndex = 20,
			Parent = b,
		})
		Ui.pad(6).Parent = tipLabel
		Ui.corner(6).Parent = tipLabel
		b.MouseEnter:Connect(function()
			tipLabel.Visible = true
		end)
		b.MouseLeave:Connect(function()
			tipLabel.Visible = false
		end)
		local pressAt = 0
		b.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				pressAt = os.clock()
				task.delay(0.45, function()
					if pressAt > 0 and os.clock() - pressAt >= 0.44 then
						tipLabel.Visible = true
						task.delay(1.5, function()
							tipLabel.Visible = false
						end)
					end
				end)
			end
		end)
		b.InputEnded:Connect(function()
			pressAt = 0
		end)
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("click")
			onClick()
		end)
		return b, dot
	end

	-- Menu (top-left, small): back to the main menu through the leaving screen.
	local menuButton = squareButton("MenuButton", "night", "icon_home", "Main menu", function()
		ctx.leaveToMenu()
	end)
	menuButton.Position = UDim2.fromOffset(10, 52) -- under Roblox's own top-left buttons
	menuButton.Parent = root

	-- The 2 x 3 grid (left).
	local grid = Ui.frame({
		Name = "Grid",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = root,
	})
	local gridLayout = Ui.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2,
		Parent = grid,
	})
	local buttons: { [string]: { button: ImageButton, dot: Frame } } = {}
	for i, item in GRID do
		local b, dot = squareButton(item.id, item.color, item.icon, item.tip, function()
			ctx.open(item.id)
		end)
		b.LayoutOrder = i
		b.Parent = grid
		buttons[item.id] = { button = b, dot = dot }
	end

	-- Lobby (under the grid, only in a world).
	local lobby = squareButton("Lobby", "night", "icon_home", "Back to the lobby", function()
		ctx.request("World.Hub")
	end)
	lobby.AnchorPoint = Vector2.new(0, 0)
	lobby.Parent = root

	-- Currency bars (top-right).
	local top = Ui.frame({
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(420, 44),
		Parent = root,
	}, { Ui.list(true, 14, Enum.HorizontalAlignment.Right) })
	local function bar(
		name: string,
		kind: string,
		icon: string,
		width: number,
		order: number,
		onPlus: () -> ()
	): TextLabel
		local f = Ui.frame({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, 40),
			LayoutOrder = order,
			Parent = top,
		})
		Kit.image(`currency_bar_{kind}`, {
			Name = "Skin",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 47, 336, 49),
			SliceScale = 0.42,
			Size = UDim2.fromScale(1, 1),
			Parent = f,
		})
		Ui.icon(icon, 48, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			ZIndex = 2,
			Parent = f,
		})
		local value = Ui.text({
			Name = "Value",
			Text = "0",
			FontFace = F.Number,
			TextSize = 22,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -72, 1, 0),
			ZIndex = 2,
			Parent = f,
		})
		outline(value, 2)
		local plus: ImageButton = Ui.new("ImageButton", {
			Name = "Plus",
			Image = Kit.id(`plus_{kind}`),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			ZIndex = 3,
			Parent = f,
		})
		Ui.juice(plus)
		plus.Activated:Connect(function()
			Ui.sound("click")
			onPlus()
		end)
		return value
	end
	local coins = bar("Coins", "gold", "icon_coin", 200, 1, function()
		ctx.open("Tip", { kind = "coins" }) -- Coins are earned, never sold
	end)
	local gems = bar("Gems", "blue", "icon_gem", 150, 2, function()
		ctx.open("Tip", { kind = "gems" })
	end)

	-- The deck bar (bottom centre) and the 1v1 button beside it.
	local deckBar: TextButton = Ui.new("TextButton", {
		Name = "DeckBar",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(3 * 70 + 2 * 10, 112),
		Parent = root,
	})
	deckBar.Activated:Connect(function()
		Ui.sound("click")
		ctx.open("Deck")
	end)
	local arena = squareButton("Arena", "orange", "icon_play", "1v1 Arena", function()
		ctx.open("Play")
	end)
	arena.AnchorPoint = Vector2.new(1, 1)
	arena.Parent = root

	-- The quest card (right), collapsing to a trophy with a ring.
	local quest: TextButton = Ui.new("TextButton", {
		Name = "QuestCard",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(230, 118),
		Parent = root,
	})
	local questBody = Kit.image("quest_card", {
		Name = "Body",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(40, 64, 472, 280),
		SliceScale = 0.45,
		Size = UDim2.fromScale(1, 1),
		Parent = quest,
	})
	local questTitle = Ui.display({
		Name = "Title",
		Text = "DAILY",
		TextSize = 20,
		TextColor3 = C.GoldHi,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.new(1, -20, 0, 22),
		ZIndex = 2,
		Parent = questBody,
	})
	local questCount = Ui.text({
		Name = "Count",
		Text = "0/0",
		FontFace = F.Number,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 27),
		Size = UDim2.fromOffset(46, 16),
		ZIndex = 2,
		Parent = questBody,
	})
	Ui.corner(8).Parent = questCount
	local rowFrames: { { frame: Frame, text: TextLabel, check: Frame, tick: GuiObject, setBar: (number) -> () } } =
		{}
	for i = 1, 2 do
		local y = 46 + (i - 1) * 34
		local r = Ui.frame({
			Name = `Row{i}`,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, y),
			Size = UDim2.new(1, -24, 0, 32),
			ZIndex = 2,
			Parent = questBody,
		})
		local text = Ui.text({
			Name = "Text",
			Text = "",
			FontFace = F.Bold,
			TextSize = 13,
			TextWrapped = false,
			Size = UDim2.new(1, -24, 0, 16),
			ZIndex = 3,
			Parent = r,
		})
		outline(text, 1.2)
		local check = Ui.frame({
			Name = "Check",
			BackgroundColor3 = C.Night,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(16, 16),
			ZIndex = 3,
			Parent = r,
		}, { Ui.corner(3), Ui.stroke(C.White, 1.5, 0.1) })
		local tick = Ui.image("icon_check", {
			Name = "Tick",
			Size = UDim2.fromScale(1.1, 1.1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = false,
			ZIndex = 4,
			Parent = check,
		})
		local setBar = Ui.bar(r, C.Gold, {
			Position = UDim2.fromOffset(0, 20),
			Size = UDim2.new(1, 0, 0, 7),
			ZIndex = 3,
		})
		rowFrames[i] = { frame = r, text = text, check = check, tick = tick, setBar = setBar }
	end
	-- Collapsed: a trophy button with a progress ring.
	local trophy = Ui.new("ImageButton", {
		Name = "QuestTrophy",
		Image = Kit.id("hud_btn_night"),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(B, B),
		Visible = false,
		Parent = root,
	})
	Ui.icon("icon_trophy", math.floor(B * 0.6), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		ZIndex = 2,
		Parent = trophy,
	})
	local ring = Ui.new("UIStroke", { Color = C.Gold, Thickness = 3, Transparency = 0.1, Parent = trophy })
	local ringGrad = Ui.new("UIGradient", {
		Transparency = NumberSequence.new(0),
		Parent = ring,
	})
	Ui.juice(trophy)
	Ui.juice(quest)

	local collapsed = false
	local lastTouch = os.clock()
	local hasQuest = false
	local mode = "full"

	-- HUD modes: pieces slide off their nearest edge and back.
	local wanted: { [GuiObject]: boolean } = { [lobby] = false, [quest] = false, [trophy] = false }
	local pieces: { { obj: GuiObject, dir: Vector2, keep: boolean } } = {
		{ obj = menuButton, dir = Vector2.new(-1, 0), keep = false },
		{ obj = grid, dir = Vector2.new(-1, 0), keep = false },
		{ obj = lobby, dir = Vector2.new(-1, 0), keep = false },
		{ obj = top, dir = Vector2.new(0, -1), keep = true },
		{ obj = deckBar, dir = Vector2.new(0, 1), keep = false },
		{ obj = arena, dir = Vector2.new(0, 1), keep = false },
		{ obj = quest, dir = Vector2.new(1, 0), keep = false },
		{ obj = trophy, dir = Vector2.new(1, 0), keep = false },
	}
	local homes: { [GuiObject]: UDim2 } = {}
	local function home(obj: GuiObject): UDim2
		return homes[obj] or obj.Position
	end
	local function setMode(m: string, instant: boolean?)
		if m == "full" and mode ~= "full" then
			lastTouch = os.clock() -- the quest card shows for 10 s each time the HUD comes back
		end
		mode = m
		local info = if instant or reduced
			then TweenInfo.new(0.01)
			else TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for i, piece in pieces do
			local obj = piece.obj
			local h = home(obj)
			homes[obj] = h
			local show = m == "full" or (m == "currencies" and piece.keep)
			local away = h + UDim2.fromOffset(piece.dir.X * 400, piece.dir.Y * 200)
			if show and wanted[obj] ~= false then
				obj.Visible = true
			end
			-- The HUD drops in one piece after another (MISSION 10, main menu -> playing).
			local delay = if show and not instant then (i - 1) * 0.04 else 0
			task.delay(delay, function()
				local tween = TweenService:Create(obj, info, { Position = if show then h else away })
				tween.Completed:Connect(function()
					if mode == m then
						obj.Visible = show and wanted[obj] ~= false
					end
				end)
				tween:Play()
			end)
		end
	end
	local function want(obj: GuiObject, on: boolean)
		wanted[obj] = on
		obj.Visible = on and mode == "full"
	end
	local function setCollapsed(c: boolean)
		collapsed = c
		want(quest, hasQuest and not c)
		want(trophy, hasQuest and c)
	end
	quest.Activated:Connect(function()
		Ui.sound("click")
		lastTouch = os.clock()
		setCollapsed(true)
	end)
	trophy.Activated:Connect(function()
		Ui.sound("click")
		lastTouch = os.clock()
		setCollapsed(false)
	end)
	task.spawn(function()
		while root.Parent do
			task.wait(1)
			if not collapsed and hasQuest and os.clock() - lastTouch > IDLE_COLLAPSE then
				setCollapsed(true)
			end
		end
	end)

	-- Currency count-up, pulse and a floating "+N".
	local shown: { [string]: number } = {}
	local function setCount(label: TextLabel, key: string, value: number)
		local before = shown[key]
		shown[key] = value
		if before == nil or before == value or reduced then
			label.Text = Format.short(value)
			return
		end
		Ui.countUp(label, before, value, Format.short)
		Ui.pulse(label.Parent :: GuiObject, 0.08)
		if value > before then
			Sfx.coins(value - before)
			local pop = Ui.text({
				Text = `+{Format.short(value - before)}`,
				FontFace = F.Number,
				TextSize = 20,
				TextColor3 = if key == "gems" then C.Blue else C.Gold,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(120, 24),
				ZIndex = 5,
				Parent = label.Parent,
			})
			outline(pop, 2)
			local rise = TweenService:Create(
				pop,
				TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(0.5, 0, 1, 40), TextTransparency = 1 }
			)
			rise.Completed:Connect(function()
				pop:Destroy()
			end)
			rise:Play()
		end
	end

	-- The deck bar's cards, rebuilt only when the deck or a level changes.
	local deckKey = ""
	local function renderDeck(v: any)
		local parts = {}
		for i = 1, 3 do
			local uid = v.deck[i]
			local c = uid and v.cards[uid]
			table.insert(parts, if c then `{c.characterId}:{c.level}:{c.golden}` else "-")
		end
		local key = table.concat(parts, "|")
		if key == deckKey then
			return
		end
		deckKey = key
		Ui.clear(deckBar)
		local size = Vector2.new(70, 98)
		for i = 1, 3 do
			local uid = v.deck[i]
			local c = uid and v.cards[uid]
			local cell = Ui.frame({
				Name = `Slot{i}`,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset((i - 1) * (size.X + 10), 0),
				Size = UDim2.fromOffset(size.X, 112),
				Parent = deckBar,
			})
			if c then
				Card.build(cell, {
					characterId = c.characterId,
					golden = c.golden,
					level = c.level,
					size = size,
					stats = false,
				})
				-- Stage stars under the card (Base 1 .. Max 4).
				local _, stage = Evolution.stageAt(c.level)
				local stars = Ui.frame({
					Name = "Stars",
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(0, size.Y + 1),
					Size = UDim2.new(1, 0, 0, 12),
					Parent = cell,
				}, { Ui.list(true, 1, Enum.HorizontalAlignment.Center) })
				for _ = 1, stage do
					Kit.image("emblem_star_gold", { Size = UDim2.fromOffset(12, 12), Parent = stars })
				end
			else
				Kit.image("empty_slot", {
					Name = "Empty",
					Size = UDim2.fromOffset(size.X, size.Y),
					Parent = cell,
				})
			end
			-- The slot number in the corner.
			local num = Ui.text({
				Name = "Slot",
				Text = tostring(i),
				FontFace = F.Number,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Center,
				BackgroundColor3 = C.Night,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromOffset(size.X + 2, size.Y + 2),
				Size = UDim2.fromOffset(18, 18),
				ZIndex = 60,
				Parent = cell,
			})
			Ui.corner(4).Parent = num
			Ui.stroke(C.White, 1.5, 0.2).Parent = num
		end
	end

	local api: Hud
	api = {
		refresh = function()
			want(lobby, ctx.state.area ~= 0)
			local v = ctx.state.view
			if v == nil then
				return
			end
			local dots = HudBadges.dots(v, ctx.now())
			for _, item in GRID do
				local b = buttons[item.id]
				b.dot.Visible = item.badge ~= nil and (dots :: any)[item.badge] == true
			end
			setCount(coins, "coins", v.coins)
			setCount(gems, "gems", v.gems)
			renderDeck(v)
			local card = HudBadges.questCard(v)
			hasQuest = card ~= nil
			if card then
				questTitle.Text = string.upper(card.title)
				questCount.Text = `{card.done}/{card.total}`
				for i, rf in rowFrames do
					local row = card.rows[i]
					rf.frame.Visible = row ~= nil
					if row then
						rf.text.Text = `{row.text} [{Format.short(row.progress)}/{Format.short(row.target)}]`
						Ui.fit(rf.text, 13, 9)
						rf.tick.Visible = row.done
						rf.setBar(row.progress / math.max(1, row.target))
					end
				end
				ringGrad.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(
						math.clamp(card.done / math.max(1, card.total), 0.001, 0.998),
						0
					),
					NumberSequenceKeypoint.new(
						math.clamp(card.done / math.max(1, card.total) + 0.001, 0.002, 0.999),
						0.85
					),
					NumberSequenceKeypoint.new(1, 0.85),
				})
			end
			setCollapsed(collapsed)
		end,
		setMode = setMode,
		-- Sizes: about 68 px buttons on PC, 56 px on phones, never under 44 px (physical).
		layout = function(width: number, scale: number?)
			local s = scale or 1
			local physical = if s >= 1.6 then 68 else 56
			B = math.floor(math.max(44, physical) / s)
			gridLayout.CellSize = UDim2.fromOffset(B, B)
			grid.Size = UDim2.fromOffset(2 * B + 8, 3 * B + 16)
			for _, b in { menuButton, lobby, arena, trophy } do
				b.Size = UDim2.fromOffset(B, B)
			end
			menuButton.Size = UDim2.fromOffset(math.floor(B * 0.8), math.floor(B * 0.8))
			homes[lobby] = UDim2.new(0, 10, 0.5, (3 * B + 16) / 2 + 10)
			homes[menuButton] = UDim2.fromOffset(10, 52)
			homes[arena] = UDim2.new(0.5, -(3 * 70 + 20) / 2 - 12, 1, -12)
			homes[deckBar] = UDim2.new(0.5, 0, 1, -8)
			-- Narrow screens: the quest card moves under the currency bars and stays smaller.
			homes[quest] = UDim2.new(1, -12, 0, 60)
			homes[trophy] = UDim2.new(1, -12, 0, 60)
			quest.Size = UDim2.fromOffset(if width < 760 then 190 else 230, 118)
			setMode(mode, true)
		end,
		target = function(name: string): GuiObject?
			local key = ({
				coins = "Coins",
				gems = "Gems",
				bag = "Collection",
				worlds = "Worlds",
				quests = "QuestCard",
				deck = "DeckBar",
			})[name]
			local found = key and root:FindFirstChild(key, true)
			if found and found:IsA("GuiObject") then
				if name == "quests" and not found.Visible then
					local badge = root:FindFirstChild("QuestTrophy", true)
					return if badge and badge:IsA("GuiObject") then badge else nil
				end
				return found
			end
			return nil
		end,
		select = function(id: string?)
			for key, b in buttons do
				local stroke = b.button:FindFirstChild("Selected") :: UIStroke?
				if key == id and stroke == nil then
					Ui.new("UIStroke", {
						Name = "Selected",
						Color = C.GoldHi,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Parent = b.button,
					})
				elseif key ~= id and stroke then
					stroke:Destroy()
				end
			end
		end,
	}
	return api
end

return Hud
