"""The 100-character roster: the 7 launch characters (already in Config/Characters.luau, left
untouched) plus 93 new original characters defined here, and the egg pools.

  python sim/roster.py tune     # tunes each new character's power knob on the reference engine
  python sim/roster.py write    # writes the Luau config from roster_tuned.json

`tune` plays balanced-vs-balanced random decks at level 8 (the balance gate's setup) and nudges
each new character's single knob (Special multiplier, shield/heal size or reflect) until its win
rate sits near 50%. The official gate is still sim/balance.py on the regenerated content.json.
All names are original: no anime/game character names or likenesses.
"""
import json, math, os, re, sys
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONTENT = os.path.join(HERE, "content.json")
TUNED = os.path.join(HERE, "roster_tuned.json")

# (name, rarity, role, archetype, passive, special name, passive name)
NEW = [
    # Flame
    ("Kaida Cinderhart", "Common", "Striker", "burn", "vs", "Cinder Lash", "Kindled Heart"),
    ("Hoshi Blazewright", "Rare", "Skirmisher", "quick", "first", "Flash Fire", "Spark Start"),
    ("Pyrelle Ashveil", "Epic", "Bruiser", "heal", "steal", "Phoenix Ash", "Warm Embers"),
    ("Tomo Kilnfist", "Common", "Bruiser", "burst", "fury", "Kiln Breaker", "Stoked Rage"),
    ("Sorin Embervale", "Legendary", "Skirmisher", "burn", "crit", "Ember Storm", "White Heat"),
    ("Cyrus Coalbrand", "Mythical", "Skirmisher", "burst", "vs", "Coalfall", "Searing Brand"),
    # Ice
    ("Rinna Glacierborn", "Common", "Guardian", "shield", "stand", "Rime Wall", "Packed Snow"),
    ("Fennix Snowmantle", "Rare", "Striker", "chill", "vs", "Snowblind Strike", "Cold Snap"),
    ("Mika Rimeshard", "Common", "Skirmisher", "quick", "first", "Shard Dart", "Thin Ice"),
    ("Hale Frostmere", "Epic", "Guardian", "heal", "stand", "Thaw Spring", "Frozen Resolve"),
    ("Setsu Winterglass", "Legendary", "Trickster", "chill", "crit", "Glass Blizzard", "Frostbitten Edge"),
    ("Odran Icevein", "Mythical", "Support", "stance", "vs", "Permafrost", "Deep Freeze"),
    # Lightning
    ("Juno Sparkwhip", "Common", "Skirmisher", "quick", "crit", "Whip Crack", "Live Wire"),
    ("Kenji Thunderpeak", "Rare", "Striker", "strike", "first", "Peak Thunder", "Static Charge"),
    ("Volta Skyrend", "Epic", "Trickster", "pierce", "crit", "Skyrend Bolt", "Arc Focus"),
    ("Zeph Boltcaller", "Common", "Bruiser", "burst", "fury", "Ground Strike", "Overload"),
    ("Mira Stormglen", "Legendary", "Support", "shield", "first", "Storm Barrier", "Tailwind"),
    ("Tarik Arcflash", "Mythical", "Skirmisher", "quick", "first", "Arc Flash", "Lightning Reflex"),
    # Shadow
    ("Corvin Duskweaver", "Common", "Trickster", "weaken", "crit", "Dusk Snare", "Low Light"),
    ("Kagen Hollowmere", "Rare", "Skirmisher", "quick", "vs", "Hollow Step", "Prey on Weakness"),
    ("Selene Gloomfeather", "Epic", "Support", "weaken", "steal", "Gloom Plume", "Shadow Sip"),
    ("Raith Nightfall", "Rare", "Striker", "pierce", "fury", "Nightfall Cut", "Desperate Dark"),
    ("Umbra Veilstep", "Common", "Guardian", "stance", "stand", "Veil Guard", "Fading Form"),
    ("Isolde Murkwater", "Mythical", "Support", "weaken", "vs", "Murk Tide", "Drowning Doubt"),
    # Divine
    ("Seraphel Brightvow", "Common", "Guardian", "heal", "steal", "Bright Vow", "Mercy"),
    ("Lumi Haloheart", "Rare", "Guardian", "shield", "stand", "Halo Ward", "Steadfast Light"),
    ("Caelan Sunward", "Common", "Striker", "strike", "crit", "Sunward Blade", "Noon Glare"),
    ("Ophira Graceblade", "Epic", "Skirmisher", "quick", "first", "Grace Cut", "Swift Grace"),
    ("Elio Dawnspire", "Legendary", "Skirmisher", "burst", "fury", "Spire of Dawn", "Righteous Fury"),
    ("Benedia Lightwell", "Rare", "Guardian", "heal", "first", "Lightwell", "Blessed Start"),
    # Beast
    ("Grak Thornmaw", "Common", "Bruiser", "strike", "steal", "Thorn Bite", "Feast"),
    ("Lyra Wildpelt", "Rare", "Skirmisher", "quick", "first", "Pounce", "Hunter's Start"),
    ("Tusk Boulderhide", "Common", "Guardian", "stance", "stand", "Boulder Hide", "Hardened Hide"),
    ("Nessa Fangwood", "Epic", "Trickster", "pierce", "crit", "Fangwood Rend", "Keen Fang"),
    ("Bram Stagcrown", "Legendary", "Guardian", "shield", "stand", "Antler Ward", "Old Stag"),
    ("Tavi Howlstride", "Rare", "Trickster", "weaken", "vs", "Howl", "Pack Instinct"),
    # Dragon
    ("Drakon Emberwing", "Rare", "Striker", "burn", "vs", "Wing Blaze", "Scorched Scales"),
    ("Ryuna Scalebright", "Common", "Guardian", "shield", "stand", "Scale Bulwark", "Dragonhide"),
    ("Vharos Wyrmfang", "Epic", "Bruiser", "burst", "fury", "Wyrm Fang", "Hoard Rage"),
    ("Sythe Cragscale", "Common", "Skirmisher", "quick", "crit", "Crag Dive", "Talon Edge"),
    ("Aldra Skyserpent", "Legendary", "Skirmisher", "pierce", "first", "Serpent Gale", "Sky Hunter"),
    ("Korr Flamejaw", "Mythical", "Skirmisher", "burst", "steal", "Flamejaw Crush", "Devour"),
    # Warrior
    ("Hideo Ironvow", "Common", "Striker", "strike", "fury", "Iron Vow", "Never Yield"),
    ("Marza Steelheart", "Rare", "Bruiser", "burst", "stand", "Steel Heart", "Iron Will"),
    ("Takeo Shieldbreak", "Epic", "Trickster", "pierce", "fury", "Shieldbreaker", "Battle Rage"),
    ("Valdis Spearwind", "Rare", "Skirmisher", "quick", "first", "Spear Rush", "Vanguard"),
    ("Duran Oakblade", "Epic", "Guardian", "stance", "stand", "Oak Stand", "Rooted"),
    ("Asha Warbanner", "Legendary", "Support", "heal", "first", "Rally Banner", "War Drums"),
    ("Rook Hammerfall", "Common", "Bruiser", "burst", "fury", "Hammerfall", "Grit"),
    # Ninja
    ("Kaze Silentleaf", "Common", "Skirmisher", "quick", "crit", "Silent Leaf", "Hidden Blade"),
    ("Rena Mistcut", "Rare", "Trickster", "weaken", "crit", "Mist Cut", "Unseen"),
    ("Suzu Quickveil", "Common", "Skirmisher", "quick", "first", "Veil Dash", "First Move"),
    ("Hiko Windstep", "Epic", "Striker", "strike", "first", "Wind Step", "Light Feet"),
    ("Aya Needlefall", "Rare", "Trickster", "pierce", "crit", "Needle Rain", "Pressure Point"),
    ("Joro Smokeleap", "Legendary", "Skirmisher", "quick", "crit", "Smoke Leap", "Vanish"),
    ("Toru Paperblade", "Common", "Striker", "strike", "steal", "Paper Blade", "Thousand Cuts"),
    # Royal
    ("Regina Goldcrest", "Rare", "Guardian", "shield", "first", "Gilded Aegis", "Royal Decree"),
    ("Alaric Highmantle", "Common", "Guardian", "stance", "stand", "High Mantle", "Noble Guard"),
    ("Cassia Crownguard", "Epic", "Guardian", "shield", "stand", "Crownguard", "Loyal Shield"),
    ("Edric Velvetshield", "Common", "Guardian", "heal", "steal", "Velvet Balm", "Tithe"),
    ("Isadora Gildwing", "Legendary", "Striker", "strike", "crit", "Gildwing Strike", "Golden Edge"),
    ("Leopold Lionmark", "Mythical", "Skirmisher", "burst", "fury", "Lion's Mark", "Pride"),
    # Cosmic
    ("Astra Novaheart", "Rare", "Striker", "strike", "crit", "Nova Burst", "Star Spark"),
    ("Orin Starfall", "Common", "Skirmisher", "quick", "first", "Starfall", "Meteor Start"),
    ("Nyx Voidglimmer", "Epic", "Trickster", "weaken", "crit", "Void Glimmer", "Null Edge"),
    ("Celeste Moonrift", "Rare", "Bruiser", "heal", "first", "Moon Tide", "Lunar Pull"),
    ("Quill Cometrider", "Epic", "Trickster", "pierce", "crit", "Comet Pierce", "Tail Spark"),
    ("Lyss Nebulight", "Mythical", "Skirmisher", "pierce", "crit", "Nebula Lance", "Event Horizon"),
    ("Halcyon Starwake", "Legendary", "Guardian", "shield", "stand", "Starwake Shell", "Gravity Well"),
    # Ancient
    ("Thorne Runeward", "Common", "Guardian", "stance", "stand", "Rune Ward", "Stone Skin"),
    ("Petra Stonesong", "Rare", "Guardian", "shield", "stand", "Stone Song", "Bedrock"),
    ("Ozric Tombwarden", "Epic", "Bruiser", "burst", "fury", "Tomb Slam", "Undying Wrath"),
    ("Mada Relicborn", "Common", "Trickster", "weaken", "steal", "Relic Curse", "Old Hunger"),
    ("Gideon Ashpillar", "Legendary", "Skirmisher", "pierce", "fury", "Pillar Strike", "Last Bastion"),
    ("Sila Fossilkeep", "Rare", "Guardian", "stance", "stand", "Fossil Shell", "Petrify"),
    # Mystic
    ("Mirelle Hexwhisper", "Common", "Trickster", "weaken", "crit", "Hex Whisper", "Ill Omen"),
    ("Zarek Spellbind", "Rare", "Striker", "chill", "vs", "Spellbind", "Bound Prey"),
    ("Ilsa Charmweave", "Epic", "Guardian", "heal", "first", "Charm Weave", "Foresight"),
    ("Faelan Glyphstone", "Common", "Guardian", "shield", "stand", "Glyph Shield", "Warded"),
    ("Yara Moonhex", "Rare", "Trickster", "weaken", "vs", "Moon Hex", "Hex Hunter"),
    ("Quen Spiralsight", "Mythical", "Skirmisher", "quick", "first", "Spiral Sight", "Second Sight"),
    # Spirit
    ("Aoi Wisplight", "Common", "Bruiser", "heal", "steal", "Wisp Light", "Soul Sip"),
    ("Rowan Soulkeeper", "Rare", "Guardian", "shield", "stand", "Soul Ward", "Keeper's Oath"),
    ("Tamsin Ghostbloom", "Epic", "Trickster", "weaken", "crit", "Ghost Bloom", "Haunt"),
    ("Kiri Lanternwake", "Epic", "Skirmisher", "quick", "first", "Lantern Dash", "Guiding Light"),
    ("Shiro Spiritmoss", "Rare", "Guardian", "heal", "stand", "Spirit Moss", "Rooted Soul"),
    ("Eira Mistsong", "Legendary", "Support", "strike", "steal", "Mist Song", "Echo Drain"),
    # Demon
    ("Malric Hellbrand", "Common", "Bruiser", "burst", "steal", "Hellbrand", "Bloodlust"),
    ("Zuri Brimclaw", "Rare", "Skirmisher", "burn", "vs", "Brim Claw", "Hellfire Hunger"),
    ("Vesh Cinderhorn", "Epic", "Striker", "burn", "crit", "Cinder Horn", "Wicked Edge"),
    ("Draxa Bloodthorn", "Rare", "Trickster", "weaken", "steal", "Blood Thorn", "Leech"),
    ("Corran Ashenhorn", "Legendary", "Skirmisher", "burst", "fury", "Ashen Charge", "Infernal Fury"),
    ("Ruska Sinmaw", "Mythical", "Skirmisher", "burst", "crit", "Sin Maw", "Cruel Fortune"),
]

# Display names changed after a web name check (2026-11-06) because they were too close to existing
# characters (Corran Horn, Duran of Trials of Mana, Sorin Markov / the Embervale setting, Nessa of
# Pokemon). Ids stay the original slugs: ids are permanent and already saved in profiles.
DISPLAY_RENAME = {
    "corran_ashenhorn": "Brakus Ashenhorn",
    "duran_oakblade": "Halvard Oakblade",
    "sorin_embervale": "Cassius Emberreach",
    "nessa_fangwood": "Wrenna Fangwood",
}

FAMILIES = ["Flame"] * 6 + ["Ice"] * 6 + ["Lightning"] * 6 + ["Shadow"] * 6 + ["Divine"] * 6 + ["Beast"] * 6 \
    + ["Dragon"] * 6 + ["Warrior"] * 7 + ["Ninja"] * 7 + ["Royal"] * 6 + ["Cosmic"] * 7 + ["Ancient"] * 6 \
    + ["Mystic"] * 6 + ["Spirit"] * 6 + ["Demon"] * 6
assert len(FAMILIES) == len(NEW) == 93

# Starting knob per archetype (close to the launch characters that use the same mechanic).
KNOB0 = {"strike": 1.65, "burst": 2.09, "quick": 1.5, "burn": 1.65, "chill": 1.5, "weaken": 1.33,
         "pierce": 1.5, "shield": 0.25, "heal": 0.30, "stance": 0.80}
KNOB_RANGE = {"shield": (0.12, 0.50), "heal": (0.15, 0.50), "stance": (0.40, 1.20)}
DMG_RANGE = (1.15, 2.70)


# The launch characters' one tunable number each (their entries stay hand-written in the Luau file).
LAUNCH_KNOB = {"ren_emberfang": "multiplier", "yuki_frostveil": "shieldFraction", "rai_stormvolt": "multiplier",
               "vesper_shade": "multiplier", "aurelia_dawn": "healFraction", "brannok_ironhide": "reflectFraction",
               "taren_ashscale": "multiplier"}
LAUNCH_ARCHE = {"multiplier": "strike", "shieldFraction": "shield", "healFraction": "heal", "reflectFraction": "stance"}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def family_status(family, arche):
    if arche == "burn":
        return "Burn"
    if arche == "chill":
        return "Chill"
    if arche == "weaken":
        return "Weaken"
    return {"Flame": "Burn", "Ice": "Chill", "Dragon": "Burn", "Demon": "Burn"}.get(family, "Weaken")


def special_of(arche, name, knob):
    s = {"id": slug(name), "displayName": name}
    if arche == "strike":
        s.update(cost=3, kind="Damage", multiplier=knob)
    elif arche == "burst":
        s.update(cost=4, kind="Damage", multiplier=knob, armorPen=0.30, recoilFraction=0.10)
    elif arche == "quick":
        s.update(cost=2, kind="Damage", multiplier=knob, priority=True)
    elif arche == "burn":
        s.update(cost=3, kind="Damage", multiplier=knob,
                 applies=[{"status": "Burn", "target": "Opponent", "rounds": 2, "value": 0.06}])
    elif arche == "chill":
        s.update(cost=3, kind="Damage", multiplier=knob,
                 applies=[{"status": "Chill", "target": "Opponent", "rounds": 2, "value": 0.25}])
    elif arche == "weaken":
        s.update(cost=3, kind="Damage", multiplier=knob, pierceGuard=0.25,
                 applies=[{"status": "Weaken", "target": "Opponent", "rounds": 2, "value": 0.20}])
    elif arche == "pierce":
        s.update(cost=3, kind="Damage", multiplier=knob, pierceGuard=0.50)
    elif arche == "shield":
        s.update(cost=3, kind="Shield", shieldFraction=knob)
    elif arche == "heal":
        s.update(cost=3, kind="Heal", healFraction=knob, cleanse=True)
    elif arche == "stance":
        s.update(cost=2, kind="Stance", priority=True, blockFraction=0.50, reflectFraction=knob)
    return s


STATUS_ADJ = {"Burn": "Burning", "Chill": "Chilled", "Weaken": "Weakened"}


def passive_of(code, family, arche, name):
    p = {"id": slug(name), "displayName": name}
    if code == "vs":
        st = family_status(family, arche)
        p["effect"] = {"kind": "BonusVsStatus", "status": st, "value": 0.10}
        p["description"] = f"+10% damage to {STATUS_ADJ[st]} targets."
    elif code == "crit":
        p["effect"] = {"kind": "CritBonus", "value": 0.05}
        p["description"] = "+5% critical hit chance."
    elif code == "steal":
        p["effect"] = {"kind": "Lifesteal", "value": 0.10}
        p["description"] = "Attacks heal for 10% of the damage dealt."
    elif code == "fury":
        p["effect"] = {"kind": "LowHpStat", "stat": "atk", "threshold": 0.5, "value": 0.10}
        p["description"] = "+10% ATK below half HP."
    elif code == "stand":
        p["effect"] = {"kind": "LowHpStat", "stat": "def", "threshold": 0.5, "value": 0.30}
        p["description"] = "+30% DEF below half HP."
    elif code == "first":
        p["effect"] = {"kind": "EnergyOnFirst", "value": 1}
        p["description"] = "+1 Energy when acting first."
    return p


def build(knobs):
    out = []
    for (name, rarity, role, arche, pcode, sname, pname), family in zip(NEW, FAMILIES):
        cid = slug(name)
        out.append({
            "id": cid, "displayName": DISPLAY_RENAME.get(cid, name), "family": family, "rarity": rarity, "role": role,
            "special": special_of(arche, sname, knobs[cid]),
            "passive": passive_of(pcode, family, arche, pname),
            "arche": arche,
        })
    return out


def engine_char(c):
    """The content.json shape the Python engine reads."""
    return {"id": c["id"], "family": c["family"], "rarity": c["rarity"], "role": c["role"],
            "special": c["special"], "passive": c["passive"]["effect"]}


def clamp_knob(arche, v):
    lo, hi = KNOB_RANGE.get(arche, DMG_RANGE)
    return round(min(hi, max(lo, v)), 3)


def evaluate(matches_per_worker, workers=8, seed=0):
    import balance as B  # re-imported by each spawned worker, so it reads the current content.json
    with Pool(workers) as pool:
        chunks = pool.map(B.per_character, [(matches_per_worker, 9000 + seed * 101 + i, 8) for i in range(workers)])
    tot = {}
    for w in chunks:
        for c, (a, b) in w.items():
            t = tot.setdefault(c, [0, 0]); t[0] += a; t[1] += b
    return {c: a / b for c, (a, b) in tot.items()}


def tune(rounds=10):
    base = json.load(open(CONTENT))
    launch = [c for c in base["characters"] if c["id"] not in {slug(n[0]) for n in NEW}]
    assert len(launch) == 7, f"expected the 7 launch characters in content.json, got {len(launch)}"
    knobs = json.load(open(TUNED))["knobs"] if os.path.exists(TUNED) else {}
    for (name, _, _, arche, *_ ) in NEW:
        knobs.setdefault(slug(name), KNOB0[arche])
    arche_of = {slug(n[0]): n[3] for n in NEW}
    for c in launch:
        field = LAUNCH_KNOB[c["id"]]
        knobs.setdefault(c["id"], c["special"][field])
        arche_of[c["id"]] = LAUNCH_ARCHE[field]
    for r in range(rounds):
        chars = build(knobs)
        tuned_launch = []
        for c in launch:
            c2 = json.loads(json.dumps(c)); c2["special"][LAUNCH_KNOB[c["id"]]] = knobs[c["id"]]
            tuned_launch.append(c2)
        content = dict(base); content["characters"] = tuned_launch + [engine_char(c) for c in chars]
        json.dump(content, open(CONTENT, "w"), indent=1)
        wr = evaluate(9000, seed=r)
        new_ids = list(arche_of)
        off = [c for c in new_ids if abs(wr[c] - 0.5) > 0.025]
        spread = (min(wr.values()), max(wr.values()))
        print(f"round {r}: win rates {spread[0]:.1%}-{spread[1]:.1%}, {len(off)} new outside 47.5-52.5%", flush=True)
        if not off and all(0.465 <= v <= 0.535 for v in wr.values()):
            break
        for c in new_ids:
            err = 0.5 - wr[c]
            if abs(err) <= 0.012:
                continue
            arche = arche_of[c]
            gain = 1.6 if arche in ("shield", "heal", "stance") else 1.1
            knobs[c] = clamp_knob(arche, knobs[c] * (1 + max(-0.12, min(0.12, gain * err))))
        json.dump({"knobs": knobs, "winrates": wr}, open(TUNED, "w"), indent=1)
    json.dump({"knobs": knobs, "winrates": wr}, open(TUNED, "w"), indent=1)
    for c in sorted(wr, key=wr.get)[:5] + sorted(wr, key=wr.get)[-5:]:
        print(f"  {c:22s} {wr[c]:.1%}")


# ------------------------------------------------------------------- Luau output

def lua(v, indent):
    t = "\t" * indent
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(v, 4)) if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return json.dumps(v, ensure_ascii=False)
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x, indent) for x in v) + " }"
    order = ["status", "target", "rounds", "value", "kind", "stat", "threshold"]
    keys = sorted(v, key=lambda k: (order.index(k) if k in order else 99, k))
    return "{ " + ", ".join(f"{k} = {lua(v[k], indent)}" for k in keys) + " }"


def luau_entry(c):
    s, p = c["special"], c["passive"]
    lines = ["\t{", f'\t\tid = "{c["id"]}",', f'\t\tdisplayName = {lua(c["displayName"], 0)},',
             f'\t\tfamily = "{c["family"]}",', f'\t\trarity = "{c["rarity"]}",', f'\t\trole = "{c["role"]}",',
             "\t\tspecial = {"]
    for k in ["id", "displayName", "cost", "kind", "multiplier", "priority", "pierceGuard", "armorPen",
              "healFraction", "shieldFraction", "blockFraction", "reflectFraction", "recoilFraction", "cleanse", "applies"]:
        if k in s:
            lines.append(f"\t\t\t{k} = {lua(s[k], 3)},")
    lines += ["\t\t},", "\t\tpassive = {", f'\t\t\tid = "{p["id"]}",', f'\t\t\tdisplayName = {lua(p["displayName"], 0)},',
              f'\t\t\tdescription = {lua(p["description"], 0)},', f'\t\t\teffect = {lua(p["effect"], 3)},', "\t\t},",
              "\t\tenabled = true,", "\t\tassets = {},", "\t},"]
    return "\n".join(lines)


MARK_BEGIN = "\t-- BEGIN generated roster (sim/roster.py write). Edit the numbers in sim/roster_tuned.json.\n"
MARK_END = "\t-- END generated roster\n"


def write_characters(chars):
    path = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")
    src = open(path, encoding="utf-8").read()
    block = MARK_BEGIN + "\n".join(luau_entry(c) for c in chars) + "\n" + MARK_END
    if MARK_BEGIN in src:
        a = src.index(MARK_BEGIN); b = src.index(MARK_END) + len(MARK_END)
        src = src[:a] + block + src[b:]
    else:
        end = src.index("}\n\nlocal ById")
        src = src[:end] + block + src[end:]
    open(path, "w", encoding="utf-8").write(src)


# ------------------------------------------------------------------- egg pools

EGG_THEMES = {  # egg -> (band, preferred families, in order)
    "egg_basic": ("A", ["Warrior", "Beast", "Flame", "Lightning"]),
    "egg_spotted": ("A", ["Beast", "Spirit", "Divine"]),
    "egg_cracked": ("A", ["Ancient", "Warrior", "Shadow"]),
    "egg_cat": ("A", ["Ninja", "Shadow", "Lightning"]),
    "egg_dog": ("A", ["Beast", "Warrior", "Royal"]),
    "egg_rainbow": ("A", ["Spirit", "Mystic", "Divine"]),
    "egg_sandcastle": ("B", ["Ancient", "Royal", "Warrior"]),
    "egg_coconut": ("B", ["Beast", "Lightning", "Spirit"]),
    "egg_royal": ("B", ["Royal", "Warrior", "Divine"]),
    "egg_ice": ("B", ["Ice", "Mystic"]),
    "egg_yeti": ("B", ["Ice", "Beast", "Ancient"]),
    "egg_mine": ("C", ["Ancient", "Flame", "Warrior"]),
    "egg_dragon": ("C", ["Dragon", "Flame"]),
    "egg_demon": ("C", ["Demon", "Shadow", "Flame"]),
    "egg_angel": ("D", ["Divine", "Spirit", "Royal"]),
    "egg_kraken": ("D", ["Mystic", "Ice", "Lightning"]),
    "egg_dominus": ("D", ["Royal", "Divine", "Cosmic"]),
    "egg_legendary": ("D", ["Warrior", "Dragon", "Cosmic", "Ninja"]),
    "egg_glitched": ("E", ["Cosmic", "Mystic", "Lightning"]),
    "egg_black_hole": ("E", ["Cosmic", "Shadow", "Demon"]),
    "egg_secret": ("E", ["Shadow", "Ninja", "Mystic"]),
    "egg_angel_demon": ("E", ["Divine", "Demon", "Spirit"]),
    "egg_mythical": ("E", ["Dragon", "Cosmic", "Divine", "Demon"]),
    "egg_party": ("Event", ["Spirit", "Beast", "Lightning", "Mystic"]),
}
SLOTS = {"A": {"Common": 3, "Rare": 2, "Epic": 2, "Legendary": 1},
         "B": {"Common": 3, "Rare": 2, "Epic": 1, "Legendary": 1, "Mythical": 1},
         "C": {"Common": 2, "Rare": 2, "Epic": 2, "Legendary": 1, "Mythical": 1},
         "D": {"Common": 2, "Rare": 2, "Epic": 2, "Legendary": 2, "Mythical": 1},
         "E": {"Common": 1, "Rare": 2, "Epic": 3, "Legendary": 2, "Mythical": 2},
         "Event": {"Common": 2, "Rare": 2, "Epic": 2, "Legendary": 1, "Mythical": 1}}
RARITIES = ["Common", "Rare", "Epic", "Legendary", "Mythical"]


def design_pools(all_chars):
    """Themed pools: each egg prefers its families, and every character lands in at least one egg."""
    used = {c["id"]: 0 for c in all_chars}
    pools = {}
    for egg, (band, fams) in EGG_THEMES.items():
        pool = {}
        for rarity, n in SLOTS[band].items():
            cands = [c for c in all_chars if c["rarity"] == rarity]
            def score(c):
                fam = fams.index(c["family"]) if c["family"] in fams else len(fams) + 1
                return (used[c["id"]] > 0, fam, used[c["id"]], c["id"])
            pick = sorted(cands, key=score)[:n]
            for c in pick:
                used[c["id"]] += 1
            pool[rarity] = sorted(c["id"] for c in pick)
        pools[egg] = pool
    missing = [cid for cid, n in used.items() if n == 0]
    # Swap any character still missing into the egg whose theme fits it best, replacing a
    # same-rarity character that appears elsewhere too.
    by_id = {c["id"]: c for c in all_chars}
    for cid in missing:
        c = by_id[cid]
        best = None
        for egg, (band, fams) in EGG_THEMES.items():
            ids = pools[egg].get(c["rarity"], [])
            dup = [x for x in ids if used[x] > 1]
            if not dup:
                continue
            fit = fams.index(c["family"]) if c["family"] in fams else 99
            if best is None or fit < best[0]:
                best = (fit, egg, dup[0])
        if best:
            _, egg, out = best
            ids = pools[egg][c["rarity"]]
            ids[ids.index(out)] = cid
            ids.sort()
            used[out] -= 1; used[cid] += 1
    return pools, [cid for cid, n in used.items() if n == 0]


def write_pools(pools):
    path = os.path.join(ROOT, "src", "shared", "Config", "EggPools.luau")
    lines = ["--!strict", "-- Generated by sim/roster.py write. Character pools per egg: each egg has a theme (its",
             "-- families first) and 6-10 characters across the rarities its odds band can drop. Every",
             "-- character is in at least one egg. Odds inside a rarity are equal (Shared/Domain/Odds).",
             "", "return table.freeze({"]
    for egg, pool in pools.items():
        lines.append(f"\t{egg} = table.freeze({{")
        for rarity in RARITIES:
            if rarity in pool:
                ids = ", ".join(f'"{i}"' for i in pool[rarity])
                lines.append(f"\t\t{rarity} = table.freeze({{ {ids} }}),")
        lines.append("\t}),")
    lines.append("}) :: { [string]: { [string]: { string } } }")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")


def write_launch_knobs(knobs):
    path = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")
    src = open(path, encoding="utf-8").read()
    for cid, field in LAUNCH_KNOB.items():
        a = src.index(f'id = "{cid}"'); b = src.index("enabled = true", a)
        block = src[a:b]
        new = re.sub(field + r" = [0-9.]+,[^\n]*",
                     f"{field} = {round(knobs[cid], 3)}, -- tuned for the 100-character roster (sim/roster.py)",
                     block, count=1)
        assert new != block or f"{field} = {round(knobs[cid], 3)}," in block, cid
        src = src[:a] + new + src[b:]
    open(path, "w", encoding="utf-8").write(src)


def write():
    knobs = json.load(open(TUNED))["knobs"]
    chars = build(knobs)
    write_characters(chars)
    write_launch_knobs(knobs)
    base = json.load(open(CONTENT))
    launch_ids = [c["id"] for c in base["characters"]][:7]
    everyone = [{"id": c["id"], "family": c["family"], "rarity": c["rarity"]} for c in base["characters"]
                if c["id"] in launch_ids] + [{"id": c["id"], "family": c["family"], "rarity": c["rarity"]} for c in chars]
    pools, missing = design_pools(everyone)
    write_pools(pools)
    sizes = [sum(len(v) for v in p.values()) for p in pools.values()]
    print(f"wrote {len(chars)} characters and {len(pools)} pools (sizes {min(sizes)}-{max(sizes)}); uncovered: {missing}")


# ------------------------------------------------------------------- art briefs

FAMILY_COLORS = {  # mirrors Config/Art.FamilyColors (body, accent)
    "Flame": ("#C2412D", "#FFB347"), "Ice": ("#7FB8E0", "#E8F6FF"), "Lightning": ("#3A55C8", "#FFE14D"),
    "Shadow": ("#2B2540", "#9B7BFF"), "Divine": ("#F1E6C8", "#FFD45C"), "Beast": ("#8A5A3B", "#D9B48A"),
    "Dragon": ("#2F7A4D", "#FF6A2B"), "Warrior": ("#7B8794", "#D2462E"), "Ninja": ("#22303F", "#4FD1C5"),
    "Royal": ("#5B2A86", "#FFC54B"), "Cosmic": ("#1C1F4A", "#FF7BE5"), "Ancient": ("#9C8B6E", "#5FD3A0"),
    "Mystic": ("#3E2A6B", "#B98CFF"), "Spirit": ("#A9D8D0", "#FFFFFF"), "Demon": ("#4A1022", "#FF3B3B"),
}

NAMED_COLORS = {
    "crimson red": "#C2412D", "ember orange": "#FFB347", "ice blue": "#7FB8E0", "frost white": "#E8F6FF",
    "royal blue": "#3A55C8", "electric yellow": "#FFE14D", "dark plum": "#2B2540", "lavender": "#9B7BFF",
    "cream": "#F1E6C8", "warm gold": "#FFD45C", "chestnut brown": "#8A5A3B", "tan": "#D9B48A",
    "jade green": "#2F7A4D", "flame orange": "#FF6A2B", "steel grey": "#7B8794", "scarlet": "#D2462E",
    "midnight navy": "#22303F", "teal": "#4FD1C5", "royal purple": "#5B2A86", "gold": "#FFC54B",
    "deep indigo": "#1C1F4A", "neon pink": "#FF7BE5", "sandstone": "#9C8B6E", "mint green": "#5FD3A0",
    "violet": "#3E2A6B", "soft lilac": "#B98CFF", "pale seafoam": "#A9D8D0", "white": "#FFFFFF",
    "blood maroon": "#4A1022", "bright red": "#FF3B3B", "charcoal": "#2B2B33", "slate blue": "#4A6FA5",
    "silver white": "#F2F5FF", "pale lilac grey": "#C9C2D9", "peach": "#FF9F6B", "gunmetal": "#5E6A73",
    "ash grey": "#B5B0A8", "dark brown": "#3A2A24", "grey": "#6B7280", "pale parchment": "#F4E3C1",
    "deep blue": "#2D3A6B", "pale sky blue": "#BFE6FF", "rose pink": "#FF5E7E", "straw beige": "#D9C08A",
    "sky blue": "#45BEFF", "rose": "#FF668F", "dusty violet": "#6B5B95", "pale violet": "#DCD6F7",
    "cool grey": "#A3A3B5", "amethyst": "#6E4BC4", "sea teal": "#3FA7A0", "periwinkle": "#9EAED3",
    "blossom pink": "#FF9AD5", "emerald": "#48DA97", "moss green": "#5E8A3A", "amber": "#C98A1C",
    "pale gold": "#FFF1B8", "light gold": "#FFE27A", "orange": "#FF8A3D", "lantern amber": "#FFB45A",
    "purple": "#A469FF", "navy": "#2A3760", "pale silver": "#C0C7D6", "khaki": "#E8C98A",
    "near-black violet": "#1E1A2B", "leaf green": "#9AD06B", "orchid pink": "#E85D9C", "rust red": "#C84B31",
    "sage": "#8FB3A3",
}


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def color_name(hexv):
    """The nearest named colour, so prompts say 'teal (#4FD1C5)' rather than a bare hex code."""
    r = _rgb(hexv)
    return min(NAMED_COLORS, key=lambda n: sum((a - b) ** 2 for a, b in zip(_rgb(NAMED_COLORS[n]), r)))


# Card art (the layered card's character layer, App/Card): a transparent cutout.
CARD_TEMPLATE = ("Roblox R15 avatar proportions (blocky body, slightly bigger head), drawn in a clean anime "
                 "cel-shaded style, thick dark outline, vibrant colours, soft rim light, one character only, upper "
                 "body to knees, 3/4 view, plain flat light-grey background, fully clothed battle outfit, "
                 "confident closed-mouth expression, original character design, no text, no logo, no watermark")
# The shared style from NEW_5_CHARACTERS.md (the owner's template, 2026-11-09); the background is
# removed by scripts/art/characters.py after review.
# Model reference (the 3D pipeline: image-to-3D, cleanup, cel-shading, R15 rig).
PROMPT_TEMPLATE = ("full body, front view, A-pose, plain light-grey background, single character, anime cel-shaded "
                   "game character, consistent proportions (6 heads tall, slightly large head, chunky hands and feet), "
                   "crisp dark outlines, flat two-tone shading, no text, no logo, original design")


def all_characters():
    """[(id, displayName, family, rarity, role)] for all 100, in config order."""
    base = json.load(open(CONTENT))
    src = open(os.path.join(ROOT, "src", "shared", "Config", "Characters.luau"), encoding="utf-8").read()
    names = {m.group(1): m.group(2) for m in re.finditer(r'\tid = "([a-z0-9_]+)",\n\t\tdisplayName = "([^"]+)"', src)}
    return [(c["id"], names[c["id"]], c["family"], c["rarity"], c["role"]) for c in base["characters"]]


def write_looks():
    """Writes each character's `look` into Config/Characters.luau and art/characters/PROMPTS.md."""
    from roster_looks import LOOKS
    chars = all_characters()
    assert {c[0] for c in chars} == set(LOOKS), "LOOKS must cover exactly the roster"
    path = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")
    src = open(path, encoding="utf-8").read()
    for cid, _name, family, _rarity, _role in chars:
        personality, outfit, personal, weapon, silhouette = LOOKS[cid]
        body, accent = FAMILY_COLORS[family]
        block = ("\t\tlook = {\n"
                 f"\t\t\tpersonality = {lua(personality, 0)},\n"
                 f"\t\t\toutfit = {lua(outfit, 0)},\n"
                 f'\t\t\tcolors = {{ "{body}", "{accent}", "{personal}" }},\n'
                 f"\t\t\tweapon = {lua(weapon, 0)},\n"
                 f"\t\t\tsilhouette = {lua(silhouette, 0)},\n"
                 "\t\t},\n")
        a = src.index(f'\tid = "{cid}",')
        b = src.index("\t\tenabled = true,", a)
        entry = re.sub(r"\t\tlook = \{\n(?:\t\t\t[^\n]*\n)*?\t\t\},\n", "", src[a:b])
        src = src[:a] + entry + block + src[b:]
    open(path, "w", encoding="utf-8").write(src)
    write_prompts(chars)


def write_prompts(chars=None):
    """art/characters/PROMPTS.md: the card-art prompt and the model reference prompt per character."""
    from roster_looks import LOOKS
    chars = chars or all_characters()
    lines = ["# Character image prompts", "",
             "One prompt per character, all from the same template, so the roster shares one camera, pose and",
             "style (docs/ART_STYLE.md section 5). Generated by `python sim/roster.py prompts` from",
             "`sim/roster_looks.py`: edit the brief there, not here.", "",
             "Never use images or names of existing anime, game or franchise characters (no character datasets).",
             "Every character here is original.", "",
             "## Two images per character", "",
             "1. **Card art** (needed first): `art/characters/<id>/card.png`, a **transparent PNG**, 768 px wide by",
             "   1024 px tall, the character alone (no background, no frame). It becomes the character layer of the",
             "   layered card (`App/Card`): the family background, glow, effects and frame are separate layers drawn",
             "   by the game, so the character must have no background of its own.",
             "2. **Model reference** (for 3D, later): `art/characters/<id>/front.png`, about 1024 px tall, on the",
             "   plain light-grey background. It feeds the Blender pipeline (image-to-3D, cleanup, cel-shading, R15 rig).",
             "",
             "**Card art template:**", "", f"> {CARD_TEMPLATE}, <character description>", "",
             "**Model reference template:**", "", f"> {PROMPT_TEMPLATE}, <character description>", "",
             "The description gives the outfit, the three colours (family body, family accent, personal), the",
             "weapon and the silhouette note. Rarity is never in the prompt: it only changes the card frame.",
             "Until a character's card art exists, its card shows a TEMP role silhouette tinted with its colours.", ""]
    fam = None
    order = list(FAMILY_COLORS)
    for cid, name, family, rarity, role in sorted(chars, key=lambda c: (order.index(c[2]), c[1])):
        if family != fam:
            fam = family
            lines += [f"## {family}", ""]
        personality, outfit, personal, weapon, silhouette = LOOKS[cid]
        body, accent = FAMILY_COLORS[family]
        cols = (f"colour scheme {color_name(body)} ({body}), {color_name(accent)} ({accent}) "
                f"and {color_name(personal)} ({personal})")
        desc = (f"{outfit}; {cols}; holding {weapon}; signature silhouette: {silhouette}; "
                f"expression and pose suggest: {personality[0].lower() + personality[1:]}")
        lines += [f"### {name} (`{cid}`)", "", f"{family} · {rarity} · {role}", "",
                  f"Card art → `art/characters/{cid}/card.png`", "", f"> {CARD_TEMPLATE}, {desc}.", "",
                  f"Model reference → `art/characters/{cid}/front.png`", "", f"> {PROMPT_TEMPLATE}, {desc}.", ""]
    os.makedirs(os.path.join(ROOT, "art", "characters"), exist_ok=True)
    with open(os.path.join(ROOT, "art", "characters", "PROMPTS.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote art/characters/PROMPTS.md for {len(chars)} characters")


if __name__ == "__main__":
    sys.path.insert(0, HERE)
    cmd = sys.argv[1] if len(sys.argv) > 1 else "tune"
    if cmd == "tune":
        tune(int(sys.argv[2]) if len(sys.argv) > 2 else 10)
    elif cmd == "write":
        write()
        write_looks()
    elif cmd == "looks":
        write_looks()
    elif cmd == "prompts":
        write_prompts()
