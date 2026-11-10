"""The image-kit pipeline (BAD_GUI_3_EGG_SHOP.md section 3): owner component sheets -> clean pieces.

  python scripts/art/cut_sheet.py cut <sheet.png> [--name NAME] [--bg auto|magenta|white|alpha]
                                      [--min-area 400] [--pad 4] [--merge 18]
      background -> transparent (soft edge + magenta de-fringe), one piece per connected region
      (small fragments merged into their nearest piece), trimmed, saved as
      art/ui/kit-v3/<name>_<n>.png in reading order, added to art/ui/kit-v3/kit.json as REVIEW,
      and a numbered contact sheet docs/review/<name>_cut.png.
  python scripts/art/cut_sheet.py slicetest <name>
      renders every piece of that sheet that has 9-slice margins, stretched to 3 sizes, into
      docs/review/<name>_slice_test.png (corners must stay crisp).
  python scripts/art/cut_sheet.py luau
      writes src/shared/Config/UiKit.luau from kit.json: LIVE pieces (approved + uploaded) and TEMP
      pieces with the Config/UiAssets slot they fall back to.
  python scripts/art/cut_sheet.py selftest
      cuts a synthetic sheet and checks the result.

Rules (CLAUDE.md "Asset safety"): sheets in art/ui/sheets/ are never edited; pieces are copies.
A piece is REVIEW until the owner OKs its contact sheet (APPROVED), then uploaded in batches of
5 or fewer (LIVE, with its asset id). Never run this on a REFERENCE-ONLY image.
"""
import json
import os
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
KIT_DIR = os.path.join(ROOT, "art", "ui", "kit-v3")
KIT_JSON = os.path.join(KIT_DIR, "kit.json")
REVIEW = os.path.join(ROOT, "docs", "review")
FONT = os.path.join(ROOT, "art", "fonts", "TitanOne-Regular.ttf")
MAX_PX = 1024
STATUSES = ("TEMP", "REVIEW", "APPROVED", "LIVE")


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


# ------------------------------------------------------------------------------- kit.json

def load_kit():
    if os.path.exists(KIT_JSON):
        with open(KIT_JSON, encoding="utf-8") as f:
            return json.load(f)
    return {"note": "Piece -> file, size, 9-slice margins (left, top, right, bottom in px), asset id, "
                    "tint, status (TEMP | REVIEW | APPROVED | LIVE), the UiAssets slot it replaces once "
                    "LIVE, and its source. Written by scripts/art/cut_sheet.py; names are edited by hand.",
            "pieces": {}}


def save_kit(kit):
    os.makedirs(KIT_DIR, exist_ok=True)
    for name, p in kit["pieces"].items():
        assert p.get("status") in STATUSES, f"{name}: bad status {p.get('status')}"
        if p["status"] == "LIVE":
            assert p.get("assetId"), f"{name}: LIVE needs an assetId"
    with open(KIT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(kit, f, indent=1, sort_keys=True)
        f.write("\n")


# ------------------------------------------------------------------------------- background

def background_alpha(rgb, mode):
    """Alpha in 0..1 from the background: 0 on the key colour, 1 far from it, soft in between."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    if mode == "magenta":
        # Distance from #FF00FF, measured mostly on green (magenta has none) and the R/B balance.
        d = np.maximum.reduce([g, 255 - r, 255 - b]).astype(np.float32)
        return np.clip((d - 40) / 60, 0, 1)
    if mode == "white":
        d = (255 - np.minimum.reduce([r, g, b])).astype(np.float32)
        return np.clip((d - 18) / 40, 0, 1)
    raise ValueError(mode)


def guess_bg(img):
    a = np.asarray(img.convert("RGBA"))
    if (a[..., 3] < 16).mean() > 0.2:
        return "alpha"
    border = np.concatenate([a[0, :, :3], a[-1, :, :3], a[:, 0, :3], a[:, -1, :3]])
    mean = border.mean(axis=0)
    if mean[0] > 200 and mean[2] > 200 and mean[1] < 80:
        return "magenta"
    if mean.min() > 225:
        return "white"
    raise SystemExit(f"can't tell the background (border mean {mean.round()}): pass --bg")


def defringe(rgba, alpha):
    """Removes magenta spill from soft edge pixels: where R and B both exceed G on a partly
    transparent pixel, pull them down toward G."""
    out = rgba.astype(np.float32)
    r, g, b = out[..., 0], out[..., 1], out[..., 2]
    m = np.minimum(r, b)
    spill = np.clip(m - g, 0, None) * (alpha < 0.98)
    out[..., 0] = r - spill
    out[..., 2] = b - spill
    return out


def to_rgba(img, mode):
    if mode == "alpha":
        return np.asarray(img.convert("RGBA")).astype(np.float32)
    rgb = np.asarray(img.convert("RGB"))
    alpha = background_alpha(rgb, mode)
    rgba = np.dstack([rgb.astype(np.float32), alpha * 255])
    if mode == "magenta":
        rgba = defringe(rgba, alpha)
    return rgba


# ------------------------------------------------------------------------------- pieces

def find_pieces(alpha, min_area, merge):
    """Bounding boxes (x0, y0, x1, y1) of the pieces, small fragments merged into their nearest."""
    solid = alpha > 0.12
    grown = ndimage.binary_dilation(solid, iterations=max(1, merge // 2)) if merge > 0 else solid
    labels, n = ndimage.label(grown)
    boxes = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        if sl is None:
            continue
        area = int((solid[sl] & (labels[sl] == i)).sum())
        boxes.append([sl[1].start, sl[0].start, sl[1].stop, sl[0].stop, area])
    big = [b for b in boxes if b[4] >= min_area]
    small = [b for b in boxes if b[4] < min_area]
    for s in small:  # merge into the nearest big box (gap between boxes)
        if not big:
            break
        def gap(b):
            dx = max(b[0] - s[2], s[0] - b[2], 0)
            dy = max(b[1] - s[3], s[1] - b[3], 0)
            return dx * dx + dy * dy
        t = min(big, key=gap)
        if gap(t) <= (merge * 4) ** 2:
            t[0], t[1], t[2], t[3] = min(t[0], s[0]), min(t[1], s[1]), max(t[2], s[2]), max(t[3], s[3])
    # reading order: rows (by centre y, banded by the median height), then x
    if not big:
        return []
    band = max(1, int(np.median([b[3] - b[1] for b in big]) * 0.6))
    big.sort(key=lambda b: (((b[1] + b[3]) // 2) // band, b[0]))
    return [tuple(b[:4]) for b in big]


def crop_piece(rgba, box, pad):
    h, w = rgba.shape[:2]
    x0, y0, x1, y1 = box
    x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)
    piece = rgba[y0:y1, x0:x1].copy()
    ys, xs = np.nonzero(piece[..., 3] > 3)
    if len(xs):
        piece = piece[max(0, ys.min() - pad):ys.max() + pad + 1, max(0, xs.min() - pad):xs.max() + pad + 1]
    return Image.fromarray(np.clip(piece, 0, 255).astype(np.uint8), "RGBA")


def checker(size, cell=12):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    c = (((xx // cell) + (yy // cell)) % 2 * 30 + 40).astype(np.uint8)
    return Image.fromarray(np.dstack([c, c, c + 10, np.full_like(c, 255)]), "RGBA")


def contact(name, files, out):
    cell, cols = 220, 5
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 30) + 50), (10, 9, 28, 255))
    d = ImageDraw.Draw(sheet)
    d.text((10, 10), f"{name}: {len(files)} pieces (REVIEW, needs the owner's OK)", font=font(22), fill=(255, 226, 122))
    for i, (num, path) in enumerate(files):
        im = Image.open(path).convert("RGBA")
        w, h = im.size
        im.thumbnail((cell - 16, cell - 16))
        x, y = (i % cols) * cell, 50 + (i // cols) * (cell + 30)
        bg = checker((cell - 8, cell - 8))
        bg.alpha_composite(im, ((cell - 8 - im.width) // 2, (cell - 8 - im.height) // 2))
        sheet.alpha_composite(bg, (x + 4, y + 4))
        d.text((x + 8, y + cell - 2), f"#{num}  {w}x{h}", font=font(16), fill=(242, 245, 255))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.convert("RGB").save(out)


def cut(path, name=None, bg="auto", min_area=400, pad=4, merge=18, out_dir=None, review_dir=None, kit=None):
    name = name or os.path.splitext(os.path.basename(path))[0]
    out_dir = out_dir or KIT_DIR
    review_dir = review_dir or REVIEW
    img = Image.open(path)
    mode = guess_bg(img) if bg == "auto" else bg
    rgba = to_rgba(img, mode)
    boxes = find_pieces(rgba[..., 3] / 255, min_area, merge)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for n, box in enumerate(boxes, start=1):
        piece = crop_piece(rgba, box, pad)
        if max(piece.size) > MAX_PX:  # Roblox shrinks anything over 1024 px
            piece.thumbnail((MAX_PX, MAX_PX), Image.LANCZOS)
        p = os.path.join(out_dir, f"{name}_{n}.png")
        piece.save(p)
        written.append((n, p))
        if kit is not None:
            key = f"{name}_{n}"
            old = kit["pieces"].get(key, {})
            kit["pieces"][key] = {
                "file": os.path.relpath(p, ROOT).replace("\\", "/"),
                "sheet": os.path.relpath(path, ROOT).replace("\\", "/"),
                "size": list(piece.size),
                "slice": old.get("slice"),
                "assetId": old.get("assetId", ""),
                "tint": old.get("tint"),
                "replaces": old.get("replaces"),
                "status": old.get("status", "REVIEW") if old.get("status") != "LIVE" else "LIVE",
            }
    contact(name, written, os.path.join(review_dir, f"{name}_cut.png"))
    return mode, written


# ------------------------------------------------------------------------------- 9-slice test

def nine_slice(im, margins, size):
    """Draws `im` 9-sliced to `size`: corners kept at 1:1, edges and centre stretched."""
    l, t, r, b = margins
    w, h = im.size
    W, H = size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    xs_src, xs_dst = [0, l, w - r, w], [0, l, W - r, W]
    ys_src, ys_dst = [0, t, h - b, h], [0, t, H - b, H]
    for i in range(3):
        for j in range(3):
            sx0, sx1, dx0, dx1 = xs_src[i], xs_src[i + 1], xs_dst[i], xs_dst[i + 1]
            sy0, sy1, dy0, dy1 = ys_src[j], ys_src[j + 1], ys_dst[j], ys_dst[j + 1]
            if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
                continue
            tile = im.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS)
            out.paste(tile, (dx0, dy0))  # an exact copy: corners must stay pixel-identical
    return out


def slicetest(name, kit=None):
    kit = kit or load_kit()
    pieces = [(k, p) for k, p in sorted(kit["pieces"].items())
              if (k.startswith(name + "_") or (p.get("sheet") or "").endswith(name + ".png") or k == name) and p.get("slice")]
    if not pieces:
        raise SystemExit(f"no pieces of {name} have 9-slice margins yet (set 'slice' in kit.json)")
    rows = []
    for key, p in pieces:
        im = Image.open(os.path.join(ROOT, p["file"])).convert("RGBA")
        w, h = im.size
        sizes = [(w, h), (int(w * 1.8), int(h * 0.8) or h), (int(w * 0.75) or w, int(h * 1.6))]
        rows.append((key, [nine_slice(im, p["slice"], s) for s in sizes]))
    W = max(sum(t.width for t in ts) + 40 * len(ts) for _, ts in rows) + 20
    H = sum(max(t.height for t in ts) + 50 for _, ts in rows) + 20
    sheet = Image.new("RGBA", (W, H), (10, 9, 28, 255))
    d = ImageDraw.Draw(sheet)
    y = 10
    for key, tiles in rows:
        d.text((10, y), key, font=font(18), fill=(255, 226, 122))
        x = 10
        for t in tiles:
            sheet.alpha_composite(checker(t.size), (x, y + 30))
            sheet.alpha_composite(t, (x, y + 30))
            x += t.width + 40
        y += max(t.height for t in tiles) + 50
    out = os.path.join(REVIEW, f"{name}_slice_test.png")
    sheet.convert("RGB").save(out)
    return out


# ------------------------------------------------------------------------------- Luau

def write_luau(kit=None):
    """Config/UiKit.luau: LIVE pieces with their asset id, and TEMP pieces with the Config/UiAssets
    slot they fall back to. REVIEW and APPROVED pieces are not usable yet and are left out."""
    kit = kit or load_kit()
    usable = {k: p for k, p in kit["pieces"].items()
              if p["status"] == "LIVE" or (p["status"] == "TEMP" and p.get("fallback"))}
    lines = ["--!strict",
             "-- Generated by `python scripts/art/cut_sheet.py luau` from art/ui/kit-v3/kit.json. Do not edit.",
             "-- The painted UI pieces by name (App/Kit.piece): LIVE pieces (owner-approved and uploaded) with",
             "-- their image, TEMP pieces with the Config/UiAssets slot drawn until theirs is live. A LIVE",
             "-- piece that `replaces` a UiAssets slot is used wherever that slot is drawn (App/Ui.asset).",
             "",
             "export type Piece = {",
             "\tid: string?, -- LIVE: the uploaded image",
             "\tfallback: string?, -- TEMP: the Config/UiAssets slot used until then",
             "\tsize: { number }?,",
             "\tslice: { number }?, -- 9-slice margins: left, top, right, bottom (px)",
             "\ttint: string?,",
             "\treplaces: string?,",
             "}",
             "",
             "local Pieces: { [string]: Piece } = {"]
    for k in sorted(usable):
        p = usable[k]
        parts = []
        if p["status"] == "LIVE":
            parts.append(f'id = "{p["assetId"]}"')
            parts.append(f'size = {{ {p["size"][0]}, {p["size"][1]} }}')
            if p.get("slice"):
                parts.append("slice = { " + ", ".join(str(v) for v in p["slice"]) + " }")
            if p.get("replaces"):
                parts.append(f'replaces = "{p["replaces"]}"')
        else:
            parts.append(f'fallback = "{p["fallback"]}"')
        if p.get("tint"):
            parts.append(f'tint = "{p["tint"]}"')
        lines.append(f"\t{k} = {{ " + ", ".join(parts) + " },")
    lines += ["}", "", "return table.freeze({ Pieces = table.freeze(Pieces) })", ""]
    out = os.path.join(ROOT, "src", "shared", "Config", "UiKit.luau")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    return out, len(usable)


# ------------------------------------------------------------------------------- selftest

def selftest():
    tmp = tempfile.mkdtemp(prefix="cut_sheet_")
    W, H = 900, 600
    sheet = Image.new("RGB", (W, H), (255, 0, 255))
    d = ImageDraw.Draw(sheet)
    # three panels, a round button, and a sparkle right next to the button (must merge into it)
    d.rounded_rectangle((40, 40, 300, 220), 30, fill=(70, 40, 140), outline=(255, 200, 60), width=8)
    d.rounded_rectangle((360, 40, 620, 220), 30, fill=(40, 90, 160), outline=(120, 220, 255), width=8)
    d.rounded_rectangle((680, 60, 860, 200), 40, fill=(250, 190, 40), outline=(120, 70, 0), width=6)
    d.ellipse((80, 320, 240, 480), fill=(200, 40, 60), outline=(255, 255, 255), width=6)
    d.polygon([(258, 330), (264, 342), (276, 344), (264, 348), (258, 360), (252, 348), (240, 344), (252, 342)], fill=(255, 255, 210))
    d.rectangle((400, 330, 820, 420), fill=(30, 200, 120))
    # soft anti-aliased edge: blend a few magenta-tinted pixels around the last box
    big = sheet.resize((W * 2, H * 2), Image.NEAREST).resize((W, H), Image.LANCZOS)
    src = os.path.join(tmp, "synthetic.png")
    big.save(src)
    kit = {"pieces": {}}
    mode, pieces = cut(src, "synthetic", out_dir=os.path.join(tmp, "kit"), review_dir=tmp, kit=kit)
    assert mode == "magenta", mode
    assert len(pieces) == 5, f"expected 5 pieces (sparkle merged into the button), got {len(pieces)}"
    for _, p in pieces:
        a = np.asarray(Image.open(p).convert("RGBA")).astype(int)
        vis = a[..., 3] > 40
        pink = (a[..., 0] > 200) & (a[..., 2] > 200) & (a[..., 1] < 60) & vis
        assert pink.sum() == 0, f"{p}: {pink.sum()} magenta pixels left"
        assert a[0, :, 3].max() < 40 or a[:, 0, 3].max() < 40, f"{p}: not trimmed with a clear edge"
    first = Image.open(pieces[0][1])
    assert abs(first.width - 270) < 16 and abs(first.height - 190) < 16, first.size
    kit["pieces"]["synthetic_1"]["slice"] = [40, 40, 40, 40]
    im = Image.open(pieces[0][1]).convert("RGBA")
    stretched = nine_slice(im, [40, 40, 40, 40], (im.width * 2, im.height))
    assert stretched.size == (im.width * 2, im.height)
    # corners stay 1:1
    assert np.array_equal(np.asarray(stretched)[:40, :40], np.asarray(im)[:40, :40])
    print(f"selftest ok: {len(pieces)} pieces, magenta removed, corners kept ({tmp})")


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    cmd = sys.argv[1]
    if cmd == "selftest":
        selftest()
    elif cmd == "cut":
        args = sys.argv[2:]
        def opt(flag, default, cast=str):
            return cast(args[args.index(flag) + 1]) if flag in args else default
        kit = load_kit()
        mode, written = cut(args[0], opt("--name", None), opt("--bg", "auto"), opt("--min-area", 400, int),
                            opt("--pad", 4, int), opt("--merge", 18, int), kit=kit)
        save_kit(kit)
        print(f"{mode} background: {len(written)} pieces -> art/ui/kit-v3, contact sheet in docs/review")
    elif cmd == "slicetest":
        print(slicetest(sys.argv[2]))
    elif cmd == "luau":
        out, n = write_luau()
        print(f"wrote {out} ({n} usable pieces: LIVE, or TEMP with a fallback)")
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
