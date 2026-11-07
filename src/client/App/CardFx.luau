--!strict
-- Animates the layered cards built by App/Card with one render-step loop for every card, and only
-- for cards that are actually on screen: every 0.2 s each card is checked (ScreenGui enabled,
-- every ancestor visible, not clipped out of a scroll list or the screen). Off-screen and hidden
-- cards cost nothing per frame. Effects per card:
--   frame   the frame's UIGradient turning (Epic, Mythical)
--   glow    the outer glow's pulse (Legendary, Mythical, level 15)
--   shine   a periodic light sweep (Rare and up, Golden)
--   holo    the holo foil's moving rainbow (Mythical); foil shimmer (Golden)
--   sparks  twinkling sparkles (Legendary) or rising particles (Mythical)
--   parallax  layers shift toward the pointer on hover / drag (PC), while pressed (touch) or with
--             the device's tilt (mobile accelerometer)
-- Purely visual.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CardFx = {}

export type Layer = { obj: GuiObject, base: UDim2, depth: number } -- depth: px at full tilt

export type Entry = {
	root: GuiObject,
	frameGrad: UIGradient?,
	glowGrad: UIGradient?, -- turned with the frame (Epic, Mythical)
	frameSpin: number, -- degrees per second (0 = static)
	glow: ImageLabel?,
	glowBase: number, -- resting transparency
	glowPulse: number, -- 0 = none
	shine: GuiObject?,
	shineEvery: number,
	holoGrad: UIGradient?,
	foilGrad: UIGradient?,
	sparks: { ImageLabel },
	sparkMode: "twinkle" | "rise" | "none",
	layers: { Layer },
	tilt: Vector2, -- current (smoothed)
	target: Vector2, -- where the pointer / tilt wants it, -1..1 per axis
	held: boolean,
	interactive: boolean,
	visible: boolean,
	phase: number,
}

local entries: { Entry } = {}
local clock = 0
local checkIn = 0
local gravityTilt = Vector2.zero

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

local function step(dt: number)
	clock += dt
	checkIn -= dt
	local recheck = checkIn <= 0
	if recheck then
		checkIn = 0.2
	end
	for i = #entries, 1, -1 do
		local e = entries[i]
		if e.root.Parent == nil then
			table.remove(entries, i)
			continue
		end
		if recheck then
			e.visible = onScreen(e.root)
		end
		if not e.visible then
			continue
		end
		local t = clock + e.phase
		if e.frameGrad and e.frameSpin ~= 0 then
			e.frameGrad.Rotation = (t * e.frameSpin) % 360
			if e.glowGrad then
				e.glowGrad.Rotation = (t * e.frameSpin) % 360
			end
		end
		if e.glow and e.glowPulse > 0 then
			e.glow.ImageTransparency = e.glowBase + e.glowPulse * (0.5 + 0.5 * math.sin(t * 2.6))
		end
		if e.shine then
			local cycle = (t % e.shineEvery) / 0.9 -- the sweep takes 0.9 s of each cycle
			e.shine.Position = UDim2.fromScale(if cycle < 1 then -0.4 + 1.8 * cycle else -0.4, 0.5)
		end
		if e.holoGrad then
			e.holoGrad.Offset = Vector2.new(math.sin(t * 0.7) * 0.5, math.cos(t * 0.5) * 0.3)
			e.holoGrad.Rotation = 35 + math.sin(t * 0.4) * 20
		end
		if e.foilGrad then
			e.foilGrad.Offset = Vector2.new(((t * 0.35) % 2) - 1, 0)
		end
		if e.sparkMode == "twinkle" then
			for k, s in e.sparks do
				local p = (t * 0.9 + k * 0.37) % 1
				s.ImageTransparency = 0.1 + 0.9 * math.abs(math.cos(p * math.pi))
				s.Rotation = (t * 40 + k * 70) % 360
			end
		elseif e.sparkMode == "rise" then
			for k, s in e.sparks do
				local p = (t * 0.18 + k / #e.sparks) % 1
				local x = (k * 0.618) % 1
				s.Position = UDim2.fromScale(0.12 + 0.76 * x + math.sin(t + k) * 0.03, 0.95 - 0.85 * p)
				s.ImageTransparency = 0.15 + 0.85 * math.abs(p * 2 - 1) ^ 3
			end
		end
		if e.interactive then
			local goal = if e.held or e.target.Magnitude > 0 then e.target else gravityTilt
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

-- Pointer position over `face` as -1..1 per axis.
local function toTilt(face: GuiObject, at: Vector2): Vector2
	local rel = (at - face.AbsolutePosition) / face.AbsoluteSize
	return Vector2.new(math.clamp(rel.X * 2 - 1, -1, 1), math.clamp(rel.Y * 2 - 1, -1, 1))
end

-- Registers a card. `face` receives the pointer for parallax when `e.interactive`.
function CardFx.add(e: Entry, face: GuiObject)
	start()
	e.visible = true
	table.insert(entries, e)
	if e.interactive then
		face.MouseMoved:Connect(function(x: number, y: number)
			e.target = toTilt(face, Vector2.new(x, y))
		end)
		face.MouseLeave:Connect(function()
			if not e.held then
				e.target = Vector2.zero
			end
		end)
		face.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.Touch then
				e.held = true
				e.target = toTilt(face, Vector2.new(input.Position.X, input.Position.Y))
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
			end
		end)
	end
end

-- For the Studio checks: how many cards are registered and how many are animating right now.
function CardFx.stats(): (number, number)
	local live = 0
	for _, e in entries do
		if e.visible then
			live += 1
		end
	end
	return #entries, live
end

return CardFx
