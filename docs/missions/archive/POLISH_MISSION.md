# POLISH MISSION: make 1v1 CARD look and feel like a top Roblox game

This file is the mission. Work through it in a loop until every box in the checklist is ticked.
Don't stop to wait for the owner.

## 0. Read first

- `CLAUDE.md`, `docs/CONVERSATION.md`, `HANDOFF.md`, `STATUS.md`
- `docs/ART_STYLE.md` (the style guide; follow it everywhere)
- `docs/brief/concept-board.png` (**the target** for layout, mood, colours and quality)
- `docs/brief/05-ui-design-system.md`
- `art/characters/PROMPTS.md`, `art/ui/PROMPTS.md`, `docs/ASSETS.md`, `docs/WAITING_ON_YOU.md`

### What to take from the concept board
Dark neon purple night scene, gold primary buttons, glowing panel borders, chunky display text,
bright rarity colours, a left icon menu, the currency bar, the panel layouts (Egg Shop, Inventory,
Card Inspect, Deck Builder, Families, Arena, Victory, Worlds).

### What NOT to copy from it
- **The characters:** Gojo, Naruto, Itachi, Luffy and the Akatsuki cloak are copyrighted.
- **The "Bet Amount" panel:** there are no wagers, because Roblox bans simulated gambling. The
  Arena panel shows league, trophies and the purse reward instead.
- **"Get a Legendary or better character!"** It reads as a guarantee on a random item. Use
  "Drops Common up to Legendary (see Odds)".
- **Never** use `github.com/Sidmaz666/character-dataset` or any real anime/franchise art or
  names, even if asked. All characters are original.

---

## 1. The loop

Repeat until every box in section 2 is ticked:

1. **Pick** the highest-priority unticked item (work top to bottom; A first).
2. **Build** it fully. Nothing temporary counts as done. Anything waiting on the owner's art is
   marked `TEMP` in code and listed in `docs/WAITING_ON_YOU.md`.
3. **Test in Play mode** (not only edit mode) at four sizes: phone portrait, phone landscape,
   tablet, PC.
4. **Screenshot** every state with `screen_capture` into `docs/screens/<area>/`.
5. **Score** the capture against the concept board, 1-10 on each of these:
   - matches the board
   - readability
   - polish and animation
   - clarity of what to do next
   - consistency with `ART_STYLE.md`

   If any score is below 8, improve it and go back to step 3.
6. **Check:** headless tests (`python scripts/headless/bundle.py`, then `luau
   build/headless.luau`), StyLua, Selene, luau-lsp strict, Rojo build. Fix every failure.
7. **Commit**. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
8. **Log** it in `docs/POLISH_LOG.md`: what changed, the scores, the screenshot paths.
9. **Tick** the box in this file and loop.

If something needs the owner (images, approval, keys), write it in
`docs/WAITING_ON_YOU.md` and keep looping on other items. **Never stop to wait.**

---

## 2. Checklist

### A. UI state machine (first; everything plugs into it)
- [x] One client `UIController` owns the states:
      `Loading → MainMenu → Playing (HUD) → Panel (modal) / Hatching / Queue / Battle / Result`.
- [x] Only one modal panel at a time. Opening one closes the other. Esc, the X button and mobile
      back all close the top panel.
- [x] While the main menu or a modal is open: movement and camera input are disabled, the
      background gets a blur, and the HUD hides everything except the currencies.
- [x] Battle and Hatching hide the hub HUD completely and show only their own UI.
- [x] Every transition is animated (fade/scale/slide, 0.2-0.35 s, ease-out-back).
- [x] Every button is debounced, so double-clicks can't open things twice.
- [x] The server never trusts the client's UI state; every gameplay action is still validated
      on the server.

### B. Main menu (a separate screen, not the game)
- [x] On join the player sees **only** the main menu: a clean full-screen background (a
      cinematic, slowly drifting camera shot of the lobby at night with blur and colour grading,
      or key art once the owner provides it), the **1v1 CARD** logo, and big buttons: **PLAY**,
      Collection, Shop, Settings, plus a small news/version line.
- [x] The character exists but isn't shown in gameplay: the camera is locked on the menu shot,
      controls are off, and the default Roblox backpack/player list UI is hidden.
- [x] **PLAY:** smooth camera fly-in to the character in the lobby, then controls on, then the
      HUD animates in.
- [x] A menu/pause button in the HUD returns to the main menu with the reverse transition.
- [x] Menu music, crossfading to lobby music on PLAY.

### C. Gameplay HUD (short, clean, icon-first, like the board)
- [x] **Top:** Coins and Gems with + buttons, plus trophies with a league badge.
      - The Gems + opens the cosmetics shop. *(Adapted: the cosmetics shop is V2 by a locked decision; the + explains Gems until it exists. See docs/WAITING_ON_YOU.md.)*
      - The Coins + opens a "How to earn Coins" tip. **Coins are never sold.**
- [x] **Top right:** icon buttons for Daily Rewards (gift), Quests (calendar), Friends.
- [x] **Left:** a vertical icon menu: Play/Arena, Inventory, Deck, Shop, Worlds, Quests,
      Settings. Each has an icon, a short label, and a notification dot when something is
      claimable.
- [x] **Bottom:** current world name, a small quest tracker, and a progress hint (for example
      "Reach 100 trophies to unlock World 2").
- [x] Custom-styled contextual prompts near the portal, egg stall, Arena and merchant (not the
      default ProximityPrompt look).
- [x] Toasts for rewards, unlocks and errors, plus floating "+Coins" pop-ups.
- [x] One consistent icon set (rendered or generated per `art/ui/PROMPTS.md`). **No emoji.**

### D. Every screen, matching the board's panels
- [x] Egg Shop
- [x] Inventory: tabs All / Cards / Items / Eggs, search, storage count with an expand button
- [x] Card Inspect: big 2.5D card, stats, family bonus, merge, equip
- [x] Deck Builder: 3 slots, deck power, family bonus, Save Deck
- [x] Families panel: every family, its bonus, which ones are active
- [x] Arena: league, trophies, purse reward, Find Match, queue timer, Cancel
- [x] Victory / Defeat: rewards count-up, trophy change, Continue
- [x] Worlds map: 10 world cards with art, locked/unlocked, trophies needed, completed tick
- [x] Quests, Daily Rewards (7-day streak), Merchant
- [x] Settings: music and SFX volume sliders, reduced motion, graphics hint. Saved to the
      profile.
- [x] The same panel frame, title bar, close button, tabs and buttons everywhere, from
      `art/ui/`.

### E. Cards (brighter and fancier as value goes up)
- [x] **Common:** clean silver frame, soft shadow.
- [x] **Rare:** bright blue frame plus a periodic shine sweep.
- [x] **Epic:** purple frame plus an animated gradient glowing border.
- [x] **Legendary:** gold frame, sparkle particles, pulsing glow.
- [x] **Mythical:** rainbow animated frame, holo-foil shimmer overlay, floating particles.
- [x] **Golden copies:** gold-foil overlay on top of any rarity.
- [x] **Level** shown as stars or a badge. Level 15 adds a crown and a stronger glow.
- [x] Rarity banner in its colour, big readable stats, family icon. Bold colourful design, not
      flat panels.
- [x] **2.5D layered build:** background, character cutout, glow/VFX layer, frame. Parallax
      offset on hover/drag (PC) and press/tilt (mobile), drop shadow, rim light.
- [x] Used everywhere: inventory, inspect, deck, hatch reveal, battle, victory.
- [x] Only cards that are visible on screen animate.

### F. Characters (Blender pipeline, original characters only)
- [x] For every image the owner adds at `art/characters/<id>/front.png`: *(0 images added so far, so nothing to process yet. `scripts/art/characters.py` validates and applies card art; steps 1-4 need Blender's generators switched on, see docs/WAITING_ON_YOU.md 1-2.)*
  1. image-to-3D in Blender (Hyper3D Rodin or Hunyuan3D)
  2. clean up in Blender:
     - topology and proportions per `ART_STYLE.md` (6 heads tall)
     - cel-shaded materials
     - **under 10k triangles**, textures **1024 px or smaller**
  3. `auto_setup_avatar` to R15
  4. `generate_animation`: idle, attack, special, defend, hit, KO, victory
  5. render, with a fixed camera and lighting rig:
     - the card cutout (transparent background)
     - the portrait
- [x] Characters without an image yet keep a `TEMP` silhouette card and a `TEMP` rig, listed in
      `WAITING_ON_YOU.md`.
- [x] Never stack primitive parts into fake characters.
- [x] Each image the owner adds is picked up automatically on the next loop pass.

### G. Eggs (more types, better design)
- [x] Keep the 24 egg-pack eggs. Reference the files as supplied and **never edit them** (see
      the pack's License.txt).
- [x] Add new **original** egg types modelled in Blender in one consistent style, for example:
      Galaxy, Divine, Shadow, Celestial, Inferno, Crystal, Storm, plus seasonal/event eggs.
      Each one gets:
      - a rendered icon
      - a 3D display model on a glowing shop pedestal
      **Not built: CLAUDE.md locks exactly the 24 icon-pack eggs.** Waiting on the owner
      (docs/WAITING_ON_YOU.md 00); see the conflicts in docs/POLISH_LOG.md.
- [x] Every egg is data-driven in `Config/Eggs`, with its own character pool.
- [x] Every egg's exact odds are shown behind an **"Odds"** button.
- [x] Robux eggs come only from unlocked worlds. Golden eggs are earned only.
- [x] Every policy and odds test keeps passing.

### H. Egg opening (clean and satisfying)
- [x] Sequence: camera focus and blur, then the egg on a pedestal, then a shake that builds up,
      then spreading cracks, then light rays, then a burst in the rarity colour, then the card
      flips in with its frame, name, rarity banner and stats.
- [x] Bigger rarities get bigger moments:
      - **Legendary** adds slow-mo and a gold flash.
      - **Mythical** adds a rainbow shockwave and screen shake.
      - **Golden** eggs get a gold version of the whole sequence.
- [x] Open x1 / x3 / x8 (multi-open shows a grid reveal), a **Skip** button (tap to fast-forward),
      an auto-open toggle, and **"New!"** tags on first copies.
- [x] A sound for every beat: shake, crack, burst, and a reveal sound per rarity.
      (Ids filled in I; every beat heard firing in Play.)

### I. Music and sound
- [x] Use **only audio uploaded by the official Roblox account** in the Creator Store
      (licensed). Log every id in `docs/ASSETS.md`.
- [x] Music for the main menu, the lobby, each world and battles, plus victory and defeat
      stingers. Crossfade between areas.
- [x] SFX for:
      - UI: button hover and click, panel open and close, purchase, error
      - rewards: coin pickup, merge, level up
      - hatching: every beat, plus the card flip
      - battle: every action, KO, victory, defeat
- [x] Volume sliders in Settings, saved to the profile.

### J. Lobby and worlds
- [x] Every player spawns in the lobby after the main menu and after battles.
- [x] The Worlds portal opens the Worlds map. The **server** validates the unlock and moves the
      player.
- [x] 10 separate world maps under `Workspace.Worlds.World01..World10`, far apart, with
      StreamingEnabled. Each has its own terrain, props, sky, lighting preset, particles, music,
      spawn, farming nodes, merchant, Guardian Trial and a Back to Lobby portal. The client
      swaps the lighting preset on entry.
- [x] Themes:
  1. Green Plains
  2. Enchanted Forest
  3. Desert Kingdom
  4. Frozen Lands
  5. Volcano
  6. Demon Realm
  7. Celestial Islands
  8. Ancient Kingdom
  9. Shadow Dimension
  10. Divine World

### K. Final pass
- [x] Play through as a fresh player: join → main menu → PLAY → hatch → deck → battle →
      victory → world → farm and sell → back to the main menu. Fix anything that feels off.
- [x] Screenshots of every screen in `docs/screens/`.
- [x] Final report in `docs/POLISH_REPORT.md`:
      - what was built
      - before/after screenshots
      - scores
      - what's still `TEMP` and waiting on the owner
      - what was verified in Play mode
      - the next priorities

---

## 3. Rules the whole time

- Gameplay stays server-authoritative. Don't break existing systems.
- **Creator Store models:** delete every script inside, check the license, log them in
  `docs/ASSETS.md`.
- **Performance:**
  - animate only what's visible
  - few particles on mobile
  - under 10k triangles per character
  - StreamingEnabled
  - UI images 1024 px or smaller
- No published place, no Robux spending, no purchases, nothing irreversible outside the repo.
- Never claim something works unless it was tested in Play mode. If it was only checked in edit
  mode, say so.
