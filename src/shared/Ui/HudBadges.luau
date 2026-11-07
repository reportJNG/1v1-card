--!strict
-- What the HUD points at (POLISH_MISSION C): notification dots on the left menu when something is
-- ready, and the bottom quest tracker. Pure, from the client's profile view and the time, so it
-- is unit-tested and never decides anything: claiming still goes through the server.
local Config = script.Parent.Parent.Config
local QuestsCfg = require(Config.Quests)

local HudBadges = {}

local DAY = 86400

export type Dots = { Quests: boolean, Shop: boolean, Deck: boolean }

export type Tracker = { text: string, progress: number, target: number }?

-- True when a quest in the view is complete and not yet claimed.
local function questReady(view: any): boolean
	for id, q in view.quests or {} do
		local def = QuestsCfg.ById[id]
		if def and not q.claimed and q.progress >= def.target then
			return true
		end
	end
	return false
end

function HudBadges.dots(view: any, now: number): Dots
	local today = now // DAY
	local daily = view.daily or {}
	local bagged = false
	for _, counts in view.eggBag or {} do
		if (counts.normal or 0) + (counts.golden or 0) > 0 then
			bagged = true
			break
		end
	end
	return {
		-- a finished quest to claim, or today's streak reward
		Quests = questReady(view) or (daily.lastClaimDay or -1) ~= today,
		-- today's free egg, or eggs waiting in the bag
		Shop = (daily.freeEggDay or -1) ~= today or bagged,
		-- a deck isn't complete
		Deck = #(view.deck or {}) < 3,
	}
end

-- The bottom tracker: today's first unfinished daily quest, else the first unfinished
-- achievement, else nothing.
function HudBadges.tracker(view: any): Tracker
	local best: Tracker = nil
	local function consider(id: string, q: any)
		local def = QuestsCfg.ById[id]
		if def == nil or q.claimed or q.progress >= def.target then
			return
		end
		local daily = string.sub(id, 1, 2) == "d_"
		local current = best
		if current == nil or (daily and not string.find(current.text, "^Daily")) then
			best = {
				text = `{if daily then "Daily" else "Goal"}: {def.text}`,
				progress = q.progress,
				target = def.target,
			}
		end
	end
	local ids = {}
	for id in view.quests or {} do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		consider(id, view.quests[id])
	end
	return best
end

return table.freeze(HudBadges)
