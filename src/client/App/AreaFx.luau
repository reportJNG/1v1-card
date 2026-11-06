--!strict
-- Client-side area presentation: applies the Config/Lighting preset for where the player is
-- (World attribute 0 = hub, 1-10 = a farming world, or "arena" while a battle screen is open)
-- and animates the hub's Worlds portal swirl. Purely visual; nothing here affects game state.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Presets = require(Shared.Config.Lighting)

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

-- Applies a preset by name ("hub", "arena", "world"). `instant` skips the tween (edit-mode
-- previews and the first apply).
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

local function refresh()
	local player = Players.LocalPlayer
	local world = if player then player:GetAttribute("World") else 0
	if battleOpen then
		AreaFx.apply("arena")
	elseif world == 0 or world == nil then
		AreaFx.apply("hub")
	else
		AreaFx.apply("world")
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
		if what == "battle" then
			AreaFx.setBattle(ctx.state.battle ~= nil)
		end
	end)
	refresh()
	task.spawn(function()
		local hub = workspace:WaitForChild("Hub", 60)
		if hub then
			spinPortal(hub)
		end
	end)
end

return AreaFx
