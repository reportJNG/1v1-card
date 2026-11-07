--!strict
-- The client shell: the main menu, the HUD (top bar + left menu), one modal panel at a time,
-- full-screen overlays (hatch, battle), toasts and confirmations. One state machine
-- (Shared/Ui/UiFlow) decides what is shown: App feeds it events and applies its view (HUD mode,
-- blur, input lock, menu camera through `deps.effects`). Screens get a Ctx with everything
-- injected, so the Studio UI check can build every screen with fake data (scripts/studio/ui-check).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Domain.Progress)
local HudBadges = require(Shared.Ui.HudBadges)
local WorldsCfg = require(Shared.Config.Worlds)
local UiFlow = require(Shared.Ui.UiFlow)
local MainMenu = require(script.Parent.MainMenu)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Format = require(script.Parent.Format)
local State = require(script.Parent.State)

local C = Theme.Color

export type Reply = { ok: boolean, value: any?, err: string? }

export type Net = {
	request: (name: string, payload: any?) -> Reply,
	on: (push: string, fn: (data: any) -> ()) -> (),
}

export type Screen = { destroy: () -> (), refresh: (() -> ())? }

export type Ctx = {
	state: State.State,
	net: Net,
	gui: ScreenGui,
	open: (name: string, arg: any?) -> (),
	close: () -> (),
	overlay: (build: (layer: Frame) -> Screen) -> Screen,
	toast: (text: string, kind: string?) -> (),
	confirm: (title: string, body: string, yes: string, onYes: () -> ()) -> (),
	request: (name: string, payload: any?, quiet: boolean?) -> Reply,
	attr: (name: string) -> any,
	now: () -> number,
	guid: () -> string,
	reducedMotion: () -> boolean,
	ui: (event: string, arg: string?) -> (), -- feeds the UI state machine (UiFlow)
	invite: () -> (), -- the Roblox friend-invite prompt
	flow: UiFlow.Flow,
}

export type Deps = {
	gui: ScreenGui,
	net: Net,
	attr: (name: string) -> any,
	now: () -> number,
	guid: () -> string,
	screens: { [string]: (ctx: Ctx, layer: Frame, arg: any?) -> Screen },
	-- World-side effects of the UI state (App/UiEffects). Without them (previews, checks) the
	-- app skips the main menu and starts in the game view.
	effects: any?,
}

local App = {}

local Worlds = require(Shared.Config.Worlds)

-- Left icon dock (concept board order). Trade is V2 and not built, so it is not shown. Each tile is
-- an icon-pack icon on a bright tile in its own accent, with a one-word label.
local MENU = {
	{ id = "Play", icon = "icon_play", label = "1v1", accent = Color3.fromHex("#FF9F2E") },
	{ id = "Collection", icon = "icon_cards", label = "Cards", accent = Color3.fromHex("#A469FF") },
	{ id = "Deck", icon = "icon_deck", label = "Deck", accent = Color3.fromHex("#3FA9FF") },
	{ id = "Shop", icon = "icon_shop", label = "Eggs", accent = Color3.fromHex("#FF6FC8") },
	{ id = "Worlds", icon = "icon_worlds", label = "Worlds", accent = Color3.fromHex("#2FD6E0") },
	{ id = "Quests", icon = "icon_quests", label = "Quests", accent = Color3.fromHex("#48DA97") },
	{ id = "Settings", icon = "icon_settings", label = "Settings", accent = Color3.fromHex("#8D9BC4") },
}
local TILE = 48 -- dock tile size (design px)

type Hud = {
	refresh: () -> (),
	select: (id: string?) -> (),
	setMode: (mode: string, instant: boolean?) -> (),
	layout: (width: number) -> (),
}

local function buildHud(ctx: Ctx, root: Frame): Hud
	local F = Theme.Face

	-- Logo (top-left): display type until the logo art exists.
	local logo = Ui.frame({
		Name = "Logo",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(150, 76),
		Parent = root,
	})
	Ui.display({
		Text = "1v1",
		TextSize = 44,
		Rotation = -4,
		Size = UDim2.new(1, 0, 0, 44),
		Parent = logo,
	}, true)
	Ui.display({
		Text = "CARD",
		TextSize = 30,
		Rotation = -4,
		Position = UDim2.fromOffset(6, 38),
		Size = UDim2.new(1, 0, 0, 32),
		Parent = logo,
	})

	-- Currency badges (top centre). Coins and Gems are earned, never bought, so "+" shows
	-- where to earn them (Worlds for Coins, Quests for Gems).
	local top = Ui.frame({
		Name = "TopBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 10, 0, 12),
		Size = UDim2.fromOffset(560, 40),
		Parent = root,
	}, { Ui.list(true, 14, Enum.HorizontalAlignment.Center) })

	local function badge(name: string, icon: string, order: number, onPlus: (() -> ())?): TextLabel
		local f = Ui.frame({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(if onPlus then 168 else 156, 36),
			LayoutOrder = order,
			Parent = top,
		})
		Ui.skin(f, "currency_badge", 0.5)
		Ui.icon(icon, 34, { Position = UDim2.new(0, -6, 0.5, 0), ZIndex = 2, Parent = f })
		local value = Ui.text({
			Name = "Value",
			Text = "0",
			FontFace = F.Number,
			TextSize = 18,
			TextWrapped = false,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, if onPlus then -72 else -40, 1, 0),
			ZIndex = 2,
			Parent = f,
		})
		Ui.outline(C.Night, 1.5).Parent = value
		Ui.fit(value, 18, 10)
		if onPlus then
			local plus: ImageButton = Ui.new("ImageButton", {
				Name = "Plus",
				Image = Ui.asset("button_plus"),
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -4, 0.5, 0),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = 2,
				Parent = f,
			})
			Ui.juice(plus)
			plus.Activated:Connect(function()
				Ui.sound("click")
				onPlus()
			end)
		end
		return value
	end
	local coins = badge("Coins", "icon_coin", 1, function()
		ctx.open("Tip", { kind = "coins" }) -- Coins are earned, never sold
	end)
	local gems = badge("Gems", "icon_gem", 2, function()
		ctx.open("Tip", { kind = "gems" })
	end)
	local trophies = badge("Trophies", "icon_trophy", 3, nil)

	-- Top icons (top-right): daily rewards, quests and inviting friends.
	local icons = Ui.frame({
		Name = "TopIcons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(166, 48),
		Parent = root,
	}, { Ui.list(true, 8, Enum.HorizontalAlignment.Right) })
	for i, item in
		{ { "Daily", "icon_gift" }, { "QuestsIcon", "icon_calendar" }, { "Friends", "icon_friends" } }
	do
		local b: ImageButton = Ui.new("ImageButton", {
			Name = item[1],
			Image = Ui.asset(item[2]),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(46, 46),
			LayoutOrder = i,
			Parent = icons,
		})
		Ui.juice(b)
		b.Activated:Connect(function()
			Ui.sound("click")
			if item[1] == "Friends" then
				ctx.invite()
			else
				ctx.open("Quests")
			end
		end)
	end

	-- Left icon dock: square bright tiles, icon first, a tiny label.
	local menu = Ui.frame({
		Name = "Menu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 82),
		Size = UDim2.fromOffset(TILE, #MENU * (TILE + 4)),
		Parent = root,
	}, { Ui.list(false, 4) })
	local rows: { [string]: { stroke: UIStroke, label: TextLabel, dot: Frame } } = {}
	for i, item in MENU do
		local row: TextButton = Ui.new("TextButton", {
			Name = item.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = C.White,
			LayoutOrder = i,
			Size = UDim2.fromOffset(TILE, TILE),
			Parent = menu,
		}, {
			Ui.new("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Ui.new("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, item.accent:Lerp(C.White, 0.25)),
					ColorSequenceKeypoint.new(0.55, item.accent),
					ColorSequenceKeypoint.new(1, item.accent:Lerp(C.Night, 0.45)),
				}),
			}),
		})
		local stroke: UIStroke = Ui.new("UIStroke", {
			Color = C.Night,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = row,
		})
		-- Gloss: a soft white sheen over the top half.
		Ui.frame({
			Name = "Gloss",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.78,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 0.42, 0),
			ZIndex = 2,
			Parent = row,
		}, { Ui.new("UICorner", { CornerRadius = UDim.new(0, 9) }) })
		Ui.icon(item.icon, 32, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.4, 0),
			ZIndex = 3,
			Parent = row,
		})
		local label = Ui.display({
			Text = item.label,
			TextSize = 11,
			TextWrapped = false,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 1),
			Size = UDim2.new(1, 6, 0, 13),
			ZIndex = 4,
			Parent = row,
		})
		-- Notification dot: something is ready here (HudBadges).
		local dot = Ui.frame({
			Name = "Dot",
			BackgroundColor3 = C.Red,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -3, 0, 3),
			Size = UDim2.fromOffset(12, 12),
			Visible = false,
			ZIndex = 5,
			Parent = row,
		}, { Ui.corner(6), Ui.stroke(C.Night, 2) })
		Ui.juice(row)
		row.Activated:Connect(function()
			Ui.sound("click")
			ctx.open(item.id)
		end)
		rows[item.id] = { stroke = stroke, label = label, dot = dot }
	end

	-- Bottom hint: the next world and the trophies it needs.
	local hint = Ui.frame({
		Name = "Hint",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 40, 1, -12),
		Size = UDim2.fromOffset(400, 32),
		Parent = root,
	})
	Ui.skin(hint, "toast", 0.44)
	Ui.icon("icon_trophy", 26, { Position = UDim2.new(0, 10, 0.5, 0), ZIndex = 2, Parent = hint })
	local hintText = Ui.text({
		Text = "",
		FontFace = F.Bold,
		TextSize = 14,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -44, 1, 0),
		ZIndex = 2,
		Parent = hint,
	})
	Ui.fit(hintText, 14, 9)

	-- Where the player is (bottom-left): the lobby, or the world number and name.
	local place = Ui.frame({
		Name = "Place",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(200, 32),
		Parent = root,
	})
	Ui.skin(place, "toast", 0.44)
	Ui.icon("icon_worlds", 24, { Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 2, Parent = place })
	local placeText = Ui.text({
		Name = "Value",
		Text = "LOBBY",
		FontFace = F.Title,
		TextSize = 14,
		TextWrapped = false,
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		ZIndex = 2,
		Parent = place,
	})
	Ui.fit(placeText, 14, 9)

	-- Quest tracker (bottom-right): the next daily quest; tap for Quests.
	local tracker: TextButton = Ui.new("TextButton", {
		Name = "Tracker",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(230, 50),
		Parent = root,
	})
	Ui.skin(tracker, "toast", 0.6)
	Ui.icon("icon_quests", 26, { Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 2, Parent = tracker })
	local trackerText = Ui.text({
		Text = "",
		FontFace = F.Bold,
		TextSize = 13,
		TextWrapped = false,
		Position = UDim2.fromOffset(40, 6),
		Size = UDim2.new(1, -50, 0, 18),
		ZIndex = 2,
		Parent = tracker,
	})
	Ui.fit(trackerText, 13, 9)
	local setTrack = Ui.bar(tracker, C.Gold, {
		Position = UDim2.fromOffset(40, 28),
		Size = UDim2.new(1, -86, 0, 10),
		ZIndex = 2,
	})
	local trackerCount = Ui.text({
		Text = "",
		FontFace = F.Number,
		TextSize = 12,
		TextColor3 = C.Gold,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.new(1, -44, 0, 24),
		Size = UDim2.fromOffset(36, 18),
		ZIndex = 2,
		Parent = tracker,
	})
	Ui.juice(tracker)
	tracker.Activated:Connect(function()
		Ui.sound("click")
		ctx.open("Quests")
	end)

	-- Back to Lobby (bottom-left, above the place name), shown only while the player is in a world
	-- (World attribute 1-10). The server moves the character (World.Hub); each world also has a
	-- lobby portal.
	local lobby = Ui.button("      Lobby", "primary", function()
		ctx.request("World.Hub")
	end, {
		Name = "Lobby",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -52),
		Size = UDim2.fromOffset(120, 40),
		TextSize = 16,
	})
	Ui.icon("icon_home", 30, { Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 5, Parent = lobby.instance })
	lobby.instance.Visible = false
	lobby.instance.Parent = root

	-- Menu (top-right, left of the daily icons): back to the main menu.
	local pause = Ui.button("Menu", "secondary", function()
		ctx.ui("menu")
	end, {
		Name = "MenuButton",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -188, 0, 16),
		Size = UDim2.fromOffset(78, 32),
		TextSize = 14,
	})
	pause.instance.Parent = root

	-- HUD modes (UiFlow view): "full", "currencies" (only the top bar) or "hidden". Pieces slide
	-- off their nearest edge and back.
	local wanted: { [GuiObject]: boolean } =
		{ [hint] = true, [lobby.instance] = false, [logo] = true, [tracker] = false }
	local pieces: { { obj: GuiObject, home: UDim2, away: UDim2, keep: boolean } } = {
		{ obj = logo, home = logo.Position, away = logo.Position - UDim2.fromOffset(260, 0), keep = false },
		{
			obj = pause.instance,
			home = pause.instance.Position,
			away = pause.instance.Position - UDim2.fromOffset(340, 0),
			keep = false,
		},
		{ obj = menu, home = menu.Position, away = menu.Position - UDim2.fromOffset(120, 0), keep = false },
		{
			obj = icons,
			home = icons.Position,
			away = icons.Position + UDim2.fromOffset(180, 0),
			keep = false,
		},
		{ obj = hint, home = hint.Position, away = hint.Position + UDim2.fromOffset(0, 80), keep = false },
		{ obj = place, home = place.Position, away = place.Position + UDim2.fromOffset(0, 80), keep = false },
		{
			obj = tracker,
			home = tracker.Position,
			away = tracker.Position + UDim2.fromOffset(0, 90),
			keep = false,
		},
		{
			obj = lobby.instance,
			home = lobby.instance.Position,
			away = lobby.instance.Position + UDim2.fromOffset(0, 80),
			keep = false,
		},
		{ obj = top, home = top.Position, away = top.Position - UDim2.fromOffset(0, 80), keep = true },
	}
	local mode = "full"
	local function setMode(m: string, instant: boolean?)
		mode = m
		local info = if instant or ctx.reducedMotion()
			then TweenInfo.new(0.01)
			else TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		for _, piece in pieces do
			local show = m == "full" or (m == "currencies" and piece.keep)
			local content = wanted[piece.obj] ~= false
			if show and content then
				piece.obj.Visible = true
			end
			local tween =
				TweenService:Create(piece.obj, info, { Position = if show then piece.home else piece.away })
			tween.Completed:Connect(function()
				if mode == m then
					-- Read `wanted` now, not at the start: the area can change mid-slide (PLAY sends
					-- the player to the lobby while the HUD slides in).
					piece.obj.Visible = show and wanted[piece.obj] ~= false
				end
			end)
			tween:Play()
		end
	end
	local function want(obj: GuiObject, on: boolean)
		wanted[obj] = on
		obj.Visible = on and mode == "full"
	end

	local shown: { [string]: number } = {}
	local function setCount(label: TextLabel, key: string, value: number)
		local before = shown[key]
		shown[key] = value
		if before == nil or before == value or ctx.reducedMotion() then
			label.Text = Format.number(value)
			return
		end
		Ui.countUp(label, before, value, Format.number)
		Ui.pulse(label.Parent :: GuiObject, 0.08)
		if value > before then
			Ui.sound("coin")
			-- A "+N" that floats up from the badge and fades.
			local badgeFrame = label.Parent :: GuiObject
			local pop = Ui.text({
				Text = `+{Format.number(value - before)}`,
				FontFace = F.Number,
				TextSize = 20,
				TextColor3 = if key == "gems" then C.Blue else C.Gold,
				TextWrapped = false,
				TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(120, 24),
				ZIndex = 5,
				Parent = badgeFrame,
			})
			Ui.outline(C.Night, 2).Parent = pop
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

	return {
		refresh = function()
			want(lobby.instance, ctx.state.area ~= 0)
			local area = ctx.state.area
			local world = WorldsCfg.ById[area]
			placeText.Text = if world then `WORLD {area} · {string.upper(world.displayName)}` else "LOBBY"
			local v = ctx.state.view
			if v == nil then
				return
			end
			local dots = HudBadges.dots(v, ctx.now())
			for id, r in rows do
				r.dot.Visible = (dots :: any)[id] == true
			end
			local track = HudBadges.tracker(v)
			want(tracker, track ~= nil)
			if track then
				trackerText.Text = track.text
				trackerCount.Text = `{track.progress}/{track.target}`
				setTrack(track.progress / track.target)
			end
			setCount(coins, "coins", v.coins)
			setCount(gems, "gems", v.gems)
			trophies.Text = `{Format.number(v.trophies)} · {Progress.leagueFor(v.trophies).id}`
			local nextWorld = nil
			for _, w in Worlds.List do
				if v.highestTrophies < w.trophiesToUnlock then
					nextWorld = w
					break
				end
			end
			want(hint, nextWorld ~= nil)
			if nextWorld then
				hintText.Text =
					`Reach {Format.number(nextWorld.trophiesToUnlock)} trophies to unlock World {nextWorld.id}: {nextWorld.displayName}`
			end
		end,
		setMode = setMode,
		-- Narrow screens (phones held upright, ~720 design px wide): no big logo and the currency
		-- bar fills the space left of the icons. Below tablet width the Menu button drops under the
		-- icons.
		layout = function(width: number)
			local narrow = width < 860
			wanted[logo] = not narrow
			for _, piece in pieces do
				if piece.obj == top then
					piece.home = if narrow
						then UDim2.fromOffset((width - 180) / 2, 12)
						else UDim2.new(0.5, 10, 0, 12)
					piece.away = piece.home - UDim2.fromOffset(0, 80)
				elseif piece.obj == pause.instance then
					-- Up to tablet widths the top bar reaches the icons: the Menu button goes under them.
					piece.home = if width < 1040 then UDim2.new(1, -18, 0, 62) else UDim2.new(1, -188, 0, 16)
					piece.away = piece.home + UDim2.fromOffset(260, 0)
				end
			end
			setMode(mode, true)
		end,
		select = function(id: string?)
			for key, r in rows do
				local on = key == id
				r.stroke.Color = if on then C.Gold else C.Night
				r.stroke.Thickness = if on then 3 else 2
			end
		end,
	}
end

function App.start(deps: Deps): Ctx
	local gui = deps.gui
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function()
		(gui :: any).ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end)

	-- Design space 960 x 540, scaled to fit the device.
	local root = Ui.frame({
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(Theme.Size.base.X, Theme.Size.base.Y),
		Parent = gui,
	})
	local uiScale = Ui.new("UIScale", { Parent = root })
	local hud: Hud? = nil
	local panelFit: UIScale? = nil
	local function fit()
		local vp = gui.AbsoluteSize
		if vp.X > 0 and vp.Y > 0 then
			-- Scale so the 960 x 540 design space fits, then let the root fill the screen in design
			-- units, so edge-anchored HUD pieces sit at the real screen edges on wide phones.
			local s = math.clamp(math.min(vp.X / Theme.Size.base.X, vp.Y / Theme.Size.base.Y), 0.5, 2)
			uiScale.Scale = s
			root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
			if hud then
				hud.layout(vp.X / s)
			end
			if panelFit then
				panelFit.Scale = math.min(1, (vp.X / s - 16) / 820)
			end
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local hudLayer = Ui.frame({ Name = "Hud", BackgroundTransparency = 1, Parent = root })
	local menuLayer = Ui.frame({ Name = "Menu", BackgroundTransparency = 1, Parent = root })
	local dim = Ui.frame({
		Name = "Dim",
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 0.55,
		Visible = false,
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1.5, -1.5),
		Parent = root,
	})
	-- Panels are centred; on narrow screens (phones held upright) the whole layer scales down so
	-- the widest panel (800 design px) and its close button stay on screen.
	local panelLayer = Ui.frame({
		Name = "Panels",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = root,
	})
	panelFit = Ui.new("UIScale", { Name = "Fit", Parent = panelLayer })
	fit()
	local overlayLayer = Ui.frame({ Name = "Overlays", BackgroundTransparency = 1, Parent = root })
	local toastLayer = Ui.frame({
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(460, 200),
		Parent = root,
	}, {
		Ui.new("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local current: Screen? = nil
	local overlays: { Screen } = {}
	local toastCount = 0
	local ctx: Ctx
	local flow = UiFlow.new()
	-- Screens only the shell opens (previews and checks get them too).
	for _, name in { "Tip", "Families" } do
		if deps.screens[name] == nil then
			deps.screens[name] = require(script.Parent.Screens:FindFirstChild(name) :: ModuleScript) :: any
		end
	end
	local effects = deps.effects
	local menu: MainMenu.Menu

	-- Removes the open panel's UI. `animated`: a quick scale-out first (0.12 s).
	local function dropPanel(animated: boolean)
		local screen = current
		current = nil
		dim.Visible = false
		if hud then
			hud.select(nil)
		end
		local frames = panelLayer:GetChildren()
		local function finish()
			if screen then
				screen.destroy()
			end
			for _, f in frames do
				if f == panelFit then
					continue -- the layer's own fit scale stays
				end
				f:Destroy()
			end
		end
		local panel = panelLayer:FindFirstChild("Panel")
		if animated and panel and panel:IsA("GuiObject") and not ctx.reducedMotion() then
			local scale = panel:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = panel })
			local out = TweenService:Create(scale, Theme.Motion.close, { Scale = 0.86 })
			out.Completed:Connect(finish)
			out:Play()
		else
			finish()
		end
	end

	-- Applies the state machine's view: HUD mode, the main menu, blur, input lock, menu camera.
	local function apply(instant: boolean?)
		local view = UiFlow.view(flow)
		if current and flow.top ~= "Panel" and flow.top ~= "Hatching" then -- a panel stays under a hatch
			dropPanel(not instant)
		end
		if hud then
			hud.setMode(view.hud, instant)
		end
		local onMenu = flow.base == "MainMenu" or flow.base == "Loading"
		menu.setLoading(flow.base == "Loading")
		if onMenu ~= menuLayer.Visible or instant then
			menuLayer.Visible = onMenu
			menu.show(onMenu)
		end
		ctx.state.changed:fire("ui") -- AreaFx follows (menu music)
		if effects then
			effects.reduced = ctx.reducedMotion()
			effects.setBlur(view.blur)
			effects.setInputLocked(view.inputLocked)
			effects.setMenuShot(view.menuShot, instant)
		end
	end

	local function ui(event: string, arg: string?)
		if UiFlow.send(flow, event :: any, arg) then
			apply()
		end
	end

	local function close()
		if flow.top == "Panel" then
			UiFlow.send(flow, "close")
			dropPanel(true)
			apply()
		elseif current then
			dropPanel(false)
		end
	end

	ctx = {
		state = State.new(),
		net = deps.net,
		gui = gui,
		open = function(name: string, arg: any?)
			local build = deps.screens[name]
			if build == nil then
				return
			end
			if flow.top == "Panel" and flow.panel == name then
				return -- already open: a double click opens nothing twice
			end
			if not UiFlow.send(flow, "open", name) then
				return -- not over a battle, a hatch or the loading screen
			end
			dropPanel(false)
			dim.Visible = true
			current = build(ctx, panelLayer, arg)
			Ui.skinify(panelLayer)
			if hud then
				hud.select(name)
			end
			apply()
		end,
		close = close,
		overlay = function(build: (layer: Frame) -> Screen): Screen
			local frame = Ui.frame({ BackgroundTransparency = 1, Parent = overlayLayer })
			local screen = build(frame)
			Ui.skinify(frame)
			local wrapped: Screen
			wrapped = {
				destroy = function()
					screen.destroy()
					frame:Destroy()
					local i = table.find(overlays, wrapped)
					if i then
						table.remove(overlays, i)
					end
				end,
				refresh = screen.refresh,
			}
			table.insert(overlays, wrapped)
			return wrapped
		end,
		toast = function(text: string, kind: string?)
			toastCount += 1
			local color = if kind == "error" then C.Red elseif kind == "good" then C.Green else C.Blue
			local t = Ui.frame({
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(440, 38),
				LayoutOrder = toastCount,
				Parent = toastLayer,
			})
			local skin = Ui.skin(t, "toast", 0.52)
			skin.ImageColor3 = C.White:Lerp(color, 0.35)
			local label = Ui.text({
				Text = text,
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
				Parent = t,
			})
			Ui.outline(C.Night, 1, 0.3).Parent = label
			Ui.popIn(t)
			if kind == "error" then
				Ui.sound("error")
			end
			task.delay(3, function()
				if t.Parent then
					TweenService:Create(skin, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
					local fade = TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 })
					fade:Play()
					fade.Completed:Wait()
					t:Destroy()
				end
			end)
		end,
		confirm = function(title: string, body: string, yes: string, onYes: () -> ())
			local box: Screen
			box = ctx.overlay(function(layer)
				Ui.frame({ BackgroundColor3 = C.Black, BackgroundTransparency = 0.4, Parent = layer })
				local p = Ui.panel(layer, title, function()
					box.destroy()
				end, UDim2.fromOffset(420, 220))
				Ui.text({ Text = body, Size = UDim2.new(1, 0, 0, 70), Parent = p.body })
				local row = Ui.frame({
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 1, -44),
					Size = UDim2.new(1, 0, 0, 40),
					Parent = p.body,
				}, { Ui.list(true, 10, Enum.HorizontalAlignment.Right) })
				local cancel = Ui.button("Cancel", "ghost", function()
					box.destroy()
				end, { Size = UDim2.fromOffset(120, 40) })
				cancel.instance.Parent = row
				local ok = Ui.button(yes, "primary", function()
					box.destroy()
					onYes()
				end, { Size = UDim2.fromOffset(160, 40) })
				ok.instance.Parent = row
				return { destroy = function() end }
			end)
		end,
		request = function(name: string, payload: any?, quiet: boolean?): Reply
			local reply = deps.net.request(name, payload)
			if not reply.ok and not quiet then
				ctx.toast(Format.error(reply.err), "error")
			end
			return reply
		end,
		attr = deps.attr,
		now = deps.now,
		guid = deps.guid,
		reducedMotion = function(): boolean
			local v = ctx.state.view
			return v ~= nil and v.settings ~= nil and v.settings.reducedMotion == true
		end,
		ui = ui,
		flow = flow,
		invite = function()
			local player = Players.LocalPlayer
			if player == nil then
				return
			end
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(player)
			end)
			if ok and can then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			else
				ctx.toast("Invites aren't available here (they work in the published game).")
			end
		end,
	}

	hud = buildHud(ctx, hudLayer)
	fit()
	menu = MainMenu.build(menuLayer, {
		play = function()
			-- PLAY always lands in the lobby, wherever the player was (server-checked World.Hub).
			task.spawn(ctx.request, "World.Hub")
			ui("play")
		end,
		open = function(name: string)
			ctx.open(name)
		end,
	}, ctx.reducedMotion)
	apply(true)

	-- Esc, gamepad B and Backspace close the top panel (the X button does too).
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local key = input.KeyCode
		if
			key == Enum.KeyCode.ButtonB
			or key == Enum.KeyCode.Escape
			or (key == Enum.KeyCode.Backspace and not processed)
		then
			if flow.top == "Panel" then
				close()
			end
		end
	end)

	local refreshHud = (hud :: Hud).refresh
	local loaded = false
	ctx.state.changed:connect(function(what)
		if what == "battle" then
			-- A battle takes over the whole screen; its end returns to the game view.
			ui(if ctx.state.battle ~= nil then "battleStart" else "resultDone")
		elseif what == "queue" then
			ui(if ctx.state.queue.state == "Searching" then "queueJoin" else "queueLeave")
		end
		if what == "profile" and not loaded then
			loaded = true
			ui("loaded")
			if effects == nil then
				ui("play") -- previews and checks: straight to the game view
			end
		end
		if what == "area" then
			refreshHud()
			if current and current.refresh then
				current.refresh()
			end
		end
		if what == "profile" then
			refreshHud()
			if current and current.refresh then
				current.refresh()
				Ui.skinify(panelLayer)
			end
			for _, o in overlays do
				if o.refresh then
					o.refresh()
				end
			end
		end
	end)

	deps.net.on("Profile.Snapshot", function(view)
		ctx.state:setSnapshot(view)
	end)
	deps.net.on("Profile.Delta", function(delta)
		ctx.state:applyDelta(delta)
	end)
	deps.net.on("Queue.Status", function(status)
		ctx.state:setQueue(status)
	end)
	deps.net.on("Notice", function(n)
		ctx.toast(tostring(n.text), n.kind)
	end)
	return ctx
end

return App
