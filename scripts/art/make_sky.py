"""Generates the hub's night skybox (art/sky/hub_<face>.png): a navy-to-purple gradient by
elevation, a soft violet/pink nebula band, stars and a moon (docs/ART_STYLE.md section 6).
Every pixel's colour is a function of its view direction, so the six faces meet without seams.
Original, code-drawn art (no third-party images).

  python scripts/art/make_sky.py [size]      # default 512 px per face
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import Canvas, hex_rgb, mix, ramp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "sky")
H = hex_rgb

# Roblox Sky faces: for each, the view direction at the image centre, the world direction of
# image +x (right) and of image +y (down).
FACES = {
    "ft": ((0, 0, -1), (1, 0, 0), (0, -1, 0)),   # front: looking -Z
    "bk": ((0, 0, 1), (-1, 0, 0), (0, -1, 0)),   # back: looking +Z
    "lf": ((-1, 0, 0), (0, 0, -1), (0, -1, 0)),  # left: looking -X
    "rt": ((1, 0, 0), (0, 0, 1), (0, -1, 0)),    # right: looking +X
    "up": ((0, 1, 0), (0, 0, 1), (1, 0, 0)),     # up: looking +Y
    "dn": ((0, -1, 0), (0, 0, 1), (-1, 0, 0)),   # down: looking -Y
}

MOON = (0.35, 0.42, -0.84)  # direction of the moon (front-right, fairly high)


def norm(v):
    n = math.sqrt(sum(a * a for a in v))
    return tuple(a / n for a in v)


MOON = norm(MOON)


def hash3(i, j, k):
    n = (i * 73856093) ^ (j * 19349663) ^ (k * 83492791)
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFFFF) / 0xFFFFFF


def vnoise(x, y, z):
    xi, yi, zi = math.floor(x), math.floor(y), math.floor(z)
    xf, yf, zf = x - xi, y - yi, z - zi
    u, v, w = (t * t * (3 - 2 * t) for t in (xf, yf, zf))
    acc = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                wgt = (u if dx else 1 - u) * (v if dy else 1 - v) * (w if dz else 1 - w)
                acc += wgt * hash3(xi + dx, yi + dy, zi + dz)
    return acc


def fbm(x, y, z):
    return 0.55 * vnoise(x, y, z) + 0.3 * vnoise(x * 2.1, y * 2.1, z * 2.1) + 0.15 * vnoise(x * 4.3, y * 4.3, z * 4.3)


def sky(d):
    x, y, z = d
    elev = y  # -1..1
    base = ramp([(0, H("#24164A")), (0.42, H("#3E2A86")), (0.52, H("#6A4AC0")), (0.62, H("#3A2C8A")),
                 (0.8, H("#22206A")), (1, H("#12143E"))], (elev + 1) / 2)
    # horizon glow
    base = mix(base, H("#B07BFF"), 0.45 * math.exp(-abs(elev - 0.03) / 0.07))
    # nebula band tilted across the sky
    band = math.exp(-((y - 0.45 * x - 0.25) / 0.28) ** 2)
    n = fbm(x * 2.2 + 5, y * 2.2, z * 2.2)
    neb = band * max(0, n - 0.38) * 2.2
    base = mix(base, ramp([(0, H("#7B3CFF")), (0.6, H("#FF7BD5")), (1, H("#45BEFF"))], n), min(0.8, neb * 1.3))
    # moon with halo
    dot = x * MOON[0] + y * MOON[1] + z * MOON[2]
    ang = math.acos(max(-1, min(1, dot)))
    if ang < 0.09:
        moon = 1 - (ang / 0.09) ** 6
        base = mix(base, H("#F6EEFF"), moon)
    base = mix(base, H("#C9B6FF"), 0.45 * math.exp(-ang / 0.12))
    # stars: hashed cells on a direction grid, brighter higher up
    if elev > -0.05:
        g = 70
        ci, cj, ck = math.floor(x * g), math.floor(y * g), math.floor(z * g)
        hsh = hash3(ci, cj, ck)
        if hsh > 0.9:
            cx, cy, cz = ((ci + 0.5) / g, (cj + 0.5) / g, (ck + 0.5) / g)
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2) * g
            b = max(0, 1 - dist * 1.8) * (hsh - 0.9) / 0.1 * min(1, (elev + 0.05) * 4)
            base = mix(base, (1, 1, 1), min(1, b * 1.4))
    return base


def render(size):
    os.makedirs(OUT, exist_ok=True)
    for face, (c, r, dn) in FACES.items():
        cv = Canvas(size, size)
        for py in range(size):
            v = (py + 0.5) / size * 2 - 1
            for px in range(size):
                u = (px + 0.5) / size * 2 - 1
                d = norm(tuple(c[i] + u * r[i] + v * dn[i] for i in range(3)))
                col = sky(d)
                p = cv.px[py * size + px]
                p[0], p[1], p[2], p[3] = col[0], col[1], col[2], 1.0
        cv.save(os.path.join(OUT, f"hub_{face}.png"))
        print("sky", face, flush=True)


if __name__ == "__main__":
    random.seed(1)
    render(int(sys.argv[1]) if len(sys.argv) > 1 else 512)
