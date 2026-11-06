# Claude setup for 1v1 CARD

What is installed on this machine (2026-11-06), what each piece is for, and the manual steps
left for the owner.

## Connected tools (Claude Code MCP servers, user scope)
| Server | Command | Status |
| --- | --- | --- |
| `Roblox_Studio` (official, built into Studio) | `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` | registered; `claude mcp list` reports it Connected |
| `blender` (MCP for Blender, community) | `uvx mcp-for-blender` | registered; `claude mcp list` reports it Connected |

Check them with `claude mcp list` or `/mcp` in a new session. MCP servers load when a session
starts, so start a **new** Claude Code session to get their tools.

### Owner steps to finish
1. **Roblox Studio:** open Studio → **Assistant** → **… → Manage MCP Servers** → turn on
   **Enable Studio as MCP server**. A green indicator shows connected clients.
2. **Blender:** open Blender 5.2, using the desktop shortcut or
   `C:\Users\Administrator\Tools\blender-5.2.3-windows-x64\blender.exe`. The **MCP for Blender**
   add-on is installed and enabled; its server starts with Blender (see the N panel tab). Keep
   Blender open while Claude works in it.
3. **Restart Claude Code** so both servers' tools load.
4. The MCP for Blender setup script also added a `blender` entry to the Claude Desktop config
   (`claude_desktop_config.json`). It's harmless; remove it there if you don't want Blender in
   Claude Desktop.

## Plugins (Claude Code, user scope)
- `context7`: up-to-date library and API documentation lookup.
- `code-review`: multi-agent review of the current diff or a PR (`/code-review`).
- `frontend-design`: already installed.
- **Not installed, on purpose:**
  - `superpowers`: its mandatory brainstorm-and-ask workflow conflicts with this project's "work
    autonomously, don't stop to ask" brief.
  - `playwright`: Claude in Chrome already covers browser work.
  - Install either with `/plugin` if you want them anyway.
- There is no separate "Roblox Studio" Claude Code plugin. Roblox now ships the MCP server inside
  Studio (above), and the older `Roblox/studio-rust-mcp-server` is no longer developed.

## Project skills and agents (in this repo, loaded automatically)
`.claude/skills/`:

| Skill | Covers |
| --- | --- |
| `game-director` | routing, locked decisions, definition of done |
| `roblox-architecture` | where code goes; adding a feature end to end |
| `roblox-luau` | strict-mode idioms and the traps this repo hit |
| `roblox-networking-security` | the remote pipeline, the add-a-remote checklist, threat review |
| `roblox-data-persistence` | profiles, migrations, receipts, idempotent payouts, MemoryStore |
| `roblox-testing` | full check, headless and real-Studio runs, parity, policy matrix |
| `roblox-performance` | mobile budgets, server loops, request budgets |
| `3d-asset-pipeline` | Blender → Roblox: specs, licensing, QA (modelling, PBR, rigging, animation, VFX) |
| `world-building-lighting` | data-driven worlds, art passes, lighting |
| `roblox-ui-ux` | design tokens, the client App framework, UX rules, visual QA |
| `card-design-economy` | roster rules, balance gate, odds, currencies, Robux limits |
| `game-qa` | the QA gate and report format |

`.claude/agents/`: architect, gameplay-engineer, 3d-artist, ui-designer, world-designer,
qa-engineer and security-reviewer.

The setup brief listed 17–18 skills. Overlapping ones are merged (for example, Blender
modelling, PBR, rigging and animation/VFX are one pipeline skill), so each skill carries real
rules rather than a name.

## Engineering toolchain
- `rokit install` in the repo installs the pinned Rojo, StyLua, Selene and luau-lsp (see README).
- Also needed: the Luau CLI, Python 3 and TestEZ (`DevPackages/TestEZ`); see README.
- `run-in-roblox` 0.3.0 runs the suite and the boot check inside real Studio (see the
  `roblox-testing` skill).
- `uv` is installed with winget (it runs the Blender MCP).

## Not adopted from the setup brief
The brief's sample "Project Constitution" predates the owner's locked decisions. Its wagers,
40 eggs, 5-egg combining and V1 trading were overruled. `CLAUDE.md` stays the constitution, and
the skills follow it.
