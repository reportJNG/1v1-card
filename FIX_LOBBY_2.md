# FIX LOBBY 2: the main menu gets its own scene, and a bigger lobby upgrade (lobby only)

The owner, 2026-11-10, after `MASTER_FIX_PLAN` was finished:
1. "The main menu shows the lobby as its background. That's not the purpose of the lobby."
2. "Upgrade the lobby map only, not the other maps. Make where players spawn amazing. Make the
   lobby super cool."
3. "Why aren't the card images used?" **Answer:** `Downloads\New folder` still holds only the
   rejected `fighter_01..05`. They stay rejected (`PLAN.md` §4, `NEW_5_CHARACTERS.md`). Nothing
   to do until the owner adds new original images and says "new images are in".

**Scope:** the main menu background and the lobby map only. **Don't touch** the worlds, the
arenas or the other screens.

---

## A. The main menu must NOT show the lobby
**Now:** the menu camera looks at the live lobby (see `docs/brief/bad-gui/20-menu-shows-lobby.png`;
save the owner's screenshot there). That's wrong: the menu should be its **own scene**.

**Fix:**
1. **Build a separate menu stage,** `Workspace.MenuStage`, placed far from the lobby (for example
   at Y = 5,000 or 10,000 studs away) and **never visible from the lobby**. It's a small
   cinematic set, built only for the camera:
   - a glowing stone platform on a cliff edge
   - a starry purple sky with a big moon
   - floating islands far away, a few glowing cherry trees, drifting petals and light motes
   - a soft spotlight on the player's avatar
   - the 3 floating cards (N/R/SR) behind the avatar, kept as they are now
2. **The camera** is fixed at the menu stage, with a slow gentle sway. The player's avatar stands
   on the platform (the current avatar logic, moved).
3. **When the owner's D1 background arrives:** it can sit behind the stage as a far backdrop
   (review gate). Until then the stage is built in 3D.
4. **Main menu UI is unchanged** (logo, PLAY, SHOP, currencies), with one fix: **hide the
   lobby's world text** (EGGS, LANTERN TRADER, 1v1 ARENA) while the menu is open, and **hide the
   yellow spawn ring**. Nothing from the lobby may show on the menu.
5. **PLAY** fades to black, puts the player at the lobby spawn, then fades in at the spawn view
   (section B1).
6. **Lighting:** a `menu` preset in `Config/Lighting`, applied while the menu is open; switch to
   `hub` on PLAY.
7. **Test:** while the menu is open, no lobby part, billboard or ring is in view. Check with a
   screenshot at 1334 × 750 and at phone size.

## B. The lobby: a much bigger upgrade
The current lobby (399 parts, 21 lights) is clean but **too small and plain**: the owner scored
lobby detail 7. **Target:** a lobby that wows in 5 seconds. **Budget:** about 6,000 parts at
most, 40 PointLights at most. Use far more of it: aim for about 3,000-4,500 parts.

### B1. The spawn: make it amazing (first impression)
- **Spawn shrine:** a raised circular stone platform with carved rings and gold inlay, and a
  **glowing summoning circle** on the floor (rotating rune ring decal or beam, gentle pulse). It
  replaces the plain yellow ring.
- **4 tall lantern pillars** around it, with hanging paper lanterns and warm light pools.
- **Spawn effect:**
  1. players arrive in a **burst of petals and light** with a soft "whoosh" sound
  2. a camera move from slightly above, settling behind the player
  3. a short "Welcome to 1v1 CARD" big outlined text, shown once per session
- **Composition:** from the spawn, the player sees in one view:
  - the grand stairway leading up to the plaza
  - the **1v1 ARENA** torii lit up in the centre
  - the **WORLDS** portal glowing on the right
  - the egg pavilion on the left
- **The path from the spawn:**
  - a wide stone path lined with lanterns
  - cherry trees on both sides arching over it, with petals falling
  - small glowing koi in a stream beside the path

### B2. Bigger landmarks
- **1v1 ARENA:**
  - a **giant** double torii gate, 3x the current size
  - a round sign with crossed swords, flame braziers, two original guardian statues
  - a red carpet up the steps
  - gold particles drifting
- **WORLDS portal:**
  - a tall temple gate with a **swirling portal surface** (rotating textures and beams)
  - floating rune stones orbiting it
  - a light pillar going up into the sky, visible from anywhere
- **EGG pavilion:**
  - a two-floor pagoda with glowing lanterns
  - eggs (the pack images, unedited) on spinning glowing pedestals in tier colours, each with a
    price billboard
  - one giant golden egg on the roof as the landmark
- **Central plaza:**
  - a big fountain with water effects and floating cards spinning above it
  - a golden trophy-card statue
  - benches and planters

### B3. Detail and life everywhere
- **Ground:**
  - patterned stone tiles (MaterialVariants)
  - borders, steps and low walls between zones
  - moss and flower beds
- **Edges:**
  - pagodas with lit windows, cliffs, a waterfall falling off the edge
  - floating islands with small trees around the lobby
  - a big moon and stars
- **Life:**
  - falling petals, fireflies near the water, lanterns swaying
  - koi, banners waving
  - occasional shooting stars
  - ambient sound zones: water near the fountain, wind at the edges, chimes near the shrine
- **Night lighting:**
  - moonlight
  - purple Atmosphere haze
  - Bloom and ColorCorrection
  - warm light pools under every lantern
- **Function:** keep the merchant, quest board ("!"), daily shrine and world text. Make each
  place bigger and easier to read from the spawn.

### B4. How to build it
- **Hero props:** Blender MCP (torii, portal gate, pagoda, spawn shrine, fountain, statue,
  lantern pillar), plus Studio `generate_mesh` and `generate_material`, plus Creator Store models
  with **every script removed** and logged in `docs/ASSETS.md`.
- **Review gate:** any **new texture or image** goes on a contact sheet in `docs/review/lobby2.png`
  and waits for the owner's OK before upload (5 or fewer per batch, stop on any rejection).
  Meshes, parts, terrain, lighting and particles using existing textures can be built straight
  away.
- **Performance:**
  - StreamingEnabled
  - the hero landmarks set to `Atomic`
  - repeated props reused
  - particles halved on mobile
  - part count, light count and frame time logged in `docs/LOBBY_AUDIT.md`

### B5. Done means
- **Before and after** screenshots from the same angles: the spawn view, the plaza, the arena
  gate, the portal, the egg pavilion, aerial, and phone size.
- **Comparison** `docs/screens/lobby/compare_lobby2.png`, with **9+ for the spawn view** and
  **8+ on everything else**.
- The main menu never shows the lobby (section A test).
- **Code checks:** tests, lint and the builds clean.
- **Git:** named paths only, committed and pushed.
- **Report:** `docs/MASTER_FIX_REPORT.md` gets a "FIX_LOBBY_2" row.
