# Lobby audit (FIX_LOBBY.md, MASTER_FIX_PLAN Phase 11)

## Before (2026-11-10, `docs/screens/lobby/before_1..6`)

Six angles of the lobby as it was (Studio, hub lighting preset):

| # | Problem (FIX_LOBBY §1) | Seen in |
|---|---|---|
| 1 | **Generic and empty:** a flat rectangular plaza with props spread along one straight path; nothing in the middle, no landmark that pulls the eye. | `before_6-top`, `before_1-spawn` |
| 2 | **The destinations don't read as places:** the arena building and the portal sit off to the sides of a long corridor; the egg stall is a small cart by the entrance; small world text. | `before_1-spawn`, `before_3-north` |
| 3 | **No zones:** one slab and one path; no plaza, steps, terrace, river or edges between areas. | `before_6-top` |
| 4 | **Missing places:** no merchant, quest board or daily shrine in the lobby. | all |
| 5 | **Flat light:** lantern pools along the path only; the landmarks aren't lit; no moon. | `before_1-spawn`, `before_2-south_high` |
| 6 | **Little life:** petals only; no water, fire, fireflies or moving elements. | all |

## After (Phase 11)

The zone plan from FIX_LOBBY §3, built in `Config/HubLayout` (data) and `Server/World/HubBuilder`:

- **Spawn** (south) on a lit circle, facing north: the lantern-string path crosses the **river** on a
  wooden **bridge** to the round **plaza**.
- **Plaza:** a round cobbled plaza with marble and neon inlays, a marble **fountain** with spray and
  light, and the **golden card statue** (an original trophy: a giant card on a pedestal, turning
  slowly), eight stone lanterns between the four paths.
- **1v1 ARENA** (north): three steps up to a terrace, the grand torii (1.6×) with a round wooden
  sign (the swords icon), the arena hall behind it, two original winged-lion guardian statues,
  two braziers with fire, swaying banners.
- **WORLDS** (east): a two-tier dais with a neon ring, the portal (2.4×) with its swirl core and
  sparks, two braziers.
- **EGGS** (west): the pavilion on a wooden floor with five glowing pedestals, each with a real
  World 1 pack egg (unedited) and its Coin price over it.
- **Merchant** (south-west): the trader's cart, crates and sacks; the lobby merchant really trades
  (the server's range check now knows the lobby's merchant point; spec added).
- **Quest board** (south-east): posts, roof, pinned notes; a big "!" over it while a quest is ready.
- **Daily shrine** (east of the path): red pillars and a gold chest that glows, with a DAILY sign,
  while today's streak reward waits.
- **Edges:** four pagodas, a ring of cherry trees, the river across the south, floating islands.
- **Life:** petals, fireflies over the river, fountain spray, brazier fire, the portal's sparks,
  lantern flicker, the card statue turning, banners swaying (client-side, off with reduced motion);
  Roblox's built-in moon in the sky.
- **World text** on every place (Billboard standard): 1v1 ARENA, WORLDS, EGGS, LANTERN TRADER,
  QUESTS, DAILY, the egg prices.

**Not done, by rule:** the Blender hero props (torii, portal gate, pagodas, lantern, fountain,
statue) and any new `generate_mesh` / `generate_material` asset. Each creates new uploaded images
(textures), so each must go through the review gate (CLAUDE.md "Asset safety" rule 4) before use.
The lobby is built so they replace today's pieces by changing `Config/HubLayout` only. A new night
skybox is the same case (owner-generated faces through the gate); the moon and stars are Roblox
built-ins. The optional leaderboard needs a ranked leaderboard store, which isn't designed yet (no
temporary logic).

## Performance (measured in Studio, see the numbers below)

Studio, Edit mode, the whole lobby built by `HubBuilder.build` (2026-11-10):

| Measure | Budget (FIX_LOBBY §5) | Lobby |
|---|---|---|
| Parts and meshes | about 6,000 | **399** (48 meshes, the rest simple parts) |
| Dynamic lights | 40 or fewer | **21** PointLights (no shadows except the stage's key lights, which aren't in the lobby) |
| Particle emitters | modest rates | **8** (petals 22/s, fireflies 10/s, fountain 18/s, four braziers 26/s, portal 14/s) |

The brazier fire emitters are built (counted above) but barely show in the Edit-mode captures; check them in the Phase 13 Play pass. Frame time on a low-end device emulation (MicroProfiler) was not measured in this pass; the counts
are far under budget. The Phase 13 final pass covers the phone-size run.

## Scores (`docs/screens/lobby/compare_lobby.png`)

| Point | Score | Why |
|---|---|---|
| Landmark readability | 9 | the torii gate with its round sign, the portal on its dais and the pavilion each own a side of the plaza, with big world text |
| Clarity of where to go | 9 | the spawn faces the bridge, the plaza and the arena gate; four paths lead out of the plaza |
| Lighting and mood | 8 | lantern pools, lit landmarks, the moon, purple haze |
| Life | 8 | petals, fireflies, fountain spray, fire, the turning statue, swaying banners, flickering lanterns |
| Performance | 9 | 399 parts, 21 lights, 8 emitters |
| Detail and polish | **7** | the architecture is simple parts; the Blender hero props wait for the review gate |
