# BAD GUI 9: harvest prompt, CARDS button, inventory showing card stats

The owner reported these on 2026-11-11.
- **Screenshots:** `docs/brief/bad-gui/21-24`.
- **Related:** `BAD_GUI_6_DECK_AND_INVENTORY.md` (targets 14/15) and `UI_TARGETS.md`.
- **Rules:** the UI rules in `CLAUDE.md` apply: big outlined words, painted kit images, no web boxes.

---

## 1. Harvest prompt is a web tooltip (`21-harvest-prompt-web-box.png`)

**Now:** a dark rounded box with a thin border, an "E" key, then "Harvest" with "Greenleaf" in
small text under it. This is the web-style box of small text that `CLAUDE.md` bans.

**Fix:**
- **No box.** The prompt is a billboard above the node.
- **Order, left to right:**
  1. a painted round **E key plate** (on touch, a big round tap button instead)
  2. the big outlined word **HARVEST**
  3. the **item icon** (the Greenleaf icon) and its yield, e.g. "x1"
- **Remove** the second line of small text.
- **Hold to harvest:** a ring fills around the E plate.
- **When done:** the item icon flies to the bag counter (`ctx.fly`).
- **Same style for every interact prompt:** sell, talk, open egg, enter portal. Each one uses one word
  that matches its action (SELL, TALK, OPEN, ENTER).

## 2. CARDS button opens the Inventory (`22-cards-button-opens-inventory.png`)

**Bug:** the HUD **CARDS** button opens the Inventory (items: Greenleaf, Meadow, Oak Log).

**Fix:**
- **The game has no Cards screen yet, so build one.** CARDS opens the **Cards** screen: the card
  collection.
- **Layout:** like target 15 / `hd-03`, but cards only.
  - **Header:** a cards icon plate, a big **CARDS** title, search, and the storage count (N / 300).
  - **Sort or filter chips:** rarity, family, level.
  - **Grid:** art-first small cards, each with a rarity-coloured frame, a family gem and a power
    plate. No names on small cards.
  - **Inspect panel on the right:** the large card plus Power / Health / Skill / Family Bonus, and the
    buttons Equip, Upgrade (merge), Favorite.
  - **Shortcut:** a big **DECK** button that opens the Deck Builder (BAD_GUI_6).
- **Inventory** keeps its own HUD button (the bag icon) and shows **items only**.

## 3. Inventory shows card stats (`24-inventory-shows-card-stats.png`)

**Bug:** with the Inventory open, the right panel shows the **Halvard card** inspect (Power, Health,
Skill, Family Bonus, Equipped / Stats). The Inventory must never show card stats.

**Fix:** the Inventory inspect panel shows only the **selected item**:
- a big item icon on a tier tile
- the item name in big outlined text
- the count ("x9")
- the sell price (coin icon + number)
- a painted **SELL** button with a quantity picker
- "Sold at:" with the merchant icon (one line)
- **When nothing is selected:** the panel is hidden and the grid fills the space.

**The card panel in that screenshot also breaks the rules.** Fix it in the Cards screen:
- **Two rarity systems at once:** an **SR** badge and an "Epic" label. `CLAUDE.md` locks
  Common / Rare / Epic / Legendary / Mythical. **Remove N/R/SR/SSR/UR letters everywhere.** Badges show
  the locked rarity name or its coloured gem.
- **Numbers disagree:** the card plate says 270 / 146, but the panel says Power 538 / Health 778.
  Use one source (the server's card stat function at the copy's level) for both, and add a test.
- **Two different names:** the header says "HALVARD" and the banner says "Halvard Frostwarden".
  Use the same full display name in both places.
- **Text is too small:** the skill text ("+10% damage to Chilled targets") and the green Family
  Bonus lines. Show the skill as an icon + name, with the one-line effect at 20 px or larger. Show the
  family bonus as a chip (family icon + "+2%").
- **The STATS button opens nothing new,** because the stats are already shown. Replace it with
  **UPGRADE**.

## 4. Inventory tabs have no labels (`23-inventory-tabs-no-labels.png`)

**Now:** the left tabs show an icon plus a bare number ("4", "3/5", "0", "+1"). A player can't tell
what each tab is.

**Fix:**
- Each tab gets a big outlined label under its icon: **ALL, ITEMS, CRYSTALS, EGGS, MORE**. Name them
  after what each tab actually filters.
- Counts go in a small number badge on the tab's corner.
- No Cards tab here, because cards live in the Cards screen.
- The "+1" gold tab is unclear. If it means expanding storage, move it to a gold "+" next to the
  storage count in the header, as in target 15.

## 5. Checklist
- [x] Every interact prompt is a billboard: E plate + big word + item icon, no box, no small second line
- [x] CARDS opens the new Cards screen. The bag button opens the Inventory.
- [x] The Inventory shows items only, and its inspect panel shows the item + SELL
- [x] SR/SSR/UR letters are removed everywhere. Rarity uses the locked names and gems.
- [x] The card plate and the panel show the same Power/Health (one source, with a test)
- [x] One display name everywhere. STATS is replaced by UPGRADE.
- [x] Inventory tabs have labels and count badges
- [x] Before/after screenshots in `docs/screens/roblox-ui/compare_cards.png` and
  `compare_inventory2.png`, scored 8+
- [x] Tests and lint clean. Committed and pushed with named paths only.

## Done (2026-11-11)

- **Prompts** (`App/Prompts`): a billboard with no box: a painted E plate (a round green TAP button
  on touch), one big word, then the item icon on a soft glow and its yield ("x1-3") for nodes, or the
  place's own icon. Harvest is a 0.4 s hold and a gold ring fills around the E plate. The server gives
  every prompt one word (HARVEST, SELL, FIGHT, ENTER, OPEN, CLAIM) and an icon
  (`Server/World/WorldBuilder`, `HubBuilder`, `Config/HubLayout`); a tall stall sets its own height,
  so the merchant's SELL clears its cart (its name sign moved up).
- **Cards screen** (`Screens/Cards`, new): opened by CARDS (now a fan of the kit's card backs, not the
  bag). Header with the cards icon, CARDS, search and N / 300 with a gold "+"; rarity chips (gem +
  name), FAMILY and SORT chips; a paged 5 x 2 grid of art-first cards with a level, family gem and
  power plate; the inspect panel (large card, full name, rarity name, POWER, HEALTH, family bonus
  chip, the Skill as icon + name + one 20 px line, EQUIP / UPGRADE / FAVORITE, SELL for spares of a
  maxed character); a big DECK button.
- **Inventory** (`Screens/Inventory`, was `Collection`): opened by the new BAG button at the left end
  of the deck bar (harvested items fly to it). Items and eggs only. Tabs ALL / ITEMS / EGGS with big
  labels and corner count badges; the bag slots with a gold "+" in the header. Selecting an item shows
  its icon on a tier tile, name, "xN", the price each, a quantity picker, SELL and "SOLD AT ANY
  MERCHANT"; an egg shows OPEN. Nothing selected: no panel, the grid fills the space.
- **No rarity letters anywhere:** `Config/Rarities` has no `badge` field; cards, the hatch reveal, the
  loading fan and the battle bar show the rarity's gem (kit `corner_gem_*`) or its name. Mythical's
  display name is now "Mythical" (it was "God-tier").
- **One source for card numbers:** `Domain/Power.stats` (the battle unit at the copy's level) feeds the
  card plate (now POWER and HEALTH), the Cards panel and the stats panel; `CardNumbers.spec` pins it.
  Halvard at level 1 reads 538 / 778 everywhere (the plate used to say 270 / 146).
- **One name:** the panel shows the full display name, wrapping to two lines.
- **STATS is UPGRADE** (merges spares; a red badge shows how many).
- Screens: `docs/screens/roblox-ui/compare_cards.png`, `compare_inventory2.png`, `compare_prompts.png`,
  `docs/screens/bad_gui9/`.
