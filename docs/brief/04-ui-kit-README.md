# 1v1 CARD — Roblox UI & Egg System Starter Kit

This is a **visual prototype pack**, not a finished economy or production game. It gives you:
- A standalone clickable browser simulation of the egg shop, egg selection, details, drop-preview panel and hatch feedback.
- 12 reusable original vector egg assets (SVG), plus 5 rarity card-frame SVGs.
- A Roblox Studio LocalScript that builds a responsive-feeling egg UI shell with a dark/purple/blue/gold theme.
- A shared Luau theme module and starter content catalog.
- A generated concept-board reference image under `assets/references/`.

## Preview the UI
Open `prototype/index.html` in Chrome, Edge or Firefox. No server or dependencies are required.

## Import into Roblox Studio
1. Open Roblox Studio and your place.
2. Create a LocalScript under `StarterPlayer > StarterPlayerScripts`.
3. Paste `roblox/StarterPlayerScripts/OneVOneCardUI.client.lua`.
4. Create a ModuleScript under `ReplicatedStorage > Modules` named `Theme` and paste `roblox/ReplicatedStorage/Modules/Theme.lua`.
5. The starter catalog JSON is a design reference; Roblox runtime data should be represented as validated ModuleScripts or server data.

## Visual direction
- Base: deep navy/near-black `#080B18`.
- Raised panels: `#12192E` / `#1A2340`.
- Primary accent: electric purple `#A469FF`.
- Secondary accent: cyan `#45BEFF`.
- Reward accent: warm gold `#FFC54B`.
- Text: soft white `#F2F5FF`; secondary text `#9EAED3`.
- Use 12–16 px corner radii, thin blue-violet strokes, restrained glow, and strong spacing.
- Cards share one geometry; rarity changes frame/accent only.

## Important production notes
- The UI's hatch buttons intentionally do not grant items. The HTML demo only changes local demo counters.
- Real egg rolls, coin deductions, inventory grants, daily claims, trade locks, and marketplace escrow must be implemented on the server.
- Never trust client-submitted rarity, price, drop result, deck power, bet amount, or ownership.
- Validate and disclose all drop rates. Add rate limits, duplicate request protection, and transaction logs.
- For Roblox publishing, use original character designs or obtain the required rights to use anime characters, names, logos, likenesses, and music. The concept board is visual inspiration, not cleared production art.
- SVG files are source-friendly design assets; Roblox UI does not render SVG directly. Export them to PNG before using as ImageLabels, or recreate the egg icons with Roblox UI/vector shapes.
- The 3D characters, rigging, VFX, animations, and battle arena are not included in this UI starter pack.

## Folder map
- `prototype/index.html` — browser UI simulation.
- `assets/eggs/*.svg` — original egg icons.
- `assets/cards/*_frame.svg` — rarity card frame templates.
- `assets/references/ui_concept_board.png` — generated style reference.
- `roblox/StarterPlayerScripts/OneVOneCardUI.client.lua` — Roblox UI shell.
- `roblox/ReplicatedStorage/Modules/Theme.lua` — shared color tokens.
- `roblox/ReplicatedStorage/Modules/ContentCatalog.json` — sample catalog data.
