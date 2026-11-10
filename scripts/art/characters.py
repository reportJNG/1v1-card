"""Character art pipeline (MISSION.md section 12, PLAN.md section 5), under CLAUDE.md "Asset safety".

  python scripts/art/characters.py ingest [folder] [batch]    copy new images, unchanged, from
                                                            Downloads\\New folder to incoming/<batch>/
  python scripts/art/characters.py sheet <batch>              contact sheet docs/review/<batch>.png and
                                                            the safety/IP checklist docs/review/<batch>.md
  python scripts/art/characters.py approve <batch> "<words>"  record the owner's written approval; run it
                                                            only after the owner approved in chat
  python scripts/art/characters.py map <batch> <file> <id>    map one image to a roster character
  python scripts/art/characters.py process <batch>            approved batches only: card.png, portrait.png,
                                                            silhouette.png per mapped character
  python scripts/art/characters.py check [batch]              sizes, transparency, duplicates, and the
                                                            gallery docs/screens/characters/contact_<batch>.png
  python scripts/art/characters.py urls <batch>               upload URLs, in groups of at most 5 (approved only)
  python scripts/art/characters.py apply <ids.json>           write uploaded ids into Config/Characters assets.cardArt
  python scripts/art/characters.py status                     what is ingested, approved, processed and uploaded
  python scripts/art/characters.py selftest                   the whole flow on a synthetic image in a temp folder

The rules this enforces (CLAUDE.md "Asset safety", PLAN.md section 3):
  - only the owner's folder; the rejected files (fighter_01..05) are never copied
  - originals are copied unchanged; processing works on copies
  - nothing is processed or offered for upload before the owner's written approval is recorded
  - no face sheets are split and no expressions are made: one card image per character
  - upload URLs come in groups of at most 5; stop everything at the first "moderated", "rejected"
    or 403 and tell the owner
Uploading itself goes through the Roblox Studio MCP upload_image tool (serve the repo with
`python -m http.server 8765`), then `apply` the {url: rbxassetid} answer.
"""
import datetime
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile

ROOT = os.environ.get("CHARACTER_ART_ROOT") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = r"C:\Users\Administrator\Downloads\New folder"
REJECTED = ("fighter_01", "fighter_02", "fighter_03", "fighter_04", "fighter_05")  # PLAN.md section 4
IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")
UPLOAD_GROUP = 5

ART = os.path.join(ROOT, "art", "characters")
INCOMING = os.path.join(ART, "incoming")
PROCESSED = os.path.join(ART, "processed")
MAP = os.path.join(ART, "map.json")
IDS = os.path.join(ART, "ids.json")
REVIEW = os.path.join(ROOT, "docs", "review")
GALLERY = os.path.join(ROOT, "docs", "screens", "characters")
CHARS = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")

CARD_SIZE = (576, 768)  # 3:4, 768 px tall (the card art window)
PORTRAIT_SIZE = (512, 512)
FAMILY_ACCENT = {
    "Flame": "#FFB347", "Ice": "#E8F6FF", "Lightning": "#FFE14D", "Shadow": "#9B7BFF", "Divine": "#FFD45C",
    "Beast": "#D9B48A", "Dragon": "#FF6A2B", "Warrior": "#D2462E", "Ninja": "#4FD1C5", "Royal": "#FFC54B",
    "Cosmic": "#FF7BE5", "Ancient": "#5FD3A0", "Mystic": "#B98CFF", "Spirit": "#FFFFFF", "Demon": "#FF3B3B",
}
RARITY_GLOW = {"Common": "#E8E6FF", "Rare": "#1EA8FF", "Epic": "#B45CFF", "Legendary": "#FFB01E", "Mythical": "#18E890"}


# ------------------------------------------------------------------ helpers


def roster():
    s = open(CHARS, encoding="utf-8").read()
    # a trailing comment after displayName is allowed (the 2026-11-10 renames carry one)
    rows = re.findall(
        r'id = "([a-z0-9_]+)",\n\t\tdisplayName = "([^"]+)",[^\n]*\n\t\tfamily = "(\w+)",\n\t\trarity = "(\w+)"', s
    )
    return {r[0]: {"name": r[1], "family": r[2], "rarity": r[3]} for r in rows}


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def rejected(name):
    return os.path.splitext(name)[0].lower().startswith(REJECTED)


def batch_files(batch):
    d = os.path.join(INCOMING, batch)
    if not os.path.isdir(d):
        raise SystemExit(f"no batch {batch} in {INCOMING}")
    return [f for f in sorted(os.listdir(d)) if f.lower().endswith(IMAGE_EXT) and not rejected(f)]


def review_path(batch):
    return os.path.join(REVIEW, f"{batch}.md")


def approved(batch):
    p = review_path(batch)
    return os.path.exists(p) and re.search(r"^Owner approval: APPROVED", open(p, encoding="utf-8").read(), re.M) is not None


def require_approved(batch):
    if not approved(batch):
        raise SystemExit(f"{batch} is not approved: make the contact sheet (`sheet`), check it, and wait for the "
                         f"owner's written approval in chat before `approve` (CLAUDE.md, Asset safety rule 4)")


def load_map():
    return json.load(open(MAP, encoding="utf-8")) if os.path.exists(MAP) else {}


def hexc(h):
    import numpy as np
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


# ------------------------------------------------------------------ ingest / sheet / approve / map


def ingest(folder=SOURCE, batch=None):
    batch = batch or datetime.date.today().isoformat()
    dst = os.path.join(INCOMING, batch)
    os.makedirs(dst, exist_ok=True)
    copied, skipped = [], []
    for f in sorted(os.listdir(folder)):
        if not f.lower().endswith(IMAGE_EXT) and not f.lower().startswith("license"):
            continue
        if rejected(f):
            skipped.append(f)
            continue
        shutil.copy2(os.path.join(folder, f), os.path.join(dst, f))
        copied.append(f)
    print(f"batch {batch}: copied {len(copied)} unchanged, refused {len(skipped)} rejected file(s) {skipped}")
    return batch, copied, skipped


def sheet(batch):
    from PIL import Image, ImageDraw
    files = batch_files(batch)
    if not files:
        raise SystemExit(f"{batch} has no images")
    os.makedirs(REVIEW, exist_ok=True)
    T, cols = 320, min(len(files), 5)
    rows = (len(files) + cols - 1) // cols
    img = Image.new("RGB", (cols * T, rows * (T + 24)), (24, 20, 44))
    dr = ImageDraw.Draw(img)
    for i, f in enumerate(files):
        im = Image.open(os.path.join(INCOMING, batch, f)).convert("RGBA")
        im.thumbnail((T - 8, T - 8))
        x, y = (i % cols) * T, (i // cols) * (T + 24)
        img.paste(im, (x + (T - im.width) // 2, y + 4), im)
        dr.text((x + 6, y + T + 4), f[:44], fill=(255, 255, 255))
    img.save(os.path.join(REVIEW, f"{batch}.png"))
    lines = [f"# Review: {batch}", "",
             f"Contact sheet: `docs/review/{batch}.png`. Check every image against CLAUDE.md \"Asset safety\":",
             "1. Roblox-style character in an anime style, fully clothed; not an anime girl.",
             "2. Nothing suggestive: no blushing, tears, open-mouth or pained faces, no cleavage, midriff,",
             "   swimsuit, lingerie or suggestive pose.",
             "3. Not an existing anime, game or franchise character or signature look.", "",
             "| File | Size | sha256 | Rule 1 | Rule 2 | Rule 3 | Notes |", "|---|---|---|---|---|---|---|"]
    for f in files:
        p = os.path.join(INCOMING, batch, f)
        w, h = Image.open(p).size
        lines.append(f"| {f} | {w}x{h} | {sha(p)[:12]} | TODO | TODO | TODO | |")
    lines += ["", "Owner approval: PENDING (nothing is used or uploaded until the owner approves in chat)", ""]
    open(review_path(batch), "w", encoding="utf-8").write("\n".join(lines))
    print(f"wrote docs/review/{batch}.png and docs/review/{batch}.md; fill in the checks, then stop for approval")


def approve(batch, words):
    p = review_path(batch)
    if not os.path.exists(p):
        raise SystemExit(f"no review for {batch}: run `sheet` first")
    s = open(p, encoding="utf-8").read()
    if "| TODO |" in s or "TODO |" in s:
        raise SystemExit(f"{batch}: fill in every rule check in {p} first")
    if re.search(r"^Owner approval: ", s, re.M) is None:
        raise SystemExit(f"{p} has no approval line: run `sheet` again")
    if not words.strip():
        raise SystemExit("quote the owner's written approval")
    line = f"Owner approval: APPROVED {datetime.date.today().isoformat()}: \"{words.strip()}\""
    s = re.sub(r"^Owner approval: .*$", lambda _m: line, s, count=1, flags=re.M)  # the quote may hold "\"
    open(p, "w", encoding="utf-8").write(s)
    print(line)


def map_one(batch, file, cid):
    if file not in batch_files(batch):
        raise SystemExit(f"{file} is not an image of {batch}")
    if cid not in roster():
        raise SystemExit(f"{cid} is not a roster character id")
    m = load_map()
    m[f"{batch}/{file}"] = cid
    os.makedirs(ART, exist_ok=True)
    json.dump(m, open(MAP, "w", encoding="utf-8"), indent=1, sort_keys=True)
    print(f"{batch}/{file} -> {cid}")


# ------------------------------------------------------------------ process


def cut_background(rgba):
    """A transparent cut-out. An opaque image with a plain background loses the background colour
    connected to its border; anything else is kept as it is."""
    import numpy as np
    from scipy import ndimage
    a = rgba[..., 3]
    corners = np.array([rgba[0, 0], rgba[0, -1], rgba[-1, 0], rgba[-1, -1]]).astype(np.float32)
    if corners[:, 3].min() < 200:
        return rgba  # already transparent
    bg = corners[:, :3].mean(axis=0)
    if np.abs(corners[:, :3] - bg).max() > 24:
        return rgba  # not a plain background: keep it (the card window crops it)
    near = np.abs(rgba[..., :3].astype(np.float32) - bg).max(axis=2) < 30
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = np.isin(lab, list(border))
    out = rgba.copy()
    out[..., 3] = np.where(mask, 0, a)
    return out


def clean(rgba):
    import numpy as np
    from scipy import ndimage
    a = rgba[..., 3].astype(np.float32)
    if a.min() > 200:
        return rgba  # opaque art: nothing to clean
    solid = ndimage.binary_fill_holes(ndimage.binary_closing(a > 40, iterations=2))
    solid = ndimage.binary_erosion(solid, iterations=1)
    alpha = ndimage.gaussian_filter(solid.astype(np.float32), 0.8) * 255
    out = rgba.copy()
    out[..., 3] = np.clip(np.minimum(alpha, a + 60), 0, 255).astype(np.uint8)
    ys, xs = np.where(out[..., 3] > 8)
    return out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def style(rgba, family):
    """One grade for every batch: a gentle S-curve, +8% saturation, and a rim light in the family colour."""
    import numpy as np
    from scipy import ndimage
    img = rgba.astype(np.float32)
    x = img[..., :3] / 255
    x = x + 0.10 * (x - 0.5) * (1 - np.abs(2 * x - 1))
    grey = x.mean(axis=2, keepdims=True)
    x = grey + (x - grey) * 1.08
    rgb = np.clip(x, 0, 1) * 255
    a = img[..., 3] / 255
    if a.min() < 0.5:
        edge = (a > 0.5) & ~ndimage.binary_erosion(a > 0.5, iterations=3)
        rim = edge & ~np.roll(np.roll(a > 0.5, 3, axis=0), 3, axis=1)
        rimf = ndimage.gaussian_filter(rim.astype(np.float32), 1.2)[..., None] * 0.55
        rgb = rgb * (1 - rimf) + hexc(FAMILY_ACCENT[family]) * rimf
    out = img.copy()
    out[..., :3] = rgb
    return np.clip(out, 0, 255).astype(np.uint8)


def fit(rgba, size, fill=0.94, anchor_bottom=True):
    """Lanczos into a transparent canvas of `size`, never more than 4x."""
    from PIL import Image, ImageFilter
    im = Image.fromarray(rgba, "RGBA")
    w, h = size
    s = min(w * fill / im.width, h * fill / im.height, 4.0)
    im = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=50, threshold=2))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(im, ((w - im.width) // 2, max(0, h - im.height if anchor_bottom else (h - im.height) // 2)))
    return canvas


def silhouette(card, rarity):
    import numpy as np
    from PIL import Image
    from scipy import ndimage
    a = np.asarray(card)[..., 3].astype(np.float32) / 255
    body = a > 0.5
    rim = ndimage.gaussian_filter(np.clip(ndimage.binary_dilation(body, iterations=5).astype(np.float32) - body, 0, 1), 3) * 2.2
    out = np.zeros(a.shape + (4,), dtype=np.float32)
    out[..., :3] = hexc(RARITY_GLOW[rarity])
    out[..., 3] = np.clip(rim, 0, 1) * 255
    out[body, :3] = 8
    out[..., 3] = np.where(body, 255, out[..., 3])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def process(batch):
    import numpy as np
    from PIL import Image
    require_approved(batch)
    chars = roster()
    done = []
    for key, cid in load_map().items():
        b, f = key.split("/", 1)
        if b != batch:
            continue
        info = chars[cid]
        rgba = np.asarray(Image.open(os.path.join(INCOMING, batch, f)).convert("RGBA"))
        cut = style(clean(cut_background(rgba)), info["family"])
        out = os.path.join(PROCESSED, cid)
        os.makedirs(out, exist_ok=True)
        card = fit(cut, CARD_SIZE)
        card.save(os.path.join(out, "card.png"), optimize=True)
        head = cut[: min(cut.shape[0], cut.shape[1])]  # the top square: head and shoulders
        fit(head, PORTRAIT_SIZE, anchor_bottom=False).save(os.path.join(out, "portrait.png"), optimize=True)
        silhouette(card, info["rarity"]).save(os.path.join(out, "silhouette.png"), optimize=True)
        done.append(cid)
    if not done:
        raise SystemExit(f"{batch}: no image is mapped to a character (`map`)")
    print(f"processed {len(done)}: {done}")
    return done


# ------------------------------------------------------------------ check / urls / apply / status


def batch_characters(batch):
    return sorted({cid for key, cid in load_map().items() if batch is None or key.split("/", 1)[0] == batch})


def check(batch=None):
    from PIL import Image, ImageDraw
    bad, seen, shown = 0, {}, []
    for cid in batch_characters(batch):
        d = os.path.join(PROCESSED, cid)
        for name, size in (("card.png", CARD_SIZE), ("portrait.png", PORTRAIT_SIZE), ("silhouette.png", CARD_SIZE)):
            p = os.path.join(d, name)
            if not os.path.exists(p):
                print(f"BAD  {cid}/{name}: missing"); bad += 1; continue
            im = Image.open(p)
            problems = []
            if im.size != size:
                problems.append(f"{im.size} is not {size}")
            if im.mode != "RGBA" or im.getchannel("A").getextrema()[0] > 16:
                problems.append("no transparency")
            h = sha(p)
            if h in seen:
                problems.append(f"duplicate of {seen[h]}")
            seen[h] = f"{cid}/{name}"
            print(("BAD  " if problems else "OK   ") + f"{cid}/{name}" + (": " + "; ".join(problems) if problems else ""))
            bad += bool(problems)
        shown.append(cid)
    if shown and batch:
        os.makedirs(GALLERY, exist_ok=True)
        T = 192
        img = Image.new("RGB", (T * 3, (T * 4 // 3 + 20) * len(shown)), (24, 20, 44))
        dr = ImageDraw.Draw(img)
        for r, cid in enumerate(shown):
            for c, name in enumerate(("card.png", "portrait.png", "silhouette.png")):
                p = os.path.join(PROCESSED, cid, name)
                if os.path.exists(p):
                    im = Image.open(p).convert("RGBA"); im.thumbnail((T - 8, T * 4 // 3 - 8))
                    img.paste(im, (c * T + 4, r * (T * 4 // 3 + 20) + 4), im)
            dr.text((4, r * (T * 4 // 3 + 20) + T * 4 // 3), cid, fill=(255, 255, 255))
        img.save(os.path.join(GALLERY, f"contact_{batch}.png"))
    print("check:", "clean" if bad == 0 else f"{bad} problem(s)")
    return bad


def urls(batch):
    require_approved(batch)
    done = json.load(open(IDS)) if os.path.exists(IDS) else {}
    todo = [f"http://127.0.0.1:8765/art/characters/processed/{cid}/card.png" for cid in batch_characters(batch)]
    todo = [u for u in todo if u not in done]
    groups = [todo[i:i + UPLOAD_GROUP] for i in range(0, len(todo), UPLOAD_GROUP)]
    for i, g in enumerate(groups, 1):
        print(f"group {i} of {len(groups)}: {json.dumps(g)}")
    print("Upload one group at a time. Stop everything at the first moderated / rejected / 403 answer.")
    return groups


def apply(path):
    ids = json.load(open(path))
    src = open(CHARS, encoding="utf-8").read()
    n = 0
    for url, asset in ids.items():
        m = re.search(r"/art/characters/processed/([a-z0-9_]+)/card\.png$", url)
        if not m or not str(asset).startswith("rbxassetid://"):
            continue
        cid = m.group(1)
        a = src.index(f'\tid = "{cid}",')
        b = src.index("\t\tassets = {", a)
        e = src.index("}", b)
        block = src[b:e + 1]
        new = re.sub(r"\t*cardArt = \"[^\"]*\",\n", "", block)
        new = new.replace("assets = {", f'assets = {{\n\t\t\tcardArt = "{asset}",', 1)
        src = src[:b] + new + src[e + 1:]
        n += 1
    open(CHARS, "w", encoding="utf-8").write(src)
    merged = json.load(open(IDS)) if os.path.exists(IDS) else {}
    merged.update(ids)
    json.dump(merged, open(IDS, "w"), indent=1, sort_keys=True)
    print(f"applied {n} card art id(s); run stylua")


def status():
    batches = sorted(os.listdir(INCOMING)) if os.path.isdir(INCOMING) else []
    for b in batches:
        print(f"batch {b}: {len(batch_files(b))} image(s), {'APPROVED' if approved(b) else 'not approved'}, "
              f"{len(batch_characters(b))} mapped")
    s = open(CHARS, encoding="utf-8").read()
    print(f"characters with uploaded card art: {s.count('cardArt = \"rbxassetid://')}")
    if not batches:
        print("no batches yet: waiting for the owner's images in", SOURCE)


# ------------------------------------------------------------------ selftest


def selftest():
    """Runs ingest -> sheet -> (refused before approval) -> approve -> map -> process -> check -> urls on a
    synthetic figure drawn here, in a temp folder. Nothing is uploaded and nothing in the repo changes."""
    import numpy as np
    from PIL import Image, ImageDraw
    global ROOT
    tmp = tempfile.mkdtemp(prefix="charart-")
    src = os.path.join(tmp, "src")
    os.makedirs(src)
    for name in ("fighter_01_rejected.png", "test_hero.png"):
        im = Image.new("RGBA", (300, 420), (40, 90, 160, 255))
        d = ImageDraw.Draw(im)
        d.ellipse((110, 40, 190, 120), fill=(240, 200, 170, 255))  # head
        d.rectangle((95, 120, 205, 300), fill=(200, 60, 50, 255))  # body
        d.rectangle((105, 300, 145, 400), fill=(30, 30, 40, 255))
        d.rectangle((155, 300, 195, 400), fill=(30, 30, 40, 255))
        im.save(os.path.join(src, name))
    os.makedirs(os.path.join(tmp, "src", "shared", "Config"), exist_ok=True)
    shutil.copy(CHARS, os.path.join(tmp, "src", "shared", "Config", "Characters.luau"))
    os.environ["CHARACTER_ART_ROOT"] = tmp
    try:
        out = __import__("subprocess").run([sys.executable, __file__, "selftest-run", src], capture_output=True, text=True,
                                           env=dict(os.environ))
        print(out.stdout + out.stderr)
        if out.returncode != 0:
            raise SystemExit("selftest FAILED")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def selftest_run(src):
    batch, copied, skipped = ingest(src, "selftest")
    assert copied == ["test_hero.png"] and skipped == ["fighter_01_rejected.png"], (copied, skipped)
    sheet(batch)
    assert os.path.exists(os.path.join(REVIEW, "selftest.png"))
    for fn in (lambda: process(batch), lambda: urls(batch), lambda: approve(batch, "ok")):
        try:
            fn()
            raise AssertionError("ran before the review was filled in and approved")
        except SystemExit:
            pass
    p = review_path(batch)
    text = open(p, encoding="utf-8").read()
    open(p, "w", encoding="utf-8").write(text.replace("TODO", "pass"))
    approve(batch, "selftest approval")
    map_one(batch, "test_hero.png", "ren_emberfang")
    process(batch)
    from PIL import Image
    card = Image.open(os.path.join(PROCESSED, "ren_emberfang", "card.png"))
    assert card.size == CARD_SIZE and card.getchannel("A").getextrema()[0] == 0
    assert check(batch) == 0
    assert os.path.exists(os.path.join(GALLERY, "contact_selftest.png"))
    groups = urls(batch)
    assert len(groups) == 1 and len(groups[0]) == 1
    assert not os.path.exists(os.path.join(PROCESSED, "ren_emberfang", "expr_1.png"))
    print("SELFTEST PASSED: rejected file refused, nothing ran before approval, card/portrait/silhouette made, "
          "no expressions, upload groups of at most 5")


if __name__ == "__main__":
    a = sys.argv[1:]
    cmd = a[0] if a else "status"
    if cmd == "ingest":
        ingest(a[1] if len(a) > 1 else SOURCE, a[2] if len(a) > 2 else None)
    elif cmd == "sheet":
        sheet(a[1])
    elif cmd == "approve":
        approve(a[1], a[2] if len(a) > 2 else "")
    elif cmd == "map":
        map_one(a[1], a[2], a[3])
    elif cmd == "process":
        process(a[1])
    elif cmd == "check":
        sys.exit(1 if check(a[1] if len(a) > 1 else None) else 0)
    elif cmd == "urls":
        urls(a[1])
    elif cmd == "apply":
        apply(a[1])
    elif cmd == "status":
        status()
    elif cmd == "selftest":
        selftest()
    elif cmd == "selftest-run":
        selftest_run(a[1])
    else:
        raise SystemExit(__doc__)
