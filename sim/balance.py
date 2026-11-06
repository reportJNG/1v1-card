"""Balance suite on the reference engine. Run: python3 sim/balance.py [--quick]
Prints the design-doc targets and writes sim/balance_report.json. Every new character must keep
these within target before it ships (the Python model is the balance gate)."""
import itertools, json, os, statistics, sys
from multiprocessing import Pool
import engine as E

IDS = [c["id"] for c in E.C["characters"]]
QUICK = "--quick" in sys.argv


def threat(m, i):
    o = m.sides[1 - i]
    return o.unit.special["kind"] == "Damage" and o.energy >= o.unit.special["cost"]


def make(p_def, q_sp):
    def pol(m, i, g):
        u = m.sides[i].unit
        th = threat(m, i)
        if th and u.last != "Defend" and g.next() < p_def:
            return "Defend"
        if "Special" in m.legal(i):
            k = u.special["kind"]
            if k == "Heal" and u.hp > u.max_hp * 0.6:
                return "Attack"
            if k == "Shield" and u.shield > 0:
                return "Attack"
            if k == "Stance" and not th:
                return "Attack"
            if g.next() < q_sp:
                return "Special"
        return "Attack"
    return pol


def make_reader():
    """Adapts: learns how often the opponent fires a ready Special and Defends under threat."""
    st = {"sp": [1, 2], "df": [1, 2], "prev": None}
    def pol(m, i, g):
        me, o = m.sides[i], m.sides[1 - i]
        u, t = me.unit, o.unit
        if st["prev"]:
            opp_ready, me_ready = st["prev"]
            if opp_ready:
                st["sp"][1] += 1; st["sp"][0] += t.last == "Special"
            if me_ready:
                st["df"][1] += 1; st["df"][0] += t.last == "Defend"
        q = st["sp"][0] / st["sp"][1]; p = st["df"][0] / st["df"][1]
        th = threat(m, i)
        ready = "Special" in m.legal(i)
        st["prev"] = (th, ready and u.special["kind"] == "Damage")
        if th and u.last != "Defend" and g.next() < min(0.9, q * 1.1):
            return "Defend"
        if ready:
            k = u.special["kind"]
            if k == "Heal": return "Special" if u.hp < u.max_hp * 0.6 else "Attack"
            if k == "Shield": return "Special" if u.shield == 0 else "Attack"
            if k == "Stance": return "Special" if th else "Attack"
            return "Attack" if g.next() < min(0.85, p) else "Special"
        return "Attack"
    return pol


def random_pol(m, i, g):
    acts = m.legal(i)
    return acts[int(g.next() * len(acts))]


STYLES = {
    "spam": lambda: make(0, 1.0), "turtle": lambda: make(1.0, 1.0), "balanced": lambda: make(0.5, 0.7),
    "reader70": lambda: make(0.7, 0.5), "aggro": lambda: make(0.25, 0.85),
    "attack-only": lambda: (lambda m, i, g: "Attack"), "random": lambda: random_pol,
    "adaptive": make_reader,
}


def run_match(deck_a, deck_b, pa, pb, seed):
    m = E.Match(deck_a, deck_b, seed)
    g = E.PRNG(seed * 7 + 3)
    while m.outcome() is None:
        a, b = pa(m, 0, g), pb(m, 1, g)
        m.resolve(a, b)
        for i in (0, 1):
            if m.needs_next(i):
                m.choose_next(i, m.default_next(i))
    return m.outcome(), m.round


def rand_deck(g, level):
    pool = list(IDS); out = []
    for _ in range(3):
        out.append((pool.pop(int(g.next() * len(pool))), level if isinstance(level, int) else level(g)))
    return out


def duel(job):
    sa, sb, n, seed, level_a, level_b, deck_a, deck_b = job
    g = E.PRNG(seed)
    wins = 0; rounds = []
    for k in range(n):
        da = deck_a or rand_deck(g, level_a)
        db = deck_b or rand_deck(g, level_b)
        pa, pb = STYLES[sa](), STYLES[sb]()
        if k % 2 == 0:
            r, rd = run_match(da, db, pa, pb, seed * 100003 + k); wins += r == 1
        else:
            r, rd = run_match(db, da, pb, pa, seed * 100003 + k); wins += r == 2
        rounds.append(rd)
    return wins / n, rounds


def per_character(job):
    n, seed, level = job
    g = E.PRNG(seed)
    w = {c: [0, 0] for c in IDS}
    for k in range(n):
        da, db = rand_deck(g, level), rand_deck(g, level)
        r, _ = run_match(da, db, STYLES["balanced"](), STYLES["balanced"](), seed * 100003 + k)
        win, lose = (da, db) if r == 1 else (db, da)
        for c, _ in win: w[c][0] += 1; w[c][1] += 1
        for c, _ in lose: w[c][1] += 1
    return w


if __name__ == "__main__":
    N = 400 if QUICK else 1500
    out = {}
    with Pool() as pool:
        names = list(STYLES)
        jobs = [(a, b, N, 1000 + i * 31 + j, 8, 8, None, None) for i, a in enumerate(names) for j, b in enumerate(names) if a != b]
        res = pool.map(duel, jobs)
        table = {}; rounds = []
        for (a, b, *_), (wr, rs) in zip(jobs, res):
            table.setdefault(a, {})[b] = wr; rounds += rs
        print("== play styles (row win rate vs column), level 8, random decks ==")
        for a in names:
            avg = statistics.mean(table[a].values())
            print(f"  {a:12s} avg {avg:5.1%}  " + " ".join(f"{b[:6]}={table[a][b]:.0%}" for b in names if b != a))
        out["styles"] = table
        sensible = [b for b in names if b not in ("random",)]
        out["random_vs_sensible"] = [table["random"][b] for b in sensible]
        out["attack_only_avg"] = statistics.mean(table["attack-only"].values())
        fixed = [b for b in names if b not in ("adaptive", "random")]
        out["adaptive_vs_fixed"] = [table["adaptive"][b] for b in fixed]
        rounds.sort()
        out["rounds_mean"] = statistics.mean(rounds); out["rounds_p90"] = rounds[int(len(rounds) * 0.9)]

        chunks = pool.map(per_character, [(N // 2, 77 + i, 8) for i in range(8)])
        tot = {c: [0, 0] for c in IDS}
        for w in chunks:
            for c in IDS: tot[c][0] += w[c][0]; tot[c][1] += w[c][1]
        out["characters"] = {c: tot[c][0] / tot[c][1] for c in IDS}

        lv = pool.map(duel, [("balanced", "balanced", N, 500 + d, 15, 15 - d, None, None) for d in (1, 2, 4, 7)])
        out["level_gap"] = {f"15v{15 - d}": r[0] for d, r in zip((1, 2, 4, 7), lv)}

    print(f"random vs sensible styles: {min(out['random_vs_sensible']):.0%}-{max(out['random_vs_sensible']):.0%} (target < 15%)")
    print(f"attack-only average: {out['attack_only_avg']:.0%} (target <= 60%)")
    print(f"adaptive vs fixed: {min(out['adaptive_vs_fixed']):.0%}-{max(out['adaptive_vs_fixed']):.0%}, avg {statistics.mean(out['adaptive_vs_fixed']):.0%} (target > 55%)")
    print(f"match length: mean {out['rounds_mean']:.1f}, p90 {out['rounds_p90']} (target 12-16)")
    cw = out["characters"]
    print(f"character win rates: {min(cw.values()):.1%}-{max(cw.values()):.1%} (target 45-55%)")
    for c in sorted(cw, key=cw.get):
        print(f"  {c:20s} {cw[c]:.1%}")
    print("level gap:", ", ".join(f"{k} {v:.0%}" for k, v in out["level_gap"].items()))
    json.dump(out, open(os.path.join(os.path.dirname(__file__), "balance_report.json"), "w"), indent=1)
