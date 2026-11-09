# BAD GUI 6: Deck Builder, Families and Inventory must look like the targets

The owner, 2026-11-09:

> "Always remember how the UI should look. That way you'll get back to doing better UI, not some
> CSS cringe design. Add it to the bad UI screens that should be fixed."

Siblings: `BAD_GUI_THINKING_AND_UI.md` … `BAD_GUI_5_INGAME_HUD.md`. **Every target is listed in
`UI_TARGETS.md`, which `CLAUDE.md` loads every session.**

---

## 1. Targets

| File | Screen |
|---|---|
| `docs/brief/bad-gui/14-target-deck-builder-REFERENCE-ONLY-copyrighted-art.png` | Deck Builder + Families (small) |
| `docs/brief/bad-gui/15-target-inventory-REFERENCE-ONLY-copyrighted-art.png` | Inventory + card inspect (small) |
| `docs/brief/ui-refs/hd-04-deck-builder-families.png` | The same Deck Builder + Families at full resolution |
| `docs/brief/ui-refs/hd-03-inventory-card.png` | The same Inventory + inspect at full resolution |

⚠️ **The characters on these cards are copyrighted:** Gojo, Itachi, Naruto, Luffy and others.
The images are **layout and style references only**: never upload them, never crop art from
them. Our cards show approved original art or the clean template emblem.

---

## 2. What the targets do (and what our code-drawn screens miss)

**Deck Builder (left part of 14)**
- A painted dark-glass panel with a violet glow border. The header has a **round icon plate**
  (cards icon), a big "Deck Builder" title and a round close button.
- **Three big cards side by side**, each with:
  - a rarity badge top-left (SSR / UR, italic, coloured)
  - a family gem top-right
  - **art filling the whole card**
  - a **power plate** at the bottom: a gold sword icon and a **big number** (950)
- **"Deck Power: 2,770"** in big text, the number in **green with a green up-arrow**.
- **"Family Bonus:"** with a family icon chip ("Shadow") and a green "+2%".
- A big glossy **gold "Save Deck"** button.

**Families panel (right part of 14)**
- Its own painted panel: a **star icon** header, "Families", a close button.
- A **two-column list** of all 15 families: a **coloured round icon** plus the name. Active
  families glow; inactive ones are dimmed.
- Footer: a **crown icon** and "Collect more cards to activate bonuses!"

**Inventory (15)**
- **Header:**
  - a **backpack icon plate**
  - a big "Inventory" title
  - a **search bar** with a magnifier
  - the **storage count "12 / 50"**
  - a gold **"+"** button
- **Left vertical tabs:** **All** (selected, glowing blue), Cards, Items, Eggs, Others, each with
  its icon.
- **Grid:** small cards with **rarity-coloured frames and art filling the frame**, a rarity badge
  top-left and a family gem top-right; eggs and items on **tier-coloured glowing tiles**.
- **Inspect panel on the right:**
  - **the large card**: rarity badge, family gem, art, a name banner, a power plate with a sword
    icon and a big number
  - beside it, the **name**, a rarity chip ("SSR") and "· Shadow Family", a one-line description
  - **Power / Health / Skill** rows
  - **Family Bonus** lines in green
  - a purple **"Equipped"** button

**Common to all:** painted panels, icon plates, big bold outlined numbers, coloured chips,
glowing selection states, art-first cards. **Nothing looks like a website form.**

---

## 3. Rebuild (same pipeline: kit images, no code-drawn boxes)
1. **The panels:** Sheet A's panel frame, header bar, icon sockets and close button (from
   `BAD_GUI_3_EGG_SHOP.md` §4).
2. **Cards:** our card system (`MISSION.md` §6). The small grid card and the medium deck card
   **must show art filling the card** (approved art, or the template emblem centred large), the
   badge, the gem, and the **power plate with a big number**. **No names** on small cards; names
   only on the large inspect card's banner.
3. **The Deck Builder:**
   - 3 medium cards with drag-and-drop or tap-to-swap from the inventory
   - empty slot = a dashed glowing frame with a "+"
   - **Deck Power** with a count-up and a green arrow when it improves (red when it drops)
   - the **Family Bonus** chip with its icon and "+N%"
   - a gold **Save Deck** button, disabled-grey when nothing changed
4. **Families panel:**
   - a two-column list with 15 painted family icons (`gem_family_<family>` from `MISSION.md` §11)
   - active families glow and show their bonus; inactive ones are dimmed
   - the crown footer
5. **Inventory:**
   - the header (icon plate, title, search image field, "N / max" storage with a gold "+" that
     opens storage expansion)
   - vertical icon tabs (All, Cards, Items, Eggs, Others)
   - a grid of small cards and tiles, with no scrollbar visible: paging, or a thin painted
     scroll handle
   - the inspect panel as described
   - its buttons follow `MISSION.md` §6.4: Upgrade, Evolve, Equip/Equipped, Favorite, Preview,
     as painted purple buttons with icons; the main state ("Equipped") is shown as in the target
6. **Text:**
   - titles 36 px or larger, outlined
   - numbers big and bold, with a stroke
   - descriptions one line, 20 px or larger
   - nothing tiny
7. **Motion:**
   - the grid staggers in
   - the selected card lifts and glows
   - the inspect card flips in on selection
   - Deck Power counts up
   - Save squashes and plays the confirm sound, with a toast-free success pop ("SAVED!" over the
     button)

## 4. Owner images (add to `WAITING_ON_YOU.md` if not already covered)
Sheet A (panels, buttons, pills, tabs), Sheet B (tier tiles) and E4 (card frames) cover most of
this. One extra sheet:

**F1. Inventory/deck extras** → `art/ui/sheets/inv_extras.png`
> "Same style as the attached Inventory/Deck Builder image, NO TEXT, NO characters, flat magenta
> background, separated: a vertical tab button in selected (glowing blue) and unselected (dark)
> state; an empty search bar with a magnifier icon; a small dark power plate with a gold sword
> icon on the left (empty number area); a dashed glowing empty card slot with a plus; a green up
> arrow; a family bonus chip (empty); a round star icon plate; a crown icon; 15 round glossy
> family emblem icons: dragon, shadow, demon, divine, warrior, flame, ice, lightning, spirit,
> beast, ninja, royal, cosmic, ancient, mystic."

**Review gate:** a contact sheet, the owner's OK, then upload in batches of 5 or fewer; stop on
any rejection.

## 5. Checklist
- [ ] Deck Builder like 14 / `hd-04` (cards with art and power plate, Deck Power with arrow,
  Family Bonus chip, Save Deck)
- [ ] Families panel like 14 (two columns, painted icons, active glow, crown footer)
- [ ] Inventory like 15 / `hd-03` (header with search and storage, vertical tabs, art-first grid,
  inspect panel)
- [ ] F1 prompt in `PROMPTS_V3.md` + `WAITING_ON_YOU.md`; sheet cut, reviewed, approved,
  uploaded, swapped
- [ ] Comparisons `docs/screens/roblox-ui/compare_deck.png`, `compare_families.png` and
  `compare_inventory.png`, scored 8+
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
