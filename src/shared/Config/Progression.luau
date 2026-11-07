--!strict
-- Card evolution stages (CARDS_EGGS_MISSION section 4.6): visual stages that follow a copy's level.
-- Display only, not a separate system: stages never change stats, merging or anything the server
-- decides. The owner's brief asks for evolution at levels 1 / 50 / 100; the locked max level is 15
-- (Economy.Progression.maxLevel), so the stages are mapped onto 1-15 here. A later switch to 100
-- levels is an edit of these thresholds only.
--   Base       1-4    the normal frame
--   Awakened   5-9    brighter frame, corner gems, a faint aura even on small cards
--   Ascended   10-14  animated energy, a gold inner line, a stronger aura
--   Max        15     a crown on the badge, the MAX ribbon, the strongest aura and a special shine

export type Stage = { id: string, name: string, minLevel: number }

local evolutionStages: { Stage } = {
	{ id = "base", name = "Base", minLevel = 1 },
	{ id = "awakened", name = "Awakened", minLevel = 5 },
	{ id = "ascended", name = "Ascended", minLevel = 10 },
	{ id = "max", name = "Max", minLevel = 15 },
}
for _, s in evolutionStages do
	table.freeze(s)
end

return table.freeze({
	evolutionStages = table.freeze(evolutionStages),
})
