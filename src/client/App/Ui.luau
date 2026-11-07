--!strict
-- UI construction kit. Every screen builds its GUI through these helpers, so the art (9-slice
-- images from Config/UiAssets), type, motion and sound stay consistent with docs/ART_STYLE.md.
-- Images come from UiAssets: the owner's final art when uploaded, otherwise the TEMP stand-in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UiAssets = require(Shared.Config.UiAssets)
local Sounds = require(Shared.Config.Sounds)
local Theme = require(script.Parent.Theme)

local C = Theme.Color
local S = Theme.Size
local F = Theme.Face
local M = Theme.Motion

local Ui = {}

-- Creates an instance, applies props (Parent last) and parents the children.
function Ui.new(className: string, props: { [string]: any }?, children: { any }?): any
	local inst = Instance.new(className) :: any
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function merge(defaults: { [string]: any }, props: { [string]: any }?): { [string]: any }
	if props then
		for k, v in props do
			defaults[k] = v
		end
	end
	return defaults
end

-- ------------------------------------------------------------------ images

-- The image for a slot: final art when it exists, else the TEMP stand-in.
function Ui.asset(slot: string): string
	local def = UiAssets[slot]
	assert(def, `unknown UI image slot {slot}`)
	return if def.final and def.final ~= "" then def.final else def.temp
end

-- Puts a slot's image behind `target`'s content, filling it (plus the glow bleed). 9-sliced
-- slots keep their corners at `scale` design px per image px, shrunk when the target is too
-- small for the corners. Returns the ImageLabel (named "Skin").
function Ui.skin(target: GuiObject, slot: string, scale: number?, props: { [string]: any }?): ImageLabel
	local def = UiAssets[slot]
	assert(def, `unknown UI image slot {slot}`)
	local s = scale or 1
	local slice = def.slice
	if slice then
		local cw = slice[1] + (def.size[1] - slice[3])
		local ch = slice[2] + (def.size[2] - slice[4])
		local size = target.Size
		if size.X.Scale == 0 and size.X.Offset > 0 then
			s = math.min(s, size.X.Offset / (cw + 2))
		end
		if size.Y.Scale == 0 and size.Y.Offset > 0 then
			s = math.min(s, size.Y.Offset / (ch + 2))
		end
	end
	local b = def.bleed * s
	local holder: any = target
	holder.BackgroundTransparency = 1
	local img: ImageLabel = Ui.new(
		"ImageLabel",
		merge({
			Name = "Skin",
			Image = Ui.asset(slot),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-b, -b),
			Size = UDim2.new(1, 2 * b, 1, 2 * b),
			ScaleType = if slice then Enum.ScaleType.Slice else Enum.ScaleType.Stretch,
			SliceCenter = if slice
				then Rect.new(slice[1], slice[2], slice[3], slice[4])
				else Rect.new(0, 0, 0, 0),
			SliceScale = s,
			ZIndex = 0,
			Parent = target,
		}, props)
	)
	return img
end

-- Swaps a skin made by Ui.skin to another slot (selection states), keeping its scale.
function Ui.reskin(img: ImageLabel, slot: string)
	local def = UiAssets[slot]
	assert(def, `unknown UI image slot {slot}`)
	img.Image = Ui.asset(slot)
	local slice = def.slice
	if slice then
		img.SliceCenter = Rect.new(slice[1], slice[2], slice[3], slice[4])
	end
	local b = def.bleed * img.SliceScale
	img.Position = UDim2.fromOffset(-b, -b)
	img.Size = UDim2.new(1, 2 * b, 1, 2 * b)
end

-- A plain (non-sliced) image from a slot: icons, banners, rings.
function Ui.image(slot: string, props: { [string]: any }?): ImageLabel
	return Ui.new(
		"ImageLabel",
		merge({
			Image = Ui.asset(slot),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(32, 32),
		}, props)
	)
end

function Ui.icon(slot: string, size: number, props: { [string]: any }?): ImageLabel
	return Ui.image(
		slot,
		merge(
			{ Name = "Icon", Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0, 0.5) },
			props
		)
	)
end

-- An amount with its currency icon (coin, gem, trophy), centred in a row of `height` px.
function Ui.price(amount: string, icon: string, height: number, props: { [string]: any }?): Frame
	local row = Ui.frame(
		merge({
			Name = "Price",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height),
		}, props),
		{ Ui.list(true, 4, Enum.HorizontalAlignment.Center) }
	)
	Ui.icon(icon, height, { AnchorPoint = Vector2.zero, LayoutOrder = 1, Parent = row })
	local label = Ui.text({
		Name = "Amount",
		Text = amount,
		FontFace = F.Number,
		TextSize = math.floor(height * 0.8),
		TextColor3 = C.Gold,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		LayoutOrder = 2,
		Parent = row,
	})
	Ui.outline(C.Night, 1.5).Parent = label
	return row
end

-- ------------------------------------------------------------------ sound

local cache: { [string]: Sound } = {}
local sfxVolume = 1

function Ui.setSfxVolume(v: number)
	sfxVolume = v
end

function Ui.sound(name: string)
	local def = Sounds[name]
	if def == nil or def.id == nil or sfxVolume <= 0 then
		return
	end
	local snd: Sound? = cache[name]
	if snd == nil then
		local made: Sound = Ui.new("Sound", { Name = `Ui_{name}`, SoundId = def.id, Parent = SoundService })
		cache[name] = made
		snd = made
	end
	assert(snd, "sound cache")
	snd.Volume = def.volume * sfxVolume
	SoundService:PlayLocalSound(snd)
end

-- ------------------------------------------------------------------ motion

-- Pops a GUI object in with the open bounce (ART_STYLE section 4). Uses (or adds) a UIScale.
function Ui.popIn(obj: GuiObject, reduced: boolean?)
	local scale = obj:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = obj })
	if reduced then
		scale.Scale = 1
		return
	end
	scale.Scale = 0.85
	TweenService:Create(scale, M.open, { Scale = 1 }):Play()
end

function Ui.pulse(obj: GuiObject, amount: number?)
	local scale = obj:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = obj })
	scale.Scale = 1 + (amount or 0.12)
	TweenService:Create(scale, M.spring, { Scale = 1 }):Play()
end

-- Counts a label up from `from` to `to` (rewards, currency), formatting each step.
function Ui.countUp(label: TextLabel, from: number, to: number, format: (number) -> string, info: TweenInfo?)
	local value = Instance.new("NumberValue")
	value.Value = from
	label.Text = format(from)
	value.Changed:Connect(function(v)
		label.Text = format(math.floor(v + 0.5))
	end)
	local tween = TweenService:Create(value, info or M.count, { Value = to })
	tween.Completed:Connect(function()
		label.Text = format(to)
		value:Destroy()
	end)
	tween:Play()
end

-- Hover glow, a soft hover tick (at most one every 0.08 s) and press squash for any clickable
-- GuiObject (ART_STYLE section 4).
local lastHover = 0
function Ui.juice(button: GuiButton, skin: ImageLabel?)
	local scale = button:FindFirstChildOfClass("UIScale") or Ui.new("UIScale", { Parent = button })
	local base = if skin then skin.ImageColor3 else C.White
	button.MouseEnter:Connect(function()
		if os.clock() - lastHover > 0.08 then
			lastHover = os.clock()
			Ui.sound("hover")
		end
		TweenService:Create(scale, M.hover, { Scale = 1.04 }):Play()
		if skin then
			TweenService:Create(skin, M.hover, { ImageColor3 = base:Lerp(C.White, 0.6) }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, M.hover, { Scale = 1 }):Play()
		if skin then
			TweenService:Create(skin, M.hover, { ImageColor3 = base }):Play()
		end
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, M.press, { Scale = 0.94 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, M.spring, { Scale = 1 }):Play()
	end)
end

-- ------------------------------------------------------------------ layout helpers

function Ui.corner(radius: number?): any
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or S.corner) })
end

function Ui.stroke(color: Color3?, thickness: number?, transparency: number?): any
	return Ui.new("UIStroke", {
		Color = color or C.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- A text outline (UIStroke in Contextual mode) for display text and numbers on art.
function Ui.outline(color: Color3?, thickness: number?, transparency: number?): any
	return Ui.new("UIStroke", {
		Color = color or C.Night,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Ui.pad(px: number?): any
	local u = UDim.new(0, px or S.pad)
	return Ui.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Ui.list(horizontal: boolean?, gap: number?, align: Enum.HorizontalAlignment?): any
	return Ui.new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
	})
end

function Ui.grid(cell: Vector2, gap: number?): any
	return Ui.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap or 8, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Ui.gradient(top: Color3, bottom: Color3, rotation: number?): any
	return Ui.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

-- The gold vertical gradient used on display text ("Victory!", Legendary callouts).
function Ui.goldText(): any
	return Ui.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.GoldHi),
			ColorSequenceKeypoint.new(0.55, C.Gold),
			ColorSequenceKeypoint.new(1, C.GoldLo),
		}),
		Rotation = 90,
	})
end

function Ui.text(props: { [string]: any }): TextLabel
	return Ui.new(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			FontFace = F.Body,
			TextColor3 = C.Text,
			TextSize = S.body,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, S.body + 6),
		}, props)
	)
end

-- Big display text (Luckiest Guy) with a dark outline; `gold` adds the gold gradient.
function Ui.display(props: { [string]: any }, gold: boolean?): TextLabel
	local label = Ui.text(merge({
		FontFace = F.Display,
		TextSize = S.display,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
	}, props))
	Ui.outline(C.Night, 3).Parent = label
	if gold then
		label.TextColor3 = C.White
		Ui.goldText().Parent = label
	end
	return label
end

-- Shrinks a label's text to fit its box, never above `max` (long names on small cards).
function Ui.fit(label: any, max: number, min: number?): any
	label.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 8, Parent = label })
	return label
end

function Ui.frame(props: { [string]: any }, children: { any }?): Frame
	return Ui.new(
		"Frame",
		merge({
			BackgroundColor3 = C.Raised,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, props),
		children
	)
end

-- A recessed area (lists, odds tables) drawn with the panel_inset image.
function Ui.inset(props: { [string]: any }, children: { any }?): Frame
	local f = Ui.frame(merge({ BackgroundTransparency = 1 }, props), children)
	Ui.skin(f, "panel_inset", 1)
	return f
end

-- A grid slot (eggs, cards, items). `className` is usually "TextButton" or "Frame".
function Ui.tile(className: string, props: { [string]: any }, selected: boolean?): any
	local t = Ui.new(
		className,
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = if className == "TextButton" then "" else nil,
			AutoButtonColor = if className == "TextButton" then false else nil,
		}, props)
	)
	local skin = Ui.skin(t, if selected then "tile_selected" else "tile", 1)
	if t:IsA("GuiButton") then
		Ui.juice(t, skin)
		t.Activated:Connect(function()
			Ui.sound("click")
		end)
	end
	return t
end

-- ------------------------------------------------------------------ buttons

local STYLE: { [string]: { slot: string, fg: Color3, face: Font } } = {
	primary = { slot = "button_primary", fg = C.GoldInk, face = F.Title },
	secondary = { slot = "button_secondary", fg = C.Text, face = F.Title },
	ghost = { slot = "button_secondary", fg = C.Text, face = F.Bold },
	success = { slot = "button_robux", fg = C.Text, face = F.Title },
	robux = { slot = "button_robux", fg = C.Text, face = F.Title },
	danger = { slot = "button_danger", fg = C.Text, face = F.Title },
	purple = { slot = "tab_on", fg = C.Text, face = F.Title },
	tab = { slot = "tab_off", fg = C.Muted, face = F.Bold },
}
-- Image px of the visible button body (image height minus 2 * bleed), so buttons of any height
-- keep the same proportions.
local BODY_PX: { [string]: number } = { button = 80, tab = 52 }

export type Button = {
	instance: TextButton,
	label: TextLabel,
	setEnabled: (enabled: boolean) -> (),
	setText: (text: string) -> (),
}

-- One dominant primary action per panel (design rule 1): use "primary" once per panel.
function Ui.button(text: string, style: string, onClick: () -> (), props: { [string]: any }?): Button
	local st = STYLE[style] or STYLE.ghost
	local b: TextButton = Ui.new(
		"TextButton",
		merge({
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, S.button),
		}, props)
	)
	-- Keep compatibility with screens that set alignment props meant for the label.
	local align = b.TextXAlignment
	local height = if b.Size.Y.Scale == 0 then b.Size.Y.Offset else S.button
	local body = if string.sub(st.slot, 1, 4) == "tab_" then BODY_PX.tab else BODY_PX.button
	local skin = Ui.skin(b, st.slot, height / body)
	local label = Ui.text({
		Name = "Label",
		Text = text,
		FontFace = st.face,
		TextColor3 = st.fg,
		TextSize = math.clamp(math.floor(height * 0.42), 11, 22),
		TextXAlignment = align,
		TextWrapped = false,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		ZIndex = 2,
		Parent = b,
	})
	Ui.new("UITextSizeConstraint", { MaxTextSize = label.TextSize, MinTextSize = 9, Parent = label })
	label.TextScaled = true
	if style ~= "primary" then
		Ui.outline(C.Night, 1, 0.5).Parent = label
	end
	Ui.juice(b, skin)
	local enabled = true
	local lastClick = -math.huge
	b.Activated:Connect(function()
		if not enabled then
			Ui.sound("error")
			return
		end
		-- Debounce: a double click (or a double tap) acts once.
		local now = os.clock()
		if now - lastClick < 0.35 then
			return
		end
		lastClick = now
		Ui.sound("click")
		onClick()
	end)
	return {
		instance = b,
		label = label,
		setEnabled = function(on: boolean)
			enabled = on
			skin.ImageTransparency = if on then 0 else 0.45
			skin.ImageColor3 = if on then C.White else Color3.fromRGB(150, 150, 165)
			label.TextColor3 = if on then st.fg else C.Muted
		end,
		setText = function(t: string)
			label.Text = t
		end,
	}
end

-- The round close button (close_button image).
function Ui.closeButton(onClose: () -> (), props: { [string]: any }?): ImageButton
	local b: ImageButton = Ui.new(
		"ImageButton",
		merge({
			Name = "Close",
			Image = Ui.asset("close_button"),
			BackgroundTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(38, 38),
		}, props)
	)
	Ui.juice(b)
	b.Activated:Connect(function()
		Ui.sound("close")
		onClose()
	end)
	return b
end

-- ------------------------------------------------------------------ panels

export type Panel = { frame: Frame, body: Frame, title: TextLabel, header: Frame }

-- A centred modal panel: drop shadow, glowing frame, title bar with an optional icon chip, and
-- the round close button. Opens with the bounce.
function Ui.panel(parent: Instance, title: string, onClose: (() -> ())?, size: UDim2?, icon: string?): Panel
	local frame = Ui.frame({
		Name = "Panel",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- Centred on screen: the left menu slides away while a modal is open (UiFlow).
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = size or UDim2.fromOffset(760, 440),
		Parent = parent,
	})
	local shadow = Ui.frame({
		Name = "Shadow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 8),
		ZIndex = 0,
		Parent = frame,
	})
	Ui.skin(shadow, "shadow", 1)
	Ui.skin(frame, "panel", 1)
	local header = Ui.frame({
		Name = "Header",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 0, 54),
		Parent = frame,
	})
	Ui.skin(header, "panel_header", 0.62)
	local x = 18
	if icon then
		Ui.icon(icon, 38, { Position = UDim2.new(0, 14, 0.5, 0), Parent = header })
		x = 60
	end
	local titleLabel = Ui.text({
		Name = "Title",
		Text = title,
		FontFace = F.Title,
		TextSize = S.title,
		TextWrapped = false,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -x - 60, 1, 0),
		Parent = header,
	})
	Ui.outline(C.Night, 1, 0.4).Parent = titleLabel
	if onClose then
		Ui.closeButton(onClose, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = header,
		})
	end
	local body = Ui.frame({
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -76),
		Parent = frame,
	})
	Ui.sound("open")
	Ui.popIn(frame)
	return { frame = frame, body = body, title = titleLabel, header = header }
end

function Ui.scroll(props: { [string]: any }): ScrollingFrame
	return Ui.new(
		"ScrollingFrame",
		merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.Purple,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, props)
	)
end

-- A horizontal bar (HP, progress) from the hp_frame / hp_fill images, the fill tinted `color`.
-- Returns a setter for the fraction (0..1).
function Ui.bar(parent: Instance, color: Color3, props: { [string]: any }?): (number) -> ()
	local back = Ui.frame(merge({
		Name = "Bar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12),
		Parent = parent,
	}, props))
	local h = if back.Size.Y.Scale == 0 then back.Size.Y.Offset else 12
	Ui.skin(back, "hp_frame", h / 48)
	local clip = Ui.frame({
		Name = "Clip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 1,
		Parent = back,
	})
	local fill = Ui.new("ImageLabel", {
		Name = "Fill",
		Image = Ui.asset("hp_fill"),
		ImageColor3 = color,
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(24, 24, 488, 24),
		SliceScale = h / 48,
		Size = UDim2.fromScale(1, 1),
		Parent = clip,
	})
	-- The fill image spans the whole bar: relative to the clip it is 1 / fraction wide.
	return function(f: number)
		local fraction = math.clamp(f, 0, 1)
		fill.Visible = fraction > 0.001
		clip.Size = UDim2.fromScale(fraction, 1)
		fill.Size = UDim2.fromScale(if fraction > 0.001 then 1 / fraction else 1, 1)
	end
end

-- The theme pass: every rounded, raised, code-drawn box under `root` (a Frame/TextButton with a
-- UICorner and a Raised/Panel/Background fill) becomes the 9-slice tile art, so all screens share
-- the same look. A gold stroke marks the selected tile. Already-skinned boxes are left alone.
local TILE_FILLS = { C.Raised, C.Panel, C.Background, C.Stroke, C.PanelDeep, C.RaisedHi }

local function isTileFill(c: Color3): boolean
	for _, f in TILE_FILLS do
		if math.abs(c.R - f.R) + math.abs(c.G - f.G) + math.abs(c.B - f.B) < 0.02 then
			return true
		end
	end
	return false
end

function Ui.skinify(root: Instance)
	for _, d in root:GetDescendants() do
		if
			(d.ClassName == "Frame" or d.ClassName == "TextButton")
			and not d:FindFirstChild("Skin")
			and d:FindFirstChildOfClass("UICorner")
		then
			local g = d :: any
			if g.BackgroundTransparency < 0.5 and isTileFill(g.BackgroundColor3) then
				local stroke = d:FindFirstChildOfClass("UIStroke")
				local selected = stroke ~= nil
					and math.abs(stroke.Color.R - C.Gold.R) + math.abs(stroke.Color.G - C.Gold.G) < 0.05
				local dim = g.BackgroundColor3 == C.Background
				for _, c in d:GetChildren() do
					if c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient") then
						c:Destroy()
					end
				end
				local skin = Ui.skin(g, if selected then "tile_selected" else "tile", 0.75)
				if dim then
					skin.ImageTransparency = 0.4
				end
				if g:IsA("TextButton") and not g:GetAttribute("Juiced") then
					g:SetAttribute("Juiced", true)
					g.AutoButtonColor = false
					Ui.juice(g, skin)
				end
			end
		end
	end
end

-- Removes every child except layout objects and skins.
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if
			not child:IsA("UIGridStyleLayout")
			and not child:IsA("UIPadding")
			and not (child.Name == "Skin" and child:IsA("ImageLabel"))
		then
			child:Destroy()
		end
	end
end

return Ui
