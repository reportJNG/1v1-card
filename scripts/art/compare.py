"""Side-by-side comparison images (CARDS_EGGS_MISSION section 8): the owner's board on the left,
ours on the right, at the same height, with labels.

  python scripts/art/compare.py <out.png> <board.png> <ours.png> [title] [--height 520]

Several images per side (MASTER_FIX_PLAN screen judging), stacked two to a row, with scores:

  python scripts/art/compare.py <out.png> --left a.png [b.png ...] --right c.png [d.png ...]
         [--left-title TARGET] [--right-title OURS] [--scores "layout 8" "art 8" ...]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONT = os.path.join(ROOT, "art", "fonts", "TitanOne-Regular.ttf")


def compare(out, ref, ours, title="", height=520):
    a = Image.open(ref).convert("RGB")
    b = Image.open(ours).convert("RGB")
    a = a.resize((round(a.width * height / a.height), height), Image.LANCZOS)
    b = b.resize((round(b.width * height / b.height), height), Image.LANCZOS)
    pad, head = 16, 44
    w = a.width + b.width + pad * 3
    h = height + head + pad
    sheet = Image.new("RGB", (w, h), (12, 10, 32))
    sheet.paste(a, (pad, head))
    sheet.paste(b, (pad * 2 + a.width, head))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, 20)
    d.text((pad, 10), "Board (owner reference)" if a.width >= 300 else "Board", font=f, fill=(200, 190, 255))
    d.text((pad * 2 + a.width, 10), "Ours (in game)" + (f" - {title}" if title else ""), font=f, fill=(255, 225, 120))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out, optimize=True)
    return sheet.size


def grid(paths, width):
    """Stacks images two to a row (one if alone), each scaled to the column width."""
    imgs = [Image.open(p).convert("RGB") for p in paths]
    cols = 1 if len(imgs) == 1 else 2
    cw = (width - (cols - 1) * 12) // cols
    imgs = [im.resize((cw, round(im.height * cw / im.width)), Image.LANCZOS) for im in imgs]
    rows = [imgs[i:i + cols] for i in range(0, len(imgs), cols)]
    hs = [max(im.height for im in r) for r in rows]
    out = Image.new("RGB", (width, sum(hs) + 12 * (len(rows) - 1)), (12, 10, 32))
    y = 0
    for r, h in zip(rows, hs):
        for c, im in enumerate(r):
            out.paste(im, (c * (cw + 12), y))
        y += h + 12
    return out


def compare_many(out, left, right, left_title="Target", right_title="Ours (in game)", scores=(), width=900):
    a, b = grid(left, width), grid(right, width)
    pad, head = 16, 52
    foot = 46 if scores else 0
    h = head + max(a.height, b.height) + foot + pad
    sheet = Image.new("RGB", (width * 2 + pad * 3, h), (12, 10, 32))
    sheet.paste(a, (pad, head))
    sheet.paste(b, (pad * 2 + width, head))
    d = ImageDraw.Draw(sheet)
    f = ImageFont.truetype(FONT, 28)
    d.text((pad, 12), left_title, font=f, fill=(200, 190, 255))
    d.text((pad * 2 + width, 12), right_title, font=f, fill=(255, 225, 120))
    if scores:
        d.text((pad * 2 + width, h - foot), "   ".join(scores), font=ImageFont.truetype(FONT, 24), fill=(255, 225, 120))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out, optimize=True)
    return sheet.size


def flag_list(name):
    if name not in sys.argv:
        return []
    i = sys.argv.index(name) + 1
    vals = []
    while i < len(sys.argv) and not sys.argv[i].startswith("--"):
        vals.append(sys.argv[i])
        i += 1
    return vals


if __name__ == "__main__" and "--left" in sys.argv:
    def one(name, default):
        v = flag_list(name)
        return " ".join(v) if v else default
    print(compare_many(sys.argv[1], flag_list("--left"), flag_list("--right"), one("--left-title", "Target"),
                       one("--right-title", "Ours (in game)"), flag_list("--scores")))
elif __name__ == "__main__":
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    hgt = int(sys.argv[sys.argv.index("--height") + 1]) if "--height" in sys.argv else 520
    if "--height" in sys.argv:
        args.remove(str(hgt))
    print(compare(args[0], args[1], args[2], args[3] if len(args) > 3 else "", hgt))
