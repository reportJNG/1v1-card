---
name: roblox-performance
description: Mobile-first performance budgets and patterns for 1v1 CARD - parts, scripts, Heartbeat work, UI rebuilds, MemoryStore and DataStore request budgets. Use when adding loops, geometry, effects or anything that scales with players.
---

# Performance (mobile first)

Profile before optimising: MicroProfiler (Ctrl+F6), the Developer Console's Memory and Scripts
tabs, and `Stats`. Write down the numbers you measured before and after a change.

## Budgets (per server or client; tighten after the M7 measurements)
| Area | Budget |
| --- | --- |
| Client frame time on a mid phone | under 16 ms. Keep UI rebuilds out of per-frame code |
| Parts per world (blockout) | 200 or fewer. Merge static geometry into meshes when art lands |
| Unanchored or simulated parts | none in worlds |
| Heartbeat handlers on the server | one (`BattleService` tick). Everything else is event-driven or polled at ≥ 0.5 s |
| Textures | 1024² for heroes, 512² for props. Reuse materials and atlases |
| Characters | 10k triangles or fewer for heroes, 4k for NPCs (confirm in M2) |
| Particles | short bursts, `Rate` 0 plus `Emit()`. Respect the reduced-motion setting |

## Server
- `MatchHost.tick` runs every frame but does nothing between deadlines. Keep it O(matches).
- MemoryStore: about 5 requests per queued player per poll cycle. The limit is
  1,000 + 120 × concurrent users per minute, and one sorted map lives on one partition (about
  30k/min). Ticks run every 2 s, so don't poll faster.
- DataStore: autosave every 60 s per session plus `saveNow` on purchases. Never save in a loop
  per action.

## Client UI
- Screens rebuild on `profile` changes. Keep them cheap: clear and rebuild only the open panel,
  and never touch hidden screens.
- Grid tiles: use plain Frames. Avoid many UIStrokes and UIGradients on large lists. Use
  `ScrollingFrame` with `AutomaticCanvasSize`.
- Tweens: animate the transform (UIScale, Position), not layout-driving sizes, inside lists.

## Checks before shipping a feature
- Mobile emulator in Studio (Test → Device) at 844×390: no frame spikes when opening each panel.
- Memory: no growth across 20 open/close cycles of a panel (leaked connections). Disconnect
  everything in `destroy()`.
