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

## 2. Current state (as of 2026-11-09)

**Built and verified** (`STATUS.md`, `docs/MISSION_REPORT.md`):
- **Every game system:** economy, eggs and odds, cards, merging, decks, battle engine (identical
  to the Python model), Guardian AI and Trials, matchmaking (logic with mocks), settlement, 10
  world maps, farming, merchants, quests, streaks, telemetry, persistence, receipts and policy
  rules.
- **The MISSION.md visual work:**
  - the four-screen flow (launch loading → menu → playing → leaving), with the return-to-spot fix
  - the clean in-game HUD
  - the UI kit (183 images) and logo
  - the rarity display
  - card frames, the template card, the stats panel with Favorite, card animations and evolution
    stages
  - the egg pack wired in, the Egg Shop, the 5-stage egg opening, silhouettes
  - every other screen, sound slots and motion
- 283 headless tests pass; StyLua, Selene, luau-lsp strict and the Rojo builds are clean.

**Not done:**
- **Card with character art:** the code path exists, but there's no approved art (section 5).
- **Phase 2, the character art pipeline:** built for the portrait pack, which is now banned. It
  needs reworking to the new rules (section 6, step 5).
- **The final continuous pass:** a fresh player at phone and PC sizes, in one run. Studio ran out
  of memory last time.
- **Cleanup of the portrait pack:** `CLEANUP_PORTRAIT_PACK.md` §2 (check every item).
- **`MISSION.md` checkboxes:** they were reset when the file was rewritten on 2026-11-08. Re-tick
  them from `docs/MISSION_REPORT.md` and git history; don't redo finished work.

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

1. **Safety rules in `CLAUDE.md`.** Confirm the "Asset safety" section is there (added on
   2026-11-09) and commit it, if it isn't yet.
2. **Cleanup** (`CLEANUP_PORTRAIT_PACK.md` §2):
   - delete the pack, the processed folders, id files and screenshots
   - remove every code and config reference
   - battle reactions become effects only
   - scrub it from git history
   - mark the 43 ids "REMOVED" in `docs/ASSETS.md`

   Ask the owner to confirm they archived the 43 assets on create.roblox.com. **No uploads
   before that confirmation.**
3. **Re-tick `MISSION.md`** from `docs/MISSION_REPORT.md` and git history. Remove the portrait
   pack from its open items.
4. **5-card mode code** (section 5), with tests and the sims. It works with the template card
   while there's no art.
5. **Rework phase 2** (`MISSION.md` §12) to the new rules:
   - no `split` of third-party face sheets
   - no expressions
   - add the review gate and contact sheet steps
   - document the commands in `ANIME_FOLDER.md` (rewrite it as "Adding character art")
6. **When the owner's replacement images arrive:** run section 5's steps 1-5, then check "Card
   with character" in Play on every card size and in the egg reveal, and tick it in `MISSION.md`.
7. **The final continuous pass** (`MISSION.md` §15), at phone (1334×750) and PC (1920×1080) in
   one session:
   - launch → loading → menu → PLAY → lobby
   - shop → x1 and x8 → inventory → favourite → upgrade → deck
   - World 1 → Trial → back to the same spot
   - arena queue → cancel
   - Menu → leaving → menu → PLAY → lobby

   **Low-memory tips:** close other apps, use `build/step5.rbxlx` only, stop the image server
   when not uploading, and screenshot as you go.
8. **Update the reports and this file:**
   - `docs/MISSION_REPORT.md`, `STATUS.md`, `HANDOFF.md`, `docs/WAITING_ON_YOU.md`
   - sections 2 and 6 here
   - commit

## 7. Waiting on the owner
- **The 5 original replacement card images** in `Downloads\New folder`, following rules 1-3.
- **Confirm the 43 portrait-pack assets are archived** on create.roblox.com.
- **Approve each art batch** from its contact sheet.
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
