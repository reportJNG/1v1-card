# MASTER FIX REPORT

The progress log for `MASTER_FIX_PLAN.md` (phases 0-13) and `GOAL_ALL.md` (Phase 3b icons,
Phase 14 characters). Updated at every commit. Scores follow `UI_TARGETS.md` (1-10, 8+ on each
point to pass), from Play screenshots and a side-by-side compare image.

**Status words:** `todo` · `in progress` · `done` · `done, waiting for art` (the layout and
behaviour are final; only named owner sheets are missing) · `done, waiting for owner`.

## Phase table

| Phase | What | Status | Commits | Scores |
|---|---|---|---|---|
| 0 | Prepare: README, report, before shots, PROMPTS_V3, links, character rename | done | see git log `ui(0)` | n/a |
| 1 | Bugs from the reports (Sell all, item icons, return-to-spot) | done | `ui(1)` | n/a (bug fixes; screenshots in `docs/screens/phase1`) |
| 2 | Stop web thinking: WorldText, no toast bars, sweep | done | `ui(2)` | big text 8 · icons 8 · on-object 9 · no web boxes 9 (`compare_notifications.png`) |
| 3 | Image-kit pipeline (cut_sheet, kit.json, slice test, App/Ui/Kit) | done, waiting for owner (OK on `docs/review/ui-kit-v3.png`) | `ui(3)` | n/a (pipeline; pieces scored when used) |
| 3b | Combined icon set (three packs, licences, icon_map.json) | done, waiting for owner (OK on `docs/review/icons_final.png`) | `ui(3b)` | n/a (scored with the screens that use them) |
| 4 | In-game HUD | done, waiting for art (E1-E4) | `ui(4)` | clean 9 · buttons 9 · text 8 · painted 7 until E1-E4 (`compare_hud.png`) |
| 5 | Main menu | done, waiting for art (D1-D4) | `ui(5)` | layout 8 · hero 8 · buttons 8 · text 9 · motion 8 · background 7 / logo 7 until D1/D2 (`compare_mainmenu.png`) |
| 6 | Egg Shop | done, waiting for art (Sheets A, B; C if Option 2) | `ui(6)` | grid 9 · featured 8 · text 8 · buttons 8 · painted 7 until A/B (`compare_eggshop.png`) |
| 7 | Merchant + every other panel | done, waiting for art (merchant kit, Sheet A) | `ui(7)` | merchant: layout 9 · text 9 · icons 8 · space 8 · buttons 8 · painted 7; panels: text 8 · icons 8 · no web boxes 8 · painted 7 (`compare_merchant.png`, `compare_panels.png`) |
| 8 | Deck Builder, Families, Inventory | done, waiting for art (Sheets A, B, F1, E4) | `ui(8)` | deck: layout 8 · cards 8 · text 8 · motion 8; inventory: layout 8 · cards 8 · text 8 · inspect 8; painted 7 until the sheets (`compare_deck.png`, `compare_families.png`, `compare_inventory.png`) |
| 9 | Battle screen + 5 arenas | done, waiting for art (H1, H2) | `ui(9)` | bars 9 · timer 8 · action cards 8 · clean 9 · motion 8 · painted 7 until H1/H2 (`compare_battle.png`, `docs/screens/arenas`) |
| 10 | Battle result | todo | | |
| 11 | Lobby full upgrade | todo | | |
| 12 | Worlds 1-10 upgrade | todo | | |
| 13 | Final pass | todo | | |
| 14 | Characters: rename done in Phase 0; art waits for "new images are in" | done, waiting for owner (art) | | |

## Phase notes

### Phase 0 (2026-11-10)
- **Toolchain.** The tools from earlier sessions lived in a temp folder that was cleared. Reinstalled
  the `rokit.toml` versions plus the Luau CLI, Python 3.13 (Pillow, numpy) and the luau-lsp Roblox
  definitions into `C:\Users\Administrator\Tools\1v1card` (persistent, outside the repo).
  `scripts/check.sh` now runs the whole gate in one command (README "Checks"). Baseline before any
  change: StyLua, Selene, luau-lsp clean, 3 Rojo builds, **291 passed, 0 failed**.
- **README.md** restored from history (`72341c9~1`), with the one-command gate, the toolchain note
  and a fuller layout.
- **Before screenshots** in `docs/screens/before/`:
  - lobby from 6 angles (`lobby_1..6`, also `docs/screens/lobby/before_*`), Studio Edit mode,
    hub preset
  - every other screen from the 2026-11-09 final pass, which ran on this exact code: main menu,
    HUD, Egg Shop, odds, inventory, deck, battle, Victory, arena queue, confirm
  - the owner's own "now" captures for the merchant (03), Defeat (17), the toast bar (01) and the
    battle (19)
- **Owner prompts** for every sheet in one file, `art/ui/PROMPTS_V3.md`, and the priority list at
  the top of `docs/WAITING_ON_YOU.md`.
- **Links:** `PLAN.md` §6 step 2 and `CLAUDE.md` "Start here" point at this plan and this report.
- **Characters renamed** (GOAL_ALL Phase 14, "can be done now"): `displayName` and `look` only; ids,
  stats and `Roster.active` unchanged. `sim/roster_looks.py` holds the new briefs (from
  `NEW_5_CHARACTERS.md`), `python sim/roster.py looks` regenerated `Config/Characters` and
  `art/characters/PROMPTS.md`, and the card prompt template is now the owner's shared style. A
  Roster spec pins the five names. The design doc table and `PLAN.md` use the new names; history
  logs keep the old ones.

### Phase 1 (2026-11-10)
- **"Sell all" invisible.** The gold button image renders fine today (Play and preview); in the
  owner's capture it and the header's shop icon were blank, which is what an image still in
  Roblox moderation looks like. A dark label then floats on nothing. Fix: every `Ui.button`
  waits 4 s for its painted image and, if it still hasn't loaded, draws a solid body in its style
  colour (`STYLE.fill`), so a button can never be a bare label. Checked in Studio by forcing the
  image to fail: `docs/screens/phase1/sell_all_image_fallback.jpg`.
- **Oak Log showed a crystal.** Every merchant tile used `icon_energy`. Items now carry an `icon`
  slot (one per item, filled with the approved pack icon in Phase 3b); until it is live,
  `App/ItemIcon` shows the item's own resource-node mesh (`Domain/ItemArt`), so the Oak Log shows
  the oak-log pile. The inventory's item tiles were text-only; they are icon-first now. The
  validator refuses an item without its own icon slot or its own node model, and counts TEMP item
  icons as a launch gap; two specs pin it (`ConfigValidator.spec` "Item icons").
  `docs/screens/phase1/merchant_item_icons.jpg`.
- **Return to the spot after every battle.** Found a real gap: BattleService ran the end-of-battle
  hooks (SessionService puts the player back on their saved spot and out of "battling") only
  after a *successful* settlement, so a missing profile or a refused settlement left the player in
  the battling state. Now settlement runs inside a `pcall` and `Server/Battle/BattleEnd.leavers`
  sends every human seat back afterwards, ranked or Trial (`Flow.spec` "BattleEnd").
  Play check (Trial, World 1): start → forfeit → the character is back on the same spot (0.00
  studs), session "playing", World 1. Ranked uses the same hooks; a live two-client ranked run
  needs a second player and is left for the Phase 13 pass / a published test place.
- Other "now" items in the BAD_GUI reports are layout problems owned by their phases (4-10).
- Checks: StyLua, Selene, luau-lsp clean; **296 passed, 0 failed**.

### Phase 2 (2026-11-10)
- **The toast bar is gone.** `App/WorldText` shows every message at its source: `pop` over a world
  object, `near` beside a screen element (errors shake), `center` only when there is no source,
  `fly` sends icons to their HUD counter, which bounces. Pops are pooled (`Shared/Ui/PopPool`, at
  most 20 of each kind; a recycled pop's late animation can't touch its new use; 5 specs).
- **Every former toast** is now the right pop (`docs/GUI_AUDIT_ROBLOX.md` §1): harvest "+2" with the
  item icon over the node and items flying to the bag; rare drops "RARE +1" in gold; sales "+N" and
  "THANKS!" over the merchant with coins flying to the Coins bar; errors as 1-3 red words beside the
  pressed button (`Format.errorPop`); "SAVED!", "IN DECK!", "MERGED!", "LEVEL UP!"; quest claims
  and the daily streak fly their rewards to the bars.
- **Moments** (`Shared/Ui/Moments`, 4 specs): quest progress pops "+N" by the quest card, a finished
  quest "QUEST COMPLETE!", a new world "WORLD N UNLOCKED!" then flies to the WORLDS button.
- **World text** (`Shared/Ui/Billboard`, used by the server builders and the client): hub signs,
  world name, merchant name + coin, Guardian name + deck power, LOBBY portal, a name over every
  resource node (hidden while spent or while its prompt is up), and name + trophies over other
  players (`App/Nameplates`; the server publishes a `Trophies` attribute).
- **Found in Play:** always-on-top billboards are not drawn at all with this game's lighting
  (`App/Prompts` had noted the same), so no billboard uses AlwaysOnTop; pops anchor to their own
  Attachment a little above the object. A viewport icon draws nothing until its mesh has rendered
  once, so item meshes are warmed at startup. Roblox runs a signal's newest handlers first, so the
  "pressed button" is tracked on `InputBegan`.
- **Panel titles** are big now (Luckiest Guy 32, gradient, 3 px stroke, 46 px icon).
- **Sweep:** `docs/GUI_AUDIT_ROBLOX.md` lists every text element with a verdict and its owner phase.
  The rules are in `CLAUDE.md` "UI rules".
- **Play checks** (`docs/screens/roblox-ui/`): harvest pop with icon and items flying; rare pop; the
  error pop above the locked World 3 card; selling (coins fly, 500 → 510); world billboards.
  Not seen live: "QUEST COMPLETE!", "LEVEL UP!" and "WORLD UNLOCKED!" (they need a finished quest, a
  merge and a trophy gain; the logic is covered by the Moments specs).
- Checks: StyLua, Selene, luau-lsp clean; **303 passed, 0 failed**.

### Phase 3 (2026-11-10)
- **`scripts/art/cut_sheet.py`:** `cut` (magenta / near-white / alpha backgrounds made transparent with a
  soft edge and magenta de-fringe; one piece per connected region, small fragments merged into
  their nearest piece; trimmed; capped at 1024 px; reading order; numbered contact sheet
  `docs/review/<sheet>_cut.png`; registered in `kit.json` as REVIEW), `slicetest` (9-slice at 3
  sizes, corners copied pixel-exact), `luau` (writes `Config/UiKit`), `selftest` (a synthetic sheet:
  5 pieces, the sparkle merged into its button, no magenta left, corners identical after stretching).
- **`art/ui/kit-v3/kit.json`:** piece → file, size, 9-slice margins, asset id, tint, status
  (TEMP / REVIEW / APPROVED / LIVE), the UiAssets slot it `replaces` and its TEMP `fallback`.
  17 logical pieces (panel frame, header, close, gold/purple/green/red buttons, tabs, tiles, card
  back, HP bar, reward chip, result banners) start as TEMP on today's images.
- **`App/Kit.piece(name)`** (the plan's "App/Ui/Kit"; it lives in the existing `App/Kit` module) is how
  screens get a painted piece by name; a TEMP piece draws its fallback slot. A LIVE piece that
  `replaces` a UiAssets slot is drawn wherever that slot is (`Ui.asset`/`Ui.skin`/`Ui.reskin`), with its
  own size and margins, so swapping art is a data change. The validator checks the kit (spec added).
- **Pieces from the owner's target** (`scripts/art/slice_target.py`): 8 clean pieces (panel frame rebuilt
  as a seamless 9-slice from the clean corner, close button, crown, empty-state coin bag, divider,
  3 sparkles), all REVIEW. Not cut: everything with baked-in text. **Review gate:**
  `docs/review/ui-kit-v3.png` + `ui-kit-v3.md`; nothing is used or uploaded before the owner's OK.
- Checks: StyLua, Selene, luau-lsp clean; **304 passed, 0 failed**.

### Phase 3b (2026-11-10)
- **Licences read** (`docs/ASSETS.md` "Icon packs"): Free Icon Pack v3.1 (commercial OK, unedited),
  Stylized Game Essentials (commercial OK, editing OK, no redistribution), `Downloads\Free` (no
  licence: not used, listed for the owner).
- **The GitHub repo is public**, so the packs are copied to `art/icons/<pack>/` locally only
  (git-ignored) with their licence texts committed; the review sheets are local too.
- **Sheets:** one per pack and `docs/review/icons_final.png` (39 slots: currencies, HUD 4, menu,
  battle, UI, and 4 farm items). One painted style (35 from Stylized). Choice and reasons:
  `art/icons/icon_map.json`. The other 26 farm items keep their own node mesh, so no item shows
  another item's picture.
- **STOP:** waiting for the owner's OK before any upload (`docs/review/icons_final.md`). The
  per-slot validator test is added with the upload, when the ids exist.

### Phase 4 (2026-11-10)
- **Clean HUD** (`App/Hud`, rewritten to BAD_GUI_5): only a 2 × 2 grid of big labelled buttons (CARDS,
  EGGS, WORLDS, 1v1; bouncing dots, an idle shimmer, press squash), a round ≡ menu (Settings,
  Quests, Main Menu, and Lobby while in a world), bigger currency pills (big icon over the left end,
  30 px number, glossy +), a gift button only while something is claimable, the quest panel, and
  the deck bar. Removed: the 6-button column, both home buttons, the trophy button, the 1v1 button
  by the deck, the deck button (the deck bar opens the Deck Builder; it carries the deck dot).
- **Deck bar:** 3 tall art-first cards (`Card.build` gained `bare`: no name, rarity line or small
  level) with a big "Lv.N" top-right, 4 stage stars on a dark strip, and a framed slot number;
  ~130 × 175 px on PC, ~100 × 135 on phones.
- **Tutorial** (`Config/Quests.Tutorial`, 7 steps: travel, harvest, sell, hatch, save deck, win a
  Trial, try the Arena): tracked on the server like achievements (new kinds Travel, DeckSet,
  QueueJoin in WorldService, EconomyService, MatchmakingService), no rewards, not claimable; sets
  the existing `flags.tutorialDone` when finished. The panel shows TUTORIAL N/7 and the next two
  steps, a new step slides in when one finishes; then it shows the dailies. It doesn't auto-hide
  while the tutorial runs (it would hide it from new players); dailies tuck away after 10 s idle.
  4 specs (`Tutorial.spec`); HudBadges specs keep their meaning.
- **Mobile:** grid 64 px, the grid sits higher on touch screens (thumbstick), the quest panel starts
  collapsed on touch, deck cards shrink. Checked in Play at Studio's 1042 × 433 view (a phone-like
  aspect); 1334 × 750 is part of the Phase 13 pass.
- **Bug found in Play:** the ≡ dropdown's skin was stacked by its list layout and pushed the rows off
  screen; the rows now live in their own frame.
- **Painted look waits for E1-E4** (`art/ui/PROMPTS_V3.md` §2): the layout and behaviour are final.
- Checks: StyLua, Selene, luau-lsp clean; **308 passed, 0 failed**.

### Phase 5 (2026-11-10)
- **Only** the logo, PLAY, SHOP, the Coins/Gems pills and the hero are on the menu; the four tiles,
  tagline, version line, drifting card backs and card showcase are gone. SHOP opens the Egg Shop
  over the menu; the pills' "+" open the Coins / Gems tips.
- **Background:** the D1 path is built (four `menu_bg_*` kit pieces in a 2 × 2, 16:9 cover-fit container
  drifting ±1%, used as soon as they are LIVE). Until then the menu shows **the real night lobby** through
  a re-composed menu camera (low on the plaza, through the torii, the Worlds portal on the right:
  target 09's composition), with a dark left third for the buttons and 12 falling petals. This is the
  FIX_LOBBY §4.9 option; Phase 11's lobby upgrade improves it directly.
- **Hero:** the player's own avatar (`CreateHumanoidModelFromDescription`, in a ViewportFrame + WorldModel,
  warm rim light), standing centre-right like target 09, head near the top and feet on the plaza,
  fading in when it has loaded. Idle: a slow bob and turn and the left arm raised toward a fan of the
  player's three deck cards. Found in Play: parenting re-applies the rig (it jumped 5.7 studs), and a
  WorldModel doesn't step joints, so the pose is set on anchored parts each frame.
- **Logo** (TEMP until D2): a crown over "1V1" in a pink-to-gold gradient and "CARD" in white, 5 px
  strokes, bobbing. **PLAY** (gold, crossed swords both sides, breathing) and **SHOP** (purple, egg
  icon until the cart icon is approved).
- Not checked here: 750 × 1334 portrait (Phase 13).
- Checks: StyLua, Selene, luau-lsp clean; **308 passed, 0 failed**.

### Phase 6 (2026-11-10)
- **Rebuilt to target 06** (`Screens/Shop`): EGGS / EGG BAG tabs and a pager with big arrows and the
  page's worlds ("WORLDS 1-3") instead of a scroll row; a **4 × 2 grid** of tier-coloured tiles (name
  on top in outlined display type, the egg bobbing in its glow, a big price pill in the bottom edge,
  a lock with "WORLD N" for locked worlds, a FREE ribbon on the Basic egg while the daily egg waits,
  the selected tile lifts and glows); the **featured panel** (big gold title, the egg on its pedestal
  with turning rays, popping in on selection; "COMMON → LEGENDARY" in rarity colours from
  `Domain/Odds` with the ODDS pill; a big price; chunky x1 / x3 / x8 that grey out when unaffordable;
  a big FREE EGG gift button; Robux buttons only for products on sale while policy allows; AUTO as
  a small toggle). Locked eggs show the unlock trophies instead.
- **Removed:** the scrollbar, "World 1 · Green Plains" and every sub-20 px line, the "x1 soon" /
  "x3 soon" placeholders (a Robux button now appears only for a product that is on sale), the wide
  green free-egg bar, the "Auto-open: Off" text.
- **Egg Bag:** the same tiles with a big "x2", Golden markers (gold tile, ODDS for Golden eggs) and
  OPEN, paged.
- Purchase, odds and policy logic are unchanged (same requests; the server decides).
- **Eggs:** the Egg Icon Pack, unedited (Option 1), until the owner decides on Sheet C.
- Checks: StyLua, Selene, luau-lsp clean; **308 passed, 0 failed**.

### Phase 7 (2026-11-10)
- **Merchant = target 04** (`Screens/Merchant`): header with the name and a live Coins pill; a gold banner
  with a coin pile, "SELL YOUR HARVEST" in heavy italic (SELL gold), an italic subtitle and a big gold
  SELL ALL with the total; tall item cards in tier colour (rare gold, common blue) with a RARE ribbon,
  the item's own icon with sparkles, a big italic gold "xN", a dark name plate, an "N each" pill and its
  SELL button; free space shows the empty state; more than 4 items page with side arrows (one row is
  all that fits the 540 px design height). Found: clearing the banner deleted its own gradient (it
  turned white); only GUI children are cleared now.
- **The template on every panel:**
  - **Quests:** a gold streak banner of 7 day tiles (check / coin / gem, big amounts) with a big
    CLAIM DAY N; DAILY / GOALS tabs; quests as big cards (kind icon, 20 px task, thick bar, "1/2",
    reward pill, CLAIM / DONE); no scrolling (goals page 3 at a time); no idle button on an
    unfinished quest.
  - **Settings:** SOUND / INFO tabs; big icon rows, ON / OFF toggles, chunky sliders; the purchase
    rules, graphics hint and credits (with the version line the menu dropped) on INFO. Found: the
    credits used to spill out of the panel.
  - **Arena queue:** reward sentences became chips (+220 coins, +30 trophies, LV 8), a big FIND MATCH,
    and "NO ENTRY FEE" in green instead of a footnote.
  - **Worlds picker:** no subtitle, no scrollbar, display type for names and status (TRAVEL, DONE,
    trophies), one big line "TAP A WORLD TO TRAVEL".
  - **Odds:** tier-coloured rows with the name, rarity and a big %, sized to its rows, a readable note.
  - **Confirmations:** a 22 px body and big CANCEL / action buttons.
- Panel art stays TEMP until the owner's merchant kit (and Sheet A) are approved and live.
- Checks: StyLua, Selene, luau-lsp clean; **308 passed, 0 failed**.

### Phase 8 (2026-11-10)
- **Deck Builder + Families side by side** (target hd-04 layout; its copyrighted card art is never used):
  three art-first slot cards with a power plate (sword icon, big number); DECK POWER in big type with
  a count-up and a green or red arrow; the family bonus chips and the ranked level cap as chips; a
  paged strip of the best copy of each character (deck-slot numbers on the ones in use) that flies
  into the selected slot; SAVE DECK grey while nothing changed. **Families** is a compact two-column
  panel of glowing family gems, the active ones gold with their "+N%", and a crown footer.
- **Inventory** (target hd-03 layout): the search bar with a magnifier and the storage count
  (13/300) in the header; big vertical tabs; art-first cards (`Card` `bare`, no names, no stat chips)
  with a big LV and a gold deck-slot box; egg tiles with big labels and OPEN xN; the inspect pane is
  never an empty placeholder (it opens on the first card), with a big name, rarity and family, a
  17 px description, 20 px stat rows, the family bonus, and big EQUIPPED / MERGE / STATS / SELL
  (MERGE only when there are spares). The grid keeps a thin 3 px handle (60 cards a page).
- **Rename follow-up:** Solaris's passive read "heal her"; it is neutral now.
- Checks: StyLua, Selene, luau-lsp clean; **308 passed, 0 failed**.

### Phase 9 (2026-11-10)
- **Battle screen rebuilt to target 18** (`Screens/Battle`): two long HP bars meeting at a hexagon
  timer medallion (ring drains, last 3 s red with a tick and a pulse) and a ROUND plate; under each
  bar only the name with status icons (burn, chill, weaken; they pop when applied), the italic
  rarity badge, an HP sub-bar with "hp / max" and the energy diamonds. Bars drain from the medallion
  side with a white chip trail and a small shake, in step with each hit as the arena plays it (not
  when the packet arrives).
- **Action tray:** three tall cards (ATTACK red sword, DEFEND blue shield, SPECIAL (cost) purple with
  the gold Lightning bolt) on a glass tray with the energy pips toward the Special; the Special is
  dimmed with a lock without enough energy. Pick: the card lifts and glows, the others dim, LOCKED IN
  stamps; the opponent shows a pulsing "?" card until the reveal; both picks then flip in under the
  medallion and a gold 1ST tag (no percentage) marks who acts first.
- **Removed:** the battle log, the "You act first: 20%" pill, usernames, trophies, families, KO lists
  and ability names on screen, and the big red Forfeit (now a small dark FORFEIT with a confirm,
  "Forfeit counts as a loss").
- **Moments:** the arena intro (camera sweep around the map, the map name banner, fighters drop onto
  their pads with an impact ring, the VS badge slams in; tap to skip, ~2.5 s), ROUND N, big damage
  numbers (CRIT! in gold over red, green +heal), PARRY! with a flash, Special camera cut + aura burst
  + screen flash, K.O.! with a slow-motion beat after which the fighter shatters into its aura
  particles; the KO replacement picker waits until the knock-out has played. Reduced motion keeps
  the information and drops the sweep, flashes and shakes.
- **Fighters:** standees with a glowing family-colour aura (particles and light) on light pads that
  take the family colour (the target's aura treatment; real models come from the art pipeline).
- **5 arenas** (`Config/Arenas`, `Shared/Domain/ArenaLayout`, `Shared/Art/ArenaKit`,
  `Server/World/ArenaBuilder`): Sakura Courtyard, Frozen Shrine, Volcano Forge, Celestial Isle,
  Storm Rooftop. One shared core (40-stud platform, rim and inner ring, two light pads, spawn and
  camera points) and per-map dressing, lighting preset (`Config/Lighting arena_*`), sky, particles
  and music (`Config/Sounds music_arena_*`, APMOfficial); Celestial's light rings turn, Storm Rooftop
  has lightning flashes with thunder (PSE). The server picks the map from the match seed and sends it
  in `Battle.Start`, so both players and a reconnect get the same map; the area's lighting and music
  come back after the battle.
- **Deviations, logged:** the templates live in `ReplicatedStorage.Arenas` rather than
  `ServerStorage`, because each client builds its own stage (a hub server can host several local
  battles at once); they're built on every server, including battle servers. The dressing reuses the
  meshes already generated for the hub and worlds (no new uploads, no Creator Store models), so no
  review gate was needed; Blender / `generate_scene` hero props are a later art pass through the
  gate. The old `HubLayout.StageProps` backdrop is replaced by the arenas.
- **Budget:** largest map (Storm Rooftop) is 118 parts including a 46-tower skyline; one ambient
  emitter per map (rate 9-60) plus one aura emitter per fighter.
- **The result screen** was moved unchanged into `Screens/BattleResult` for Phase 10.
- Tests: `Arenas.spec` (five maps; same map for the same seed; all five maps used, each 15-25% over
  5,000 seeds; identical core in every map; deterministic skyline, no prop on the platform; config
  validates; both players get the same map in the start packet) and `ConfigValidator` arena rules.
  StyLua, Selene, luau-lsp clean; **315 passed, 0 failed**.
- **Verified in Studio** with the real screen and real MatchRunner rounds (`UiPreview.battle`) in all
  five maps: intro, picking, reveal, damage, K.O. (`docs/screens/arenas`), and in **Play**: a real
  Guardian Trial (Session.Play, Trial.Start) where the server picked Sakura Courtyard from the seed,
  `Battle.Start` carried it, the client cloned the server's template with its 13 meshes, and a click
  on ATTACK locked in, revealed and played the round (`play_trial_sakura.png`, `play_reveal.png`).
  Fixes from these runs: the Special icon (the pack's "energy" icon is a green gem; now the Lightning
  bolt), a small dark FORFEIT, the 1ST tag, reveal tiles and ROUND word moved off the plate, the KO
  picker waits for the knock-out, Celestial's rock poking through the floor, a readable Storm skyline.
  **Not yet verified:** a phone-size viewport (the Phase 13 final pass covers it).

## Waiting for art
Nothing is blocked: each phase builds its layout and behaviour with TEMP images. The sheets each
phase will swap in (prompts in `art/ui/PROMPTS_V3.md`):

| Sheet | Phases | Status |
|---|---|---|
| A (panel kit) | 4-8 | not received |
| E1-E4 (HUD) | 4 | not received |
| D1-D4 (menu) | 5 | not received |
| B (egg tiles) | 6, 8 | not received |
| Merchant kit + icons | 7 | not received |
| H1-H2 (battle) | 9 | not received |
| G1-G2 (result) | 10 | not received |
| F1 (inventory extras) | 8 | not received |
| C (crystal eggs) | 6 | only if Option 2 |
| Lobby concept | 11 | optional |
| 5 character images | 14 | not received (`NEW_5_CHARACTERS.md`) |

## Owner decisions
| Decision | Asked | Answer |
|---|---|---|
| Egg art: Option 1 (pack eggs in tier tiles) or Option 2 (Sheet C crystal eggs) | 2026-11-10 | pending; Option 1 ships meanwhile |
| GitHub history scrub of `fighter_01..05` (commit `9969dc6`) | 2026-11-10 | pending: waits for the owner's "go" |
| Approval of every new image (sliced pieces, icons, sheets) | per review sheet | pending per sheet |
| OK for the 39 icons (`docs/review/icons_final.png`, local) | 2026-11-10 | pending |
| OK for the 8 pieces cut from `04-merchant-target.png` (`docs/review/ui-kit-v3.png`) | 2026-11-10 | pending |

## Incidents
| Date | What | Action |
|---|---|---|
| 2026-11-10 | The Studio MCP `screen_capture` hung and the viewport reported 1 × 1: the PC's display had gone to sleep at night, which froze the desktop. | Woke the display and ran a session-only keep-awake loop (no power settings changed). `scripts/studio/grab.ps1` saves a Studio window shot as a fallback. |
| 2026-11-10 | Parallel tool downloads landed in the repo root for a moment (a `cd` inside a backgrounded subshell). | Moved out before any commit; nothing staged. |
| 2026-11-10 | A desktop folder named "Ultimate Multi-Expre…" (it looks like the banned portrait pack) still exists on the owner's desktop. | Not touched (owner's files). Flagged in `WAITING_ON_YOU.md`; the project never reads it. |
