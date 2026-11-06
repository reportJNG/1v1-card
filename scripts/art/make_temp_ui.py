"""Generates the UI image list (art/ui/PROMPTS.md) and the TEMPORARY stand-in images
(art/ui/temp/TEMP_<slot>.png) from one spec table, so the list, the stand-ins and the
Luau config (src/shared/Config/UiAssets.luau, slice data) can't drift apart.

  python scripts/art/make_temp_ui.py            # write PROMPTS.md + every TEMP png
  python scripts/art/make_temp_ui.py prompts    # PROMPTS.md only
  python scripts/art/make_temp_ui.py <slot>...  # just these TEMP pngs

The stand-ins follow docs/ART_STYLE.md (palette, radii, glow) so screens can be laid out for
real, but they are flat vector drawings, not final art. The owner generates the final images
from the prompts into art/ui/<slot>.png at the same size and slice margins.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import (Canvas, cover, hex_rgb, mix, ramp, sd_circle, sd_polygon, sd_round_rect,  # noqa: E402
                 sd_segment, smooth)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "ui")
TEMP = os.path.join(OUT, "temp")

H = hex_rgb
NIGHT, PANEL, PANEL_DEEP, RAISED, RAISED_HI, STROKE = (H(x) for x in (
    "#05070F", "#12192E", "#0C1124", "#1A2340", "#243058", "#2A3760"))
PURPLE, VIOLET, BLUE, PINK = H("#A469FF"), H("#7B3CFF"), H("#45BEFF"), H("#FF7BD5")
GOLD, GOLD_HI, GOLD_LO, GOLD_INK = H("#FFC54B"), H("#FFE27A"), H("#E08A00"), H("#3A2200")
GREEN, RED, TEXT, MUTED, WHITE = H("#48DA97"), H("#FF668F"), H("#F2F5FF"), H("#9EAED3"), (1, 1, 1)
RARITY = {
    "Common": [H("#E4ECF7"), H("#B9C7DC"), H("#7F8BA0")],
    "Rare": [H("#A8E4FF"), H("#45BEFF"), H("#1E6FB8")],
    "Epic": [H("#D9BCFF"), H("#A469FF"), H("#6A35C9")],
    "Legendary": [H("#FFF1B8"), H("#FFC54B"), H("#B8791A")],
    "Mythical": [H("#FF9BB8"), H("#FF668F"), H("#A469FF"), H("#45BEFF")],
}

STYLE = ("Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan "
         "glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a "
         "fully transparent background, no text, no letters, no watermark, no logo")

# ------------------------------------------------------------------------------ the image list
# slot, (w, h), slice (left, top, right, bottom) or None, bleed (glow outside the visual box, px),
# use, prompt. Sizes are the exact pixel sizes to generate; all <= 1024 px.
SPECS = []


def spec(slot, size, slice_, bleed, use, prompt, group):
    SPECS.append(dict(slot=slot, size=size, slice=slice_, bleed=bleed, use=use, prompt=prompt, group=group))


spec("panel", (256, 256), (56, 56, 200, 200), 14, "Every popup panel body (9-slice)",
     "a square game UI panel frame, rounded corners (radius ~18 px), body is a vertical gradient from "
     "#12192E to #0C1124, a 2-3 px glowing border fading from neon purple #A469FF (top-left) to cyan "
     "#45BEFF (bottom-right), soft purple outer glow 14 px wide, subtle inner top highlight; the centre must be "
     "plain so it can be 9-sliced", "Panels")
spec("panel_header", (512, 88), (40, 40, 472, 48), 0, "Title bar strip at the top of a panel (9-slice)",
     "a wide title bar strip for the top of a game panel, rounded top corners only, slightly lighter navy "
     "#1A2340 fading downwards to transparent, thin bright cyan-to-purple glowing line along the bottom edge",
     "Panels")
spec("panel_inset", (128, 128), (28, 28, 100, 100), 0, "Recessed area inside a panel (lists, odds table)",
     "a recessed inset area for a game UI, rounded corners radius 12, very dark navy #0A0F20 with a faint inner "
     "shadow at the top and a 1 px #2A3760 hairline border", "Panels")
spec("shadow", (128, 128), (48, 48, 80, 80), 24, "Soft drop shadow behind floating panels (9-slice)",
     "a soft blurred black drop shadow of a rounded rectangle, 24 px blur, 50% opacity, nothing else",
     "Panels")
spec("close_button", (96, 96), None, 6, "Round close button (top-right of every panel)",
     "a round close button for a game UI, dark navy circle #1A2340 with a glossy top highlight, thin "
     "pink-white glowing rim, a bold white X in the centre", "Buttons")
spec("button_primary", (256, 96), (44, 44, 212, 52), 8, "Gold primary action button (Buy, Find Match, Save Deck)",
     "a glossy gold game button, rounded rectangle radius ~22 px, vertical gradient from bright yellow "
     "#FFE27A through #FFC54B to deep orange-gold #E08A00, a light bevel along the top edge, a darker 6 px lip "
     "along the bottom, soft warm outer glow; blank, no text", "Buttons")
spec("button_secondary", (256, 96), (44, 44, 212, 52), 8, "Secondary button (Odds, Merge, Back)",
     "a game UI secondary button, rounded rectangle radius ~22 px, dark navy body #1A2340 with a slight top "
     "highlight, 2 px glowing cyan #45BEFF border, soft cyan outer glow; blank, no text", "Buttons")
spec("button_robux", (256, 96), (44, 44, 212, 52), 8, "Robux egg button (shown only when allowed)",
     "a game UI button, rounded rectangle radius ~22 px, deep teal-green gradient body #1F8F6A to #136B4E, "
     "2 px bright mint #48DA97 border, soft green glow; blank, no text", "Buttons")
spec("button_danger", (256, 96), (44, 44, 212, 52), 8, "Danger button (Forfeit, Leave queue)",
     "a game UI button, rounded rectangle radius ~22 px, dark navy body with a 2 px glowing pink-red #FF668F "
     "border and a soft red glow; blank, no text", "Buttons")
spec("button_plus", (64, 64), None, 4, "Small gold + next to the Coins and Gems badges",
     "a small square glossy gold game button with rounded corners radius 12, a bold dark-brown plus sign in "
     "the centre", "Buttons")
spec("tab_on", (192, 64), (28, 28, 164, 36), 6, "Selected tab / selected left-menu item",
     "a selected tab for a game menu, rounded rectangle radius 14, glowing purple gradient #A469FF to "
     "#7B3CFF, bright 2 px light-violet border and soft purple glow; blank", "Buttons")
spec("tab_off", (192, 64), (28, 28, 164, 36), 6, "Unselected tab / left-menu item",
     "an unselected tab for a game menu, rounded rectangle radius 14, dark translucent navy #12192E at 80% "
     "opacity with a faint 1 px #2A3760 border; blank", "Buttons")
spec("menu_item", (256, 64), (36, 28, 220, 36), 4, "Left menu row background (Play, Cards, Deck...)",
     "a left-side game menu row, a dark translucent navy bar that fades out to the right, rounded left end, "
     "faint purple hairline along the top and bottom; blank", "Buttons")
spec("currency_badge", (320, 72), (36, 36, 284, 36), 4, "Coins / Gems counter pill in the top bar",
     "a horizontal pill-shaped counter badge for a game HUD, very dark navy #0A0F20 at 85% opacity, thin 2 px "
     "border with a soft gold glow, glossy top edge; blank, no text", "HUD")
spec("tile", (128, 128), (32, 32, 96, 96), 4, "Grid slot: eggs, cards, items (9-slice)",
     "a square inventory slot tile for a game UI, rounded radius 12, navy gradient #1A2340 to #12192E, 1-2 px "
     "cyan-blue glowing border, faint inner top highlight; blank", "HUD")
spec("tile_selected", (128, 128), (32, 32, 96, 96), 6, "Selected grid slot",
     "a selected square slot tile for a game UI, rounded radius 12, navy body, bright 3 px gold #FFC54B "
     "glowing border with a soft gold outer glow; blank", "HUD")
spec("toast", (512, 72), (36, 36, 476, 36), 6, "Notification toast",
     "a wide notification pill for a game UI, dark navy body at 90% opacity, thin cyan glowing border; blank",
     "HUD")

for r in ["Common", "Rare", "Epic", "Legendary", "Mythical"]:
    look = {
        "Common": "a single clean silver #B9C7DC border, no glow",
        "Rare": "a cyan #45BEFF border with a soft blue inner glow and small corner studs",
        "Epic": "a double violet #A469FF border with a purple glow and faceted corner gems",
        "Legendary": "an ornate double gold #FFC54B border with engraved corner filigree, warm glow and a light "
                     "sheen",
        "Mythical": "an iridescent border shifting pink #FF668F to violet #A469FF to cyan #45BEFF, ornate "
                    "corners, sparkles and a strong glow",
    }[r]
    spec(f"card_frame_{r.lower()}", (512, 716), None, 0, f"{r} card frame overlay (art shows through the middle)",
         f"a trading card frame for an anime card game, portrait 5:7, {look}; the inside of the frame is "
         "completely transparent (a window for character art), a dark gradient name plate along the bottom 18%, a "
         "small blank plate in the top-left corner for the rarity word, a small round blank badge in the top-right "
         "for the family icon; same frame geometry as the other rarities, only colours and ornament differ",
         "Cards")
spec("card_golden_foil", (512, 716), None, 0, "Golden copy foil overlay (on top of any frame)",
     "a transparent overlay for a trading card: thin diagonal gold foil sheen streaks and a gold inner edge "
     "glow, mostly transparent so the card shows through", "Cards")
spec("card_back", (512, 716), None, 0, "Card back (hatch flip, face-down cards)",
     "the back of a trading card, portrait 5:7, deep navy with a symmetrical neon purple and cyan geometric "
     "mandala pattern, a glowing central emblem medallion, gold rim; no text", "Cards")
spec("card_shine", (256, 716), None, 0, "Light sweep strip animated across Legendary/Mythical cards",
     "a tall soft diagonal white light streak on a transparent background, feathered edges", "Cards")
spec("egg_pedestal", (512, 256), None, 0, "Pedestal under the featured egg in the shop and hatch",
     "a glowing circular stone pedestal seen from a 3/4 angle, dark navy stone with neon purple rune rim, "
     "soft light rays rising from it, magical", "Eggs")
spec("egg_glow", (256, 256), None, 0, "Rarity-tinted glow behind eggs (tinted in code)",
     "a soft round white glow, radial falloff, transparent edges", "Eggs")
spec("light_rays", (512, 512), None, 0, "Rotating light rays behind the hatch reveal and Victory",
     "radial light rays bursting from the centre, white, soft edges, transparent background", "Eggs")
spec("sparkle", (64, 64), None, 0, "Sparkle particle (hatch, Mythical cards)",
     "a single four-pointed white sparkle star with a soft glow", "Eggs")
spec("crack_overlay", (256, 256), None, 0, "Crack lines drawn over the egg during hatching",
     "glowing white crack lines in a zig-zag pattern, transparent background, no egg", "Eggs")

ICONS = {
    "icon_play": "two crossed swords, gold and white",
    "icon_cards": "a fan of three trading cards, purple and gold",
    "icon_deck": "a stack of cards with a shield emblem, cyan and white",
    "icon_shop": "a magical egg in a shopping basket, purple and gold",
    "icon_quests": "a rolled parchment scroll with a ribbon, gold and cream",
    "icon_worlds": "a glowing planet globe with a ring, cyan and green",
    "icon_settings": "a gear cog, silver with a cyan core",
    "icon_gift": "a gift box with a bow, pink and gold",
    "icon_calendar": "a calendar page with a star, white and purple",
    "icon_friends": "two person silhouettes, white with cyan",
    "icon_coin": "a shiny gold coin with a star engraving",
    "icon_gem": "a faceted blue diamond gem",
    "icon_trophy": "a gold trophy cup",
    "icon_power": "a gold sword pointing up-right, power stat icon",
    "icon_lock": "a closed padlock, steel grey",
    "icon_check": "a bold green check mark in a circle",
    "icon_energy": "a glowing cyan lightning-shaped energy crystal",
    "icon_hp": "a red heart",
    "icon_odds": "a percent sign on a small purple badge",
    "icon_search": "a magnifying glass, white",
}
for slot, what in ICONS.items():
    spec(slot, (128, 128), None, 0, f"Icon: {slot[5:]}",
         f"a game UI icon of {what}, chunky stylised shape with a dark navy 4 px outline, soft cel shading, "
         "small highlight, centred with 8 px margin", "Icons")

spec("timer_ring_bg", (256, 256), None, 0, "12 s pick timer ring (track)",
     "a thick circular ring, dark navy #12192E with a faint purple inner edge, transparent centre", "Battle")
spec("timer_ring_fill", (256, 256), None, 0, "12 s pick timer ring (fill, cropped radially in code)",
     "a thick circular ring in solid white with a soft glow, transparent centre (tinted in code)", "Battle")
spec("energy_pip_on", (64, 64), None, 0, "Energy pip, filled (max 5)",
     "a small glowing cyan diamond crystal, bright core", "Battle")
spec("energy_pip_off", (64, 64), None, 0, "Energy pip, empty",
     "a small empty diamond crystal socket, dark navy with a thin grey-blue outline", "Battle")
spec("hp_frame", (512, 48), (24, 24, 488, 24), 0, "HP bar frame (9-slice)",
     "a horizontal health bar frame, rounded ends, dark navy inside, thin light border, glossy; empty", "Battle")
spec("hp_fill", (512, 48), (24, 24, 488, 24), 0, "HP bar fill (tinted green/gold/red in code)",
     "a horizontal health bar fill, rounded ends, white with a lighter top half and soft bottom shade "
     "(tinted in code)", "Battle")
spec("action_attack", (192, 192), None, 0, "Attack action button art",
     "a round action button for a card battle, red-orange glowing rim, a bold sword slash symbol", "Battle")
spec("action_defend", (192, 192), None, 0, "Defend action button art",
     "a round action button for a card battle, cyan glowing rim, a bold shield symbol", "Battle")
spec("action_special", (192, 192), None, 0, "Special action button art",
     "a round action button for a card battle, purple-pink glowing rim, a bold star-burst symbol", "Battle")
spec("vs_badge", (256, 160), None, 0, "VS badge between the two decks",
     "the letters V and S as a fiery gold and red emblem with lightning, bold anime game style", "Battle")
spec("banner_victory", (1024, 384), None, 0, "Victory banner (text 'Victory!' is drawn on top in code)",
     "a golden winged banner with a crown on top, ornate gold ribbon across the middle left blank for a word, "
     "light glow behind, anime game victory screen style", "Results")
spec("banner_defeat", (1024, 384), None, 0, "Defeat banner (text drawn on top in code)",
     "a torn dark steel-blue ribbon banner with cracked edges, muted grey and navy, left blank for a word, "
     "somber game defeat screen style", "Results")
spec("reward_chip", (256, 72), (36, 36, 220, 36), 4, "Reward pill on the results screen (+Coins, +Trophies)",
     "a horizontal pill-shaped reward chip, dark navy body, soft gold border glow; blank", "Results")


# ------------------------------------------------------------------------------ drawing


def glow_rect(c, cx, cy, hw, hh, r, col, width, strength=0.55):
    def f(x, y):
        d = sd_round_rect(x, y, cx, cy, hw, hh, r)
        if d <= 0:
            return None
        return col, strength * math.exp(-d / (width / 2.5)) * smooth(width * 1.2, 0, d)
    c.shade(f, mode="add")


def fill_rect(c, cx, cy, hw, hh, r, colfn, alpha=1.0):
    def f(x, y):
        a = cover(sd_round_rect(x, y, cx, cy, hw, hh, r))
        if a <= 0:
            return None
        return colfn(x, y), a * alpha
    c.shade(f, (cx - hw - 1, cy - hh - 1, cx + hw + 1, cy + hh + 1))


def ring_rect(c, cx, cy, hw, hh, r, th, colfn, alpha=1.0):
    def f(x, y):
        d = sd_round_rect(x, y, cx, cy, hw, hh, r)
        a = cover(abs(d + th / 2) - th / 2)
        if a <= 0:
            return None
        return colfn(x, y), a * alpha
    c.shade(f, (cx - hw - 2, cy - hh - 2, cx + hw + 2, cy + hh + 2))


def vgrad(stops, y0, y1):
    return lambda x, y: ramp(stops, (y - y0) / max(1, y1 - y0))


def diag(c1, c2, w, h):
    return lambda x, y: mix(c1, c2, max(0, min(1, (x / w + y / h) / 2)))


def draw_panel(c, w, h, bleed):
    cx, cy, hw, hh, r = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 18
    glow_rect(c, cx, cy, hw, hh, r, PURPLE, bleed, 0.5)
    fill_rect(c, cx, cy, hw, hh, r, vgrad([(0, PANEL), (1, PANEL_DEEP)], bleed, h - bleed), 0.97)
    # inner top highlight
    fill_rect(c, cx, bleed + 20, hw - 6, 14, 12, lambda x, y: WHITE, 0.035)
    ring_rect(c, cx, cy, hw, hh, r, 2.6, diag(PURPLE, BLUE, w, h))
    ring_rect(c, cx, cy, hw - 3, hh - 3, r - 3, 1, lambda x, y: WHITE, 0.08)


def draw_header(c, w, h):
    def f(x, y):
        d = sd_round_rect(x, y, w / 2, h / 2 + 10, w / 2, h / 2 + 10, 18)
        a = cover(d)
        if a <= 0 or y > h:
            return None
        t = y / h
        return RAISED, a * (0.9 * (1 - t) ** 1.4)
    c.shade(f)

    def line(x, y):
        d = abs(y - (h - 3)) - 1.0
        edge = smooth(0, 60, min(x, w - x))
        a = cover(d) * edge
        g = math.exp(-abs(y - (h - 3)) / 3) * 0.45 * edge
        return mix(BLUE, PURPLE, x / w), max(a, g)
    c.shade(line, (0, h - 14, w, h), mode="add")


def draw_inset(c, w, h):
    fill_rect(c, w / 2, h / 2, w / 2 - 1, h / 2 - 1, 12, vgrad([(0, H("#070B18")), (1, H("#0B1124"))], 0, h), 0.92)
    ring_rect(c, w / 2, h / 2, w / 2 - 1, h / 2 - 1, 12, 1, lambda x, y: STROKE)


def draw_shadow(c, w, h, bleed):
    def f(x, y):
        d = sd_round_rect(x, y, w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 16)
        return NIGHT, 0.55 * (1 - smooth(-6, bleed, d))
    c.shade(f)


def draw_button(c, w, h, bleed, kind):
    cx, cy, hw, hh, r = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 22
    if kind == "primary":
        glow_rect(c, cx, cy, hw, hh, r, GOLD, bleed, 0.45)
        fill_rect(c, cx, cy, hw, hh, r, lambda x, y: GOLD_LO)  # lip
        fill_rect(c, cx, cy - 3, hw, hh - 3, r - 2,
                  vgrad([(0, GOLD_HI), (0.5, GOLD), (1, H("#F0A21E"))], bleed, h - bleed - 6))
        fill_rect(c, cx, bleed + hh * 0.42, hw - 8, hh * 0.32, r - 8, lambda x, y: WHITE, 0.22)
        ring_rect(c, cx, cy, hw, hh, r, 1.6, lambda x, y: H("#FFF3C4"), 0.9)
        return
    body, edge, glow = {
        "secondary": ([(0, RAISED_HI), (1, RAISED)], BLUE, BLUE),
        "robux": ([(0, H("#1F8F6A")), (1, H("#136B4E"))], GREEN, GREEN),
        "danger": ([(0, RAISED_HI), (1, RAISED)], RED, RED),
    }[kind]
    glow_rect(c, cx, cy, hw, hh, r, glow, bleed, 0.4)
    fill_rect(c, cx, cy, hw, hh, r, vgrad(body, bleed, h - bleed))
    fill_rect(c, cx, bleed + hh * 0.42, hw - 8, hh * 0.3, r - 8, lambda x, y: WHITE, 0.07)
    ring_rect(c, cx, cy, hw, hh, r, 2.2, lambda x, y: edge)


def draw_plus(c, w, h, bleed):
    cx, cy, hw, hh, r = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 12
    fill_rect(c, cx, cy, hw, hh, r, lambda x, y: GOLD_LO)
    fill_rect(c, cx, cy - 2, hw, hh - 2, r - 1, vgrad([(0, GOLD_HI), (1, GOLD)], bleed, h - bleed))
    for (ax, ay, bx, by) in [(cx - 12, cy - 1, cx + 12, cy - 1), (cx, cy - 13, cx, cy + 11)]:
        c.shade(lambda x, y, a=(ax, ay, bx, by): (GOLD_INK, cover(sd_segment(x, y, *a, 3.6))))


def draw_tab(c, w, h, bleed, on):
    cx, cy, hw, hh, r = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 14
    if on:
        glow_rect(c, cx, cy, hw, hh, r, PURPLE, bleed, 0.5)
        fill_rect(c, cx, cy, hw, hh, r, vgrad([(0, H("#B98AFF")), (0.5, PURPLE), (1, VIOLET)], bleed, h - bleed))
        ring_rect(c, cx, cy, hw, hh, r, 2, lambda x, y: H("#E2CCFF"))
    else:
        fill_rect(c, cx, cy, hw, hh, r, lambda x, y: PANEL, 0.8)
        ring_rect(c, cx, cy, hw, hh, r, 1.2, lambda x, y: STROKE)


def draw_menu_item(c, w, h, bleed):
    def f(x, y):
        d = sd_round_rect(x, y, w / 2 + 20, h / 2, w / 2 + 20 - bleed, h / 2 - bleed, 16)
        a = cover(d)
        if a <= 0:
            return None
        fade = 1 - smooth(w * 0.45, w, x)
        return mix(PANEL, RAISED, 0.4), a * 0.82 * fade
    c.shade(f)
    for yy in (bleed + 1, h - bleed - 1):
        c.shade(lambda x, y, yy=yy: (PURPLE, cover(abs(y - yy) - 0.5) * 0.5 * (1 - smooth(w * 0.3, w, x))),
                (0, yy - 2, w, yy + 2))


def draw_pill(c, w, h, bleed, edge, alpha=0.88, glow=True):
    cx, cy, hw, hh = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed
    if glow:
        glow_rect(c, cx, cy, hw, hh, hh, edge, bleed + 2, 0.3)
    fill_rect(c, cx, cy, hw, hh, hh, vgrad([(0, H("#141B33")), (1, H("#080C1A"))], bleed, h - bleed), alpha)
    fill_rect(c, cx, bleed + hh * 0.5, hw - hh * 0.6, hh * 0.35, hh * 0.35, lambda x, y: WHITE, 0.05)
    ring_rect(c, cx, cy, hw, hh, hh, 1.8, lambda x, y: edge, 0.85)


def draw_tile(c, w, h, bleed, selected):
    cx, cy, hw, hh, r = w / 2, h / 2, w / 2 - bleed, h / 2 - bleed, 12
    if selected:
        glow_rect(c, cx, cy, hw, hh, r, GOLD, bleed, 0.6)
    fill_rect(c, cx, cy, hw, hh, r, vgrad([(0, RAISED_HI), (0.35, RAISED), (1, PANEL)], bleed, h - bleed))
    fill_rect(c, cx, bleed + 14, hw - 6, 8, 6, lambda x, y: WHITE, 0.05)
    if selected:
        ring_rect(c, cx, cy, hw, hh, r, 3, lambda x, y: GOLD)
    else:
        ring_rect(c, cx, cy, hw, hh, r, 1.6, diag(BLUE, PURPLE, w, h), 0.8)


def draw_close(c, w, h, bleed):
    cx = cy = w / 2
    rad = w / 2 - bleed

    def glow(x, y):
        d = sd_circle(x, y, cx, cy, rad)
        return (PINK, 0.4 * math.exp(-d / 2.5)) if d > 0 else None
    c.shade(glow, mode="add")
    c.shade(lambda x, y: (ramp([(0, RAISED_HI), (1, PANEL)], (y - bleed) / (2 * rad)),
                          cover(sd_circle(x, y, cx, cy, rad))))
    c.shade(lambda x, y: (WHITE, 0.08 * cover(sd_circle(x, y, cx, cy - rad * 0.35, rad * 0.55))))
    c.shade(lambda x, y: (H("#FFD6F0"), cover(abs(sd_circle(x, y, cx, cy, rad - 1.2)) - 1.2)))
    k = rad * 0.38
    for a in [(cx - k, cy - k, cx + k, cy + k), (cx - k, cy + k, cx + k, cy - k)]:
        c.shade(lambda x, y, a=a: (WHITE, cover(sd_segment(x, y, *a, 4.2))))


CARD_R = 26


def draw_card_frame(c, w, h, rarity):
    cols = RARITY[rarity]
    th = {"Common": 10, "Rare": 12, "Epic": 14, "Legendary": 16, "Mythical": 18}[rarity]
    cx, cy, hw, hh = w / 2, h / 2, w / 2 - 6, h / 2 - 6

    def border_col(x, y):
        if rarity == "Mythical":
            t = (x / w * 0.6 + y / h * 0.4)
            return ramp([(0, cols[0]), (0.35, cols[1]), (0.7, cols[2]), (1, cols[3])], t)
        return ramp([(0, cols[0]), (0.45, cols[1]), (1, cols[2])], y / h)

    if rarity in ("Epic", "Legendary", "Mythical"):
        # inner glow onto the art edge
        def ig(x, y):
            d = -sd_round_rect(x, y, cx, cy, hw - th, hh - th, CARD_R - 6)
            if d <= 0:
                return None
            return cols[1], 0.5 * math.exp(-d / 10)
        c.shade(ig, mode="add")
    # bottom name plate (dark gradient) and top-left rarity plate inside the window
    c.shade(lambda x, y: (NIGHT, cover(sd_round_rect(x, y, cx, cy, hw - th, hh - th, CARD_R - 6))
                          * 0.85 * smooth(h * 0.74, h * 0.86, y)))
    ring_rect(c, cx, cy, hw, hh, CARD_R, th, border_col)
    ring_rect(c, cx, cy, hw - 2, hh - 2, CARD_R - 2, 1.5, lambda x, y: WHITE, 0.35)
    if rarity != "Common":
        ring_rect(c, cx, cy, hw - th - 4, hh - th - 4, CARD_R - 10, 2, lambda x, y: cols[1], 0.85)
    # rarity plate (top-left) and family badge socket (top-right)
    px0, py0 = 6 + th + 4, 6 + th + 4
    fill_rect(c, px0 + 70, py0 + 22, 70, 22, 10, lambda x, y: mix(NIGHT, cols[2], 0.35), 0.92)
    ring_rect(c, px0 + 70, py0 + 22, 70, 22, 10, 2, border_col)
    bx, by, br = w - (6 + th + 4) - 30, 6 + th + 4 + 30, 30
    c.shade(lambda x, y: (mix(NIGHT, cols[2], 0.35), 0.92 * cover(sd_circle(x, y, bx, by, br))))
    c.shade(lambda x, y: (border_col(x, y), cover(abs(sd_circle(x, y, bx, by, br - 1.2)) - 1.2)))
    # corner ornaments
    if rarity in ("Epic", "Legendary", "Mythical"):
        for (ox, oy) in [(cx - hw + th / 2, cy - hh + th / 2 + 120), (cx + hw - th / 2, cy - hh + th / 2 + 120),
                         (cx - hw + th / 2, cy + hh - th / 2 - 120), (cx + hw - th / 2, cy + hh - th / 2 - 120)]:
            pts = [(ox, oy - 16), (ox + 9, oy), (ox, oy + 16), (ox - 9, oy)]
            c.shade(lambda x, y, p=pts: (cols[0], cover(sd_polygon(x, y, p))), (ox - 12, oy - 20, ox + 12, oy + 20))
    if rarity in ("Legendary", "Mythical"):
        # top crest
        pts = [(cx - 46, 6), (cx + 46, 6), (cx + 30, 6 + th + 18), (cx, 6 + th + 30), (cx - 30, 6 + th + 18)]
        c.shade(lambda x, y: (border_col(x, y), cover(sd_polygon(x, y, pts))), (cx - 50, 0, cx + 50, 80))
        c.shade(lambda x, y: (WHITE, 0.9 * cover(sd_circle(x, y, cx, 6 + th + 10, 7))))
    if rarity == "Mythical":
        import random
        rnd = random.Random(7)
        for _ in range(26):
            sx, sy = rnd.uniform(0, w), rnd.uniform(0, h)
            if sd_round_rect(sx, sy, cx, cy, hw - th, hh - th, CARD_R) < -4:
                continue
            draw_star(c, sx, sy, rnd.uniform(4, 9), WHITE, 0.9)


def draw_star(c, sx, sy, s, col, alpha):
    def f(x, y):
        dx, dy = abs(x - sx), abs(y - sy)
        d = (dx * dy) ** 0.5 * 2.2 + max(dx, dy) * 0.35 - s * 0.5
        a = cover(d, 1.0)
        g = 0.35 * math.exp(-math.hypot(x - sx, y - sy) / (s * 0.6))
        return col, alpha * max(a, g)
    c.shade(f, (sx - s * 2, sy - s * 2, sx + s * 2, sy + s * 2), mode="add")


def draw_foil(c, w, h):
    def f(x, y):
        if sd_round_rect(x, y, w / 2, h / 2, w / 2 - 6, h / 2 - 6, CARD_R) > 0:
            return None
        t = (x * 0.8 + y) / 60
        streak = max(0.0, math.sin(t)) ** 12
        edge = math.exp(sd_round_rect(x, y, w / 2, h / 2, w / 2 - 6, h / 2 - 6, CARD_R) / 14)
        return mix(GOLD_HI, GOLD, streak), 0.28 * streak + 0.45 * edge
    c.shade(f, mode="add")


def draw_card_back(c, w, h):
    cx, cy, hw, hh = w / 2, h / 2, w / 2 - 6, h / 2 - 6
    fill_rect(c, cx, cy, hw, hh, CARD_R, vgrad([(0, H("#1B1240")), (0.5, PANEL), (1, H("#0A0E22"))], 0, h))

    def pattern(x, y):
        if sd_round_rect(x, y, cx, cy, hw - 22, hh - 22, CARD_R - 10) > 0:
            return None
        u, v = (x - cx) / 46, (y - cy) / 46
        d = abs((abs(u) + abs(v)) % 1 - 0.5)
        a = cover((d - 0.03) * 46, 1.2) * 0.35
        return mix(PURPLE, BLUE, y / h), a
    c.shade(pattern)
    c.shade(lambda x, y: (NIGHT, 0.9 * cover(sd_circle(x, y, cx, cy, 92))))
    for rr, col, th in [(92, GOLD, 4), (78, PURPLE, 2.5), (60, BLUE, 2)]:
        c.shade(lambda x, y, rr=rr, col=col, th=th: (col, cover(abs(sd_circle(x, y, cx, cy, rr)) - th / 2)))
    pts = [(cx, cy - 46), (cx + 34, cy), (cx, cy + 46), (cx - 34, cy)]
    c.shade(lambda x, y: (ramp([(0, GOLD_HI), (1, GOLD_LO)], (y - cy + 46) / 92), cover(sd_polygon(x, y, pts))))
    ring_rect(c, cx, cy, hw, hh, CARD_R, 10, vgrad([(0, GOLD_HI), (0.5, GOLD), (1, GOLD_LO)], 0, h))
    ring_rect(c, cx, cy, hw - 16, hh - 16, CARD_R - 8, 2, lambda x, y: PURPLE, 0.8)


def draw_shine(c, w, h):
    def f(x, y):
        d = abs((x - w / 2) - (y - h / 2) * 0.25)
        return WHITE, 0.55 * math.exp(-(d / (w * 0.16)) ** 2)
    c.shade(f)


def draw_pedestal(c, w, h):
    cx, cy = w / 2, h * 0.62

    def rays(x, y):
        if y > cy:
            return None
        spread = (cy - y) / cy
        dx = abs(x - cx) / (w * 0.32 + spread * w * 0.1)
        a = 0.22 * (1 - dx) * (1 - spread) if dx < 1 else 0
        return mix(PURPLE, PINK, spread), max(0, a)
    c.shade(rays, mode="add")

    def ell(x, y, rx, ry, oy=0):
        return (math.hypot((x - cx) / rx, (y - cy - oy) / ry) - 1) * min(rx, ry)
    # side of the stone
    def side(x, y):
        body = min(ell(x, y, 200, 46, 30), max(abs(x - cx) - 200, abs(y - cy - 15) - 15))
        return ramp([(0, H("#2A2450")), (1, H("#0E0A22"))], (y - cy) / 76), cover(body)
    c.shade(side)
    c.shade(lambda x, y: (ramp([(0, H("#3A3070")), (1, H("#1A1440"))], (y - cy + 46) / 92), cover(ell(x, y, 200, 46))))
    c.shade(lambda x, y: (PURPLE, cover(abs(ell(x, y, 186, 40)) - 2.2)))
    c.shade(lambda x, y: (BLUE, 0.6 * cover(abs(ell(x, y, 150, 30)) - 1.2)))
    c.shade(lambda x, y: (PURPLE, 0.35 * math.exp(-max(0, ell(x, y, 200, 46)) / 8) if ell(x, y, 200, 46) > 0 else 0),
            mode="add")


def draw_radial(c, w, h, a0=1.0):
    c.shade(lambda x, y: (WHITE, a0 * max(0, 1 - math.hypot(x - w / 2, y - h / 2) / (w / 2)) ** 2.2))


def draw_rays(c, w, h):
    def f(x, y):
        dx, dy = x - w / 2, y - h / 2
        r = math.hypot(dx, dy) / (w / 2)
        if r > 1:
            return None
        ang = math.atan2(dy, dx)
        beam = max(0.0, math.cos(ang * 9)) ** 6
        return WHITE, beam * (1 - r) ** 1.3 * 0.9 + 0.25 * (1 - r) ** 4
    c.shade(f)


def draw_crack(c, w, h):
    pts = [(128, 20), (110, 70), (140, 100), (102, 140), (134, 178), (118, 236)]
    branches = [((110, 70), (70, 90)), ((140, 100), (190, 120)), ((102, 140), (60, 150)), ((134, 178), (182, 200))]
    segs = list(zip(pts[:-1], pts[1:])) + branches
    for (a, b) in segs:
        c.shade(lambda x, y, a=a, b=b: (WHITE, max(cover(sd_segment(x, y, *a, *b, 2.6)),
                                                  0.5 * math.exp(-max(0, sd_segment(x, y, *a, *b, 0)) / 5))),
                mode="add")


def draw_ring(c, w, h, fill):
    cx = cy = w / 2
    ro, ri = w / 2 - 10, w / 2 - 36
    if fill:
        c.shade(lambda x, y: (WHITE, cover(abs(sd_circle(x, y, cx, cy, (ro + ri) / 2)) - (ro - ri) / 2)))
        c.shade(lambda x, y: (WHITE, 0.3 * math.exp(-abs(sd_circle(x, y, cx, cy, (ro + ri) / 2)) / 10)), mode="add")
    else:
        c.shade(lambda x, y: (PANEL, 0.92 * cover(abs(sd_circle(x, y, cx, cy, (ro + ri) / 2)) - (ro - ri) / 2)))
        c.shade(lambda x, y: (PURPLE, 0.6 * cover(abs(sd_circle(x, y, cx, cy, ri + 1)) - 1)))
        c.shade(lambda x, y: (STROKE, cover(abs(sd_circle(x, y, cx, cy, ro - 1)) - 1)))


def draw_pip(c, w, h, on):
    cx = cy = w / 2
    pts = [(cx, 6), (w - 12, cy), (cx, h - 6), (12, cy)]
    if on:
        c.shade(lambda x, y: (BLUE, 0.55 * math.exp(-max(0, sd_polygon(x, y, pts)) / 4) if sd_polygon(x, y, pts) > 0
                              else 0), mode="add")
        c.shade(lambda x, y: (ramp([(0, H("#D8F4FF")), (0.5, BLUE), (1, H("#1E6FB8"))], y / h),
                              cover(sd_polygon(x, y, pts))))
        inner = [(cx, 16), (cx + 9, cy - 4), (cx, cy), (cx - 9, cy - 4)]
        c.shade(lambda x, y: (WHITE, 0.6 * cover(sd_polygon(x, y, inner))))
    else:
        c.shade(lambda x, y: (H("#0A0F20"), 0.9 * cover(sd_polygon(x, y, pts))))
        c.shade(lambda x, y: (MUTED, 0.7 * cover(abs(sd_polygon(x, y, pts)) - 1.2)))


def draw_bar(c, w, h, fill):
    cx, cy, hw, hh = w / 2, h / 2, w / 2 - 2, h / 2 - 2
    if fill:
        fill_rect(c, cx, cy, hw - 4, hh - 4, hh - 4, vgrad([(0, WHITE), (0.45, H("#E8ECF5")), (1, H("#AEB6C8"))], 6, h - 6))
        fill_rect(c, cx, cy - hh * 0.35, hw - 14, hh * 0.22, hh * 0.22, lambda x, y: WHITE, 0.5)
    else:
        fill_rect(c, cx, cy, hw, hh, hh, vgrad([(0, H("#05070F")), (1, H("#10162A"))], 0, h), 0.95)
        ring_rect(c, cx, cy, hw, hh, hh, 2, lambda x, y: H("#3A4878"))


def draw_action(c, w, h, col, symbol):
    cx = cy = w / 2
    rad = w / 2 - 14
    c.shade(lambda x, y: (col, 0.5 * math.exp(-max(0, sd_circle(x, y, cx, cy, rad)) / 6)
                          if sd_circle(x, y, cx, cy, rad) > 0 else 0), mode="add")
    c.shade(lambda x, y: (ramp([(0, RAISED_HI), (1, PANEL_DEEP)], (y - 14) / (2 * rad)), cover(sd_circle(x, y, cx, cy, rad))))
    c.shade(lambda x, y: (col, cover(abs(sd_circle(x, y, cx, cy, rad - 3)) - 3)))
    symbol(c, cx, cy, col)


def sym_sword(c, cx, cy, col):
    c.shade(lambda x, y: (WHITE, cover(sd_segment(x, y, cx - 34, cy + 34, cx + 36, cy - 36, 7))))
    c.shade(lambda x, y: (col, cover(sd_segment(x, y, cx - 30, cy + 10, cx - 10, cy + 30, 5))))
    c.shade(lambda x, y: (col, cover(sd_segment(x, y, cx - 44, cy + 44, cx - 30, cy + 30, 6))))


def sym_shield(c, cx, cy, col):
    pts = [(cx - 36, cy - 38), (cx + 36, cy - 38), (cx + 34, cy + 2), (cx, cy + 44), (cx - 34, cy + 2)]
    c.shade(lambda x, y: (WHITE, cover(sd_polygon(x, y, pts))))
    inner = [(cx - 24, cy - 28), (cx + 24, cy - 28), (cx + 22, cy), (cx, cy + 30), (cx - 22, cy)]
    c.shade(lambda x, y: (col, cover(sd_polygon(x, y, inner))))


def sym_burst(c, cx, cy, col):
    pts = []
    for i in range(16):
        a = i * math.pi / 8 - math.pi / 2
        r = 46 if i % 2 == 0 else 20
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    c.shade(lambda x, y: (WHITE, cover(sd_polygon(x, y, pts))))
    c.shade(lambda x, y: (col, cover(sd_circle(x, y, cx, cy, 12))))


def draw_banner(c, w, h, win):
    cx, cy = w / 2, h / 2 + 20
    if win:
        draw_rays_into(c, cx, cy, 300, GOLD_HI, 0.5)
        for s in (-1, 1):  # wings
            for k in range(5):
                ang = -0.25 - k * 0.22
                bx = cx + s * (250 + k * 34)
                by = cy - 40 - k * 18
                pts = [(cx + s * 220, cy - 10), (bx + s * 120 * math.cos(ang), by + 120 * math.sin(ang) * 0.5),
                       (bx + s * 40, by + 30)]
                c.shade(lambda x, y, p=pts: (ramp([(0, GOLD_HI), (1, GOLD_LO)], (y - 40) / 300),
                                             cover(sd_polygon(x, y, p))))
        band = [(cx - 340, cy - 60), (cx + 340, cy - 60), (cx + 300, cy + 60), (cx - 300, cy + 60)]
        c.shade(lambda x, y: (ramp([(0, GOLD_HI), (0.5, GOLD), (1, GOLD_LO)], (y - cy + 60) / 120),
                              cover(sd_polygon(x, y, band))))
        inner = [(cx - 320, cy - 48), (cx + 320, cy - 48), (cx + 284, cy + 48), (cx - 284, cy + 48)]
        c.shade(lambda x, y: (H("#5A2A00"), 0.9 * cover(sd_polygon(x, y, inner))))
        crown = [(cx - 70, cy - 70), (cx - 80, cy - 150), (cx - 36, cy - 108), (cx, cy - 168), (cx + 36, cy - 108),
                 (cx + 80, cy - 150), (cx + 70, cy - 70)]
        c.shade(lambda x, y: (ramp([(0, GOLD_HI), (1, GOLD_LO)], (y - cy + 168) / 100), cover(sd_polygon(x, y, crown))))
        for gx in (-36, 0, 36):
            c.shade(lambda x, y, gx=gx: (RED if gx == 0 else BLUE, cover(sd_circle(x, y, cx + gx, cy - 88, 8))))
    else:
        band = [(cx - 340, cy - 54), (cx - 120, cy - 64), (cx + 140, cy - 50), (cx + 340, cy - 58), (cx + 310, cy + 2),
                (cx + 336, cy + 56), (cx - 330, cy + 60), (cx - 300, cy)]
        c.shade(lambda x, y: (ramp([(0, H("#4A5878")), (1, H("#1E2640"))], (y - cy + 64) / 124),
                              cover(sd_polygon(x, y, band))))
        inner = [(cx - 300, cy - 42), (cx + 300, cy - 42), (cx + 290, cy + 44), (cx - 290, cy + 44)]
        c.shade(lambda x, y: (H("#0C1124"), 0.85 * cover(sd_polygon(x, y, inner))))
        for (a, b) in [((cx - 200, cy - 60), (cx - 180, cy - 20)), ((cx + 150, cy + 58), (cx + 170, cy + 20))]:
            c.shade(lambda x, y, a=a, b=b: (NIGHT, cover(sd_segment(x, y, *a, *b, 2))))


def draw_rays_into(c, cx, cy, rad, col, alpha):
    def f(x, y):
        dx, dy = x - cx, y - cy
        r = math.hypot(dx, dy) / rad
        if r > 1:
            return None
        beam = max(0.0, math.cos(math.atan2(dy, dx) * 8)) ** 5
        return col, alpha * beam * (1 - r) ** 1.5
    c.shade(f, mode="add")


def draw_vs(c, w, h):
    cx, cy = w / 2, h / 2
    draw_rays_into(c, cx, cy, 120, H("#FF8A3D"), 0.6)
    V = [(cx - 100, cy - 52), (cx - 70, cy - 52), (cx - 48, cy + 14), (cx - 24, cy - 52), (cx + 4, cy - 52),
         (cx - 34, cy + 52), (cx - 62, cy + 52)]
    S1 = [(cx + 100, cy - 52), (cx + 30, cy - 52), (cx + 14, cy - 30), (cx + 20, cy + 4), (cx + 62, cy + 6),
          (cx + 56, cy + 26), (cx + 8, cy + 26), (cx, cy + 52), (cx + 76, cy + 52), (cx + 94, cy + 30),
          (cx + 88, cy - 8), (cx + 46, cy - 12), (cx + 52, cy - 30), (cx + 94, cy - 30)]
    for poly in (V, S1):
        c.shade(lambda x, y, p=poly: (ramp([(0, GOLD_HI), (0.55, H("#FF8A3D")), (1, RED)], (y - cy + 52) / 104),
                                      max(cover(sd_polygon(x, y, p)), 0)))
        c.shade(lambda x, y, p=poly: (NIGHT, cover(abs(sd_polygon(x, y, p)) - 2.5)))


# ---- icons: chunky shapes, navy outline, two-tone fill

def icon_shape(c, sdf, top, bottom, outline=4, box=(0, 0, 128, 128)):
    y0, y1 = box[1] + 12, box[3] - 12
    c.shade(lambda x, y: (NIGHT, cover(sdf(x, y) - outline)))
    c.shade(lambda x, y: (ramp([(0, top), (1, bottom)], (y - y0) / (y1 - y0)), cover(sdf(x, y))))


def u(*fs):
    return lambda x, y: min(f(x, y) for f in fs)


def sub(a, b):
    return lambda x, y: max(a(x, y), -b(x, y))


def draw_icon(c, slot):
    W = 128
    m = W / 2
    seg = lambda ax, ay, bx, by, r: (lambda x, y: sd_segment(x, y, ax, ay, bx, by, r))  # noqa: E731
    rr = lambda cx, cy, hw, hh, r: (lambda x, y: sd_round_rect(x, y, cx, cy, hw, hh, r))  # noqa: E731
    circ = lambda cx, cy, r: (lambda x, y: sd_circle(x, y, cx, cy, r))  # noqa: E731
    poly = lambda pts: (lambda x, y: sd_polygon(x, y, pts))  # noqa: E731
    if slot == "icon_play":
        for s in (1, -1):
            blade = seg(m - s * 34, 96, m + s * 34, 24, 6)
            guard = seg(m - s * 40 + s * 0, 74, m - s * 18, 96, 5)
            icon_shape(c, u(blade, guard), WHITE, H("#C8D2E8"))
            icon_shape(c, seg(m - s * 46, 108, m - s * 36, 98, 6), GOLD_HI, GOLD_LO)
    elif slot == "icon_cards":
        for i, (dx, rot) in enumerate([(-22, -0.35), (0, 0), (22, 0.35)]):
            ca, sa = math.cos(rot), math.sin(rot)
            cx0, cy0 = m + dx, 70

            def card(x, y, ca=ca, sa=sa, cx0=cx0, cy0=cy0):
                lx = (x - cx0) * ca + (y - cy0) * sa
                ly = -(x - cx0) * sa + (y - cy0) * ca
                return sd_round_rect(lx, ly, 0, 0, 20, 30, 5)
            icon_shape(c, card, [H("#D9BCFF"), PURPLE, GOLD_HI][i], [PURPLE, VIOLET, GOLD][i])
    elif slot == "icon_deck":
        for i in range(3):
            icon_shape(c, rr(m + 6 - i * 6, 60 + i * 8, 26, 34, 6), H("#A8E4FF"), BLUE)
        shield = poly([(m - 16, 56), (m + 4, 56), (m + 4, 74), (m - 6, 90), (m - 16, 74)])
        icon_shape(c, shield, WHITE, H("#C8D2E8"), 3)
    elif slot == "icon_shop":
        egg = lambda x, y: (math.hypot((x - m) / 26, (y - 52) / (34 if y < 52 else 28)) - 1) * 26  # noqa: E731
        icon_shape(c, egg, H("#E2CCFF"), PURPLE)
        icon_shape(c, poly([(24, 70), (104, 70), (94, 108), (34, 108)]), GOLD_HI, GOLD_LO)
    elif slot == "icon_quests":
        icon_shape(c, rr(m, 64, 30, 38, 4), H("#FFF1D0"), H("#E8C98A"))
        icon_shape(c, u(rr(m, 28, 38, 8, 8), rr(m, 100, 38, 8, 8)), GOLD_HI, GOLD_LO)
        for yy in (52, 64, 76):
            c.shade(lambda x, y, yy=yy: (H("#8A6A3A"), cover(sd_segment(x, y, m - 18, yy, m + 18, yy, 2.2))))
    elif slot == "icon_worlds":
        icon_shape(c, circ(m, m, 38), H("#A8E4FF"), H("#1E8F6A"))
        for (ax, ay, bx, by) in [(m - 36, m, m + 36, m), (m, m - 36, m, m + 36)]:
            c.shade(lambda x, y, a=(ax, ay, bx, by): (WHITE, 0.6 * cover(sd_segment(x, y, *a, 1.6))))
        c.shade(lambda x, y: (WHITE, 0.6 * cover(abs((math.hypot((x - m) / 18, (y - m) / 38) - 1) * 18) - 1.6)))
        ring = lambda x, y: abs((math.hypot((x - m) / 56, (y - m - (x - m) * 0.25) / 14) - 1) * 14) - 3  # noqa: E731
        c.shade(lambda x, y: (GOLD, cover(ring(x, y)) if not (sd_circle(x, y, m, m, 38) < 0 and y < m + (x - m) * 0.25) else 0))
    elif slot == "icon_settings":
        def gear(x, y):
            a = math.atan2(y - m, x - m)
            r = 34 + 8 * smooth(-0.3, 0.3, math.cos(a * 8))
            return math.hypot(x - m, y - m) - r
        icon_shape(c, sub(gear, circ(m, m, 13)), H("#E4ECF7"), H("#7F8BA0"))
        c.shade(lambda x, y: (BLUE, cover(sd_circle(x, y, m, m, 9))))
    elif slot == "icon_gift":
        icon_shape(c, rr(m, 78, 38, 28, 5), PINK, H("#C2408F"))
        icon_shape(c, rr(m, 44, 42, 10, 4), H("#FF9AD5"), PINK)
        icon_shape(c, rr(m, 70, 7, 38, 2), GOLD_HI, GOLD_LO, 2)
        icon_shape(c, u(circ(m - 14, 26, 11), circ(m + 14, 26, 11)), GOLD_HI, GOLD_LO, 3)
    elif slot == "icon_calendar":
        icon_shape(c, rr(m, 68, 40, 38, 8), WHITE, H("#C8D2E8"))
        icon_shape(c, rr(m, 38, 40, 10, 6), PURPLE, VIOLET, 2)
        for xx in (m - 20, m + 20):
            icon_shape(c, rr(xx, 26, 4, 10, 3), H("#C8D2E8"), MUTED, 2)
        star = [(m + 18 * math.cos(i * math.pi / 5 - math.pi / 2) * (1 if i % 2 == 0 else 0.45),
                 76 + 18 * math.sin(i * math.pi / 5 - math.pi / 2) * (1 if i % 2 == 0 else 0.45)) for i in range(10)]
        c.shade(lambda x, y: (PURPLE, cover(sd_polygon(x, y, star))))
    elif slot == "icon_friends":
        for (dx, col) in [(18, H("#A8E4FF")), (-12, WHITE)]:
            icon_shape(c, u(circ(m + dx, 46, 15), rr(m + dx, 92, 26, 20, 16)), col, mix(col, BLUE, 0.5))
    elif slot == "icon_coin":
        icon_shape(c, circ(m, m, 44), GOLD_HI, GOLD_LO)
        c.shade(lambda x, y: (H("#FFF3C4"), cover(abs(sd_circle(x, y, m, m, 34)) - 2.2)))
        star = [(m + 20 * math.cos(i * math.pi / 5 - math.pi / 2) * (1 if i % 2 == 0 else 0.45),
                 m + 20 * math.sin(i * math.pi / 5 - math.pi / 2) * (1 if i % 2 == 0 else 0.45)) for i in range(10)]
        c.shade(lambda x, y: (H("#C98A1C"), cover(sd_polygon(x, y, star))))
    elif slot == "icon_gem":
        outer = [(m - 40, 46), (m - 22, 24), (m + 22, 24), (m + 40, 46), (m, 108)]
        icon_shape(c, poly(outer), H("#D8F4FF"), H("#1E6FB8"))
        for (a, b) in [((m - 40, 46), (m + 40, 46)), ((m - 14, 46), (m, 108)), ((m + 14, 46), (m, 108)),
                       ((m - 22, 24), (m - 14, 46)), ((m + 22, 24), (m + 14, 46))]:
            c.shade(lambda x, y, a=a, b=b: (WHITE, 0.55 * cover(sd_segment(x, y, *a, *b, 1.4))))
    elif slot == "icon_trophy":
        cup = poly([(m - 32, 24), (m + 32, 24), (m + 26, 62), (m + 8, 76), (m - 8, 76), (m - 26, 62)])
        handles = u(lambda x, y: abs(sd_circle(x, y, m - 34, 42, 12)) - 4, lambda x, y: abs(sd_circle(x, y, m + 34, 42, 12)) - 4)
        icon_shape(c, u(cup, handles, rr(m, 88, 6, 12, 2), rr(m, 106, 24, 7, 3)), GOLD_HI, GOLD_LO)
    elif slot == "icon_power":
        icon_shape(c, seg(36, 92, 98, 30, 7), WHITE, H("#C8D2E8"))
        icon_shape(c, u(seg(30, 72, 56, 98, 6), seg(22, 106, 34, 94, 7)), GOLD_HI, GOLD_LO)
    elif slot == "icon_lock":
        icon_shape(c, lambda x, y: abs(sd_round_rect(x, y, m, 44, 18, 22, 18)) - 6, H("#E4ECF7"), MUTED)
        icon_shape(c, rr(m, 80, 34, 28, 8), H("#C8D2E8"), H("#6A7590"))
        c.shade(lambda x, y: (NIGHT, cover(u(circ(m, 76, 7), rr(m, 88, 3, 10, 2))(x, y))))
    elif slot == "icon_check":
        icon_shape(c, circ(m, m, 44), H("#7FF0BC"), H("#1F8F6A"))
        c.shade(lambda x, y: (WHITE, cover(u(seg(m - 22, m + 2, m - 6, m + 18, 6), seg(m - 6, m + 18, m + 24, m - 16, 6))(x, y))))
    elif slot == "icon_energy":
        bolt = [(m + 8, 14), (m - 26, 70), (m - 2, 70), (m - 12, 114), (m + 28, 52), (m + 4, 52)]
        icon_shape(c, poly(bolt), H("#D8F4FF"), BLUE)
    elif slot == "icon_hp":
        heart = lambda x, y: min(sd_circle(x, y, m - 18, 50, 22), sd_circle(x, y, m + 18, 50, 22),  # noqa: E731
                                 sd_polygon(x, y, [(m - 38, 60), (m + 38, 60), (m, 104)]))
        icon_shape(c, heart, H("#FF9BB8"), H("#C2234F"))
    elif slot == "icon_odds":
        icon_shape(c, rr(m, m, 40, 40, 14), H("#C9A2FF"), VIOLET)
        c.shade(lambda x, y: (WHITE, cover(min(sd_circle(x, y, m - 16, m - 16, 8) if abs(sd_circle(x, y, m - 16, m - 16, 8)) else 99,
                                                sd_segment(x, y, m + 18, m - 22, m - 18, m + 22, 4.5),
                                                sd_circle(x, y, m + 16, m + 16, 8)))))
    elif slot == "icon_search":
        icon_shape(c, u(lambda x, y: abs(sd_circle(x, y, m - 10, m - 10, 26)) - 6, seg(m + 10, m + 10, m + 36, m + 36, 8)),
                   WHITE, H("#C8D2E8"))


def draw(slot):
    s = next(x for x in SPECS if x["slot"] == slot)
    w, h = s["size"]
    b = s["bleed"]
    c = Canvas(w, h)
    if slot == "panel":
        draw_panel(c, w, h, b)
    elif slot == "panel_header":
        draw_header(c, w, h)
    elif slot == "panel_inset":
        draw_inset(c, w, h)
    elif slot == "shadow":
        draw_shadow(c, w, h, b)
    elif slot == "close_button":
        draw_close(c, w, h, b)
    elif slot.startswith("button_") and slot != "button_plus":
        draw_button(c, w, h, b, slot[7:])
    elif slot == "button_plus":
        draw_plus(c, w, h, b)
    elif slot in ("tab_on", "tab_off"):
        draw_tab(c, w, h, b, slot == "tab_on")
    elif slot == "menu_item":
        draw_menu_item(c, w, h, b)
    elif slot == "currency_badge":
        draw_pill(c, w, h, b, GOLD)
    elif slot == "toast":
        draw_pill(c, w, h, b, BLUE, 0.92)
    elif slot == "reward_chip":
        draw_pill(c, w, h, b, GOLD)
    elif slot in ("tile", "tile_selected"):
        draw_tile(c, w, h, b, slot == "tile_selected")
    elif slot.startswith("card_frame_"):
        draw_card_frame(c, w, h, slot[11:].capitalize())
    elif slot == "card_golden_foil":
        draw_foil(c, w, h)
    elif slot == "card_back":
        draw_card_back(c, w, h)
    elif slot == "card_shine":
        draw_shine(c, w, h)
    elif slot == "egg_pedestal":
        draw_pedestal(c, w, h)
    elif slot == "egg_glow":
        draw_radial(c, w, h)
    elif slot == "light_rays":
        draw_rays(c, w, h)
    elif slot == "sparkle":
        draw_star(c, w / 2, h / 2, 24, WHITE, 1.0)
    elif slot == "crack_overlay":
        draw_crack(c, w, h)
    elif slot.startswith("icon_"):
        draw_icon(c, slot)
    elif slot in ("timer_ring_bg", "timer_ring_fill"):
        draw_ring(c, w, h, slot.endswith("fill"))
    elif slot in ("energy_pip_on", "energy_pip_off"):
        draw_pip(c, w, h, slot.endswith("on"))
    elif slot in ("hp_frame", "hp_fill"):
        draw_bar(c, w, h, slot.endswith("fill"))
    elif slot == "action_attack":
        draw_action(c, w, h, H("#FF7A45"), sym_sword)
    elif slot == "action_defend":
        draw_action(c, w, h, BLUE, sym_shield)
    elif slot == "action_special":
        draw_action(c, w, h, H("#D46BFF"), sym_burst)
    elif slot == "vs_badge":
        draw_vs(c, w, h)
    elif slot in ("banner_victory", "banner_defeat"):
        draw_banner(c, w, h, slot.endswith("victory"))
    else:
        raise SystemExit(f"no drawing for {slot}")
    os.makedirs(TEMP, exist_ok=True)
    c.save(os.path.join(TEMP, f"TEMP_{slot}.png"))


# ------------------------------------------------------------------------------ PROMPTS.md


def write_prompts():
    lines = [
        "# UI image set",
        "",
        "Every UI image the game uses. Generate each one at the **exact pixel size** with a **transparent",
        "background**, save it as `art/ui/<slot>.png`, and keep it 1024 px or smaller. The style is set in",
        "`docs/ART_STYLE.md`.",
        "",
        "Until a final image exists, the game uses a stand-in from `art/ui/temp/TEMP_<slot>.png`. Those are",
        "flat vector drawings made by `scripts/art/make_temp_ui.py`, and are marked Placeholder",
        "(`Config/ContentStatus.uiArt`). Release builds refuse them.",
        "",
        "## How to use this list",
        "- **Style line**: add it to every prompt. " + f"_\"{STYLE}\"_",
        "- **9-slice margins** are `left, top, right, bottom` in pixels: the corners outside them never stretch.",
        "  Keep borders and rounded corners inside the margins and keep the middle plain.",
        "- **Bleed** is how far the glow reaches outside the visible shape. Leave that many pixels of glow on every",
        "  side; the code offsets the image so the visible edge lines up with the layout.",
        "- No text in any image: labels, numbers and the words on banners are drawn by the game, so they",
        "  can be localised and never blur.",
        "- When you add a final image, tell Claude (or run the upload step in `docs/WAITING_ON_YOU.md`). Its asset id",
        "  goes into `src/shared/Config/UiAssets.luau` (`final`), which replaces the TEMP id.",
        "",
    ]
    group = None
    for s in SPECS:
        if s["group"] != group:
            group = s["group"]
            lines += [f"## {group}", "", "| Slot | Size (px) | 9-slice | Bleed | Used for |", "| --- | --- | --- | --- | --- |"]
            for t in [x for x in SPECS if x["group"] == group]:
                sl = ", ".join(map(str, t["slice"])) if t["slice"] else "none"
                lines.append(f"| `{t['slot']}` | {t['size'][0]}×{t['size'][1]} | {sl} | {t['bleed']} | {t['use']} |")
            lines.append("")
            for t in [x for x in SPECS if x["group"] == group]:
                lines += [f"**`{t['slot']}`** ({t['size'][0]}×{t['size'][1]})", "", f"> {t['prompt']}. {STYLE}.", ""]
    with open(os.path.join(OUT, "PROMPTS.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    write_prompts()
    if args == ["prompts"]:
        sys.exit(0)
    for s in SPECS:
        if not args or s["slot"] in args:
            draw(s["slot"])
            print("drew", s["slot"], flush=True)
