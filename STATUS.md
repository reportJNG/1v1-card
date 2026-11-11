# 1v1 CARD: status (2026-11-09, 5-card mode, portrait pack removed, final pass)

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
| Active roster (5-card mode, now 8 with set 02): only `Config/Roster.active` characters drop from eggs (odds panel = roll), start the deck and fight as Guardians | `Config/Roster`, `Shared/Domain/Odds`, `Config/Economy.StarterCards`, `Config/Guardians` | Roster.spec, Odds.spec, ConfigValidator, `sim/balance.py`, `sim/trials.py`, Play mode (odds, x1, x8) |
| Character art pipeline under the asset safety rules (review gate, owner approval, no expressions, upload groups of 5) | `scripts/art/characters.py`, `ANIME_FOLDER.md` | `characters.py selftest` |
| Battle reactions as effects only (sword, shield, KO ring) | `App/BattleStage` | Play mode (recorded during a 15-round Trial) |
| 100 character art briefs | `Config/Characters` (`look`), `sim/roster_looks.py` | ConfigValidator spec |
| MASTER_FIX_PLAN UI (2026-11-10): toast-free WorldText, clean HUD + tutorial, main menu, Egg Shop, merchant and every panel, deck/families/inventory, battle screen to target 18, battle result with both fighters | `App/WorldText`, `App/Hud`, `App/MainMenu`, `Screens/*`, `Screens/Battle`, `Screens/BattleResult` | Play mode, compare images in `docs/screens/roblox-ui`, `docs/MASTER_FIX_REPORT.md` |
| 5 battle arenas (Sakura Courtyard, Frozen Shrine, Volcano Forge, Celestial Isle, Storm Rooftop), picked by the server from the match seed | `Config/Arenas`, `Shared/Domain/ArenaLayout`, `Shared/Art/ArenaKit`, `Server/World/ArenaBuilder` | Arenas.spec, Play mode (`docs/screens/arenas`) |
| Lobby rebuilt to the FIX_LOBBY zone plan, with a working lobby merchant, quest board and daily shrine | `Config/HubLayout`, `Server/World/HubBuilder` | Lobby.spec, Worlds.spec, Play mode (`docs/screens/lobby`, `docs/LOBBY_AUDIT.md`) |
| FIX_LOBBY_2: the menu's own scene; the lobby's second pass (spawn shrine and welcome burst, giant double torii, temple gate and light pillar, egg pagoda and golden egg, tiled plaza, walls, shelf edge with waterfalls, shooting stars, ambient sound zones), 3,230 parts, 26 lights | `Config/MenuStage`, `App/MenuScene`, `Config/LobbyDecor`, `App/AreaFx` | MenuStage.spec, Lobby.spec (spawn on the shrine, part budget, sounds, motions), Play mode (`docs/screens/lobby2`, `compare_lobby2.png`) |
| Worlds 1-10: spawn gate, landmarks, readable nodes, paths | `Config/WorldLayouts` (`theme.gate`), `Server/World/WorldBuilder` | Worlds.spec, `docs/screens/worlds/compare_world*.png` |

## Placeholder (marked in `Config/ContentStatus` / `status = "Placeholder"`; release builds refuse them)

| Content | Why |
| --- | --- |
| Character art | Procedural placeholder rigs until the owner's images go through the pipeline |
| Character asset ids, Developer Product ids | Not created yet (launch gaps). Egg icons are uploaded unedited (session 2) |
| Egg pools | Designed (8-10 per egg, every character covered) but await owner review |
| Odds bands, egg prices, economy prices, item prices, quest rewards | Starting values |
| Character numbers | Pass the balance gate; still need real playtests |
| Guardian decks | Difficulty curve needs playtests (`sim/trials.py`: 36-53% for a random deck) |
| World art | Spawn gates and readable nodes (Phase 12) on generated terrain and meshes, code-drawn skies, Studio-captured picker thumbnails, APM tracks picked by title |
| Party Egg odds | Stand-in Event band |
| All UI images | Layouts final (MASTER_FIX_PLAN 4-10); painted pieces are TEMP until the owner's sheets (`art/ui/PROMPTS_V3.md`) pass the review gate |
| Hub art | Zone layout built (Phase 11) from generated meshes and simple parts; Blender hero props and a night skybox wait for the review gate |
| Sound choices | Every slot filled with licensed APM/PSE audio, picked without listening; the owner reviews |

## Designed but not built (by decision)
- V2 player store (`Config/Market`, `enabled = false`), trading, cosmetics shop.

## Verification (2026-11-06)

| Check | Result |
| --- | --- |
| TestEZ headless (2026-11-09) | 291 passed, 0 failed |
| Final pass in Studio Play (2026-11-09) | one continuous fresh-player run at 1334 x 750 + the same screens at 1066 x 600 (`docs/screens/final_pass`); 4 issues found and fixed |
| `sim/balance.py` on the 5-card roster (2026-11-09) | every target met (characters 46.6-53.0%, length 16.0, attack-only 48%, adaptive 60%); Trials 42-53% |
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
