# Waiting on you

Things only the owner can do. Everything else keeps moving without them. Newest items first.

## 00000. The master fix plan (2026-11-10; `MASTER_FIX_PLAN.md`, progress in `docs/MASTER_FIX_REPORT.md`)
Claude builds every screen's new layout and behaviour now with TEMP images, so nothing waits on
you. The painted look comes from these sheets. **Exact prompts: `art/ui/PROMPTS_V3.md`.** Flat
magenta background, no text (unless stated), no characters, saved to `art/ui/sheets/`.

| Priority | Sheet | File | Unlocks |
|---|---|---|---|
| 1 | A: panel / button / pill kit | `eggshop_frame.png` | HUD, menu, shop, all panels, deck |
| 2 | E1-E4: HUD buttons, currency, quest panel, deck cards | `hud_*.png` | the in-game HUD |
| 3 | D1-D4: menu background (**no character**), logo, buttons, pills | `menu_*.png`, `logo.png` | the main menu |
| 4 | B: egg tiles by tier | `eggshop_tiles.png` | Egg Shop, inventory |
| 5 | Merchant kit + icon sheet | `merchant_kit.png`, `icons.png` | merchant and every panel |
| 6 | H1-H2: battle action cards, top HUD | `battle_*.png` | battle screen |
| 7 | G1-G2: result banners, result pieces | `result_*.png` | Victory / Defeat |
| 8 | F1: inventory/deck extras | `inv_extras.png` | deck, families, inventory |
| 9 | C: crystal eggs (only if Option 2 below) | `eggs_crystal_*.png` | Egg Shop eggs |
| 10 | Lobby concept (optional) | `lobby_concept.png` | the lobby layout |
| any | 5 original character images | `Downloads\New folder` | cards (`NEW_5_CHARACTERS.md`) |

⚠️ `08`/`09` (main menu) contain a copyrighted character and `11`, `14`, `15`, `hd-03`, `hd-04`
contain copyrighted card art. Use them only as style references in your image tool; they are never
uploaded or cut.

**Decisions:**
- **Egg art:** Option 1, keep the Egg Icon Pack eggs inside the new glowing tier tiles (what ships
  now), or Option 2, new crystal eggs from Sheet C that match the target exactly.
- **GitHub history scrub** of `fighter_01..05` (commit `9969dc6`): Claude will show the exact
  commands and affected commits and waits for your **"go"**.
- **Every new image** (your sheets, the sliced pieces of `04-merchant-target.png`, the chosen icons)
  is shown to you on a contact sheet in `docs/review/` first, and nothing is uploaded until you OK it.

**Review sheets waiting for your OK** (nothing is used or uploaded before it):
- `docs/review/ui-kit-v3.png` (8 pieces cut from your merchant target; notes in `ui-kit-v3.md`)
- `docs/review/icons_final.png` (39 icons from your two licensed packs; notes in `icons_final.md`)

**Icon packs:**
- `Downloads\Free` (20 PNGs) has **no licence file**, so it isn't used. Add its licence if you want it.
- The repo on GitHub is **public**. The 21 Free Icon Pack PNGs committed earlier in `art/icons/`
  are public there; the pack's licence only forbids reselling and asset packs, but you may prefer
  the repo private. The new packs are kept local only (the Stylized licence forbids redistribution).

**Your desktop still has a folder named "Ultimate Multi-Expre…"**, which looks like the banned
portrait pack (`CLEANUP_PORTRAIT_PACK.md`). The project never reads it; you may want to delete it so
it can't be picked up by mistake.

**The five characters are renamed** (ids and stats unchanged): Zephyr Volt (N), Rook Emberforge
(R), Halvard Frostwarden (SR), Nox Veilstrider (SSR), Solaris Dawnbringer (UR). Their image prompts
are in `NEW_5_CHARACTERS.md` and `art/characters/PROMPTS.md`; say **"new images are in"** when they
are in `Downloads\New folder`.

## 0000. What Claude needs from you (2026-11-09; also `PLAN.md` section 7)
- **GitHub history:** a commit on 2026-11-09 (`9969dc6`) accidentally included the rejected
  `fighter_01..05` images from `art/characters/`. They are untracked now (`a5444cc`) and git-ignored,
  but still in that commit's history on GitHub. Removing them needs a history rewrite and a force
  push: say "scrub the fighter images from GitHub", or do it yourself.
- **Roblox moderation is re-checking your uploads.** Since the ban, the account's recent images (UI
  kit, UI slots, skies, world thumbnails, prop textures) show as "Pending" at Roblox. Most render in
  Studio again; nothing to do in code, but watch your messages on roblox.com.
- **Archive the 43 portrait-pack assets** on create.roblox.com (`CLEANUP_PORTRAIT_PACK.md` §1, the
  full id list). The pack is removed from the project; **Claude uploads nothing until you confirm
  this is done.**
- **5 original replacement card images** in `Downloads\New folder`, following `CLAUDE.md` "Asset
  safety" (no anime girls, nothing suggestive, no existing characters). `fighter_01..05` are rejected.
- **100 levels instead of 15?** The boards show "Lv. 1/100" and evolution at 1 / 50 / 100. The locked
  max level is 15, so the evolution stages map onto 1-15 (`Config/Progression.evolutionStages`).
  Say "switch to 100 levels" to start it: it needs a rebalance of levels, merge costs and stats
  (`sim/balance.py`).
- **Listen to the unreviewed sounds.** Section 9's new slots (confirm, tab, toast, equip, leave,
  matchmaking, battle picks, summon, sparkle) reuse ids from the licensed APM / PSE set because the
  Creator Store search can't filter by creator (`docs/ASSETS.md`). Swap any for a dedicated sound.
- **Optional painted art.** Every kit image now has a finished version; `art/ui/PROMPTS_V2.md` has
  prompts if you want painted upgrades.

## 000. Step 3 (the new GUI): look and tell Claude what to change
- **Screenshots:** `docs/screens/step3/` (main menu, lobby icon HUD, Egg Shop, Inventory, Deck,
  Arena).
- **Character art:** see `ANIME_FOLDER.md` ("Adding character art").
- **Icons:** the HUD now uses your Free Icon Pack (unedited). Say if you want different icons for
  any shortcut.

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

## 5. Listen to the sounds (approve or swap)
Every sound slot now has a licensed id: music from APMOfficial, and effects from ProSoundEffects
plus a few APM stings. They are all listed in `docs/ASSETS.md`. Claude picked them by title,
description and length because it can't hear audio. Play through the game (menu, shop, a hatch, a
battle) and replace any id you don't like in `src/shared/Config/Sounds.luau`.

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
