# 1v1 CARD: status (2026-11-06, all HANDOFF stages built)

## Implemented (real logic, tested)

| System | Where | Tests |
| --- | --- | --- |
| Odds, Wallet, Hatch, Cards (copies, provenance, V1 merge), Inventory, Deck | `Shared/Domain` | Odds, Wallet, Hatch, Cards, Inventory, Deck specs |
| Profile schema v3, append-only migrations (1→2→3) | `Shared/Domain/ProfileSchema` | ProfileSchema.spec |
| Policy rules (purchase vs trading, fail closed) | `Shared/Domain/PolicyRules`, `Services/PolicyGate` | PolicyRules, PolicyMatrix specs |
| Session-locked persistence, receipts | `Server/Persistence`, `Server/Purchases` | SessionStore, ProfileManager, ReceiptProcessor, M1Acceptance specs |
| Net layer: every remote through Dispatcher (rate limit → parse → handler) | `Shared/Net`, `Server/Net` | Net.spec, e2e |
| Settlement: trophies, game-paid purse, daily cap, void rules, idempotent by matchId | `Shared/Domain/Settlement` | Settlement.spec |
| Battle engine (identical to Python on 1,000 seeds) | `Shared/Battle` | BattleParity.spec |
| MatchRunner (12 s picks, timeouts, forfeit, 5 s KO pick) and MatchHost (AI, 30 s reconnect) | `Server/Battle` | MatchRunner, MatchHost specs |
| Guardian AI (identical to `sim/balance.py` reader on 300 seeds) and Guardian Trials | `Server/Battle/BattleAI`, `Shared/Domain/Trials` | BattleAI, Trials specs |
| Matchmaking: pairing, lease, MemoryStore queue, match records, battle servers, reconnect | `Server/Matchmaking`, `Services/MatchmakingService` | Matchmaking.spec (mocked MemoryStore) |
| Worlds 1-10: layouts, builder, farming (range, profile-stored respawns), merchants | `Config/WorldLayouts`, `Shared/Domain/Farming`, `Server/World` | Worlds.spec, e2e |
| Quests (3 daily + achievements, Secret Egg reveal) and 7-day streak | `Shared/Domain/Quests`, `Shared/Domain/Streak` | Worlds.spec |
| Client UI: HUD, shop + Odds + Robux gating, hatch, collection, deck, arena/queue, battle, results, worlds, quests, settings, merchant | `src/client/App` | ui-check (real Studio), e2e |
| 100-character roster, 24 themed egg pools, Guardian decks | `Config/Characters`, `Config/EggPools`, `Config/Guardians` | ConfigValidator.spec, `sim/balance.py`, `sim/trials.py` |
| Telemetry events and counters | `Services/Telemetry` | e2e (no errors) |

## Placeholder (marked in `Config/ContentStatus` / `status = "Placeholder"`; release builds refuse them)

| Content | Why |
| --- | --- |
| Character art and card frames | Procedural rigs and code-drawn frames. Hero models need a 3D artist |
| Egg icons, character asset ids, Developer Product ids | Not uploaded or created yet (launch gaps) |
| Egg pools | Designed (8-10 per egg, every character covered) but await owner review |
| Odds bands, egg prices, economy prices, item prices, quest rewards | Starting values |
| Character numbers | Pass the balance gate; still need real playtests |
| Guardian decks | Difficulty curve needs playtests (`sim/trials.py`: 36-53% for a random deck) |
| World art | Data-driven blockouts |
| Party Egg odds | Stand-in Event band |

## Designed but not built (by decision)
- V2 player store (`Config/Market`, `enabled = false`), trading, cosmetics shop.

## Verification (2026-11-06)

| Check | Result |
| --- | --- |
| StyLua, Selene, luau-lsp strict, Rojo build (default, dev, e2e) | clean |
| TestEZ headless | 240 passed, 0 failed |
| TestEZ in real Studio (the owner's `live.rbxlx`, Rojo-synced) | 240 passed, 0 failed |
| Server boot in Studio Run mode (`scripts/studio/boot-check`) | 27 remotes, 10 worlds, 130 nodes, 0 errors |
| Every screen in Studio (`scripts/studio/ui-check`) | 0 failures, 0 text overflows, Robux button hidden/shown with the attribute, all 100 rigs build |
| End-to-end Play test in Studio (`scripts/e2e`, real client and UI) | 40 passed, 0 failed |
| `sim/balance.py` (100 characters) | every target met (characters 47.4-52.9%, attack-only 59%, adaptive 60%, length 15.9) |
| Player Emulator, 4 policy combinations | **1 of 4 run**: known/unrestricted/trading allowed printed `MATCH` (Studio defaults). The other 3 need the Player Emulator UI, which the Studio MCP can't drive. The logic for all 4 is unit-tested (PolicyMatrix.spec) |
| Cross-server matchmaking and teleports | logic unit-tested with mocks. ReserveServer/TeleportService only work on a published place, so not run live |
| Real DataStore / MemoryStore | not run: the place is unpublished, so Studio uses the in-memory fallbacks |
