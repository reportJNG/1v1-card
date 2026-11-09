# CLEANUP: remove the portrait pack completely (moderation ban, 2026-11-08)

On 2026-11-08 Roblox **banned the owner's account for 1 day** (it can be reactivated after
2026-11-09, 06:24). The flagged asset was a face cut from the "Ultimate Multi-Expression Portrait
Pack": asset `114026669753620`, the Space Pilot Girl face used as `nyx_voidglimmer`'s "hit"
reaction. Moderator note: *"Roblox does not permit sexual content in any form on the platform."*
A blushing, crying, open-mouthed face reads as sexual to Roblox moderation, even though it was
meant as "hurt".

**The portrait pack is removed from the game permanently.** Do every step below **before any
other work**. Another strike could mean a longer ban or account termination.

## 1. Owner: archive every uploaded asset (as soon as the account is reactivated)

43 images from the pack were uploaded to Roblox. They are still live and could be flagged again.

Archive all of them:
1. Open **create.roblox.com → Creations → Development Items → Images/Decals**.
2. Open each asset below.
3. Choose **Archive**. An archived image stops showing everywhere.

The ids are also in `art/characters/ids.json` and `art/characters/reaction_ids.json`.

| # | Character | Image | Asset id |
|---|---|---|---|
| 1 | asha_warbanner | card | 92854127828979 |
| 2 | asha_warbanner | reaction attack | 70678548602464 |
| 3 | aurelia_dawn | card | 86655307080418 |
| 4 | corvin_duskweaver | card | 93379065970880 |
| 5 | corvin_duskweaver | reaction attack | 72277603985086 |
| 6 | corvin_duskweaver | reaction hit | 96292095396913 |
| 7 | corvin_duskweaver | reaction ko | 97678042801843 |
| 8 | corvin_duskweaver | reaction victory | 115723977420855 |
| 9 | draxa_bloodthorn | card | 108315633733334 |
| 10 | draxa_bloodthorn | reaction attack | 86289455675672 |
| 11 | draxa_bloodthorn | reaction hit | 128201419508210 |
| 12 | draxa_bloodthorn | reaction ko | 76799067138001 |
| 13 | draxa_bloodthorn | reaction victory | 92173426689531 |
| 14 | edric_velvetshield | card | 116010905514177 |
| 15 | edric_velvetshield | reaction attack | 85147945664162 |
| 16 | edric_velvetshield | reaction hit | 113271597475374 |
| 17 | edric_velvetshield | reaction ko | 136159346972611 |
| 18 | edric_velvetshield | reaction victory | 98240224800692 |
| 19 | eira_mistsong | card | 100556568220747 |
| 20 | eira_mistsong | reaction attack | 118940198861137 |
| 21 | eira_mistsong | reaction hit | 109941892325317 |
| 22 | eira_mistsong | reaction ko | 102114377071095 |
| 23 | eira_mistsong | reaction victory | 80315939884012 |
| 24 | kenji_thunderpeak | card | 74939243679017 |
| 25 | kenji_thunderpeak | reaction attack | 121822875601499 |
| 26 | kenji_thunderpeak | reaction hit | 139019441252908 |
| 27 | kenji_thunderpeak | reaction ko | 83134501296661 |
| 28 | kenji_thunderpeak | reaction victory | 81754839088633 |
| 29 | lyra_wildpelt | card | 70960382819383 |
| 30 | lyra_wildpelt | reaction attack | 94309107741899 |
| 31 | lyra_wildpelt | reaction hit | 103195630974841 |
| 32 | lyra_wildpelt | reaction ko | 136428776190691 |
| 33 | lyra_wildpelt | reaction victory | 95358517588719 |
| 34 | mirelle_hexwhisper | card | 124769498928235 |
| 35 | mirelle_hexwhisper | reaction attack | 77615127031410 |
| 36 | mirelle_hexwhisper | reaction hit | 94633362073500 |
| 37 | mirelle_hexwhisper | reaction ko | 72894536201655 |
| 38 | mirelle_hexwhisper | reaction victory | 101761936663554 |
| 39 | nyx_voidglimmer | card | 97076501453960 |
| 40 | nyx_voidglimmer | reaction attack | 94197504938250 |
| 41 | nyx_voidglimmer | reaction hit | 114026669753620 **(the one that got the ban)** |
| 42 | nyx_voidglimmer | reaction ko | 113999011413246 |
| 43 | nyx_voidglimmer | reaction victory | 109471600220282 |

If Roblox sends any more moderation messages about these, archive the asset and don't appeal
(appealing an image that really looks suggestive won't succeed). Appeal only the ban itself, if
the owner wants to, through the Appeals Portal, explaining that it was third-party art uploaded
by mistake and has been removed.

## 2. Claude (CLI): remove it from the project

**No uploads until the owner confirms that step 1 is done.**

1. **Delete the pack and everything derived from it:**
   - `art/characters/incoming/portrait-pack/`
   - every folder in `art/characters/processed/` that came from the pack (`asha_warbanner`,
     `aurelia_dawn`, `corvin_duskweaver`, `draxa_bloodthorn`, `edric_velvetshield`,
     `eira_mistsong`, `kenji_thunderpeak`, `lyra_wildpelt`, `mirelle_hexwhisper`,
     `nyx_voidglimmer`)
   - `processed/portrait-pack_review.json`
   - `art/characters/map.json` entries from the pack
   - `art/characters/portrait_ids.json`, `art/characters/reaction_ids.json`
   - the pack entries in `art/characters/ids.json`
   - `docs/screens/characters/contact_portrait-pack.png`
   - any other screenshot or contact sheet that shows these faces
2. **Remove every reference in code and config:**
   - card art ids, portrait ids, reaction ids and silhouettes for those 10 characters
   - `ContentStatus` entries for the pack

   Those 10 characters go back to the clean **template card** (star/crown emblem, MISSION.md 6.2)
   and the role silhouette.
3. **Battle reactions:** remove the face pop-up feature's art. Keep the system, but have it show
   **effects only** (hit flash, shake, icon bursts such as a sword, a shield or a skull for KO)
   until safe original art exists.
4. **Remove the pack from git history too**, because the repo may be shared:
   - use `git filter-repo` (or BFG) on `art/characters/incoming/portrait-pack/` and the
     processed folders
   - then garbage-collect
   - tell the owner it was done; a force-push is only relevant if a remote exists
5. **Update the docs:**
   - remove the portrait-pack sections from `MISSION.md` (already replaced: see section 12.3
     there) and `ANIME_FOLDER.md`
   - remove the pack items from `docs/WAITING_ON_YOU.md`
   - in `docs/ASSETS.md`, mark the 43 ids "REMOVED: moderation"
6. Run the tests and the Rojo build, do a Play-mode check that no card or battle shows those
   faces, then commit: "Remove portrait pack after moderation action".
7. Record this incident and the new rules in `CLAUDE.md` under **Moderation safety** (see
   `MISSION.md` §1, rule 7).

## 3. Lessons (permanent)
- Expression sheets of anime faces are high risk: blushing, tears, open mouths, panting and
  "flustered" faces get read as sexual.
- Third-party anime packs without a license are doubly risky. They're out.
- Every image now needs the **owner's approval before upload** (MISSION.md §1, rule 7).
