"""Our own 3D eggs (MAKE_3D_EGGS_AND_FIGHTERS.md section 1), built in Blender from one base egg.

Run inside Blender (the MCP's execute_blender_code, or Blender's text editor):
    exec(open(r"<repo>/scripts/blender/eggs.py").read()); build_all(); render_all()

- One base egg: a UV sphere stretched 1.3x on Z and narrower at the top, 1,520 triangles.
- 24 themed variants (Config/Eggs RequiredIds) with modelled details, never the icon pack's images
  (its licence forbids editing them; the 2D icons stay in the UI only).
- Toon look: a 3-step colour ramp on the diffuse light and a thick dark outline (an inverted hull,
  Solidify with flipped normals), which exports as part of the mesh.
- Golden: the same meshes with the gold material (not a new model).
Renders go to art/3d/renders/eggs/<id>.png for docs/review/3d_eggs.png. Nothing is uploaded here.
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Vector, Matrix

REPO = r"C:\Users\Administrator\work\1v1card"
OUT = os.path.join(REPO, "art", "3d", "renders", "eggs")
H = 1.0  # egg height in metres (about 3.6 studs)
R = H / 2 / 1.3  # base sphere radius before the 1.3x stretch
SPACING = 2.4

EGGS = [
    "basic", "spotted", "cracked", "cat", "dog", "rainbow", "sandcastle", "coconut", "royal", "ice",
    "yeti", "mine", "dragon", "demon", "angel", "kraken", "dominus", "legendary", "glitched",
    "black_hole", "secret", "angel_demon", "mythical", "party",
]
GOLDEN = ["basic", "cat", "dragon", "royal"]

# body colour, accent colour per egg (our own palette; not sampled from the icon pack)
PALETTE = {
    "basic": ("#F4EBDD", "#D9C7AE"), "spotted": ("#FFE7B8", "#E07A3A"), "cracked": ("#E8DCC8", "#FFB43C"),
    "cat": ("#F2A65A", "#FFE1C4"), "dog": ("#C8935C", "#6E4428"), "rainbow": ("#FF5A6E", "#FFFFFF"),
    "sandcastle": ("#EBCB8B", "#C79A55"), "coconut": ("#7A4A2A", "#D9B07A"), "royal": ("#6A3DD8", "#FFC93C"),
    "ice": ("#A9E6FF", "#E9FBFF"), "yeti": ("#E9F2FF", "#9EC6E8"), "mine": ("#7C7F8C", "#9B6B3D"),
    "dragon": ("#2FA35B", "#F2D35B"), "demon": ("#7A1630", "#1C0B14"), "angel": ("#FFF8EC", "#FFD86B"),
    "kraken": ("#2C6E9E", "#E0607A"), "dominus": ("#1F2347", "#F2C14E"), "legendary": ("#FF9F1C", "#FFE27A"),
    "glitched": ("#2B2E4A", "#FF3EA5"), "black_hole": ("#120C24", "#A35BFF"), "secret": ("#2A2633", "#7DF9FF"),
    "angel_demon": ("#FFF8EC", "#3A0F22"), "mythical": ("#16C27D", "#FFE27A"), "party": ("#7B5CFF", "#FFD23F"),
}


def hexc(h, a=1.0):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    # sRGB -> linear for node colours
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return (c[0], c[1], c[2], a)


# ---------------------------------------------------------------- materials
_MATS = {}


def toon(name, color, glow=0.0, metal=False):
    """A toon material: diffuse light through a constant 3-step ramp, with optional glow."""
    key = (name, color, glow, metal)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new(f"Toon_{name}")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    base = Vector(hexc(color)[:3])
    if glow > 0:
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = hexc(color)
        em.inputs["Strength"].default_value = glow
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    else:
        # toon light from one fixed key direction (upper left, towards the camera): N.L -> 3 bands.
        # Deterministic in any engine, and it bakes the same way for Roblox.
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = Vector((-0.45, -0.65, 0.62)).normalized()
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        el = ramp.color_ramp.elements
        dark = base * (0.62 if not metal else 0.5)
        # the lit band keeps the colour's hue (a grey sheen on black cloth looked like plastic)
        lum = 0.2126 * base.x + 0.7152 * base.y + 0.0722 * base.z
        light = base.lerp(Vector((1, 1, 1)), (0.3 if not metal else 0.38) * min(1.0, lum * 2.5))
        if lum < 0.12:
            light = base * 1.9 + Vector((0.012, 0.012, 0.02))
        el[0].position, el[0].color = 0.0, (*dark, 1)
        el[1].position, el[1].color = 0.38, (*base, 1)
        e3 = el.new(0.86)
        e3.color = (*light, 1)
        em = nt.nodes.new("ShaderNodeEmission")
        rng = nt.nodes.new("ShaderNodeMapRange")  # dot in -1..1 -> 0..1
        rng.inputs["From Min"].default_value = -1.0
        nt.links.new(geo.outputs["Normal"], dot.inputs[0])
        nt.links.new(dot.outputs["Value"], rng.inputs["Value"])
        nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], em.inputs["Color"])
        em.inputs["Strength"].default_value = 1.0
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    m.diffuse_color = hexc(color)
    _MATS[key] = m
    return m


def outline_mat():
    if "Outline" in bpy.data.materials:
        return bpy.data.materials["Outline"]
    m = bpy.data.materials.new("Outline")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = hexc("#120C24")
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    m.use_backface_culling = True
    m.diffuse_color = hexc("#120C24")
    return m


def gold_mat():
    return toon("gold", "#FFC21A", metal=True)


def glass_mat(name, color, alpha=0.35, strength=2.0):
    m = bpy.data.materials.new(f"Glow_{name}")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = hexc(color)
    em.inputs["Strength"].default_value = strength
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs["Fac"].default_value = alpha
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    try:
        m.surface_render_method = "BLENDED"
    except Exception:
        pass
    return m


# ---------------------------------------------------------------- mesh helpers
def link(obj, coll):
    for c in obj.users_collection:
        c.objects.unlink(obj)
    coll.objects.link(obj)


def finish(obj, mat, coll, parent, outline=0.012, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    if smooth and obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = True
    if outline and obj.type == "MESH":
        obj.data.materials.append(outline_mat())
        mod = obj.modifiers.new("Outline", "SOLIDIFY")
        mod.thickness = outline
        mod.offset = 1.0
        mod.use_flip_normals = True
        mod.use_rim = False
        mod.material_offset = 1
    link(obj, coll)
    if parent is not None:
        # keep the object's own location/rotation/scale (its matrix_world may not be updated yet)
        obj.parent = parent
        obj.matrix_parent_inverse = parent.matrix_world.inverted()
    obj["Egg"] = parent.name if parent is not None else obj.name
    return obj


def sphere(loc, scale, seg=10, rings=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    return o


def ico(loc, r, sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc)
    return bpy.context.active_object


def cone(loc, r1, r2, depth, verts=12):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc)
    return bpy.context.active_object


def cyl(loc, r, depth, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc)
    return bpy.context.active_object


def cube(loc, size):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = size
    return o


def torus(loc, R_, r, maj=32, mino=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=R_, minor_radius=r, major_segments=maj, minor_segments=mino,
                                     location=loc)
    return bpy.context.active_object


def aim(obj, normal, roll=0.0):
    """Point the object's +Z along `normal`."""
    q = Vector((0, 0, 1)).rotation_difference(normal.normalized())
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = q @ Matrix.Rotation(roll, 4, "Z").to_quaternion()


def curve(points, depth, coll, name="Curve"):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = depth
    cu.bevel_resolution = 1
    sp = cu.splines.new("POLY")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        rad = p[3] if len(p) > 3 else 1.0
        sp.points[i].co = (p[0], p[1], p[2], 1)
        sp.points[i].radius = rad
    sp.use_smooth = True
    ob = bpy.data.objects.new(name, cu)
    coll.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return bpy.context.active_object


# ---------------------------------------------------------------- the base egg
def base_egg(name, loc, coll):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=R, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    me = o.data
    zmax = R * 1.3
    for v in me.vertices:
        z = v.co.z * 1.3
        t = max(z, 0) / zmax
        s = 1 - 0.17 * t ** 1.3  # narrower at the top
        if z < 0:
            s *= 1 + 0.03 * (-z / zmax)
        v.co.x *= s
        v.co.y *= s
        v.co.z = z + zmax  # sits on its base: z from 0 to H
    o.location = loc
    return o


class Surf:
    """Points on the egg's surface by direction (raycast from outside towards the egg's centre)."""

    def __init__(self, egg):
        self.egg = egg
        self.c = Vector((0, 0, H / 2))

    def at(self, direction, height=None):
        d = Vector(direction).normalized()
        c = self.c.copy()
        if height is not None:
            c.z = height * H
            d.z = 0
            d.normalize()
        hit, loc, nrm, _ = self.egg.ray_cast(c + d * 5, -d)
        if not hit:
            return self.egg.matrix_world @ c, d
        return self.egg.matrix_world @ loc, (self.egg.matrix_world.to_3x3() @ nrm).normalized()

    def sph(self, az, el):
        """Azimuth/elevation in degrees (az 0 = front, -Y)."""
        a, e = math.radians(az), math.radians(el)
        return self.at((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))


# ---------------------------------------------------------------- features
def feat_spotted(s, ctx):
    rnd = random.Random(2)
    for i in range(14):
        p, n = s.sph(rnd.uniform(0, 360), rnd.uniform(-45, 60))
        o = sphere(p, (0.075 + rnd.random() * 0.03, 0.075 + rnd.random() * 0.03, 0.035))
        aim(o, n)
        ctx.add(o, ctx.accent)


def feat_cracked(s, ctx):
    pts = []
    for i, (az, el) in enumerate([(-40, 55), (-25, 40), (-38, 25), (-18, 12), (-30, -2), (-12, -15)]):
        p, n = s.sph(az, el)
        pts.append((*(p + n * 0.004), 1.0))
    ctx.add(curve(pts, 0.016, ctx.coll, "Crack"), ctx.accent, glow=3.0, outline=0)
    pts = []
    for az, el in [(30, 50), (18, 34), (32, 18), (20, 4)]:
        p, n = s.sph(az, el)
        pts.append((*(p + n * 0.004), 0.8))
    ctx.add(curve(pts, 0.014, ctx.coll, "Crack2"), ctx.accent, glow=3.0, outline=0)
    # the chipped hole with a glow inside
    p, n = s.sph(10, 62)
    hole = sphere(p - n * 0.02, (0.11, 0.11, 0.05))
    aim(hole, n)
    ctx.add(hole, ctx.accent, glow=4.0, outline=0)
    for k in range(5):
        a = k / 5 * math.tau
        q = p + Vector((math.cos(a), math.sin(a), 0)) * 0.13
        ch = cone(q, 0.04, 0.0, 0.07, 6)
        aim(ch, n)
        ctx.add(ch, ctx.body, smooth=False)


def ears(s, ctx, kind):
    for side in (-1, 1):
        if kind == "cat":
            # flat pointed ears leaning out, with a pink inner ear in front
            p, n = s.sph(side * 32, 58)
            e = cone(p + Vector((0, 0, 0.06)), 0.1, 0.0, 0.22, 16)
            e.scale = (1, 0.42, 1)
            e.rotation_euler = (0, side * math.radians(24), 0)
            ctx.add(e, ctx.body)
            i = cone(p + Vector((side * 0.006, -0.035, 0.06)), 0.06, 0.0, 0.15, 16)
            i.scale = (1, 0.3, 1)
            i.rotation_euler = (0, side * math.radians(24), 0)
            ctx.add(i, "#FFB3C7", outline=0)
        else:
            # long floppy ears hanging from the top sides, turned a little forward
            p, n = s.sph(side * 62, 58)
            e = sphere(p + Vector((side * 0.06, -0.02, -0.12)), (0.07, 0.12, 0.24), 14, 8)
            e.rotation_euler = (math.radians(-10), side * math.radians(-22), side * math.radians(-15))
            ctx.add(e, ctx.accent)


def tail(s, ctx, curl):
    pts = []
    for k in range(7):
        t = k / 6
        pts.append((ctx.at.x + math.sin(t * curl) * 0.08,
                    ctx.at.y + 0.33 + t * 0.18,
                    ctx.at.z + 0.18 + t * 0.32 + math.sin(t * math.pi) * 0.05,
                    1.0 - 0.5 * t))
    ctx.add(curve(pts, 0.035, ctx.coll, "Tail"), ctx.body if curl > 2 else ctx.accent)


def feat_cat(s, ctx):
    ears(s, ctx, "cat")
    tail(s, ctx, 3.5)
    for az in (-16, 16):  # stripes
        for el in (5, 25):
            p, n = s.sph(az * 4, el)
            o = sphere(p, (0.09, 0.025, 0.02))
            aim(o, n)
            ctx.add(o, "#C9702E", outline=0)


def feat_dog(s, ctx):
    ears(s, ctx, "dog")
    tail(s, ctx, 0.5)
    p, n = s.sph(0, 18)  # a cream muzzle patch with a dark nose
    o = sphere(p, (0.16, 0.12, 0.03), 14, 8)
    aim(o, n)
    ctx.add(o, "#F3DDBF", outline=0)
    p, n = s.sph(0, 24)
    nose = sphere(p + n * 0.02, (0.04, 0.03, 0.025))
    aim(nose, n)
    ctx.add(nose, "#2B1A10", outline=0)


def feat_coconut(s, ctx):
    rnd = random.Random(5)
    for i in range(70):
        p, n = s.sph(rnd.uniform(0, 360), rnd.uniform(-50, 70))
        t = n.cross(Vector((0, 0, 1)))
        if t.length < 1e-3:
            t = Vector((1, 0, 0))
        t.normalize()
        t = Matrix.Rotation(rnd.uniform(-0.6, 0.6), 3, n) @ t
        a = p + n * 0.006
        pts = [(*(a - t * 0.06), 1.0), (*(a + t * 0.06 + n * 0.01), 0.7)]
        ctx.add(curve(pts, 0.006, ctx.coll, "Fibre"), ctx.accent, outline=0)
    for az in (-25, 0, 25):
        p, n = s.sph(az, 70 if az == 0 else 62)
        o = sphere(p, (0.035, 0.035, 0.02))
        aim(o, n)
        ctx.add(o, "#2B1A10", outline=0)


def feat_sandcastle(s, ctx):
    for i, (az, h) in enumerate([(0, 0.18), (-120, 0.14), (120, 0.14)]):
        top = Vector((0, 0, H * 0.86)) if i == 0 else None
        if i == 0:
            base = ctx.at + Vector((0, 0, H * 0.88))
        else:
            p, n = s.sph(az, 25)
            base = p + n * 0.04
        t = cyl(base + Vector((0, 0, h / 2)), 0.07 if i else 0.09, h, 12)
        ctx.add(t, ctx.body, smooth=False)
        rr = 0.07 if i else 0.09
        for k in range(6):
            a = k / 6 * math.tau
            c = cube(base + Vector((math.cos(a) * rr, math.sin(a) * rr, h + 0.02)), (0.03, 0.03, 0.04))
            ctx.add(c, ctx.accent, smooth=False)
        if i == 0:
            pole = cyl(base + Vector((0, 0, h + 0.12)), 0.006, 0.18, 6)
            ctx.add(pole, "#6E4428", outline=0)
            flag = cone(base + Vector((0.05, 0, h + 0.18)), 0.05, 0.0, 0.1, 3)
            flag.rotation_euler = (0, math.radians(90), 0)
            flag.scale = (1, 1, 0.2)
            ctx.add(flag, "#E0405F", smooth=False)
    band = torus(ctx.at + Vector((0, 0, H * 0.3)), R * 0.98, 0.02, 40, 6)
    ctx.add(band, ctx.accent)


def crown(ctx, at, r, gems=True):
    band = cyl(at, r, 0.07, 24)
    ctx.add(band, "gold", smooth=False)
    for k in range(5):
        a = k / 5 * math.tau
        sp = cone(at + Vector((math.cos(a) * r * 0.92, math.sin(a) * r * 0.92, 0.08)), 0.035, 0.0, 0.1, 6)
        ctx.add(sp, "gold", smooth=False)
        if gems:
            g = ico(at + Vector((math.cos(a + 0.6) * r * 1.02, math.sin(a + 0.6) * r * 1.02, 0)), 0.018, 1)
            ctx.add(g, "#E0405F" if k % 2 else "#2AA8FF", glow=1.5, outline=0, smooth=False)


def feat_royal(s, ctx):
    crown(ctx, ctx.at + Vector((0, 0, H * 0.94)), 0.17)
    for az, el, col in [(0, 20, "#E0405F"), (-40, 0, "#2AA8FF"), (40, 0, "#14D282")]:
        p, n = s.sph(az, el)
        g = ico(p + n * 0.01, 0.04, 1)
        ctx.add(g, col, glow=1.2, smooth=False)
    band = torus(ctx.at + Vector((0, 0, H * 0.45)), R * 1.0, 0.018, 40, 6)
    ctx.add(band, "gold")


def feat_ice(s, ctx):
    rnd = random.Random(9)
    for i in range(13):
        p, n = s.sph(rnd.uniform(0, 360), rnd.choice([rnd.uniform(40, 80), rnd.uniform(-30, 0)]))
        L = rnd.uniform(0.2, 0.36)
        c = cone(p + n * (L / 2 - 0.03), rnd.uniform(0.045, 0.07), 0.0, L, 6)
        aim(c, (n + Vector((rnd.uniform(-.2, .2), rnd.uniform(-.2, .2), 0.2))).normalized())
        ctx.add(c, "#E9FBFF" if i % 2 else "#7CD6FF", glow=0.0, smooth=False)


def feat_yeti(s, ctx):
    rnd = random.Random(4)
    for i in range(26):
        p, n = s.sph(rnd.uniform(0, 360), rnd.choice([rnd.uniform(-40, -5), rnd.uniform(55, 80)]))
        for k in range(3):
            c = cone(p + n * 0.03, 0.03, 0.0, 0.09, 5)
            aim(c, (n + Vector((rnd.uniform(-.4, .4), rnd.uniform(-.4, .4), rnd.uniform(0, .3)))).normalized())
            ctx.add(c, "#FFFFFF", smooth=False)
    for side in (-1, 1):  # two blue paw-print pads
        p, n = s.sph(side * 20, 20)
        o = sphere(p, (0.05, 0.05, 0.02))
        aim(o, n)
        ctx.add(o, ctx.accent, outline=0)


def feat_mine(s, ctx):
    rnd = random.Random(7)
    for i, col in enumerate(["#B06BFF", "#2FD6E0", "#FFC93C", "#B06BFF", "#2FD6E0"]):
        p, n = s.sph(rnd.uniform(-160, 160), rnd.uniform(-30, 50))
        o = ico(p, rnd.uniform(0.045, 0.07), 1)
        ctx.add(o, col, glow=0.8, smooth=False)
    # the pickaxe leaning across the front
    c = ctx.at + Vector((0.0, -R * 1.05, H * 0.45))
    handle = cyl(c, 0.018, 0.75, 10)
    handle.rotation_euler = (0, math.radians(35), 0)
    ctx.add(handle, ctx.accent)
    head_c = c + Matrix.Rotation(math.radians(35), 3, "Y") @ Vector((0, 0, 0.36))
    for side in (-1, 1):
        h = cone(head_c + Matrix.Rotation(math.radians(35), 3, "Y") @ Vector((side * 0.1, 0, 0)), 0.03, 0.0, 0.2, 8)
        h.rotation_euler = (0, math.radians(35 + 90 * side), 0)
        ctx.add(h, "#B8BCCB", smooth=False)


def feat_dragon(s, ctx):
    for row, el in enumerate([-15, 0, 15, 30]):
        for k in range(-2, 3):
            p, n = s.sph(k * 16 + (8 if row % 2 else 0), el)
            o = sphere(p, (0.06, 0.04, 0.02))
            aim(o, n)
            ctx.add(o, ctx.accent, outline=0.006)
    for side in (-1, 1):
        p, n = s.sph(side * 40, 66)
        pts = []
        for k in range(6):
            t = k / 5
            q = p + n * (t * 0.05) + Vector((side * 0.05 * t, 0.12 * t * t, 0.2 * t))
            pts.append((*q, 1.0 - 0.85 * t))
        ctx.add(curve(pts, 0.035, ctx.coll, "Horn"), "#F7EBC5")
    for k in range(5):  # back spikes
        p, n = s.sph(180, 70 - k * 22)
        c = cone(p + n * 0.03, 0.035, 0.0, 0.08, 4)
        aim(c, n)
        ctx.add(c, ctx.accent, smooth=False)


def feat_kraken(s, ctx):
    for i in range(3):
        pts = []
        for k in range(14):
            t = k / 13
            a = math.radians(i * 120 + t * 260)
            el = -35 + t * 85
            p, n = s.sph(math.degrees(a), el)
            pts.append((*(p + n * 0.02), 1.0 - 0.75 * t))
        ctx.add(curve(pts, 0.045, ctx.coll, "Tentacle"), ctx.accent)
        for k in range(2, 12, 3):
            t = k / 13
            a = math.radians(i * 120 + t * 260)
            p, n = s.sph(math.degrees(a) + 6, -35 + t * 85)
            d = sphere(p + n * 0.05, (0.016, 0.016, 0.008))
            aim(d, n)
            ctx.add(d, "#FFC8D4", outline=0)


def horns(s, ctx, size=1.0, col="#2A0E1A"):
    for side in (-1, 1):
        p, n = s.sph(side * 32, 62)
        pts = []
        for k in range(7):
            t = k / 6
            q = p + Vector((side * (0.1 * t + 0.08 * t * t), 0.04 * t, 0.26 * t - 0.08 * t * t)) * size
            pts.append((*q, 1.0 - 0.9 * t))
        ctx.add(curve(pts, 0.05 * size, ctx.coll, "Horn"), col)


def feat_demon(s, ctx):
    horns(s, ctx, 1.1)
    ring = torus(ctx.at + Vector((0, 0, 0.07)), R * 0.9, 0.035, 32, 8)
    ctx.add(ring, "#FF2E5C", glow=3.0, outline=0)
    for az in (-18, 18):  # glowing slit eyes-like runes, not a face: two flame marks
        p, n = s.sph(az, 18)
        o = sphere(p, (0.03, 0.03, 0.09))
        aim(o, n)
        ctx.add(o, "#FF5A2E", glow=3.0, outline=0)


def wing(ctx, side, base, kind):
    feathers = 4
    for k in range(feathers):
        t = k / (feathers - 1)
        ang = math.radians(20 + 55 * t)
        L = 0.34 - 0.07 * k
        c = base + Vector((side * (0.05 + math.cos(ang) * L * 0.5), 0.05, math.sin(ang) * L * 0.5 - 0.05))
        if kind == "angel":
            f = sphere(c, (L * 0.55, 0.025, 0.085))
            col = "#FFFFFF"
        else:
            f = cone(c, 0.09, 0.0, L, 3)
            f.scale = (1, 0.2, 1)
            col = "#3A0F22"
        f.rotation_euler = (0, side * -(math.pi / 2 - ang) if kind == "angel" else side * -(math.pi / 2 - ang) - side * 1.57, 0)
        ctx.add(f, col, smooth=kind == "angel")


def feat_angel(s, ctx):
    for side in (-1, 1):
        p, n = s.sph(side * 95, 25)
        wing(ctx, side, p, "angel")
    halo = torus(ctx.at + Vector((0, 0, H + 0.12)), 0.15, 0.022, 32, 8)
    ctx.add(halo, "#FFD86B", glow=2.5, outline=0)


def feat_angel_demon(s, ctx):
    p, n = s.sph(-95, 25)
    wing(ctx, -1, p, "angel")
    p, n = s.sph(95, 25)
    wing(ctx, 1, p, "demon")
    # split body: the right half dark
    egg = ctx.egg
    egg.data.materials.append(toon("ad_dark", "#3A0F22"))
    dark = len(egg.data.materials) - 1
    for poly in egg.data.polygons:
        if poly.center.x > 0.0:
            poly.material_index = dark
    halo = torus(ctx.at + Vector((-0.08, 0, H + 0.1)), 0.11, 0.018, 28, 8)
    halo.rotation_euler = (0, math.radians(-15), 0)
    ctx.add(halo, "#FFD86B", glow=2.5, outline=0)
    p, n = s.sph(35, 60)
    hn = cone(p + n * 0.06, 0.04, 0.0, 0.16, 8)
    aim(hn, (n + Vector((0.3, 0, 0.5))).normalized())
    ctx.add(hn, "#2A0E1A")


def feat_dominus(s, ctx):
    # a tall crest fin over the crown of the egg and two swept points (no face, no hood with eyes)
    fin = sphere(ctx.at + Vector((0, 0.02, H * 0.98)), (0.025, 0.2, 0.16))
    ctx.add(fin, ctx.accent)
    for side in (-1, 1):
        p, n = s.sph(side * 60, 45)
        c = cone(p + n * 0.05, 0.05, 0.0, 0.22, 6)
        aim(c, (n + Vector((side * 0.2, 0.5, 0.7))).normalized())
        ctx.add(c, ctx.accent, smooth=False)
    band = torus(ctx.at + Vector((0, 0, H * 0.62)), R * 0.92, 0.02, 40, 6)
    ctx.add(band, ctx.accent)
    p, n = s.sph(0, 35)
    g = ico(p + n * 0.01, 0.05, 1)
    ctx.add(g, "#4FE3FF", glow=2.0, smooth=False)


def trim(ctx, col="gold"):
    for z in (0.3, 0.62):
        band = torus(ctx.at + Vector((0, 0, H * z)), R * (1.0 if z < 0.5 else 0.93), 0.022, 40, 6)
        ctx.add(band, col)
    for k in range(6):
        a = k / 6 * 360
        pts = []
        for el in range(-25, 46, 10):
            p, n = ctx.s.sph(a, el)
            pts.append((*(p + n * 0.008), 1.0))
        ctx.add(curve(pts, 0.012, ctx.coll, "Trim"), col, outline=0)


def feat_legendary(s, ctx):
    trim(ctx)
    aura = base_egg("Aura", ctx.at, ctx.coll)
    aura.scale = (1.14, 1.14, 1.1)
    aura.location = ctx.at - Vector((0, 0, 0.04))
    ctx.add(aura, None, mat=glass_mat("legendary", "#FFD45A", 0.2, 3.0), outline=0)
    p, n = s.sph(0, 15)
    st = ico(p + n * 0.02, 0.06, 1)
    ctx.add(st, "#FFF2A8", glow=2.0, smooth=False)


def feat_mythical(s, ctx):
    trim(ctx)
    aura = base_egg("Aura", ctx.at, ctx.coll)
    aura.scale = (1.16, 1.16, 1.12)
    aura.location = ctx.at - Vector((0, 0, 0.05))
    ctx.add(aura, None, mat=glass_mat("mythical", "#18E890", 0.22, 3.0), outline=0)
    for az in (0, 120, 240):
        p, n = s.sph(az, 15)
        g = cone(p + n * 0.03, 0.05, 0.0, 0.12, 4)
        aim(g, n)
        ctx.add(g, "#9CFFD6", glow=1.5, smooth=False)


def feat_party(s, ctx):
    rnd = random.Random(11)
    cols = ["#FF5A6E", "#FFD23F", "#2FD6E0", "#7CFF6B", "#FF8BD1", "#FFFFFF"]
    for i in range(45):
        p, n = s.sph(rnd.uniform(0, 360), rnd.uniform(-50, 60))
        o = cube(p, (0.03, 0.012, 0.004)) if i % 2 else sphere(p, (0.022, 0.022, 0.005), 8, 4)
        aim(o, n, rnd.uniform(0, 3))
        ctx.add(o, cols[i % len(cols)], outline=0)
    hat_at = ctx.at + Vector((0.05, 0, H * 0.95))
    hat = cone(hat_at + Vector((0, 0, 0.13)), 0.11, 0.0, 0.28, 24)
    hat.rotation_euler = (0, math.radians(14), 0)
    ctx.add(hat, "#FFD23F")
    for k, z in enumerate((0.04, 0.11, 0.18)):
        ring = torus(hat_at + Vector((0.03 * (z / 0.18), 0, z)), 0.1 * (1 - z / 0.28) + 0.006, 0.01, 24, 4)
        ring.rotation_euler = (0, math.radians(14), 0)
        ctx.add(ring, "#FF5A6E", outline=0)
    pom = ico(hat_at + Vector((0.07, 0, 0.29)), 0.04, 2)
    ctx.add(pom, "#FFFFFF")


def feat_rainbow(s, ctx):
    egg = ctx.egg
    bands = ["#FF5A6E", "#FF9F1C", "#FFE14D", "#5BE37D", "#2FB7FF", "#8E6BFF"]
    first = len(egg.data.materials)
    for b in bands:
        egg.data.materials.append(toon(f"rb_{b}", b))
    for poly in egg.data.polygons:
        z = poly.center.z / H
        poly.material_index = first + min(len(bands) - 1, max(0, int(z * len(bands))))
    # little clouds at the base
    for az in (-50, 50):
        p, n = s.sph(az, -10)
        for k in range(3):
            c = sphere(p + n * 0.03 + Vector((k * 0.05 - 0.05, 0, 0)), (0.05, 0.04, 0.04))
            ctx.add(c, "#FFFFFF")


def feat_glitched(s, ctx):
    rnd = random.Random(3)
    cols = ["#FF3EA5", "#2FD6E0", "#7CFF6B", "#FFFFFF"]
    for i in range(22):
        p, n = s.sph(rnd.uniform(0, 360), rnd.uniform(-50, 70))
        sz = rnd.uniform(0.04, 0.09)
        c = cube(p + n * rnd.uniform(-0.01, 0.06) + Vector((rnd.uniform(-.04, .04), 0, 0)), (sz, sz, sz * 0.7))
        ctx.add(c, cols[i % 4], glow=1.2 if i % 3 == 0 else 0.0, smooth=False, outline=0.006)
    # a displaced slice: one band of the body shifted sideways
    egg = ctx.egg
    for v in egg.data.vertices:
        if 0.45 < v.co.z / H < 0.55:
            v.co.x += 0.04


def feat_black_hole(s, ctx):
    p, n = s.sph(0, 15)
    core = sphere(p - n * 0.02, (0.14, 0.14, 0.04))
    aim(core, n)
    ctx.add(core, "#000000", outline=0)
    for arm in range(3):
        pts = []
        for k in range(20):
            t = k / 19
            ang = arm * 120 + t * 300
            rr = 0.13 + t * 0.32
            q, qn = s.at(Vector((math.sin(math.radians(ang)) * rr, -1, math.cos(math.radians(ang)) * rr * 1.3 + 0.0)))
            pts.append((*(q + qn * 0.005), 1.0 - 0.6 * t))
        ctx.add(curve(pts, 0.02, ctx.coll, "Swirl"), ctx.accent, glow=3.0, outline=0)
    ring = torus(p + n * 0.01, 0.15, 0.015, 32, 6)
    aim(ring, n)
    ctx.add(ring, "#E2C6FF", glow=3.0, outline=0)


def feat_secret(s, ctx):
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.active_object
    t.data.body = "?"
    t.data.extrude = 0.025
    t.data.size = 0.6
    t.data.align_x = "CENTER"
    t.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    t = bpy.context.active_object
    p, n = s.sph(0, 8)
    t.location = p + n * 0.025
    t.rotation_euler = (math.radians(90 - 8), 0, 0)
    ctx.add(t, ctx.accent, glow=3.0, outline=0, smooth=False)
    for az in (-60, 60, 180):  # small rune dots
        p, n = s.sph(az, 30)
        d = ico(p + n * 0.01, 0.025, 1)
        ctx.add(d, ctx.accent, glow=2.0, outline=0, smooth=False)


FEATURES = {
    "spotted": feat_spotted, "cracked": feat_cracked, "cat": feat_cat, "dog": feat_dog,
    "coconut": feat_coconut, "sandcastle": feat_sandcastle, "royal": feat_royal, "ice": feat_ice,
    "yeti": feat_yeti, "mine": feat_mine, "dragon": feat_dragon, "kraken": feat_kraken,
    "demon": feat_demon, "angel": feat_angel, "angel_demon": feat_angel_demon, "dominus": feat_dominus,
    "legendary": feat_legendary, "mythical": feat_mythical, "party": feat_party, "rainbow": feat_rainbow,
    "glitched": feat_glitched, "black_hole": feat_black_hole, "secret": feat_secret,
}


class Ctx:
    def __init__(self, egg_id, egg, at, coll, golden):
        self.id = egg_id
        self.egg = egg
        self.at = at
        self.coll = coll
        self.golden = golden
        self.body, self.accent = PALETTE[egg_id]
        self.s = Surf(egg)

    def add(self, obj, color, glow=0.0, outline=0.01, smooth=True, mat=None):
        if mat is None:
            if color == "gold" or (self.golden and glow == 0 and color in (self.body, self.accent)):
                mat = gold_mat()
            else:
                mat = toon(color, color, glow)
        finish(obj, mat, self.coll, self.egg, outline, smooth)
        return obj


def build_egg(egg_id, golden=False, at=None):
    name = f"egg_{egg_id}" + ("_golden" if golden else "")
    coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    at = at or Vector((0, 0, 0))
    egg = base_egg(name, at, coll)
    link(egg, coll)
    ctx = Ctx(egg_id, egg, at, coll, golden)
    finish(egg, gold_mat() if golden else toon(egg_id, ctx.body), coll, None, 0.016)
    egg["Egg"] = name
    bpy.context.view_layer.update()
    f = FEATURES.get(egg_id)
    if f:
        f(ctx.s, ctx)
    if golden:  # sparkle: four little star points
        for k in range(4):
            p, n = ctx.s.sph(k * 90 + 30, 40 - k * 15)
            st = ico(p + n * 0.05, 0.022, 1)
            ctx.add(st, "#FFFBE0", glow=4.0, outline=0, smooth=False)
    return coll


def build_all():
    for i, e in enumerate(EGGS):
        build_egg(e, False, Vector(((i % 6) * SPACING, (i // 6) * SPACING, 0)))
    for i, e in enumerate(GOLDEN):
        build_egg(e, True, Vector((i * SPACING, 4 * SPACING, 0)))
    return "built"


def tri_count(coll):
    deps = bpy.context.evaluated_depsgraph_get()
    n = 0
    for o in coll.objects:
        if o.type == "MESH":
            me = o.evaluated_get(deps).to_mesh()
            n += sum(len(p.vertices) - 2 for p in me.polygons)
            o.evaluated_get(deps).to_mesh_clear()
    return n


def setup_render():
    sc = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else engines[0]
    sc.render.resolution_x = 480
    sc.render.resolution_y = 480
    sc.render.film_transparent = True
    sc.view_settings.view_transform = "Standard"
    if "EggCam" not in bpy.data.objects:
        cam = bpy.data.cameras.new("EggCam")
        cam.lens = 70
        o = bpy.data.objects.new("EggCam", cam)
        sc.collection.objects.link(o)
    sc.camera = bpy.data.objects["EggCam"]
    if "EggSun" not in bpy.data.objects:
        l = bpy.data.lights.new("EggSun", "SUN")
        l.energy = 3.0
        o = bpy.data.objects.new("EggSun", l)
        o.rotation_euler = (math.radians(50), 0, math.radians(-35))
        sc.collection.objects.link(o)


def render_egg(coll_name, out_path):
    sc = bpy.context.scene
    for c in sc.collection.children:
        c.hide_render = c.name != coll_name
    egg = bpy.data.objects[coll_name]
    target = egg.location + Vector((0, 0, H * 0.55))
    cam = bpy.data.objects["EggCam"]
    cam.location = target + Vector((0.9, -3.4, 0.9))
    d = target - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out_path
    bpy.ops.render.render(write_still=True)


def render_all(only=None):
    os.makedirs(OUT, exist_ok=True)
    setup_render()
    done = []
    names = [f"egg_{e}" for e in EGGS] + [f"egg_{e}_golden" for e in GOLDEN]
    for n in names:
        if only and n not in only:
            continue
        render_egg(n, os.path.join(OUT, n + ".png"))
        done.append(f"{n}:{tri_count(bpy.data.collections[n])}")
    for c in bpy.context.scene.collection.children:
        c.hide_render = False
    import json
    path = os.path.join(OUT, "tris.json")
    tris = json.load(open(path)) if os.path.exists(path) else {}
    for d in done:
        k, v = d.split(":")
        tris[k] = int(v)
    json.dump(tris, open(path, "w"), indent=1)
    return done
