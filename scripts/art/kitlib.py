"""Shared drawing helpers for the step-5 art kit (card_kit.py, ui_kit.py, egg compositing).

Pure numpy + Pillow. Everything is drawn supersampled (SS x the final size) as float RGBA
arrays in 0..1 with *straight* alpha, then downsampled with a box filter and written as PNG.
Shapes are 2D signed distance fields (negative inside), so bevels, glows and outlines all come
from the same geometry.

Run with a Python that has numpy and Pillow (see scripts/art/README in the mission notes):
the Blender-bundled Python works: <blender>/5.2/python/bin/python.exe.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FONTS = os.path.join(ROOT, "art", "fonts")


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)], dtype=np.float32)


# ------------------------------------------------------------------ canvas


def grid(w, h, ss, cx=None, cy=None):
    """Pixel-centre coordinates in *final* pixels (so shape sizes don't depend on ss)."""
    cx = w / 2 if cx is None else cx
    cy = h / 2 if cy is None else cy
    xs = (np.arange(w * ss, dtype=np.float32) + 0.5) / ss - cx
    ys = (np.arange(h * ss, dtype=np.float32) + 0.5) / ss - cy
    return np.meshgrid(xs, ys)


def blank(w, h, ss):
    return np.zeros((h * ss, w * ss, 4), dtype=np.float32)


def over(dst, rgb, alpha):
    """Composite a layer (rgb HxWx3 or a colour, alpha HxW) over dst (straight alpha)."""
    a = np.clip(alpha, 0, 1)[..., None]
    rgb = np.broadcast_to(np.asarray(rgb, dtype=np.float32), dst[..., :3].shape)
    da = dst[..., 3:4]
    oa = a + da * (1 - a)
    safe = np.where(oa > 1e-6, oa, 1)
    dst[..., :3] = (rgb * a + dst[..., :3] * da * (1 - a)) / safe
    dst[..., 3:4] = oa
    return dst


def add_light(dst, rgb, amount):
    """Additive light (glow, energy): brightens colour and raises alpha."""
    a = np.clip(amount, 0, 1)[..., None]
    rgb = np.asarray(rgb, dtype=np.float32)
    da = dst[..., 3:4]
    oa = np.clip(da + a * (1 - da), 0, 1)
    safe = np.where(oa > 1e-6, oa, 1)
    col = (dst[..., :3] * da + rgb * a) / safe
    dst[..., :3] = np.clip(col, 0, 1)
    dst[..., 3:4] = oa
    return dst


def edge_fade(arr, ss, margin):
    """Fade alpha to zero within `margin` final px of the canvas edge (glows never clip hard)."""
    h, w = arr.shape[0], arr.shape[1]
    yy = np.minimum(np.arange(h), np.arange(h)[::-1]) / (margin * ss)
    xx = np.minimum(np.arange(w), np.arange(w)[::-1]) / (margin * ss)
    f = np.clip(np.minimum(yy[:, None], xx[None, :]), 0, 1)
    arr[..., 3] *= f * f * (3 - 2 * f)
    return arr


def save(arr, ss, path, size=None):
    """Downsample by ss (box filter on premultiplied colour) and write an RGBA PNG."""
    h, w = arr.shape[0] // ss, arr.shape[1] // ss
    a = arr[..., 3:4]
    pm = np.concatenate([arr[..., :3] * a, a], axis=2)
    pm = pm[: h * ss, : w * ss].reshape(h, ss, w, ss, 4).mean(axis=(1, 3))
    alpha = pm[..., 3:4]
    rgb = np.where(alpha > 1e-6, pm[..., :3] / np.maximum(alpha, 1e-6), 0)
    out = np.concatenate([rgb, alpha], axis=2)
    img = Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    if size and (img.width, img.height) != tuple(size):
        img = img.resize(size, Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return img


# ------------------------------------------------------------------ blur


def _box(a, r, axis):
    if r < 1:
        return a
    n = a.shape[axis]
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="constant"), axis=axis, dtype=np.float64)
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def blur(a, sigma):
    """Gaussian-ish blur (three box passes) of a 2D array; sigma in array pixels."""
    if sigma <= 0.3:
        return a
    r = max(1, int(round(math.sqrt(12 * sigma * sigma / 3 + 1) / 2)))
    for _ in range(3):
        a = _box(a, r, 0)
        a = _box(a, r, 1)
    return a


def fast_blur(a, sigma):
    """Blur at reduced resolution for big radii (glows), then scale back up."""
    if sigma < 6:
        return blur(a, sigma)
    f = int(min(8, sigma // 3))
    h, w = a.shape
    hh, ww = h // f, w // f
    small = a[: hh * f, : ww * f].reshape(hh, f, ww, f).mean(axis=(1, 3))
    small = blur(small, sigma / f)
    img = Image.fromarray(small.astype(np.float32), "F").resize((w, h), Image.BILINEAR)
    return np.asarray(img, dtype=np.float32)


# ------------------------------------------------------------------ SDFs (final-pixel units)


def sd_box(x, y, hx, hy):
    qx, qy = np.abs(x) - hx, np.abs(y) - hy
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0)


def sd_chamfer_box(x, y, hx, hy, c):
    """Box with 45-degree chamfered corners of size c."""
    ax, ay = np.abs(x), np.abs(y)
    d = sd_box(x, y, hx, hy)
    return np.maximum(d, (ax + ay - (hx + hy - c)) / math.sqrt(2))


def sd_round_box(x, y, hx, hy, r):
    return sd_box(x, y, hx - r, hy - r) - r


def sd_rhombus(x, y, hx, hy):
    """Diamond centred at 0 with half-diagonals hx, hy (approximate, exact on the axes)."""
    return (np.abs(x) / hx + np.abs(y) / hy - 1) * (hx * hy / math.hypot(hx, hy))


def sd_blade(x, y, p0, p1, r0, r1):
    """Tapered capsule from p0 (radius r0) to p1 (radius r1): spikes, leaves, rays."""
    bx, by = p1[0] - p0[0], p1[1] - p0[1]
    px, py = x - p0[0], y - p0[1]
    t = np.clip((px * bx + py * by) / (bx * bx + by * by), 0, 1)
    return np.hypot(px - bx * t, py - by * t) - (r0 + (r1 - r0) * t)


def sd_circle(x, y, cx, cy, r):
    return np.hypot(x - cx, y - cy) - r


def sd_ring(x, y, cx, cy, r, th):
    return np.abs(np.hypot(x - cx, y - cy) - r) - th / 2


def sd_star(x, y, cx, cy, r, inner=0.45, n=5, rot=-math.pi / 2):
    """Exact-enough n-pointed star."""
    px, py = x - cx, y - cy
    ang = np.arctan2(py, px) - rot
    seg = 2 * math.pi / n
    a = np.mod(ang + seg / 2, seg) - seg / 2
    rr = np.hypot(px, py)
    qx, qy = rr * np.cos(a), np.abs(rr * np.sin(a))
    # edge from the tip (r, 0) to the inner vertex
    ix, iy = r * inner * math.cos(seg / 2), r * inner * math.sin(seg / 2)
    ex, ey = ix - r, iy
    t = np.clip(((qx - r) * ex + qy * ey) / (ex * ex + ey * ey), 0, 1)
    d = np.hypot(qx - r - ex * t, qy - ey * t)
    side = (qx - r) * ey - qy * ex
    return np.where(side > 0, -d, d) * -1


def union(*ds):
    out = ds[0]
    for d in ds[1:]:
        out = np.minimum(out, d)
    return out


def smooth_union(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def cover(d, ss):
    """Anti-aliased coverage of a final-pixel SDF on an ss grid."""
    return np.clip(0.5 - d * ss, 0, 1)


# ------------------------------------------------------------------ shading


def bevel_normal(d, bevel, ss, profile="round"):
    """Height field from the distance inside the shape; returns (nx, ny, nz, height)."""
    t = np.clip(-d / bevel, 0, 1)
    if profile == "round":
        hgt = np.sqrt(1 - (1 - t) ** 2)
    else:
        hgt = t
    gy, gx = np.gradient(hgt * bevel * ss)
    nz = np.ones_like(gx)
    n = np.sqrt(gx * gx + gy * gy + nz * nz)
    return -gx / n, -gy / n, nz / n, hgt


def metal(nx, ny, nz, ramp, y=None, light=(-0.45, -0.7, 0.55), spec=28, sheen=0.0):
    """Polished metal: a 4-stop ramp (shadow, base, bright, highlight) indexed by lighting, plus
    a specular highlight and an optional top-to-bottom sheen (y in -1..1)."""
    lx, ly, lz = light
    ln = math.sqrt(lx * lx + ly * ly + lz * lz)
    lx, ly, lz = lx / ln, ly / ln, lz / ln
    diff = np.clip(nx * lx + ny * ly + nz * lz, 0, 1)
    # reflection of the view vector (0,0,1) about n, dotted with the light
    rz = 2 * nz * nz - 1
    rx, ry = 2 * nz * nx, 2 * nz * ny
    sp = np.clip(rx * lx + ry * ly + rz * lz, 0, 1) ** spec
    k = diff
    if y is not None and sheen:
        k = np.clip(k + sheen * (-y), 0, 1)
    stops = [hexc(s) if isinstance(s, str) else s for s in ramp]
    pos = np.array([0.0, 0.45, 0.8, 1.0])
    out = np.zeros(nx.shape + (3,), dtype=np.float32)
    for i in range(3):
        a, b = pos[i], pos[i + 1]
        m = (k >= a) & (k <= b)
        f = ((k - a) / (b - a))[..., None]
        out = np.where(m[..., None], stops[i] * (1 - f) + stops[i + 1] * f, out)
    out = out + sp[..., None] * 0.9
    return np.clip(out, 0, 1)


def gem(x, y, cx, cy, hx, hy, ramp):
    """A faceted diamond gem: four facets lit differently plus a table highlight."""
    px, py = x - cx, y - cy
    d = sd_rhombus(px, py, hx, hy)
    stops = [hexc(s) for s in ramp]
    # facet brightness: top-left brightest, bottom-right darkest
    fac = np.where(px < 0, np.where(py < 0, 1.0, 0.55), np.where(py < 0, 0.75, 0.3))
    inner = sd_rhombus(px, py, hx * 0.45, hy * 0.45) < 0
    fac = np.where(inner, 0.95, fac)
    col = np.where(
        (fac < 0.6)[..., None],
        stops[0] * (1 - fac[..., None] / 0.6) + stops[1] * (fac[..., None] / 0.6),
        stops[1] * (1 - (fac[..., None] - 0.6) / 0.4) + stops[2] * ((fac[..., None] - 0.6) / 0.4),
    )
    col = np.where((fac > 0.9)[..., None], stops[3] * 0.35 + col * 0.65, col)
    return d, np.clip(col, 0, 1)


# ------------------------------------------------------------------ text


def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), int(size))


def text_mask(text, fnt, w, h, ss, shear=0.0, cx=None, cy=None, tracking=0):
    """Text as a coverage mask (h*ss x w*ss), centred, optionally sheared (italic)."""
    W, H = w * ss, h * ss
    img = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(img)
    f = fnt
    widths = [dr.textlength(ch, font=f) for ch in text]
    total = sum(widths) + tracking * ss * (len(text) - 1)
    bbox = dr.textbbox((0, 0), text, font=f)
    th = bbox[3] - bbox[1]
    x = (W - total) / 2 if cx is None else cx * ss - total / 2
    y = (H - th) / 2 - bbox[1] if cy is None else cy * ss - th / 2 - bbox[1]
    for ch, cw in zip(text, widths):
        dr.text((x, y), ch, font=f, fill=255)
        x += cw + tracking * ss
    if shear:
        img = img.transform(img.size, Image.AFFINE, (1, shear, -shear * H / 2, 0, 1, 0), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255


def dilate(mask, r):
    """Round dilation of a coverage mask by r array pixels (via blur + threshold, soft edge)."""
    if r <= 0:
        return mask
    b = blur(mask, r * 0.5)
    return np.clip((b - 0.02) * 4 + mask, 0, 1) if r < 2 else np.clip(fast_blur(mask, r / 1.6) * 6, 0, 1)


def distance_outside(mask, max_r):
    """Approximate distance (array px) from the mask, by repeated 3x3 max filters, capped."""
    d = np.full(mask.shape, float(max_r), dtype=np.float32)
    cur = mask > 0.5
    d[cur] = 0
    for i in range(1, int(max_r) + 1):
        nxt = cur.copy()
        nxt[1:] |= cur[:-1]
        nxt[:-1] |= cur[1:]
        nxt[:, 1:] |= cur[:, :-1]
        nxt[:, :-1] |= cur[:, 1:]
        new = nxt & ~cur
        d[new] = i
        cur = nxt
    return d


# ------------------------------------------------------------------ lightning


def bolt(rng, p0, p1, rough=0.35, depth=5):
    """Midpoint-displacement lightning between two points (final px). Returns a point list."""
    pts = [p0, p1]
    disp = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * rough
    for _ in range(depth):
        nxt = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy) or 1
            off = rng.uniform(-disp, disp)
            nxt += [(mx - dy / ln * off, my + dx / ln * off), b]
        pts = nxt
        disp *= 0.55
    return pts


def draw_polyline(mask_img, pts, ss, width):
    dr = ImageDraw.Draw(mask_img)
    sp = [(x * ss, y * ss) for x, y in pts]
    dr.line(sp, fill=255, width=max(1, int(round(width * ss))), joint="curve")
