# The full story so far (read this before doing anything)

This project was started in a Claude web session (claude.ai/code, 6 Nov 2026) with the owner,
hamzaremali10. That chat can't be resumed from the CLI, so this file carries everything you need
from it: what the owner asked for, what they decided, what was built, and what is left. The
owner's own brief files are in `docs/brief/` (verbatim), and the agreed design is in
`docs/DESIGN.md`.

The owner writes quickly and informally, often with typos. Read for intent. They want the game
built end to end with as few questions as possible: "dont stop or ask".

---

## 1. What the owner asked for, in order

1. **Kick-off.** They connected Roblox Studio (place "Place1") and pointed at their egg art in
   `C:\Users\Administrator\Downloads\Eggs Icon Pack v2 (Basic)` (24 eggs: Angel, AngelDemon,
   Basic, Black Hole, Cat, Coconut, Cracked, Demon, Dog, Dominus, Dragon, Glitched, Ice, Kraken,
   Legendary, Mine, Mythical, Party, Rainbow, Royal, Sandcastle, Secret, Spotted, Yeti; normal +
   golden PNGs; see its License.txt: **the egg art must not be edited or redistributed**).
   They asked me to "think about the full game", use all the eggs, and ask what I'd need to make
   it perfect, like the concept board.
   - `docs/brief/concept-board.png` is their concept board. It shows the target **layout and
     mood**: dark purple/neon anime style, a left menu (Play, Inventory, Deck, Shop, Trade,
     Quests, Settings), Coins and Gems top bar, an Egg Shop grid with a featured egg and a Buy
     button, Inventory grid, a card inspect panel, Deck Builder with deck power and family bonus,
     a Families list, a 1v1 Arena panel, a Victory screen, and a Worlds strip with 10 worlds.
     **It uses copyrighted anime characters (Gojo, Naruto, Itachi, Luffy, Akatsuki cloak) and a
     "Bet Amount" panel. Neither goes in the game.** Characters are original. There are no bets
     (Roblox policy, see section 3).
   - They also shared `onevone_card_roblox_ui_kit` (UI starter kit with egg SVGs, rarity card
     frames, a browser prototype and `DESIGN_SYSTEM.md` → `docs/brief/05-ui-design-system.md`).
     Use its design system (colours, type, spacing) for all UI.
2. **Their decisions document** (`docs/brief/02-your-decisions.md`): turn-based tactical 1v1
   with 3 cards each, original 3D anime-inspired characters, 5 rarities with families separate,
   Golden as a variant, Coins + Gems, cross-server matchmaking with no bots, 10 worlds, mobile
   first, server authority. Key lines: "Do not start building the full game before we agree on
   these foundations." and "challenge bad ideas … Do not invent completed assets, pretend a
   prototype is production-ready or implement temporary logic that we will have to rewrite."
3. **Setup document** (`docs/brief/03-claude-senior-roblox-setup.md`): toolchain (Rojo, StyLua,
   Selene, luau-lsp, TestEZ, GitHub), plugins, Blender MCP, a draft CLAUDE.md (which still had
   wagers, 40 eggs and 100 characters; superseded by the decisions below).
4. I wrote the **design doc** (now `docs/DESIGN.md`, also a Claude Doc artifact:
   https://claude.ai/artifact/Bdc9fe3tjh3ybZnVVBVMfg). It includes battle rules tested in 150k+
   simulated matches, the economy, 24 eggs over 10 worlds, the architecture, the policy risks
   and the roadmap M0-M7.
5. **Answers to my open questions:**
   - Q1 Guardian Trials: yes.
   - Q2 max level: 15 for all rarities.
   - Q3 counter-loop rules: yes.
   - Q4 Robux: "they can buy eggs and buy card on online shop with robux". Settled as
     **Robux buys eggs (paid random items) and cosmetics only**.
   - Q11/Q12: "full store online in game player can sell a card there". Settled as a **V2 player
     store, priced in Coins, 10% configurable fee, 1 active listing; save format designed now**.
   - Card model: **copies + merge** (replaces fragments).
6. **"Go ahead and start Stage 1"** with 7 requirements:
   1. permanent Robux provenance on every card copy
   2. trading eligibility separate from purchase eligibility
   3. test all PolicyService combinations in the Player Emulator
   4. configurable storage and prices
   5. data-driven eggs
   6. 7 characters expandable to 100
   7. automated tests for save/load, hatching, merging, inventory, decks and currency

   Also: Robux eggs only from unlocked worlds, odds disclosure, earned eggs as the alternative
   for restricted players. "Don't rush into building the entire game."
7. **Verification pass before closing Stage 1:**
   - V1 merge rule: only level-1 duplicate copies can be consumed. Upgraded cards are never merge
     material.
   - The 4-combination policy matrix is enforced server-side for every operation, and the client
     is never trusted.
   - Persistence tests: two servers, lock expiry, crash during save, retries, duplicate
     receipts, delivery after reconnect, shutdown with unsaved changes.
   - Mark placeholder content clearly. Confirm 23 world eggs + Party as the event egg.
   - Deliver the folder, ZIP, git hash, full test output, check results, README, the
     implemented-vs-placeholder list, and Place1 save instructions.
   - "Do not claim Player Emulator policy testing is complete until all four combinations have
     actually been tested."
8. **"apply full all stages verify when u finish everything dont stop or ask"**, then an
   "overnight autonomous mission" text that adds:
   - Vision: 100 anime-inspired characters, 3-card decks, 1v1 PvP with 3D animated combat,
     stronger decks usually win but mechanics matter, currency from duels and farming worlds,
     farming items to sell, **players start with 500 Coins**, and "players wager in-game currency,
     winners collect the pot".
   - Work loop: audit → fix → test → improve. Do not fake implementations, do not claim
     unverified work, do not publish or spend Robux, and finish with a full report.
9. They stopped the web session to continue here in the CLI.

## 2. Locked decisions (also in CLAUDE.md, do not reopen without the owner)

| Topic | Decision |
| --- | --- |
| Battle | Counter loop (Attack / Defend / Special), 3 cards, simultaneous picks |
| Rarity | 5: Common, Rare, Epic, Legendary, Mythical |
| Levels | Max 15 for all rarities, +0.75% per level; ranked league caps 4/8/12/15 |
| Cards | Copies + merge; V1 merges only level-1, never-merged copies |
| Storage | Card storage 300 → 1000; item inventory 5 → 30 slots |
| Golden eggs | Earned only, never sold |
| Coins | Never sold for Robux |
| Gems | Cosmetics only |
| Robux | Eggs from unlocked worlds only (paid random items) + cosmetics |
| Matches | **No wagers.** Winners get a game-paid purse (see below) |
| Guardian Trials | Yes, one PvE trial per world |
| Matchmaking | Cross-server, no bots |
| Player store | V2 only: Coins, 10% fee, 1 listing; data shape exists now |
| Starting Coins | 500 (added from the overnight brief) |

**Why no wagers, though the overnight brief mentions them.** Roblox bans simulated gambling
(since Sept 2023). Staking currency on a match between players is a reportable risk, and the
owner had already locked "no wagers" when they approved the design. So the owner's "winners collect
the pot" is built as a **purse the game pays** (`Economy.Matches.purseByLeague`): winners collect
it, nobody stakes or loses Coins. If the owner insists on real stakes, stop and explain the
policy risk before building anything.

## 3. Roblox policy rules that shape the code

- Robux eggs are **paid random items**: show the exact % for every outcome (behind a button
  labelled "Odds") before purchase. The roll and the display use one function (`Odds`). No pity
  and no luck boosts.
- PolicyService: `ArePaidRandomItemsRestricted` (purchase) and `IsPaidItemTradingAllowed`
  (trading) are separate and fail closed. Restricted players never see the Robux egg button, and
  the same eggs stay buyable with Coins.
- Receipts: grant → record PurchaseId → save, then `PurchaseGranted`. Ineligible receipts are held
  (`NotProcessedYet`, logged in `heldReceipts`), never granted.
- Original characters only. Never use anime IP, names or likenesses.

## 4. What exists now (commit history in git)

- **Stage 1 / M0** (commit 1c7b817): the tooling, typed config (24 eggs, 7 characters, economy),
  domain logic (odds, wallet, hatch, cards, inventory, deck, profile schema, policy rules), the
  session-locked persistence (SessionStore, ProfileManager), ReceiptProcessor, PolicyGate,
  PurchaseService, PlayerDataService and the Studio-only PolicySelfCheck. 135 tests.
- **Since then** (commit 7510b15): the M1 net layer and EconomyService, the M1 acceptance tests,
  the M3 battle engine (Luau, identical to `sim/engine.py` on 1,000 seeds), a balance tuning pass,
  profile schema v2 and 500 starting Coins. 154 tests passing (headless). Details are in
  `HANDOFF.md`.
- Everything checks clean (StyLua, Selene, strict luau-lsp, Rojo).
- **Not yet done in Studio:** syncing the latest code, running the tests in Studio, the Player
  Emulator 4-combination test (`[PolicySelfCheck]` lines must all say MATCH) and saving Place1.

## 5. What is left (do these in order; `HANDOFF.md` has file-level detail)

1. Settlement: trophies, purse, daily cap, low-quality rules, idempotent by matchId.
2. MatchRunner + BattleService: timers, timeouts, KO replacement, local 1v1 and Guardian
   Trials (PvE AI).
3. M4 matchmaking: MemoryStore queue + lease, pairing, ReserveServer/teleport, reconnect,
   league caps.
4. M6 worlds 1-10: resources, farming nodes, merchants, quests, daily streak.
5. M5 client UI from the design system: shop with Odds, hatch animation, collection, deck
   builder, battle screen, worlds, settings. Mobile first.
6. M2 art: one character to final quality. Needs an artist or Blender. Don't fake it; mark
   placeholders.
7. 100-character roster (original names; each must pass `python3 sim/balance.py`) and real egg
   pools (6-10 characters each).
8. M7 prep: telemetry, a security review and the maturity questionnaire (owner's job).
9. Verify everything in Studio, save Place1, commit and report what was and wasn't verified.

## 6. Working with this machine

- Roblox Studio is reachable through the Roblox Studio MCP (`Place1`). Sync with Rojo:
  `rojo serve dev.project.json` and the Rojo plugin.
- Headless tests: `python scripts/headless/bundle.py` then `luau build/headless.luau`.
- Battle rules or characters changed? See "Regenerate" in `HANDOFF.md`.
- Commit messages end with:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

---

## Decisions made in the CLI

Made by Claude while working autonomously on "finish every stage in HANDOFF.md and verify it"
(from 2026-11-06). Each one can be reopened by the owner.

### Tooling on this machine
- The machine had no Python, Luau, Rojo, StyLua, Selene or luau-lsp on PATH. Rather than install
  anything system-wide, I downloaded the versions pinned in `rokit.toml` (plus the Luau CLI, the
  embeddable Python 3.13 and TestEZ into `DevPackages/`, which is git-ignored) into the session's
  temp folder. To reproduce: `rokit install`, install Python 3, and follow the README.

### Settlement (`Shared/Domain/Settlement`)
- **Void rules.** A voided *win* earns no Coins and no trophies. A voided *loss* still costs trophies,
  so quitting early is never free. The exception is the repeat-opponent rule: past 3 matches a day
  between the same two players, nothing moves for either side, which stops win-trading.
- **Loss Coins.** These are the `lossCoinsByLeague` consolation. Once a player has 10 paid wins that
  day, they also drop to the reduced rate, so loss farming isn't a loophole.
- **League.** The purse is paid for the league the player was in when the match was played.
- **Coin cap.** If the wallet is at its cap, the purse is skipped but the match still settles. A
  settlement must never get stuck retrying.
- **Bounded memory.** `settledMatches` keeps the last `Economy.Matches.settledMemory` (300) matchIds.
  The authoritative match record lives in the battle server for far less time than 300 matches
  take, so a replay can't come in after its id has been dropped.

### Battles (`Server/Battle`, `BattleService`)
- `MatchRunner` is a pure state machine (Picking → Choosing → Ended) with the clock injected.
  `MatchHost` runs all of a server's matches, and `BattleService` wires them to remotes. Both are
  tested with mocks.
- **Both players time out together.** If both reach 3 timeouts in the same round, the side with
  more HP share wins, and the match is voided for pay (Timeouts rule).
- **Disconnects.** When a player drops mid-match, their profile session stays loaded on this
  server (`PlayerDataService.retainWhile`). The result can then be settled even if they never
  return, and a rejoin within 30 s finds the same profile and seat. The profile is released after
  settlement.
- **Guardian Trials.**
  - The Guardian plays the "adaptive" reader from `sim/balance.py`, ported to `BattleAI` and
    checked against Python on 300 seeded matches.
  - The player fights with real card levels (no league cap in PvE).
  - Repeat clears pay nothing. Retries wait 30 s (`Economy.Trials.retryCooldown`).
  - Guardian names are original.
  - The decks use launch characters and are marked Placeholder (`guardianDecks`).
- **Clock.** Battles use `workspace:GetServerTimeNow()`, so clients can count down to the same
  deadline.

### Studio verification without the Studio MCP
- The roblox-mcp-pro server wasn't installed or connected in this CLI session; the plugin's
  bridge on 127.0.0.1:3690 had no listener. Instead I use `run-in-roblox` 0.3.0, which opens real
  Roblox Studio on a Rojo-built `build/dev.rbxlx` and runs a script. Two scripts:
  - `scripts/studio/run-tests.server.luau` runs the whole TestEZ suite inside Studio.
  - `scripts/studio/boot-check.server.luau` starts Run mode, so the real server Script boots,
    then checks the services and remotes and that the log has no errors.
- Run mode has no client and no Player Emulator. Client UI play-tests and the four
  PolicyService combinations still need someone at Studio (see README).
