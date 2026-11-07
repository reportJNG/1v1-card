# UI image set

Every UI image the game uses. Generate each one at the **exact pixel size** with a **transparent
background**, save it as `art/ui/<slot>.png`, and keep it 1024 px or smaller. The style is set in
`docs/ART_STYLE.md`.

Until a final image exists, the game uses a stand-in from `art/ui/temp/TEMP_<slot>.png`. Those are
flat vector drawings made by `scripts/art/make_temp_ui.py`, and are marked Placeholder
(`Config/ContentStatus.uiArt`). Release builds refuse them.

## How to use this list
- **Style line**: add it to every prompt. _"Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo"_
- **9-slice** is the stretchable centre rectangle `x0, y0, x1, y1` in pixels (Roblox `SliceCenter`); everything outside it (corners, edges) never stretches.
  Keep borders and rounded corners inside the margins and keep the middle plain.
- **Bleed** is how far the glow reaches outside the visible shape. Leave that many pixels of glow on every
  side; the code offsets the image so the visible edge lines up with the layout.
- No text in any image: labels, numbers and the words on banners are drawn by the game, so they
  can be localised and never blur.
- When you add a final image, tell Claude (or run the upload step in `docs/WAITING_ON_YOU.md`). Its asset id
  goes into `src/shared/Config/UiAssets.luau` (`final`), which replaces the TEMP id.

## Panels

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `panel` | 256×256 | 56, 56, 200, 200 | 14 | Every popup panel body (9-slice) |
| `panel_header` | 512×88 | 40, 40, 472, 48 | 0 | Title bar strip at the top of a panel (9-slice) |
| `panel_inset` | 128×128 | 28, 28, 100, 100 | 0 | Recessed area inside a panel (lists, odds table) |
| `shadow` | 128×128 | 48, 48, 80, 80 | 24 | Soft drop shadow behind floating panels (9-slice) |

**`panel`** (256×256)

> a square game UI panel frame, rounded corners (radius ~18 px), body is a vertical gradient from #12192E to #0C1124, a 2-3 px glowing border fading from neon purple #A469FF (top-left) to cyan #45BEFF (bottom-right), soft purple outer glow 14 px wide, subtle inner top highlight; the centre must be plain so it can be 9-sliced. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`panel_header`** (512×88)

> a wide title bar strip for the top of a game panel, rounded top corners only, slightly lighter navy #1A2340 fading downwards to transparent, thin bright cyan-to-purple glowing line along the bottom edge. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`panel_inset`** (128×128)

> a recessed inset area for a game UI, rounded corners radius 12, very dark navy #0A0F20 with a faint inner shadow at the top and a 1 px #2A3760 hairline border. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`shadow`** (128×128)

> a soft blurred black drop shadow of a rounded rectangle, 24 px blur, 50% opacity, nothing else. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Buttons

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `close_button` | 96×96 | none | 6 | Round close button (top-right of every panel) |
| `button_primary` | 256×96 | 44, 44, 212, 52 | 8 | Gold primary action button (Buy, Find Match, Save Deck) |
| `button_secondary` | 256×96 | 44, 44, 212, 52 | 8 | Secondary button (Odds, Merge, Back) |
| `button_robux` | 256×96 | 44, 44, 212, 52 | 8 | Robux egg button (shown only when allowed) |
| `button_danger` | 256×96 | 44, 44, 212, 52 | 8 | Danger button (Forfeit, Leave queue) |
| `button_plus` | 64×64 | none | 4 | Small gold + next to the Coins and Gems badges |
| `tab_on` | 192×64 | 28, 28, 164, 36 | 6 | Selected tab / selected left-menu item |
| `tab_off` | 192×64 | 28, 28, 164, 36 | 6 | Unselected tab / left-menu item |
| `menu_item` | 256×64 | 36, 28, 220, 36 | 4 | Left menu row background (Play, Cards, Deck...) |

**`close_button`** (96×96)

> a round close button for a game UI, dark navy circle #1A2340 with a glossy top highlight, thin pink-white glowing rim, a bold white X in the centre. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`button_primary`** (256×96)

> a glossy gold game button, rounded rectangle radius ~22 px, vertical gradient from bright yellow #FFE27A through #FFC54B to deep orange-gold #E08A00, a light bevel along the top edge, a darker 6 px lip along the bottom, soft warm outer glow; blank, no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`button_secondary`** (256×96)

> a game UI secondary button, rounded rectangle radius ~22 px, dark navy body #1A2340 with a slight top highlight, 2 px glowing cyan #45BEFF border, soft cyan outer glow; blank, no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`button_robux`** (256×96)

> a game UI button, rounded rectangle radius ~22 px, deep teal-green gradient body #1F8F6A to #136B4E, 2 px bright mint #48DA97 border, soft green glow; blank, no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`button_danger`** (256×96)

> a game UI button, rounded rectangle radius ~22 px, dark navy body with a 2 px glowing pink-red #FF668F border and a soft red glow; blank, no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`button_plus`** (64×64)

> a small square glossy gold game button with rounded corners radius 12, a bold dark-brown plus sign in the centre. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`tab_on`** (192×64)

> a selected tab for a game menu, rounded rectangle radius 14, glowing purple gradient #A469FF to #7B3CFF, bright 2 px light-violet border and soft purple glow; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`tab_off`** (192×64)

> an unselected tab for a game menu, rounded rectangle radius 14, dark translucent navy #12192E at 80% opacity with a faint 1 px #2A3760 border; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`menu_item`** (256×64)

> a left-side game menu row, a dark translucent navy bar that fades out to the right, rounded left end, faint purple hairline along the top and bottom; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## HUD

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `currency_badge` | 320×72 | 36, 36, 284, 36 | 4 | Coins / Gems counter pill in the top bar |
| `tile` | 128×128 | 32, 32, 96, 96 | 4 | Grid slot: eggs, cards, items (9-slice) |
| `tile_selected` | 128×128 | 32, 32, 96, 96 | 6 | Selected grid slot |
| `toast` | 512×72 | 36, 36, 476, 36 | 6 | Notification toast |

**`currency_badge`** (320×72)

> a horizontal pill-shaped counter badge for a game HUD, very dark navy #0A0F20 at 85% opacity, thin 2 px border with a soft gold glow, glossy top edge; blank, no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`tile`** (128×128)

> a square inventory slot tile for a game UI, rounded radius 12, navy gradient #1A2340 to #12192E, 1-2 px cyan-blue glowing border, faint inner top highlight; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`tile_selected`** (128×128)

> a selected square slot tile for a game UI, rounded radius 12, navy body, bright 3 px gold #FFC54B glowing border with a soft gold outer glow; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`toast`** (512×72)

> a wide notification pill for a game UI, dark navy body at 90% opacity, thin cyan glowing border; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Cards

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `card_golden_foil` | 512×716 | none | 0 | Golden copy foil overlay (on top of any frame) |
| `card_back` | 512×716 | none | 0 | Card back (hatch flip, face-down cards) |
| `card_shine` | 256×716 | none | 0 | Light sweep strip animated across Legendary/Mythical cards |

**`card_golden_foil`** (512×716)

> a transparent overlay for a trading card: thin diagonal gold foil sheen streaks and a gold inner edge glow, mostly transparent so the card shows through. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_back`** (512×716)

> the back of a trading card, portrait 5:7, deep navy with a symmetrical neon purple and cyan geometric mandala pattern, a glowing central emblem medallion, gold rim; no text. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_shine`** (256×716)

> a tall soft diagonal white light streak on a transparent background, feathered edges. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Eggs

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `egg_pedestal` | 512×256 | none | 0 | Pedestal under the featured egg in the shop and hatch |
| `egg_glow` | 256×256 | none | 0 | Rarity-tinted glow behind eggs (tinted in code) |
| `light_rays` | 512×512 | none | 0 | Rotating light rays behind the hatch reveal and Victory |
| `sparkle` | 64×64 | none | 0 | Sparkle particle (hatch, Mythical cards) |
| `crack_overlay` | 256×256 | none | 0 | Crack lines drawn over the egg during hatching |

**`egg_pedestal`** (512×256)

> a glowing circular stone pedestal seen from a 3/4 angle, dark navy stone with neon purple rune rim, soft light rays rising from it, magical. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`egg_glow`** (256×256)

> a soft round white glow, radial falloff, transparent edges. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`light_rays`** (512×512)

> radial light rays bursting from the centre, white, soft edges, transparent background. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`sparkle`** (64×64)

> a single four-pointed white sparkle star with a soft glow. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`crack_overlay`** (256×256)

> glowing white crack lines in a zig-zag pattern, transparent background, no egg. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Icons

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `icon_play` | 128×128 | none | 0 | Icon: play |
| `icon_cards` | 128×128 | none | 0 | Icon: cards |
| `icon_deck` | 128×128 | none | 0 | Icon: deck |
| `icon_shop` | 128×128 | none | 0 | Icon: shop |
| `icon_quests` | 128×128 | none | 0 | Icon: quests |
| `icon_worlds` | 128×128 | none | 0 | Icon: worlds |
| `icon_settings` | 128×128 | none | 0 | Icon: settings |
| `icon_gift` | 128×128 | none | 0 | Icon: gift |
| `icon_calendar` | 128×128 | none | 0 | Icon: calendar |
| `icon_friends` | 128×128 | none | 0 | Icon: friends |
| `icon_coin` | 128×128 | none | 0 | Icon: coin |
| `icon_gem` | 128×128 | none | 0 | Icon: gem |
| `icon_trophy` | 128×128 | none | 0 | Icon: trophy |
| `icon_power` | 128×128 | none | 0 | Icon: power |
| `icon_lock` | 128×128 | none | 0 | Icon: lock |
| `icon_check` | 128×128 | none | 0 | Icon: check |
| `icon_energy` | 128×128 | none | 0 | Icon: energy |
| `icon_hp` | 128×128 | none | 0 | Icon: hp |
| `icon_odds` | 128×128 | none | 0 | Icon: odds |
| `icon_search` | 128×128 | none | 0 | Icon: search |

**`icon_play`** (128×128)

> a game UI icon of two crossed swords, gold and white, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_cards`** (128×128)

> a game UI icon of a fan of three trading cards, purple and gold, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_deck`** (128×128)

> a game UI icon of a stack of cards with a shield emblem, cyan and white, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_shop`** (128×128)

> a game UI icon of a magical egg in a shopping basket, purple and gold, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_quests`** (128×128)

> a game UI icon of a rolled parchment scroll with a ribbon, gold and cream, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_worlds`** (128×128)

> a game UI icon of a glowing planet globe with a ring, cyan and green, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_settings`** (128×128)

> a game UI icon of a gear cog, silver with a cyan core, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_gift`** (128×128)

> a game UI icon of a gift box with a bow, pink and gold, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_calendar`** (128×128)

> a game UI icon of a calendar page with a star, white and purple, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_friends`** (128×128)

> a game UI icon of two person silhouettes, white with cyan, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_coin`** (128×128)

> a game UI icon of a shiny gold coin with a star engraving, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_gem`** (128×128)

> a game UI icon of a faceted blue diamond gem, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_trophy`** (128×128)

> a game UI icon of a gold trophy cup, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_power`** (128×128)

> a game UI icon of a gold sword pointing up-right, power stat icon, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_lock`** (128×128)

> a game UI icon of a closed padlock, steel grey, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_check`** (128×128)

> a game UI icon of a bold green check mark in a circle, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_energy`** (128×128)

> a game UI icon of a glowing cyan lightning-shaped energy crystal, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_hp`** (128×128)

> a game UI icon of a red heart, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_odds`** (128×128)

> a game UI icon of a percent sign on a small purple badge, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`icon_search`** (128×128)

> a game UI icon of a magnifying glass, white, chunky stylised shape with a dark navy 4 px outline, soft cel shading, small highlight, centred with 8 px margin. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Battle

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `timer_ring_bg` | 256×256 | none | 0 | 12 s pick timer ring (track) |
| `timer_ring_fill` | 256×256 | none | 0 | 12 s pick timer ring (fill, cropped radially in code) |
| `energy_pip_on` | 64×64 | none | 0 | Energy pip, filled (max 5) |
| `energy_pip_off` | 64×64 | none | 0 | Energy pip, empty |
| `hp_frame` | 512×48 | 24, 24, 488, 24 | 0 | HP bar frame (9-slice) |
| `hp_fill` | 512×48 | 24, 24, 488, 24 | 0 | HP bar fill (tinted green/gold/red in code) |
| `action_attack` | 192×192 | none | 0 | Attack action button art |
| `action_defend` | 192×192 | none | 0 | Defend action button art |
| `action_special` | 192×192 | none | 0 | Special action button art |
| `vs_badge` | 256×160 | none | 0 | VS badge between the two decks |

**`timer_ring_bg`** (256×256)

> a thick circular ring, dark navy #12192E with a faint purple inner edge, transparent centre. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`timer_ring_fill`** (256×256)

> a thick circular ring in solid white with a soft glow, transparent centre (tinted in code). Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`energy_pip_on`** (64×64)

> a small glowing cyan diamond crystal, bright core. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`energy_pip_off`** (64×64)

> a small empty diamond crystal socket, dark navy with a thin grey-blue outline. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`hp_frame`** (512×48)

> a horizontal health bar frame, rounded ends, dark navy inside, thin light border, glossy; empty. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`hp_fill`** (512×48)

> a horizontal health bar fill, rounded ends, white with a lighter top half and soft bottom shade (tinted in code). Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`action_attack`** (192×192)

> a round action button for a card battle, red-orange glowing rim, a bold sword slash symbol. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`action_defend`** (192×192)

> a round action button for a card battle, cyan glowing rim, a bold shield symbol. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`action_special`** (192×192)

> a round action button for a card battle, purple-pink glowing rim, a bold star-burst symbol. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`vs_badge`** (256×160)

> the letters V and S as a fiery gold and red emblem with lightning, bold anime game style. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## VFX

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `petal` | 64×64 | none | 0 | Falling cherry-blossom petal particle (hub) |
| `portal_swirl` | 512×512 | none | 0 | Rotating swirl inside the Worlds portal |

**`petal`** (64×64)

> a single soft pink cherry blossom petal, notched tip, light gradient from white-pink to pink. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`portal_swirl`** (512×512)

> a glowing magical vortex swirl seen head-on, violet and pink spiral arms with a bright white core, transparent edges. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Results

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `banner_victory` | 1024×384 | none | 0 | Victory banner (text 'Victory!' is drawn on top in code) |
| `banner_defeat` | 1024×384 | none | 0 | Defeat banner (text drawn on top in code) |
| `reward_chip` | 256×72 | 36, 36, 220, 36 | 4 | Reward pill on the results screen (+Coins, +Trophies) |

**`banner_victory`** (1024×384)

> a golden winged banner with a crown on top, ornate gold ribbon across the middle left blank for a word, light glow behind, anime game victory screen style. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`banner_defeat`** (1024×384)

> a torn dark steel-blue ribbon banner with cracked edges, muted grey and navy, left blank for a word, somber game defeat screen style. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`reward_chip`** (256×72)

> a horizontal pill-shaped reward chip, dark navy body, soft gold border glow; blank. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Card layers

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `card_border` | 512×716 | none | 0 | The card frame for every rarity, in greys (tinted per rarity in code) |
| `card_glow` | 320×420 | none | 0 | Soft outer glow behind a card (tinted, pulsed in code) |
| `card_holo` | 512×716 | none | 0 | Holo-foil band pattern over Mythical cards (coloured by a moving gradient) |
| `badge_level` | 96×96 | none | 0 | Level badge (top-left of a card, tinted, number drawn in code) |
| `badge_crown` | 96×72 | none | 0 | Crown over the level badge at level 15 |

**`card_border`** (512×716)

> a trading card frame for an anime card game, portrait 5:7, drawn entirely in white and light-to-mid grey metal (no colour, it is tinted in code): a bevelled outer border, a thin inner border, a ribbon-shaped banner socket centred on the top edge, round sockets in the top-left and top-right corners, a dark name plate across the bottom 22% with a thin divider above a stat strip, small gems at the four corners; the window inside is completely transparent. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_glow`** (320×420)

> a soft white glow in the shape of a rounded portrait card outline, feathered outward, transparent centre and edges. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_holo`** (512×716)

> a transparent overlay of thin diagonal white holographic foil bands and fine sparkle noise, mostly transparent, for a trading card. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`badge_level`** (96×96)

> a round faceted metal medal badge in white and grey (tinted in code), bevelled rim, blank centre. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`badge_crown`** (96×72)

> a small shiny gold crown with three points and gems, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Card backgrounds

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `card_bg_flame` | 320×448 | none | 0 | Flame family card background (behind the character) |
| `card_bg_ice` | 320×448 | none | 0 | Ice family card background (behind the character) |
| `card_bg_lightning` | 320×448 | none | 0 | Lightning family card background (behind the character) |
| `card_bg_shadow` | 320×448 | none | 0 | Shadow family card background (behind the character) |
| `card_bg_divine` | 320×448 | none | 0 | Divine family card background (behind the character) |
| `card_bg_beast` | 320×448 | none | 0 | Beast family card background (behind the character) |
| `card_bg_dragon` | 320×448 | none | 0 | Dragon family card background (behind the character) |
| `card_bg_warrior` | 320×448 | none | 0 | Warrior family card background (behind the character) |
| `card_bg_ninja` | 320×448 | none | 0 | Ninja family card background (behind the character) |
| `card_bg_royal` | 320×448 | none | 0 | Royal family card background (behind the character) |
| `card_bg_cosmic` | 320×448 | none | 0 | Cosmic family card background (behind the character) |
| `card_bg_ancient` | 320×448 | none | 0 | Ancient family card background (behind the character) |
| `card_bg_mystic` | 320×448 | none | 0 | Mystic family card background (behind the character) |
| `card_bg_spirit` | 320×448 | none | 0 | Spirit family card background (behind the character) |
| `card_bg_demon` | 320×448 | none | 0 | Demon family card background (behind the character) |
| `family_flame` | 64×64 | none | 0 | Flame family glyph (white, tinted in code) |
| `family_ice` | 64×64 | none | 0 | Ice family glyph (white, tinted in code) |
| `family_lightning` | 64×64 | none | 0 | Lightning family glyph (white, tinted in code) |
| `family_shadow` | 64×64 | none | 0 | Shadow family glyph (white, tinted in code) |
| `family_divine` | 64×64 | none | 0 | Divine family glyph (white, tinted in code) |
| `family_beast` | 64×64 | none | 0 | Beast family glyph (white, tinted in code) |
| `family_dragon` | 64×64 | none | 0 | Dragon family glyph (white, tinted in code) |
| `family_warrior` | 64×64 | none | 0 | Warrior family glyph (white, tinted in code) |
| `family_ninja` | 64×64 | none | 0 | Ninja family glyph (white, tinted in code) |
| `family_royal` | 64×64 | none | 0 | Royal family glyph (white, tinted in code) |
| `family_cosmic` | 64×64 | none | 0 | Cosmic family glyph (white, tinted in code) |
| `family_ancient` | 64×64 | none | 0 | Ancient family glyph (white, tinted in code) |
| `family_mystic` | 64×64 | none | 0 | Mystic family glyph (white, tinted in code) |
| `family_spirit` | 64×64 | none | 0 | Spirit family glyph (white, tinted in code) |
| `family_demon` | 64×64 | none | 0 | Demon family glyph (white, tinted in code) |

**`card_bg_flame`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #C2412D to near-black navy with rising flame tongues and embers in #FFB347, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_ice`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #7FB8E0 to near-black navy with frost crystal shards and snow motes in #E8F6FF, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_lightning`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #3A55C8 to near-black navy with zig-zag lightning bolts and sparks in #FFE14D, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_shadow`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #2B2540 to near-black navy with curling ink-smoke wisps in #9B7BFF, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_divine`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #F1E6C8 to near-black navy with soft light rays from above and floating feathers in #FFD45C, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_beast`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #8A5A3B to near-black navy with claw slash marks and drifting leaves in #D9B48A, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_dragon`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #2F7A4D to near-black navy with a dragon-scale pattern and sparks in #FF6A2B, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_warrior`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #7B8794 to near-black navy with crossed steel streaks and sparks in #D2462E, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_ninja`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #22303F to near-black navy with spinning leaves and shuriken silhouettes in #4FD1C5, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_royal`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #5B2A86 to near-black navy with a gold diamond lattice and glints in #FFC54B, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_cosmic`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #1C1F4A to near-black navy with a starfield and nebula swirl in #FF7BE5, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_ancient`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #9C8B6E to near-black navy with stone rune circles with a jade glow in #5FD3A0, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_mystic`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #3E2A6B to near-black navy with a glowing glyph circle and motes in #B98CFF, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_spirit`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #A9D8D0 to near-black navy with floating lantern-light orbs in #FFFFFF, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`card_bg_demon`** (320×448)

> an anime trading card background, portrait 5:7, no character: a deep gradient from #4A1022 to near-black navy with glowing red cracks and hellfire embers in #FF3B3B, soft glow behind the centre where the character stands, painterly but clean. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_flame`** (64×64)

> a simple bold white icon glyph for the Flame family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_ice`** (64×64)

> a simple bold white icon glyph for the Ice family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_lightning`** (64×64)

> a simple bold white icon glyph for the Lightning family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_shadow`** (64×64)

> a simple bold white icon glyph for the Shadow family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_divine`** (64×64)

> a simple bold white icon glyph for the Divine family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_beast`** (64×64)

> a simple bold white icon glyph for the Beast family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_dragon`** (64×64)

> a simple bold white icon glyph for the Dragon family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_warrior`** (64×64)

> a simple bold white icon glyph for the Warrior family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_ninja`** (64×64)

> a simple bold white icon glyph for the Ninja family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_royal`** (64×64)

> a simple bold white icon glyph for the Royal family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_cosmic`** (64×64)

> a simple bold white icon glyph for the Cosmic family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_ancient`** (64×64)

> a simple bold white icon glyph for the Ancient family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_mystic`** (64×64)

> a simple bold white icon glyph for the Mystic family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_spirit`** (64×64)

> a simple bold white icon glyph for the Spirit family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`family_demon`** (64×64)

> a simple bold white icon glyph for the Demon family of an anime card game, flat, isolated. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

## Card cutouts (TEMP)

| Slot | Size (px) | 9-slice | Bleed | Used for |
| --- | --- | --- | --- | --- |
| `cutout_striker_line` | 384×512 | none | 0 | TEMP Striker character cutout, line layer (replaced by the character's own art) |
| `cutout_striker_skin` | 384×512 | none | 0 | TEMP Striker character cutout, skin layer (replaced by the character's own art) |
| `cutout_striker_outfit` | 384×512 | none | 0 | TEMP Striker character cutout, outfit layer (replaced by the character's own art) |
| `cutout_striker_accent` | 384×512 | none | 0 | TEMP Striker character cutout, accent layer (replaced by the character's own art) |
| `cutout_guardian_line` | 384×512 | none | 0 | TEMP Guardian character cutout, line layer (replaced by the character's own art) |
| `cutout_guardian_skin` | 384×512 | none | 0 | TEMP Guardian character cutout, skin layer (replaced by the character's own art) |
| `cutout_guardian_outfit` | 384×512 | none | 0 | TEMP Guardian character cutout, outfit layer (replaced by the character's own art) |
| `cutout_guardian_accent` | 384×512 | none | 0 | TEMP Guardian character cutout, accent layer (replaced by the character's own art) |
| `cutout_skirmisher_line` | 384×512 | none | 0 | TEMP Skirmisher character cutout, line layer (replaced by the character's own art) |
| `cutout_skirmisher_skin` | 384×512 | none | 0 | TEMP Skirmisher character cutout, skin layer (replaced by the character's own art) |
| `cutout_skirmisher_outfit` | 384×512 | none | 0 | TEMP Skirmisher character cutout, outfit layer (replaced by the character's own art) |
| `cutout_skirmisher_accent` | 384×512 | none | 0 | TEMP Skirmisher character cutout, accent layer (replaced by the character's own art) |
| `cutout_trickster_line` | 384×512 | none | 0 | TEMP Trickster character cutout, line layer (replaced by the character's own art) |
| `cutout_trickster_skin` | 384×512 | none | 0 | TEMP Trickster character cutout, skin layer (replaced by the character's own art) |
| `cutout_trickster_outfit` | 384×512 | none | 0 | TEMP Trickster character cutout, outfit layer (replaced by the character's own art) |
| `cutout_trickster_accent` | 384×512 | none | 0 | TEMP Trickster character cutout, accent layer (replaced by the character's own art) |
| `cutout_support_line` | 384×512 | none | 0 | TEMP Support character cutout, line layer (replaced by the character's own art) |
| `cutout_support_skin` | 384×512 | none | 0 | TEMP Support character cutout, skin layer (replaced by the character's own art) |
| `cutout_support_outfit` | 384×512 | none | 0 | TEMP Support character cutout, outfit layer (replaced by the character's own art) |
| `cutout_support_accent` | 384×512 | none | 0 | TEMP Support character cutout, accent layer (replaced by the character's own art) |
| `cutout_bruiser_line` | 384×512 | none | 0 | TEMP Bruiser character cutout, line layer (replaced by the character's own art) |
| `cutout_bruiser_skin` | 384×512 | none | 0 | TEMP Bruiser character cutout, skin layer (replaced by the character's own art) |
| `cutout_bruiser_outfit` | 384×512 | none | 0 | TEMP Bruiser character cutout, outfit layer (replaced by the character's own art) |
| `cutout_bruiser_accent` | 384×512 | none | 0 | TEMP Bruiser character cutout, accent layer (replaced by the character's own art) |

**`cutout_striker_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Striker silhouette raising a big sword overhead in one hand, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_striker_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Striker silhouette raising a big sword overhead in one hand, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_striker_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Striker silhouette raising a big sword overhead in one hand, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_striker_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Striker silhouette raising a big sword overhead in one hand, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_guardian_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Guardian silhouette braced behind a large shield, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_guardian_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Guardian silhouette braced behind a large shield, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_guardian_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Guardian silhouette braced behind a large shield, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_guardian_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Guardian silhouette braced behind a large shield, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_skirmisher_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Skirmisher silhouette in a low lean with a dagger in each hand and a trailing scarf, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_skirmisher_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Skirmisher silhouette in a low lean with a dagger in each hand and a trailing scarf, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_skirmisher_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Skirmisher silhouette in a low lean with a dagger in each hand and a trailing scarf, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_skirmisher_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Skirmisher silhouette in a low lean with a dagger in each hand and a trailing scarf, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_trickster_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Trickster silhouette fanning three cards in one hand, cape flaring, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_trickster_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Trickster silhouette fanning three cards in one hand, cape flaring, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_trickster_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Trickster silhouette fanning three cards in one hand, cape flaring, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_trickster_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Trickster silhouette fanning three cards in one hand, cape flaring, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_support_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Support silhouette holding a tall staff topped with a glowing orb, long robe, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_support_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Support silhouette holding a tall staff topped with a glowing orb, long robe, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_support_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Support silhouette holding a tall staff topped with a glowing orb, long robe, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_support_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Support silhouette holding a tall staff topped with a glowing orb, long robe, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_bruiser_line`** (384×512)

> TEMPORARY stand-in only: the line layer of a flat anime-style Bruiser silhouette with broad shoulders and huge gauntlet fists raised, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_bruiser_skin`** (384×512)

> TEMPORARY stand-in only: the skin layer of a flat anime-style Bruiser silhouette with broad shoulders and huge gauntlet fists raised, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_bruiser_outfit`** (384×512)

> TEMPORARY stand-in only: the outfit layer of a flat anime-style Bruiser silhouette with broad shoulders and huge gauntlet fists raised, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.

**`cutout_bruiser_accent`** (384×512)

> TEMPORARY stand-in only: the accent layer of a flat anime-style Bruiser silhouette with broad shoulders and huge gauntlet fists raised, upper body to knees, greyscale so it can be tinted. Roblox anime card battler UI, dark navy and purple night theme with neon violet and cyan glow, glossy, clean vector game UI, crisp edges, soft outer glow, centred, isolated on a fully transparent background, no text, no letters, no watermark, no logo.
