--!strict
-- Client-side area presentation: applies the Config/Lighting preset and the music for where the
-- player is (World attribute 0 = hub, n = world n with preset "world<n>" and music
-- "music_world<n>", or the battle arena's own preset and music while a battle screen is open:
-- Config/Arenas) and animates the portal swirls in
-- the hub and in every world. Purely visual; nothing here affects game state.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presets = require(Shared.Config.Lighting)
local Arenas = require(Shared.Config.Arenas)
local Ui = require(script.Parent.Ui)
local Sounds = require(Shared.Config.Sounds)
local HubLayout = require(Shared.Config.HubLayout)
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local AreaFx = {}

local FADE = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local function effect<T>(className: string, name: string): T
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found :: any
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e :: any
end

local current: string? = nil

-- Applies a preset by name ("hub", "arena", "world1".."world10"). `instant` skips the tween
-- (edit-mode previews and the first apply).
function AreaFx.apply(name: string, instant: boolean?)
	local p = Presets[name]
	if p == nil or current == name then
		return
	end
	current = name
	local function set(inst: Instance, goal: { [string]: any })
		if instant then
			for k, v in goal do
				(inst :: any)[k] = v
			end
		else
			TweenService:Create(inst, FADE, goal):Play()
		end
	end
	set(Lighting, {
		ClockTime = p.clockTime,
		Brightness = p.brightness,
		ExposureCompensation = p.exposure,
		Ambient = Color3.fromHex(p.ambient),
		OutdoorAmbient = Color3.fromHex(p.outdoorAmbient),
		EnvironmentDiffuseScale = p.envDiffuse,
		EnvironmentSpecularScale = p.envSpecular,
	})
	local a = p.atmosphere
	set(effect("Atmosphere", "AreaAtmosphere"), {
		Density = a.density,
		Offset = a.offset,
		Color = Color3.fromHex(a.color),
		Decay = Color3.fromHex(a.decay),
		Glare = a.glare,
		Haze = a.haze,
	})
	set(effect("BloomEffect", "AreaBloom"), {
		Intensity = p.bloom.intensity,
		Size = p.bloom.size,
		Threshold = p.bloom.threshold,
	})
	set(effect("ColorCorrectionEffect", "AreaColor"), {
		Brightness = p.color.brightness,
		Contrast = p.color.contrast,
		Saturation = p.color.saturation,
		TintColor = Color3.fromHex(p.color.tint),
	})
	set(
		effect("SunRaysEffect", "AreaSunRays"),
		{ Intensity = p.sunRays.intensity, Spread = p.sunRays.spread }
	)
	local sky = Lighting:FindFirstChild("AreaSky") :: Sky?
	if p.sky then
		local s: Sky = sky or effect("Sky", "AreaSky")
		s.SkyboxFt = p.sky.ft
		s.SkyboxBk = p.sky.bk
		s.SkyboxLf = p.sky.lf
		s.SkyboxRt = p.sky.rt
		s.SkyboxUp = p.sky.up
		s.SkyboxDn = p.sky.dn
		s.StarCount = p.sky.stars
		s.MoonAngularSize = p.sky.moon or 0
		s.SunAngularSize = 0
		s.CelestialBodiesShown = p.sky.moon ~= nil
	elseif sky then
		sky:Destroy()
	end
end

local battleOpen = false
local battleArena: string? = nil
local musicOn = true
local musicVolume = 0.8 -- the player's music volume (Settings, 0-1)
local sfxVolume = 1 -- the player's SFX volume (Settings, 0-1), for the lobby's ambience
local track: Sound? = nil
local trackName: string? = nil

-- Crossfades to an area's looping track (Config/Sounds music_*). Silent when the slot has no id
-- or the player turned music off in Settings.
local function playMusic(name: string?)
	if name == trackName then
		return
	end
	trackName = name
	local old = track
	if old then
		local fade = TweenService:Create(old, FADE, { Volume = 0 })
		fade.Completed:Connect(function()
			old:Destroy()
		end)
		fade:Play()
	end
	track = nil
	local def = if name then Sounds[name] else nil
	if def == nil or def.id == nil or not musicOn then
		return
	end
	-- A Sound made in the first moments of a session can stay unloaded for good (seen in Play: the
	-- menu track never loaded while every other id did), so an unloaded track is rebuilt, up to 3 times.
	local function start(attempt: number)
		local snd = Instance.new("Sound")
		snd.Name = `Music_{name}`
		snd.SoundId = def.id :: string
		snd.Looped = def.looped == true
		snd.Volume = 0
		snd.Parent = SoundService
		snd:Play()
		TweenService:Create(snd, FADE, { Volume = def.volume * musicVolume }):Play()
		track = snd
		task.delay(4, function()
			if track == snd and not snd.IsLoaded and attempt < 3 then
				snd:Destroy()
				start(attempt + 1)
			end
		end)
	end
	start(1)
end

function AreaFx.setMusicVolume(v: number)
	musicVolume = math.clamp(v, 0, 1)
	local name = trackName
	local def = if name then Sounds[name] else nil
	if track and def then
		track.Volume = def.volume * musicVolume
	end
end

function AreaFx.setMusic(on: boolean)
	musicOn = on
	local name = trackName
	trackName = nil
	playMusic(if on then name else nil)
	if not on then
		trackName = name
	end
end

local onMenu = false
local reducedOf: () -> boolean = function()
	return false
end
local lobbyMotion: (Instance) -> ()

local function refresh()
	local player = Players.LocalPlayer
	local world = if player then player:GetAttribute("World") else 0
	if onMenu and not battleOpen then
		AreaFx.apply("menu") -- the menu's own scene (App/MenuScene)
		playMusic("music_menu")
	elseif battleOpen then
		local arena = battleArena and Arenas.ById[battleArena]
		AreaFx.apply(if arena and Presets[arena.lighting] then arena.lighting else "arena")
		playMusic(if arena and Sounds[arena.music] then arena.music else "music_battle")
	elseif world == 0 or world == nil then
		AreaFx.apply("hub")
		playMusic("music_hub")
	else
		AreaFx.apply(`world{world}`)
		local music = `music_world{world}`
		playMusic(if Sounds[music] then music else "music_hub")
	end
end

-- While a battle is open the arena's preset and music play; the area's come back after.
function AreaFx.setBattle(open: boolean, arena: string?)
	battleOpen = open
	battleArena = if open then arena else nil
	refresh()
end

-- The lobby's slow motion (FIX_LOBBY section 4.7, FIX_LOBBY_2 B3): the golden card statue and the
-- rune rings turn, the summoning circle and the light pillar pulse, the floating cards and rune
-- stones orbit, the golden egg bobs, koi swim the stream, banners sway, lanterns flicker and
-- shooting stars cross the sky. Client-only and purely visual; still under reduced motion. The
-- lobby streams out while the player is in a world, so its parts are collected again whenever
-- they change. Particles run at half rate on touch devices.
type Mover = { part: BasePart, home: CFrame, kind: string, i: number }
type Flicker = { light: PointLight, base: number }

local MOVING = { Spin = true, Sway = true, Pulse = true, Orbit = true, Koi = true, Bob = true }

local function collect(hub: Instance): ({ Mover }, { Model }, { Flicker })
	local movers: { Mover } = {}
	local rings: { Model } = {}
	local lights: { Flicker } = {}
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	for _, d in hub:GetDescendants() do
		local fx = d:GetAttribute("Fx")
		if d:IsA("Model") and fx == "Spin" then
			table.insert(rings, d)
		elseif d:IsA("BasePart") and type(fx) == "string" and MOVING[fx] then
			table.insert(movers, { part = d, home = d.CFrame, kind = fx, i = #movers + 1 })
			if fx == "Pulse" and d:GetAttribute("BaseTransparency") == nil then
				d:SetAttribute("BaseTransparency", d.Transparency)
			end
		elseif d:IsA("PointLight") and d.Color.R > d.Color.B then -- warm lantern and fire light
			table.insert(lights, { light = d, base = d.Brightness })
		elseif d:IsA("ImageLabel") and d.Name == "Swirl" and d:GetAttribute("Spinning") == nil then
			d:SetAttribute("Spinning", true) -- the portal's swirl
			TweenService:Create(
				d,
				TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			):Play()
		elseif d:IsA("ParticleEmitter") and touch and d:GetAttribute("BaseRate") == nil then
			d:SetAttribute("BaseRate", d.Rate)
			d.Rate = d.Rate / 2
		end
	end
	return movers, rings, lights
end

local function num(p: Instance, key: string, default: number): number
	local value = p:GetAttribute(key)
	return if type(value) == "number" then value else default
end

local function move(m: Mover, t: number, origin: Vector3)
	local p, home = m.part, m.home
	if m.kind == "Spin" then
		p.CFrame = CFrame.new(home.Position) * CFrame.Angles(0, t * 0.6, 0)
	elseif m.kind == "Sway" then
		p.CFrame = home * CFrame.Angles(0, 0, math.sin(t * 1.3 + m.i) * math.rad(4))
	elseif m.kind == "Pulse" then
		local base = num(p, "BaseTransparency", 0.7)
		p.Transparency = base + (1 - base) * 0.45 * (0.5 + 0.5 * math.sin(t * 1.8 + m.i))
	elseif m.kind == "Bob" then
		p.CFrame = home * CFrame.new(0, math.sin(t * 1.1) * 0.8, 0) * CFrame.Angles(0, t * 0.4, 0)
	elseif m.kind == "Orbit" then
		local c = origin + Vector3.new(num(p, "cx", 0), num(p, "cy", 0), num(p, "cz", 0))
		local a = t * num(p, "speed", 0.2)
		local rel = home.Position - c
		if p:GetAttribute("axis") == "X" then
			p.CFrame = CFrame.new(c) * CFrame.Angles(a, 0, 0) * CFrame.new(rel) * CFrame.Angles(0, a * 3, 0)
		else
			local lift = Vector3.new(0, math.sin(t + m.i) * num(p, "bob", 0), 0)
			p.CFrame = CFrame.new(c)
				* CFrame.Angles(0, a, 0)
				* CFrame.new(rel + lift)
				* home.Rotation
				* CFrame.Angles(0, t * 0.8, 0)
		end
	elseif m.kind == "Koi" then
		local z0, z1 = num(p, "z0", 0), num(p, "z1", 1)
		local span = z1 - z0
		local u = ((home.Position.Z - origin.Z - z0) / span + t * 0.05 * (1 + m.i % 3 * 0.3)) % 1
		local wiggle = math.sin(t * 1.7 + m.i)
		p.CFrame = CFrame.new(home.Position.X + wiggle * 0.5, home.Position.Y, origin.Z + z0 + u * span)
			* CFrame.Angles(0, wiggle * 0.5, 0)
	end
end

-- A shooting star: a short neon streak across the sky, client-local.
local function shootingStar(origin: Vector3)
	local from = origin + Vector3.new(math.random(-260, 260), math.random(220, 320), math.random(-420, -200))
	local dir = Vector3.new(if math.random() < 0.5 then -1 else 1, -0.35, math.random() * 0.4).Unit
	local star = Instance.new("Part")
	star.Name = "ShootingStar"
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromHex("#FFF6D8")
	star.Size = Vector3.new(0.8, 0.8, 26)
	star.CFrame = CFrame.lookAt(from, from + dir)
	star.Transparency = 0.1
	star.Parent = workspace
	local tween = TweenService:Create(
		star,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.lookAt(from + dir * 260, from + dir * 261), Transparency = 1 }
	)
	tween.Completed:Connect(function()
		star:Destroy()
	end)
	tween:Play()
end

-- The lobby's ambient sound zones (Config/LobbyDecor.Ambient): looped sounds at their spots, heard
-- only nearby (fountain water, waterfalls, chimes by the shrine, wind at the edges). Client-local,
-- at the player's SFX volume.
local ambience: { { sound: Sound, volume: number } } = {}
local function ambientSounds(origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "LobbyAmbience"
	for _, zone in HubLayout.Ambient do
		local def = Sounds[zone.sound]
		if def and def.id then
			local spot = Instance.new("Part")
			spot.Name = zone.sound
			spot.Anchored = true
			spot.CanCollide = false
			spot.CanQuery = false
			spot.CanTouch = false
			spot.Transparency = 1
			spot.Size = Vector3.one
			spot.Position = origin + Vector3.new(zone.at[1], zone.at[2], zone.at[3])
			spot.Parent = folder
			local snd = Instance.new("Sound")
			snd.SoundId = def.id :: string
			snd.Looped = true
			snd.Volume = def.volume * sfxVolume
			snd.RollOffMode = Enum.RollOffMode.InverseTapered
			snd.RollOffMinDistance = zone.range * 0.2
			snd.RollOffMaxDistance = zone.range
			snd.Parent = spot
			snd:Play()
			table.insert(ambience, { sound = snd, volume = def.volume })
		end
	end
	folder.Parent = workspace
end

function AreaFx.setSfxVolume(v: number)
	sfxVolume = math.clamp(v, 0, 1)
	for _, a in ambience do
		a.sound.Volume = a.volume * sfxVolume
	end
end

function lobbyMotion(first: Instance)
	local o = HubLayout.ORIGIN
	local origin = Vector3.new(o[1], o[2], o[3])
	ambientSounds(origin)
	local hub: Instance = first
	local dirty = true
	local conns: { RBXScriptConnection } = {}
	local function watch(h: Instance)
		for _, c in conns do
			c:Disconnect()
		end
		conns = {
			h.DescendantAdded:Connect(function()
				dirty = true
			end),
			h.DescendantRemoving:Connect(function()
				dirty = true
			end),
		}
	end
	watch(first)
	local movers: { Mover } = {}
	local rings: { Model } = {}
	local lights: { Flicker } = {}
	local lastScan = 0
	local nextStar = os.clock() + 6
	local t0 = os.clock()
	local last = t0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - last
		if dt < 1 / 30 then
			return
		end
		last = now
		if hub.Parent == nil then
			local found = workspace:FindFirstChild("Hub")
			if found == nil then
				return
			end
			hub = found
			watch(found)
			dirty = true
		end
		if dirty and now - lastScan > 0.5 then
			dirty = false
			lastScan = now
			movers, rings, lights = collect(hub)
		end
		if reducedOf() then
			return
		end
		local t = now - t0
		for _, m in movers do
			if m.part.Parent then
				move(m, t, origin)
			end
		end
		for i, ring in rings do
			if ring.Parent then
				ring:PivotTo(ring:GetPivot() * CFrame.Angles(0, dt * (if i % 2 == 0 then -0.12 else 0.16), 0))
			end
		end
		for i, l in lights do
			l.light.Brightness = l.base * (0.88 + 0.12 * math.noise(t * 3, i))
		end
		local player = Players.LocalPlayer
		local inLobby = player == nil or (player:GetAttribute("World") or 0) == 0
		if inLobby and not onMenu and not battleOpen and now >= nextStar then
			nextStar = now + 8 + math.random() * 7
			shootingStar(origin)
		end
	end)
end

-- Follows the player's World attribute and the battle screen (ctx.state "battle").
function AreaFx.start(ctx: any)
	reducedOf = ctx.reducedMotion
	current = nil
	AreaFx.apply("hub", true)
	local player = Players.LocalPlayer
	if player then
		player:GetAttributeChangedSignal("World"):Connect(refresh)
	end
	ctx.state.changed:connect(function(what: string)
		if what == "ui" then
			local menu = ctx.flow ~= nil and (ctx.flow.base == "MainMenu" or ctx.flow.base == "Loading")
			if menu ~= onMenu then
				onMenu = menu
				refresh()
			end
		elseif what == "battle" then
			local battle = ctx.state.battle
			AreaFx.setBattle(battle ~= nil, battle and battle.arena)
		elseif what == "profile" then
			-- The player's audio settings (saved on the server, Settings.Set).
			local settings = ctx.state.view and ctx.state.view.settings
			if settings then
				if (settings.music ~= false) ~= musicOn then
					AreaFx.setMusic(settings.music ~= false)
				end
				local sfx = if settings.sfx == false then 0 else (settings.sfxVolume or 100) / 100
				Ui.setSfxVolume(sfx)
				AreaFx.setSfxVolume(sfx)
				AreaFx.setMusicVolume((settings.musicVolume or 80) / 100)
			end
		end
	end)
	refresh()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if hub then
			lobbyMotion(hub)
		end
	end)
	-- The Back to Lobby portals stream in with their worlds (StreamingEnabled).
	task.spawn(function()
		local worlds = workspace:WaitForChild("Worlds", 60)
		if worlds == nil then
			return
		end
		local function spin(inst: Instance)
			if inst:IsA("ImageLabel") and inst.Name == "Swirl" then
				TweenService:Create(
					inst,
					TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
					{ Rotation = 360 }
				):Play()
			end
		end
		for _, d in worlds:GetDescendants() do
			spin(d)
		end
		worlds.DescendantAdded:Connect(spin)
	end)
end

return AreaFx
