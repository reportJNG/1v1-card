--!strict
-- Screen 1, launch loading (MISSION 2.2). Runs once from ReplicatedFirst when the game starts; no
-- button or path ever returns to it.
--   * replaces Roblox's default loading screen at once
--   * the 1v1 CARD logo, a fan of card backs that shuffle and flip one by one to the N -> UR
--     rarity frames, a progress bar with a percentage, and a rotating tip
--   * really preloads (ContentProvider:PreloadAsync): every kit and UI image, the egg icons, the
--     main-menu music and core sounds; the bar is the real preload progress plus the wait for the
--     server profile (the App sets the local "UiReady" attribute when the profile has arrived)
--   * at least 1.5 s on screen (no flash); after 20 s it continues anyway and logs it
--   * at the end the cards fly apart and the screen fades into the main menu
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local MIN_SECONDS = 1.5
local TIMEOUT = 20
local started = os.clock()
local player = Players.LocalPlayer

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className) :: any
	local parent = props.Parent
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	inst.Parent = parent
	return inst
end

local gui = new("ScreenGui", {
	Name = "LaunchLoading",
	IgnoreGuiInset = true,
	DisplayOrder = 1000,
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
local root = new("Frame", {
	Name = "Root",
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1),
	Parent = gui,
})
new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromHex("#1A1240"), Color3.fromHex("#06061B")),
	Parent = root,
})
-- Everything sits in a 960 x 540 design box scaled to the screen.
local box = new("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(960, 540),
	Parent = root,
})
local scale = new("UIScale", { Parent = box })
local function fit()
	local s = gui.AbsoluteSize
	scale.Scale = math.min(s.X / 960, s.Y / 540)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local tipLabel = new("TextLabel", {
	BackgroundTransparency = 1,
	Text = "",
	FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	TextSize = 18,
	TextColor3 = Color3.fromHex("#C8C0FF"),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -28),
	Size = UDim2.fromOffset(700, 24),
	Parent = box,
})
local barBack = new("Frame", {
	BackgroundColor3 = Color3.fromHex("#140E30"),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -66),
	Size = UDim2.fromOffset(460, 18),
	Parent = box,
})
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = barBack })
new("UIStroke", { Color = Color3.fromHex("#B98CFF"), Thickness = 2, Transparency = 0.2, Parent = barBack })
local barFill = new("Frame", {
	BackgroundColor3 = Color3.new(1, 1, 1),
	Size = UDim2.fromScale(0, 1),
	Parent = barBack,
})
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = barFill })
new("UIGradient", {
	Color = ColorSequence.new(Color3.fromHex("#B46CFF"), Color3.fromHex("#FF4FB8")),
	Parent = barFill,
})
local pct = new("TextLabel", {
	BackgroundTransparency = 1,
	Text = "0%",
	FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy),
	TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1),
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -88),
	Size = UDim2.fromOffset(200, 22),
	Parent = box,
})
new("UIStroke", { Color = Color3.fromHex("#05070F"), Thickness = 1.5, Parent = pct })

local progress = 0
local function setProgress(p: number)
	progress = math.max(progress, math.clamp(p, 0, 1))
	TweenService:Create(barFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(progress, 1) }):Play()
	pct.Text = `{math.floor(progress * 100 + 0.5)}%`
end

-- The shared config (kit ids, UI images, eggs, sounds, tips) replicates a moment after we start.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local CardKit = require(Config:WaitForChild("CardKit")) :: any
local UiAssets = require(Config:WaitForChild("UiAssets")) :: any
local Eggs = require(Config:WaitForChild("Eggs")) :: any
local Sounds = require(Config:WaitForChild("Sounds")) :: any
local Tips = require(Config:WaitForChild("LoadingTips")) :: any

local function kit(slot: string): string
	local s = CardKit.Slots[slot]
	return if s then s.id else ""
end

new("ImageLabel", {
	Name = "Logo",
	BackgroundTransparency = 1,
	Image = kit("logo_1v1card"),
	ScaleType = Enum.ScaleType.Fit,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(420, 210),
	Parent = box,
})

-- The card fan: five backs that shuffle, then flip one by one to N, R, SR, SSR, UR.
local TAGS = { "n", "r", "sr", "ssr", "ur" }
local cards: { any } = {}
local CARD = Vector2.new(104, 143)
for i, tag in TAGS do
	local angle = (i - 3) * 9
	local holder = new("Frame", {
		Name = `Card{i}`,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, (i - 3) * 78, 0, 400 + math.abs(i - 3) * 8),
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		Rotation = angle,
		ZIndex = i,
		Parent = box,
	})
	local face = new("ImageLabel", {
		BackgroundTransparency = 1,
		Image = kit(`card_back_{tag}`),
		ScaleType = Enum.ScaleType.Stretch,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.16, 1.14), -- the kit canvas carries a bleed around the card
		ZIndex = i,
		Parent = holder,
	})
	cards[i] = { holder = holder, face = face, tag = tag, angle = angle }
end

local function flip(c: any, toFront: boolean)
	local half = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local t = TweenService:Create(c.holder, half, { Size = UDim2.fromOffset(2, CARD.Y) })
	t:Play()
	t.Completed:Wait()
	c.face.Image = if toFront then kit(`frame_{c.tag}_medium`) else kit(`card_back_{c.tag}`)
	if toFront and c.panel == nil then
		c.panel = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = kit(`panel_{c.tag}_medium`),
			ScaleType = Enum.ScaleType.Stretch,
			Size = UDim2.fromScale(1, 1),
			ZIndex = c.face.ZIndex - 1,
			Parent = c.face,
		})
		c.emblem = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = kit(
				if c.tag == "n"
					then "emblem_star_silver"
					elseif c.tag == "r" then "emblem_star_blue"
					else "emblem_crown_gold"
			),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.5, 0.36),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = c.face.ZIndex + 1,
			Parent = c.face,
		})
		c.badge = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = kit(`badge_{c.tag}_small`),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.06),
			Size = UDim2.fromScale(0.62, 0.22),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = c.face.ZIndex + 2,
			Parent = c.face,
		})
	end
	if c.panel then
		c.panel.Visible = toFront
		c.emblem.Visible = toFront
		c.badge.Visible = toFront
	end
	TweenService:Create(c.holder, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
	}):Play()
	task.wait(0.18)
end

local running = true
task.spawn(function()
	while running do
		-- shuffle: the fan closes to the centre and opens again
		for _, c in cards do
			TweenService
				:Create(c.holder, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					Position = UDim2.new(0.5, 0, 0, 400),
					Rotation = 0,
				})
				:Play()
		end
		task.wait(0.4)
		for i, c in cards do
			TweenService
				:Create(c.holder, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.new(0.5, (i - 3) * 78, 0, 400 + math.abs(i - 3) * 8),
					Rotation = c.angle,
				})
				:Play()
		end
		task.wait(0.45)
		for _, c in cards do
			if not running then
				break
			end
			flip(c, true)
			task.wait(0.08)
		end
		task.wait(0.9)
		for _, c in cards do
			if not running then
				break
			end
			flip(c, false)
		end
	end
end)

task.spawn(function()
	local i = math.random(1, #Tips)
	while running do
		tipLabel.Text = Tips[i]
		i = i % #Tips + 1
		task.wait(2.6)
	end
end)

-- What to preload: every kit and UI image, the egg icons, the menu music and core sounds.
local function collect(): { string }
	local seen: { [string]: boolean } = {}
	local list: { string } = {}
	local function add(id: any)
		if typeof(id) == "string" and id ~= "" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, s in CardKit.Slots do
		add(s.id)
	end
	for _, s in UiAssets do
		add(if s.final and s.final ~= "" then s.final else s.temp)
	end
	for _, egg in Eggs.List do
		add(egg.icon.normalAssetId)
		add(egg.icon.goldenAssetId)
	end
	for _, name in { "music_menu", "click", "hover", "open", "close", "card_flip" } do
		local s = Sounds[name]
		add(s and s.id)
	end
	return list
end

local assets = collect()
local loaded = 0
local function profileReady(): boolean
	return player:GetAttribute("UiReady") == true
end
local function update()
	local share = if #assets > 0 then loaded / #assets else 1
	setProgress(share * 0.85 + (if profileReady() then 0.15 else 0))
end
task.spawn(function()
	local CHUNK = 12
	for i = 1, #assets, CHUNK do
		local batch = {}
		for j = i, math.min(i + CHUNK - 1, #assets) do
			local id = assets[j]
			table.insert(batch, id)
		end
		pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)
		loaded += #batch
		update()
	end
end)
player:GetAttributeChangedSignal("UiReady"):Connect(update)

while os.clock() - started < TIMEOUT do
	if loaded >= #assets and profileReady() and os.clock() - started >= MIN_SECONDS then
		break
	end
	task.wait(0.1)
end
if os.clock() - started >= TIMEOUT then
	warn(`[Loading] continuing after {TIMEOUT} s: {loaded}/{#assets} assets, profile ready: {profileReady()}`)
end
setProgress(1)
task.wait(0.25)
running = false

-- The cards fly apart and everything fades into the main menu.
for i, c in cards do
	local dir = (i - 3)
	TweenService:Create(c.holder, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, dir * 260, 0, if dir == 0 then -200 else 420 - math.abs(dir) * 120),
		Rotation = c.angle * 4,
	}):Play()
end
local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
task.wait(0.25)
TweenService:Create(root, fade, { BackgroundTransparency = 1 }):Play()
for _, d in gui:GetDescendants() do
	if d:IsA("ImageLabel") then
		TweenService:Create(d, fade, { ImageTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") and d ~= root then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.5)
gui:Destroy()
player:SetAttribute("LaunchDone", true)
