---
name: 3d-asset-pipeline
description: Producing 3D assets for 1v1 CARD with the Blender MCP and Roblox Studio MCP - characters, rigs, eggs presentation, props, materials, animation and VFX - with Roblox import limits, licensing rules and QA gates. Use for any modelling, texturing, rigging, animation or effects work.
---

# 3D asset pipeline (Blender → Roblox)

Blender is the source of truth. This machine has the portable Blender 5.2.3 LTS at
`C:\Users\Administrator\Tools\blender-5.2.3-windows-x64\blender.exe`, with the "MCP for Blender"
add-on enabled. Open Blender and the add-on's server starts; its tab is in the N panel. Then the
`blender` MCP tools work. Generated meshes or materials (Studio MCP `generate_mesh` /
`generate_material`, Meshy) are starting points only. Every asset gets topology, UV, scale and QA
passes.

## Hard rules
- **Original designs only.** No anime IP, names, silhouettes or signature outfits. The concept
  board is a reference for mood and layout only.
- **The egg icon pack can't be edited or redistributed.** Use the PNGs exactly as supplied, for
  icons only. Don't recolour, trace or convert them to 3D. Any 3D egg must be our own model, and
  hatch effects are separate overlays.
- **Mark it Placeholder** until the owner or an artist approves it: a `Placeholder` attribute on
  the model, plus `ContentStatus`. Only set `Characters[...].assets.model` once it's approved.
- Never upload, publish or spend Robux without the owner. Asset ids come from the owner's uploads.

## Roblox specs
- Scale: 1 stud ≈ 0.28 m. Model in metres with Blender's unit scale at 1. Export FBX with
  "Apply Transform", forward −Z and up Y, then check the size in Studio.
- Characters: an R15-compatible rig (Roblox avatar bone names), up to 10k triangles (heroes),
  one 1024² texture set, and a separate cage/accessory layer if needed.
- Props: up to 2k triangles, sharing a trim sheet or atlas. Collisions use simple `CollisionFidelity`
  (Box or Hull).
- Materials: SurfaceAppearance PBR (Color, Normal, Roughness, Metalness), 512–1024². Emissive
  parts use Neon sparingly.
- Animations: Idle, Attack, Defend, Special, Hit, KO and Victory for each battle character.
  Export from Blender and import with the Animation Editor. Keep them under 2 s, except Idle,
  which loops.
- VFX: ParticleEmitter, Beam and Trail, with textures from licensed sources (Poly Haven CC0, or our
  own). Respect `settings.reducedMotion`.

## Workflow per asset
1. Write a brief: role, rarity, family, silhouette and colour palette from the design system
   (purple/blue/gold on navy). Don't use rarity colour alone; the card UI shows the rarity name
   too.
2. Block out in Blender, then use `screen_capture` / viewport renders to compare against the brief.
3. Retopology and UVs, then bake or texture. Check the triangle count.
4. Export, then import in Studio (Studio MCP `insert_asset` or a local import). Check scale, pivot,
   rig and materials in the live place.
5. QA, all four: a front/side/back capture, the count against budget, a mobile emulator look,
   and a Placeholder mark until approved.

## What can be produced here vs needs an artist
Blockouts, props, environment pieces, stylised eggs (our own), VFX and simple rigs: yes. Final
hero characters at anime quality need an artist's pass. Say so, and ship them clearly marked
Placeholder.
