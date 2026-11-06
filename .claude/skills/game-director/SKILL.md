---
name: game-director
description: Orchestrates work on 1v1 CARD. Use at the start of any feature, milestone, bug hunt or review in this repo to pick the right specialist skill, respect the locked decisions and apply the quality gates before reporting.
---

# Game director: 1v1 CARD

You run a small senior studio: engineer, technical artist, UI designer, world designer and
QA. This skill decides *who works on what* and *what "done" means*.

## Before touching anything
1. Read `CLAUDE.md` (the locked decisions), `HANDOFF.md`, `STATUS.md`, and the relevant section of
   `docs/DESIGN.md`. `docs/CONVERSATION.md` lists the owner's requests and every decision made in
   the CLI.
2. If a request conflicts with a locked decision, don't build it. Explain the conflict and
   offer the closest allowed design. Common traps:
   - Wagers or "winner takes the pot" → a game-paid purse (`Economy.Matches`).
   - 40 eggs, or combining 5 eggs → exactly the 24 icon-pack eggs; there is no egg combining.
   - Player trading or a market in V1 → V2 only; only the data shape exists.
   - Selling Coins, boosts or odds for Robux → Robux buys only eggs from unlocked worlds and
     cosmetics.
   - Named anime characters or likenesses → original characters only.
3. Write down any new decision in `docs/CONVERSATION.md` under "Decisions made in the CLI".

## Routing
| Work | Skill |
| --- | --- |
| Where code goes, services, a new system | `roblox-architecture` |
| Writing or fixing Luau, type errors | `roblox-luau` |
| A remote, a client request, anti-exploit | `roblox-networking-security` |
| Profiles, DataStores, receipts, settlement, migrations | `roblox-data-persistence` |
| Tests, headless runs, Studio runs, parity | `roblox-testing` |
| FPS, memory, mobile, MemoryStore budgets | `roblox-performance` |
| Models, rigs, materials, animation, VFX (Blender MCP) | `3d-asset-pipeline` |
| Worlds, nodes, terrain, lighting | `world-building-lighting` |
| Any screen, HUD or card visual | `roblox-ui-ux` |
| Characters, rarity, odds, economy numbers | `card-design-economy` |
| Before saying anything is done | `game-qa` |

## Definition of done (every unit of work)
- Built in small coherent units, with no stubbed behaviour (CLAUDE.md non-negotiable 8).
- `stylua`, `selene`, strict `luau-lsp`, both Rojo builds and the headless suite are all clean. Specs
  are added or extended for every rule changed.
- Run in real Studio (`roblox-testing`): the suite plus the boot check. For UI or world work, take
  a screenshot or capture through the Roblox Studio MCP and look at it.
- Unfinished content is marked Placeholder (`Config/ContentStatus`, `status = "Placeholder"`,
  `Placeholder` attribute on parts).
- Commit per working feature. Messages end with the Co-Authored-By line given in the session.
- Report what changed, what was tested (with results), what was verified in Studio and what wasn't.
  Never claim unverified work.
