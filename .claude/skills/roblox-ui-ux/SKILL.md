---
name: roblox-ui-ux
description: Building 1v1 CARD interfaces - design tokens, the client App framework (Ctx, Ui helpers, screens), mobile-first scaling, card and rarity presentation, shop/odds/Robux rules, animation and visual QA. Use for any screen, HUD, card visual or UI animation.
---

# UI/UX

Source of truth: `docs/brief/05-ui-design-system.md`. The concept board
(`docs/brief/concept-board.png`) is a reference for layout and mood only. Never use its characters
or its "Bet Amount" panel.

## Tokens (`src/client/App/Theme.luau`, never raw colours)
| Token | Hex | Use |
| --- | --- | --- |
| Background | #080B18 | canvas |
| Panel | #12192E | panels |
| Raised | #1A2340 | tiles and controls |
| Purple | #A469FF | selection and premium |
| Blue | #45BEFF | info and secondary |
| Gold | #FFC54B | currency and the primary CTA |
| Green | #48DA97 | success |
| Text | #F2F5FF | primary text |
| Muted | #9EAED3 | secondary text |

Rarity colours: Common #B9C7DC, Rare #45BEFF, Epic #A469FF, Legendary #FFC54B, Mythical #FF668F.

## Framework
- Screens: `App/Screens/<Name>.luau` returns `function(ctx, layer, arg) -> { destroy, refresh? }`.
  Register them in `src/client/init.client.luau`.
- Use `Ctx` only (state, request, toast, confirm, overlay, open/close, attr, now, guid,
  reducedMotion). Never reach `Players.LocalPlayer` or remotes from a screen, so a Studio script
  can render any screen with fake data.
- Helpers: `Ui.panel`, `Ui.button(text, style, onClick)`, `Ui.text`, `Ui.frame`, `Ui.grid`,
  `Ui.list`, `Ui.bar` and `Ui.scroll`. Card art and egg art go through `Visuals.portrait` and
  `Visuals.egg`, which draw labelled placeholders until assets exist.
- Design space is 960×540 with a UIScale fit and `DeviceSafeInsets`. Check it at 844×390 (phone)
  and 1920×1080.

## UX rules (enforced in review)
1. One `primary` (gold) action per panel.
2. Show the egg's name, rarity band, price, owned count and a labelled **"Odds"** button before
   any Coin or Robux purchase. The odds come from `Shared/Domain/Odds.display`, the same table the
   server rolls from.
3. Never rely on colour alone: always show the rarity name, and family as text.
4. Confirm multi-opens and every paid or irreversible action (sell, expand, forfeit).
5. Three equal deck slots. Show the family bonus separately (`Domain/Power.deck`).
6. Keep the card silhouette consistent; rarity only changes the border, foil and particles.
7. Use motion for hatch, selection and results, not everywhere. Honour `settings.reducedMotion`.
- Show the Robux egg button only when the `PaidRandomItemsAllowed` attribute is `true`, the
  world is unlocked and the egg is a Robux egg. The server re-checks regardless.
- No wording that suggests gambling or stakes: say "purse paid by the game", never "bet" or "pot".

## Visual QA
Through the Roblox Studio MCP: play, open each screen, `screen_capture`, compare with the design
system and the concept board's layout, and fix spacing or clipping. Check text at small sizes
(at least 12 px after scale). Report what was looked at.
