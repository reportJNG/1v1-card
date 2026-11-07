"""Side-by-side comparison images (CARDS_EGGS_MISSION section 8): the owner's board on the left,
ours on the right, at the same height, with labels.

  python scripts/art/compare.py <out.png> <board.png> <ours.png> [title] [--height 520]
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
    d.text((pad, 10), "Board (owner reference)", font=f, fill=(200, 190, 255))
    d.text((pad * 2 + a.width, 10), "Ours (in game)" + (f" - {title}" if title else ""), font=f, fill=(255, 225, 120))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    sheet.save(out, optimize=True)
    return sheet.size


if __name__ == "__main__":
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    hgt = int(sys.argv[sys.argv.index("--height") + 1]) if "--height" in sys.argv else 520
    if "--height" in sys.argv:
        args.remove(str(hgt))
    print(compare(args[0], args[1], args[2], args[3] if len(args) > 3 else "", hgt))
