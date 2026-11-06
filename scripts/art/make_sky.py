"""Generates the skyboxes from code: the hub night sky (art/sky/hub_<face>.png: navy-to-purple
gradient, violet/pink nebula band, stars, moon; docs/ART_STYLE.md section 6) and one sky per
farming world (art/sky/w<n>_<face>.png, palettes in WORLD_SKIES). Every pixel is a function of its
view direction, so the six faces meet without seams. Original art (no third-party images).

  python scripts/art/make_sky.py [size]               # hub sky, default 512 px per face
  python scripts/art/make_sky.py world [size] [n...]  # world skies art/sky/w<n>_<face>.png (WORLD_SKIES)
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from png import Canvas, hex_rgb, mix, ramp, smooth  # noqa: E402

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


# One palette per world (docs/ART_STYLE.md section 6: worlds 1-3 day-lit, darker and more neon
# from world 5). stops: colour by elevation (0 = straight down, 1 = straight up); glow: horizon
# glow colour and strength; sun: (direction, colour, disc size, halo); clouds: (colour, shadow
# colour, cover 0-1, top of the cloud band); cloud_sea: clouds also fill below the horizon;
# band: a nebula/aurora band's colours; stars: density 0-1.
WORLD_SKIES = {
    1: dict(stops=[(0, "#7FB06A"), (0.48, "#CFEFFF"), (0.52, "#BFE6FF"), (0.7, "#6FB6FF"), (1, "#2E7BF0")],
            glow=("#FFFFFF", 0.35), sun=((-0.45, 0.55, -0.7), "#FFF6D8", 0.05, 0.25),
            clouds=("#FFFFFF", "#C9DDF2", 0.55, 0.45)),
    2: dict(stops=[(0, "#1A2440"), (0.48, "#E0A0E8"), (0.53, "#B07CD8"), (0.7, "#4B4FA0"), (1, "#141C48")],
            glow=("#FFB0E0", 0.5), sun=((0.5, 0.18, -0.85), "#FFE8F4", 0.04, 0.3),
            clouds=("#C9A0F0", "#6A4AA8", 0.35, 0.35), stars=0.35),
    3: dict(stops=[(0, "#E0B070"), (0.48, "#FFE6B8"), (0.53, "#FFD9A0"), (0.72, "#6FB0F0"), (1, "#2F7AD8")],
            glow=("#FFF2D0", 0.45), sun=((0.2, 0.7, -0.68), "#FFFBEA", 0.07, 0.35),
            clouds=("#FFF8EA", "#E8C9A0", 0.2, 0.3)),
    4: dict(stops=[(0, "#C8DDF0"), (0.48, "#F2FAFF"), (0.53, "#D6ECFF"), (0.72, "#7FB0E0"), (1, "#3A6AB0")],
            glow=("#FFFFFF", 0.4), sun=((-0.6, 0.22, -0.77), "#FFF4E8", 0.045, 0.3),
            clouds=("#FFFFFF", "#B8CCE0", 0.35, 0.4), band=("#48F0B0", "#45BEFF", "#B07BFF"), stars=0.1),
    5: dict(stops=[(0, "#1A0805"), (0.47, "#FF7A30"), (0.52, "#C0401A"), (0.66, "#5A1A10"), (1, "#1A0806")],
            glow=("#FF8A3A", 0.7), sun=((0.3, 0.12, -0.95), "#FFB060", 0.06, 0.45),
            clouds=("#4A2A22", "#1E0E0A", 0.6, 0.5)),
    6: dict(stops=[(0, "#0E0306"), (0.47, "#E03A6A"), (0.52, "#7A1030"), (0.68, "#2E0818"), (1, "#0A0208")],
            glow=("#FF3B5B", 0.6), sun=((-0.35, 0.42, -0.84), "#FF4A4A", 0.06, 0.4),
            clouds=("#3A0E20", "#14040C", 0.45, 0.45), stars=0.25),
    7: dict(stops=[(0, "#FFFFFF"), (0.46, "#FFFFFF"), (0.52, "#E6F4FF"), (0.72, "#8FCBFF"), (1, "#4A9EF5")],
            glow=("#FFFFFF", 0.5), sun=((0.4, 0.5, -0.77), "#FFF2B0", 0.05, 0.35),
            clouds=("#FFFFFF", "#D2E4F7", 0.5, 0.35), cloud_sea=True),
    8: dict(stops=[(0, "#8A6A40"), (0.48, "#FFC98A"), (0.53, "#FFB070"), (0.7, "#7A8FC8"), (1, "#3A5A9E")],
            glow=("#FFD8A0", 0.55), sun=((-0.3, 0.1, -0.95), "#FFE0A0", 0.07, 0.45),
            clouds=("#FFD0A8", "#B87A60", 0.4, 0.35)),
    9: dict(stops=[(0, "#05030C"), (0.48, "#6A4ADF"), (0.53, "#2A1A5A"), (0.7, "#120A2A"), (1, "#04020A")],
            glow=("#7C5CFF", 0.6), band=("#7B3CFF", "#FF7BD5", "#45F0E0"), stars=0.9,
            sun=((0.5, 0.35, -0.79), "#D8C8FF", 0.035, 0.3)),
    10: dict(stops=[(0, "#FFF6E0"), (0.47, "#FFFFFF"), (0.53, "#FFF0C8"), (0.72, "#BFE0FF"), (1, "#7AB8FF")],
             glow=("#FFE9A0", 0.55), sun=((0.0, 0.62, -0.78), "#FFF6C0", 0.08, 0.55),
             clouds=("#FFFFFF", "#F0D8A0", 0.45, 0.4), cloud_sea=True),
}


def world_sky(d, spec):
    x, y, z = d
    elev = y
    stops = [(p, H(c)) for p, c in spec["stops"]]
    base = ramp(stops, (elev + 1) / 2)
    gc, gs = spec["glow"]
    base = mix(base, H(gc), gs * math.exp(-abs(elev - 0.02) / 0.09))
    if "band" in spec:  # aurora / nebula
        c1, c2, c3 = (H(c) for c in spec["band"])
        band = math.exp(-((y - 0.35 * x - 0.35) / 0.22) ** 2) * max(0.0, min(1.0, elev * 4))
        n = fbm(x * 2.6 + 3, y * 2.6, z * 2.6)
        a = band * max(0, n - 0.32) * 2.4
        base = mix(base, ramp([(0, c1), (0.55, c2), (1, c3)], n), min(0.85, a * 1.3))
    if spec.get("stars") and elev > -0.02:
        th = 1 - 0.12 * spec["stars"]
        g = 80
        ci, cj, ck = math.floor(x * g), math.floor(y * g), math.floor(z * g)
        hsh = hash3(ci, cj, ck)
        if hsh > th:
            cx, cy, cz = ((ci + 0.5) / g, (cj + 0.5) / g, (ck + 0.5) / g)
            dist = math.sqrt((x - cx) ** 2 + (y - cy) ** 2 + (z - cz) ** 2) * g
            b = max(0, 1 - dist * 1.8) * (hsh - th) / (1 - th) * min(1, (elev + 0.02) * 5)
            base = mix(base, (1, 1, 1), min(1, b * 1.5))
    if "sun" in spec:
        sd, sc, disc, halo = spec["sun"]
        sd = norm(sd)
        ang = math.acos(max(-1, min(1, x * sd[0] + y * sd[1] + z * sd[2])))
        base = mix(base, H(sc), halo * math.exp(-ang / 0.25))
        if ang < disc:
            base = mix(base, H(sc), 1 - (ang / disc) ** 8)
    if "clouds" in spec:
        cc, cs, amount, top = spec["clouds"]
        sea = spec.get("cloud_sea")
        lo = -1.0 if sea else -0.04
        if lo <= elev <= top:
            n = fbm(x * 3.2 + 11, y * 7.0, z * 3.2)
            th = 0.62 - amount * 0.3
            dens = smooth(th, th + 0.16, n)
            fade = smooth(top, top - 0.15, elev) * (1.0 if sea else smooth(lo, lo + 0.05, elev))
            if sea and elev < 0:
                dens = max(dens, smooth(-0.02, -0.12, elev) * 0.9)
            col = mix(H(cs), H(cc), smooth(0.0, 1.0, (n - th) * 3 + 0.3))
            base = mix(base, col, dens * fade)
    return base


def render_world(args):
    n, size = args
    spec = WORLD_SKIES[n]
    for face, (c, r, dn) in FACES.items():
        cv = Canvas(size, size)
        for py in range(size):
            v = (py + 0.5) / size * 2 - 1
            for px in range(size):
                u = (px + 0.5) / size * 2 - 1
                d = norm(tuple(c[i] + u * r[i] + v * dn[i] for i in range(3)))
                col = world_sky(d, spec)
                p = cv.px[py * size + px]
                p[0], p[1], p[2], p[3] = col[0], col[1], col[2], 1.0
        cv.save(os.path.join(OUT, f"w{n}_{face}.png"))
    print("sky world", n, flush=True)



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
    if len(sys.argv) > 1 and sys.argv[1] == "world":
        from multiprocessing import Pool
        os.makedirs(OUT, exist_ok=True)
        size = int(sys.argv[2]) if len(sys.argv) > 2 else 384
        worlds = [int(a) for a in sys.argv[3:]] or sorted(WORLD_SKIES)
        with Pool(min(8, len(worlds))) as pool:
            pool.map(render_world, [(n, size) for n in worlds])
    else:
        render(int(sys.argv[1]) if len(sys.argv) > 1 else 512)
