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

### Matchmaking (M4: `Server/Matchmaking`, `MatchmakingService`)
- **Pairing.** Same league only, so both decks play under one level cap. The band is
  ±100 → ±400, widening 50 every 10 s. Two players pair when their gap fits the *wider* of their
  two bands (whoever has waited longer decides), and the oldest ticket is served first.
- **No multi-key transactions in MemoryStore.** A claim therefore stamps each ticket with
  `UpdateAsync` and reverts the first if the second fails. Leaving marks the ticket `left` first,
  so the matchmaker can never claim it mid-leave.
- **Order.** The match record is written *before* the tickets are claimed. A claimed pair always has
  a record; a failed claim leaves an orphan record that just expires.
- **Teleport to the battle server.** The leader can't teleport players on other Hub servers. It
  stamps the assignment (matchId + access code) on the tickets, and each Hub polls its own
  players' tickets every 2 s and teleports them. This needs no MessagingService.
- **Battle server.** It finds its record by `game.PrivateServerId` and ignores teleport data. It
  rebuilds both decks from the loaded profiles under the league cap. If a player doesn't arrive
  within 30 s, or a deck is no longer valid, the match is cancelled with no reward and both players
  are sent home.
- **Reconnect.** `active:{userId}` (MemoryStore, 15 min TTL, cleared at settlement) sends a player
  who rejoins the Hub back to their reserved server.
- **Studio.** ReserveServer doesn't exist there, so a pair plays locally on the same server. With an
  unpublished place, MemoryStore falls back to an in-memory map (Studio only, like the DataStore
  fallback). A live server never falls back.

### Worlds (M6)
- **One place, not two.** The design describes separate Hub and Battle places. For V1, battle
  servers are reserved servers of the same place, detected by `PrivateServerId`; they skip
  building worlds. This avoids a second place to publish and keep in sync. Splitting them later
  only changes `MatchmakingService.reserve` / `sendHome`.
- **Layout.** Each world sits 2,000 studs apart on X. It has two common resources (6 and 5 nodes)
  and one rare (2 nodes, 120 s respawn, and also a 3% drop from the common nodes). Node positions
  come from one pure function (`WorldLayout`), used by both the builder and the server range
  check, so they can't disagree.
- **Respawn timers are per player.** Players never compete for nodes. The timers live in server
  memory: a rejoin resets them, which is harmless because the respawns are short. There is no idle
  income.
- **Merchants.** Selling items needs the player within 16 studs of their current world's
  merchant. Any merchant buys any item.
- **Quests.** Each player gets 3 dailies a day, seeded by day and UserId so a rejoin can't
  reroll them. Dailies pay Coins and achievements pay Gems.
  - The Secret Egg's reveal quest is "Harvest 150 resources in the Shadow Dimension".
  - Voided ranked matches don't count toward quests.
- **Streak.** Days 1–6 pay Coins (100–400), day 7 pays 10 Gems and a Golden Basic egg, then it
  restarts. Missing a day restarts at day 1.
- **Item names and prices for worlds 2–10 are new and original.** The items, world art and quest
  rewards are all marked Placeholder.

### Client UI (M5, `src/client/App`)
- **Built in code, from `05-ui-design-system.md` tokens (`Theme`).** The base is a 960×540 design
  space with a UIScale fit to the device, which is mobile first. Every screen gets its dependencies
  injected (state, net, clock, attributes). This lets `scripts/studio/ui-check.server.luau` build
  every screen inside real Studio with a real profile view and real MatchRunner battle states, and
  check for errors and text overflow.
- **Left menu.** Play, Cards, Deck, Shop, Worlds, Quests, Settings. **Trade is not shown**: it's V2
  and not built.
- **Odds** is its own labelled button next to every Coin and Robux buy, fed by `Shared/Domain/Odds`.
- **Robux buttons** appear only while `PaidRandomItemsAllowed` is true, only for eggs of unlocked
  worlds. Until a Developer Product id exists they show "not on sale yet" and are disabled.
- **No art yet.** Eggs show a neutral silhouette labelled "art pending", not an imitation of the
  icon pack, which can't be edited. Character cards show initials in a rarity frame with the rarity
  written out (never colour alone). Both switch to the real assets once their ids are filled in.
- **Coin icon.** The 🪙 emoji doesn't render in Roblox's font (the Studio screenshot showed a box),
  so Coins use 💰.
- **Settings** are saved on the server through a new `Settings.Set` remote, which accepts only the
  three known boolean keys. The settings panel also explains plainly what Robux can and can't buy.

### The 100-character roster and egg pools
- **The roster.** 93 new original characters (`sim/roster.py`) join the 7 launch ones, whose ids
  and order are unchanged.
  - Rarity split is 30 Common, 26 Rare, 20 Epic, 14 Legendary, 10 Mythical, with 6–7 per family.
  - Names were checked against well-known anime and game characters. Examples I avoided: Pyra,
    Ignis, Noctis, Kiba, Vex, Valka, Nala, Sora.
- **Mechanics.** Every Special and passive uses mechanics the engine already has. Each character
  has one tuned number, written to `sim/roster_tuned.json`.
- **Roles follow rarity.** Measured on the model, a Common Support loses even with the biggest
  heal, and a Mythical Bruiser wins even with the weakest Special, because the rarity stat budget
  and role base stats dominate. So low-rarity healers and shielders are Guardians or Bruisers,
  Support is a premium (Legendary/Mythical) role, and high-rarity damage dealers are mostly
  Skirmishers. **Taren's and Vesper's Special multipliers hit the 1.15 floor; their roles are worth
  revisiting with the owner.**
- **The launch seven were re-tuned for the bigger roster**, one number each (marked in
  `Characters.luau`).
- **One battle rule changed.** `guardVsAttack` went from 0.35 to 0.40 (Defend softens a basic
  Attack by 40%), because with the full roster "always Attack" reached 61% against a ≤60% target.
  Both parity fixtures were regenerated; Luau and Python still match exactly.
- **Gate methodology.** `sim/balance.py` now scales the per-character sample with the roster
  (≥75 matches × roster size per worker). With 100 characters, the old fixed sample gave each
  character only ~360 appearances, about ±2.6% noise, so a perfectly balanced roster could fail
  the 45–55% gate by chance.
- **Result.** All targets pass:
  - every character 47.4–52.9%
  - random 4–12%
  - attack-only 59%
  - adaptive 60%
  - match length 15.9
- **Egg pools** (`Config/EggPools.luau`):
  - 8–10 themed characters per egg. Cat leans Ninja and Dog leans Beast, as the design says.
  - Every character is in at least one egg.
  - Pools only hold rarities the egg's band can drop.
  - Pools stay Placeholder until the owner reviews them.
- **Guardians** field three characters from their own world's eggs. In `sim/trials.py`, a random
  same-level deck beats them 36–53% of the time.

### Placeholder art (M2)
- **I can't produce hero-quality character models here, and I don't pretend to.** They need a 3D
  artist (or a dedicated Blender pass with the now-installed Blender MCP) and then the approval
  pipeline in DESIGN.md section 4.
- **What exists, all marked `Placeholder`:**
  - **`Shared/Art/RigBuilder`:** a procedural, R15-style jointed rig for every character. The role
    sets the silhouette and prop, the family the colours, the rarity the neon trim. It has Motor6D
    joints named like R15, so animations can be authored now and real models
    (`CharacterDef.assets.model`) can replace the rigs later.
  - **Figures:** the rigs appear in ViewportFrames in the card inspect, deck slots, arena, hatch
    reveal and battle. The battle plays a lunge on each hit. Long grids keep the 2D portrait, so
    phones don't render dozens of viewports.
  - **`Config/Art` card frames:** one per rarity, differing only in border, gradient and shine, plus
    a gold foil for Golden copies.
- **Verified in real Studio.** All 100 rigs build (1,299 parts, 600 joints), and a gallery
  screenshot confirms the frames and figures render.

### M7 prep: security review, performance, telemetry
- **Security review of every remote.** Findings:
  - **Fixed: farming exploit.** Harvest respawn timers lived in server memory, so hopping servers
    (~15 s) reset them, including the 120 s rare nodes worth up to 550 Coins. The timers are now
    saved on the profile (`harvests`, schema v3, append-only migration 2→3). This supersedes the M6
    note that "a rejoin resets them, which is harmless".
  - **Already safe:** shop, bag, daily egg, merge, card sell (deck, locked and non-spare cards
    refused), storage, deck, merchant (proximity plus ownership), quests, travel, queue, Trials
    (cooldown, world, deck, not in a match or queue), battle picks (seat, round, deadline, once),
    settings (three known keys).
  - Every payload goes through `Shared/Net/Check` (exact keys and types) and the per-remote rate
    limit. Handler errors become "ServerError", with no text leaked.
- **Performance.**
  - Shine tweens run only on large cards.
  - The collection is paged at 60 cards; storage goes up to 1,000.
  - The deck picker shows only the best copy of each character (at most 100 tiles).
  - `Workspace.StreamingEnabled` is on in both projects, so phones only load the world they're in.
- **Telemetry.**
  - Already: hatch, merge, match_end, trial_end, sell_items, quest_claim, streak_claim, travel,
    queue_join, queue_matched.
  - Added: session_start, deck_set, storage_expand, trial_start, battle_forfeit, robux_egg_granted.
  - Counter-only (`Telemetry.increment`, never sent per event, to stay under analytics limits):
    harvests, replayed receipts, held receipts by reason.

### Final verification (Studio MCP session)
- **Studio sync.** This session had the Roblox Studio MCP. The owner's `live.rbxlx` was Rojo-synced
  to `dev.project.json`, and the TestEZ suite ran there: 240/240.
- **End-to-end Play test.** `execute_luau` has its own module cache and can't touch the running
  game's services, so the test lives in Studio-only scripts (`scripts/e2e/`):
  - The scripts were inserted into the place for one Play session and then deleted.
  - A real client drove every remote, with 40/40 steps passing.
  - The only bug found was cosmetic: after a match the battle screen kept the timer and the
    "Pick your action" text. It's fixed.
- **Player Emulator: 1 of 4.** Only the Studio-default policy (unrestricted, trading allowed) ran,
  and it printed `MATCH`. `PlayerEmulatorService` isn't reachable from the MCP context, and its
  mouse and keyboard input only reach the game viewport, so the other three combinations need the
  owner at the Test ribbon.
- **Place1.** The MCP can't save the open place to a file, so `Place1.rbxlx` is a Rojo build of
  `default.project.json`: the shipping tree, without tests. It sits in the repo root and is
  git-ignored like every place file.

### Visual overhaul, session 2 (2026-11-06, owner away: "never stop to wait")
The owner asked for the game to look and feel like `docs/brief/concept-board.png`: a style guide, the
100 art briefs, a UI image list, then a vertical slice (hub, HUD, shop + hatch, battle).
- **Style guide.** `docs/ART_STYLE.md` covers palette, fonts (Luckiest Guy + Builder Sans), UI rules,
  character proportions, lighting, VFX and pipeline. Everything after it follows it.
- **The UI is image-based.** `Ui` skins every panel, button, tab, tile and bar with 9-slice images
  from `Config/UiAssets`. Each slot uses the owner's `final` image once uploaded, else a `temp` one.
  The 65 TEMP images are drawn in code by `scripts/art/make_temp_ui.py` (pure Python, no third-party
  art). That script also writes `art/ui/PROMPTS.md`. `Ui.skinify` is a theme pass that turns
  leftover code-drawn tiles into tile art. Release builds refuse TEMP slots (validator, with a spec).
- **Egg icons are uploaded unedited** (47 files; the pack has no Golden Rainbow) and referenced in
  `Config/Eggs`.
- **The hub is new.** Players now spawn in a hub plaza (World attribute 0), built at runtime from
  `Config/HubLayout` by `Server/World/HubBuilder`. A new `World.Hub` remote returns there from a
  world. Hub props are original meshes from Studio's `generate_mesh`, so no Creator Store models
  were needed. Studio-made instances can't be saved back to the repo, which is why the layout is
  data (mesh + texture ids). Meshes load in the background so server boot never waits on them.
- **Lighting** per area comes from `Config/Lighting`, applied client-side by `App/AreaFx`.
  `Technology = Future` is set in the Rojo project files. The hub sky is drawn by
  `scripts/art/make_sky.py`.
- **Battles have a 3D stage**: `App/BattleStage`, built locally per client, with backdrop props from
  `ReplicatedStorage.StageProps`. It only plays the server's event packets: hit-stop, shake,
  floating damage, family-coloured bursts, Special camera cuts, parry bubbles and a KO fall. The
  camera is bound after the default camera module.
- **Character briefs.** All 100 have a `look` (personality, outfit, 3 colours, weapon, silhouette)
  from `sim/roster_looks.py`, written by `python sim/roster.py looks` (also `art/characters/PROMPTS.md`).
  A web name check renamed 4 display names; ids are unchanged (see `WAITING_ON_YOU.md`).
- **Honest odds copy.** The shop shows "Drops X up to Y (see Odds)". The board's "Get a Legendary or
  better" would read as a guarantee on a paid random item, so it is not used.
- **Audio.** Only Roblox-licensed APMOfficial tracks are used: hub and battle music, the victory
  sting, and the open swipe. Other SFX slots are empty until the owner picks ids.
- **Not done (blocked).**
  - Character models, animations and card renders: they need the owner's images.
  - Blender's generators and libraries are switched off.

### Session 3: lobby, worlds as maps, card upgrade (2026-11-07, owner away: "keep going")
The owner set a new focus, in order: (1) the lobby as the spawn point with a world picker, (2) the
10 worlds as separate themed maps, (3) a brighter layered card system. Rule from the owner: never
use real anime or franchise character images or names (no character datasets), only the original
roster's art.

**Part 1: lobby as the spawn point**
- **Always the lobby.** Characters spawn in the lobby on join and on every respawn (world spawns are
  disabled), return there after every settled battle (`BattleService.onMatchEnd` →
  `WorldService`), and are brought back if they fall below y = -120 (the Celestial and Divine
  islands float).
- **The picker** (`Screens/Worlds`, opened from the lobby's Worlds portal or the menu) shows 10
  world cards: art, name, trophies needed, locked or unlocked from `highestTrophies`, and the
  Guardian Trial status. Locked worlds have no Travel button and the server refuses them anyway
  (`Progress.travel`, checked in Play: `WorldLocked`, `BadRequest` for an unknown id).
- **Guardian Trials start at each world's trial gate**, not from the picker, so the picker has one
  job.
- **Back to the lobby:** each world has a Back to Lobby portal behind its spawn, and the HUD shows a
  "Back to Lobby" button while the player is in a world. Both send `World.Hub`.
- **The client knows its area** from the server's `World` attribute (`State.area`), so the HUD
  button and the picker's "You are here" update when the server moves the character.
- **Bug found in Play:** after a battle the camera stayed on the battle's saved subject (the old
  character), so it didn't follow the character back to the lobby. `BattleStage.destroy` now points
  the camera at the current character. The hub's prompts were also moved to chest height with a
  22-stud range: the Worlds portal prompt hung 16 studs up and was out of reach.

**Part 2: worlds as separate maps**
- **One place, ten maps.** `Workspace.Worlds.World01..World10` are Models (streamable), 2,000
  studs apart and 2,400 from the lobby, each with `Spawn`, `Farm/Nodes`, `Merchant`,
  `GuardianTrial`, `LobbyPortal`, `Decor`, `Bounds` and `Ambience`. A world is built only from its
  own data (`Config/WorldLayouts` entry, `Config/WorldProps`, `Config/Lighting world<n>`, its
  sky and music), so it can move into its own place later.
- **Terrain is generated from data** (`TerrainSpec`): Terrain is one object per place and can't live
  in a world's model. The farm field stays flat at y = 0 so the server's node range checks are
  unchanged; hills ring the edge, with islands for worlds 7 and 10. **Terrain material colours are
  global to the place**, so a material is never given two colours (a spec enforces it); the first
  build had World 6 recolouring World 1's hills.
- **Props are generated meshes**, 62 of them (`Config/WorldProps`, `docs/ASSETS.md`): no Creator
  Store models. Nodes are an invisible prompt part at the exact range-check position with the mesh
  under it, so farming logic didn't change. Scenery placement is a pure, seeded function
  (`WorldLayout.decor`) that keeps clear of nodes, NPCs, the spawn, the portal and the path.
- **Look per world:** a code-drawn skybox (`make_sky.py world`), its own Lighting / Atmosphere /
  Bloom / ColorCorrection / SunRays preset applied on the client when the World attribute changes,
  ambient particles (≤ 18/s) and an APM music track. Presets were tuned from Studio captures (the
  first pass was too foggy in 2, 5, 6 and 9 and blown out in 7 and 10).
- **Picker thumbnails** are Studio captures of the built worlds, marked TEMP until key art exists.

**Part 3: the card visual upgrade**
- **One layered card everywhere** (`App/Card`): collection grid and inspect, deck builder slots and
  picker, hatch reveal, battle plates, the KO replacement picker and a new "your team" row on the
  Victory/Defeat screen. `Visuals.portrait` is now a thin wrapper, and every caller passes the
  copy's level. Battle units carry their level in the client view (`MatchRunner.view`); the battle
  engine itself is untouched.
- **One frame image for every rarity.** `card_border` is drawn in greys, and a UIGradient tints and
  turns it per rarity. That keeps the silhouette identical (design-system rule 6) and makes the
  animated Epic/Mythical borders cost one property write per frame. The five old per-rarity frame
  images were removed.
- **Effects run only on visible cards** (`App/CardFx`): checked every 0.2 s. Verified in Studio: a
  15-card gallery animates 15 while shown, 0 while hidden, and destroyed cards leave the loop.
- **TEMP cutouts until the owner's art.** Each of the 6 roles has a 4-layer silhouette (ink line,
  skin, outfit tinted with the character's first look colour, accent tinted with its second), so
  every card already works as a layered card. They are labelled "TEMP ART" on big cards and listed
  as Placeholder; a character's own transparent `card.png` replaces them through
  `CharacterDef.assets.cardArt`.
- **Character prompts** now lead with the card cutout ("transparent background, single character,
  upper body to knees, dynamic pose, anime cel-shaded"); the A-pose model reference stays as the
  second image. `art/ui/PROMPTS.md` gained the 15 family backgrounds and the card layers.

### Polish mission (POLISH_MISSION.md, 2026-11-07, owner away: "dont stop")
Per-item detail, scores and screenshots are in `docs/POLISH_LOG.md`. Decisions:
- **Locked rules win over the mission.** The mission's new egg types (G) and cosmetics shop (C)
  aren't built; they are listed in `docs/WAITING_ON_YOU.md` section 00.
- **Multi-open (H) is decided on the server.**
  - `count` is 1, 3 or 8.
  - A Coin batch is one charge under one request id, so a replay is refused as a whole.
  - The client never sends prices or results.
- **Auto-open pauses on Legendary or better**, so a big pull is never skipped past. It also stops
  when Coins, storage or the bag stack run out. It's a per-session toggle and isn't saved.
- **"New!" is computed on the client** from the cards it already knew before the request. It's
  cosmetic only, so no profile field was added.
- **Testing rare moments.** Real rolls almost never give Legendary or Mythical. Their effects are
  exercised in Play mode by calling the real hatch screen with injected cards. Those screenshots are
  labelled "injected". No dev hook ships in the game.
- **Starter deck (found in K).**
  - A new player can't otherwise reach a battle: 500 Coins buy 2 eggs, plus the free one, often
    duplicates, and a deck needs 3 different characters.
  - So anyone who has never owned a card gets three different Basic-egg Commons as a ready deck
    (`Economy.StarterCards`, applied once in `PlayerDataService` via `ProfileSchema.grantStarter`).
  - Card serials are never reused, so no one who has played can be topped up.
  - The owner can change the three ids or empty the list.
- **Audio sources.** The mission asks for "the official Roblox account". Roblox's licensed audio in
  the Creator Store comes from its partner accounts APMOfficial and ProSoundEffects, so only those
  are used, and every id is checked to load.

### Step 3: the GUI redesign (2026-11-07, owner: "full gui clean design and sound effects and animations")
References: `Downloads\now gui` (5 crops of the concept board). The layout and style were taken
from them. Their copyrighted characters and the "Bet Amount" panel are not used (no copied IP, no
wagers).
- **Main menu is its own screen.**
  - An opaque key-art backdrop: violet gradient, turning rays, drifting card backs, and a fanned
    Legendary / Golden Mythical / Epic showcase. It never shows the lobby, so the HUD and the world
    blur are off there (`UiFlow`: MainMenu hud = hidden).
  - PLAY always sends `World.Hub` (server-checked) and the menu fades away, so the player is in the
    lobby wherever they were.
  - The HUD's Menu button comes back to it.
- **Icon-first HUD.** The left menu is a dock of bright square tiles with one-word labels.
  - Every HUD icon is from the owner's `Free Icon Pack v3.1` (commercial use allowed), used
    **unedited** (256 px "Outline" versions, `art/icons`, license copied there). They are wired as
    the `final` art of the icon slots (`art/ui/ids.json`).
  - The Lobby button carries the house icon.
- **Panels.**
  - `Ui.glowTile`: a deep navy tile with a glowing accent border, gold when selected.
  - `Ui.pricePill`: a currency icon and the amount on a dark pill.
  - Egg Shop: band-coloured tiles and a gold featured pane.
  - Inventory: a vertical icon sidebar (All / Cards / Items / Eggs / +storage) and a glow inspect
    pane.
  - Deck: slots edged in their rarity, with a power pill.
  - Arena: unchanged layout (VS, Find Match, no stakes).
- **Animations.** Grid tiles pop in one after another on a panel's first render (`Ui.stagger`),
  notification dots breathe, and the main menu moves. All of it respects reduced motion.
- **Glitch fixed:** a HUD piece's visibility was decided when its slide began, so the Lobby button
  could reappear in the lobby after PLAY. It's now decided when the slide ends.
- **The anime folder** (`ANIME_FOLDER.md`).
  - The portrait pack in Downloads has no license file and isn't our characters, so it isn't used.
  - The doc explains how a folder gets in (license, mapping to character ids, the pickup script).

- **Cards and merchant (finished after the owner's "finish wht not finished").**
  - The card face is drawn in code now, like the reference cards:
    - a bright rounded border in the rarity's colours, animated as before;
    - full-bleed art;
    - a level socket, a rarity pill with the word written out, and a family socket on top;
    - a dark bottom plate with the name and the card's power (sword icon + number, the same
      `Power.card` the deck builder uses).
  - Golden copies get a gold border with a sweeping glint and a "GOLDEN …" pill.
  - The deck slots dropped their separate power pill, since the card shows its power.
  - The merchant is a gold "Sell your harvest" bar with the total and a **Sell all** button, then
    one glow tile per item (rare resources in gold with a RARE tag): count, price each, and a
    sell button. Items gained a `rare` flag in `Config/Items` for this.
