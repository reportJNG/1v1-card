--!strict
-- One Guardian per world for the Guardian Trials (PvE). The Guardian plays the adaptive reader
-- AI (Server/Battle/BattleAI). First-clear rewards are in Economy.Trials.
-- Each Guardian fields three characters from its own world's eggs, at a level that rises
-- world by world. The difficulty curve still needs playtesting (ContentStatus: guardianDecks).

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
			{ characterId = "marza_steelheart", level = 1 },
			{ characterId = "brannok_ironhide", level = 1 },
			{ characterId = "aoi_wisplight", level = 1 },
		},
	},
	{
		world = 2,
		displayName = "Thistle the Grove-Keeper",
		deck = {
			{ characterId = "rowan_soulkeeper", level = 2 },
			{ characterId = "shiro_spiritmoss", level = 2 },
			{ characterId = "faelan_glyphstone", level = 2 },
		},
	},
	{
		world = 3,
		displayName = "Sultana Kesh",
		deck = {
			{ characterId = "nyx_voidglimmer", level = 3 },
			{ characterId = "benedia_lightwell", level = 3 },
			{ characterId = "juno_sparkwhip", level = 3 },
		},
	},
	{
		world = 4,
		displayName = "Old Hrimvald",
		deck = {
			{ characterId = "yuki_frostveil", level = 4 },
			{ characterId = "yara_moonhex", level = 4 },
			{ characterId = "sythe_cragscale", level = 4 },
		},
	},
	{
		world = 5,
		displayName = "Magmar the Forgeborn",
		deck = {
			{ characterId = "sorin_embervale", level = 6 },
			{ characterId = "taren_ashscale", level = 6 },
			{ characterId = "vesh_cinderhorn", level = 6 },
		},
	},
	{
		world = 6,
		displayName = "Countess Veyra",
		deck = {
			{ characterId = "vesper_shade", level = 7 },
			{ characterId = "vesh_cinderhorn", level = 7 },
			{ characterId = "selene_gloomfeather", level = 7 },
		},
	},
	{
		world = 7,
		displayName = "Skyherald Ilun",
		deck = {
			{ characterId = "eira_mistsong", level = 9 },
			{ characterId = "elio_dawnspire", level = 9 },
			{ characterId = "mira_stormglen", level = 9 },
		},
	},
	{
		world = 8,
		displayName = "King Osrath the Undying",
		deck = {
			{ characterId = "leopold_lionmark", level = 11 },
			{ characterId = "elio_dawnspire", level = 11 },
			{ characterId = "korr_flamejaw", level = 11 },
		},
	},
	{
		world = 9,
		displayName = "The Hollow Regent",
		deck = {
			{ characterId = "lyss_nebulight", level = 13 },
			{ characterId = "quen_spiralsight", level = 13 },
			{ characterId = "mira_stormglen", level = 13 },
		},
	},
	{
		world = 10,
		displayName = "Seraph-Tyrant Azael",
		deck = {
			{ characterId = "aurelia_dawn", level = 15 },
			{ characterId = "ruska_sinmaw", level = 15 },
			{ characterId = "tamsin_ghostbloom", level = 15 },
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
