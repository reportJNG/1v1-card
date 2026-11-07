"""Final images for the UI kit slots in Config/UiAssets (MISSION 4.3: replace every TEMP stand-in).

  python scripts/art/ui_slots.py [slot ...]     render into art/ui/final/<slot>.png

Each image keeps its slot's size, 9-slice centre and glow bleed (scripts/art/make_temp_ui.py
SPECS), so every screen picks it up without code changes once its uploaded id is in
art/ui/ids.json (`final`) and `make_temp_ui.py luau` has run. Route C (kitlib), drawn at 4x.
Style (MISSION 4.1 / 4.4): navy-violet glass panels with a violet rim and glow, gold primary and
purple-glass secondary buttons with a darker lip and a glossy top, chunky dark outlines.
"""
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import kitlib as K  # noqa: E402
import ui_extras as X  # noqa: E402

OUT = os.path.join(K.ROOT, "art", "ui", "final")
KIT = os.path.join(K.ROOT, "art", "ui", "kit")
INK = "#0B0720"


def save(img, ss, slot):
    K.save(img, ss, os.path.join(OUT, slot + ".png"))
    print("slot", slot, flush=True)


def glass_panel(slot, top, bottom, rim, glow, alpha=1.0, w=256, h=256, bleed=14, r=14):
    ss = 4
    x, y = K.grid(w, h, ss)
    hx, hy = w / 2 - bleed, h / 2 - bleed
    d = K.sd_round_box(x, y, hx, hy, r)
    img = K.blank(w, h, ss)
    K.add_light(img, K.hexc(glow), np.clip(K.fast_blur(K.cover(d, ss), 6 * ss) * 1.4, 0, 1) * 0.65)
    K.over(img, K.hexc(rim), K.cover(d, ss))
    t = np.clip((y + hy) / (2 * hy), 0, 1)[..., None]
    col = K.hexc(top) * (1 - t) + K.hexc(bottom) * t
    K.over(img, col, K.cover(d + 2.2, ss) * alpha)
    # faint inner top highlight
    K.add_light(img, K.hexc("#FFFFFF"), K.cover(np.maximum(d + 3, np.abs(y + hy - 10) - 6), ss) * 0.07)
    save(img, ss, slot)


def button(slot, ramp, w=256, h=96, bleed=8, glossy=True, alpha=1.0):
    """A chunky rounded button: dark outline, vertical gradient, darker bottom lip, glossy top."""
    light, base, deep = (K.hexc(c) for c in ramp)
    ss = 4
    x, y = K.grid(w, h, ss)
    hx, hy = w / 2 - bleed, h / 2 - bleed
    r = hy * 0.9
    d = K.sd_round_box(x, y, hx, hy, r)
    img = K.blank(w, h, ss)
    K.over(img, K.hexc(INK), K.cover(d - 2.5, ss))
    lip = K.sd_round_box(x, y, hx - 1.5, hy - 1.5, r - 1.5)
    K.over(img, deep, K.cover(lip, ss))
    face = K.sd_round_box(x, y - 3, hx - 2.5, hy - 5, r - 3)
    t = np.clip((y + hy) / (2 * hy), 0, 1)[..., None]
    K.over(img, light * (1 - t) + base * t, K.cover(face, ss) * alpha)
    if glossy:
        gloss = K.sd_round_box(x, y + hy * 0.45, hx - 12, hy * 0.28, hy * 0.25)
        K.add_light(img, K.hexc("#FFFFFF"), K.cover(gloss, ss) * 0.3)
    save(img, ss, slot)


def pill(slot, rim, fill, w, h, bleed=4, alpha=0.92, glow=None):
    ss = 4
    x, y = K.grid(w, h, ss)
    hx, hy = w / 2 - bleed, h / 2 - bleed
    d = K.sd_round_box(x, y, hx, hy, hy)
    img = K.blank(w, h, ss)
    if glow:
        K.add_light(img, K.hexc(glow), np.clip(K.fast_blur(K.cover(d, ss), 3 * ss) * 1.3, 0, 1) * 0.6)
    K.over(img, K.hexc(rim), K.cover(d, ss))
    t = np.clip((y + hy) / (2 * hy), 0, 1)[..., None]
    K.over(img, K.hexc(fill) * (1.2 - 0.5 * t), K.cover(d + 2.5, ss) * alpha)
    save(img, ss, slot)


def from_kit(slot, src, size):
    im = Image.open(os.path.join(KIT, src + ".png")).convert("RGBA").resize(size, Image.LANCZOS)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, slot + ".png"), optimize=True)
    print("slot", slot, "(from kit", src + ")", flush=True)


def round_icon_button(slot, ramp, glyph_slot):
    """Battle action art: a chunky round button with a stat icon on it."""
    light, base, deep = ramp
    w, ss = 192, 4
    x, y = K.grid(w, w, ss)
    d = K.sd_circle(x, y, 0, 0, 84)
    img = K.blank(w, w, ss)
    K.add_light(img, K.hexc(base), np.clip(K.fast_blur(K.cover(d, ss), 5 * ss) * 1.4, 0, 1) * 0.6)
    K.over(img, K.hexc(INK), K.cover(d - 4, ss))
    nx, ny, nz, _ = K.bevel_normal(d, 10, ss)
    K.over(img, K.metal(nx, ny, nz, [deep, base, light, "#FFFFFF"], y=y / 84, sheen=0.3, spec=12), K.cover(d, ss))
    K.add_light(img, K.hexc("#FFFFFF"), K.cover(K.sd_round_box(x, y + 46, 50, 16, 14), ss) * 0.16)
    out = os.path.join(OUT, slot + ".png")
    K.save(img, ss, out)
    base_im = Image.open(out)
    glyph = Image.open(os.path.join(KIT, glyph_slot + ".png")).convert("RGBA").resize((112, 112), Image.LANCZOS)
    base_im.alpha_composite(glyph, (40, 38))
    base_im.save(out, optimize=True)
    print("slot", slot, flush=True)


def vs_badge():
    w, h, ss = 256, 160, 4
    f = K.font("LuckiestGuy-Regular.ttf", 132 * ss)
    m = K.text_mask("VS", f, w, h, ss, cy=h * 0.55, shear=0.15)
    d = K.distance_outside(m, 40)
    outline = np.clip(1 - (d - 30) / 4, 0, 1)
    img = K.blank(w, h, ss)
    img[..., :3] = K.hexc("#FF5A1F")
    img[..., 3] = np.clip(K.fast_blur(outline, 10 * ss) * 1.6, 0, 1) * 0.9
    K.over(img, K.hexc(INK), outline)
    ys = np.broadcast_to(np.linspace(0, 1, h * ss, dtype=np.float32)[:, None], m.shape)
    t = np.clip((ys - 0.2) / 0.65, 0, 1)[..., None]
    col = K.hexc("#FFF2A0") * (1 - t) ** 2 + K.hexc("#FF9A1F") * (2 * t * (1 - t)) + K.hexc("#E8231C") * t ** 2
    K.over(img, np.clip(col, 0, 1), m)
    K.edge_fade(img, ss, 3)
    save(img, ss, "vs_badge")


def banner(slot, win):
    """Winged banner: a ribbon with wings either side and a crown (Victory) or a plain steel one
    (Defeat). The word is drawn on top in code."""
    w, h, ss = 1024, 384, 2
    x, y = K.grid(w, h, ss)
    ribbon = K.sd_round_box(x, y + 20, 330, 70, 24)
    tails = np.maximum(K.union(K.sd_box(x - 390, y + 40, 80, 50), K.sd_box(x + 390, y + 40, 80, 50)),
                       -K.union(K.sd_rhombus(x - 470, y + 40, 30, 50), K.sd_rhombus(x + 470, y + 40, 30, 50)))
    wings = []
    for sgn in (-1, 1):
        for k in range(4):
            wings.append(K.sd_blade(x, y, (sgn * 300, -10), (sgn * (420 + k * 20), -120 + k * 34), 34 - k * 4, 6))
    wing = K.union(*wings)
    ramp_main = ["#5A3000", "#E0A000", "#FFE680", "#FFFFFF"] if win else ["#1E2638", "#5A6A86", "#C8D4E8", "#FFFFFF"]
    ramp_dark = ["#3A1A00", "#A86A00", "#F0C040", "#FFF4C0"] if win else ["#10141E", "#3A4458", "#8E9AB2", "#E0E8F4"]
    img = K.blank(w, h, ss)
    glow = "#FFB01E" if win else "#7FA8D8"
    K.add_light(img, K.hexc(glow), np.clip(K.fast_blur(K.cover(K.union(ribbon, wing), ss), 18 * ss), 0, 1) * 0.7)
    for part, ramp in ((wing, ramp_dark), (tails, ramp_dark), (ribbon, ramp_main)):
        K.over(img, K.hexc(INK), K.cover(part - 5, ss))
        nx, ny, nz, _ = K.bevel_normal(part, 8, ss)
        K.over(img, K.metal(nx, ny, nz, ramp, y=y / 100, sheen=0.3, spec=14), K.cover(part, ss))
    inner = K.sd_round_box(x, y + 20, 310, 52, 18)
    K.over(img, K.hexc("#2A0C5E" if win else "#141A28"), K.cover(inner, ss) * 0.85)
    K.edge_fade(img, ss, 4)
    out = os.path.join(OUT, slot + ".png")
    K.save(img, ss, out)
    if win:
        im = Image.open(out)
        crown = Image.open(os.path.join(KIT, "emblem_crown_gold.png")).convert("RGBA").resize((180, 180), Image.LANCZOS)
        im.alpha_composite(crown, ((w - 180) // 2, 0))
        im.save(out, optimize=True)
    print("slot", slot, flush=True)


FAMILY_GLYPHS = {}


def glyph(name):
    def deco(fn):
        FAMILY_GLYPHS[name] = fn
        return fn
    return deco


@glyph("flame")
def _flame(x, y):
    return K.smooth_union(K.sd_circle(x, y, 0, 18, 30), X.poly_sdf([(-26, 14), (0, -52), (26, 14)], 128, 128, 4), 10)


@glyph("ice")
def _ice(x, y):
    arms = [K.sd_blade(x, y, (0, 0), (46 * math.cos(a), 46 * math.sin(a)), 6, 4) for a in np.arange(6) * math.pi / 3]
    return K.union(*arms, K.sd_circle(x, y, 0, 0, 10))


@glyph("lightning")
def _lightning(x, y):
    return X.bolt_shape(x, y)


@glyph("shadow")
def _shadow(x, y):
    return np.maximum(K.sd_circle(x, y, 0, 0, 44), -K.sd_circle(x, y, 18, -12, 38))


@glyph("divine")
def _divine(x, y):
    return K.union(K.sd_ring(x, y, 0, -30, 26, 8), K.sd_star(x, y, 0, 16, 34, 0.45))


@glyph("beast")
def _beast(x, y):
    toes = [K.sd_circle(x, y, cx, cy, 11) for cx, cy in ((-28, -16), (-10, -34), (10, -34), (28, -16))]
    return K.union(K.sd_round_box(x, y - 18, 26, 20, 14), *toes)


@glyph("dragon")
def _dragon(x, y):
    claws = [K.sd_blade(x, y, (-30 + i * 30, 40), (-20 + i * 30, -44), 9, 2) for i in range(3)]
    return K.union(*claws)


@glyph("warrior")
def _warrior(x, y):
    return X.sword(x, y)


@glyph("ninja")
def _ninja(x, y):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = 50 if i % 2 == 0 else 14
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return np.maximum(X.poly_sdf(pts, 128, 128, 4), -K.sd_circle(x, y, 0, 0, 7))


@glyph("royal")
def _royal(x, y):
    return X.poly_sdf([(-44, 30), (44, 30), (48, -26), (22, 0), (0, -40), (-22, 0), (-48, -26)], 128, 128, 4) - 2


@glyph("cosmic")
def _cosmic(x, y):
    planet = K.sd_circle(x, y, 0, 0, 24)
    ring = np.abs(np.hypot(x / 1.0, (y + x * 0.3) / 0.38) - 48) - 4
    return K.union(planet, np.maximum(ring, -(planet - 4)))


@glyph("ancient")
def _ancient(x, y):
    return K.union(K.sd_box(x, y, 34, 6), K.sd_box(x - 22, y - 2, 6, 44), K.sd_box(x + 22, y - 2, 6, 44), K.sd_box(x, y + 44, 44, 6), K.sd_box(x, y - 46, 44, 6))


@glyph("mystic")
def _mystic(x, y):
    return X.poly_sdf([(0, -54), (30, 0), (0, 54), (-30, 0)], 128, 128, 4)


@glyph("spirit")
def _spirit(x, y):
    body = K.smooth_union(K.sd_circle(x, y, 0, -12, 28), X.poly_sdf([(-28, -6), (28, -6), (10, 50)], 128, 128, 4), 10)
    eyes = K.union(K.sd_circle(x, y, -10, -16, 5), K.sd_circle(x, y, 10, -16, 5))
    return np.maximum(body, -eyes)


@glyph("demon")
def _demon(x, y):
    horns = K.union(K.sd_blade(x, y, (-20, 0), (-40, -50), 12, 2), K.sd_blade(x, y, (20, 0), (40, -50), 12, 2))
    return K.union(horns, K.sd_circle(x, y, 0, 16, 28))


def family_icons():
    w, ss = 128, 4
    for name, fn in FAMILY_GLYPHS.items():
        x, y = K.grid(w, w, ss)
        d = fn(x, y)
        img = K.blank(w, w, ss)
        img[..., :3] = 1
        img[..., 3] = K.cover(d, ss)
        # a soft dark rim so the white glyph reads on light gems
        K.over(img, K.hexc("#20123A"), K.cover(d - 3, ss) * (1 - K.cover(d, ss)) * 0.6)
        K.edge_fade(img, ss, 2)
        save(img, ss, f"family_{name}")


def all_slots():
    glass_panel("panel", "#1B1640", "#0E0B26", "#8B5CF6", "#7B3CFF")
    glass_panel("panel_light", "#33307A", "#1C2058", "#B9A8FF", "#8FB8FF", alpha=0.82)
    # header strip: lighter than the panel, a glowing line along the bottom
    ss = 4
    w, h = 512, 88
    x, y = K.grid(w, h, ss)
    d = K.sd_round_box(x, y, 252, 40, 14)
    img = K.blank(w, h, ss)
    t = np.clip((y + 40) / 80, 0, 1)[..., None]
    K.over(img, K.hexc("#3A2C86") * (1 - t) + K.hexc("#1E1650") * t, K.cover(d, ss) * 0.92)
    K.add_light(img, K.hexc("#B98CFF"), K.cover(np.abs(y - 39) - 1, ss) * (np.abs(x) < 240) * 0.9)
    save(img, ss, "panel_header")
    w = 128
    x, y = K.grid(w, w, ss)
    d = K.sd_round_box(x, y, 60, 60, 12)
    img = K.blank(w, w, ss)
    K.over(img, K.hexc("#07051A"), K.cover(d, ss) * 0.7)
    K.over(img, K.hexc("#05040F"), K.cover(np.maximum(d, -(d + 6)), ss) * 0.4)
    K.add_light(img, K.hexc("#6A4ACF"), K.cover(np.abs(d) - 0.8, ss) * 0.6)
    save(img, ss, "panel_inset")
    x, y = K.grid(w, w, ss)
    d = K.sd_round_box(x, y, 40, 40, 16)
    img = K.blank(w, w, ss)
    img[..., :3] = 0
    img[..., 3] = np.clip(K.fast_blur(K.cover(d, ss), 10 * ss), 0, 1) * 0.75
    save(img, ss, "shadow")
    # close button: dark circle, white X, a subtle red glow
    w = 96
    x, y = K.grid(w, w, ss)
    d = K.sd_circle(x, y, 0, 0, 40)
    img = K.blank(w, w, ss)
    K.add_light(img, K.hexc("#FF3D5A"), np.clip(K.fast_blur(K.cover(d, ss), 4 * ss) * 1.3, 0, 1) * 0.45)
    K.over(img, K.hexc("#D8D0FF"), K.cover(d, ss))
    K.over(img, K.hexc("#1A1238"), K.cover(d + 3, ss))
    xx = K.union(K.sd_blade(x, y, (-14, -14), (14, 14), 5, 5), K.sd_blade(x, y, (-14, 14), (14, -14), 5, 5))
    K.over(img, K.hexc("#FFFFFF"), K.cover(xx, ss))
    save(img, ss, "close_button")
    button("button_primary", ["#FFE680", "#F59E0B", "#9A4E00"])
    button("button_secondary", ["#B98CFF", "#6A2FD8", "#2E0F7A"])
    button("button_robux", ["#9CF27A", "#2FAE4A", "#0E5A20"])
    button("button_danger", ["#FF9A8A", "#E2343C", "#7A0E18"])
    from_kit("button_plus", "plus_gold", (64, 64))
    pill("tab_on", "#E0C8FF", "#7B3CFF", 192, 64, 6, glow="#B45CFF")
    pill("tab_off", "#4A3C86", "#1A1440", 192, 64, 6)
    # tiles: dark gradient with a rim; selected: gold rim, glow and corner sparkles
    for slot, rim, glow in (("tile", "#5A4AA8", None), ("tile_selected", "#FFD24A", "#FFB01E")):
        w = 128
        x, y = K.grid(w, w, ss)
        bleed = 6 if glow else 4
        d = K.sd_round_box(x, y, 64 - bleed, 64 - bleed, 14)
        img = K.blank(w, w, ss)
        if glow:
            K.add_light(img, K.hexc(glow), np.clip(K.fast_blur(K.cover(d, ss), 4 * ss) * 1.5, 0, 1) * 0.8)
        K.over(img, K.hexc(rim), K.cover(d, ss))
        t = np.clip((y + 58) / 116, 0, 1)[..., None]
        K.over(img, K.hexc("#2A2266") * (1 - t) + K.hexc("#100C2C") * t, K.cover(d + 2.5, ss))
        if glow:
            for cx, cy in ((-48, -48), (48, 48)):
                star = np.exp(-np.abs(x - cx) / 1.2) * np.exp(-np.abs(y - cy) / 8) + np.exp(-np.abs(y - cy) / 1.2) * np.exp(-np.abs(x - cx) / 8)
                K.add_light(img, K.hexc("#FFFFFF"), np.clip(star, 0, 1))
        save(img, ss, slot)
    glass_panel("toast", "#2A2470", "#14103A", "#9B7BFF", "#7B3CFF", w=512, h=72, bleed=6, r=24)
    pill("reward_chip", "#FFC23A", "#3A2408", 256, 72, 4, glow="#FFB01E")
    # card back (512 x 716): the kit's purple back, scaled to the old slot
    from_kit("card_back", "card_back_sr", (512, 716))
    # card shine: a soft white diagonal strip
    w, h = 256, 716
    x, y = K.grid(w, h, 2)
    img = K.blank(w, h, 2)
    img[..., :3] = 1
    img[..., 3] = np.exp(-(x / 40) ** 2) * 0.85 + np.exp(-(x / 12) ** 2) * 0.4
    save(img, 2, "card_shine")
    x, y = K.grid(256, 256, 2)
    img = K.blank(256, 256, 2)
    img[..., :3] = 1
    img[..., 3] = np.clip(1 - np.hypot(x, y) / 128, 0, 1) ** 2
    save(img, 2, "egg_glow")
    from_kit("light_rays", "light_rays", (512, 512))
    from_kit("sparkle", "fx_sparkle", (64, 64))
    from_kit("crack_overlay", "crack_overlay_2", (256, 256))
    # battle: timer ring track, energy pips, HP bar, action buttons, VS badge
    x, y = K.grid(256, 256, ss)
    d = K.sd_ring(x, y, 0, 0, 110, 18)
    img = K.blank(256, 256, ss)
    K.over(img, K.hexc(INK), K.cover(d - 3, ss))
    K.over(img, K.hexc("#241A52"), K.cover(d, ss))
    save(img, ss, "timer_ring_bg")
    for on in (True, False):
        x, y = K.grid(64, 64, ss)
        d = K.sd_rhombus(x, y, 22, 28)
        img = K.blank(64, 64, ss)
        if on:
            K.add_light(img, K.hexc("#FFC020"), np.clip(K.fast_blur(K.cover(d, ss), 3 * ss) * 1.5, 0, 1))
            dd, col = K.gem(x, y, 0, 0, 22, 28, ["#8A5400", "#F5B414", "#FFE680", "#FFFFFF"])
        else:
            dd, col = K.gem(x, y, 0, 0, 22, 28, ["#140E30", "#2A2258", "#3E3478", "#5A4C9E"])
        K.over(img, K.hexc(INK), K.cover(dd - 2.5, ss))
        K.over(img, col, K.cover(dd, ss))
        save(img, ss, "energy_pip_on" if on else "energy_pip_off")
    x, y = K.grid(512, 48, ss)
    d = K.sd_round_box(x, y, 252, 20, 20)
    img = K.blank(512, 48, ss)
    K.over(img, K.hexc(INK), K.cover(d - 2, ss))
    K.over(img, K.hexc("#8B7ACF"), K.cover(d, ss))
    K.over(img, K.hexc("#0A0820"), K.cover(d + 2.5, ss))
    save(img, ss, "hp_frame")
    img = K.blank(512, 48, ss)
    d = K.sd_round_box(x, y, 248, 16, 16)
    t = np.clip((y + 16) / 32, 0, 1)[..., None]
    K.over(img, K.hexc("#FFFFFF") * (1 - t) + K.hexc("#B8B0D8") * t, K.cover(d, ss))
    K.add_light(img, K.hexc("#FFFFFF"), K.cover(K.sd_round_box(x, y + 8, 240, 3, 3), ss) * 0.6)
    save(img, ss, "hp_fill")
    round_icon_button("action_attack", ["#FF8A7A", "#E2343C", "#7A0E18"], "icon_atk")
    round_icon_button("action_defend", ["#8CC8FF", "#2F86FF", "#123F9E"], "icon_def")
    round_icon_button("action_special", ["#D6A8FF", "#8B3DF0", "#3E0C8A"], "icon_energy")
    vs_badge()
    # petal and portal swirl
    x, y = K.grid(64, 64, ss)
    d = np.maximum(K.sd_circle(x, y, -8, 0, 22), K.sd_circle(x, y, 8, 0, 22))
    img = K.blank(64, 64, ss)
    t = np.clip((x + 20) / 40, 0, 1)[..., None]
    K.over(img, K.hexc("#FFD0E8") * (1 - t) + K.hexc("#FF8AC8") * t, K.cover(d, ss))
    save(img, ss, "petal")
    x, y = K.grid(512, 512, 2)
    r = np.hypot(x, y)
    a = np.arctan2(y, x)
    sw = np.clip(np.cos(a * 3 + r / 18) * 1.6 - 0.2, 0, 1) * np.clip(1 - r / 250, 0, 1) + np.clip(1 - r / 70, 0, 1)
    img = K.blank(512, 512, 2)
    img[..., :3] = K.hexc("#E8D8FF")
    img[..., 3] = np.clip(sw, 0, 1)
    K.edge_fade(img, 2, 6)
    save(img, 2, "portal_swirl")
    banner("banner_victory", True)
    banner("banner_defeat", False)
    family_icons()


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    all_slots()
