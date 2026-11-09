# BAD GUI 7: the battle result screen (Defeat / Victory) and the 1v1 battle look

The owner, 2026-11-09:

> "The right one is the bad UI I have on my screen, when it should be 2 players. This UI is
> better in Roblox. Report this screen, it also has so much bad UI."

Siblings: `BAD_GUI_THINKING_AND_UI.md` … `BAD_GUI_6_DECK_AND_INVENTORY.md`. It's listed in
`UI_TARGETS.md`.

---

## 1. Images

| File | What it is |
|---|---|
| `docs/brief/bad-gui/17-battle-result-current.png` | **Now (bad)** |
| `docs/brief/bad-gui/16-target-battle-result.png` | **Target** (the owner's mockup of our own screen, no copyrighted characters) |

## 2. What's wrong with "now" (17), compared to the target (16)
1. **The DEFEAT banner is flat:** a grey code-drawn box with plain rounded text and thin wings.
   The target banner is **painted steel with cracks and ice shards bursting out**, with heavy
   bevelled metal letters and glowing purple light behind.
2. **The scene is dead:** a flat dark arena floor, no light, no particles. The target has a
   **glowing purple arena** with stadium lights, fog, **embers and rock debris floating**, and
   coloured light from the cards.
3. **The two players don't read as a 1v1:**
   - the opponent is a grey blocky dummy, and the player's own avatar is hidden behind the big
     card
   - the target clearly shows **both fighters**: the player's avatar on the left (next to their
     card) and the opponent on the right, both lit and posed
4. **The cards have no energy:** small glow only. In the target, each card has a **rarity aura**
   (silver glow on N, **blue flames** on R, **purple flames** on SR) and the big card on the left
   has shards and sparkles.
5. **The reason line is tiny grey text** ("Too many missed picks · 4 rounds"). The target puts it
   in a **styled pill with an icon and "!!!"** warning marks.
6. **The Continue button is a flat yellow pill with small text.** The target is a **big ornate
   gold button with flames**, a glowing frame and heavy "CONTINUE" letters.
7. **The battle log** (bottom-left) is **small plain web text**: "Round 4: you special…". It
   should be gone from this screen; battle events are big world/screen pops while fighting
   (`BAD_GUI_THINKING_AND_UI.md`). At most, a short coloured line in a painted pill.
8. **The top player panels are crowded with tiny text:** username, trophies, rarity, HP "71 /
   557", "Special: Glacier Ward", "Ren Emberfang KO · Rai Stormvolt 100%". The target keeps the
   panels, but they're painted and readable. Cut the text down further (section 3).
9. **Rewards aren't visible:** nothing shows coins or trophies won or lost. The result screen must
   show them big.

---

## 3. Target result screen (both Victory and Defeat)

**Layout (1920 × 1080 design):**
- **Top-centre: the result banner**, painted:
  - **DEFEAT:** steel, cracked, ice shards, cold purple-blue light
  - **VICTORY:** gold, wings, crown, warm light rays (the matching set, `ui-refs/hd-06-victory.png`)

  It slams down with a screen shake and shards or sparks flying.
- **Top-left: the player's panel. Top-right: the opponent's panel.** Each is painted, with:
  - the lead card thumbnail with its rarity badge
  - **the player name** (big, outlined)
  - **trophies with a trophy icon**
  - **an HP bar** (painted, coloured, with the number in big text)
  - the **deck pips** (filled for cards still alive)

  That's all. No ability names, no percentages, no rarity words.
- **Left: the player's MVP card**, large: the card that did the most damage, tilted, with shards,
  sparkles and its aura. **Right: the opponent's MVP card**, smaller and slightly dimmed on a
  loss (on a win, swap the emphasis).
- **The arena between them: both fighters.**
  - The player's avatar stands on the left, the opponent's avatar on the right, both lit by the
    arena lights.
  - The winner plays a **victory pose**, the loser a **defeat pose** (from `generate_animation`).
  - Each has a name billboard above their head.
  - **For Guardian Trials**, the opponent is the Guardian model, not a grey dummy.
- **Centre: one short line in big outlined text.**
  - Defeat: "So close! Tune your deck and try again." Victory: "You won the match!"
- **Under it: the player's 3 deck cards**, each with its rarity aura (flames for R and up),
  KO'd cards darkened with a crack overlay.
- **Rewards row:** big reward chips with icons (**+N coins**, **+/− N trophies**, a Gem or egg
  for Trial clears) that count up, with coins flying to the currency pill. On a 0-reward match,
  the chip says why (see the next point).
- **Reason pill**, only when it matters ("Too many missed picks · 4 rounds", "Opponent
  forfeited"): a painted pill with a warning icon and "!!!", in big text.
- **Bottom-centre: a big ornate gold CONTINUE button** with flame accents, a shine sweep, a press
  squash and the confirm sound. It returns the player to their saved spot (`MISSION.md` §2.4).
- **The battle log is removed from this screen.**

**The arena scene:**
- stadium spotlights, purple fog, glowing ring lines on the floor
- floating embers and rock debris (particles)
- the lanterns lit
- card auras cast coloured light (a small `PointLight` per card in the 3D scene, or a glow image
  behind each UI card)
- a camera with a slow push-in on the result
- **Mobile:** reduce particles to about 40%

## 4. Owner images (exact prompts)
Attach `16-target-battle-result.png` as the style reference. Flat magenta background, separated.

**G1. Result banners** → `art/ui/sheets/result_banners.png` (text baked in: these words never
change)
> "Two Roblox game result banners in exactly the style of the attached image: (1) 'DEFEAT' in
> heavy bevelled steel letters on a cracked steel plate with ice shards bursting out, cold purple
> glow; (2) 'VICTORY' in heavy bevelled gold letters on an ornate gold plate with wings and a
> crown, warm glow and light rays. Flat magenta background, separated."

**G2. Result UI pieces** → `art/ui/sheets/result_pieces.png`
> "Same style, NO TEXT, flat magenta background, separated: a big ornate gold button with flame
> accents (empty); a painted player info panel (dark glass, gold-violet frame) with an empty card
> socket on the left; a painted HP bar background and fills in red, yellow and green; a warning
> pill (dark, with a red-yellow warning icon and three exclamation marks, empty text area); reward
> chips (empty) with a gold coin, a trophy and a blue gem; a crack overlay for a knocked-out card;
> blue flame aura and purple flame aura sprites for cards."

**Review gate:** contact sheet, check for no characters, the owner's OK, upload in batches of 5 or
fewer, stop on any rejection.

## 5. Checklist
- [ ] Battle log removed from the result screen (and the in-battle log replaced by pops)
- [ ] Both fighters shown in the arena (the player's avatar left, the opponent or Guardian right),
  with victory/defeat poses and name billboards
- [ ] Painted DEFEAT and VICTORY banners with the slam, shake and shards/sparks
- [ ] Player panels cut down: card, name, trophies, HP bar, deck pips only
- [ ] MVP cards, deck cards with rarity auras and crack overlays
- [ ] Reward chips with count-up and fly-to-pill; reason pill only when it matters
- [ ] Ornate CONTINUE → saved spot
- [ ] Arena scene: lights, fog, embers and debris, card-coloured light, push-in camera, mobile
  particle budget
- [ ] G1/G2 prompts in `PROMPTS_V3.md` + `WAITING_ON_YOU.md`; sheets cut, reviewed, approved,
  uploaded, swapped
- [ ] Comparison `docs/screens/roblox-ui/compare_result_defeat.png` and
  `compare_result_victory.png`, scoring 8+
- [ ] `PLAN.md` §2/§6 updated, tests pass, committed
