---
name: roblox-networking-security
description: Server-authoritative networking and anti-exploit rules for 1v1 CARD - adding a remote, validating payloads, rate limits, what the server must derive itself, and a threat checklist for reviews. Use for any remote, client request or security review.
---

# Networking and security

## The only path in
Client → `RemoteFunction` (created by `Server/Net/Router` from `Shared/Net/Remotes`) →
`Server/Net/Dispatcher.run`, which goes:
1. **rate limit** (per player, per remote: `rate` per second with a `burst` bucket)
2. **parse** (`def.parse(payload)` returns a cleaned table or nil; nil becomes `BadRequest`)
3. **profile loaded** (unless `needsProfile = false`)
4. **handler** (`pcall`; thrown text is logged and the client only ever sees `ServerError`)
5. **mark dirty / save** (`saveNow` for purchases and hatches) → **push delta**

Pushes (server → client): `Profile.Snapshot`, `Profile.Delta`, `Queue.Status`, `Battle.*`,
`Notice`.

## Adding a remote: checklist
- [ ] Entry in `Remotes.Requests`, with `Check.shape` listing the *exact* allowed keys.
- [ ] Every field goes through `Check.id` / `Check.int(min, max)` / `Check.bool` /
      `Check.idList(max)`. Enums must be an explicit whitelist.
- [ ] Mutating money? Require a `requestId` (`Check.id(v, 40)`) and use it in the Wallet ref,
      so retries are idempotent.
- [ ] Rate set for the real need: purchases 4/s, battle picks 4/s, claims 1–2/s.
- [ ] The handler takes *nothing* authoritative from the payload. The server derives positions
      (`WorldService.positionOf`), prices (Config), ownership (profile), time and the userId.
- [ ] The spec covers the parse rejects (wrong types, extra keys, out of range).

## What the client may never decide
Balances, rolls, damage, results, ownership, deck validity, unlocks, odds, trophy changes, quest
progress, distances, cooldowns, or whether it's eligible for Robux eggs. The client only hides the
Robux button when the `PaidRandomItemsAllowed` attribute is false; the server re-checks on every
offer and every receipt.

## Threat checklist (use it for reviews)
- **Replay:** the same requestId, matchId or PurchaseId twice → `recentTx`, `settledMatches` and
  `processedReceipts` stop it.
- **Race:** two requests changing the same profile. Validate first, then apply changes that can't
  fail.
- **Teleport data:** never trusted. Battle servers read `ps:{PrivateServerId}` from MemoryStore.
- **Spoofed position or range:** the server uses its own character position.
  `Farming.harvest` and `nearMerchant` check range.
- **Battle:** picks are accepted once, for the current round, before the deadline, and only from
  the match's own players (`MatchHost`).
- **Policy:** `ArePaidRandomItemsRestricted` and `IsPaidItemTradingAllowed` are separate and fail
  closed (`PolicyRules`, `PolicyGate`).
- **Gambling:** no stakes, no pots between players, no paid randomness without exact odds shown
  first.
- **Information leaks:** `ClientView` never sends provenance details, receipts, the ledger or
  other players' private data.
