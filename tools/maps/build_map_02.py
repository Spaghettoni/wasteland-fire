"""Builds Map 02 from Martin's schematic of 2026-10-16 (Story 038).

Writes src/gameplay/maps/map_02/map_02.tscn, its Fuel building map_02_fuel_building.tscn and its
tyre track settings map_02_tyre_track_settings.tres. The scenes are never edited by hand: change
the tables below and run the script again (tools/maps/readme.md).

The schematic (design/source/wasteland-fire-map-02-2026-10-16.svg) is in metres with x across, 0
to 160, and z down, 0 to 290, mirror-symmetric about z = 145; every place below is written in its
numbers, and sx_sz() turns them into the Map's own frame, whose origin is the schematic's centre
(80, 145): world x = sx - 80, world z = sz - 145. Player 1 (Orange) has the top half (negative z),
Player 2 (Teal) the bottom half.

Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-2 to AC-5, AC-9.
Run from the repository root: python3 tools/maps/build_map_02.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tscn import Scene, color, node_paths, num, packed_vec2, transform, vec2, vec3  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "src", "gameplay", "maps", "map_02")
RES = "res://src/gameplay/maps/map_02"

# --- The schematic ---------------------------------------------------------------------------

CENTRE = (80.0, 145.0)
MIRROR_Z = 145.0

# The floor inside the canyon: a rectangle with rounded corners.
FLOOR_RECT = (20.0, 20.0, 140.0, 270.0)  # x0, z0, x1, z1
FLOOR_CORNER = 50.0
ARC_STEPS = 12
# How far out the canyon's rock is drawn, so the camera never sees past it.
CANYON_OUTER = (-60.0, -60.0, 220.0, 350.0)
CANYON_HEIGHT = 6.0
# The invisible boundary along the canyon's foot that stops every Unit (on the map layer).
EDGE_HEIGHT = 3.0
EDGE_THICKNESS = 2.0

# The rock ridge of the top half (the bottom one is its mirror image), only the Gyrocopter crosses it.
RIDGE_NORTH = [(105.0, 50.0), (110.0, 56.0), (117.0, 70.0), (121.0, 86.0), (120.0, 102.0), (114.0, 116.0),
               (109.0, 126.0), (107.5, 136.0), (104.0, 136.0), (103.0, 124.0), (102.0, 106.0), (101.5, 86.0),
               (102.0, 68.0), (103.0, 57.0)]
RIDGE_TOP = 2.0
RIDGE_DEPTH = 2.5

# The wall in the ridge's gap: Wall Panels of no Player along z, centred on x.
RIDGE_WALL_X = 105.5
RIDGE_WALL_Z = (136.0, 154.0)

# The wall across the top half (mirrored for the bottom): two runs either side of the gap between
# the half's two Turrets, at x = 44 and 56.
FIELD_WALL_Z = 76.0
FIELD_WALL_RUNS = [(20.0, 44.0), (56.0, 104.0)]
FIELD_TURRETS_X = [44.0, 56.0]
# The Turrets stand this far in front of the wall's line, toward the other half, so the wall's own end panels never cut
# their sight or their Shots (Map 01's stand 4 m in front of their Gate wall).
FIELD_TURRETS_AHEAD = 2.5

PANEL_LENGTH = 3.0  # wall_panel_scrap.tscn is 3 m along its local z

# The water at both ends of the passage: x0, z0, x1, z1 (the bottom one is the mirror image).
WATER_NORTH = (108.0, 80.0, 140.0, 98.0)

# Each Base: Map 01's compound Base, its Gate facing east (yaw -90: its Garage lies west of its Flag).
BASE_NORTH = (72.0, 42.0)
BASE_YAW = -90.0

# The supply buildings: the Fuel building (shared, zone to its east) and an ammunition building per
# half (zone to its west, so turned round).
FUEL_BUILDING = (36.0, 145.0)
AMMO_NORTH = (90.0, 100.0)

# The cover of the top half (mirrored for the bottom), then the middle's. Yaw in Godot's sense
# (counter-clockwise seen from above): the schematic's clockwise turns are negated.
SHACKS_NORTH = [("shack_long", (56.0, 134.0)), ("shack_square", (78.0, 88.0))]
WRECKS_NORTH = [((50.0, 98.0), -25.0), ((74.0, 106.0), 15.0), ((28.0, 112.0), -70.0)]
BUSHES_NORTH = [(30.0, 92.0), (64.0, 116.0), (88.0, 128.0), (40.0, 128.0)]
WRECK_MIDDLE = ((86.0, 145.0), -90.0)
BUSH_MIDDLE = (70.0, 145.0)

# --- The scenes it uses ----------------------------------------------------------------------

MAP_FIELD = "res://src/gameplay/maps/map_field.gd"
TOKEN_STOCK = "res://src/gameplay/maps/data/token_stock.tres"
COMPOUND_BASE = "res://src/gameplay/maps/map_01/compound_base.tscn"
TEAM_ORANGE = "res://src/gameplay/split_screen/data/team_orange_material.tres"
TEAM_TEAL = "res://src/gameplay/split_screen/data/team_teal_material.tres"
PANEL = "res://src/gameplay/defences/wall_panel_scrap.tscn"
TURRET = "res://src/gameplay/defences/turret.tscn"
FORD = "res://src/gameplay/maps/ford.tscn"
AMMO_BUILDING = "res://src/gameplay/supply/ammo_building.tscn"
SUPPLY_ZONE = "res://src/gameplay/supply/supply_zone.tscn"
TYRE_TRACKS = "res://src/gameplay/maps/tyre_tracks.tscn"
TYRE_TRACK_SETTINGS_SCRIPT = "res://src/gameplay/maps/tyre_track_settings.gd"
BUSH = "res://src/gameplay/cover/bush.tscn"
WRECK = "res://src/gameplay/cover/wreck.tscn"
SHACK = "res://src/gameplay/cover/{}.tscn"
SAND = "res://src/gameplay/maps/map_01/materials/sand.tres"
ROCK = "res://src/gameplay/maps/map_01/materials/rock.tres"
RIDGE = "res://src/gameplay/maps/map_01/materials/ridge.tres"
FUEL_TANK = "res://src/gameplay/maps/map_01/materials/fuel_tank.tres"
RUST = "res://src/gameplay/maps/map_01/materials/rust.tres"
WALL = "res://src/gameplay/maps/map_01/materials/wall.tres"
TOWER = "res://src/gameplay/maps/map_01/materials/tower.tres"

# A flat polygon in the XZ plane: CSGPolygon3D turned so its polygon's (x, y) is the world's (x, z)
# and its depth runs up from its origin (Map 01's Island and cliffs use the same turn).
FLAT = "Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, {x}, {y}, {z})"

# Map 01's light and air, copied so both Maps look alike (map_01.tscn).
SUN = "Transform3D(0.81915206, 0.40557979, -0.40557979, 0, 0.70710678, 0.70710678, 0.57357645, -0.57922797, 0.57922797, 0, 0, 0)"


def sx_sz(point):
    """A schematic point (sx, sz) in the Map's frame (x, z)."""
    return point[0] - CENTRE[0], point[1] - CENTRE[1]


def mirror(point):
    return point[0], 2.0 * MIRROR_Z - point[1]


def floor_outline():
    """The inner edge of the canyon, clockwise seen from above, in schematic numbers."""
    x0, z0, x1, z1 = FLOOR_RECT
    r = FLOOR_CORNER
    corners = [((x1 - r, z0 + r), -90.0, 0.0), ((x1 - r, z1 - r), 0.0, 90.0),
               ((x0 + r, z1 - r), 90.0, 180.0), ((x0 + r, z0 + r), 180.0, 270.0)]
    points = []
    for (cx, cz), start, end in corners:
        for step in range(ARC_STEPS + 1):
            angle = math.radians(start + (end - start) * step / ARC_STEPS)
            points.append((cx + r * math.cos(angle), cz + r * math.sin(angle)))
    return points


def canyon_pieces():
    """The canyon's rock as four simple polygons round the floor, in schematic numbers."""
    x0, z0, x1, z1 = FLOOR_RECT
    r = FLOOR_CORNER
    ox0, oz0, ox1, oz1 = CANYON_OUTER

    def arc(cx, cz, start, end):
        return [(cx + r * math.cos(math.radians(start + (end - start) * s / ARC_STEPS)),
                 cz + r * math.sin(math.radians(start + (end - start) * s / ARC_STEPS))) for s in range(ARC_STEPS + 1)]

    top = [(ox0, oz0), (ox1, oz0), (ox1, z0 + r)] + arc(x1 - r, z0 + r, 0.0, -90.0) + arc(x0 + r, z0 + r, -90.0, -180.0) + [(ox0, z0 + r)]
    bottom = [(ox0, oz1), (ox0, z1 - r)] + arc(x0 + r, z1 - r, 180.0, 90.0) + arc(x1 - r, z1 - r, 90.0, 0.0) + [(ox1, z1 - r), (ox1, oz1)]
    west = [(ox0, z0 + r), (x0, z0 + r), (x0, z1 - r), (ox0, z1 - r)]
    east = [(x1, z0 + r), (ox1, z0 + r), (ox1, z1 - r), (x1, z1 - r)]
    return {"CanyonNorth": top, "CanyonSouth": bottom, "CanyonWest": west, "CanyonEast": east}


def panels_along(start, end, fixed, along_x):
    """Wall Panel centres filling start..end, PANEL_LENGTH apart, on the line at `fixed`."""
    count = max(1, round((end - start) / PANEL_LENGTH))
    step = (end - start) / count
    return [((start + step * (i + 0.5), fixed) if along_x else (fixed, start + step * (i + 0.5))) for i in range(count)]


def to_local(points):
    return [sx_sz(p) for p in points]


def build_fuel_building():
    scene = Scene()
    zone = scene.ext_resource("PackedScene", SUPPLY_ZONE)
    tank_mat = scene.ext_resource("Material", FUEL_TANK)
    rust = scene.ext_resource("Material", RUST)
    wall = scene.ext_resource("Material", WALL)
    tower = scene.ext_resource("Material", TOWER)
    tank = scene.sub_resource("CylinderMesh", "CylinderMesh_tank", {"material": tank_mat, "top_radius": 2.0, "bottom_radius": 2.0, "height": 3, "radial_segments": 14, "rings": 0})
    band = scene.sub_resource("CylinderMesh", "CylinderMesh_band", {"material": rust, "top_radius": 2.06, "bottom_radius": 2.06, "height": 0.6, "radial_segments": 14, "rings": 0, "cap_top": "false", "cap_bottom": "false"})
    dome = scene.sub_resource("SphereMesh", "SphereMesh_dome", {"material": tank_mat, "radius": 2.0, "height": 1.0, "radial_segments": 14, "rings": 3})
    hatch = scene.sub_resource("CylinderMesh", "CylinderMesh_hatch", {"material": tower, "top_radius": 0.45, "bottom_radius": 0.45, "height": 0.3, "radial_segments": 12, "rings": 0})
    plinth = scene.sub_resource("BoxMesh", "BoxMesh_plinth", {"material": wall, "size": vec3(5.2, 0.4, 10.4)})
    shape = scene.sub_resource("CylinderShape3D", "CylinderShape3D_tank", {"height": 3.0, "radius": 2.06})
    scene.node("FuelBuilding", "Node3D")
    scene.node("Plinth", "MeshInstance3D", ".", {"transform": transform(0, 0.2, 0), "mesh": plinth})
    for name, z in (("TankNorth", -2.6), ("TankSouth", 2.6)):
        scene.node(name, "MeshInstance3D", ".", {"transform": transform(0, 1.9, z), "mesh": tank})
        scene.node("Band", "MeshInstance3D", name, {"transform": transform(0, -1.0, 0), "mesh": band})
        scene.node("Dome", "MeshInstance3D", name, {"transform": transform(0, 1.5, 0), "mesh": dome})
        scene.node("Hatch", "MeshInstance3D", name, {"transform": transform(0, 2.05, 0), "mesh": hatch})
        # A Tall piece on the map layer, as Map 01's depot tanks: it stops every Unit and every Shot.
        scene.node("Collider", "StaticBody3D", name, {"collision_mask": 0})
        scene.node("CollisionShape3D", "CollisionShape3D", f"{name}/Collider", {"shape": shape})
    scene.node("FuelZone", None, ".", {"transform": transform(6.5, 0, 0), "kind": 0, "size": vec3(6, 6, 6)}, instance=zone)
    scene.save(os.path.join(OUT, "map_02_fuel_building.tscn"))


def build_tyre_track_settings():
    x0, z0, x1, z1 = FLOOR_RECT
    origin = sx_sz((x0, z0))
    size = (x1 - x0, z1 - z0)
    pixels_per_metre = 14.0  # about Map 01's (4096 px over 294 m)
    text = f"""[gd_resource type="Resource" script_class="TyreTrackSettings" format=3]

[ext_resource type="Script" path="{TYRE_TRACK_SETTINGS_SCRIPT}" id="1_settings"]

[resource]
script = ExtResource("1_settings")
area_origin = {vec2(*origin)}
area_size = {vec2(*size)}
texture_size = Vector2i({round(size[0] * pixels_per_metre)}, {round(size[1] * pixels_per_metre)})
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
    with open(os.path.join(OUT, "map_02_tyre_track_settings.tres"), "w", encoding="utf-8") as handle:
        handle.write(text)


def build_map():
    scene = Scene()
    script = scene.ext_resource("Script", MAP_FIELD)
    stock = scene.ext_resource("Resource", TOKEN_STOCK)
    base_scene = scene.ext_resource("PackedScene", COMPOUND_BASE)
    orange = scene.ext_resource("Material", TEAM_ORANGE)
    teal = scene.ext_resource("Material", TEAM_TEAL)
    panel = scene.ext_resource("PackedScene", PANEL)
    turret = scene.ext_resource("PackedScene", TURRET)
    ford = scene.ext_resource("PackedScene", FORD)
    ammo = scene.ext_resource("PackedScene", AMMO_BUILDING)
    fuel = scene.ext_resource("PackedScene", f"{RES}/map_02_fuel_building.tscn")
    tracks = scene.ext_resource("PackedScene", TYRE_TRACKS)
    track_settings = scene.ext_resource("Resource", f"{RES}/map_02_tyre_track_settings.tres")
    bush = scene.ext_resource("PackedScene", BUSH)
    wreck = scene.ext_resource("PackedScene", WRECK)
    shacks = {name: scene.ext_resource("PackedScene", SHACK.format(name)) for name, _ in SHACKS_NORTH}
    sand = scene.ext_resource("Material", SAND)
    rock = scene.ext_resource("Material", ROCK)
    ridge = scene.ext_resource("Material", RIDGE)
    ford_material = scene.ext_resource("Material", "res://src/gameplay/maps/map_01/materials/ford.tres")

    scene.sub_resource("BoxShape3D", "BoxShape3D_floor", {"size": vec3(CANYON_OUTER[2] - CANYON_OUTER[0], 1, CANYON_OUTER[3] - CANYON_OUTER[1])})
    scene.sub_resource("ProceduralSkyMaterial", "ProceduralSkyMaterial_desert", {
        "sky_top_color": color(0.4, 0.56, 0.76), "sky_horizon_color": color(0.7, 0.78, 0.86), "sky_curve": 0.09,
        "ground_bottom_color": color(0.5, 0.4, 0.28), "ground_horizon_color": color(0.76, 0.67, 0.53)})
    scene.sub_resource("Sky", "Sky_desert", {"sky_material": 'SubResource("ProceduralSkyMaterial_desert")'})
    scene.sub_resource("Environment", "Environment_sky", {
        "background_mode": 2, "sky": 'SubResource("Sky_desert")', "ambient_light_source": 3,
        "ambient_light_color": color(0.8, 0.8, 0.82), "ambient_light_sky_contribution": 0.6, "ambient_light_energy": 0.9,
        "ssao_enabled": "true", "ssao_radius": 2.0, "ssao_intensity": 3.0, "ssao_light_affect": 0.4,
        "fog_enabled": "true", "fog_mode": 1, "fog_light_color": color(0.84, 0.8, 0.72), "fog_density": 0.2,
        "fog_sky_affect": 0.3, "fog_depth_begin": 60.0, "fog_depth_end": 260.0})
    water_shape = scene.sub_resource("BoxShape3D", "BoxShape3D_water", {"size": vec3(WATER_NORTH[2] - WATER_NORTH[0], 3, WATER_NORTH[3] - WATER_NORTH[1])})
    water_mesh = scene.sub_resource("PlaneMesh", "PlaneMesh_water", {"material": ford_material, "size": vec2(WATER_NORTH[2] - WATER_NORTH[0], WATER_NORTH[3] - WATER_NORTH[1])})

    # Who lists what (paths from the Map's root), filled as the nodes are made.
    neutral, outposts, bushes, zones = [], [[], []], [], []

    root_props = {
        "script": script,
        "player_1_base": 'NodePath("Base1")',
        "player_2_base": 'NodePath("Base2")',
        "neutral_structures": "__NEUTRAL__",
        "supply_zones": "__ZONES__",
        "tyre_tracks": 'NodePath("TyreTracks")',
        "token_stock": stock,
        "player_1_outposts": "__OUT1__",
        "player_2_outposts": "__OUT2__",
        "bushes": "__BUSHES__",
    }
    scene.node("Map", "Node3D", paths=["player_1_base", "player_2_base", "neutral_structures", "supply_zones",
                                       "tyre_tracks", "player_1_outposts", "player_2_outposts", "bushes"], props=root_props)
    scene.node("Sun", "DirectionalLight3D", ".", {"transform": SUN, "light_color": color(1, 0.93, 0.82), "light_energy": 1.3,
                                                   "shadow_enabled": "true", "directional_shadow_max_distance": 100.0})
    scene.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": 'SubResource("Environment_sky")'})
    scene.node("Floor", "StaticBody3D", ".")
    scene.node("CollisionShape3D", "CollisionShape3D", "Floor", {"transform": transform(0, -0.5, 0), "shape": 'SubResource("BoxShape3D_floor")'})

    # The ground and the canyon.
    scene.node("Terrain", "Node3D", ".")
    scene.node("Ground", "CSGPolygon3D", "Terrain", {"transform": FLAT.format(x=0, y=-0.198, z=0), "cast_shadow": 0,
                                                     "polygon": packed_vec2(to_local(floor_outline())), "depth": 0.2, "material": sand})
    for name, points in canyon_pieces().items():
        scene.node(name, "CSGPolygon3D", "Terrain", {"transform": FLAT.format(x=0, y=-0.5, z=0),
                                                     "polygon": packed_vec2(to_local(points)), "depth": CANYON_HEIGHT + 0.5, "material": rock})
    # The canyon's foot: boxes along the floor's edge on the map layer, in the map_edge group so a
    # Gyrocopter that flies into it is only stopped, never crashed, as at Map 01's shore.
    scene.node("CanyonEdge", "Node3D", "Terrain")
    outline = floor_outline()
    for index in range(len(outline)):
        a = outline[index]
        b = outline[(index + 1) % len(outline)]
        length = math.dist(a, b)
        if length < 0.01:
            continue
        mid = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        # Outward normal of an outline that runs clockwise on the schematic (z down): (dz, -dx) / length.
        nx, nz = (b[1] - a[1]) / length, -(b[0] - a[0]) / length
        centre = (mid[0] + nx * EDGE_THICKNESS / 2.0, mid[1] + nz * EDGE_THICKNESS / 2.0)
        yaw = -math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
        shape_id = f"BoxShape3D_edge{index}"
        scene.sub_resource("BoxShape3D", shape_id, {"size": vec3(length + 0.4, EDGE_HEIGHT, EDGE_THICKNESS)})
        name = f"Edge{index + 1:02d}"
        scene.node(name, "StaticBody3D", "Terrain/CanyonEdge", {"collision_mask": 0}, groups=["map_edge"])
        x, z = sx_sz(centre)
        scene.node("CollisionShape3D", "CollisionShape3D", f"Terrain/CanyonEdge/{name}", {
            "transform": transform(x, EDGE_HEIGHT / 2.0, z, yaw), "shape": f'SubResource("{shape_id}")'})

    # The ridges: drawn cliffs on the cliffs_water layer (32), as Map 01's: ground Units stop, the Gyrocopter flies over.
    scene.node("Cliffs", "Node3D", ".")
    for name, points in (("RidgeNorth", RIDGE_NORTH), ("RidgeSouth", [mirror(p) for p in reversed(RIDGE_NORTH)])):
        scene.node(name, "CSGPolygon3D", "Cliffs", {"transform": FLAT.format(x=0, y=RIDGE_TOP - RIDGE_DEPTH, z=0),
                                                    "use_collision": "true", "collision_layer": 32, "collision_mask": 0,
                                                    "polygon": packed_vec2(to_local(points)), "depth": RIDGE_DEPTH, "material": ridge})

    # The water at both ends of the passage: Map 01's ford (it slows ground Units), sized to the schematic.
    for name, rect in (("WaterNorth", WATER_NORTH), ("WaterSouth", (WATER_NORTH[0], 2 * MIRROR_Z - WATER_NORTH[3], WATER_NORTH[2], 2 * MIRROR_Z - WATER_NORTH[1]))):
        x, z = sx_sz(((rect[0] + rect[2]) / 2.0, (rect[1] + rect[3]) / 2.0))
        scene.node(name, None, ".", {"transform": transform(x, 0, z)}, instance=ford)
        scene.node("CollisionShape3D", None, name, {"shape": water_shape})
        scene.node("Water", None, name, {"mesh": water_mesh})

    # The Bases.
    for index, (name, point, material) in enumerate((("Base1", BASE_NORTH, orange), ("Base2", mirror(BASE_NORTH), teal))):
        x, z = sx_sz(point)
        props = {"transform": transform(x, 0, z, BASE_YAW), "color_material": material}
        paths = None
        if index == 1:
            # Mirrored: the first spawn spot is the one toward the canyon, as Map 01's Base B.
            props["spawn_point"] = 'NodePath("SpareSpawnRight")'
            props["spare_spawn_points"] = '[NodePath("SpareSpawnLeft")]'
            paths = ["spawn_point", "spare_spawn_points"]
        scene.node(name, None, ".", props, instance=base_scene, paths=paths)

    # The walls across each half, with the half's two Turrets at the gap, and the wall in each ridge's gap.
    scene.node("FieldWalls", "Node3D", ".")
    for half, (wall_name, z_line) in enumerate((("FieldWallNorth", FIELD_WALL_Z), ("FieldWallSouth", 2 * MIRROR_Z - FIELD_WALL_Z))):
        holder = f"FieldWalls/{wall_name}"
        scene.node(wall_name, "Node3D", "FieldWalls")
        count = 0
        for start, end in FIELD_WALL_RUNS:
            for point in panels_along(start, end, z_line, True):
                count += 1
                x, z = sx_sz(point)
                scene.node(f"Panel{count}", None, holder, {"transform": transform(x, 0, z, 90.0)}, instance=panel)
                neutral.append(f"{holder}/Panel{count}")
        team = orange if half == 0 else teal
        for turret_name, tx in zip(("TurretWest", "TurretEast"), FIELD_TURRETS_X):
            ahead = FIELD_TURRETS_AHEAD if half == 0 else -FIELD_TURRETS_AHEAD
            x, z = sx_sz((tx, z_line + ahead))
            scene.node(turret_name, None, holder, {"transform": transform(x, 0, z, 0.0 if half == 0 else 180.0)}, instance=turret)
            scene.node("Band", None, f"{holder}/{turret_name}/Look/Head", {"material_override": team})
            scene.editable(f"{holder}/{turret_name}")
            outposts[half].append(f"{holder}/{turret_name}")
    scene.node("RidgeWall", "Node3D", "FieldWalls")
    for index, point in enumerate(panels_along(RIDGE_WALL_Z[0], RIDGE_WALL_Z[1], RIDGE_WALL_X, False)):
        x, z = sx_sz(point)
        scene.node(f"Panel{index + 1}", None, "FieldWalls/RidgeWall", {"transform": transform(x, 0, z)}, instance=panel)
        neutral.append(f"FieldWalls/RidgeWall/Panel{index + 1}")

    # The supply buildings.
    x, z = sx_sz(FUEL_BUILDING)
    scene.node("FuelBuilding", None, ".", {"transform": transform(x, 0, z)}, instance=fuel)
    zones.append("FuelBuilding/FuelZone")
    for name, point in (("AmmoBuildingNorth", AMMO_NORTH), ("AmmoBuildingSouth", mirror(AMMO_NORTH))):
        x, z = sx_sz(point)
        scene.node(name, None, ".", {"transform": transform(x, 0, z, 180.0)}, instance=ammo)
        zones.append(f"{name}/AmmoZone")

    # The cover of the left corridor.
    scene.node("Cover", "Node3D", ".")
    for half in (0, 1):
        suffix = "North" if half == 0 else "South"
        for index, (shack_name, point) in enumerate(SHACKS_NORTH):
            place = point if half == 0 else mirror(point)
            x, z = sx_sz(place)
            name = f"Shack{suffix}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(x, 0, z, 0.0 if half == 0 else 180.0)}, instance=shacks[shack_name])
            neutral.append(f"Cover/{name}")
        for index, (point, yaw) in enumerate(WRECKS_NORTH):
            place = point if half == 0 else mirror(point)
            x, z = sx_sz(place)
            name = f"Wreck{suffix}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(x, 0, z, yaw if half == 0 else -yaw)}, instance=wreck)
            neutral.append(f"Cover/{name}")
        for index, point in enumerate(BUSHES_NORTH):
            place = point if half == 0 else mirror(point)
            x, z = sx_sz(place)
            name = f"Bush{suffix}{index + 1}"
            scene.node(name, None, "Cover", {"transform": transform(x, 0, z, 37.0 * (index + 1) * (1 if half == 0 else -1))}, instance=bush)
            bushes.append(f"Cover/{name}")
    x, z = sx_sz(WRECK_MIDDLE[0])
    scene.node("WreckMiddle", None, "Cover", {"transform": transform(x, 0, z, WRECK_MIDDLE[1])}, instance=wreck)
    neutral.append("Cover/WreckMiddle")
    x, z = sx_sz(BUSH_MIDDLE)
    scene.node("BushMiddle", None, "Cover", {"transform": transform(x, 0, z)}, instance=bush)
    bushes.append("Cover/BushMiddle")

    scene.node("TyreTracks", None, ".", {"settings": track_settings}, instance=tracks)

    text = scene.text()
    text = text.replace('"__NEUTRAL__"', node_paths(neutral)).replace("__NEUTRAL__", node_paths(neutral))
    text = text.replace("__ZONES__", node_paths(zones)).replace("__OUT1__", node_paths(outposts[0]))
    text = text.replace("__OUT2__", node_paths(outposts[1])).replace("__BUSHES__", node_paths(bushes))
    with open(os.path.join(OUT, "map_02.tscn"), "w", encoding="utf-8") as handle:
        handle.write(text)
    return len(neutral), len(bushes), [len(o) for o in outposts]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    build_fuel_building()
    build_tyre_track_settings()
    counts = build_map()
    print("wrote map_02.tscn: %d neutral pieces, %d Bushes, outposts %s" % counts)
