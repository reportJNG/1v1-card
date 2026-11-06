--!strict
-- The client's copy of what the server says: the profile view (snapshot + deltas), the queue
-- status, the live battle and the area the character is in (the server's World attribute:
-- 0 = lobby, 1-10 = a world). Read-only for the UI: only server pushes change it.
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
		area: number,
		changed: Signal.Signal<string>, -- "profile" | "queue" | "battle" | "area"
	},
	State
))

function State.new(): State
	return setmetatable(
		{ view = nil, queue = { state = "Idle" }, battle = nil, area = 0, changed = Signal.new() },
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

function State.setArea(self: State, area: number)
	self.area = area
	self.changed:fire("area")
end

return State
