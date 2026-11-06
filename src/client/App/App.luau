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

local MENU = {
	{ id = "Play", icon = "⚔", label = "Play" },
	{ id = "Collection", icon = "🃏", label = "Cards" },
	{ id = "Deck", icon = "🛡", label = "Deck" },
	{ id = "Shop", icon = "🥚", label = "Shop" },
	{ id = "Worlds", icon = "🌍", label = "Worlds" },
	{ id = "Quests", icon = "📜", label = "Quests" },
	{ id = "Settings", icon = "⚙", label = "Settings" },
}

local function buildHud(ctx: Ctx, root: Frame): () -> ()
	local top = Ui.frame({
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = root,
	})
	Ui.text({
		Text = "1v1 CARD",
		Font = Theme.Font.Title,
		TextSize = 26,
		TextColor3 = C.Gold,
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.fromOffset(140, 32),
		Parent = top,
	})
	local chips = Ui.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(520, 32),
		Parent = top,
	}, { Ui.list(true, 10, Enum.HorizontalAlignment.Center) })
	local function chip(icon: string, color: Color3, order: number): TextLabel
		local f = Ui.frame({
			BackgroundColor3 = C.Panel,
			Size = UDim2.fromOffset(150, 32),
			LayoutOrder = order,
			Parent = chips,
		}, { Ui.corner(16), Ui.stroke(color, 1, 0.4) })
		Ui.text({
			Text = icon,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromOffset(30, 32),
			Parent = f,
		})
		return Ui.text({
			Name = "Value",
			Text = "0",
			Font = Theme.Font.Bold,
			TextSize = 16,
			TextColor3 = color,
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Parent = f,
		})
	end
	local coins = chip("💰", C.Gold, 1)
	local gems = chip("💎", C.Blue, 2)
	local trophies = chip("🏆", C.Text, 3)

	local menu = Ui.frame({
		Name = "Menu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.fromOffset(132, 7 * 48),
		Parent = root,
	}, { Ui.list(false, 6) })
	for i, item in MENU do
		local b = Ui.button(`{item.icon}  {item.label}`, "ghost", function()
			ctx.open(item.id)
		end, {
			Name = item.id,
			LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 42),
		})
		Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = b.instance })
		Ui.stroke(C.Stroke, 1).Parent = b.instance
		b.instance.Parent = menu
	end

	return function()
		local v = ctx.state.view
		if v == nil then
			return
		end
		coins.Text = Format.number(v.coins)
		gems.Text = Format.number(v.gems)
		trophies.Text = `{Format.number(v.trophies)} · {Progress.leagueFor(v.trophies).id}`
	end
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
			local s = math.min(vp.X / Theme.Size.base.X, vp.Y / Theme.Size.base.Y)
			uiScale.Scale = math.clamp(s, 0.5, 2)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local hudLayer = Ui.frame({ Name = "Hud", BackgroundTransparency = 1, Parent = root })
	local dim = Ui.frame({
		Name = "Dim",
		BackgroundColor3 = C.Black,
		BackgroundTransparency = 0.45,
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
				Font = Theme.Font.Bold,
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

	local refreshHud = buildHud(ctx, hudLayer)
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
