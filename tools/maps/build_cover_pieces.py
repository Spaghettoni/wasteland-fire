"""Builds the destructible cover of Map 02: the car wreck and the two small buildings (Story 038).

Writes src/gameplay/cover/wreck.tscn, shack_long.tscn, shack_square.tscn and container.tscn (Story 058). Each is a Structure
(src/gameplay/defences/structure.gd) on the cover layer (64): it stops ground Units and every Shot,
the Gyrocopter flies over it (at 2.5 m, over every piece of 2 m or less), both Players' Shots
damage it (it belongs to no Player and its type is in no row of the damage matrix, so every Shot
counts 1.0, the Motorbike's too), it shows two damaged looks and falls into low rubble at 0 hit
points. The numbers are its StructureStats (data/wreck_stats.tres, data/shack_stats.tres).

Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-7.
Run from the repository root: python3 tools/maps/build_cover_pieces.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tscn import Scene, transform, vec3  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "src", "gameplay", "cover")

STRUCTURE = "res://src/gameplay/defences/structure.gd"
RUST = "res://src/gameplay/maps/map_01/materials/rust.tres"
WALL = "res://src/gameplay/maps/map_01/materials/wall.tres"
RUBBER = "res://src/gameplay/maps/map_01/materials/dressing_rubber.tres"
DAMAGED = ["res://src/gameplay/defences/materials/flag_wall_damaged_1.tres",
           "res://src/gameplay/defences/materials/flag_wall_damaged_2.tres"]
CHIPS = "res://src/gameplay/defences/materials/flag_wall_chips.tres"

# The cover layer: what stops ground Units and Shots and not the Gyrocopter (project.godot).
COVER_LAYER = 64

# The car wreck, metres: its box (length along x, height, width along z) and its parts.
WRECK_BOX = (5.4, 1.6, 2.4)
WRECK_PARTS = [  # name, size, (x, y, z), yaw, tilt, material key
    ("Chassis", (5.2, 0.6, 2.3), (0.0, 0.55, 0.0), 0.0, 0.0, "rust"),
    ("Cabin", (2.2, 0.75, 2.0), (-0.5, 1.2, 0.05), 4.0, -5.0, "rust"),
    ("Hood", (1.5, 0.3, 2.1), (1.85, 0.98, 0.0), -3.0, 7.0, "rust"),
    ("Bed", (1.3, 0.35, 2.2), (-2.1, 1.0, 0.0), 2.0, 0.0, "rust"),
]
WRECK_WHEELS = [(1.75, 1.15), (-1.75, 1.15), (1.75, -1.15)]  # x, z: one wheel is missing
WHEEL_RADIUS = 0.45
WHEEL_WIDTH = 0.35

# The small buildings: footprint (x, z) and wall height, metres; roof overhang and thickness.
# Since Story 058 also "container", the breakable stand-in for Map 01's two containers (12 x 2.5 m, as their old boxes).
SHACKS = {"shack_long": (8.0, 5.4), "shack_square": (6.4, 6.4), "container": (12.0, 2.5)}
SHACK_HEIGHT = 2.0
ROOF_OVERHANG = 0.25
ROOF_THICKNESS = 0.14

# Rubble: how many chunks and how big, as a share of the piece's footprint.
RUBBLE_CHUNKS = [(-0.3, -0.25, 25.0), (0.25, -0.2, -40.0), (-0.1, 0.25, 70.0), (0.32, 0.22, 10.0), (0.0, 0.0, -15.0)]
RUBBLE_SIZE = (0.28, 0.28, 0.32)  # share of x, metres of y, share of z
CHIPS_AT = [(-0.48, -0.42, 30.0), (0.47, 0.4, -50.0), (-0.45, 0.4, 80.0), (0.46, -0.44, 15.0)]
CHIP_SIZE = (0.6, 0.26, 0.44)


def _box(scene, ident, size, material):
    return scene.sub_resource("BoxMesh", ident, {"material": material, "size": vec3(*size)})


def _structure_root(scene, name, stats_path, box, damaged_count):
    stats = scene.ext_resource("Resource", stats_path)
    script = scene.ext_resource("Script", STRUCTURE)
    shape = scene.sub_resource("BoxShape3D", "BoxShape3D_body", {"size": vec3(*box)})
    looks = [f"Damaged{i + 1}" for i in range(damaged_count)]
    scene.node(name, "StaticBody3D", paths=["intact", "wreck", "damaged_looks"], props={
        "collision_layer": COVER_LAYER,
        "collision_mask": 0,
        "script": script,
        "stats": stats,
        "intact": 'NodePath("Intact")',
        "wreck": 'NodePath("Rubble")',
        "damaged_looks": "[" + ", ".join(f'NodePath("{n}")' for n in looks) + "]",
    })
    scene.node("CollisionShape3D", "CollisionShape3D", ".", {
        "transform": transform(0.0, box[1] / 2.0, 0.0), "shape": shape})


def _rubble(scene, box, material):
    chunk = _box(scene, "BoxMesh_rubble", (box[0] * RUBBLE_SIZE[0], RUBBLE_SIZE[1], box[2] * RUBBLE_SIZE[2]), material)
    scene.node("Rubble", "Node3D", ".", {"visible": "false"})
    for index, (sx, sz, yaw) in enumerate(RUBBLE_CHUNKS):
        scene.node(f"Chunk{index + 1}", "MeshInstance3D", "Rubble", {
            "transform": transform(sx * box[0], RUBBLE_SIZE[1] / 2.0, sz * box[2], yaw),
            "cast_shadow": 0, "mesh": chunk})


def _chips(scene, parent, box, chip_mesh, count):
    for index, (sx, sz, yaw) in enumerate(CHIPS_AT[:count]):
        scene.node(f"Chip{index + 1}", "MeshInstance3D", parent, {
            "transform": transform(sx * box[0], CHIP_SIZE[1] / 2.0, sz * box[2], yaw),
            "cast_shadow": 0, "mesh": chip_mesh})


def build_wreck():
    scene = Scene()
    mats = {"rust": scene.ext_resource("Material", RUST)}
    rubber = scene.ext_resource("Material", RUBBER)
    damaged = [scene.ext_resource("Material", path) for path in DAMAGED]
    chips = scene.ext_resource("Material", CHIPS)
    _structure_root(scene, "Wreck", "res://src/gameplay/cover/data/wreck_stats.tres", WRECK_BOX, len(DAMAGED))
    meshes = {name: _box(scene, f"BoxMesh_{name.lower()}", size, mats[key]) for name, size, _, _, _, key in WRECK_PARTS}
    wheel = scene.sub_resource("CylinderMesh", "CylinderMesh_wheel", {
        "material": rubber, "top_radius": WHEEL_RADIUS, "bottom_radius": WHEEL_RADIUS,
        "height": WHEEL_WIDTH, "radial_segments": 12, "rings": 1})
    chip_mesh = _box(scene, "BoxMesh_chip", CHIP_SIZE, chips)
    looks = [("Intact", None)] + [(f"Damaged{i + 1}", damaged[i]) for i in range(len(DAMAGED))]
    for look_index, (look, override) in enumerate(looks):
        props = {} if look_index == 0 else {"visible": "false"}
        scene.node(look, "Node3D", ".", props)
        for name, _, (x, y, z), yaw, tilt, _ in WRECK_PARTS:
            sag = 0.08 * look_index  # each damaged look sags a little lower
            part = {"transform": transform(x, y - sag, z, yaw + 3.0 * look_index, tilt_degrees=tilt), "mesh": meshes[name]}
            if override is not None:
                part["material_override"] = override
            scene.node(name, "MeshInstance3D", look, part)
        for index, (x, z) in enumerate(WRECK_WHEELS):
            wheel_props = {"transform": transform(x, WHEEL_RADIUS, z, tilt_degrees=90.0), "mesh": wheel}
            scene.node(f"Wheel{index + 1}", "MeshInstance3D", look, wheel_props)
        if look_index > 0:
            _chips(scene, look, WRECK_BOX, chip_mesh, 2 * look_index)
    _rubble(scene, WRECK_BOX, mats["rust"])
    scene.save(os.path.join(OUT, "wreck.tscn"))


def build_shack(name, footprint):
    scene = Scene()
    wall = scene.ext_resource("Material", WALL)
    rust = scene.ext_resource("Material", RUST)
    damaged = [scene.ext_resource("Material", path) for path in DAMAGED]
    chips = scene.ext_resource("Material", CHIPS)
    box = (footprint[0], SHACK_HEIGHT, footprint[1])
    _structure_root(scene, "Shack", "res://src/gameplay/cover/data/shack_stats.tres", box, len(DAMAGED))
    body = _box(scene, "BoxMesh_body", box, wall)
    roof = _box(scene, "BoxMesh_roof", (box[0] + 2 * ROOF_OVERHANG, ROOF_THICKNESS, box[2] + 2 * ROOF_OVERHANG), rust)
    door = _box(scene, "BoxMesh_door", (1.1, 1.7, 0.06), rust)
    chip_mesh = _box(scene, "BoxMesh_chip", CHIP_SIZE, chips)
    looks = [("Intact", None)] + [(f"Damaged{i + 1}", damaged[i]) for i in range(len(DAMAGED))]
    for look_index, (look, override) in enumerate(looks):
        props = {} if look_index == 0 else {"visible": "false"}
        scene.node(look, "Node3D", ".", props)
        body_props = {"transform": transform(0.0, box[1] / 2.0, 0.0), "mesh": body}
        roof_props = {"transform": transform(0.0, box[1] + ROOF_THICKNESS / 2.0 - 0.05 * look_index, 0.0, tilt_degrees=2.0 * look_index), "mesh": roof}
        if override is not None:
            body_props["material_override"] = override
            roof_props["material_override"] = override
        scene.node("Body", "MeshInstance3D", look, body_props)
        scene.node("Roof", "MeshInstance3D", look, roof_props)
        scene.node("Door", "MeshInstance3D", look, {
            "transform": transform(box[0] * 0.2, 0.85, box[2] / 2.0 + 0.03), "mesh": door})
        if look_index > 0:
            _chips(scene, look, box, chip_mesh, 2 * look_index)
    _rubble(scene, box, wall)
    scene.save(os.path.join(OUT, f"{name}.tscn"))


if __name__ == "__main__":
    build_wreck()
    for shack_name, shack_footprint in SHACKS.items():
        build_shack(shack_name, shack_footprint)
    print("wrote wreck.tscn, " + ", ".join(f"{n}.tscn" for n in SHACKS))
