# BAD GUI 3: the Egg Shop, and the real fix for "it looks like CSS"

The owner, 2026-11-09:

> "This too is bad GUI. The eggs don't look like I wanted. I said don't use simple trash CSS.
> What you see in the image is what I want. Look online how to do this UI."

Siblings: `BAD_GUI_THINKING_AND_UI.md` (notifications and world text) and `BAD_GUI_2_PANELS.md`
(panels). All three are permanent rules.

---

## 1. Before and after

| | File |
|---|---|
| **Now (bad)** | `docs/brief/bad-gui/05-egg-shop-current-web-style.png` |
| **Target** | `docs/brief/bad-gui/06-egg-shop-target.png` (small), and the full-resolution `docs/brief/ui-refs/hd-02-egg-shop.png` |

### Everything wrong with "now"
1. **A code-drawn panel:** flat navy box, thin glow line, small header. A web modal.
2. **No egg tiles.** Eggs stand on grey floor discs in an open row; there's no card or frame
   around each egg. The target has a framed tile per egg.
3. **A horizontal scroll row with a visible scrollbar** (web). The target is a tidy **4 × 2
   grid**, with paging instead of a scrollbar.
4. **Names and prices are detached:** names in flat black pills, prices floating underneath, the
   bottom row cut off. In the target, the name is at the top of the tile and the price is a pill
   built into the tile bottom.
5. **The eggs look wrong for the target:** cartoon pack eggs with no glow, no rarity colour and
   no shine. The target eggs are **glossy crystal/gem eggs with a strong glow** in their tier
   colour (section 4).
6. **Tiny text everywhere:** "World 1 · Green Plains", "Eggs", "Egg Bag (0)", "Common egg", the
   yellow "Drops…" line, "Claim free daily egg" (a wide green web bar), "Auto-open: Off".
7. **The open buttons look disabled and dull:** brown x3/x8, flat purple "Odds".
8. **"x1 soon" / "x3 soon" placeholder buttons** (web thinking: never show unfinished buttons).
   Remove them.
9. **The details strip is a flat box.** The target has a **featured panel** with an ornate gold
   frame, the egg huge in a golden flourish with rays, a gold title, a big price and a big gold
   **Buy** button.
10. **Wasted space and no hierarchy:** nothing pulls the eye to the selected egg or the buy
    action.

---

## 2. What we learned online (how Roblox games get this look)

1. **Good-looking Roblox UI is made of images, not styled frames.** Designers draw the panels,
   frames, buttons and badges in an image tool (Photoshop, Photopea, Figma, or an AI image
   generator), export them as transparent PNGs, upload them, and use them as
   `ImageLabel`/`ImageButton` elements, with text added in Studio on top. A DevForum tutorial on
   simulator-style UI builds every frame in Photoshop and then imports it; a long-standing answer
   on "how to make a GUI in Photoshop and put it in Roblox" says the background is uploaded as an
   image and only the text is handled in Studio.
2. **Anything that stretches uses 9-slice** (`ScaleType = Slice`, `SliceCenter`), so corners
   and borders don't distort. Several 9-slice pieces can share one sheet through
   `ImageRectOffset`/`ImageRectSize`. Images must be 1024 px or smaller.
3. **AI workflow, current best practice:**
   1. generate the **whole screen as one concept** (the owner already has these boards)
   2. generate **component sheets in the same style, with no text**, on a transparent or flat
      magenta background
   3. **cut** each component into its own PNG
   4. set **9-slice borders** on everything that stretches
   5. wire them up in code

   Generate components as **separate pieces rather than cropping them out of a mockup**, and use
   the concept as the style reference for every sheet so they match. There's a Roblox-specific
   walkthrough of exactly this: design in ChatGPT, split into parts, export each asset with a
   local tool.
4. **"Juice":** pop-in tweens, hover and press motion, sounds, glow pulses (as in our motion
   rules).

**The honest bottleneck:** Claude can't paint images. Everything it draws from code (Pillow,
Frames, UICorner, UIStroke) comes out as "CSS". **The painted look has to come from image files
the owner generates** (the same way the reference boards were made). Claude cuts them, slices
them, uploads them and builds the screens from them. Until those images exist, any screen Claude
makes alone will still look code-drawn, so don't spend more time polishing code-drawn panels.

Sources:
- devforum.roblox.com/t/how-to-make-ui-styled-for-simulator-detailed-tutorial/2895762
- devforum.roblox.com/t/how-can-i-make-a-gui-in-photoshop-or-any-software-and-implant-it-in-roblox/424605
- create.roblox.com/docs/ui/9-slice
- devforum.roblox.com/t/how-to-use-slicecenter-robloxs-9-slice-gui-property/18313
- spritecook.ai/blog/generate-game-ui-with-ai
- sozai.app/transcript/create-stunning-roblox-guis-ai-full-workflow

---

## 3. The pipeline (Claude builds it once; it's used for every screen)

```
art/ui/sheets/<name>.png        owner-generated component sheets (no text), never edited
art/ui/kit-v3/<piece>.png       cut, trimmed, transparent components (derived)
art/ui/kit-v3/kit.json          piece -> file, size, 9-slice margins, asset id, tint, status
```

1. **`scripts/art/cut_sheet.py <sheet>`:**
   - turn a flat magenta (#FF00FF) or near-white background into transparency (with
     de-fringing)
   - find each component as a connected region with padding; merge small fragments into their
     nearest component
   - trim each one and save it as `kit-v3/<sheet>_<n>.png`
   - make a labelled contact sheet `docs/review/<sheet>_cut.png` (numbers on every piece)
2. **`kit.json` naming:** Claude names each numbered piece (e.g. `egg_tile_gold`,
   `featured_frame`, `buy_button_gold`) and sets 9-slice margins by measuring the corner and
   border thickness. It checks each by rendering a stretched test at 3 sizes into
   `docs/review/<sheet>_slice_test.png`.
3. **Size rules:** at most 1024 px. Pieces shown at different sizes get two exports (full and
   half) to stay crisp.
4. **Review gate** (`CLAUDE.md`, Asset safety): the contact sheet goes to the owner. UI art with
   no characters is low risk, but it still needs a quick "OK" before upload. Upload in batches of
   5 or fewer, and stop on any rejection.
5. **`App/Ui/Kit`:** one place that maps piece names to asset ids, so screens never hard-code
   images, and swapping art later is just data.

---

## 4. What the owner generates (exact prompts)

Use the same image tool as the boards, and attach `06-egg-shop-target.png` /
`hd-02-egg-shop.png` as the style reference. Generate at the largest size available. **No text
on any piece.** Use a flat magenta background unless the tool can do real transparency. Leave
space between pieces.

**Sheet A: Egg Shop frame kit** → `art/ui/sheets/eggshop_frame.png`
> "Roblox mobile game UI component sheet in exactly the style of the attached Egg Shop image:
> dark purple glass panels with glowing violet borders, gold accents, glossy. NO TEXT anywhere.
> Flat magenta background, every piece separated with empty space. Pieces: 1 large empty main
> panel frame; 1 header bar with a round empty icon socket on the left; 1 round close button with
> white X; 1 tall ornate GOLD featured-item frame (empty, with golden flourish wings at the bottom
> for an item to sit on); 1 large glossy GOLD empty button; 1 glossy PURPLE empty button; 1
> glossy GREY disabled empty button; 1 dark empty price pill with a gold coin on the left; 1 tab
> button 'on' and 1 tab button 'off' (empty); 1 small empty page arrow (left) and (right)."

**Sheet B: egg tiles by tier** → `art/ui/sheets/eggshop_tiles.png`
> "Same style, NO TEXT, flat magenta background, pieces separated. Eight empty square-ish egg
> tiles (dark inner background with a soft radial glow in the middle and a glowing border):
> silver/white, blue, purple, gold, red, galaxy (blue-pink), divine (white-gold), shadow (dark
> violet). Plus each tile's 'selected' version (brighter border, sparkles in corners). Plus one
> locked overlay (dark glass with a padlock)."

**Sheet C: the eggs** (only if the owner wants the target's crystal eggs instead of the pack
eggs; see 4.1) → `art/ui/sheets/eggs_crystal_<n>.png`
> "Glossy crystal/gem fantasy eggs for a Roblox game, same style as the attached image: faceted
> shell, inner glow, strong colored aura, sparkles. NO TEXT. Flat magenta background, 8 eggs per
> sheet, separated, front view, centered, same size: [list 8 egg names with their colours]."

Three sheets of 8 cover all 24 eggs; Golden versions are a 4th prompt, "same eggs in gold
variant". Each egg's look should hint at its name: Ice = icy blue crystal, Dragon = red scales
with horns, Kraken = teal with tentacle pattern, and so on.

### 4.1 Egg art decision (in `WAITING_ON_YOU.md`)
- **Option 1:** keep the Egg Icon Pack, inside the new glowing tier tiles. Fastest, and already
  licensed.
- **Option 2:** new crystal eggs (Sheet C) that match the target exactly.

The owner's message ("the eggs don't look like I wanted") points to **Option 2**. **Default:**
build with the pack eggs inside the new tiles now, and switch to Sheet C eggs the moment they
arrive and are approved. It's only a `Config/Eggs` icon swap.

---

## 5. Rebuild the Egg Shop exactly like the target

1. **Panel:** Sheet A main frame (9-slice). Header: an egg icon in the round socket, "Egg Shop"
   in big outlined display font, the close button.
2. **Left: 4 × 2 grid of egg tiles** (Sheet B, in each egg's tier colour). Each tile has:
   - the egg name at the top in bold outlined text
   - the egg centred, with an idle bob and a glow pulse
   - a price pill (Sheet A) built into the bottom edge: coin + big number
   - a locked overlay with "World N" when the egg isn't unlocked
   - Sheet B's selected version when the egg is chosen

   **Page arrows or world tabs** switch between pages of 8: no scrollbars, no "World 1 ·
   Green Plains" tiny labels. Each world page has a big tab with the world number and name.
3. **Right: featured panel** (Sheet A's gold frame):
   - the egg's name as a big gold-gradient title
   - the egg large on the golden flourish, with rays and sparkles behind it
   - one short line: "Drops Common up to <top rarity>", with an **Odds** pill button next to it
   - a big price (coin + number)
   - a **big gold Buy button**, with **x1 / x3 / x8** as three chunky gold buttons when the player
     can afford them (grey Sheet A buttons when not)
4. **Remove:**
   - "x1 soon" / "x3 soon"
   - the wide green "Claim free daily egg" bar. The free daily egg moves to a gift-icon button
     with a red notification dot, shown on the Basic egg tile ("FREE" ribbon) when available.
   - "Auto-open: Off" text. It becomes a small toggle icon with a tooltip.
   - every line of text under 20 px
5. **Egg Bag:** the second tab, with the same tile grid showing owned eggs and counts ("x3" big
   italic), Golden markers, and an Open button.
6. **Robux button:** only when policy allows it (existing rule); a Sheet A button with the Robux
   icon.
7. **Motion and sound:**
   - the panel pops open
   - tiles stagger in
   - the selected tile lifts and glows
   - the featured egg swaps with a burst
   - Buy squashes and plays the purchase sound, then the opening sequence starts
8. **Comparison:** `docs/screens/roblox-ui/compare_eggshop.png` (target vs ours), scored 8+ on
   painted look, grid and tiles, featured panel, text size, and buttons.

---

## 6. Order of work
1. **Now (no owner art needed):**
   - write `cut_sheet.py`, `kit.json` and `App/Ui/Kit`
   - restructure the Egg Shop layout (4 × 2 grid with paging, featured panel, removed
     placeholders, free-egg gift button)
   - use the current kit images, marked TEMP
   - write the section 4 prompts into `art/ui/PROMPTS_V3.md` and `docs/WAITING_ON_YOU.md`
     (top item)
2. **When Sheets A and B arrive:**
   1. cut them
   2. make the review sheet and **wait for the owner's OK**
   3. upload in batches of 5 or fewer
   4. swap the Egg Shop to the real pieces
   5. compare, score 8+, commit
3. **When Sheet C arrives** (if Option 2): cut, review, OK, upload, swap the icons in
   `Config/Eggs`, then re-check the Egg Shop, the opening sequence and the Egg Bag.
4. **Then:** use the same sheets and pipeline for the merchant (`BAD_GUI_2_PANELS.md`) and every
   other panel.

## 7. Checklist
- [ ] `scripts/art/cut_sheet.py`, `kit.json` format, `App/Ui/Kit`, slice-test renders
- [ ] Egg Shop restructured (grid, paging, featured panel, Buy x1/x3/x8, Odds pill, free-egg gift
  button, Egg Bag tab); placeholders and tiny texts removed
- [ ] `PROMPTS_V3.md` + `WAITING_ON_YOU.md` top item: Sheets A, B (and C) with the exact prompts
  above, plus the egg-art decision
- [ ] Sheets cut, reviewed, approved, uploaded (batches of 5 or fewer)
- [ ] Egg Shop on real kit art, comparison scoring 8+
- [ ] Rule added to `CLAUDE.md` "UI rules": *"Never polish code-drawn panels. Painted look =
  owner-generated component sheets, cut by `cut_sheet.py`, 9-sliced, served through `App/Ui/Kit`."*
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
