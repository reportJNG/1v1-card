--!strict
-- Installs every remote (Server/Net/Router) once player data is ready, and lets
-- PlayerDataService push profile snapshots and deltas through it.
local Net = script.Parent.Parent:WaitForChild("Net")
local Router = require(Net.Router)
local PlayerDataService = require(script.Parent.PlayerDataService)

local NetService = {}

function NetService.init()
	Router.start({
		getProfile = PlayerDataService.getProfile,
		markDirty = PlayerDataService.markDirty,
		saveNow = PlayerDataService.saveNow,
		push = PlayerDataService.push,
	})
	PlayerDataService.setSender(Router.push)
end

return NetService
