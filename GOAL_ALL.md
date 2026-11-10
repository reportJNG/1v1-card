# GOAL_ALL: one goal that runs everything

This adds two phases to `MASTER_FIX_PLAN.md`: **icons (Phase 3b)** and **characters (Phase 14)**.
The order is: the master plan's phases 0-3, then 3b, then 4-13, then 14. All rules in
`CLAUDE.md` "Asset safety" and `MASTER_FIX_PLAN.md` §0 apply. Log progress in
`docs/MASTER_FIX_REPORT.md`.

## Phase 3b: The best combined icon set (run after Phase 3, before Phase 4)
**Sources** (the owner's packs; never edit the originals):
1. `C:\Users\Administrator\Downloads\Free Icon Pack v3.1 (Basic)`, already in use
2. `C:\Users\Administrator\Downloads\Stylized_Game_Essentials_147_Icons`
3. `C:\Users\Administrator\Downloads\Free`

**Steps:**
1. **Read each pack's license** (any txt, pdf or readme file).
   - Record the author, whether commercial use is allowed, whether editing is allowed, and any
     credit needed, in `docs/ASSETS.md`.
   - **Use no pack whose license is missing or forbids commercial use.** List it in
     `WAITING_ON_YOU.md` instead.
   - If a license forbids editing, use those icons **unedited**: scaling only.
2. **Copy the packs** unchanged to `art/icons/<pack>/` and copy each license file next to it.
3. **Make one contact sheet per pack:** `docs/review/icons_<pack>.png`, with the file names shown.
4. **Choose the best icon for every slot**, one consistent painted Roblox style per screen. The
   slots:
   - currencies: coin, gem, Robux
   - the HUD 4: cards, eggs, worlds, 1v1/swords
   - ≡ menu items: settings, quests, inventory, shop, daily, gift, trophy, leaderboard
   - battle: attack/sword, defend/shield, special/bolt, heart/HP, timer
   - items: wood/oak log, stone, crystal, ore, and the other farm items, each with **its own
     correct icon** (this fixes the Oak Log bug)
   - UI: lock, check, close, plus, arrow, star, crown, sparkle, info, sell, cart, tag, backpack
5. **Write the choice into `art/icons/icon_map.json`** (slot → pack/file, with a reason) and make
   `docs/review/icons_final.png`, showing each slot with its chosen icon.
6. **STOP:** show `icons_final.png` and wait for the owner's OK.
7. After the OK:
   1. upload in batches of 5 or fewer, and stop on any rejection
   2. add the icons to `App/Ui/Kit` / `Config/UiAssets` by slot name; screens never hard-code ids
   3. add a validator test: every slot and every item has an icon, with no duplicates for
      different items
8. Every later phase uses only icons from `icon_map.json`.

## Phase 14: Characters (`NEW_5_CHARACTERS.md`). Run when the owner says "new images are in"
- **Don't wait for this.** Phases 0-13 continue meanwhile, and cards stay on the template.
- **Rename the 5 active characters**, keeping their ids and stats; change only `displayName` and
  `look`:

  | Rarity | Old name | New name |
  |---|---|---|
  | N | Rai | Zephyr Volt |
  | R | Ren | Rook Emberforge |
  | SR | Yuki | Halvard Frostwarden |
  | SSR | Vesper | Nox Veilstrider |
  | UR | Aurelia | Solaris Dawnbringer |

  Update `art/characters/PROMPTS.md`, the tests and the docs to match. **This rename can be done
  now**, in Phase 0.
- **`fighter_01..05` are rejected forever.** Never use them; the pipeline refuses them by name.
- **When the new images arrive:** `scripts/art/characters.py` runs `ingest`, then `sheet`, then
  **STOP for the owner's OK**, then `approve` → `map` → `process` → `check` → `urls` (5 or fewer,
  stop on rejection) → `apply`.
- Then check the cards in Play: every card size, the stats panel and the egg reveal. Tick "Card
  with character" in `MISSION.md`.
- **If an image looks like an existing anime character, reject it** and tell the owner why.

## Also in Phase 0
- **GitHub scrub** of the `fighter_01..05` images from history, **only after the owner says
  "go"**:
  1. show the commands and the affected commits first
  2. use `git filter-repo` on those 5 paths only
  3. force-push `main`
- **Uploads:** the owner says the 43 portrait-pack assets are archived, so uploads are allowed
  again, but each one still goes through the review gate.

## Done means
Everything in `MASTER_FIX_PLAN.md` "Done means", plus:
- Phase 3b is done and approved.
- The 5 characters are renamed.
- Phase 14 is either done, or waiting only for the owner's images.
