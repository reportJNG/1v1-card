--!strict
-- Creates every remote from Shared/Net/Remotes and routes requests through Dispatcher.
-- Services call Router.handle(name, fn, options) in init() and Router.push(player, name, data).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Dispatcher = require(script.Parent.Dispatcher)
local RateLimiter = require(script.Parent.RateLimiter)

local Router = {}

local handlers: { [string]: { fn: Dispatcher.Handler, options: Dispatcher.Options? } } = {}
local events: { [string]: RemoteEvent } = {}
local deps: Dispatcher.Deps? = nil
local folder: Folder? = nil

function Router.handle(name: string, fn: Dispatcher.Handler, options: Dispatcher.Options?)
	assert(Remotes.Requests[name], `unknown remote {name}`)
	assert(handlers[name] == nil, `remote {name} registered twice`)
	handlers[name] = { fn = fn, options = options }
end

function Router.push(player: Player, name: string, data: any)
	local event = events[name]
	assert(event, `unknown push {name}`)
	if player.Parent then
		event:FireClient(player, data)
	end
end

function Router.pushAll(name: string, data: any)
	events[name]:FireAllClients(data)
end

-- Installs the remotes. `profileDeps` comes from PlayerDataService (avoids a require cycle).
function Router.start(profileDeps: {
	getProfile: (number) -> any,
	markDirty: (number) -> (),
	saveNow: (number) -> any,
	push: (Player) -> (),
})
	local limiter = RateLimiter.new()
	deps = {
		limiter = limiter,
		now = os.clock,
		userIdOf = function(who: any)
			return (who :: Player).UserId
		end,
		getProfile = profileDeps.getProfile,
		markDirty = profileDeps.markDirty,
		saveNow = profileDeps.saveNow,
		push = profileDeps.push :: any,
		log = function(message: string)
			warn(message)
		end,
	}
	local f = Instance.new("Folder")
	f.Name = Remotes.FOLDER
	for name in Remotes.Requests do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.OnServerInvoke = function(player: Player, payload: unknown)
			local entry = handlers[name]
			return Dispatcher.run(
				name,
				entry and entry.fn,
				entry and entry.options,
				player,
				payload,
				deps :: any
			)
		end
		remote.Parent = f
	end
	for _, name in Remotes.Pushes do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = f
		events[name] = event
	end
	f.Parent = ReplicatedStorage
	folder = f
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
	end)
end

function Router.isStarted(): boolean
	return folder ~= nil
end

return Router
