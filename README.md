# 1v1 CARD

The Roblox game project, synced with [Rojo](https://rojo.space). Project rules are in `CLAUDE.md`; what is real vs placeholder is in `STATUS.md`.

## Setup (Windows)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
   It installs the pinned Rojo, StyLua, Selene and luau-lsp.
2. Install the Rojo plugin in Studio: `rojo plugin install`.
3. Get TestEZ (dev only):
   `git clone --depth 1 https://github.com/Roblox/testez.git %TEMP%\testez`, then
   `xcopy /E /I %TEMP%\testez\src DevPackages\TestEZ`.
4. Run `rojo serve dev.project.json`, then click **Connect** in the Rojo plugin.
   Use `default.project.json` for builds without tests.

## Checks

| Check | Command |
| --- | --- |
| Format | `stylua src tests` (CI: `stylua --check src tests`) |
| Lint | `selene src tests` |
| Types | `rojo sourcemap dev.project.json -o sourcemap.json`, then `luau-lsp analyze --definitions=globalTypes.d.luau --definitions=testez.d.luau --sourcemap=sourcemap.json src tests` |
| Unit tests (Studio) | Command Bar: `print(require(game.ServerScriptService.Tests.RunTests)().report)` |
| Unit tests (headless) | `python scripts/headless/bundle.py`, then `luau build/headless.luau` ([Luau CLI](https://github.com/luau-lang/luau/releases)) |

The headless host (`scripts/headless/shim.luau`) fakes only what the specs touch: the instance
tree, `require` by instance, `Random`, `Color3.fromHex` and `TestService`. DataStores in the specs
are `tests/Mocks/MockDataStore`. Studio stays the reference runtime: run the suite there too
before closing a milestone.

`globalTypes.d.luau` is the Roblox API definition file from the luau-lsp repository
(`scripts/globalTypes.d.luau`). Selene builds its Roblox library the first time it runs.

## Testing PolicyService combinations (Player Emulator)

Run all four, one Play session each:

| # | ArePaidRandomItemsRestricted | IsPaidItemTradingAllowed | Expected |
| --- | --- | --- | --- |
| 1 | off (false) | off (false) | Robux eggs allowed; paid-origin cards not tradable |
| 2 | off (false) | on (true) | Robux eggs allowed; paid-origin cards tradable |
| 3 | on (true) | off (false) | Robux eggs blocked; paid-origin cards not tradable |
| 4 | on (true) | on (true) | Robux eggs blocked; paid-origin cards tradable |

1. **Test → Player Emulator**: tick **Enable Test Profile**.
2. Under **Policies**, set the two values for the row.
3. Press **Play**. In Output, find the `[PolicySelfCheck]` line. It runs the real server checks
   (Robux egg offer, receipt delivery, Coin egg, trade eligibility of a paid and an earned copy)
   on a throwaway profile and ends in `MATCH` or `MISMATCH`. Also note the `[PolicyGate]` line.
4. Stop, change the policies, repeat. Record all four lines.

`[PolicySelfCheck]` only runs in Studio and never touches the player's real profile.

## Saving Place1

Rojo syncs scripts but doesn't save the place. After syncing: **File → Save to File As…**
→ `Place1.rbxlx` (or **File → Save to Roblox** if the place is published).

## Layout

- `src/shared` → `ReplicatedStorage.Shared`: types, config, and pure domain logic
- `src/server` → `ServerScriptService.Server`
  - `Services/`: PolicyGate, PlayerDataService, PurchaseService, PolicySelfCheck (Studio only)
  - `Persistence/`: SessionStore (locked DataStore records), ProfileManager (session lifecycle),
    InMemoryDataStore (Studio fallback when API access is off)
  - `Purchases/ReceiptProcessor`: Robux receipt rules (pure, tested)
- `src/client` → `StarterPlayerScripts.Client`
- `tests` → `ServerScriptService.Tests`: TestEZ specs and mocks (dev project only)
- `scripts/headless`: runs the TestEZ suite outside Studio
