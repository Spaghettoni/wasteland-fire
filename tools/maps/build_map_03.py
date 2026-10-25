"""Builds Map 03, the archipelago, from the layout Martin approved on 2026-10-25 (Story 054).

Writes src/gameplay/maps/map_03/: map_03.tscn, garage_base.tscn (a Team's Garage, the Base the Players
spawn and swap at), flag_fortress.tscn (a Team's flag fortress, where its Flag stands and where the
other Team's Flag is brought to win) and map_03_tyre_track_settings.tres. The scenes are never
edited by hand: change the tables below and run the script again (tools/maps/readme.md).

The layout (design/source/wasteland-fire-map-03-2026-10-25.svg) is in metres in the Map's own frame:
x east, z south, the origin in the middle, 240 x 240 m of sea with five islands. Orange holds the
west, Teal the east, mirror images about x = 0. Each Team's Garage is in its north corner and its
flag fortress in its south corner, so the Flag a Team goes for is in the corner opposite its Garage
(Martin, 2026-10-25: "garaz bude v 1 rohu a vlajka co sa snazis ukradnut bude v protilahlom").
Shallows join the islands (fords, which slow ground Units); everywhere else the sea stops every
ground Unit and only the Gyrocopter crosses it.

The Garage and the fortress are cut out of Map 01's compound (map_01/compound_base.tscn): the
Garage takes its spawn spots, its Garage and its Marking, the fortress its walls, towers, water
tower, Flag Walls, Turrets, Flag and seat, and its zone as the fortress's flag zone (Story 053:
Base.flag_zone). The Garage is the Base; the map's instance of it points flag, flag_seat, flag_zone,
color_meshes and structures at its Team's fortress.

Needs no package beyond Python 3. Implements: production/epics/wasteland-fire/story-054-map-03-archipelago.md.
Run from the repository root: python3 tools/maps/build_map_03.py
"""

import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tscn import Scene, color, node_paths, packed_vec2, transform, vec2, vec3  # noqa: E402
from shapes import pool_outline  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "src", "gameplay", "maps", "map_03")
RES = "res://src/gameplay/maps/map_03"
COMPOUND = os.path.join(ROOT, "src", "gameplay", "maps", "map_01", "compound_base.tscn")

# --- The layout (Orange's half; Teal's is its mirror image, x -> -x) ---------------------------

HALF = 120.0  # the sea runs to +-HALF; the Map's edge stops even the Gyrocopter there
SMOOTH_STEPS = 6  # points per side of an island's rounded outline

# Islands: a closed outline through these points, rounded (Catmull-Rom).
ISLAND_GARAGE = [(-112, -108), (-70, -114), (-40, -100), (-36, -68), (-50, -46), (-84, -42), (-110, -50), (-116, -80)]
ISLAND_FORTRESS = [(-114, 52), (-80, 46), (-52, 66), (-56, 102), (-90, 114), (-112, 108), (-118, 80)]
ISLAND_MIDDLE = [(-40, -22), (-16, -44), (16, -44), (40, -22), (40, 22), (16, 44), (-16, 44), (-40, 22)]

# Shallows: (from, to, width) in metres; the ford runs from point to point and reaches 4 m into
# each island so no seam is left at the shore.
FORD_WIDTH = 14.0
FORDS = [
    ((-49, -51), (-27, -31)),     # Garage island <-> middle
    ((-101, -52), (-101, 54)),    # Garage island <-> own fortress (the west sandbar)
    ((-31, 31), (-57, 67)),       # middle <-> own fortress
]
FORDS_SHARED = [
    ((-42, -100), (42, -100)),    # north channel: Garage island <-> the other Team's Garage island
    ((-58, 104), (58, 104)),      # south channel: fortress <-> the other Team's fortress
]
# Puddles: small fords on the islands, (centre, length, width, yaw).
PUDDLES = [((-62, -62), 9.0, 5.0, 30.0), ((-88, -52), 8.0, 5.0, -20.0), ((-18, 28), 9.0, 5.0, 60.0), ((-112, 90), 8.0, 4.0, 0.0)]

# Each Team's Garage: its centre and its yaw (its open side, the compound's local -z, toward the
# middle ford); and its fortress, its Gate toward the middle (east for Orange).
GARAGE = ((-86.0, -76.0), -135.0)
FORTRESS = ((-88.0, 82.0), -90.0)

# Supply: Fuel buildings (zone on their +x side) and ammunition buildings (zone on their +x side);
# a yaw of 180 turns the zone to -x. Teal's are mirrored and turned round.
FUEL = [((-60.0, -98.0), 0.0), ((-26.0, 0.0), 0.0)]
AMMO = [((-104.0, -62.0), 0.0), ((-110.0, 102.0), 0.0)]

# Cover, all of it breakable or crossable: wrecks (centre, yaw), small buildings, Bushes.
WRECKS = [((-20, -26), 30.0), ((-6, 0), 90.0), ((-78, -94), 10.0), ((-101, 10), 80.0), ((-44, 50), -45.0),
          ((-20, -100), 0.0), ((-26, 104), 0.0)]
# Small buildings, all breakable (Martin, 2026-10-25: "v strede ostrova su nerozbitne budovy, tie tiez nechcem. ked tak,
# tak rozbitne": the middle's and the Garage island's rocks became these): kind, centre, yaw.
SHACKS = [("shack_long", (-30, 16), 0.0), ("shack_square", (-82, 106), 0.0), ("shack_long", (-8, -12), 60.0),
          ("shack_square", (-8, 16), 20.0), ("shack_square", (-96, -96), 35.0)]
BUSHES = [(-30, -14), (-8, -32), (-8, 34), (-62, -74), (-72, -56), (-108, -96), (-48, -82), (-70, 108),
          (-110, 64), (-64, -104), (-62, 80), (-34, -2)]

# How far beyond each outline the sea's invisible wall is cut, so a Unit at the shore stands on sand.
# The water's heights (Story 058): a ford's water top under the islands' sand top (0.002), so an island hides the part of a ford
# that reaches onto it, over the ford's sand bed and the sea; a puddle's on the sand. Each pool is a thin slab. A puddle slows
# Units in a box this share of its pool's size, so no corner of the box lies outside the pool.
FORD_WATER_TOP = -0.03
POOL_TOP = 0.02
POOL_DEPTH = 0.02
BED_TOP = -0.08
POOL_BOX_SHARE = 0.75

SEA_WALL_HEIGHT = 0.4  # below the shooting height (0.5 m): a Turret sees and Shots fly over the water

# --- The scenes it uses ----------------------------------------------------------------------

MAP_FIELD = "res://src/gameplay/maps/map_field.gd"
TOKEN_STOCK = "res://src/gameplay/maps/data/token_stock.tres"
TEAM_ORANGE = "res://src/gameplay/split_screen/data/team_orange_material.tres"
TEAM_TEAL = "res://src/gameplay/split_screen/data/team_teal_material.tres"
FORD = "res://src/gameplay/maps/ford.tscn"
AMMO_BUILDING = "res://src/gameplay/supply/ammo_building.tscn"
FUEL_BUILDING = "res://src/gameplay/maps/map_02/map_02_fuel_building.tscn"
TYRE_TRACKS = "res://src/gameplay/maps/tyre_tracks.tscn"
TYRE_TRACK_SETTINGS_SCRIPT = "res://src/gameplay/maps/tyre_track_settings.gd"
BUSH = "res://src/gameplay/cover/bush.tscn"
WRECK = "res://src/gameplay/cover/wreck.tscn"
SHACK = "res://src/gameplay/cover/{}.tscn"
SAND = "res://src/gameplay/maps/map_01/materials/sand.tres"
SEA = "res://src/gameplay/maps/map_01/materials/sea.tres"
FORD_MATERIAL = "res://src/gameplay/maps/map_01/materials/ford.tres"
TEAM_MATERIAL = "res://src/gameplay/split_screen/data/team_{}_material.tres"

FLAT = "Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, {x}, {y}, {z})"
SUN = "Transform3D(0.81915206, 0.40557979, -0.40557979, 0, 0.70710678, 0.70710678, 0.57357645, -0.57922797, 0.57922797, 0, 0, 0)"


def mirror(point):
    return -point[0], point[1]


def rounded(points, steps=SMOOTH_STEPS):
    """A closed Catmull-Rom outline through the points, `steps` points per side."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in (0, 1)))
    return out


def ford_rect(a, b, width=FORD_WIDTH, reach=2.0):
    """The ford from a to b as (centre, length, width, yaw): its local z runs from a to b."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz) + 2 * reach
    return ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0), length, width, math.degrees(math.atan2(dx, dz))


def rect_outline(centre, length, width, yaw):
    """The four corners of a ford's rectangle, in the Map's (x, z)."""
    yaw_r = math.radians(yaw)
    along = (math.sin(yaw_r), math.cos(yaw_r))
    across = (math.cos(yaw_r), -math.sin(yaw_r))
    out = []
    for sa, sw in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        out.append((centre[0] + along[0] * sa * length / 2 + across[0] * sw * width / 2,
                    centre[1] + along[1] * sa * length / 2 + across[1] * sw * width / 2))
    return out


def all_fords():
    """Every ford and puddle of the Map as (name, centre, length, width, yaw)."""
    fords = []
    for index, (a, b) in enumerate(FORDS):
        for side, (pa, pb) in (("West", (a, b)), ("East", (mirror(a), mirror(b)))):
            centre, length, width, yaw = ford_rect(pa, pb)
            fords.append((f"Ford{side}{index + 1}", centre, length, width, yaw))
    for index, (a, b) in enumerate(FORDS_SHARED):
        centre, length, width, yaw = ford_rect(a, b, reach=0.0)
        fords.append((("FordNorth", "FordSouth")[index], centre, length, width, yaw))
    for index, (centre, length, width, yaw) in enumerate(PUDDLES):
        fords.append((f"PuddleWest{index + 1}", centre, length, width, yaw))
        fords.append((f"PuddleEast{index + 1}", mirror(centre), length, width, -yaw))
    return fords


def islands():
    out = [("IslandMiddle", rounded(ISLAND_MIDDLE))]
    for name, points in (("Garage", ISLAND_GARAGE), ("Fortress", ISLAND_FORTRESS)):
        west = rounded(points)
        out.append((f"Island{name}West", west))
        out.append((f"Island{name}East", [mirror(p) for p in reversed(west)]))
    return out


# --- Cutting Map 01's compound in two ---------------------------------------------------------

def compound_parts():
    """compound_base.tscn as its header (resources) and its node blocks, each (path, head, body)."""
    with open(COMPOUND, encoding="utf-8") as handle:
        text = handle.read()
    blocks = re.split(r"\n(?=\[)", text)
    header, nodes = [], []
    for block in blocks:
        first = block.split("\n", 1)[0]
        if first.startswith("[node"):
            name = re.search(r'name="([^"]+)"', first).group(1)
            parent = re.search(r'parent="([^"]+)"', first)
            path = name if parent is None else (name if parent.group(1) == "." else f"{parent.group(1)}/{name}")
            if parent is None:
                path = "."
            nodes.append((path, first, block.split("\n", 1)[1] if "\n" in block else ""))
        elif not first.startswith("[gd_scene") and not first.startswith("[editable"):
            header.append(block.strip())
    return header, nodes


def _under(path, roots):
    return any(path == r or path.startswith(r + "/") for r in roots)


def build_garage(header, nodes):
    """garage_base.tscn: the compound's spawn spots, Pad and Garage, a zone over them and a mast."""
    keep = ["SpawnPoint", "SpareSpawnLeft", "SpareSpawnRight", "Pad", "Garage"]
    garage_panels = [p for p, _, _ in nodes if p.startswith("Garage/Garage") and re.search(r"/Panel\d+$", p)]
    dashes = [p for p, _, _ in nodes if p.startswith("Garage/Marking/Dash")]
    out = ["[gd_scene format=3]", ""]
    out += [h for h in header]
    out.append('[sub_resource type="BoxShape3D" id="BoxShape3D_garage_zone"]\nsize = Vector3(16, 4, 16)')
    out.append('[sub_resource type="BoxMesh" id="BoxMesh_mast"]\nsize = Vector3(0.8, 10, 0.8)')
    out.append('[sub_resource type="BoxMesh" id="BoxMesh_pennant"]\nsize = Vector3(0.12, 1.6, 2.6)')
    root = ('[node name="Base" type="Node3D" node_paths=PackedStringArray("spawn_point", "spare_spawn_points", "zone", "pad", '
            '"beacon", "color_meshes", "structures")]\n'
            'script = ExtResource("1_base")\nspawn_point = NodePath("SpareSpawnLeft")\nspare_spawn_points = [NodePath("SpareSpawnRight")]\n'
            'zone = NodePath("Zone")\npad = NodePath("Pad")\nbeacon = NodePath("Mast")\n'
            f'color_meshes = {node_paths(dashes + ["Mast/Pennant"])}\nstructures = {node_paths(garage_panels)}')
    out.append(root)
    for path, head, body in nodes:
        if path != "." and _under(path, keep):
            out.append((head + "\n" + body).strip())
    out.append('[node name="Zone" type="Area3D" parent="."]\ncollision_layer = 4\ncollision_mask = 18')
    out.append('[node name="CollisionShape3D" type="CollisionShape3D" parent="Zone"]\n'
               f'transform = {transform(0, 2, 6)}\nshape = SubResource("BoxShape3D_garage_zone")')
    out.append(f'[node name="Mast" type="MeshInstance3D" parent="."]\ntransform = {transform(7.6, 5, 12.6)}\nmesh = SubResource("BoxMesh_mast")')
    out.append(f'[node name="Pennant" type="MeshInstance3D" parent="Mast"]\ntransform = {transform(0, 4.0, -1.6)}\nmesh = SubResource("BoxMesh_pennant")')
    with open(os.path.join(OUT, "garage_base.tscn"), "w", encoding="utf-8") as handle:
        handle.write("\n\n".join(out).rstrip() + "\n")
    return dashes, garage_panels


def build_fortress(header, nodes):
    """flag_fortress.tscn: the compound's walls, water tower, Flag Walls, Turrets, Flag and seat, and
    its zone renamed FlagZone. A plain Node3D: the Garage Base of its Team paints and lists it."""
    keep = ["Walls", "WaterTower", "Defences", "Turrets", "FlagSeat", "Flag"]
    out = ["[gd_scene format=3]", ""]
    out += [h for h in header if "base.gd" not in h]
    out.append('[node name="Fortress" type="Node3D"]')
    for path, head, body in nodes:
        if path == "." or path == "Garage" or path.startswith("Garage/"):
            continue
        if _under(path, keep):
            out.append((head + "\n" + body).strip())
        elif path == "Zone":
            out.append(head.replace('name="Zone"', 'name="FlagZone"') + "\n" + body.strip())
        elif path == "Zone/CollisionShape3D":
            out.append(head.replace('parent="Zone"', 'parent="FlagZone"') + "\n" + body.strip())
    with open(os.path.join(OUT, "flag_fortress.tscn"), "w", encoding="utf-8") as handle:
        handle.write("\n\n".join(out).rstrip() + "\n")
    paths = [p for p, _, _ in nodes]
    colored = [p + "/Mesh" for p in paths if re.fullmatch(r"Walls/Corners/\w+", p)] + ["WaterTower/Roof", "WaterTower/Tank"]
    colored += [p + "/Look/Head/Band" for p in paths if re.fullmatch(r"Turrets/Turret\w+", p)]
    structures = [p for p in paths if re.fullmatch(r"Defences/FlagWall\w+", p) or re.fullmatch(r"Turrets/Turret\w+", p)
                  or re.fullmatch(r"Walls/\w+/Panel\d+", p) or re.fullmatch(r"Walls/Corners/\w+", p)]
    return colored, structures


# --- The Map ------------------------------------------------------------------------------------

def build_tyre_track_settings():
    pixels_per_metre = 12.0
    size = 2 * HALF
    text = f"""[gd_resource type="Resource" script_class="TyreTrackSettings" format=3]

[ext_resource type="Script" path="{TYRE_TRACK_SETTINGS_SCRIPT}" id="1_settings"]

[resource]
script = ExtResource("1_settings")
area_origin = {vec2(-HALF, -HALF)}
area_size = {vec2(size, size)}
texture_size = Vector2i({round(size * pixels_per_metre)}, {round(size * pixels_per_metre)})
darkness = 0.7
rut_depth = 0.05
rut_reach = 1.5
smoothing = 0.3
rim_pixels = 1.0
hold_seconds = 20.0
fade_seconds = 40.0
jump_step = 2.0
min_step = 0.01
"""
    with open(os.path.join(OUT, "map_03_tyre_track_settings.tres"), "w", encoding="utf-8") as handle:
        handle.write(text)


def build_map(garage_colored, garage_structures, fortress_colored, fortress_structures):
    scene = Scene()
    script = scene.ext_resource("Script", MAP_FIELD)
    stock = scene.ext_resource("Resource", TOKEN_STOCK)
    garage = scene.ext_resource("PackedScene", f"{RES}/garage_base.tscn")
    fortress = scene.ext_resource("PackedScene", f"{RES}/flag_fortress.tscn")
    teams = {"orange": scene.ext_resource("Material", TEAM_ORANGE), "teal": scene.ext_resource("Material", TEAM_TEAL)}
    ford = scene.ext_resource("PackedScene", FORD)
    ammo = scene.ext_resource("PackedScene", AMMO_BUILDING)
    fuel = scene.ext_resource("PackedScene", FUEL_BUILDING)
    tracks = scene.ext_resource("PackedScene", TYRE_TRACKS)
    track_settings = scene.ext_resource("Resource", f"{RES}/map_03_tyre_track_settings.tres")
    bush = scene.ext_resource("PackedScene", BUSH)
    wreck = scene.ext_resource("PackedScene", WRECK)
    shacks = {name: scene.ext_resource("PackedScene", SHACK.format(name)) for name, _, _ in SHACKS}
    sand = scene.ext_resource("Material", SAND)
    sea = scene.ext_resource("Material", SEA)
    ford_material = scene.ext_resource("Material", FORD_MATERIAL)

    scene.sub_resource("BoxShape3D", "BoxShape3D_floor", {"size": vec3(2 * HALF + 40, 1, 2 * HALF + 40)})
    scene.sub_resource("PlaneMesh", "PlaneMesh_sea", {"material": sea, "size": vec2(1000, 1000)})
    scene.sub_resource("BoxShape3D", "BoxShape3D_edge", {"size": vec3(2 * HALF + 8, 12, 4)})
    scene.sub_resource("ProceduralSkyMaterial", "ProceduralSkyMaterial_sea", {
        "sky_top_color": color(0.4, 0.56, 0.76), "sky_horizon_color": color(0.72, 0.8, 0.88), "sky_curve": 0.09,
        "ground_bottom_color": color(0.2, 0.32, 0.42), "ground_horizon_color": color(0.6, 0.7, 0.76)})
    scene.sub_resource("Sky", "Sky_sea", {"sky_material": 'SubResource("ProceduralSkyMaterial_sea")'})
    scene.sub_resource("Environment", "Environment_sky", {
        "background_mode": 2, "sky": 'SubResource("Sky_sea")', "ambient_light_source": 3,
        "ambient_light_color": color(0.8, 0.8, 0.82), "ambient_light_sky_contribution": 0.6, "ambient_light_energy": 0.9,
        "ssao_enabled": "true", "ssao_radius": 2.0, "ssao_intensity": 3.0, "ssao_light_affect": 0.4,
        "fog_enabled": "true", "fog_mode": 1, "fog_light_color": color(0.8, 0.82, 0.84), "fog_density": 0.2,
        "fog_sky_affect": 0.3, "fog_depth_begin": 60.0, "fog_depth_end": 260.0})

    neutral, outposts, bushes, zones = [], [[], []], [], []
    root_props = {
        "script": script, "player_1_base": 'NodePath("GarageOrange")', "player_2_base": 'NodePath("GarageTeal")',
        "neutral_structures": "__NEUTRAL__", "supply_zones": "__ZONES__", "tyre_tracks": 'NodePath("TyreTracks")',
        "token_stock": stock, "player_1_outposts": "__OUT1__", "player_2_outposts": "__OUT2__", "bushes": "__BUSHES__",
    }
    scene.node("Map", "Node3D", paths=["player_1_base", "player_2_base", "neutral_structures", "supply_zones",
                                       "tyre_tracks", "player_1_outposts", "player_2_outposts", "bushes"], props=root_props)
    scene.node("Sun", "DirectionalLight3D", ".", {"transform": SUN, "light_color": color(1, 0.95, 0.86), "light_energy": 1.3,
                                                   "shadow_enabled": "true", "directional_shadow_max_distance": 100.0,
                                                   "directional_shadow_pancake_size": 0.0})
    scene.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("Environment_sky")'})
    scene.node("Floor", "StaticBody3D", ".")
    scene.node("CollisionShape3D", "CollisionShape3D", "Floor", {"transform": transform(0, -0.5, 0), "shape": 'SubResource("BoxShape3D_floor")'})
    scene.node("Sea", "MeshInstance3D", ".", {"transform": transform(0, -0.12, 0), "cast_shadow": 0, "mesh": 'SubResource("PlaneMesh_sea")'})

    # The Map's edge: four walls on the map layer, in the map_edge group (a Gyrocopter is stopped, not crashed).
    scene.node("Edge", "Node3D", ".")
    for name, (x, z, yaw) in {"EdgeNorth": (0, -HALF - 2, 0), "EdgeSouth": (0, HALF + 2, 0),
                              "EdgeWest": (-HALF - 2, 0, 90), "EdgeEast": (HALF + 2, 0, 90)}.items():
        scene.node(name, "StaticBody3D", "Edge", {"collision_mask": 0}, groups=["map_edge"])
        scene.node("CollisionShape3D", "CollisionShape3D", f"Edge/{name}", {"transform": transform(x, 6, z, yaw), "shape": 'SubResource("BoxShape3D_edge")'})

    # The land: sand islands, and sand under every ford so the water lies on ground.
    scene.node("Terrain", "Node3D", ".")
    land = islands()
    fords = all_fords()
    for name, outline in land:
        scene.node(name, "CSGPolygon3D", "Terrain", {"transform": FLAT.format(x=0, y=-0.198, z=0), "cast_shadow": 0,
                                                     "polygon": packed_vec2(outline), "depth": 0.2, "material": sand})
    for name, centre, length, width, yaw in fords:
        if name.startswith("Puddle"):
            continue
        scene.node(f"Bed{name}", "CSGPolygon3D", "Terrain", {"transform": FLAT.format(x=0, y=BED_TOP - 0.2, z=0), "cast_shadow": 0,
                                                             "polygon": packed_vec2(rect_outline(centre, length, width, yaw)),
                                                             "depth": 0.2, "material": sand})
    # The sea's wall: a low slab over the whole Map on the cliffs_water layer (32), the land cut out of it. Every ground Unit
    # stops at the shore; the Gyrocopter flies over (its mask leaves the layer out); it is lower than the shooting height,
    # so Shots and a Turret's sight pass over the water. Never drawn (visual layers 0).
    scene.node("SeaWall", "CSGCombiner3D", "Terrain", {"use_collision": "true", "collision_layer": 32, "collision_mask": 0,
                                                        "layers": 0, "cast_shadow": 0})
    scene.node("Slab", "CSGBox3D", "Terrain/SeaWall", {"transform": transform(0, SEA_WALL_HEIGHT / 2.0, 0),
                                                         "size": vec3(2 * HALF + 20, SEA_WALL_HEIGHT, 2 * HALF + 20)})
    for name, outline in land:
        scene.node(f"Cut{name}", "CSGPolygon3D", "Terrain/SeaWall", {"operation": 2, "transform": FLAT.format(x=0, y=-1, z=0),
                                                                     "polygon": packed_vec2(outline), "depth": 3.0})
    for name, centre, length, width, yaw in fords:
        if name.startswith("Puddle"):
            continue
        scene.node(f"Cut{name}", "CSGPolygon3D", "Terrain/SeaWall", {"operation": 2, "transform": FLAT.format(x=0, y=-1, z=0),
                                                                     "polygon": packed_vec2(rect_outline(centre, length, width, yaw)),
                                                                     "depth": 3.0})

    # The fords and puddles: Map 01's ford, sized and turned (it slows ground Units), its own rectangular Water hidden and
    # the water drawn as a pool (Story 058; Martin, 2026-10-25: "aby vodne mladky neboli hranate, bud maju byt orezane hranou
    # ostrova, alebo ked su ako ojedinele, tak zaoblenych tvarov"). A ford between islands: its water lies a hair under the
    # islands' sand, so the islands cut it at their shore. A puddle: a rounded pool on the sand, its slowing box a little
    # inside the pool.
    scene.node("Pools", "Node3D", ".")
    for index, (name, centre, length, width, yaw) in enumerate(fords):
        puddle = name.startswith("Puddle")
        box = (width * POOL_BOX_SHARE, 3, length * POOL_BOX_SHARE) if puddle else (width, 3, length)
        shape = scene.sub_resource("BoxShape3D", f"BoxShape3D_{name}", {"size": vec3(*box)})
        scene.node(name, None, ".", {"transform": transform(centre[0], 0, centre[1], yaw)}, instance=ford)
        scene.node("CollisionShape3D", None, name, {"shape": shape})
        scene.node("Water", None, name, {"visible": "false"})
        scene.editable(name)
        if puddle:
            outline = pool_outline(centre, length, width, yaw, seed=index)
            top = POOL_TOP
        else:
            outline = rect_outline(centre, length, width, yaw)
            top = FORD_WATER_TOP
        scene.node(f"Pool{name}", "CSGPolygon3D", "Pools", {"transform": FLAT.format(x=0, y=top - POOL_DEPTH, z=0), "cast_shadow": 0,
                                                            "polygon": packed_vec2(outline), "depth": POOL_DEPTH, "material": ford_material})

    # The fortresses, then the Garages (each Garage is its Team's Base and lists its fortress).
    for team, sign in (("orange", 1), ("teal", -1)):
        name = "Fortress" + team.capitalize()
        (fx, fz), yaw = FORTRESS
        props = {"transform": transform(fx * sign, 0, fz, yaw * sign)}
        scene.node(name, None, ".", props, instance=fortress)
    for index, (team, sign) in enumerate((("orange", 1), ("teal", -1))):
        name = "Garage" + team.capitalize()
        fort = "../Fortress" + team.capitalize()
        (gx, gz), yaw = GARAGE
        props = {
            "transform": transform(gx * sign, 0, gz, yaw * sign), "color_material": teams[team],
            "flag": f'NodePath("{fort}/Flag")', "flag_seat": f'NodePath("{fort}/FlagSeat")',
            "flag_zone": f'NodePath("{fort}/FlagZone")',
            "color_meshes": node_paths(garage_colored + ["Mast/Pennant"] + [f"{fort}/{p}" for p in fortress_colored]),
            "structures": node_paths(garage_structures + [f"{fort}/{p}" for p in fortress_structures]),
        }
        if index == 1:
            # The mirror image's left and right swap: Teal's first spot is the compound's right one.
            props["spawn_point"] = 'NodePath("SpareSpawnRight")'
            props["spare_spawn_points"] = '[NodePath("SpareSpawnLeft")]'
        paths = ["flag", "flag_seat", "flag_zone", "color_meshes", "structures"]
        if index == 1:
            paths += ["spawn_point", "spare_spawn_points"]
        scene.node(name, None, ".", props, instance=garage, paths=paths)

    # Supply.
    for index, ((x, z), yaw) in enumerate(FUEL):
        for side, sx, syaw in (("West", x, yaw), ("East", -x, yaw + 180.0)):
            name = f"Fuel{side}{index + 1}"
            scene.node(name, None, ".", {"transform": transform(sx, 0, z, syaw)}, instance=fuel)
            zones.append(f"{name}/FuelZone")
    for index, ((x, z), yaw) in enumerate(AMMO):
        for side, sx, syaw in (("West", x, yaw), ("East", -x, yaw + 180.0)):
            name = f"Ammo{side}{index + 1}"
            scene.node(name, None, ".", {"transform": transform(sx, 0, z, syaw)}, instance=ammo)
            zones.append(f"{name}/AmmoZone")

    # Cover.
    scene.node("Cover", "Node3D", ".")
    for index, ((x, z), yaw) in enumerate(WRECKS):
        for side, sx, syaw in (("West", x, yaw), ("East", -x, -yaw)):
            name = f"Wreck{side}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(sx, 0, z, syaw)}, instance=wreck)
            neutral.append(f"Cover/{name}")
    for index, (kind, (x, z), yaw) in enumerate(SHACKS):
        for side, sx, syaw in (("West", x, yaw), ("East", -x, 180.0 - yaw)):
            name = f"Shack{side}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(sx, 0, z, syaw)}, instance=shacks[kind])
            neutral.append(f"Cover/{name}")
    for index, (x, z) in enumerate(BUSHES):
        for side, sx, sign in (("West", x, 1), ("East", -x, -1)):
            name = f"Bush{side}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(sx, 0, z, 37.0 * (index + 1) * sign)}, instance=bush)
            bushes.append(f"Cover/{name}")

    scene.node("TyreTracks", None, ".", {"settings": track_settings}, instance=tracks)

    text = scene.text()
    text = text.replace('"__NEUTRAL__"', node_paths(neutral)).replace("__NEUTRAL__", node_paths(neutral))
    text = text.replace("__ZONES__", node_paths(zones)).replace("__OUT1__", node_paths(outposts[0]))
    text = text.replace("__OUT2__", node_paths(outposts[1])).replace("__BUSHES__", node_paths(bushes))
    with open(os.path.join(OUT, "map_03.tscn"), "w", encoding="utf-8") as handle:
        handle.write(text)
    return len(neutral), len(bushes), len(zones), len(fords)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    header, nodes = compound_parts()
    garage_colored, garage_structures = build_garage(header, nodes)
    fortress_colored, fortress_structures = build_fortress(header, nodes)
    build_tyre_track_settings()
    counts = build_map(garage_colored, garage_structures, fortress_colored, fortress_structures)
    print("wrote map_03.tscn: %d neutral pieces, %d Bushes, %d supply zones, %d fords and puddles" % counts)
