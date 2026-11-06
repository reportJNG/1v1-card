---
name: roblox-architecture
description: Where code belongs in 1v1 CARD and how to add a system (config, pure domain, server service, remote, client screen). Use when planning any new feature or moving code.
---

# Architecture: 1v1 CARD

## Layers (Rojo: `default.project.json`, `dev.project.json`)
- `src/shared` → `ReplicatedStorage.Shared`
  - `Config/`: all content and tunables, as data only. No other file hard-codes ids, prices or odds.
  - `Domain/`: pure functions over a profile. No Instances, no yields, RNG and clock injected.
    They return `Result<T>` (`Shared/Domain/Result`) and `assert` only on programmer errors.
  - `Battle/`: `BattleRules` and `Prng`, kept identical to `sim/engine.py`.
  - `Net/`: `Remotes` (every remote, with its rate limit and payload parser) and `Check`
    (validators).
- `src/server` → `ServerScriptService.Server`
  - `Services/`: Roblox wiring only. Each has `init()` and optionally `start()`, and is listed in
    `ORDER` in `init.server.luau`.
  - `Net/`: `Dispatcher` (rate limit → parse → profile → handler → save → push) and `Router`.
  - `Persistence/`: `SessionStore` and `ProfileManager`.
  - `Purchases/`: `ReceiptProcessor`.
  - `Battle/`: `MatchRunner`, `MatchHost` and `BattleAI`, pure state machines with the clock
    injected.
  - `Matchmaking/`: `Pairing`, `Lease`, `Queue`, `MatchRecord`, `Matchmaker`, and `InMemoryMap`
    (a Studio-only fallback and the test mock).
  - `World/`: `WorldBuilder`, built from `Config/WorldLayouts` + `Domain/WorldLayout`.
- `src/client` → `StarterPlayerScripts.Client`
  - `App/`: Theme, Ui, State, Signal, Format, Visuals, App.
  - `App/Screens/*`: each screen is built from an injected `Ctx`, so a Studio script can render it
    with fake data.
- `tests` → `ServerScriptService.Tests` (dev only): TestEZ specs, `Mocks/` and `Fixtures/`.

## Adding a feature: the order
1. Config: data plus a `ConfigValidator` rule and a `ContentStatus` entry if it's placeholder.
2. Domain: pure logic plus a spec. Validate everything first, then apply changes that can't fail.
3. Remote: an entry in `Shared/Net/Remotes` with a strict `parse` and a rate (see
   `roblox-networking-security`).
4. Service: `Router.handle(name, fn, options)` in `init()`, then add the service to `ORDER`.
   Positions, time and identity come from the server, never from the payload.
5. Client: a screen or controller that only sends intents and renders pushes.
6. Docs: update `STATUS.md` and `HANDOFF.md`, and record decisions in `docs/CONVERSATION.md`.

## Rules that are easy to break
- Every currency change goes through `Wallet.apply`, with a unique ref and a ledger entry.
- Anything that moves a card between players calls `PolicyGate.canTradeCopy`. That's V2 only.
- Card uids are `<ownerUserId>-<serial>` and are never reused. A copy's `origin` never changes.
- Battle servers are reserved servers of the same place (`game.PrivateServerId ~= ""` and
  `PrivateServerOwnerId == 0`). They build no worlds.
- Live servers never fall back to in-memory stores. Only Studio does, with a warning.
