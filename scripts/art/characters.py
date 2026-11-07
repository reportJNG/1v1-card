"""Picks up the owner's character images (POLISH_MISSION F) on every loop pass.

  python scripts/art/characters.py status            # which characters have card.png / front.png
  python scripts/art/characters.py check             # validate them (PNG, <= 1024 px, card.png has transparency)
  python scripts/art/characters.py urls              # upload URLs for the new/changed card.png files
  python scripts/art/characters.py apply <ids.json>  # write uploaded ids into Config/Characters assets.cardArt

Flow: drop art/characters/<id>/card.png (transparent, 768x1024) -> `check` -> serve the repo with
`python -m http.server 8765` and upload the `urls` through the Studio MCP upload_image tool ->
save the {url: rbxassetid} answer as art/characters/ids.json -> `apply`. The card and the 3D
standee pick the art up from CharacterDef.assets.cardArt; the TEMP silhouette disappears for that
character. Only the project's original characters are accepted (ids from Config/Characters).

front.png (the model reference) feeds the Blender pipeline (image-to-3D, cleanup, R15 rig, the
animations, renders), which needs Blender's generators switched on (docs/WAITING_ON_YOU.md).
"""
import json
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "art", "characters")
CHARS = os.path.join(ROOT, "src", "shared", "Config", "Characters.luau")
IDS = os.path.join(ART, "ids.json")


def character_ids():
    src = open(CHARS, encoding="utf-8").read()
    return re.findall(r'\n\t\tid = "([a-z0-9_]+)",\n\t\tdisplayName', src)


def png_info(path):
    """(width, height, has_alpha_channel, any_transparent_pixel) for an 8-bit PNG."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, w, h, bit, ctype = 8, b"", 0, 0, 0, 0
    trns = False
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        if tag == b"IHDR":
            w, h, bit, ctype = struct.unpack(">IIBB", body[:10])
        elif tag == b"IDAT":
            idat += body
        elif tag == b"tRNS":
            trns = True
        pos += 12 + n
    alpha = ctype in (4, 6) or trns
    transparent = False
    if ctype == 6 and bit == 8:
        raw = zlib.decompress(idat)
        stride = w * 4 + 1
        # sample the four corners: a cut-out has a clear background there
        for y in (0, h - 1):
            row = raw[y * stride + 1:(y + 1) * stride]
            for x in (0, w - 1):
                if row[x * 4 + 3] < 16:
                    transparent = True
    elif trns:
        transparent = True
    return w, h, alpha, transparent


def found():
    out = []
    for cid in character_ids():
        d = os.path.join(ART, cid)
        out.append((cid, os.path.exists(os.path.join(d, "card.png")), os.path.exists(os.path.join(d, "front.png"))))
    return out


def status():
    rows = found()
    cards = [c for c, card, _ in rows if card]
    fronts = [c for c, _, front in rows if front]
    print(f"{len(rows)} characters | card.png: {len(cards)} | front.png: {len(fronts)}")
    for c in cards:
        print("  card ", c)
    for c in fronts:
        print("  front", c)
    unknown = [d for d in os.listdir(ART) if os.path.isdir(os.path.join(ART, d)) and d not in {r[0] for r in rows}]
    for d in unknown:
        print("  IGNORED (not an original character id):", d)


def check():
    bad = 0
    for cid, card, front in found():
        for name, present in (("card.png", card), ("front.png", front)):
            if not present:
                continue
            path = os.path.join(ART, cid, name)
            try:
                w, h, alpha, transparent = png_info(path)
            except Exception as e:  # noqa: BLE001
                print(f"BAD  {cid}/{name}: {e}")
                bad += 1
                continue
            problems = []
            if max(w, h) > 1024:
                problems.append(f"{w}x{h} is over 1024 px")
            if name == "card.png" and not transparent:
                problems.append("background is not transparent (corners must be clear)")
            print(("BAD " if problems else "OK  ") + f"{cid}/{name} {w}x{h}" + (": " + "; ".join(problems) if problems else ""))
            bad += bool(problems)
    print("check:", "clean" if bad == 0 else f"{bad} problem(s)")
    return bad


def urls():
    done = json.load(open(IDS)) if os.path.exists(IDS) else {}
    out = []
    for cid, card, _ in found():
        if card:
            url = f"http://127.0.0.1:8765/art/characters/{cid}/card.png"
            if url not in done:
                out.append(url)
    print(json.dumps(out))


def apply(path):
    ids = json.load(open(path))
    src = open(CHARS, encoding="utf-8").read()
    n = 0
    for url, asset in ids.items():
        m = re.search(r"/art/characters/([a-z0-9_]+)/card\.png$", url)
        if not m or not str(asset).startswith("rbxassetid://"):
            continue
        cid = m.group(1)
        a = src.index(f'\tid = "{cid}",')
        b = src.index("\t\tassets = {", a)
        e = src.index("}", b)
        block = src[b:e + 1]
        new = re.sub(r"\t*cardArt = \"[^\"]*\",\n", "", block)
        new = new.replace("assets = {", f'assets = {{\n\t\t\tcardArt = "{asset}",', 1)
        new = new.replace("assets = {\n\t\t\tcardArt", "assets = {\n\t\t\tcardArt")
        src = src[:b] + new + src[e + 1:]
        n += 1
    open(CHARS, "w", encoding="utf-8").write(src)
    merged = json.load(open(IDS)) if os.path.exists(IDS) else {}
    merged.update(ids)
    json.dump(merged, open(IDS, "w"), indent=1, sort_keys=True)
    print(f"applied {n} card art id(s); run stylua")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        status()
    elif cmd == "check":
        sys.exit(1 if check() else 0)
    elif cmd == "urls":
        urls()
    elif cmd == "apply":
        apply(sys.argv[2])
    else:
        raise SystemExit(__doc__)
