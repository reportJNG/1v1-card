--!strict
-- Small UI construction helpers on top of Instances, styled from Theme. Every screen builds its
-- GUI through these so spacing, corners and type stay consistent.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local C = Theme.Color
local S = Theme.Size

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
		VerticalAlignment = Enum.VerticalAlignment.Top,
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

function Ui.text(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Theme.Font.Body,
		TextColor3 = C.Text,
		TextSize = S.body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, S.body + 6),
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.new("TextLabel", defaults)
end

-- Shrinks a label's text to fit its box, never above `max` (long names on small cards).
function Ui.fit(label: any, max: number, min: number?): any
	label.TextScaled = true
	Ui.new("UITextSizeConstraint", { MaxTextSize = max, MinTextSize = min or 8, Parent = label })
	return label
end

function Ui.frame(props: { [string]: any }, children: { any }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = C.Raised,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.new("Frame", defaults, children)
end

local STYLE: { [string]: { bg: Color3, fg: Color3 } } = {
	primary = { bg = C.Gold, fg = C.Background },
	secondary = { bg = C.Blue, fg = C.Background },
	success = { bg = C.Green, fg = C.Background },
	danger = { bg = C.Red, fg = C.Background },
	purple = { bg = C.Purple, fg = C.Text },
	ghost = { bg = C.Raised, fg = C.Text },
}

export type Button = {
	instance: TextButton,
	setEnabled: (enabled: boolean) -> (),
	setText: (text: string) -> (),
}

-- One dominant primary action per panel (design rule 1): use "primary" once per panel.
function Ui.button(text: string, style: string, onClick: () -> (), props: { [string]: any }?): Button
	local st = STYLE[style] or STYLE.ghost
	local scale = Ui.new("UIScale", { Scale = 1 })
	local b: TextButton = Ui.new("TextButton", {
		Text = text,
		Font = Theme.Font.Bold,
		TextSize = S.body + 1,
		TextColor3 = st.fg,
		BackgroundColor3 = st.bg,
		AutoButtonColor = true,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, S.button),
	}, { Ui.corner(8), scale })
	if props then
		for k, v in props do
			(b :: any)[k] = v
		end
	end
	local enabled = true
	b.Activated:Connect(function()
		if not enabled then
			return
		end
		scale.Scale = 0.94
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		onClick()
	end)
	return {
		instance = b,
		setEnabled = function(on: boolean)
			enabled = on
			b.AutoButtonColor = on
			b.BackgroundColor3 = if on then st.bg else C.Stroke
			b.TextColor3 = if on then st.fg else C.Muted
		end,
		setText = function(t: string)
			b.Text = t
		end,
	}
end

export type Panel = { frame: Frame, body: Frame, title: TextLabel }

-- A centred modal panel with a title bar and a close button.
function Ui.panel(parent: Instance, title: string, onClose: (() -> ())?, size: UDim2?): Panel
	local frame = Ui.frame({
		Name = "Panel",
		BackgroundColor3 = C.Panel,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = size or UDim2.fromOffset(760, 440),
		Parent = parent,
	}, { Ui.corner(14), Ui.stroke(C.Purple, 2, 0.35) })
	local titleLabel = Ui.text({
		Text = title,
		Font = Theme.Font.Title,
		TextSize = S.title,
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -80, 0, 32),
		Parent = frame,
	})
	if onClose then
		local close = Ui.button("X", "ghost", onClose, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(36, 36),
			Name = "Close",
		})
		close.instance.Parent = frame
	end
	local body = Ui.frame({
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 54),
		Size = UDim2.new(1, -32, 1, -68),
		Parent = frame,
	})
	return { frame = frame, body = body, title = titleLabel }
end

function Ui.scroll(props: { [string]: any }): ScrollingFrame
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Purple,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}
	for k, v in props do
		defaults[k] = v
	end
	return Ui.new("ScrollingFrame", defaults)
end

-- A horizontal progress bar; returns a setter for the fraction (0..1).
function Ui.bar(parent: Instance, color: Color3, props: { [string]: any }?): (number) -> ()
	local back = Ui.frame({
		BackgroundColor3 = C.Background,
		Size = UDim2.new(1, 0, 0, 10),
		Parent = parent,
	}, { Ui.corner(5) })
	if props then
		for k, v in props do
			(back :: any)[k] = v
		end
	end
	local fill = Ui.frame(
		{ BackgroundColor3 = color, Size = UDim2.fromScale(0, 1), Parent = back },
		{ Ui.corner(5) }
	)
	return function(f: number)
		fill.Size = UDim2.fromScale(math.clamp(f, 0, 1), 1)
	end
end

-- Removes every child except layout objects.
function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIGridStyleLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return Ui
