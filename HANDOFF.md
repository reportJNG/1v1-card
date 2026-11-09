# Handoff (2026-11-09)

## Where things stand (read `PLAN.md` first: sections 2, 6 and 7)
- `PLAN.md` is the running plan; its section 6 is what to do next. `CLAUDE.md` "Asset safety" overrides
  everything: no image is used or uploaded without the owner's written approval.
- `MISSION.md`: every box is ticked except "Card with character" and Phase 2's first approved batch,
  which wait for the owner's images. Evidence: `docs/MISSION_REPORT.md`, `docs/screens/final_pass`.
- 5-card mode: `Config/Roster.active`; odds go through `Shared/Domain/Odds` (per-rarity fallback to
  active characters); sims use the active roster (`--all` for every character).
- Character art: `scripts/art/characters.py` (`ANIME_FOLDER.md`, "Adding character art").
- GitHub: `origin` = `https://github.com/reportJNG/1v1-card`; commit and push after every step.
  Stage named paths only (never `git add -A`).
- **Studio loop:** build `dev.project.json` to `build/final.rbxlx` for a fresh player (the
  `qa.project.json` build to `build/step5.rbxlx` grants a test collection). `execute_luau` has its own
  module cache, so to touch the running game's services insert a Studio-only Script during Play.
  Studio's game view can get stuck at 1 x 1; restart every Studio window then.

Every stage listed in the previous handoff is built, tested and committed (Settlement, MatchRunner +
BattleService + Guardian Trials, M4 matchmaking, M6 worlds, M5 client UI, the 100-character roster
and egg pools, M2 placeholder art, M7 prep). `STATUS.md` has what is real vs placeholder and every
check's result; `docs/CONVERSATION.md` ("Decisions made in the CLI") has every decision made along
the way.

## How to check everything
```
stylua src tests && selene src tests
rojo sourcemap dev.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --definitions=testez.d.luau --sourcemap=sourcemap.json src tests
python scripts/headless/bundle.py && luau build/headless.luau
```
In Studio (Rojo-synced `dev.project.json`), Command Bar:
`print(require(game.ServerScriptService.Tests.RunTests)().report)`

Real-Studio scripts (run with `run-in-roblox --place build/dev.rbxlx --script <file>`):
- `scripts/studio/run-tests.server.luau`: the TestEZ suite.
- `scripts/studio/boot-check.server.luau`: boots the real server in Run mode and checks it.
- `scripts/studio/ui-check.server.luau`: builds every screen and all 100 rigs, holds each for screenshots.
- `scripts/e2e/` + `e2e.project.json`: a Studio-only Play test. `Setup.server.luau` grants test
  cards; `Driver.client.luau` plays every remote as a client. Build `e2e.project.json` and press Play,
  or insert both scripts into a synced place, Play, read the `E2E` lines, then delete them.

## Regenerate after changing characters or battle rules
```
python3 scripts/headless/bundle.py --entry=ServerScriptService/Tests/Tools/ExportContent
luau build/entry.luau > sim/content.json
python3 sim/parity.py && python3 sim/ai_parity.py && python3 sim/balance.py && python3 sim/trials.py
python3 scripts/headless/bundle.py && luau build/headless.luau
```
New characters: edit `sim/roster.py`, then `python sim/roster.py tune` and `python sim/roster.py write`.

## Session 3: lobby, world maps, layered cards
- The owner's next step is `POLISH_MISSION.md` (every box ticked, each with Play-mode screenshots in
  `docs/screens`, all tests passing). Session 3's focus (lobby, worlds, cards) is done; see
  `docs/CONVERSATION.md` "Session 3" for the decisions.
- **Studio loop used this session.** Studio can't fetch localhost, so code is synced by rebuilding
  `dev.project.json` to `build/worlds.rbxlx` and reopening it (~15 s). Images upload through the
  Studio MCP `upload_image` from a local `python -m http.server 8765` in the repo root
  (`http://127.0.0.1:8765/<path>`).
- **Previews (Edit mode, Command Bar or MCP):**
  - `require(game.ServerScriptService.Tests.Tools.WorldPreview).build()` then `.show(n)` (0 = lobby)
  - `require(game.ServerScriptService.Tests.Tools.CardPreview).show()` (every rarity, Lv 1 / 15 /
    Golden) or `.show({ big = true, rarity = "Mythical" })`
- **New art:** world props are `generate_mesh` outputs recorded in `Config/WorldProps`; world skies
  come from `python scripts/art/make_sky.py world` (`art/sky/ids.json`); card layers come from
  `scripts/art/card_layers.py` through `make_temp_ui.py` (then `make_temp_ui.py luau`).
- A character's transparent card art goes in `CharacterDef.assets.cardArt`; the TEMP cutout
  disappears for that character automatically.

## Session 2: the visual slice
- Read `docs/ART_STYLE.md` first; `docs/WAITING_ON_YOU.md` lists what the owner owes; screenshots are
  in `docs/screens/`.
- Studio loop used this session: build `dev.project.json` to `build/slice.rbxlx`, open it in Studio,
  then in the Command Bar (or MCP `execute_luau`, Edit mode):
  `local P = require(game.ServerScriptService.Tests.Tools.UiPreview); P.show("Shop", {world = 1})`
  (also `P.hud()`, `P.hatch(golden)`, `P.battle(rounds)`, `P.result(win)`, `P.odds()`), and
  `require(game.ServerScriptService.Server.World.HubBuilder).build(workspace)` for the hub.
- New UI art: put the PNG in `art/ui/<slot>.png`, upload it, add the id to `art/ui/ids.json`, then run
  `python scripts/art/make_temp_ui.py luau`.
- Next for the slice: 2 characters through the pipeline once their images exist, SFX ids,
  per-world lighting, the Families panel in the deck builder, the inspect box and the
  remaining emoji labels.

## What needs the owner
1. **Player Emulator, the remaining 3 policy combinations** (Test → Player Emulator → Policies; see
   README). One combination (unrestricted, trading allowed) already printed `MATCH`.
2. **Publish to a test universe** to exercise real DataStores, MemoryStore matchmaking, ReserveServer
   and teleports with two accounts. Turn on Studio Access to API Services.
3. **Create the Developer Products** and fill `Config/Monetization` (egg icons are already uploaded unedited, session 2).

4. **Character art:** commission or produce hero models (DESIGN.md section 4), and fill
   `CharacterDef.assets`.
5. **Review:** egg pools, prices and the Taren/Vesper roles (their Specials sit at the 1.15 floor).
6. **The maturity questionnaire** on the Creator Dashboard.

## Next highest-priority work
1. A live two-account ranked match on a published place: matchmaking → teleport → battle →
   settlement → return.
2. An economy simulation (Coins in vs out per hour by world) to replace the starting prices.
3. World art passes (terrain, props, lighting) on the blockout layouts, keeping node positions.
4. Battle presentation: real animations on the R15-named rig joints, hit VFX, sound.
5. A tutorial for the first session (deck → first Trial → first ranked match).
