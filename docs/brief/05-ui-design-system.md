# Design System — 1v1 CARD

## Palette
| Token | Hex | Use |
|---|---|---|
| Background | `#080B18` | App/game canvas |
| Panel | `#12192E` | Main panels |
| Raised panel | `#1A2340` | Tiles, cards, controls |
| Purple | `#A469FF` | Premium, epic, selection |
| Blue | `#45BEFF` | Rare, info, secondary actions |
| Gold | `#FFC54B` | Currency, legendary, primary CTA |
| Green | `#48DA97` | Success, owned, confirmation |
| Text | `#F2F5FF` | Primary copy |
| Muted | `#9EAED3` | Secondary copy |

## Rarity mapping
Common `#B9C7DC`; Uncommon `#48DA97`; Rare `#45BEFF`; Epic `#A469FF`; Legendary `#FFC54B`; Mythical `#FF668F`.

## UX rules
1. One dominant primary action per panel.
2. Keep egg name, rarity, price, owned count and odds visible before opening.
3. Avoid relying on color alone: always show rarity text and icon.
4. Show a confirmation for multi-open and any paid action.
5. Keep the three deck slots visually equal and show family synergy separately.
6. Keep the card silhouette consistent; rarity only changes border, foil and particles.
7. Use motion for hatch reveal, hover and selection, not for every UI element.
