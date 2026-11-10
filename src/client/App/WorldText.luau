--!strict
-- Every message the game shows during play (BAD_GUI_THINKING_AND_UI): no toast bars, no dark boxes
-- of small text. Big Luckiest Guy text with a thick stroke, an icon first, colour that means
-- something, and motion; shown at the thing it is about.
--   WorldText.pop(source, spec)    over an object in the world (a node, the merchant): pops in
--                                  0 -> 1.2 -> 1, rises ~3 studs and fades in 0.9 s
--   WorldText.near(gui, spec)      beside a screen element (an error next to the pressed button,
--                                  shaking; a "+1" by the quest row)
--   WorldText.center(spec)         a short centre pop for moments with no source ("QUEST
--                                  COMPLETE!", "LEVEL UP!", "WORLD 2 UNLOCKED!")
--   WorldText.fly(from, to, icon)  a few icons fly from the source to their HUD counter, which
--                                  bounces when they land
-- Pops are pooled (Shared/Ui/PopPool, at most 20 of each kind active) and respect reduced motion.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local PopPool = require(Shared.Ui.PopPool)
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local ItemIcon = require(script.Parent.ItemIcon)

local C = Theme.Color
local F = Theme.Face

local WorldText = {}

export type Tone = "gold" | "cyan" | "green" | "red" | "white" | "violet"
export type Spec = {
	text: string,
	icon: string?, -- Config/UiAssets slot
	itemId: string?, -- an item: its own icon (App/ItemIcon)
	tone: Tone?,
	size: number?, -- text px (popups 28+, headlines 36-60)
	duration: number?,
	shake: boolean?, -- errors
}

local CAP = 20
local TONES: { [string]: { Color3 } } = {
	gold = { Color3.fromHex("#FFE680"), Color3.fromHex("#FFA800") },
	cyan = { Color3.fromHex("#9FF1FF"), Color3.fromHex("#1E9BFF") },
	green = { Color3.fromHex("#B4FF8A"), Color3.fromHex("#19B954") },
	red = { Color3.fromHex("#FF9AAE"), Color3.fromHex("#FF2F55") },
	white = { Color3.new(1, 1, 1), Color3.fromHex("#C9D4F2") },
	violet = { Color3.fromHex("#F1E2FF"), Color3.fromHex("#A469FF") },
}

local layer: Frame? = nil -- the top screen layer (design space, scaled)
local scaleOf: () -> number = function()
	return 1
end
local reducedOf: () -> boolean = function()
	return false
end

-- One pop's instances: a holder with an icon slot and the text, plus its UIScale.
type Pop = { root: GuiObject, gui: BillboardGui?, icon: Frame, label: TextLabel, scale: UIScale }

-- Thick enough to read on grass, snow and lava alike.
local function strokeFor(size: number): number
	return math.clamp(size / 9, 3, 6)
end

local function outlineText(label: TextLabel, size: number)
	Ui.outline(C.Night, strokeFor(size)).Parent = label
end

local function makeContent(parent: Instance): Pop
	local root = Ui.frame({
		Name = "Pop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 72),
		Visible = false,
		Parent = parent,
	}, { Ui.list(true, 6, Enum.HorizontalAlignment.Center) })
	local list = root:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = Ui.frame({ Name = "IconSlot", BackgroundTransparency = 1, LayoutOrder = 1, Parent = root })
	local label = Ui.text({
		Name = "Text",
		FontFace = F.Display,
		TextSize = 34,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 60),
		LayoutOrder = 2,
		Parent = root,
	})
	label.TextColor3 = C.White
	Ui.new("UIGradient", { Rotation = 90, Parent = label })
	outlineText(label, 34)
	local scale = Ui.new("UIScale", { Parent = root })
	return { root = root, icon = icon, label = label, scale = scale }
end

local worldPool: any = nil
local screenPool: any = nil

local function setContent(p: Pop, spec: Spec)
	local size = spec.size or 34
	local tone = TONES[spec.tone or "white"] or TONES.white
	p.label.Text = spec.text
	p.label.TextSize = size
	p.label.Size = UDim2.fromOffset(0, math.floor(size * 1.5))
	p.label.TextTransparency = 0
	local grad = p.label:FindFirstChildOfClass("UIGradient") :: UIGradient
	grad.Color = ColorSequence.new(tone[1], tone[2])
	local stroke = p.label:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Thickness = strokeFor(size)
	stroke.Transparency = 0
	for _, c in p.icon:GetChildren() do
		c:Destroy()
	end
	local iconPx = math.floor(size * 1.35)
	if spec.itemId then
		p.icon.Size = UDim2.fromOffset(iconPx, iconPx)
		ItemIcon.new(spec.itemId, iconPx, { Parent = p.icon }, true)
	elseif spec.icon then
		p.icon.Size = UDim2.fromOffset(iconPx, iconPx)
		Ui.icon(spec.icon, iconPx, { Size = UDim2.fromScale(1, 1), Parent = p.icon })
	else
		p.icon.Size = UDim2.fromOffset(0, 0)
	end
	p.root.Size = UDim2.fromOffset(math.floor(size * 0.7 * #spec.text + iconPx + 16), math.floor(size * 1.6))
end

local function fadeAll(p: Pop, t: number)
	local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(p.label, info, { TextTransparency = 1 }):Play()
	local stroke = p.label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	end
	for _, d in p.icon:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ViewportFrame") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		end
	end
end

local function bounceIn(p: Pop, reduced: boolean)
	if reduced then
		p.scale.Scale = 1
		return
	end
	p.scale.Scale = 0
	local up = TweenService:Create(p.scale, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Scale = 1.2 })
	up.Completed:Connect(function()
		TweenService:Create(p.scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
	up:Play()
end

-- The layer's coordinates of an absolute screen point.
local function toLayer(abs: Vector2): Vector2
	local l = layer :: Frame
	return (abs - l.AbsolutePosition) / scaleOf()
end

local function worldToScreen(at: Vector3): Vector2?
	local cam = workspace.CurrentCamera
	if cam == nil then
		return nil
	end
	local p, onScreen = cam:WorldToViewportPoint(at)
	if not onScreen then
		return nil
	end
	local inset = GuiService:GetGuiInset()
	return Vector2.new(p.X, p.Y) - inset
end

local function positionOf(source: any): Vector3?
	if typeof(source) == "Vector3" then
		return source
	elseif typeof(source) == "Instance" then
		if source:IsA("BasePart") then
			return source.Position
		elseif source:IsA("Model") then
			return source:GetPivot().Position
		elseif source:IsA("Attachment") then
			return source.WorldPosition
		end
	end
	return nil
end

-- Hooks WorldText to the App: `top` is the topmost design-space layer, `scale()` its UIScale.
function WorldText.init(top: Frame, scale: () -> number, reduced: () -> boolean)
	layer = top
	scaleOf = scale
	reducedOf = reduced
	local player = Players.LocalPlayer
	local f = Instance.new("Folder")
	f.Name = "WorldTextPops"
	f.Parent = if player then player:FindFirstChildOfClass("PlayerGui") or top else top -- BillboardGuis don't render under a ScreenGui
	worldPool = PopPool.new(CAP, function(): Pop
		-- Each pop has its own anchor: an Attachment under Terrain (at the origin), moved to the
		-- source. Not AlwaysOnTop: those billboards are not drawn with this game's lighting
		-- (Shared/Ui/Billboard), so pops start a little above their object instead.
		local anchor = Instance.new("Attachment")
		anchor.Name = "WorldPopAnchor"
		anchor.Parent = workspace.Terrain
		local gui = Instance.new("BillboardGui")
		gui.Name = "WorldPop"
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(360, 96)
		gui.AlwaysOnTop = false
		gui.LightInfluence = 0
		gui.MaxDistance = 220
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = f
		local p = makeContent(gui)
		p.gui = gui
		return p
	end)
	screenPool = PopPool.new(CAP, function(): Pop
		return makeContent(top)
	end)
end

-- A pop over a world object (or point). Falls back to a centre pop if there is no source.
function WorldText.pop(source: any, spec: Spec)
	local at = positionOf(source)
	if worldPool == nil or at == nil then
		WorldText.center(spec)
		return
	end
	local p: Pop, recycled: Pop?, use: number = worldPool:acquire()
	local gui = p.gui :: BillboardGui
	if recycled then
		recycled.root.Visible = false
	end
	setContent(p, spec)
	local anchor = gui.Adornee :: Attachment
	anchor.Position = at + Vector3.new(0, 2.5, 0)
	gui.StudsOffset = Vector3.zero
	gui.Enabled = true
	p.root.Visible = true
	local reduced = reducedOf()
	bounceIn(p, reduced)
	local life = spec.duration or (if reduced then 0.6 else 0.9)
	TweenService:Create(
		gui,
		TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, if reduced then 1.5 else 3, 0) }
	):Play()
	task.delay(life * 0.45, function()
		if worldPool:current(p, use) then
			fadeAll(p, life * 0.55)
		end
	end)
	task.delay(life, function()
		if worldPool:current(p, use) then
			worldPool:release(p, use)
			gui.Enabled = false
			p.root.Visible = false
		end
	end)
end

local function screenPop(pos: Vector2, spec: Spec, rise: number)
	if screenPool == nil then
		return
	end
	local p: Pop, recycled: Pop?, use: number = screenPool:acquire()
	if recycled then
		recycled.root.Visible = false
	end
	setContent(p, spec)
	p.root.Position = UDim2.fromOffset(pos.X, pos.Y)
	p.root.ZIndex = 50
	p.root.Visible = true
	local reduced = reducedOf()
	bounceIn(p, reduced)
	local life = spec.duration or (if reduced then 0.8 else 1.2)
	if spec.shake and not reduced then
		task.spawn(function()
			for i = 1, 6 do
				if not screenPool:current(p, use) then
					return
				end
				p.root.Position = UDim2.fromOffset(pos.X + (if i % 2 == 0 then 6 else -6), pos.Y)
				task.wait(0.04)
			end
			p.root.Position = UDim2.fromOffset(pos.X, pos.Y)
		end)
	end
	task.delay(life * 0.35, function()
		if not screenPool:current(p, use) then
			return
		end
		TweenService:Create(
			p.root,
			TweenInfo.new(life * 0.65, Enum.EasingStyle.Quad),
			{ Position = UDim2.fromOffset(pos.X, pos.Y - rise) }
		):Play()
		fadeAll(p, life * 0.65)
	end)
	task.delay(life, function()
		if screenPool:current(p, use) then
			screenPool:release(p, use)
			p.root.Visible = false
		end
	end)
end

-- A pop beside a screen element (its right side, or above it when there's no room).
function WorldText.near(gui: GuiObject?, spec: Spec)
	if layer == nil then
		return
	end
	if gui == nil or not gui:IsDescendantOf(game) or gui.AbsoluteSize.X == 0 then
		WorldText.center(spec)
		return
	end
	local l = layer :: Frame
	local centre = toLayer(gui.AbsolutePosition + gui.AbsoluteSize / 2)
	local above = toLayer(gui.AbsolutePosition).Y - 30
	local pos = Vector2.new(centre.X, math.max(30, above))
	if pos.X < 120 then
		pos = Vector2.new(120, pos.Y)
	elseif pos.X > l.AbsoluteSize.X / scaleOf() - 120 then
		pos = Vector2.new(l.AbsoluteSize.X / scaleOf() - 120, pos.Y)
	end
	screenPop(pos, spec, 30)
end

-- A short centre pop (quest complete, level up, unlocks, errors with no source).
function WorldText.center(spec: Spec)
	if layer == nil then
		return
	end
	local l = layer :: Frame
	local size = l.AbsoluteSize / scaleOf()
	local s = table.clone(spec)
	s.size = s.size or 48
	screenPop(Vector2.new(size.X / 2, size.Y * 0.36), s, 40)
end

-- Icons fly from `from` (a world object or point, a screen element, or "center") to the HUD element `to`,
-- which bounces as they land. `onLand` runs when the last icon arrives.
function WorldText.fly(
	from: any,
	to: GuiObject?,
	spec: { icon: string?, itemId: string?, count: number? },
	onLand: (() -> ())?
)
	if layer == nil or to == nil or not to:IsDescendantOf(game) then
		if onLand then
			onLand()
		end
		return
	end
	local start: Vector2? = nil
	if from == "center" then -- from where WorldText.center pops
		local size = (layer :: Frame).AbsoluteSize / scaleOf()
		start = Vector2.new(size.X / 2, size.Y * 0.36)
	elseif typeof(from) == "Instance" and from:IsA("GuiObject") then
		start = toLayer(from.AbsolutePosition + from.AbsoluteSize / 2)
	else
		local at = positionOf(from)
		local screen = at and worldToScreen(at)
		start = screen and toLayer(screen)
	end
	local target = toLayer(to.AbsolutePosition + to.AbsoluteSize / 2)
	local function land()
		local s = to:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = to })
		s.Scale = 1.18
		TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if onLand then
			onLand()
		end
	end
	if start == nil or reducedOf() then
		land()
		return
	end
	local n = math.clamp(spec.count or 4, 1, 6)
	local landed = 0
	for i = 1, n do
		local icon: GuiObject
		if spec.itemId then
			icon = ItemIcon.new(spec.itemId, 34, nil, true)
		else
			icon = Ui.icon(spec.icon or "icon_coin", 34)
		end
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ZIndex = 60
		local jitter = Vector2.new(math.random(-28, 28), math.random(-20, 20))
		icon.Position = UDim2.fromOffset((start :: Vector2).X + jitter.X, (start :: Vector2).Y + jitter.Y)
		icon.Parent = layer
		task.delay((i - 1) * 0.06, function()
			local t = TweenService:Create(
				icon,
				TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(22, 22) }
			)
			t.Completed:Connect(function()
				icon:Destroy()
				landed += 1
				if landed == n then
					land()
				end
			end)
			t:Play()
		end)
	end
end

-- For tests and the Studio preview: how many pops are showing now.
function WorldText.active(): (number, number)
	return if worldPool then worldPool:activeCount() else 0,
		if screenPool then screenPool:activeCount() else 0
end

return WorldText
