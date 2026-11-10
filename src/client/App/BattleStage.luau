--!strict
-- The 3D battle stage (BAD_GUI_8 sections 4-5), built locally on the client: the match's arena map
-- (Config/Arenas, picked by the server from the match seed), key lights on both pads, the two
-- active fighters as glowing aura silhouettes on light pads, and a scripted camera. It only PLAYS
-- the event packets the server sends (Hit, Parry, Shield, KO, Enter...): every number shown comes
-- from the server. Fighters are standees (Shared/Art/Standee: the character's cut-out art on a
-- panel, turned to the camera) until a character's approved model exists
-- (CharacterDef.assets.model).
-- Battle reactions are effects only (CLAUDE.md "Asset safety": hits and KOs never show faces):
-- sparks, a shield bubble, big numbers, a shock ring and "K.O.!", and a KO'd fighter shatters
-- into aura particles.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Arenas = require(Shared.Config.Arenas)
local Art = require(Shared.Config.Art)
local ArenaLayout = require(Shared.Domain.ArenaLayout)
local ArenaKit = require(Shared.Art.ArenaKit)
local Standee = require(Shared.Art.Standee)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.Kit)

local C = Theme.Color

local BattleStage = {}
BattleStage.__index = BattleStage

-- Far from the hub and the worlds; client-only parts, so every player gets their own stage.
local ORIGIN = Vector3.new(0, 800, 6000)
local MARK = ArenaLayout.MARK
local RENDER_KEY = "OneVOneBattleCamera"
local INTRO_SECONDS = 2.4
local ENTER_AT = 1.0 -- seconds into the intro when the fighters drop onto their pads

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local HOME_CAM = CFrame.lookAt(ORIGIN + v3(ArenaLayout.CAMERA.at), ORIGIN + v3(ArenaLayout.CAMERA.look))

export type Stage = typeof(setmetatable(
	{} :: {
		model: Model,
		arena: Arenas.Arena,
		you: number,
		fighters: { [number]: Model? },
		ids: { [number]: string },
		hp: { [number]: number }, -- HP shown on each side (for heal amounts)
		camera: Camera,
		shake: number,
		camBase: CFrame,
		reduced: boolean,
		saved: { cameraType: Enum.CameraType, cframe: CFrame, fov: number },
		playing: number, -- rounds still animating
		queued: { [number]: string }, -- fighters that enter once those rounds have played
		pending: { [number]: string }?, -- fighters waiting for the intro
		introSkip: (() -> ())?,
		spinners: { Model },
	},
	BattleStage
))

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function markPos(side: number, you: number): Vector3
	return ORIGIN + Vector3.new(if side == you then -MARK else MARK, 0, 0)
end

local function accentOf(characterId: string): Color3
	local def = Characters.ById[characterId]
	local fam = def and Art.FamilyColors[def.family]
	return if fam then Color3.fromHex(fam.accent) else C.Purple
end

-- The arena: the server's template for this map (core + meshes), or the same map without meshes
-- while the template hasn't replicated.
local function buildArena(arena: Arenas.Arena, model: Model)
	local folder = ReplicatedStorage:FindFirstChild("Arenas")
	local template = folder and folder:FindFirstChild(arena.id)
	local map: Model = if template and template:IsA("Model") then template:Clone() else ArenaKit.build(arena)
	map.Name = "Arena"
	map:PivotTo(CFrame.new(ORIGIN))
	map.Parent = model
end

local function spot(model: Model, at: Vector3, color: Color3, name: string, brightness: number): SpotLight
	local holder = part({ Name = name, Size = Vector3.new(1, 1, 1), Position = at, Transparency = 1 }, model)
	holder.CFrame = CFrame.lookAt(at, at - Vector3.new(0, 1, 0))
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Angle = 50
	s.Range = 40
	s.Brightness = brightness
	s.Color = color
	s.Shadows = true
	s.Parent = holder
	return s
end

function BattleStage.new(you: number, ids: { [number]: string }, reduced: boolean, arenaId: string?): Stage
	local model = Instance.new("Model")
	model.Name = "BattleStage"
	local arena = Arenas.ById[arenaId or ""] or Arenas.List[1]
	local camera = workspace.CurrentCamera
	local self = setmetatable({
		model = model,
		arena = arena,
		you = you,
		fighters = {},
		ids = {},
		hp = {},
		camera = camera,
		shake = 0,
		camBase = HOME_CAM,
		reduced = reduced,
		saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView },
		playing = 0,
		queued = {},
		pending = nil :: { [number]: string }?,
		introSkip = nil :: (() -> ())?,
		spinners = {},
	}, BattleStage)
	buildArena(arena, model)
	-- The fighters are always lit (BAD_GUI_8 section 5): a key light over each pad, a rim light in
	-- the fighter's family colour and a soft fill from the camera side.
	for side = 1, 2 do
		local mark = markPos(side, you)
		spot(model, mark + Vector3.new(0, 18, 4), Color3.fromHex("#F2ECFF"), `Key{side}`, 6)
		spot(model, mark + Vector3.new(if side == you then -6 else 6, 14, -8), C.Purple, `Rim{side}`, 5)
		local fill = part({
			Name = `Fill{side}`,
			Size = Vector3.one,
			Position = mark + Vector3.new(0, 5, 8),
			Transparency = 1,
		}, model)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromHex("#D8CCFF")
		l.Range = 16
		l.Brightness = 2
		l.Shadows = false
		l.Parent = fill
	end
	model.Parent = workspace
	for _, d in model:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Fx") == "Spin" then
			table.insert(self.spinners, d)
		end
	end
	if reduced then
		for side = 1, 2 do
			self:enter(side, ids[side])
		end
	else
		self.pending = { [1] = ids[1], [2] = ids[2] }
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 46
	camera.CFrame = HOME_CAM
	-- Runs after the default camera module (RenderPriority.Camera) and re-asserts Scriptable every
	-- frame, so the player's camera scripts can't pull the view back to the character.
	RunService:BindToRenderStep(RENDER_KEY, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		camera.CameraType = Enum.CameraType.Scriptable
		local s = self.shake
		local offset = CFrame.new()
		if s > 0.01 then
			offset = CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			self.shake = s * math.exp(-dt * 14)
		end
		camera.CFrame = self.camBase * offset
		if not self.reduced then
			for i, ring in self.spinners do
				ring:PivotTo(ring:GetPivot() * CFrame.Angles(0, dt * (if i % 2 == 0 then -0.12 else 0.18), 0))
			end
		end
	end)
	if table.find(arena.fx, "lightning") then
		self:_lightning()
	end
	return self
end

-- Storm Rooftop: a lightning flash every few seconds with its thunder a moment later (no flash
-- with reduced motion; the thunder stays).
function BattleStage._lightning(self: Stage)
	task.spawn(function()
		while self.model.Parent do
			task.wait(6 + math.random() * 7)
			if not self.model.Parent then
				return
			end
			if not self.reduced then
				local fx = Lighting:FindFirstChild("AreaColor")
				if fx and fx:IsA("ColorCorrectionEffect") then
					local base = fx.Brightness
					for _ = 1, 2 do
						fx.Brightness = base + 0.35
						task.wait(0.06)
						fx.Brightness = base
						task.wait(0.09)
					end
				end
			end
			task.wait(0.35)
			Ui.sound("thunder")
		end
	end)
end

-- The arena intro (about 2.4 s): the camera sweeps around the map from behind the fighters to the
-- wide shot, and the fighters drop onto their pads with an impact ring part-way. Returns a skip
-- function. With reduced motion there is no sweep (the fighters are already on their pads).
function BattleStage.intro(self: Stage): () -> ()
	if self.reduced then
		return function() end
	end
	local from = v3(ArenaLayout.INTRO.at)
	local to = v3(ArenaLayout.CAMERA.at)
	local a0, a1 = math.atan2(from.X, from.Z), math.atan2(to.X, to.Z)
	local r0 = Vector2.new(from.X, from.Z).Magnitude
	local r1 = Vector2.new(to.X, to.Z).Magnitude
	local look0, look1 = v3(ArenaLayout.INTRO.look), v3(ArenaLayout.CAMERA.look)
	local done = false
	local function landFighters()
		local pending = self.pending
		self.pending = nil
		if pending then
			for side = 1, 2 do
				self:enter(side, pending[side])
			end
		end
	end
	local function finish()
		if done then
			return
		end
		done = true
		self.camBase = HOME_CAM
		landFighters()
	end
	task.spawn(function()
		local t0 = os.clock()
		while not done and self.model.Parent do
			local t = math.clamp((os.clock() - t0) / INTRO_SECONDS, 0, 1)
			local e = 1 - (1 - t) ^ 3
			local a = a0 + (a1 - a0) * e
			local r = r0 + (r1 - r0) * e
			local y = from.Y + (to.Y - from.Y) * e
			local pos = ORIGIN + Vector3.new(math.sin(a) * r, y, math.cos(a) * r)
			self.camBase = CFrame.lookAt(pos, ORIGIN + look0:Lerp(look1, e))
			if self.pending and os.clock() - t0 >= ENTER_AT then
				landFighters()
			end
			if t >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		finish()
	end)
	self.introSkip = finish
	return finish
end

-- A flat shock ring on the floor (fighter landings, KOs).
function BattleStage.ring(self: Stage, at: Vector3, color: Color3, size: number)
	local r = part({
		Name = "ImpactRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, 2, 2),
		CFrame = CFrame.new(at + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.1,
	}, self.model)
	TweenService:Create(
		r,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad),
		{ Size = Vector3.new(0.1, size, size), Transparency = 1 }
	):Play()
	task.delay(0.5, function()
		r:Destroy()
	end)
end

-- The glowing aura around a fighter in its family colour (BAD_GUI_8: fighters as aura
-- silhouettes on light pads), plus the light that lifts it.
local function aura(rig: Model, color: Color3)
	local cf, size = rig:GetBoundingBox()
	local holder = part({
		Name = "Aura",
		Size = Vector3.new(size.X * 0.95, size.Y * 0.9, 0.6),
		CFrame = cf,
		Transparency = 1,
	}, rig)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura"
	e.Texture = Ui.asset("sparkle")
	e.Color = ColorSequence.new(color:Lerp(C.White, 0.55), color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.4, 1.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.7, 1.3)
	e.Speed = NumberRange.new(1.5, 3.5)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, 2, 0)
	e.Rate = 50
	e.Parent = holder
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 14
	glow.Brightness = 3
	glow.Shadows = false
	glow.Parent = holder
end

-- Puts a fighter on its pad (on start and when a card enters after a KO). While a round is still
-- animating, the new fighter waits until it has played, so the KO lands on the card that was
-- knocked out, not on its replacement.
function BattleStage.enter(self: Stage, side: number, characterId: string)
	if self.playing > 0 then
		self.queued[side] = characterId
		return
	end
	if self.pending then
		self.pending[side] = characterId
		return
	end
	local old = self.fighters[side]
	if old then
		old:Destroy()
	end
	self.ids[side] = characterId
	local rig = Standee.build(characterId)
	local mark = markPos(side, self.you)
	local facing = markPos(3 - side, self.you)
	-- Face the camera, turned a little toward the opponent; the pivot is the standee's feet.
	local toCamera = Vector3.new(HOME_CAM.Position.X, mark.Y, HOME_CAM.Position.Z) - mark
	local toFoe = (facing - mark).Unit
	local look = (toCamera.Unit * 0.8 + toFoe * 0.35).Unit
	rig:PivotTo(CFrame.lookAt(mark, mark + look))
	rig.Parent = self.model
	local color = accentOf(characterId)
	aura(rig, color)
	self.fighters[side] = rig
	local rim = self.model:FindFirstChild(`Rim{side}`)
	local light = rim and rim:FindFirstChildOfClass("SpotLight")
	if light then
		light.Color = color
	end
	-- The light pad takes the fighter's family colour.
	local arena = self.model:FindFirstChild("Arena")
	local core = arena and arena:FindFirstChild("ArenaCore")
	local pad = core and core:FindFirstChild(if side == self.you then "PadA" else "PadB")
	if pad and pad:IsA("BasePart") then
		pad.Color = color:Lerp(C.White, 0.35)
	end
	if not self.reduced then
		-- Drop in, then an impact ring on the pad.
		local home = rig:GetPivot()
		rig:PivotTo(home + Vector3.new(0, 9, 0))
		local v = Instance.new("NumberValue")
		v.Value = 9
		v.Changed:Connect(function(h)
			if rig.Parent then
				rig:PivotTo(home + Vector3.new(0, h, 0))
			end
		end)
		local t = TweenService:Create(
			v,
			TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Value = 0 }
		)
		t.Completed:Connect(function()
			v:Destroy()
			if rig.Parent then
				self:ring(mark, color, 12)
				self:burst(mark + Vector3.new(0, 1, 0), color, 16)
				self:addShake(0.5)
			end
		end)
		t:Play()
	end
end

-- A particle burst (family-coloured hit sparks, entrances, KOs).
function BattleStage.burst(self: Stage, at: Vector3, color: Color3, count: number)
	local holder = part(
		{ Name = "Burst", Size = Vector3.new(0.2, 0.2, 0.2), Position = at, Transparency = 1 },
		self.model
	)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Ui.asset("sparkle")
	e.Color = ColorSequence.new(color:Lerp(C.White, 0.3), color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Speed = NumberRange.new(10, 22)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = holder
	e:Emit(count)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 14
	glow.Brightness = 5
	glow.Parent = holder
	TweenService:Create(glow, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- A big number (or word) popping over a fighter: white Display type with a coloured outline;
-- `tag` adds a small word above it ("CRIT!").
function BattleStage.float(
	self: Stage,
	side: number,
	text: string,
	color: Color3,
	big: boolean?,
	tag: string?
)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf, size = rig:GetBoundingBox()
	local anchor = part({
		Name = "Float",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = cf.Position + Vector3.new((math.random() - 0.5) * 2, size.Y * 0.2, 1.5),
		Transparency = 1,
	}, self.model)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if big then 260 else 180, if big then 110 else 70)
	gui.AlwaysOnTop = false -- always-on-top billboards aren't drawn with this game's lighting
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Ui.display({
		Text = text,
		TextSize = if big then 64 else 46,
		TextColor3 = if tag then C.GoldHi else C.White,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, if big then 72 else 50),
		Parent = gui,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = 4
	end
	local small: TextLabel? = nil
	if tag then
		local t = Ui.display({
			Text = tag,
			TextSize = 30,
			TextColor3 = C.GoldHi,
			Size = UDim2.new(1, 0, 0, 34),
			Parent = gui,
		})
		local s = t:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = C.Red
			s.Thickness = 3
		end
		small = t
	end
	Ui.popIn(label, self.reduced)
	TweenService:Create(
		anchor,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ Position = anchor.Position + Vector3.new(0, 3, 0) }
	):Play()
	task.delay(0.65, function()
		local labels: { TextLabel } = { label }
		if small then
			table.insert(labels, small)
		end
		for _, l in labels do
			do
				TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				local s = l:FindFirstChildOfClass("UIStroke")
				if s then
					TweenService:Create(s, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				end
			end
		end
	end)
	task.delay(1.05, function()
		anchor:Destroy()
	end)
end

-- A reaction icon over a fighter (`icon_atk`, `icon_def`, `shockwave_ring`): it bounces in, holds
-- and fades, about 0.6 s in all.
function BattleStage.icon(self: Stage, side: number, slot: string, color: Color3?)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf, size = rig:GetBoundingBox()
	local anchor = part({
		Name = "Reaction",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = cf.Position + Vector3.new(0, size.Y / 2 + 2.5, 0),
		Transparency = 1,
	}, self.model)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(84, 84)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = anchor
	local image = Kit.image(slot, {
		Name = slot,
		ImageColor3 = color or C.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	if not self.reduced then
		local scale = Ui.new("UIScale", { Scale = 0.2, Parent = image })
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	task.delay(0.4, function()
		TweenService:Create(image, TweenInfo.new(0.2), { ImageTransparency = 1 }):Play()
	end)
	task.delay(0.65, function()
		anchor:Destroy()
	end)
end

-- Moves a fighter toward its opponent and back (the attack dash).
function BattleStage.lunge(self: Stage, side: number, distance: number)
	local rig = self.fighters[side]
	if rig == nil or self.reduced then
		return
	end
	local home = rig:GetPivot()
	local toward = (markPos(3 - side, self.you) - markPos(side, self.you)).Unit
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(d)
		if rig.Parent then
			rig:PivotTo(home + toward * d)
		end
	end)
	local out = TweenService:Create(v, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Value = distance })
	out.Completed:Connect(function()
		local back = TweenService:Create(v, TweenInfo.new(0.24, Enum.EasingStyle.Quad), { Value = 0 })
		back.Completed:Connect(function()
			v:Destroy()
		end)
		back:Play()
	end)
	out:Play()
end

-- Knock-back flinch on the fighter that was hit.
function BattleStage.flinch(self: Stage, side: number)
	local rig = self.fighters[side]
	if rig == nil or self.reduced then
		return
	end
	local home = rig:GetPivot()
	local away = (markPos(side, self.you) - markPos(3 - side, self.you)).Unit
	rig:PivotTo((home + away * 0.8) * CFrame.Angles(math.rad(-8), 0, 0))
	task.delay(0.12, function()
		if rig.Parent then
			rig:PivotTo(home)
		end
	end)
end

-- A translucent bubble around a fighter (Defend, Shield, parry).
function BattleStage.bubble(self: Stage, side: number, color: Color3)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf, size = rig:GetBoundingBox()
	local b = part({
		Name = "Bubble",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (size.Y + 1),
		Position = cf.Position,
		Color = color,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
	}, self.model)
	TweenService:Create(b, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	task.delay(0.75, function()
		b:Destroy()
	end)
end

-- A screen-wide flash through the area colour correction (Specials, parries).
function BattleStage.flash(self: Stage, amount: number)
	if self.reduced then
		return
	end
	local fx = Lighting:FindFirstChild("AreaColor")
	if fx and fx:IsA("ColorCorrectionEffect") then
		local base = fx.Brightness
		fx.Brightness = base + amount
		TweenService:Create(fx, TweenInfo.new(0.25), { Brightness = base }):Play()
	end
end

-- KO: a short slow-motion beat, then the fighter shatters into its aura particles.
function BattleStage.knockOut(self: Stage, side: number)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf = rig:GetBoundingBox()
	local color = accentOf(self.ids[side])
	self.fighters[side] = nil
	if self.reduced then
		self:burst(cf.Position, color, 30)
		rig:Destroy()
		return
	end
	local fx = Lighting:FindFirstChild("AreaColor")
	if fx and fx:IsA("ColorCorrectionEffect") then
		local sat = fx.Saturation
		fx.Saturation = -0.6
		TweenService:Create(fx, TweenInfo.new(0.8), { Saturation = sat }):Play()
	end
	-- slow motion: the fighter sinks a little while the aura flares
	local aurae = rig:FindFirstChild("Aura")
	local emitter = aurae and aurae:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter.Rate = 120
	end
	local home = rig:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		if rig.Parent then
			rig:PivotTo(home * CFrame.Angles(math.rad(a), 0, 0))
		end
	end)
	TweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Linear), { Value = 10 }):Play()
	task.delay(0.4, function()
		self:burst(cf.Position, color, 46)
		self:burst(cf.Position + Vector3.new(0, 1.5, 0), C.White, 18)
		self:ring(home.Position, color, 18)
		rig:Destroy()
		v:Destroy()
	end)
end

-- Camera: a quick cut to the attacker for a Special, then back to the wide shot.
function BattleStage.cutTo(self: Stage, side: number?)
	if self.reduced then
		return
	end
	if side == nil then
		self.camBase = HOME_CAM
		return
	end
	local mark = markPos(side, self.you)
	local other = markPos(3 - side, self.you)
	local dir = (other - mark).Unit
	self.camBase = CFrame.lookAt(mark - dir * 7 + Vector3.new(0, 6, 9), other + Vector3.new(0, 3, 0))
end

function BattleStage.addShake(self: Stage, amount: number)
	if not self.reduced then
		self.shake = math.max(self.shake, amount)
	end
end

function BattleStage.destroy(self: Stage)
	RunService:UnbindFromRenderStep(RENDER_KEY)
	self.model:Destroy()
	local cam = self.camera
	cam.CameraType = self.saved.cameraType
	cam.FieldOfView = self.saved.fov
	if self.saved.cameraType == Enum.CameraType.Scriptable then
		cam.CFrame = self.saved.cframe
	end
	-- The server moves the character back to the lobby when a battle ends (and it may have
	-- respawned meanwhile), so follow the current character, not the one the battle started with.
	local player = Players.LocalPlayer
	local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		cam.CameraSubject = humanoid
	end
end

-- A Roblox avatar for the result scene (nil when it can't be built, e.g. in Edit-mode previews).
local function avatarOf(userId: number?): Model?
	if userId == nil or userId <= 0 then
		return nil
	end
	local ok, built = pcall(function()
		local desc = Players:GetHumanoidDescriptionFromUserId(userId)
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or built == nil then
		return nil
	end
	local m = built :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = d.Name == "HumanoidRootPart"
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	local humanoid = m:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.PlatformStand = true
	end
	return m
end

-- Victory (both arms up) or defeat (head and shoulders down) by turning the R15 joints.
local function pose(m: Model, won: boolean)
	local function turn(jointName: string, cf: CFrame)
		for _, d in m:GetDescendants() do
			if d:IsA("Motor6D") and d.Name == jointName then
				d.C0 = d.C0 * cf
			end
		end
	end
	if won then
		turn("LeftShoulder", CFrame.Angles(0, 0, math.rad(-150)))
		turn("RightShoulder", CFrame.Angles(0, 0, math.rad(150)))
		turn("Neck", CFrame.Angles(math.rad(12), 0, 0))
	else
		turn("Neck", CFrame.Angles(math.rad(-30), 0, 0))
		turn("Waist", CFrame.Angles(math.rad(-14), 0, 0))
		turn("LeftShoulder", CFrame.Angles(0, 0, math.rad(8)))
		turn("RightShoulder", CFrame.Angles(0, 0, math.rad(-8)))
	end
end

-- A name billboard over a fighter's head (never always-on-top: see Shared/Ui/Billboard).
local function nameTag(at: BasePart, text: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Parent = at
	local label =
		Ui.display({ Text = string.upper(text), TextSize = 30, Size = UDim2.fromScale(1, 1), Parent = gui })
	label.TextColor3 = C.White
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color:Lerp(C.Night, 0.5)
		stroke.Thickness = 3
	end
end

export type ResultSide = {
	userId: number?, -- a player's avatar; nil for the Guardian (its lead card's standee)
	characterId: string, -- the side's MVP card (standee fallback, aura colour)
	name: string,
	won: boolean,
}

-- The result scene (BAD_GUI_7 section 3): both fighters back on their pads, the player's avatar
-- on the left and the opponent's (or the Guardian) on the right, in victory or defeat poses with
-- name billboards; embers rise, and the camera pushes in slowly.
function BattleStage.showResult(self: Stage, sides: { [number]: ResultSide }, mobile: boolean)
	self.pending = nil
	self.queued = {}
	for side = 1, 2 do
		local spec = sides[side]
		local old = self.fighters[side]
		if old then
			old:Destroy()
			self.fighters[side] = nil
		end
		local mark = markPos(side, self.you)
		local color = accentOf(spec.characterId)
		local toCamera = Vector3.new(HOME_CAM.Position.X, mark.Y, HOME_CAM.Position.Z) - mark
		local toFoe = (markPos(3 - side, self.you) - mark).Unit
		local look = (toCamera.Unit * 0.85 + toFoe * 0.3).Unit
		local avatar = avatarOf(spec.userId)
		local head: BasePart?
		local r: Model
		if avatar then
			r = avatar
			local rig = avatar
			rig.Parent = self.model
			task.wait() -- parenting re-applies the rig; place it afterwards
			rig:PivotTo(CFrame.lookAt(mark, mark + look))
			local box, size = rig:GetBoundingBox()
			rig:PivotTo(rig:GetPivot() + Vector3.new(0, mark.Y + 0.3 - (box.Position.Y - size.Y / 2), 0))
			pose(rig, spec.won)
			head = rig:FindFirstChild("Head") :: BasePart?
		else
			r = Standee.build(spec.characterId)
			r:PivotTo(CFrame.lookAt(mark, mark + look))
			r.Parent = self.model
			if not spec.won then
				r:PivotTo(r:GetPivot() * CFrame.Angles(math.rad(-10), 0, 0))
			end
			head = r:FindFirstChild("Panel") :: BasePart?
		end
		aura(r, color)
		if not spec.won then
			local a = r:FindFirstChild("Aura")
			local e = a and a:FindFirstChildOfClass("ParticleEmitter")
			if e then
				e.Rate = 12
			end
		end
		if head then
			nameTag(head, spec.name, color, if r:FindFirstChildOfClass("Humanoid") then 1.6 else 4)
		end
		self.fighters[side] = r
		self:ring(mark, color, 12)
	end
	-- embers and drifting debris over the arena (about 40% on phones)
	local holder = part({
		Name = "ResultEmbers",
		Size = Vector3.new(60, 1, 30),
		Position = ORIGIN + Vector3.new(0, -1, -4),
		Transparency = 1,
	}, self.model)
	local e = Instance.new("ParticleEmitter")
	e.Texture = Ui.asset("sparkle")
	e.Color = ColorSequence.new(Color3.fromHex("#FFC27A"), Color3.fromHex("#C05AFF"))
	e.LightEmission = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.35),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Lifetime = NumberRange.new(3, 6)
	e.Speed = NumberRange.new(1.5, 4)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0.4, 0.8, 0)
	e.Rate = if mobile then 10 else 26
	e.Parent = holder
	-- the slow push-in
	self.camBase = HOME_CAM
	if not self.reduced then
		local v = Instance.new("NumberValue")
		v.Changed:Connect(function(d)
			self.camBase = HOME_CAM * CFrame.new(0, 0, -d)
		end)
		TweenService:Create(v, TweenInfo.new(6, Enum.EasingStyle.Sine), { Value = 4 }):Play()
	end
end

-- Plays one resolved round's events in order, with hit-stop, numbers, shake and VFX.
-- `special[side]` is true when that side picked a Special this round. `onEvent` is called as each
-- event lands (the HUD drains HP bars then), `onDone` once the round has played.
function BattleStage.play(
	self: Stage,
	events: { { any } },
	special: { [number]: boolean },
	onEvent: ((e: { any }) -> ())?,
	onDone: (() -> ())?
)
	self.playing += 1
	task.spawn(function()
		if self.introSkip then
			self.introSkip()
		end
		self:playEvents(events, special, onEvent)
		self.playing -= 1
		if self.playing == 0 and self.model.Parent then
			for side, id in self.queued do
				self.queued[side] = nil
				self:enter(side, id)
			end
		end
		if onDone then
			onDone()
		end
	end)
end

function BattleStage.playEvents(
	self: Stage,
	events: { { any } },
	special: { [number]: boolean },
	onEvent: ((e: { any }) -> ())?
)
	local function landed(e: { any })
		if onEvent then
			onEvent(e)
		end
	end
	for _, e in events do
		if self.model.Parent == nil then
			return
		end
		local kind = e[1]
		if kind == "Hit" then
			local attacker = e[2] :: number
			local target = 3 - attacker
			local isSpecial = special[attacker] == true
			local crit = e[4] == 1
			local color = accentOf(self.ids[attacker] or "")
			if isSpecial then
				-- camera cut to the caster, an aura burst and a screen flash, then the hit
				self:cutTo(attacker)
				self:burst(markPos(attacker, self.you) + Vector3.new(0, 3, 0), color, 24)
				self:flash(0.25)
				task.wait(0.35)
			end
			self:lunge(attacker, MARK * 0.9)
			task.wait(0.16)
			Ui.sound(if isSpecial then "hit_special" else "hit")
			local rig = self.fighters[target]
			if rig then
				local cf = rig:GetBoundingBox()
				self:burst(cf.Position, color, if isSpecial then 28 else 12)
			end
			self:flinch(target)
			self:addShake(if isSpecial then 1.1 elseif crit then 0.8 else 0.45)
			self.hp[target] = e[5]
			landed(e)
			self:float(
				target,
				tostring(e[3]),
				if crit then C.Red elseif isSpecial then color:Lerp(C.Night, 0.35) else C.Night,
				isSpecial or crit,
				if crit then "CRIT!" else nil
			)
			task.wait(if isSpecial or crit then 0.12 else 0.06) -- hit-stop
			if isSpecial then
				task.wait(0.3)
				self:cutTo(nil)
			end
			task.wait(0.3)
		elseif kind == "Parry" then
			local side = e[2] :: number
			self:bubble(side, C.Blue)
			self:flash(0.18)
			self:float(side, "PARRY!", C.Blue, true)
			Ui.sound("parry")
			landed(e)
			task.wait(0.45)
		elseif kind == "Shield" or kind == "Stance" then
			self:bubble(e[2] :: number, C.Blue)
			landed(e)
			task.wait(0.3)
		elseif kind == "Heal" then
			local side = e[2] :: number
			local before = self.hp[side]
			self.hp[side] = e[3]
			landed(e)
			local gained = if before then e[3] - before else nil
			self:float(side, if gained and gained > 0 then `+{gained}` else "+HP", C.Green)
			local rig = self.fighters[side]
			if rig then
				self:burst(rig:GetBoundingBox().Position, C.Green, 12)
			end
			task.wait(0.3)
		elseif kind == "Burn" or kind == "Recoil" then
			self.hp[e[2] :: number] = e[4]
			landed(e)
			self:float(e[2] :: number, tostring(e[3]), Color3.fromHex("#FF6A2A"))
			task.wait(0.25)
		elseif kind == "Reflect" then
			self.hp[3 - (e[2] :: number)] = e[4]
			landed(e)
			self:float(3 - (e[2] :: number), tostring(e[3]), C.Blue)
			task.wait(0.25)
		elseif kind == "KO" then
			local side = e[2] :: number
			Ui.sound("ko")
			self.hp[side] = 0
			landed(e)
			self:icon(side, "shockwave_ring", C.Red)
			self:addShake(1.4)
			self:knockOut(side)
			task.wait(0.9)
		elseif kind == "Round" then
			-- the HUD flips both picks in over the timer; a short beat before the actions play
			landed(e)
			task.wait(if self.reduced then 0.3 else 0.7)
		else
			landed(e)
		end
	end
end

return BattleStage
