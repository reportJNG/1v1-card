"""Contact sheet of kit images: python scripts/art/contact.py out.png cell glob [glob ...]"""
import glob, os, sys
from PIL import Image, ImageDraw
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
out, cell = sys.argv[1], int(sys.argv[2])
files = []
for g in sys.argv[3:]:
    files += sorted(glob.glob(os.path.join(ROOT, "art", "ui", "kit", g)))
cols = 8
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGBA", (cols * cell, rows * (cell + 14)), (8, 7, 30, 255))
d = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    im = Image.open(f).convert("RGBA")
    im.thumbnail((cell - 6, cell - 6))
    x, y = (i % cols) * cell, (i // cols) * (cell + 14)
    sheet.alpha_composite(im, (x + (cell - im.width) // 2, y + (cell - im.height) // 2))
    d.text((x + 3, y + cell), os.path.basename(f)[:-4][:22], fill=(200, 200, 230, 255))
sheet.save(out)
