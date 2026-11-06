---
name: world-building-lighting
description: Building and lighting the 10 worlds of 1v1 CARD - the data-driven layout, node and NPC placement rules, terrain/props passes in Studio, per-world lighting and atmosphere, and performance limits. Use for any world, map, terrain, lighting or environment work.
---

# Worlds and lighting

## Data first
- `Config/WorldLayouts`: per world, the theme (ground, accent, material, sky), 2–3 resources
  (node count, respawn, yield, rare drop) and the merchant's name.
- `Domain/WorldLayout`: the **only** source of positions (spawn, merchant, Guardian and nodes).
  The server's harvest range check (12 studs) and merchant check (16 studs) use the same numbers
  as the builder. Never move a node in Studio by hand. Change the layout data and rebuild.
- `Server/World/WorldBuilder`: builds `workspace.Worlds.World1..10` as a blockout. Every part has
  `Placeholder = true`. Worlds sit 2,000 studs apart on X, and each play area is 360 studs.

## Art passes (keep the gameplay positions fixed)
1. Terrain (Studio MCP `execute_luau` or terrain tools): sculpt around the 360-stud area. Keep the
   node rings (radii 40/80/120 around z −60) and the spawn/NPC plaza (z 100–130) walkable and
   readable.
2. Set dressing: themed props per world (Green Plains, Enchanted Forest, Desert Kingdom, Frozen
   Lands, Volcano, Demon Realm, Celestial Islands, Ancient Kingdom, Shadow Dimension, Divine
   World). These are original designs: no copied landmarks or IP.
3. Nodes: swap the blockout cubes and spheres for themed meshes, keeping the `NodeId` / `ItemId`
   attributes and the `Harvest` ProximityPrompt.
4. Lighting: `Lighting.Technology = Future` on desktop, with Atmosphere, Sky and ColorCorrection
   per world (theme `sky` colour). Switch on the client when the `World` player attribute
   changes. Use Bloom for neon accents, but keep it subtle on mobile.

## Rules
- Readability first: from the spawn, the merchant (gold) and the Guardian (purple) must be visible.
- Up to about 200 parts per world, all anchored. Reuse meshes, and use StreamingEnabled-friendly
  models (a Model plus a PrimaryPart).
- Mark anything that isn't final art as Placeholder, and update `ContentStatus.worldArt` only when
  final.
- Verify in Studio with the boot check (worlds=10, nodes=130 with the current data), then fly
  through each world and capture a screenshot through the Studio MCP.
