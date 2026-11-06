"""Tiny dependency-free RGBA canvas + PNG writer used by make_temp_ui.py.

Drawing is done with signed distance functions (SDF) so shapes are anti-aliased: each pixel's
coverage is derived from its distance to the shape edge.
"""
import math
import struct
import zlib


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(a, b, t) for a, b in zip(c1, c2))


def ramp(stops, t):
    """stops: [(pos, rgb)], t in 0..1 -> rgb"""
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if t <= p1:
            return mix(c0, c1, 0 if p1 == p0 else (t - p0) / (p1 - p0))
    return stops[-1][1]


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


def sd_round_rect(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - hw + r
    qy = abs(py - cy) - hh + r
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - r


def sd_circle(px, py, cx, cy, r):
    return math.hypot(px - cx, py - cy) - r


def sd_segment(px, py, ax, ay, bx, by, r):
    pax, pay = px - ax, py - ay
    bax, bay = bx - ax, by - ay
    h = max(0.0, min(1.0, (pax * bax + pay * bay) / (bax * bax + bay * bay)))
    return math.hypot(pax - bax * h, pay - bay * h) - r


def sd_polygon(px, py, pts):
    d = (px - pts[0][0]) ** 2 + (py - pts[0][1]) ** 2
    s = 1.0
    n = len(pts)
    j = n - 1
    for i in range(n):
        ex, ey = pts[j][0] - pts[i][0], pts[j][1] - pts[i][1]
        wx, wy = px - pts[i][0], py - pts[i][1]
        h = max(0.0, min(1.0, (wx * ex + wy * ey) / (ex * ex + ey * ey)))
        bx, by = wx - ex * h, wy - ey * h
        d = min(d, bx * bx + by * by)
        c1 = py >= pts[i][1]
        c2 = py < pts[j][1]
        c3 = ex * wy > ey * wx
        if (c1 and c2 and c3) or (not c1 and not c2 and not c3):
            s = -s
        j = i
    return s * math.sqrt(d)


def cover(d, aa=0.75):
    """Coverage (0..1) of a pixel whose centre is at signed distance d."""
    return max(0.0, min(1.0, 0.5 - d / (2 * aa)))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]

    def blend(self, x, y, rgb, a):
        """Source-over blend of straight-alpha colour."""
        if a <= 0:
            return
        p = self.px[y * self.w + x]
        da = p[3]
        oa = a + da * (1 - a)
        if oa <= 0:
            return
        for i in range(3):
            p[i] = (rgb[i] * a + p[i] * da * (1 - a)) / oa
        p[3] = oa

    def add(self, x, y, rgb, a):
        """Additive glow (keeps hue, raises alpha)."""
        if a <= 0:
            return
        p = self.px[y * self.w + x]
        da = p[3]
        oa = min(1.0, da + a)
        if oa <= 0:
            return
        for i in range(3):
            p[i] = min(1.0, (p[i] * da + rgb[i] * a) / oa)
        p[3] = oa

    def shade(self, fn, bbox=None, mode="blend"):
        """fn(x+0.5, y+0.5) -> (rgb, alpha) or None, applied to every pixel (in bbox)."""
        x0, y0, x1, y1 = bbox or (0, 0, self.w, self.h)
        x0, y0 = max(0, int(x0)), max(0, int(y0))
        x1, y1 = min(self.w, int(math.ceil(x1))), min(self.h, int(math.ceil(y1)))
        op = self.blend if mode == "blend" else self.add
        for y in range(y0, y1):
            for x in range(x0, x1):
                r = fn(x + 0.5, y + 0.5)
                if r is not None:
                    op(x, y, r[0], r[1])

    def save(self, path):
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for x in range(self.w):
                p = self.px[y * self.w + x]
                raw += bytes(int(round(max(0, min(1, v)) * 255)) for v in p)

        def chunk(tag, data):
            c = struct.pack(">I", len(data)) + tag + data
            return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)
