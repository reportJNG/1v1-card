# 1v1 CARD: status (2026-11-07, lobby + 10 world maps + layered cards)

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
| Worlds 1-10 as separate maps (`Workspace.Worlds.World01..10`): generated terrain, 62 generated meshes, nodes, merchant, Guardian Trial gate, Back to Lobby portal, walls, ambience; farming (range, profile-stored respawns), merchants | `Config/WorldLayouts`, `Config/WorldProps`, `Shared/Domain/WorldLayout`, `Shared/Domain/Farming`, `Server/World` | Worlds.spec (layout, decor clearances, material colours, props/lighting/music per world), Play mode (travel, harvest, sell, Trial, lobby portal), `docs/screens/worlds` |
| Quests (3 daily + achievements, Secret Egg reveal) and 7-day streak | `Shared/Domain/Quests`, `Shared/Domain/Streak` | Worlds.spec |
| Client UI: HUD, shop + Odds + Robux gating, hatch, collection, deck, arena/queue, battle, results, worlds, quests, settings, merchant | `src/client/App` | ui-check (real Studio), e2e |
| 100-character roster, 24 themed egg pools, Guardian decks | `Config/Characters`, `Config/EggPools`, `Config/Guardians` | ConfigValidator.spec, `sim/balance.py`, `sim/trials.py` |
| Telemetry events and counters | `Services/Telemetry` | e2e (no errors) |
| Image-based UI kit (9-slice skins, fonts, motion, sounds, theme pass) | `App/Ui`, `App/Theme`, `Config/UiAssets`, `Config/Sounds` | Studio previews (`tests/Tools/UiPreview`), validator spec |
| Lobby as the spawn point: join, respawn, after every battle, fall-out; world picker (art, trophies, lock state), World.Travel (server-checked), Back to Lobby (portal + HUD) | `Config/HubLayout`, `Server/World/HubBuilder`, `Services/WorldService`, `Screens/Worlds`, `Config/WorldArt` | Play mode in Studio: spawn, picker from the portal, locked world refused, travel, respawn, Trial → lobby, lobby portal |
| Area lighting + sky + music per area (hub, arena, world1..10) | `Config/Lighting`, `Config/Sounds`, `App/AreaFx` | Play mode in Studio, world captures |
| Layered 2.5D card (shadow, glow, family background, cutout + rim light, effects, rarity-tinted frame, Golden foil, rarity banner, level badge with level-15 crown, family icon, stats), animated only while on screen, parallax on hover / press / tilt; used in collection, inspect, deck builder, hatch reveal, battle, KO picker and results | `App/Card`, `App/CardFx`, `App/Visuals`, `scripts/art/card_layers.py` | Play mode (hatch, collection + inspect, battle, result), `tests/Tools/CardPreview` gallery, CardFx visibility counts in Studio, `docs/screens/cards` |
| Hatch sequence, 3D battle stage, battle UI, results | `Screens/Hatch`, `App/BattleStage`, `Screens/Battle` | Play mode: a real Guardian Trial round and forfeit |
| Step 3 GUI: standalone main menu (PLAY always to the lobby), icon-first HUD dock (icon pack, unedited), glow tiles and price pills, Shop / Inventory / Deck / Merchant restyle, code-drawn card face (rarity pill, sockets, power plate), staggered tile pop-in, starter deck for new players | `App/MainMenu`, `App/App`, `App/Card`, `App/Ui` (glowTile, pricePill, stagger), `Screens/*`, `ProfileSchema.grantStarter` | Play mode (`docs/screens/step3`, `docs/screens/final`), UiFlow and ProfileSchema specs |
| 100 character art briefs | `Config/Characters` (`look`), `sim/roster_looks.py` | ConfigValidator spec |

## Placeholder (marked in `Config/ContentStatus` / `status = "Placeholder"`; release builds refuse them)

| Content | Why |
| --- | --- |
| Character art | Procedural placeholder rigs until the owner's images go through the pipeline |
| Character asset ids, Developer Product ids | Not created yet (launch gaps). Egg icons are uploaded unedited (session 2) |
| Egg pools | Designed (8-10 per egg, every character covered) but await owner review |
| Odds bands, egg prices, economy prices, item prices, quest rewards | Starting values |
| Character numbers | Pass the balance gate; still need real playtests |
| Guardian decks | Difficulty curve needs playtests (`sim/trials.py`: 36-53% for a random deck) |
| World art | First pass: generated terrain and meshes, code-drawn skies, Studio-captured picker thumbnails, APM tracks picked by title |
| Party Egg odds | Stand-in Event band |
| All UI images | TEMP code-drawn stand-ins (`art/ui/temp`) until the owner's art (`art/ui/PROMPTS.md`) |
| Hub art | Generated meshes and a code-drawn sky, awaiting slice approval |
| Sound choices | Every slot filled with licensed APM/PSE audio, picked without listening; the owner reviews |

## Designed but not built (by decision)
- V2 player store (`Config/Market`, `enabled = false`), trading, cosmetics shop.

## Verification (2026-11-06)

| Check | Result |
| --- | --- |
| StyLua, Selene, luau-lsp strict, Rojo build (default, dev, e2e) | clean |
| TestEZ headless (step 3) | 263 passed, 0 failed |
| TestEZ headless (session 3) | 246 passed, 0 failed |
| TestEZ in real Studio (session 3, run-in-roblox) | 246 passed, 0 failed |
| TestEZ headless (session 2) | 242 passed, 0 failed |
| TestEZ in real Studio (session 2, `build/slice.rbxlx`) | 242 passed, 0 failed |
| TestEZ headless (session 1) | 240 passed, 0 failed |
| TestEZ in real Studio (the owner's `live.rbxlx`, Rojo-synced) | 240 passed, 0 failed |
| Server boot in Studio Run mode (`scripts/studio/boot-check`, session 3) | 29 remotes, 10 worlds, 130 nodes, 160 prompts, 0 errors |
| Every screen in Studio (`scripts/studio/ui-check`, session 3) | 0 failures, 0 text overflows (2 found and fixed: Shop drop line, hatch caption), Robux button hidden/shown with the attribute, all 100 rigs build |
| End-to-end Play test in Studio (`scripts/e2e`, real client and UI, session 3) | 40 passed, 0 failed |
| Lobby / worlds Play test (session 3) | spawn in lobby, picker from the portal, locked world refused, travel, harvest, sell, Trial → back in lobby, respawn → lobby, lobby portal → lobby |
| `sim/balance.py` (100 characters) | every target met (characters 47.4-52.9%, attack-only 59%, adaptive 60%, length 15.9) |
| Player Emulator, 4 policy combinations | **1 of 4 run**: known/unrestricted/trading allowed printed `MATCH` (Studio defaults). The other 3 need the Player Emulator UI, which the Studio MCP can't drive. The logic for all 4 is unit-tested (PolicyMatrix.spec) |
| Cross-server matchmaking and teleports | logic unit-tested with mocks. ReserveServer/TeleportService only work on a published place, so not run live |
| Real DataStore / MemoryStore | not run: the place is unpublished, so Studio uses the in-memory fallbacks |
