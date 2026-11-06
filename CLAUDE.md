# 1v1 CARD — Project Rules

Read this before changing anything. It replaces the earlier setup-file constitution, which had
wagers, 40 eggs and V1 trading. Those were overruled.

The full design lives in the design doc "1v1 CARD — Game Design & Technical Foundation"
(https://claude.ai/artifact/Bdc9fe3tjh3ybZnVVBVMfg). If this file and the doc disagree, stop and ask.

## What the game is

An original, anime-inspired collectible card battler on Roblox.
- **Battles:** players hatch eggs for character cards, build 3-card decks, and fight a
  turn-based 1v1 (simultaneous picks).
- **Progression:** they earn trophies to unlock 10 worlds, and farm and sell items to NPCs.
- **No copied IP:** no Gojo, Naruto, Luffy, Itachi or Akatsuki-style designs.

## Locked decisions (do not change without the owner)

| Area | Decision |
| --- | --- |
| Battle | Attack / Defend / Special counter loop. Defend parries a Special (80% block, +1 energy to the defender, −1 to the attacker, 0.5× counter-hit). Energy comes only from actions, max 5. 12 s picks. Probabilistic initiative, capped at 20–80% |
| Rarity | Common, Rare, Epic, Legendary, Mythical. Families are separate from rarities |
| Levels | Max level 15 for every rarity, +0.75% stats per level. Ranked league caps are 4 / 8 / 12 / 15 |
| Cards | Each hatch is a card **copy**. Spare copies merge into a card to level it. No Fragments |
| Storage | Card storage starts at 300 and expands to 1,000. Item inventory starts at 5 slots and expands to 30. All values are configurable |
| Eggs | All 24 icon-pack eggs, data-driven. Golden is the same egg with Common removed. Golden eggs are earned only, never sold |
| Currencies | Coins (earned, never sold) and Gems (earned; cosmetics only, never anything random) |
| Robux | Buys eggs from **unlocked worlds** (paid random items) and fixed-price cosmetics. Never buys Coins, Gems, boosts, levels, trophies or odds |
| Matches | No wagers or entry fees. Fixed rewards, daily caps, trophies |
| Worlds | 10 worlds unlocked by highest trophies, plus a one-time Guardian Trial trophy grant per world |
| Player store | V2 only. Coins, 10% fee, one active listing. **Not built in V1**; only the data shape exists |

## Non-negotiables

1. **The server is authoritative.** The client sends intents. Balances, rolls, damage, results,
   ownership, deck validity and unlocks are decided on the server. Never trust a client value.
2. **One source of odds.** `Shared/Domain/Odds` feeds both the roll and the odds display. Exact %
   per character is shown before every Coin or Robux egg purchase, behind a labelled "Odds" button.
3. **Two separate policy eligibilities** (`Shared/Domain/PolicyRules`, `Server/Services/PolicyGate`):
   - `ArePaidRandomItemsRestricted` decides whether a player may be offered Robux eggs.
   - `IsPaidItemTradingAllowed` decides whether a player may trade paid items (V2).
   - Both fail closed. Restricted players keep the Coin path to the same eggs.
4. **Provenance is permanent.**
   - A copy's `origin` never changes.
   - Merging adds the spare's origins, `paidRefs` and `paidLineage` to the target.
   - `ProfileSchema.validate` rejects a Robux copy without paid lineage.
5. **Robux receipts are idempotent and re-checked** (`Server/Purchases/ReceiptProcessor`):
   - Grant, record the PurchaseId in `processedReceipts` and save, all before returning
     `PurchaseGranted`. A replayed receipt grants nothing; it is acknowledged after a save.
   - Eligibility (policy known and unrestricted, Robux egg, world unlocked) is checked again at
     delivery, because a client can open a purchase prompt by itself. An ineligible receipt is
     never granted: it is logged in `heldReceipts` and left `NotProcessedYet`.
   - Anything that will ever move a card between players must call `PolicyGate.canTradeCopy`.
6. **Every currency change goes through `Wallet`**, with a unique ref and a ledger entry.
   Multi-step operations validate everything first, then apply changes that can't fail.
7. **Data safety:**
   - Session-locked profiles (`Server/Persistence/SessionStore`), using `UpdateAsync` only.
   - `ProfileManager` autosaves every session (dirty or not) so the lock heartbeat never goes
     stale, retries failed releases, and flushes everything on `BindToClose`.
   - The in-memory store is a Studio-only fallback. A live server never falls back.
   - Never write an invalid profile, and never load data from a newer schema version.
   - Migrations are append-only.
8. **No temporary logic.** If a feature isn't designed yet, leave it out rather than stub
   behaviour we'll rewrite.

## Code layout

```
src/shared   -> ReplicatedStorage.Shared   types, config (data only), pure domain logic
  Config/    all tunables and content. No other file may hard-code ids, prices or odds
  Domain/    pure functions over a profile: no Instances, no yields, RNG injected
src/server   -> ServerScriptService.Server Script; services, persistence, remotes
src/client   -> StarterPlayerScripts.Client LocalScript; controllers and UI (from M5)
tests        -> ServerScriptService.Tests  (dev.project.json only) TestEZ specs and mocks
scripts/headless                           runs the same TestEZ suite with the Luau CLI
```

- Strict Luau (`--!strict`) everywhere, tabs, StyLua formatting, and no Selene warnings.
- Domain functions return `Result<T>` (`{ ok = true, value }` or `{ ok = false, err }`) and never throw
  on bad player input. They `assert` only on programmer errors.
- New services go in `Server/Services` and are added to `ORDER` in `init.server.luau`
  (`init()`, then `start()`).
- Card uids are `<ownerUserId>-<serial>`, unique across all players and never reused.

## Content rules

- **Adding a character:** append it to `Config/Characters` (the id is permanent) and add it to
  egg pools. The catalog is capped at 100 until that's reviewed.
- **Placeholder content** is marked: `status = "Placeholder"` on eggs and entries in
  `Config/ContentStatus`. The validator warns in development and refuses release builds.
- **Eggs:** exactly the 24 `Eggs.RequiredIds`: 23 world eggs and the Party event egg. Use the icon files exactly as supplied. The pack
  license allows commercial use but forbids editing, so no recolours. Hatch effects are separate
  overlays.
- **Before launch:**
  - Fill in Developer Product ids in `Config/Monetization`.
  - Fill in egg and character asset ids.
  - `ConfigValidator.validate({ release = true })` must pass. Live servers already run release mode.

## Workflow

1. Read the relevant files and the design doc section first.
2. Plan the change, then build it in small, coherent units.
3. Run `stylua src tests`, `selene src tests`, and `luau-lsp analyze` (see README).
4. Run the TestEZ suite in Studio (`dev.project.json`). Add or extend specs for every rule you change.
5. Playtest in Studio. For anything involving policy, use the Player Emulator's policy settings.
6. Report exactly what changed, what was tested and what wasn't.

Never claim something works without running it. Never overwrite work without reading it first.
