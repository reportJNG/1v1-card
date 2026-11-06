--!strict
-- The 3D battle stage (ART_STYLE sections 6-7), built locally on the client: a dark stage with a
-- glowing ring, spotlights on both marks, the two active fighters, and a scripted camera. It only
-- PLAYS the event packets the server sends (Hit, Parry, Shield, KO, Enter...): every number shown
-- comes from the server. Placeholder rigs (Shared/Art/RigBuilder) stand in until a character's
-- approved model exists (CharacterDef.assets.model).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Config.Characters)
local Art = require(Shared.Config.Art)
local RigBuilder = require(Shared.Art.RigBuilder)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local C = Theme.Color

local BattleStage = {}
BattleStage.__index = BattleStage

-- Far from the hub and the worlds; client-only parts, so every player gets their own stage.
local ORIGIN = Vector3.new(0, 800, 6000)
local MARK = 11 -- studs from the centre to each fighter's mark
local RENDER_KEY = "OneVOneBattleCamera"
local HOME_CAM = CFrame.lookAt(ORIGIN + Vector3.new(0, 7.5, 27), ORIGIN + Vector3.new(0, 3.2, 0))

export type Stage = typeof(setmetatable(
	{} :: {
		model: Model,
		you: number,
		fighters: { [number]: Model? },
		ids: { [number]: string },
		camera: Camera,
		shake: number,
		camBase: CFrame,
		reduced: boolean,
		saved: { cameraType: Enum.CameraType, cframe: CFrame, fov: number },
	},
	BattleStage
))

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
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

-- The stage floor: a dark glossy disc with a violet inner ring and a cyan outer ring, plus a
-- spotlight over each mark (rim-lit in the fighter's family colour when it enters).
local function buildFloor(model: Model)
	part({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 54, 54),
		CFrame = CFrame.new(ORIGIN - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#2A2150"),
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
		CanCollide = true,
	}, model)
	for _, ring in { { d = 30, color = "#A469FF", y = 0.02 }, { d = 54.6, color = "#45BEFF", y = 0.0 } } do
		part({
			Name = "Ring",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, ring.d, ring.d),
			CFrame = CFrame.new(ORIGIN + Vector3.new(0, ring.y + 0.01, 0))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromHex(ring.color),
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		}, model)
	end
	-- Inner floor so the rings read as lines, not discs.
	part({
		Name = "Inner",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.14, 29.4, 29.4),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#30265C"),
		Material = Enum.Material.Glass,
		Reflectance = 0.2,
	}, model)
	part({
		Name = "Outer",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.13, 53.8, 53.8),
		CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.015, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#2A2150"),
		Material = Enum.Material.Glass,
		Reflectance = 0.15,
	}, model)
	-- Hub props as a backdrop when the server has shared them (StageProps), else just darkness.
	local props = ReplicatedStorage:FindFirstChild("StageProps")
	if props then
		local backdrop = props:Clone()
		backdrop:PivotTo(CFrame.new(ORIGIN))
		backdrop.Parent = model
	end
end

local function spot(model: Model, at: Vector3, color: Color3, name: string): SpotLight
	local holder = part({ Name = name, Size = Vector3.new(1, 1, 1), Position = at, Transparency = 1 }, model)
	holder.CFrame = CFrame.lookAt(at, at - Vector3.new(0, 1, 0))
	local s = Instance.new("SpotLight")
	s.Face = Enum.NormalId.Front
	s.Angle = 50
	s.Range = 40
	s.Brightness = 6
	s.Color = color
	s.Shadows = true
	s.Parent = holder
	return s
end

function BattleStage.new(you: number, ids: { [number]: string }, reduced: boolean): Stage
	local model = Instance.new("Model")
	model.Name = "BattleStage"
	local camera = workspace.CurrentCamera
	local self = setmetatable({
		model = model,
		you = you,
		fighters = {},
		ids = {},
		camera = camera,
		shake = 0,
		camBase = HOME_CAM,
		reduced = reduced,
		saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView },
	}, BattleStage)
	buildFloor(model)
	for side = 1, 2 do
		local mark = markPos(side, you)
		spot(model, mark + Vector3.new(0, 18, 4), Color3.fromHex("#E8DEFF"), `Key{side}`)
		spot(model, mark + Vector3.new(if side == you then -6 else 6, 14, -8), C.Purple, `Rim{side}`)
		-- Soft fill from the camera side so the fighters read against the dark stage.
		local fill = part({
			Name = `Fill{side}`,
			Size = Vector3.one,
			Position = mark + Vector3.new(0, 5, 8),
			Transparency = 1,
		}, model)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromHex("#D8CCFF")
		l.Range = 16
		l.Brightness = 2.2
		l.Shadows = false
		l.Parent = fill
	end
	model.Parent = workspace
	for side = 1, 2 do
		self:enter(side, ids[side])
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
	end)
	return self
end

-- Puts a fighter on its mark (on start and when a card enters after a KO).
function BattleStage.enter(self: Stage, side: number, characterId: string)
	local old = self.fighters[side]
	if old then
		old:Destroy()
	end
	self.ids[side] = characterId
	local rig = RigBuilder.build(characterId)
	local mark = markPos(side, self.you)
	local facing = markPos(3 - side, self.you)
	local _, size = rig:GetBoundingBox()
	rig:PivotTo(
		CFrame.lookAt(
			mark + Vector3.new(0, size.Y / 2, 0),
			Vector3.new(facing.X, mark.Y + size.Y / 2, facing.Z)
		)
	)
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	rig.Parent = self.model
	self.fighters[side] = rig
	local rim = self.model:FindFirstChild(`Rim{side}`)
	local light = rim and rim:FindFirstChildOfClass("SpotLight")
	if light then
		light.Color = accentOf(characterId)
	end
	if not self.reduced then
		-- Drop in with a flash.
		local home = rig:GetPivot()
		rig:PivotTo(home + Vector3.new(0, 8, 0))
		local v = Instance.new("NumberValue")
		v.Value = 8
		v.Changed:Connect(function(h)
			if rig.Parent then
				rig:PivotTo(home + Vector3.new(0, h, 0))
			end
		end)
		local t = TweenService:Create(v, TweenInfo.new(0.35, Enum.EasingStyle.Bounce), { Value = 0 })
		t.Completed:Connect(function()
			v:Destroy()
		end)
		t:Play()
		self:burst(mark + Vector3.new(0, 1, 0), accentOf(characterId), 14)
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

-- A floating number (or word) over a fighter: white Display type with a coloured outline.
function BattleStage.float(self: Stage, side: number, text: string, color: Color3, big: boolean?)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf, size = rig:GetBoundingBox()
	local anchor = part({
		Name = "Float",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Position = cf.Position + Vector3.new((math.random() - 0.5) * 2, size.Y / 2 + 1, 0),
		Transparency = 1,
	}, self.model)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if big then 240 else 160, if big then 90 else 60)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Ui.display({
		Text = text,
		TextSize = if big then 60 else 42,
		TextColor3 = C.White,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
		stroke.Thickness = 4
	end
	Ui.popIn(label, self.reduced)
	TweenService:Create(
		anchor,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad),
		{ Position = anchor.Position + Vector3.new(0, 3, 0) }
	):Play()
	task.delay(0.6, function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		if stroke then
			TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end
	end)
	task.delay(1, function()
		anchor:Destroy()
	end)
end

-- Moves a fighter toward its opponent and back (attack lunge).
function BattleStage.lunge(self: Stage, side: number, distance: number)
	local rig = self.fighters[side]
	if rig == nil or self.reduced then
		return
	end
	local home = rig:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(d)
		if rig.Parent then
			rig:PivotTo(home * CFrame.new(0, 0, -d))
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
	rig:PivotTo(home * CFrame.new(0, 0, 0.8) * CFrame.Angles(math.rad(-8), 0, 0))
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

function BattleStage.knockOut(self: Stage, side: number)
	local rig = self.fighters[side]
	if rig == nil then
		return
	end
	local cf, size = rig:GetBoundingBox()
	self:burst(cf.Position, accentOf(self.ids[side]), 30)
	if self.reduced then
		rig:Destroy()
		self.fighters[side] = nil
		return
	end
	local fx = Lighting:FindFirstChild("AreaColor")
	if fx and fx:IsA("ColorCorrectionEffect") then
		local sat = fx.Saturation
		fx.Saturation = -0.6
		TweenService:Create(fx, TweenInfo.new(0.6), { Saturation = sat }):Play()
	end
	local home = rig:GetPivot()
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		if rig.Parent then
			rig:PivotTo(
				home
					* CFrame.new(0, -size.Y / 2, 0)
					* CFrame.Angles(math.rad(a), 0, 0)
					* CFrame.new(0, size.Y / 2, 0)
			)
		end
	end)
	TweenService:Create(v, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Value = 82 }):Play()
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

-- Plays one resolved round's events in order, with hit-stop, numbers, shake and VFX.
-- `special[side]` is true when that side picked a Special this round.
function BattleStage.play(self: Stage, events: { { any } }, special: { [number]: boolean })
	task.spawn(function()
		for _, e in events do
			if self.model.Parent == nil then
				return
			end
			local kind = e[1]
			if kind == "Hit" then
				local attacker = e[2] :: number
				local target = 3 - attacker
				local isSpecial = special[attacker] == true
				local color = accentOf(self.ids[attacker] or "")
				if isSpecial then
					self:cutTo(attacker)
					self:burst(markPos(attacker, self.you) + Vector3.new(0, 3, 0), color, 20)
					task.wait(0.3)
				end
				self:lunge(attacker, MARK * 0.9)
				task.wait(0.16)
				Ui.sound(if isSpecial then "hit_special" else "hit")
				local rig = self.fighters[target]
				if rig then
					local cf = rig:GetBoundingBox()
					self:burst(
						cf.Position,
						if isSpecial then color else C.White,
						if isSpecial then 26 else 10
					)
				end
				self:flinch(target)
				self:addShake(if isSpecial then 1.1 else 0.45)
				self:float(
					target,
					tostring(e[3]) .. (if e[4] == 1 then "!" else ""),
					if isSpecial then color else C.Red,
					isSpecial or e[4] == 1
				)
				task.wait(if isSpecial then 0.12 else 0.06) -- hit-stop
				if isSpecial then
					task.wait(0.35)
					self:cutTo(nil)
				end
				task.wait(0.3)
			elseif kind == "Parry" then
				local side = e[2] :: number
				self:bubble(side, C.Blue)
				self:float(side, "PARRY!", C.Blue, true)
				Ui.sound("parry")
				task.wait(0.4)
			elseif kind == "Shield" or kind == "Stance" then
				self:bubble(e[2] :: number, C.Blue)
				task.wait(0.3)
			elseif kind == "Heal" then
				self:float(e[2] :: number, "+HP", C.Green)
				local rig = self.fighters[e[2] :: number]
				if rig then
					self:burst(rig:GetBoundingBox().Position, C.Green, 12)
				end
				task.wait(0.3)
			elseif kind == "Burn" or kind == "Recoil" then
				self:float(e[2] :: number, tostring(e[3]), Color3.fromHex("#FF8A3D"))
				task.wait(0.25)
			elseif kind == "Reflect" then
				self:float(3 - (e[2] :: number), tostring(e[3]), C.Blue)
				task.wait(0.25)
			elseif kind == "KO" then
				Ui.sound("ko")
				self:knockOut(e[2] :: number)
				self:addShake(1.4)
				task.wait(0.6)
			end
		end
	end)
end

return BattleStage
