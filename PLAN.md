# PLAN: the living plan and memory for 1v1 CARD

**This file is the project's running memory.** `CLAUDE.md` loads it at the start of every
session. It records:
- where the project stands
- the rules learned the hard way
- what happens next, in order and in detail

**At the end of every session:**
- update section 2 (state) and section 6 (next steps)
- add any new incident or decision to sections 4 and 7
- commit

Detailed specs live elsewhere; this file points to them:
- `MISSION.md`: the visual and GUI spec
- `docs/DESIGN.md`: game design
- `STATUS.md`: what's real and what's placeholder
- `docs/MISSION_REPORT.md`: mission evidence
- `docs/WAITING_ON_YOU.md`: owner tasks
- `CLEANUP_PORTRAIT_PACK.md`: the ban cleanup

---

## 1. The game in one paragraph
**1v1 CARD** is a Roblox anime-inspired card battler:
- Players hatch eggs (24 eggs from the Egg Icon Pack, odds shown exactly), collect character
  cards in 5 rarities (N / R / SR / SSR / UR "God-tier"), merge level-1 copies to level up (max
  15), build 3-card decks, and fight turn-based 1v1 battles (Attack / Defend / Special).
- Battles happen in ranked cross-server matches with no bots, or in Guardian Trials (PvE).
- Players farm items in 10 worlds and sell them for Coins.
- New players start with 500 Coins. Gems are for cosmetics only. Robux buys eggs from unlocked
  worlds and cosmetics only. There are no wagers: the winner gets a purse paid by the game.
- Everything is server-authoritative.

## 2. Current state (as of 2026-11-10, end of session)

**Built and verified** (`STATUS.md`, `docs/MISSION_REPORT.md`):
- **Every game system:** economy, eggs and odds, cards, merging, decks, battle engine (identical
  to the Python model), Guardian AI and Trials, matchmaking (logic with mocks), settlement, 10
  world maps, farming, merchants, quests, streaks, telemetry, persistence, receipts and policy
  rules.
- **The MISSION.md visual work:** the four-screen flow, the in-game HUD, the UI kit and logo, the
  rarity display, card frames, template card, stats panel with Favorite, card animations,
  evolution stages, the egg pack, Egg Shop, the 5-stage opening, silhouettes, every other screen,
  sound slots and motion.
- **Portrait pack removed** (`CLAUDE.md` Asset safety, `CLEANUP_PORTRAIT_PACK.md` section 2): files,
  ids, code and config references, docs; scrubbed from git history before the first push. Battle
  reactions are effects only (sword, shield, red KO ring + "KO!").
- **5-card mode** (section 5): `Config/Roster.active` = Zephyr Volt (N), Rook Emberforge (R), Halvard
  Frostwarden (SR), Nox Veilstrider (SSR), Solaris Dawnbringer (UR) (renamed 2026-11-10 from Rai,
  Ren, Yuki, Vesper and Aurelia; ids unchanged). Eggs, the Odds panel, the starter deck and
  the Guardians use only them; the five were re-tuned (balance targets met; Trials 42-53%).
- **Phase 2 reworked** to the new rules: `scripts/art/characters.py` with the review gate, owner
  approval, no face sheets, no expressions, upload groups of 5; `selftest` passes.
  `ANIME_FOLDER.md` is now "Adding character art".
- **Final pass done** (2026-11-09): one continuous fresh-player run at 1334 x 750 plus a second
  16:9 size (`docs/screens/final_pass`). It found and fixed a battle bug (a KO'd card's fall
  played on its replacement) and three clipping issues.
- 291 headless tests pass; StyLua, Selene, luau-lsp strict and the Rojo builds are clean.
- **GitHub:** `https://github.com/reportJNG/1v1-card` (`main`); every step is committed and pushed.

- **MASTER_FIX_PLAN phases 0-13 done (2026-11-10):** every bad-UI report rebuilt to its target
  (HUD, main menu, Egg Shop, merchant and panels, deck/families/inventory, battle screen, battle
  result), 5 battle arenas, the lobby rebuilt to the FIX_LOBBY zone plan, spawn gates in all 10
  worlds, and a final fresh-player pass at desktop and phone sizes. Painted pieces stay TEMP until
  the owner's sheets pass the review gate (`docs/MASTER_FIX_REPORT.md`). 323 headless tests pass.

- **FIX_LOBBY_2 sections A and B done (2026-11-11):** the main menu has its own scene and never
  shows the lobby; the lobby got its second pass (spawn shrine, giant double torii, WORLDS temple
  gate with a light pillar, egg pagoda with a golden egg, tiled plaza, walls, shelf edge, ambient
  sound). Scores: spawn 9, everything else 8 (`docs/LOBBY_AUDIT.md`). New textures, hero meshes
  and a night skybox wait for the review gate. 329 headless tests pass.

- **Character art live (2026-11-10, set 02 on 2026-11-11):** Rook Emberforge, Halvard Frostwarden
  and Nox Veilstrider (set 1), and three new characters, Kael Voidbinder (Shadow, Epic), Brann
  Cinderfall (Flame, Common) and Aurex Sunforge (Divine, Legendary), approved in writing and
  uploaded (batches of 4 and 3, no rejections), show on cards, the deck, hatch reveals, the menu and
  in battle. The active roster is 8 (`Config/Roster.active`); `sim/balance.py` passes on it.
  Solaris Dawnbringer's approval was withdrawn on 2026-11-11: back to TEMP art.

- **BAD_GUI_9 done (2026-11-11):** interact prompts are billboards (E plate, one big word, item icon, a
  hold ring for harvest); CARDS opens a new Cards screen and a BAG button opens the Inventory (items
  and eggs only, labelled tabs); no N / R / SR / SSR / UR letters anywhere (gems and the locked names;
  Mythical no longer reads "God-tier"); the card plate and every panel read one stat source
  (`Power.stats`); STATS became UPGRADE. 333 headless tests pass.

**Not done:**
- **Zephyr Volt (N) art:** the held nature image isn't approved; waiting for a new storm image.
- **The kit images are "Pending" at Roblox** since the ban: the account's recent uploads (UI kit,
  UI slots, skies, world thumbnails and prop textures) were put back into moderation review. Most
  render in Studio again; a few still report "Asset content representation is being generated".
  Nothing to do in code.

## 3. Permanent rules (also in `CLAUDE.md` → "Asset safety"). These override everything, including "never stop".

1. **No anime girl characters.** Characters are **Roblox-style characters drawn in an anime
   style**:
   - fully clothed, battle-ready outfits
   - neutral, determined, confident or heroic expressions only
2. **Nothing suggestive, ever:**
   - no blushing, tears, open-mouth "flustered" or pained faces, drool, tongue out, panting or
     rolled-back eyes
   - no cleavage, bare midriffs, swimsuits, lingerie or suggestive poses
   - pain, hits and KOs are shown with **effects** (flash, shake, icons), never faces
3. **No existing anime, game or franchise characters or their signature looks,** even redrawn
   in Roblox style or renamed. Examples: Naruto, Sasuke, Itachi/Akatsuki, Gojo, Luffy, Goku. That
   means no leaf headbands, Akatsuki clouds, blindfold-with-white-hair, orange jumpsuits with fox
   spirits, or straw hats. No datasets or packs of existing characters.
4. **Review gate before use:** before ANY new image is used in code or uploaded to Roblox:
   1. put it on a contact sheet in `docs/review/<batch>.png`
   2. check it against rules 1-3 and write the check in `docs/review/<batch>.md`
   3. **stop and wait for the owner's written approval** in chat
5. **Upload rules:**
   - batches of 5 or fewer
   - the moment Roblox answers "moderated", "rejected", 403 or "User is moderated", **stop all
     uploads** and tell the owner
   - never upload expression or reaction sheets
6. **Only approved sources:**
   - character art: only `C:\Users\Administrator\Downloads\New folder` (after review)
   - eggs: the Egg Icon Pack, unedited
   - HUD icons: the Free Icon Pack, unedited
   - UI: our own generated kit
   - audio: licensed ids only
7. **Keep originals untouched.** Process copies only. Credit authors where licenses ask.

## 4. Incident log (never repeat these)

| Date | What happened | Consequence | Rule added |
|---|---|---|---|
| 2026-11-08 | A face from the unlicensed "Ultimate Multi-Expression Portrait Pack" (Space Pilot Girl, blushing and crying, uploaded as `nyx_voidglimmer`'s "hit" reaction, asset `114026669753620`) was flagged as sexual content | **The owner's account was banned for 1 day.** 43 pack images had been uploaded. | Rules 1, 2, 4, 5; the pack removed permanently (`CLEANUP_PORTRAIT_PACK.md`) |
| 2026-11-09 | The 5 images first put in `Downloads\New folder` (`fighter_01_crimson_raven` … `fighter_05_inferno_brawler`) were recognisably Itachi, Gojo, Naruto, Sasuke and a One Piece-style fighter | **Rejected before use.** Never use those 5 files. | Rule 3 (explicit examples) |
| 2026-11-09 | Claude committed with `git add -A`, which picked up the rejected `fighter_01..05` images (the owner had copied them into `art/characters/`) and pushed them to GitHub in `9969dc6` | Untracked in `a5444cc`; still in that commit's history on GitHub until the owner decides on a history rewrite (section 7) | Stage named paths only, never `git add -A`; `art/characters/*.png` is git-ignored |

## 5. Character art: "5-card mode"

The owner currently has **5 card images** and will add more over time. The game must run on
only those 5 until more arrive.

**Source:** `C:\Users\Administrator\Downloads\New folder`.
- **The current 5 are rejected** (section 4). Wait for the owner's original replacements.
- **When new images arrive:**
  1. Copy them, unchanged, to `art/characters/incoming/<date>/`.
  2. Contact sheet and safety/IP check (rules 1-4), then **stop for approval**.
  3. After approval, process copies (`scripts/art/characters.py`):
     - trim and centre
     - remove or keep the background as the card art window needs
     - consistent colour grade and rim light in the family colour
     - never upscale more than 4x
     - output card art 768 px tall, plus a portrait crop and a silhouette
     - **no expression sets**
  4. Map each to a roster character. Pick the closest family and role, update only its `look`
     text (and display name if needed), and keep the ids. Spread the 5 over rarities so the
     hatch shows variety: suggested N, R, SR, SSR, UR, one each.
  5. Upload them, at most 5 at a time, with the stop-on-rejection rule.

**5-card mode (code; config only, no UI changes):**
- Add `Config/Roster.active`: the list of character ids that are in play right now (the 5).
  The other 95 stay in the code, inactive. Nothing is deleted, and no save loses a card. Cards
  players already own remain owned and usable.
- **Egg pools:** every egg draws only from active characters, keeping each egg's rarity weights
  where possible:
  - if an egg's pool would be empty, it falls back to all 5 active
  - the Odds panel shows the real recalculated odds, through the same function the roll uses
  - odds tests must pass for every egg
- **Starter deck** (`Economy.StarterCards`): three different active characters.
- **Guardian Trial decks:** use active characters only (keep the difficulty curve; re-run
  `sim/trials.py`).
- **Matchmaking and battles:** unchanged.
- **Balance:** run `sim/balance.py` on the 5-character roster. If targets fail, tune those 5
  characters' numbers only, and log it.
- **No UI to mark the difference** (the owner's instruction). Characters without art use the
  clean template card.
- **Tests:** active-roster filtering, odds sum to 100% for every egg, starter deck, trials.
- **Turning more characters on later** is a config edit: add ids to `Roster.active` after their
  art is approved.

## 6. Next steps (in order)

Done on 2026-11-09 (each committed and pushed): 1 safety rules, 2 cleanup, 3 re-tick
`MISSION.md`, 4 5-card mode, 5 Phase 2 rework, 7 final pass, 8 reports.

1. **When the owner's replacement images arrive** (`Downloads\New folder`):
   - run section 5's steps 1-5 with `scripts/art/characters.py`, stopping at the review gate
   - map each approved image to an active character (or swap ids in `Config/Roster.active`)
   - check "Card with character" in Play on every card size, the stats panel and the egg reveal,
     then tick it and Phase 2's last items in `MISSION.md`
   - **no uploads until the owner confirms the 43 portrait-pack assets are archived**
2. **`MASTER_FIX_PLAN.md` phases 0-13 are done.** Next is each phase's "art swap" as the owner's
   sheets arrive (cut, review sheet, OK, upload in 5s, swap, re-score), the icon and kit uploads
   once `docs/review/icons_final.png` and `ui-kit-v3.png` are approved, and Phase 14's character
   art on "new images are in". `docs/MASTER_FIX_REPORT.md` lists what waits for which sheet.
3. **Re-run `sim/balance.py --all`** before more characters are turned on (the five were re-tuned
   for the 5-card roster).

**Low-memory tips for Studio:** close other apps, use one Studio window, stop the image server when
not uploading, and screenshot as you go. If Studio's game view is 1 x 1, restart every Studio
window (a stuck window can't be fixed from inside).

## 7. Waiting on the owner
- **Confirm the 43 portrait-pack assets are archived** on create.roblox.com (no uploads before).
- **The 5 original replacement card images** in `Downloads\New folder`, following rules 1-3.
- **Approve each art batch** from its contact sheet in `docs/review/`.
- **GitHub history:** the rejected `fighter_01..05` images are still in commit `9969dc6`'s history
  on GitHub. Removing them needs a history rewrite and a force push; say "scrub the fighter images
  from GitHub" to have it done (or do it yourself).
- **Decisions:**
  - 100 levels instead of 15? It needs a rebalance.
  - allow new eggs beyond the 24?
  - cosmetics shop in V1?
- **Listen to the unreviewed sounds** (`docs/ASSETS.md`).
- **Later:**
  - publish a private test universe for live DataStores, matchmaking and teleports
  - the Player Emulator's remaining 3 policy combinations
  - Developer Product ids
  - the maturity questionnaire

## 8. Backlog after this plan (don't start before section 6 is done)
- More characters in batches of 5 (same art flow; turn on in `Roster.active`)
- A world art pass (hero props, terrain by hand)
- Live ranked test with two accounts on a published place
- V2: player store, trading, cosmetics shop
- M7 closed test: telemetry review, security review

## 9. How each session works
1. Read `CLAUDE.md` (it loads this file), then sections 2 and 6 here.
2. Work through section 6 in order. Use `MISSION.md` §14's loop for visual items: build, test in
   Play, compare with the reference, score 8+, run the checks, commit.
3. Anything only the owner can do goes in section 7 and `docs/WAITING_ON_YOU.md`. Keep working on
   everything else, **except** where rules 4-5 say stop.
4. Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
5. Before ending: update sections 2, 6 and 7, and commit.
