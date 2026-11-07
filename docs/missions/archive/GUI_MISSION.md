# GUI MISSION (step 4): a clean GUI, card frames, sound and motion, plus the portrait pack

The game's systems are done and tested (see `STATUS.md`). **This mission changes only how the
game looks, sounds and moves.** Don't rewrite gameplay, the economy, the server or the balance.
Every gameplay rule stays server-authoritative, exactly as now.

The owner's verdict on the current build: **"the GUI is so bad, even the GUI of the cards (not
the characters)."** Fix that first. It matters more than anything else in this file.

---

## 0. Read first

- `CLAUDE.md`, `STATUS.md`, `docs/WAITING_ON_YOU.md`, `docs/POLISH_REPORT.md`, `docs/ART_STYLE.md`,
  `ANIME_FOLDER.md`
- **References**, in `docs/brief/ui-refs/`. **These are the target.**

  | File | Screen |
  | --- | --- |
  | `01-main-menu.png` / `hd-01-main-menu.png` | Main menu |
  | `02-egg-shop.png` / `hd-02-egg-shop.png` | Egg Shop |
  | `03-inventory-card.png` / `hd-03-inventory-card.png` | Inventory + card inspect |
  | `04-deck-builder.png` / `hd-04-deck-builder-families.png` | Deck Builder + Families |
  | `05-arena-1v1.png` / `hd-05-arena.png` | 1v1 Arena |
  | `hd-06-victory.png` | Victory |
  | `hd-07-worlds.png` | Worlds |

  The `hd-` files are full-resolution crops of `docs/brief/concept-board.png`. Zoom into those for
  detail.

### Copy from the references
Layout, proportions, colours, glow, depth, font weight, button shapes, how dense each screen is,
and the overall "premium mobile game" feel.

### Never copy from the references
- **The characters on the cards and in the art:** Gojo, Itachi, Naruto, Luffy, and the Akatsuki
  cloak on the avatar. They're copyrighted, and every one of them is removed. Card art comes only
  from section 8 (the portrait pack) or from our own original art.
- **"Bet Amount":** no wagers (Roblox bans simulated gambling). The Arena shows league, trophies and
  the game-paid purse instead (section 6).
- **"Get a Legendary or better character!":** it reads as a guarantee on a random item. Write
  "Drops Common up to Legendary · see Odds".
- **"SSR" / "UR" labels:** our rarities are Common, Rare, Epic, Legendary, Mythical. Use our names
  or the letters C / R / E / L / M on the rarity badge.
- **"Trade":** it's V2 and not built. Leave it out of the menu (or show it disabled with "Soon").

---

## 1. Why the current GUI looks bad (fix these causes, not just symptoms)

Compare `docs/screens/step3/` and `docs/screens/final/` with the references and write down every
difference in `docs/GUI_AUDIT.md` before changing anything. The usual causes:

1. **Flat surfaces.** The references never use a flat fill. Every panel has a vertical gradient
   (lighter top, darker bottom), a thin neon border, an inner glow, an outer glow and a soft drop
   shadow.
2. **Weak hierarchy.** Titles are big, bold and white with a dark stroke; prices and power numbers
   are big and bold; labels are small. Ours are all similar sizes.
3. **Thin borders and no glow.** The references use 2-3 px bright borders plus a coloured glow
   around anything important (selected tile, featured egg, rarity frame).
4. **No icon plates.** Every panel title has a round icon plate on its left; every price has a coin
   icon; every stat has an icon.
5. **Low-resolution, code-drawn TEMP images.** These look cheap. Section 2 replaces them with a
   proper generated UI kit.
6. **Little motion.** The references feel alive: glows pulse, shine sweeps cross cards, eggs bob.
   Section 9 adds this.

---

## 2. Build a proper UI kit (no external art needed)

The owner has no UI artist, so **generate a high-quality UI kit with code** and render it as PNGs,
in `scripts/art/ui_kit.py` (Python + Pillow, or Blender renders for 3D-looking pieces).

**Technique:**
- draw at 4x size, then downsample (anti-aliased edges)
- real gradients and multi-layer glows (Gaussian blur)
- inner highlights and bevels
- 9-slice margins recorded per image
- export at the final size, 1024 px or smaller

Every piece replaces its `art/ui/temp/TEMP_*` stand-in. Keep the TEMP files only as a fallback.

| Piece | Look (match the references) |
| --- | --- |
| `panel` | Navy-to-indigo vertical gradient (#1B1640 → #0E0B26), 2 px violet border (#8B5CF6) with a soft outer glow, 14 px corners, faint inner top highlight |
| `panel_header` | Slightly lighter strip; room for the round icon plate on the left and the close button on the right |
| `icon_plate` | 56 px circle, violet gradient, white glossy rim. Holds the screen icon (egg, backpack, cards, swords, globe, star) |
| `close_button` | Dark circle, white bold X, a subtle red glow on hover |
| `button_gold` | Yellow-to-orange gradient (#FFD84A → #F59E0B), darker bottom lip (3D feel), glossy top highlight, dark-brown bold text with no stroke |
| `button_purple` | Violet gradient version for secondary actions (e.g. "Equipped") |
| `button_plus` | Small gold rounded square with a white "+" (next to currencies) |
| `pill_currency` | Dark rounded pill, thin border, icon socket on the left |
| `price_pill` | Dark pill with a coin icon and white bold number (bottom of egg and shop tiles) |
| `tile_<tier>` | Egg and item tile frames in 8 tiers (grey, blue, purple, gold, red, galaxy, divine, shadow): gradient fill, coloured border, inner glow in the tier colour |
| `tile_selected` | Brighter border, stronger glow, tiny corner sparkles |
| `featured_frame` | Large gold-bordered frame with a radial glow behind the item (featured egg / featured card) |
| `tab_on` / `tab_off` | Vertical side tabs, like Inventory (All / Cards / Items / Eggs) |
| `search_box` | Dark rounded field with a magnifier icon |
| `menu_row` | Left main-menu row: translucent dark bar, icon left, bold label, highlighted state with a violet glow bar on the left edge |
| `hint_pill` | Bottom hint bar with a trophy icon ("Reach World 2 to unlock more content!") |
| `vs_badge` | Large fiery "VS" (red-orange-yellow gradient, dark stroke, sparks) |
| `banner_victory` / `banner_defeat` | Gold winged "Victory!" with a crown; a cold steel "Defeat" |
| `glow_radial`, `shine_sweep`, `sparkle`, `light_rays` | FX images for section 9 |

**Card frames** are their own kit (section 3).

Icons: keep the licensed Free Icon Pack (unedited) for the HUD. For the panel-title icons, use the
same pack, placed on `icon_plate`.

**Fonts:** a heavy display font for titles and numbers (closest available Roblox font to the
references: bold, slightly condensed, e.g. Builder Sans Black, or Luckiest Guy for the logo and
banners), and Builder Sans Medium/Bold for body text. Titles and numbers get a 2 px dark stroke
(`UIStroke`).

---

## 3. Card GUI: the frame, not the character (top priority)

One card component in three sizes, the same design everywhere:
- **small:** inventory grid, hatch grid
- **medium:** deck slots, battle
- **large:** inspect, hatch reveal

### Layout, top to bottom (match `hd-03` and `hd-04`)
1. **Rarity badge**, top-left: a slanted, glossy badge with the letter C, R, E, L or M (or the
   name on large cards) in the rarity colour, white bold text with a stroke.
2. **Family icon**, top-right: a small glowing gem with the family icon.
3. **Art window:** the character portrait (section 8) on the family background. The portrait's
   head and shoulders fill about 70% of the card. A rim light in the family colour.
4. **Name plate**, large cards only: the character name, white bold, on a dark gradient band.
5. **Power plate**, bottom: a dark rounded plate with a gold sword icon and the card's power
   number, big, white, bold, with a stroke (like "950" in the references). Level stars sit just
   above the plate.
6. **Frame:** a thick bevelled border in the rarity colours, with an outer glow.

### Rarity escalation
Each step must look clearly more valuable than the one below.

| Rarity | Frame | Effects |
| --- | --- | --- |
| Common | Silver-grey bevel | Soft shadow only |
| Rare | Bright blue bevel, white inner line | Shine sweep every 4 s |
| Epic | Purple-magenta bevel | Animated gradient border + soft pulse glow |
| Legendary | Gold bevel with ornate corners | Sparkles + gold pulse glow + shine sweep |
| Mythical | Prismatic rainbow bevel, ornate corners | Holo-foil shimmer across the art + floating particles + rainbow rim |
| Golden copy | Gold foil overlay on top of its rarity | Extra glints |
| Level 15 | Crown on the rarity badge | Stronger glow |

### Rendering
- Render the frames in `scripts/art/card_kit.py` at 4x, then downsample, 9-slice-safe.
- Each frame is one image per rarity, plus separate glow/effect layers.
- The 2.5D layering stays: background, portrait, rim light, effects, frame. Use subtle parallax
  on hover, press or tilt.
- Animate only cards that are on screen (keep the current rule).

### Card screenshots for the owner
Save to `docs/screens/step4/cards/`:
- every rarity at small, medium and large size
- Golden copies
- level 15
- side-by-side with `hd-03`

---

## 4. Main menu vs in-game HUD (from `01-main-menu`)

### Main menu (shown after joining, and from the in-game menu button)
- **Background:** the real 3D lobby behind a slowly drifting cinematic camera: torii gate with the
  1v1 ARENA sign, the WORLDS portal glowing on the right, cherry trees, pagodas, a night sky,
  purple fog, petals. The player's avatar stands centre-left, seen from behind, as in the
  reference.
- **Top-left:** the **1v1 CARD** logo (big, with a crown, purple-to-pink gradient, heavy dark
  stroke, a splash behind it). Make it with the UI kit generator, as a PNG.
- **Top centre:** coin and gem pills with gold "+" buttons.
- **Top right:** three square icon buttons: Daily Rewards (gift), Quests/Calendar, Friends.
- **Left:** a vertical labelled menu: **Play** (gold, highlighted), Inventory, Deck, Shop,
  Quests, Settings. Each row is a big icon plus a bold label, with hover glow and a press
  animation.
- **Bottom centre:** the hint pill with a trophy ("Reach World 2 to unlock more content!",
  driven by real progress).
- No movement, no gameplay HUD. **Play** flies the camera into the character and starts the game.

### In-game HUD (after Play): minimal
- **Small icons only:**
  - a compact column of icon buttons on the left edge (Inventory, Deck, Shop, Worlds, Quests,
    Arena), with no labels and a tooltip on hover or long press
  - small currency pills at the top
  - a small **menu button** (top-left) that returns to the main menu with the reverse camera
    transition
- **Nothing else permanently on screen:** the quest tracker collapses to a small icon with a
  progress ring, and toasts appear and fade.
- Opening any panel follows the existing UiFlow rules (blur, input lock, one modal at a time).

---

## 5. Screens (each must sit side-by-side with its reference)

### Egg Shop (`hd-02`)
- **Header:** icon plate with an egg, "Egg Shop", close button.
- **Left:** a 4 × 2 grid of egg tiles:
  - egg name on top
  - big egg art centre with an idle bob and a glow in the tier colour
  - price pill at the bottom
  - a lock overlay with "World N" for eggs not unlocked yet
  - tabs or arrows to page through all 24 eggs (grouped by world)
- **Right featured panel:**
  - egg name in gold
  - big egg with a radial glow and a crown flourish, slowly rotating or pulsing
  - "Drops Common up to Legendary · see Odds"
  - big price
  - the gold **Buy** button with **x1 / x3 / x8**
  - an **Odds** button with exact percentages (existing system)
  - the Robux button, shown only when the `PaidRandomItemsAllowed` attribute is true (existing
    rule)
- The selected tile is highlighted, and the featured panel animates to the new egg.

### Inventory + card inspect (`hd-03`)
- **Header:** backpack icon plate, "Inventory", search box, storage count "12 / 50" with a gold "+".
- **Left tabs:** All, Cards, Items, Eggs, Others.
- **Grid:** small cards, plus egg and item tiles in tier frames.
- **Inspect panel on the right** (or popup on phones):
  - the large card
  - name, rarity pill, family
  - a one-line description
  - Power, Health and Skill rows with icons
  - Family Bonus lines in green
  - buttons: Equip / Equipped (purple), Merge, Sell

### Deck Builder + Families (`hd-04`)
- **Deck Builder:**
  - three medium card slots with the power numbers
  - "Deck Power: 2,770" (big, with a green up-arrow when it improves)
  - the active family bonus chip with its icon and "+2%"
  - the gold **Save Deck** button
  - empty slots show a dashed glowing outline with a "+"
- **Families panel:** a two-column list of all 15 families with their icons. Active families
  glow; inactive ones are dimmed. Footer: "Collect more cards to activate bonuses!" with a
  crown.

### 1v1 Arena (`hd-05`)
Keep the layout; replace the bet area.
- **Left:**
  - league badge and name
  - trophies
  - "Win purse: +360 coins" (`Economy.Matches.purseByLeague`)
  - the level cap for the league
  - the big gold **Find Match** button, which becomes a queue timer and Cancel while searching
- **Right:** a split "VS" scene: the player's lead card art on the left with a purple aura, and
  on the right the opponent (a dark "?" silhouette with a red aura while searching, their lead
  card when found), with the fiery VS badge between them.

### Victory / Defeat (`hd-06`)
- **Victory:** the winged gold "Victory!" banner with a crown, "You won the match!", reward chips
  (coins, trophies) counting up, and a gold **Continue** button. The winner's card art behind,
  with light rays.
- **Defeat:** the same layout in cold steel colours, smaller rewards, and an encouraging line.

### Worlds (`hd-07`)
A horizontal strip of 10 tall world cards with art, number and name:
- **unlocked:** bright, with a green "Completed" tick when cleared
- **locked:** darkened with a lock and the trophy requirement
- the current world is highlighted

### Everything else
Quests, Daily Rewards, Settings, Merchant, Queue, Battle UI and the KO picker get the same kit:
the same panel, header, icon plate, buttons and pills.

---

## 6. Rules for every screen
- **One system:** the same panel, header, close button, buttons, pills, fonts and spacing (8 px
  grid). No one-off styles.
- **Phone-first:**
  - test at 1334×750 (phone landscape), 750×1334 (phone portrait), 2048×1536 (tablet) and
    1920×1080 (PC)
  - tap targets at least 44 px
  - respect safe areas
  - panels become full-screen sheets on phone portrait
- **No text overflow, no emoji, no default Roblox-looking widgets.**
- **Performance:**
  - images 1024 px or smaller
  - reuse images
  - animate only what's visible
  - pause effect loops when a panel is closed
  - stay under about 300 visible GuiObjects per screen

---

## 7. Sound: every interaction has one

Use the existing `Config/Sounds` slots and licensed ids (APMOfficial / ProSoundEffects, or the
official Roblox account). Add any missing slots:

| Event | Sound |
| --- | --- |
| Button hover | Soft tick, very quiet |
| Button press | Click, with a ±5% random pitch |
| Primary button (Buy, Play, Find Match, Save Deck) | A fuller "confirm" |
| Panel open / close | Whoosh up / whoosh down |
| Tab switch | Light tick |
| Error / not enough coins | Soft buzz |
| Currency gained | Coin chime, with a rising pitch for big amounts |
| Purchase | Cash register / chime |
| Egg: select, shake, crack, burst, reveal | One per rarity, rising in excitement |
| Card hover, flip, equip, merge, level up | Each its own |
| Matchmaking | Searching loop, match found |
| Battle | Attack, defend, special, hit, KO |
| Victory / defeat | Stingers |
| Toast / notification | Ping |

- Play every sound through one `Sfx` module, with volume from Settings.
- No two identical sounds within 50 ms (debounce).
- List every id in `docs/ASSETS.md`.
- Claude can't hear audio, so mark each new pick "unreviewed" for the owner.

---

## 8. Portrait pack → card art

**Source:** `C:\Users\Administrator\Desktop\Ultimate Multi-Expression Portrait Pack — 320+ Free
Anime Expressions`. It has 40 sheets: 10 characters × 4 sheets, about 6-8 expression heads per
sheet, 1024 × 1024, transparent.

### 8.1 License gate
- Copy the pack, **unchanged**, to `art/anime/portrait-pack/original/`.
- The pack has **no license file**. Use it in development, flagged `TEMP_UNLICENSED` in
  `Config/ContentStatus`, so the release validator refuses to ship it.
- Add a line to `docs/WAITING_ON_YOU.md`: "Put the portrait pack's license, or the link to its
  download page showing commercial use is allowed, in
  `art/anime/portrait-pack/LICENSE.txt`."
- When that file exists and allows commercial use, remove the flag.

### 8.2 Fix the images: the processed copies, never the originals
Write `scripts/art/portrait_pack.py` that writes to `art/anime/portrait-pack/processed/`:
1. **Cut out every head:** split each sheet into its separate faces using alpha connected
   components, merge pieces that belong to one head, drop fragments.
2. **Clean the edges:** remove fringe and halo pixels on the alpha, close small holes, apply a
   1 px feather.
3. **Upscale 2x** with an anime-tuned upscaler if one installs cleanly (Real-ESRGAN anime model);
   otherwise Lanczos plus a light unsharp mask. Final size 768 px on the long side.
4. **Unify the style** so the 10 characters match each other:
   - the same colour grade (contrast and saturation curve)
   - a thin dark outline around the cutout
   - consistent head size and position per crop
   - the black-and-white and sketchy sheets get a subtle tint in their family colour so they sit
     on coloured cards
5. **Keep it all-ages:** crop every portrait at the shoulders/upper chest. The Demon Queen sheets
   need the tightest crop (head and shoulders only).
6. **Tag the expressions:** for each face, pick the closest of neutral/confident, attack (shout),
   hit (pain), KO (dazed or sad), victory (smile or laugh). Write
   `processed/<character>/<expression>.png` and a `processed/index.json`.
7. **Contact sheet:** save `docs/screens/step4/portraits_contact.png` showing all 10 characters
   with their chosen expressions.

### 8.3 Map the 10 to roster characters
Pick 10 existing characters from `Config/Characters` by family (and a good role). Suggested
families:

| Pack character | Family |
| --- | --- |
| Demon Queen | Demon |
| Vampire Boy | Shadow |
| Gothic School Girl | Mystic |
| Chaotic Jester | Royal (court jester) |
| Cute Catgirl | Beast |
| Cyberpunk Boy | Lightning |
| Fantasy Elf Girl | Spirit |
| Space Pilot Girl | Cosmic |
| Post-Apocalyptic Girl | Warrior |
| Angelic Idol | Divine |

- Spread them across rarities so the hatch shows the escalation: some Common, some Rare, at least
  one each of Epic, Legendary and Mythical.
- Update only each chosen character's `look` text (and display name, if it no longer fits), so
  the brief matches the art. Ids stay, so saves are safe.
- Stats and balance don't change.
- Write the mapping to `art/anime/portrait-pack/map.json`.

### 8.4 Use them
- **Card art:** the neutral/confident portrait is the art window on every card size, and on the
  battle standee for those 10 characters.
- **Battle reactions:** a small 2.5D portrait pops up beside the HP bar with the matching
  expression on attack, hit, KO and victory. This is short and snappy: about 0.6 s, a slight
  bounce, with the hit shake.
- **Remove every other character image now on cards,** including any leftover test images and
  the three reference characters (Gojo, Itachi, Naruto) if they appear anywhere. The other 90
  characters keep the TEMP silhouette (now drawn in the new card frame) until their art arrives.
- Upload through the Studio MCP and record the ids in the existing art scripts
  (`scripts/art/characters.py`).

---

## 9. Animation: every screen feels alive

Put all timings in one `Motion` module; respect `settings.reducedMotion`.

| Element | Motion |
| --- | --- |
| Panel open | Scale 0.92 → 1, fade in, 0.25 s, back-out; background blur in |
| Panel close | Scale 1 → 0.95, fade out, 0.15 s |
| Tiles and cards in a grid | Staggered pop-in, 25 ms apart |
| Button hover | Scale 1.04, glow brightens, 0.1 s |
| Button press | Squash to 0.94, release with back-out |
| Gold buttons | Slow shine sweep every 5 s |
| Selected tile | Glow pulse (1.2 s loop) |
| Featured egg | Idle bob plus slow rotation; burst on selection change |
| Egg tiles | Gentle bob, out of phase with each other |
| Currencies | Count-up when they change, the pill pulses, "+N" floats up |
| Deck Power | Count-up, with a green arrow flash when it improves |
| Notification dots | Small bounce every few seconds |
| Toasts | Slide in from the top, auto-dismiss |
| Main menu → game | Camera fly-in (1.2 s), HUD icons drop in one by one |
| Game → main menu | Reverse transition |
| VS screen | Both sides slide in, VS badge slams with a screen shake and sparks |
| Victory | Banner drops with a bounce, rays rotate, rewards count up |
| Cards | Parallax tilt; rarity effects from section 3 |

---

## 10. The loop

Order: section 1 → 2 → 3 → 8 → 4 → 5 (Egg Shop, Inventory, Deck, Arena, Victory, Worlds, then
the rest) → 7 → 9 → the final pass.

For each item:
1. Build it.
2. Test it in **Play mode** at the four sizes (section 6).
3. `screen_capture` the result, then make a **side-by-side comparison image** (reference on the
   left, ours on the right) at `docs/screens/step4/compare_<screen>.png`.
4. Score it 1-10 on:
   - matches the reference
   - visual quality (depth, glow, gradients)
   - readability
   - animation feel
   - consistency

   If any score is below 8, list the differences, fix them, and repeat.
5. Run the headless tests, StyLua, Selene, luau-lsp and the Rojo build. Fix every failure.
6. Commit (the message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`).
7. Log the scores and the comparison image paths in `docs/POLISH_LOG.md`.
8. Tick the item in the checklist below.

Never stop to wait for the owner. Put anything you need from them in `docs/WAITING_ON_YOU.md`
and continue.

---

## 11. Checklist
- [ ] `docs/GUI_AUDIT.md` (section 1)
- [ ] UI kit generated, TEMP images replaced (section 2)
- [ ] Logo
- [ ] Card frames, all rarities, Golden, level 15, three sizes (section 3)
- [ ] Portrait pack processed, mapped, on cards and battle reactions; old character images
  removed (section 8)
- [ ] Main menu (section 4)
- [ ] Minimal in-game HUD plus the menu button (section 4)
- [ ] Egg Shop
- [ ] Inventory + inspect
- [ ] Deck Builder + Families
- [ ] Arena
- [ ] Victory / Defeat
- [ ] Worlds
- [ ] Quests, Daily, Settings, Merchant, Queue, Battle UI, KO picker restyled
- [ ] Sound on every interaction (section 7)
- [ ] Motion everywhere (section 9)
- [ ] Final pass: a fresh player goes through menu → play → shop → hatch → inventory → deck →
  arena → battle → victory → worlds → menu, at phone and PC sizes. Fix anything that feels off.
- [ ] Report: `docs/GUI_REPORT.md`, with every comparison image, the scores, what's still TEMP,
  and what needs the owner

## 12. Don't
- Don't change gameplay, balance, odds, prices or server code (except to expose data the UI
  needs, read-only).
- Don't use any existing anime or franchise characters, names or art, or anything from
  `github.com/Sidmaz666/character-dataset`.
- Don't edit the original files of third-party packs. Process copies only.
- Don't publish, spend Robux or buy anything.
- Don't claim something works unless it was tested in Play mode.
