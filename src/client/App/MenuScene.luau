--!strict
-- The main menu's own 3D scene (FIX_LOBBY_2.md section A, Config/MenuStage): while the menu is open
-- this client places a copy of the server's template (ReplicatedStorage.MenuStage, shapes and
-- meshes) at MenuStage.ORIGIN, far from the lobby, the worlds and the arenas, and removes it when
-- the menu closes, so the lobby never sees it. If the template hasn't arrived (or its meshes are
-- still loading) the same scene is built from data without meshes and swapped once they land.
-- Client-local parts: streaming never drops them. Purely visual.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local MenuStage = require(Shared.Config.MenuStage)
local ArenaKit = require(Shared.Art.ArenaKit)

local MenuScene = {}

local SPIN_KEY = "UiMenuSceneSpin"

local current: Model? = nil
local fromTemplate = false
local shown = false
local reducedOf: () -> boolean = function()
	return false
end

local function origin(): CFrame
	local o = MenuStage.ORIGIN
	return CFrame.new(o[1], o[2], o[3])
end

function MenuScene.origin(): Vector3
	return origin().Position
end

local function place()
	local template = ReplicatedStorage:FindFirstChild("MenuStage")
	local dressed = template ~= nil and template:GetAttribute("Dressed") == true
	if current and (fromTemplate == dressed or not dressed) then
		return -- already the best copy available
	end
	if current then
		current:Destroy()
	end
	local m: Model = if dressed
			and template
			and template:IsA("Model")
		then template:Clone()
		else ArenaKit.scene("MenuStage", MenuStage.Prims, MenuStage.Particles)
	m.Name = "MenuStage"
	m:PivotTo(origin())
	m.Parent = workspace
	current = m
	fromTemplate = dressed
end

-- The rune rings turn slowly (off with reduced motion).
local function spinners(): { Model }
	local out = {}
	if current then
		for _, d in current:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Fx") == "Spin" then
				table.insert(out, d)
			end
		end
	end
	return out
end

function MenuScene.init(reduced: () -> boolean)
	reducedOf = reduced
	task.spawn(function()
		local template = ReplicatedStorage:WaitForChild("MenuStage", 60)
		if template == nil then
			return
		end
		template:GetAttributeChangedSignal("Dressed"):Connect(function()
			if shown then
				place()
			end
		end)
		if shown then
			place()
		end
	end)
end

function MenuScene.show(on: boolean)
	if on == shown then
		return
	end
	shown = on
	if on then
		place()
		local rings: { Model } = {}
		local ringsOf: Model? = nil
		RunService:BindToRenderStep(SPIN_KEY, Enum.RenderPriority.Last.Value, function(dt: number)
			if reducedOf() then
				return
			end
			if current ~= ringsOf then -- the dressed template replaced the first copy
				ringsOf = current
				rings = spinners()
			end
			for i, ring in rings do
				ring:PivotTo(ring:GetPivot() * CFrame.Angles(0, dt * (if i % 2 == 0 then -0.1 else 0.14), 0))
			end
		end)
	else
		RunService:UnbindFromRenderStep(SPIN_KEY)
		if current then
			current:Destroy()
			current = nil
		end
	end
end

return MenuScene
