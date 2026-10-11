"""Builds Map 01's props in Blender and exports them as one .glb file, one mesh per prop
(wasteland_kit.py says how the parts are coloured, joined and baked). Run headless with Blender's
own Python:

    blender --background --factory-startup --python tools/blender/build_props.py -- \
        --out assets/art/map_01/props/map_01_props.glb --previews <dir>

Each prop replaces a primitive of the Map's scenes and is built to exactly that primitive's box
(fit_to_box), centred on its origin as the primitive was, so the box a scene draws is the box it
draws today and the box its collider fills: the cover's wrecks, containers and scrap walls
(src/gameplay/maps/map_01/map_01_cover.tscn, whose evidence measures the drawn box against the
runs), and the dressing's containers, tyres, boulders and depot posts (map_01_dressing.tscn). No
prop wears a Team colour or the Fuel Can's red: rust, faded paint, steel, rubber and concrete.

    WreckPickup     6 x 1.3 x 3 m   a gutted pickup on its belly, wheels gone, junk in the bed
    WreckFlipped    6 x 1.3 x 3 m   a car on its roof, its chassis, axles and one tyre in the air
    Container       12 x 2 x 2.5 m  a corrugated container, its doors at one end
    ScrapWall       2.5 x 2 x 12 m  a barricade: crushed car bodies, sheets leaning on both faces,
                                    posts, tyres and drums at its foot
    DressingContainer7, DressingContainer8   7 and 8 x 2.5 x 4 m: olive containers in the Bases
    Tyre            0.68 m radius, 0.36 m tall: one tyre of a stack
    Boulder         1 m radius: a rough stone
    Post            0.75 m radius, 1.2 m tall: a concrete bollard of the depot
    FuelTankTrim    laid on a depot fuel tank (map_01_depot.tscn), whose cylinder, band, dome and
                    collider stay the scene's (the evidence measures them): seams, a ladder, a
                    railing round the dome, a vent and a valve, none more than 0.12 m past the
                    band, about the cylinder's centre

Sizes are Godot's x, y (height), z. Axes: Godot X and Z become Blender X and -Y, its height Blender
Z; the glTF exporter turns them back. Each prop is built on the ground at its own spot, apart from
the others (so the occlusion bake of one does not darken another), and exported about its centre.
"""

import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# Metres between the props' spots while they are built and baked.
SPACING = 20.0
# The occlusion bake's reach and ground.
AO_DISTANCE = 0.5
GROUND_SIZE = 260.0
# The props in the order of their spots.
NAMES = ["WreckPickup", "WreckFlipped", "Container", "ScrapWall", "DressingContainer7",
        "DressingContainer8", "Tyre", "Boulder", "Post", "FuelTankTrim"]
# Preview cameras: name -> (location, look-at point, orthographic scale or None); one three-quarter
# view of each prop, from a distance that fits its size.
VIEW_DISTANCE = {"Container": 2.0, "ScrapWall": 2.0, "DressingContainer7": 1.5,
        "DressingContainer8": 1.5, "Tyre": 0.4, "Boulder": 0.6, "Post": 0.5}
VIEWS = {}
for _index, _name in enumerate(NAMES):
    _scale = VIEW_DISTANCE.get(_name, 1.0)
    VIEWS[_name] = ((_index * 20.0 + 6.0 * _scale, -8.0 * _scale, 5.0 * _scale),
            (_index * 20.0, 0.0, 0.6 * min(_scale, 1.0)), None)


def spot(index):
    return (index * SPACING, 0.0)


def finish_prop(name, index, parts, size, groups, origins):
    """Fits a prop's parts to its box (Godot size: x, height, z) at its spot and records it."""
    x0, y0 = spot(index)
    length, height, width = size
    kit.fit_to_box(parts, (x0 - length / 2.0, y0 - width / 2.0, 0.0),
            (x0 + length / 2.0, y0 + width / 2.0, height))
    groups[name] = parts
    origins[name] = (x0, y0, height / 2.0)


def wreck_pickup(x0, y0, rng):
    """A gutted pickup on its belly: front toward +X."""
    p = []
    def b(n, size, at, key, bevel=0.03, rot=(0.0, 0.0, 0.0)):
        p.append(kit.box(n, size, (x0 + at[0], y0 + at[1], at[2]), key, bevel=bevel, rotation=rot))
    b("floor", (5.6, 2.6, 0.22), (0.0, 0.0, 0.11), "rust_dark")
    for side in (-1.0, 1.0):
        b("sill", (5.2, 0.16, 0.3), (0.0, side * 1.36, 0.32), "paint_khaki")
        b("side", (4.9, 0.12, 0.42), (0.1, side * 1.42, 0.66), "paint_khaki",
                rot=(side * 2.0, 0.0, side * 1.0))
        for x in (1.9, -1.8):
            p.append(kit.cylinder("drum", 0.26, 0.3, (x0 + x, y0 + side * 1.25, 0.32), "Y",
                    "gunmetal", segments=10))
            b("arch_hole", (0.9, 0.04, 0.32), (x, side * 1.49, 0.36), "hole", bevel=0.0)
        b("rust_hole", (0.3, 0.03, 0.12), (rng.uniform(-1.5, 1.0), side * 1.49, 0.62), "hole",
                bevel=0.0)
    b("bonnet", (1.5, 2.5, 0.24), (2.1, 0.0, 0.74), "paint_khaki", rot=(4.0, 6.0, 0.0))
    b("bonnet_rust", (0.6, 0.8, 0.03), (2.2, 0.5, 0.88), "rust_dark", bevel=0.0,
            rot=(4.0, 6.0, 0.0))
    b("grille", (0.15, 2.3, 0.45), (2.9, 0.0, 0.45), "steel_dark")
    b("bumper", (0.2, 2.9, 0.18), (2.95, 0.0, 0.3), "rust_dark", rot=(0.0, 0.0, 5.0))
    b("cab", (1.6, 2.7, 0.5), (0.6, 0.0, 0.75), "paint_khaki")
    b("roof", (1.4, 2.4, 0.16), (0.45, 0.0, 1.2), "paint_khaki", rot=(3.0, -4.0, 0.0))
    for side in (-1.0, 1.0):
        b("window", (1.0, 0.04, 0.22), (0.5, side * 1.33, 1.06), "glass", bevel=0.0)
    b("windscreen", (0.06, 2.3, 0.3), (1.32, 0.0, 1.06), "glass", bevel=0.0, rot=(0.0, -30.0, 0.0))
    b("bed_floor", (2.5, 2.5, 0.08), (-1.6, 0.0, 0.55), "rust_dark")
    for side in (-1.0, 1.0):
        b("bed_side", (2.6, 0.08, 0.45), (-1.6, side * 1.25, 0.8), "paint_khaki",
                rot=(side * 4.0, 0.0, 0.0))
    b("tailgate", (0.08, 2.5, 0.45), (-2.9, 0.0, 0.8), "paint_khaki", rot=(0.0, 12.0, 0.0))
    p.append(kit.cylinder("bed_drum", 0.3, 0.9, (x0 - 1.4, y0 + 0.5, 0.9), "Y", "steel_dark",
            segments=12, bevel=0.02))
    b("bed_crate", (0.6, 0.6, 0.45), (-2.2, -0.6, 0.82), "olive", rot=(0.0, 0.0, 20.0))
    return p


def wreck_flipped(x0, y0, rng):
    """A car on its roof, its chassis up: front toward +X."""
    p = []
    def b(n, size, at, key, bevel=0.03, rot=(0.0, 0.0, 0.0)):
        p.append(kit.box(n, size, (x0 + at[0], y0 + at[1], at[2]), key, bevel=bevel, rotation=rot))
    b("cabin", (2.6, 2.4, 0.5), (0.2, 0.0, 0.25), "paint_white", rot=(0.0, 3.0, 0.0))
    for side in (-1.0, 1.0):
        b("cabin_glass", (2.0, 0.04, 0.24), (0.2, side * 1.21, 0.27), "glass", bevel=0.0)
    b("body", (5.6, 2.8, 0.55), (0.0, 0.0, 0.76), "paint_white")
    b("body_rust", (1.2, 0.04, 0.3), (-1.6, 1.41, 0.8), "rust_dark", bevel=0.0)
    b("body_rust2", (0.8, 0.04, 0.25), (1.8, -1.41, 0.72), "rust_dark", bevel=0.0)
    b("pan", (5.4, 2.5, 0.06), (0.0, 0.0, 1.06), "rust_dark", bevel=0.01)
    for side in (-1.0, 1.0):
        b("rail", (5.2, 0.14, 0.12), (0.0, side * 0.7, 1.14), "steel_dark")
    for x in (1.9, -1.9):
        p.append(kit.tube("axle", (x0 + x, y0 - 1.15, 1.18), (x0 + x, y0 + 1.15, 1.18), 0.06,
                "gunmetal"))
        for side in (-1.0, 1.0):
            p.append(kit.cylinder("hub", 0.25, 0.16, (x0 + x, y0 + side * 1.22, 1.18), "Y",
                    "gunmetal", segments=10))
    p.append(kit.torus("tyre_left", 0.28, 0.1, (x0 + 1.9, y0 + 1.3, 1.18), "Y", "rubber",
            segments=16, section_width=0.11))
    p.append(kit.tube("exhaust", (x0 + 2.3, y0 + 0.4, 1.17), (x0 - 2.7, y0 + 0.4, 1.17), 0.045,
            "gunmetal"))
    b("tank", (0.8, 1.1, 0.16), (-1.0, -0.4, 1.17), "steel_dark")
    b("bumper_front", (0.18, 2.8, 0.2), (2.85, 0.0, 0.6), "rust_dark", rot=(0.0, 0.0, -4.0))
    b("bumper_back", (0.18, 2.7, 0.2), (-2.85, 0.0, 0.62), "rust_dark")
    return p


def container(x0, y0, length, width, height, key, rng, door_side=1.0):
    """A corrugated container along X, its doors on the door_side end."""
    p = []
    def b(n, size, at, k, bevel=0.0, rot=(0.0, 0.0, 0.0)):
        p.append(kit.box(n, size, (x0 + at[0], y0 + at[1], at[2]), k, bevel=bevel, rotation=rot))
    inner = width - 0.08
    b("shell", (length - 0.1, inner, height - 0.06), (0.0, 0.0, height / 2.0), key, bevel=0.02)
    rib_count = int(length / 0.36)
    for i in range(rib_count):
        x = -length / 2.0 + 0.3 + i * (length - 0.6) / (rib_count - 1)
        for side in (-1.0, 1.0):
            b("rib", (0.12, 0.05, height - 0.3), (x, side * (width / 2.0 - 0.025),
                    height / 2.0), key)
    for i in range(int(length / 0.6)):
        x = -length / 2.0 + 0.4 + i * 0.6
        b("roof_rib", (0.1, inner - 0.2, 0.03), (x, 0.0, height - 0.015), key)
    for side in (-1.0, 1.0):
        for z in (0.07, height - 0.07):
            b("rail", (length, 0.12, 0.14), (0.0, side * (width / 2.0 - 0.06), z), "steel_dark")
        for end in (-1.0, 1.0):
            b("post", (0.2, 0.2, height), (end * (length / 2.0 - 0.1), side * (width / 2.0 - 0.1),
                    height / 2.0), "steel_dark")
    door_x = door_side * (length / 2.0 - 0.02)
    for side in (-1.0, 1.0):
        b("door", (0.04, inner / 2.0 - 0.06, height - 0.3), (door_x, side * inner / 4.0,
                height / 2.0), key)
        for offset in (0.2, 0.5):
            p.append(kit.tube("lock_bar", (x0 + door_x + door_side * 0.04, y0 + side * offset,
                    0.25), (x0 + door_x + door_side * 0.04, y0 + side * offset, height - 0.25),
                    0.025, "steel"))
    for i in range(3):
        side = rng.choice((-1.0, 1.0))
        b("rust_streak", (rng.uniform(0.4, 1.0), 0.02, rng.uniform(0.4, 1.0)),
                (rng.uniform(-length / 2.0 + 1.0, length / 2.0 - 1.0), side * (width / 2.0 + 0.0),
                rng.uniform(0.5, height - 0.5)), "rust_dark")
    return p


def scrap_wall(x0, y0, rng):
    """A barricade of scrap along Y, 12 m: crushed car bodies stacked in its core, sheets leaning on
    both faces, posts, and tyres and drums at its foot."""
    p = []
    bodies = ["paint_khaki", "paint_white", "rust_dark", "scrap", "container_grey"]
    y = -5.9
    while y < 5.9:
        length = rng.uniform(2.6, 3.6)
        centre = min(y + length / 2.0, 5.9 - length / 2.0)
        z = 0.0
        for level in range(rng.randint(2, 3)):
            height = rng.uniform(0.45, 0.65)
            if z + height > 2.0:
                break
            p.append(kit.box("crushed", (rng.uniform(1.4, 1.8), length, height),
                    (x0 + rng.uniform(-0.12, 0.12), y0 + centre, z + height / 2.0),
                    rng.choice(bodies), bevel=0.05,
                    rotation=(rng.uniform(-4.0, 4.0), rng.uniform(-3.0, 3.0),
                    rng.uniform(-6.0, 6.0))))
            z += height
        y += length * 0.9
    for i in range(7):
        py = -6.0 + 0.2 + i * (11.6 / 6.0)
        for side in (-1.0, 1.0):
            p.append(kit.box("post", (0.14, 0.14, 2.0), (x0 + side * 0.95, y0 + py, 1.0),
                    "steel_dark"))
    keys = ["scrap", "rust_dark", "steel_dark", "paint_khaki", "scrap", "paint_white"]
    y = -6.0
    while y < 6.0:
        width = rng.uniform(1.0, 1.8)
        for side in (-1.0, 1.0):
            height = rng.uniform(1.1, 1.9)
            centre = min(y + width / 2.0, 6.0 - width / 2.0)
            p.append(kit.box("sheet", (0.05, width, height), (x0 + side * 1.05,
                    y0 + centre, height / 2.0), rng.choice(keys),
                    rotation=(rng.uniform(-4.0, 4.0), -side * rng.uniform(4.0, 10.0), 0.0)))
        y += width * 0.85
    for i in range(6):
        side = rng.choice((-1.0, 1.0))
        y = rng.uniform(-5.4, 5.4)
        if rng.random() < 0.5:
            for level in range(rng.randint(1, 3)):
                p.append(kit.torus("tyre", 0.3, 0.11, (x0 + side * 0.95, y0 + y,
                        0.11 + level * 0.22), "Z", "rubber", segments=14, section_width=0.11))
        else:
            p.append(kit.cylinder("drum", 0.28, 0.85, (x0 + side * 0.97, y0 + y, 0.425), "Z",
                    rng.choice(("steel_dark", "olive")), segments=12, bevel=0.02))
    return p


def tyre(x0, y0):
    """One tyre lying flat, a ring with tread blocks round it."""
    p = [kit.torus("tyre", 0.5, 0.17, (x0, y0, 0.18), "Z", "rubber", segments=20,
            section_width=0.18)]
    for k in range(16):
        a = 2.0 * math.pi * k / 16
        p.append(kit.box("tread", (0.08, 0.16, 0.3), (x0 + math.cos(a) * 0.645, y0 + math.sin(a)
                * 0.645, 0.18), "tread", rotation=(0.0, 0.0, math.degrees(a))))
    return p


def boulder(x0, y0, rng):
    """A rough stone of 1 m radius."""
    import bmesh
    from mathutils import Vector
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for vert in bm.verts:
        vert.co *= rng.uniform(0.86, 1.08)
        vert.co.z = max(vert.co.z, -0.85)
    bm.transform(kit._matrix((x0, y0, 1.0), (0.0, 0.0, rng.uniform(0.0, 360.0))))
    obj = kit._finish_part("boulder", bm, "rock")
    tones = ((0.5, 0.31, 0.19), (0.44, 0.27, 0.16), (0.56, 0.37, 0.24))
    kit.face_colours(obj, lambda c, n: rng.choice(tones) if n.z < 0.6 else (0.6, 0.42, 0.28))
    return [obj]


def post(x0, y0):
    """A concrete bollard with a dark band and a worn cap."""
    return [kit.cylinder("bollard", 0.75, 1.1, (x0, y0, 0.55), "Z", "concrete", segments=16,
            bevel=0.04),
            kit.cylinder("band", 0.76, 0.18, (x0, y0, 0.8), "Z", "steel_dark", segments=16),
            kit.cylinder("cap", 0.6, 0.1, (x0, y0, 1.15), "Z", "steel_dark", segments=16,
                    bevel=0.02)]


def fuel_tank_trim(x0, y0):
    """The trim of a fuel tank whose cylinder (2.5 m radius, 3 m tall) stands centred on (x0, y0,
    1.5) under a dome 0.6 m high, its band 2.56 m in radius at the foot: seam rings and seams, a
    ladder on the +X side, a railing round the dome, a vent and a valve on the band."""
    p = []
    centre_z = 1.5
    for z in (-0.4, 0.55):
        p.append(kit.torus("seam_ring", 2.505, 0.025, (x0, y0, centre_z + z), "Z", "steel_dark",
                segments=32, section_segments=4))
    for k in range(8):
        a = 2.0 * math.pi * (k + 0.5) / 8
        p.append(kit.box("seam", (0.05, 0.03, 2.2), (x0 + math.cos(a) * 2.51, y0 + math.sin(a)
                * 2.51, centre_z + 0.3), "steel_dark", rotation=(0.0, 0.0, math.degrees(a))))
    for side in (-0.25, 0.25):
        p.append(kit.tube("stile", (x0 + 2.62, y0 + side, 0.0), (x0 + 2.62, y0 + side, 3.2), 0.03,
                "steel", segments=6))
    for k in range(1, 10):
        z = k * 3.2 / 10
        p.append(kit.tube("rung", (x0 + 2.62, y0 - 0.25, z), (x0 + 2.62, y0 + 0.25, z), 0.018,
                "steel", segments=4))
    count = 16
    rim = 2.3
    for k in range(count):
        a = 2.0 * math.pi * k / count
        x, y = x0 + math.cos(a) * rim, y0 + math.sin(a) * rim
        p.append(kit.tube("rail_post", (x, y, 3.2), (x, y, 4.05), 0.025, "steel_dark", segments=4))
        a1 = 2.0 * math.pi * (k + 1) / count
        p.append(kit.tube("rail", (x, y, 4.05), (x0 + math.cos(a1) * rim, y0 + math.sin(a1) * rim,
                4.05), 0.025, "steel_dark", segments=4))
    p.append(kit.tube("vent", (x0 - 1.0, y0 + 0.6, 3.4), (x0 - 1.0, y0 + 0.6, 4.1), 0.06,
            "gunmetal", segments=8))
    p.append(kit.cylinder("vent_cap", 0.12, 0.06, (x0 - 1.0, y0 + 0.6, 4.12), "Z", "gunmetal",
            segments=8))
    p.append(kit.tube("valve_stub", (x0, y0 - 2.5, 0.35), (x0, y0 - 2.62, 0.35), 0.05, "gunmetal",
            segments=8))
    p.append(kit.torus("valve_wheel", 0.14, 0.02, (x0, y0 - 2.64, 0.35), "Y", "steel_dark",
            segments=12, section_segments=4))
    return p


def main():
    args = kit.parse_args()
    kit.reset_scene()
    rng = random.Random(20261010)
    groups, origins = {}, {}
    finish_prop("WreckPickup", 0, wreck_pickup(*spot(0), rng), (6.0, 1.3, 3.0), groups, origins)
    finish_prop("WreckFlipped", 1, wreck_flipped(*spot(1), rng), (6.0, 1.3, 3.0), groups, origins)
    finish_prop("Container", 2, container(*spot(2), 12.0, 2.5, 2.0, "container_grey", rng),
            (12.0, 2.0, 2.5), groups, origins)
    finish_prop("ScrapWall", 3, scrap_wall(*spot(3), rng), (2.5, 2.0, 12.0), groups, origins)
    finish_prop("DressingContainer7", 4, container(*spot(4), 7.0, 4.0, 2.5, "olive", rng),
            (7.0, 2.5, 4.0), groups, origins)
    finish_prop("DressingContainer8", 5, container(*spot(5), 8.0, 4.0, 2.5, "olive", rng, -1.0),
            (8.0, 2.5, 4.0), groups, origins)
    finish_prop("Tyre", 6, tyre(*spot(6)), (1.36, 0.36, 1.36), groups, origins)
    finish_prop("Boulder", 7, boulder(*spot(7), rng), (2.0, 2.0, 2.0), groups, origins)
    finish_prop("Post", 8, post(*spot(8)), (1.5, 1.2, 1.5), groups, origins)
    x0, y0 = spot(9)
    # A stand-in of the tank for the occlusion bake only: without a key it is no part and not
    # exported.
    stand_in = kit.cylinder("tank_stand_in", 2.56, 3.0, (x0, y0, 1.5), "Z", "steel", segments=24)
    del stand_in["key"]
    groups["FuelTankTrim"] = fuel_tank_trim(x0, y0)
    origins["FuelTankTrim"] = (x0, y0, 1.5)
    kit.finish(args["out"], args["previews"], VIEWS, ground_size=GROUND_SIZE,
            ao_distance=AO_DISTANCE, groups=groups, preview_ground=GROUND_SIZE, origins=origins)


main()
