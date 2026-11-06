---
name: roblox-luau
description: Strict-mode Luau idioms and the type-checker, StyLua and Selene pitfalls this repo has actually hit. Use when writing or fixing any .luau file in 1v1 CARD.
---

# Luau in this repo

Every file starts with `--!strict`. Use tabs and StyLua formatting (`stylua.toml`), with no Selene
warnings (`selene.toml`, Roblox std) and zero strict `luau-lsp` errors.

## Idioms
- Results: `return Result.ok(v)` / `Result.fail("CodeInPascalCase")`. Read them with
  `if not r.ok then return r end`. To get the error text in a test:
  `if r.ok then "" else r.err`.
- Freeze config tables with `table.freeze`. Build `ById` maps next to the `List`.
- Use exported types for public shapes (`export type X = {...}`), with
  `typeof(setmetatable({} :: {...}, M))` for classes.
- Inject randomness (`Random`, or `Prng` in battles) and the clock (`now`) into domain code. Never
  call `os.time()` inside `Shared/Domain`.

## Type-checker traps (seen here)
- `::` binds tighter than `or`. Write `(picked or "Attack") :: BattleRules.Action`, not
  `picked or "Attack" :: ...`.
- String literals widen to `string` in `if` expressions and tables. Annotate the local
  (`local a: BattleRules.Action = ...`) or cast.
- `next(t)` returns two values. Inside `expect(...)` or `table.insert`, wrap it:
  `(next(t))`.
- A list of differently shaped tables needs an explicit type:
  `local cases: { { [string]: any } } = {...}`.
- `Random` isn't structurally a custom `Rng` type. Cast it at the call site (`rng :: any`).
- Selene flags manual copy loops (use `table.clone`) and unused variables. Remove them, don't
  silence them.
- `continue` is a contextual keyword, so don't use it as a variable name.

## Style
- Comments explain *why* (a rule or a risk), not what the line does. Match the density of the
  surrounding code.
- Keep scripts focused. Split a service before it passes about 300 lines of mixed concerns.
- Never `require` across layers upward: shared must not require server, and the server must not
  require client code.
