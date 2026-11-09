# BAD GUI 4: the main menu must look exactly like the target

The owner, 2026-11-09:

> "The main menu doesn't look like the GUI I wanted. This is the background, and this is the UI I
> want shown. It should be fixed. It really needs to be this good."

Siblings: `BAD_GUI_THINKING_AND_UI.md`, `BAD_GUI_2_PANELS.md`, `BAD_GUI_3_EGG_SHOP.md`. Same
rules, same pipeline (owner-generated images → `cut_sheet.py` → review → `App/Ui/Kit`).

---

## 1. The three images

| File | What it is |
|---|---|
| `docs/brief/bad-gui/07-main-menu-current.png` | **Now:** code-drawn |
| `docs/brief/bad-gui/08-main-menu-bg-REFERENCE-ONLY-has-copyrighted-character.png` | **Background reference** from the owner |
| `docs/brief/bad-gui/09-main-menu-target.png` | **Target:** the background plus the menu UI |

### ⚠️ The background can't be uploaded as it is (`CLAUDE.md`, Asset safety, rule 3)
The character in images 08 and 09 has white spiky hair, a black blindfold and a black high-collar
uniform. That's **Gojo Satoru (Jujutsu Kaisen)** drawn in Roblox style, and the cards in his hand
show anime characters too. **Never upload 08 or 09, and never use them in the game.** They are
**layout and mood references only**:
- the scene: night temple plaza, cherry trees, torii, the 1v1 ARENA sign, the WORLDS portal
- the composition
- the UI placement and style

The real background is regenerated **without any character** (section 3). The character spot is
filled by **the player's own Roblox avatar** (section 4), which is also what top Roblox games do
and looks better.

### What's wrong with "now" (07)
1. **No background art:** a flat purple gradient with floating card outlines. The target is a
   full painted scene (the lobby at night).
2. **The logo is code text.** "1V1 CARD" in yellow and white text with a stroke. The target logo
   is a **painted emblem**: "1v1" in a pink-gold gradient with a crown on top, "CARD" in white
   below, over a black brush-splash.
3. **Too many buttons and too much text:** the PLAY bar, four tiles (CARDS, EGGS, DECK,
   SETTINGS), a tagline, a version line. The target has **only two buttons: PLAY and SHOP**.
4. **The PLAY button is a plain yellow pill.** The target PLAY is an **ornate painted button**:
   pink-to-orange gradient, gold frame, crossed-sword icons on both sides, gold-gradient "PLAY"
   text.
5. **No SHOP button.** The target has an ornate blue-purple SHOP button with a cart icon.
6. **No currency display.** The target has coins and gems with "+" at the top right.
7. **Card showcase instead of a hero:** three big cards fill the right side. The target puts a
   **character** there, centre-right, posing with cards in hand, and keeps the scene readable.
8. **No life:** the target scene has glowing lanterns, a portal, petals and fire. Ours is static.

---

## 2. Target layout (09, at 1920 × 1080; scale for other sizes)

| Element | Position | Look |
|---|---|---|
| Background | Full screen | Painted night temple plaza, purple cherry trees, pagodas, torii with the "1v1 ARENA" sign, the glowing "WORLDS" portal on the right, purple sky, lanterns |
| Logo | Top-left, about 22% of the width | Painted emblem: crown, "1v1" pink-gold gradient, "CARD" white, black brush splash |
| PLAY button | Left, under the logo, about 24% of the width | Ornate: pink-orange gradient, gold frame, crossed swords both sides, gold "PLAY" text |
| SHOP button | Under PLAY, the same width | Ornate: blue-violet gradient, light-blue frame, cart icon, white "SHOP" text |
| Coins and gems | Top-right | Dark pills with gold coin / blue diamond icons, big white numbers (live values, short format), "+" buttons |
| Hero character | Centre-right, standing on the plaza | **The player's own avatar** (section 4), fanning 3 cards in one hand, with a light swoosh effect |
| Roblox top bar | Untouched | Keep the left side clear for the Roblox menu buttons |

**Nothing else:** no tagline, no version text, no extra tiles. Settings and everything else are
reached inside the game. A tiny version string can live in Settings → Credits.

**Buttons:**
- **PLAY:** the menu → playing flow (the camera fly-in from `MISSION.md` §2.3).
- **SHOP:** opens the Egg Shop (`BAD_GUI_3_EGG_SHOP.md`) over the menu. Closing it returns to the
  menu.

---

## 3. What the owner generates (exact prompts)

Attach `09-main-menu-target.png` as the style reference. Generate at the largest size
available.

**D1. Background, NO characters** → `art/ui/sheets/menu_bg.png`, landscape 16:9 (2048 × 1152 or
larger if possible)
> "Same scene and style as the attached image, but with NO characters and NO people at all: an
> empty night temple plaza for a Roblox anime game, purple cherry blossom trees, pagodas with
> glowing windows, a big torii gate in the middle with a round wooden sign that says '1v1 ARENA'
> with crossed swords, a glowing purple swirl portal on the right under a sign that says
> 'WORLDS', flaming lanterns, stone floor with reflections, purple starry sky with clouds. Leave
> the left third slightly darker and calmer (UI goes there) and keep the centre-right floor area
> clear (a character will stand there). No UI, no logo, no buttons."

**D2. Logo** → `art/ui/sheets/logo.png`
> "Game logo for '1v1 CARD' in exactly the style of the attached image's logo: a gold crown on
> top, '1v1' in a bold pink-to-gold gradient with a dark outline, 'CARD' in bold white with a dark
> outline below it, a black brush-stroke splash behind. Transparent or flat magenta background,
> centred, nothing else."

**D3. Menu buttons** → `art/ui/sheets/menu_buttons.png`
> "Two ornate Roblox game buttons in exactly the style of the attached image, on a flat magenta
> background, separated: (1) 'PLAY' button: pink-to-orange gradient body, gold ornate frame,
> crossed golden swords on both sides, 'PLAY' in bold gold gradient letters; (2) 'SHOP' button:
> blue-violet gradient body, light blue ornate frame, a shopping cart icon on the left, 'SHOP' in
> bold white letters. Then the same two buttons again in a brighter 'hover' version, and a
> slightly darker 'pressed' version."

(Text is baked into the logo and these two buttons on purpose: they never change and must look
exactly painted.)

**D4. Currency pills:** reuse Sheet A's pill, or ask in the same style:
> "dark rounded currency pill with a gold coin socket on the left and a small gold '+' button on
> the right, and the same with a blue diamond, empty, no numbers, magenta background."

### Review gate (`CLAUDE.md`, Asset safety)
- Contact sheet `docs/review/menu.png`. Claude checks especially that **D1 has no character, no
  anime likeness and no text except the two signs**.
- The owner's "OK" before upload. Upload in batches of 5 or fewer; stop on any rejection.

---

## 4. The hero character: the player's own avatar

- In the main menu, a `ViewportFrame` (with a `WorldModel` for animation) shows a **clone of the
  player's real avatar** (`Players:CreateHumanoidModelFromUserId` or a clone of the character),
  lit to match the scene: a purple key light and a warm rim light from the portal side.
- **Pose and animation:** a confident idle with one hand fanning **3 cards**. The cards are small
  parts or `SurfaceGui`s showing **our own card art**: the player's actual deck cards, with frames
  and the template for characters without art. A subtle swoosh trail under it.
- Generate the idle with `generate_animation` ("confident idle, holding a fan of cards in the
  right hand, slight bob"), or hand-keyframe it. Upload the animation as normal.
- **Fallback** while the avatar loads: a neutral silhouette, then a fade-in.
- **Placement:** centre-right on the plaza, feet on the painted floor line (match the target's
  scale: the head at about 22% from the top, the feet at about 82%).
- **Never** dress the avatar in or add accessories from existing anime characters.

---

## 5. Building it (code)

1. **Background at full quality:** Roblox shrinks any image over 1024 px. Split the 2048 × 1152
   background into **four 1024 × 576 tiles** (`menu_bg_00..11`), placed as 4 `ImageLabel`s in a
   2 × 2 grid inside one container (no seams). The container uses
   `UIAspectRatioConstraint` 16:9 and **covers** the screen: on narrower or wider screens it
   crops the edges, never stretches.
2. **Life (cheap):**
   - a very slow parallax drift of the background (±1%)
   - falling petal sprites (about 12 UI particles, recycled)
   - a glow pulse over the WORLDS portal (an additive glow image, 3 s loop)
   - lantern flicker (2-3 small glow images)
   - the logo bobs gently, PLAY and SHOP get a shine sweep every 5 s
   - everything respects `reducedMotion`
3. **Buttons:** `ImageButton`s with normal, hover and pressed images from D3, a squash on press,
   the hover sound and the confirm sound.
4. **Currency pills:** D4 images + live values with count-up + "+" (it opens the earn-coins tip,
   because Coins are never sold).
5. **Layout:**
   - everything scales from a 1920 × 1080 design with `UIScale` and anchors
   - test at 1920×1080, 1366×768, 1334×750 (phone landscape) and 750×1334 (phone portrait:
     logo top-centre, buttons bottom-centre, character centre)
   - keep the Roblox top-bar area clear
6. **Remove** the old menu tiles, tagline, version line and card showcase from the menu.
   (Inventory, Deck and Settings stay reachable in game.)
7. **Flow stays the same:** launch loading → this menu → PLAY → playing; Menu → leaving screen →
   this menu (`MISSION.md` §2).

---

## 6. Order of work
1. **Now:**
   - restructure the menu to the target layout (logo spot, PLAY, SHOP, currency pills, hero
     viewport with the player's avatar, the 2 × 2 background container, the motion)
   - use temporary images, marked TEMP
   - write the D1-D4 prompts into `art/ui/PROMPTS_V3.md` and as the top item of
     `docs/WAITING_ON_YOU.md`, with the warning that 08/09 contain a copyrighted character and
     must not be uploaded
2. **When D1-D4 arrive:**
   1. cut D2-D4 with `cut_sheet.py`
   2. split D1 into 4 tiles
   3. make the review sheet and **wait for the owner's OK**
   4. upload in batches of 5 or fewer
   5. swap them in
3. **Comparison:** `docs/screens/roblox-ui/compare_mainmenu.png`, the target (09) next to ours,
   scored 8+ on:
   - background
   - logo
   - buttons
   - currency
   - hero character
   - minimal text
   - motion

   The character differs on purpose (the player's avatar instead of the copyrighted one); judge
   the pose, place and scale.

## 7. Checklist
- [ ] Menu restructured: only logo, PLAY, SHOP, currency pills, hero avatar; old tiles, tagline,
  version line and card showcase removed
- [ ] Hero: the player's avatar in a ViewportFrame, holding their 3 deck cards, idle animation,
  lighting matched
- [ ] Background container: 2 × 2 tiles, cover-fit, parallax, petals, portal glow, lantern flicker
- [ ] D1-D4 prompts in `PROMPTS_V3.md` and `WAITING_ON_YOU.md`, with the copyright warning about
  08/09
- [ ] Owner images cut, reviewed, approved, uploaded (batches of 5 or fewer), swapped in
- [ ] Phone, tablet and PC layouts checked in Play
- [ ] Comparison scoring 8+
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
