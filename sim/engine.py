"""1v1 CARD battle engine: reference model (Python).

This is the authority the Luau engine (src/shared/Battle/BattleRules.luau) is tested against:
`parity.py` plays seeded matches here and writes tests/Fixtures/BattleParity.luau, and the Luau
spec replays the same seeds and must produce identical results.

Both engines use the same PRNG (Park-Miller, exact in doubles) and round half up, so results
match bit for bit. Rules and characters come from content.json, exported from the Luau config:
  python3 scripts/headless/bundle.py --entry=ServerScriptService/Tests/Tools/ExportContent
  luau build/entry.luau > sim/content.json
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
C = json.load(open(os.path.join(HERE, "content.json")))  # exported from the Luau config
RULES = C["rules"]
CHARS = {c["id"]: c for c in C["characters"]}
ROLES = C["roles"]
RARITY_BUDGET = C["rarityBudget"]
FAMILY_STAT = C["familyStat"]
SYNERGY = {int(k): v for k, v in C["synergy"].items()}


class PRNG:
    M = 2147483647

    def __init__(self, seed):
        s = int(seed) % self.M
        if s <= 0:
            s += self.M - 1
        self.s = s

    def next(self):
        self.s = (self.s * 48271) % self.M
        return self.s / self.M

    def uniform(self, a, b):
        return a + (b - a) * self.next()

    def int(self, lo, hi):
        return lo + int(self.next() * (hi - lo + 1)) if hi > lo else lo


def rnd(x):
    """Round half up (x >= 0 in every use)."""
    import math
    return math.floor(x + 0.5)


class Unit:
    def __init__(self, cid, level, bonus, crit_bonus):
        d = CHARS[cid]
        self.cid, self.d = cid, d
        self.special, self.passive = d["special"], d["passive"]
        m = (1 + RARITY_BUDGET[d["rarity"]]) * (1 + RULES["statPerLevel"] * (level - 1))
        b = ROLES[d["role"]]
        self.max_hp = rnd(b["hp"] * m * (1 + bonus.get("hp", 0)))
        self.atk = b["atk"] * m * (1 + bonus.get("atk", 0))
        self.df = b["def"] * m * (1 + bonus.get("def", 0))
        self.spd = b["spd"] * m * (1 + bonus.get("spd", 0))
        self.crit = RULES["baseCrit"] + crit_bonus
        p = self.passive
        if p["kind"] == "CritBonus":
            self.crit += p["value"]
        self.hp = self.max_hp
        self.status = {}  # name -> rounds left (insertion ordered)
        self.shield = 0
        self.last = None

    @property
    def alive(self):
        return self.hp > 0

    def low(self):
        p = self.passive
        return p["kind"] == "LowHpStat" and self.hp < self.max_hp * p["threshold"]

    def eff_atk(self):
        a = self.atk
        if "Weaken" in self.status:
            a *= 1 - self.status_value["Weaken"]
        if self.low() and self.passive["stat"] == "atk":
            a *= 1 + self.passive["value"]
        return a

    def eff_def(self):
        d = self.df
        if self.low() and self.passive["stat"] == "def":
            d *= 1 + self.passive["value"]
        return d

    def eff_spd(self):
        s = self.spd
        if "Chill" in self.status:
            s *= 1 - self.status_value["Chill"]
        return s


class Side:
    def __init__(self, specs):
        fams = {}
        for s in specs:
            f = CHARS[s[0]]["family"]
            fams[f] = fams.get(f, 0) + 1
        self.units = []
        for cid, level in specs:
            f = CHARS[cid]["family"]
            stat, val = FAMILY_STAT[f], SYNERGY[min(fams[f], 3)]
            bonus, crit = {}, 0
            if stat == "crit":
                crit = val
            else:
                bonus[stat] = val
            u = Unit(cid, level, bonus, crit)
            u.status_value = {}
            self.units.append(u)
        self.active = 0
        self.energy = RULES["energyStart"]

    @property
    def unit(self):
        return self.units[self.active]

    def alive(self):
        return any(u.alive for u in self.units)

    def bench(self):
        return [i for i, u in enumerate(self.units) if u.alive and i != self.active]


class Match:
    def __init__(self, deck_a, deck_b, seed):
        self.sides = [Side(deck_a), Side(deck_b)]
        self.rng = PRNG(seed)
        self.round = 0
        self.events = []

    # --- helpers
    def ev(self, *parts):
        self.events.append(":".join(str(p) for p in parts))

    def legal(self, i):
        s = self.sides[i]
        acts = ["Attack", "Defend"]
        if s.energy >= s.unit.special["cost"]:
            acts.append("Special")
        return acts

    def est(self, src, dst):
        return src.eff_atk() * RULES["kDef"] / (RULES["kDef"] + dst.eff_def())

    def default_next(self, i):
        s, o = self.sides[i], self.sides[1 - i]
        best, bestv = None, None
        for idx in s.bench():
            u = s.units[idx]
            v = self.est(u, o.unit) - self.est(o.unit, u)
            if bestv is None or v > bestv:
                best, bestv = idx, v
        return best

    def needs_next(self, i):
        s = self.sides[i]
        return (not s.unit.alive) and s.alive()

    def choose_next(self, i, idx):
        s = self.sides[i]
        assert idx in s.bench()
        s.active = idx
        self.ev("Enter", i + 1, idx + 1)

    def outcome(self):
        a, b = self.sides[0].alive(), self.sides[1].alive()
        if a and not b:
            return 1
        if b and not a:
            return 2
        if self.round >= RULES["maxRounds"] or (not a and not b):
            fa = sum(u.hp / u.max_hp for u in self.sides[0].units)
            fb = sum(u.hp / u.max_hp for u in self.sides[1].units)
            return 1 if fa >= fb else 2
        return None

    # --- combat
    def deal(self, si, src, dst, mult, guard, special, pierce=0.0, pen=0.0):
        R = RULES
        dfv = dst.eff_def() * (1 - pen)
        dmg = src.eff_atk() * mult * (R["kDef"] / (R["kDef"] + dfv))
        dmg = dmg * (1 + self.rng.uniform(-R["variance"], R["variance"]))
        crit = self.rng.next() < src.crit
        if crit:
            dmg = dmg * R["critMult"]
        p = src.passive
        if p["kind"] == "BonusVsStatus" and p["status"] in dst.status:
            dmg = dmg * (1 + p["value"])
        if guard != 0:
            if guard < 0:
                red = -guard
            else:
                red = guard * (R["guardVsSpecial"] if special else R["guardVsAttack"])
            if pierce:
                red = red * (1 - pierce)
            dmg = dmg * (1 - red)
        dmg = rnd(dmg)
        if dst.shield > 0:
            absorbed = min(dst.shield, dmg)
            dst.shield -= absorbed
            dmg -= absorbed
            if absorbed:
                self.ev("Absorb", 2 - si, absorbed, dst.shield)
        dst.hp = max(0, dst.hp - dmg)
        self.ev("Hit", si + 1, dmg, 1 if crit else 0, dst.hp)
        return dmg

    def reflect(self, oi, si, dmg, frac, block):
        r = rnd(dmg / (1 - block) * frac) if dmg else 0
        a = self.sides[si].unit
        a.hp = max(0, a.hp - r)
        self.ev("Reflect", oi + 1, r, a.hp)

    def apply_status(self, unit, app):
        unit.status.pop(app["status"], None)
        unit.status[app["status"]] = app["rounds"]
        unit.status_value[app["status"]] = app["value"]

    def resolve(self, act_a, act_b):
        R = RULES
        self.round += 1
        S = self.sides
        acts = [act_a, act_b]
        for i in (0, 1):
            sp = S[i].unit.special
            if acts[i] == "Special" and S[i].energy < sp["cost"]:
                acts[i] = "Attack"
            if acts[i] == "Special":
                S[i].energy -= sp["cost"]
        guard = [0.0, 0.0]
        prio = [0, 0]
        for i in (0, 1):
            u = S[i].unit
            if acts[i] == "Defend":
                guard[i] = R["repeatDefend"] if u.last == "Defend" else 1.0
                prio[i] = 2
            elif acts[i] == "Special" and u.special["kind"] == "Stance":
                guard[i] = -u.special["blockFraction"]
                prio[i] = 2
            elif acts[i] == "Special" and u.special.get("priority"):
                prio[i] = 1
        if prio[0] != prio[1]:
            order = [0, 1] if prio[0] > prio[1] else [1, 0]
        else:
            sa, sb = S[0].unit.eff_spd(), S[1].unit.eff_spd()
            g = R["initSlope"] * (sa - sb) / (sa + sb)
            g = max(-R["initCap"], min(R["initCap"], g))
            order = [0, 1] if self.rng.next() < 0.5 + g else [1, 0]
        self.ev("Round", self.round, acts[0], acts[1], order[0] + 1, S[0].energy, S[1].energy)
        reflect = [None, None]
        first = order[0]
        for si in order:
            oi = 1 - si
            s, o = S[si], S[oi]
            u, t = s.unit, o.unit
            if not u.alive or not t.alive:
                continue
            a = acts[si]
            if a == "Defend":
                s.energy = min(R["energyMax"], s.energy + R["energyOnDefend"])
            elif a == "Attack":
                s.energy = min(R["energyMax"], s.energy + R["energyOnAttack"])
                dmg = self.deal(si, u, t, 1.0, guard[oi], False)
                if u.passive["kind"] == "Lifesteal":
                    u.hp = min(u.max_hp, u.hp + rnd(dmg * u.passive["value"]))
                    self.ev("Heal", si + 1, u.hp)
                if reflect[oi] is not None and dmg:
                    self.reflect(oi, si, dmg, reflect[oi][0], reflect[oi][1])
            else:
                sp = u.special
                k = sp["kind"]
                dmg = 0
                if k == "Damage":
                    dmg = self.deal(si, u, t, sp["multiplier"], guard[oi], True, sp.get("pierceGuard", 0.0), sp.get("armorPen", 0.0))
                    for app in sp.get("applies", []):
                        self.apply_status(t if app["target"] == "Opponent" else u, app)
                    if sp.get("recoilFraction"):
                        rec = rnd(u.max_hp * sp["recoilFraction"])
                        u.hp = max(1, u.hp - rec)
                        self.ev("Recoil", si + 1, rec, u.hp)
                elif k == "Shield":
                    u.shield = rnd(u.max_hp * sp["shieldFraction"])
                    for app in sp.get("applies", []):
                        self.apply_status(t if app["target"] == "Opponent" else u, app)
                    self.ev("Shield", si + 1, u.shield)
                elif k == "Heal":
                    heal = rnd(u.max_hp * sp["healFraction"])
                    u.hp = min(u.max_hp, u.hp + heal)
                    if sp.get("cleanse"):
                        u.status.clear()
                    self.ev("Heal", si + 1, u.hp)
                elif k == "Stance":
                    reflect[si] = (sp["reflectFraction"], sp["blockFraction"])
                    self.ev("Stance", si + 1)
                if k != "Stance" and reflect[oi] is not None and dmg:
                    self.reflect(oi, si, dmg, reflect[oi][0], reflect[oi][1])
                if k == "Damage" and acts[oi] == "Defend":
                    o.energy = min(R["energyMax"], o.energy + 1)
                    s.energy = max(0, s.energy - 1)
                    self.ev("Parry", oi + 1)
                    if t.alive and u.alive:
                        self.deal(oi, t, u, R["riposte"], 0.0, False)
            if u.passive["kind"] == "EnergyOnFirst" and si == first:
                s.energy = min(R["energyMax"], s.energy + u.passive["value"])
            if not t.alive:
                self.ev("KO", oi + 1)
        for i in (0, 1):
            u = S[i].unit
            if u.alive and "Burn" in u.status:
                b = rnd(u.max_hp * u.status_value["Burn"])
                u.hp = max(0, u.hp - b)
                self.ev("Burn", i + 1, b, u.hp)
                if not u.alive:
                    self.ev("KO", i + 1)
            for k in list(u.status):
                u.status[k] -= 1
                if u.status[k] <= 0:
                    del u.status[k]
            u.last = acts[i]
        self.ev("End", S[0].energy, S[1].energy, S[0].unit.hp, S[1].unit.hp)


# --- scripted pickers used by the parity test (separate PRNG stream)
def scripted_pick(m, i, prng):
    acts = m.legal(i)
    x = prng.next()
    if "Special" in acts and x < 0.45:
        return "Special"
    if x < 0.75:
        return "Attack"
    return "Defend"


def play(deck_a, deck_b, seed, picker=scripted_pick):
    m = Match(deck_a, deck_b, seed)
    pol = PRNG(seed + 7919)
    while m.outcome() is None:
        a, b = picker(m, 0, pol), picker(m, 1, pol)
        m.resolve(a, b)
        for i in (0, 1):
            if m.needs_next(i):
                m.choose_next(i, m.default_next(i))
    return m


def signature(m):
    h = 0
    for e in m.events:
        for ch in e.encode() + b"|":
            h = (h * 31 + ch) % 2147483647
    return h
