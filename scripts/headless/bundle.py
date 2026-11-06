"""Bundle the dev project (Shared, Server, Tests, TestEZ) with shim.luau into one Luau file that
the stock `luau` CLI can run: python3 scripts/headless/bundle.py && luau build/headless.luau"""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MAP = [("ReplicatedStorage/Shared", "src/shared"),
       ("ReplicatedStorage/DevPackages/TestEZ", "DevPackages/TestEZ"),
       ("ServerScriptService/Server", "src/server"),
       ("ServerScriptService/Tests", "tests")]
def long(s):
    n = 0
    while f"]{'=' * n}]" in s: n += 1
    return f"[{'=' * n}[\n{s}]{'=' * n}]"
def classify(name):
    for ext in (".luau", ".lua"):
        for kind, cls in ((".server", "Script"), (".client", "LocalScript"), ("", "ModuleScript")):
            if name.endswith(kind + ext): return cls, name[: -len(kind + ext)]
    return None, None
entries = []
def walk(dm_path, fs_path):
    if os.path.isdir(fs_path):
        names = sorted(os.listdir(fs_path))
        init = next((e for e in names if re.fullmatch(r"init(\.server|\.client)?\.luau?", e)), None)
        if init:
            cls, _ = classify(init)
            entries.append((dm_path, cls, open(os.path.join(fs_path, init)).read()))
        else:
            entries.append((dm_path, "Folder", None))
        for e in names:
            if e == init: continue
            p = os.path.join(fs_path, e)
            if os.path.isdir(p): walk(f"{dm_path}/{e}", p)
            else:
                cls, base = classify(e)
                if cls: entries.append((f"{dm_path}/{base}", cls, open(p).read()))
for dm, rel in MAP:
    if not os.path.isdir(os.path.join(ROOT, rel)):
        sys.exit(f"missing {rel} (see README: TestEZ goes in DevPackages/TestEZ)")
    walk(dm, os.path.join(ROOT, rel))
out = ["local FILES = {"]
for path, cls, src in entries:
    out.append(f"\t{{ path = {json.dumps(path)}, class = {json.dumps(cls)}, src = {long(src) if src is not None else 'nil'} }},")
out.append("}")
entry = next((a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--entry=")), None)
out.append(f"local ENTRY = {json.dumps(entry) if entry else 'nil'}")
out.append(open(os.path.join(HERE, "shim.luau")).read())
os.makedirs(os.path.join(ROOT, "build"), exist_ok=True)
dest = os.path.join(ROOT, "build", "headless.luau" if entry is None else "entry.luau")
open(dest, "w").write("\n".join(out))
print(f"bundled {len(entries)} instances -> {os.path.relpath(dest, ROOT)}")
