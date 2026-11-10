# UI art prompts, V3 (MASTER_FIX_PLAN.md "Owner art list")

Every image the owner generates for the master fix plan, in priority order. Copy a prompt into
the same image tool the reference boards were made with, attach the named target image as the
style reference, and generate at the largest size available.

**For every sheet:**
- a **flat magenta (#FF00FF) background** (or real transparency if the tool can do it)
- **no text**, except where a prompt says the words are baked in
- pieces **spaced apart**, so `scripts/art/cut_sheet.py` can find each one
- **no characters**, no anime or franchise likenesses, no logos
- save as `art/ui/sheets/<file>` (the file names below)

**What happens next** (`MASTER_FIX_PLAN.md`): `cut_sheet.py` → name pieces in
`art/ui/kit-v3/kit.json` → 9-slice test → contact sheet in `docs/review/` → **your OK** → upload
(5 or fewer at a time, stop on any rejection) → status `LIVE` → screen compare, 8+.

⚠️ **Reference images that must never be uploaded or cut:** `08-main-menu-bg-REFERENCE-ONLY…`,
`09-main-menu-target.png` (a copyrighted character stands in it), `11-…REFERENCE-ONLY…`,
`14-…REFERENCE-ONLY…`, `15-…REFERENCE-ONLY…` and the `hd-03`/`hd-04` boards (copyrighted card
art). Attach them to the image tool only as style references; never put them in the game.

| # | Sheet | File | For | Spec |
|---|---|---|---|---|
| 1 | A: panel / button / pill kit | `eggshop_frame.png` | HUD, menu, shop, panels, deck | `BAD_GUI_3` §4 |
| 2 | E1-E4: HUD buttons, currency, quest panel, deck cards | `hud_buttons.png`, `hud_currency.png`, `hud_quest.png`, `hud_deckcards.png` | HUD | `BAD_GUI_5` §3 |
| 3 | D1-D4: menu background, logo, buttons, pills | `menu_bg.png`, `logo.png`, `menu_buttons.png`, `menu_pills.png` | main menu | `BAD_GUI_4` §3 |
| 4 | B: egg tiles by tier | `eggshop_tiles.png` | Egg Shop, inventory | `BAD_GUI_3` §4 |
| 5 | Merchant kit + icon sheet | `merchant_kit.png`, `icons.png` | merchant, every panel | `BAD_GUI_2` §3 |
| 6 | H1-H2: battle action cards, top HUD | `battle_actions.png`, `battle_top.png` | battle | `BAD_GUI_8` §6 |
| 7 | G1-G2: result banners, result pieces | `result_banners.png`, `result_pieces.png` | result | `BAD_GUI_7` §4 |
| 8 | F1: inventory/deck extras | `inv_extras.png` | deck, inventory | `BAD_GUI_6` §4 |
| 9 | C: crystal eggs (only if you pick Option 2) | `eggs_crystal_1..4.png` | Egg Shop | `BAD_GUI_3` §4.1 |
| 10 | Lobby concept (optional) | `lobby_concept.png` | lobby | `FIX_LOBBY` §2 |

---

## 1. Sheet A: panel / button / pill kit → `eggshop_frame.png`
Reference: `docs/brief/bad-gui/06-egg-shop-target.png` (or `docs/brief/ui-refs/hd-02-egg-shop.png`).

> Roblox mobile game UI component sheet in exactly the style of the attached Egg Shop image: dark
> purple glass panels with glowing violet borders, gold accents, glossy. NO TEXT anywhere. Flat
> magenta background, every piece separated with empty space. Pieces: 1 large empty main panel
> frame; 1 header bar with a round empty icon socket on the left; 1 round close button with white
> X; 1 tall ornate GOLD featured-item frame (empty, with golden flourish wings at the bottom for
> an item to sit on); 1 large glossy GOLD empty button; 1 glossy PURPLE empty button; 1 glossy
> GREY disabled empty button; 1 dark empty price pill with a gold coin on the left; 1 tab button
> 'on' and 1 tab button 'off' (empty); 1 small empty page arrow (left) and (right).

## 2. Sheets E1-E4: the in-game HUD
References: `13-target-currency-bars.png`, `12-target-quest-panel.png`,
`02-good-roblox-hud-reference.png` (layout only).

**E1. HUD buttons → `hud_buttons.png`**
> Four big chunky square Roblox game HUD buttons in the style of the attached images: glossy,
> thick dark outline, rounded corners, darker bottom lip, big centered icon. (1) red-orange with
> a backpack full of cards icon, (2) orange-gold with an egg icon, (3) purple with a glowing
> portal / globe icon, (4) teal-blue with crossed swords icon. Plus one small round dark button
> with a three-line menu icon, and one small square gift-box button. No text. Flat magenta
> background, separated.

**E2. Currency pills → `hud_currency.png`**
> Two Roblox game currency bars in exactly the style of the attached currency image: a long dark
> glass pill with a gold rim and a big shiny gold coin overlapping the left end and a round
> glossy gold '+' button on the right end; and the same with a blue rim, a big shiny blue diamond
> and a round glossy blue '+'. Empty, NO numbers. Flat magenta background, separated.

**E3. Quest panel → `hud_quest.png`**
> Quest tracker panel pieces in exactly the style of the attached tutorial image: a dark blue
> panel with gold trim and an angled header plate (empty, no text); a gold trophy with three gold
> stars; a small dark counter pill; an empty square checkbox and a checked green checkbox; a thin
> progress bar background and a gold fill bar. No text. Flat magenta background, separated.

**E4. Deck bar card pieces → `hud_deckcards.png`**
Reference: `11-target-deck-bar-REFERENCE-ONLY…` (layout only: its card art is copyrighted).
> Tall trading-card frames for a Roblox game HUD in the style of the attached deck-bar image, NO
> characters, NO art inside (empty window): frames in grey, blue, purple, gold and green; a small
> round element-icon socket for the top-left corner; a dark bottom strip with five empty star
> slots; a filled gold star; a small square number box. No text. Flat magenta background,
> separated.

## 3. Sheets D1-D4: the main menu
Reference: `09-main-menu-target.png`, **style and layout only**: the character in it is a
copyrighted likeness (white spiky hair, blindfold) and the cards in his hand show anime
characters. D1 must come back with **no character at all**; Claude checks this at review.

**D1. Background, NO characters → `menu_bg.png`** (16:9, 2048 × 1152 or larger)
> Same scene and style as the attached image, but with NO characters and NO people at all: an
> empty night temple plaza for a Roblox anime game, purple cherry blossom trees, pagodas with
> glowing windows, a big torii gate in the middle with a round wooden sign that says '1v1 ARENA'
> with crossed swords, a glowing purple swirl portal on the right under a sign that says
> 'WORLDS', flaming lanterns, stone floor with reflections, purple starry sky with clouds. Leave
> the left third slightly darker and calmer (UI goes there) and keep the centre-right floor area
> clear (a character will stand there). No UI, no logo, no buttons.

**D2. Logo → `logo.png`** (text baked in)
> Game logo for '1v1 CARD' in exactly the style of the attached image's logo: a gold crown on
> top, '1v1' in a bold pink-to-gold gradient with a dark outline, 'CARD' in bold white with a
> dark outline below it, a black brush-stroke splash behind. Transparent or flat magenta
> background, centred, nothing else.

**D3. Menu buttons → `menu_buttons.png`** (text baked in)
> Two ornate Roblox game buttons in exactly the style of the attached image, on a flat magenta
> background, separated: (1) 'PLAY' button: pink-to-orange gradient body, gold ornate frame,
> crossed golden swords on both sides, 'PLAY' in bold gold gradient letters; (2) 'SHOP' button:
> blue-violet gradient body, light blue ornate frame, a shopping cart icon on the left, 'SHOP' in
> bold white letters. Then the same two buttons again in a brighter 'hover' version, and a
> slightly darker 'pressed' version.

**D4. Currency pills → `menu_pills.png`** (skip if E2 is done: the menu reuses E2)
> Dark rounded currency pill with a gold coin socket on the left and a small gold '+' button on
> the right, and the same with a blue diamond, empty, no numbers, magenta background.

## 4. Sheet B: egg tiles by tier → `eggshop_tiles.png`
Reference: `06-egg-shop-target.png`.
> Same style, NO TEXT, flat magenta background, pieces separated. Eight empty square-ish egg
> tiles (dark inner background with a soft radial glow in the middle and a glowing border):
> silver/white, blue, purple, gold, red, galaxy (blue-pink), divine (white-gold), shadow (dark
> violet). Plus each tile's 'selected' version (brighter border, sparkles in corners). Plus one
> locked overlay (dark glass with a padlock).

## 5. Merchant kit and icon sheet → `merchant_kit.png`, `icons.png`
Reference: `04-merchant-target.png` (your own art; Claude also slices its clean pieces).

**Kit**
> Roblox game UI kit sheet, same style as [attach 04-merchant-target.png]: purple and gold
> fantasy mobile game UI, glossy, sparkles. NO TEXT anywhere. Transparent or plain flat magenta
> background, each element separated with space around it. Elements: 1 large empty panel frame
> with angled header tab and diagonal stripes; 1 empty header bar; 1 gold banner frame with coin
> pile on the left; gold glossy button (empty), blue glossy button (empty), green glossy button
> (empty), red glossy button (empty); round close button with X; currency pill (empty, coin
> socket); price pill (empty); corner ribbon badge (empty) in grey, green, blue, purple, gold;
> item card frames in grey, green, blue, purple, gold, rainbow; dark name plate; tab buttons
> on/off; search bar; empty-state coin bag illustration.

**Icons** (only if the three icon packs in `Downloads` don't cover a slot; see
`art/icons/icon_map.json`)
> Same style, icon sheet, no text: cart, tag, coin, gem, backpack, egg, cards, deck, globe, gear,
> gift, calendar, trophy, crown, star, check, lock, arrow, plus, swords, shield, heart, sparkle.

## 6. Sheets H1-H2: the battle screen
Reference: `18-target-battle-screen.png`.

**H1. Action cards → `battle_actions.png`**
> Three tall glass action cards for a Roblox battle UI in exactly the style of the attached
> image, NO TEXT: (1) red neon frame with a glowing red sword icon, (2) blue neon frame with a
> glowing blue shield icon, (3) purple neon frame with a purple-gold lightning bolt icon. Also a
> dimmed locked version of the purple card with a small lock, a 'selected' glowing version of
> each, and the empty glass tray they sit on. Flat magenta background, separated.

**H2. Top HUD pieces → `battle_top.png`** (the three stamps have their words baked in)
> Same style, NO TEXT: a steel hexagon timer medallion (empty center), a small 'round' plate
> (empty), a long angled HP bar frame for the left side and a mirrored one for the right side
> (empty), HP fills in magenta and gold, a thin sub-bar frame, an energy diamond empty and filled
> (gold), a small dark forfeit button (empty), a 'LOCKED IN' stamp (with text), a 'K.O.!' burst
> (with text), a 'PARRY!' burst (with text). Flat magenta background, separated.

## 7. Sheets G1-G2: the battle result
Reference: `16-target-battle-result.png`.

**G1. Result banners → `result_banners.png`** (text baked in)
> Two Roblox game result banners in exactly the style of the attached image: (1) 'DEFEAT' in
> heavy bevelled steel letters on a cracked steel plate with ice shards bursting out, cold purple
> glow; (2) 'VICTORY' in heavy bevelled gold letters on an ornate gold plate with wings and a
> crown, warm glow and light rays. Flat magenta background, separated.

**G2. Result UI pieces → `result_pieces.png`**
> Same style, NO TEXT, flat magenta background, separated: a big ornate gold button with flame
> accents (empty); a painted player info panel (dark glass, gold-violet frame) with an empty card
> socket on the left; a painted HP bar background and fills in red, yellow and green; a warning
> pill (dark, with a red-yellow warning icon and three exclamation marks, empty text area);
> reward chips (empty) with a gold coin, a trophy and a blue gem; a crack overlay for a
> knocked-out card; blue flame aura and purple flame aura sprites for cards.

## 8. Sheet F1: inventory and deck extras → `inv_extras.png`
Reference: `14-…` / `15-…REFERENCE-ONLY…` (layout only: copyrighted card art).
> Same style as the attached Inventory/Deck Builder image, NO TEXT, NO characters, flat magenta
> background, separated: a vertical tab button in selected (glowing blue) and unselected (dark)
> state; an empty search bar with a magnifier icon; a small dark power plate with a gold sword
> icon on the left (empty number area); a dashed glowing empty card slot with a plus; a green up
> arrow; a family bonus chip (empty); a round star icon plate; a crown icon; 15 round glossy
> family emblem icons: dragon, shadow, demon, divine, warrior, flame, ice, lightning, spirit,
> beast, ninja, royal, cosmic, ancient, mystic.

## 9. Sheet C: crystal eggs (only if you choose Option 2) → `eggs_crystal_1..4.png`
Decide first (`docs/WAITING_ON_YOU.md`): **Option 1** keeps the Egg Icon Pack eggs inside the
new tier tiles (licensed, already uploaded). **Option 2** replaces them with crystal eggs that
match the target. The game ships Option 1 until you say otherwise.
> Glossy crystal/gem fantasy eggs for a Roblox game, same style as the attached image: faceted
> shell, inner glow, strong colored aura, sparkles. NO TEXT. Flat magenta background, 8 eggs per
> sheet, separated, front view, centered, same size: [list 8 egg names with their colours].

Sheets 1-3: Basic, Spotted, Cat, Dog, Coconut, Sandcastle, Ice, Yeti / Mine, Cracked, Dragon,
Demon, Kraken, Angel, AngelDemon, Royal / Legendary, Mythical, Rainbow, Glitched, Black Hole,
Dominus, Secret, Party. Sheet 4: "the same eggs in a gold variant" (no Golden Rainbow). Each egg's
look hints at its name (Ice = icy blue crystal, Dragon = red scales with horns, Kraken = teal
with a tentacle pattern…).

## 10. Lobby concept (optional) → `lobby_concept.png`
> Top-down 3/4 view concept art of a Roblox game hub map: night sakura temple plaza on a mountain
> shelf, central round plaza with a fountain, a grand red torii gate with a round '1v1 ARENA'
> sign to the north, a temple gate with a swirling purple portal and 'WORLDS' sign to the east, an
> egg shop pavilion to the west, a merchant stall and a quest board near the spawn, stone
> lanterns, purple cherry trees, a small river with a wooden bridge, pagodas around the edges, no
> characters, no UI.
