---
name: game-qa
description: The QA gate for 1v1 CARD - functional, visual, policy and regression checks to run before claiming any feature, milestone or release is done, and the exact report format. Use before every "done", commit summary or status update.
---

# QA gate

Never claim something works without running it. "Should work" isn't a result.

## 1. Automated (every change)
- Run the full check (`roblox-testing`): StyLua, Selene with 0 warnings, strict luau-lsp with 0
  errors, both Rojo builds, and the headless suite with 0 failed.
- In real Studio: `STUDIO TESTS: N passed, 0 failed` and
  `BOOT CHECK: ... errors=0`.
- If battle rules or characters changed: parity (1,000 battle seeds and 300 AI seeds) and
  `balance.py` inside its targets.

## 2. Functional play-test (Roblox Studio MCP: `start_stop_play`, `screen_capture`, `get_console_output`)
Walk the loop and capture each step:
1. Join → the snapshot arrives, the HUD shows 500 Coins, and you're placed in your current world.
2. Shop → Odds pop-up (exact %) → buy with Coins → hatch reveal (normal and Golden) → the card
   appears in Collection.
3. Inspect → merge a spare → level up. Deck → three cards → Save. Check deck power and family
   bonus.
4. Harvest a node (you can't from more than 12 studs) → sell at the merchant (you can't from
   far away).
5. Guardian Trial → win and lose → first-clear rewards are paid once.
6. Ranked with two clients (Test → Clients and Servers, 2 players): queue → match → picks,
   timeouts, KO replacement → result. Check the purse and trophies.
7. Quests claim, streak claim, settings persist after a rejoin.
Console: no errors and no unexpected warnings.

## 3. Policy (Player Emulator, manual)
All four combinations of ArePaidRandomItemsRestricted × IsPaidItemTradingAllowed. Every
`[PolicySelfCheck]` line must end in `MATCH`, and the Robux egg button is hidden when restricted.
Not done until all four have actually been run.

## 4. Visual
- Phone (844×390) and desktop: no clipping or overlap, and text is at least 12 px after scale.
- One gold primary action per panel, rarity shown as text, and Placeholder art clearly labelled.

## 5. Report format
- **Built/changed:** files and behaviour.
- **Bugs found and fixed.**
- **Checks run:** each command and its result line.
- **Verified in Studio** vs **verified outside Studio only.**
- **Not verified / placeholder / unfinished:** be explicit.
- **Next highest-priority items.**
