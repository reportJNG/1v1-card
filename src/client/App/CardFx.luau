--!strict
-- Animates the cards built by App/Card with one render-step loop for every card, and only for
-- cards that are actually on screen: every 0.2 s each card is checked (ScreenGui enabled, every
-- ancestor visible, not clipped out of a scroll list or the screen). Off-screen and hidden cards
-- cost nothing per frame. Effects per card (CARDS_EGGS_MISSION 4.5, board 07):
--   aura      the flame ring breathes and sways; grid cards show it only on hover
--   orbit     the light ribbon sways around the card (Legendary, Mythical)
--   glow      the frame glow breathes on a 1.5 s loop, stronger at higher rarity and stage
--   energy    the lightning layer flickers in short random bursts; from Ascended it crackles
--             continuously (flipped 180 degrees between frames: the card is symmetric)
--   shine     a diagonal sweep every 4-6 s (R and up, Golden, Max)
--   particles sparkles twinkle (SR), embers and motes rise (SSR, UR)
--   hover     grid cards lift to 1.05 with a brighter aura and a tick
--   parallax  layers shift toward the pointer on hover / drag (PC), while pressed (touch) or with
--             the device's tilt (mobile accelerometer)
-- Budget: at most MAX_BIG cards run their large effects (aura, orbit, particles) at once; the rest
-- keep only the cheap ones. Purely visual.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local CardFx = {}

local MAX_BIG = 6

export type Layer = { obj: GuiObject, base: UDim2, depth: number } -- depth: px at full tilt

export type Entry = {
	root: GuiObject,
	big: boolean,
	aura: ImageLabel?,
	auraBase: number,
	auraIdle: boolean,
	orbit: ImageLabel?,
	glow: ImageLabel?,
	glowBase: number,
	glowPulse: number,
	energy: ImageLabel?,
	energyBase: number,
	crackle: boolean,
	shine: GuiObject?,
	shineEvery: number,
	particles: { ImageLabel },
	particleMode: "twinkle" | "rise" | "none",
	layers: { Layer },
	tilt: Vector2, -- current (smoothed)
	target: Vector2, -- where the pointer / tilt wants it, -1..1 per axis
	held: boolean,
	interactive: boolean,
	hover: boolean,
	hovered: boolean,
	lift: UIScale?,
	visible: boolean,
	phase: number,
	seed: number,
	priority: number, -- who gets the large-effects budget first: bigger, higher stage, rarer
	burst: number?, -- internal: time left in the current energy burst
	nextBurst: number?,
	rich: boolean?, -- internal: within the large-effects budget this check
}

local entries: { Entry } = {}
local clock = 0
local checkIn = 0
local gravityTilt = Vector2.zero
local onHoverSound: (() -> ())? = nil

local function intersects(ax: Vector2, as: Vector2, bx: Vector2, bs: Vector2): boolean
	return ax.X < bx.X + bs.X and bx.X < ax.X + as.X and ax.Y < bx.Y + bs.Y and bx.Y < ax.Y + as.Y
end

-- On screen and shown: every GuiObject ancestor visible, the ScreenGui enabled, and the card's box
-- overlapping every clipping ancestor (scroll lists) and the screen.
local function onScreen(root: GuiObject): boolean
	local pos, size = root.AbsolutePosition, root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 or not root.Visible then
		return false
	end
	local at: Instance? = root.Parent
	while at do
		if at:IsA("GuiObject") then
			if not at.Visible then
				return false
			end
			if at.ClipsDescendants and not intersects(pos, size, at.AbsolutePosition, at.AbsoluteSize) then
				return false
			end
		elseif at:IsA("LayerCollector") then
			if not at.Enabled then
				return false
			end
			return intersects(pos, size, Vector2.zero, at.AbsoluteSize)
		end
		at = at.Parent
	end
	return false -- not under any ScreenGui
end

-- Pseudo-random 0..1 from a seed and a step (stable, no shared RNG state).
local function hash(a: number, b: number): number
	local x = math.sin(a * 12.9898 + b * 78.233) * 43758.5453
	return x - math.floor(x)
end

local function setRich(e: Entry, rich: boolean)
	e.rich = rich
	local showAura = rich and (not e.auraIdle or e.hovered)
	if e.aura then
		e.aura.Visible = showAura
	end
	if e.orbit then
		e.orbit.Visible = rich
	end
	for _, p in e.particles do
		p.Visible = rich
	end
end

local function step(dt: number)
	clock += dt
	checkIn -= dt
	local recheck = checkIn <= 0
	if recheck then
		checkIn = 0.2
		local candidates: { Entry } = {}
		for i = #entries, 1, -1 do
			local e = entries[i]
			if e.root.Parent == nil then
				table.remove(entries, i)
				continue
			end
			e.visible = onScreen(e.root)
			if e.visible and e.big then
				table.insert(candidates, e)
			else
				setRich(e, e.visible and e.hovered)
			end
		end
		-- Hovered and interactive cards always get their effects; the rest share the budget, in
		-- priority order.
		table.sort(candidates, function(a: Entry, b: Entry)
			return a.priority > b.priority
		end)
		local bigCount = 0
		for _, e in candidates do
			local rich = e.hovered or e.interactive or bigCount < MAX_BIG
			if rich and not (e.hovered or e.interactive) then
				bigCount += 1
			end
			setRich(e, rich)
		end
	end
	for _, e in entries do
		if not e.visible or e.root.Parent == nil then
			continue
		end
		local t = clock + e.phase
		local hoverBoost = if e.hovered then 0.25 else 0
		if e.aura and e.aura.Visible then
			e.aura.Rotation = math.sin(t * 0.8) * 4
			e.aura.ImageTransparency = math.clamp(e.auraBase - hoverBoost + 0.12 * math.sin(t * 2.2), 0, 1)
		end
		if e.orbit and e.orbit.Visible then
			e.orbit.Rotation = -12 + math.sin(t * 0.9) * 10
			e.orbit.ImageTransparency = 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 1.8))
		end
		if e.glow then
			-- 1.5 s breathing loop
			e.glow.ImageTransparency = math.clamp(
				e.glowBase + e.glowPulse * (0.5 + 0.5 * math.sin(t * (2 * math.pi / 1.5))) - hoverBoost * 0.5,
				0,
				1
			)
		end
		if e.energy then
			if e.crackle then
				local frame = math.floor(t * 14)
				e.energy.Rotation = if frame % 2 == 0 then 0 else 180
				e.energy.ImageTransparency = e.energyBase * 0.6 + 0.25 * hash(e.seed, frame)
			else
				-- short random bursts: mostly faint, a quick flicker every 1-3 s
				e.nextBurst = (e.nextBurst or (1 + 2 * hash(e.seed, 0))) - dt
				if (e.nextBurst :: number) <= 0 then
					e.burst = 0.25 + 0.2 * hash(e.seed, t)
					e.nextBurst = 1 + 2.2 * hash(e.seed + 1, t)
				end
				if e.burst and e.burst > 0 then
					e.burst -= dt
					local frame = math.floor(t * 20)
					e.energy.ImageTransparency = if frame % 2 == 0 then e.energyBase * 0.3 else 0.85
					e.energy.Rotation = if hash(e.seed, frame) > 0.5 then 180 else 0
				else
					e.energy.ImageTransparency = math.min(1, e.energyBase + 0.35)
				end
			end
		end
		if e.shine then
			local cycle = (t % e.shineEvery) / 0.8 -- the sweep takes 0.8 s of each cycle
			e.shine.Position = UDim2.fromScale(if cycle < 1 then -0.5 + 2 * cycle else -0.5, 0.5)
		end
		if e.rich then
			if e.particleMode == "twinkle" then
				for k, s in e.particles do
					local p = (t * 0.8 + k * 0.37) % 1
					s.ImageTransparency = 0.1 + 0.9 * math.abs(math.cos(p * math.pi))
					s.Rotation = (t * 40 + k * 70) % 360
				end
			elseif e.particleMode == "rise" then
				for k, s in e.particles do
					local p = (t * 0.2 + k / #e.particles) % 1
					local x = (k * 0.618) % 1
					s.Position = UDim2.fromScale(0.1 + 0.8 * x + math.sin(t + k) * 0.03, 0.98 - 0.9 * p)
					s.ImageTransparency = 0.1 + 0.9 * math.abs(p * 2 - 1) ^ 3
				end
			end
		end
		if e.interactive or e.hover then
			local goal = if e.held or e.target.Magnitude > 0 then e.target else gravityTilt
			if not e.interactive then
				goal = if e.hovered then e.target * 0.5 else Vector2.zero
			end
			e.tilt = e.tilt:Lerp(goal, math.min(1, dt * 10))
			for _, l in e.layers do
				l.obj.Position = l.base + UDim2.fromOffset(e.tilt.X * l.depth, e.tilt.Y * l.depth)
			end
		end
	end
end

local started = false
local function start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(step)
	if UserInputService.AccelerometerEnabled then
		UserInputService.DeviceGravityChanged:Connect(function(g: InputObject)
			local v = g.Position
			gravityTilt = Vector2.new(math.clamp(v.X * 1.6, -1, 1), math.clamp(-v.Y * 1.6 - 0.8, -1, 1))
		end)
	end
end

-- The sound played when a grid card is hovered (set by App, so CardFx doesn't need Ui).
function CardFx.setHoverSound(fn: () -> ())
	onHoverSound = fn
end

-- Pointer position over `face` as -1..1 per axis.
local function toTilt(face: GuiObject, at: Vector2): Vector2
	local rel = (at - face.AbsolutePosition) / face.AbsoluteSize
	return Vector2.new(math.clamp(rel.X * 2 - 1, -1, 1), math.clamp(rel.Y * 2 - 1, -1, 1))
end

local LIFT = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function setHovered(e: Entry, on: boolean)
	if e.hovered == on then
		return
	end
	e.hovered = on
	if e.lift then
		TweenService:Create(e.lift, LIFT, { Scale = if on then 1.05 else 1 }):Play()
	end
	if e.aura then
		e.aura.Visible = (e.rich == true or on) and (not e.auraIdle or on)
	end
	if on and onHoverSound then
		onHoverSound()
	end
end

-- Registers a card. `face` receives the pointer for parallax (`interactive`) and hover (`hover`).
function CardFx.add(e: Entry, face: GuiObject)
	start()
	e.visible = true
	table.insert(entries, e)
	setRich(e, e.big)
	if e.interactive or e.hover then
		face.MouseEnter:Connect(function()
			if e.hover then
				setHovered(e, true)
			end
		end)
		face.MouseMoved:Connect(function(x: number, y: number)
			e.target = toTilt(face, Vector2.new(x, y))
		end)
		face.MouseLeave:Connect(function()
			if not e.held then
				e.target = Vector2.zero
			end
			setHovered(e, false)
		end)
		face.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				e.held = true
				e.target = toTilt(face, Vector2.new(input.Position.X, input.Position.Y))
				if e.hover then
					setHovered(e, true)
				end
			end
		end)
		face.InputChanged:Connect(function(input: InputObject)
			if e.held and input.UserInputType == Enum.UserInputType.Touch then
				e.target = toTilt(face, Vector2.new(input.Position.X, input.Position.Y))
			end
		end)
		face.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				e.held = false
				e.target = Vector2.zero
				setHovered(e, false)
			end
		end)
	end
end

-- For the Studio checks: how many cards are registered, how many are animating right now, and
-- how many run their large effects.
function CardFx.stats(): (number, number, number)
	local live, rich = 0, 0
	for _, e in entries do
		if e.visible then
			live += 1
			if e.rich then
				rich += 1
			end
		end
	end
	return #entries, live, rich
end

return CardFx
