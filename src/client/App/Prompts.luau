--!strict
-- The game's own look for proximity prompts (BAD_GUI_9 section 1). The portal, the egg stall, the
-- Arena, merchants, nodes, Guardian gates and lobby portals are built with Style = Custom
-- (Server/World), and this draws each one as a billboard over its object with **no box**, left to
-- right:
--   1. a painted key plate: "E" (or the gamepad button); on touch a big round TAP button
--   2. the action as one big outlined word: HARVEST, SELL, FIGHT, ENTER, OPEN, CLAIM
--   3. the item icon and its yield for a resource node ("x1-3"), or the prompt's own icon
-- A hold prompt (harvest) fills a gold ring around the key plate while held. Triggering still goes
-- through the prompt, so WorldInteraction and the server checks are unchanged; the harvested items
-- fly to the bag from WorldInteraction (ctx.fly).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.Kit)
local ItemIcon = require(script.Parent.ItemIcon)

local C = Theme.Color

local Prompts = {}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return (string.gsub(name, "^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

-- A ring that fills clockwise from 12 o'clock around the key plate: the kit's glow ring in two
-- clipped halves, each revealed by a turning gradient. Returns a setter for 0..1.
local function holdRing(parent: GuiObject, z: number): (number) -> ()
	local holder = Ui.frame({
		Name = "HoldRing",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.45, 1.45),
		ZIndex = z,
		Parent = parent,
	})
	Ui.image("timer_ring_bg", {
		Name = "Track",
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Parent = holder,
	})
	local grads: { UIGradient } = {}
	for side = 0, 1 do
		local clip = Ui.frame({
			Name = if side == 0 then "Left" else "Right",
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(side * 0.5, 0),
			Size = UDim2.fromScale(0.5, 1),
			ZIndex = z + 1,
			Parent = holder,
		})
		local img = Kit.image("shockwave_ring", {
			Name = "Fill",
			ImageColor3 = C.GoldHi,
			ScaleType = Enum.ScaleType.Stretch,
			Position = UDim2.fromScale(-side, 0),
			Size = UDim2.fromScale(2, 1),
			ZIndex = z + 1,
			Parent = clip,
		})
		grads[side + 1] = Ui.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.499, 0),
				NumberSequenceKeypoint.new(0.5, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = img,
		})
	end
	local function set(a: number)
		a = math.clamp(a, 0, 1)
		grads[2].Rotation = math.min(a, 0.5) * 360 -- right half: 12 to 6 o'clock
		grads[1].Rotation = 180 + (math.max(a, 0.5) - 0.5) * 360 -- left half: 6 back to 12
	end
	set(0)
	return set
end

export type Shown = { gui: BillboardGui, ring: ((number) -> ())? }

local function build(
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType,
	parent: Instance
): Shown
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local gui: BillboardGui = Ui.new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = false, -- always-on-top billboards were not drawn in testing (Future lighting + UI blur)
		LightInfluence = 0,
		Size = UDim2.fromOffset(340, 84),
		-- above stalls, carts and nodes (not drawn always-on-top); a tall object sets its own height
		StudsOffset = Vector3.new(0, (tonumber(prompt:GetAttribute("Height")) or 6), 0),
		Active = touch,
		ResetOnSpawn = false,
		Parent = parent,
	})
	local body: TextButton = Ui.new("TextButton", {
		Name = "Body",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1, -- no box: the plate, the word and the icon stand on their own
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, { Ui.list(true, 10, Enum.HorizontalAlignment.Center) })
	local layout = body:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = body })

	-- 1. the key plate (a painted HUD button), or a big round tap button on touch
	local plateSize = if touch then 72 else 58
	local plate = Kit.image(if touch then "hud_btn_green" else "hud_btn_orange", {
		Name = "Key",
		ScaleType = Enum.ScaleType.Stretch,
		Size = UDim2.fromOffset(plateSize, plateSize),
		LayoutOrder = 1,
		ZIndex = 3,
		Parent = body,
	})
	if touch then
		Ui.corner(plateSize // 2).Parent = plate
	end
	local key = Ui.display({
		Name = "Glyph",
		Text = keyText(prompt, inputType),
		TextSize = if touch then 24 else 34,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = plate,
	})
	key.TextColor3 = C.White
	local ring = if prompt.HoldDuration > 0 then holdRing(plate, 2) else nil

	-- 2. the action as one big word
	local word = Ui.display({
		Name = "Action",
		Text = string.upper(prompt.ActionText),
		TextSize = 40,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 48),
		LayoutOrder = 2,
		ZIndex = 3,
		Parent = body,
	}, true)
	Ui.outline(C.Night, 4).Parent = word

	-- 3. the item icon and yield (resource nodes), or the prompt's own icon
	local itemId = prompt:GetAttribute("ItemId")
	local icon = prompt:GetAttribute("Icon")
	if typeof(itemId) == "string" then
		local holder = Ui.frame({
			Name = "Item",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(60, 60),
			LayoutOrder = 3,
			ZIndex = 3,
			Parent = body,
		})
		-- a soft light behind the item, so a green leaf still reads over green grass
		Kit.image("fx_mote", {
			Name = "Glow",
			ImageColor3 = C.White,
			ImageTransparency = 0.25,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.7, 1.7),
			ZIndex = 2,
			Parent = holder,
		})
		ItemIcon.new(itemId, 60, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 3,
			Parent = holder,
		}, true)
		local yield = prompt:GetAttribute("Yield")
		if typeof(yield) == "string" then
			local y = Ui.display({
				Name = "Yield",
				Text = yield,
				TextSize = 24,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 30),
				LayoutOrder = 4,
				ZIndex = 3,
				Parent = body,
			}, true)
			Ui.outline(C.Night, 3).Parent = y
		end
	elseif typeof(icon) == "string" then
		Ui.icon(icon, 54, {
			Name = "Icon",
			AnchorPoint = Vector2.zero,
			LayoutOrder = 3,
			ZIndex = 3,
			Parent = body,
		})
	end

	if touch then
		body.Activated:Connect(function()
			if prompt.HoldDuration > 0 then
				return -- holds use the press below
			end
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
		body.InputBegan:Connect(function(input)
			if prompt.HoldDuration > 0 and input.UserInputType == Enum.UserInputType.Touch then
				prompt:InputHoldBegin()
			end
		end)
		body.InputEnded:Connect(function(input)
			if prompt.HoldDuration > 0 and input.UserInputType == Enum.UserInputType.Touch then
				prompt:InputHoldEnd()
			end
		end)
	end
	TweenService:Create(scale, Theme.Motion.open, { Scale = 1 }):Play()
	return { gui = gui, ring = ring }
end

function Prompts.start()
	local player = Players.LocalPlayer
	local holder = Instance.new("Folder") -- BillboardGuis do not render under a ScreenGui
	holder.Name = "Prompts"
	holder.Parent = player:WaitForChild("PlayerGui")
	local shown: { [ProximityPrompt]: Shown } = {}
	local holding: { [ProximityPrompt]: RBXScriptConnection } = {}
	local function stopHold(prompt: ProximityPrompt)
		local c = holding[prompt]
		holding[prompt] = nil
		if c then
			c:Disconnect()
		end
		local s = shown[prompt]
		if s and s.ring then
			s.ring(0)
		end
	end
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local old = shown[prompt]
		if old then
			old.gui:Destroy()
		end
		if holder.Parent == nil then
			holder.Parent = player:FindFirstChildOfClass("PlayerGui") -- a respawn can clear it
		end
		shown[prompt] = build(prompt, inputType, holder)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		stopHold(prompt)
		local s = shown[prompt]
		shown[prompt] = nil
		if s then
			s.gui:Destroy()
		end
	end)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
		local s = shown[prompt]
		if s == nil or s.ring == nil or prompt.HoldDuration <= 0 then
			return
		end
		stopHold(prompt)
		local started = os.clock()
		local ring = s.ring
		holding[prompt] = RunService.RenderStepped:Connect(function()
			ring((os.clock() - started) / prompt.HoldDuration)
		end)
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
		stopHold(prompt)
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		stopHold(prompt)
		local s = shown[prompt]
		local key = s and s.gui:FindFirstChild("Key", true) :: GuiObject?
		if key then
			Ui.pulse(key, 0.18) -- a little press on use
		end
	end)
end

return Prompts
