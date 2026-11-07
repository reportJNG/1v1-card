-- Studio-only visual QA (CARDS_EGGS_MISSION): gives the test player a varied collection through the
-- real PlayerDataService: every rarity at levels 1 / 5 / 10 / 15, Golden copies, spares to merge,
-- a favourite, eggs in the bag and Coins. Insert into ServerScriptService for one Play session, then
-- delete it. Refuses to run outside Studio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "grant-cards must never run on a live server")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cards = require(Shared.Domain.Cards)
local Wallet = require(Shared.Domain.Wallet)
local Characters = require(Shared.Config.Characters)
local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
local PlayerDataService = require(Services:WaitForChild("PlayerDataService"))

local function first(rarity: string, skip: number): string
	local n = 0
	for _, c in Characters.List do
		if c.rarity == rarity then
			n += 1
			if n > skip then
				return c.id
			end
		end
	end
	error(rarity)
end

local function setup(player: Player)
	local profile = PlayerDataService.waitForProfile(player.UserId, 30)
	if profile == nil then
		return
	end
	local now = os.time()
	local function give(id: string, level: number, golden: boolean): string
		local r = Cards.create(profile, id, "Reward", "qa", golden, now)
		assert(r.ok, "card")
		local copy = (r :: any).value
		copy.level = level
		return copy.uid
	end
	for i, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
		give(first(rarity, 0), 1, false)
		give(first(rarity, 1), 5, false)
		give(first(rarity, 2), 10, i % 2 == 0)
		give(first(rarity, 3), 15, false)
		give(first(rarity, 4), 1, true)
	end
	-- spares for merging the level-1 Legendary
	for _ = 1, 3 do
		give(first("Legendary", 0), 1, false)
	end
	local fav = give(first("Epic", 0), 1, false)
	profile.cards[fav].favorite = true
	profile.eggBag["egg_basic"] = { normal = 5, golden = 1 }
	Wallet.apply(profile, "coins", 50000, "QA", `qa:{player.UserId}`, now)
	PlayerDataService.markDirty(player.UserId)
	PlayerDataService.push(player)
	player:SetAttribute("QAReady", true)
	print("QA GRANT done")
end

Players.PlayerAdded:Connect(setup)
for _, p in Players:GetPlayers() do
	task.spawn(setup, p)
end
