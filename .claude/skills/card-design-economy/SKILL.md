---
name: card-design-economy
description: Designing characters, rarities, odds and economy numbers for 1v1 CARD - the roster rules, the balance gate (sim/balance.py), egg pools and odds bands, merge/level costs, rewards and Roblox monetization limits. Use when adding characters, changing stats, odds, prices or rewards.
---

# Cards and economy

## Card model (locked)
- Five rarities: Common, Rare, Epic, Legendary, Mythical. Families (15) are separate from
  rarity. Two of a family give +2% to its bonus stat, and three give +3%.
- Each hatch is a card **copy**. Spare level-1, never-merged copies merge into a target. There
  are no Fragments. Max level is 15 for all rarities, at +0.75% stats per level. Ranked league
  caps are 4 / 8 / 12 / 15.
- Battle: Attack / Defend / Special. Defend parries a Special (80% block, +1 energy to the
  defender, −1 to the attacker, 0.5× counter). Energy comes only from actions, max 5. Picks have a
  12 s timer. Initiative is capped at 20–80%.

## Adding a character
1. Append it to `Config/Characters`. The id is permanent and never reused. Use an original name
   and design, with no anime IP or likeness.
2. Choose its family, rarity, role, Special (cost 2–4, a `kind` from the validator) and passive
   (`PassiveEffect` kinds only).
3. Regenerate and gate it (see `roblox-testing`): `sim/content.json` → `parity.py` →
   `ai_parity.py` → `balance.py`. Every target in `sim/balance.py` must hold, with no character's
   win rate outside its band.
4. Add it to egg pools. Real pools have 6–10 characters per egg; Dog leans Beast and Cat leans
   Ninja.
5. The catalog is capped at 100 (`Characters.MaxCatalogSize`) until that's reviewed.

## Odds
- There is one source: `Shared/Domain/Odds`, from `Config/OddsBands` (A–E plus Event), with an
  equal share within a rarity. The display and the roll use the same table.
- Golden is the same egg with Common removed and its share redistributed. Golden eggs are earned
  only, never sold.
- No pity, no luck boosts, nothing that changes odds for money.

## Currencies and Robux (locked)
- Coins are earned and never sold. Gems are earned and buy cosmetics only, never anything random.
- Robux buys eggs from **unlocked** worlds (paid random items, with exact odds shown) and
  fixed-price cosmetics. It never buys Coins, Gems, boosts, levels, trophies or odds.
- Matches have no wagers or entry fees. Winners get a game-paid purse (`Economy.Matches`), daily
  caps apply, and low-quality matches pay nothing.

## Numbers
Every price, cap, reward and timer lives in `Config/Economy` (or `Quests`, `Items`,
`WorldLayouts`). Starting values stay marked in `ContentStatus` until an economy simulation or
playtest replaces them. When you change a number, update the spec that pins it and write down why
in `docs/CONVERSATION.md`.
