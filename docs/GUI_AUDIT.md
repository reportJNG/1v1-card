# GUI audit (MISSION section 4.2)

The current screens (`docs/screens/step3`, `docs/screens/final`, and the step-5 captures) compared
with every reference board. For each difference: its cause (the six usual causes of the "bad GUI"
plus the in-game one) and where it is fixed.

Causes: **F** flat fills · **H** weak type hierarchy · **B** thin borders, no glow · **P** no icon
plates · **T** cheap low-resolution TEMP images · **M** too little motion · **D** (while playing)
panels too big and too dark.

## Global
| Difference | Cause | Fix |
| --- | --- | --- |
| Panels, buttons, tabs, tiles and toasts were code-drawn TEMP images at low resolution | T, F | Section 4: `scripts/art/ui_slots.py` renders all 51 used UI slots at 4x with gradients, rims and glows (final ids in `art/ui/ids.json`) |
| Rarity frames were a code-drawn rounded border tinted per rarity; no ornament, no energy | T, B | Section 6.1: `scripts/art/card_kit.py` frames, glow, energy and badges per rarity and size |
| Rarity read only by colour and word; no N / R / SR / SSR / UR badges | H | Section 5: `Config/Rarities` display fields; badges on every card; Odds shows "UR · God-tier" |
| Static cards | M | Section 6.5: `App/CardFx` aura, orbit, glow breathing, energy flicker, shine, particles, hover lift |
| While playing, a tall dock, a top bar with three badges, a logo, a hint pill, a place label and a quest bar covered the world | D, H | Section 3: `App/Hud` (icon grid, two currency bars, deck bar, collapsible quest card) |
| In-game panels ~85 % of the screen, deep navy | D | Section 3.2: `panel_light` glass at ~70 % while playing |

## Main menu (`hd-01-main-menu`)
| Difference | Cause | Fix |
| --- | --- | --- |
| Opaque key-art backdrop instead of the 3D lobby behind a drifting camera | — | Section 8 pass: the menu backdrop turns translucent over the lobby menu shot (`UiEffects.setMenuShot` already drifts the camera) |
| Logo drawn in live text | T | `logo_1v1card` image (section 4.4) on the launch, leaving and menu screens |
| Left labelled menu rows | H, P | Section 8 pass (menu rows with icon plates) |

## Egg Shop (`hd-02`, `ui-refs-2/01`)
| Difference | Cause | Fix |
| --- | --- | --- |
| Eggs in flat tiles; no tier pedestals or tier label pills | P, B | Section 7.2: eggs on tier pedestals in a scrollable row with label and price pills, bob and glow |
| "Drops X up to Y" in body text | H | Section 7.2: details panel with the real top rarity, x1 / x3 / x8 gold buttons, Odds |

## Inventory + inspect (`hd-03`)
| Difference | Cause | Fix |
| --- | --- | --- |
| Stats as small plain text | H, P | Section 6.4: Card Stats panel (board 05) with icons, big ATK / DEF, real merge bar |
| Rarity filter labels squeezed ("Com m") | H | Section 8: filter chips from `filter_chip_<rarity>` with short badge labels |

## Deck Builder + Families (`hd-04`)
| Difference | Cause | Fix |
| --- | --- | --- |
| Empty slots as plain text | P | Dashed `empty_slot` with "+" (done) |
| Deck Power without count-up arrow | M | Section 8 |
| Families panel flat | F | Section 8 (glowing active rows) |

## Arena (`hd-05`), Victory (`hd-06`), Worlds (`hd-07`)
| Difference | Cause | Fix |
| --- | --- | --- |
| VS badge was a TEMP drawing | T | Final `vs_badge` (fiery gradient, dark stroke) |
| Victory / Defeat banners were TEMP | T | Final winged gold / cold steel banners |
| Worlds strip cards without "Completed" ticks | P | Section 8 |

## Card stats (`ui-refs-2/05`), frames (`04`), template (`06`), animations (`07`), ladder (`08`)
All built in step 5; comparisons in `docs/screens/step5/compare_*.png`.
