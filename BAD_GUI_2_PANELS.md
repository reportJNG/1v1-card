# BAD GUI 2: panels drawn like CSS → replace them with painted Roblox UI art

The owner, 2026-11-09, about the merchant panel (and every shop-like screen):

> "This is so bad, it's like web. We're using CSS logic thinking of drawing styles. Image UI is
> easy and so much better than styling and showing stuff like this. It should be like this new
> image."

This is a **sibling of `BAD_GUI_THINKING_AND_UI.md`**. That file covers notifications and world
text; this one covers **panels and screens**. Both are permanent rules.

---

## 1. Before and after

| | File |
|---|---|
| **Now (bad)** | `docs/brief/bad-gui/03-merchant-current-web-style.png` |
| **Target** | `docs/brief/bad-gui/04-merchant-target.png` (1473 × 1068) |

### What makes "now" look like a website
- **Built from code shapes:** flat rounded rectangles (`UICorner`), thin strokes (`UIStroke`),
  plain fills. That's CSS thinking: a box, a border-radius, a border.
- **A huge empty purple area.** Two small cards float in a big flat field.
- **A plain header bar:** small title, no icon, no shape.
- **A weak banner:** flat brown box, small title, tiny grey subtitle.
- **"Sell all" is nearly invisible:** dark text on a dark background with no button shape. A
  real bug.
- **Wrong icon:** "Oak Log" shows a crystal. Another bug: every item must use its own icon.
- **Small, flat text**, with no italic display font, gradient or depth.
- **Small flat green buttons** with no icon, no gloss and no rarity colour.

### What makes the target look like a Roblox game
- **Painted image art, not code shapes:**
  - an ornate panel frame with an angled header tab and diagonal stripe details
  - a gold-framed banner with a painted coin pile and sparkles
  - illustrated item cards whose painted backgrounds are tinted by tier (gold, blue)
- **Big italic heavy display text** with a stroke and a gold gradient on the key word ("SELL"
  gold, "YOUR HARVEST" white). The subtitle is italic and readable.
- **The header:**
  - a cart icon
  - "Farmer Tobb" in big bold type
  - the currency pill (coin, 55, +) inside the header
  - a glowing round close button breaking out of the frame corner
- **Item cards:**
  - a corner ribbon badge ("RARE" with a crown shield)
  - a big item icon with sparkles
  - a huge italic count ("x1", "x5") with a stroke
  - a dark name plate
  - a price pill ("25 each")
  - a big glossy button in the card's colour, with a tag icon ("Sell 25")
- **"Sell all":** a big gold glossy button with a tag icon, in the banner.
- **Empty space is designed:** a faded illustrated coin bag with "Select an item to sell" instead
  of blank purple.
- **Frame details:** a bottom crown ornament, an inner glow, and a background showing the world
  through it.

---

## 2. The rule: UI is images, not styled boxes

1. **Panels, banners, cards, buttons, badges, pills and tabs are image assets** (9-slice
   `ImageLabel` / `ImageButton`, `ScaleType = Slice` with correct `SliceCenter`). They are **not**
   built from `Frame` + `UICorner` + `UIStroke` + flat `BackgroundColor3`.
   - Allowed in code: layout (`UIListLayout`, `UIGridLayout`, `UIPadding`,
     `UIAspectRatioConstraint`), text, `UIStroke` on text, `UIGradient` on text or as a tint
     over an image, and animation.
   - Not allowed: a visible "box" made only from code properties. If a player can see a
     rectangle, it should be a painted image.
2. **Text uses display fonts:**
   - titles and big numbers: heavy italic display font (`Enum.Font.Bangers` or
     `LuckiestGuy`), with a gradient on key words
   - labels: heavy rounded font (`FredokaOne` / Builder Sans Black)
   - always a thick stroke
3. **Every element has an icon or illustration:** headers (cart, egg, backpack…), buttons (tag,
   check, arrow…), badges (crown, star), empty states (an illustration with one short line).
4. **Tier colours are painted:** card backgrounds and buttons follow the item's tier (Common
   grey, Uncommon green, Rare gold or blue as in the target, Epic purple…). Use one painted base
   and tinted variants, or separate painted images per tier.
5. **No empty flat space.** Fill it with an illustration, a decorative pattern or a layout that
   uses the room. Grids must not leave a big bare field.
6. **Buttons look pressable:** glossy, with a darker bottom lip, an icon and bold text, plus
   press and hover motion.
7. **Glow, sparkles and stripes** are part of the painted art or of small FX images, never left
   out.

---

## 3. Where the images come from (a UI kit sheet)

The target image is the owner's own generated art, so it can be used as **source material**:
1. **Slice what's clean:**
   - panel frame corners and edges
   - stripe details
   - the coin pile, sparkles, the coin-bag illustration
   - the crown ornament
   - the card frames and backgrounds
   - the round close button

   Cut them from `04-merchant-target.png` into `art/ui/kit-v3/` with transparent backgrounds and
   9-slice margins. Clean the edges.
2. **Ask the owner for text-free versions** of the pieces that have baked-in text (buttons,
   banner, badges, pills). Give them these prompts, in the same style as the target. Put them in
   `art/ui/PROMPTS_V3.md` and in `docs/WAITING_ON_YOU.md`.

   > *"Roblox game UI kit sheet, same style as [attach 04-merchant-target.png]: purple and gold
   > fantasy mobile game UI, glossy, sparkles. **No text anywhere.** Transparent or plain flat
   > magenta background, each element separated with space around it. Elements: 1 large empty
   > panel frame with angled header tab and diagonal stripes; 1 empty header bar; 1 gold banner
   > frame with coin pile on the left; gold glossy button (empty), blue glossy button (empty),
   > green glossy button (empty), red glossy button (empty); round close button with X; currency
   > pill (empty, coin socket); price pill (empty); corner ribbon badge (empty) in grey, green,
   > blue, purple, gold; item card frames in grey, green, blue, purple, gold, rainbow; dark name
   > plate; tab buttons on/off; search bar; empty-state coin bag illustration."*

   > *"Same style, icon sheet, no text: cart, tag, coin, gem, backpack, egg, cards, deck, globe,
   > gear, gift, calendar, trophy, crown, star, check, lock, arrow, plus, swords, shield, heart,
   > sparkle."*

3. **Until those arrive:** rebuild the merchant panel from the sliced pieces plus Blender/Pillow
   renders that copy the target's look (route B/C from `MISSION.md` §4.3), marked `TEMP`.
4. **Review gate** (`CLAUDE.md`, Asset safety): UI images with no characters are low risk, but
   they still go on a contact sheet (`docs/review/ui-kit-v3.png`) and wait for the owner's OK
   before upload. Upload in batches of 5 or fewer.

---

## 4. Rebuild the merchant panel exactly like the target (the template for every panel)

1. **Frame:** the painted panel frame (9-slice), the angled header tab, stripes, the bottom
   crown ornament, an inner glow. The world is visible through slight transparency outside the
   frame.
2. **Header:**
   - cart icon
   - "Farmer Tobb" (the merchant's name, big bold)
   - the currency pill (coin + live amount + "+" that opens the earn-coins tip)
   - the glowing round close button overlapping the top-right corner
3. **Banner:**
   - gold frame, coin pile and sparkles on the left
   - "SELL YOUR HARVEST" in italic heavy type: "SELL" gold gradient, the rest white with a
     stroke
   - the subtitle in italic
   - a **gold "Sell all" button with a tag icon** on the right, with the total in coins (for
     example "Sell all · 55"). It's disabled (greyed image) when there's nothing to sell.
4. **Item cards:** a painted tall card per item stack, in its tier colour, with:
   - the corner ribbon badge (tier name and its emblem)
   - the item's **own** icon (fix the Oak Log icon bug; check every item in `Config/Items` has a
     distinct, correct icon)
   - sparkles
   - a big italic "xN"
   - the name plate
   - "N each" in a price pill
   - a glossy sell button in the card's colour with a tag icon and "Sell N"
5. **Empty state:** with no items, show the faded coin-bag illustration and "Select an item to
   sell". It also fills the free slots beside a short list, as in the target.
6. **Motion and sound:**
   - the panel pops open
   - cards stagger in
   - buttons squash on press
   - when selling, coins burst from the card to the currency pill (see `BAD_GUI_THINKING_AND_UI.md`)
   - the card shrinks away when the stack is gone, with a "+N" coin pop and the sell sound
7. **Side-by-side** `docs/screens/roblox-ui/compare_merchant.png` (target vs ours), scored 8+ on:
   painted look, text style, icons, use of space, button quality.

---

## 5. Apply the same rebuild to every panel
Same frame, header, banner style, cards, buttons, badges, pills, empty states and fonts:
- **Egg Shop:** egg cards on painted tier cards, a big "OPEN" gold button, the Odds button as a
  pill with an icon
- **Inventory:** item and card tiles on painted tier cards, tabs as painted buttons, the search
  bar image
- **Deck Builder / Families:** painted slots, a painted deck-power banner
- **Arena, Quests, Daily Rewards, Worlds, Settings, Victory/Defeat, the KO picker**

For each one:
- list in `docs/GUI_AUDIT_ROBLOX.md` the code-drawn boxes to replace
- rebuild it from kit images
- take a Play-mode before/after screenshot and a comparison, scored 8+

---

## 6. Checklist
- [ ] Bugs: "Sell all" readable and a real button; every item shows its own correct icon
- [ ] `art/ui/kit-v3/`: pieces sliced from the target, cleaned, 9-slice margins set
- [ ] `art/ui/PROMPTS_V3.md` + `WAITING_ON_YOU.md` entry for the owner's text-free kit and icon
  sheets
- [ ] Review sheet `docs/review/ui-kit-v3.png` and owner OK before upload (batches of 5 or fewer)
- [ ] Merchant panel rebuilt exactly like the target, with a comparison scoring 8+
- [ ] A shared `App/Ui/Kit` API (`Kit.panel`, `Kit.banner`, `Kit.card(tier)`, `Kit.button(color, icon)`,
  `Kit.badge(tier)`, `Kit.pill`, `Kit.emptyState`), so every screen uses the same images
- [ ] Code-drawn boxes removed from every panel (section 5), each with before/after and 8+
- [ ] Rule added to `CLAUDE.md` under "UI rules": *"Visible boxes are painted images (9-slice),
  never Frame + UICorner + UIStroke. Display fonts with strokes. Every element has an icon. No
  empty flat space."*
- [ ] Tests pass, Rojo builds clean, committed. `PLAN.md` §2/§6 updated.
