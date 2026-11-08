# 1v1 CARD: MASTER MISSION

**This is the only mission file.** It replaces `POLISH_MISSION.md`, `GUI_MISSION.md` and
`CARDS_EGGS_MISSION.md`. Everything still wanted from them is merged in here.

**First step:** move those three files to `docs/missions/archive/` (keep them for history) and
commit.

**Goal:** the game must look, sound and flow like a polished Roblox front-page game:
- a clean, light in-game screen
- beautiful cards and eggs
- smooth animation and sound everywhere
- a clear four-screen flow (launch loading → main menu → playing, with a leaving screen between
  playing and the menu)

Gameplay, economy, odds, balance and server rules stay as they are, unless this file names a
change.

---

## 0. Read first

- `CLAUDE.md`, `STATUS.md`, `HANDOFF.md`, `docs/WAITING_ON_YOU.md`, `docs/ART_STYLE.md`,
  `ANIME_FOLDER.md`
- **References (the targets):**
  - `docs/brief/ui-refs-3/01-ingame-hud.png`: **how the screen looks while playing** (section 3)
  - `docs/brief/ui-refs-2/01..08`: eggs, egg opening, cards with and without art, card stats,
    rarity frames, card animations, rarity ladder
  - `docs/brief/ui-refs/` and `hd-*`: main menu, Egg Shop, Inventory + inspect, Deck + Families,
    Arena, Victory, Worlds
  - `docs/brief/concept-board.png`: overall mood

**From the references, copy:** layout, proportions, colours, glow, depth, the chunky icon
buttons, font weight, density and motion. **Never copy:**
- **The characters in them:** the anime heroes on the cards, the Akatsuki cloak, the Goku-like
  cards in the HUD reference. They are copyrighted.
- **The "Bet Amount" panel:** there are no wagers.
- **"Get a Legendary or better":** it reads as a guarantee on a random item.
- **"Rebirth" / "Trade":** neither is a V1 feature.

---

## 1. Hard rules (always)

1. **Original characters only.** Never use existing anime, game or franchise characters, names or
   art, including `github.com/Sidmaz666/character-dataset`.
2. **Licenses:**
   - **Egg Icon Pack v2 (Basic)** (`C:\Users\Administrator\Desktop\Eggs Icon Pack v2 (Basic)`,
     by @gvesster): commercial use is allowed, **editing is not** for a commercial game. Use every
     egg **unedited**. Glows, cracks, shards and frames are separate layers drawn over or behind
     it. Never recolour, redraw or merge it into another image. Credit @gvesster on a Credits
     screen in Settings.
   - **Free Icon Pack** (HUD icons): unedited, as now.
   - **Portrait pack:** `TEMP_UNLICENSED` until the owner adds `LICENSE.txt` (section 12).
3. No wagers, no stakes. The 1v1 purse is paid by the game.
4. Odds are shown exactly. The result is decided on the server before any animation, and no
   animation pretends a different result.
5. Server-authoritative. Every new remote goes through `Server/Net/Dispatcher`, with a parser,
   rate limit and tests.
6. Don't publish, spend Robux or buy anything. Don't claim anything works without a **Play-mode**
   test.

---

## 2. Screen flow: four screens, and a clean reset (do this first; it fixes bugs)

### 2.1 The four screens
| # | Screen | When | How you leave it |
|---|---|---|---|
| 1 | **Launch loading** | Only when the game starts. **No button or path ever returns to it.** | Automatically, when loading finishes → 2 |
| 2 | **Main menu** | After 1, and whenever the player chooses "Main Menu" | **PLAY** → 3 |
| 3 | **Playing** | The game itself (lobby, worlds, panels, battles) | Menu button → 4 → 2 |
| 4 | **Leaving** | A short transition shown when quitting from 3 | Automatically → 2 |

### 2.2 Screen 1: launch loading
- **A full-screen loading GUI with a card animation:**
  - the 1v1 CARD logo
  - a fan of card backs that shuffle and flip, showing rarity frames (N → UR) one after another
  - a progress bar with a percentage
  - a rotating tip line ("Tip: Defend parries a Special!")
- **Really preloads** with `ContentProvider:PreloadAsync`:
  - every UI image in the manifest
  - egg icons, card frames, fonts
  - the main-menu music and core SFX
- The progress bar reflects the real preload progress, plus the wait for the server profile
  (`ProfileLoaded`).
- Minimum display 1.5 s (no flash); timeout safety at 20 s (continue anyway, log it).
- Hide the default Roblox loading screen (`ReplicatedFirst` + `RemoveDefaultLoadingScreen`), so
  ours shows immediately.
- At the end, the cards fly apart and fade into the main menu.

### 2.3 Screen 2: main menu
As `ui-refs/hd-01-main-menu`:
- the 3D lobby behind a drifting cinematic camera
- the logo top-left
- currencies at the top
- three icon buttons top-right (Daily, Quests, Friends)
- a left labelled menu: **PLAY**, Inventory, Deck, Shop, Quests, Settings
- the hint pill at the bottom

Rules on this screen:
- No character control, no gameplay HUD.
- The menu panels (Inventory, Deck, Shop, Quests, Settings) work here too.

### 2.4 Screen 3: playing (and the 1v1 return bug)
- **PLAY from the main menu always starts fresh**, like rejoining:
  - the server spawns the character at the **lobby spawn**
  - nothing carries over (no open panels, no queue, no old world)
  - camera fly-in, then the in-game HUD (section 3) drops in
- **After a 1v1 or a Guardian Trial**, the player returns to **the exact place they were before
  the battle**, in the same world. **This is the bug to fix:** today they go to the lobby.
  - The server saves `{worldId, CFrame}` when the battle starts, and restores it when the battle
    ends.
  - If that spot is no longer valid (world locked, out of bounds), fall back to that world's
    spawn, then to the lobby.
  - Ranked battles on another server: pass the saved spot in the teleport data and restore it on
    arrival. If it's missing, use the lobby.
  - Add tests (pure function for choosing the return spot) and a Play-mode check (stand
    somewhere in World 1, fight a Guardian Trial, come back to the same spot).

### 2.5 Screen 4: leaving
- Triggered by the in-game **Menu** button, after a small confirm ("Return to the main menu?").
  During a battle, the confirm says the battle counts as a **forfeit**.
- Shows a short leaving screen (about 1 s): darken, the logo, "Returning to menu…", a spinner made
  of a flipping card.
- **Resets the session cleanly, like quitting:**
  - close every panel, cancel the queue
  - forfeit any battle (the server's normal forfeit path)
  - stop world music and effects
  - clear temporary client state
  - the server removes the character (or parks it), marks the player "in menu", and saves the
    profile
- Then screen 2. Pressing PLAY again goes to the lobby, as in 2.4.
- Add a server state `menu | playing | battling` per player:
  - matchmaking, farming and travel refuse players in `menu`
  - remotes check it
  - add tests

### 2.6 Flow checklist
- [x] Launch loading with the card animation and real preload
- [x] Main menu as the only path to playing
- [x] PLAY → lobby, fresh
- [x] Battle → back to the saved spot (1v1, Trial, cross-server fallback)
- [x] Menu → leaving screen → main menu, with a full reset
- [x] No path back to screen 1
- [x] Specs plus Play-mode screenshots `docs/screens/flow/01..06`

---

## 3. In-game HUD: clean, light, little text (`ui-refs-3/01-ingame-hud.png`)

The owner says the current in-game GUI is **too big, too heavy and too navy blue**. While
playing, the screen must stay mostly game world, like top Roblox games.

### 3.1 Layout
- **Left:** a **2 × 3 grid of chunky square icon buttons**. Each is a bright, colourful,
  rounded square with a thick dark outline and an inner highlight, and a big icon. **No labels**
  (tooltip on hover or long press). Each button has its own colour, as in the reference:
  - Inventory (red, backpack)
  - Shop/Eggs (orange, egg)
  - Deck (teal, cards)
  - Daily/Gift (green, gift)
  - Worlds (purple, globe)
  - Settings (blue, gear)
  - the Menu button (small, top-left corner, separate)
- **Top right:** two big currency bars, coins (gold coin icon, amount, gold "+") and gems
  (diamond, amount, blue "+"). Amounts are short-formatted: 1.04K, 12.5K, 1.2M.
- **Bottom centre:** the **deck bar**, the 3 equipped cards as small cards:
  - each with its rarity frame, art (or template), "Lv. N" and stars
  - a slot number 1-3 in the corner
  - tapping one opens the Deck
- **Right:** a **compact quest tracker card**: title, "0/2", up to two task rows with a check box
  and a thin progress bar. It collapses to a small trophy icon with a ring when the player taps
  it or after 10 s idle.
- **Arena:** a single 1v1 icon button (crossed swords) above the deck bar, or in the grid if
  there's room.

### 3.2 Style rules while playing
- Bright, saturated, playful colours (orange, red, green, teal, purple, gold) and thick outlines,
  like the reference. **No big navy panels while playing.**
- **Minimum text.** Show a word only where an icon can't say it: currency amounts, levels, quest
  lines. No titles, no explanations, no permanent hints.
- **Small footprint:** the HUD never covers more than about 20% of the screen. Buttons are 64-72
  px on PC, 56 px on phone, and never smaller than 44 px.
- **Panels are smaller and lighter:**
  - when opened from the HUD, they take at most about 70% of the screen on PC (full sheet on
    phone portrait)
  - a lighter glass style (more transparency, brighter border)
  - the deep navy look stays only on the main menu and the big showcase screens (egg opening,
    card preview)
- Notification dots on buttons with claimable rewards.
- Toasts are small and short (2 s), from the top centre.
- **Battle hides this HUD completely** and shows only the battle UI.

### 3.3 HUD checklist
- [x] Square icon grid
- [x] Currency bars
- [x] Deck bar
- [x] Compact quest tracker
- [x] Menu button
- [x] Lighter panel style
- [x] Less text everywhere
- [x] Side-by-side `docs/screens/hud/compare_ingame.png` (reference vs ours), scoring 8+

---

## 4. Visual language and UI kit

### 4.1 Values (measured from the boards)
| Element | Value |
| --- | --- |
| Menu/showcase background | Deep navy-violet #06061B → #0D0B26, purple haze |
| Common (N) | Silver #F0F0F0, shadow #9080C0 |
| Rare (R) | Blue #0080F0 → #00A0F0 |
| Epic (SR) | Violet #9B4DFF → #E090F0 |
| Legendary (SSR) | Gold #F0C010 → #F0D030 |
| God-tier (UR) | Emerald #00C070 → #00D080 |
| Gold buttons | #FFD84A → #F59E0B, a darker bottom lip, glossy top, dark-brown bold text |
| Type | Heavy bold sans for titles and numbers (white, 2 px dark stroke); italic heavy display font for rarity badges; Luckiest Guy (or closest) for the logo and banners |

### 4.2 Fix the causes of the "bad GUI"
Write `docs/GUI_AUDIT.md` first: compare the current screens with every reference and list each
difference. The usual causes:
- flat fills
- weak type hierarchy
- thin borders without glow
- no icon plates
- cheap, low-resolution TEMP images
- too little motion
- (while playing) panels that are too big and too dark

### 4.3 How to produce assets at reference quality
| Route | Use for | How |
| --- | --- | --- |
| **B: Blender renders** (main route) | Card frames, badges, crowns, stars, gems, pedestals, shards, the summoning circle, the logo | `art/blender/ui_studio.blend`: an orthographic camera per asset type, a fixed 3-point light rig, emissive materials, Eevee with Bloom, transparent film, render at 2-4x then downsample. A batch render script in Blender. |
| **C: code / Pillow** | Gradients, glow sprites, particles, bars, pills, simple shapes | `scripts/art/ui_kit.py`, drawn at 4x with multi-layer Gaussian glows |
| **O: owner AI images** | Optional painted upgrades | Prompts in `art/ui/PROMPTS_V2.md` (write them). The pipeline swaps the images in when they appear. |

- Every asset goes in `art/ui/MANIFEST_V2.json`: slot, file, size, 9-slice, route, `TEMP` or
  `FINAL`, asset id.
- Images are 1024 px or smaller. Small sizes are rendered separately, never just scaled down.
- Upload in batches through the Studio MCP.
- Replace every `art/ui/temp/TEMP_*` stand-in.

### 4.4 Kit pieces
- **Showcase and menu panels:** a gradient glass panel, a header with a round icon plate, a title
  plus a subtitle (for example "Egg GUI / Collect Powerful Eggs"), a dark round close button.
- **Light in-game panels:** section 3.2.
- **Buttons:** gold primary, purple glass secondary (icon + label, like the card-stats buttons),
  small gold or blue "+".
- **Square HUD icon buttons:** six colours, thick outline, inner highlight (section 3.1).
- **Pills:** currency, price (coin icon), label (rarity-coloured border).
- **Tiles:** item and egg tiles in tier colours, plus a selected state with a stronger glow and
  corner sparkles.
- **Other pieces:** tabs, search box, menu rows, hint pill, toast, VS badge, Victory and Defeat
  banners.
- **FX sprites:** radial glow, shine sweep, sparkle, light rays.
- **The logo:** "1v1 CARD", with a crown and a purple-pink gradient, made with route B or C.

---

## 5. Rarity display (config only; ids and saves don't change)

Add display fields to `Config/Rarities`. Every UI reads them; no hard-coded colours.

| Internal | Badge | Display name | Colour | Emblem |
| --- | --- | --- | --- | --- |
| Common | N | Common | silver | star |
| Rare | R | Rare | blue | star |
| Epic | SR | Epic | violet | crown |
| Legendary | SSR | Legendary | gold | crown |
| Mythical | UR | God-tier | emerald | crown |

The Odds panel shows the badge and display name (for example "UR · God-tier 0.5%"). The maths
doesn't change.

---

## 6. Cards

### 6.1 Rarity frames (`ui-refs-2/04`)
- Per rarity, separate layers:
  - `frame_<r>`: ornate bevelled metal, pointed corner flourishes, a diamond gem at the top and
    bottom centre, a thin inner line
  - `frame_<r>_glow`: outer glow
  - `frame_<r>_energy`: crackling lightning strokes
  - `badge_<r>`: italic N / R / SR / SSR / UR
- **Sizes:** large 512 × 704, medium 256 × 352, small 128 × 176. Small sizes are simpler.
- **Escalation:** N is plainest; UR is the most ornate, with the strongest energy.
- `overlay_golden` adds foil for Golden copies.
- **Route B.**

### 6.2 Card without character (`ui-refs-2/06`)
The default for every character without art. It replaces the TEMP silhouettes.
- the frame
- a dark violet inner panel with a faint pattern
- a big glowing emblem (star for N and R, crown for SR and up)
- a name plate, "Lv. N", ATK (sword) and DEF (shield) chips, the family gem, the badge

### 6.3 Card with character (`ui-refs-2/03`)
- the badge top-left, overlapping the frame
- a crown top-right (SR and up)
- the art filling the window, with a vignette and rarity-coloured energy FX behind it
- the name (white, bold, stroke) and the rarity name in its colour
- "Lv. N" bottom-left, ATK and DEF bottom-right
- the 2.5D layers and parallax stay

### 6.4 Card stats panel (`ui-refs-2/05`)
- **Header:** crown icon, name, rarity name in its colour.
- **Level:** "Lv. N / max" and a real merge-progress bar ("x / y").
- **Stats:**
  - big ATK and DEF
  - an HP and SPD row
  - real numbers from `Cards.statsAt`, with K or M only above 9,999
- **Abilities:** the special (with its energy cost) and the passive, using the real text from
  `Config/Characters`.
- **Family bonus:** shown when it's active.
- **Buttons** (purple glass, icon + label):
  - **Upgrade:** the merge flow.
  - **Evolve:** shows the stages (6.6) and what the next stage needs.
  - **Equip:** Deck.Set.
  - **Favorite:** a heart toggle. Favourite cards can't be sold or merged. This is a new
    `favorite` flag plus a validated `Cards.SetFavorite` remote; Sell and Merge refuse favourites.
    Add tests.
  - **Preview:** a full-screen rotating showcase with the aura.

### 6.5 Card animations (`ui-refs-2/07` and more)
- **Aura:** N none, R blue, SR purple, SSR gold with an orbiting light ribbon, UR emerald with a
  ribbon and rising motes.
- **Glow pulse** (1.5 s), **energy flicker**, a **shine sweep** every 4-6 s (R and up), and
  **particles** (sparkles for SR, embers for SSR, motes for UR).
- **Hover:** lift and a brighter aura. **Equip:** the card flies to its slot with a trail.
  **Level up:** a ring burst and the bar filling. **Golden:** glints.
- **Performance:** animate only visible cards. Grids pause their auras until hovered. At most
  about 6 large animated effects on screen.

### 6.6 Evolution stages (the locked max level is 15)
The thresholds go in `Config/Progression.evolutionStages`, so changing the max level later is a
config edit.

| Stage | Levels | Look |
| --- | --- | --- |
| Base | 1-4 | Normal |
| Awakened | 5-9 | Brighter frame, extra gems, a faint aura even when small |
| Ascended | 10-14 | Animated frame energy, gold inner line, a stronger aura |
| Max | 15 | Crown on the badge, a "MAX" ribbon, the strongest aura, a special shine |

### 6.7 Cards everywhere
One component in three sizes. The same card appears in:
- the shop, the hatch, inventory and inspect
- the deck and the in-game deck bar
- battle, the KO picker and results

---

## 7. Eggs: the Egg Icon Pack is the game's egg art

### 7.1 Use the pack fully
- Source: `C:\Users\Administrator\Desktop\Eggs Icon Pack v2 (Basic)`. It has 24 eggs (Angel,
  AngelDemon, Basic, Black Hole, Cat, Coconut, Cracked, Demon, Dog, Dominus, Dragon, Glitched, Ice,
  Kraken, Legendary, Mine, Mythical, Party, Rainbow, Royal, Sandcastle, Secret, Spotted, Yeti),
  each in normal and Golden versions, at 256 px and 64 px.
- Copy the pack unchanged to `art/eggs/pack/`, including `License.txt`.
- Every egg in `Config/Eggs` uses its pack icon, **unedited**:
  - the 256 px version for big views
  - the 64 px version for small tiles, the bag and toasts
  - the Golden version for Golden eggs
- Upload any icons not uploaded yet and record the ids.
- **Display size limit:** the icons are 256 px, so never show one bigger than about 260 px on a
  1080p screen (scale the layout so it stays sharp). Make big moments feel big with glow, rays
  and pedestals behind and around the egg, not by stretching it.
- **Tier styling:** each egg gets a tier from its odds band (Common / Rare / Epic / Legendary /
  God-tier). The tier sets the colour of its pedestal, glow, label pill and summoning circle, as
  in `ui-refs-2/01`. The egg image itself is never changed.
- **Don't** build Blender egg models. The pack is the egg art. (This replaces the earlier Blender
  egg plan.)
- In-world egg stall: show each egg as an upright image (`BillboardGui`/`SurfaceGui`) on a
  Blender-made 3D pedestal with an emissive tier ring.

### 7.2 Egg Shop (`ui-refs-2/01`, `ui-refs/hd-02`)
- **Header:** egg icon plate, "Egg Shop", subtitle "Collect Powerful Eggs", close.
- **Egg row:** eggs on tier pedestals in a scrollable row, grouped by world, each with:
  - its label pill (name, in the tier colour)
  - its price pill
  - an idle bob and glow
  - a lock overlay with "World N" when locked
- **The selected egg** rises, its ring brightens, and the details panel shows:
  - the egg (up to 256 px)
  - its name and tier
  - "Drops Common up to <real top rarity> · see Odds"
  - the price
  - **Open x1 / x3 / x8** (gold)
  - **Odds**
  - **Auto-open**
  - the Robux button only when the policy allows it
- **Egg Bag tab:** owned eggs, their counts, Golden markers, and Open buttons.
- **Credits:** @gvesster in Settings → Credits.

### 7.3 Egg opening: five stages (`ui-refs-2/02`)
Everything is tinted with the **real** rarity being revealed. The server decides first.

| # | Stage | What happens | Time |
|---|---|---|---|
| 1 | **Summon** | The screen dims and blurs. The pack egg image rises out of a glowing summoning circle (rotating runes, ring pulses). The camera pushes in. | 0.9 s |
| 2 | **Crack** | The egg shakes in rising pulses. **Crack overlay sprites** (our own art, drawn on a separate layer over the unedited egg) spread out. The glow shifts toward the rarity colour. | 1.0 s (+0.4 s slow-mo for SSR and up) |
| 3 | **Break** | The egg image hides. **Our own shard sprites**, tinted to the tier, burst outward, with a light flash, a shockwave ring and a short screen shake. | 0.5 s |
| 4 | **Reveal** | The character's silhouette stands in a rising aura of the rarity colour with light rays. The badge slams in. | 0.8 s (UR: +0.6 s with an emerald light pillar) |
| 5 | **Get Card** | The silhouette becomes the card, which flips in. A "NEW!" sticker or "+1 copy". The name and the rarity name. Confetti for SSR and up. Buttons: Continue, Open Again, Equip (if new). | until tapped |

- **Multi-open:** stages 1-3 together; stage 4 shows a row of silhouettes; stage 5 flips the cards
  one by one, or all at once on tap, into a grid.
- **Skip:** tap to jump to stage 5.
- **Golden:** a gold circle, gold shards, a Golden card overlay.
- **Sound:** one per stage (section 9).

### 7.4 Silhouettes
Each character's silhouette comes from its processed art (black fill plus a rim light in the
rarity colour). Characters without art use a silhouette for their role.

---

## 8. Other screens (match their references, use the kit)

- **Inventory + inspect** (`hd-03`):
  - tabs All, Cards, Items, Eggs; search; storage count with "+"; a grid of small cards
  - the inspect view uses the stats panel (6.4) and the large card
- **Deck Builder + Families** (`hd-04`):
  - **Deck Builder:** three medium cards; "Deck Power" with a count-up and a green arrow when it
    improves; the family bonus chip; Save Deck; empty slots dashed with a "+"
  - **Families:** a two-column list; active families glow, inactive ones are dimmed
- **1v1 Arena** (`hd-05`, **no bet**):
  - **Left:** league, trophies, the win purse, the level cap, and Find Match (which becomes a
    queue timer and Cancel while searching)
  - **Right:** the player's lead card VS the opponent's silhouette (their lead card when the match
    is found), with the fiery VS badge between
- **Victory / Defeat** (`hd-06`):
  - **Victory:** the winged gold banner with a crown, reward count-ups, Continue (which returns
    to the saved spot, 2.4)
  - **Defeat:** the same in cold steel
- **Worlds** (`hd-07`): a strip of world cards with lock state, "Completed" ticks, and trophy
  requirements.
- **Restyle with the kit:** Quests, Daily Rewards, Settings (sliders and Credits), Merchant,
  Queue, Battle UI, the KO picker.

---

## 9. Sound: every interaction has one

Use licensed ids only (APMOfficial, ProSoundEffects, or the official Roblox account). Play
everything through one `Sfx` module, with the volume from Settings and a 50 ms debounce. Log
every id in `docs/ASSETS.md` as "unreviewed" (Claude can't listen to audio).

| Event | Sound |
| --- | --- |
| Hover | Soft tick |
| Press | Click (±5% random pitch) |
| Primary button | "Confirm" |
| Panel open / close | Whoosh up / down |
| Tabs | Tick |
| Error | Soft buzz |
| Coins gained | Chime, rising in pitch for big amounts |
| Purchase | Cash register / chime |
| Egg | Summon hum, crack ticks rising, shatter, a reveal swell per rarity, card flip, sparkle |
| Cards | Hover, flip, equip, merge, level up |
| Matchmaking | Searching loop, match found |
| Battle | Attack, defend, special, hit, KO, victory and defeat stingers |
| Flow | Launch-loading ambience, menu music, crossfade to lobby music on PLAY, leaving-screen whoosh |
| Toasts | Ping |

---

## 10. Motion

Put all timings in one `Motion` module, and respect `settings.reducedMotion`.

| Element | Motion |
| --- | --- |
| Panel open | Scale 0.92 → 1 and fade in, 0.25 s back-out |
| Panel close | 0.15 s |
| Grid items | Stagger in, 25 ms apart |
| Button hover | Scale 1.04 and glow |
| Button press | Squash to 0.94, then back-out |
| Gold buttons | Shine sweep every 5 s |
| Selected tile | Glow pulse |
| Eggs | Idle bob, out of phase with each other |
| Currencies | Count-up, pill pulse, "+N" floats up |
| Deck Power | Count-up |
| Notification dots | Bounce |
| Toasts | Slide in from the top |
| Main menu ↔ playing | Camera fly-in; HUD buttons drop in one by one; the leaving screen in reverse |
| VS | Both sides slide in, the badge slams, screen shake |
| Victory | Banner bounce, rotating rays, count-ups |
| Launch loading | The card shuffle and flip sequence (2.2) |

---

## 11. Extra assets (complete the set)

- **Stickers:** `sticker_new`, `sticker_max`, `sticker_dup`, `ribbon_max`
- **Gems:** `gem_family_<family>` × 15
- **Stat icons:** `icon_atk`, `icon_def`, `icon_hp`, `icon_spd`, `icon_energy`, `icon_passive`
- **Stats-panel buttons:** `icon_upgrade`, `icon_evolve`, `icon_equip`, `icon_favorite` (on/off),
  `icon_preview`
- **Level bar:** `bar_level_bg`, `bar_level_fill`, `bar_level_glow`
- **Egg opening:**
  - `summon_circle`, `summon_runes`, `pedestal_<tier>`
  - `crack_overlay_1..3`, `shard_set_<tier>`, `shockwave_ring`
  - `light_rays`, `light_pillar`, `confetti_set`
- **Card animations:** `aura_<rarity>`, `ribbon_orbit`, `sparkle`, `ember`, `mote`
- **Locks:** `lock_overlay`, `world_badge`
- **Cards:** `card_back_<rarity>` (also used in the launch loading animation), `empty_slot`
- **Filters, toasts, odds:** `filter_chip_<rarity>`, `toast_rarity_<rarity>`,
  `odds_row_<rarity>`
- **HUD:** six square HUD button backgrounds in their colours, `menu_button`, `quest_card`
- **Logo:** `logo_1v1card`

---

## 12. Phase 2: character PNGs

Start this after sections 2-11 are done, or blocked only by owner items.

### 12.1 Folders
```
art/characters/
  incoming/<batch>/              raw PNGs as supplied (never edited) + LICENSE.txt
  processed/<character_id>/      card.png (768 px tall, transparent), portrait.png, silhouette.png, expr_<name>.png
  map.json                       { "incoming/<batch>/<file>": "<character_id>" }
```

### 12.2 `scripts/art/characters.py` commands
- `ingest`: copy in; no license means `TEMP_UNLICENSED` (development only; the release validator
  refuses it) plus a line in `WAITING_ON_YOU.md`.
- `split`: cut sheets into faces with alpha connected components; merge parts, drop fragments.
- `clean`: remove fringe and halo, fill holes, 1 px feather, trim, normalise head size and
  position.
- `upscale`: Real-ESRGAN anime if available, otherwise Lanczos plus sharpening. Never more than 4x.
- `style`: one colour grade for all, a thin dark outline, a rim light in the family colour; tint
  black-and-white or sketchy art.
- `safe`: all-ages crops (head and shoulders where needed), plus a manual-review list.
- `map`: suggest matches by look, family and role. Change only a character's `look` text (and
  its display name if needed), never its stats or ids.
- `derive`: card, portrait, silhouette and expressions.
- `check`: sizes, transparency, no duplicates, and a contact sheet at
  `docs/screens/characters/contact_<batch>.png`.
- `upload` and `status`.

**Rules:**
- Reject anything that looks like an existing character.
- Keep the originals untouched.
- Each batch is styled to match the others.

### 12.3 First batch: the portrait pack
`C:\Users\Administrator\Desktop\Ultimate Multi-Expression Portrait Pack — 320+ Free Anime Expressions`
has 40 sheets of 10 characters, in head and shoulders.

- **Family mapping:**

  | Pack character | Family |
  | --- | --- |
  | Demon Queen | Demon (tightest crop) |
  | Vampire Boy | Shadow |
  | Gothic School Girl | Mystic |
  | Chaotic Jester | Royal |
  | Cute Catgirl | Beast |
  | Cyberpunk Boy | Lightning |
  | Fantasy Elf Girl | Spirit |
  | Space Pilot Girl | Cosmic |
  | Post-Apocalyptic Girl | Warrior |
  | Angelic Idol | Divine |

- Spread them over all 5 rarities.
- **Uses:**
  - the card art window
  - the stats panel
  - battle reaction pop-ups (attack, hit, KO, victory; about 0.6 s with a bounce)
  - the egg reveal silhouette
- Remove any other test or leftover character images from cards.
- It stays `TEMP_UNLICENSED` until the owner adds `LICENSE.txt`.

### 12.4 Phase 2 checklist
- [x] Pipeline works end to end
- [ ] 10 characters shown everywhere
- [x] Contact sheet and galleries
- [x] Status report in `WAITING_ON_YOU.md`

---

## 13. Decisions in this file, and what the owner must answer

**Decided here:**
- The N / R / SR / SSR / UR labels and "God-tier" (display only).
- The pack icons as the egg art (unedited).
- Favorite.
- The return-to-saved-spot rule after battles.
- PLAY always starts fresh in the lobby.
- Evolution mapped onto max level 15.

**Add to `WAITING_ON_YOU.md`:**
- "100 levels instead of 15? Say 'switch to 100 levels'. It needs a rebalance."
- "The portrait pack license."
- "Listen to the unreviewed sounds."

---

## 14. The loop (every checklist item)

Order: **section 2 (flow) → 3 (HUD) → 4 (audit + kit) → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12**.

1. Build it.
2. Test it in **Play mode** at phone landscape 1334×750, phone portrait 750×1334, tablet
   2048×1536 and PC 1920×1080.
3. `screen_capture`, then a **side-by-side comparison** with its reference in
   `docs/screens/<area>/compare_*.png`.
4. Score it 1-10 on:
   - matches the reference
   - visual quality
   - readability / little text
   - motion
   - consistency

   Below 8: list the differences, fix them, repeat.
5. Run the headless tests, StyLua, Selene, luau-lsp strict and the Rojo builds. Fix every
   failure.
6. Commit; the message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
7. Log it in `docs/POLISH_LOG.md`.
8. Tick the box.

Never stop to wait for the owner: write what you need in `docs/WAITING_ON_YOU.md` and continue.

---

## 15. Master checklist
- [x] Old mission files archived
- [x] **Flow:** launch loading, main menu, playing, leaving screen, reset, return-to-spot fix (2.6)
- [x] **In-game HUD**, clean and light (3.3)
- [x] `docs/GUI_AUDIT.md`, plus the UI kit replacing all TEMP images, plus the logo
- [x] Rarity display config
- [x] Card frames (5 × 3 sizes, layers, badges, Golden)
- [x] Template card
- [ ] Card with character
- [x] Card stats panel + Favorite (server and tests)
- [x] Card animations
- [x] Evolution stages
- [x] Cards used everywhere, including the deck bar
- [x] Egg pack wired in fully (unedited, 256/64, Golden), tier pedestals, Credits
- [x] Egg Shop
- [x] Egg opening, all 5 stages, every rarity, x1 / x3 / x8, Skip, Golden
- [x] Silhouettes
- [x] Inventory, Deck + Families, Arena (no bet), Victory/Defeat, Worlds, and the remaining
  screens restyled
- [x] Sound on every interaction
- [x] Motion everywhere
- [x] Extra assets
- [ ] Phase 2: character PNG pipeline and the portrait pack (12.4)
- [ ] **Final pass**, as a fresh player at phone and PC sizes:
  - launch → loading → menu → PLAY → lobby
  - shop → open x1 and x8 → inventory → favourite → upgrade → deck
  - walk into World 1 → Guardian Trial → back to the same spot
  - Arena queue → cancel
  - Menu → leaving screen → menu → PLAY → lobby

  Fix anything that feels off.
- [x] Report: `docs/MISSION_REPORT.md`, with every comparison image, the scores, what's `TEMP`,
  and what needs the owner

## 16. Don't
- Don't change odds, prices, pools, balance or match rules.
- Don't use existing characters or art.
- Don't edit the egg icons or any other third-party art.
- Don't publish, spend Robux or buy anything.
- Don't call anything done without a Play-mode test and a comparison image.
