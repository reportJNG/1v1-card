--!strict
-- The moments worth a pop (BAD_GUI_THINKING_AND_UI section 3), found by comparing the profile view
-- before and after a server update: a quest ticked up ("+1" by the quest card), a quest finished
-- ("QUEST COMPLETE!"), a world unlocked ("WORLD 2 UNLOCKED!"). Pure, so it is tested headlessly;
-- App/Feedback shows them. The view is updated in place, so callers keep a `snap` of the last one.
local Config = script.Parent.Parent.Config
local QuestsCfg = require(Config.Quests)
local Worlds = require(Config.Worlds)

local Moments = {}

export type Snap = { highestTrophies: number, quests: { [string]: number } }
export type Moment =
	{ kind: "questProgress", questId: string, delta: number }
	| { kind: "questComplete", questId: string }
	| { kind: "worldUnlocked", world: number }

function Moments.snap(view: any): Snap
	local quests: { [string]: number } = {}
	for id, q in view.quests or {} do
		quests[id] = q.progress
	end
	return { highestTrophies = view.highestTrophies or 0, quests = quests }
end

function Moments.diff(before: Snap?, view: any): { Moment }
	local out: { Moment } = {}
	if before == nil then
		return out -- the first snapshot is not news
	end
	local ids: { string } = {}
	for id in view.quests or {} do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local q = view.quests[id]
		local def = QuestsCfg.ById[id]
		local was = before.quests[id]
		-- A new day's quests arrive at 0: only progress on a quest we already had is news.
		if def and was ~= nil and q.progress > was and not q.claimed then
			if was < def.target and q.progress >= def.target then
				table.insert(out, { kind = "questComplete", questId = id })
			elseif q.progress < def.target then
				table.insert(out, { kind = "questProgress", questId = id, delta = q.progress - was })
			end
		end
	end
	local high = view.highestTrophies or 0
	for _, w in Worlds.List do
		if w.trophiesToUnlock > before.highestTrophies and w.trophiesToUnlock <= high then
			table.insert(out, { kind = "worldUnlocked", world = w.id })
		end
	end
	return out
end

return table.freeze(Moments)
