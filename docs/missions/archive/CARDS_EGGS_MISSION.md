# CARDS & EGGS MISSION (step 5): the exact look of the owner's boards, then the character PNGs

This file **extends `GUI_MISSION.md`**. Where they overlap (card frames, the Egg Shop, egg
opening), **this file wins**. It covers two phases, in this order:

1. **Phase 1: the visual system.** Eggs, egg opening, cards with and without art, card stats,
   rarity frames, card animations and card evolution, matching the owner's boards as closely as
   Roblox allows, plus the extra assets listed in section 6.
2. **Phase 2: the character PNG pipeline.** Take many character PNGs, clean and process them, and
   put them on these cards.

Gameplay, economy, server rules and balance stay as they are, except where section 9 lists a
change the owner must approve.

---

## 0. Reference boards (the target)

The files are in `docs/brief/ui-refs-2/`:

| File | Shows |
| --- | --- |
| `01-egg-gui.png` | 5 egg styles on glowing pedestals (Common, Rare, Epic, Legendary, God-tier), with labels |
| `02-egg-opening.png` | The 5 stages: Summon → Crack → Break → Reveal (silhouette) → Get Card (with a "NEW!" sticker) |
| `03-card-with-character.png` | Complete illustrated card: rarity badge, crown, art, name, rarity name, Lv, two stats |
| `04-card-borders.png` | 5 empty rarity frames: N, R, SR, SSR, UR |
| `05-card-stats.png` | Stats panel: name, rarity, level + bar, ATK/DEF, passive, and 5 action buttons |
| `06-card-without-character.png` | Clean template card: emblem, name plate, Lv, stats, family gem |
| `07-card-animations.png` | Blue / purple / gold auras around cards |
| `08-rarity-levels.png` | Rarity ladder, Common → God-tier, with star and crown emblems |

The owner said these are **overview sheets, not production components**. Phase 1 turns each one
into separate, high-resolution, production-ready assets, plus the ones listed in section 6. Also
read `GUI_MISSION.md` (the base GUI kit, sound, motion, loop rules) and `docs/brief/ui-refs/`.

**Never copy** existing anime or franchise characters. The "Shadow Knight" on board 03 is a
generic stand-in and is not used. Card art comes only from phase 2 (licensed or original PNGs).

---

## 1. Visual language (measured from the boards)

| Element | Value |
| --- | --- |
| Background | Deep navy-violet, #06061B → #0D0B26, with purple haze and lightning |
| Common (N) | Silver/white #F0F0F0, cool lavender shadow #9080C0, white glow |
| Rare (R) | Electric blue #0080F0 → #00A0F0, cyan glow |
| Epic (SR) | Violet/magenta #9B4DFF → #E090F0, pink-violet glow |
| Legendary (SSR) | Gold #F0C010 → #F0D030, warm orange glow |
| God-tier (UR) | Emerald green #00C070 → #00D080, mint glow |
| Frames | Ornate bevelled metal: pointed corner flourishes, a diamond gem at the top-centre and bottom-centre, a thin inner line, crackling energy lightning along the edges, outer glow in the rarity colour |
| Badges | Italic heavy letters (N / R / SR / SSR / UR) in the rarity colour, gradient fill, thick dark outline, sitting over the top edge of the frame |
| Emblems | Star for N and R; crown for SR, SSR and UR (on templates and eggs) |
| Labels | Dark rounded pill under each item, rarity-coloured border, white bold text |
| Panels | Same as `GUI_MISSION.md`: dark glass, violet border and glow, round icon plate with a play/egg icon, title plus subtitle (e.g. "Egg GUI / Collect Powerful Eggs") |
| Type | Heavy bold sans for titles and numbers, white with a dark stroke; italic heavy display font for rarity badges |

---

## 2. Rarity display (config only; ids and saves don't change)

The internal rarities stay `Common, Rare, Epic, Legendary, Mythical`. Add display fields to
`Config/Rarities`:

| Internal | Badge | Display name | Colour set | Emblem |
| --- | --- | --- | --- | --- |
| Common | N | Common | silver | star |
| Rare | R | Rare | blue | star |
| Epic | SR | Epic | violet | crown |
| Legendary | SSR | Legendary | gold | crown |
| Mythical | UR | God-tier | emerald | crown |

- Every UI reads these fields. No hard-coded colours anywhere.
- The Odds panel shows the display name and the badge (for example "UR · God-tier 0.5%").
- The odds maths doesn't change.

---

## 3. How to produce the assets at board quality

Roblox UI can't draw ornate metal, lightning or glossy crystal from code alone. Each asset gets
one of three routes:

| Route | Use for | How |
| --- | --- | --- |
| **B: Blender renders** (main route, no waiting on the owner) | Eggs, pedestals, card frames, badges, crowns, stars, gems, shards | Model in Blender (via Blender MCP); emissive materials for glow; Eevee with Bloom; transparent film; render at 2-4x and downsample; export PNG with alpha. Frames get real bevels, metallic materials and emissive edge lines. |
| **C: code / Pillow** | Simple shapes, gradients, glow sprites, particles, bars, pills | `scripts/art/ui_kit.py`, drawn at 4x, multi-layer Gaussian glows |
| **O: owner AI images** (optional upgrade) | Anything where the owner wants a painted look | The owner generates from `art/ui/PROMPTS_V2.md` (written in this mission). The pipeline swaps them in when they appear. |

**Rules for all assets:**
- Every asset is listed in `art/ui/MANIFEST_V2.json` with: slot, file, size, 9-slice margins (if
  any), route (B/C/O), status (`TEMP` or `FINAL`) and Roblox asset id.
- Upload in batches through the Studio MCP and record the ids.
- Size limits:
  - images 1024 px or smaller
  - frames 512 × 704 at the large card size
  - small sizes are generated as separate images, never just scaled down

**Blender scene standard:** save it as `art/blender/ui_studio.blend`. It holds:
- one fixed orthographic camera per asset type
- a three-point light rig
- a dark world background, with film set to transparent for export
- Bloom on

Every render comes from this file, so all assets look consistent. Batch rendering is a Python
script inside Blender.

---

## 4. Phase 1 components (in this order)

### 4.1 Card borders: five separate rarity frames (board 04)
For each rarity, a set of separate PNG layers:
- `frame_<rarity>`: the ornate frame, with a transparent window
- `frame_<rarity>_glow`: the outer glow, a separate layer so it can pulse
- `frame_<rarity>_energy`: lightning/energy strokes, a separate layer that flickers
- `badge_<rarity>`: the italic N / R / SR / SSR / UR badge

Requirements:
- **Three sizes:** large 512 × 704, medium 256 × 352, small 128 × 176. Small sizes are simpler:
  fewer flourishes and thicker lines.
- **Escalation:** N is the plainest; each step adds ornament, glow and energy. UR has the most
  ornate corners and the strongest energy.
- **Golden copies:** `overlay_golden` adds gold foil over any frame.
- **Comparison:** save `docs/screens/step5/compare_frames.png` (board 04 on the left, ours on the
  right). It must read as the same design.

### 4.2 Card without character: the clean template (board 06)
The default card for every character that has no art yet. It replaces the TEMP silhouettes.

**Layers:**
- the rarity frame
- a dark violet gradient inner panel with a faint pattern
- a large glowing emblem (star for N and R, crown for SR and up) in the rarity colour, with a
  soft glow
- a name plate ("Name Here" becomes the character's name)
- "Lv. N"
- two stat chips: a sword for attack and a shield for defence
- the family gem, bottom-left
- the badge

**Sizes:** all three, all rarities, plus Golden. Save a gallery to
`docs/screens/step5/template_gallery.png`.

### 4.3 Card with character (board 03)
Same structure as the template, but the art window shows the character (phase 2).

**Layout, top to bottom:**
- rarity badge, top-left, overlapping the frame
- crown, top-right, for SR and up
- the character art, filling the window behind a soft vignette
- energy/lightning FX behind the character, in the rarity colour
- name in white bold with a stroke
- the rarity name in the rarity colour
- "Lv. N" bottom-left
- the ATK and DEF chips bottom-right

**2.5D:** background, character, FX, frame and glow are separate layers, with parallax on hover
or tilt (keep the current system).

### 4.4 Card stats panel (board 05)
Shown in the inspect view, next to the large card. Layout:
- **Header:** crown icon, name, rarity name in its colour.
- **Level:** "Lv. N / max" and a progress bar. The bar shows real merge progress
  (`mergePoints` / points needed for the next level), as "x / y".
- **Stats:**
  - big ATK (sword icon) and DEF (shield icon)
  - HP and SPD in a smaller row underneath
  - real numbers from `Cards.statsAt`, formatted with K / M only above 9,999
- **Special and passive:** an icon, the name, the real description from `Config/Characters`, and
  the energy cost of the special.
- **Family bonus:** shown when it's active.
- **Buttons, right column** (purple glass, icon + label, like board 05):
  - **Upgrade:** opens the merge flow (spare level-1 copies, coin fee). This exists already.
  - **Evolve:** shows the evolution stages (4.6) and what the next stage needs. It's not a
    separate system: stages follow level.
  - **Equip:** add to or replace in the deck (existing Deck.Set).
  - **Favorite:** a heart toggle. Favourite cards can't be sold or used as merge spares. This
    needs a small server addition: a `favorite` flag on the card copy, a validated
    `Cards.SetFavorite` remote, and Sell/Merge refusing favourites. Add tests.
  - **Preview:** a full-screen showcase of the card, slowly rotating, with its aura, plus the
    battle portrait/standee.

### 4.5 Card animations (board 07, plus more)
- **Aura:** a soft rotating ring or flame aura behind the card, in the rarity colour:
  - N: none
  - R: blue
  - SR: purple
  - SSR: gold, with an orbiting light ribbon like board 07
  - UR: emerald, with an orbiting ribbon plus rising particles
- **Glow pulse:** the frame glow layer breathes (1.5 s loop); stronger at higher rarity.
- **Energy flicker:** the frame energy layer flickers at random, in short bursts.
- **Shine sweep:** a diagonal shine crosses the card every 4-6 s (R and up).
- **Particles:** sparkles (SR and up), embers (SSR), emerald motes (UR).
- **Hover / select:** lift (scale 1.05), brighter aura, a tick sound.
- **Equip:** the card flies into its deck slot with a trail, and a confirm sound.
- **Level up:** a ring burst, "+1" counting up, the bar filling, a level-up sound.
- **Golden:** gold foil glints.
- **Performance:** animate only visible cards. Grids of small cards pause their auras until
  hovered. Keep at most about 6 animated large effects on screen.

### 4.6 Card evolution: visual stages by level
The owner wants visibly different cards as level rises (their brief says levels 1, 50 and 100).
**The locked max level is 15** (section 9). Until the owner decides otherwise, map the stages onto
1-15:

| Stage | Levels | Visual change |
| --- | --- | --- |
| Base | 1-4 | Normal frame |
| Awakened | 5-9 | Brighter frame, extra corner gems, a faint aura even at small sizes |
| Ascended | 10-14 | Animated energy on the frame, gold inner line, a stronger aura |
| Max | 15 | Crown on the badge, a "MAX" ribbon, the strongest aura, a special shine |

- Keep the stage thresholds in config (`Config/Progression.evolutionStages`), so a later change
  to 100 levels is a config edit.
- Save `docs/screens/step5/evolution.png`: one card at each stage, for every rarity.

### 4.7 Egg styles (board 01)
- **5 tier eggs**, modelled in Blender:
  - shape: a crystal-cracked faceted shell
  - glowing cracks in the tier colour
  - an emblem (star for Common and Rare, crown for Epic and up)
  - a crown on top for Legendary and God-tier
  - materials: polished stone (Common), sapphire (Rare), amethyst (Epic), obsidian with gold
    cracks (Legendary), emerald crystal (God-tier)
  - a pedestal: a dark stone ring with an emissive rim in the tier colour
- **Per-egg variants:** the 24 game eggs keep their ids, worlds, prices and pools. Each gets a
  tier from its odds band, and a themed variant of that tier's egg: a recolour, pattern or
  accessory matching its name (Ice, Dragon, Kraken and so on), rendered in the same Blender
  scene. That gives 24 unique, consistent eggs.
- **The original icon pack:** keep its files untouched (license). The shop switches to the new
  Blender eggs. Record the switch in `docs/ASSETS.md`.
- **Exports for every egg:** a shop icon (512 px), a pedestal render, a 3D mesh (FBX → Studio,
  under 5k triangles) for the in-world stall and the opening animation, and a shard set for the
  break stage.

### 4.8 Egg GUI: the shop (board 01 plus the earlier `hd-02-egg-shop`)
- **Panel header:** egg icon plate, "Egg Shop", subtitle "Collect Powerful Eggs", close button.
- **Main row:** eggs on their pedestals in a horizontal, scrollable row, each with:
  - its tier label pill under it
  - its price pill (coin icon)
  - an idle bob
  - a soft glow
  - a world lock overlay when locked
- **Selected egg:** it rises, its pedestal ring brightens, and the details panel shows:
  - the big egg
  - its name and tier
  - "Drops Common up to God-tier · see Odds" (with the real top rarity of that egg)
  - the price
  - **Open x1 / x3 / x8** buttons (gold)
  - **Odds** button
  - **Auto-open** toggle
  - the Robux button only when the policy allows it (existing rule)
- **Egg Bag tab:** owned eggs, with counts and Golden markers, and Open buttons.

### 4.9 Egg opening: every stage (board 02)
Replaces the current sequence. Each stage has its own timing, sound and FX, all tinted to the
**rarity being revealed**, so the colour builds suspense.

| # | Stage | Visual | Time |
|---|---|---|---|
| 1 | **Summon** | The screen dims and blurs. The egg rises out of a glowing summoning circle (rotating runes, ring pulses). The camera pushes in. | 0.9 s |
| 2 | **Crack** | The egg shakes in rising pulses. Glowing cracks spread across the shell. The aura colour hints at the rarity (it starts neutral, then shifts). | 1.0 s (Legendary or higher: +0.4 s slow-mo) |
| 3 | **Break** | The shell explodes into crystal shards (the 3D shard set plus 2D shards) with a light burst, a shockwave ring and a short screen shake. | 0.5 s |
| 4 | **Reveal** | A dark character silhouette stands in a rising aura of the rarity colour, with light rays behind it. The rarity badge slams in above it. | 0.8 s (UR: +0.6 s, with an emerald pillar of light) |
| 5 | **Get Card** | The silhouette turns into the card, which flips in with its full frame, art and effects. A "NEW!" sticker for first copies; "+1 copy" otherwise. Name and rarity name appear. Confetti for SSR and up. Buttons: Continue, Open Again, and Equip (if the card is new). | until tapped |

- **Multi-open (x3 / x8):** stages 1-3 play together for all eggs; stage 4 shows silhouettes in
  a row; stage 5 flips the cards one by one (tap to flip all), in a grid.
- **Skip:** a tap fast-forwards to stage 5.
- **Golden eggs:** a gold summoning circle, gold shards and a Golden card overlay.
- **Sounds:** one per stage (summon hum, crack ticks rising in pitch, shatter, reveal swell per
  rarity, card flip and sparkle). Use licensed ids, logged in `docs/ASSETS.md`, marked
  "unreviewed".
- **Fairness:** the result is decided by the server before the animation starts. The animation
  only shows it. No fake "almost" moments, no false hints that suggest a different rarity than
  the real one.

### 4.10 Egg reveal: silhouette art
- Every character needs a **silhouette** image. Generate it from the character's processed art
  (phase 2): a black fill plus a rim light in the rarity colour.
- Characters without art use a generic silhouette for their role.

---

## 5. Production checklist for phase 1 (save every item's comparison to `docs/screens/step5/`)
- [ ] `ui_studio.blend` scene plus the batch render script
- [ ] Rarity display config (section 2), used everywhere
- [ ] Frames: 5 rarities × 3 sizes × (frame, glow, energy) + badges + Golden overlay → `compare_frames.png`
- [ ] Clean template card for all rarities and sizes → `template_gallery.png`
- [ ] Card with character (using phase-2 art when present, a test portrait otherwise) → `compare_card.png`
- [ ] Card stats panel + 5 buttons (Favorite with server support and tests) → `compare_stats.png`
- [ ] Card animations (aura, pulse, flicker, shine, particles, hover/equip/level-up) → a short video or frame strip in `anim_*.png`
- [ ] Evolution stages → `evolution.png`
- [ ] 5 tier eggs + 24 themed eggs + pedestals + shards + meshes → `compare_eggs.png`
- [ ] Egg Shop → `compare_shop.png`
- [ ] Egg opening (all 5 stages, every rarity, x1 / x3 / x8, Skip, Golden) → `compare_opening_stage1..5.png`
- [ ] Silhouettes
- [ ] Extra assets (section 6)
- [ ] Every card everywhere uses the new system: shop, hatch, inventory, inspect, deck,
  battle, results, KO picker

---

## 6. Extra assets (added to complete the set)

| Asset | Use |
| --- | --- |
| `sticker_new`, `sticker_max`, `sticker_dup` | "NEW!", "MAX", "+1" on cards |
| `ribbon_max` | Ribbon for max-level cards |
| `gem_family_<family>` × 15 | Glowing family gems (cards, filters, Families panel) |
| `icon_atk`, `icon_def`, `icon_hp`, `icon_spd`, `icon_energy`, `icon_passive` | Stat icons, all one style |
| `icon_upgrade`, `icon_evolve`, `icon_equip`, `icon_favorite` (on/off), `icon_preview` | Stats-panel buttons |
| `bar_level_bg`, `bar_level_fill`, `bar_level_glow` | Level / merge progress bar |
| `summon_circle`, `summon_runes` | Opening stage 1 |
| `crack_overlay_1..3`, `shard_set`, `shockwave_ring`, `light_rays`, `light_pillar` | Opening stages 2-4 |
| `aura_<rarity>`, `ribbon_orbit`, `sparkle`, `ember`, `mote` | Card animations |
| `pedestal_<tier>` | Egg pedestals |
| `lock_overlay`, `world_badge` | Locked eggs and cards |
| `card_back_<rarity>` | Card backs for flip animations and the hatch grid |
| `filter_chip_<rarity>` | Inventory rarity filters |
| `toast_rarity_<rarity>` | "You got a Legendary!" toast background |
| `confetti_set` | SSR+ reveals, victory |
| `empty_slot` | Deck slot with a dashed glow and "+" |
| `odds_row_<rarity>` | Rows in the Odds panel, using the rarity colours |

---

## 7. Phase 2: the character PNG pipeline (many PNGs, handled well)

Start only when the phase-1 checklist is done (or blocked only by owner items).

### 7.1 Folders
```
art/characters/
  incoming/<pack-or-batch>/          raw PNGs as supplied (never edited) + LICENSE.txt
  processed/<character_id>/
      card.png        cut-out art for the card window (768 px tall, transparent)
      portrait.png    head-and-shoulders for battle and the stats panel
      silhouette.png  for the egg reveal
      expr_<name>.png optional expressions (attack, hit, ko, victory)
  map.json           { "incoming/<batch>/<file>": "<character_id>" }
```

### 7.2 `scripts/art/characters.py` (extend the existing script)
- `ingest <folder>`:
  - copy into `incoming/`
  - check for a license file. Without one, mark the batch `TEMP_UNLICENSED` (it can be used in
    development, but the release validator refuses it) and add a line to `WAITING_ON_YOU.md`.
- `split`: cut multi-face sheets into single faces using alpha connected components, merging
  pieces that belong together and dropping fragments.
- `clean`: remove fringe and halo pixels, close holes, 1 px feather, trim, and normalise
  position and head size per output type.
- `upscale`: an anime-tuned upscaler if available (Real-ESRGAN anime); otherwise Lanczos plus
  light sharpening. Never upscale more than 4x.
- `style`: the same colour grade for all, a thin dark outline, a rim light in the family colour.
  Sketchy or black-and-white art gets a subtle tint in its family colour.
- `safe`: all-ages crop rules (head and shoulders when needed), with a manual-review list.
- `map`: suggest roster matches by look, family and role; write `map.json`. Update a
  character's `look` text only, never its stats.
- `derive`: produce `card.png`, `portrait.png`, `silhouette.png` and the expressions.
- `check`:
  - sizes and transparency
  - no duplicate art across characters
  - a contact sheet at `docs/screens/step5/characters_contact_<batch>.png`
- `upload`: batch upload through the Studio MCP, then write the ids into the character asset
  config.
- `status`: how many characters have final art, temp art or no art.

### 7.3 Art rules
- Original characters only. Reject any image that looks like an existing anime, game or
  franchise character, and log why.
- Keep the incoming originals untouched. Everything else is derived.
- One art style per batch. If a batch clashes with the others, the `style` step evens it out.

### 7.4 First batch: the portrait pack
`C:\Users\Administrator\Desktop\Ultimate Multi-Expression Portrait Pack — 320+ Free Anime Expressions`
(40 sheets, 10 characters). Follow `GUI_MISSION.md` §8 for the mapping (families: Demon, Shadow,
Mystic, Royal, Beast, Lightning, Spirit, Cosmic, Warrior, Divine), spread across all 5
rarities. There's no license yet, so it's `TEMP_UNLICENSED` until the owner adds `LICENSE.txt`.

### 7.5 Phase 2 checklist
- [ ] Pipeline commands work end to end on the portrait pack
- [ ] 10 characters show their art on every card size, in the stats panel, in battle and in the
  egg reveal silhouette
- [ ] Contact sheet and card gallery screenshots
- [ ] `status` report in `docs/WAITING_ON_YOU.md`: how many characters still need art

---

## 8. Loop, checks and reports
Use the loop from `GUI_MISSION.md` §10 for every checklist item:
1. Build it.
2. Test it in **Play mode** at phone landscape, phone portrait, tablet and PC.
3. Make a side-by-side comparison with the board.
4. Score it 1-10. Below 8: fix and repeat.
5. Run the headless tests, StyLua, Selene, luau-lsp and the Rojo build.
6. Commit (the message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`).
7. Log it in `docs/POLISH_LOG.md`.
8. Tick the box.

Never stop to wait for the owner: write it in `docs/WAITING_ON_YOU.md` and continue.

**Final report:** `docs/CARDS_EGGS_REPORT.md`, with:
- every comparison image and score
- the asset manifest summary
- what's `TEMP`
- what still needs the owner

---

## 9. Decisions this mission makes, and what needs the owner

- **Rarity labels N / R / SR / SSR / UR and "God-tier" for Mythical:** display only, done in
  this mission.
- **New Blender egg art for all 24 eggs:** this is new art, not new eggs, so the 24-egg rule still
  holds. The pack's icons stay unedited but aren't shown. Done in this mission.
- **Max level:** the boards show "Lv. 1/100" and evolution at 1/50/100. The **locked rule is
  max level 15**. This mission keeps 15 and maps the evolution stages onto it. Add to
  `WAITING_ON_YOU.md`: "Do you want 100 levels? It needs a rebalance of levels, merge costs and
  stats (sim/balance.py); say 'switch to 100 levels' to start it."
- **Favorite:** a new small server feature (section 4.4), with tests. Done in this mission.
- **The "4.8K" stat style:** shows our real stats. No inflated numbers.

## 10. Don't
- Don't change odds, prices, pools, balance or match rules.
- Don't use any existing anime or franchise character, name or art.
- Don't edit third-party originals.
- Don't publish, spend Robux or buy anything.
- Don't call anything done without a Play-mode test and a comparison image.
