"""Character PNG pipeline (MISSION section 12), first batch: the portrait pack.

  python scripts/art/portraits.py ingest <folder> [batch]   copy the originals, unchanged, to
                                                         art/characters/incoming/<batch>/ (git-ignored)
                                                         and flag the batch TEMP_UNLICENSED if it has
                                                         no LICENSE.txt
  python scripts/art/portraits.py process [batch]        split -> clean -> upscale -> style -> safe ->
                                                         derive, for every mapped character
  python scripts/art/portraits.py check [batch]          sizes, transparency, duplicates, contact sheet
  python scripts/art/portraits.py urls                    upload URLs for the processed card.png files
  python scripts/art/characters.py apply <ids.json>      write the uploaded ids into Config/Characters
                                                         (assets.cardArt); accepts processed/<id>/card.png
  python scripts/art/portraits.py status                 how many characters have final / temp / no art

Steps (all on copies; originals are never edited):
  split    every sheet -> faces, by alpha connected components (pieces closer than a few px merge,
           fragments under 2% of the sheet are dropped); opaque near-white framing (one sheet uses
           white cards) is keyed out from the crop's edges first
  clean    fringe and halo removal (alpha below 40 cut, 1 px erode), small holes closed, 1 px feather,
           trimmed
  upscale  Lanczos to the output size plus a light unsharp mask, never more than 4x (no Real-ESRGAN
           on this machine)
  style    one colour grade for all (contrast and saturation curve), a thin dark outline, a rim light
           in the character's family colour; black-and-white or sketchy art gets a soft family tint
  safe     all-ages crop: head and shoulders only (the Demon Queen sheets tightest); every crop is
           listed in processed/<batch>_review.json for a manual check
  derive   card.png (576 x 768, the face fills ~70% of the card), portrait.png (512 x 512 head),
           silhouette.png (black fill + rim light in the rarity colour), expr_<n>.png (the other
           faces, untagged: no automatic expression classifier, marked for review)
The pick for card.png is the largest face over all of a character's sheets (the most detail).
"""
import glob
import hashlib
import json
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art", "characters")
INCOMING = os.path.join(ART, "incoming")
PROCESSED = os.path.join(ART, "processed")
MAP = os.path.join(ART, "map.json")
CHARS = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")
SCREENS = os.path.join(ROOT, "docs", "screens", "characters")

BATCH = "portrait-pack"

# Pack character (file prefix) -> roster id (MISSION 12.3: family mapping, spread over rarities).
PACK_MAP = {
    "GOTHIC SCHOOL GIRL": "mirelle_hexwhisper",  # Mystic, Common
    "CHAOTIC JESTER": "edric_velvetshield",  # Royal, Common
    "VAMPIRE BOY": "corvin_duskweaver",  # Shadow, Common
    "CYBERPUNK BOY": "kenji_thunderpeak",  # Lightning, Rare
    "CUTE CATGIRL": "lyra_wildpelt",  # Beast, Rare
    "DEMON QUEEN": "draxa_bloodthorn",  # Demon, Rare
    "SPACE PILOT GIRL": "nyx_voidglimmer",  # Cosmic, Epic
    "FANTASY ELF GIRL": "eira_mistsong",  # Spirit, Legendary
    "POST APOCALYPTIC GIRL": "asha_warbanner",  # Warrior, Legendary
    "ANGELIC IDOL": "aurelia_dawn",  # Divine, Mythical (God-tier)
}
TIGHT = {"DEMON QUEEN": 0.72}  # kept fraction of the cut-out's height (tighter = head and shoulders)
DEFAULT_CROP = 0.86

FAMILY_ACCENT = {
    "Flame": "#FFB347", "Ice": "#E8F6FF", "Lightning": "#FFE14D", "Shadow": "#9B7BFF", "Divine": "#FFD45C",
    "Beast": "#D9B48A", "Dragon": "#FF6A2B", "Warrior": "#D2462E", "Ninja": "#4FD1C5", "Royal": "#FFC54B",
    "Cosmic": "#FF7BE5", "Ancient": "#5FD3A0", "Mystic": "#B98CFF", "Spirit": "#FFFFFF", "Demon": "#FF3B3B",
}
RARITY_GLOW = {"Common": "#E8E6FF", "Rare": "#1EA8FF", "Epic": "#B45CFF", "Legendary": "#FFB01E", "Mythical": "#18E890"}


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def roster():
    import re
    s = open(CHARS, encoding="utf-8").read()
    rows = re.findall(r'id = "([a-z_]+)",\n\t\tdisplayName = "([^"]+)",\n\t\tfamily = "(\w+)",\n\t\trarity = "(\w+)"', s)
    return {r[0]: {"name": r[1], "family": r[2], "rarity": r[3]} for r in rows}


# ------------------------------------------------------------------ ingest


def ingest(folder, batch=BATCH):
    dst = os.path.join(INCOMING, batch)
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in sorted(os.listdir(folder)):
        if f.lower().endswith(".png") or f.lower().startswith("license"):
            shutil.copy2(os.path.join(folder, f), os.path.join(dst, f))
            n += 1
    licensed = any(f.lower().startswith("license") for f in os.listdir(dst))
    status = {"batch": batch, "files": n, "license": "present" if licensed else "TEMP_UNLICENSED"}
    json.dump(status, open(os.path.join(dst, "_status.json"), "w"), indent=1)
    print(status)
    return status


# ------------------------------------------------------------------ split / clean


def key_white(rgba):
    """Remove opaque near-white framing connected to the image edge (white card backgrounds)."""
    rgb = rgba[..., :3].astype(np.int32)
    white = (rgb.min(axis=2) > 225) & (rgba[..., 3] > 200)
    lab, _ = ndimage.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    if edge:
        mask = np.isin(lab, list(edge))
        rgba = rgba.copy()
        rgba[..., 3] = np.where(mask, 0, rgba[..., 3])
    return rgba


def split(path):
    """Faces in a sheet: list of (bbox, rgba crop). Heads on these sheets touch, so the alpha is
    eroded harder and harder until it breaks into separate seeds (the most faces of at least 2.5%
    of the sheet, at most 9), then every pixel goes to its nearest seed (a distance-based
    watershed). Tiny fragments are dropped."""
    im = np.asarray(Image.open(path).convert("RGBA")).copy()
    im = key_white(im)
    a = im[..., 3] > 40
    total = a.size
    small = a[::4, ::4]  # work at 1/4 resolution for the seeds
    best = None
    for it in (2, 5, 9, 14, 20, 28, 36):
        er = ndimage.binary_erosion(small, iterations=it)
        lab, n = ndimage.label(er)
        if n == 0:
            break
        sizes = ndimage.sum(er, lab, range(1, n + 1))
        big = [k + 1 for k, sz in enumerate(sizes) if sz * 16 >= total * 0.006]
        if 1 <= len(big) <= 9 and (best is None or len(big) > best[0]):
            seeds = np.where(np.isin(lab, big), lab, 0)
            best = (len(big), seeds)
    if best is None:
        return []
    seeds = best[1]
    _, idx = ndimage.distance_transform_edt(seeds == 0, return_indices=True)
    owner_small = seeds[idx[0], idx[1]]
    owner = np.kron(owner_small, np.ones((4, 4), dtype=owner_small.dtype))[: a.shape[0], : a.shape[1]]
    faces = []
    for k in np.unique(owner_small):
        if k == 0:
            continue
        m = (owner == k) & a
        if m.sum() < total * 0.025:
            continue
        ys, xs = np.where(m)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        crop = im[y0:y1, x0:x1].copy()
        crop[..., 3] = np.where(m[y0:y1, x0:x1], crop[..., 3], 0)
        faces.append(((int(x0), int(y0), int(x1), int(y1)), crop))
    return faces


def clean(rgba):
    a = rgba[..., 3].astype(np.float32)
    solid = a > 40
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(solid, iterations=2))
    lab, n = ndimage.label(solid)
    if n > 1:  # keep the main body only
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        solid = lab == (int(np.argmax(sizes)) + 1)
    solid = ndimage.binary_erosion(solid, iterations=1)
    alpha = ndimage.gaussian_filter(solid.astype(np.float32), 0.8) * 255
    out = rgba.copy()
    out[..., 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    ys, xs = np.where(out[..., 3] > 8)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


# ------------------------------------------------------------------ style / safe / derive


def safe_crop(rgba, ratio):
    """Head and shoulders: keep the top `ratio` of the cut-out's height (all-ages crop)."""
    h, w = rgba.shape[:2]
    keep = max(8, int(h * ratio))
    out = rgba[:keep].copy()
    # soften the cut edge
    fade = np.ones(keep, dtype=np.float32)
    n = max(4, keep // 14)
    fade[-n:] = np.linspace(1, 0, n)
    out[..., 3] = (out[..., 3].astype(np.float32) * fade[:, None]).astype(np.uint8)
    return out


def style(rgba, family):
    img = rgba.astype(np.float32)
    rgb = img[..., :3]
    # colour grade: gentle S-curve and +12% saturation
    x = rgb / 255
    x = x + 0.12 * (x - 0.5) * (1 - np.abs(2 * x - 1))
    grey = x.mean(axis=2, keepdims=True)
    sat = np.abs(rgb - rgb.mean(axis=2, keepdims=True)).mean() / 255
    x = grey + (x - grey) * 1.12
    if sat < 0.06:  # black-and-white / sketchy: a soft tint in the family colour
        tint = hexc(FAMILY_ACCENT[family]) / 255
        x = x * (0.78 + 0.22 * tint)
    rgb = np.clip(x, 0, 1) * 255
    a = img[..., 3] / 255
    # rim light in the family colour along the upper-left edge
    inner = ndimage.binary_erosion(a > 0.5, iterations=3)
    edge = (a > 0.5) & ~inner
    shifted = np.roll(np.roll(a > 0.5, 3, axis=0), 3, axis=1)
    rim = edge & ~shifted
    rimf = ndimage.gaussian_filter(rim.astype(np.float32), 1.2)
    rgb = rgb * (1 - rimf[..., None] * 0.6) + hexc(FAMILY_ACCENT[family]) * rimf[..., None] * 0.6
    out = np.zeros((rgba.shape[0] + 8, rgba.shape[1] + 8, 4), dtype=np.float32)
    out[4:-4, 4:-4, :3] = rgb
    out[4:-4, 4:-4, 3] = a * 255
    # thin dark outline behind
    ring = ndimage.binary_dilation(out[..., 3] > 128, iterations=2) & ~(out[..., 3] > 128)
    ringf = ndimage.gaussian_filter(ring.astype(np.float32), 0.6)
    over = ringf * (1 - out[..., 3] / 255)
    out[..., :3] = out[..., :3] * (1 - over[..., None]) + np.array([20, 12, 36]) * over[..., None]
    out[..., 3] = np.clip(out[..., 3] + over * 230, 0, 255)
    return np.clip(out, 0, 255).astype(np.uint8)


def fit(rgba, size, fill=0.92, anchor_bottom=True):
    """Upscale (Lanczos + unsharp, at most 4x) into a transparent canvas of `size`."""
    im = Image.fromarray(rgba, "RGBA")
    w, h = size
    s = min(w * fill / im.width, h * fill / im.height, 4.0)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    x = (w - im.width) // 2
    y = h - im.height if anchor_bottom else (h - im.height) // 2
    canvas.alpha_composite(im, (x, max(0, y)))
    return canvas


def silhouette(card, rarity):
    a = np.asarray(card)[..., 3].astype(np.float32) / 255
    rim = ndimage.gaussian_filter(np.clip(ndimage.binary_dilation(a > 0.5, iterations=5).astype(np.float32) - (a > 0.5), 0, 1), 3) * 2.2
    out = np.zeros(a.shape + (4,), dtype=np.float32)
    col = hexc(RARITY_GLOW[rarity])
    out[..., :3] = col
    out[..., 3] = np.clip(rim, 0, 1) * 255
    body = a > 0.5
    out[body, :3] = 8
    out[..., 3] = np.where(body, 255, out[..., 3])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def process(batch=BATCH):
    src = os.path.join(INCOMING, batch)
    chars = roster()
    review = []
    mapping = json.load(open(MAP)) if os.path.exists(MAP) else {}
    for prefix, cid in PACK_MAP.items():
        info = chars[cid]
        sheets = sorted(f for f in glob.glob(os.path.join(src, "*.png")) if prefix in os.path.basename(f))
        faces = []
        for sheet in sheets:
            for bbox, crop in split(sheet):
                faces.append((os.path.basename(sheet), bbox, crop))
        if not faces:
            print("no faces for", prefix)
            continue
        # Single heads first: roughly square crops (merged neighbours are wide) under 40% of a
        # sheet, largest first (the most detail).
        def single(f):
            h, w = f[2].shape[:2]
            return 0.55 <= w / h <= 1.12 and w * h < 1024 * 1024 * 0.3
        faces.sort(key=lambda f: (not single(f), -(f[2].shape[0] * f[2].shape[1])))
        out = os.path.join(PROCESSED, cid)
        os.makedirs(out, exist_ok=True)
        for f in glob.glob(os.path.join(out, "*.png")):
            os.remove(f)
        ratio = TIGHT.get(prefix, DEFAULT_CROP)
        for i, (sheet, bbox, crop) in enumerate(faces[:7]):
            c = clean(crop)
            c = safe_crop(c, ratio)
            st = style(c, info["family"])
            if i == 0:
                card = fit(st, (576, 768), fill=0.98)
                card.save(os.path.join(out, "card.png"), optimize=True)
                portrait = fit(st[: int(st.shape[1] * 0.85)], (512, 512), fill=0.95, anchor_bottom=False)
                portrait.save(os.path.join(out, "portrait.png"), optimize=True)
                silhouette(card, info["rarity"]).save(os.path.join(out, "silhouette.png"), optimize=True)
                mapping[f"incoming/{batch}/{sheet}#{bbox}"] = cid
            else:
                fit(st, (384, 384), fill=0.95).save(os.path.join(out, f"expr_{i}.png"), optimize=True)
            review.append({"character": cid, "sheet": sheet, "bbox": list(bbox), "use": "card" if i == 0 else f"expr_{i}",
                           "crop": f"head and shoulders, height {ratio} x width", "status": "needs manual review"})
        print("processed", prefix, "->", cid, len(faces), "faces")
    json.dump(mapping, open(MAP, "w"), indent=1, sort_keys=True)
    json.dump(review, open(os.path.join(PROCESSED, f"{batch}_review.json"), "w"), indent=1)


# ------------------------------------------------------------------ check / status


def check(batch=BATCH):
    chars = roster()
    seen = {}
    rows = []
    problems = []
    for cid in PACK_MAP.values():
        d = os.path.join(PROCESSED, cid)
        for name, size in (("card.png", (576, 768)), ("portrait.png", (512, 512)), ("silhouette.png", (576, 768))):
            p = os.path.join(d, name)
            if not os.path.exists(p):
                problems.append(f"{cid}: missing {name}")
                continue
            im = Image.open(p)
            if im.size != size or im.mode != "RGBA":
                problems.append(f"{cid}/{name}: {im.size} {im.mode}")
            if np.asarray(im)[..., 3].min() != 0:
                problems.append(f"{cid}/{name}: no transparency")
            h = hashlib.sha1(im.tobytes()).hexdigest()
            if h in seen and name == "card.png":
                problems.append(f"{cid}: duplicate art of {seen[h]}")
            seen[h] = cid
        rows.append(cid)
    # contact sheet: card, portrait, silhouette per character, on the card background colour
    os.makedirs(SCREENS, exist_ok=True)
    cell = 150
    sheet = Image.new("RGBA", (cell * 3 + 160, (cell + 10) * len(rows)), (12, 10, 32, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sheet)
    for r, cid in enumerate(rows):
        y = r * (cell + 10)
        dr.text((6, y + cell // 2 - 12), f"{chars[cid]['name']}\n{chars[cid]['family']} · {chars[cid]['rarity']}", fill=(220, 210, 255, 255))
        for k, name in enumerate(("card.png", "portrait.png", "silhouette.png")):
            p = os.path.join(PROCESSED, cid, name)
            if os.path.exists(p):
                im = Image.open(p)
                im.thumbnail((cell, cell))
                sheet.alpha_composite(im, (160 + k * cell + (cell - im.width) // 2, y + (cell - im.height) // 2))
    out = os.path.join(SCREENS, f"contact_{batch}.png")
    sheet.save(out)
    print("contact sheet:", out)
    print("problems:", problems or "none")
    return problems


def status():
    chars = roster()
    s = open(CHARS, encoding="utf-8").read()
    final = s.count("cardArt = \"rbxassetid://")
    processed = [c for c in chars if os.path.exists(os.path.join(PROCESSED, c, "card.png"))]
    st = json.load(open(os.path.join(INCOMING, BATCH, "_status.json"))) if os.path.exists(os.path.join(INCOMING, BATCH, "_status.json")) else {}
    print(f"{len(chars)} characters: {final} with uploaded card art, {len(processed)} processed (not uploaded: "
          f"{len(processed) - final}), {len(chars) - len(processed)} with no art (TEMP role silhouette). "
          f"Portrait pack license: {st.get('license', 'unknown')}.")


def urls():
    for cid in PACK_MAP.values():
        print(f"http://127.0.0.1:8765/art/characters/processed/{cid}/card.png")


if __name__ == "__main__":
    a = sys.argv[1:]
    cmd = a[0] if a else "status"
    if cmd == "ingest":
        ingest(a[1], a[2] if len(a) > 2 else BATCH)
    elif cmd == "process":
        process(a[1] if len(a) > 1 else BATCH)
    elif cmd == "check":
        check(a[1] if len(a) > 1 else BATCH)
    elif cmd == "urls":
        urls()
    elif cmd == "status":
        status()
    else:
        print(__doc__)
