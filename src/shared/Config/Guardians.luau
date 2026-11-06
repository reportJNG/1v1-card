--!strict
-- One Guardian per world for the Guardian Trials (PvE). The Guardian plays the adaptive reader
-- AI (Server/Battle/BattleAI). First-clear rewards are in Economy.Trials.
-- Decks use launch characters until the full roster exists (ContentStatus: guardianDecks).

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
			{ characterId = "brannok_ironhide", level = 1 },
			{ characterId = "ren_emberfang", level = 1 },
			{ characterId = "aurelia_dawn", level = 1 },
		},
	},
	{
		world = 2,
		displayName = "Thistle the Grove-Keeper",
		deck = {
			{ characterId = "aurelia_dawn", level = 2 },
			{ characterId = "yuki_frostveil", level = 2 },
			{ characterId = "rai_stormvolt", level = 2 },
		},
	},
	{
		world = 3,
		displayName = "Sultana Kesh",
		deck = {
			{ characterId = "taren_ashscale", level = 3 },
			{ characterId = "brannok_ironhide", level = 3 },
			{ characterId = "vesper_shade", level = 3 },
		},
	},
	{
		world = 4,
		displayName = "Old Hrimvald",
		deck = {
			{ characterId = "yuki_frostveil", level = 4 },
			{ characterId = "brannok_ironhide", level = 4 },
			{ characterId = "rai_stormvolt", level = 4 },
		},
	},
	{
		world = 5,
		displayName = "Magmar the Forgeborn",
		deck = {
			{ characterId = "taren_ashscale", level = 6 },
			{ characterId = "ren_emberfang", level = 6 },
			{ characterId = "brannok_ironhide", level = 6 },
		},
	},
	{
		world = 6,
		displayName = "Countess Veyra",
		deck = {
			{ characterId = "vesper_shade", level = 7 },
			{ characterId = "taren_ashscale", level = 7 },
			{ characterId = "aurelia_dawn", level = 7 },
		},
	},
	{
		world = 7,
		displayName = "Skyherald Ilun",
		deck = {
			{ characterId = "aurelia_dawn", level = 9 },
			{ characterId = "rai_stormvolt", level = 9 },
			{ characterId = "yuki_frostveil", level = 9 },
		},
	},
	{
		world = 8,
		displayName = "King Osrath the Undying",
		deck = {
			{ characterId = "brannok_ironhide", level = 11 },
			{ characterId = "taren_ashscale", level = 11 },
			{ characterId = "vesper_shade", level = 11 },
		},
	},
	{
		world = 9,
		displayName = "The Hollow Regent",
		deck = {
			{ characterId = "vesper_shade", level = 13 },
			{ characterId = "rai_stormvolt", level = 13 },
			{ characterId = "taren_ashscale", level = 13 },
		},
	},
	{
		world = 10,
		displayName = "Seraph-Tyrant Azael",
		deck = {
			{ characterId = "taren_ashscale", level = 15 },
			{ characterId = "aurelia_dawn", level = 15 },
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
