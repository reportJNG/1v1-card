"""3D fighters (MAKE_3D_EGGS_AND_FIGHTERS.md section 2): the six approved characters and the Guardian.

Run inside Blender after scripts/blender/eggs.py (it reuses its toon materials and mesh helpers):
    ns = {}; exec(open(".../eggs.py").read(), ns); exec(open(".../fighters.py").read(), ns)
    ns["build_fighters"](); ns["render_fighters"]()

Each fighter is the standard Roblox R15 *blocky* body (in game: the built-in R15 rig with
BodyColors, so no body mesh is uploaded) plus the parts that give it its identity, made here:
hair, coat / scarf / collar / chains / armour, the weapon or effect prop, and a face (eyes and
brows; determined or confident, closed mouth, no blush or tears). Units are studs (1 = 1 stud).
The body parts hang on joint empties named like R15 joints so poses and the attack GIF can be
keyframed here; in game the same poses drive the R15 Motor6Ds from code.
Nothing here is uploaded: renders go to art/3d/renders/fighters for docs/review/3d_fighters.png.
"""
import math
import os

import bpy
from mathutils import Vector

OUTF = os.path.join(REPO, "art", "3d", "renders", "fighters")  # noqa: F821 (REPO from eggs.py)
SKIN = "#F2D2BC"

# id -> look (from the approved card art, docs/review/new5-2026-11-10.md and set02-2026-11-11.md)
FIGHTERS = {
    "ren_emberfang": dict(name="Rook Emberforge", hair="#D8261C", hair_style="wild", eyes="#FF7A1A",
                          torso="#1C1214", arms="#1C1214", legs="#1C1214", coat="#2A1416", trim="#FF6A1A",
                          trim_kind="flame", collar="fur", belt="#E0A030", prop="fire_fists", glow="#FF7A1A"),
    "yuki_frostveil": dict(name="Halvard Frostwarden", hair="#14141E", hair_style="messy", eyes="#4FB8FF",
                           torso="#141822", arms="#141822", legs="#141822", coat="#1A1F2C", trim="#EAF4FF",
                           trim_kind="stripe", collar="scarf", scarf="#101016", belt="#EAF4FF", pads="#EAF4FF",
                           prop="ice_lance", glow="#4FB8FF"),
    "vesper_shade": dict(name="Nox Veilstrider", hair="#121018", hair_style="spiky", eyes="#B45CFF",
                         torso="#121018", arms="#121018", legs="#121018", coat="#17131F", trim="#7A3DD8",
                         trim_kind="tatter", collar="scarf", scarf="#0E0C12", chains=True, prop="void_orb",
                         glow="#9B4DFF"),
    "kael_voidbinder": dict(name="Kael Voidbinder", hair="#121018", hair_style="spiky", eyes="#B45CFF",
                            torso="#1A1426", arms="#2A2140", legs="#121018", coat="#1E1830", trim="#8E6BFF",
                            trim_kind="tatter", collar="scarf", scarf="#121018", chains=True, pads="#3A2E5C",
                            prop="shadow_blade", glow="#8E6BFF"),
    "brann_cinderfall": dict(name="Brann Cinderfall", hair="#3A0E10", hair_style="wild", eyes="#FF3A2E",
                             torso="#1A1012", arms="#1A1012", legs="#1A1012", coat="#241416", trim="#E0261C",
                             trim_kind="flame", collar="scarf", scarf="#C81E24", chains=True, prop="flame_blade",
                             glow="#FF3A2E"),
    "aurex_sunforge": dict(name="Aurex Sunforge", hair="#FFD24A", hair_style="spiky", eyes="#FFC21A",
                           torso="#F4EEDF", arms="#1A1612", legs="#1A1612", coat="#F4EEDF", trim="#FFC21A",
                           trim_kind="stripe", collar="scarf", scarf="#FFFFFF", belt="#FFC21A", pads="#FFC21A",
                           prop="sun_blade", glow="#FFD24A"),
}

# R15 blocky body: part -> (size, centre); joints -> pivot and parent. Feet at z = 0.
PARTS = {
    "LowerTorso": ((2.0, 1.0, 0.4), (0, 0, 2.2)),
    "UpperTorso": ((2.0, 1.0, 1.6), (0, 0, 3.2)),
    "Head": ((1.2, 1.2, 1.2), (0, 0, 4.62)),
    "RightUpperArm": ((1.0, 1.0, 1.1), (1.5, 0, 3.45)),
    "RightLowerArm": ((1.0, 1.0, 0.75), (1.5, 0, 2.52)),
    "RightHand": ((1.0, 1.0, 0.3), (1.5, 0, 1.99)),
    "LeftUpperArm": ((1.0, 1.0, 1.1), (-1.5, 0, 3.45)),
    "LeftLowerArm": ((1.0, 1.0, 0.75), (-1.5, 0, 2.52)),
    "LeftHand": ((1.0, 1.0, 0.3), (-1.5, 0, 1.99)),
    "RightUpperLeg": ((1.0, 1.0, 1.0), (0.5, 0, 1.5)),
    "RightLowerLeg": ((1.0, 1.0, 0.8), (0.5, 0, 0.6)),
    "RightFoot": ((1.0, 1.0, 0.2), (0.5, 0, 0.1)),
    "LeftUpperLeg": ((1.0, 1.0, 1.0), (-0.5, 0, 1.5)),
    "LeftLowerLeg": ((1.0, 1.0, 0.8), (-0.5, 0, 0.6)),
    "LeftFoot": ((1.0, 1.0, 0.2), (-0.5, 0, 0.1)),
}
JOINTS = {  # joint: (parent joint, pivot)
    "Root": (None, (0, 0, 2.2)),
    "Waist": ("Root", (0, 0, 2.4)),
    "Neck": ("Waist", (0, 0, 4.0)),
    "RightShoulder": ("Waist", (1.5, 0, 3.85)),
    "RightElbow": ("RightShoulder", (1.5, 0, 2.9)),
    "RightWrist": ("RightElbow", (1.5, 0, 2.14)),
    "LeftShoulder": ("Waist", (-1.5, 0, 3.85)),
    "LeftElbow": ("LeftShoulder", (-1.5, 0, 2.9)),
    "LeftWrist": ("LeftElbow", (-1.5, 0, 2.14)),
    "RightHip": ("Root", (0.5, 0, 2.0)),
    "RightKnee": ("RightHip", (0.5, 0, 1.0)),
    "RightAnkle": ("RightKnee", (0.5, 0, 0.2)),
    "LeftHip": ("Root", (-0.5, 0, 2.0)),
    "LeftKnee": ("LeftHip", (-0.5, 0, 1.0)),
    "LeftAnkle": ("LeftKnee", (-0.5, 0, 0.2)),
}
PART_JOINT = {
    "LowerTorso": "Root", "UpperTorso": "Waist", "Head": "Neck",
    "RightUpperArm": "RightShoulder", "RightLowerArm": "RightElbow", "RightHand": "RightWrist",
    "LeftUpperArm": "LeftShoulder", "LeftLowerArm": "LeftElbow", "LeftHand": "LeftWrist",
    "RightUpperLeg": "RightHip", "RightLowerLeg": "RightKnee", "RightFoot": "RightAnkle",
    "LeftUpperLeg": "LeftHip", "LeftLowerLeg": "LeftKnee", "LeftFoot": "LeftAnkle",
}


class Rig:
    def __init__(self, fid, at, coll, scale=1.0):
        self.id = fid
        self.coll = coll
        self.joints = {}
        self.at = Vector(at)
        self.scale = scale
        for j, (parent, pivot) in JOINTS.items():
            e = bpy.data.objects.new(f"{fid}_{j}", None)
            e.empty_display_size = 0.2
            coll.objects.link(e)
            e.location = Vector(pivot) * scale + (self.at if parent is None else Vector((0, 0, 0)))
            if parent is not None:
                p = self.joints[parent]
                e.parent = p
                e.location = (Vector(pivot) - Vector(JOINTS[parent][1])) * scale
            e.rotation_mode = "XYZ"
            self.joints[j] = e
        bpy.context.view_layer.update()

    def attach(self, obj, joint, mat, outline=0.03, smooth=True):
        obj.data.materials.clear()
        obj.data.materials.append(mat)
        if obj.type == "MESH":
            for p in obj.data.polygons:
                p.use_smooth = smooth
        if outline:
            obj.data.materials.append(outline_mat())  # noqa: F821
            m = obj.modifiers.new("Outline", "SOLIDIFY")
            m.thickness = outline * self.scale
            m.offset = 1.0
            m.use_flip_normals = True
            m.use_rim = False
            m.material_offset = 1
        link(obj, self.coll)  # noqa: F821
        bpy.context.view_layer.update()
        j = self.joints[joint]
        obj.parent = j
        obj.matrix_parent_inverse = j.matrix_world.inverted()
        obj["Fighter"] = self.id
        return obj

    def w(self, local):
        """A body-space point (studs, feet at 0) to world space at rest."""
        return self.at + Vector(local) * self.scale


def mat(color, glow=0.0, metal=False):
    return toon(color, color, glow, metal)  # noqa: F821


def box(rig, size, centre, bevel=0.12):
    o = cube(rig.w(centre), Vector(size) * rig.scale)  # noqa: F821
    if bevel:
        b = o.modifiers.new("Bevel", "BEVEL")
        b.width = bevel * rig.scale
        b.segments = 2
    return o


def body(rig, look):
    cols = {"Head": SKIN, "LeftHand": SKIN, "RightHand": SKIN}
    for part, (size, centre) in PARTS.items():
        if part in cols:
            c = cols[part]
        elif "Torso" in part:
            c = look["torso"]
        elif "Arm" in part:
            c = look["arms"]
        elif "Foot" in part:
            c = "#121014"
        else:
            c = look["legs"]
        o = box(rig, size, centre, 0.1 if part != "Head" else 0.22)
        o.name = f"{rig.id}_{part}"
        rig.attach(o, PART_JOINT[part], mat(c), 0.035)
    face(rig, look)


def face(rig, look):
    # determined eyes (dark outline, coloured iris, a white glint) and angled brows; mouth closed
    for side in (-1, 1):
        x = side * 0.27
        white = box(rig, (0.3, 0.04, 0.2), (x, -0.62, 4.62), 0.03)
        rig.attach(white, "Neck", mat("#FFFFFF"), 0)
        iris = box(rig, (0.17, 0.05, 0.19), (x - side * 0.02, -0.635, 4.61), 0.03)
        rig.attach(iris, "Neck", mat(look["eyes"], 1.0), 0)
        glint = box(rig, (0.05, 0.06, 0.05), (x + side * 0.0 + 0.03, -0.645, 4.66), 0)
        rig.attach(glint, "Neck", mat("#FFFFFF", 1.5), 0)
        brow = box(rig, (0.34, 0.05, 0.06), (x, -0.63, 4.79), 0)
        brow.rotation_euler = (0, side * math.radians(14), 0)  # inner ends down: determined
        rig.attach(brow, "Neck", mat("#15101A"), 0)
    if look.get("collar") != "scarf":
        mouth = box(rig, (0.18, 0.04, 0.035), (0, -0.62, 4.32), 0)
        rig.attach(mouth, "Neck", mat("#5A3030"), 0)


def hair(rig, look):
    col = mat(look["hair"])
    cap = sphere(rig.w((0, 0.06, 4.86)), Vector((0.72, 0.72, 0.5)) * rig.scale, 16, 8)  # noqa: F821
    rig.attach(cap, "Neck", col, 0.035)
    style = look["hair_style"]
    spikes = []
    # (azimuth around the head from the front, elevation, length, thickness)
    if style == "wild":
        spikes = [(a, e, L, 0.26) for a, e, L in [
            (180, 20, 0.95), (140, 25, 0.9), (220, 25, 0.9), (100, 35, 0.8), (260, 35, 0.8), (60, 45, 0.75),
            (300, 45, 0.75), (180, 55, 0.85), (20, 60, 0.6), (340, 60, 0.6), (120, 60, 0.7), (240, 60, 0.7)]]
    elif style == "messy":
        spikes = [(a, e, L, 0.24) for a, e, L in [
            (180, 15, 0.7), (145, 20, 0.65), (215, 20, 0.65), (100, 30, 0.6), (260, 30, 0.6), (180, 50, 0.6),
            (60, 50, 0.5), (300, 50, 0.5), (0, 70, 0.45)]]
    else:  # spiky, swept up
        spikes = [(a, e, L, 0.25) for a, e, L in [
            (180, 25, 0.85), (140, 35, 0.85), (220, 35, 0.85), (90, 45, 0.75), (270, 45, 0.75), (180, 60, 0.9),
            (40, 62, 0.7), (320, 62, 0.7), (110, 65, 0.8), (250, 65, 0.8)]]
    centre = Vector((0, 0.05, 4.8))
    for az, el, L, t in spikes:
        a, e = math.radians(az), math.radians(el)
        d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
        base = centre + d * 0.5
        c = cone(rig.w(base + d * L / 2), t * rig.scale, 0.0, L * rig.scale, 6)  # noqa: F821
        aim(c, d)  # noqa: F821
        rig.attach(c, "Neck", col, 0.03, smooth=False)
    # bangs: chunky fringe pieces over the forehead (eyes stay visible)
    for k, x in enumerate((-0.42, -0.18, 0.08, 0.32)):
        L = 0.3 if k % 2 == 0 else 0.24  # short enough to leave the eyes and brows clear
        c = cone(rig.w((x, -0.6, 5.22 - L / 2)), 0.15 * rig.scale, 0.0, L * rig.scale, 5)  # noqa: F821
        c.rotation_euler = (math.radians(180 + 12), math.radians(-12 + k * 8), 0)
        rig.attach(c, "Neck", col, 0.03, smooth=False)
    for side in (-1, 1):  # side locks
        c = cone(rig.w((side * 0.62, -0.1, 4.55)), 0.13 * rig.scale, 0.0, 0.5 * rig.scale, 5)  # noqa: F821
        c.rotation_euler = (math.radians(180), side * math.radians(-8), 0)
        rig.attach(c, "Neck", col, 0.03, smooth=False)


def coat(rig, look):
    """Long coat tails from the waist (open at the front), with a trim along the hem."""
    import bmesh
    me = bpy.data.meshes.new(f"{rig.id}_coat")
    bm = bmesh.new()
    seg, top, bot = 20, 2.45, 0.55
    ring_t, ring_b = [], []
    for i in range(seg + 1):
        a = math.radians(40 + i * (280 / seg))  # leaves an 80 degree opening at the front
        for (z, r, ring) in ((top, 1.12, ring_t), (bot, 1.42, ring_b)):
            ring.append(bm.verts.new((math.sin(a) * r * 1.0, -math.cos(a) * r * 0.62, z)))
    for i in range(seg):
        bm.faces.new((ring_t[i], ring_t[i + 1], ring_b[i + 1], ring_b[i]))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(f"{rig.id}_Coat", me)
    bpy.context.scene.collection.objects.link(o)
    o.scale = (rig.scale,) * 3
    o.location = rig.at
    sol = o.modifiers.new("Thick", "SOLIDIFY")
    sol.thickness = 0.08
    rig.attach(o, "Root", mat(look["coat"]), 0.035)
    # trim along the hem
    hem = []
    for i in range(seg + 1):
        a = math.radians(40 + i * (280 / seg))
        hem.append((math.sin(a) * 1.44, -math.cos(a) * 0.64, bot + 0.06))
    kind = look["trim_kind"]
    if kind == "flame" or kind == "tatter":
        for i in range(0, seg + 1, 2):
            x, y, z = hem[i]
            c = cone(rig.w((x, y, z - 0.14)), 0.16 * rig.scale, 0.0, 0.42 * rig.scale, 4)  # noqa: F821
            c.rotation_euler = (math.radians(180), 0, math.atan2(y, x))
            glow = 1.6 if kind == "flame" else 0.0
            rig.attach(c, "Root", mat(look["trim"], glow), 0.0 if glow else 0.02, smooth=False)
    pts = [(*(rig.w(p)), 1.0) for p in hem]
    rig.attach(curve(pts, 0.06 * rig.scale, rig.coll, "Hem"), "Root", mat(look["trim"], 1.2 if kind == "flame" else 0.0), 0)  # noqa: F821
    # coat front panels on the chest: two lapels in the trim colour
    for side in (-1, 1):
        lap = box(rig, (0.24, 0.08, 1.4), (side * 0.36, -0.53, 3.2), 0.03)
        lap.rotation_euler = (0, side * math.radians(-8), 0)
        rig.attach(lap, "Waist", mat(look["trim"]), 0.02)


def collar(rig, look):
    if look["collar"] == "fur":
        for k in range(12):
            a = k / 12 * math.tau
            s = sphere(rig.w((math.sin(a) * 0.72, -math.cos(a) * 0.48, 4.02)), Vector((0.26, 0.26, 0.2)) * rig.scale)  # noqa: F821
            rig.attach(s, "Waist", mat("#F2EEE6"), 0.03)
    else:
        ring = torus(rig.w((0, 0, 4.02)), 0.62 * rig.scale, 0.2 * rig.scale, 20, 8)  # noqa: F821
        ring.scale = (1, 0.72, 1)
        rig.attach(ring, "Waist", mat(look["scarf"]), 0.03)
        mask = box(rig, (1.26, 0.2, 0.5), (0, -0.56, 4.24), 0.08)  # over the mouth and nose
        rig.attach(mask, "Neck", mat(look["scarf"]), 0.03)
        for side, L in ((1, 1.5), (-1, 1.1)):  # two tails flying back
            t = box(rig, (0.34, 0.08, L), (side * 0.35, 0.62, 4.0 - L / 2 + 0.1), 0.04)
            t.rotation_euler = (math.radians(-22), 0, side * math.radians(10))
            rig.attach(t, "Waist", mat(look["scarf"]), 0.03)


def extras(rig, look):
    if look.get("belt"):
        b = box(rig, (2.1, 1.08, 0.24), (0, 0, 2.42), 0.04)
        rig.attach(b, "Root", mat(look["belt"]), 0.02)
        k = box(rig, (0.36, 0.1, 0.32), (0, -0.56, 2.42), 0.04)
        rig.attach(k, "Root", mat("#FFC21A", 0.4), 0.02)
    if look.get("pads"):
        for side in (-1, 1):
            p = sphere(rig.w((side * 1.55, 0, 3.98)), Vector((0.66, 0.66, 0.3)) * rig.scale)  # noqa: F821
            rig.attach(p, "RightShoulder" if side > 0 else "LeftShoulder", mat(look["pads"]), 0.03)
    if look.get("chains"):
        # a chain across the chest, left shoulder to right hip, links turned alternately
        a, b = Vector((-0.9, -0.56, 3.9)), Vector((0.95, -0.56, 2.45))
        n = 11
        for i in range(n):
            p = a.lerp(b, i / (n - 1))
            l = torus(rig.w(p), 0.1 * rig.scale, 0.03 * rig.scale, 10, 4)  # noqa: F821
            d = (b - a).normalized()
            aim(l, d.cross(Vector((0, -1, 0))) if i % 2 else Vector((0, -1, 0)))  # noqa: F821
            rig.attach(l, "Waist", mat("#B8BCCB", 0.0, True), 0.0, smooth=False)


def prop(rig, look):
    kind, g = look["prop"], look["glow"]
    hand_r = (1.5, -0.1, 1.75)
    if kind == "fire_fists":
        for side, joint in ((1, "RightWrist"), (-1, "LeftWrist")):
            for k in range(8):  # flames wrapping the fist and rising past the forearm
                a = k / 8 * math.tau
                c = cone(rig.w((side * 1.5 + math.cos(a) * 0.42, math.sin(a) * 0.42, 2.2)), 0.24 * rig.scale, 0.0, 1.1 * rig.scale, 5)  # noqa: F821
                c.rotation_euler = (math.sin(a) * -0.35, math.cos(a) * 0.35, 0)
                rig.attach(c, joint, mat("#FFB43C" if k % 2 else g, 2.0), 0, smooth=False)
    elif kind == "ice_lance":
        shaft = cyl(rig.w((1.5, -0.1, 2.1)), 0.07 * rig.scale, 4.6 * rig.scale, 8)  # noqa: F821
        rig.attach(shaft, "RightWrist", mat("#DDEFFF"), 0.02)
        tip = cone(rig.w((1.5, -0.1, 4.75)), 0.24 * rig.scale, 0.0, 0.9 * rig.scale, 6)  # noqa: F821
        rig.attach(tip, "RightWrist", mat("#8FD8FF", 1.2), 0.025, smooth=False)
        for k in range(4):
            sh = cone(rig.w((1.5 + (0.18 if k % 2 else -0.18), -0.1, 4.2 - k * 0.12)), 0.08 * rig.scale, 0.0, 0.35 * rig.scale, 5)  # noqa: F821
            sh.rotation_euler = (0, math.radians(30 if k % 2 else -30), 0)
            rig.attach(sh, "RightWrist", mat("#BFE9FF", 0.8), 0.0, smooth=False)
    elif kind == "void_orb":
        orb = sphere(rig.w((1.5, -0.75, 1.9)), Vector((0.42, 0.42, 0.42)) * rig.scale, 16, 10)  # noqa: F821
        rig.attach(orb, "RightWrist", mat("#2A0F4A", 0.0), 0.0)
        ring = torus(rig.w((1.5, -0.75, 1.9)), 0.55 * rig.scale, 0.05 * rig.scale, 24, 6)  # noqa: F821
        ring.rotation_euler = (math.radians(70), 0, math.radians(20))
        rig.attach(ring, "RightWrist", mat(g, 2.5), 0.0)
        glow = sphere(rig.w((1.5, -0.75, 1.9)), Vector((0.5, 0.5, 0.5)) * rig.scale, 16, 10)  # noqa: F821
        rig.attach(glow, "RightWrist", glass_mat(rig.id + "orb", g, 0.35, 3.0), 0)  # noqa: F821
    else:  # blades
        colour = {"shadow_blade": "#3A2466", "flame_blade": "#E0261C", "sun_blade": "#FFE27A"}[kind]
        L = 3.3
        blade = box(rig, (0.16, 0.5, L), (1.5, -0.1, 1.95 + 0.3 + L / 2), 0.02)
        if kind != "sun_blade":  # jagged edges
            for k in range(5):
                c = cone(rig.w((1.5, -0.38, 2.6 + k * 0.6)), 0.14 * rig.scale, 0.0, 0.32 * rig.scale, 3)  # noqa: F821
                c.rotation_euler = (math.radians(90 + 25), 0, 0)
                rig.attach(c, "RightWrist", mat(g, 2.0), 0.0, smooth=False)
        rig.attach(blade, "RightWrist", mat(colour, 1.0 if kind != "shadow_blade" else 0.3), 0.025, smooth=False)
        tip = cone(rig.w((1.5, -0.1, 1.95 + 0.3 + L + 0.3)), 0.26 * rig.scale, 0.0, 0.6 * rig.scale, 4)  # noqa: F821
        tip.scale = (0.4, 1, 1)
        rig.attach(tip, "RightWrist", mat(colour, 1.0 if kind != "shadow_blade" else 0.3), 0.025, smooth=False)
        guard = box(rig, (0.3, 1.1, 0.16), (1.5, -0.1, 2.2), 0.03)
        rig.attach(guard, "RightWrist", mat("#FFC21A" if kind == "sun_blade" else "#2A2233"), 0.02)
        edge = box(rig, (0.06, 0.08, L * 0.95), (1.5, -0.36, 1.95 + 0.3 + L / 2), 0)
        rig.attach(edge, "RightWrist", mat(g, 2.5), 0.0)
        if kind == "sun_blade":  # a ring of light behind the back (the sun)
            halo = torus(rig.w((0, 0.9, 4.2)), 1.3 * rig.scale, 0.06 * rig.scale, 32, 6)  # noqa: F821
            halo.rotation_euler = (math.radians(90), 0, 0)
            rig.attach(halo, "Waist", mat("#FFE27A", 2.5), 0.0)


def guardian(rig, theme="#5BE0FF"):
    """An original golem knight: stone blocks, glowing seams in the world colour, a visor slit
    (no face), big pauldrons, a stone greatsword and a round shield."""
    stone, dark = "#8A8F9E", "#5A5E6C"
    for part, (size, centre) in PARTS.items():
        grow = Vector((1.15, 1.15, 1.0)) if "Torso" in part or "Upper" in part else Vector((1.05, 1.05, 1.0))
        o = box(rig, Vector(size) * grow, centre, 0.08)
        rig.attach(o, PART_JOINT[part], mat(stone if "Torso" in part or part == "Head" else dark), 0.04, smooth=False)
    # glowing seams
    for z in (2.9, 3.5):
        s = box(rig, (2.32, 1.18, 0.06), (0, 0, z), 0)
        rig.attach(s, "Waist", mat(theme, 2.5), 0.0)
    core = sphere(rig.w((0, -0.6, 3.25)), Vector((0.28, 0.12, 0.28)) * rig.scale, 12, 8)  # noqa: F821
    rig.attach(core, "Waist", mat(theme, 3.0), 0.0)
    # helmet: a crest and a visor slit of light (no eyes, no face)
    helm = box(rig, (1.42, 1.42, 1.3), (0, 0, 4.66), 0.12)
    rig.attach(helm, "Neck", mat(stone), 0.04, smooth=False)
    visor = box(rig, (1.0, 0.06, 0.12), (0, -0.72, 4.66), 0)
    rig.attach(visor, "Neck", mat(theme, 3.0), 0.0)
    crest = box(rig, (0.18, 1.3, 0.6), (0, 0.05, 5.45), 0.06)
    rig.attach(crest, "Neck", mat(theme, 1.5), 0.03)
    for side in (-1, 1):
        p = box(rig, (1.3, 1.4, 0.55), (side * 1.65, 0, 4.0), 0.14)
        p.rotation_euler = (0, side * math.radians(-12), 0)
        rig.attach(p, "RightShoulder" if side > 0 else "LeftShoulder", mat(stone), 0.04, smooth=False)
        g = box(rig, (1.34, 1.44, 0.06), (side * 1.65, 0, 3.74), 0)
        rig.attach(g, "RightShoulder" if side > 0 else "LeftShoulder", mat(theme, 2.0), 0.0)
    # greatsword (right) and round shield (left)
    blade = box(rig, (0.22, 0.75, 4.2), (1.5, -0.2, 4.4), 0.03)
    rig.attach(blade, "RightWrist", mat("#B8BCCB"), 0.03, smooth=False)
    edge = box(rig, (0.06, 0.1, 4.0), (1.5, -0.6, 4.4), 0)
    rig.attach(edge, "RightWrist", mat(theme, 2.5), 0.0)
    guard = box(rig, (0.35, 1.5, 0.25), (1.5, -0.2, 2.25), 0.04)
    rig.attach(guard, "RightWrist", mat(dark), 0.03)
    sh = cyl(rig.w((-1.95, -0.2, 2.6)), 1.0 * rig.scale, 0.22 * rig.scale, 20)  # noqa: F821
    sh.rotation_euler = (0, math.radians(90), 0)
    rig.attach(sh, "LeftWrist", mat(stone), 0.04, smooth=False)
    boss = sphere(rig.w((-2.08, -0.2, 2.6)), Vector((0.12, 0.3, 0.3)) * rig.scale)  # noqa: F821
    rig.attach(boss, "LeftWrist", mat(theme, 2.5), 0.0)


def build_one(fid, at, scale=1.0, theme=None):
    coll = bpy.data.collections.get(f"fighter_{fid}") or bpy.data.collections.new(f"fighter_{fid}")
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    rig = Rig(fid, at, coll, scale)
    if fid.startswith("guardian"):
        guardian(rig, theme)
    else:
        look = FIGHTERS[fid]
        body(rig, look)
        hair(rig, look)
        coat(rig, look)
        collar(rig, look)
        extras(rig, look)
        prop(rig, look)
    idle(rig)
    return rig


def pose(rig, p):
    """p: joint -> (x, y, z) degrees."""
    for j, e in rig.joints.items():
        r = p.get(j, (0, 0, 0))
        e.rotation_euler = tuple(math.radians(v) for v in r)


IDLE = {"RightShoulder": (-10, 0, 8), "LeftShoulder": (-6, 0, -8), "RightElbow": (-25, 0, 0),
        "LeftElbow": (-15, 0, 0), "RightHip": (0, 0, 4), "LeftHip": (0, 0, -4)}
ATTACK = [  # the attack: wind-up, dash, strike, follow-through, recover (root moves forward)
    ({}, 0.0),
    ({"Waist": (0, 0, 25), "RightShoulder": (60, 0, 30), "RightElbow": (-60, 0, 0), "LeftShoulder": (-30, 0, -20),
      "RightHip": (15, 0, 0), "LeftHip": (-20, 0, 0)}, -0.3),
    ({"Waist": (10, 0, 10), "RightShoulder": (110, 0, 10), "RightElbow": (-20, 0, 0), "LeftShoulder": (-40, 0, -25),
      "RightHip": (-35, 0, 0), "LeftHip": (30, 0, 0), "LeftKnee": (-30, 0, 0)}, -1.6),
    ({"Waist": (15, 0, -30), "RightShoulder": (-60, 0, -10), "RightElbow": (-5, 0, 0), "LeftShoulder": (20, 0, -30),
      "RightHip": (-40, 0, 0), "LeftHip": (35, 0, 0), "LeftKnee": (-35, 0, 0)}, -2.4),
    ({"Waist": (5, 0, -15), "RightShoulder": (-40, 0, -5), "RightElbow": (-15, 0, 0), "LeftShoulder": (0, 0, -15)}, -1.2),
    ({}, 0.0),
]


def idle(rig):
    pose(rig, IDLE)


def build_fighters():
    ids = list(FIGHTERS)
    for i, fid in enumerate(ids):
        build_one(fid, (i * 7.0, 30.0, 0))
    for k, (w, theme) in enumerate([("1", "#7CFF6B"), ("4", "#5BE0FF"), ("8", "#FF6A3D")]):
        build_one(f"guardian_w{w}", (k * 12.0, 46.0, 0), 1.8, theme)
    return "built"


def setup_fighter_render():
    setup_render()  # noqa: F821
    sc = bpy.context.scene
    sc.render.resolution_x = 420
    sc.render.resolution_y = 560
    cam = bpy.data.objects["EggCam"]
    cam.data.lens = 50


def render_view(coll_name, target, dist, az, out, lens=50):
    sc = bpy.context.scene
    for c in sc.collection.children:
        c.hide_render = c.name != coll_name
    cam = bpy.data.objects["EggCam"]
    cam.data.lens = lens
    a = math.radians(az)
    cam.location = target + Vector((math.sin(a) * dist, -math.cos(a) * dist, dist * 0.18))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)


def render_fighters(only=None):
    os.makedirs(OUTF, exist_ok=True)
    setup_fighter_render()
    names = list(FIGHTERS) + ["guardian_w1", "guardian_w4", "guardian_w8"]
    done = []
    for fid in names:
        if only and fid not in only:
            continue
        coll = f"fighter_{fid}"
        root = bpy.data.objects[f"{fid}_Root"]
        sc = 1.8 if fid.startswith("guardian") else 1.0
        idle_pose = {j: tuple(e.rotation_euler) for j, e in ((j, bpy.data.objects[f"{fid}_{j}"]) for j in JOINTS)}
        target = root.location + Vector((0, 0, 0.7 * sc))
        views = [("front", 0), ("three_quarter", -35), ("back", 180)] if not fid.startswith("guardian_w4") and not fid.startswith("guardian_w8") else [("front", -20)]
        for v, az in views:
            render_view(coll, target, 13.5 * sc, az, os.path.join(OUTF, f"{fid}_{v}.png"))
        if not fid.startswith("guardian") or fid == "guardian_w1":
            rig = type("R", (), {})()
            rig.joints = {j: bpy.data.objects[f"{fid}_{j}"] for j in JOINTS}
            base = root.location.copy()
            for k, (p, dy) in enumerate(ATTACK):
                full = dict(IDLE)
                full.update(p)
                pose(rig, full)
                root.location = base + Vector((0, dy * sc, 0))
                bpy.context.view_layer.update()
                render_view(coll, base + Vector((0, -0.8 * sc, 0.7 * sc)), 14.5 * sc, -60, os.path.join(OUTF, f"{fid}_attack{k}.png"))
            root.location = base
            for j, r in idle_pose.items():
                bpy.data.objects[f"{fid}_{j}"].rotation_euler = r
        done.append(f"{fid}:{tri_count(bpy.data.collections[coll])}")  # noqa: F821
    for c in bpy.context.scene.collection.children:
        c.hide_render = False
    import json
    json.dump({d.split(':')[0]: int(d.split(':')[1]) for d in done}, open(os.path.join(OUTF, "tris.json"), "w"), indent=1)
    return done
