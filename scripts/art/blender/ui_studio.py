"""The Blender UI studio (CARDS_EGGS_MISSION section 3, route B).

Builds art/blender/ui_studio.blend: fixed cameras per asset type, a three-point light rig, a dark
world (film transparent for export), and the builders for every 3D-looking UI asset: emblems
(star, crown), the 5 tier eggs and 24 themed eggs, pedestals and shards. All renders come from
this one scene so every asset is lit the same way. Glows are added afterwards in 2D
(scripts/art/egg_kit.py) so they stay consistent with the card kit.

Run headless (batch):
  blender -b --factory-startup --python scripts/art/blender/ui_studio.py -- <command> [args]
commands:
  save                      build the studio scene and save art/blender/ui_studio.blend
  emblems                   render art/ui/kit/raw/emblem_*.png
  eggs [ids...]             render art/ui/kit/raw/egg_<id>.png (+ _ped pedestal shots)
  shards                    render art/ui/kit/raw/shard_<tier>_<n>.png
  meshes                    export art/eggs/meshes/egg_<tier>.fbx (< 5k triangles)
Or exec() it inside a live Blender to build interactively (functions only, no command).
"""
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RAW = os.path.join(ROOT, "art", "ui", "kit", "raw")


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


# ------------------------------------------------------------------ scene


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def clear_objects(keep=("Cam", "Key", "Fill", "Rim", "Rim2")):
    for o in list(bpy.data.objects):
        if o.name not in keep:
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        if m.users == 0:
            bpy.data.meshes.remove(m)
    for c in list(bpy.data.curves):
        if c.users == 0:
            bpy.data.curves.remove(c)


def setup(res=(512, 512)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
    except TypeError:
        pass
    sc.eevee.taa_render_samples = 64
    try:
        sc.eevee.use_raytracing = True
    except AttributeError:
        pass
    # Studio environment for reflections (film is transparent, so it never shows): a dark floor,
    # a bright soft-box band above the horizon and a violet sky, so metals and gloss read.
    w = bpy.data.worlds.get("Studio") or bpy.data.worlds.new("Studio")
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        if n.type not in ("BACKGROUND", "OUTPUT_WORLD"):
            nt.nodes.remove(n)
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    cr = ramp.color_ramp
    cr.elements[0].position = 0.0
    cr.elements[0].color = hexc("#0A0818")
    cr.elements[1].position = 1.0
    cr.elements[1].color = hexc("#4A3A8C")
    e = cr.elements.new(0.52)
    e.color = hexc("#2A2050")
    e = cr.elements.new(0.62)
    e.color = hexc("#FFFFFF")
    e = cr.elements.new(0.72)
    e.color = hexc("#8C7CD8")
    nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs[0])
    bg.inputs[1].default_value = 1.6
    sc.world = w

    cam = bpy.data.objects.get("Cam")
    if not cam:
        cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam

    def light(name, kind, loc, energy, color, size=2.0):
        o = bpy.data.objects.get(name)
        if not o:
            o = bpy.data.objects.new(name, bpy.data.lights.new(name, kind))
            sc.collection.objects.link(o)
        o.location = loc
        o.data.energy = energy
        o.data.color = color[:3]
        if kind == "AREA":
            o.data.size = size
        direction = Vector((0, 0, 0.9)) - o.location
        o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return o

    # Three-point rig (+ a second rim): key top-left front, cool fill right, two coloured rims.
    light("Key", "AREA", (-3.2, -4.2, 4.2), 900, hexc("#FFF4E8"), 3.0)
    light("Fill", "AREA", (4.0, -3.0, 1.2), 260, hexc("#B8C8FF"), 4.0)
    light("Rim", "AREA", (2.6, 3.4, 3.2), 700, hexc("#B57BFF"), 2.0)
    light("Rim2", "AREA", (-2.8, 3.0, 0.6), 420, hexc("#6CB8FF"), 2.0)
    return sc


def camera(kind):
    """Fixed camera per asset type."""
    cam = bpy.data.objects["Cam"]
    sc = bpy.context.scene
    if kind == "emblem":
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 2.2
        cam.location = (0, -6, 0)
        cam.rotation_euler = (math.radians(90), 0, 0)
        sc.render.resolution_x, sc.render.resolution_y = 512, 512
    elif kind == "egg":
        cam.data.type = "PERSP"
        cam.data.lens = 85
        cam.location = (0, -9.2, 2.35)
        cam.rotation_euler = (math.radians(82.5), 0, 0)
        sc.render.resolution_x, sc.render.resolution_y = 512, 512
    elif kind == "pedestal":
        cam.data.type = "PERSP"
        cam.data.lens = 85
        cam.location = (0, -10.4, 3.4)
        cam.rotation_euler = (math.radians(78.5), 0, 0)
        sc.render.resolution_x, sc.render.resolution_y = 512, 640
    elif kind == "shard":
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = 1.0
        cam.location = (0, -6, 0)
        cam.rotation_euler = (math.radians(90), 0, 0)
        sc.render.resolution_x, sc.render.resolution_y = 128, 128


def render(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# ------------------------------------------------------------------ materials


def principled(name, base, metallic=0.0, rough=0.3, coat=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = hexc(base)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Coat Weight"].default_value = coat
    if emit:
        bsdf.inputs["Emission Color"].default_value = hexc(emit)
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def link(nt, a, b):
    nt.links.new(a, b)


def shell_material(name, base, base2, crack, crack_strength, rough=0.16, metallic=0.15, scale=3.2,
                   crack_width=0.035, spots=None, stripes=None, split=None):
    """Glossy crystal-cracked shell: Voronoi cells vary between two base colours; the cell edges
    are recessed cracks that glow in the tier colour. Optional spots / stripes / two-tone split."""
    m = bpy.data.materials.get(name)
    if m:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = scale
    vor.inputs["Randomness"].default_value = 0.9
    link(nt, tc.outputs["Object"], vor.inputs["Vector"])
    cells = nt.nodes.new("ShaderNodeTexVoronoi")
    cells.feature = "F1"
    cells.inputs["Scale"].default_value = scale
    cells.inputs["Randomness"].default_value = 0.9
    link(nt, tc.outputs["Object"], cells.inputs["Vector"])
    # crack mask: 1 on the edges
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (1, 1, 1, 1)
    ramp.color_ramp.elements[1].position = crack_width
    ramp.color_ramp.elements[1].color = (0, 0, 0, 1)
    link(nt, vor.outputs["Distance"], ramp.inputs["Fac"])
    # cell colour variation
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = hexc(base)
    mix.inputs["B"].default_value = hexc(base2)
    link(nt, cells.outputs["Color"], mix.inputs["Factor"])
    color_out = mix.outputs["Result"]
    if split:
        # two-tone shell split by X (AngelDemon): left colour A, right colour B
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        link(nt, tc.outputs["Object"], sep.inputs["Vector"])
        gt = nt.nodes.new("ShaderNodeMath")
        gt.operation = "GREATER_THAN"
        gt.inputs[1].default_value = 0.0
        link(nt, sep.outputs["X"], gt.inputs[0])
        mix2 = nt.nodes.new("ShaderNodeMix")
        mix2.data_type = "RGBA"
        link(nt, gt.outputs[0], mix2.inputs["Factor"])
        link(nt, color_out, mix2.inputs["A"])
        mix2.inputs["B"].default_value = hexc(split)
        color_out = mix2.outputs["Result"]
    if spots:
        dots = nt.nodes.new("ShaderNodeTexVoronoi")
        dots.feature = "F1"
        dots.inputs["Scale"].default_value = spots[1]
        dots.inputs["Randomness"].default_value = 0.6
        link(nt, tc.outputs["Object"], dots.inputs["Vector"])
        dr = nt.nodes.new("ShaderNodeValToRGB")
        dr.color_ramp.elements[0].position = 0.22
        dr.color_ramp.elements[0].color = (1, 1, 1, 1)
        dr.color_ramp.elements[1].position = 0.26
        dr.color_ramp.elements[1].color = (0, 0, 0, 1)
        link(nt, dots.outputs["Distance"], dr.inputs["Fac"])
        mix3 = nt.nodes.new("ShaderNodeMix")
        mix3.data_type = "RGBA"
        link(nt, dr.outputs["Color"], mix3.inputs["Factor"])
        link(nt, color_out, mix3.inputs["A"])
        if spots[0] == "random":
            link(nt, dots.outputs["Color"], mix3.inputs["B"])
        else:
            mix3.inputs["B"].default_value = hexc(spots[0])
        color_out = mix3.outputs["Result"]
    if stripes:
        wave = nt.nodes.new("ShaderNodeTexWave")
        wave.inputs["Scale"].default_value = stripes[1]
        wave.inputs["Distortion"].default_value = 0.0
        link(nt, tc.outputs["Object"], wave.inputs["Vector"])
        wr = nt.nodes.new("ShaderNodeValToRGB")
        wr.color_ramp.elements[0].position = 0.45
        wr.color_ramp.elements[1].position = 0.5
        link(nt, wave.outputs["Fac"], wr.inputs["Fac"])
        mix4 = nt.nodes.new("ShaderNodeMix")
        mix4.data_type = "RGBA"
        link(nt, wr.outputs["Color"], mix4.inputs["Factor"])
        link(nt, color_out, mix4.inputs["A"])
        mix4.inputs["B"].default_value = hexc(stripes[0])
        color_out = mix4.outputs["Result"]
    # cracks: base colour darkened in the crack, emission in the tier colour
    dark = nt.nodes.new("ShaderNodeMix")
    dark.data_type = "RGBA"
    link(nt, ramp.outputs["Color"], dark.inputs["Factor"])
    link(nt, color_out, dark.inputs["A"])
    dark.inputs["B"].default_value = hexc(crack)
    link(nt, dark.outputs["Result"], bsdf.inputs["Base Color"])
    link(nt, ramp.outputs["Color"], bsdf.inputs["Emission Strength"])
    bsdf.inputs["Emission Color"].default_value = hexc(crack)
    em = nt.nodes.new("ShaderNodeMath")
    em.operation = "MULTIPLY"
    em.inputs[1].default_value = crack_strength
    link(nt, ramp.outputs["Color"], em.inputs[0])
    link(nt, em.outputs[0], bsdf.inputs["Emission Strength"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.45
    bump.inputs["Distance"].default_value = 0.04
    link(nt, ramp.outputs["Color"], bump.inputs["Height"])
    bump.invert = True
    link(nt, bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Coat Weight"].default_value = 0.7
    bsdf.inputs["Coat Roughness"].default_value = 0.05
    return m


# ------------------------------------------------------------------ meshes


def mesh_from_outline(name, pts2d, depth, bevel):
    """Extrude a closed 2D outline (x, z) along Y with a bevel: emblems and crowns."""
    me = bpy.data.meshes.new(name)
    n = len(pts2d)
    verts = [(x, -depth / 2, z) for x, z in pts2d] + [(x, depth / 2, z) for x, z in pts2d]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = bevel
    bv.segments = 4
    bv.limit_method = "ANGLE"
    for p in me.polygons:
        p.use_smooth = False
    return o


def star_outline(r=1.0, inner=0.48, n=5):
    pts = []
    for i in range(2 * n):
        rr = r if i % 2 == 0 else r * inner
        a = math.pi / 2 + i * math.pi / n
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return pts


def crown_outline(w=1.0, h=0.8):
    """A five-point crown: band at the bottom, three tall points and two short ones."""
    return [
        (-w, -h * 0.55), (w, -h * 0.55), (w * 1.02, h * 0.55), (w * 0.62, h * 0.08),
        (w * 0.38, h * 0.62), (0.0, h * 0.05), (0.0, h * 0.05), (-w * 0.38, h * 0.62),
        (-w * 0.62, h * 0.08), (-w * 1.02, h * 0.55),
    ]


def crown_outline_clean():
    pts = crown_outline()
    out = []
    for p in pts:
        if not out or (abs(out[-1][0] - p[0]) > 1e-6 or abs(out[-1][1] - p[1]) > 1e-6):
            out.append(p)
    # middle point higher
    out[5] = (0.0, 0.8)
    out.insert(5, (0.18, 0.12))
    out.insert(7, (-0.18, 0.12))
    return out


def domed(name, pts2d, depth, dome):
    """A faceted, domed emblem: the outline extruded back, with its front rising to a centre point
    (like a cut gem), so each point has a lit and a shaded facet."""
    me = bpy.data.meshes.new(name)
    n = len(pts2d)
    verts = [(x, 0.0, z) for x, z in pts2d] + [(x, depth, z) for x, z in pts2d] + [(0.0, -dome, 0.0)]
    c = 2 * n
    faces = [list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i][::-1])
        faces.append([j, i, c])
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    bv = o.modifiers.new("Bevel", "BEVEL")
    bv.width = 0.02
    bv.segments = 2
    bv.limit_method = "ANGLE"
    bv.angle_limit = math.radians(40)
    bv.use_clamp_overlap = True
    return o


def crown(name, scale=1.0, mat=None, jewel=None):
    """Five-point crown: a domed, faceted body (like the stars), balls on the points, and a band
    of gems across the base."""
    pts = [
        (-1.0, -0.5), (1.0, -0.5), (1.05, 0.62), (0.6, 0.12), (0.36, 0.72), (0.14, 0.2),
        (0.0, 0.9), (-0.14, 0.2), (-0.36, 0.72), (-0.6, 0.12), (-1.05, 0.62),
    ]
    o = domed(name, pts, 0.3, 0.22)
    o.scale = (scale, scale, scale)
    if mat:
        o.data.materials.append(mat)
    for x, z, r in [(1.05, 0.62, 0.13), (-1.05, 0.62, 0.13), (0.0, 0.9, 0.15), (0.36, 0.72, 0.11), (-0.36, 0.72, 0.11)]:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, -0.04, z + r * 0.7))
        b = bpy.context.active_object
        if mat:
            b.data.materials.append(mat)
        b.parent = o
    # the band: a raised strip with three gems
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.1, -0.33))
    band = bpy.context.active_object
    band.scale = (2.02, 0.22, 0.3)
    bv = band.modifiers.new("Bevel", "BEVEL")
    bv.width = 0.04
    bv.segments = 3
    if mat:
        band.data.materials.append(mat)
    band.parent = o
    if jewel:
        for x, r in [(0.0, 0.15), (0.55, 0.1), (-0.55, 0.1)]:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(x, -0.24, -0.33))
            g = bpy.context.active_object
            g.scale = (1, 0.6, 1)
            g.data.materials.append(jewel)
            g.parent = o
    return o


def star(name, scale=1.0, mat=None):
    o = domed(name, star_outline(), 0.25, 0.32)
    o.scale = (scale, scale, scale)
    if mat:
        o.data.materials.append(mat)
    return o


# ------------------------------------------------------------------ emblems

GOLD = dict(base="#FFC23A", metallic=1.0, rough=0.22)


def emblems():
    """Star (silver, blue) and crown (gold) emblems, front view, transparent."""
    setup()
    camera("emblem")
    out = {}
    specs = {
        "emblem_star_silver": ("star", principled("StarSilver", "#E8E4FF", 1.0, 0.18, emit="#CFC8FF", strength=0.4)),
        "emblem_star_blue": ("star", principled("StarBlue", "#4AA8FF", 0.7, 0.14, emit="#1E8CFF", strength=0.9)),
        "emblem_star_gold": ("star", principled("StarGold", "#FFC23A", 1.0, 0.2, emit="#FF9A00", strength=0.5)),
        "emblem_crown_gold": ("crown", principled("CrownGold", "#FFC23A", 1.0, 0.22, emit="#FF9A00", strength=0.35)),
    }
    for name, (shape, mat) in specs.items():
        clear_objects()
        if shape == "star":
            o = star(name, 0.95, mat)
            o.rotation_euler = (0, 0, 0)
        else:
            o = crown(name, 0.9, mat, jewel=principled("Ruby", "#FF2850", 0.0, 0.05, emit="#FF2850", strength=1.5))
            o.location = (0, 0, -0.08)
        # tilt slightly toward the key light for a lit bevel
        o.rotation_euler = (math.radians(-6), 0, 0)
        path = os.path.join(RAW, f"{name}.png")
        render(path)
        out[name] = path
    return out


# ------------------------------------------------------------------ main

if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    cmd = args[0] if args else "save"
    reset()
    setup()
    if cmd == "emblems":
        print(emblems())
    elif cmd == "save":
        os.makedirs(os.path.join(ROOT, "art", "blender"), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "blender", "ui_studio.blend"))
