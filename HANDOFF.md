# Handoff (2026-11-06)

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
