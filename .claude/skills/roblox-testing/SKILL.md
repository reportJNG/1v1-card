---
name: roblox-testing
description: How to test 1v1 CARD - headless TestEZ, the full check run, running the suite and a boot check inside real Roblox Studio, the battle/AI parity fixtures and the Player Emulator policy matrix. Use before every commit and whenever a rule changes.
---

# Testing

## Toolchain
Run `rokit install` (Rojo 7.7.1, StyLua 2.6.0, Selene 0.31.0, luau-lsp 1.70.1). You also need the
Luau CLI, Python 3, and TestEZ in `DevPackages/TestEZ` (see README). For luau-lsp you need
`globalTypes.d.luau` from the luau-lsp repo. Set `PYTHONUTF8=1` on Windows.

## The full check (run all of it after every feature)
```
stylua src tests
selene src tests                                   # 0 errors, 0 warnings
rojo sourcemap dev.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --definitions=testez.d.luau --sourcemap=sourcemap.json src tests
rojo build default.project.json -o build/default.rbxlx
rojo build dev.project.json -o build/dev.rbxlx
python scripts/headless/bundle.py && luau build/headless.luau   # "N passed, 0 failed"
```
A run only passes if *every* step is clean. Don't grep for "passed" alone: also check for
` 0 failed`.

## Real Studio, no clicks (run-in-roblox 0.3.0)
```
run-in-roblox --place build/dev.rbxlx --script scripts/studio/run-tests.server.luau
run-in-roblox --place build/dev.rbxlx --script <copy of scripts/studio/boot-check.server.luau>
```
- `run-tests` prints `STUDIO TESTS: N passed, 0 failed`.
- `boot-check` calls `RunService:Run()`, so the real server Script boots. It prints
  `BOOT CHECK: remotes=… worlds=… nodes=… prompts=… errors=0`.
- Run mode has no client. For client and UI flows, play in Studio through the Roblox Studio MCP
  (`start_stop_play`, `screen_capture`, `get_console_output`).

## What to spec
- Every domain rule, including the reject paths (bad input changes nothing).
- Idempotency: replay the same matchId, PurchaseId or requestId and check nothing pays twice.
- Persistence: two servers, lock expiry, crash mid-save and shutdown flush (see
  `ProfileManager.spec`).
- Pure state machines with a fake clock (`MatchRunner`, `MatchHost`, `Matchmaker` with
  `InMemoryMap`).

## Parity: change battle rules or characters → regenerate
```
python scripts/headless/bundle.py --entry=ServerScriptService/Tests/Tools/ExportContent
luau build/entry.luau > sim/content.json
python sim/parity.py && python sim/ai_parity.py && python sim/balance.py
```
`BattleParity` (1,000 seeds) and `BattleAI` (300 seeds) must match Python exactly.
`sim/balance.py` must stay inside its targets.

## Player Emulator policy matrix (manual, in Studio)
There are four combinations of ArePaidRandomItemsRestricted × IsPaidItemTradingAllowed (README
table). Each `[PolicySelfCheck]` line must end in `MATCH`. Never report this as done until all
four have actually been run.
