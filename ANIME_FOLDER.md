# Adding character art

How the owner's character images get into 1v1 CARD, safely. The rules come from `CLAUDE.md`
("Asset safety") and `PLAN.md` sections 3-5. They exist because an uploaded anime face got the
owner's Roblox account banned on 2026-11-08 (`CLEANUP_PORTRAIT_PACK.md`).

---

## 1. What an image must be

1. **A Roblox-style character drawn in an anime style.** Fully clothed, in a battle-ready outfit.
   The expression is neutral, determined, confident or heroic. **No anime girl characters.**
2. **Nothing suggestive, ever:**
   - no blushing, tears, open-mouth, "flustered" or pained faces, drool, tongue out, panting or
     rolled-back eyes
   - no cleavage, bare midriffs, swimsuits, lingerie or suggestive poses
3. **Not an existing character or look.** No Naruto, Sasuke, Itachi/Akatsuki, Gojo, Luffy, Goku
   and so on, even redrawn in Roblox style or renamed. That also rules out their signature looks:
   leaf headbands, Akatsuki clouds, a blindfold with white hair, an orange jumpsuit with a fox
   spirit, a straw hat. No datasets or packs of existing characters.
4. **One character per image**, ideally with a transparent or plain background, upper body to
   knees. It becomes a card's art window, the stats panel art and the egg reveal silhouette.
   **Expression sheets are never used**; battle reactions are effects only.

## 2. Where to put it

Only `C:\Users\Administrator\Downloads\New folder`. Its first five files (`fighter_01..05`) are
rejected (they were recognisably existing characters), and the pipeline refuses them by name.

## 3. The flow (`scripts/art/characters.py`)

| Step | Command | What happens |
| --- | --- | --- |
| 1. Copy | `ingest [folder] [batch]` | New images are copied, unchanged, to `art/characters/incoming/<batch>/` (git-ignored). The batch name defaults to today's date |
| 2. Review | `sheet <batch>` | Writes the contact sheet `docs/review/<batch>.png` and the checklist `docs/review/<batch>.md`. Claude looks at every image and fills in rules 1-3 for each |
| 3. **Stop** | | Claude shows the contact sheet and **waits for the owner's written approval in chat**. Nothing is processed, used or uploaded before it |
| 4. Approve | `approve <batch> "<owner's words>"` | Records the approval with the owner's words. `process` and `urls` refuse a batch without it |
| 5. Map | `map <batch> <file> <character id>` | Each image becomes one roster character (closest family and role). Only its `look` text, and its display name if needed, may change; never its stats or id |
| 6. Process | `process <batch>` | On copies: background cut (plain backgrounds only), trim, one colour grade, a rim light in the family colour, at most 4x upscale. Writes `processed/<id>/card.png` (576 × 768), `portrait.png` (512 × 512) and `silhouette.png`. No expressions |
| 7. Check | `check <batch>` | Sizes, transparency, duplicates, and the gallery `docs/screens/characters/contact_<batch>.png` |
| 8. Upload | `urls <batch>` | Upload URLs in **groups of at most 5**, through the Roblox Studio MCP `upload_image` (serve the repo with `python -m http.server 8765`). **At the first "moderated", "rejected" or 403, stop all uploads and tell the owner** |
| 9. Apply | `apply <ids.json>` | Writes the ids into `Config/Characters` (`assets.cardArt`). The card, stats panel and egg reveal pick them up |
| 10. Turn on | edit `Config/Roster.active` | The character joins the active roster (eggs, starter deck, Guardians). Re-run `sim/balance.py` and `sim/trials.py` |

`status` shows every batch and whether it's approved. `selftest` runs steps 1-8 on a synthetic image
in a temp folder (nothing uploaded, nothing in the repo changed).

## 4. Removed: the portrait pack
The "Ultimate Multi-Expression Portrait Pack" was removed permanently on 2026-11-08 after one of its
faces got the owner's account banned (`CLEANUP_PORTRAIT_PACK.md`). Expression sheets are never used.

## 5. The icon pack (used)
`Downloads\Free Icon Pack v3.1 (Basic)` by @gvesster allows commercial use and does not allow
editing the icons for resale. The HUD shortcuts use its icons **unedited** (the 256 px "Outline"
versions), listed in `docs/ASSETS.md`. Its license is copied to `art/icons/License.txt`.
