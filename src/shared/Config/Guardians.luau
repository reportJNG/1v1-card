--!strict
-- One Guardian per world for the Guardian Trials (PvE). The Guardian plays the adaptive reader
-- AI (Server/Battle/BattleAI). First-clear rewards are in Economy.Trials.
-- Each Guardian fields three active characters (Config/Roster, "5-card mode"), at a level that
-- rises world by world. Trios are picked so a random same-level deck wins about 52% in World 1,
-- easing down to about 36% in World 10 (sim/trials.py). The difficulty curve still needs playtesting (ContentStatus: guardianDecks).

export type GuardianDef = {
	world: number,
	displayName: string,
	deck: { { characterId: string, level: number } },
}

local List: { GuardianDef } = {
	{
		world = 1,
		displayName = "Warden Moss",
		deck = {
			{ characterId = "ren_emberfang", level = 1 },
			{ characterId = "yuki_frostveil", level = 1 },
			{ characterId = "rai_stormvolt", level = 1 },
		},
	},
	{
		world = 2,
		displayName = "Thistle the Grove-Keeper",
		deck = {
			{ characterId = "ren_emberfang", level = 2 },
			{ characterId = "rai_stormvolt", level = 2 },
			{ characterId = "aurelia_dawn", level = 2 },
		},
	},
	{
		world = 3,
		displayName = "Sultana Kesh",
		deck = {
			{ characterId = "ren_emberfang", level = 3 },
			{ characterId = "vesper_shade", level = 3 },
			{ characterId = "aurelia_dawn", level = 3 },
		},
	},
	{
		world = 4,
		displayName = "Old Hrimvald",
		deck = {
			{ characterId = "ren_emberfang", level = 4 },
			{ characterId = "yuki_frostveil", level = 4 },
			{ characterId = "vesper_shade", level = 4 },
		},
	},
	{
		world = 5,
		displayName = "Magmar the Forgeborn",
		deck = {
			{ characterId = "rai_stormvolt", level = 6 },
			{ characterId = "vesper_shade", level = 6 },
			{ characterId = "aurelia_dawn", level = 6 },
		},
	},
	{
		world = 6,
		displayName = "Countess Veyra",
		deck = {
			{ characterId = "yuki_frostveil", level = 7 },
			{ characterId = "vesper_shade", level = 7 },
			{ characterId = "aurelia_dawn", level = 7 },
		},
	},
	{
		world = 7,
		displayName = "Skyherald Ilun",
		deck = {
			{ characterId = "ren_emberfang", level = 9 },
			{ characterId = "yuki_frostveil", level = 9 },
			{ characterId = "vesper_shade", level = 9 },
		},
	},
	{
		world = 8,
		displayName = "King Osrath the Undying",
		deck = {
			{ characterId = "rai_stormvolt", level = 11 },
			{ characterId = "vesper_shade", level = 11 },
			{ characterId = "aurelia_dawn", level = 11 },
		},
	},
	{
		world = 9,
		displayName = "The Hollow Regent",
		deck = {
			{ characterId = "yuki_frostveil", level = 13 },
			{ characterId = "rai_stormvolt", level = 13 },
			{ characterId = "vesper_shade", level = 13 },
		},
	},
	{
		world = 10,
		displayName = "Seraph-Tyrant Azael",
		deck = {
			{ characterId = "yuki_frostveil", level = 15 },
			{ characterId = "rai_stormvolt", level = 15 },
			{ characterId = "vesper_shade", level = 15 },
		},
	},
}

local ByWorld: { [number]: GuardianDef } = {}
for _, def in List do
	ByWorld[def.world] = def
end

return table.freeze({
	List = table.freeze(List),
	ByWorld = table.freeze(ByWorld),
})
