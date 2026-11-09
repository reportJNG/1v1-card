# BAD GUI 5: the in-game screen (HUD): clean, only what matters

The owner, 2026-11-09:

> "The screen while playing isn't good at all, not even close. I only want this UI showing on my
> screen, in a clean way. And the left icons should be fewer, with some pretty idea and better UI,
> to make a clean experience for players."

Siblings: `BAD_GUI_THINKING_AND_UI.md` (world text and pops), `BAD_GUI_2_PANELS.md`,
`BAD_GUI_3_EGG_SHOP.md`, `BAD_GUI_4_MAIN_MENU.md`. Same rules and the same image pipeline
(owner sheets → `cut_sheet.py` → review → `App/Ui/Kit`). This file **replaces `MISSION.md` §3**
(in-game HUD) where they differ.

---

## 1. The images

| File | What it is |
|---|---|
| `docs/brief/bad-gui/10-ingame-hud-current.png` | **Now (bad)** |
| `docs/brief/bad-gui/11-target-deck-bar-REFERENCE-ONLY-copyrighted-art.png` | **Target deck bar.** The art on those cards is copyrighted (Goku-style characters), so it's a layout and style reference only. Never upload or use it. |
| `docs/brief/bad-gui/12-target-quest-panel.png` | **Target quest/tutorial panel** |
| `docs/brief/bad-gui/13-target-currency-bars.png` | **Target currency bars** |

### What's wrong with "now"
1. **Too many left buttons:** 7 icons in a column, plus **two duplicate "home" buttons** (top-left
   and bottom-left), plus a lone sword button next to the deck. It's cluttered, and it's unclear
   what matters.
2. **The buttons are small and code-drawn:** small rounded squares with a thin border. They're
   not the painted, chunky, glossy buttons of the reference.
3. **The currency bars are close but flat:**
   - a thin dark bar with a flat gradient
   - the coin icon is a flat "$" coin
   - the "+" is a flat square
   - the numbers are small

   The target is a **painted glossy pill**: a big shiny coin or diamond overlapping the left end,
   a dark glass body with a coloured rim, a big bold number and a round glossy "+".
4. **A random trophy button** sits alone top-right.
5. **The deck cards are small and empty:**
   - tiny text ("Rai Stormvolt / Common / Lv. 1") crammed into the bottom
   - small rarity letters

   The target cards are **taller, with art filling the card**, a family/element icon top-left,
   **a big "Lv. 32" top-right**, a **row of stars** on a dark strip at the bottom, and a slot
   number box bottom-right. No name text on the bar.
6. **There's no quest/tutorial panel.** The target has a clean painted panel on the right
   showing what to do next.
7. **Nothing guides the player:** no current-goal display, no hints.

---

## 2. The clean layout (only these on screen while playing)

```
┌───────────────────────────────────────────────────────────────┐
│ [Roblox] [≡]                     [🪙 1.04K (+)] [💎 0 (+)]   │  ← top: menu + currencies
│                                                [🎁] (only when │
│ ┌────┐┌────┐                                     claimable)  │
│ │CARD││EGGS│                            ┌─────────────────┐  │
│ └────┘└────┘                            │ ★ TUTORIAL 🏆   │  │  ← right: quest panel
│ ┌────┐┌────┐                            │   0/2           │  │
│ │WRLD││1v1 │                            │ Collect Coins ☑ │  │
│ └────┘└────┘                            │ ▓▓▓░░░░░░░      │  │
│                                         │ Travel to … ☐   │  │
│                                         └─────────────────┘  │
│                                                               │
│                    ┌───┐ ┌───┐ ┌───┐                          │  ← bottom: the 3 deck cards
│                    │ 1 │ │ 2 │ │ 3 │                          │
│                    └───┘ └───┘ └───┘                          │
└───────────────────────────────────────────────────────────────┘
```

### 2.1 Left: only 4 buttons, in a 2 × 2 grid (was 7 + duplicates)
| Button | Opens | Colour (painted) |
|---|---|---|
| **CARDS** (backpack/cards icon) | Inventory / collection | Red-orange |
| **EGGS** (egg icon) | Egg Shop | Orange-gold |
| **WORLDS** (globe/portal icon) | Worlds map | Purple |
| **1v1** (crossed swords) | Arena (queue) | Teal-blue |

**What happened to the others:**
- **Deck:** removed as a button. **Tapping the deck bar opens the Deck Builder.**
- **Daily gift:** removed from the grid. A **gift icon appears under the currencies only when a
  reward is claimable**, with a bounce and a red dot. Otherwise it's hidden.
- **Settings, quests list, main menu:** inside **one small round "≡" menu button** top-left
  (below or next to the Roblox top-bar buttons, never covering them). It opens a small painted
  dropdown: Settings, Quests, Main Menu.
- **Trophy button:** removed. Trophies show in the Arena and the main menu.
- **The duplicate home buttons:** removed. "Back to Lobby" goes in the ≡ menu, and appears as a
  temporary button only while the player is inside a world.

**The pretty idea for the grid:**
- Big **chunky painted square buttons** (about 76 px on PC, 64 px on phone) with a glossy top,
  a dark bottom lip, a thick outline and a big icon, like the reference.
- Each has a **short big label** stuck on the bottom edge ("CARDS", "EGGS", "WORLDS", "1v1"),
  in white with a thick stroke.
- An idle shimmer passes across one button every few seconds.
- Notification dots bounce.
- On press: squash and the click sound.

### 2.2 Top-right: currency bars (target 13)
- Painted pill: a big glossy coin (gold) or diamond (blue) **overlapping the left end**, a dark
  glass body with a gold or blue rim, a **big bold number** (short format: 1.04K, 12.5M), and a
  **round glossy "+"** (gold for coins, blue for gems).
- About 240 px wide on PC.
- The "+" on Coins opens the earn-coins tip (Coins are never sold); the "+" on Gems opens the
  gems info.
- Gains: icons fly in, the pill pulses, the number counts up.

### 2.3 Right: quest/tutorial panel (target 12)
- **Header:**
  - a painted dark-blue panel with a gold trim
  - an angled header with **"TUTORIAL"** (or "QUESTS" after the tutorial) in big gold-gradient
    outlined letters
  - a trophy with three stars on the right
  - a "0/2" counter pill under the header
- **Rows** (up to 2): the task text in bold white with a stroke, the count in brackets
  ("Collect Coins [1.04K/10K]"), a checkbox (empty, or green with a tick when done), and a thin
  progress bar under each row.
- **Data:** the real tutorial steps first (move, harvest, sell, hatch an egg, build a deck, win a
  Trial, try the Arena), then the daily quests.
- **Behaviour:**
  - when a task finishes, the box ticks with a bounce, "+1" pops, and the next task slides in
  - tap the panel to collapse it to a small trophy badge with a ring; tap again to expand
  - it collapses automatically during battles

### 2.4 Bottom-centre: the deck bar (target 11 layout)
- **3 tall cards** (about 130 × 175 px on PC), in rarity-coloured painted frames:
  - **art** fills the card: the character's approved art, or the clean template emblem
  - the **family/element icon** in a circle top-left
  - a **big "Lv. N"** top-right in white with a stroke
  - a dark strip at the bottom with **stars** (the evolution stage or rarity stars, gold)
  - the **slot number** in a small framed box bottom-right
  - **no name text** on the bar
- Tap any card to open the Deck Builder.
- They lift slightly on hover and gently bob in turn.
- The 1v1 button stays in the left grid, not next to the deck.

### 2.5 Everything else stays off the screen
- No other permanent text, labels, hints or buttons.
- Messages are world-space pops (`BAD_GUI_THINKING_AND_UI.md`).
- In battle, this HUD hides completely.

---

## 3. What the owner generates (exact prompts)

Attach `13-target-currency-bars.png`, `12-target-quest-panel.png` and
`02-good-roblox-hud-reference.png` as style references. Flat magenta background, pieces
separated, **no text** unless the prompt says so.

**E1. HUD buttons** → `art/ui/sheets/hud_buttons.png`
> "Four big chunky square Roblox game HUD buttons in the style of the attached images: glossy,
> thick dark outline, rounded corners, darker bottom lip, big centered icon. (1) red-orange with a
> backpack full of cards icon, (2) orange-gold with an egg icon, (3) purple with a glowing portal /
> globe icon, (4) teal-blue with crossed swords icon. Plus one small round dark button with a
> three-line menu icon, and one small square gift-box button. No text. Flat magenta background,
> separated."

**E2. Currency pills** → `art/ui/sheets/hud_currency.png`
> "Two Roblox game currency bars in exactly the style of the attached currency image: a long dark
> glass pill with a gold rim and a big shiny gold coin overlapping the left end and a round glossy
> gold '+' button on the right end; and the same with a blue rim, a big shiny blue diamond and a
> round glossy blue '+'. Empty, NO numbers. Flat magenta background, separated."

**E3. Quest panel** → `art/ui/sheets/hud_quest.png`
> "Quest tracker panel pieces in exactly the style of the attached tutorial image: a dark blue
> panel with gold trim and an angled header plate (empty, no text); a gold trophy with three gold
> stars; a small dark counter pill; an empty square checkbox and a checked green checkbox; a thin
> progress bar background and a gold fill bar. No text. Flat magenta background, separated."

**E4. Deck bar card pieces** → `art/ui/sheets/hud_deckcards.png`
> "Tall trading-card frames for a Roblox game HUD in the style of the attached deck-bar image, NO
> characters, NO art inside (empty window): frames in grey, blue, purple, gold and green; a small
> round element-icon socket for the top-left corner; a dark bottom strip with five empty star
> slots; a filled gold star; a small square number box. No text. Flat magenta background,
> separated."

### Review gate (`CLAUDE.md`, Asset safety)
- Contact sheets go in `docs/review/hud_*.png`.
- Check: no characters, no copyrighted art.
- Wait for the owner's OK. Upload in batches of 5 or fewer; stop on any rejection.

---

## 4. Code changes
1. Rebuild the HUD from `App/Ui/Kit` pieces, laid out as in section 2, scaled from a
   1920 × 1080 design with `UIScale`.
2. Remove: the old 7-button column, both home buttons, the trophy button, the sword button by the
   deck, and the deck button.
3. Add:
   - the ≡ menu dropdown (Settings, Quests, Main Menu, Back to Lobby when in a world)
   - the conditional gift button
   - the tutorial/quest panel with the tutorial steps (`Config/Tutorial`, server-tracked like
     quests, with tests)
   - the deck bar opening the Deck Builder
4. **Mobile:**
   - at 1334 × 750 the grid stays 2 × 2 at 64 px
   - the quest panel shrinks to its collapsed badge by default
   - the deck cards scale to about 100 × 135
   - nothing overlaps the Roblox top bar or the thumbstick area (bottom-left on mobile, so on
     touch devices the left grid sits higher, above the thumbstick zone)
5. Until the owner's E1-E4 arrive, use the current kit images marked TEMP, but **with the new
   layout and button count right away**.

## 5. Checklist
- [ ] Left grid down to 4 painted buttons (CARDS, EGGS, WORLDS, 1v1) with labels; duplicates,
  trophy, deck and sword buttons removed
- [ ] ≡ menu with Settings, Quests, Main Menu, Back to Lobby (in worlds)
- [ ] Conditional gift button
- [ ] Currency pills like target 13 (painted, big number, glossy +), with count-up and fly-in
- [ ] Tutorial/quest panel like target 12, with real tutorial steps, tick animation, collapse
- [ ] Deck bar like target 11's layout (tall cards, big level, stars, slot number, no names),
  opens the Deck Builder
- [ ] E1-E4 prompts in `PROMPTS_V3.md` + `WAITING_ON_YOU.md`; sheets cut, reviewed, approved,
  uploaded, swapped
- [ ] Mobile layout checked in Play (thumbstick zone, top bar)
- [ ] Comparison `docs/screens/roblox-ui/compare_hud.png` (targets 11-13 + `02` vs ours), scoring
  8+ on clean screen, painted look, big text, fewer buttons
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
