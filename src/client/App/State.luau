--!strict
-- The client's copy of what the server says: the profile view (snapshot + deltas), the queue
-- status and the live battle. Read-only for the UI: only server pushes change it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientView = require(Shared.Domain.ClientView)
local Signal = require(script.Parent.Signal)

local State = {}
State.__index = State

export type State = typeof(setmetatable(
	{} :: {
		view: ClientView.View?,
		queue: { [string]: any },
		battle: { [string]: any }?,
		changed: Signal.Signal<string>, -- "profile" | "queue" | "battle"
	},
	State
))

function State.new(): State
	return setmetatable(
		{ view = nil, queue = { state = "Idle" }, battle = nil, changed = Signal.new() },
		State
	) :: any
end

function State.setSnapshot(self: State, view: ClientView.View)
	self.view = view
	self.changed:fire("profile")
end

function State.applyDelta(self: State, delta: ClientView.Delta)
	if self.view == nil then
		return
	end
	ClientView.apply(self.view :: ClientView.View, delta)
	self.changed:fire("profile")
end

function State.setQueue(self: State, status: { [string]: any })
	self.queue = status
	self.changed:fire("queue")
end

function State.setBattle(self: State, battle: { [string]: any }?)
	self.battle = battle
	self.changed:fire("battle")
end

return State
