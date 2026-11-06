# Handoff: where work stopped (2026-11-06)

Open this folder in Claude Code (`claude` in this directory). `CLAUDE.md` loads automatically;
read this file and `STATUS.md` first. The full plan is the design doc
(https://claude.ai/artifact/Bdc9fe3tjh3ybZnVVBVMfg), section 8 "Roadmap".

## Done since the Stage 1 commit
- **M1 economy core**
  - `Shared/Net/Remotes` lists every remote; `Shared/Net/Check` validates payloads.
  - `Server/Net/Dispatcher`: rate limit → validate → profile → handler → save → push.
  - `Server/Net/Router` creates the remotes.
  - `Services/NetService`, `EconomyService` (buy/open eggs, daily free egg, merge, sell spares, deck, storage), `Telemetry`.
  - `Shared/Domain/ClientView`: profile snapshot plus deltas, with nothing secret sent.
  - `Cards.sellSpares`.
  - Tests: `M1Acceptance.spec` (10,000 purchases chi-square, 50 forced crashes, receipt ×100), `Net.spec`.
- **M3 battle engine**
  - `Shared/Battle/BattleRules` and `Prng`, ported from `sim/engine.py`. `Config/Battle` holds the rules.
  - Passives are data (`passive.effect`).
  - `BattleParity.spec`: 1,000 seeded matches identical to Python.
  - Tuning pass applied: guardVsAttack 0.35; Vesper 1.33, Taren 2.09, Rai 1.5. `python3 sim/balance.py`: all design targets met.
- **Profile schema v2** (migration 1→2): currentWorld, opponentsToday, questDay, trials, stats, settings. New players start with 500 Coins.
- `Economy.Matches` (game-paid purse, no stakes) and `Economy.Trials` config.

## Regenerate after changing characters or battle rules
```
python3 scripts/headless/bundle.py --entry=ServerScriptService/Tests/Tools/ExportContent
luau build/entry.luau > sim/content.json
python3 sim/parity.py && python3 sim/ai_parity.py && python3 sim/balance.py && python3 sim/trials.py
python3 scripts/headless/bundle.py && luau build/headless.luau
```

## Next, in order
1. `Shared/Domain/Settlement`: trophies ±, purse, daily cap, low-quality rules, `settledMatches` idempotency. Add tests.
2. `Server/Battle/MatchRunner`: picks, 12 s timers, timeouts → Attack, 3 timeouts → forfeit, KO replacement (5 s, default `BattleRules.defaultNext`). Add tests.
3. `BattleService`: local 1v1 plus Guardian Trials (PvE; the AI policy is the "adaptive" reader in `sim/balance.py`).
4. M4: MemoryStore queue and lease, pairing (pure, tested), ReserveServer and teleport, match record, reconnect window, league level caps.
5. M6: worlds 1-10 config and blockout builder, farming nodes, merchants, quests, daily streak.
6. M5: client UI (shop with Odds, hatch, collection, deck builder, battle screen). Hide the Robux button when the `PaidRandomItemsAllowed` attribute is false.
7. 100-character roster (balance gate: `sim/balance.py`) and real egg pools.
8. Verify in Studio: tests, the Player Emulator with all 4 combinations (`[PolicySelfCheck]` lines), and save Place1.

## Decisions made while you were away
- No player-staked wagers: Roblox bans simulated gambling, and "no wagers" was a locked decision. Winners get a game-paid purse instead.
