"""Composites kit layers into preview sheets (docs/screens/step5/...)."""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import kitlib as K

KIT = os.path.join(K.ROOT, "art", "ui", "kit")
BG = (8, 7, 30, 255)


def card(tag, size, golden=False, panel=True, extra=None):
    """Stack: glow, panel, extra (emblem/art), energy, frame, golden."""
    layers = [f"glow_{tag}_{size}"] + ([f"panel_{tag}_{size}"] if panel else [])
    base = Image.open(os.path.join(KIT, f"frame_{tag}_{size}.png"))
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    for name in layers:
        out.alpha_composite(Image.open(os.path.join(KIT, name + ".png")))
    if extra is not None:
        out.alpha_composite(extra)
    for name in [f"energy_{tag}_{size}", f"frame_{tag}_{size}"] + ([f"golden_{size}"] if golden else []):
        out.alpha_composite(Image.open(os.path.join(KIT, name + ".png")))
    return out


def sheet(images, gap=16, bg=BG):
    w = sum(i.width for i in images) + gap * (len(images) + 1)
    h = max(i.height for i in images) + 2 * gap
    s = Image.new("RGBA", (w, h), bg)
    x = gap
    for i in images:
        s.alpha_composite(i, (x, gap + (h - 2 * gap - i.height) // 2))
        x += i.width + gap
    return s


if __name__ == "__main__":
    tags = sys.argv[2:] or ["n", "r", "sr", "ssr", "ur"]
    size = sys.argv[1]
    out = sheet([card(t, size) for t in tags])
    out.save(os.path.join(os.environ.get("OUT", "."), f"preview_{size}.png"))


def board04(size="medium"):
    """Board 04's layout: five empty frames, each with its badge centred over the top edge."""
    cells = []
    for t in ["n", "r", "sr", "ssr", "ur"]:
        c = card(t, size)
        badge = Image.open(os.path.join(KIT, f"badge_{t}_large.png"))
        bw = int(c.width * 0.62)
        badge = badge.resize((bw, bw // 2), Image.LANCZOS)
        cell = Image.new("RGBA", (c.width, c.height + bw // 4), (0, 0, 0, 0))
        cell.alpha_composite(c, (0, bw // 4))
        cell.alpha_composite(badge, ((c.width - bw) // 2, 0))
        cells.append(cell)
    return sheet(cells, gap=4)
