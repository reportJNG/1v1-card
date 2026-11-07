# UI art prompts, version 2 (route O: optional owner images)

Every slot below already has a finished image made by the pipeline (route B or C, listed in
`art/ui/MANIFEST_V2.json`). These prompts are for the owner if you want a painted upgrade. Rules
for every image:

- Transparent PNG, exactly the size given, nothing outside the shape except its glow.
- Dark navy-violet game UI style (#06061B to #0D0B26), neon glow, glossy bevels, thick dark outlines.
- No characters, logos, text or brands unless a prompt asks for text.
- Save as `art/ui/kit/<slot>.png` (replacing the generated file), then run
  `python scripts/art/manifest.py`, upload, and `python scripts/art/manifest.py ids '<json>'`.

## Card frames (`frame_<n|r|sr|ssr|ur>_<large|medium|small>`, 512 x 704 / 256 x 352 / 128 x 176)
> Ornate trading-card frame for a mobile anime card game, bevelled polished metal in {silver with
> lavender shadows | electric blue | violet-magenta | gold | emerald green}, pointed corner
> flourishes and inward corner blades, a diamond gem at the top and bottom centre, a thin inner
> line, empty transparent window, the card centred with a bleed of 36 px at the sides and 44 px top
> and bottom. Front view, flat, no glow (glow is a separate layer). {plainest | more ornament |
> more | ornate | the most ornate} corners.

## Frame glow and energy (`glow_*`, `energy_*`, same sizes)
> Only the soft outer glow of the frame above, in {colour}, on transparency. / Only crackling
> lightning strokes hugging the frame edges, white core with {colour} halo, on transparency.

## Rarity badges (`badge_<n|r|sr|ssr|ur>_<large|small>`, 256 x 128 / 128 x 64)
> The letters "{N | R | SR | SSR | UR}" in a heavy italic display font, gradient fill in
> {colour} with a white highlight on top, a thick dark outline and a soft glow. Transparent.

## Emblems (`emblem_star_silver`, `emblem_star_blue`, `emblem_star_gold`, `emblem_crown_gold`, 256 x 256)
> A faceted 3D {star | crown with three jewels}, {silver | sapphire blue | gold}, glossy, soft
> glow, front view, transparent.

## Egg pedestals (`pedestal_<common|rare|epic|legendary|godtier>`, 512 x 256)
> A short dark stone ring pedestal seen from slightly above, an emissive {colour} rim and a glowing
> ring on its top face, nothing on it, transparent background.

## HUD buttons (`hud_btn_<red|orange|teal|green|purple|blue|night>`, 128 x 128)
> A chunky rounded-square game button in {colour}, thick dark outline, bevelled, soft inner
> highlight on the top third, darker bottom lip, no icon, transparent.

## Logo (`logo_1v1card`, 1024 x 512)
> The words "1v1 CARD" in a heavy rounded display font, purple-to-pink gradient, thick dark
> stroke, a small gold crown over the "1v1", a soft violet splash behind. Transparent.

## Panels (`panel`, `panel_light`, 256 x 256, 9-slice 56 / 200)
> A rounded game UI panel, {deep navy-indigo | lighter translucent blue-violet glass}, 2 px
> {violet | bright lavender} rim with a soft outer glow, faint highlight along the top edge,
> 14 px corners, centred with a 14 px glow bleed.

## Victory and Defeat banners (`banner_victory`, `banner_defeat`, 1024 x 384)
> A wide ribbon banner with feathered wings on both sides, {gold with a crown on top | cold steel
> grey-blue}, empty centre for text, transparent.
