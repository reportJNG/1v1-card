"""The layered card's TEMPORARY images (docs/ART_STYLE.md section 4, App/Card.luau), registered into
make_temp_ui.py's SPECS so they get the same PROMPTS.md entries, TEMP pngs and UiAssets slots:

  card_border         one frame for every rarity, drawn in greys; App/Card tints and animates it
  card_glow               soft outer glow behind the card (tinted, pulsed for Legendary / level 15)
  card_holo               holo-foil band pattern (Mythical), coloured by a moving rainbow gradient
  card_bg_<family>        15 family backgrounds (the card's back layer)
  cutout_<role>_<layer>   TEMP character cutouts: 6 role silhouettes x 4 layers (line, skin, outfit,
                          accent), tinted per character from its look colours, until the owner's
                          transparent character art exists
  family_<family>         15 family glyphs (white, tinted in code)
  badge_level, badge_crown  the level badge and the level-15 crown

Pure code, no third-party art. Greys and whites are tinted at runtime, so one image serves many
cards.
"""
import math
import random

from png import cover, hex_rgb, mix, ramp, sd_circle, sd_polygon, sd_round_rect, sd_segment, smooth

H = hex_rgb
WHITE = (1, 1, 1)
NIGHT = H("#05070F")

FAMILIES = {
    "Flame": ("#C2412D", "#FFB347", "flames"),
    "Ice": ("#7FB8E0", "#E8F6FF", "shards"),
    "Lightning": ("#3A55C8", "#FFE14D", "bolts"),
    "Shadow": ("#2B2540", "#9B7BFF", "wisps"),
    "Divine": ("#F1E6C8", "#FFD45C", "rays"),
    "Beast": ("#8A5A3B", "#D9B48A", "slashes"),
    "Dragon": ("#2F7A4D", "#FF6A2B", "scales"),
    "Warrior": ("#7B8794", "#D2462E", "steel"),
    "Ninja": ("#22303F", "#4FD1C5", "leaves"),
    "Royal": ("#5B2A86", "#FFC54B", "lattice"),
    "Cosmic": ("#1C1F4A", "#FF7BE5", "stars"),
    "Ancient": ("#9C8B6E", "#5FD3A0", "runes"),
    "Mystic": ("#3E2A6B", "#B98CFF", "glyphs"),
    "Spirit": ("#A9D8D0", "#FFFFFF", "orbs"),
    "Demon": ("#4A1022", "#FF3B3B", "cracks"),
}
ROLES = ["Striker", "Guardian", "Skirmisher", "Trickster", "Support", "Bruiser"]
LAYERS = ["line", "skin", "outfit", "accent"]

ROLE_LOOK = {
    "Striker": "raising a big sword overhead in one hand",
    "Guardian": "braced behind a large shield",
    "Skirmisher": "in a low lean with a dagger in each hand and a trailing scarf",
    "Trickster": "fanning three cards in one hand, cape flaring",
    "Support": "holding a tall staff topped with a glowing orb, long robe",
    "Bruiser": "with broad shoulders and huge gauntlet fists raised",
}

MOTIF_TEXT = {
    "flames": "rising flame tongues and embers",
    "shards": "frost crystal shards and snow motes",
    "bolts": "zig-zag lightning bolts and sparks",
    "wisps": "curling ink-smoke wisps",
    "rays": "soft light rays from above and floating feathers",
    "slashes": "claw slash marks and drifting leaves",
    "scales": "a dragon-scale pattern and sparks",
    "steel": "crossed steel streaks and sparks",
    "leaves": "spinning leaves and shuriken silhouettes",
    "lattice": "a gold diamond lattice and glints",
    "stars": "a starfield and nebula swirl",
    "runes": "stone rune circles with a jade glow",
    "glyphs": "a glowing glyph circle and motes",
    "orbs": "floating lantern-light orbs",
    "cracks": "glowing red cracks and hellfire embers",
}

CARD_R = 34


def register(spec):
    grp = "Card layers"
    spec("card_border", (512, 716), None, 0, "The card frame for every rarity, in greys (tinted per rarity in code)",
         "a trading card frame for an anime card game, portrait 5:7, drawn entirely in white and light-to-mid grey "
         "metal (no colour, it is tinted in code): a bevelled outer border, a thin inner border, a ribbon-shaped "
         "banner socket centred on the top edge, round sockets in the top-left and top-right corners, a dark name "
         "plate across the bottom 22% with a thin divider above a stat strip, small gems at the four corners; the "
         "window inside is completely transparent", grp)
    spec("card_glow", (320, 420), None, 0, "Soft outer glow behind a card (tinted, pulsed in code)",
         "a soft white glow in the shape of a rounded portrait card outline, feathered outward, transparent "
         "centre and edges", grp)
    spec("card_holo", (512, 716), None, 0, "Holo-foil band pattern over Mythical cards (coloured by a moving gradient)",
         "a transparent overlay of thin diagonal white holographic foil bands and fine sparkle noise, mostly "
         "transparent, for a trading card", grp)
    spec("badge_level", (96, 96), None, 0, "Level badge (top-left of a card, tinted, number drawn in code)",
         "a round faceted metal medal badge in white and grey (tinted in code), bevelled rim, blank centre", grp)
    spec("badge_crown", (96, 72), None, 0, "Crown over the level badge at level 15",
         "a small shiny gold crown with three points and gems, isolated", grp)
    for fam, (body, accent, motif) in FAMILIES.items():
        spec(f"card_bg_{fam.lower()}", (320, 448), None, 0, f"{fam} family card background (behind the character)",
             f"an anime trading card background, portrait 5:7, no character: a deep gradient from {body} to near-black "
             f"navy with {MOTIF_TEXT[motif]} in {accent}, soft glow behind the centre where the character stands, "
             "painterly but clean", "Card backgrounds")
    for fam in FAMILIES:
        spec(f"family_{fam.lower()}", (64, 64), None, 0, f"{fam} family glyph (white, tinted in code)",
             f"a simple bold white icon glyph for the {fam} family of an anime card game, flat, isolated", "Card backgrounds")
    for role in ROLES:
        for layer in LAYERS:
            spec(f"cutout_{role.lower()}_{layer}", (384, 512), None, 0,
                 f"TEMP {role} character cutout, {layer} layer (replaced by the character's own art)",
                 f"TEMPORARY stand-in only: the {layer} layer of a flat anime-style {role} silhouette {ROLE_LOOK[role]}, "
                 "upper body to knees, greyscale so it can be tinted", "Card cutouts (TEMP)")


def owns(slot):
    return (slot in ("card_border", "card_glow", "card_holo", "badge_level", "badge_crown")
            or slot.startswith("card_bg_") or slot.startswith("family_") or slot.startswith("cutout_"))


# --------------------------------------------------------------------------------------- frame


def grey(v):
    return (v, v, v)


def draw_frame(c, w, h):
    cx, cy, hw, hh = w / 2, h / 2, w / 2 - 6, h / 2 - 6
    th = 18

    def bevel(x, y):
        d = sd_round_rect(x, y, cx, cy, hw, hh, CARD_R)
        inner = -(d)  # 0 at the outer edge, th at the inner edge
        t = max(0.0, min(1.0, inner / th))
        light = 0.5 + 0.5 * (-(x - cx) / w - (y - cy) / h)  # brighter toward the top-left
        ridge = 1 - abs(t - 0.45) * 1.4
        return grey(max(0.45, min(1.0, 0.62 + 0.25 * ridge + 0.22 * (light - 0.5))))

    # Dark name plate and stat strip inside the window (so the tint stays subtle there).
    def plate(x, y):
        a = cover(sd_round_rect(x, y, cx, cy, hw - th, hh - th, CARD_R - 8)) * smooth(h * 0.70, h * 0.775, y)
        if a <= 0:
            return None
        return grey(0.12), a * 0.94
    c.shade(plate, (0, h * 0.68, w, h))
    # divider between the name and the stat strip
    c.shade(lambda x, y: (grey(0.75), cover(abs(y - h * 0.872) - 1.2) * smooth(cx - hw + th + 30, cx - hw + th + 60, x)
                          * smooth(cx + hw - th - 30, cx + hw - th - 60, x)), (0, h * 0.86, w, h * 0.885))

    def ring(x, y):
        d = sd_round_rect(x, y, cx, cy, hw, hh, CARD_R)
        a = cover(abs(d + th / 2) - th / 2)
        if a <= 0:
            return None
        return bevel(x, y), a
    c.shade(ring)
    # thin inner border and highlight
    c.shade(lambda x, y: (grey(0.95), 0.9 * cover(abs(sd_round_rect(x, y, cx, cy, hw - th - 5, hh - th - 5, CARD_R - 12)) - 1.3)))
    c.shade(lambda x, y: (WHITE, 0.5 * cover(abs(sd_round_rect(x, y, cx, cy, hw - 2, hh - 2, CARD_R - 2)) - 0.9)))
    # top banner socket (a ribbon across the top edge)
    bw, by0, by1 = 168, 2, 66
    pts = [(cx - bw, by0 + 8), (cx + bw, by0 + 8), (cx + bw - 22, (by0 + by1) / 2 + 4), (cx + bw, by1),
           (cx - bw, by1), (cx - bw + 22, (by0 + by1) / 2 + 4)]
    c.shade(lambda x, y: (grey(0.3), cover(sd_polygon(x, y, pts))), (cx - bw - 4, 0, cx + bw + 4, by1 + 4))
    c.shade(lambda x, y: (grey(0.9), cover(abs(sd_polygon(x, y, pts)) - 2.2)), (cx - bw - 6, 0, cx + bw + 6, by1 + 6))
    # corner sockets: level (top-left) and family (top-right)
    for sx in (cx - hw + th + 34, cx + hw - th - 34):
        sy = cy - hh + th + 58
        c.shade(lambda x, y, sx=sx, sy=sy: (grey(0.2), 0.9 * cover(sd_circle(x, y, sx, sy, 36))), (sx - 40, sy - 40, sx + 40, sy + 40))
        c.shade(lambda x, y, sx=sx, sy=sy: (grey(0.92), cover(abs(sd_circle(x, y, sx, sy, 36)) - 2.6)), (sx - 42, sy - 42, sx + 42, sy + 42))
    # corner gems
    for (gx, gy) in [(cx - hw + th / 2, cy - hh + th / 2 + 4), (cx + hw - th / 2, cy - hh + th / 2 + 4),
                     (cx - hw + th / 2, cy + hh - th / 2 - 4), (cx + hw - th / 2, cy + hh - th / 2 - 4)]:
        pts2 = [(gx, gy - 15), (gx + 11, gy), (gx, gy + 15), (gx - 11, gy)]
        c.shade(lambda x, y, p=pts2: (grey(1.0), cover(sd_polygon(x, y, p))), (gx - 14, gy - 18, gx + 14, gy + 18))
        c.shade(lambda x, y, p=pts2: (grey(0.55), cover(abs(sd_polygon(x, y, p)) - 1.2)), (gx - 14, gy - 18, gx + 14, gy + 18))


def draw_glow(c, w, h):
    cx, cy = w / 2, h / 2
    hw, hh = w / 2 - 34, h / 2 - 34

    def f(x, y):
        d = sd_round_rect(x, y, cx, cy, hw, hh, 26)
        if d < -8:
            return WHITE, 0.95
        return WHITE, max(0.0, 0.95 * math.exp(-max(0.0, d + 8) / 11))
    c.shade(f)


def draw_holo(c, w, h):
    rnd = random.Random(11)
    dots = [(rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(0.6, 1.6)) for _ in range(140)]

    def f(x, y):
        if sd_round_rect(x, y, w / 2, h / 2, w / 2 - 10, h / 2 - 10, CARD_R) > 0:
            return None
        t = (x * 0.7 + y) / 38
        band = max(0.0, math.sin(t)) ** 6 * 0.55 + max(0.0, math.sin(t * 2.3 + 1)) ** 10 * 0.35
        return WHITE, band * 0.75
    c.shade(f)
    for (dx, dy, r) in dots:
        c.shade(lambda x, y, dx=dx, dy=dy, r=r: (WHITE, 0.9 * cover(sd_circle(x, y, dx, dy, r))), (dx - 3, dy - 3, dx + 3, dy + 3), mode="add")


def draw_badge(c, w, h):
    cx, cy, r = w / 2, h / 2, w / 2 - 6
    sides = 8
    pts = [(cx + r * math.cos(i / sides * 2 * math.pi + math.pi / 8), cy + r * math.sin(i / sides * 2 * math.pi + math.pi / 8))
           for i in range(sides)]
    inner = [(cx + (r - 9) * math.cos(i / sides * 2 * math.pi + math.pi / 8), cy + (r - 9) * math.sin(i / sides * 2 * math.pi + math.pi / 8))
             for i in range(sides)]
    c.shade(lambda x, y: (grey(0.85 - 0.25 * (y - cy) / r), cover(sd_polygon(x, y, pts))))
    c.shade(lambda x, y: (grey(0.22), cover(sd_polygon(x, y, inner))))
    c.shade(lambda x, y: (WHITE, 0.9 * cover(abs(sd_polygon(x, y, inner)) - 1.3)))


def draw_crown(c, w, h):
    gold = [(0, H("#FFF1B8")), (0.5, H("#FFC54B")), (1, H("#B8791A"))]
    pts = [(10, 62), (6, 18), (28, 38), (48, 8), (68, 38), (90, 18), (86, 62)]
    c.shade(lambda x, y: (ramp(gold, y / h), cover(sd_polygon(x, y, pts))))
    c.shade(lambda x, y: (H("#3A2200"), cover(abs(sd_polygon(x, y, pts)) - 1.6)))
    c.shade(lambda x, y: (ramp(gold, 0.2), cover(sd_round_rect(x, y, 48, 60, 40, 6, 3))))
    for (gx, gy, col) in [(48, 46, "#FF668F"), (26, 50, "#45BEFF"), (70, 50, "#48DA97")]:
        c.shade(lambda x, y, gx=gx, gy=gy, col=col: (H(col), cover(sd_circle(x, y, gx, gy, 5))))
    for (gx, gy) in [(6, 18), (48, 8), (90, 18)]:
        c.shade(lambda x, y, gx=gx, gy=gy: (WHITE, cover(sd_circle(x, y, gx, gy, 4.5))))


# ---------------------------------------------------------------------------------- backgrounds


def draw_bg(c, w, h, fam):
    body, accent, motif = FAMILIES[fam]
    b, a = H(body), H(accent)
    top = mix(b, a, 0.18)
    rnd = random.Random(hash(fam) & 0xFFFF)

    def base(x, y):
        t = y / h
        col = ramp([(0, top), (0.55, mix(b, NIGHT, 0.35)), (1, mix(NIGHT, b, 0.15))], t)
        g = math.exp(-(((x - w / 2) / (w * 0.42)) ** 2 + ((y - h * 0.45) / (h * 0.34)) ** 2))
        return mix(col, a, 0.35 * g), 1.0
    c.shade(base)

    def add(fn, bbox=None):
        c.shade(fn, bbox, mode="add")

    if motif == "flames":
        def f(x, y):
            n = math.sin(x / 19 + math.sin(y / 31) * 2) * 0.5 + 0.5
            v = smooth(h * 0.45, h, y) * n ** 3
            return a, 0.45 * v
        add(f)
        for _ in range(26):
            ex, ey = rnd.uniform(0, w), rnd.uniform(h * 0.2, h)
            add(lambda x, y, ex=ex, ey=ey: (a, 0.8 * cover(sd_circle(x, y, ex, ey, 1.6))), (ex - 3, ey - 3, ex + 3, ey + 3))
    elif motif == "shards":
        for _ in range(14):
            sx, sy, s = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(14, 40)
            ang = rnd.uniform(0, math.pi)
            pts = [(sx + math.cos(ang) * s, sy + math.sin(ang) * s), (sx + math.cos(ang + 1.9) * s * 0.3, sy + math.sin(ang + 1.9) * s * 0.3),
                   (sx - math.cos(ang) * s, sy - math.sin(ang) * s), (sx + math.cos(ang - 1.2) * s * 0.3, sy + math.sin(ang - 1.2) * s * 0.3)]
            add(lambda x, y, p=pts: (a, 0.32 * cover(sd_polygon(x, y, p))), (sx - s - 2, sy - s - 2, sx + s + 2, sy + s + 2))
    elif motif == "bolts":
        for _ in range(5):
            x0, y0 = rnd.uniform(0, w), rnd.uniform(-20, h * 0.4)
            pts = [(x0, y0)]
            for _ in range(5):
                x0 += rnd.uniform(-34, 34)
                y0 += rnd.uniform(30, 60)
                pts.append((x0, y0))
            for i in range(len(pts) - 1):
                (ax, ay), (bx, by) = pts[i], pts[i + 1]
                add(lambda x, y, ax=ax, ay=ay, bx=bx, by=by: (a, 0.75 * cover(sd_segment(x, y, ax, ay, bx, by, 2.0))
                                                               + 0.25 * math.exp(-max(0, sd_segment(x, y, ax, ay, bx, by, 2.0)) / 6)),
                    (min(ax, bx) - 20, min(ay, by) - 20, max(ax, bx) + 20, max(ay, by) + 20))
    elif motif == "wisps":
        def f(x, y):
            v = math.sin(x / 23 + math.sin(y / 17) * 2.4) * math.sin(y / 29 + x / 41)
            return a, 0.35 * max(0.0, v) ** 2
        add(f)
    elif motif == "rays":
        def f(x, y):
            ang = math.atan2(y + 60, x - w / 2)
            v = max(0.0, math.sin(ang * 18)) ** 4 * smooth(h, 0, y)
            return a, 0.4 * v
        add(f)
    elif motif == "slashes":
        for i in range(3):
            ox = w * 0.62 + i * 22
            add(lambda x, y, ox=ox: (a, 0.5 * cover(sd_segment(x, y, ox, 60, ox - 120, 300, 4.5 - i))), (0, 40, w, 320))
    elif motif == "scales":
        def f(x, y):
            r = 18
            row = math.floor(y / r)
            xx = x + (r if row % 2 else 0)
            dx = (xx % (2 * r)) - r
            dy = (y % r) - r
            d = math.hypot(dx, dy) - r
            return a, 0.28 * cover(abs(d) - 1.2)
        add(f)
    elif motif == "steel":
        for _ in range(9):
            y0 = rnd.uniform(0, h)
            add(lambda x, y, y0=y0: (a, 0.3 * cover(sd_segment(x, y, 0, y0, w, y0 - 140, 1.5))), (0, y0 - 150, w, y0 + 10))
    elif motif == "leaves":
        for _ in range(12):
            lx, ly, s = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(8, 16)
            add(lambda x, y, lx=lx, ly=ly, s=s: (a, 0.4 * cover(max(sd_circle(x, y, lx - s * 0.35, ly, s * 0.7), sd_circle(x, y, lx + s * 0.35, ly, s * 0.7)))),
                (lx - s - 2, ly - s - 2, lx + s + 2, ly + s + 2))
    elif motif == "lattice":
        def f(x, y):
            u, v = (x + y) / 40, (x - y) / 40
            d = min(abs(u - round(u)), abs(v - round(v))) * 40
            return a, 0.3 * cover(d - 1.0)
        add(f)
    elif motif == "stars":
        def f(x, y):
            v = math.sin(x / 37 + y / 53) * math.sin(y / 31 - x / 61)
            return mix(a, H("#45BEFF"), 0.5), 0.3 * max(0.0, v)
        add(f)
        for _ in range(60):
            sx, sy, r = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(0.6, 1.8)
            add(lambda x, y, sx=sx, sy=sy, r=r: (WHITE, 0.9 * cover(sd_circle(x, y, sx, sy, r))), (sx - 3, sy - 3, sx + 3, sy + 3))
    elif motif == "runes":
        for (rx, ry, rr) in [(w / 2, h * 0.42, 120), (w / 2, h * 0.42, 96)]:
            add(lambda x, y, rx=rx, ry=ry, rr=rr: (a, 0.4 * cover(abs(sd_circle(x, y, rx, ry, rr)) - 1.5)))
        for i in range(12):
            ang = i / 12 * 2 * math.pi
            gx, gy = w / 2 + math.cos(ang) * 108, h * 0.42 + math.sin(ang) * 108
            add(lambda x, y, gx=gx, gy=gy: (a, 0.5 * cover(sd_round_rect(x, y, gx, gy, 4, 7, 1))), (gx - 8, gy - 10, gx + 8, gy + 10))
    elif motif == "glyphs":
        add(lambda x, y: (a, 0.4 * cover(abs(sd_circle(x, y, w / 2, h * 0.42, 110)) - 2)))
        tri = [(w / 2 + 100 * math.cos(-math.pi / 2 + k * 2 * math.pi / 3), h * 0.42 + 100 * math.sin(-math.pi / 2 + k * 2 * math.pi / 3)) for k in range(3)]
        add(lambda x, y: (a, 0.35 * cover(abs(sd_polygon(x, y, tri)) - 1.5)))
    elif motif == "orbs":
        for _ in range(12):
            ox, oy, r = rnd.uniform(0, w), rnd.uniform(0, h), rnd.uniform(5, 14)
            add(lambda x, y, ox=ox, oy=oy, r=r: (a, 0.45 * math.exp(-max(0.0, math.hypot(x - ox, y - oy) - r * 0.3) / r)),
                (ox - r * 3, oy - r * 3, ox + r * 3, oy + r * 3))
    elif motif == "cracks":
        for _ in range(6):
            x0, y0 = rnd.uniform(0, w), rnd.uniform(h * 0.5, h)
            for _ in range(5):
                x1, y1 = x0 + rnd.uniform(-40, 40), y0 - rnd.uniform(15, 45)
                add(lambda x, y, x0=x0, y0=y0, x1=x1, y1=y1: (a, 0.8 * cover(sd_segment(x, y, x0, y0, x1, y1, 1.4))
                                                               + 0.3 * math.exp(-max(0, sd_segment(x, y, x0, y0, x1, y1, 1.4)) / 5)),
                    (min(x0, x1) - 16, min(y0, y1) - 16, max(x0, x1) + 16, max(y0, y1) + 16))
                x0, y0 = x1, y1
    # vignette
    c.shade(lambda x, y: (NIGHT, 0.55 * smooth(0.55, 1.05, math.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2)))))


# ------------------------------------------------------------------------------- family glyphs


def draw_family(c, w, h, fam):
    cx, cy = w / 2, h / 2

    def fill(sdf, bbox=None):
        c.shade(lambda x, y: (WHITE, cover(sdf(x, y))), bbox)

    if fam == "Flame":
        fill(lambda x, y: min(sd_circle(x, y, cx, cy + 8, 15), sd_polygon(x, y, [(cx - 14, cy + 6), (cx, cy - 26), (cx + 14, cy + 6)])))
    elif fam == "Ice":
        for k in range(3):
            ang = k * math.pi / 3
            fill(lambda x, y, ang=ang: sd_segment(x, y, cx - math.cos(ang) * 24, cy - math.sin(ang) * 24, cx + math.cos(ang) * 24, cy + math.sin(ang) * 24, 3.5))
    elif fam == "Lightning":
        fill(lambda x, y: sd_polygon(x, y, [(cx + 6, cy - 28), (cx - 14, cy + 4), (cx - 1, cy + 4), (cx - 8, cy + 28), (cx + 14, cy - 6), (cx + 1, cy - 6)]))
    elif fam == "Shadow":
        fill(lambda x, y: max(sd_circle(x, y, cx, cy, 24), -sd_circle(x, y, cx + 11, cy - 7, 20)))
    elif fam == "Divine":
        fill(lambda x, y: sd_circle(x, y, cx, cy, 11))
        for k in range(8):
            ang = k * math.pi / 4
            fill(lambda x, y, ang=ang: sd_segment(x, y, cx + math.cos(ang) * 16, cy + math.sin(ang) * 16, cx + math.cos(ang) * 26, cy + math.sin(ang) * 26, 2.8))
    elif fam == "Beast":
        fill(lambda x, y: sd_circle(x, y, cx, cy + 10, 12))
        for (px, py) in [(-15, -6), (-5, -16), (7, -16), (16, -6)]:
            fill(lambda x, y, px=px, py=py: sd_circle(x, y, cx + px, cy + py, 6))
    elif fam == "Dragon":
        fill(lambda x, y: sd_polygon(x, y, [(cx - 22, cy + 22), (cx - 6, cy - 26), (cx + 2, cy - 4), (cx + 22, cy - 18), (cx + 10, cy + 22)]))
    elif fam == "Warrior":
        fill(lambda x, y: sd_segment(x, y, cx - 18, cy + 18, cx + 18, cy - 18, 4))
        fill(lambda x, y: sd_segment(x, y, cx - 22, cy + 8, cx - 8, cy + 22, 3.5))
    elif fam == "Ninja":
        for k in range(4):
            ang = k * math.pi / 2
            pts = [(cx, cy), (cx + math.cos(ang) * 26, cy + math.sin(ang) * 26), (cx + math.cos(ang + 0.9) * 9, cy + math.sin(ang + 0.9) * 9)]
            fill(lambda x, y, p=pts: sd_polygon(x, y, p))
        c.shade(lambda x, y: (NIGHT, cover(sd_circle(x, y, cx, cy, 4))))
    elif fam == "Royal":
        fill(lambda x, y: sd_polygon(x, y, [(cx - 22, cy + 16), (cx - 24, cy - 14), (cx - 10, cy), (cx, cy - 22), (cx + 10, cy), (cx + 24, cy - 14), (cx + 22, cy + 16)]))
    elif fam == "Cosmic":
        fill(lambda x, y: sd_polygon(x, y, [(cx, cy - 26), (cx + 6, cy - 6), (cx + 26, cy), (cx + 6, cy + 6), (cx, cy + 26), (cx - 6, cy + 6), (cx - 26, cy), (cx - 6, cy - 6)]))
    elif fam == "Ancient":
        fill(lambda x, y: abs(sd_circle(x, y, cx, cy, 22)) - 3)
        fill(lambda x, y: abs(sd_polygon(x, y, [(cx, cy - 14), (cx + 13, cy + 9), (cx - 13, cy + 9)])) - 2.5)
    elif fam == "Mystic":
        fill(lambda x, y: abs(sd_polygon(x, y, [(cx - 26, cy), (cx, cy - 14), (cx + 26, cy), (cx, cy + 14)])) - 3)
        fill(lambda x, y: sd_circle(x, y, cx, cy, 7))
    elif fam == "Spirit":
        fill(lambda x, y: min(sd_circle(x, y, cx - 2, cy - 4, 14), sd_polygon(x, y, [(cx - 14, cy), (cx + 12, cy + 2), (cx + 18, cy + 26)])))
    elif fam == "Demon":
        fill(lambda x, y: sd_polygon(x, y, [(cx - 22, cy + 14), (cx - 26, cy - 26), (cx - 6, cy - 2)]))
        fill(lambda x, y: sd_polygon(x, y, [(cx + 22, cy + 14), (cx + 26, cy - 26), (cx + 6, cy - 2)]))
        fill(lambda x, y: sd_circle(x, y, cx, cy + 10, 12))


# ------------------------------------------------------------------------------------- cutouts


def caps(ax, ay, bx, by, r):
    return ("seg", ax, ay, bx, by, r)


def circ(x, y, r):
    return ("circ", x, y, r)


def poly(*pts):
    return ("poly", list(pts))


def sdf(shape, x, y):
    k = shape[0]
    if k == "seg":
        return sd_segment(x, y, *shape[1:])
    if k == "circ":
        return sd_circle(x, y, *shape[1:])
    return sd_polygon(x, y, shape[1])


def bbox(shape):
    if shape[0] == "seg":
        _, ax, ay, bx, by, r = shape
        return (min(ax, bx) - r - 4, min(ay, by) - r - 4, max(ax, bx) + r + 4, max(ay, by) + r + 4)
    if shape[0] == "circ":
        _, x, y, r = shape
        return (x - r - 4, y - r - 4, x + r + 4, y + r + 4)
    xs = [p[0] for p in shape[1]]
    ys = [p[1] for p in shape[1]]
    return (min(xs) - 4, min(ys) - 4, max(xs) + 4, max(ys) + 4)


def figure(role):
    """Shapes per layer for a role, 384x512, character facing 3/4 left, upper body to knees."""
    hx, hy = 196, 118  # head centre
    skin = [circ(hx, hy, 44), caps(hx + 2, hy + 40, hx + 4, hy + 66, 14)]
    outfit = [poly((128, 168), (268, 160), (284, 330), (112, 336)),  # torso
              poly((116, 320), (196, 326), (186, 508), (118, 508)),  # left leg
              poly((196, 326), (284, 318), (278, 508), (206, 508))]  # right leg
    accent = [poly((150, 92), (160, 54), (180, 74), (196, 40), (214, 70), (238, 50), (242, 92), (252, 118), (236, 104),
                   (220, 84), (196, 80), (172, 86), (150, 118)),  # spiky hair
              poly((112, 300), (286, 292), (288, 318), (112, 326))]  # belt
    if role == "Striker":
        outfit += [caps(128, 182, 84, 104, 17), caps(266, 178, 312, 264, 17)]
        skin += [circ(80, 96, 15), circ(316, 272, 15)]
        accent += [caps(80, 96, 70, -10, 11), poly((60, 92), (100, 100), (96, 110), (56, 102)),
                   poly((62, -20), (82, -20), (78, 96), (66, 96))]
    elif role == "Guardian":
        outfit += [caps(132, 184, 112, 286, 18), caps(264, 180, 300, 276, 18)]
        skin += [circ(300, 282, 15)]
        accent += [poly((44, 168), (176, 160), (182, 330), (112, 396), (40, 330))]
    elif role == "Skirmisher":
        outfit += [caps(128, 186, 70, 250, 15), caps(266, 182, 324, 236, 15)]
        skin += [circ(64, 256, 13), circ(330, 230, 13)]
        accent += [poly((52, 262), (60, 254), (24, 330), (18, 324)), poly((334, 222), (342, 230), (370, 156), (364, 152)),
                   poly((150, 168), (250, 162), (300, 196), (340, 250), (322, 262), (284, 214), (160, 196))]
    elif role == "Trickster":
        outfit += [caps(130, 186, 96, 276, 16), caps(264, 182, 300, 128, 16)]
        skin += [circ(92, 284, 14), circ(302, 120, 14)]
        # one cape flaring out behind the left shoulder, and a scarf tail
        accent += [poly((130, 172), (150, 196), (132, 300), (60, 470), (24, 452), (78, 300)),
                   poly((222, 168), (262, 166), (330, 222), (318, 236), (250, 196))]
        for k, ang in enumerate((-0.5, -0.15, 0.2)):
            cxk, cyk = 302 + math.sin(ang) * 46, 96 - math.cos(ang) * 46
            accent.append(poly((302, 112), (cxk - 14, cyk - 4), (cxk + 6, cyk - 18), (cxk + 22, cyk + 2)))
    elif role == "Support":
        outfit[0] = poly((128, 168), (268, 160), (304, 508), (96, 508))  # long robe
        outfit += [caps(130, 186, 92, 264, 16), caps(264, 182, 312, 250, 16)]
        skin += [circ(88, 270, 14), circ(318, 254, 14)]
        accent += [caps(330, 40, 300, 508, 7), circ(332, 34, 24)]
    elif role == "Bruiser":
        outfit[0] = poly((98, 166), (296, 156), (290, 334), (108, 340))
        outfit += [caps(106, 180, 70, 250, 24), caps(288, 176, 324, 120, 24)]
        accent += [circ(66, 262, 34), circ(328, 104, 34)]
    return {"skin": skin, "outfit": outfit, "accent": accent}


def draw_cutout(c, w, h, role, layer):
    shapes = figure(role)
    light = (-0.6, -0.8)  # from the upper left
    k = 12

    def union(group, x, y):
        return min(sdf(s, x, y) for s in group)

    def shaded(group, base, shadow):
        boxes = [bbox(s) for s in group]
        x0 = max(0, min(b[0] for b in boxes))
        y0 = max(0, min(b[1] for b in boxes))
        x1 = min(w, max(b[2] for b in boxes))
        y1 = min(h, max(b[3] for b in boxes))

        def f(x, y):
            d = union(group, x, y)
            a = cover(d)
            if a <= 0:
                return None
            # two-tone cel shading: shadow where stepping away from the light leaves the shape
            inside_away = union(group, x - light[0] * k, y - light[1] * k) < 0
            return grey(base if inside_away else shadow), a
        c.shade(f, (x0, y0, x1, y1))

    if layer == "line":
        allshapes = shapes["skin"] + shapes["outfit"] + shapes["accent"]

        def f(x, y):
            d = min(sdf(s, x, y) for s in allshapes)
            a = cover(d - 4.5)
            return (NIGHT, a) if a > 0 else None
        c.shade(f)
    elif layer == "skin":
        # skin keeps its colour (not tinted): a warm light tone with a cooler shadow
        boxes = [bbox(s) for s in shapes["skin"]]

        def f(x, y):
            d = min(sdf(s, x, y) for s in shapes["skin"])
            a = cover(d)
            if a <= 0:
                return None
            lit = min(sdf(s, x - light[0] * k, y - light[1] * k) for s in shapes["skin"]) < 0
            return (H("#FFE3CF") if lit else H("#E8B9A0")), a
        for b in boxes:
            c.shade(f, b)
    elif layer == "outfit":
        shaded(shapes["outfit"], 0.95, 0.68)
    elif layer == "accent":
        shaded(shapes["accent"], 1.0, 0.72)


def draw(c, slot, w, h):
    if slot == "card_border":
        draw_frame(c, w, h)
    elif slot == "card_glow":
        draw_glow(c, w, h)
    elif slot == "card_holo":
        draw_holo(c, w, h)
    elif slot == "badge_level":
        draw_badge(c, w, h)
    elif slot == "badge_crown":
        draw_crown(c, w, h)
    elif slot.startswith("card_bg_"):
        fam = next(f for f in FAMILIES if f.lower() == slot[8:])
        draw_bg(c, w, h, fam)
    elif slot.startswith("family_"):
        fam = next(f for f in FAMILIES if f.lower() == slot[7:])
        draw_family(c, w, h, fam)
    elif slot.startswith("cutout_"):
        _, role, layer = slot.split("_")
        draw_cutout(c, w, h, next(r for r in ROLES if r.lower() == role), layer)
