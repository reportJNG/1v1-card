# Using an anime art folder in 1v1 CARD

How a folder of anime-style art gets into the game, what it must contain, and what Claude does with
it. Drop the folder, say "use the anime folder", and Claude does the rest.

---

## 1. The two rules that decide everything

1. **Original characters only.** The game never uses existing anime or franchise characters,
   names or likenesses, even as placeholders. That rules out Gojo, Naruto, Luffy, Itachi, the
   Akatsuki cloak, character datasets scraped from anime, and so on. This is your own rule
   (`CLAUDE.md`, "No copied IP") and Roblox's: copied characters get assets and games taken down.
2. **We must hold the rights.** Every image needs a license that allows commercial use in a
   Roblox game. Art you or an artist you paid made yourself counts; a pack whose license says
   "commercial use allowed" counts. A pack with **no license file** does not, even if its name says
   "free", because nobody can show who made it or what they allowed.

If both are true, the art can go in. If either is unclear, Claude doesn't ship it and lists it in
`docs/WAITING_ON_YOU.md` instead.

## 2. Where to drop it

```
C:\Users\Administrator\work\1v1card\art\anime\<pack name>\
    LICENSE.txt                 the pack's license or your proof of ownership (required)
    <the images, as supplied>
```

Keep the images exactly as supplied. Claude never edits third-party art. It crops or frames it in
the game (layers, masks, frames), and only when the license allows it.

## 3. What the game can use, and how

| Art you have | Where it goes in the game | Requirements |
| --- | --- | --- |
| **One full character per image**, transparent background, upper body to knees | **Card art** for one of our 100 characters (`CharacterDef.assets.cardArt`). It replaces the TEMP silhouette on every card and on the 3D standee in battles | PNG, transparent corners, at most 1024 px, 3:4 (768 × 1024 is ideal). It must fit that character's brief in `art/characters/PROMPTS.md` (role, family colours, weapon) |
| **Backgrounds / scenes** | Family card backgrounds (`card_bg_<family>`), main-menu key art, world picker art | 384 × 216 (picker), 1024 × 576 (menu), 512 × 704 (card backgrounds) |
| **Icons** | HUD and menu shortcuts | 256 px PNG, transparent |

**Mapping art to characters.** Every image needs to land on exactly one of the 100 original
characters (`src/shared/Config/Characters.luau`, ids like `ren_emberfang`). Either:
- name the files `<character id>.png` (for example `ren_emberfang.png`), or
- add `art/anime/<pack>/map.json` as `{ "file name.png": "character_id" }`.

A new character not on the roster can be added too (the roster is capped at 100, so it would replace
one). It needs a name check, a balance pass (`python sim/roster.py tune`) and your OK.

## 4. What Claude does when you drop a folder

1. Reads `LICENSE.txt`. No license means the pack stops here and is listed in WAITING_ON_YOU.
2. Checks every image: PNG, size, transparent corners for card art. That is
   `python scripts/art/characters.py check` for files under `art/characters/<id>/card.png`.
3. Looks at the images to confirm they aren't existing anime or game characters.
4. Copies each card image to `art/characters/<id>/card.png`, uploads it through the Roblox Studio
   MCP, and writes the ids with `python scripts/art/characters.py apply`.
5. Rebuilds, then shows in Play mode: cards in the shop, hatch, inventory, deck and battle
   standees. It saves screenshots to `docs/screens/characters/` and commits.

Nothing else in the game changes. Odds, stats and rarities stay as they are; only the pictures
change.

## 5. Removed: the portrait pack
The "Ultimate Multi-Expression Portrait Pack" was removed permanently on 2026-11-08 after one of its
faces got the owner's account banned (`CLEANUP_PORTRAIT_PACK.md`). Expression sheets are never used.

## 6. The fastest way to real card art
Generate the card art from `art/characters/PROMPTS.md` (one transparent PNG per character, upper
body to knees). Those are original by construction and need no license check. Start with two:
`ren_emberfang` and `yuki_frostveil`, saved as `art/characters/<id>/card.png`.

## 7. The icon pack (used)
`Downloads\Free Icon Pack v3.1 (Basic)` by @gvesster allows commercial use and does not allow
editing the icons for resale. The HUD shortcuts use its icons **unedited** (the 256 px "Outline"
versions), listed in `docs/ASSETS.md`. Its license is copied to `art/icons/License.txt`.
