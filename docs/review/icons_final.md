# Review batch: icons_final (GOAL_ALL Phase 3b)

**Status: waiting for the owner's OK.** Nothing is uploaded or used until then.

- **Sheet:** `docs/review/icons_final.png` (39 slots). It is a local file, git-ignored with the
  packs: the repo is public and the Stylized licence forbids redistributing the icons.
- **Per-pack sheets** (to pick other icons): `docs/review/icons_free-icon-pack-v3.1.png`,
  `docs/review/icons_stylized-game-essentials.png` (local).
- **Choice per slot, with reasons:** `art/icons/icon_map.json`. One painted style: 35 slots from
  Stylized Game Essentials; Robux, the closed lock and plus from the Free Icon Pack (unedited).
- **Farm items:** 4 items get a pack icon that truly shows them (Meadow Crystal, Glacier Shard,
  Seraph Gold, Null Quartz); the other 26 keep their own resource-node mesh (`App/ItemIcon`),
  because the packs have no correct icon for them. No two items share an icon.
- **Sparkle** uses the kit piece `m_sparkle_gold` (batch `ui-kit-v3`).

## Safety check (`CLAUDE.md` "Asset safety" rules 1-3)
- [x] No characters, faces or people (the "friends" icon is two plain silhouettes).
- [x] Nothing suggestive.
- [x] No franchise characters, symbols or logos (the meme, social-logo and "roblox bank" icons of the
  Free pack are excluded). The Robux icon is Roblox's own currency mark, shown only on Robux prices.
- [x] Licences read and recorded (`docs/ASSETS.md` "Icon packs"); the unlicensed `Downloads\Free` is not used.

## After the OK
Upload in batches of 5 or fewer (8 batches), stopping at the first "moderated", "rejected" or 403.
Each upload's id goes into `Config/UiAssets` as the `final` of the slot in `replaces`, or a new slot
`icon_<slot>`, and items get `item_<id>` slots, so `App/ItemIcon` switches from the node mesh
automatically. Then the validator test "every slot and every item has an icon, no duplicates"
covers the uploaded slots.
