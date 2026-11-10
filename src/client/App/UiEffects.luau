--!strict
-- The world-side effects of the UI state (Shared/Ui/UiFlow view), applied by App: the blur and
-- colour grade behind the menu and modals, the input lock (movement controls off, camera held),
-- the main menu's camera on its own scene (App/MenuScene, FIX_LOBBY_2 section A: never the lobby),
-- the fade through black on PLAY and Menu with the camera settling behind the character, and the
-- Roblox backpack / player list hidden while in the menu.
-- Client only; previews and checks run App without it.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MenuStage = require(ReplicatedStorage:WaitForChild("Shared").Config.MenuStage)
local MenuScene = require(script.Parent.MenuScene)

local UiEffects = {}

export type Effects = {
	setBlur: (on: boolean) -> (),
	setInputLocked: (on: boolean) -> (),
	setMenuShot: (on: boolean, instant: boolean?) -> (),
	reduced: boolean,
}

local FADE = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_IN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE_OUT = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SETTLE = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
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

-- The menu shot (FIX_LOBBY_2 section A): the menu's own scene, from the front of the cliff
-- platform past the hero to the islands and the moon, drifting very slowly.
local function menuCFrame(t: number): CFrame
	local o = MenuScene.origin()
	local cam, look, sway = MenuStage.CAMERA.at, MenuStage.CAMERA.look, MenuStage.SWAY
	local eye = o
		+ Vector3.new(
			cam[1] + math.sin(t * 0.07) * sway * 2,
			cam[2] + math.sin(t * 0.11) * sway * 0.4,
			cam[3]
		)
	local at = o + Vector3.new(look[1] + math.sin(t * 0.05) * sway, look[2], look[3])
	return CFrame.lookAt(eye, at)
end

-- A black cover over the world for the fade on PLAY and Menu.
local function fadeCover(): Frame?
	local player = Players.LocalPlayer
	local gui = player and player:FindFirstChildOfClass("PlayerGui")
	if gui == nil then
		return nil
	end
	local sg = gui:FindFirstChild("UiFade") :: ScreenGui?
	if sg == nil then
		local made = Instance.new("ScreenGui")
		made.Name = "UiFade"
		made.IgnoreGuiInset = true
		made.ResetOnSpawn = false
		made.DisplayOrder = 90
		made.Parent = gui
		local f = Instance.new("Frame")
		f.Name = "Cover"
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.Size = UDim2.fromScale(1, 1)
		f.BorderSizePixel = 0
		f.Parent = made
		sg = made
	end
	return (sg :: ScreenGui):FindFirstChild("Cover") :: Frame?
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
	local cutId = 0 -- the latest menu switch (a fade's late callback must not undo a newer one)

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- no tools in this game
	end)

	local self: Effects
	MenuScene.init(function()
		return self.reduced
	end)
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
			cutId += 1
			local myCut = cutId
			if flying then
				flying:Cancel()
				flying = nil
			end
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not on)
			end)
			local cover = fadeCover()
			local smooth = not (instant or self.reduced) and cover ~= nil
			-- Cover the world, run `cut` while it is black, then uncover (a plain cut when reduced).
			local function through(cut: () -> ())
				if not smooth or cover == nil then
					cut()
					return
				end
				local c = cover :: Frame
				local down = TweenService:Create(c, FADE_IN, { BackgroundTransparency = 0 })
				down.Completed:Connect(function()
					if myCut ~= cutId then
						return -- a newer switch took over
					end
					cut()
					TweenService:Create(c, FADE_OUT, { BackgroundTransparency = 1 }):Play()
				end)
				down:Play()
			end
			if on then
				through(function()
					MenuScene.show(true)
					camera.CameraType = Enum.CameraType.Scriptable
					RunService:BindToRenderStep(
						MENU_RENDER,
						Enum.RenderPriority.Camera.Value + 2,
						function(dt: number)
							menuClock += dt
							-- The default camera scripts reset the type when the character spawns: hold it.
							camera.CameraType = Enum.CameraType.Scriptable
							camera.CFrame = menuCFrame(menuClock)
						end
					)
				end)
			else
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
				through(function()
					RunService:UnbindFromRenderStep(MENU_RENDER)
					MenuScene.show(false)
					local target = characterView()
					if target == nil or not smooth then
						finish()
						return
					end
					-- From slightly above, settling behind the character (FIX_LOBBY_2 B1).
					local t = target :: CFrame
					camera.CFrame =
						CFrame.lookAt(t.Position + Vector3.new(0, 9, 6), t.Position + t.LookVector * 20)
					local tween = TweenService:Create(camera, SETTLE, { CFrame = t })
					flying = tween
					tween.Completed:Connect(finish)
					tween:Play()
				end)
			end
		end,
	}
	return self
end

return UiEffects
