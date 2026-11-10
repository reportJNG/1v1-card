# Review batch: ui-kit-v3 (pieces cut from the owner's merchant target)

**Status: waiting for the owner's OK.** Nothing here is used in the game or uploaded until then.

- **Contact sheet:** `docs/review/ui-kit-v3.png` (8 pieces). 9-slice test of the frame:
  `docs/review/m_panel_frame_slice_test.png` (3 sizes; corners stay crisp).
- **Source:** `docs/brief/bad-gui/04-merchant-target.png`, the owner's own generated target
  (`BAD_GUI_2_PANELS.md` §3.1 allows it as source). The original is not edited; the pieces are cut
  and cleaned copies (`scripts/art/slice_target.py`).
- **Not cut** (baked-in text or overlapping the banner): the header with "Farmer Tobb", the banner,
  the coin pile, the item cards, the buttons, the currency pill. They wait for the owner's text-free
  merchant kit sheet (`art/ui/PROMPTS_V3.md` §5).

| # | Piece | Size | Use | Replaces once LIVE |
|---|---|---|---|---|
| 1 | `m_panel_frame` | 440 × 220 | every panel's 9-slice frame (rebuilt from the clean bottom-left corner, mirrored) | `panel` |
| 2 | `m_close_button` | 107 × 107 | round close button | `close_button` |
| 3 | `m_crown` | 54 × 44 | bottom crown ornament | — |
| 4 | `m_coinbag_empty` | 490 × 330 | empty-state illustration ("Select an item to sell") | — |
| 5 | `m_divider` | 404 × 30 | divider line with a sparkle | — |
| 6 | `m_sparkle_gold` | 54 × 59 | sparkle | — |
| 7 | `m_sparkle_white` | 49 × 48 | sparkle | — |
| 8 | `m_sparkle_violet` | 37 × 47 | sparkle | — |

## Safety check (`CLAUDE.md` "Asset safety" rules 1-3)
- [x] No characters of any kind, no faces, no people.
- [x] Nothing suggestive.
- [x] No existing anime, game or franchise character, symbol or signature look (a cart-free frame,
  an X button, a crown, a coin bag, sparkles, a line).
- [x] Not from a REFERENCE-ONLY image.

## After the OK
Upload in two batches (5, then 3), stopping at the first "moderated", "rejected" or 403. Set each
piece's `assetId` and status `LIVE` in `art/ui/kit-v3/kit.json`, run
`python scripts/art/cut_sheet.py luau`, and the frame and close button replace the TEMP `panel`
and `close_button` everywhere they are drawn.
