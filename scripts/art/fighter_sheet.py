"""Review sheet for the 3D fighters: docs/review/3d_fighters.png, plus an attack GIF per fighter
in docs/review/3d_fighters_attack/<id>.gif (MAKE_3D_EGGS_AND_FIGHTERS.md section 3).

    python scripts/art/fighter_sheet.py

Reads art/3d/renders/fighters (scripts/blender/fighters.py render_fighters).
"""
import json
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "3d", "renders", "fighters")
OUT = os.path.join(ROOT, "docs", "review")
ROWS = [
    ("ren_emberfang", "ROOK EMBERFORGE (Rare, Flame)"),
    ("yuki_frostveil", "HALVARD FROSTWARDEN (Epic, Ice)"),
    ("vesper_shade", "NOX VEILSTRIDER (Legendary, Shadow)"),
    ("kael_voidbinder", "KAEL VOIDBINDER (Epic, Shadow)"),
    ("brann_cinderfall", "BRANN CINDERFALL (Common, Flame)"),
    ("aurex_sunforge", "AUREX SUNFORGE (Legendary, Divine)"),
    ("guardian_w1", "GUARDIAN (original golem knight, 1.8x; one colour per world)"),
]
VIEWS = ["front", "three_quarter", "back"]
ATTACK = [1, 2, 3]


def load(name, h):
    p = os.path.join(SRC, name + ".png")
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    im.thumbnail((int(h * 0.9), h))
    return im


def main():
    tris = {}
    tp = os.path.join(SRC, "tris.json")
    if os.path.exists(tp):
        tris = json.load(open(tp))
    cell_w, cell_h = 210, 250
    cols = len(VIEWS) + len(ATTACK) + 2  # + two extra guardian themes on its row
    W = 24 + cols * cell_w
    Hh = 110 + len(ROWS) * (cell_h + 44)
    sheet = Image.new("RGB", (W, Hh), (30, 24, 56))
    d = ImageDraw.Draw(sheet)
    big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 26)
    font = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 18)
    small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 14)
    d.text((14, 12), "3D fighters for review: R15 blocky body + our own Blender hair / outfit / weapon meshes", fill=(255, 220, 120), font=big)
    d.text((14, 48), "Front, 3/4 and back, then three frames of the attack (wind-up, dash, strike). Full attack GIFs: "
                     "docs/review/3d_fighters_attack/. Faces: determined eyes, closed mouth or scarf; no blush or tears.",
           fill=(220, 214, 245), font=small)
    d.text((14, 68), "Body parts are Roblox's built-in R15 (colours only); only the identity parts would be uploaded. "
                     "Triangles include the outline hulls.", fill=(220, 214, 245), font=small)
    for r, (fid, label) in enumerate(ROWS):
        y = 100 + r * (cell_h + 44)
        d.text((16, y), label + (f"   {tris[fid]} tris" if fid in tris else ""), fill=(255, 255, 255), font=font)
        names = [f"{fid}_{v}" for v in VIEWS] + [f"{fid}_attack{k}" for k in ATTACK]
        if fid == "guardian_w1":
            names += ["guardian_w4_front", "guardian_w8_front"]
        for c, n in enumerate(names):
            x = 12 + c * cell_w
            d.rectangle([x + 3, y + 26, x + cell_w - 3, y + 26 + cell_h], fill=(54, 44, 92) if "attack" not in n else (70, 40, 70))
            im = load(n, cell_h - 12)
            if im:
                sheet.paste(im, (x + (cell_w - im.width) // 2, y + 32 + (cell_h - 12 - im.height)), im)
            tag = n.replace(fid + "_", "").replace("_", " ")
            if n.startswith("guardian_w4"):
                tag = "world 4 theme"
            elif n.startswith("guardian_w8"):
                tag = "world 8 theme"
            d.text((x + 8, y + 30), tag, fill=(200, 192, 240), font=small)
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "3d_fighters.png")
    sheet.save(out)
    print(out, sheet.size)
    gifs = os.path.join(OUT, "3d_fighters_attack")
    os.makedirs(gifs, exist_ok=True)
    for fid, _ in ROWS:
        frames = []
        for k in range(6):
            p = os.path.join(SRC, f"{fid}_attack{k}.png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGBA")
                bg = Image.new("RGBA", im.size, (40, 32, 70, 255))
                bg.alpha_composite(im)
                frames.append(bg.convert("RGB").resize((im.width // 2, im.height // 2)))
        if frames:
            durations = [400, 220, 160, 260, 220, 500][: len(frames)]
            frames[0].save(os.path.join(gifs, f"{fid}.gif"), save_all=True, append_images=frames[1:],
                           duration=durations, loop=0)
    print("gifs", gifs)


if __name__ == "__main__":
    main()
