"""Contact sheet of the 3D egg renders for the review gate: docs/review/3d_eggs.png.

    python scripts/art/egg_sheet.py [out.png]

Reads art/3d/renders/eggs/egg_<id>.png (scripts/blender/eggs.py render_all) and lays them out with
their names and triangle counts (art/3d/renders/eggs/tris.json when present).
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "3d", "renders", "eggs")
EGGS = [
    "basic", "spotted", "cracked", "cat", "dog", "rainbow", "sandcastle", "coconut", "royal", "ice",
    "yeti", "mine", "dragon", "demon", "angel", "kraken", "dominus", "legendary", "glitched",
    "black_hole", "secret", "angel_demon", "mythical", "party",
]
GOLDEN = ["basic", "cat", "dragon", "royal"]


def main(out):
    tris = {}
    tp = os.path.join(SRC, "tris.json")
    if os.path.exists(tp):
        tris = json.load(open(tp))
    names = [f"egg_{e}" for e in EGGS] + [f"egg_{e}_golden" for e in GOLDEN]
    cell, cols = 260, 7
    rows = (len(names) + cols - 1) // cols
    W, Hh = cols * cell + 24, rows * (cell + 34) + 96
    sheet = Image.new("RGB", (W, Hh), (30, 24, 56))
    d = ImageDraw.Draw(sheet)
    big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 17)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    d.text((14, 12), "3D eggs for review: our own Blender models (no icon-pack images), toon + outline", fill=(255, 220, 120), font=big)
    d.text((14, 48), "24 eggs (Config/Eggs RequiredIds) + Golden = the same meshes with the gold material and sparkle (4 shown). "
                     "Triangles include the outline hull.", fill=(220, 214, 245), font=small)
    for i, n in enumerate(names):
        x = 12 + (i % cols) * cell
        y = 80 + (i // cols) * (cell + 34)
        bg = (54, 44, 92) if "golden" not in n else (84, 64, 30)
        d.rectangle([x + 4, y, x + cell - 4, y + cell + 28], fill=bg)
        p = os.path.join(SRC, n + ".png")
        if os.path.exists(p):
            im = Image.open(p).convert("RGBA")
            im.thumbnail((cell - 16, cell - 16))
            sheet.paste(im, (x + (cell - im.width) // 2, y + 4), im)
        label = n.replace("egg_", "").replace("_", " ").upper()
        d.text((x + 10, y + cell - 6), label, fill=(255, 255, 255), font=font)
        if n in tris:
            d.text((x + cell - 70, y + cell - 4), f"{tris[n]} tris", fill=(180, 170, 220), font=small)
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "docs", "review", "3d_eggs.png"))
