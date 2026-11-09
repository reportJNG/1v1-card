# BAD GUI THINKING AND UI: stop building web UI, build Roblox UI

The owner, 2026-11-09:

> "Like these GUI I don't want them at all, not web. This is web, to do in shop and characters,
> this background and little text. Roblox UI should be big text and icon usage. Roblox games are
> great with big font text and icons, and text appearing on top of objects. That's what Roblox
> is famous for."

This file is a **permanent design rule** plus a **task list**. It applies to every screen: HUD,
shop, characters/cards, inventory, deck, worlds, battle, and every popup and notification.

---

## 1. The bad example (never again)

`docs/brief/bad-gui/01-web-style-toast-bar.png`: the **"+2 Oak Log"** notification.

What makes it "web":
- a **wide dark navy bar** across the bottom of the screen, like a website snackbar or cookie
  banner
- **small, thin, plain text**: no stroke, no colour, no icon
- the information is **far from the thing that caused it**: the tree is in the world, the text
  is in a box at the bottom
- **no motion and no personality**: it just appears and sits there
- it **covers the deck bar** and other UI

The same "web thinking" appears elsewhere. Find and fix all of it:
- dark rectangles with small text in them
- labels inside panels instead of on the object
- long sentences
- grey or white body text, thin fonts
- information shown in a list where an icon would do

---

## 2. Roblox UI thinking (the rules)

Use `docs/brief/bad-gui/02-good-roblox-hud-reference.png` and the boards in `docs/brief/`
as the look.

1. **Big, bold, outlined text.**
   - Fonts: Fredoka One / Luckiest Guy / Builder Sans Black (`Enum.Font`).
   - Every gameplay text gets a thick dark `UIStroke` (2-4 px, depending on size).
   - Important numbers get a `UIGradient` (gold for coins, cyan for gems, rarity colours for
     cards).
   - Minimum sizes: 28 px for popup text, 36-60 px for headline pop text, 20 px for anything a
     player must read.
2. **An icon first, then a few words.** "+2 🪵" beats "+2 Oak Log".
   - Every reward, item, currency and stat has an icon (from the icon pack or our kit). Never
     use emoji characters in text; use image icons.
   - Use the icon plus a number, with the name only where it's needed.
3. **Text lives on top of objects in the world.** Use `BillboardGui` text and icons above:
   - **trees, ores and resource nodes:** name + level, or a "Ready" glow when harvestable
   - **NPCs and merchants:** name in big outlined text, plus a coin icon for merchants
   - **portals:** "WORLDS", "1v1 ARENA" in big glowing letters
   - **the egg stall:** each egg's price floating above it
   - **Guardian Trial gates:** the guardian's name and its power/level
   - **players:** name and level/trophies (small, clean)
   - **pickups and harvests:** "+2" with the item icon popping out of the object (section 3)
4. **No dark boxes behind gameplay text.**
   - Floating text stands on its own: stroke, gradient, and maybe a soft glow.
   - Panels are only for real menus (shop, inventory, deck), and even those use the bright kit
     style, not plain navy rectangles.
5. **Motion on everything.** Text pops, bounces, floats up and fades. Numbers count up. Icons fly
   to their HUD counter. Nothing just "appears".
6. **Fewer words, bigger.** If a sentence can be a number plus an icon, make it that. If it must
   be words, keep it to 1-4 words, big.
7. **Colour means something.**
   - Gold = coins and primary buttons. Cyan/blue = gems.
   - Rarity colours = cards and eggs.
   - Green = gain / success. Red = loss / error.
8. **Don't cover the play area or the HUD.** World-space text sits on the object. Screen pops
   appear briefly near the centre or near the related HUD element, then fly away. Never a bar
   across the bottom.

---

## 3. Replacements, element by element

| Today (web) | Roblox replacement |
|---|---|
| **"+2 Oak Log" bottom bar** (and every resource or harvest toast) | When harvesting, a `BillboardGui` pop **above the tree**: a big "+2" with the log icon, gradient text, thick stroke. It scales 0 → 1.2 → 1, floats up about 3 studs, fades in 0.9 s. At the same time a few small log icons fly from the tree into the inventory/backpack HUD button, which bounces and shows its count going up. A harvest sound plays. **The bottom bar is deleted.** |
| Coin and gem gains (sell, rewards, quests) | Coin icons burst from the source (merchant, chest, victory screen) and fly to the coin bar. The coin bar pulses and counts up. A big "+25" with a coin icon pops at the source. |
| Selling to a merchant | A "+25" coin pop above the merchant's head, coins flying to the coin bar, and the merchant's billboard briefly saying "THANKS!". No text box. |
| Error messages ("Not enough coins") | A short red pop text, 2-3 words ("NEED 🪙 250", with an image icon), shaking next to the button pressed, plus the error sound. No banner. |
| Quest progress | The quest tracker card ticks with a bounce; a "+1" pops beside the task; on completion a big "QUEST COMPLETE!" pop with a gold stroke appears in the centre for 1.2 s. |
| Level up / merge | "LEVEL UP!" in big gradient text over the card, with a ring burst. |
| Unlocks (new world, new egg) | A big centre pop ("WORLD 2 UNLOCKED!") with an icon and a short fanfare, then it flies to the related HUD button, which glows. |
| Battle damage | Big damage numbers above the hit character (white, red-tinted for crits with "CRIT!", green for heals) that jump up and fade, plus the shake. |
| Shop item text | A big price on each tile (coin icon plus number, gradient, stroke), the egg's name above it in outlined text, and the rarity shown by colour and badge, not by sentences. |
| Character cards | The name in big outlined text on the card; stats as icon plus big number (sword 340, shield 90); no paragraphs on the card. Long text (ability descriptions) goes only in the inspect panel, still big and short. |
| Panel titles | Huge outlined title text (gradient), with its icon. No small header strips. |
| Notification toasts in general | Gone. Every message becomes either a world-space pop at its source or a short centre pop. |

---

## 4. World-space text (BillboardGui) standards

- **One module, `App/WorldText`.** It handles every billboard and pop, from pooled instances.
- **Billboard sizing:** use scale-based `Size` with `MaxDistance` (60-120 studs depending on
  type), so it stays readable but doesn't clutter at range. `AlwaysOnTop` only for pops and
  important labels (portals, merchants).
- **Text:** a big font, thick `UIStroke`, `UIGradient` where it carries meaning, and an icon
  `ImageLabel` to the left.
- **Pops:** pooled (reused, not created and destroyed each time), at most about 20 active,
  tweened scale, position and transparency.
- **Performance:**
  - use `LightInfluence = 0` for clarity
  - update nothing every frame unless it's moving
  - static labels never change their text unless the value changes
  - respect `settings.reducedMotion` (shorter, smaller pops)
- **Mobile:** test that billboards are readable at 1334×750 and that they don't block taps on
  the HUD.

---

## 5. Sweep: find every piece of web thinking

1. **List every place that shows text to the player:** grep for `TextLabel`, `TextButton`, toast
   calls, notifications, and every screen in `src/client/App/Screens/*`. Write the list to
   `docs/GUI_AUDIT_ROBLOX.md`, marking each one **keep**, **replace with world text**,
   **replace with a pop**, **make bigger and bolder** or **cut**.
2. **Flag as web thinking:**
   - any dark rectangle whose main content is small text
   - any text under 20 px that players must read
   - any sentence longer than 6 words outside the inspect, settings and odds panels
   - any message shown far from its source
   - any information that could be an icon
3. Fix them in priority order:
   1. harvest, pickup and reward messages
   2. errors
   3. shop
   4. cards/characters
   5. inventory and deck
   6. the rest

---

## 6. Task checklist
- [ ] Delete the bottom notification bar component and every call to it
- [ ] `App/WorldText` module: billboards plus pooled pops, with specs for pooling and limits
- [ ] Harvest pop above nodes + icons flying to the backpack button + counter bounce
- [ ] Coin and gem burst-and-fly to the currency bars, count-up, source pop
- [ ] Merchant sell pop
- [ ] Error pops next to the pressed button
- [ ] Quest tick, "+1" and "QUEST COMPLETE!" pop
- [ ] Level-up and unlock pops
- [ ] Battle damage numbers (normal, crit, heal)
- [ ] Billboards: nodes, NPCs and merchants, portals, egg stall prices, Guardian gates,
  players' names
- [ ] Shop tiles: big prices, outlined names, colour and badge instead of words
- [ ] Cards: big outlined name, icon + number stats, no paragraphs on the card
- [ ] Panel titles: huge outlined gradient titles with icons
- [ ] `docs/GUI_AUDIT_ROBLOX.md` sweep done, every item fixed or justified
- [ ] Play-mode before/after screenshots in `docs/screens/roblox-ui/`:
  - harvesting in World 1
  - selling
  - an error
  - a quest completion
  - the shop
  - an inventory card
  - a battle hit

  Each one has a side-by-side comparison, scored 8+ on "big text, icons, on-object, no web
  boxes".
- [ ] Tests pass, the Rojo builds are clean, committed

## 7. Rules to keep forever (add these to `CLAUDE.md` under "UI rules")
- No web-style UI: no snackbars or toast bars, no dark boxes of small text.
- Big bold outlined text with icons. World text sits on top of the object it's about.
- Every gain flies to its HUD counter. Every message appears at its source.
- 1-4 big words, or an icon plus a number. Never a paragraph in gameplay.
