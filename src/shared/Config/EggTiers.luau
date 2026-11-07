--!strict
-- The display tier of each egg (MISSION 7.1), from its odds band: the tier sets the colour of the
-- egg's pedestal, glow, label pill and summoning circle (`ui-refs-2/01`). Display only: the egg
-- image itself (the Egg Icon Pack, unedited) never changes, and the odds come from OddsBands.
-- Tiers reuse the rarity display (Config/Rarities): Common, Rare, Epic, Legendary, God-tier.
local Types = require(script.Parent.Parent.Types)

local BY_BAND: { [string]: string } = {
	A = "Common",
	B = "Rare",
	C = "Epic",
	D = "Legendary",
	E = "Mythical",
	Event = "Epic",
}

local EggTiers = {}

EggTiers.ByBand = table.freeze(BY_BAND)

-- The tier (a rarity name) of an egg.
function EggTiers.of(egg: Types.EggDef): string
	return BY_BAND[egg.oddsBand] or "Common"
end

return table.freeze(EggTiers)
