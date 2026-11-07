"""Merge Studio upload results ({"<url>/<slot>.png": "rbxassetid://..."}) into art/ui/ids.json, the
`final` ids for Config/UiAssets slots. Then run `python scripts/art/make_temp_ui.py luau`.

  python scripts/art/final_ids.py '<json>'
"""
import json
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PATH = os.path.join(ROOT, "art", "ui", "ids.json")
ids = json.load(open(PATH)) if os.path.exists(PATH) else {}
for url, aid in json.loads(sys.argv[1]).items():
    ids[os.path.basename(url)[:-4]] = aid
json.dump(ids, open(PATH, "w"), indent=1, sort_keys=True)
print(len(ids), "final ids")
