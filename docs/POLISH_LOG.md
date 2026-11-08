# Polish log (POLISH_MISSION.md)

One entry per checklist item, in the order it was done: what changed, the scores (1-10 against
the concept board: matches the board / readability / polish and animation / clarity of what to do
next / consistency with ART_STYLE), the screenshots, and what was and wasn't tested in Play mode.

Sizes: Studio's device emulator can't be scripted, so the four sizes come from resizing the Studio
window (its viewport): **PC** 1398×753, **tablet** 1073×805 (4:3), **phone landscape** 1742×805
(2.16:1, the shape of a 19.5:9 phone), **phone portrait** 362×805. The game runs landscape on
phones (`StarterGui.ScreenOrientation = LandscapeSensor`, now set in the project files), so
portrait is checked for robustness only.

---

## Conflicts with locked decisions (not built, see docs/WAITING_ON_YOU.md)
- **G, new egg types:** CLAUDE.md locks the game to exactly the 24 icon-pack eggs (game-director:
  "40 eggs" is a listed trap). The rest of G (odds button, Robux rules, data-driven pools, tests)
  already holds and is kept.
- **C, "Gems + opens the cosmetics shop":** the cosmetics shop is designed but not built in V1
  (STATUS "Designed but not built"). The Gems + explains what Gems are for instead.
- **F, Blender pipeline:** needs the owner's character images and Blender's generators switched
  on (WAITING_ON_YOU 1-2). The TEMP silhouettes and the automatic pickup are in place.

---

## A. UI state machine — done (2026-11-07)
**Changed**
- `Shared/Ui/UiFlow`: one pure state machine, `Loading → MainMenu → Playing / Queue`, with
  `Panel` (one modal), `Hatching`, `Battle` and `Result` on top. It derives the view: HUD mode
  (full / currencies only / hidden), input lock, blur, the menu camera. Unit-tested
  (`UiFlow.spec`, 7 specs).
- `App/App`: every screen change goes through it. One modal at a time, and opening one replaces the
  other. Esc, gamepad B, Backspace and the X close the top panel. Panels close with a scale-out,
  and the HUD slides off and back (0.3 s, Back ease-out).
- `App/UiEffects`: blur + colour grade under modals and the menu, movement off and the camera held
  while a modal is open.
- Battle and Hatching hide the whole hub HUD. A panel stays open under a hatch and is there again
  after it.
- `Ui.button` is debounced (0.35 s). The server still validates every action, since the UI state
  is presentation only.
- **Narrow screens:** the logo hides, the currency bar moves left of the icons, the Menu button
  drops under the icons, and panels scale to fit.

**Tested in Play**
- Holding W with a panel open moves 0.00 studs; after Backspace, 15.97 studs.
- A double click opens one panel.
- The Shop survives a hatch.
- Battle and Result show no HUD; Continue brings the full HUD back.
- Esc closes the panel, but Roblox's own Esc menu also opens. Games can't intercept that key, so
  Backspace or B are the clean ways to close.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/ui/04-11` (HUD and modal at all four sizes).

## B. Main menu — done (2026-11-07)
**Changed**
- `App/MainMenu`: a full-screen menu over a slowly drifting, blurred and colour-graded camera shot
  of the night lobby. It has the 1V1 CARD logo, a big pulsing gold PLAY, Cards / Shop / Settings,
  and a version/news line. While loading it shows "Loading your cards…".
- The camera holds the menu shot and controls are off. The backpack is hidden always, and the
  player list while in the menu.
- PLAY: the camera flies in to the character (1.4 s), then controls come on and the HUD slides in.
- The HUD's Menu button reverses it.
- Menu music (APM "Team of Heroes") crossfades to the lobby track on PLAY.

**Tested in Play**
- Menu on join with only the currencies.
- PLAY → HUD and camera back on the character; Menu → back.
- Panels open over the menu.
- Music swapped from `Music_music_menu` to `Music_music_hub`.
- Player list on again after PLAY.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9. Key art from the owner
would lift "board".

**Screens:** `docs/screens/ui/01-03` (menu PC / tablet / portrait), `08` (a panel over the menu).

## E. Cards — done in session 3 (step 1)
All nine boxes were built and tested before this mission: `docs/screens/cards/01-09`, with Play
captures of the hatch, collection, battle and result. The details are in `docs/CONVERSATION.md`
("Session 3, Part 3").

## J. Lobby and worlds — done in session 3 (step 1)
- Lobby spawn (join, respawn, after battles, and now after the main menu's PLAY).
- Server-checked travel and a Back to Lobby portal.
- 10 themed maps with their own terrain, props, sky, lighting, particles and music.

Screenshots are in `docs/screens/12-15` and `docs/screens/worlds/`. Everything was tested in Play
(see `docs/CONVERSATION.md` "Session 3, Parts 1-2").

## C. Gameplay HUD — done (2026-11-07)
**Changed**
- **Top:** Coins, Gems and Trophies with the league. The Coins **+** opens "How to earn Coins"
  (Coins are never sold). The Gems **+** opens "What Gems are for": the cosmetics shop isn't in V1
  (locked: designed, not built), so it explains that instead (`Screens/Tip`).
- **Top right:** the gift (daily rewards) and calendar (quests) icons, plus a new **Friends** icon
  that opens the Roblox invite prompt. In Studio it toasts that invites need the published game.
- **Left:** the icon menu (Play, Inventory, Deck, Shop, Worlds, Quests, Settings), each with a
  notification dot when something is ready (`Shared/Ui/HudBadges`, unit-tested):
  - Quests: a finished quest or today's streak
  - Shop: today's free egg or eggs in the bag
  - Deck: fewer than 3 cards
- **Bottom:**
  - left: the current place ("LOBBY" or "WORLD 3 · DESERT KINGDOM")
  - centre: the progress hint
  - right: a quest tracker with a progress bar (taps through to Quests)
- **Custom prompts** (`App/Prompts`): every world and hub prompt is drawn in the game's style, with
  a gold key chip (E, the gamepad button, or TAP on touch, where the whole pill is the button), the
  action and the object. Prompts are off while a modal or the menu is up.
  - Billboards set to AlwaysOnTop were not drawn at all in this place (verified with a plain
    test billboard), so prompts sit 6 studs up instead.
- **Toasts and pop-ups:** reward, unlock and error toasts were already there. Currency gains now
  float a "+N" up from the badge while it counts up.
- **No emoji:** all 17 emoji labels were replaced by words or icon images (Coins, Gems, trophies,
  energy, Power, "In deck").

**Tested in Play (PC)**
- Dots shown for Deck, Shop and Quests on a new profile; the Quests dot cleared after claiming the
  streak.
- The tracker showed "Daily: Harvest 30 resources 0/30".
- The custom prompt showed at the egg stall, and E opened the Egg Shop.
- The Coins + tip opened, and "+100" floated up on the streak claim.
- Note: during a long idle pause with the Shop open, one Basic Egg was bought (ledger
  `egg:egg_basic`, 35 minutes before it was noticed). It could not be reproduced, and no key or
  code path buys without a click on Buy, so it was most likely an outside click on the open Studio
  window.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/hud/01-04`. The four sizes for the HUD are in `docs/screens/ui/04-07`.

## D. Every screen — done (2026-11-07)
**Changed**
- **Inventory** (was Collection):
  - tabs All / Cards n/300 / Items n/5 / Eggs n, rarity filters and a search box (name or family)
  - the storage expand button for the current tab
  - egg tiles with Open (Golden copies get their own tile) and item tiles
- **Card Inspect:** a big 150×210 layered card, the four stats, the family bonus the card brings,
  merge progress, Merge, **Equip** and Sell spares.
  - Equip replaces a copy of the same character, else the weakest card. An incomplete deck is
    filled with the strongest other characters, since a deck is always 3 different characters.
- **Families panel (new):** all 15 families with glyph, bonus stat, owned characters (n/total), and
  ACTIVE ×2/×3 for the saved deck. Opened from the Deck Builder's new Families button.
- **Arena:** shows the trophy count with the league. Find Match, the queue timer and range, and
  Cancel were already there.
- **Worlds map:** a completed tick on worlds whose Guardian Trial is cleared.
- **Settings:** music and effects volume sliders (0-100%, steps of 5) saved on the profile, plus a
  graphics hint.
  - Profile schema v4: append-only migration 3→4 adds `musicVolume = 80` and `sfxVolume = 100`.
  - `Settings.Set` accepts the volumes only as whole numbers 0-100 (specs for the payload and the
    migration).
  - Music and effects volume apply live.
- Fixes found in Play:
  - Equip on an empty deck returned BadRequest (now fills the deck).
  - The streak Claim button overflowed the Quests panel.
  - The reduced-motion label was cut off.
  - The merchant's name was hidden by the cart.
  - The merchant had three gold buttons (now the green style; this restyle was checked by the
    static checks only).

**Tested in Play (PC, granted test profile)**
- Inventory All and Eggs tabs, and inspecting the level-15 Mythical.
- Equip → "Aurelia Dawn is in your deck" and a full deck.
- Deck Builder and Families, with Flame ACTIVE ×3 after an all-Flame deck.
- Arena: Find Match → "Searching… 0:05 · trophy range ±100" → Cancel search.
- Settings slider to 50%: saved on the server, and lobby music 0.25 → 0.125.
- A real Guardian Trial win: the Victory screen with KO marks, the count-up and +40 trophies.
- The Worlds map then showed the tick on World 1 and World 2 unlocked.
- Quests and the 7-day streak; the merchant opened from its prompt in World 1.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/screens/01-14`.

## F. Characters — done as far as the owner's art allows (2026-11-07)
**Changed**
- **No more stacked-primitive characters.** `Shared/Art/RigBuilder` (part-built R15-style rigs) is
  deleted. Characters in 3D are now **standees** (`Shared/Art/Standee`): the character's cut-out art
  on a thin panel readable from both sides, on a glowing base in the family accent.
  - The battle stage turns them to the camera, so lunge, flinch, bubble, KO and the drop-in still
    play.
  - Each world's Guardian stands in its trial gate as a scaled standee.
- One source for the art layers (`Shared/Art/Cutout`): the card UI and the standee draw the same
  thing, either the owner's transparent `cardArt` with a rim light, or the TEMP role silhouette
  (4 layers tinted with the character's look colours).
- **Automatic pickup** (`scripts/art/characters.py status|check|urls|apply`):
  - finds `art/characters/<id>/card.png` and `front.png` for original character ids only
  - checks PNG, ≤ 1024 px, and a transparent background for the card
  - lists the upload URLs, then writes the uploaded ids into `CharacterDef.assets.cardArt`
  - tested end to end on a temporary copy
- The battle plates no longer show "0 trophies" in Guardian Trials (the Trial seat now carries the
  player's trophies, and AI seats show none).

**Waiting on the owner:** 0 character images exist yet. The Blender steps (image-to-3D,
cleanup, R15, animations, renders) need the images and Blender's generators switched on
(WAITING_ON_YOU 1-2).

**Tested in Play:**
- Guardian Trial with standees upright, facing the camera, on family-colour bases.
- An Attack round, captured mid-lunge with the hit burst.
- The World 1 Guardian standee in its gate.
- The UI check builds all 100 standees (2 parts each).

**Scores:** board 7 · readability 8 · polish 7 · clarity 9 · consistency 9. "Board" and "polish"
stay below 8 until real character art replaces the TEMP silhouettes; that is owner-blocked and
logged.

**Screens:** `docs/screens/characters/01-03`.

## H. Egg opening — done, except the sound ids (2026-11-07)
**Changed**
- **x1 / x3 / x8, decided on the server.** `Shop.BuyEgg` and `Bag.OpenEgg` take an optional
  `count` (1, 3 or 8; default 1, so old clients still work).
  - `Domain/Hatch` checks the count, free storage and the bag stack before anything changes.
  - A Coin batch is one charge (price × count) under one request id, so a replay is refused as a
    whole. Anything else fails with `InvalidQuantity`.
- **Shop.** A x1 / x3 / x8 selector, with the total price and "Buy x8". Bag opens take as many as
  the stack and storage allow ("Open x3 from Egg Bag (4)"). The Auto-open toggle is beside the
  selector.
- **Hatch screen** (`Screens/Hatch`, rewritten):
  - Darker focus backdrop.
  - A burst in the best rarity's colour, then a grid reveal: 1 large card, 3 in a row, or a 4 × 2
    grid. The small cards drop the caption because the card already shows name, rarity and stats.
  - **Legendary and up:** a slow-mo beat (the room darkens, the egg swells, cracks and rays turn
    gold), then a gold flash.
  - **Mythical:** three rainbow shockwaves above the flash, plus a screen shake.
  - **Golden:** gold rays, pedestal, flash, rings and callout.
  - The colour wash after a flash is a tint, never a solid screen.
- **Skip** fast-forwards any beat straight to the finished cards.
- **Auto-open:**
  - Opens the next batch after 1.4 s.
  - Stops when the player taps "Stop auto-open", when Coins, storage or the stack run out, or when
    a Legendary or better appears (so it is always seen).
  - Batches chain inside one overlay.
- **"NEW!"** marks the first copy of a character, against the cards owned before the request and
  earlier cards in the same batch. It sits on the card's left edge, clear of the banner.
- **Sound slots for every beat:** hatch_shake, hatch_crack, hatch_burst, card_flip, and
  reveal_common through reveal_mythical. They are silent until I fills them.

**Tests:** 3 new specs: x3 and x8 buys (one charge, refusals leave Coins and cards untouched), bag
x3 and x8, and the sound slots. Net.spec also rejects counts 9, 2.5 and "3". 262 pass headless.

**Tested in Play:**
- With real server rolls:
  - Coin buys at x1, x3 and x8.
  - A Golden x8 bag open.
  - Auto-open from a bag of 12: x8, then x3, then x1, then a stop at the empty bag with Continue.
    Skip and Stop were visible on each batch.
  - Skip pressed mid-shake on a x3 buy: the cards were finished in under a second.
  - The bag button disappeared when the stack emptied.
  - "NEW!" appeared only on first copies, including duplicates within one batch.
- Real rolls almost never give Legendary or Mythical. Those moments were played in Play mode by
  calling the real `Screens/Hatch` with injected cards (screenshots marked "injected").
  - A logger counted 3 rings growing to 1,400 px and a shake of up to 16 px.
- Sizes: the x8 grid at 1600 desktop, phone landscape and portrait (fits, scaled).
  Reduced motion shows the cards at once.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/hatch/01-15`.

## G. Eggs — done within the locked rules (2026-11-07)
**Already true, now checked in Play:**
- **The 24 icon-pack eggs only.** Their icons are uploaded unedited and referenced in
  `Config/Eggs`. Golden eggs use the pack's own golden files, never a recolour.
- **Data-driven.** Every egg is in `Config/Eggs`, with its own themed pool (`Config/EggPools`,
  8-10 characters).
- **Odds.** The labelled Odds button opens exact per-character % from `Shared/Domain/Odds`, the
  same table the server rolls from, with the rounding note.
- **Robux and Golden rules:**
  - The Robux buttons exist only for unlocked-world eggs while `PaidRandomItemsAllowed` is true.
  - The receipt is re-checked at delivery.
  - There are no Golden Developer Products, so Golden eggs are earned only.
- **Tests.** All policy and odds specs pass (PolicyRules, PolicyMatrix, Odds, ReceiptProcessor;
  262 total). H's multi-open keeps one charge per batch and never changes odds.

**Not built:** new original egg types. They are blocked by the locked 24-egg rule (WAITING_ON_YOU 00).

**Tested in Play:** the Egg Shop (prices, owned counts, x1/x3/x8, the Odds button, Robux buttons
shown as "not on sale yet" until product ids exist) and the Odds popup for the Basic Egg.

**Scores:** board 8 · readability 9 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/eggs/01-02` (and the hatch shots in `docs/screens/hatch/`).

## I. Music and sound — done (2026-11-07)
**Changed**
- **Every SFX slot has an id** (`Config/Sounds`, listed in `docs/ASSETS.md`):
  - 20 from ProSoundEffects and 5 stings from APMOfficial.
  - These are the two licensed libraries Roblox provides in the Creator Store. "The official Roblox
    account" itself has no SFX library, so these partner accounts are the licensed source.
  - Rips from commercial games (Valve, Garry's Mod, Undertale, Minecraft, JJS) came up in search
    and were rejected.
- **New slots:** `purchase` (Coin egg buys, storage and item-slot expands), `merge`, and `level_up`
  (the Inventory Merge button: merge, then level-up when the level rises). `hover` plays on every
  juiced button, at most once every 0.08 s.
- **Battle:** hit (Attack), hit_special (Special), parry (Defend vs Special), KO, the 12 s pick
  tick, victory and the new defeat sting.
- **Music:** main menu, lobby, battles and each of the 10 worlds, crossfaded by `App/AreaFx`.
- **Bug found in Play:**
  - The main-menu track never loaded. The Sound was made in the first moments of the session and
    stayed unloaded while "playing"; the same id loads fine on a fresh Sound.
  - Fix: AreaFx rebuilds a track that hasn't loaded after 4 s, up to 3 times. After the fix it loads
    (157.8 s).
- The volume sliders were already done in D (saved to the profile, schema v4).

**Tested in Play:**
- Every id loads in Studio (ContentProvider plus a parented Sound).
- In Play, the UI created and played:
  - shop and hatch: hover, click, open, close, purchase, shake, crack, burst, card_flip, reveal
  - battle (a full 24-round Guardian Trial): tick, hit, hit_special, KO, coin and the defeat sting
  - music: the menu → lobby crossfade (menu fading out while the lobby fades in)
- Not heard in that run, but wired and loading:
  - parry: no Defend met a Special
  - victory: the battle was lost
  - merge and level_up: the merge was sent through the remote, not the Inventory button
- Claude can't hear audio, so the owner should listen and swap any id (WAITING_ON_YOU 5).

**Scores:** board 8 · readability 9 · polish 8 · clarity 9 · consistency 9.

## K. Final pass — done (2026-11-07)
- A fresh-player playthrough in Play: menu → PLAY → deck → hatch → World 1 → Guardian Trial
  victory → lobby → farm → sell → main menu. Screens are in `docs/screens/final/01-15`.
- **Fixed:**
  - Starter deck for new players (they couldn't form a 3-character deck).
  - The hatch title for cards already owned.
  - The main-menu music never loading (in I).
- The report is `docs/POLISH_REPORT.md`. 263 specs pass.

---

# MISSION.md (master mission, 2026-11-07)

## Cards: frames, template, stats panel, favourite, evolution, animations (sections 5-6)
Built before MISSION.md landed, under CARDS_EGGS_MISSION (now merged into MISSION.md).
- **Frames (6.1):** `scripts/art/card_kit.py`, 5 rarities x 3 sizes, separate frame / glow /
  energy / panel layers, italic badges, Golden overlay. Compare: `docs/screens/step5/compare_frames.png`.
  Scores: reference 8 · quality 8 · readability 9 · motion 8 · consistency 9. First pass scored 7
  (thin band, no inward corner blades); fixed by thickening the band and adding the blades.
- **Template card (6.2):** `docs/screens/step5/compare_template.png`, `template_gallery.png` (Play
  mode, every rarity and kit size, Golden). Scores: 8 · 8 · 9 · 8 · 9.
- **Stats panel + Favorite (6.4):** `docs/screens/step5/compare_stats.png` (Play mode). Upgrade
  merged Lv 1 -> 3 through the server, Equip set the deck, Favorite toggled, Evolve and Preview
  open. Scores: 9 · 8 · 9 · 8 · 9.
- **Evolution (6.6):** `docs/screens/step5/evolution.png` (Play mode). Scores: 8 · 8 · 9 · 8 · 9.

## Section 2: the four-screen flow
- **Launch loading:** `src/first/Loading.client.luau` (ReplicatedFirst). Real PreloadAsync of 300+
  images and core sounds plus the profile wait; card fan N -> UR flips; tips; min 1.5 s, 20 s
  timeout. Play mode: 0% -> 24% -> 67% -> 100%, then fades into the menu
  (`docs/screens/flow/01-launch-loading.png`, `02-main-menu.png`).
- **Session state (server):** `Domain/PlayState`, `Services/SessionService`; characters no longer
  auto-load; `Session.Play` / `Session.Leave`; travel, hub, harvest, sell, queue and Trial refuse
  players who aren't playing (checked in Play: `Farm.Harvest` on the menu -> `NotPlaying`).
- **PLAY:** a fresh character at the lobby spawn (Play mode: -2400, 4.5, 74 both times, also after
  leaving from World 1). `docs/screens/flow/03-play-lobby.png`.
- **Return-to-spot fix:** `Domain/ReturnSpot` (spot -> world spawn -> lobby). Play mode: travel to
  World 1, stand at (40, 6, 60), Guardian Trial, forfeit -> back at (40, 6, 60), 0.00 studs off,
  still World 1 (`04-after-trial-same-spot.png`). Ranked across servers carries the spot in the
  teleport data both ways (logic tested; ReserveServer doesn't run in Studio).
- **Leaving:** Menu -> confirm (forfeit warning in a battle) -> leaving screen (logo, flipping
  card, ~1 s) -> menu; server forfeits, leaves the queue, removes the character, saves
  (`05-menu-confirm.png`, `06-leaving.png`, `07-back-to-menu.png`).
- Specs: Flow.spec (PlayState, ReturnSpot), UiFlow `leave`; e2e driver checks the menu gate and PLAY.
- Scores (flow, no board): function 9 · clarity 9 · motion 8 · consistency 9.

## Section 3: in-game HUD (`ui-refs-3/01-ingame-hud.png`)
- `App/Hud.luau` replaces the old dock: a 2 x 3 grid of chunky square buttons (red Inventory,
  orange Eggs, teal Deck, green Daily, purple Worlds, blue Settings) with dots and tooltips, a small
  Menu button, two currency bars (short amounts, gold / blue "+"), the deck bar (3 small cards,
  level, stage stars, slot number, tap -> Deck), the 1v1 button, and a compact quest card (title,
  done/total, two rows with check boxes and bars) that collapses to a trophy with a ring on tap or
  after 10 s. Removed while playing: the logo, the hint pill, the place label, the Friends icon.
- Buttons size to ~68 px physical on PC and 56 px on phones (never under 44).
- Lighter in-game panels: `panel_light` glass while playing, at ~86% scale (about 70% of the
  screen); the deep navy panel stays on the menu and showcases.
- Play mode (phone landscape viewport, 844 x 441): `docs/screens/hud/ingame_lobby.png`,
  `ingame_quest.png`, `ingame_panel_light.png`; compare `docs/screens/hud/compare_ingame.png`.
- Scores: reference 8 · quality 8 · little text 9 · motion 8 · consistency 8.

## Section 4: UI kit replacing the TEMP images
- `scripts/art/ui_slots.py` renders final images for every UI slot still on a TEMP stand-in (51
  slots: panels, header, inset, shadow, close, gold / purple / green / red buttons, tabs, tiles,
  toast, reward chip, card back, shine, glow, rays, sparkle, cracks, timer ring, energy pips, HP
  bar, action buttons, VS badge, petal, portal swirl, Victory / Defeat banners, 15 family glyphs),
  uploaded and recorded as `final` in `art/ui/ids.json`. Retired slots (old card layers, card
  backgrounds, old HUD pieces) are left out of `Config/UiAssets`.
- Still TEMP: `egg_pedestal` (tier pedestals come in section 7) and the 24 `cutout_*` role
  silhouettes (character placeholders until phase 2 art).
- **Card animations (6.5):** `docs/screens/step5/compare_anim.png` (Play mode, Rare / Epic /
  Legendary auras, Legendary orbit ribbon now drawn front and back), frame strip
  `anim_strip.png`. Scores: reference 8 · quality 8 · readability 9 · motion 8 · consistency 9.
- **Cards everywhere (6.7):** every call site uses App/Card (HUD deck bar, main-menu showcase,
  battle plates, KO picker, results, inventory grid and inspect, card stats, deck slots and picker,
  hatch, arena).
- `docs/GUI_AUDIT.md` (section 4.2) and `art/ui/PROMPTS_V2.md` (route O prompts) written.

## Section 7: eggs
- **Pack wired in (7.1):** the Egg Icon Pack copied unchanged to `art/eggs/pack/` (with
  `License.txt`); 47 64 px icons uploaded (`smallAssetId`, `goldenSmallAssetId`); `Visuals.egg` uses
  them for small views and never shows an egg above ~256 physical px. Egg tiers come from the odds
  band (`Config/EggTiers`) and colour the pedestal, glow, pills and summon circle only. Tier
  pedestals rendered in Blender (`ui_studio.py pedestals`), shard sets drawn in code. Credits in
  Settings (@gvesster). `docs/ASSETS.md` records the switch away from Blender eggs.
- **Egg Shop (7.2):** eggs on tier pedestals in one scrollable row grouped by world, label and
  price pills, idle bob, glow, "World N" locks; the selected egg rises and its ring glows; details
  with tier pill, "Drops X up to Y · see Odds", price, gold x1 / x3 / x8, Odds, Auto-open, Robux
  only while allowed (one compact row); Egg Bag tab. Compare `docs/screens/eggs/compare_shop.png`
  (board 01; the egg art differs by design: the unedited pack). Scores: reference 8 · quality 8 ·
  readability 8 · motion 8 · consistency 9.
- **Opening (7.3):** five stages (summon, crack, break, reveal, get card). Play mode: a real x1
  Common hatch from the shop; injected (labelled) x1 God-tier with the light pillar, x8 Golden with
  mixed rarities (gold circle, gold shards, Golden foil, row of silhouettes, grid flip), x3 with Skip
  (tap -> cards). Compares `docs/screens/eggs/compare_opening_stage1..5.png`; frames
  `opening_ur_stage*.png`, `opening_x3_skip.png`. Scores: reference 8 · quality 8 · readability 8 ·
  motion 9 · consistency 9.

## Section 8: other screens (Play mode, phone-landscape viewport)
| Screen | Compare | Scores (ref · quality · little text · motion · consistency) |
| --- | --- | --- |
| Inventory + inspect (`hd-03`): badge filter chips, large card, rarity pill + family, description, Power / Health / Skill rows, green family bonus, Equip (purple) / Merge / Card Stats | `docs/screens/screens/compare_inventory.png` | 8 · 8 · 8 · 8 · 9 |
| Deck Builder (`hd-04`): Deck Power count-up with a green arrow (seen: 1,619 -> 1,714 after equipping), family chip with gem and "+2% ATK", dashed empty slots, equip fly-in | `compare_deck.png` | 8 · 8 · 8 · 9 · 9 |
| Families (`hd-04`): two-column list, glowing active rows (Warrior x2), dimmed inactive, crown footer | `compare_families.png` | 8 · 8 · 8 · 8 · 9 |
| Arena (`hd-05`, no bet): league, trophies, win purse, level cap, Find Match -> queue timer + Cancel (tested), lead card VS red "?" | `compare_arena.png` | 8 · 8 · 8 · 8 · 9 |
| Victory (`hd-06`): real Guardian Trial win, winged gold banner with crown, rays, lead card, rewards counted up | `compare_victory.png` | 9 · 8 · 8 · 9 · 9 |
| Defeat: cold steel banner, encouraging line | `compare_defeat.png` | 8 · 8 · 9 · 8 · 9 |
| Worlds (`hd-07`): strip of 10 tall cards, big numbers, locks, trophy needs, Completed tick, HERE tag | `compare_worlds.png` | 8 · 8 · 9 · 8 · 9 |
| Quests / Daily, Settings (+ Credits), Merchant, Queue, Battle UI, KO picker | final kit images (panel, tiles, buttons, HP bar, pips, action buttons); `quests_ours.png`, battle in `defeat_ours.png` / `victory_ours.png` | 8 · 8 · 8 · 8 · 9 |

## Section 9: sound
- `App/Sfx`: one module for every sound (Settings volume, 50 ms debounce, ±5 % pitch on
  click / tick / tab / hover / card flip, coin chime pitch rising with the amount). `Ui.sound`
  delegates to it.
- Wired: hover, press, primary "confirm", tabs, panel open / close, error, coins, purchase, egg
  summon / shake / crack / burst / reveal per rarity / card flip / sparkle, card hover / flip /
  equip / merge / level up, matchmaking searching tick and match found, battle picks (attack,
  defend, special), hit, parry, KO, victory / defeat stingers, flow (menu music, lobby crossfade,
  leaving whoosh), toasts. New slots reuse licensed ids (ASSETS.md), "unreviewed".
- Play mode: no errors in the console through menu -> PLAY -> panels.

## Section 10: motion
- `App/Motion` holds every timing (panel 0.92 -> 1 in 0.25 s back-out, close 0.15 s, hover 1.04,
  press 0.94, 25 ms stagger, gold shine every 5 s, selected-tile pulse 1.2 s, card lift 1.05,
  glow breath 1.5 s); `Theme.Motion` points at it.
- Added: shine sweep on gold buttons, selected-tile glow pulse. Existing: staggered grids, count-
  ups and "+N" on currencies and Deck Power, notification dot bounce, toasts, HUD drop-in, VS slam,
  Victory banner bounce with rotating rays, the launch card shuffle. Reduced motion skips them.

## Section 11: extra assets
All listed assets exist in the kit (`art/ui/MANIFEST_V2.json`, 183 images uploaded): stickers,
MAX ribbon, 15 family gems, stat and button icons, level bar, summon circle and runes, cracks 1-3,
shard sets per tier, shockwave, rays, pillar, confetti, auras per rarity, orbit ribbon, sparkle /
ember / mote (`fx_*`), tier pedestals, lock overlay, world badge, card backs per rarity, empty slot,
filter chips, rarity toasts, odds rows, six HUD button colours (+ `hud_btn_night`, used as the
`menu_button`), quest card, logo.

## Section 12: phase 2, character PNG pipeline (portrait pack)
- `scripts/art/portraits.py`: ingest (originals copied unchanged to the git-ignored
  `art/characters/incoming/portrait-pack`, flagged TEMP_UNLICENSED), split (seeded distance
  watershed, heads touch on these sheets), clean (fringe, holes, 1 px feather), upscale (Lanczos +
  unsharp, at most 4x), style (one grade, dark outline, family rim light, tint for sketchy art),
  safe (head and shoulders, review list), derive (card, portrait, silhouette, expressions), check
  (sizes, transparency, duplicates, contact sheet), urls, status. `characters.py apply` writes the ids.
- 10 characters processed, 0 problems: contact sheet `docs/screens/characters/contact_portrait-pack.png`.
- **Not done: upload and in-game check.** The local image server was stopped by Claude Code for
  low memory and is not restarted without the owner (WAITING_ON_YOU 0000).
