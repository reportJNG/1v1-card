# MASTER FIX PLAN: every bad-UI report plus the lobby, start to finish

**Written:** 2026-11-09, for the Claude Code CLI working in `C:\Users\Administrator\work\1v1card`.

This is the **one plan that runs everything** the owner reported as bad, in order. Each phase
points to its detailed report. That report is the spec; this file sets the order, how work
moves from one phase to the next, and what "done" means.

**Read first, every session:**
1. `CLAUDE.md`, which loads `PLAN.md` and `UI_TARGETS.md`
2. this file
3. `docs/MASTER_FIX_REPORT.md`, the progress log you keep (Phase 0 creates it)

---

## 0. Ground rules for this whole plan

1. **Safety rules come first.** `CLAUDE.md` "Asset safety" and `PLAN.md` §3 override everything
   in this plan, including any "don't stop" in a `/goal`:
   - no anime girls, nothing suggestive, no existing franchise characters or their signature
     looks
   - **every new image** goes on a contact sheet in `docs/review/`, then **wait for the owner's
     written OK** before it is used in code or uploaded
   - uploads go in batches of 5 or fewer; at the first "moderated", "rejected" or 403, stop
     **all** uploads and tell the owner
   - images marked REFERENCE-ONLY in `docs/brief/` (they contain Gojo, Goku and other
     copyrighted characters) are **never** cut, traced, uploaded or used as source
2. **Roblox UI, not web UI** (`UI_TARGETS.md`, `BAD_GUI_THINKING_AND_UI.md`):
   - painted image pieces (9-slice `ImageLabel`s), big outlined text, icons first
   - text sits on top of objects in the world (BillboardGui), not in toast bars
   - a clean screen
   - **no** code-drawn rounded boxes posing as a final look
3. **Never block on owner art.** When a phase needs owner sheets that haven't arrived:
   1. build the **new layout and behaviour now** with the current kit images marked `TEMP`
   2. put the prompt in `art/ui/PROMPTS_V3.md` and `docs/WAITING_ON_YOU.md`
   3. log it under "Waiting for art" in `docs/MASTER_FIX_REPORT.md`
   4. **move on** to the next phase

   When the sheets arrive, come back and do that phase's "art swap" step.
4. **Server-authoritative stays.** UI changes never move logic to the client. Any new remote goes
   through `Server/Net/Dispatcher` with validation and rate limits.
5. **Git:**
   - stage **named paths only**, never `git add -A`
   - one commit per finished step, pushed to `main` as before
   - message format `ui(<phase>): …` / `map(lobby): …`, ending with
     `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
6. **Checks on every commit:** headless TestEZ (291+, 0 failed), StyLua, Selene, luau-lsp strict,
   and the Rojo builds (default, dev, e2e), all clean.
7. **How every screen is judged (`UI_TARGETS.md`):**
   1. take Play screenshots at 1334 × 750 and at a phone size
   2. make a side-by-side image `docs/screens/<area>/compare_<screen>.png` with the target
   3. score it 1-10 on layout, art, text, clarity and motion
   4. **8+ on each, or fix and score again**

   Write the scores in the report.
8. **No publishing, no Robux spending, no irreversible external actions.** No secrets in files or
   logs.

---

## Phase 0: Prepare (no art needed)
1. Read every report:
   - `BAD_GUI_THINKING_AND_UI.md`
   - `BAD_GUI_2_PANELS.md` … `BAD_GUI_8_BATTLE_SCREEN.md`
   - `FIX_LOBBY.md`
   - `UI_TARGETS.md`
   - the images in `docs/brief/bad-gui/`
2. **Restore `README.md`**, which is 2 bytes now: get its content from git history (`git log -p --
   README.md`) and update it lightly.
3. Create `docs/MASTER_FIX_REPORT.md` with these sections:
   - a phase table (status, commits, scores)
   - Waiting for art
   - Owner decisions
   - Incidents
4. **Before screenshots** of every screen in this plan, in `docs/screens/before/`:
   - main menu
   - HUD
   - Egg Shop
   - merchant and other panels
   - deck, inventory and families
   - battle
   - result (Victory and Defeat)
   - lobby from 6 angles
5. **Write all owner prompts in one place:** `art/ui/PROMPTS_V3.md`, covering sheets A, B, C, D1-D4,
   E1-E4, F1, G1-G2, H1-H2, the merchant kit and icon sheet from `BAD_GUI_2`, and the optional
   lobby concept from `FIX_LOBBY`. Put the same list, ordered by priority (section "Owner art
   list" below), at the **top** of `docs/WAITING_ON_YOU.md`.
6. Link this plan:
   - in `PLAN.md` §6, replace step 2 with "Run `MASTER_FIX_PLAN.md` phases 0-12"
   - in `CLAUDE.md` "Start here", add `MASTER_FIX_PLAN.md`
7. Commit.

## Phase 1: Fix the bugs found in the reports (no art needed)
- **"Sell all" button invisible** on the merchant (`BAD_GUI_2`).
- **Oak Log shows a crystal icon** (`BAD_GUI_2`): check every item's icon mapping in config, and
  add a validator test that every item has its own correct icon.
- **1v1 return bug:** after every battle (ranked and Trial) the player goes back to the exact spot
  they left (the 4-screen flow in `MISSION.md`). Add a test or Play check for both.
- Any other bug noted in a `BAD_GUI_*` "now" section.
- Commit each fix with a test where possible.

## Phase 2: Stop web thinking everywhere → `BAD_GUI_THINKING_AND_UI.md`
- **Remove the toast bars** ("+2 Oak Log" style).
- **Add `App/WorldText`:** BillboardGui pops on top of the object, with big outlined text, an icon
  and a short rise-and-fade.
- **Billboard standards** from §4 of that report.
- **Run the §5 sweep** over all of `src/client`, and fix or list every web-style element.
- Add the §7 rules to `CLAUDE.md` under "UI rules".
- Check in Play: harvest, sell, quest progress and rewards each show world text, with no toast
  bars anywhere.
- Commit.

## Phase 3: The image-kit pipeline (built once, used by every screen) → `BAD_GUI_3_EGG_SHOP.md` §3
- **`scripts/art/cut_sheet.py`:**
  - turns magenta or near-white backgrounds transparent, with de-fringing
  - finds the components, trims them, and saves `art/ui/kit-v3/<sheet>_<n>.png`
  - makes a numbered contact sheet `docs/review/<sheet>_cut.png`
  - test it on a synthetic sheet
- **`art/ui/kit-v3/kit.json`:** piece → file, size, 9-slice margins, asset id, tint, and status
  (`TEMP` / `REVIEW` / `APPROVED` / `LIVE`).
- **The 9-slice test renderer:** `docs/review/<sheet>_slice_test.png`, stretched to 3 sizes.
- **`App/Ui/Kit`:**
  - the only place screens get images from, by piece name; screens never hard-code images
  - falls back to the current TEMP image when a piece isn't live
- **Slice the clean pieces** from the owner's own target image `04-merchant-target.png`
  (`BAD_GUI_2` §3.1): frame corners and edges, stripes, the coin pile, sparkles, the crown, card
  frames, the close button. **Review gate before any upload.**
- Commit.

## Phase 4: In-game HUD → `BAD_GUI_5_INGAME_HUD.md` (replaces `MISSION.md` §3)
**Now:**
- On the left, **only 4 big buttons in a 2 × 2 grid:** CARDS, EGGS, WORLDS, 1v1.
- **≡ menu** for everything else.
- **Gift button** shown only when something is claimable.
- **Currency pills** at the top right.
- **Quest/tutorial panel** on the right.
- **Deck bar** at the bottom centre.
- Remove everything else from the screen.
- TEMP images until E1-E4 arrive.

**Art swap:** E1-E4 → cut → review → OK → upload (5 or fewer) → swap → compare 8+.

## Phase 5: Main menu → `BAD_GUI_4_MAIN_MENU.md`
**Now:**
- Only the logo, **PLAY**, **SHOP** and the currency pills.
- The **player's own avatar** in a ViewportFrame as the hero, with an idle animation.
- PLAY always goes to the lobby.

**Art swap:**
- D1 background (must have **no character**; check it at review), split into 2 × 2 tiles of
  1024 px.
- D2 logo, D3 buttons, D4 pills.

**Later option** (see `FIX_LOBBY` §4.9): a cinematic camera over the real upgraded lobby instead
of D1.

## Phase 6: Egg Shop → `BAD_GUI_3_EGG_SHOP.md` §5
**Now:**
- A **4 × 2 grid of tier tiles** with paging, each with a price pill in the bottom edge.
- A **featured panel** on the right: the big egg, odds button, x1 / x3 / x8 buy buttons (grey
  when the player can't afford them).
- Remove the placeholders. Add the free-egg gift button.
- Robux button only when policy allows it.
- Eggs = the **Egg Icon Pack, unedited**, until the owner decides on Option 2 (§4.1; log it in
  Owner decisions).

**Art swap:** Sheets A, B, then C if Option 2.

## Phase 7: Merchant and all other panels → `BAD_GUI_2_PANELS.md`
**Now:**
- Rebuild the **merchant exactly like `04-merchant-target.png`**: sliced pieces plus TEMP renders.
- That panel becomes the template; apply it to **every other panel** (§5 list):
  - settings
  - quests
  - worlds picker
  - arena queue
  - odds
  - confirmations

**Art swap:** the merchant kit and icon sheet prompts from §3.2.

## Phase 8: Deck Builder, Families, Inventory → `BAD_GUI_6_DECK_AND_INVENTORY.md`
**Now:**
- Rebuild the layouts to match the targets: Sheet A panels and tabs, Sheet B tier tiles, E4 card
  frames.
- Images 14 and 15 are **layout-only** (copyrighted cards): never cut or upload them.

**Art swap:** F1.

## Phase 9: Battle screen and 5 arenas → `BAD_GUI_8_BATTLE_SCREEN.md`
**UI, now:**
- **Top HP bars** for both fighters, with a **hex timer medallion** in the middle.
- **3 tall action cards** (Attack / Defend / Special) at the bottom.
- The §4 animations, respecting `reducedMotion` and the server's timing (12 s picks); the client
  only animates server events.

**Arenas, now:**
- `Config/Arenas` and `ServerStorage/Arenas/<Map>`, sharing one `ArenaCore` (platform, pads,
  camera and spawn points), with map props in a `Dressing` folder.
- **5 maps:** Sakura Courtyard (an upgrade of the current one), Frozen Shrine, Volcano Forge,
  Celestial Isle, Storm Rooftop.
- **Picked by the server from the match seed,** so both players see the same map; announced in
  the intro.
- Each map has its own lighting preset, sky, particles and music; the area's preset comes back
  after the battle.
- Build with Blender MCP hero props, `generate_scene`, `generate_mesh` and `generate_material`,
  and Creator Store models with **every script removed** and logged in `docs/ASSETS.md`.
- Performance budget from §5.
- **Tests:** map choice is deterministic for a seed, every map has the core parts, config
  validation.
- **Screenshots:** `docs/screens/arenas/<map>.png`, the intro and mid-fight.

**Art swap:** H1, H2.

## Phase 10: Battle result → `BAD_GUI_7_BATTLE_RESULT.md`
**Now:**
- Show **both fighters**: the player's and the opponent's.
- Painted **VICTORY / DEFEAT**.
- A rewards row: trophies, purse, XP, quest progress.
- Clear buttons: Rematch-queue / Back.
- **Remove the battle log.**
- After closing, the player returns to the spot they left (Phase 1).

**Art swap:** G1, G2.

## Phase 11: Lobby map, full upgrade → `FIX_LOBBY.md`
- **Before:** screenshots from 6 angles and `docs/LOBBY_AUDIT.md`.
- **Optional:** the owner's top-down concept, through the review gate.
- **Build the zone layout:**
  - spawn facing the landmarks
  - central plaza with a fountain and the golden-card statue
  - **1v1 ARENA** torii (north)
  - **WORLDS** portal (east)
  - egg pavilion (west)
  - merchant, quest board, daily shrine, optional leaderboard
  - edges: river, bridge, cherry grove, pagodas
- **Props:**
  - hero props from Blender
  - secondary props: generated, or curated with scripts removed
  - MaterialVariants
  - set dressing
- **Atmosphere:**
  - lighting preset "hub" (night, moonlit, lantern light pools)
  - a proper night sky
  - life: petals, fireflies, water, portal effects, ambient sound
- **World text** on every place (Phase 2 standards). Each place opens its panel.
- **Performance:**
  - StreamingEnabled
  - about 6,000 parts at most
  - 40 or fewer PointLights
  - numbers logged
- **Done when:** after screenshots plus a comparison scoring **8+** on each of the 6 points.

## Phase 12: Worlds 1-10 upgrade → `FIX_LOBBY.md` §7
Do this only after Phase 11 is done. Same method, World 1 (Green Plains) first:
- 2 hero props
- a terrain pass by theme
- MaterialVariants
- a proper sky, lighting and particles
- a landmark at the spawn
- readable resource nodes

One world per commit, with before and after screenshots and a score.

## Phase 13: Final pass
- One continuous **fresh-player run** at 1334 × 750 and at phone size, covering:
  - launch loading → main menu → lobby → HUD
  - Egg Shop: hatch x1 and x8
  - deck
  - merchant: harvest and sell
  - a world
  - a Trial battle (one of the 5 arenas) → result → back to the spot
  - quests and gift
- Save it to `docs/screens/final_master/`. Fix everything found.
- Full checks.
- Update `PLAN.md` §2/§6/§7, `STATUS.md` (move the UI and hub from Placeholder to done, or TEMP
  where art is still waiting) and `docs/MASTER_FIX_REPORT.md`.
- Commit and push.

---

## Owner art list (what only the owner can make, by priority)
Generate each on a **flat magenta (#FF00FF) background**, with **no text** (except G1, where
the words are baked in), pieces spaced apart, in the style of the target image named in each
report. Save to `art/ui/sheets/`.

| Priority | Sheet | File | For phase | Report |
|---|---|---|---|---|
| 1 | **A:** panel / button / pill kit | `eggshop_frame.png` | 4-8 | BAD_GUI_3 §4 |
| 2 | **E1-E4:** HUD buttons, currency, quest panel, deck cards | `hud_*.png` | 4 | BAD_GUI_5 §3 |
| 3 | **D1-D4:** menu background (no characters), logo, buttons, pills | `menu_*.png`, `logo.png` | 5 | BAD_GUI_4 §3 |
| 4 | **B:** egg tiles by tier | `eggshop_tiles.png` | 6, 8 | BAD_GUI_3 §4 |
| 5 | **Merchant kit + icon sheet** | `merchant_kit.png`, `icons.png` | 7 | BAD_GUI_2 §3 |
| 6 | **H1-H2:** battle action cards, top HUD | `battle_*.png` | 9 | BAD_GUI_8 §6 |
| 7 | **G1-G2:** result banners, result pieces | `result_*.png` | 10 | BAD_GUI_7 §4 |
| 8 | **F1:** inventory/deck extras | `inv_extras.png` | 8 | BAD_GUI_6 §4 |
| 9 | **C:** crystal eggs (only if Option 2) | `eggshop_eggs.png` | 6 | BAD_GUI_3 §4.1 |
| 10 | Lobby concept (optional) | `lobby_concept.png` | 11 | FIX_LOBBY §2 |
| any time | **5 original character images** | `Downloads\New folder` | — | `ANIME_FOLDER.md` |

**When a sheet arrives:**
1. `cut_sheet.py`
2. name the pieces in `kit.json`
3. slice test
4. contact sheet in `docs/review/`
5. **stop for the owner's OK**
6. upload (5 or fewer, stop on rejection)
7. set the status to `LIVE`
8. compare and score 8+
9. commit

## Also waiting on the owner (from `PLAN.md` §7; don't block on these)
- Confirm the 43 portrait-pack assets are archived. **No uploads of any kind before this.**
- The egg art decision (pack eggs, or Sheet C crystal eggs).
- Whether to scrub the rejected fighter images from GitHub history.

---

## Done means
- Phases 0-13 are each marked done or "done, waiting for art" in `docs/MASTER_FIX_REPORT.md`,
  with commits and scores.
- Every screen in `UI_TARGETS.md` scores 8+ against its target, or is listed as waiting only for
  named owner sheets, with its layout and behaviour already final.
- The lobby and the 5 arenas score 8+.
- No toast bars. No code-drawn boxes as a final look. No REFERENCE-ONLY image used.
- Tests and every check are clean; everything is committed and pushed.
