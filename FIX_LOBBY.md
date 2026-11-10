# FIX LOBBY: a full upgrade of the main lobby map

The owner, 2026-11-09:

> "We have, I guess, 11 maps: the main lobby map and the 10 other maps. Mark the lobby map as bad.
> It needs to be more fancy, a better map, a full upgrade. Report it as a new file: fix lobby."

**Status of the maps:**

| Map | Where | Status |
|---|---|---|
| **Main lobby (hub)** | `Config/HubLayout`, `Server/World/HubBuilder` | ❌ **BAD: full upgrade (this file)** |
| World 1-10 (Green Plains … Divine World) | `Config/WorldLayouts`, `Config/WorldProps`, `Workspace.Worlds.World01..10` | ⚠️ First pass (generated terrain, 6 generated meshes each, code-drawn skies). Upgrade **after** the lobby, using the same method (section 7) |
| 5 battle arenas | `BAD_GUI_8_BATTLE_SCREEN.md` §5 | New, built with the same method |

The lobby is the **first place every player sees** after PLAY and the place they return to most.
It has to sell the game in 5 seconds.

---

## 1. What's wrong with the lobby now
Take Play-mode screenshots of the current lobby from 6 angles into `docs/screens/lobby/before_*.png`
before changing anything. Then list the problems in `docs/LOBBY_AUDIT.md`. Expected findings:
- **Generic and empty:**
  - a flat plaza with a few generated props spread out
  - no strong landmark
  - nothing pulls the eye or tells the player where to go
- **Low-detail props:** simple generated meshes with flat colours, a cheap-looking portal, no
  material detail, no trim, no wear, no small set dressing (crates, banners, plants, steps,
  railings).
- **Weak ground:** a flat or blurry terrain texture, no paths, no floor pattern, no edges between
  areas.
- **Lighting and sky:** a code-drawn sky; flat light; little contrast; no light pools, glow or
  depth.
- **No life:** few particles, no moving elements (water, banners, fireflies), little ambient
  sound.
- **Unclear function:** the egg shop, merchant, arena, worlds portal and quests aren't readable
  as places with big signs and world text (`BAD_GUI_THINKING_AND_UI.md`).

## 2. The target look
The references (**layout and mood only**; never upload these images):
- `docs/brief/concept-board.png` (top-left: the hub scene)
- `docs/brief/bad-gui/08-main-menu-bg-…png` / `09-main-menu-target.png` (**they contain a
  copyrighted character**, so they're references only)
- `docs/ART_STYLE.md`

**The vision:**
- a **night sakura temple plaza** floating on a mountain shelf
- a purple starry sky with a big moon, glowing **purple cherry trees**
- **pagodas with lit windows**, warm **stone lanterns**
- a reflective **stone-tiled plaza**
- **two hero landmarks:**
  - the **1v1 ARENA** gate: a grand red torii with a round wooden sign showing crossed swords
  - the **WORLDS** portal: a temple gate with a swirling purple portal, golden sign, braziers

The style is cartoony-stylised Roblox, not realistic: clean shapes, rich colour, strong
silhouettes.

**Optional:** the owner can generate a top-down or 3/4 concept of the lobby map (no characters)
to lock the layout before building. The prompt is in `art/ui/PROMPTS_V3.md`:
> "Top-down 3/4 view concept art of a Roblox game hub map: night sakura temple plaza on a
> mountain shelf, central round plaza with a fountain, a grand red torii gate with a round '1v1
> ARENA' sign to the north, a temple gate with a swirling purple portal and 'WORLDS' sign to the
> east, an egg shop pavilion to the west, a merchant stall and a quest board near the spawn, stone
> lanterns, purple cherry trees, a small river with a wooden bridge, pagodas around the edges, no
> characters, no UI."

## 3. Layout (zones, about 220 × 220 studs, everything readable from the spawn)

```
                 N
          [1v1 ARENA GATE]
       pagoda  ─── steps ───  pagoda
                    │
 [EGG SHOP]  ── central plaza ──  [WORLDS PORTAL]
 pavilion      (fountain + statue)    temple gate
                    │
   [MERCHANT]   [SPAWN]   [QUEST BOARD]
       river + bridge, cherry grove, lanterns
                 S
```

| Zone | Contents | World text (big, outlined, billboard) |
|---|---|---|
| **Spawn** (south) | A small lantern-lit circle facing north, so the first view shows the plaza, the arena gate and the portal | none; the camera faces the landmarks |
| **Central plaza** | Round stone plaza with a fountain and a **trophy statue** (stylised, original: a giant golden card on a pedestal), petal particles, benches | none |
| **1v1 ARENA gate** (north) | A grand red torii with a round sign, two guardian statues (original), braziers. Walking through opens the Arena queue panel | **"1v1 ARENA"** with a swords icon |
| **WORLDS portal** (east) | A temple gate with an animated swirl portal (beams, particles, a pulsing light), a stone stairway | **"WORLDS"** with a globe icon |
| **Egg shop pavilion** (west) | An open pavilion with **eggs on glowing tier pedestals** (the real pack egg images on billboards), a lantern roof | **"EGGS"**, plus a price over each egg |
| **Merchant stall** | A market stall with sacks and crates, and the merchant NPC | **merchant name** + coin icon |
| **Quest board** | A wooden notice board with glowing pins | **"QUESTS"** with a "!" when claimable |
| **Daily shrine** | A small shrine with a gift chest that glows when the daily reward is ready | **"DAILY"** when ready |
| **Leaderboard** (optional) | Two stone tablets: top trophies, top collection (SurfaceGui, big text) | titles on the tablets |
| **Edges** | Pagodas, cliffs, a cherry grove, a river with a wooden bridge, distant mountains and floating islands as the backdrop. Invisible walls follow the natural edges | none |

## 4. How to build it to a high standard (no "random models")
1. **Hero props, made in Blender (Blender MCP):**
   - the torii and its sign
   - the portal temple gate and the portal frame
   - a pagoda (2 sizes)
   - the stone lantern
   - the egg pedestal
   - the fountain
   - the trophy statue

   Stylised, bevelled, with clean UVs and simple PBR/stylised materials. Each prop under about
   10k triangles, with a texture of 1024 px or smaller. Export to FBX, import, and check scale
   (1 stud ≈ 0.28 m).
2. **Secondary props:** Studio `generate_mesh` (original) and `generate_material` for custom
   MaterialVariants (stone tiles, wood, roof tiles). Plus **curated Creator Store models** (trees,
   rocks, crates), with **every script removed**, the license checked and an entry in
   `docs/ASSETS.md`.
3. **Ground:**
   - Terrain for cliffs, grass and water
   - MaterialVariants for the plaza tiles and paths
   - clear borders between zones (stone edging, steps, low walls)
4. **Set dressing:** banners that sway (a small animation), hanging paper lanterns along strings,
   flower beds, crates and sacks at the stall, bridge railings, small details near each landmark.
5. **Lighting** (a `Lighting` preset "hub"):
   - Future lighting, a moonlit night
   - Atmosphere with purple haze
   - Bloom, ColorCorrection (cool shadows, warm lights), SunRays off at night
   - light **pools under every lantern** (`PointLight`s, budgeted), and emissive windows on the
     pagodas
6. **Sky:** a proper night skybox (stars, moon, soft clouds), either licensed from the Creator
   Store or owner-generated faces (through the review gate).
7. **Life:**
   - falling petals near the trees
   - fireflies by the river
   - flowing water with a scrolling texture
   - portal particles and beams
   - lantern flicker
   - ambient sound: wind, water, distant chimes, soft music (from `Config/Sounds`)
8. **Function:** every place opens its panel through a styled prompt or walk-in trigger. The world
   text follows `BAD_GUI_THINKING_AND_UI.md`.
9. **Main menu tie-in:** the menu's cinematic camera (`BAD_GUI_4_MAIN_MENU.md`) can later use the
   real upgraded lobby instead of a painted background, from a camera point with the same
   composition as `09`.

## 5. Performance budget (mobile-first)
- StreamingEnabled on, with the lobby as one streaming area; the hero landmarks set to `Atomic`
  so they're always visible.
- About 6,000 parts or meshes at most in the lobby; instance and reuse repeated props (lanterns,
  trees).
- 40 or fewer dynamic `PointLight`s, and shadows only on the key lights.
- Particle emitters at modest rates, halved on mobile through a quality check.
- Check: client memory and frame time in Studio's MicroProfiler on a low-end device emulation;
  log the numbers in `docs/LOBBY_AUDIT.md`.

## 6. Review and acceptance
- Screenshots `docs/screens/lobby/after_*.png` from the same 6 angles as before, plus the spawn
  view, plus a phone-size view.
- A side-by-side `docs/screens/lobby/compare_lobby.png`, scored 1-10 on:
  - landmark readability
  - detail and polish
  - lighting and mood
  - life
  - clarity of where to go
  - performance

  **8+ on each** to be done.
- Asset safety: no copyrighted characters or likenesses anywhere (statues are original), every
  Creator Store model stripped of scripts and logged, every uploaded image through the review
  gate.

## 7. After the lobby: the 10 worlds (later, same method)
Each world gets:
- 2 Blender hero props
- a terrain pass by theme
- MaterialVariants
- a proper skybox, lighting and particles
- a landmark at the spawn and readable resource nodes

Order: World 1 (Green Plains) first, because new players see it first.

## 8. Checklist
- [ ] Before screenshots and `docs/LOBBY_AUDIT.md`
- [ ] (Optional) the owner's lobby concept, reviewed
- [ ] Zone layout built (spawn, plaza, arena gate, worlds portal, egg pavilion, merchant, quest
  board, daily shrine, edges)
- [ ] Hero props from Blender; secondary props (generated, curated, scripts removed, logged)
- [ ] Ground, set dressing, lighting preset "hub", night sky, life (particles, water, sound)
- [ ] World text and prompts on every place
- [ ] Performance budget met, numbers logged
- [ ] After screenshots and a comparison scoring 8+
- [ ] `UI_TARGETS.md` and `PLAN.md` §2/§6 updated, tests pass, committed
