# GUI audit: web thinking vs Roblox UI (BAD_GUI_THINKING_AND_UI §5)

Every place that shows text to the player, swept on 2026-11-10 (Phase 2 of `MASTER_FIX_PLAN.md`).
Verdicts: **keep** · **world text** (move onto the object) · **pop** (a short pop at its source) ·
**bigger** (bigger and bolder, fewer words) · **cut**. "Owner" is the phase that finishes the item;
"done" means fixed in Phase 2.

Flags used (§5.2): small text that players must read (< 20 px), sentences over 6 words outside
inspect/settings/odds, messages far from their source, dark boxes of small text, info that could be
an icon.

Counts per file at the sweep (text labels / text under 20 px / code-drawn boxes):
Battle 18/14/8 · CardStats 18/11/6 · Collection 16/18/6 · Shop 13/15/6 · Deck 10/7/3 · Hud 7/4/10 ·
Merchant 7/3/2 · MainMenu 6/3/6 · Play 6/3/6 · Settings 6/4/7 · Quests 5/5/3 · Worlds 5/4/7 ·
Families 4/4/4 · OddsPopup 4/1/3 · Prompts 3/1/2 · Hatch 2/1/4 · Tip 1/1/2.

## 1. Messages (priority 1-2): all done in Phase 2

| Element | Was | Verdict | Now |
|---|---|---|---|
| Toast bar (`App.toast`, bottom of screen) | navy bar, small text, far from source | **cut** | deleted; `ctx.say/popAt/near/cheer/warn/fail/fly` (App/WorldText) |
| Harvest "+2 Oak Log" | toast | **world text** | "+2" with the item's icon pops out of the node, items fly to the CARDS/bag button |
| Rare drop "· rare: +1 …!" | appended to the toast | **world text** | a gold "RARE +1" pop with the item icon over the node |
| Sold for N Coins | toast | **world text** | "+N" coin pop over the merchant, "THANKS!", coins fly to the Coins bar |
| Every server error (`ctx.request`) | toast sentence ("Not enough Coins.") | **pop** | 1-3 red words + icon beside the pressed button, shaking (`Format.errorPop`) |
| Deck needs 3 cards / max level / no spares | toast sentences | **pop** | "NEED 3 CARDS", "MAX LEVEL", "NO SPARES" beside the button |
| Card equipped / deck saved / merged | toast sentences | **pop** | "IN DECK!", "SAVED!", "MERGED!" in green beside the button |
| Level up after a merge | toast sentence | **pop** | centre "LEVEL UP!" (gold, upgrade icon) |
| Quest claim | toast "Quest complete: 250 Coins" | **pop** | "+250" coin pop at the button, coins fly to the bar |
| Quest progress | nothing | **pop** | "+N" beside the quest card (Shared/Ui/Moments) |
| Quest finished | nothing | **pop** | centre "QUEST COMPLETE!" |
| World unlocked | nothing | **pop** | centre "WORLD N UNLOCKED!", then an icon flies to the WORLDS button |
| Daily streak claim | toast "Day 3 reward claimed!" | **pop** | centre "DAY 3!" and coins/gems fly to their bar |
| Locked world tap | toast sentence | **pop** | "<trophies>" with a trophy icon beside the card |
| Invite not available | toast sentence | **pop** | "LIVE GAME ONLY" |
| Server `Notice` push | toast | **pop** | centre pop (no server code sends it today) |

## 2. World text (billboards): done in Phase 2 unless noted

All built by `Shared/Ui/Billboard` (one look: Luckiest Guy, thick stroke, icon on the left,
meaningful gradient, LightInfluence 0, MaxDistance by kind, AlwaysOnTop for places and NPCs).

| Billboard | Verdict | Now |
|---|---|---|
| Hub signs "1v1 ARENA", "WORLDS", "EGG SHOP" | bigger | icon + gold gradient, AlwaysOnTop, 260 studs (Phase 11 rebuilds the places) |
| World name sign | bigger | the world's name with the worlds icon, gold |
| Merchant name | world text | name + coin icon, gold, AlwaysOnTop |
| Guardian gate | world text | name (violet) + its deck power with the power icon (was "GUARDIAN TRIAL") |
| Back to Lobby portal | bigger | "LOBBY" + home icon, gold |
| Resource nodes | world text (new) | the item's name over each node (green; gold for rare), hidden while spent for you |
| Players | world text (new) | name + trophies with a trophy icon over other players (`App/Nameplates`); Roblox's plain name display is off |
| Egg stall prices | world text | **Phase 11** (the egg pavilion with eggs on pedestals is built there) |
| Battle damage numbers | keep, restyle | `App/BattleStage` already pops damage over the hit fighter; crit/heal styling in **Phase 9** |

## 3. Screens (priority 3-6)

| Screen | Web-thinking found | Verdict | Owner |
|---|---|---|---|
| Panel titles (every panel) | 24 px Builder Sans strip title | **bigger** | **done**: 32 px Luckiest Guy, gradient, 3 px stroke, 46 px icon |
| Egg Shop | code-drawn navy panel; scroll row with scrollbar; tiny "World 1 · Green Plains", "Drops…", "Auto-open: Off"; "x1 soon" placeholders; wide green "Claim free daily egg" bar | bigger / cut | Phase 6 |
| Merchant | flat header strip; 13 px subtitle; small 15 px names; empty purple field | bigger | Phase 7 (item icons fixed in Phase 1, sale pops in Phase 2) |
| Settings, Quests, Worlds, Arena queue, Odds, confirmations | code-drawn boxes (`Ui.frame` + `Ui.corner` + `BackgroundColor3`); 12-15 px rows; streak days as small text tiles | bigger | Phase 7 |
| Inventory (Collection) | 18 small texts; text-only tabs labels; card names on small cards | bigger | Phase 8 (item tiles made icon-first in Phase 1) |
| Card inspect (CardStats) | 11 small texts; ability paragraphs | keep (inspect is the one place long text is allowed), **bigger** rows | Phase 8 |
| Deck Builder / Families | 7 + 4 small texts; family list as text rows | bigger | Phase 8 |
| Battle screen | two info boxes of tiny text; battle log (web); round candy buttons; "You act first: 20%" pill | cut / bigger | Phase 9 |
| Result screen | battle log; tiny reason line; no rewards | cut / bigger | Phase 10 |
| HUD | 7-button column + duplicates; tooltip strips; 13 px quest rows | cut / bigger | Phase 4 |
| Main menu | code-text logo; tagline; version line; four tiles | cut | Phase 5 |
| Proximity prompts (`App/Prompts`) | a toast-style plate with small object text | bigger | Phase 11 (with the lobby's place signs) |
| Hatch | caption under 20 px | bigger | Phase 6 |
| Tip popup (Coins/Gems "+") | a paragraph | keep (an explanation panel, like settings) | — |

Nothing in this list is left without an owner phase; `docs/MASTER_FIX_REPORT.md` tracks each.
