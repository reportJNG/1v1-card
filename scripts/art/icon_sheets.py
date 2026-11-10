"""Icon pack review sheets and the final icon choice (GOAL_ALL Phase 3b).

  python scripts/art/icon_sheets.py packs    one contact sheet per pack: docs/review/icons_<pack>.png
  python scripts/art/icon_sheets.py final    docs/review/icons_final.png from art/icons/icon_map.json

The packs live in art/icons/<pack>/ locally only (git-ignored: the repo is public and the licences
forbid redistributing the icons as standalone files), so these sheets are local too.
"""
import glob
import json
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ICONS = os.path.join(ROOT, "art", "icons")
REVIEW = os.path.join(ROOT, "docs", "review")
FONT = os.path.join(ROOT, "art", "fonts", "TitanOne-Regular.ttf")


def font(n):
    return ImageFont.truetype(FONT, n)


def sheet(entries, title, out, cell=150, cols=10):
    rows = (len(entries) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell, rows * (cell + 34) + 50), (16, 14, 40))
    d = ImageDraw.Draw(img)
    d.text((10, 10), title, font=font(24), fill=(255, 226, 122))
    for i, (label, path) in enumerate(entries):
        x, y = (i % cols) * cell, 50 + (i // cols) * (cell + 34)
        im = Image.open(path).convert("RGBA")
        im.thumbnail((cell - 20, cell - 20))
        img.paste(im, (x + (cell - im.width) // 2, y + (cell - 20 - im.height) // 2 + 6), im)
        for k, line in enumerate([label[:20], label[20:40]] if len(label) > 20 else [label]):
            d.text((x + 6, y + cell - 18 + k * 15), line, font=font(12), fill=(230, 232, 255))
    os.makedirs(REVIEW, exist_ok=True)
    img.save(out)
    print(f"{out}: {len(entries)} icons")


def packs():
    free = os.path.join(ICONS, "free-icon-pack-v3.1")
    entries = []
    for cat in sorted(os.listdir(free)):
        if not os.path.isdir(os.path.join(free, cat)):
            continue
        for subj in sorted(os.listdir(os.path.join(free, cat))):
            big = [d for d in glob.glob(os.path.join(free, cat, subj, "256*")) if os.path.isdir(d)]
            if not big:
                continue
            files = sorted(glob.glob(os.path.join(big[0], "*.png")))
            pick = next((f for f in files if " 1st 256" in f and "Golden" not in f and "Outline" not in f), files[0] if files else None)
            if pick:
                entries.append((f"{cat}/{subj}", pick))
    sheet(entries, "Free Icon Pack v3.1 (gvesster): one colour variant per subject, 256 px", os.path.join(REVIEW, "icons_free-icon-pack-v3.1.png"))
    sty = os.path.join(ICONS, "stylized-game-essentials")
    entries = []
    for f in sorted(glob.glob(os.path.join(sty, "[0-9][0-9]_*", "*.png"))):
        cat = os.path.basename(os.path.dirname(f))[:2]
        entries.append((f"{cat}/{os.path.basename(f)[:-4]}", f))
    sheet(entries, "Stylized Game Essentials (147 icons, 512 px)", os.path.join(REVIEW, "icons_stylized-game-essentials.png"))


def final():
    m = json.load(open(os.path.join(ICONS, "icon_map.json"), encoding="utf-8"))
    entries = []
    for slot, e in m["slots"].items():
        if e.get("file"):
            entries.append((slot, os.path.join(ICONS, e["file"])))
    sheet(entries, "icons_final: the chosen icon per slot (REVIEW: needs the owner's OK before upload)",
          os.path.join(REVIEW, "icons_final.png"), cell=170, cols=8)


if __name__ == "__main__":
    {"packs": packs, "final": final}[sys.argv[1]]()
