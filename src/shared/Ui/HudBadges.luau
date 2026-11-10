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
function HudBadges.questReady(view: any): boolean
	for id, q in view.quests or {} do
		local def = QuestsCfg.ById[id]
		if def and not q.claimed and q.progress >= def.target then
			return true
		end
	end
	return false
end

-- True when today's streak reward hasn't been claimed yet.
function HudBadges.dailyReady(view: any, now: number): boolean
	return ((view.daily or {}).lastClaimDay or -1) ~= now // DAY
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
		Quests = HudBadges.questReady(view) or (daily.lastClaimDay or -1) ~= today,
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

export type QuestRow = { text: string, progress: number, target: number, done: boolean }
export type QuestCard = { title: string, done: number, total: number, rows: { QuestRow } }

-- The compact quest card (MISSION 3.1): today's daily quests ("Daily", done / total) with up to
-- two task rows, unfinished first; with no dailies, the unfinished achievements ("Goals"). Nil when
-- there is nothing to show.
function HudBadges.questCard(view: any): QuestCard?
	-- The tutorial comes first, until every step is done (BAD_GUI_5 section 2.3).
	if not (view.flags and view.flags.tutorialDone) then
		local rows: { QuestRow } = {}
		local done = 0
		for _, def in QuestsCfg.Tutorial do
			local q = view.quests and view.quests[def.id]
			local progress = if q then math.min(q.progress, def.target) else 0
			local finished = progress >= def.target
			if finished then
				done += 1
			elseif #rows < 2 then
				table.insert(
					rows,
					{ text = def.text, progress = progress, target = def.target, done = false }
				)
			end
		end
		if #rows > 0 then
			return { title = "Tutorial", done = done, total = #QuestsCfg.Tutorial, rows = rows }
		end
	end
	local dailies: { any }, goals: { any } = {}, {}
	for id, q in view.quests or {} do
		local def = QuestsCfg.ById[id]
		if def then
			local row = {
				id = id,
				text = def.text,
				progress = math.min(q.progress, def.target),
				target = def.target,
				done = q.claimed or q.progress >= def.target,
			}
			table.insert(if string.sub(id, 1, 2) == "d_" then dailies else goals, row)
		end
	end
	local function order(a: any, b: any): boolean
		if a.done ~= b.done then
			return not a.done
		end
		return a.id < b.id
	end
	local list: { any }, title = dailies, "Daily"
	if #dailies == 0 then
		list, title = {}, "Goals"
		for _, g in goals do
			if not g.done then
				table.insert(list, g)
			end
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, order)
	local done = 0
	for _, r in list do
		if r.done then
			done += 1
		end
	end
	local rows: { QuestRow } = {}
	for i = 1, math.min(2, #list) do
		local r = list[i]
		table.insert(rows, { text = r.text, progress = r.progress, target = r.target, done = r.done })
	end
	return { title = title, done = done, total = #list, rows = rows }
end

return table.freeze(HudBadges)
