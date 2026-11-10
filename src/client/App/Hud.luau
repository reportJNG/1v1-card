--!strict
-- The in-game HUD, clean (BAD_GUI_5_INGAME_HUD.md, which replaces MISSION section 3). Only these
-- are on screen while playing:
--   left          2 x 2 big chunky buttons with a big label on the bottom edge: CARDS, EGGS,
--                 WORLDS, 1v1 (notification dots bounce; an idle shimmer runs across one now and
--                 then); on touch screens the grid sits higher, clear of the thumbstick
--   top-left      a small round "≡" menu: Settings, Quests, Main Menu, and Back to Lobby in a world
--   top-right     the Coins and Gems pills (big coin / diamond over the left end, big number, a
--                 glossy "+"), and a gift button under them only while something is claimable
--   right         the quest panel: TUTORIAL until the first-session steps are done, then the
--                 dailies; tap to collapse it to a trophy badge (collapsed by default on phones)
--   bottom centre the deck bar: 3 tall art-first cards (big level, stage stars, slot number, no
--                 names); tapping it opens the Deck Builder
-- Everything else is off the screen; messages are pops at their source (App/WorldText). Pieces slide
-- off their nearest edge for the UiFlow HUD modes (full / currencies / hidden); battles hide all.
-- Images are today's kit (TEMP) until the owner's E1-E4 sheets are cut, approved and uploaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
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
	layout: (width: number, scale: number?, height: number?) -> (),
	-- Where gains fly to (App/WorldText): "coins", "gems", "bag", "worlds", "quests", "deck".
	target: (name: string) -> GuiObject?,
}

-- The four buttons (BAD_GUI_5 section 2.1). `badge` is the HudBadges dot that lights it.
local GRID: { { id: string, icon: string, label: string, color: string, badge: string? } } = {
	{ id = "Collection", icon = "icon_cards", label = "CARDS", color = "red", badge = nil },
	{ id = "Shop", icon = "icon_shop", label = "EGGS", color = "orange", badge = "Shop" },
	{ id = "Worlds", icon = "icon_worlds", label = "WORLDS", color = "purple", badge = nil },
	{ id = "Play", icon = "icon_play", label = "1v1", color = "teal", badge = nil },
}

local IDLE_COLLAPSE = 10 -- s
local SHIMMER_EVERY = 4 -- s between idle shimmers on the grid

local function outline(label: TextLabel, thickness: number?)
	Ui.outline(C.Night, thickness or 2).Parent = label
end

-- A red dot that beats (notifications).
local function dot(parent: GuiObject, reduced: boolean): Frame
	local d = Ui.frame({
		Name = "Dot",
		BackgroundColor3 = C.Red,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(18, 18),
		Visible = false,
		ZIndex = 6,
		Parent = parent,
	}, { Ui.corner(9), Ui.stroke(C.Night, 2.5) })
	if not reduced then
		local beat = Ui.new("UIScale", { Parent = d })
		TweenService:Create(
			beat,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true, 0.9),
			{ Scale = 1.35 }
		):Play()
	end
	return d
end

function Hud.build(ctx: any, root: Frame): Hud
	local B = 76 -- grid button size in design px (set by layout)
	local reduced = ctx.reducedMotion()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	-- A big chunky square button with its label on the bottom edge.
	local function bigButton(
		name: string,
		color: string,
		icon: string,
		text: string,
		onClick: () -> ()
	): (ImageButton, Frame)
		local b: ImageButton = Ui.new("ImageButton", {
			Name = name,
			Image = Kit.id(`hud_btn_{color}`),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromOffset(B, B),
		})
		Ui.icon(icon, math.floor(B * 0.6), {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromScale(0.6, 0.6),
			ZIndex = 2,
			Parent = b,
		})
		local label = Ui.display({
			Name = "Label",
			Text = text,
			TextSize = 20,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, 8, 0, 22),
			ZIndex = 3,
			Parent = b,
		})
		label.TextColor3 = C.White
		outline(label, 3)
		Ui.fit(label, 20, 12)
		local d = dot(b, reduced)
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("click")
			onClick()
		end)
		return b, d
	end

	-- ≡ menu (top-left, small and round, under Roblox's own top-left buttons).
	local menuButton: ImageButton = Ui.new("ImageButton", {
		Name = "MenuButton",
		Image = Kit.id("hud_btn_night"),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		Position = UDim2.fromOffset(10, 52),
		Size = UDim2.fromOffset(46, 46),
		Parent = root,
	})
	local burger = Ui.display({
		Name = "Glyph",
		Text = "≡",
		TextSize = 34,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = menuButton,
	})
	burger.TextColor3 = C.White
	outline(burger, 2)
	Ui.juice(menuButton)
	local dropdown = Ui.frame({
		Name = "MenuDropdown",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.fromOffset(210, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	Ui.skin(dropdown, "panel", 0.5)
	-- the rows live in their own frame: the skin is a child too, and a list layout would stack it
	local rows = Ui.frame({
		Name = "Rows",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 20,
		Parent = dropdown,
	}, { Ui.pad(10), Ui.list(false, 6) })
	local inWorld = false
	local function menuRow(order: number, icon: string, text: string, onClick: () -> ()): TextButton
		local row: TextButton = Ui.new("TextButton", {
			Name = text,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 21,
			Parent = rows,
		})
		Ui.skin(row, "tile", 0.45)
		Ui.icon(icon, 34, { Position = UDim2.new(0, 22, 0.5, 0), ZIndex = 22, Parent = row })
		local t = Ui.display({
			Text = text,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(1, -52, 1, 0),
			ZIndex = 22,
			Parent = row,
		})
		t.TextColor3 = C.White
		outline(t, 2)
		Ui.fit(t, 22, 14)
		Ui.juice(row)
		row.Activated:Connect(function()
			Ui.sound("click")
			dropdown.Visible = false
			onClick()
		end)
		return row
	end
	menuRow(1, "icon_settings", "SETTINGS", function()
		ctx.open("Settings")
	end)
	menuRow(2, "icon_quests", "QUESTS", function()
		ctx.open("Quests")
	end)
	local lobbyRow = menuRow(3, "icon_worlds", "LOBBY", function()
		ctx.request("World.Hub")
	end)
	menuRow(4, "icon_home", "MAIN MENU", function()
		ctx.leaveToMenu()
	end)
	menuButton.Activated:Connect(function()
		Ui.sound("click")
		lobbyRow.Visible = inWorld
		dropdown.Visible = not dropdown.Visible
		if dropdown.Visible then
			Ui.popIn(dropdown, reduced)
		end
	end)

	-- The 2 x 2 grid (left).
	local grid = Ui.frame({
		Name = "Grid",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = root,
	})
	local gridLayout = Ui.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2,
		Parent = grid,
	})
	local buttons: { [string]: { button: ImageButton, dot: Frame } } = {}
	for i, item in GRID do
		local b, d = bigButton(item.id, item.color, item.icon, item.label, function()
			ctx.open(item.id)
		end)
		b.LayoutOrder = i
		b.Parent = grid
		buttons[item.id] = { button = b, dot = d }
	end
	-- An idle shimmer runs across one grid button every few seconds (BAD_GUI_5 section 2.1).
	if not reduced then
		task.spawn(function()
			local turn = 0
			while root.Parent do
				task.wait(SHIMMER_EVERY)
				turn = turn % #GRID + 1
				local b = buttons[GRID[turn].id].button
				if b.Visible and grid.Visible then
					local clip = Ui.frame({
						Name = "Shimmer",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 4,
						Parent = b,
					}, { Ui.corner(14) })
					local band = Ui.image("card_shine", {
						ScaleType = Enum.ScaleType.Stretch,
						ImageTransparency = 0.45,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(-0.4, 0.5),
						Size = UDim2.fromScale(0.35, 1.4),
						Rotation = 20,
						ZIndex = 4,
						Parent = clip,
					})
					local tw = TweenService:Create(
						band,
						TweenInfo.new(0.6, Enum.EasingStyle.Quad),
						{ Position = UDim2.fromScale(1.4, 0.5) }
					)
					tw.Completed:Connect(function()
						clip:Destroy()
					end)
					tw:Play()
				end
			end
		end)
	end

	-- Currency pills (top-right) and the gift under them.
	local top = Ui.frame({
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(480, 52),
		Parent = root,
	}, { Ui.list(true, 18, Enum.HorizontalAlignment.Right) })
	local function pill(
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
			Size = UDim2.fromOffset(width, 48),
			LayoutOrder = order,
			Parent = top,
		})
		Kit.image(`currency_bar_{kind}`, {
			Name = "Skin",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 47, 336, 49),
			SliceScale = 0.5,
			Size = UDim2.fromScale(1, 1),
			Parent = f,
		})
		-- the big coin / diamond overlaps the pill's left end
		Ui.icon(icon, 62, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			ZIndex = 3,
			Parent = f,
		})
		local value = Ui.text({
			Name = "Value",
			Text = "0",
			FontFace = F.Display,
			TextSize = 30,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -78, 1, 0),
			ZIndex = 2,
			Parent = f,
		})
		value.TextColor3 = C.White
		outline(value, 3)
		local plus: ImageButton = Ui.new("ImageButton", {
			Name = "Plus",
			Image = Kit.id(`plus_{kind}`),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
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
	local coins = pill("Coins", "gold", "icon_coin", 230, 1, function()
		ctx.open("Tip", { kind = "coins" }) -- Coins are earned, never sold
	end)
	local gems = pill("Gems", "blue", "icon_gem", 170, 2, function()
		ctx.open("Tip", { kind = "gems" })
	end)
	local gift: ImageButton = Ui.new("ImageButton", {
		Name = "Gift",
		Image = Kit.id("hud_btn_green"),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 66),
		Size = UDim2.fromOffset(58, 58),
		Visible = false,
		Parent = root,
	})
	Ui.icon("icon_gift", 40, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		ZIndex = 2,
		Parent = gift,
	})
	local giftDot = dot(gift, reduced)
	giftDot.Visible = true
	Ui.juice(gift)
	gift.Activated:Connect(function()
		Ui.sound("click")
		ctx.open("Quests")
	end)
	if not reduced then
		local bob = Ui.new("UIScale", { Parent = gift })
		TweenService:Create(
			bob,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, -1, true, 1.4),
			{ Scale = 1.12 }
		):Play()
	end

	-- The deck bar (bottom centre): tap it to open the Deck Builder.
	local CW, CH = 112, 156 -- card size (set by layout)
	local deckBar: TextButton = Ui.new("TextButton", {
		Name = "DeckBar",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(3 * CW + 2 * 12, CH + 14),
		Parent = root,
	})
	local deckDot = dot(deckBar, reduced)
	deckBar.Activated:Connect(function()
		Ui.sound("click")
		ctx.open("Deck")
	end)

	-- The quest panel (right), collapsing to a trophy badge.
	local quest: TextButton = Ui.new("TextButton", {
		Name = "QuestCard",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 132),
		Size = UDim2.fromOffset(270, 150),
		Parent = root,
	})
	local questBody = Kit.image("quest_card", {
		Name = "Body",
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(40, 64, 472, 280),
		SliceScale = 0.5,
		Size = UDim2.fromScale(1, 1),
		Parent = quest,
	})
	local questTitle = Ui.display({
		Name = "Title",
		Text = "TUTORIAL",
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -70, 0, 30),
		ZIndex = 2,
		Parent = questBody,
	}, true)
	Ui.fit(questTitle, 26, 16)
	Ui.icon("icon_trophy", 40, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 2),
		ZIndex = 3,
		Parent = questBody,
	})
	local questCount = Ui.text({
		Name = "Count",
		Text = "0/0",
		FontFace = F.Display,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = C.Night,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.fromOffset(58, 22),
		ZIndex = 2,
		Parent = questBody,
	})
	questCount.TextColor3 = C.White
	Ui.corner(11).Parent = questCount
	local rowFrames: { { frame: Frame, text: TextLabel, check: Frame, tick: GuiObject, setBar: (number) -> () } } =
		{}
	for i = 1, 2 do
		local r = Ui.frame({
			Name = `Row{i}`,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16, 64 + (i - 1) * 40),
			Size = UDim2.new(1, -32, 0, 36),
			ZIndex = 2,
			Parent = questBody,
		})
		local text = Ui.text({
			Name = "Text",
			Text = "",
			FontFace = F.Title,
			TextSize = 17,
			TextWrapped = false,
			Size = UDim2.new(1, -30, 0, 20),
			ZIndex = 3,
			Parent = r,
		})
		outline(text, 2)
		local check = Ui.frame({
			Name = "Check",
			BackgroundColor3 = C.Night,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 3,
			Parent = r,
		}, { Ui.corner(4), Ui.stroke(C.White, 2, 0.1) })
		local tick = Ui.image("icon_check", {
			Name = "Tick",
			Size = UDim2.fromScale(1.2, 1.2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = false,
			ZIndex = 4,
			Parent = check,
		})
		local setBar = Ui.bar(r, C.Gold, {
			Position = UDim2.fromOffset(0, 25),
			Size = UDim2.new(1, -30, 0, 8),
			ZIndex = 3,
		})
		rowFrames[i] = { frame = r, text = text, check = check, tick = tick, setBar = setBar }
	end
	-- Collapsed: a trophy badge with a progress ring.
	local trophy = Ui.new("ImageButton", {
		Name = "QuestTrophy",
		Image = Kit.id("hud_btn_night"),
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 132),
		Size = UDim2.fromOffset(60, 60),
		Visible = false,
		Parent = root,
	})
	Ui.icon("icon_trophy", 36, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6),
		ZIndex = 2,
		Parent = trophy,
	})
	local ring = Ui.new("UIStroke", { Color = C.Gold, Thickness = 3, Transparency = 0.1, Parent = trophy })
	local ringGrad = Ui.new("UIGradient", { Transparency = NumberSequence.new(0), Parent = ring })
	Ui.juice(trophy)
	Ui.juice(quest)

	local collapsed = touch -- phones start with the badge (BAD_GUI_5 section 4)
	local lastTouch = os.clock()
	local hasQuest = false
	local tutorial = false
	local mode = "full"
	local lastRows: { [number]: string } = {}

	-- HUD modes: pieces slide off their nearest edge and back.
	local wanted: { [GuiObject]: boolean } = { [quest] = false, [trophy] = false, [gift] = false }
	local pieces: { { obj: GuiObject, dir: Vector2, keep: boolean } } = {
		{ obj = menuButton, dir = Vector2.new(-1, 0), keep = false },
		{ obj = grid, dir = Vector2.new(-1, 0), keep = false },
		{ obj = top, dir = Vector2.new(0, -1), keep = true },
		{ obj = gift, dir = Vector2.new(1, 0), keep = false },
		{ obj = deckBar, dir = Vector2.new(0, 1), keep = false },
		{ obj = quest, dir = Vector2.new(1, 0), keep = false },
		{ obj = trophy, dir = Vector2.new(1, 0), keep = false },
	}
	local homes: { [GuiObject]: UDim2 } = {}
	local function home(obj: GuiObject): UDim2
		return homes[obj] or obj.Position
	end
	local function setMode(m: string, instant: boolean?)
		if m == "full" and mode ~= "full" then
			lastTouch = os.clock()
		end
		mode = m
		if m ~= "full" then
			dropdown.Visible = false
		end
		local info = if instant or reduced
			then TweenInfo.new(0.01)
			else TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for i, piece in pieces do
			local obj = piece.obj
			local h = home(obj)
			homes[obj] = h
			local show = m == "full" or (m == "currencies" and piece.keep)
			local away = h + UDim2.fromOffset(piece.dir.X * 420, piece.dir.Y * 240)
			if show and wanted[obj] ~= false then
				obj.Visible = true
			end
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
			-- the tutorial stays open for new players; only the dailies tuck away when idle
			if not collapsed and hasQuest and not tutorial and os.clock() - lastTouch > IDLE_COLLAPSE then
				setCollapsed(true)
			end
		end
	end)

	-- Currency count-up and pulse (the "+N" pop and the flying icons come from App/WorldText).
	local shown: { [string]: number } = {}
	local function setCount(label: TextLabel, key: string, value: number)
		local before = shown[key]
		shown[key] = value
		if before == nil or before == value or reduced then
			label.Text = Format.short(value)
			return
		end
		Ui.countUp(label, before, value, Format.short)
		Ui.pulse(label.Parent :: GuiObject, 0.1)
		if value > before then
			Sfx.coins(value - before)
		end
	end

	-- The deck bar's cards, rebuilt only when the deck, a level or the card size changes.
	local deckKey = ""
	local function renderDeck(v: any)
		local parts = { `{CW}x{CH}` }
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
		for _, ch in deckBar:GetChildren() do
			if ch:IsA("GuiObject") and ch ~= deckDot then
				ch:Destroy()
			end
		end
		local size = Vector2.new(CW, CH)
		deckBar.Size = UDim2.fromOffset(3 * CW + 2 * 12, CH + 14)
		for i = 1, 3 do
			local uid = v.deck[i]
			local c = uid and v.cards[uid]
			local cell = Ui.frame({
				Name = `Slot{i}`,
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset((i - 1) * (CW + 12), 0),
				Size = UDim2.fromOffset(CW, CH + 14),
				Parent = deckBar,
			})
			if c then
				Card.build(cell, {
					characterId = c.characterId,
					golden = c.golden,
					level = c.level,
					size = size,
					stats = false,
					bare = true,
				})
				-- a big level top-right
				local lv = Ui.display({
					Name = "BigLevel",
					Text = `Lv.{c.level}`,
					TextSize = math.floor(CW * 0.2),
					TextXAlignment = Enum.TextXAlignment.Right,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.new(0.6, 0, 0, math.floor(CW * 0.22)),
					ZIndex = 60,
					Parent = cell,
				})
				lv.TextColor3 = C.White
				outline(lv, 3)
				-- stage stars on a dark strip at the bottom
				local _, stage = Evolution.stageAt(c.level)
				local strip = Ui.frame({
					Name = "Stars",
					BackgroundColor3 = C.Night,
					BackgroundTransparency = 0.25,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 0, CH + 8),
					Size = UDim2.new(0.86, 0, 0, 20),
					ZIndex = 60,
					Parent = cell,
				}, { Ui.corner(10), Ui.list(true, 2, Enum.HorizontalAlignment.Center) })
				for s = 1, 4 do
					Kit.image("emblem_star_gold", {
						Size = UDim2.fromOffset(16, 16),
						ImageColor3 = if s <= stage then C.White else Color3.fromRGB(70, 70, 90),
						ImageTransparency = if s <= stage then 0 else 0.35,
						ZIndex = 61,
						Parent = strip,
					})
				end
			else
				Kit.image("empty_slot", {
					Name = "Empty",
					Size = UDim2.fromOffset(CW, CH),
					Parent = cell,
				})
			end
			-- the slot number in a framed box, bottom-right
			local num = Ui.display({
				Name = "Slot",
				Text = tostring(i),
				TextSize = 18,
				BackgroundColor3 = C.Night,
				BackgroundTransparency = 0,
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromOffset(CW + 4, CH - 4),
				Size = UDim2.fromOffset(26, 26),
				ZIndex = 62,
				Parent = cell,
			})
			num.TextColor3 = C.White
			Ui.corner(6).Parent = num
			Ui.stroke(C.GoldHi, 2, 0.1).Parent = num
		end
	end

	local api: Hud
	api = {
		refresh = function()
			inWorld = ctx.state.area ~= 0
			local v = ctx.state.view
			if v == nil then
				return
			end
			local dots = HudBadges.dots(v, ctx.now())
			for _, item in GRID do
				local b = buttons[item.id]
				b.dot.Visible = item.badge ~= nil and (dots :: any)[item.badge] == true
			end
			deckDot.Visible = dots.Deck
			want(gift, dots.Quests)
			setCount(coins, "coins", v.coins)
			setCount(gems, "gems", v.gems)
			renderDeck(v)
			local card = HudBadges.questCard(v)
			hasQuest = card ~= nil
			tutorial = card ~= nil and card.title == "Tutorial"
			if card then
				questTitle.Text = string.upper(card.title)
				questCount.Text = `{card.done}/{card.total}`
				for i, rf in rowFrames do
					local row = card.rows[i]
					rf.frame.Visible = row ~= nil
					if row then
						rf.text.Text = if row.target > 1
							then `{row.text} [{Format.short(row.progress)}/{Format.short(row.target)}]`
							else row.text
						Ui.fit(rf.text, 17, 11)
						rf.tick.Visible = row.done
						rf.setBar(row.progress / math.max(1, row.target))
						-- a new task slides in (the previous one was finished)
						if lastRows[i] ~= nil and lastRows[i] ~= row.text and not reduced then
							rf.frame.Position = UDim2.fromOffset(76, 64 + (i - 1) * 40)
							TweenService:Create(
								rf.frame,
								TweenInfo.new(0.3, Enum.EasingStyle.Back),
								{ Position = UDim2.fromOffset(16, 64 + (i - 1) * 40) }
							):Play()
						end
						lastRows[i] = row.text
					end
				end
				local f = card.done / math.max(1, card.total)
				ringGrad.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(math.clamp(f, 0.001, 0.998), 0),
					NumberSequenceKeypoint.new(math.clamp(f + 0.001, 0.002, 0.999), 0.85),
					NumberSequenceKeypoint.new(1, 0.85),
				})
			end
			setCollapsed(collapsed)
		end,
		setMode = setMode,
		-- Sizes (BAD_GUI_5 section 4): grid buttons 76 px on PC, 64 on phones (never under 44
		-- physical); deck cards about 130 x 175 on PC and 100 x 135 on phones.
		-- Deck cards are also capped at 22% of the screen height (found in the Phase 13 pass: on a
		-- short landscape phone they covered the character).
		layout = function(width: number, scale: number?, height: number?)
			local s = scale or 1
			local phone = s < 1.6
			local physical = if phone then 64 else 76
			B = math.floor(math.max(44, physical) / s)
			gridLayout.CellSize = UDim2.fromOffset(B, B)
			grid.Size = UDim2.fromOffset(2 * B + 10, 2 * B + 12)
			CW = math.floor((if phone then 100 else 130) / s)
			local maxH = (height or 540) * 0.22
			if CW * 1.35 > maxH then
				CW = math.floor(maxH / 1.35)
			end
			CH = math.floor(CW * 1.35)
			-- touch screens: the grid sits higher, clear of the thumbstick (bottom-left)
			homes[grid] = if touch then UDim2.new(0, 10, 0.42, 0) else UDim2.new(0, 10, 0.5, 0)
			homes[menuButton] = UDim2.fromOffset(10, 52)
			homes[deckBar] = UDim2.new(0.5, 0, 1, -8)
			homes[quest] = UDim2.new(1, -12, 0, 132)
			homes[trophy] = UDim2.new(1, -12, 0, 132)
			homes[gift] = UDim2.new(1, -16, 0, 66)
			quest.Size = UDim2.fromOffset(if width < 760 then 220 else 270, 150)
			deckKey = "" -- rebuild the cards at the new size
			local v = ctx.state.view
			if v then
				renderDeck(v)
			end
			setMode(mode, true)
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
		target = function(name: string): GuiObject?
			if name == "quests" then
				return if quest.Visible then quest else trophy
			end
			local map: { [string]: GuiObject } = {
				coins = coins.Parent :: GuiObject,
				gems = gems.Parent :: GuiObject,
				bag = buttons.Collection.button,
				worlds = buttons.Worlds.button,
				deck = deckBar,
			}
			return map[name]
		end,
	}
	return api
end

return Hud
