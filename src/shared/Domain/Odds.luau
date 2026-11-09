--!strict
-- The single source of egg odds. Both the hatch roll and the odds shown to players call this
-- module, so what a player sees before buying is exactly what the server rolls.
--
-- Rules (design doc section 2):
--   * Band odds per rarity (Config/OddsBands), equal share per enabled character inside a rarity.
--   * A rarity with no enabled character in the pool is removed and its share redistributed
--     proportionally across the remaining rarities.
--   * Golden: Common is removed and redistributed proportionally. Same pool, same egg.
--   * Only active characters drop (Config/Roster, "5-card mode"). Inside each rarity an egg's own
--     pool comes first; if it has no active character of a rarity it lists, every active character
--     of that rarity takes its place, so each egg keeps its rarity odds where it can. An egg left
--     with nothing falls back to every active character.
local Types = require(script.Parent.Parent.Types)
local Config = script.Parent.Parent.Config
local OddsBands = require(Config.OddsBands)
local Rarities = require(Config.Rarities)
local Characters = require(Config.Characters)
local Roster = require(Config.Roster)

local ACTIVE: { [string]: boolean } = {}
for _, id in Roster.active do
	ACTIVE[id] = true
end

export type CharacterOdds = { characterId: string, rarity: string, percent: number } -- rarity: Types.Rarity

export type EggOdds = {
	eggId: string,
	golden: boolean,
	rarities: { [string]: number }, -- Rarity -> percent
	characters: { CharacterOdds }, -- rarity order, then pool order; zero-chance entries omitted
}

export type DisplayRow = { characterId: string, rarity: string, text: string }

local Odds = {}

local function droppable(id: string): boolean
	local def = Characters.ById[id]
	return def ~= nil and def.enabled and ACTIVE[id] == true
end

-- Every active character of a rarity, in roster order.
local function activeOfRarity(rarity: string): { string }
	local out = {}
	for _, id in Roster.active do
		if droppable(id) and Characters.ById[id].rarity == rarity then
			table.insert(out, id)
		end
	end
	return out
end

local function activePool(egg: Types.EggDef, rarity: string): { string }
	local ids = egg.pool[rarity]
	if ids == nil or #ids == 0 then
		return {}
	end
	local out = {}
	for _, id in ids do
		if droppable(id) then
			table.insert(out, id)
		end
	end
	if #out == 0 then
		return activeOfRarity(rarity)
	end
	return out
end

function Odds.forEgg(egg: Types.EggDef, golden: boolean): EggOdds
	assert(not golden or egg.goldenAllowed, `{egg.id} has no Golden version`)
	local band = OddsBands[egg.oddsBand]
	assert(band, `{egg.id}: unknown odds band {egg.oddsBand}`)

	local weights: { [string]: number } = {}
	local pools: { [string]: { string } } = {}
	local total = 0
	for _, rarity in Rarities.Order do
		local pool = activePool(egg, rarity)
		pools[rarity] = pool
		local w = band[rarity] or 0
		if (golden and rarity == "Common") or #pool == 0 then
			w = 0
		end
		weights[rarity] = w
		total += w
	end
	if total == 0 then
		-- Nothing of this egg is active: every active character, with the band's weights where the
		-- band has them and an equal share otherwise.
		local anyBand = false
		for _, rarity in Rarities.Order do
			pools[rarity] = activeOfRarity(rarity)
			anyBand = anyBand or ((band[rarity] or 0) > 0 and #pools[rarity] > 0)
		end
		for _, rarity in Rarities.Order do
			local w = if anyBand then band[rarity] or 0 else 1
			if (golden and rarity == "Common") or #pools[rarity] == 0 then
				w = 0
			end
			weights[rarity] = w
			total += w
		end
	end
	assert(total > 0, `{egg.id}: no character can drop`)

	local rarities: { [string]: number } = {}
	local characters: { CharacterOdds } = {}
	for _, rarity in Rarities.Order do
		local percent = weights[rarity] / total * 100
		rarities[rarity] = percent
		if percent > 0 then
			local pool = pools[rarity]
			for _, id in pool do
				table.insert(characters, { characterId = id, rarity = rarity, percent = percent / #pool })
			end
		end
	end
	return { eggId = egg.id, golden = golden, rarities = rarities, characters = characters }
end

-- Rolls one character. `rng` must be a server-side Random; clients never roll.
function Odds.roll(egg: Types.EggDef, golden: boolean, rng: Random): CharacterOdds
	local odds = Odds.forEgg(egg, golden)
	local x = rng:NextNumber() * 100
	local acc = 0
	for _, entry in odds.characters do
		acc += entry.percent
		if x < acc then
			return entry
		end
	end
	-- Floating-point tail (x within 1e-12 of 100): the last entry owns it.
	return odds.characters[#odds.characters]
end

-- Formats a percentage for the odds disclosure. Whole numbers print plainly; otherwise the value
-- keeps 4 digits from its first significant digit (Roblox allows rounding at 4+ places past the
-- first non-zero digit, with a note that totals may not equal exactly 100%).
function Odds.formatPercent(percent: number): (string, boolean)
	if percent == math.floor(percent) then
		return `{percent}%`, false
	end
	local firstSig = if percent >= 1 then 0 else -math.floor(math.log10(percent))
	local decimals = math.max(firstSig + 3, 1)
	local text = string.format(`%.{decimals}f`, percent)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	local rounded = tonumber(text) ~= percent
	return `{text}%`, rounded
end

-- Rows for the odds pop-up shown before any Coin or Robux purchase.
-- `needsRoundingNote` is true when the shown values may not total exactly 100%.
function Odds.display(egg: Types.EggDef, golden: boolean): ({ DisplayRow }, boolean)
	local odds = Odds.forEgg(egg, golden)
	local rows: { DisplayRow } = {}
	local anyRounded = false
	for _, entry in odds.characters do
		local text, rounded = Odds.formatPercent(entry.percent)
		anyRounded = anyRounded or rounded
		table.insert(rows, { characterId = entry.characterId, rarity = entry.rarity, text = text })
	end
	return rows, anyRounded
end

return table.freeze(Odds)
