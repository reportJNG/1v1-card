"""Contact sheet of art/ui/temp on the game's background colour, for visual review.
Only reads the PNGs written by png.py (8-bit RGBA, filter 0)."""
import os, struct, sys, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import Canvas, hex_rgb

def load(path):
    data = open(path, "rb").read()
    pos, w, h, idat = 8, 0, 0, b""
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]; tag = data[pos + 4:pos + 8]; body = data[pos + 8:pos + 8 + n]
        if tag == b"IHDR": w, h = struct.unpack(">II", body[:8])
        if tag == b"IDAT": idat += body
        pos += 12 + n
    raw = zlib.decompress(idat); px = []
    for y in range(h):
        row = raw[y * (w * 4 + 1) + 1:(y + 1) * (w * 4 + 1)]
        px.append([tuple(c / 255 for c in row[x * 4:x * 4 + 4]) for x in range(w)])
    return w, h, px

src = sys.argv[1]; out = sys.argv[2]; scale = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
files = sorted(f for f in os.listdir(src) if f.endswith(".png"))
W = 1400; x = y = 10; rowh = 0; placed = []
for f in files:
    w, h, px = load(os.path.join(src, f)); sw, sh = int(w * scale), int(h * scale)
    if x + sw > W - 10: x = 10; y += rowh + 10; rowh = 0
    placed.append((x, y, sw, sh, w, h, px)); x += sw + 10; rowh = max(rowh, sh)
c = Canvas(W, y + rowh + 10); bg = hex_rgb("#080B18")
for p in c.px: p[:] = [bg[0], bg[1], bg[2], 1]
for (ox, oy, sw, sh, w, h, px) in placed:
    for yy in range(sh):
        for xx in range(sw):
            r, g, b, a = px[int(yy / scale)][int(xx / scale)]
            c.blend(ox + xx, oy + yy, (r, g, b), a)
c.save(out)
