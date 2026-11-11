--!strict
-- "Power" numbers for the UI (deck builder, card inspect, matchmaking screen). Built from the
-- same units a battle would field (BattleRules.preview), so family bonuses shown are the real
-- ones. Display only: nothing in the rules reads it.
local Config = script.Parent.Parent.Config
local Characters = require(Config.Characters)
local Families = require(Config.Families)
local BattleRules = require(script.Parent.Parent.Battle.BattleRules)

export type Spec = { characterId: string, level: number }

export type FamilyBonus = { family: string, count: number, stat: string, value: number }

export type DeckPreview = {
	total: number,
	units: {
		{
			characterId: string,
			power: number,
			hp: number,
			atk: number,
			def: number,
			spd: number,
			crit: number,
		}
	},
	families: { FamilyBonus }, -- only families with 2+ cards
}

local Power = {}

local function unitPower(u: BattleRules.Unit): number
	return math.floor(u.maxHp / 10 + u.atk + u.def + u.spd / 2 + 0.5)
end

export type CardNumbers = { power: number, hp: number, atk: number, def: number, spd: number, crit: number }

local function numbers(u: BattleRules.Unit): CardNumbers
	return {
		power = unitPower(u),
		hp = u.maxHp,
		atk = math.floor(u.atk + 0.5),
		def = math.floor(u.def + 0.5),
		spd = math.floor(u.spd + 0.5),
		crit = u.crit,
	}
end

-- One card copy's numbers at its level, exactly as a battle would field it alone. The single
-- source for every card number on screen (BAD_GUI_9 section 3): the card's power plate, the Cards
-- inspect panel and the stats panel all read this, so they can never disagree.
function Power.stats(characterId: string, level: number): CardNumbers
	return numbers(BattleRules.preview({ { characterId = characterId, level = level } })[1])
end

function Power.card(characterId: string, level: number): number
	return Power.stats(characterId, level).power
end

function Power.deck(specs: { Spec }): DeckPreview
	local units = BattleRules.preview(specs)
	local out = {}
	local total = 0
	for i, u in units do
		local p = unitPower(u)
		total += p
		out[i] = {
			characterId = u.characterId,
			power = p,
			hp = u.maxHp,
			atk = math.floor(u.atk + 0.5),
			def = math.floor(u.def + 0.5),
			spd = math.floor(u.spd + 0.5),
			crit = u.crit,
		}
	end
	local counts: { [string]: number } = {}
	for _, s in specs do
		local f = Characters.ById[s.characterId].family
		counts[f] = (counts[f] or 0) + 1
	end
	local families = {}
	for family, count in counts do
		if count >= 2 then
			table.insert(families, {
				family = family,
				count = count,
				stat = Families.Defs[family].bonusStat,
				value = Families.SynergyBonus[math.min(count, 3)],
			})
		end
	end
	table.sort(families, function(a, b)
		return a.family < b.family
	end)
	return { total = total, units = out, families = families }
end

return table.freeze(Power)
