--!strict
-- The world-side effects of the UI state (Shared/Ui/UiFlow view), applied by App: the blur and
-- colour grade behind the menu and modals, the input lock (movement controls off, camera held),
-- the main menu's slowly drifting camera shot over the lobby at night, the fly-in to the character
-- on PLAY (and back out on Menu), and the Roblox backpack / player list hidden while in the menu.
-- Client only; previews and checks run App without it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubLayout = require(ReplicatedStorage:WaitForChild("Shared").Config.HubLayout)

local UiEffects = {}

export type Effects = {
	setBlur: (on: boolean) -> (),
	setInputLocked: (on: boolean) -> (),
	setMenuShot: (on: boolean, instant: boolean?) -> (),
	reduced: boolean,
}

local FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FLY = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local SINK = "UiInputLock"
local MENU_RENDER = "UiMenuShot"

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

local function controls(): any?
	local player = Players.LocalPlayer
	local scripts = player and player:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	if module == nil then
		return nil
	end
	local ok, pm = pcall(require, module)
	if not ok or pm == nil then
		return nil
	end
	local okC, c = pcall(function()
		return (pm :: any):GetControls()
	end)
	return if okC then c else nil
end

-- The menu shot (BAD_GUI_4 target 09's composition): low on the plaza, looking north through the
-- torii to the arena with the Worlds portal on the right, drifting very slowly. It is the main
-- menu's background until the owner's painted D1 is live.
local function menuCFrame(t: number): CFrame
	local o = HubLayout.ORIGIN
	local centre = Vector3.new(o[1], o[2], o[3])
	local eye = centre + Vector3.new(-6 + math.sin(t * 0.05) * 5, 11 + math.sin(t * 0.08) * 0.6, 92)
	local look = centre + Vector3.new(10 + math.sin(t * 0.04) * 3, 13, -40)
	return CFrame.lookAt(eye, look)
end

local function characterView(): CFrame?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if head == nil then
		return nil
	end
	local h = head :: BasePart
	local back = h.CFrame.LookVector * -1
	local eye = h.Position + back * 13 + Vector3.new(0, 3.5, 0)
	return CFrame.lookAt(eye, h.Position + Vector3.new(0, 0.5, 0))
end

function UiEffects.new(): Effects
	local camera = workspace.CurrentCamera
	local blur: BlurEffect = effect("BlurEffect", "UiBlur")
	blur.Size = 0
	local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect", "UiGrade")
	grade.Saturation = 0
	grade.Contrast = 0
	local locked = false
	local menuOn = false
	local menuClock = 0
	local flying: Tween? = nil

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- no tools in this game
	end)

	local self: Effects
	self = {
		reduced = false,
		setBlur = function(on: boolean)
			TweenService:Create(blur, FADE, { Size = if on then 14 else 0 }):Play()
			TweenService:Create(grade, FADE, {
				Saturation = if on then -0.15 else 0,
				Contrast = if on then 0.08 else 0,
			}):Play()
		end,
		setInputLocked = function(on: boolean)
			if on == locked then
				return
			end
			locked = on
			-- No world prompts behind the menu or a modal.
			ProximityPromptService.Enabled = not on
			local c = controls()
			if c then
				if on then
					c:Disable()
				else
					c:Enable()
				end
			end
			if on then
				-- Hold the camera: no zoom, no rotation, no first-person while a modal is up.
				ContextActionService:BindActionAtPriority(
					SINK,
					function()
						return Enum.ContextActionResult.Sink
					end,
					false,
					Enum.ContextActionPriority.High.Value + 50,
					Enum.UserInputType.MouseWheel,
					Enum.UserInputType.MouseButton2,
					Enum.KeyCode.I,
					Enum.KeyCode.O,
					Enum.KeyCode.Left,
					Enum.KeyCode.Right
				)
				if not menuOn and camera.CameraType == Enum.CameraType.Custom then
					camera.CameraType = Enum.CameraType.Scriptable
				end
			else
				ContextActionService:UnbindAction(SINK)
				if not menuOn and flying == nil and camera.CameraType == Enum.CameraType.Scriptable then
					camera.CameraType = Enum.CameraType.Custom
				end
			end
		end,
		setMenuShot = function(on: boolean, instant: boolean?)
			if on == menuOn then
				return
			end
			menuOn = on
			if flying then
				flying:Cancel()
				flying = nil
			end
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not on)
			end)
			if on then
				camera.CameraType = Enum.CameraType.Scriptable
				local start = camera.CFrame
				local blend = if instant or self.reduced then 1 else 0
				RunService:BindToRenderStep(
					MENU_RENDER,
					Enum.RenderPriority.Camera.Value + 2,
					function(dt: number)
						menuClock += dt
						-- The default camera scripts reset the type when the character spawns: hold it.
						camera.CameraType = Enum.CameraType.Scriptable
						blend = math.min(1, blend + dt / 1.4)
						local e = blend * blend * (3 - 2 * blend)
						camera.CFrame = start:Lerp(menuCFrame(menuClock), e)
					end
				)
			else
				RunService:UnbindFromRenderStep(MENU_RENDER)
				local target = characterView()
				local function finish()
					flying = nil
					if menuOn then
						return
					end
					local player = Players.LocalPlayer
					local humanoid = player
						and player.Character
						and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						camera.CameraSubject = humanoid
					end
					if not locked then
						camera.CameraType = Enum.CameraType.Custom
					end
				end
				if target == nil or instant or self.reduced then
					finish()
				else
					local tween = TweenService:Create(camera, FLY, { CFrame = target })
					flying = tween
					tween.Completed:Connect(finish)
					tween:Play()
				end
			end
		end,
	}
	return self
end

return UiEffects
