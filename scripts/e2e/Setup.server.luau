-- E2E only (e2e.project.json; never in default.project.json). Gives each test player three
-- different characters and some Coins through the real PlayerDataService, so the client driver
-- (Driver.client.luau) can exercise deck, battle, merge and merchant flows. Refuses to run
-- outside Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "E2E setup must never run on a live server")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Domain.Cards)
local Wallet = require(Shared.Domain.Wallet)
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local function setup(player: Player)
	local profile = PlayerDataService.waitForProfile(player.UserId, 30)
	if profile == nil then
		print("E2E SETUP FAIL no profile")
		return
	end
	for _, id in { "ren_emberfang", "yuki_frostveil", "brannok_ironhide" } do
		assert(Cards.create(profile, id, "Reward", "e2e", false, os.time()).ok, "card")
	end
	-- a spare copy to merge
	assert(Cards.create(profile, "ren_emberfang", "Reward", "e2e", false, os.time()).ok, "spare")
	assert(Wallet.apply(profile, "coins", 5000, "E2E", `e2e:{player.UserId}`, os.time()).ok, "coins")
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.push(player)
	player:SetAttribute("E2EReady", true)
	print("E2E SETUP done")
end

Players.PlayerAdded:Connect(setup)
for _, p in Players:GetPlayers() do
	task.spawn(setup, p)
end
