# Polish log (POLISH_MISSION.md)

One entry per checklist item, in the order it was done: what changed, the scores (1-10 against
the concept board: matches the board / readability / polish and animation / clarity of what to do
next / consistency with ART_STYLE), the screenshots, and what was and wasn't tested in Play mode.

Sizes: Studio's device emulator can't be scripted, so the four sizes come from resizing the Studio
window (its viewport): **PC** 1398×753, **tablet** 1073×805 (4:3), **phone landscape** 1742×805
(2.16:1, the shape of a 19.5:9 phone), **phone portrait** 362×805. The game runs landscape on
phones (`StarterGui.ScreenOrientation = LandscapeSensor`, now set in the project files), so
portrait is checked for robustness only.

---

## Conflicts with locked decisions (not built, see docs/WAITING_ON_YOU.md)
- **G, new egg types:** CLAUDE.md locks the game to exactly the 24 icon-pack eggs (game-director:
  "40 eggs" is a listed trap). The rest of G (odds button, Robux rules, data-driven pools, tests)
  already holds and is kept.
- **C, "Gems + opens the cosmetics shop":** the cosmetics shop is designed but not built in V1
  (STATUS "Designed but not built"). The Gems + explains what Gems are for instead.
- **F, Blender pipeline:** needs the owner's character images and Blender's generators switched
  on (WAITING_ON_YOU 1-2). The TEMP silhouettes and the automatic pickup are in place.

---

## A. UI state machine — done (2026-11-07)
**Changed**
- `Shared/Ui/UiFlow`: one pure state machine, `Loading → MainMenu → Playing / Queue`, with
  `Panel` (one modal), `Hatching`, `Battle` and `Result` on top. It derives the view: HUD mode
  (full / currencies only / hidden), input lock, blur, the menu camera. Unit-tested
  (`UiFlow.spec`, 7 specs).
- `App/App`: every screen change goes through it. One modal at a time, and opening one replaces the
  other. Esc, gamepad B, Backspace and the X close the top panel. Panels close with a scale-out,
  and the HUD slides off and back (0.3 s, Back ease-out).
- `App/UiEffects`: blur + colour grade under modals and the menu, movement off and the camera held
  while a modal is open.
- Battle and Hatching hide the whole hub HUD. A panel stays open under a hatch and is there again
  after it.
- `Ui.button` is debounced (0.35 s). The server still validates every action, since the UI state
  is presentation only.
- **Narrow screens:** the logo hides, the currency bar moves left of the icons, the Menu button
  drops under the icons, and panels scale to fit.

**Tested in Play**
- Holding W with a panel open moves 0.00 studs; after Backspace, 15.97 studs.
- A double click opens one panel.
- The Shop survives a hatch.
- Battle and Result show no HUD; Continue brings the full HUD back.
- Esc closes the panel, but Roblox's own Esc menu also opens. Games can't intercept that key, so
  Backspace or B are the clean ways to close.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9.

**Screens:** `docs/screens/ui/04-11` (HUD and modal at all four sizes).

## B. Main menu — done (2026-11-07)
**Changed**
- `App/MainMenu`: a full-screen menu over a slowly drifting, blurred and colour-graded camera shot
  of the night lobby. It has the 1V1 CARD logo, a big pulsing gold PLAY, Cards / Shop / Settings,
  and a version/news line. While loading it shows "Loading your cards…".
- The camera holds the menu shot and controls are off. The backpack is hidden always, and the
  player list while in the menu.
- PLAY: the camera flies in to the character (1.4 s), then controls come on and the HUD slides in.
- The HUD's Menu button reverses it.
- Menu music (APM "Team of Heroes") crossfades to the lobby track on PLAY.

**Tested in Play**
- Menu on join with only the currencies.
- PLAY → HUD and camera back on the character; Menu → back.
- Panels open over the menu.
- Music swapped from `Music_music_menu` to `Music_music_hub`.
- Player list on again after PLAY.

**Scores:** board 8 · readability 8 · polish 8 · clarity 9 · consistency 9. Key art from the owner
would lift "board".

**Screens:** `docs/screens/ui/01-03` (menu PC / tablet / portrait), `08` (a panel over the menu).

## E. Cards — done in session 3 (step 1)
All nine boxes were built and tested before this mission: `docs/screens/cards/01-09`, with Play
captures of the hatch, collection, battle and result. The details are in `docs/CONVERSATION.md`
("Session 3, Part 3").

## J. Lobby and worlds — done in session 3 (step 1)
- Lobby spawn (join, respawn, after battles, and now after the main menu's PLAY).
- Server-checked travel and a Back to Lobby portal.
- 10 themed maps with their own terrain, props, sky, lighting, particles and music.

Screenshots are in `docs/screens/12-15` and `docs/screens/worlds/`. Everything was tested in Play
(see `docs/CONVERSATION.md` "Session 3, Parts 1-2").
