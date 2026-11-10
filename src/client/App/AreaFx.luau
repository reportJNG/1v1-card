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
local SoundService = game:GetService("SoundService")

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

-- Spins the portal swirl images (SurfaceGuis built by Server/World/HubBuilder).
local function spinPortal(hub: Instance)
	local core = hub:WaitForChild("PortalCore", 30)
	if core == nil then
		return
	end
	for _, gui in core:GetChildren() do
		local img = gui:FindFirstChild("Swirl")
		if img and img:IsA("ImageLabel") then
			TweenService:Create(
				img,
				TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = if gui.Name == "Swirl" then 360 else -360 }
			):Play()
		end
	end
end

-- The lobby's slow motion (FIX_LOBBY section 4.7): the golden card statue turns, the banners sway
-- and the lanterns flicker. Client-only and purely visual; still under reduced motion.
function lobbyMotion(hub: Instance)
	local architecture = hub:WaitForChild("Architecture", 30)
	if architecture == nil then
		return
	end
	local spinners: { BasePart } = {}
	local swayers: { { part: BasePart, home: CFrame } } = {}
	for _, d in architecture:GetChildren() do
		if d:IsA("BasePart") then
			local fx = d:GetAttribute("Fx")
			if fx == "Spin" then
				table.insert(spinners, d)
			elseif fx == "Sway" then
				table.insert(swayers, { part = d, home = d.CFrame })
			end
		end
	end
	local lights: { { light: PointLight, base: number } } = {}
	local models = hub:FindFirstChild("Models")
	local function addLights(root: Instance)
		for _, d in root:GetDescendants() do
			if d:IsA("PointLight") and d.Color.R > d.Color.B then -- warm lantern and fire light
				table.insert(lights, { light = d, base = d.Brightness })
			end
		end
	end
	if models then
		task.delay(8, function() -- the meshes stream in on the server
			addLights(models)
		end)
	end
	local t0 = os.clock()
	task.spawn(function()
		while hub.Parent do
			local t = os.clock() - t0
			if not reducedOf() then
				for _, p in spinners do
					p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, t * 0.6, 0)
				end
				for i, s in swayers do
					s.part.CFrame = s.home * CFrame.Angles(0, 0, math.sin(t * 1.3 + i) * math.rad(4))
				end
				for i, l in lights do
					l.light.Brightness = l.base * (0.88 + 0.12 * math.noise(t * 3, i))
				end
			end
			task.wait(1 / 20)
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
				Ui.setSfxVolume(if settings.sfx == false then 0 else (settings.sfxVolume or 100) / 100)
				AreaFx.setMusicVolume((settings.musicVolume or 80) / 100)
			end
		end
	end)
	refresh()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if hub then
			spinPortal(hub)
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
