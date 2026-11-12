--!strict
-- Plays the fighters' animation set (Config/FighterPoses) on an R15 rig by writing its Motor6D
-- Transforms each frame: idle loops; attack, defend, special, hit, KO and win play once (KO and win
-- hold their last pose). No animation assets are uploaded. Reduced motion: only the idle breath
-- stops; the actions still read as poses. One RenderStepped connection serves every rig.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FighterPoses = require(Shared.Config.FighterPoses)

local FighterAnim = {}

export type Controller = {
	play: (action: string) -> (),
	destroy: () -> (),
	rig: Model,
}

type State = {
	rig: Model,
	motors: { [string]: Motor6D },
	action: string,
	started: number,
	reduced: boolean,
	base: CFrame,
	forward: Vector3,
}

local active: { [State]: boolean } = {}
local conn: RBXScriptConnection? = nil

local function rot(v: { number }?): CFrame
	if v == nil then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- The pose of an action at time t: every joint lerped between the two keys around t.
local function sample(action: FighterPoses.Action, t: number): ({ [string]: CFrame }, number)
	local keys = action.keys
	local last = keys[#keys]
	if action.loop then
		t = t % last.t
	end
	if t >= last.t then
		local out = {}
		for j, v in last.pose do
			out[j] = rot(v)
		end
		return out, last.root or 0
	end
	local a, b = keys[1], keys[1]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			a, b = keys[i], keys[i + 1]
			break
		end
	end
	local span = math.max(1e-3, b.t - a.t)
	local u = ease(math.clamp((t - a.t) / span, 0, 1))
	local out = {}
	local joints: { [string]: boolean } = {}
	for j in a.pose do
		joints[j] = true
	end
	for j in b.pose do
		joints[j] = true
	end
	for j in joints do
		out[j] = rot(a.pose[j]):Lerp(rot(b.pose[j]), u)
	end
	return out, (a.root or 0) + ((b.root or 0) - (a.root or 0)) * u
end

local function step()
	local now = os.clock()
	for s in active do
		if s.rig.Parent == nil then
			active[s] = nil
			continue
		end
		local action = FighterPoses.Actions[s.action]
		local t = now - s.started
		if s.reduced and s.action == "idle" then
			t = 0
		end
		local pose, root = sample(action, t)
		for name, motor in s.motors do
			motor.Transform = pose[name] or CFrame.identity
		end
		s.rig:PivotTo(s.base + s.forward * root)
		local last = action.keys[#action.keys].t
		if not action.loop and t > last and s.action ~= "ko" and s.action ~= "win" then
			s.action = "idle"
			s.started = now
		end
	end
	if next(active) == nil and conn then
		conn:Disconnect()
		conn = nil
	end
end

-- Starts animating an R15 rig standing at its current pivot; `forward` is the direction to its foe.
function FighterAnim.attach(rig: Model, forward: Vector3, reduced: boolean): Controller
	local motors: { [string]: Motor6D } = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local s: State = {
		rig = rig,
		motors = motors,
		action = "idle",
		started = os.clock(),
		reduced = reduced,
		base = rig:GetPivot(),
		forward = Vector3.new(forward.X, 0, forward.Z).Unit,
	}
	active[s] = true
	if conn == nil then
		conn = RunService.RenderStepped:Connect(step)
	end
	return {
		rig = rig,
		play = function(action: string)
			if FighterPoses.Actions[action] and s.action ~= "ko" then
				s.action = action
				s.started = os.clock()
			end
		end,
		destroy = function()
			active[s] = nil
		end,
	}
end

-- For tests: the pose of an action at time t (joint -> CFrame) and the root offset.
FighterAnim.sample = sample

return FighterAnim
