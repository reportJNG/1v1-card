---
name: roblox-data-persistence
description: Profiles, session locks, migrations, Robux receipts and idempotent settlement in 1v1 CARD. Use whenever a change touches PlayerProfile fields, DataStores, MemoryStore records, receipts or anything that pays out.
---

# Data and persistence

## Profile lifecycle
- `Server/Persistence/SessionStore`: session-locked records using only `UpdateAsync`, with
  retries and write verification. It refuses data from a newer schema version.
- `ProfileManager`: load on join, autosave *every* session (dirty or not) so the lock heartbeat
  never goes stale, retry failed releases, and flush everything on `BindToClose`.
- `PlayerDataService.retainWhile(fn)`: keeps a leaving player's profile while they're in a live
  match, so the result can still settle. Release it afterwards with `releaseIfAbsent`.
- The in-memory DataStore is a Studio-only fallback. A live server never falls back.

## Changing the profile shape
1. Bump `ProfileSchema.CURRENT_VERSION`. Append a migration `[n] = function(data) ... end`;
   never edit a shipped one.
2. Add the default in `ProfileSchema.new` and the field in `Types.PlayerProfile`.
3. Extend `ProfileSchema.validate` if invalid data could corrupt rules.
4. Add a spec: an old profile migrates, a new profile is valid, and a newer version is refused.
5. If the client needs the field, add it to `ClientView` (`SCALARS` or `TABLES`). Never send
   secrets.

## Payouts are idempotent
| Payout | Key | Where |
| --- | --- | --- |
| Robux receipt | PurchaseId → `processedReceipts` | `ReceiptProcessor` (grant → record → save → `PurchaseGranted`) |
| Ranked match | matchId → `settledMatches` (bounded, 300) | `Domain/Settlement` |
| Wallet change | unique ref → `recentTx` | `Domain/Wallet` |
| Trial first clear | `trials[worldId]` | `Domain/Trials` |
| Quests / streak | `quests[id].claimed` / `daily.lastClaimDay` | `Domain/Quests`, `Domain/Streak` |

An ineligible receipt is never granted. It is logged in `heldReceipts` and left
`NotProcessedYet`.

## Provenance is permanent
A copy's `origin` never changes. Merging adds the spare's origins, `paidRefs` and `paidLineage`
to the target. `validate` rejects a Robux copy without paid lineage.

## MemoryStore (matchmaking)
Sorted maps: `RankedQueue_v1`, `Matches_v1` (`match:{id}`, `ps:{privateServerId}`,
`active:{userId}`) and `MatchmakerLease_v1`. There are no multi-key transactions: stamp each key
with `UpdateAsync` and revert on partial failure. Wrap every call in `pcall`.
