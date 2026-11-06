"""Guardian Trial difficulty on the reference engine: a player's random deck (cards at the
Guardian's level) playing the "balanced" style against each world's Guardian playing the adaptive
reader (the Trial AI). Run: python sim/trials.py"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import engine as E
import balance as B

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "src", "shared", "Config", "Guardians.luau"), encoding="utf-8").read()
GUARDIANS = {int(w): [(c, int(l)) for c, l in re.findall(r'characterId = "([a-z_]+)", level = (\d+)', body)]
             for w, body in re.findall(r"world = (\d+),.*?deck = \{(.*?)\n\t\t\},", src, re.S)}

if __name__ == "__main__":
    for w, deck in sorted(GUARDIANS.items()):
        level = deck[0][1]
        g = E.PRNG(40 + w)
        wins = 0; n = 600
        for k in range(n):
            mine = B.rand_deck(g, level)
            r, _ = B.run_match(mine, deck, B.STYLES["balanced"](), B.make_reader(), 7000 + w * 1000 + k)
            wins += r == 1
        print(f"world {w:2d} (level {level:2d}): player wins {wins / n:.0%}")
