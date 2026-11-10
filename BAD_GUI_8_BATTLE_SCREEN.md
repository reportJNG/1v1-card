# BAD GUI 8: the battle screen while fighting, plus 5 random battle maps

The owner, 2026-11-09:

> "Report bad UI while playing. The background map should be upgraded. Add more new map ideas,
> not just one main lobby of 1v1: 5 random clean maps while fighting, in the new UI. Make
> something like that, with clean lovely animation."

Siblings: `BAD_GUI_THINKING_AND_UI.md` … `BAD_GUI_7_BATTLE_RESULT.md`. It's listed in
`UI_TARGETS.md`.

---

## 1. Images

| File | What it is |
|---|---|
| `docs/brief/bad-gui/19-battle-screen-current.png` | **Now (bad)** |
| `docs/brief/bad-gui/18-target-battle-screen.png` | **Target** |

## 2. What's wrong with "now" (19), compared to the target (18)
1. **Two big info boxes full of tiny text** at the top:
   - card thumbnail
   - name, username, trophies, rarity, family, HP numbers
   - "SPECIAL READY"
   - "Rai Stormvolt KO · Ren Emberfang KO"
   - "Special: Static Step"

   The target has **two long sleek HP bars** across the top, meeting at a **round timer
   medallion**, with only the **name**, a **rarity badge**, an **HP bar with numbers** and
   **energy diamonds** under each.
2. **The timer is a dashed ring with "GUARDIAN TRIAL · ROUND 15" and a "You act first: 20%"
   pill.** The target timer is a **steel hexagon medallion** with a big number and a small
   "ROUND 15" plate under it, and nothing else.
3. **Round candy buttons** (red, blue, purple circles) with labels under them and "Pick your
   action!" text. The target uses **three tall glass action cards** (ATTACK red, DEFEND blue,
   SPECIAL purple), each with a big glowing icon and its label inside, sitting on a glass tray
   with **energy pips** under it.
4. **A web battle log** in the bottom-left (four lines of small white text). **Removed:** events
   become big pops in the arena (section 4).
5. **A big red Forfeit button** that draws the eye. The target has a **small dark "FORFEIT"**
   in the corner, with a confirm.
6. **A plain arena:** a flat purple floor and red pillars, with the same lobby courtyard every
   time. The target is darker and cleaner, with focused light on the fighters. And we want **5
   different maps** (section 5).
7. **The fighters are flat white or blue shapes.** The target shows them as **glowing aura
   silhouettes on light pads**: a blue-white flame aura for one, a gold lightning aura for the
   other, in each fighter's family colour. (Proper models come later from the art pipeline; the
   aura treatment stays.)

---

## 3. Target battle UI (match 18)

**Top bar:**
- **Two long angled HP bars** from the screen edges to the centre:
  - the left one for the player, glowing pink-magenta
  - the right one for the opponent, gold
- **The centre medallion:** a steel hexagon ring with the **big round timer number**, and the
  small **"ROUND N"** plate below.
  - The ring drains as time runs out.
  - In the last 3 s it pulses red and ticks.
- **Under each bar:**
  - the **fighter name** (bold, outlined)
  - the **rarity badge** (italic N / R / SR …)
  - a thin **HP sub-bar with "95 / 778"**
  - **energy diamonds** (filled gold; empty dark)
- **Nothing else:** no usernames, trophies, families, KO lists or ability names on screen. The
  special's name shows on its action card tooltip only.

**Bottom: the action tray**
- A **glass tray** holding **3 tall action cards**:
  - **ATTACK:** red frame, red sword icon
  - **DEFEND:** blue frame, blue shield icon
  - **SPECIAL (cost):** purple frame, purple-gold lightning icon; dimmed with a lock when there
    isn't enough energy
- Under the tray: **3 small pips** showing the energy towards the special.
- **On pick:**
  - the chosen card lifts and glows, the others dim
  - a "LOCKED IN" stamp appears
  - when both sides have picked, the **two choices flip in over the medallion** as icons (the
    reveal)
- **Initiative** ("who acts first") shows **after the reveal** as a small arrow or flash on the
  side that acts first. No percentage text on screen.

**Corner:** a small dark **FORFEIT** button bottom-right, with a confirm ("Forfeit counts as a
loss").

**Mobile:** the action cards get big tap targets (at least 110 px wide on phone), the top bars
are thinner, nothing overlaps the Roblox top bar.

## 4. Animation (clean and lovely, never cluttered)
- **Arena intro** (about 2.5 s, skippable):
  1. the camera sweeps around the arena while the map name banner slides in ("SAKURA
     COURTYARD")
  2. the fighters drop onto their pads with an impact ring
  3. the VS badge slams in, then fades away
- **Round start:** a "ROUND N" pop by the medallion, the timer ring refills.
- **Pick:** card lift and glow, others dim, then the "LOCKED IN" stamp; the opponent shows a
  pulsing "?" card on their side until the reveal.
- **Reveal:** both choice icons flip over the medallion, then a short pause (0.3 s).
- **Actions:**
  - **attack:** the attacker dashes and hits, with spark particles in the family colour
  - **defend:** a shield bubble on the defender
  - **special:** a camera cut to the caster, an aura burst, a screen flash, then the effect
  - **parry:** a blue flash and "PARRY!" pop
- **Hits:**
  - a **big damage number** pops above the target (white; "CRIT!" in yellow-red; green for heals)
  - the target's HP bar shakes, and a white **chip trail** drains after the real drop
  - a small screen shake
- **Status effects:** small icons next to the fighter's name (burn, chill, weaken) with a pop when
  they're applied. No text.
- **Energy:** each energy diamond fills with a sparkle.
- **KO:**
  - slow motion (0.4 s)
  - the fighter shatters into aura particles
  - a big **"K.O.!"** pop
  - the next fighter drops in, or the result screen follows (`BAD_GUI_7_BATTLE_RESULT.md`)
- Every animation respects `reducedMotion` and stays within the existing server timing (12 s
  picks). The client only animates the events the server sends.

## 5. Five battle maps, picked at random per match

Every battle (ranked and Guardian Trial) is played in **one of 5 arena maps**:
- **picked by the server** from the match seed (so both players see the same map)
- announced in the intro

All maps share the same **core**:
- a round fighting platform about 40 studs across, two light pads, and the camera rig
- so gameplay and camera angles never change

Each map has its own surroundings, sky, lighting, particles and music.

| # | Map | Look | Lighting / particles | Music mood |
|---|---|---|---|---|
| 1 | **Sakura Courtyard** (upgrade of the current one) | Night temple court, cherry trees, torii, stone lanterns, a koi pond edge | Purple night, warm lantern pools, falling petals | Calm-tense taiko |
| 2 | **Frozen Shrine** | An ice shrine on a glacier, crystal pillars, a reflective ice floor | Cold blue, an aurora in the sky, light snow | Icy strings |
| 3 | **Volcano Forge** | Obsidian platform over lava, glowing floor cracks, chains and anvils | Red-orange underglow, embers, heat haze | Heavy drums |
| 4 | **Celestial Isle** | A floating white-gold platform among floating islands, waterfalls falling into clouds | Golden sunset, rotating light rings, drifting motes | Heroic choir |
| 5 | **Storm Rooftop** | A night pagoda rooftop above a glowing city, rain, banners | Dark blue, lightning flashes (thunder synced), rain | Fast electronic-taiko |

**Building them:**
- **One template per map** in `ServerStorage/Arenas/<Map>`, cloned for each battle and destroyed
  after.
- Shared core: `ArenaCore` (platform, pads, camera points, spawn points). Map props go in a
  `Dressing` folder.
- **Make the props** with Studio `generate_scene` and `generate_mesh` (original meshes), terrain,
  and curated Creator Store models with **every script removed** and the license checked
  (`docs/ASSETS.md`).
- **Config:** `Config/Arenas` (map id, display name, lighting preset, sky, particles, music id,
  weight). The server chooses with the match seed; the client applies the preset on battle start
  and restores the area's preset after.
- **Lighting:** each map has a `Lighting` preset (Future, Atmosphere, Bloom, ColorCorrection,
  sky), applied on the client and tweened in during the intro.
- **Performance:**
  - each map under about 15k parts/meshes worth of detail and about 80 particle emitters (fewer
    on mobile)
  - StreamingEnabled-safe (all inside the battle area)
  - the fighters are always lit by a key light so they read clearly
- **Tests:** map choice is deterministic for a seed, every map has the core parts, and the config
  validates.
- **Screenshots:** `docs/screens/arenas/<map>.png`, the intro shot plus mid-fight.

## 6. Owner images (exact prompts)
Attach `18-target-battle-screen.png` as the reference. Flat magenta background, separated.

**H1. Action cards** → `art/ui/sheets/battle_actions.png`
> "Three tall glass action cards for a Roblox battle UI in exactly the style of the attached
> image, NO TEXT: (1) red neon frame with a glowing red sword icon, (2) blue neon frame with a
> glowing blue shield icon, (3) purple neon frame with a purple-gold lightning bolt icon. Also a
> dimmed locked version of the purple card with a small lock, a 'selected' glowing version of each,
> and the empty glass tray they sit on. Flat magenta background, separated."

**H2. Top HUD pieces** → `art/ui/sheets/battle_top.png`
> "Same style, NO TEXT: a steel hexagon timer medallion (empty center), a small 'round' plate
> (empty), a long angled HP bar frame for the left side and a mirrored one for the right side
> (empty), HP fills in magenta and gold, a thin sub-bar frame, an energy diamond empty and filled
> (gold), a small dark forfeit button (empty), a 'LOCKED IN' stamp (with text), a 'K.O.!' burst
> (with text), a 'PARRY!' burst (with text). Flat magenta background, separated."

**Review gate:** contact sheet, check for no characters, the owner's OK, upload in batches of 5 or
fewer, stop on any rejection.

## 7. Checklist
- [ ] Top bar like 18: long HP bars, timer medallion, round plate, name + badge + HP sub-bar +
  energy diamonds only
- [ ] Action tray with 3 tall action cards, lock state, energy pips, pick/lock/reveal animation
- [ ] Battle log removed; event pops in the arena (damage, crit, heal, parry, status icons, K.O.!)
- [ ] Small corner FORFEIT with confirm
- [ ] Fighters as aura silhouettes on light pads in their family colour (until real models)
- [ ] Arena intro (sweep, map name, fighters drop in, VS slam), skippable
- [ ] 5 arena maps (Sakura Courtyard, Frozen Shrine, Volcano Forge, Celestial Isle, Storm
  Rooftop), with a shared core, config, server pick by seed, lighting/music per map, tests
- [ ] H1/H2 prompts in `PROMPTS_V3.md` + `WAITING_ON_YOU.md`; sheets cut, reviewed, approved,
  uploaded, swapped
- [ ] Mobile checked in Play; particle budget respected
- [ ] Comparisons `docs/screens/roblox-ui/compare_battle.png` (18 vs ours), scored 8+, plus the
  arena screenshots
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
