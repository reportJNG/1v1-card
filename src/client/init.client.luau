--!strict
-- 1v1 CARD client entry point. The client never decides balances, rolls, damage or results:
-- it sends intents through the remotes (validated by the server's Dispatcher) and renders what
-- the server pushes back.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AppFolder = script:WaitForChild("App")
local App = require(AppFolder:WaitForChild("App"))
local Screens = AppFolder:WaitForChild("Screens")
local Battle = require(Screens:WaitForChild("Battle"))
local WorldInteraction = require(AppFolder:WaitForChild("WorldInteraction"))
local AreaFx = require(AppFolder:WaitForChild("AreaFx"))
local UiEffects = require(AppFolder:WaitForChild("UiEffects"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local net: App.Net = {
	request = function(name: string, payload: any?): App.Reply
		local remote = remotes:FindFirstChild(name)
		if remote == nil or not remote:IsA("RemoteFunction") then
			return { ok = false, err = "NotAvailable" }
		end
		local ok, reply = pcall(function()
			return (remote :: RemoteFunction):InvokeServer(payload)
		end)
		if not ok or typeof(reply) ~= "table" then
			return { ok = false, err = "ServerError" }
		end
		return reply
	end,
	on = function(push: string, fn: (any) -> ())
		local event = remotes:WaitForChild(push) :: RemoteEvent
		event.OnClientEvent:Connect(fn)
	end,
}

local gui = Instance.new("ScreenGui")
gui.Name = "OneVOneCard"
gui.Parent = player:WaitForChild("PlayerGui")

local ctx = App.start({
	gui = gui,
	net = net,
	attr = function(name: string): any
		return player:GetAttribute(name)
	end,
	now = function(): number
		return workspace:GetServerTimeNow()
	end,
	guid = function(): string
		return HttpService:GenerateGUID(false)
	end,
	effects = UiEffects.new(),
	screens = {
		Play = require(Screens:WaitForChild("Play")) :: any,
		Collection = require(Screens:WaitForChild("Collection")) :: any,
		Deck = require(Screens:WaitForChild("Deck")) :: any,
		Shop = require(Screens:WaitForChild("Shop")) :: any,
		Worlds = require(Screens:WaitForChild("Worlds")) :: any,
		Quests = require(Screens:WaitForChild("Quests")) :: any,
		Settings = require(Screens:WaitForChild("Settings")) :: any,
		Merchant = require(Screens:WaitForChild("Merchant")) :: any,
	},
})

-- Lobby vs world (the server sets the World attribute on travel, return and respawn).
local function syncArea()
	local world = player:GetAttribute("World")
	ctx.state:setArea(if typeof(world) == "number" then world else 0)
end
player:GetAttributeChangedSignal("World"):Connect(syncArea)
syncArea()

local battle: Battle.Handle? = nil
net.on("Battle.Start", function(start)
	ctx.close()
	if battle then
		battle.destroy()
	end
	battle = Battle.open(ctx, start)
end)
net.on("Battle.Round", function(msg)
	if battle then
		battle.round(msg)
	end
end)
net.on("Battle.End", function(data)
	if battle then
		battle.finish(data)
	end
end)

-- The leaving screen resets the client: the battle screen goes (the server has forfeited it).
ctx.onLeave(function()
	if battle then
		battle.destroy()
		battle = nil
	end
	ctx.state:setBattle(nil)
end)

WorldInteraction.start(ctx)
require(AppFolder:WaitForChild("Prompts")).start()
require(AppFolder:WaitForChild("Nameplates")).start()
AreaFx.start(ctx)
