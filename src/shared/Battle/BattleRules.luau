--!strict
-- The battle engine: a pure, deterministic port of the reference model in sim/engine.py.
-- Same seed + same picks = same match, in Luau and in Python (tests/Specs/BattleParity.spec).
-- The server runs it; clients only animate the events it produces.
--
-- Round: both sides pick Attack / Defend / Special. Specials cost Energy (unaffordable ones
-- become Attack). Guards (Defend, Stance specials) resolve first, then priority specials, then
-- initiative by speed. Counter loop: Special beats Attack, Defend parries Special, Attack
-- beats Defend. Burn ticks and status timers run at the end of the round.
local Shared = script.Parent.Parent
local Rules = require(Shared.Config.Battle)
local Characters = require(Shared.Config.Characters)
local Roles = require(Shared.Config.Roles)
local Rarities = require(Shared.Config.Rarities)
local Families = require(Shared.Config.Families)
local Types = require(Shared.Types)
local Prng = require(script.Parent.Prng)

export type Action = "Attack" | "Defend" | "Special"
export type Event = { any } -- { kind, ...fields }; see the `ev` calls below for each shape

export type UnitSpec = { characterId: string, level: number }

export type Unit = {
	characterId: string,
	special: Types.AbilityDef,
	passive: Types.PassiveEffect,
	maxHp: number,
	hp: number,
	atk: number,
	def: number,
	spd: number,
	crit: number,
	shield: number,
	status: { [string]: number }, -- name -> rounds left
	statusValue: { [string]: number },
	last: string?,
}

export type Side = { units: { Unit }, active: number, energy: number }

export type Match = {
	sides: { Side },
	rng: Prng.Prng,
	round: number,
	events: { Event },
}

local BattleRules = {}

local function rnd(x: number): number
	return math.floor(x + 0.5)
end

local function newUnit(spec: UnitSpec, bonus: { [string]: number }, critBonus: number): Unit
	local d = Characters.ById[spec.characterId]
	assert(d, `unknown character {spec.characterId}`)
	local m = (1 + Rarities.Defs[d.rarity].statBudget) * (1 + Rules.statPerLevel * (spec.level - 1))
	local b = Roles[d.role].base
	local p = d.passive.effect
	local crit = Rules.baseCrit + critBonus
	if p.kind == "CritBonus" then
		crit += p.value
	end
	local maxHp = rnd(b.hp * m * (1 + (bonus.hp or 0)))
	return {
		characterId = d.id,
		special = d.special,
		passive = p,
		maxHp = maxHp,
		hp = maxHp,
		atk = b.atk * m * (1 + (bonus.atk or 0)),
		def = b.def * m * (1 + (bonus.def or 0)),
		spd = b.spd * m * (1 + (bonus.spd or 0)),
		crit = crit,
		shield = 0,
		status = {},
		statusValue = {},
		last = nil,
	}
end

local function newSide(specs: { UnitSpec }): Side
	local counts: { [string]: number } = {}
	for _, s in specs do
		local f = Characters.ById[s.characterId].family
		counts[f] = (counts[f] or 0) + 1
	end
	local units = {}
	for _, s in specs do
		local f = Characters.ById[s.characterId].family
		local stat = Families.Defs[f].bonusStat
		local value = Families.SynergyBonus[math.min(counts[f], 3)]
		local bonus: { [string]: number } = {}
		local crit = 0
		if stat == "crit" then
			crit = value
		else
			bonus[stat] = value
		end
		table.insert(units, newUnit(s, bonus, crit))
	end
	return { units = units, active = 1, energy = Rules.energyStart }
end

local function lowHp(u: Unit): boolean
	return u.passive.kind == "LowHpStat" and u.hp < u.maxHp * (u.passive.threshold :: number)
end

function BattleRules.effAtk(u: Unit): number
	local a = u.atk
	if u.status.Weaken then
		a = a * (1 - u.statusValue.Weaken)
	end
	if lowHp(u) and u.passive.stat == "atk" then
		a = a * (1 + u.passive.value)
	end
	return a
end

function BattleRules.effDef(u: Unit): number
	local d = u.def
	if lowHp(u) and u.passive.stat == "def" then
		d = d * (1 + u.passive.value)
	end
	return d
end

function BattleRules.effSpd(u: Unit): number
	local s = u.spd
	if u.status.Chill then
		s = s * (1 - u.statusValue.Chill)
	end
	return s
end

-- The three units a deck would field, with family bonuses applied, exactly as a battle builds
-- them. For the deck builder and card inspect; no RNG involved.
function BattleRules.preview(specs: { UnitSpec }): { Unit }
	return newSide(specs).units
end

function BattleRules.new(deckA: { UnitSpec }, deckB: { UnitSpec }, seed: number): Match
	return { sides = { newSide(deckA), newSide(deckB) }, rng = Prng.new(seed), round = 0, events = {} }
end

local function ev(m: Match, ...: any)
	table.insert(m.events, { ... })
end

function BattleRules.activeUnit(m: Match, side: number): Unit
	local s = m.sides[side]
	return s.units[s.active]
end

local function sideAlive(s: Side): boolean
	for _, u in s.units do
		if u.hp > 0 then
			return true
		end
	end
	return false
end

function BattleRules.legal(m: Match, side: number): { Action }
	local s = m.sides[side]
	local acts: { Action } = { "Attack", "Defend" }
	if s.energy >= s.units[s.active].special.cost then
		table.insert(acts, "Special")
	end
	return acts
end

function BattleRules.canSpecial(m: Match, side: number): boolean
	local s = m.sides[side]
	return s.energy >= s.units[s.active].special.cost
end

local function est(src: Unit, dst: Unit): number
	return BattleRules.effAtk(src) * Rules.kDef / (Rules.kDef + BattleRules.effDef(dst))
end

-- Chance that `side` acts first this round when neither player guards (the "You act first: 64%"
-- display). Reads state only; it never draws from the match RNG, so it can't change a result.
function BattleRules.firstChance(m: Match, side: number): number
	local mine, theirs =
		BattleRules.effSpd(BattleRules.activeUnit(m, side)),
		BattleRules.effSpd(BattleRules.activeUnit(m, 3 - side))
	local g = Rules.initSlope * (mine - theirs) / (mine + theirs)
	return 0.5 + math.max(-Rules.initCap, math.min(Rules.initCap, g))
end

-- Bench slots (1-based) that can come in.
function BattleRules.bench(m: Match, side: number): { number }
	local s = m.sides[side]
	local out = {}
	for i, u in s.units do
		if u.hp > 0 and i ~= s.active then
			table.insert(out, i)
		end
	end
	return out
end

function BattleRules.needsNext(m: Match, side: number): boolean
	local s = m.sides[side]
	return s.units[s.active].hp <= 0 and sideAlive(s)
end

-- The "sensible default" replacement: best expected trade against the opponent's active card.
function BattleRules.defaultNext(m: Match, side: number): number?
	local opp = BattleRules.activeUnit(m, 3 - side)
	local best, bestValue = nil, nil
	for _, i in BattleRules.bench(m, side) do
		local u = m.sides[side].units[i]
		local v = est(u, opp) - est(opp, u)
		if bestValue == nil or v > bestValue then
			best, bestValue = i, v
		end
	end
	return best
end

function BattleRules.chooseNext(m: Match, side: number, slot: number): boolean
	if not table.find(BattleRules.bench(m, side), slot) then
		return false
	end
	m.sides[side].active = slot
	ev(m, "Enter", side, slot)
	return true
end

-- 1 or 2 when decided, nil while the match goes on.
function BattleRules.outcome(m: Match): number?
	local a, b = sideAlive(m.sides[1]), sideAlive(m.sides[2])
	if a and not b then
		return 1
	elseif b and not a then
		return 2
	end
	if m.round >= Rules.maxRounds or (not a and not b) then
		local fa, fb = 0, 0
		for _, u in m.sides[1].units do
			fa += u.hp / u.maxHp
		end
		for _, u in m.sides[2].units do
			fb += u.hp / u.maxHp
		end
		return if fa >= fb then 1 else 2
	end
	return nil
end

-- Remaining HP share per side (0..3), for UI and tiebreak display.
function BattleRules.hpShare(m: Match, side: number): number
	local t = 0
	for _, u in m.sides[side].units do
		t += u.hp / u.maxHp
	end
	return t
end

local function deal(
	m: Match,
	si: number,
	src: Unit,
	dst: Unit,
	mult: number,
	guard: number,
	special: boolean,
	pierce: number,
	pen: number
): number
	local dfv = BattleRules.effDef(dst) * (1 - pen)
	local dmg = BattleRules.effAtk(src) * mult * (Rules.kDef / (Rules.kDef + dfv))
	dmg = dmg * (1 + m.rng:uniform(-Rules.variance, Rules.variance))
	local crit = m.rng:next() < src.crit
	if crit then
		dmg = dmg * Rules.critMult
	end
	local p = src.passive
	if p.kind == "BonusVsStatus" and dst.status[p.status :: string] then
		dmg = dmg * (1 + p.value)
	end
	if guard ~= 0 then
		local red
		if guard < 0 then
			red = -guard
		else
			red = guard * (if special then Rules.guardVsSpecial else Rules.guardVsAttack)
		end
		if pierce ~= 0 then
			red = red * (1 - pierce)
		end
		dmg = dmg * (1 - red)
	end
	dmg = rnd(dmg)
	if dst.shield > 0 then
		local absorbed = math.min(dst.shield, dmg)
		dst.shield -= absorbed
		dmg -= absorbed
		if absorbed > 0 then
			ev(m, "Absorb", 3 - si, absorbed, dst.shield)
		end
	end
	dst.hp = math.max(0, dst.hp - dmg)
	ev(m, "Hit", si, dmg, if crit then 1 else 0, dst.hp)
	return dmg
end

local function reflectHit(m: Match, oi: number, si: number, dmg: number, frac: number, block: number)
	local r = if dmg ~= 0 then rnd(dmg / (1 - block) * frac) else 0
	local a = BattleRules.activeUnit(m, si)
	a.hp = math.max(0, a.hp - r)
	ev(m, "Reflect", oi, r, a.hp)
end

local NO_APPLIES: { Types.StatusApplication } = {}

local function applyStatus(unit: Unit, app: Types.StatusApplication)
	unit.status[app.status] = app.rounds
	unit.statusValue[app.status] = app.value
end

function BattleRules.resolve(m: Match, actA: Action, actB: Action)
	m.round += 1
	local S = m.sides
	local acts: { string } = { actA, actB }
	for i = 1, 2 do
		local sp = S[i].units[S[i].active].special
		if acts[i] == "Special" and S[i].energy < sp.cost then
			acts[i] = "Attack"
		end
		if acts[i] == "Special" then
			S[i].energy -= sp.cost
		end
	end
	local guard = { 0, 0 }
	local prio = { 0, 0 }
	for i = 1, 2 do
		local u = S[i].units[S[i].active]
		if acts[i] == "Defend" then
			guard[i] = if u.last == "Defend" then Rules.repeatDefend else 1.0
			prio[i] = 2
		elseif acts[i] == "Special" and u.special.kind == "Stance" then
			guard[i] = -(u.special.blockFraction :: number)
			prio[i] = 2
		elseif acts[i] == "Special" and u.special.priority then
			prio[i] = 1
		end
	end
	local order: { number }
	if prio[1] ~= prio[2] then
		order = if prio[1] > prio[2] then { 1, 2 } else { 2, 1 }
	else
		local sa, sb =
			BattleRules.effSpd(BattleRules.activeUnit(m, 1)), BattleRules.effSpd(BattleRules.activeUnit(m, 2))
		local g = Rules.initSlope * (sa - sb) / (sa + sb)
		g = math.max(-Rules.initCap, math.min(Rules.initCap, g))
		order = if m.rng:next() < 0.5 + g then { 1, 2 } else { 2, 1 }
	end
	ev(m, "Round", m.round, acts[1], acts[2], order[1], S[1].energy, S[2].energy)
	local reflect: { { number }? } = { nil, nil }
	local first = order[1]
	for _, si in order do
		local oi = 3 - si
		local s, o = S[si], S[oi]
		local u, t = s.units[s.active], o.units[o.active]
		if u.hp <= 0 or t.hp <= 0 then
			continue
		end
		local a = acts[si]
		if a == "Defend" then
			s.energy = math.min(Rules.energyMax, s.energy + Rules.energyOnDefend)
		elseif a == "Attack" then
			s.energy = math.min(Rules.energyMax, s.energy + Rules.energyOnAttack)
			local dmg = deal(m, si, u, t, 1.0, guard[oi], false, 0, 0)
			if u.passive.kind == "Lifesteal" then
				u.hp = math.min(u.maxHp, u.hp + rnd(dmg * u.passive.value))
				ev(m, "Heal", si, u.hp)
			end
			local r = reflect[oi]
			if r and dmg ~= 0 then
				reflectHit(m, oi, si, dmg, r[1], r[2])
			end
		else
			local sp = u.special
			local k = sp.kind
			local dmg = 0
			if k == "Damage" then
				dmg = deal(
					m,
					si,
					u,
					t,
					sp.multiplier :: number,
					guard[oi],
					true,
					sp.pierceGuard or 0,
					sp.armorPen or 0
				)
				for _, app in (sp.applies or NO_APPLIES) :: { Types.StatusApplication } do
					applyStatus(if app.target == "Opponent" then t else u, app)
				end
				if sp.recoilFraction then
					local rec = rnd(u.maxHp * sp.recoilFraction)
					u.hp = math.max(1, u.hp - rec)
					ev(m, "Recoil", si, rec, u.hp)
				end
			elseif k == "Shield" then
				u.shield = rnd(u.maxHp * (sp.shieldFraction :: number))
				for _, app in (sp.applies or NO_APPLIES) :: { Types.StatusApplication } do
					applyStatus(if app.target == "Opponent" then t else u, app)
				end
				ev(m, "Shield", si, u.shield)
			elseif k == "Heal" then
				local heal = rnd(u.maxHp * (sp.healFraction :: number))
				u.hp = math.min(u.maxHp, u.hp + heal)
				if sp.cleanse then
					table.clear(u.status)
				end
				ev(m, "Heal", si, u.hp)
			elseif k == "Stance" then
				reflect[si] = { sp.reflectFraction :: number, sp.blockFraction :: number }
				ev(m, "Stance", si)
			end
			local r = reflect[oi]
			if k ~= "Stance" and r and dmg ~= 0 then
				reflectHit(m, oi, si, dmg, r[1], r[2])
			end
			if k == "Damage" and acts[oi] == "Defend" then
				o.energy = math.min(Rules.energyMax, o.energy + 1)
				s.energy = math.max(0, s.energy - 1)
				ev(m, "Parry", oi)
				if t.hp > 0 and u.hp > 0 then
					deal(m, oi, t, u, Rules.riposte, 0, false, 0, 0)
				end
			end
		end
		if u.passive.kind == "EnergyOnFirst" and si == first then
			s.energy = math.min(Rules.energyMax, s.energy + u.passive.value)
		end
		if t.hp <= 0 then
			ev(m, "KO", oi)
		end
	end
	for i = 1, 2 do
		local u = S[i].units[S[i].active]
		if u.hp > 0 and u.status.Burn then
			local b = rnd(u.maxHp * u.statusValue.Burn)
			u.hp = math.max(0, u.hp - b)
			ev(m, "Burn", i, b, u.hp)
			if u.hp <= 0 then
				ev(m, "KO", i)
			end
		end
		for name, left in u.status do
			if left - 1 <= 0 then
				u.status[name] = nil
			else
				u.status[name] = left - 1
			end
		end
		u.last = acts[i]
	end
	ev(m, "End", S[1].energy, S[2].energy, S[1].units[S[1].active].hp, S[2].units[S[2].active].hp)
end

-- Event as the "a:b:c" text the Python model logs (parity checks and debugging).
function BattleRules.eventText(e: Event): string
	local parts = table.create(#e)
	for i, v in e do
		parts[i] = tostring(v)
	end
	return table.concat(parts, ":")
end

function BattleRules.signature(m: Match): number
	local h = 0
	for _, e in m.events do
		local text = BattleRules.eventText(e) .. "|"
		for i = 1, #text do
			h = (h * 31 + string.byte(text, i)) % 2147483647
		end
	end
	return h
end

return table.freeze(BattleRules)
