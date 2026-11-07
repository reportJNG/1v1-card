--!strict
-- Client-side area presentation: applies the Config/Lighting preset and the music for where the
-- player is (World attribute 0 = hub, n = world n with preset "world<n>" and music
-- "music_world<n>", or "arena" while a battle screen is open) and animates the portal swirls in
-- the hub and in every world. Purely visual; nothing here affects game state.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presets = require(Shared.Config.Lighting)
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
		s.MoonAngularSize = 0
		s.SunAngularSize = 0
		s.CelestialBodiesShown = false
	elseif sky then
		sky:Destroy()
	end
end

local battleOpen = false
local musicOn = true
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
	local snd = Instance.new("Sound")
	snd.Name = `Music_{name}`
	snd.SoundId = def.id
	snd.Looped = def.looped == true
	snd.Volume = 0
	snd.Parent = SoundService
	snd:Play()
	TweenService:Create(snd, FADE, { Volume = def.volume }):Play()
	track = snd
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

local function refresh()
	local player = Players.LocalPlayer
	local world = if player then player:GetAttribute("World") else 0
	if onMenu and not battleOpen then
		AreaFx.apply("hub")
		playMusic("music_menu")
	elseif battleOpen then
		AreaFx.apply("arena")
		playMusic("music_battle")
	elseif world == 0 or world == nil then
		AreaFx.apply("hub")
		playMusic("music_hub")
	else
		AreaFx.apply(`world{world}`)
		local music = `music_world{world}`
		playMusic(if Sounds[music] then music else "music_hub")
	end
end

function AreaFx.setBattle(open: boolean)
	battleOpen = open
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

-- Follows the player's World attribute and the battle screen (ctx.state "battle").
function AreaFx.start(ctx: any)
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
			AreaFx.setBattle(ctx.state.battle ~= nil)
		elseif what == "profile" then
			-- The player's audio settings (saved on the server, Settings.Set).
			local settings = ctx.state.view and ctx.state.view.settings
			if settings then
				if (settings.music ~= false) ~= musicOn then
					AreaFx.setMusic(settings.music ~= false)
				end
				Ui.setSfxVolume(if settings.sfx == false then 0 else 1)
			end
		end
	end)
	refresh()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if hub then
			spinPortal(hub)
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
