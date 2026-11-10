--!strict
-- The client shell: the main menu, the HUD (top bar + left menu), one modal panel at a time,
-- full-screen overlays (hatch, battle), pops (App/WorldText) and confirmations. One state machine
-- (Shared/Ui/UiFlow) decides what is shown: App feeds it events and applies its view (HUD mode,
-- blur, input lock, menu camera through `deps.effects`). Screens get a Ctx with everything
-- injected, so the Studio UI check can build every screen with fake data (scripts/studio/ui-check).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local HubLayout = require(Shared.Config.HubLayout)
local UiFlow = require(Shared.Ui.UiFlow)
local MainMenu = require(script.Parent.MainMenu)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local CardFx = require(script.Parent.CardFx)
local HudModule = require(script.Parent.Hud)
local Kit = require(script.Parent.Kit)
local Format = require(script.Parent.Format)
local State = require(script.Parent.State)
local WorldText = require(script.Parent.WorldText)
local Feedback = require(script.Parent.Feedback)
local ItemIcon = require(script.Parent.ItemIcon)

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
	-- Messages are pops at their source, never a toast bar (App/WorldText):
	say: (text: string, tone: string?, icon: string?) -> (), -- a short centre pop
	popAt: (source: any, spec: any) -> (), -- over a world object
	near: (gui: GuiObject?, spec: any) -> (), -- beside a screen element
	cheer: (text: string, icon: string?) -> (), -- a green pop beside the pressed button
	warn: (text: string, icon: string?) -> (), -- a red, shaking pop beside the pressed button
	fail: (err: string?) -> (), -- a server error as a short red pop beside the pressed button
	fly: (from: any, target: string, spec: any, onLand: (() -> ())?) -> (), -- icons to a HUD counter
	hudTarget: (name: string) -> GuiObject?,
	confirm: (title: string, body: string, yes: string, onYes: () -> ()) -> (),
	leaveToMenu: () -> (),
	onLeave: (fn: () -> ()) -> (),
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

-- Waits (up to `timeout` s) until the local character stands at the hub spawn, after the server
-- has moved it there (World.Hub). The server's PivotTo replicates a moment after its reply.
local function waitForLobby(timeout: number)
	local o, s = HubLayout.ORIGIN, HubLayout.SPAWN
	local spawn = Vector3.new(o[1] + s[1], o[2] + s[2] + 3, o[3] + s[3])
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local player = Players.LocalPlayer
		local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - spawn).Magnitude < 40 then
			return
		end
		task.wait()
	end
end

type Hud = HudModule.Hud

function App.start(deps: Deps): Ctx
	CardFx.setHoverSound(function()
		Ui.sound("hover")
	end)
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
	local panelShrink = 1 -- panels opened while playing take at most ~70% of the screen (MISSION 3.2)
	local function fit()
		local vp = gui.AbsoluteSize
		if vp.X > 0 and vp.Y > 0 then
			-- Scale so the 960 x 540 design space fits, then let the root fill the screen in design
			-- units, so edge-anchored HUD pieces sit at the real screen edges on wide phones.
			local s = math.clamp(math.min(vp.X / Theme.Size.base.X, vp.Y / Theme.Size.base.Y), 0.5, 2)
			uiScale.Scale = s
			root.Size = UDim2.fromOffset(vp.X / s, vp.Y / s)
			if hud then
				hud.layout(vp.X / s, s, vp.Y / s)
			end
			if panelFit then
				panelFit.Scale = math.min(1, (vp.X / s - 16) / 820) * panelShrink
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
	-- Pops (App/WorldText) sit above everything; there is no toast bar.
	local popLayer =
		Ui.frame({ Name = "Pops", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	-- The button the player just pressed: errors and confirmations pop beside it.
	local function pressed(): GuiObject?
		if os.clock() - Ui.lastPressedAt < 2 then
			return Ui.lastPressed
		end
		return nil
	end

	local current: Screen? = nil
	local overlays: { Screen } = {}
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
		local playing = flow.base == "Playing" or flow.base == "Queue"
		Ui.setPanelStyle(if playing then "light" else "dark")
		local shrink = if playing then 0.86 else 1
		if shrink ~= panelShrink then
			panelShrink = shrink
			fit()
		end
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
			UiFlow.send(flow, "close") -- under a hatch: it must not return to this panel
			dropPanel(false)
		end
	end

	-- Screen 4, leaving (MISSION 2.5): a short screen (darken, the logo, "Returning to menu...", a
	-- flipping card), while the server resets the session (Session.Leave: forfeit, queue, character,
	-- save). Then the main menu. Returns a function that removes the screen.
	local function leavingScreen(): () -> ()
		local screen = Ui.frame({
			Name = "Leaving",
			BackgroundColor3 = Color3.fromHex("#06061B"),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 500,
			Parent = root,
		})
		TweenService:Create(screen, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		Kit.image("logo_1v1card", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromOffset(320, 160),
			ZIndex = 501,
			Parent = screen,
		})
		local spinner = Kit.image("card_back_ur", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromOffset(52, 72),
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 501,
			Parent = screen,
		})
		Ui.text({
			Text = "Returning to menu...",
			FontFace = Theme.Face.Title,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.71),
			Size = UDim2.fromOffset(320, 26),
			ZIndex = 501,
			Parent = screen,
		})
		local spin = true
		task.spawn(function()
			local t0 = os.clock()
			while spin and spinner.Parent do
				local a = (os.clock() - t0) * 5
				spinner.Size = UDim2.fromOffset(math.max(2, math.abs(math.cos(a)) * 52), 72)
				task.wait()
			end
		end)
		return function()
			spin = false
			TweenService:Create(screen, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			for _, d in screen:GetDescendants() do
				if d:IsA("ImageLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
				elseif d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				end
			end
			task.delay(0.35, screen.Destroy, screen)
		end
	end
	local leaveHooks: { () -> () } = {}
	local leavingNow = false
	local function leave()
		leavingNow = true
		Ui.sound("leave")
		local done = leavingScreen()
		local t0 = os.clock()
		ctx.request("Session.Leave", nil, true)
		close()
		for _, o in table.clone(overlays) do
			o.destroy()
		end
		for _, hook in leaveHooks do
			task.spawn(hook)
		end
		task.wait(math.max(0, 1 - (os.clock() - t0)))
		ui("leave")
		done()
		leavingNow = false
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
		say = function(text: string, tone: string?, icon: string?)
			Ui.sound(if tone == "red" then "error" else "toast")
			WorldText.center({ text = text, tone = (tone or "white") :: any, icon = icon })
		end,
		popAt = function(source: any, spec: any)
			WorldText.pop(source, spec)
		end,
		near = function(target: GuiObject?, spec: any)
			WorldText.near(target, spec)
		end,
		cheer = function(text: string, icon: string?)
			Ui.sound("toast")
			WorldText.near(pressed(), { text = text, icon = icon, tone = "green", size = 30 })
		end,
		warn = function(text: string, icon: string?)
			Ui.sound("error")
			WorldText.near(pressed(), { text = text, icon = icon, tone = "red", size = 30, shake = true })
		end,
		fail = function(err: string?)
			local e = Format.errorPop(err)
			ctx.warn(e.text, e.icon)
		end,
		fly = function(from: any, target: string, spec: any, onLand: (() -> ())?)
			WorldText.fly(from, if hud then hud.target(target) else nil, spec, onLand)
		end,
		hudTarget = function(name: string): GuiObject?
			return if hud then hud.target(name) else nil
		end,
		-- Menu button: confirm, then the leaving screen and a full reset (MISSION 2.5).
		leaveToMenu = function()
			if leavingNow then
				return
			end
			local inBattle = ctx.state.battle ~= nil
			ctx.confirm(
				"Main Menu",
				if inBattle
					then "Return to the main menu? The battle counts as a forfeit."
					else "Return to the main menu?",
				"Main Menu",
				function()
					task.spawn(leave)
				end
			)
		end,
		onLeave = function(fn: () -> ())
			table.insert(leaveHooks, fn)
		end,
		confirm = function(title: string, body: string, yes: string, onYes: () -> ())
			local box: Screen
			box = ctx.overlay(function(layer)
				Ui.frame({ BackgroundColor3 = C.Black, BackgroundTransparency = 0.4, Parent = layer })
				local p = Ui.panel(layer, title, function()
					box.destroy()
				end, UDim2.fromOffset(480, 250))
				local text = Ui.text({
					Text = body,
					FontFace = Theme.Face.Title,
					TextSize = 22,
					TextXAlignment = Enum.TextXAlignment.Center,
					Size = UDim2.new(1, 0, 0, 96),
					Parent = p.body,
				})
				Ui.outline(C.Night, 2).Parent = text
				Ui.fit(text, 22, 14)
				local row = Ui.frame({
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 1, -52),
					Size = UDim2.new(1, 0, 0, 48),
					Parent = p.body,
				}, { Ui.list(true, 12, Enum.HorizontalAlignment.Center) })
				local cancel = Ui.button("CANCEL", "tab", function()
					box.destroy()
				end, { Size = UDim2.fromOffset(150, 48) })
				local ok = Ui.button(string.upper(yes), "primary", function()
					box.destroy()
					onYes()
				end, { Size = UDim2.fromOffset(190, 48) })
				for _, b in { cancel, ok } do
					b.label.FontFace = Theme.Face.Display
					local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
					if cap then
						cap.MaxTextSize = 26
					end
				end
				cancel.instance.Parent = row
				ok.instance.Parent = row
				return { destroy = function() end }
			end)
		end,
		request = function(name: string, payload: any?, quiet: boolean?): Reply
			local reply = deps.net.request(name, payload)
			if not reply.ok and not quiet then
				ctx.fail(reply.err)
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
				ctx.warn("LIVE GAME ONLY", "icon_friends")
			end
		end,
	}

	hud = HudModule.build(ctx, hudLayer)
	WorldText.init(popLayer, function(): number
		return uiScale.Scale
	end, ctx.reducedMotion)
	Feedback.start(ctx)
	ItemIcon.preload(popLayer)
	fit()
	local leaving = false
	menu = MainMenu.build(menuLayer, {
		play = function()
			-- PLAY always starts fresh (MISSION 2.4): the server spawns a new character at the lobby
			-- spawn (Session.Play). The menu stays up until it stands there, so the fade and the
			-- camera fly-in start in the lobby.
			if leaving then
				return
			end
			leaving = true
			task.spawn(function()
				if ctx.request("Session.Play").ok then
					waitForLobby(5)
				end
				leaving = false
				ui("play")
			end)
		end,
		open = function(name: string, arg: any?)
			ctx.open(name, arg)
		end,
		live = deps.effects ~= nil, -- the real lobby shows behind the menu (UiEffects' menu camera)
		view = function()
			return ctx.state.view
		end,
		onChanged = function(fn: () -> ())
			ctx.state.changed:connect(function(what: string)
				if what == "profile" then
					fn()
				end
			end)
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
			Players.LocalPlayer:SetAttribute("UiReady", true) -- the launch loading screen waits for it
			if effects == nil or Players.LocalPlayer:GetAttribute("Session") == "playing" then
				-- previews and checks, or back from a battle server: straight to the game view
				ui("play")
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
		ctx.say(
			tostring(n.text),
			if n.kind == "error" then "red" elseif n.kind == "good" then "green" else "white"
		)
	end)
	return ctx
end

return App
