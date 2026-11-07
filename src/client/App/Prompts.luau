--!strict
-- The game's own look for proximity prompts (POLISH_MISSION C): the portal, the egg stall, the
-- Arena, merchants, nodes, Guardian gates and lobby portals are built with Style = Custom
-- (Server/World), and this draws them as the HUD's pill: a gold key chip (E, the gamepad button,
-- or TAP on touch), the action in the title face and the object under it. On touch the whole pill
-- is the button. Triggering still goes through the prompt, so WorldInteraction and the server
-- checks are unchanged.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Ui = require(script.Parent.Ui)

local C = Theme.Color

local Prompts = {}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		local name = prompt.GamepadKeyCode.Name
		return string.gsub(name, "^Button", "")
	end
	return prompt.KeyboardKeyCode.Name
end

local function build(
	prompt: ProximityPrompt,
	inputType: Enum.ProximityPromptInputType,
	parent: Instance
): BillboardGui
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local gui: BillboardGui = Ui.new("BillboardGui", {
		Name = "Prompt",
		Adornee = prompt.Parent,
		AlwaysOnTop = false, -- always-on-top billboards were not drawn in testing (Future lighting + UI blur)
		LightInfluence = 0,
		Size = UDim2.fromOffset(250, 64),
		StudsOffset = Vector3.new(0, 6, 0), -- above stalls, carts and nodes (not drawn always-on-top)
		Active = touch,
		ResetOnSpawn = false,
		Parent = parent,
	})
	local body: TextButton = Ui.new("TextButton", {
		Name = "Body",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})
	Ui.skin(body, "toast", 0.6)
	local scale = Ui.new("UIScale", { Scale = 0.6, Parent = body })
	local chip = Ui.frame({
		Name = "Key",
		BackgroundColor3 = C.Gold,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(if touch then 52 else 42, 42),
		ZIndex = 2,
		Parent = body,
	}, {
		Ui.corner(10),
		Ui.gradient(C.GoldHi, C.GoldLo, 90),
		Ui.stroke(C.Night, 2),
	})
	Ui.text({
		Text = keyText(prompt, inputType),
		FontFace = Theme.Face.Number,
		TextSize = if touch then 15 else 22,
		TextColor3 = C.GoldInk,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Parent = chip,
	})
	local x = if touch then 72 else 62
	local action = Ui.text({
		Name = "Action",
		Text = prompt.ActionText,
		FontFace = Theme.Face.Title,
		TextSize = 20,
		TextWrapped = false,
		Position = UDim2.fromOffset(x, 7),
		Size = UDim2.new(1, -x - 10, 0, 26),
		ZIndex = 2,
		Parent = body,
	})
	Ui.outline(C.Night, 1.5).Parent = action
	Ui.fit(action, 20, 10)
	local object = Ui.text({
		Name = "Object",
		Text = prompt.ObjectText,
		FontFace = Theme.Face.Bold,
		TextSize = 14,
		TextColor3 = C.Muted,
		TextWrapped = false,
		Position = UDim2.fromOffset(x, 33),
		Size = UDim2.new(1, -x - 10, 0, 20),
		ZIndex = 2,
		Parent = body,
	})
	Ui.fit(object, 14, 9)
	if touch then
		body.Activated:Connect(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
	end
	TweenService:Create(scale, Theme.Motion.open, { Scale = 1 }):Play()
	return gui
end

function Prompts.start()
	local player = Players.LocalPlayer
	local holder = Instance.new("Folder") -- BillboardGuis do not render under a ScreenGui
	holder.Name = "Prompts"
	holder.Parent = player:WaitForChild("PlayerGui")
	local shown: { [ProximityPrompt]: BillboardGui } = {}
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		local old = shown[prompt]
		if old then
			old:Destroy()
		end
		if holder.Parent == nil then
			holder.Parent = player:FindFirstChildOfClass("PlayerGui") -- a respawn can clear it
		end
		shown[prompt] = build(prompt, inputType, holder)
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local gui = shown[prompt]
		shown[prompt] = nil
		if gui then
			gui:Destroy()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local gui = shown[prompt]
		local body = gui and gui:FindFirstChild("Body") :: GuiObject?
		if body then
			Ui.pulse(body, 0.12) -- a little press on use
		end
	end)
end

return Prompts
