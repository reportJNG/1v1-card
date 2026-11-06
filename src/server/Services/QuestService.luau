--!strict
-- Quests.Claim and Daily.ClaimStreak, and today's daily quests rolled when a profile loads.
-- Progress is added where things happen (EconomyService, FarmService, BattleService) through the
-- pure Shared/Domain/Quests.track.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Domain.Quests)
local Streak = require(Shared.Domain.Streak)
local Server = script.Parent.Parent
local Router = require(Server:WaitForChild("Net").Router)
local PlayerDataService = require(script.Parent.PlayerDataService)
local Telemetry = require(script.Parent.Telemetry)

local QuestService = {}

function QuestService.init()
	Router.handle("Quests.Claim", function(player, args, profile)
		local r = Quests.claim(profile :: any, args.questId, os.time())
		if r.ok then
			Telemetry.event(player, "quest_claim", { quest = args.questId })
		end
		return r
	end, { saveNow = true })

	Router.handle("Daily.ClaimStreak", function(player, _args, profile)
		local r = Streak.claim(profile :: any, os.time())
		if r.ok then
			Telemetry.event(player, "streak_claim", { day = r.value.day })
		end
		return r
	end, { saveNow = true })

	PlayerDataService.onLoaded(function(player, profile)
		local before = profile.questDay
		Quests.roll(profile, os.time())
		if profile.questDay ~= before then
			PlayerDataService.markDirty(player.UserId)
			PlayerDataService.push(player)
		end
	end)
end

return QuestService
