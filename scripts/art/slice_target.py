"""Cuts the clean pieces out of the owner's own target image docs/brief/bad-gui/04-merchant-target.png
(BAD_GUI_2_PANELS.md section 3.1; MASTER_FIX_PLAN Phase 3). The target is the owner's generated art,
so it may be used as source; it is never edited (pieces are copies). Pieces with baked-in text (the
header, the banner, the item cards, the buttons) are NOT cut: they wait for the owner's text-free
merchant kit sheet (art/ui/PROMPTS_V3.md section 5).

  python scripts/art/slice_target.py

Writes art/ui/kit-v3/m_*.png, registers them in kit.json as REVIEW (never LIVE: the owner OKs the
contact sheet docs/review/ui-kit-v3.png first, then uploads go in batches of 5 or fewer), and
renders the 9-slice test docs/review/m_slice_test.png.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_sheet  # noqa: E402

ROOT = cut_sheet.ROOT
SRC = os.path.join(ROOT, "docs", "brief", "bad-gui", "04-merchant-target.png")
OUT = cut_sheet.KIT_DIR


def arr(im):
    return np.asarray(im.convert("RGB")).astype(np.float32)


def with_alpha(rgb, alpha):
    a = np.clip(alpha, 0, 1) * 255
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA")


def not_grass(rgb):
    """1 on the panel (purple/lavender: blue over green), 0 on the grass and trees behind it."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    return np.clip((b - g - 6) / 18, 0, 1)


def soften(alpha, px=1.2):
    im = Image.fromarray((alpha * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(px))
    return np.asarray(im).astype(np.float32) / 255


def lift(rgb, bg, low, span):
    """Alpha from how far a pixel stands out from the local background colour."""
    d = np.sqrt(((rgb - np.array(bg, dtype=np.float32)) ** 2).sum(axis=2))
    return np.clip((d - low) / span, 0, 1)


def trim(im, pad=2):
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a > 6)
    if len(xs) == 0:
        return im
    return im.crop((max(0, xs.min() - pad), max(0, ys.min() - pad), min(im.width, xs.max() + pad + 1),
                    min(im.height, ys.max() + pad + 1)))


def panel_frame(src):
    """A 9-slice panel frame rebuilt from the target's clean bottom-left corner (border, stripes),
    mirrored to all four corners so the tone is even (the target's right corner is lit brighter),
    with the side border and interior taken from the same band, so there are no seams."""
    band_y0, band_y1 = 926, 996  # below the item cards' glow
    corner = src.crop((35, band_y0, 215, band_y1))
    mid = src.crop((226, band_y0, 270, band_y1))  # a plain stretch of the bottom border
    cw, bh, mw = corner.width, corner.height, mid.width
    side_h = 80
    W, H = cw * 2 + mw, bh * 2 + side_h
    bottom = Image.new("RGB", (W, bh))
    bottom.paste(corner, (0, 0))
    bottom.paste(mid, (cw, 0))
    bottom.paste(corner.transpose(Image.FLIP_LEFT_RIGHT), (cw + mw, 0))
    frame = Image.new("RGB", (W, H))
    frame.paste(bottom, (0, H - bh))
    frame.paste(bottom.transpose(Image.FLIP_TOP_BOTTOM), (0, 0))
    # the middle rows: the interior colour, with the border column (the corner's straight left edge,
    # above its stripes) down each side
    interior = tuple(int(v) for v in arr(mid.crop((0, 0, mid.width, 4))).reshape(-1, 3).mean(axis=0))
    rows = Image.new("RGB", (W, side_h), interior)
    edge = corner.crop((0, 0, 16, 2)).resize((16, side_h), Image.NEAREST)
    rows.paste(edge, (0, 0))
    rows.paste(edge.transpose(Image.FLIP_LEFT_RIGHT), (W - 16, 0))
    frame.paste(rows, (0, bh))
    rgb = arr(frame)
    alpha = soften(not_grass(rgb))
    return with_alpha(rgb, alpha), [cw, bh, cw, bh]


def bright(src, box, low, span):
    """Alpha from brightness (sparkles on a busy background)."""
    crop = src.crop(box)
    rgb = arr(crop)
    lum = rgb.min(axis=2)
    return trim(with_alpha(rgb, soften(np.clip((lum - low) / span, 0, 1), 0.5)))


def close_button(src):
    cx, cy, r = 1392, 122, 52
    box = (cx - r - 2, cy - r - 2, cx + r + 3, cy + r + 3)
    crop = src.crop(box)
    rgb = arr(crop)
    yy, xx = np.mgrid[0:crop.height, 0:crop.width]
    d = np.sqrt((xx - (cx - box[0])) ** 2 + (yy - (cy - box[1])) ** 2)
    return trim(with_alpha(rgb, np.clip((r - d) / 2.0, 0, 1)))


def lifted(src, box, bg_at, low=16, span=40):
    crop = src.crop(box)
    bg = arr(src.crop((bg_at[0], bg_at[1], bg_at[0] + 6, bg_at[1] + 6))).reshape(-1, 3).mean(axis=0)
    rgb = arr(crop)
    return trim(with_alpha(rgb, soften(lift(rgb, bg, low, span), 0.6)))


PIECES = [
    # name, builder, use
    ("m_panel_frame", None, "panel frame, 9-slice (rebuilt from the clean bottom corners)"),
    ("m_close_button", close_button, "round close button"),
    ("m_crown", lambda s: lifted(s, (704, 916, 768, 968), (690, 940)), "bottom crown ornament"),
    ("m_coinbag_empty", lambda s: lifted(s, (860, 430, 1350, 760), (880, 450), 8, 34), "empty-state illustration"),
    ("m_divider", lambda s: lifted(s, (920, 806, 1326, 836), (920, 840), 14, 40), "divider line with a sparkle"),
    ("m_sparkle_gold", lambda s: lifted(s, (1058, 236, 1112, 296), (1052, 300), 30, 60), "gold sparkle"),
    ("m_sparkle_white", lambda s: bright(s, (228, 204, 282, 262), 150, 70), "white sparkle"),
    ("m_sparkle_violet", lambda s: lifted(s, (1292, 522, 1344, 584), (1286, 590), 14, 40), "violet sparkle"),
]


def main():
    src = Image.open(SRC).convert("RGB")
    kit = cut_sheet.load_kit()
    written = []
    for i, (name, build, use) in enumerate(PIECES, start=1):
        if name == "m_panel_frame":
            im, margins = panel_frame(src)
        else:
            im, margins = build(src), None
        path = os.path.join(OUT, f"{name}.png")
        im.save(path)
        written.append((i, path))
        old = kit["pieces"].get(name, {})
        kit["pieces"][name] = {
            "file": os.path.relpath(path, ROOT).replace("\\", "/"),
            "sheet": "docs/brief/bad-gui/04-merchant-target.png",
            "size": list(im.size),
            "slice": margins,
            "assetId": old.get("assetId", ""),
            "tint": None,
            "replaces": "panel" if name == "m_panel_frame" else ("close_button" if name == "m_close_button" else None),
            "use": use,
            "status": old.get("status", "REVIEW"),
        }
    cut_sheet.save_kit(kit)
    cut_sheet.contact("ui-kit-v3 (from 04-merchant-target)", written, os.path.join(cut_sheet.REVIEW, "ui-kit-v3.png"))
    print(cut_sheet.slicetest("m_panel_frame", kit))
    print(f"{len(written)} pieces -> art/ui/kit-v3 (REVIEW); contact sheet docs/review/ui-kit-v3.png")


if __name__ == "__main__":
    main()
