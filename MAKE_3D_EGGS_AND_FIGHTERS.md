# MAKE 3D: eggs on pedestals + 3D fighters vs the Guardian

The owner asked for this on 2026-11-11.
- **Screenshot:** `docs/brief/bad-gui/25-eggs-flat-2d-on-pedestals.png`.
- **Rules:** asset safety and the UI rules in `CLAUDE.md` apply to every model, texture and render.

---

## 1. Eggs: real 3D eggs (lobby egg pagoda + world egg stands)

**Now:** each egg is a flat 2D icon standing on a blurry white glowing disc. It looks like a
sticker, not an object.

**Make them in Blender ourselves.** An egg is a simple shape, so don't download one. Our own meshes
also keep the icon-pack licence safe: it forbids editing its images, so its PNGs are **not**
wrapped onto the 3D eggs. The 2D icons stay in the UI only.

- **One base mesh:** a smooth egg shape (a UV sphere stretched about 1.3× on Z and narrower at the
  top), about 1,500 triangles.
- **24 variants** (`Eggs.RequiredIds`): our own toon-shaded take on each egg's theme, with the
  details modelled, not painted flat:
  - Basic: plain
  - Spotted: raised spots
  - Cracked: crack lines + a chipped hole with glow inside
  - Cat / Dog: ears + a tail
  - Coconut: husk fibres
  - Sandcastle: little towers
  - Royal: a crown + gems
  - Ice: crystal shards
  - Yeti: fur tufts
  - Mine: a pickaxe + ore
  - Dragon: scales + small horns
  - Kraken: tentacles wrapped round it
  - Demon: horns + a dark glow
  - Angel: wings + a halo
  - AngelDemon: one wing of each
  - Dominus: a hood-like crest
  - Legendary / Mythical: a gold trim + an aura
  - Party: a confetti pattern + a party hat
  - Rainbow: stripes
  - Glitched: offset voxel chunks
  - Black Hole: a swirl + a dark core
  - Secret: a "?" rune
- **Golden:** the same mesh with a gold PBR material and sparkle. It's not a new model.
- **Materials:** toon look with a thick dark outline (an inverted-hull mesh). Bake to one 512 px
  texture per egg and export FBX → MeshPart (SurfaceAppearance if needed).
- **Pedestal:**
  - Replace the white glow disc with a **rarity-coloured** stone pedestal: a carved rim and a thin
    glowing ring in the rarity colour.
  - The egg floats slowly and spins above it, with sparkle particles for Legendary and above.
  - Above the egg: a billboard with the egg icon, its name in big outlined text, and the price
    (coin icon + number). Put it **above the egg, not behind it**, because coins currently overlap
    other eggs in the screenshot.
- **Hatch animation:** use the same 3D egg (shake → cracks glow → burst → card reveal).

## 2. Characters: 3D fighters that fight the Guardian

**New design (owner):** in Guardian Trials, the player's **3 deck characters appear as 3D fighters
in the arena** and fight a 3D Guardian. Cards stay as the collection and deck. The cards decide who
fights; the 3D models are what you see.
- The battle rules don't change (Attack / Defend / Special, simultaneous picks, server
  authoritative). Only the presentation changes.
- **PvP 1v1 keeps the card battle screen** unless the owner says otherwise. Log that question in
  `WAITING_ON_YOU.md`.
- Optional, after Trials work: the equipped lead character stands at the lobby spawn and on the
  main menu stage.

### How to build them (Roblox-native, matches the art)

Our art is already **Roblox R15 proportions drawn in anime style**, so the 3D fighters use the
standard **R15 rig**, which is free and built into Roblox. Its animations, the Animation Editor and
HumanoidDescription all just work. Blender only makes the parts that give each character an identity:
- **Hair:** a sculpted, chunky, low-poly mesh in the character's hair colour.
- **Outfit:** a coat, armour plates, scarf, cape, chains or fur collar, as layered meshes on the R15
  parts. Shirt and pants textures for the base clothes.
- **Weapon or effect prop:** for example an ice lance, a forge hammer, glowing orbs.
- **Face:** a decal with determined or confident eyes and a closed mouth. No blush or tears.
- **Budget:** 12k triangles or fewer per character, 1–2 textures of 1024 px or less, toon shading +
  an outline.

Model only the **approved** characters (`NEW_ASSETS_LEVEL1.md`), and follow the approved images as
the design reference:
- **First wave:** Rook Emberforge, Halvard Frostwarden, Nox Veilstrider, Kael Voidbinder, Brann
  Cinderfall, Aurex Sunforge.
- **Not modelled until the owner approves their art:** Solaris, Zephyr Volt, and every HOLD_* file.

**The Guardian:** an original, bigger boss rig, 1.8× scale, armoured stone-and-light golem knight, one
colour theme per world. It's built in Blender as a custom rig or a scaled R15. It must not look like
any existing game boss.

**Animations** (Roblox Animation Editor or Blender → FBX), per action:
- **Idle:** breathing, weapon ready.
- **Attack:** a dash and a strike.
- **Defend:** guard up, and a parry flash when it blocks a Special.
- **Special:** a charge, then the element effect (ice, fire, shadow, light…).
- **Hit:** a knockback with an effect.
- **KO:** falls and dissolves into element particles.
- **Win pose.**

Hits and KOs are shown with effects and body motion, **never pained faces** (CLAUDE.md rule 2).

### Free 3D assets: allowed only like this

Look for free models first, but use one only if **all** of these hold:
1. **The licence is written on the download page and allows commercial use:** CC0, or CC-BY with
   credit added to `docs/ASSETS.md`.
   - **Places to check:** Quaternius, Kenney, Poly Pizza, Sketchfab (filter "Downloadable" + CC0 /
     CC-BY), OpenGameArt, itch.io (read each pack's licence).
   - **Skip:** anything with no licence, "personal use only", "NC", or ripped game models.
2. **It isn't an existing anime, game or franchise character or its signature look.** Free "anime
   hair" packs are often copies of famous characters, so check each one.
3. **It's generic:** weapons, rocks, props, VFX textures, base meshes to edit. **Character identity
   (hair, outfit) is always made in Blender by us.**
4. **Not from the Roblox Creator Store or catalog:** no Creator Store models or UGC items by other
   users. They carry unknown IP and sometimes hidden scripts.

If nothing passes, make it in Blender. **Expected result:** eggs and fighters made by us, with free
CC0 props and weapons where they fit.

## 3. Review gate (same as all art)
- **Character renders:** for each character, front / 3/4 / back renders of the model and a GIF of
  the attack go on a contact sheet: `docs/review/3d_fighters.png`.
- **Egg renders:** all 24 eggs plus Golden go on `docs/review/3d_eggs.png`.
- **Owner OK:** wait for a written OK, then upload meshes, textures and animations in batches of 5
  or fewer. Stop at the first moderated, rejected or 403 result.

## 4. Checklist
- [ ] 24 3D eggs + Golden variant, reviewed and approved, on the new rarity pedestals, with a floating
  billboard (icon, name, price) that doesn't overlap
- [ ] Hatch animation uses the 3D egg
- [ ] 6 approved fighters as R15 + Blender parts, plus the Guardian, reviewed and approved
- [ ] The animation set for each (idle, attack, defend/parry, special, hit, KO, win)
- [ ] Guardian Trials show the 3 deck fighters in 3D vs the Guardian. Battle logic unchanged, tests
  still pass.
- [ ] Every free asset has its licence and source in `docs/ASSETS.md`
- [ ] Performance: 60 fps on desktop and 30+ on mid phones during a Trial (7 rigs + effects)
- [ ] Before/after screenshots `docs/screens/roblox-ui/compare_eggs3d.png` and
  `compare_trial3d.png`, scored 8+
- [ ] Tests and lint clean. Committed and pushed with named paths only.
