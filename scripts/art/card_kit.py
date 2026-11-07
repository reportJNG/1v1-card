"""Card frame kit (CARDS_EGGS_MISSION section 4.1, board docs/brief/ui-refs-2/04-card-borders.png).

For each rarity (N, R, SR, SSR, UR = Common .. Mythical) and each size (large 512x704,
medium 256x352, small 128x176) it writes, into art/ui/kit/:
  frame_<rarity>_<size>.png    the ornate bevelled metal frame with a transparent window
  glow_<rarity>_<size>.png     the outer + inner glow, its own layer so it can pulse
  energy_<rarity>_<size>.png   the lightning strokes, its own layer so it can flicker
  panel_<rarity>_<size>.png    the dark violet inner panel (template card background)
plus golden_<size>.png (gold foil over the main band of any frame).

Every layer shares one canvas, so the game stacks them at the same size and position. The card
itself (5:7) sits centred in the canvas with a bleed for flourishes and glow; `geometry()` gives
the card and window rectangles as canvas fractions (written to the manifest).

Escalation: N is the plainest; each step adds corner ornament, glow and energy; UR has the most
ornate corners and the strongest energy. Small sizes have fewer flourishes and thicker lines.

Usage:  python scripts/art/card_kit.py [rarity ...] [--size large|medium|small]
"""
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import kitlib as K  # noqa: E402

OUT = os.path.join(K.ROOT, "art", "ui", "kit")

SIZES = {"large": (512, 704), "medium": (256, 352), "small": (128, 176)}
SS = {"large": 3, "medium": 4, "small": 6}

# Card rectangle inside the large canvas (5:7) and its bleed; other sizes scale by k = w / 512.
CARD = (440, 616)

RARITIES = ["Common", "Rare", "Epic", "Legendary", "Mythical"]
BADGE = {"Common": "N", "Rare": "R", "Epic": "SR", "Legendary": "SSR", "Mythical": "UR"}

# Metal ramps (shadow, base, bright, highlight), gem ramps, glow and energy colours (section 1).
STYLE = {
    "Common": dict(
        metal=["#3B3656", "#9080C0", "#E4E2F0", "#FFFFFF"],
        gem=["#5A5480", "#B8B0DA", "#F4F2FF", "#FFFFFF"],
        glow="#E8E6FF", energy="#F4F0FF", inner="#9080C0",
        band=12, level=0, glowA=0.55, bolts=7,
    ),
    "Rare": dict(
        metal=["#04245E", "#0A72E8", "#46C6FF", "#E6FAFF"],
        gem=["#033A8C", "#1E8CFF", "#9BE4FF", "#FFFFFF"],
        glow="#1EA8FF", energy="#BDEBFF", inner="#00A0F0",
        band=13, level=1, glowA=0.75, bolts=11,
    ),
    "Epic": dict(
        metal=["#2A0A5E", "#8B45F2", "#D995FF", "#FFF0FF"],
        gem=["#3C0C78", "#A050FF", "#F0B8FF", "#FFFFFF"],
        glow="#B45CFF", energy="#F2CCFF", inner="#E090F0",
        band=14, level=2, glowA=0.85, bolts=15,
    ),
    "Legendary": dict(
        metal=["#4E2400", "#C98200", "#FFD23A", "#FFFBE0"],
        gem=["#7A3A00", "#F0A000", "#FFE680", "#FFFFFF"],
        glow="#FFB01E", energy="#FFF0B0", inner="#F0D030",
        band=15, level=3, glowA=0.95, bolts=20,
    ),
    "Mythical": dict(
        metal=["#002E1C", "#00A866", "#3DF2A4", "#E6FFF4"],
        gem=["#004A2C", "#00C878", "#9CFFD6", "#FFFFFF"],
        glow="#18E890", energy="#D2FFEC", inner="#00D080",
        band=16, level=4, glowA=1.0, bolts=26,
    ),
}

GOLD = ["#5A3000", "#D08A0A", "#FFD95A", "#FFFFF0"]


def geometry(size):
    """Card and window rects as fractions of the canvas, for layout in the game."""
    w, h = SIZES[size]
    k = w / 512
    cw, ch = CARD[0] * k, CARD[1] * k
    st = STYLE["Common"]
    inset = (st["band"] + 7) * k
    return {
        "canvas": [w, h],
        "card": [round((w - cw) / 2 / w, 4), round((h - ch) / 2 / h, 4), round(cw / w, 4), round(ch / h, 4)],
        "window": [
            round(((w - cw) / 2 + inset) / w, 4),
            round(((h - ch) / 2 + inset) / h, 4),
            round((cw - 2 * inset) / w, 4),
            round((ch - 2 * inset) / h, 4),
        ],
    }


def frame_sdf(x, y, rarity, size):
    """All metal parts of the frame (one SDF), plus the window SDF and the gem list.
    Units are large-canvas px (callers pass coordinates divided by k)."""
    st = STYLE[rarity]
    lvl = st["level"]
    simple = size == "small"
    a, b = CARD[0] / 2, CARD[1] / 2
    c = 30  # corner chamfer
    T = st["band"] + (3 if simple else 0)
    ax, ay = np.abs(x), np.abs(y)

    outer = K.sd_chamfer_box(x, y, a, b, c)
    band = np.maximum(outer, -(outer + T))
    # Inner line (thin, separate from the band) and the corner plates that square off the window
    # so a rectangular clip in the game never shows art outside the frame.
    inset = T + 7 if not simple else T + 4
    win = K.sd_box(x, y, a - inset, b - inset)
    line_w = 2.6 if not simple else 3.2
    inner_line = np.abs(K.sd_chamfer_box(x, y, a - T - 4.5, b - T - 4.5, c * 0.75)) - line_w / 2
    parts = [band, inner_line]
    # Corner plates: cut each window corner at 45 degrees so the art never shows past the frame.
    corner_plate = np.maximum(outer, ((a + b - 2 * inset - 16) - (ax + ay)) / math.sqrt(2))
    parts.append(corner_plate)

    # Corner ornaments (first quadrant, mirrored by abs). Corner point is (a, b).
    def blade(p0, p1, r0, r1):
        return K.sd_blade(ax, ay, p0, p1, r0, r1)

    cx, cy = a - c / 2, b - c / 2  # middle of the chamfer
    dg = 1 / math.sqrt(2)
    L = [16, 26, 34, 44, 54][lvl] * (0.8 if simple else 1)
    parts.append(blade((cx - 4 * dg, cy - 4 * dg), (cx + L * dg, cy + L * dg), 6.5 + lvl * 0.6, 0.4))
    if lvl >= 1 or simple:
        # spikes leaving the edges just past the chamfer, angled outward
        s = 12 + lvl * 3
        parts.append(blade((a - 2, b - c - 8), (a + s * 0.9, b - c - 8 - s * 0.55), 4.2, 0.3))
        parts.append(blade((a - c - 8, b - 2), (a - c - 8 - s * 0.55, b + s * 0.9), 4.2, 0.3))
    if lvl >= 2 and not simple:
        # a second, longer pair and a curl around the corner
        s = 18 + lvl * 4
        parts.append(blade((a - 2, b - c - 24), (a + s * 0.75, b - c - 30 - s * 0.6), 3.6, 0.3))
        parts.append(blade((a - c - 24, b - 2), (a - c - 30 - s * 0.6, b + s * 0.75), 3.6, 0.3))
        ring = K.sd_ring(ax, ay, cx - 9, cy - 9, 11 + lvl, 3.2)
        ring = np.maximum(ring, -(K.sd_box(ax - (cx - 9), ay - (cy - 9), 30, 30)))
        parts.append(np.maximum(ring, -((ax - (cx - 9)) + (ay - (cy - 9)))))
    if lvl >= 3 and not simple:
        # gold-leaf wings along both edges near the corner
        parts.append(blade((a + 1, b - c - 40), (a + 9, b - c - 78), 5, 0.4))
        parts.append(blade((a - c - 40, b + 1), (a - c - 78, b + 9), 5, 0.4))
        parts.append(blade((cx, cy), (cx + 12, cy - 22), 4, 0.3))
        parts.append(blade((cx, cy), (cx - 22, cy + 12), 4, 0.3))
    if lvl >= 4 and not simple:
        # UR: extra crown spikes and a long side spear
        parts.append(blade((a + 2, b - c - 56), (a + 30, b - c - 92), 3.6, 0.3))
        parts.append(blade((a - c - 56, b + 2), (a - c - 92, b + 30), 3.6, 0.3))
        parts.append(blade((cx + 6, cy + 6), (cx + 38, cy + 14), 3.2, 0.3))
        parts.append(blade((cx + 6, cy + 6), (cx + 14, cy + 38), 3.2, 0.3))

    # Inward blades (board 04's signature): a diagonal spike from each corner toward the centre.
    Li = (22 + lvl * 5) * (0.8 if simple else 1)
    parts.append(blade((a - T * 0.6, b - T * 0.6), (a - T - Li * dg * 1.4, b - T - Li * dg * 1.4), 5.5 + lvl * 0.5, 0.3))
    if lvl >= 2 and not simple:
        parts.append(blade((a - T, b - T - 10), (a - T - 14, b - T - 34), 3.2, 0.3))
        parts.append(blade((a - T - 10, b - T), (a - T - 34, b - T - 14), 3.2, 0.3))
    gems = []
    # Top and bottom centre: a diamond in a setting (and side gems from SSR).
    gw, gh = (11 + lvl * 1.2, 15 + lvl * 1.6) if not simple else (14, 18)
    setting = K.sd_rhombus(ax, ay - b, gw + 5, gh + 6)
    parts.append(setting)
    if lvl >= 1 and not simple:
        parts.append(blade((gw + 4, b), (gw + 22 + lvl * 5, b - 5), 3.4, 0.3))
        parts.append(blade((gw + 4, b), (gw + 22 + lvl * 5, b + 5), 3.4, 0.3))
    if lvl >= 2 and not simple:
        parts.append(blade((0, b + gh + 4), (0, b + gh + 16 + lvl * 3), 3.4, 0.3))
    gems.append((0, b, gw, gh))
    gems.append((0, -b, gw, gh))
    if lvl >= 3 and not simple:
        sgw, sgh = 8 + lvl, 12 + lvl
        parts.append(K.sd_rhombus(ax - a, ay, sgw + 4, sgh + 5))
        parts.append(blade((a, sgh + 4), (a + 14, sgh + 24), 3, 0.3))
        parts.append(blade((a, sgh + 4), (a - 10, sgh + 26), 2.6, 0.3))
        gems.append((a, 0, sgw, sgh))
        gems.append((-a, 0, sgw, sgh))

    metal = K.union(*parts)
    return metal, win, gems, outer


def render_frame(rarity, size):
    w, h = SIZES[size]
    ss = SS[size]
    k = w / 512
    st = STYLE[rarity]
    x, y = K.grid(w, h, ss)
    x, y = x / k, y / k
    metal, win, gems, outer = frame_sdf(x, y, rarity, size)
    bev = 4.0 if size != "small" else 5.0
    nx, ny, nz, hgt = K.bevel_normal(metal * k, bev * k, ss)
    col = K.metal(nx, ny, nz, st["metal"], y=y / (CARD[1] / 2), sheen=0.22, spec=16)
    # dark engraved edge at the outline for definition
    edge = np.clip(1 - (-metal * k) / (1.2 * k + 0.4), 0, 1) ** 2
    col = col * (1 - 0.55 * edge[..., None])
    T0 = st["band"] + (3 if size == "small" else 0)
    groove = np.clip(1 - np.abs(outer + T0 * 0.5) / 0.9, 0, 1) * (outer < 0) * (outer > -T0)
    col = col * (1 - 0.45 * groove[..., None])
    img = K.blank(w, h, ss)
    # Outer dark keyline under the metal (readability on any background).
    K.over(img, K.hexc("#0B0720"), K.cover(metal * k - 1.6 * max(k, 0.6), ss) * 0.9)
    K.over(img, col, K.cover(metal * k, ss))
    for gx, gy, gw, gh in gems:
        gx_ = gx if gx == 0 else gx
        d, gcol = K.gem(x, y, gx_, gy, gw, gh, st["gem"])
        K.over(img, K.hexc("#0B0720"), K.cover(d * k - 1.2, ss))
        K.over(img, gcol, K.cover(d * k, ss))
        # tiny star glint on the gem
        gl = np.exp(-((x - gx + gw * 0.25) ** 2 + (y - gy + gh * 0.3) ** 2) / (2 * (gw * 0.18) ** 2))
        K.add_light(img, K.hexc("#FFFFFF"), gl * 0.8 * K.cover(d * k, ss))
    # Bright inner rim line (emissive) just inside the band, in the rarity's inner colour.
    T = st["band"] + (3 if size == "small" else 0)
    rim = np.abs(outer + T + 0.8) - 0.6
    K.add_light(img, K.hexc(st["inner"]), K.cover(rim * k, ss) * 0.85)
    return img


def render_glow(rarity, size):
    """Outer glow around the whole frame plus a soft inner glow along the window edge."""
    w, h = SIZES[size]
    ss = 2
    k = w / 512
    st = STYLE[rarity]
    x, y = K.grid(w, h, ss)
    x, y = x / k, y / k
    metal, win, gems, outer = frame_sdf(x, y, rarity, size)
    m = K.cover(metal * k, ss)
    s = ss * k
    g = (
        0.55 * K.fast_blur(m, 5 * s)
        + 0.45 * K.fast_blur(m, 14 * s)
        + 0.35 * K.fast_blur(m, 30 * s)
    )
    inner = np.clip(1 - np.clip(-win * k, 0, 60 * k) / (34 * k), 0, 1) ** 2 * (win < 0)
    g = np.clip(g * 2.8 * st["glowA"] + inner * 0.45 * st["glowA"], 0, 1)
    g = g * (1 - m)  # the frame itself is drawn by its own layer
    img = K.blank(w, h, ss)
    col = K.hexc(st["glow"])
    img[..., :3] = col
    img[..., 3] = g
    K.edge_fade(img, ss, 14 * k)
    return img, ss


def render_energy(rarity, size):
    """Crackling lightning along the frame edges (separate layer, flickers in the game)."""
    w, h = SIZES[size]
    ss = 3 if size != "small" else 4
    k = w / 512
    st = STYLE[rarity]
    rng = random.Random(hash((rarity, size)) & 0xFFFF)
    a, b = CARD[0] / 2, CARD[1] / 2
    cxp, cyp = w / 2, h / 2
    n = st["bolts"] * 2 if size == "large" else max(4, st["bolts"] * (2 if size == "medium" else 1) // 3)
    core = Image.new("L", (w * ss, h * ss), 0)
    # perimeter samples weighted toward the corners
    for i in range(n):
        corner = rng.random() < 0.55
        if corner:
            sx, sy = rng.choice([-1, 1]), rng.choice([-1, 1])
            px = sx * (a - rng.uniform(0, 70))
            py = sy * (b - rng.uniform(0, 70))
            if rng.random() < 0.5:
                px = sx * a
            else:
                py = sy * b
        else:
            if rng.random() < 0.5:
                px, py = rng.choice([-a, a]), rng.uniform(-b, b)
            else:
                px, py = rng.uniform(-a, a), rng.choice([-b, b])
        # direction: mostly outward, some along the edge, a few inward
        out = np.array([np.sign(px) * (abs(px) >= a - 1), np.sign(py) * (abs(py) >= b - 1)], dtype=float)
        if not out.any():
            out = np.array([np.sign(px), 0.0])
        tang = np.array([-out[1], out[0]])
        dirn = out * rng.uniform(-0.2, 0.6) + tang * rng.choice([-1, 1]) * rng.uniform(0.6, 1.0)
        dirn /= np.linalg.norm(dirn) + 1e-6
        ln = rng.uniform(34, 60 + st["level"] * 14)
        p0 = (cxp + px * k, cyp + py * k)
        m = 10 * k
        p1 = (
            min(w - m, max(m, p0[0] + dirn[0] * ln * k)),
            min(h - m, max(m, p0[1] + dirn[1] * ln * k)),
        )
        pts = K.bolt(rng, p0, p1, rough=0.4, depth=5 if size != "small" else 3)
        width = (1.6 if size == "large" else 1.4) * max(k, 0.5) + (0.6 if size == "small" else 0)
        K.draw_polyline(core, pts, ss, width)
        # one or two branches
        for _ in range(rng.randint(0, 2)):
            j = rng.randint(len(pts) // 4, max(len(pts) // 4 + 1, len(pts) - 2))
            q0 = pts[j]
            ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0]) + rng.uniform(-1.0, 1.0)
            bl = ln * rng.uniform(0.25, 0.5) * k
            q1 = (q0[0] + math.cos(ang) * bl, q0[1] + math.sin(ang) * bl)
            K.draw_polyline(core, K.bolt(rng, q0, q1, rough=0.45, depth=3), ss, width * 0.6)
    c = np.asarray(core, dtype=np.float32) / 255
    halo = np.clip(
        K.fast_blur(c, 2.5 * ss * max(k, 0.5)) * 3.0 + K.fast_blur(c, 8 * ss * max(k, 0.5)) * 2.2, 0, 1
    )
    img = K.blank(w, h, ss)
    img[..., :3] = K.hexc(st["glow"])
    img[..., 3] = halo
    K.add_light(img, K.hexc(st["energy"]), c)
    K.add_light(img, K.hexc("#FFFFFF"), np.clip(c - 0.3, 0, 1))
    K.edge_fade(img, ss, 12 * k)
    return img, ss


def render_panel(rarity, size):
    """Template card background: dark violet gradient, faint diamond pattern, rarity-tinted
    radial light where the emblem sits. Fills the window rect exactly (canvas-sized layer)."""
    w, h = SIZES[size]
    ss = 2
    k = w / 512
    st = STYLE[rarity]
    x, y = K.grid(w, h, ss)
    x, y = x / k, y / k
    a, b = CARD[0] / 2, CARD[1] / 2
    win = K.sd_box(x, y, a - 6, b - 6)
    t = (y + b) / (2 * b)
    top, bot = K.hexc("#1A1240"), K.hexc("#06061B")
    col = top * (1 - t[..., None]) + bot * t[..., None]
    # faint diamond lattice
    u, v = (x + y) / 26, (x - y) / 26
    lat = np.minimum(np.abs(u - np.round(u)), np.abs(v - np.round(v)))
    col = col + (np.clip(1 - lat / 0.06, 0, 1) * 0.035)[..., None]
    # radial light in the rarity colour around the emblem (upper middle)
    r = np.hypot(x / a, (y + b * 0.18) / (b * 0.8))
    glow = np.clip(1 - r, 0, 1) ** 2
    col = col + K.hexc(st["glow"]) * (glow * 0.28)[..., None]
    # vignette
    vig = np.clip(np.hypot(x / a, y / b) - 0.6, 0, 1)
    col = col * (1 - 0.5 * vig[..., None])
    img = K.blank(w, h, ss)
    img[..., :3] = np.clip(col, 0, 1)
    img[..., 3] = K.cover(win * k, ss)
    return img, ss


def render_golden(size):
    """Gold foil over the main band (common to every rarity) with glints."""
    w, h = SIZES[size]
    ss = SS[size]
    k = w / 512
    x, y = K.grid(w, h, ss)
    x, y = x / k, y / k
    a, b = CARD[0] / 2, CARD[1] / 2
    T = STYLE["Common"]["band"] + (3 if size == "small" else 0)
    outer = K.sd_chamfer_box(x, y, a, b, 30)
    band = np.maximum(outer, -(outer + T + 1))
    nx, ny, nz, _ = K.bevel_normal(band * k, 3.5 * k, ss)
    col = K.metal(nx, ny, nz, GOLD, y=y / b, sheen=0.2, spec=18)
    img = K.blank(w, h, ss)
    K.over(img, col, K.cover(band * k, ss) * 0.92)
    rng = random.Random(7)
    for _ in range(6 if size != "small" else 3):
        side = rng.choice(["x", "y"])
        gx = rng.choice([-a, a]) if side == "x" else rng.uniform(-a, a)
        gy = rng.uniform(-b, b) if side == "x" else rng.choice([-b, b])
        r = rng.uniform(8, 14)
        star = np.exp(-np.abs(x - gx) / (r * 0.08)) * np.exp(-np.abs(y - gy) / r) + np.exp(
            -np.abs(y - gy) / (r * 0.08)
        ) * np.exp(-np.abs(x - gx) / r)
        K.add_light(img, K.hexc("#FFFFFF"), np.clip(star, 0, 1) * 0.9)
    return img


def build(rarities, sizes):
    os.makedirs(OUT, exist_ok=True)
    for size in sizes:
        w, h = SIZES[size]
        for r in rarities:
            tag = BADGE[r].lower()
            K.save(render_frame(r, size), SS[size], os.path.join(OUT, f"frame_{tag}_{size}.png"))
            img, ss = render_glow(r, size)
            K.save(img, ss, os.path.join(OUT, f"glow_{tag}_{size}.png"))
            img, ss = render_energy(r, size)
            K.save(img, ss, os.path.join(OUT, f"energy_{tag}_{size}.png"))
            img, ss = render_panel(r, size)
            K.save(img, ss, os.path.join(OUT, f"panel_{tag}_{size}.png"))
            print("frame", r, size, flush=True)
        K.save(render_golden(size), SS[size], os.path.join(OUT, f"golden_{size}.png"))
    json.dump({s: geometry(s) for s in SIZES}, open(os.path.join(OUT, "geometry.json"), "w"), indent=1)


# ------------------------------------------------------------------ badges

BADGE_FILL = {
    "Common": ["#FFFFFF", "#E8E6F4", "#A89CD0", "#5E5488"],
    "Rare": ["#E8FBFF", "#5AD0FF", "#0A80F0", "#03307A"],
    "Epic": ["#FFF0FF", "#E7A6FF", "#A050FF", "#3C0C78"],
    "Legendary": ["#FFFFF0", "#FFE24A", "#F0A010", "#7A3A00"],
    "Mythical": ["#F0FFF8", "#6CFFC0", "#00C070", "#004A2C"],
}


def render_badge(rarity, w, h, ss=4):
    """The italic N / R / SR / SSR / UR badge: gradient letters, thick dark outline, glow."""
    text = BADGE[rarity]
    fsize = h * ss * (0.78 if len(text) < 3 else 0.7)
    f = K.font("LuckiestGuy-Regular.ttf", fsize)
    m = K.text_mask(text, f, w, h, ss, shear=0.24, cy=h * 0.56, tracking=-h * 0.02)
    unit = h * ss / 100
    d = K.distance_outside(m, int(13 * unit))
    outline = np.clip(1 - (d - 11 * unit) / (1.5 * unit), 0, 1)
    rim = np.clip(1 - (d - 5 * unit) / (1.5 * unit), 0, 1)
    img = K.blank(w, h, ss)
    glow = K.fast_blur(outline, 6 * unit)
    img[..., :3] = K.hexc(STYLE[rarity]["glow"])
    img[..., 3] = np.clip(glow * 1.6, 0, 1) * 0.9
    K.over(img, K.hexc("#0B0720"), outline)
    stops = [K.hexc(c) for c in BADGE_FILL[rarity]]
    K.over(img, stops[3], rim)
    ys = np.linspace(0, 1, h * ss, dtype=np.float32)[:, None]
    ys = np.broadcast_to(ys, m.shape)
    # gradient: highlight (top) -> bright -> base -> deep at the bottom
    t = np.clip((ys - 0.18) / 0.7, 0, 1)
    col = np.where(
        (t < 0.4)[..., None],
        stops[0] * (1 - t[..., None] / 0.4) + stops[1] * (t[..., None] / 0.4),
        stops[1] * (1 - (t[..., None] - 0.4) / 0.6) + stops[2] * ((t[..., None] - 0.4) / 0.6),
    )
    K.over(img, col, m)
    # glossy top band
    gloss = m * np.clip((0.5 - ys) / 0.1, 0, 1) * 0.35
    K.add_light(img, K.hexc("#FFFFFF"), gloss)
    K.edge_fade(img, ss, 3)
    return img


def build_badges():
    for r in RARITIES:
        tag = BADGE[r].lower()
        K.save(render_badge(r, 256, 128), 4, os.path.join(OUT, f"badge_{tag}_large.png"))
        K.save(render_badge(r, 128, 64), 4, os.path.join(OUT, f"badge_{tag}_small.png"))
        print("badge", r, flush=True)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    sizes = list(SIZES)
    if "--size" in sys.argv:
        sizes = [sys.argv[sys.argv.index("--size") + 1]]
        args = [a for a in args if a not in sizes]
    if args == ["badges"]:
        build_badges()
    else:
        build(args or RARITIES, sizes)
