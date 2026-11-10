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
| `nature_fighter_N.png` | Rai Stormvolt → Zephyr Volt | N | **HOLD: do not use**, see note 3 |

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
