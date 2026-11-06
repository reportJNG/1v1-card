--!strict
-- Ten progressive worlds, unlocked by highest trophies reached (a world never re-locks).
local Types = require(script.Parent.Parent.Types)

local List: { Types.WorldDef } = {
	{
		id = 1,
		displayName = "Green Plains",
		trophiesToUnlock = 0,
		eggs = { "egg_basic", "egg_spotted", "egg_cracked", "egg_cat", "egg_dog" },
	},
	{ id = 2, displayName = "Enchanted Forest", trophiesToUnlock = 100, eggs = { "egg_rainbow" } },
	{
		id = 3,
		displayName = "Desert Kingdom",
		trophiesToUnlock = 250,
		eggs = { "egg_sandcastle", "egg_coconut", "egg_royal" },
	},
	{ id = 4, displayName = "Frozen Lands", trophiesToUnlock = 450, eggs = { "egg_ice", "egg_yeti" } },
	{ id = 5, displayName = "Volcano", trophiesToUnlock = 700, eggs = { "egg_mine", "egg_dragon" } },
	{ id = 6, displayName = "Demon Realm", trophiesToUnlock = 1000, eggs = { "egg_demon" } },
	{
		id = 7,
		displayName = "Celestial Islands",
		trophiesToUnlock = 1350,
		eggs = { "egg_angel", "egg_kraken" },
	},
	{
		id = 8,
		displayName = "Ancient Kingdom",
		trophiesToUnlock = 1750,
		eggs = { "egg_dominus", "egg_legendary" },
	},
	{
		id = 9,
		displayName = "Shadow Dimension",
		trophiesToUnlock = 2200,
		eggs = { "egg_glitched", "egg_black_hole", "egg_secret" },
	},
	{
		id = 10,
		displayName = "Divine World",
		trophiesToUnlock = 2700,
		eggs = { "egg_angel_demon", "egg_mythical" },
	},
}

local ById: { [number]: Types.WorldDef } = {}
for _, def in List do
	ById[def.id] = def
end

return table.freeze({ List = table.freeze(List), ById = table.freeze(ById) })
