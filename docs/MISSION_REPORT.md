# MISSION.md report (2026-11-09)

What was built for the master mission, how it was checked, what is still TEMP, and what needs the
owner. Every comparison image is in the repo; per-item notes and scores are in `docs/POLISH_LOG.md`.
Tests: **291 headless TestEZ specs pass**; StyLua, Selene, luau-lsp strict and the Rojo builds are
clean on every commit.

## Checklist (MISSION section 15)
| Item | State | Evidence |
| --- | --- | --- |
| Old mission files archived | done | `docs/missions/archive/` |
| Flow: launch loading, menu, playing, leaving, reset, return-to-spot | done, Play mode | `docs/screens/flow/01..07`; Trial in World 1 returned to the exact spot (0.00 studs) |
| In-game HUD | done, Play mode | `docs/screens/hud/compare_ingame.png` |
| GUI audit + UI kit replacing TEMP images + logo | done | `docs/GUI_AUDIT.md`; 51 UI slots final (`art/ui/ids.json`); 183 kit images (`art/ui/MANIFEST_V2.json`); `logo_1v1card` |
| Rarity display config | done | N / R / SR / SSR / UR, "God-tier"; Odds shows "UR · God-tier" |
| Card frames | done | `docs/screens/step5/compare_frames.png` |
| Template card | done, Play mode | `compare_template.png`, `template_gallery.png` |
| **Card with character** | **waiting on approved art** | the art window path is in `App/Card`; the portrait pack was removed after the 2026-11-08 ban, so it waits for the owner's replacement images (`PLAN.md` section 6) |
| Card stats panel + Favorite | done, Play mode, specs | `compare_stats.png`; merge Lv 1 -> 3 through the server; Favorite specs |
| Card animations | done, Play mode | `compare_anim.png`, `anim_strip.png` |
| Evolution stages | done, Play mode, spec | `evolution.png` |
| Cards everywhere incl. deck bar | done | HUD deck bar, shop, hatch, inventory, stats, deck, battle, KO picker, results, arena |
| Egg pack, tier pedestals, Credits | done | unedited pack in `art/eggs/pack`, 64 px icons uploaded, Settings -> Credits |
| Egg Shop | done, Play mode | `docs/screens/eggs/compare_shop.png` |
| Egg opening (5 stages, every rarity, x1/x3/x8, Skip, Golden) | done, Play mode | `compare_opening_stage1..5.png` (God-tier, injected), x8 Golden (injected), x3 Skip, real x1 from the shop |
| Silhouettes | done | reveal uses black role silhouettes; `processed/<id>/silhouette.png` for the 10 portraits |
| Other screens | done, Play mode | `docs/screens/screens/compare_*.png` (inventory, deck, families, arena, victory from a real Trial win, defeat, worlds) |
| Sound | done (ids unreviewed) | `App/Sfx`, `docs/ASSETS.md` |
| Motion | done | `App/Motion` |
| Extra assets | done | `art/ui/MANIFEST_V2.json` |
| **Phase 2** | **pipeline reworked; first batch waiting** | `scripts/art/characters.py` with the review gate, no face sheets or expressions, upload groups of 5; `selftest` passes. The portrait pack is removed (`CLEANUP_PORTRAIT_PACK.md`) |
| Final pass (fresh player, phone and PC) | done, Play mode (2026-11-09) | `docs/screens/final_pass/01..21`: one continuous run at 1334 x 750 (loading, menu, PLAY, odds, x1, x8, upgrade, favourite, deck, World 1 Trial and back to the same spot, arena queue and cancel, Menu -> leaving -> menu -> PLAY) and the same screens at 1066 x 600 (16:9 scaling; a 1920 x 1080 viewport can't fit in Studio on this screen). Fixed on the way: a KO fall played on the replacement card, battle plates under Roblox's buttons, clipped shop price pills and grid badges. x8 used a Studio-only Coins top-up |
| Report | this file | |

## Scores (1-10: reference · quality · little text · motion · consistency)
Frames 8·8·9·8·9 · Template 8·8·9·8·9 · Stats 9·8·9·8·9 · Animations 8·8·9·8·9 · Evolution 8·8·9·8·9 ·
HUD 8·8·9·8·8 · Shop 8·8·8·8·9 · Opening 8·8·8·9·9 · Inventory 8·8·8·8·9 · Deck 8·8·8·9·9 ·
Families 8·8·8·8·9 · Arena 8·8·8·8·9 · Victory 9·8·8·9·9 · Defeat 8·8·9·8·9 · Worlds 8·8·9·8·9 ·
Flow 9·9·8·9 (no board). The egg art scores against board 01 count the pack eggs as correct by design
(the mission replaced the Blender eggs with the unedited pack).

## Asset manifest summary
- `art/ui/MANIFEST_V2.json`: 183 kit images, all uploaded (route B: Blender emblems and pedestals;
  route C: everything else, drawn by `scripts/art/card_kit.py`, `ui_kit.py`, `ui_extras.py`).
- `art/ui/ids.json`: 73 final UI slot images (`scripts/art/ui_slots.py`).
- Eggs: 47 pack icons at 256 px (earlier) + 47 at 64 px (this mission), unedited.

## Still TEMP
- 24 `cutout_*` role silhouettes (every character, until approved art).
- Sound picks for the new slots (licensed ids, unreviewed by ear).
- Everything already listed as Placeholder in `Config/ContentStatus` (pools, prices, world art...).
- The 5-card roster's numbers (re-tuned for five; `sim/balance.py --all` before turning more on).

## Needs the owner (`docs/WAITING_ON_YOU.md`, section 0000; `PLAN.md` section 7)
1. Confirm the 43 portrait-pack assets are archived (no uploads before).
2. The 5 original replacement card images, then approve their review sheet.
3. Whether to scrub the rejected fighter images from GitHub history (force push).
4. 100 levels instead of 15? (needs a rebalance)
5. Listen to the unreviewed sounds.
