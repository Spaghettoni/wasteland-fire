"""Builds the trim of Map 01's Bases in Blender and exports it as one .glb file, one mesh per
piece (wasteland_kit.py says how the parts are coloured, joined and baked). Run headless with
Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_base.py -- \
        --out assets/art/map_01/base/map_01_base.glb --previews <dir>

A Base's walls, corner towers and Garage stay the boxes of
src/gameplay/maps/map_01/compound_base.tscn, drawn with the wall material (welded plates,
tools/blender/build_wall_textures.py) or a corner tower's Team colour; their colliders and the
boxes the evidence measures are unchanged. Each piece here is laid on such a box as a second mesh
(the scene's Trim nodes): a steel cap along the top, a concrete footing, I-beam posts on both
faces and, on the outer walls, a run of barbed wire; on a corner tower a parapet, corner guards, a
band, window slits and a roof plate, all neutral steel so the tower keeps its Team colour; on the
water tower a ladder up one leg (a railing round the platform would be a fifth piece on the tower
top's render layer, which the camera from above leaves out and the evidence counts as four). Each
mesh is centred as the box it lies on (the ladder at its foot), in the box's own axes.

    WallBackTrim    on a 32 x 3.2 x 1.3 m wall along X
    WallSideTrim    on a 1.3 x 3.2 x 30 m wall along Z
    WallGateTrim    on a 10.5 x 3.2 x 1.3 m wall along X
    TowerTrim       on a 4.3 x 6 x 4.3 m corner tower
    GarageBackTrim  on a 14 x 2.5 x 1 m wall along X
    GarageSideTrim  on a 1 x 2.5 x 10 m wall along Z
    WaterTowerLadder  up the water tower's 8.3 m to its platform
    TurretPedestalTrim  on a Turret's drum (1 m radius, 1 m tall): a bolt ring, ribs, a hatch
    TurretPedestalTrimTall  on the grown Turret's drum (1 m radius, 2.2 m tall, Story 015): a bolt
                        ring, a collar, taller ribs and a hatch; the 1 m drum's trim above stays
                        for the evidence's frozen Turret (tools/evidence/frozen/)
    TurretHeadTrim      on its turning head: vents, a sight, an aerial, a muzzle brake and a
                        sleeve on the barrel (src/gameplay/defences/turret.tscn keeps the drum, the
                        dome, the Team band and the barrel)

Sizes are Godot's x, y (height), z. Axes: Godot X and Z become Blender X and -Y, its height Blender
Z. Each piece is built on the ground at its own spot with a stand-in of its box (not exported), so
the occlusion bake darkens it where it meets the box.
"""

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bpy  # noqa: E402

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

SPACING = 45.0
# Posts along a wall: about this far apart, how wide, how far they stand off the face.
POST_SPACING = 4.0
POST_WIDTH = 0.3
POST_OUT = 0.05
# The cap and the footing: their height and how far they reach past the faces.
CAP_HEIGHT = 0.08
CAP_OUT = 0.05
FOOT_HEIGHT = 0.22
FOOT_OUT = 0.04
# Barbed wire: the height of its zigzag above the cap and the length of one zig.
WIRE_HEIGHT = 0.3
WIRE_STEP = 0.5
AO_DISTANCE = 0.6
# The grown Turret's drum (src/gameplay/defences/turret.tscn, Story 015): 1 m radius, this tall.
TURRET_DRUM_HEIGHT = 2.2
GROUND_SIZE = 500.0
NAMES = ["WallBackTrim", "WallSideTrim", "WallGateTrim", "TowerTrim", "GarageBackTrim",
        "GarageSideTrim", "WaterTowerLadder", "TurretPedestalTrim", "TurretHeadTrim",
        "TurretPedestalTrimTall"]
VIEWS = {}
for _index, _name in enumerate(NAMES):
    VIEWS[_name] = ((_index * SPACING + 9.0, -14.0, 9.0), (_index * SPACING, 0.0, 1.8), None)


def spot(index):
    return (index * SPACING, 0.0)


def stand_in(size, centre):
    """A box like the one the trim lies on, for the occlusion bake only: no key, not exported."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=centre)
    obj = bpy.context.active_object
    obj.scale = size
    return obj


def wall_trim(x0, y0, length, thickness, height, along_x, wire):
    """The trim of a wall: length along X (along_x) or Y, thickness across, height up, standing on
    the ground at (x0, y0)."""
    p = []

    def b(name, l, t, h, a, c, z, key, bevel=0.01):
        """A box l along the wall, t across, h up, at a along, c across and z up."""
        size = (l, t, h) if along_x else (t, l, h)
        at = (x0 + a, y0 + c, z) if along_x else (x0 + c, y0 + a, z)
        p.append(kit.box(name, size, at, key, bevel=bevel))

    b("cap", length + CAP_OUT * 2.0, thickness + CAP_OUT * 2.0, CAP_HEIGHT, 0.0, 0.0,
            height + CAP_HEIGHT / 2.0, "gunmetal")
    b("footing", length, thickness + FOOT_OUT * 2.0, FOOT_HEIGHT, 0.0, 0.0, FOOT_HEIGHT / 2.0,
            "concrete")
    posts = max(1, round(length / POST_SPACING))
    for i in range(posts + 1):
        a = -length / 2.0 + POST_WIDTH / 2.0 + i * (length - POST_WIDTH) / posts
        for side in (-1.0, 1.0):
            c = side * (thickness / 2.0 + POST_OUT / 2.0)
            b("post", POST_WIDTH, POST_OUT, height, a, c, height / 2.0, "gunmetal")
            b("flange", POST_WIDTH + 0.06, POST_OUT + 0.02, 0.06, a, c, height - 0.03, "gunmetal")
    if wire:
        top = height + CAP_HEIGHT
        steps = int(length / WIRE_STEP)
        for side in (-0.12, 0.12):
            for i in range(steps):
                a0 = -length / 2.0 + i * length / steps
                a1 = a0 + length / steps
                z0 = top + (WIRE_HEIGHT if (i % 2 == 0) == (side > 0) else 0.04)
                z1 = top + (0.04 if (i % 2 == 0) == (side > 0) else WIRE_HEIGHT)
                start = (x0 + a0, y0 + side, z0) if along_x else (x0 + side, y0 + a0, z0)
                end = (x0 + a1, y0 + side, z1) if along_x else (x0 + side, y0 + a1, z1)
                p.append(kit.tube("wire", start, end, 0.012, "steel", segments=4))
        for i in range(int(length / 2.5) + 1):
            a = -length / 2.0 + i * length / int(length / 2.5)
            for side in (-1.0, 1.0):
                start = (x0 + a, y0, top) if along_x else (x0, y0 + a, top)
                end = ((x0 + a, y0 + side * 0.16, top + WIRE_HEIGHT + 0.04) if along_x
                        else (x0 + side * 0.16, y0 + a, top + WIRE_HEIGHT + 0.04))
                p.append(kit.tube("wire_arm", start, end, 0.018, "steel_dark", segments=4))
    return p


def tower_trim(x0, y0, size, height):
    """A corner tower's neutral trim: parapet, corner guards, a band, window slits, roof plate."""
    p = []
    half = size / 2.0
    for side in (-1.0, 1.0):
        for k in range(3):
            a = -half + 0.45 + k * (size - 0.9) / 2.0
            p.append(kit.box("merlon", (0.9, 0.36, 0.45), (x0 + a, y0 + side * (half - 0.16),
                    height + 0.225), "steel_dark", bevel=0.02))
            p.append(kit.box("merlon", (0.36, 0.9, 0.45), (x0 + side * (half - 0.16), y0 + a,
                    height + 0.225), "steel_dark", bevel=0.02))
        for other in (-1.0, 1.0):
            p.append(kit.box("guard", (0.16, 0.16, height), (x0 + side * (half + 0.02),
                    y0 + other * (half + 0.02), height / 2.0), "gunmetal", bevel=0.01))
        p.append(kit.box("slit", (1.6, 0.04, 0.3), (x0, y0 + side * (half + 0.02), height - 1.0),
                "glass", bevel=0.0))
        p.append(kit.box("slit", (0.04, 1.6, 0.3), (x0 + side * (half + 0.02), y0, height - 1.0),
                "glass", bevel=0.0))
    p.append(kit.box("band", (size + 0.06, size + 0.06, 0.22), (x0, y0, height * 0.42),
            "steel_dark", bevel=0.01))
    p.append(kit.box("roof", (size - 0.4, size - 0.4, 0.05), (x0, y0, height + 0.025), "gunmetal"))
    return p


def water_tower_ladder(x0, y0, height):
    """A ladder from the ground to the platform, its rungs along X, from z 0 up."""
    p = []
    for side in (-0.22, 0.22):
        p.append(kit.tube("stile", (x0 + side, y0, 0.0), (x0 + side, y0, height), 0.03, "steel",
                segments=6))
    rungs = int(height / 0.35)
    for k in range(1, rungs):
        z = k * height / rungs
        p.append(kit.tube("rung", (x0 - 0.22, y0, z), (x0 + 0.22, y0, z), 0.018, "steel",
                segments=4))
    for k in range(4, rungs, 3):
        z = k * height / rungs
        p.append(kit.box("hoop", (0.6, 0.04, 0.04), (x0, y0 - 0.32, z), "steel_dark", bevel=0.0))
    return p


def turret_pedestal_trim(x0, y0):
    """On a Turret's drum (1 m radius, 1 m tall, standing on the ground): a bolt ring at its foot,
    six ribs and a hatch."""
    p = [kit.cylinder("bolt_ring", 1.07, 0.07, (x0, y0, 0.035), "Z", "gunmetal", segments=20)]
    for k in range(6):
        a = 2.0 * math.pi * k / 6 + 0.26
        p.append(kit.box("rib", (0.05, 0.09, 0.82), (x0 + math.cos(a) * 1.01,
                y0 + math.sin(a) * 1.01, 0.5), "gunmetal", rotation=(0.0, 0.0, math.degrees(a))))
    p.append(kit.box("hatch", (0.03, 0.42, 0.5), (x0 + 1.005, y0, 0.45), "steel_dark",
            bevel=0.005))
    return p


def turret_pedestal_trim_tall(x0, y0, height):
    """On the grown Turret's drum (1 m radius, `height` tall, standing on the ground): a bolt ring
    at its foot, a collar round its top, six ribs between them and a hatch."""
    p = [kit.cylinder("bolt_ring", 1.07, 0.07, (x0, y0, 0.035), "Z", "gunmetal", segments=20),
            kit.cylinder("collar", 1.05, 0.1, (x0, y0, height - 0.05), "Z", "gunmetal",
                    segments=20)]
    rib = height - 0.4
    for k in range(6):
        a = 2.0 * math.pi * k / 6 + 0.26
        p.append(kit.box("rib", (0.05, 0.09, rib), (x0 + math.cos(a) * 1.01,
                y0 + math.sin(a) * 1.01, height / 2.0), "gunmetal",
                rotation=(0.0, 0.0, math.degrees(a))))
    p.append(kit.box("hatch", (0.03, 0.5, 0.9), (x0 + 1.005, y0, 0.6), "steel_dark",
            bevel=0.005))
    return p


def turret_head_trim(x0, y0):
    """On a Turret's turning head (its frame's origin on the drum's top; the barrel forward
    along +Y here, Godot's -Z): louvres on the back of the dome, a sight box and an aerial on top, a
    sleeve at the barrel's root and a muzzle brake at its tip (the tip 1.7 m out at 0.45 m up)."""
    p = []
    for k in range(3):
        p.append(kit.box("louvre", (0.5, 0.04, 0.05), (x0, y0 - 0.87, 0.3 + k * 0.12), "gunmetal",
                rotation=(-12.0, 0.0, 0.0)))
    p.append(kit.box("sight", (0.2, 0.3, 0.15), (x0 + 0.3, y0 + 0.2, 0.86), "steel_dark",
            bevel=0.02))
    p.append(kit.box("sight_glass", (0.14, 0.02, 0.08), (x0 + 0.3, y0 + 0.36, 0.87), "glass"))
    p.append(kit.tube("aerial", (x0 - 0.35, y0 - 0.3, 0.75), (x0 - 0.38, y0 - 0.34, 1.6), 0.01,
            "steel", segments=4))
    p.append(kit.cylinder("sleeve", 0.17, 0.32, (x0, y0 + 0.66, 0.45), "Y", "gunmetal",
            segments=10))
    p.append(kit.box("muzzle", (0.32, 0.18, 0.32), (x0, y0 + 1.62, 0.45), "steel_dark", bevel=0.02))
    p.append(kit.box("muzzle_hole", (0.14, 0.02, 0.14), (x0, y0 + 1.715, 0.45), "hole"))
    return p


def main():
    args = kit.parse_args()
    kit.reset_scene()
    groups, origins = {}, {}
    walls = [("WallBackTrim", 32.0, 1.3, 3.2, True, True),
            ("WallSideTrim", 30.0, 1.3, 3.2, False, True),
            ("WallGateTrim", 10.5, 1.3, 3.2, True, True), None,
            ("GarageBackTrim", 14.0, 1.0, 2.5, True, False),
            ("GarageSideTrim", 10.0, 1.0, 2.5, False, False)]
    for index, wall in enumerate(walls):
        if wall is None:
            continue
        name, length, thickness, height, along_x, wire = wall
        x0, y0 = spot(index)
        stand_in((length, thickness, height) if along_x else (thickness, length, height),
                (x0, y0, height / 2.0))
        groups[name] = wall_trim(x0, y0, length, thickness, height, along_x, wire)
        origins[name] = (x0, y0, height / 2.0)
    x0, y0 = spot(3)
    stand_in((4.3, 4.3, 6.0), (x0, y0, 3.0))
    groups["TowerTrim"] = tower_trim(x0, y0, 4.3, 6.0)
    origins["TowerTrim"] = (x0, y0, 3.0)
    x0, y0 = spot(7)
    stand_in((2.0, 2.0, 1.0), (x0, y0, 0.5))
    groups["TurretPedestalTrim"] = turret_pedestal_trim(x0, y0)
    origins["TurretPedestalTrim"] = (x0, y0, 0.5)
    x0, y0 = spot(8)
    stand_in((1.7, 1.7, 0.8), (x0, y0, 0.4))
    groups["TurretHeadTrim"] = turret_head_trim(x0, y0)
    origins["TurretHeadTrim"] = (x0, y0, 0.0)
    x0, y0 = spot(9)
    stand_in((2.0, 2.0, TURRET_DRUM_HEIGHT), (x0, y0, TURRET_DRUM_HEIGHT / 2.0))
    groups["TurretPedestalTrimTall"] = turret_pedestal_trim_tall(x0, y0, TURRET_DRUM_HEIGHT)
    origins["TurretPedestalTrimTall"] = (x0, y0, TURRET_DRUM_HEIGHT / 2.0)
    x0, y0 = spot(6)
    groups["WaterTowerLadder"] = water_tower_ladder(x0, y0, 8.3)
    origins["WaterTowerLadder"] = (x0, y0, 0.0)
    kit.finish(args["out"], args["previews"], VIEWS, ground_size=GROUND_SIZE,
            ao_distance=AO_DISTANCE, groups=groups, preview_ground=GROUND_SIZE, origins=origins)


main()
