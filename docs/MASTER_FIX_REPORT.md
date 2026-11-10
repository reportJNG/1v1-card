# MASTER FIX REPORT

The progress log for `MASTER_FIX_PLAN.md` (phases 0-13) and `GOAL_ALL.md` (Phase 3b icons,
Phase 14 characters). Updated at every commit. Scores follow `UI_TARGETS.md` (1-10, 8+ on each
point to pass), from Play screenshots and a side-by-side compare image.

**Status words:** `todo` · `in progress` · `done` · `done, waiting for art` (the layout and
behaviour are final; only named owner sheets are missing) · `done, waiting for owner`.

## Phase table

| Phase | What | Status | Commits | Scores |
|---|---|---|---|---|
| 0 | Prepare: README, report, before shots, PROMPTS_V3, links, character rename | done | see git log `ui(0)` | n/a |
| 1 | Bugs from the reports (Sell all, item icons, return-to-spot) | todo | | |
| 2 | Stop web thinking: WorldText, no toast bars, sweep | todo | | |
| 3 | Image-kit pipeline (cut_sheet, kit.json, slice test, App/Ui/Kit) | todo | | |
| 3b | Combined icon set (three packs, licences, icon_map.json) | todo | | |
| 4 | In-game HUD | todo | | |
| 5 | Main menu | todo | | |
| 6 | Egg Shop | todo | | |
| 7 | Merchant + every other panel | todo | | |
| 8 | Deck Builder, Families, Inventory | todo | | |
| 9 | Battle screen + 5 arenas | todo | | |
| 10 | Battle result | todo | | |
| 11 | Lobby full upgrade | todo | | |
| 12 | Worlds 1-10 upgrade | todo | | |
| 13 | Final pass | todo | | |
| 14 | Characters: rename done in Phase 0; art waits for "new images are in" | done, waiting for owner (art) | | |

## Phase notes

### Phase 0 (2026-11-10)
- **Toolchain.** The tools from earlier sessions lived in a temp folder that was cleared. Reinstalled
  the `rokit.toml` versions plus the Luau CLI, Python 3.13 (Pillow, numpy) and the luau-lsp Roblox
  definitions into `C:\Users\Administrator\Tools\1v1card` (persistent, outside the repo).
  `scripts/check.sh` now runs the whole gate in one command (README "Checks"). Baseline before any
  change: StyLua, Selene, luau-lsp clean, 3 Rojo builds, **291 passed, 0 failed**.
- **README.md** restored from history (`72341c9~1`), with the one-command gate, the toolchain note
  and a fuller layout.
- **Before screenshots** in `docs/screens/before/`:
  - lobby from 6 angles (`lobby_1..6`, also `docs/screens/lobby/before_*`), Studio Edit mode,
    hub preset
  - every other screen from the 2026-11-09 final pass, which ran on this exact code: main menu,
    HUD, Egg Shop, odds, inventory, deck, battle, Victory, arena queue, confirm
  - the owner's own "now" captures for the merchant (03), Defeat (17), the toast bar (01) and the
    battle (19)
- **Owner prompts** for every sheet in one file, `art/ui/PROMPTS_V3.md`, and the priority list at
  the top of `docs/WAITING_ON_YOU.md`.
- **Links:** `PLAN.md` §6 step 2 and `CLAUDE.md` "Start here" point at this plan and this report.
- **Characters renamed** (GOAL_ALL Phase 14, "can be done now"): `displayName` and `look` only; ids,
  stats and `Roster.active` unchanged. `sim/roster_looks.py` holds the new briefs (from
  `NEW_5_CHARACTERS.md`), `python sim/roster.py looks` regenerated `Config/Characters` and
  `art/characters/PROMPTS.md`, and the card prompt template is now the owner's shared style. A
  Roster spec pins the five names. The design doc table and `PLAN.md` use the new names; history
  logs keep the old ones.

## Waiting for art
Nothing is blocked: each phase builds its layout and behaviour with TEMP images. The sheets each
phase will swap in (prompts in `art/ui/PROMPTS_V3.md`):

| Sheet | Phases | Status |
|---|---|---|
| A (panel kit) | 4-8 | not received |
| E1-E4 (HUD) | 4 | not received |
| D1-D4 (menu) | 5 | not received |
| B (egg tiles) | 6, 8 | not received |
| Merchant kit + icons | 7 | not received |
| H1-H2 (battle) | 9 | not received |
| G1-G2 (result) | 10 | not received |
| F1 (inventory extras) | 8 | not received |
| C (crystal eggs) | 6 | only if Option 2 |
| Lobby concept | 11 | optional |
| 5 character images | 14 | not received (`NEW_5_CHARACTERS.md`) |

## Owner decisions
| Decision | Asked | Answer |
|---|---|---|
| Egg art: Option 1 (pack eggs in tier tiles) or Option 2 (Sheet C crystal eggs) | 2026-11-10 | pending; Option 1 ships meanwhile |
| GitHub history scrub of `fighter_01..05` (commit `9969dc6`) | 2026-11-10 | pending: waits for the owner's "go" |
| Approval of every new image (sliced pieces, icons, sheets) | per review sheet | pending per sheet |

## Incidents
| Date | What | Action |
|---|---|---|
| 2026-11-10 | The Studio MCP `screen_capture` hung and the viewport reported 1 × 1: the PC's display had gone to sleep at night, which froze the desktop. | Woke the display and ran a session-only keep-awake loop (no power settings changed). `scripts/studio/grab.ps1` saves a Studio window shot as a fallback. |
| 2026-11-10 | Parallel tool downloads landed in the repo root for a moment (a `cd` inside a backgrounded subshell). | Moved out before any commit; nothing staged. |
| 2026-11-10 | A desktop folder named "Ultimate Multi-Expre…" (it looks like the banned portrait pack) still exists on the owner's desktop. | Not touched (owner's files). Flagged in `WAITING_ON_YOU.md`; the project never reads it. |
