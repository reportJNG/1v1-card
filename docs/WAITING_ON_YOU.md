# Waiting on you

Things only the owner can do. Everything else keeps moving without them. Newest items first.

## 00. Decisions POLISH_MISSION.md needs from you (it conflicts with locked rules)
- **New egg types (mission G).** CLAUDE.md locks the game to exactly the 24 icon-pack eggs. Say
  "allow new original eggs" (and how many) to unlock it; until then no egg is added.
- **Cosmetics shop (mission C, the Gems +).** Gems buy cosmetics, but the cosmetics shop is V2 and
  not built. The Gems + explains that for now. Say if you want the cosmetics shop in V1.
- **Character models (mission F).** These need your character images and Blender's generators
  switched on (items 1-2 below).

## 0. Review the lobby, world picker, the 10 worlds and the new cards (session 3)
- **Cards:** `docs/screens/cards/` (every rarity at level 1, level 15 and Golden; large Legendary and
  Mythical; hatch, collection, battle, results and deck builder). Say if the effects should be
  stronger or calmer per rarity.
- **Screenshots:** `docs/screens/12-15` (lobby spawn, world picker for a new player and at 760
  trophies, arriving in World 1) and `docs/screens/worlds/world01..10-*.jpg`.
- **World art is a first pass.** Each world has generated terrain, 6 generated meshes (Roblox
  `generate_mesh`, original), a code-drawn sky, its own lighting and particles. Say which worlds to
  push further and in what direction. Hero props or a terrain pass in Studio by hand would lift them
  the most.
- **Listen to the 10 world tracks** (`Config/Sounds`, `music_world1..10`). They are APMOfficial
  tracks picked by title and description only, because Claude can't hear audio. Replace any id you
  don't like.
- **World picker art:** the thumbnails are Studio captures of each world (`art/worlds/TEMP_*`). If
  you want painted key art, make 384×216 images and Claude will swap them in.

## 1. Turn on Blender's generators and libraries (5 minutes)
Blender 5.2 and the MCP addon are connected and up to date, but every 3D generator and asset
library is **off**, so image-to-3D (Hyper3D Rodin / Hunyuan3D) and Poly Haven textures can't run.
In Blender: **N panel → BlenderMCP**:
- tick **Use Hyper3D Rodin** (or **Hunyuan3D**) and add the API key (Rodin has a free trial key
  button), and
- tick **Use assets from Poly Haven**.

Then tell Claude "Blender is ready".

## 2. Character images (the main art blocker)
Generate the **card art** first, from `art/characters/PROMPTS.md`: one **transparent PNG** per
character, 768 × 1024, the character alone, upper body to knees, dynamic pose, anime cel-shaded, saved
as `art/characters/<id>/card.png`. Never use images of existing anime or game characters.
**Start with two:** `ren_emberfang` (Flame Striker) and `yuki_frostveil` (Ice Guardian). Claude
uploads them and sets `CharacterDef.assets.cardArt` (`python scripts/art/characters.py status|check|urls|apply`,
run on every loop pass); until then every character is a TEMP role silhouette tinted with its colours,
both on cards (labelled "TEMP ART") and as the 3D standee in battles and at the Guardian gates
(the old part-built rigs are gone). The A-pose model reference
(`front.png`) is only needed later for 3D.
Also optional: 15 painted family backgrounds (`card_bg_<family>`, listed in `art/ui/PROMPTS.md`
under "Card backgrounds") to replace the code-drawn ones.

## 3. Final UI art
Generate every image in `art/ui/PROMPTS.md` at the exact size, with a transparent background, as
`art/ui/<slot>.png`. The game runs on the TEMP stand-ins (`art/ui/temp/`) until then. When you add
some, Claude uploads them, fills `art/ui/ids.json` and runs `python scripts/art/make_temp_ui.py luau`.

## 4. Approve the vertical slice
Screenshots are in `docs/screens/` (01 hub HUD, 02 hub in Play mode, 03 egg shop, 04 hatch, 05-06 battle, 07 victory, 08 defeat, 09 collection, 10 deck builder, 11 arena). Look at them against `docs/brief/concept-board.png` and say what
to change. Scaling to every screen and all 100 characters continues in the meantime, but nothing
from the slice is called final until you approve it.

## 5. Sound effects (pick or approve)
Music is in: APMOfficial tracks, which are licensed for Roblox ("Yachiyo-Jishi" in the hub,
"Battleground" in battles, "Sports Fanfare" on victory, an APM swipe on panel open). Most SFX slots
in `src/shared/Config/Sounds.luau` are still **empty and silent**: click, hover, close, coin, error,
hatch shake/crack/reveal, tick, hit, special hit, parry, KO, defeat. Creator Store search can't
filter by creator, most "click/hit" results are rips from commercial games, and Claude can't hear
audio to judge it. Either:
- paste asset ids you like into `Config/Sounds.luau` (ProSoundEffects or APMOfficial uploads are
  safe), or
- say "make synthetic SFX", and Claude will synthesize original WAVs in code. That needs an audio
  upload (Open Cloud Assets API with your API key), because the Studio MCP only uploads images.

## 6. Still open from before
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
