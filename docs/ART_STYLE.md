# 1v1 CARD: Art Style Guide

Everything visual in the game follows this guide: UI images, 3D characters, card portraits, worlds,
VFX and icons. The reference is `docs/brief/concept-board.png`, which sets the **mood and layout
only**. Its characters, its "Bet Amount" panel and its anime IP are not part of the game.
`docs/brief/05-ui-design-system.md` is the token source. This guide extends it and never
contradicts it.

The code mirrors this file in `src/client/App/Theme.luau` (colours, fonts, sizes) and
`src/shared/Config/UiAssets.luau` (image slots). When the two disagree, fix the code.

---

## 1. Mood in one line

A **neon night festival in a floating anime temple city**: deep navy and purple darkness, violet
and cyan glow, warm gold for everything you can win or press, and soft cherry-blossom pink as
the accent of the world.

## 2. Palette

### Base (UI and world shadows)

| Token | Hex | Use |
| --- | --- | --- |
| `Night` | `#05070F` | Deepest shadow, vignette, letterbox |
| `Background` | `#080B18` | Canvas behind panels |
| `Panel` | `#12192E` | Panel body (top of its gradient) |
| `PanelDeep` | `#0C1124` | Panel body (bottom of its gradient) |
| `Raised` | `#1A2340` | Tiles, slots, inputs |
| `RaisedHi` | `#243058` | Hovered/selected tile |
| `Stroke` | `#2A3760` | Hairlines, dividers |

### Neon (glow and accents)

| Token | Hex | Use |
| --- | --- | --- |
| `Purple` | `#A469FF` | Main glow: panel borders, selection, Epic |
| `Violet` | `#7B3CFF` | Deep end of the purple glow gradient |
| `Blue` | `#45BEFF` | Cyan glow: info, secondary buttons, Rare |
| `Pink` | `#FF7BD5` | World accent: blossoms, portal rim, Mythical shimmer |

### Reward and state

| Token | Hex | Use |
| --- | --- | --- |
| `Gold` | `#FFC54B` | Currency, primary CTA, Legendary |
| `GoldHi` | `#FFE27A` | Top of the gold button gradient |
| `GoldLo` | `#E08A00` | Bottom of the gold button gradient |
| `GoldInk` | `#3A2200` | Text on gold buttons (never white) |
| `Green` | `#48DA97` | Success, owned, "Completed" |
| `Red` | `#FF668F` | Damage, errors, Mythical |
| `Text` | `#F2F5FF` | Primary copy |
| `Muted` | `#9EAED3` | Secondary copy |

### Rarity (always shown with the rarity **name**, never colour alone)

| Rarity | Main | Glow | Frame treatment |
| --- | --- | --- | --- |
| Common | `#B9C7DC` | `#8C99AE` | Single silver border, no glow |
| Rare | `#45BEFF` | `#1E6FB8` | Cyan border, soft inner glow |
| Epic | `#A469FF` | `#6A35C9` | Violet double border, glow |
| Legendary | `#FFC54B` | `#B8791A` | Gold double border, glow, light sweep |
| Mythical | `#FF668F` | `#A469FF` | Pink→violet→cyan border, glow, light sweep, sparkles |
| Golden copy | `#FFE08A` | `#C98A1C` | Gold foil over any frame (cosmetic only) |

Rarity changes **only** the border, foil and particles. The card silhouette, layout and character
art style are identical across rarities (design-system rule 6).

### Family colours (character palette leads and family VFX)

Each character uses a 3-colour scheme: the family **body** colour leads, the family **accent** is
the glow/trim, and one personal colour comes from the character's own design. These are the
values in `Config/Art.FamilyColors`.

| Family | Body | Accent | VFX motif |
| --- | --- | --- | --- |
| Flame | `#C2412D` | `#FFB347` | embers, heat shimmer, fire ribbons |
| Ice | `#7FB8E0` | `#E8F6FF` | snow motes, crystal shards, frost rings |
| Lightning | `#3A55C8` | `#FFE14D` | arcs (Beams), sparks, flash |
| Shadow | `#2B2540` | `#9B7BFF` | ink smoke, purple wisps |
| Divine | `#F1E6C8` | `#FFD45C` | light rays, feathers, halo rings |
| Beast | `#8A5A3B` | `#D9B48A` | dust bursts, claw slashes, leaves |
| Dragon | `#2F7A4D` | `#FF6A2B` | scale sparks, fire breath cone |
| Warrior | `#7B8794` | `#D2462E` | steel sparks, slash arcs |
| Ninja | `#22303F` | `#4FD1C5` | leaves, smoke puffs, afterimages |
| Royal | `#5B2A86` | `#FFC54B` | gold glints, crown sparkles |
| Cosmic | `#1C1F4A` | `#FF7BE5` | stars, nebula swirl |
| Ancient | `#9C8B6E` | `#5FD3A0` | runes, stone chips, jade glow |
| Mystic | `#3E2A6B` | `#B98CFF` | glyph circles, motes |
| Spirit | `#A9D8D0` | `#FFFFFF` | wisps, lantern lights |
| Demon | `#4A1022` | `#FF3B3B` | hellfire, red cracks |

## 3. Typography

All Roblox built-in fonts, so no upload is needed.

| Role | Font | Weight | Use | Size (960×540 design space) |
| --- | --- | --- | --- | --- |
| **Display** | Luckiest Guy (`Enum.Font.LuckiestGuy`) | built-in heavy | Logo, "Victory!", "Defeat", hatch rarity callout, big damage numbers | 40–72 |
| **Title** | Builder Sans | ExtraBold (800) | Panel titles ("Egg Shop"), tab labels, button labels | 18–28 |
| **Number** | Builder Sans | Heavy (900) | Prices, currency counts, power, timers | 14–32 |
| **Body** | Builder Sans | Medium (500) / Bold (700) | Descriptions, stats, odds rows | 12–16 |

Rules:
- Display text always has a dark `UIStroke` (2–3 px, `Night`), and either a gold vertical
  gradient (Victory, Legendary) or white with a coloured stroke (damage numbers).
- Titles are white with a 1 px `Night` stroke at 40% transparency.
- Text on gold buttons is `GoldInk`, never white.
- The minimum size is 12 in the design space, which is about 11 pt on a phone after UIScale.

## 4. UI rules

### Shapes
- **Corner radius**: panels 16, tiles and cards 10, buttons 12, pills and badges fully rounded.
  The 9-slice art bakes the radius in, and code-drawn fallbacks use the same values.
- **Panels**: a vertical body gradient (`Panel` → `PanelDeep`), a 2 px border glowing
  `Purple`→`Blue` along a diagonal, a 12–18 px outer glow at 60% transparency, and a title bar
  with an icon chip on the left and a round close button on the right (as on the board).
- **Shadow**: every floating panel casts a soft drop shadow (`Night`, offset 0/6, blur 18, 50%).
- **Spacing**: an 8-point grid. Panel padding is 16, gaps between tiles are 8–10, and the left
  menu items are 44 tall (the minimum tap target on a phone after scaling).

### Buttons
| Kind | Look | Use |
| --- | --- | --- |
| Primary | Gold vertical gradient (`GoldHi`→`Gold`→`GoldLo`), 2 px light top bevel, dark bottom lip, `GoldInk` label | **One per panel**: Buy, Find Match, Save Deck, Continue |
| Secondary | `Raised` body with a `Blue` 2 px glow border, white label | Odds, Merge, Sell, Back |
| Robux | Green-teal body with a ⏣ label, same shape as Secondary | Robux egg buy (only shown when allowed) |
| Danger | `Raised` body, `Red` border | Forfeit, Leave queue |
| Disabled | 50% transparent, no glow, no motion | Not affordable, not unlocked |
| Icon / close | A 36 px circle, `Raised` with a white ✕, pink glow on hover | Close |
| Plus | A small square gold button with a dark + | Next to currency badges |

### Motion (TweenService, never every element at once)
- **Open**: scale 0.85 → 1.04 → 1.0 (Back out, 0.22 s) plus fade-in. **Close**: 1.0 → 0.9 and
  fade (Quad in, 0.12 s).
- **Hover**: the border glow brightens and the scale rises to 1.04 (0.08 s). **Press**: squash
  to 0.94 (0.06 s), then a spring back.
- **Numbers**: currency and rewards count up over 0.6 s (Quad out), and a gold pop on change.
- **Selection**: a pulsing glow on the selected tile (1.2 s sine loop).
- **Hatch reveal, victory, specials**: the only full-screen motion. Their sequence is in
  section 7.
- Reduce motion (Settings): skip squash, bounce and shake; keep fades.

### Layout (mobile first)
- 960×540 design space with one UIScale, so it fits every device.
- Respect `GuiService:GetGuiInset()` and the safe-area insets (`ScreenInsets = CoreUISafeInsets`).
- Left menu: an icon + label column, 44 px rows. The top bar is centred: Coins and Gems badges
  with + buttons, then the gift, calendar and friends icons, as on the board.
- Popups are centred and keep their ratio with `UIAspectRatioConstraint`.
- Test at phone (844×390), tablet (1024×768) and PC (1920×1080).

### Cards (one silhouette)
- A 5:7 portrait card. The art fills the card, and the frame overlays it with the rarity tag
  (top-left, e.g. "EPIC"), the family badge (top-right), the name plate (bottom) and the power
  chip (bottom-left sword icon + number).
- The rarity tag uses words, never "SSR/UR".
- Golden copies add the foil overlay and a small "GOLDEN" ribbon.

## 5. Character style

- **Anime cel-shaded**, two-tone shading with a hard terminator, plus a thin dark ink outline
  (inverted-hull in Blender, or `SurfaceAppearance` + outline mesh in Roblox).
- **Proportions are fixed for all 100**: 6 heads tall, the head slightly large (1/6 of the
  height), hands and feet a little chunky, about 5.5 studs tall on an R15 rig, feet at the
  origin, facing −Z.
- **Silhouette first**: one signature shape per character (weapon, hair, cape, horns, tail) that
  reads at 48 px. Test by filling the render black: two characters in one family must not have
  the same silhouette.
- **Colour**: the 3-colour family scheme above. Rarity never changes a model's palette, so a
  Common is as handsome as a Mythical.
- **Faces**: 2D painted texture decals with expression swaps (neutral, angry, hurt, happy).
- **Budget**: ≤ 10k triangles, one ≤ 1024² colour atlas, Neon parts and particles for glow.
- **Never**: costumes, hair, emblems or colourways of an existing character. That includes
  cloud-pattern cloaks, bandaged or blindfolded eyes, straw hats, orange jumpsuits and forehead
  protectors.
- **Image prompts** use one fixed template (`art/characters/PROMPTS.md`), so the whole roster has
  the same camera, pose and lighting.

### Card portraits (render booth)
A fixed camera at 35 mm equivalent, the character framed from mid-thigh up, 3/4 turned with a
dynamic pose. A key light warm from upper-left, a strong rim light in the family accent colour
from behind-right, a soft navy fill, and a navy→purple background gradient with family particles.
The output is 512×716 PNG. The same booth is used for every character.

## 6. Lighting and post-processing

### Hub (the temple plaza, night festival)
| Setting | Value |
| --- | --- |
| Technology | Future |
| ClockTime | 20.5 (moonlit night), GeographicLatitude 30 |
| Ambient / OutdoorAmbient | `#2A2050` / `#3A2C6E` |
| Brightness | 2 |
| EnvironmentDiffuse / Specular | 0.5 / 0.6 |
| Atmosphere | Density 0.32, Offset 0.15, Color `#6E4BC4`, Decay `#2A1450`, Glare 0.4, Haze 1.8 |
| Bloom | Intensity 0.8, Size 28, Threshold 1.4 |
| ColorCorrection | Brightness 0.02, Contrast 0.12, Saturation 0.18, Tint `#F2ECFF` |
| SunRays | Intensity 0.06, Spread 0.6 |
| DepthOfField | Off in play; FarIntensity 0.15 for menus with the 3D background |
| Sky | Custom purple-night skybox (star field + nebula), moon angular size 14 |

Practical lights: warm lanterns (`#FFB45A`, PointLight range 14, brightness 1.6), violet neon
trims on the pagodas (`#A469FF`), and the portal core (`#C77DFF` with a pink rim). Cherry trees
use `#FF9AD5` leaves with a slight emission via Neon accents.

### Battle arena (a stage in the dark)
| Setting | Value |
| --- | --- |
| Technology | Future |
| ClockTime | 0 (no sun) and a dark sky |
| Ambient | `#140F2A`, OutdoorAmbient `#1C1640` |
| Atmosphere | Density 0.45, Color `#3A2470`, Haze 2.2 |
| Bloom | Intensity 1.0, Size 32, Threshold 1.2 |
| ColorCorrection | Contrast 0.18, Saturation 0.22 |
| Key lights | Two SpotLights over each fighter's mark (white-violet, angle 50, brightness 6) |
| Rim | Each side gets a SpotLight from behind in its card's family accent |
| Floor | A dark glossy stage with a glowing ring (`Purple`) and side ring (`Blue`) |

### Farming worlds
Each world gets its own lighting block in `Config/Worlds` (`lighting = {…}`), and the client
tweens to it on travel. Worlds 1–3 are day-lit and saturated; from world 5 they get darker
and more neon. The lights stay within the budget below.

### Budgets
- At most 12 shadow-casting lights in view. Lanterns use `Shadows = false`.
- Particles: ≤ 40 emitters active in the hub, rates ≤ 20/s each.
- Textures ≤ 1024², UI images ≤ 1024².

## 7. VFX and game feel

| Moment | Sequence |
| --- | --- |
| Hatch | Camera eases to the egg (0.4 s), shake ×3 rising, crack flash, white→rarity-colour light burst, card flip-in with rarity callout (Display font), sparkles for Epic+, gold foil sweep for Golden |
| Basic attack | Lunge 0.25 s, hit-stop 0.06 s, damage number pops (white, red stroke), small shake |
| Special | Camera cut to the attacker (0.3 s), family VFX, hit-stop 0.12 s, big number (Display font, family colour), medium shake |
| Defend / parry | Blue shield bubble. A parry flashes cyan with "PARRY!" |
| KO | Slow-mo 0.3 s, desaturate, the fighter falls, a rarity-coloured spark burst |
| Victory | Gold "Victory!" banner drop with a bounce, light rays behind, rewards count up |
| Defeat | Desaturated "Defeat" banner, softer fade, rewards (consolation) count up |

Sound: soft UI clicks on every button, a coin chime on currency gain, a whoosh per open/close,
hit impacts per family, and a looping track per area (hub, battle, each world group). All audio
is free Creator Store audio, listed in `docs/ASSETS.md`.

## 8. Asset pipeline rules

1. Images and models come from this pipeline only: AI-generated images from the fixed prompts,
   Blender renders, Roblox generation tools, or Creator Store models that are curated, restyled
   and cleaned. Never stack random primitives, and never use a free model as-is.
2. Every Creator Store asset has all `Script`/`LocalScript`/`ModuleScript` removed before use,
   its license checked, and a row in `docs/ASSETS.md` (asset id, source, creator, use).
3. The egg icons come from the licensed pack and are used **unedited** (no recolours or crops).
   Hatch effects are separate overlays.
4. Temporary images are named `TEMP_*.png` and listed as Placeholder in
   `Config/ContentStatus`. Release builds refuse them.
