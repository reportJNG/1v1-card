# Polish report (POLISH_MISSION.md, 2026-11-07)

Every checklist item is in `POLISH_MISSION.md`. Per-item detail (what changed, what was tested,
scores) is in `docs/POLISH_LOG.md`. This page is the summary.

## What was built

| Item | Result |
| --- | --- |
| A. UI state machine | `Shared/Ui/UiFlow` (Loading → MainMenu → Playing → Panel / Hatching / Queue / Battle / Result), with blur, input lock and HUD modes. Specs plus Play |
| B. Main menu | A separate screen with the menu camera drift, PLAY fly-in, menu music and shortcuts |
| C. Gameplay HUD | Icon menu, currency pills with tips, notification dots, quest tracker, place name, floating +N, Friends invite, custom prompts, no emoji |
| D. Every screen | Inventory (tabs, search, rarity filters, eggs and items), big card inspect, Families panel, Arena with trophies, Worlds with completed ticks, Settings sliders (saved, profile v4) |
| E. Cards | Layered 2.5D card everywhere, effects per rarity, Golden foil, level-15 crown, animated only while visible |
| F. Characters | Part-built rigs replaced by standees with cut-out art. Character-art pickup script. Real models wait for the owner's images (see TEMP below) |
| G. Eggs | The 24 icon-pack eggs, data-driven pools, an Odds button on every egg, Robux and Golden rules. New egg types are **not built** because the locked 24-egg rule forbids them |
| H. Egg opening | x1 / x3 / x8 (checked on the server, one charge per batch), grid reveal, Skip, auto-open, "NEW!" tags, Legendary slow-mo, Mythical shockwave, Golden sequence, a sound for every beat |
| I. Music and sound | Every slot uses a licensed APMOfficial or ProSoundEffects id, crossfades between areas, volume sliders. Fixed: the menu music never loaded |
| J. Lobby and worlds | Lobby spawn, world picker, 10 world maps with terrain, props, skies, lighting and music |
| K. Final pass | A fresh-player playthrough, screenshots of every screen, this report |

## The fresh-player playthrough (K, in Play, 2026-11-07)
- **Run with a brand-new profile:** join → main menu → PLAY → lobby → Deck → Shop x1 hatch →
  World picker → World 1 → Guardian Trial → **Victory** (+40 trophies, +300 Coins, +25 Gems, a
  Golden egg) → back in the lobby → World 1 → harvest → sell to Farmer Tobb (+25 Coins) → Menu →
  main menu. Quests counted the harvest and the sale.
- **Fixed during the pass:**
  - **New players couldn't battle.** 500 Coins (2 eggs) plus the free egg give 3 random cards,
    often duplicates, and a deck needs 3 different characters. Every player who has never owned a
    card now gets three different Basic-egg Commons as a ready deck (`Economy.StarterCards`,
    `ProfileSchema.grantStarter`, once only, never for anyone who ever had a card; spec added).
    With them, the first Guardian Trial was won.
  - The hatch said "NEW CARD!" for a card already owned. It now says "YOU GOT" unless something
    is new.
  - The main-menu track never loaded. AreaFx now rebuilds a stuck track (found in I).
- **Noted for the next step:** PLAY on the main menu resumes where the player was (a world)
  instead of always going to the lobby. The owner's step 3 asks for the lobby, so it changes
  there.

## Screenshots
| Folder | What |
| --- | --- |
| `docs/screens/final/01-15` | The playthrough: menu, lobby HUD, starter deck, hatch, picker, World 1, battle, victory, merchant, sold, back to menu, inventory, arena, quests, settings |
| `docs/screens/hatch/01-15` | Egg opening: x1/x3/x8, Skip, Golden, Legendary/Mythical (injected cards), 3 sizes |
| `docs/screens/eggs`, `hud`, `ui`, `screens`, `cards`, `characters`, `worlds` | Items B-J |
| `docs/screens/01-15.jpg` | **Before**: the session-2 vertical slice, to compare with `final/` |

## Scores (1-10: board / readability / polish / clarity / consistency)
| Item | Scores |
| --- | --- |
| A, B, C, D, H | 8 / 8 / 8 / 9 / 9 |
| G, I | 8 / 9 / 8 / 9 / 9 |
| F | 7 / 8 / 7 / 9 / 9 (held back by TEMP character art) |

## Still TEMP or waiting on the owner (`docs/WAITING_ON_YOU.md`)
- **Character art.** Every character is a TEMP role silhouette until the owner's transparent
  `card.png` images exist. 3D models also need Blender's generators switched on.
- **UI images.** All UI images are code-drawn TEMP stand-ins (`art/ui/PROMPTS.md`).
- **World art and key art.** First pass only.
- **Audio.** Claude picked the ids without hearing them; the owner should listen and swap any.
- **Decisions on locked rules:** new egg types and the cosmetics shop.
- **Store setup:** Developer Product ids, the 3 remaining Player Emulator policy combinations,
  and a published test universe.

## Checks
StyLua, Selene and strict luau-lsp are clean, the Rojo builds work, and **263 TestEZ specs pass,
0 fail** (headless).

## Next priorities
1. The owner's step 3: a full GUI redesign from the new references (`Downloads/now gui`), with PLAY
   always going to the lobby, an icon-first HUD, sounds and animations.
2. Character art through the pipeline (two characters first).
3. A live two-account ranked match on a published test place.
