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

## Creator Store assets

| Asset id | Name | Creator | Type | Used for | Scripts removed | License check |
| --- | --- | --- | --- | --- | --- | --- |
| _(none yet)_ | | | | | | |

## Audio

| Slot (`Config/Sounds`) | Asset id | Name | Creator | Notes |
| --- | --- | --- | --- | --- |
| _(all slots empty: the game stays silent until ids are chosen)_ | | | | |

Audio policy: use APMOfficial (music) and ProSoundEffects (SFX). Both are Roblox's licensed partner
libraries, free for use in Roblox experiences. Never use uploads ripped from commercial games
(Valve, Undertale, Final Fantasy, Garry's Mod and so on), which show up often in search results.

## Roblox built-ins (no upload)

| What | Where |
| --- | --- |
| Fonts: Luckiest Guy, Builder Sans | `Theme.Face` |
