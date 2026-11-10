# UI TARGETS: always remember how the UI should look

`CLAUDE.md` loads this file every session. **Before touching any screen, open its target
images below and match them.** The owner has rejected code-drawn ("CSS") UI many times. Never
go back to it.

## The 8 rules (short version)
1. **Painted images, not styled boxes.** Every visible panel, frame, button, pill, tab, badge and
   tile is an owner-generated image piece (9-slice), served by `App/Ui/Kit`. Never
   Frame + UICorner + UIStroke boxes. (`BAD_GUI_2_PANELS.md`)
2. **Big bold outlined text and icons.** Display fonts with thick strokes, gradients on key
   words, an icon on everything, 1-4 words. Nothing under 20 px that players must read.
   (`BAD_GUI_THINKING_AND_UI.md`)
3. **Text on top of objects.** World-space pops and billboards; gains fly to their HUD counter.
   No snackbars or toast bars.
4. **Art-first cards.** Art fills the card; badge top-left, gem top-right, big number on a power
   plate. No names on small cards.
5. **A clean screen while playing.** Only: the 4-button grid, currency pills, the quest panel,
   the deck bar, the ≡ menu. (`BAD_GUI_5_INGAME_HUD.md`)
6. **No empty flat space, no scrollbars, no placeholder buttons** ("soon"), no tiny labels.
7. **Juice:** pop-in, stagger, hover lift, press squash, glow pulses, count-ups, a sound on every
   action.
8. **Safety first** (`CLAUDE.md` Asset safety): reference images with copyrighted characters are
   **layout-only**, never uploaded or cropped. Every new image goes through a review sheet and
   the owner's OK before upload.

**The pipeline:** owner sheets (`art/ui/sheets/`) → `scripts/art/cut_sheet.py` → `kit.json` +
slice tests → review sheet → owner OK → upload in batches of 5 or fewer → `App/Ui/Kit`.
Prompts: `art/ui/PROMPTS_V3.md`.

## Target images per screen (match these)

| Screen | Target(s) | Spec |
|---|---|---|
| Launch loading | (card shuffle, `MISSION.md` §2.2) | `MISSION.md` §2 |
| **Main menu** | `docs/brief/bad-gui/09-main-menu-target.png` (character = layout only) | `BAD_GUI_4_MAIN_MENU.md` |
| **In-game HUD** | `bad-gui/12-target-quest-panel.png`, `bad-gui/13-target-currency-bars.png`, `bad-gui/11-target-deck-bar…` (layout only), `bad-gui/02-good-roblox-hud-reference.png` (layout only) | `BAD_GUI_5_INGAME_HUD.md` |
| **Notifications / world text** | (rules) | `BAD_GUI_THINKING_AND_UI.md` |
| **Merchant** | `bad-gui/04-merchant-target.png` | `BAD_GUI_2_PANELS.md` |
| **Egg Shop** | `bad-gui/06-egg-shop-target.png`, `ui-refs/hd-02-egg-shop.png`, `ui-refs-2/01-egg-gui.png` | `BAD_GUI_3_EGG_SHOP.md` |
| Egg opening | `ui-refs-2/02-egg-opening.png` | `MISSION.md` §7.3 |
| **Deck Builder + Families** | `bad-gui/14-target-deck-builder…` (layout only), `ui-refs/hd-04-deck-builder-families.png` | `BAD_GUI_6_DECK_AND_INVENTORY.md` |
| **Inventory + inspect** | `bad-gui/15-target-inventory…` (layout only), `ui-refs/hd-03-inventory-card.png` | `BAD_GUI_6_DECK_AND_INVENTORY.md` |
| Cards (frames, template, stats, animations, rarity) | `ui-refs-2/03..08` | `MISSION.md` §6 |
| Arena (queue panel) | `ui-refs/hd-05-arena.png` (no bet panel!) | `MISSION.md` §8 |
| **Battle screen (fighting) + 5 arena maps** | `bad-gui/18-target-battle-screen.png` | `BAD_GUI_8_BATTLE_SCREEN.md` |
| **Battle result (Victory / Defeat)** | `bad-gui/16-target-battle-result.png`, `ui-refs/hd-06-victory.png` | `BAD_GUI_7_BATTLE_RESULT.md` |
| Worlds | `ui-refs/hd-07-worlds.png` | `MISSION.md` §8 |
| **Lobby map (hub), marked BAD** | `docs/brief/concept-board.png` (hub), `bad-gui/09-main-menu-target.png` (scene only; character is layout-only) | `FIX_LOBBY.md` |
| Overall mood | `docs/brief/concept-board.png` | `docs/ART_STYLE.md` |

**Bad examples to never repeat:** `bad-gui/01` (toast bar), `03` (merchant), `05` (egg shop), `07`
(main menu), `10` (in-game HUD), `17` (battle result), `19` (battle screen).

## How every UI task is judged
A side-by-side comparison (target | ours) in `docs/screens/roblox-ui/compare_<screen>.png`,
scored 1-10 on:
- painted look
- big text and icons
- matches the layout
- clean (little text, no empty space)
- motion

**Below 8 isn't done.**
