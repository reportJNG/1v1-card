--!strict
-- The client shell: HUD (top bar + left menu), one open panel at a time, full-screen overlays
-- (hatch, battle), toasts and confirmations. Screens get a Ctx with everything injected, so the
-- Studio UI check can build every screen with fake data (scripts/studio/ui-check).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progress = require(Shared.Domain.Progress)
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
}

export type Deps = {
	gui: ScreenGui,
	net: Net,
	attr: (name: string) -> any,
	now: () -> number,
	guid: () -> string,
	screens: { [string]: (ctx: Ctx, layer: Frame, arg: any?) -> Screen },
}

local App = {}

local Worlds = require(Shared.Config.Worlds)

-- Left menu (concept board order). Trade is V2 and not built, so it is not shown.
local MENU = {
	{ id = "Play", icon = "icon_play", label = "Play" },
	{ id = "Collection", icon = "icon_cards", label = "Cards" },
	{ id = "Deck", icon = "icon_deck", label = "Deck" },
	{ id = "Shop", icon = "icon_shop", label = "Shop" },
	{ id = "Worlds", icon = "icon_worlds", label = "Worlds" },
	{ id = "Quests", icon = "icon_quests", label = "Quests" },
	{ id = "Settings", icon = "icon_settings", label = "Settings" },
}

type Hud = { refresh: () -> (), select: (id: string?) -> () }

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
		ctx.open("Worlds")
	end)
	local gems = badge("Gems", "icon_gem", 2, function()
		ctx.open("Quests")
	end)
	local trophies = badge("Trophies", "icon_trophy", 3, nil)

	-- Top icons (top-right): daily rewards and quests.
	local icons = Ui.frame({
		Name = "TopIcons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(110, 48),
		Parent = root,
	}, { Ui.list(true, 8, Enum.HorizontalAlignment.Right) })
	for i, item in { { "Daily", "icon_gift" }, { "QuestsIcon", "icon_calendar" } } do
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
			ctx.open("Quests")
		end)
	end

	-- Left menu.
	local menu = Ui.frame({
		Name = "Menu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 96),
		Size = UDim2.fromOffset(150, 7 * 50),
		Parent = root,
	}, { Ui.list(false, 6) })
	local rows: { [string]: { skin: ImageLabel, label: TextLabel } } = {}
	for i, item in MENU do
		local row: TextButton = Ui.new("TextButton", {
			Name = item.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, Theme.Size.tap),
			Parent = menu,
		})
		local skin = Ui.skin(row, "menu_item", 0.69)
		Ui.icon(item.icon, 32, { Position = UDim2.new(0, 8, 0.5, 0), ZIndex = 2, Parent = row })
		local label = Ui.text({
			Text = item.label,
			FontFace = F.Title,
			TextSize = 17,
			TextWrapped = false,
			Position = UDim2.fromOffset(48, 0),
			Size = UDim2.new(1, -52, 1, 0),
			ZIndex = 2,
			Parent = row,
		})
		Ui.outline(C.Night, 1, 0.3).Parent = label
		Ui.juice(row)
		row.Activated:Connect(function()
			Ui.sound("click")
			ctx.open(item.id)
		end)
		rows[item.id] = { skin = skin, label = label }
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
		end
	end

	return {
		refresh = function()
			local v = ctx.state.view
			if v == nil then
				return
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
			hint.Visible = nextWorld ~= nil
			if nextWorld then
				hintText.Text =
					`Reach {Format.number(nextWorld.trophiesToUnlock)} trophies to unlock World {nextWorld.id}: {nextWorld.displayName}`
			end
		end,
		select = function(id: string?)
			for key, r in rows do
				local on = key == id
				Ui.reskin(r.skin, if on then "tab_on" else "menu_item")
				r.label.TextColor3 = if on then C.White else C.Text
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
	local function fit()
		local vp = gui.AbsoluteSize
		if vp.X > 0 and vp.Y > 0 then
			-- Scale so the 960 x 540 design space fits, then let the root fill the screen in design
			-- units, so edge-anchored HUD pieces sit at the real screen edges on wide phones.
			local s = math.clamp(math.min(vp.X / Theme.Size.base.X, vp.Y / Theme.Size.base.Y), 0.5, 2)
			uiScale.Scale = s
			root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local hudLayer = Ui.frame({ Name = "Hud", BackgroundTransparency = 1, Parent = root })
	local dim = Ui.frame({
		Name = "Dim",
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 0.55,
		Visible = false,
		Size = UDim2.fromScale(4, 4),
		Position = UDim2.fromScale(-1.5, -1.5),
		Parent = root,
	})
	local panelLayer = Ui.frame({ Name = "Panels", BackgroundTransparency = 1, Parent = root })
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
	local hud: Hud? = nil
	local overlays: { Screen } = {}
	local toastCount = 0
	local ctx: Ctx

	local function close()
		if current then
			current.destroy()
		end
		current = nil
		Ui.clear(panelLayer)
		dim.Visible = false
		if hud then
			hud.select(nil)
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
			close()
			dim.Visible = true
			current = build(ctx, panelLayer, arg)
			if hud then
				hud.select(name)
			end
		end,
		close = close,
		overlay = function(build: (layer: Frame) -> Screen): Screen
			local frame = Ui.frame({ BackgroundTransparency = 1, Parent = overlayLayer })
			local screen = build(frame)
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
				BackgroundColor3 = C.Panel,
				Size = UDim2.fromOffset(440, 36),
				LayoutOrder = toastCount,
				Parent = toastLayer,
			}, { Ui.corner(10), Ui.stroke(color, 1.5) })
			Ui.text({
				Text = text,
				FontFace = Theme.Face.Bold,
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = t,
			})
			task.delay(3, function()
				if t.Parent then
					local fade = TweenService:Create(t, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
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
	}

	hud = buildHud(ctx, hudLayer)
	local refreshHud = (hud :: Hud).refresh
	ctx.state.changed:connect(function(what)
		if what == "profile" then
			refreshHud()
			if current and current.refresh then
				current.refresh()
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
