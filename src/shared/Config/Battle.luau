--!strict
-- Battle rule constants (design doc section 3). Shared by the Luau engine and, through
-- tests/Tools/ExportContent, the Python reference model, so the two can never drift apart.
return table.freeze({
	kDef = 200, -- damage x kDef / (kDef + DEF)
	variance = 0.08, -- +-8% damage roll
	baseCrit = 0.05,
	critMult = 1.5,
	energyMax = 5,
	energyStart = 1,
	energyOnAttack = 1,
	energyOnDefend = 1,
	initSlope = 2.5, -- chance to act first = 0.5 + slope x speed gap / speed sum ...
	initCap = 0.30, -- ... clamped to 20-80%
	guardVsAttack = 0.35, -- Defend softens a basic Attack by 35% (M3 tuning: was 25%, curbs "always Attack")
	guardVsSpecial = 0.80, -- and parries 80% of a damaging Special
	repeatDefend = 0.5, -- a second Defend in a row works at half strength
	riposte = 0.5, -- parry counter-hit multiplier
	maxRounds = 30,
	statPerLevel = 0.0075,
	pickSeconds = 12, -- per-round action timer
	nextSeconds = 5, -- replacement pick timer after a KO
	maxTimeouts = 3, -- missed picks before a forfeit
})
