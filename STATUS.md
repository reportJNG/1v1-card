# 1v1 CARD: status at the end of Stage 1

## Implemented (real logic, tested)

| System | Where | Tests |
| --- | --- | --- |
| Odds: per-character %, Golden redistribution, roll from the same table, display rows | `Shared/Domain/Odds` | Odds.spec |
| Wallet: Coins/Gems with caps, unique refs, bounded ledger | `Shared/Domain/Wallet` | Wallet.spec |
| Hatching: Coin eggs, Robux grants (idempotent by PurchaseId), Egg Bag, daily free egg | `Shared/Domain/Hatch` | Hatch.spec |
| Cards: copies, permanent provenance, V1 merge (level-1 / 0-point / never-merged copies only), levels 1-15, storage expansion | `Shared/Domain/Cards` | Cards.spec |
| Item inventory 5 → 30 | `Shared/Domain/Inventory` | Inventory.spec |
| 3-card decks | `Shared/Domain/Deck` | Deck.spec |
| Profile schema, validation, append-only migrations | `Shared/Domain/ProfileSchema` | ProfileSchema.spec |
| Policy rules: purchase and trading eligibility kept separate, fail closed | `Shared/Domain/PolicyRules` | PolicyRules.spec, PolicyMatrix.spec |
| Config validation (dev warns, release refuses placeholders and missing launch data) | `Shared/Domain/ConfigValidator` | ConfigValidator.spec |
| Session-locked DataStore records, retries, write verification | `Server/Persistence/SessionStore` | SessionStore.spec |
| Session lifecycle: load, heartbeat autosave, release retry, shutdown flush | `Server/Persistence/ProfileManager` | ProfileManager.spec |
| Receipt rules: save before Granted, idempotent, re-checks policy and world lock, holds ineligible receipts | `Server/Purchases/ReceiptProcessor` | ReceiptProcessor.spec, PolicyMatrix.spec |
| Roblox wiring: PolicyGate, PlayerDataService, PurchaseService, PolicySelfCheck (Studio) | `Server/Services` | Studio play test (unit-tested logic underneath) |

## Placeholder (exists so systems run; not final design data)

Marked in code: `status = "Placeholder"` on every egg, and `Config/ContentStatus`.
`ConfigValidator` warns about each in development and refuses to start a release server.

| Content | Placeholder because |
| --- | --- |
| Egg character pools | All 24 eggs share the 7 launch characters until the 100-character roster and egg-specific pools exist |
| Odds bands A-E | Design-doc proposals, not balanced |
| Party Egg (event) odds | Stand-in Event band until event design |
| Egg Coin prices | Starting values pending the economy simulation |
| Storage, item-slot and merge prices | Starting values |
| Character stats and abilities | From the reference simulation; need playtest tuning |
| Items | Only 3 World 1 items |
| Egg icon asset ids, character models | Not uploaded yet (launch gap) |
| Developer Product ids | Empty until products are created on the Creator Dashboard (launch gap) |

## Designed but not built (by decision)

- V2 player store: `Config/Market` (`enabled = false`) and the card-copy data shape only.
  The server-side trading check (`PolicyGate.canTradeCopy`) exists; there are no trading operations.
- Battle, matchmaking, UI, quests, Guardian Trials: later milestones.

## Verification

| Check | Result |
| --- | --- |
| StyLua `--check` | clean |
| Selene | 0 errors, 0 warnings (offline Roblox std) |
| luau-lsp strict | 0 errors |
| Rojo build (default + dev) | both build |
| TestEZ, headless (`scripts/headless`) | 135 passed, 0 failed |
| TestEZ in Studio | last run 88/88 before the verification pass; the current 135 not yet run in Studio |
| Player Emulator, 4 policy combinations | **not yet tested**: see README "Testing PolicyService combinations" |
