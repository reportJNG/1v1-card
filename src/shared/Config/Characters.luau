--!strict
-- Character catalog. Add a character by appending one entry; ids are permanent.
-- The catalog is a list (stable order for UI and tests) plus a lookup built from it.
-- Numbers come from the battle balance model (design doc section 3).
local Types = require(script.Parent.Parent.Types)

local List: { Types.CharacterDef } = {
	{
		id = "ren_emberfang",
		displayName = "Ren Emberfang",
		family = "Flame",
		rarity = "Rare",
		role = "Striker",
		special = {
			id = "ember_rush",
			displayName = "Ember Rush",
			cost = 3,
			kind = "Damage",
			multiplier = 1.65,
			applies = { { status = "Burn", target = "Opponent", rounds = 2, value = 0.06 } },
		},
		passive = {
			id = "kindling",
			displayName = "Kindling",
			description = "+10% damage to Burning targets.",
			effect = { kind = "BonusVsStatus", status = "Burn", value = 0.10 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "yuki_frostveil",
		displayName = "Yuki Frostveil",
		family = "Ice",
		rarity = "Epic",
		role = "Guardian",
		special = {
			id = "glacier_ward",
			displayName = "Glacier Ward",
			cost = 3,
			kind = "Shield",
			shieldFraction = 0.25,
			applies = {
				{ status = "Chill", target = "Opponent", rounds = 2, value = 0.25 },
			},
		},
		passive = {
			id = "frostbite",
			displayName = "Frostbite",
			description = "+10% damage to Chilled targets.",
			effect = { kind = "BonusVsStatus", status = "Chill", value = 0.10 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "rai_stormvolt",
		displayName = "Rai Stormvolt",
		family = "Lightning",
		rarity = "Common",
		role = "Skirmisher",
		special = {
			id = "static_step",
			displayName = "Static Step",
			cost = 2,
			kind = "Damage",
			multiplier = 1.5, -- M3 tuning: was 1.45
			priority = true,
		},
		passive = {
			id = "momentum",
			displayName = "Momentum",
			description = "+1 Energy when acting first.",
			effect = { kind = "EnergyOnFirst", value = 1 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "vesper_shade",
		displayName = "Vesper Shade",
		family = "Shadow",
		rarity = "Legendary",
		role = "Trickster",
		special = {
			id = "umbral_mark",
			displayName = "Umbral Mark",
			cost = 3,
			kind = "Damage",
			multiplier = 1.33, -- M3 tuning: -5%
			pierceGuard = 0.25,
			applies = { { status = "Weaken", target = "Opponent", rounds = 2, value = 0.20 } },
		},
		passive = {
			id = "nightblade",
			displayName = "Nightblade",
			description = "10% critical hit chance.",
			effect = { kind = "CritBonus", value = 0.05 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "aurelia_dawn",
		displayName = "Aurelia Dawn",
		family = "Divine",
		rarity = "Mythical",
		role = "Support",
		special = {
			id = "radiant_mend",
			displayName = "Radiant Mend",
			cost = 3,
			kind = "Heal",
			healFraction = 0.30,
			cleanse = true,
		},
		passive = {
			id = "dawnlight",
			displayName = "Dawnlight",
			description = "Attacks heal her for 10% of the damage dealt.",
			effect = { kind = "Lifesteal", value = 0.10 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "brannok_ironhide",
		displayName = "Brannok Ironhide",
		family = "Beast",
		rarity = "Common",
		role = "Guardian",
		special = {
			id = "thick_hide",
			displayName = "Thick Hide",
			cost = 2,
			kind = "Stance",
			priority = true,
			blockFraction = 0.50,
			reflectFraction = 0.80,
		},
		passive = {
			id = "last_stand",
			displayName = "Last Stand",
			description = "+30% DEF below half HP.",
			effect = { kind = "LowHpStat", stat = "def", threshold = 0.5, value = 0.30 },
		},
		enabled = true,
		assets = {},
	},
	{
		id = "taren_ashscale",
		displayName = "Taren Ashscale",
		family = "Dragon",
		rarity = "Epic",
		role = "Bruiser",
		special = {
			id = "dragons_wrath",
			displayName = "Dragon's Wrath",
			cost = 4,
			kind = "Damage",
			multiplier = 2.09, -- M3 tuning: -5%
			armorPen = 0.30,
			recoilFraction = 0.10,
		},
		passive = {
			id = "cornered_fury",
			displayName = "Cornered Fury",
			description = "+10% ATK below half HP.",
			effect = { kind = "LowHpStat", stat = "atk", threshold = 0.5, value = 0.10 },
		},
		enabled = true,
		assets = {},
	},
}

local ById: { [string]: Types.CharacterDef } = {}
for _, def in List do
	ById[def.id] = def
end

-- Design capacity. The validator fails if the catalog grows past this without a review.
local MAX_CATALOG_SIZE = 100

return table.freeze({
	List = table.freeze(List),
	ById = table.freeze(ById),
	MaxCatalogSize = MAX_CATALOG_SIZE,
})
