"""Step-5 UI kit, route C (code) plus finishing passes on route-B Blender renders.

  python scripts/art/ui_kit.py [group ...]

Groups (default: all):
  emblems   art/ui/kit/raw/emblem_*.png (Blender) -> art/ui/kit/emblem_*.png, 256 px, soft glow
  extras    section 6 assets drawn in code (stickers, ribbon, stat and button icons, level bar,
            summon circle and runes, cracks, shockwave, rays, pillar, auras, orbit ribbon,
            particles, lock, world badge, card backs, filter chips, toasts, confetti, empty slot,
            odds rows, family gems)
Everything is drawn supersampled with kitlib and written at its final size.
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import kitlib as K  # noqa: E402

KIT = os.path.join(K.ROOT, "art", "ui", "kit")
RAW = os.path.join(KIT, "raw")


def finish_render(src, dst, size, glow_color, glow=0.6, pad=0.1):
    """Trim a Blender render, fit it into `size` with padding, and add a soft glow behind it."""
    im = Image.open(src).convert("RGBA")
    bbox = im.getbbox()
    im = im.crop(bbox)
    w, h = size
    inner = (int(w * (1 - 2 * pad)), int(h * (1 - 2 * pad)))
    s = min(inner[0] / im.width, inner[1] / im.height)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(im, ((w - im.width) // 2, (h - im.height) // 2))
    arr = np.asarray(canvas, dtype=np.float32) / 255
    a = arr[..., 3]
    halo = np.clip(K.fast_blur(a, w * 0.035) * 1.2 + K.fast_blur(a, w * 0.08) * 0.8, 0, 1) * glow
    out = np.zeros_like(arr)
    out[..., :3] = K.hexc(glow_color)
    out[..., 3] = halo
    K.over(out, arr[..., :3], a)
    K.edge_fade(out, 1, max(2, w * 0.03))
    K.save(out, 1, dst)


def emblems():
    for name, col in [
        ("emblem_star_silver", "#E8E6FF"),
        ("emblem_star_blue", "#1EA8FF"),
        ("emblem_star_gold", "#FFB01E"),
        ("emblem_crown_gold", "#FFB01E"),
    ]:
        finish_render(os.path.join(RAW, name + ".png"), os.path.join(KIT, name + ".png"), (256, 256), col)
        print("emblem", name)


import ui_extras as X  # noqa: E402


def extras():
    for fn in X.ALL:
        fn()
        print("extras", fn.__name__, flush=True)


GROUPS = {"emblems": emblems, "extras": extras}
GROUPS.update({fn.__name__: fn for fn in X.ALL})

if __name__ == "__main__":
    for g in sys.argv[1:] or list(GROUPS):
        GROUPS[g]()
