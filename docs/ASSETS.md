# Asset list

Every external or uploaded asset the game uses, where it came from, its license, and what it is for.
Rules (docs/ART_STYLE.md section 8):
- Creator Store models have every `Script`, `LocalScript` and `ModuleScript` removed before use.
- Nothing is used as-is.
- Copied game music or SFX ripped from commercial games are never used.

## Uploaded by this project (owner's account)

| What | Asset ids | Source | License / notes |
| --- | --- | --- | --- |
| 24 egg icons, normal + Golden (47 files; the pack has no Golden Rainbow) | `Config/Eggs` (`normalAssetId`, `goldenAssetId`) | "Eggs Icon Pack v2 (Basic)" by gvesster, `Downloads/Eggs Icon Pack v2 (Basic)/<Egg>/256w/*.png` | Purchased pack. Commercial use allowed; **no edits, recolours or resale**. Uploaded byte-for-byte unchanged. Optional credit: @gvesster |
| 63 TEMP UI images (panels, buttons, tabs, badges, 5 card frames, card back, foil, pedestal, glow, rays, 20 icons, timer ring, pips, HP bar, action buttons, VS badge, banners) | `Config/UiAssets` (`temp`), list in `art/ui/temp/ids.json` | Drawn by `scripts/art/make_temp_ui.py` (pure code, no third-party art) | Project-owned. **Placeholder**: replaced by the owner's final art (`art/ui/PROMPTS.md`) |
| 2 VFX textures (petal, portal swirl) | `Config/UiAssets` (`petal`, `portal_swirl`) | `scripts/art/make_temp_ui.py` | Project-owned (code-drawn) |
| Hub night skybox (6 faces) | `Config/Lighting` (`HUB_SKY`) | `scripts/art/make_sky.py` → `art/sky/hub_*.png` | Project-owned (code-drawn) |
| 10 world skyboxes (60 faces) | `Config/Lighting` (`world1..10`), list in `art/sky/ids.json` | `scripts/art/make_sky.py world` → `art/sky/w<n>_*.png` | Project-owned (code-drawn) |
| 10 world picker thumbnails | `Config/WorldArt` | Studio captures of the built worlds, cropped by a PowerShell script → `art/worlds/TEMP_world_thumb_<n>.png` | Project-owned. **Placeholder** until key art exists |

## Generated with Roblox's `generate_mesh` (owner's account, original)

All original meshes made from text prompts in Studio. Each is one textured MeshPart, built at runtime
from `Config/HubLayout` (`Models`). They contain no scripts.

| Model key | Generated asset | Mesh id | Texture id | Use |
| --- | --- | --- | --- | --- |
| `torii` | 90954891101188 | 138127000240516 | 104005221765615 | Torii gates over the hub path, arena backdrop |
| `pagoda` | 94406104615641 | 104043512113261 | 118302930204062 | Temple backdrop (hub, arena) |
| `cherry_tree` | 80052616762492 | 107670497033603 | 83193632355922 | Hub and arena trees |
| `stone_lantern` | 119549729539198 | 109848804615944 | 108408962041665 | Path lanterns (with PointLights) |
| `portal` | 104345808840073 | 79896909448972 | 124301083779520 | The Worlds portal ring |
| `arena` | 88142587129921 | 122652870592090 | 124121732817210 | The 1v1 Arena hall |
| `egg_stall` | 84900154412192 | 127204934830226 | 88267860513211 | The egg shop stall |
| `sky_island` | 133306357261870 | 99889481361002 | 79896407781887 | Floating islands on the horizon |
| `lantern_post` | 106757853537193 | 73686400801830 | 138853853468308 | Paper-lantern posts |
| _(unused)_ stone stairs | 101477790684882 | 130636793569839 | 115656331234080 | Came out too narrow; not placed |

**World props (session 3).** 62 more meshes, made the same way from text prompts, for the 10 worlds:
2 shared (`merchant_cart`, `guardian_gate`), and per world 3-4 scenery props plus one mesh for each of
its 3 resource node types (`w<n>_<item>`). Every mesh id, texture id, native size and a one-line
description is in `src/shared/Config/WorldProps.luau`, which is the list of record. They contain no
scripts. The worlds reuse the hub's `portal` mesh for the Back to Lobby portal.

## Creator Store assets

| Asset id | Name | Creator | Type | Used for | Scripts removed | License check |
| --- | --- | --- | --- | --- | --- | --- |
| _(none yet)_ | | | | | | |

## Audio

| Slot (`Config/Sounds`) | Asset id | Name | Creator | Notes |
| --- | --- | --- | --- | --- |
| `music_menu` | 1837864564 | Team of Heroes (Mus) | APMOfficial | Main menu |
| `music_hub` | 1840401478 | Yachiyo-Jishi | APMOfficial | Hub |
| `music_battle` | 9048541013 | Battleground | APMOfficial | Battles |
| `victory` | 1844384292 | Sports Fanfare | APMOfficial | Victory sting |
| `open` | 1837834196 | Reverse Quick Swipe - Light Swipe 02 | APMOfficial | Panel open |
| `music_world1` | 1836352521 | Sunny Sights | APMOfficial | Green Plains |
| `music_world2` | 1838926651 | Natural Planet | APMOfficial | Enchanted Forest |
| `music_world3` | 1840540809 | Sunset Song | APMOfficial | Desert Kingdom |
| `music_world4` | 9039666736 | Magical Night (b) | APMOfficial | Frozen Lands |
| `music_world5` | 1839685565 | Light The Fire | APMOfficial | Volcano |
| `music_world6` | 9043600381 | Mystery Mansion (b) | APMOfficial | Demon Realm |
| `music_world7` | 1844581845 | Space Fantasy | APMOfficial | Celestial Islands |
| `music_world8` | 1838829561 | Mysterious Gate | APMOfficial | Ancient Kingdom |
| `music_world9` | 9044407121 | Back to the Shadows Underscore | APMOfficial | Shadow Dimension |
| `music_world10` | 1840939025 | Ideal World (a) | APMOfficial | Divine World |

The world tracks were picked by title and description (Claude can't hear audio); the owner reviews
them (`docs/WAITING_ON_YOU.md`). Other SFX slots stay empty and silent until ids are chosen.

Audio policy: use APMOfficial (music) and ProSoundEffects (SFX). Both are Roblox's licensed partner
libraries, free for use in Roblox experiences. Never use uploads ripped from commercial games
(Valve, Undertale, Final Fantasy, Garry's Mod and so on), which show up often in search results.

## Roblox built-ins (no upload)

| What | Where |
| --- | --- |
| Fonts: Luckiest Guy, Builder Sans | `Theme.Face` |
