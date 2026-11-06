--!strict
-- The Guardian Trial opponent: the "adaptive" reader from sim/balance.py, ported line for line.
-- It learns how often the player fires a ready Special and how often they Defend under threat,
-- and plays the counter. It reads only what both players can see (energy, cards, last actions),
-- never the player's pick for the current round.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BattleRules = require(Shared.Battle.BattleRules)
local Prng = require(Shared.Battle.Prng)

export type Policy = (m: BattleRules.Match, side: number, g: Prng.Prng) -> BattleRules.Action

local BattleAI = {}

-- True when the opponent's active card has a damaging Special ready.
function BattleAI.threat(m: BattleRules.Match, side: number): boolean
	local o = m.sides[3 - side]
	local sp = o.units[o.active].special
	return sp.kind == "Damage" and o.energy >= sp.cost
end

function BattleAI.reader(): Policy
	local sp = { 1, 2 } -- { times the opponent fired a ready Special, times it was ready }
	local df = { 1, 2 } -- { times the opponent Defended my ready Special, times mine was ready }
	local prev: { boolean }? = nil
	return function(m: BattleRules.Match, side: number, g: Prng.Prng): BattleRules.Action
		local me = m.sides[side]
		local u = me.units[me.active]
		local t = BattleRules.activeUnit(m, 3 - side)
		if prev then
			if prev[1] then
				sp[2] += 1
				sp[1] += if t.last == "Special" then 1 else 0
			end
			if prev[2] then
				df[2] += 1
				df[1] += if t.last == "Defend" then 1 else 0
			end
		end
		local q, p = sp[1] / sp[2], df[1] / df[2]
		local th = BattleAI.threat(m, side)
		local ready = BattleRules.canSpecial(m, side)
		prev = { th, ready and u.special.kind == "Damage" }
		if th and u.last ~= "Defend" and g:next() < math.min(0.9, q * 1.1) then
			return "Defend"
		end
		if ready then
			local k = u.special.kind
			if k == "Heal" then
				return if u.hp < u.maxHp * 0.6 then "Special" else "Attack"
			elseif k == "Shield" then
				return if u.shield == 0 then "Special" else "Attack"
			elseif k == "Stance" then
				return if th then "Special" else "Attack"
			end
			return if g:next() < math.min(0.85, p) then "Attack" else "Special"
		end
		return "Attack"
	end
end

return table.freeze(BattleAI)
