--!strict
-- World and egg availability, from the profile's highest trophies and revealed quests.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local Worlds = require(Config.Worlds)
local Leagues = require(Config.Leagues)

local Progress = {}

function Progress.isWorldUnlocked(profile: Types.PlayerProfile, worldId: number): boolean
	local world = Worlds.ById[worldId]
	return world ~= nil and profile.highestTrophies >= world.trophiesToUnlock
end

-- An egg is available when its world is unlocked and, if hidden, its reveal quest is claimed.
-- Event eggs (no world) are never bought from the shop; events grant them.
function Progress.isEggAvailable(profile: Types.PlayerProfile, egg: Types.EggDef): boolean
	if egg.world == nil or not Progress.isWorldUnlocked(profile, egg.world) then
		return false
	end
	if egg.hiddenUntilQuest then
		local quest = profile.quests[egg.hiddenUntilQuest]
		return quest ~= nil and quest.claimed
	end
	return true
end

function Progress.leagueFor(trophies: number): Types.LeagueDef
	local current = Leagues.List[1]
	for _, league in Leagues.List do
		if trophies >= league.minTrophies then
			current = league
		end
	end
	return current
end

return table.freeze(Progress)
