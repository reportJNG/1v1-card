--!strict
-- The main menu (BAD_GUI_4_MAIN_MENU.md, target docs/brief/bad-gui/09-main-menu-target.png, layout
-- only: its character is a copyrighted likeness). Only these are on screen:
--   background    the owner's painted night plaza (D1, four 1024 px tiles in a 2 x 2 cover-fit
--                 container, drifting ±1%) once it is LIVE; until then the real night lobby itself,
--                 seen by the menu camera (App/UiEffects), which is the composition D1 paints
--   logo          top-left (D2 once LIVE; until then a crown over "1V1" in a pink-gold gradient and
--                 "CARD" in white)
--   PLAY, SHOP    under the logo; PLAY always goes to the lobby, SHOP opens the Egg Shop over the menu
--   currencies    Coins and Gems pills, top-right
--   hero          the player's own avatar (a ViewportFrame with a WorldModel), centre-right on the
--                 plaza, fanning their three deck cards, with a slow idle; a silhouette until it loads
-- Life: falling petals (12, recycled), the logo bobs, PLAY breathes and a shine crosses both buttons.
-- Everything respects reduced motion. No tagline, version line, extra tiles or card showcase.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.Kit)
local Card = require(script.Parent.Card)
local Format = require(script.Parent.Format)

local C = Theme.Color

local MainMenu = {}

export type Menu = {
	frame: Frame,
	setLoading: (loading: boolean) -> (),
	show: (on: boolean) -> (),
}

export type Actions = {
	play: () -> (),
	open: (name: string, arg: any?) -> (),
	-- The real lobby is drawn behind the menu (App/UiEffects' menu camera): no opaque backdrop.
	live: boolean?,
	-- The profile view for the currency pills and the hero's cards, and a change signal.
	view: (() -> any)?,
	onChanged: ((fn: () -> ()) -> ())?,
}

local PETALS = 12
local BG_TILES = { "menu_bg_tl", "menu_bg_tr", "menu_bg_bl", "menu_bg_br" }

local function outline(label: TextLabel, thickness: number)
	Ui.outline(C.Night, thickness).Parent = label
end

-- The hero: the player's avatar standing on the plaza, right hand raised with the cards.
local function buildHero(parent: GuiObject, reduced: () -> boolean): (ViewportFrame, () -> ())
	local vp: ViewportFrame = Ui.new("ViewportFrame", {
		Name = "Hero",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.66, 0.86), -- feet on the plaza, head near the top (target 09)
		Size = UDim2.fromScale(0.34, 0.78),
		Ambient = Color3.fromHex("#5B3E9A"),
		LightColor = Color3.fromHex("#FFD6A8"), -- warm rim from the portal side
		LightDirection = Vector3.new(-0.6, -0.5, -0.6),
		ImageTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	})
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 23
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.4, 17.5), Vector3.new(0, 3.0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model: Model? = nil
	local loop: RBXScriptConnection? = nil
	-- The idle: every part is anchored (a WorldModel doesn't step joints), so the pose is set by
	-- hand each frame: a slow bob and turn, and the left arm raised forward toward the card fan,
	-- swaying a little.
	local ARM = { LeftUpperArm = true, LeftLowerArm = true, LeftHand = true }
	local function start()
		if loop or model == nil then
			return
		end
		local m = model :: Model
		local base = m:GetPivot()
		local torso = m:FindFirstChild("UpperTorso") :: BasePart?
		local att = torso and torso:FindFirstChild("LeftShoulderRigAttachment") :: Attachment?
		if torso == nil or att == nil then
			return
		end
		local shoulderRel = base:ToObjectSpace(torso.CFrame * (att :: Attachment).CFrame)
		local rest: { [BasePart]: CFrame } = {}
		local arm: { [BasePart]: boolean } = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				rest[d] = base:ToObjectSpace(d.CFrame)
				-- an accessory on the arm moves with it
				local owner = d
				local weld = d:FindFirstChildWhichIsA("Weld") or d:FindFirstChildWhichIsA("WeldConstraint")
				if weld and weld:IsA("Weld") and weld.Part1 == d and weld.Part0 then
					owner = weld.Part0
				end
				arm[d] = ARM[d.Name] == true or ARM[owner.Name] == true
			end
		end
		local t0 = os.clock()
		loop = RunService.RenderStepped:Connect(function()
			if not vp.Visible then
				return
			end
			local t = if reduced() then 0 else os.clock() - t0
			local now = base
				* CFrame.new(0, math.sin(t * 1.6) * 0.06, 0)
				* CFrame.Angles(0, math.sin(t * 0.5) * 0.05, 0)
			local raise = shoulderRel
				* CFrame.Angles(math.rad(65 + math.sin(t * 1.6) * 3), 0, math.rad(-18))
				* shoulderRel:Inverse()
			for part, cf in rest do
				part.CFrame = if arm[part] then now * raise * cf else now * cf
			end
		end)
	end
	task.spawn(function()
		local player = Players.LocalPlayer
		if player == nil then
			return
		end
		local ok, built = pcall(function()
			local desc = Players:GetHumanoidDescriptionFromUserId(player.UserId)
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if not ok or built == nil then
			return
		end
		local m = built :: Model
		local root = m:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = d == root
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		m.Parent = world
		task.wait() -- parenting re-applies the rig, which moves it: place it afterwards
		m:PivotTo(CFrame.Angles(0, math.rad(200), 0)) -- 3/4 toward the camera
		local box, size = m:GetBoundingBox()
		m:PivotTo(m:GetPivot() + Vector3.new(-box.Position.X, size.Y / 2 - box.Position.Y, -box.Position.Z))
		model = m
		start()
		TweenService:Create(vp, TweenInfo.new(if reduced() then 0.01 else 0.6), { ImageTransparency = 0 })
			:Play()
	end)
	return vp, function()
		if loop then
			loop:Disconnect()
			loop = nil
		end
	end
end

function MainMenu.build(parent: Instance, actions: Actions, reduced: () -> boolean): Menu
	local frame = Ui.frame({
		Name = "MainMenu",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	})
	local group = Ui.new("CanvasGroup", {
		Name = "Group",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		GroupTransparency = 0,
		Parent = frame,
	})

	-- Background: D1 tiles when LIVE; the real lobby when live; a night gradient in previews.
	local tiles: Frame? = nil
	local liveBg = true
	for _, name in BG_TILES do
		liveBg = liveBg and Kit.live(name)
	end
	if liveBg then
		local cover = Ui.frame({
			Name = "Background",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.02, 1.02),
			Parent = group,
		}, {
			Ui.new("UIAspectRatioConstraint", {
				AspectRatio = 16 / 9,
				AspectType = Enum.AspectType.ScaleWithParentSize,
				DominantAxis = Enum.DominantAxis.Width,
			}),
		})
		for i, name in BG_TILES do
			local p = Kit.piece(name)
			Ui.new("ImageLabel", {
				Name = name,
				Image = p.image,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Stretch,
				Position = UDim2.fromScale(if i % 2 == 0 then 0.5 else 0, if i > 2 then 0.5 else 0),
				Size = UDim2.fromScale(0.5005, 0.5005), -- a hair of overlap: no seams
				Parent = cover,
			})
		end
		tiles = cover
	elseif not actions.live then
		local backdrop = Ui.frame({
			Name = "Backdrop",
			BackgroundColor3 = C.White,
			Size = UDim2.fromScale(1, 1),
			Parent = group,
		})
		Ui.gradient(Color3.fromHex("#1A0B3D"), Color3.fromHex("#5A1E78"), 35).Parent = backdrop
	end
	-- The left third darker and calmer, for the logo and buttons (as D1 is painted).
	Ui.frame({
		Name = "Shade",
		BackgroundColor3 = C.Night,
		Size = UDim2.fromScale(0.55, 1),
		ZIndex = 2,
		Parent = group,
	}, {
		Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.75, 0.8),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	-- Petals drifting down (recycled).
	local petals: { { img: ImageLabel, x: number, speed: number, phase: number, spin: number } } = {}
	for i = 1, PETALS do
		local img = Ui.image("petal", {
			Name = `Petal{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(14 + (i % 3) * 5, 14 + (i % 3) * 5),
			ImageColor3 = Color3.fromHex("#FFB7E8"),
			ImageTransparency = 0.15,
			ZIndex = 6,
			Parent = group,
		})
		table.insert(petals, {
			img = img,
			x = (i * 0.137) % 1,
			speed = 0.05 + (i % 4) * 0.012,
			phase = (i * 0.29) % 1,
			spin = (if i % 2 == 0 then 1 else -1) * (40 + i * 5),
		})
	end

	-- The hero and the fan of their deck cards.
	-- (outside the CanvasGroup: viewports don't render inside one; they fade on their own)
	local hero, stopHero = buildHero(frame, reduced)
	local fan = Ui.frame({
		Name = "CardFan",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.735, 0.46),
		Size = UDim2.fromOffset(170, 130),
		ZIndex = 4,
		Parent = frame,
	})
	local fanKey = ""
	local function renderFan()
		local v = actions.view and actions.view()
		if v == nil then
			return
		end
		local ids = {}
		for i = 1, 3 do
			local c = v.deck[i] and v.cards[v.deck[i]]
			table.insert(ids, if c then `{c.characterId}:{c.level}:{c.golden}` else "-")
		end
		local key = table.concat(ids, "|")
		if key == fanKey then
			return
		end
		fanKey = key
		Ui.clear(fan)
		for i = 1, 3 do
			local c = v.deck[i] and v.cards[v.deck[i]]
			if c then
				local holder = Ui.frame({
					Name = `Card{i}`,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, (i - 2) * 34, 1, if i == 2 then -6 else 0),
					Size = UDim2.fromOffset(70, 98),
					Rotation = (i - 2) * 14,
					ZIndex = if i == 2 then 6 else 5,
					Parent = fan,
				})
				Card.build(holder, {
					characterId = c.characterId,
					golden = c.golden,
					level = c.level,
					size = Vector2.new(70, 98),
					stats = false,
					bare = true,
				})
			end
		end
	end

	-- Logo (top-left): D2 once LIVE, else the TEMP text logo.
	local logo = Ui.frame({
		Name = "Logo",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 56, 0.06, 0),
		Size = UDim2.fromOffset(380, 200),
		ZIndex = 5,
		Parent = group,
	})
	if Kit.live("menu_logo") then
		local p = Kit.piece("menu_logo")
		Ui.new("ImageLabel", {
			Image = p.image,
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = logo,
		})
	else
		Kit.image("emblem_crown_gold", {
			Name = "Crown",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(110, -8),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 6,
			Parent = logo,
		})
		local one = Ui.display({
			Name = "One",
			Text = "1V1",
			TextSize = 104,
			Rotation = -4,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 0, 104),
			ZIndex = 6,
			Parent = logo,
		})
		one.TextColor3 = C.White
		Ui.gradient(Color3.fromHex("#FF6FB5"), Color3.fromHex("#FFD24A")).Parent = one
		outline(one, 5)
		local card = Ui.display({
			Name = "Card",
			Text = "CARD",
			TextSize = 70,
			Rotation = -4,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(24, 140),
			Size = UDim2.new(1, 0, 0, 72),
			ZIndex = 6,
			Parent = logo,
		})
		card.TextColor3 = C.White
		outline(card, 5)
	end

	-- PLAY and SHOP (left, under the logo).
	local buttons = Ui.frame({
		Name = "Buttons",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 56, 0.06, 236),
		Size = UDim2.fromOffset(340, 170),
		ZIndex = 5,
		Parent = group,
	}, { Ui.list(false, 16) })
	local function bigButton(text: string, style: string, icon: string, order: number, onClick: () -> ()): any
		local b = Ui.button(text, style, onClick, {
			Name = if text == "PLAY" then "Play" else "Shop",
			Size = UDim2.fromOffset(340, if text == "PLAY" then 78 else 64),
			LayoutOrder = order,
			ZIndex = 5,
		})
		b.label.FontFace = Theme.Face.Display
		b.label.TextColor3 = if style == "primary" then C.GoldInk else C.White
		local cap = b.label:FindFirstChildOfClass("UITextSizeConstraint")
		if cap then
			cap.MaxTextSize = if text == "PLAY" then 46 else 34 -- the one big call to action
		end
		if style ~= "primary" then
			outline(b.label, 3)
		end
		-- icons on both sides (crossed swords on PLAY, the cart on SHOP)
		for side = 0, if text == "PLAY" then 1 else 0 do
			Ui.icon(icon, if text == "PLAY" then 52 else 44, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(side, if side == 0 then 34 else -34, 0.5, 0),
				Rotation = if side == 0 then -10 else 10,
				ZIndex = 6,
				Parent = b.instance,
			})
		end
		b.instance.Parent = buttons
		return b
	end
	local play = bigButton("PLAY", "primary", "icon_play", 1, actions.play)
	bigButton("SHOP", "purple", "icon_shop", 2, function()
		actions.open("Shop")
	end)

	-- Currency pills (top-right).
	local pills = Ui.frame({
		Name = "Currencies",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(440, 52),
		ZIndex = 5,
		Parent = group,
	}, { Ui.list(true, 18, Enum.HorizontalAlignment.Right) })
	local function pill(
		name: string,
		kind: string,
		icon: string,
		width: number,
		order: number,
		tip: string
	): TextLabel
		local f = Ui.frame({
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(width, 48),
			LayoutOrder = order,
			ZIndex = 5,
			Parent = pills,
		})
		Kit.image(`currency_bar_{kind}`, {
			Name = "Skin",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(48, 47, 336, 49),
			SliceScale = 0.5,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = f,
		})
		local coin = Ui.icon(icon, 62, { AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = f })
		coin.Position = UDim2.new(0, 4, 0.5, 0)
		local value = Ui.text({
			Name = "Value",
			Text = "0",
			FontFace = Theme.Face.Display,
			TextSize = 30,
			TextWrapped = false,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -78, 1, 0),
			ZIndex = 6,
			Parent = f,
		})
		value.TextColor3 = C.White
		outline(value, 3)
		local plus: ImageButton = Ui.new("ImageButton", {
			Name = "Plus",
			Image = Kit.id(`plus_{kind}`),
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -2, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			ZIndex = 7,
			Parent = f,
		})
		Ui.juice(plus)
		plus.Activated:Connect(function()
			Ui.sound("click")
			actions.open("Tip", { kind = tip }) -- Coins are earned, never sold; Gems are explained
		end)
		return value
	end
	local coins = pill("Coins", "gold", "icon_coin", 230, 1, "coins")
	local gems = pill("Gems", "blue", "icon_gem", 170, 2, "gems")
	local function refresh()
		local v = actions.view and actions.view()
		pills.Visible = v ~= nil
		if v then
			coins.Text = Format.short(v.coins)
			gems.Text = Format.short(v.gems)
		end
		renderFan()
	end
	if actions.onChanged then
		actions.onChanged(refresh)
	end
	refresh()

	local loading = Ui.display({
		Name = "Loading",
		Text = "LOADING...",
		TextSize = 34,
		Visible = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0, 64, 0.06, 250),
		Size = UDim2.fromOffset(320, 40),
		ZIndex = 5,
		Parent = group,
	})
	loading.TextColor3 = C.White
	outline(loading, 3)

	-- Motion: petals fall, the logo bobs, the D1 tiles drift ±1%. One loop, only while shown.
	local loop: RBXScriptConnection? = nil
	local function setMotion(on: boolean)
		if loop then
			loop:Disconnect()
			loop = nil
		end
		for _, d in petals do
			d.img.Visible = on and not reduced()
			d.img.Position = UDim2.fromScale(d.x, d.phase)
		end
		if not on or reduced() then
			return
		end
		local t0 = os.clock()
		loop = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			logo.Position = UDim2.new(0, 56, 0.06, math.sin(t * 1.2) * 4)
			if tiles then
				tiles.Position =
					UDim2.fromScale(0.5 + math.sin(t * 0.08) * 0.01, 0.5 + math.cos(t * 0.06) * 0.006)
			end
			for _, d in petals do
				local y = ((d.phase + t * d.speed) % 1.15) - 0.07
				d.img.Position = UDim2.fromScale(d.x + math.sin(t * 0.7 + d.phase * 6) * 0.03, y)
				d.img.Rotation = t * d.spin
			end
		end)
	end

	-- PLAY breathes gently so the next step is obvious.
	local pulse: Tween? = nil
	local function setPulse(on: boolean)
		if pulse then
			pulse:Cancel()
			pulse = nil
		end
		local scale = play.instance:FindFirstChildOfClass("UIScale")
			or Ui.new("UIScale", { Parent = play.instance })
		scale.Scale = 1
		if on and not reduced() then
			local tween = TweenService:Create(
				scale,
				TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.05 }
			)
			tween:Play()
			pulse = tween
		end
	end

	local menu: Menu = {
		frame = frame,
		setLoading = function(isLoading: boolean)
			loading.Visible = isLoading
			buttons.Visible = not isLoading
			setPulse(not isLoading and frame.Visible)
		end,
		show = function(on: boolean)
			local info = TweenInfo.new(
				if reduced() then 0.01 else 0.35,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			)
			if on then
				frame.Visible = true
				hero.Visible = true
				fan.Visible = true
				group.GroupTransparency = 1
				TweenService:Create(group, info, { GroupTransparency = 0 }):Play()
				setPulse(buttons.Visible)
				setMotion(true)
				refresh()
			else
				setPulse(false)
				local fade = TweenService:Create(group, info, { GroupTransparency = 1 })
				fade.Completed:Connect(function()
					if group.GroupTransparency >= 0.99 then
						frame.Visible = false
						hero.Visible = false
						fan.Visible = false
						setMotion(false)
					end
				end)
				fade:Play()
			end
		end,
	}
	frame.Destroying:Connect(stopHero)
	return menu
end

return MainMenu
