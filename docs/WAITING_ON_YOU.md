# Waiting on you

Things only the owner can do. Everything else keeps moving without them. Newest items first.

## 1. Turn on Blender's generators and libraries (5 minutes)
Blender 5.2 and the MCP addon are connected and up to date, but every 3D generator and asset
library is **off**, so image-to-3D (Hyper3D Rodin / Hunyuan3D) and Poly Haven textures can't run.
In Blender: **N panel → BlenderMCP**:
- tick **Use Hyper3D Rodin** (or **Hunyuan3D**) and add the API key (Rodin has a free trial key
  button), and
- tick **Use assets from Poly Haven**.

Then tell Claude "Blender is ready".

## 2. Character images (the main art blocker)
Generate one image per character from `art/characters/PROMPTS.md` and save it as
`art/characters/<id>/front.png` (about 1024 px tall, plain light-grey background).
**Start with two for the vertical slice.** Suggested: `ren_emberfang` (Flame Striker) and
`yuki_frostveil` (Ice Guardian), the two launch characters with the most different silhouettes.
Until they exist, battle and cards use the procedural placeholder rigs.

## 3. Final UI art
Generate every image in `art/ui/PROMPTS.md` at the exact size, with a transparent background, as
`art/ui/<slot>.png`. The game runs on the TEMP stand-ins (`art/ui/temp/`) until then. When you add
some, Claude uploads them, fills `art/ui/ids.json` and runs `python scripts/art/make_temp_ui.py luau`.

## 4. Approve the vertical slice
Screenshots are in `docs/screens/`. Look at them against `docs/brief/concept-board.png` and say what
to change. Scaling to every screen and all 100 characters continues in the meantime, but nothing
from the slice is called final until you approve it.

## 5. Still open from before
- Player Emulator: the remaining 3 of the 4 policy combinations (README, "Testing PolicyService
  combinations").
- Publish to a test universe to try real DataStores, MemoryStore matchmaking and teleports.
- Developer Products in `Config/Monetization`.
- Review the egg pools, prices and the Taren/Vesper roles.
- The maturity questionnaire.

## Notes for you
- **Four display names were changed** after a web name check because they were too close to
  existing characters. Ids are unchanged, so saves are unaffected:
  | Was | Now | Too close to |
  | --- | --- | --- |
  | Corran Ashenhorn | Brakus Ashenhorn | Corran Horn (Star Wars) |
  | Duran Oakblade | Halvard Oakblade | Duran (Trials of Mana) |
  | Sorin Embervale | Cassius Emberreach | Sorin Markov (MTG); Embervale is the Enshrouded world |
  | Nessa Fangwood | Wrenna Fangwood | Nessa (Pokémon) |
- **The "+" next to Coins and Gems does not sell anything.** Coins and Gems can't be bought with
  Robux (locked decision), so "+" opens Worlds (earn Coins) and Quests (earn Gems).
- **The concept board's "Trade" menu item and "Bet Amount" panel are not in the game.** Trading is V2,
  and wagers are banned (see `docs/CONVERSATION.md`).
