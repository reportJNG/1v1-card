"""Section 6 extra assets (CARDS_EGGS_MISSION), route C, drawn with kitlib into art/ui/kit/.

Stickers (NEW!, MAX, +1), the MAX ribbon, 15 family gems, stat icons, stats-panel button icons,
the level bar, opening FX (summon circle and runes, cracks, shockwave, rays, pillar), rarity
auras, the orbiting ribbon, particles (fx_sparkle, fx_ember, fx_mote; prefixed so they don't
shadow the older `sparkle` UI slot), the lock overlay, world badge, empty deck slot, confetti,
filter chips, toasts, odds rows, card backs, and the evolution marks (corner gems, gold inner
line). White images are tinted in the game with ImageColor3.

Run through scripts/art/ui_kit.py (group "extras" or a single group name).
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import kitlib as K  # noqa: E402

KIT = os.path.join(K.ROOT, "art", "ui", "kit")

TAGS = {"n": "Common", "r": "Rare", "sr": "Epic", "ssr": "Legendary", "ur": "Mythical"}
PAL = {  # light, main, deep, glow (Config/Rarities colors)
    "n": ["#FFFFFF", "#E4E2F0", "#9080C0", "#E8E6FF"],
    "r": ["#9BE4FF", "#00A0F0", "#0060C0", "#1EA8FF"],
    "sr": ["#E090F0", "#9B4DFF", "#5A1FB0", "#B45CFF"],
    "ssr": ["#FFE680", "#F0C010", "#B87800", "#FFB01E"],
    "ur": ["#9CFFD6", "#00C070", "#007A48", "#18E890"],
}
FAMILY = {  # Config/Art FamilyColors (body, accent)
    "flame": ("#C2412D", "#FFB347"), "ice": ("#7FB8E0", "#E8F6FF"), "lightning": ("#3A55C8", "#FFE14D"),
    "shadow": ("#2B2540", "#9B7BFF"), "divine": ("#F1E6C8", "#FFD45C"), "beast": ("#8A5A3B", "#D9B48A"),
    "dragon": ("#2F7A4D", "#FF6A2B"), "warrior": ("#7B8794", "#D2462E"), "ninja": ("#22303F", "#4FD1C5"),
    "royal": ("#5B2A86", "#FFC54B"), "cosmic": ("#1C1F4A", "#FF7BE5"), "ancient": ("#9C8B6E", "#5FD3A0"),
    "mystic": ("#3E2A6B", "#B98CFF"), "spirit": ("#A9D8D0", "#FFFFFF"), "demon": ("#4A1022", "#FF3B3B"),
}
INK = "#0B0720"


def save(img, ss, name):
    K.save(img, ss, os.path.join(KIT, name + ".png"))


def glow_under(img, d, ss, color, r, strength=1.6, amount=0.8):
    g = K.fast_blur(K.cover(d, ss), r * ss)
    K.add_light(img, K.hexc(color), np.clip(g * strength, 0, 1) * amount)


def shaded(img, d, ss, ramp, bevel=3.0, outline=2.0, y=None, glow=None, glow_r=6.0):
    """A bevelled glossy shape: optional glow, dark outline, candy/metal shading."""
    if glow:
        glow_under(img, d, ss, glow, glow_r)
    if outline:
        K.over(img, K.hexc(INK), K.cover(d - outline, ss))
    nx, ny, nz, _ = K.bevel_normal(d, bevel, ss)
    col = K.metal(nx, ny, nz, ramp, y=y, sheen=0.25 if y is not None else 0.0, spec=20)
    K.over(img, col, K.cover(d, ss))
    return img


def mask_sdf(mask, ss, cap=60):
    """Signed distance (final px) from a coverage mask drawn at ss."""
    inside = mask > 0.5
    out = K.distance_outside(mask, cap) / ss
    inn = K.distance_outside(1 - mask, cap) / ss
    return np.where(inside, -inn, out)


def poly_sdf(pts, w, h, ss):
    m = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(m).polygon([((px + w / 2) * ss, (py + h / 2) * ss) for px, py in pts], fill=255)
    return mask_sdf(np.asarray(m, dtype=np.float32) / 255, ss)


def white_fx(name, alpha, w, h, ss, fade=4):
    img = K.blank(w, h, ss)
    img[..., :3] = 1
    img[..., 3] = np.clip(alpha, 0, 1)
    K.edge_fade(img, ss, fade)
    save(img, ss, name)


# ------------------------------------------------------------------ stickers and ribbon


def text_sticker(name, text, ramp, w=256, h=128, shear=0.2, rot=0.0, size=0.72):
    ss = 4
    f = K.font("LuckiestGuy-Regular.ttf", h * ss * size)
    m = K.text_mask(text, f, w, h, ss, shear=shear, cy=h * 0.56)
    if rot:
        m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).rotate(rot, Image.BICUBIC), dtype=np.float32) / 255
    unit = h * ss / 100
    d = K.distance_outside(m, int(12 * unit))
    outline = np.clip(1 - (d - 10 * unit) / (1.5 * unit), 0, 1)
    img = K.blank(w, h, ss)
    img[..., :3] = K.hexc(ramp[3])
    img[..., 3] = np.clip(K.fast_blur(outline, 6 * unit) * 1.5, 0, 1) * 0.85
    K.over(img, K.hexc(INK), outline)
    ys = np.broadcast_to(np.linspace(0, 1, h * ss, dtype=np.float32)[:, None], m.shape)
    t = np.clip((ys - 0.2) / 0.65, 0, 1)[..., None]
    a, b, c = K.hexc(ramp[0]), K.hexc(ramp[1]), K.hexc(ramp[2])
    col = np.where(t < 0.45, a * (1 - t / 0.45) + b * (t / 0.45), b * (1 - (t - 0.45) / 0.55) + c * ((t - 0.45) / 0.55))
    K.over(img, col, m)
    K.add_light(img, K.hexc("#FFFFFF"), m * np.clip((0.48 - ys) / 0.1, 0, 1) * 0.3)
    K.edge_fade(img, ss, 3)
    save(img, ss, name)


def stickers():
    text_sticker("sticker_new", "NEW!", ["#FFFDE0", "#FFE24A", "#FF9A10", "#FFB01E"], rot=8)
    text_sticker("sticker_max", "MAX", ["#FFF0F4", "#FF6A9A", "#C0104A", "#FF3D7F"])
    text_sticker("sticker_dup", "+1", ["#F0FFF8", "#7CFFC8", "#00A060", "#18E890"], shear=0.1)
    # MAX ribbon: crimson banner with notched tails and a gold edge, "MAX" in white.
    w, h, ss = 512, 128, 3
    x, y = K.grid(w, h, ss)
    body = K.sd_box(x, y, 170, 34)
    tails = K.union(K.sd_box(x + 200, y - 8, 46, 28), K.sd_box(x - 200, y - 8, 46, 28))
    notch = K.union(K.sd_rhombus(x + 246, y - 8, 22, 28), K.sd_rhombus(x - 246, y - 8, 22, 28))
    tails = np.maximum(tails, -notch)
    img = K.blank(w, h, ss)
    shaded(img, tails, ss, ["#3A0010", "#8A0A28", "#C8204A", "#FF8AA8"], bevel=4, y=y / 40)
    shaded(img, body, ss, ["#4A0016", "#B8123E", "#FF3D6A", "#FFD0DC"], bevel=5, y=y / 34, glow="#FF3D7F", glow_r=8)
    K.over(img, K.hexc("#FFD95A"), K.cover(np.abs(body + 4) - 1.6, ss))
    f = K.font("LuckiestGuy-Regular.ttf", 54 * ss)
    m = K.text_mask("MAX", f, w, h, ss, cy=h / 2 + 3)
    d = K.distance_outside(m, 10)
    K.over(img, K.hexc(INK), np.clip(1 - (d - 7) / 2, 0, 1))
    K.over(img, K.hexc("#FFFFFF"), m)
    K.edge_fade(img, ss, 3)
    save(img, ss, "ribbon_max")


# ------------------------------------------------------------------ gems and icons


def family_gems():
    w = 128
    ss = 4
    for fam, (body, accent) in FAMILY.items():
        x, y = K.grid(w, w, ss)
        ang = np.arctan2(y, x)
        r = np.hypot(x, y)
        seg = math.pi / 4
        a = np.mod(ang + seg / 2, seg) - seg / 2
        d = r * np.cos(a) - 46
        img = K.blank(w, w, ss)
        glow_under(img, d, ss, accent, 8, 1.4, 0.8)
        K.over(img, K.hexc(INK), K.cover(d - 4, ss))
        K.over(img, K.hexc("#FFD95A"), K.cover(d - 1.5, ss))  # gold bezel
        facet = np.where(np.sin(ang * 4 + 0.4) > 0, 1.0, 0.72)
        lit = np.clip(0.6 - 0.45 * (x + y) / 80, 0.2, 1.0) * facet
        dark, mid = K.hexc(body) * 0.6, K.hexc(accent)
        col = dark * (1 - lit[..., None]) + mid * lit[..., None]
        col = np.where((r * np.cos(a) < 22)[..., None], mid * 0.75 + 0.25, col)
        K.over(img, np.clip(col, 0, 1), K.cover(d + 5, ss))
        K.add_light(img, K.hexc("#FFFFFF"), np.exp(-((x + 14) ** 2 + (y + 16) ** 2) / 72.0) * 0.9)
        K.edge_fade(img, ss, 4)
        save(img, ss, f"gem_family_{fam}")


def icon(name, sdf, ramp, glow, w=128, ss=4):
    x, y = K.grid(w, w, ss)
    img = K.blank(w, w, ss)
    shaded(img, sdf(x, y), ss, ramp, bevel=4, outline=3, y=y / 50, glow=glow, glow_r=5)
    K.edge_fade(img, ss, 3)
    save(img, ss, name)


def sword(x, y):
    u, v = (x + y) / math.sqrt(2), (y - x) / math.sqrt(2)  # blade points up-right
    blade = np.maximum(K.sd_box(u, v + 6, 8, 36), (np.abs(u) * 2.4 - (v + 46)) / 2.6)
    guard = K.sd_round_box(u, v - 32, 22, 6, 3)
    grip = K.sd_box(u, v - 46, 5, 10)
    pommel = K.sd_circle(u, v, 0, 59, 7)
    return K.union(blade, guard, grip, pommel)


def shield(x, y):
    return poly_sdf([(-38, -42), (0, -52), (38, -42), (40, 2), (0, 50), (-40, 2)], 128, 128, 4) - 3


def heart(x, y):
    lobes = K.union(K.sd_circle(x, y, -20, -14, 23), K.sd_circle(x, y, 20, -14, 23))
    tip = poly_sdf([(-41, -6), (41, -6), (0, 46)], 128, 128, 4)
    return K.smooth_union(lobes, tip - 2, 6)


def bolt_shape(x, y):
    return poly_sdf([(-8, -50), (26, -50), (6, -10), (32, -10), (-16, 52), (-2, 6), (-28, 6)], 128, 128, 4)


def swirl(x, y):
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    spiral = np.abs(np.mod(r - ang * 8 / math.pi + 100, 16) - 8) - 4.5
    return np.maximum(spiral, r - 46)


def wing(x, y):
    return K.union(*[K.sd_blade(x, y, (-34, 26), (44, -36 + i * 18), 10 - i * 1.5, 2) for i in range(4)])


def stat_icons():
    icon("icon_atk", sword, ["#4A0008", "#D0202A", "#FF6A5A", "#FFE0D8"], "#FF4040")
    icon("icon_def", shield, ["#04245E", "#1A70E8", "#5AC0FF", "#E6FAFF"], "#2A90FF")
    icon("icon_hp", heart, ["#004A2A", "#18B060", "#6CF0A0", "#E8FFF0"], "#30E080")
    icon("icon_spd", wing, ["#004858", "#10A8C8", "#70E8FF", "#E8FCFF"], "#30D0F0")
    icon("icon_energy", bolt_shape, ["#5A3A00", "#F0A800", "#FFE24A", "#FFFFE0"], "#FFC020")
    icon("icon_passive", swirl, ["#2A0A5E", "#9050F0", "#D8A0FF", "#FFF0FF"], "#B060FF")


def button_icons():
    white = ["#5A5080", "#D8D4F0", "#FFFFFF", "#FFFFFF"]

    def arrow(x, y):
        return poly_sdf([(0, -50), (46, -2), (18, -2), (18, 46), (-18, 46), (-18, -2), (-46, -2)], 128, 128, 4) - 2

    def bag(x, y):
        body = K.sd_round_box(x, y - 12, 42, 32, 10)
        handle = np.maximum(K.sd_ring(x, y, 0, -22, 17, 8), y + 18)
        return K.union(body, handle)

    def eye(x, y):
        lens = np.maximum(K.sd_circle(x, y, 0, 40, 64), K.sd_circle(x, y, 0, -40, 64))
        hole = np.maximum(K.sd_circle(x, y, 0, 34, 54), K.sd_circle(x, y, 0, -34, 54))
        return K.union(np.maximum(lens, -hole), K.sd_circle(x, y, 0, 0, 17))

    icon("icon_upgrade", arrow, white, "#B060FF")
    icon("icon_evolve", lambda x, y: K.sd_star(x, y, 0, 4, 52, 0.48), ["#6A3A00", "#F0B000", "#FFE24A", "#FFFFE0"], "#FFC020")
    icon("icon_equip", bag, ["#4A2A10", "#E0A040", "#FFD890", "#FFF8E8"], "#FFB040")
    icon("icon_favorite_on", heart, ["#5A0028", "#F03C8C", "#FF9AC8", "#FFF0F8"], "#FF4FA0")
    icon("icon_favorite_off", lambda x, y: np.abs(heart(x, y) + 5) - 5, white, None)
    icon("icon_preview", eye, white, "#B060FF")


# ------------------------------------------------------------------ bars


def bars():
    w, h, ss = 256, 32, 4
    x, y = K.grid(w, h, ss)
    d = K.sd_round_box(x, y, 126, 14, 14)
    img = K.blank(w, h, ss)
    K.over(img, K.hexc(INK), K.cover(d - 1.5, ss))
    K.over(img, K.hexc("#1A1238"), K.cover(d, ss))
    K.over(img, K.hexc("#05040F"), K.cover(K.sd_round_box(x, y + 2, 122, 10, 10), ss) * 0.8)
    save(img, ss, "bar_level_bg")
    img = K.blank(w, h, ss)
    t = np.clip((y + 12) / 24, 0, 1)[..., None]
    K.over(img, K.hexc("#FFFFFF") * (1 - t) + K.hexc("#B8B0E0") * t, K.cover(K.sd_round_box(x, y, 122, 11, 11), ss))
    K.add_light(img, K.hexc("#FFFFFF"), K.cover(K.sd_round_box(x, y - 5, 114, 2.5, 2.5), ss) * 0.7)
    save(img, ss, "bar_level_fill")  # white: tinted per rarity in the game
    x, y = K.grid(256, 64, ss)
    g = K.cover(K.sd_round_box(x, y, 120, 12, 12), ss)
    white_fx("bar_level_glow", K.fast_blur(g, 8 * ss) * 1.5, 256, 64, ss)


# ------------------------------------------------------------------ egg opening FX


def opening_fx():
    rng = random.Random(5)
    w, ss = 512, 2
    x, y = K.grid(w, w, ss)
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    rings = K.union(K.sd_ring(x, y, 0, 0, 236, 5), K.sd_ring(x, y, 0, 0, 212, 2.5), K.sd_ring(x, y, 0, 0, 120, 3))
    ticks = np.maximum(np.abs(np.mod(ang * 36 / math.pi, 2) - 1) * r * math.pi / 36 - 1.2, np.abs(r - 224) - 9)
    lines = []
    for k in range(6):
        a0 = k * math.pi / 3
        lines.append(K.sd_blade(x, y, (200 * math.cos(a0), 200 * math.sin(a0)),
                                (200 * math.cos(a0 + 2 * math.pi / 3), 200 * math.sin(a0 + 2 * math.pi / 3)), 2.2, 2.2))
    c = K.cover(K.union(rings, ticks, *lines), ss)
    white_fx("summon_circle", c + K.fast_blur(c, 6 * ss) * 0.8, w, w, ss)
    m = Image.new("L", (w * ss, w * ss), 0)
    dr = ImageDraw.Draw(m)
    for k in range(18):
        a = k * 2 * math.pi / 18
        cx, cy = w / 2 + 168 * math.cos(a), w / 2 + 168 * math.sin(a)
        for _ in range(3):
            p = [(cx + rng.uniform(-11, 11), cy + rng.uniform(-11, 11)) for _ in range(2)]
            dr.line([(p[0][0] * ss, p[0][1] * ss), (p[1][0] * ss, p[1][1] * ss)], fill=255, width=3 * ss)
        dr.ellipse([(cx - 3) * ss, (cy - 3) * ss, (cx + 3) * ss, (cy + 3) * ss], fill=255)
    c = np.asarray(m, dtype=np.float32) / 255
    white_fx("summon_runes", c + K.fast_blur(c, 4 * ss) * 0.9, w, w, ss)
    for level in (1, 2, 3):
        m = Image.new("L", (w * ss, w * ss), 0)
        rr = random.Random(level * 11)
        for _ in range(2 + level * 3):
            a = rr.uniform(0, 2 * math.pi)
            p0 = (w / 2 + rr.uniform(-40, 40), w / 2 + rr.uniform(-60, 60))
            ln = rr.uniform(80, 120 + level * 40)
            K.draw_polyline(m, K.bolt(rr, p0, (p0[0] + math.cos(a) * ln, p0[1] + math.sin(a) * ln), 0.35, 4), ss, 3.0 + level * 0.5)
        c = np.asarray(m, dtype=np.float32) / 255
        white_fx(f"crack_overlay_{level}", c + K.fast_blur(c, 5 * ss) * 1.2, w, w, ss)
    white_fx("shockwave_ring", (np.exp(-((r - 200) / 14) ** 2) + np.exp(-((r - 200) / 40) ** 2) * 0.4) * (r < 250), w, w, ss)
    rays = np.clip(np.cos(ang * 8) * 1.4 - 0.4, 0, 1) * np.clip(1 - r / 250, 0, 1) ** 1.2
    white_fx("light_rays", rays + np.clip(1 - r / 90, 0, 1) ** 2, w, w, ss)
    xp, yp = K.grid(256, 1024, 1)
    core = np.exp(-(xp / 22) ** 2) + np.exp(-(xp / 70) ** 2) * 0.6
    white_fx("light_pillar", core * np.clip(1 - np.abs(yp) / 512, 0, 1) ** 0.6, 256, 1024, 1)


# ------------------------------------------------------------------ auras and particles


def auras():
    w, ss = 512, 2
    x, y = K.grid(w, w, ss)
    r = np.hypot(x / 0.72, y)  # a tall ellipse around a 5:7 card
    ang = np.arctan2(y, x)
    for tag, pal in PAL.items():
        rng = np.random.default_rng(len(tag) * 7 + 1)
        flame = np.zeros_like(r)
        for k in range(1, 6):
            flame += np.sin(ang * (k * 3 + 2) + rng.uniform(0, 6)) / k
        edge = 205 + flame * 9
        body = np.clip(1 - np.abs(r - edge) / 42, 0, 1) ** 1.5
        inner = np.clip(1 - np.clip(edge - r, 0, None) / 120, 0, 1) * (r < edge) * 0.35
        img = K.blank(w, w, ss)
        t = body[..., None]
        img[..., :3] = K.hexc(pal[3]) * (1 - t) + K.hexc(pal[0]) * t
        img[..., 3] = np.clip(body + inner, 0, 1) * np.clip((250 - r) / 30, 0, 1)
        K.edge_fade(img, ss, 6)
        save(img, ss, f"aura_{tag}")
    w, h = 512, 256
    x, y = K.grid(w, h, ss)
    e = np.hypot(x / 240, y / 70)
    tail = np.mod(np.arctan2(y / 70, x / 240) + math.pi * 0.25, 2 * math.pi) / (2 * math.pi)
    white_fx("ribbon_orbit", np.exp(-((e - 1) / 0.05) ** 2) * tail ** 2 * 1.4, w, h, ss)
    w, ss = 64, 4
    x, y = K.grid(w, w, ss)
    r = np.hypot(x, y)
    star4 = np.exp(-np.abs(x) / 1.8) * np.exp(-np.abs(y) / 14) + np.exp(-np.abs(y) / 1.8) * np.exp(-np.abs(x) / 14)
    white_fx("fx_sparkle", star4 + np.exp(-(r / 5) ** 2), w, w, ss, 2)
    white_fx("fx_ember", np.exp(-(np.hypot(x, y * 0.6) / 7) ** 2) * 1.2 + np.exp(-(r / 16) ** 2) * 0.4, w, w, ss, 2)
    white_fx("fx_mote", np.exp(-(r / 9) ** 2) + np.exp(-(r / 20) ** 2) * 0.5, w, w, ss, 2)


# ------------------------------------------------------------------ misc


def misc():
    w, ss = 256, 3
    x, y = K.grid(w, w, ss)
    body = K.sd_round_box(x, y - 26, 62, 50, 12)
    shackle = np.maximum(K.sd_ring(x, y, 0, -24, 40, 14), y + 10)
    hole = K.union(K.sd_circle(x, y, 0, 18, 10), K.sd_box(x, y - 36, 4, 16))
    d = np.maximum(K.union(body, shackle), -hole)
    img = K.blank(w, w, ss)
    shaded(img, d, ss, ["#3A3050", "#9890B8", "#E8E4FF", "#FFFFFF"], bevel=5, outline=4, y=y / 80, glow="#9B7BFF", glow_r=10)
    K.edge_fade(img, ss, 4)
    save(img, ss, "lock_overlay")
    x, y = K.grid(256, 96, ss)
    d = K.sd_round_box(x, y, 118, 36, 36)
    img = K.blank(256, 96, ss)
    glow_under(img, d, ss, "#9B4DFF", 6, 1.5, 0.7)
    K.over(img, K.hexc("#C8A8FF"), K.cover(d, ss))
    K.over(img, K.hexc("#140E30"), K.cover(d + 3, ss))
    K.edge_fade(img, ss, 3)
    save(img, ss, "world_badge")
    x, y = K.grid(256, 352, ss)
    d = K.sd_round_box(x, y, 110, 158, 18)
    per = np.mod((np.arctan2(y, x) + math.pi) * 40, 2 * math.pi)
    line = K.cover(np.abs(d) - 2.5, ss) * (np.sin(per) > -0.2)
    plus = K.cover(K.union(K.sd_round_box(x, y, 26, 6, 3), K.sd_round_box(x, y, 6, 26, 3)), ss)
    img = K.blank(256, 352, ss)
    K.over(img, K.hexc("#140E30"), K.cover(d + 6, ss) * 0.55)
    K.add_light(img, K.hexc("#C8A8FF"), np.clip(line + plus + K.fast_blur(line + plus, 5 * ss) * 1.2, 0, 1))
    K.edge_fade(img, ss, 3)
    save(img, ss, "empty_slot")
    x, y = K.grid(256, 64, ss, cx=0, cy=32)
    parts = [K.sd_box(x - 32, y, 8, 18), K.sd_circle(x, y, 96, 0, 12), K.sd_rhombus(x - 160, y, 12, 18),
             K.sd_star(x, y, 224, 0, 18, 0.45)]
    white_fx("confetti_set", K.cover(K.union(*parts), ss), 256, 64, ss, 1)


def rarity_strips():
    ss = 3
    for tag, pal in PAL.items():
        light, main, deep, glow = (K.hexc(c) for c in pal)
        x, y = K.grid(192, 64, ss)
        d = K.sd_round_box(x, y, 88, 24, 24)
        img = K.blank(192, 64, ss)
        K.add_light(img, glow, np.clip(K.fast_blur(K.cover(d, ss), 4 * ss) * 1.4, 0, 1) * 0.6)
        K.over(img, light, K.cover(d, ss))
        t = np.clip((y + 22) / 44, 0, 1)[..., None]
        K.over(img, deep * 0.45 * (1 - t) + K.hexc("#0A0820") * t, K.cover(d + 2.5, ss))
        K.edge_fade(img, ss, 3)
        save(img, ss, f"filter_chip_{tag}")
        x, y = K.grid(512, 128, ss)
        d = K.sd_round_box(x, y, 236, 40, 22)
        img = K.blank(512, 128, ss)
        K.add_light(img, glow, np.clip(K.fast_blur(K.cover(d, ss), 9 * ss) * 1.5, 0, 1) * 0.8)
        K.over(img, main, K.cover(d, ss))
        t = np.clip((y + 38) / 76, 0, 1)[..., None]
        K.over(img, deep * 0.55 * (1 - t) + K.hexc("#0A0820") * t, K.cover(d + 3, ss))
        K.edge_fade(img, ss, 4)
        save(img, ss, f"toast_rarity_{tag}")
        x, y = K.grid(512, 64, ss)
        d = K.sd_round_box(x, y, 252, 28, 10)
        img = K.blank(512, 64, ss)
        K.over(img, K.hexc("#140E30"), K.cover(d, ss) * 0.92)
        K.add_light(img, main, K.cover(np.abs(d) - 0.8, ss) * 0.55)
        K.over(img, main, K.cover(np.maximum(d, x + 242), ss))
        save(img, ss, f"odds_row_{tag}")


def card_backs():
    """Card back per rarity (medium canvas, same geometry as the frames): dark panel, diamond
    lattice, a ring with '1v1' in the middle, and the rarity frame on top."""
    import card_kit as CK
    w, h = CK.SIZES["medium"]
    ss = 3
    k = w / 512
    for tag in TAGS:
        x, y = K.grid(w, h, ss)
        x, y = x / k, y / k
        a, b = CK.CARD[0] / 2, CK.CARD[1] / 2
        pal = [K.hexc(c) for c in PAL[tag]]
        tt = ((y + b) / (2 * b))[..., None]
        col = K.hexc("#241860") * (1 - tt) + K.hexc("#08061C") * tt
        u, v = (x + y) / 40, (x - y) / 40
        lat = np.minimum(np.abs(u - np.round(u)), np.abs(v - np.round(v)))
        col = col + pal[3] * (np.clip(1 - lat / 0.05, 0, 1) * 0.12)[..., None]
        col = col + pal[3] * (np.clip(1 - np.hypot(x, y) / 170, 0, 1) ** 2 * 0.5)[..., None]
        img = K.blank(w, h, ss)
        K.over(img, np.clip(col, 0, 1), K.cover(K.sd_box(x, y, a - 6, b - 6) * k, ss))
        K.over(img, pal[1], K.cover(K.union(K.sd_ring(x, y, 0, 0, 92, 7), K.sd_ring(x, y, 0, 0, 72, 3)) * k, ss))
        m = K.text_mask("1v1", K.font("LuckiestGuy-Regular.ttf", 70 * k * ss), w, h, ss, cy=h / 2 + 4 * k)
        d = K.distance_outside(m, 8)
        K.over(img, K.hexc(INK), np.clip(1 - (d - 6) / 2, 0, 1))
        K.over(img, pal[0], m)
        path = os.path.join(KIT, f"card_back_{tag}.png")
        K.save(img, ss, path)
        out = Image.open(path)
        out.alpha_composite(Image.open(os.path.join(KIT, f"frame_{tag}_medium.png")))
        out.save(path, optimize=True)


def stage_marks():
    """Evolution marks: a corner gem per rarity (Awakened) and a gold inner line per size
    (Ascended), on the frame canvas."""
    import card_kit as CK
    w, ss = 64, 4
    for tag, r in TAGS.items():
        x, y = K.grid(w, w, ss)
        st = CK.STYLE[r]
        d, col = K.gem(x, y, 0, 0, 20, 26, st["gem"])
        img = K.blank(w, w, ss)
        glow_under(img, d, ss, st["glow"], 5, 1.6, 1.0)
        K.over(img, K.hexc(INK), K.cover(d - 2.5, ss))
        K.over(img, col, K.cover(d, ss))
        K.edge_fade(img, ss, 2)
        save(img, ss, f"corner_gem_{tag}")
    for size, (w, h) in CK.SIZES.items():
        ss = CK.SS[size]
        k = w / 512
        x, y = K.grid(w, h, ss)
        x, y = x / k, y / k
        a, b = CK.CARD[0] / 2, CK.CARD[1] / 2
        T = CK.STYLE["Common"]["band"] + (3 if size == "small" else 0)
        inset = T + (7 if size != "small" else 4)
        line = np.abs(K.sd_chamfer_box(x, y, a - inset + 2.5, b - inset + 2.5, 18)) - (1.4 if size != "small" else 2.2)
        img = K.blank(w, h, ss)
        K.add_light(img, K.hexc("#FFB01E"), np.clip(K.fast_blur(K.cover(line * k, ss), 3 * ss) * 2, 0, 1) * 0.7)
        nx, ny, nz, _ = K.bevel_normal(line * k, 1.2 * k + 0.4, ss)
        K.over(img, K.metal(nx, ny, nz, ["#6A3A00", "#E0A000", "#FFE680", "#FFFFFF"]), K.cover(line * k, ss))
        save(img, ss, f"inner_gold_{size}")


ALL = [stickers, family_gems, stat_icons, button_icons, bars, opening_fx, auras, misc, rarity_strips,
       card_backs, stage_marks]


def logo():
    """The 1v1 CARD logo (MISSION 4.4): heavy display letters with a purple-to-pink gradient, a
    thick dark stroke, a gold crown over the "1v1", and a soft violet splash behind."""
    w, h, ss = 1024, 512, 2
    f = K.font("LuckiestGuy-Regular.ttf", 200 * ss)
    top = K.text_mask("1v1", f, w, h, ss, cy=h * 0.36, shear=0.12)
    f2 = K.font("LuckiestGuy-Regular.ttf", 170 * ss)
    bottom = K.text_mask("CARD", f2, w, h, ss, cy=h * 0.74, shear=0.12, tracking=6)
    m = np.clip(top + bottom, 0, 1)
    d = K.distance_outside(m, 30)
    outline = np.clip(1 - (d - 26) / 2.5, 0, 1)
    rim = np.clip(1 - (d - 12) / 2.5, 0, 1)
    x, y = K.grid(w, h, ss)
    img = K.blank(w, h, ss)
    # splash: a soft violet-pink burst behind the letters
    r = np.hypot(x / 1.6, y)
    ang = np.arctan2(y, x)
    burst = np.clip(1 - r / (210 + 40 * np.sin(ang * 9)), 0, 1) ** 1.2
    img[..., :3] = K.hexc("#7B2CFF")
    img[..., 3] = burst * 0.75
    K.add_light(img, K.hexc("#FF5FD2"), np.clip(K.fast_blur(outline, 18 * ss) * 1.4, 0, 1) * 0.8)
    K.over(img, K.hexc(INK), outline)
    K.over(img, K.hexc("#2A0C5E"), rim)
    t = np.clip((y + h * 0.3) / (h * 0.6), 0, 1)[..., None]
    col = K.hexc("#F4E8FF") * (1 - t) ** 3 + (K.hexc("#B46CFF") * (1 - t) + K.hexc("#FF4FB8") * t) * (1 - (1 - t) ** 3)
    K.over(img, np.clip(col, 0, 1), m)
    gloss = m * np.clip((np.abs(y - (-h * 0.14)) < h * 0.05) * 1.0, 0, 1) * 0.0
    K.add_light(img, K.hexc("#FFFFFF"), m * np.clip(1 - np.abs((y + h * 0.2) / (h * 0.05)), 0, 1) * 0.25 + gloss)
    # crown over the "1v1"
    crown = Image.open(os.path.join(KIT, "emblem_crown_gold.png")).convert("RGBA").resize((150 * ss, 150 * ss), Image.LANCZOS)
    out_path = os.path.join(KIT, "logo_1v1card.png")
    K.edge_fade(img, ss, 6)
    K.save(img, ss, out_path)
    out = Image.open(out_path)
    crown = crown.resize((150, 150), Image.LANCZOS).rotate(-12, Image.BICUBIC, expand=True)
    out.alpha_composite(crown, (w // 2 + 150, 10))
    out.save(out_path, optimize=True)


ALL.append(logo)
