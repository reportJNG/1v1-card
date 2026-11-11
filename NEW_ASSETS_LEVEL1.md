# NEW ASSETS: level-1 fighter images (2026-11-10)

The source is `Downloads\level_1_five_fighters_png.zip` (the same 5 files are also loose in Downloads).
- **Cleaned:** stray bits of neighbouring fighters were cut off every edge, all 5 are trimmed, and the backgrounds are transparent.
- **Saved to:** `Downloads\New folder` under the NEW_5_CHARACTERS names.
- **Review sheet:** `docs/review/new5_review.png`.

`fighter_01..05` in the same folder stay rejected. Never use them.

## Mapping

| File (New folder) | Card (id unchanged) | Rarity | Status |
|---|---|---|---|
| `rook_emberforge.png` | Ren Emberfang → **Rook Emberforge** | R | Ready once the owner OKs it |
| `halvard_frostwarden.png` | Yuki Frostveil → **Halvard Frostwarden** | SR | Ready once the owner OKs it |
| `nox_veilstrider.png` | Vesper Shade → **Nox Veilstrider** | SSR | Ready once the owner OKs it |
| `solaris_dawnbringer.png` | Aurelia Dawn → **Solaris Dawnbringer** | UR | Owner OK needed, see note 2 |
| `HOLD_nature_fighter_N.png` | Rai Stormvolt → Zephyr Volt | N | **HOLD: do not use**, see note 3 |

## Review notes (rules from CLAUDE.md "Asset safety")

1. **Scarves.** Ice, shadow, radiant and nature all wear a scarf over the mouth, and
   `NEW_5_CHARACTERS.md` lists face masks covering the mouth under "never add". On its own a plain
   scarf isn't a franchise mark, so the owner decides: accept the scarves, or regenerate those
   images without them.
2. **Radiant (Solaris) is borderline.** The white spiky hair, the scarf over the mouth and the glowing
   eyes together could read as a known character. It's safer to regenerate it with brown or gold hair
   and no scarf. Use it only if the owner OKs it in writing.
3. **Nature is held.** Messy green hair, green eyes and a black suit with green thorny tendrils
   read as a well-known hero-academy anime lead. It's also a Nature fighter, but the N slot is
   Zephyr Volt (Storm). **Don't use it.** The N card keeps TEMP art until a new Zephyr Volt image (the
   storm prompt in NEW_5_CHARACTERS.md) arrives in New folder.
4. **Rest of the checklist:** all 5 are fully clothed boys with no suggestive poses, one character
   each, and no text or watermark.

## What the CLI does

1. Rename the 5 active characters per `NEW_5_CHARACTERS.md`. Change only `displayName` and `look`;
   ids and stats stay the same.
2. **Wait for the owner's written OK** on `docs/review/new5_review.png`. The OK must say which files.
3. Process only the approved files through the normal pipeline (ANIME_FOLDER.md / art scripts),
   then upload them in one batch of 5 or fewer. Stop at the first moderated, rejected or 403 result.
4. Put the asset ids in config and show the art on cards, the deck, hatch reveals and battle. Any card
   without approved art keeps TEMP art, logged in `WAITING_ON_YOU.md`.
5. Re-score the card, deck and hatch screens. Run tests and lint, then commit and push named paths only.

---

# SET 02: 5 more level-1 fighters (2026-11-11)

The source is `Downloads\level_1_five_new_fighters_set_02 (1).zip` and `(2).zip`. Both hold the same
5 fighters in two versions.
- **Version used:** (2). Its void fighter holds a sword instead of an orb, so it doesn't copy Nox,
  and its faces are clearer.
- **Cleaned the same way:** neighbouring fighters' bits removed, trimmed, transparent backgrounds.
- **Review sheet:** `docs/review/set02_review.png`.

| File (New folder) | Card | Status |
|---|---|---|
| `zephyr_volt.png` | **Zephyr Volt**, the existing N Storm card (id unchanged) | **Borderline**: needs the owner's OK by name, see note A |
| `kael_voidbinder.png` | **Kael Voidbinder**, a NEW Shadow character | Ready once the owner OKs it |
| `brann_cinderfall.png` | **Brann Cinderfall**, a NEW Fire character | Ready once the owner OKs it |
| `aurex_sunforge.png` | **Aurex Sunforge**, a NEW Light character | Ready once the owner OKs it |
| `HOLD_venom_fighter.png` | (none) | **HOLD: do not use**, see note B |

A. **Storm fighter.** Silver spiky hair together with a mask over the mouth is the signature look of
   a famous ninja-anime teacher. Safer to regenerate it with dark-blue or teal hair and no mask
   (the NEW_5 Zephyr Volt prompt). Use it only if the owner names it in a written OK.
B. **Venom fighter.** Same problem as `HOLD_nature_fighter_N`: messy green hair, green eyes and a
   black suit with green tendrils read as a famous hero-academy anime lead. Not used.

**New characters (Kael, Brann, Aurex):**
- Append them to `Config/Characters` with new permanent ids, set their rarity and stats with the
  existing balance rules in `PLAN.md`, and add them to egg pools.
- Mark them `status = "Placeholder"` until their art is uploaded.
- Never change the ids or stats of the 5 active cards.

## Done (2026-11-11)

- **Owner OK (written, confirmed in chat):** rook_emberforge, halvard_frostwarden, nox_veilstrider,
  kael_voidbinder, brann_cinderfall, aurex_sunforge. **Not approved:** solaris_dawnbringer,
  zephyr_volt, every HOLD_* file, fighter_01..05.
- **Solaris Dawnbringer:** approval withdrawn; its art is out of the game (TEMP). The uploaded image
  `rbxassetid://95044429524790` waits for the owner to archive it.
- **Set 02:** Kael Voidbinder (Shadow, Epic, Trickster), Brann Cinderfall (Flame, Common, Bruiser) and
  Aurex Sunforge (Divine, Legendary, Skirmisher), each with one tuned number (`sim/roster.py set02`),
  added to the active roster and to themed egg pools. Their images went through
  `docs/review/set02-2026-11-11.md` and were uploaded in one batch of 3 with no rejections.
- Zephyr Volt and Solaris Dawnbringer keep TEMP art (`docs/WAITING_ON_YOU.md`).
