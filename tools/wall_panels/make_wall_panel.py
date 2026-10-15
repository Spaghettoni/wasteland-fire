#!/usr/bin/env python3
"""Writes the Wall Panel scenes of src/gameplay/defences/ (story 018: wall_panel_back, wall_panel_side and
wall_panel_gate, the Bases' walls; story 019: wall_panel_garage_back, wall_panel_garage_side, the Garages'
walls, and wall_panel_scrap, the walls in the field), one per panel length of Map 01.

A Wall Panel is the Flag Wall's kind (src/gameplay/defences/flag_wall.tscn): a Structure on the cover layer
(64) with mask 0, the Flag Walls' stats, a box 2 m tall drawn by Mesh, its collider, two damaged looks (a box
with chips at its foot) and the rubble. Its length and depth are scene data (the box mesh and the box shape are
sized, never scaled), so each run length has its own scene, whose instances share one mesh and one shape. This
script makes them from the Flag Wall scene itself: every chip and rubble chunk is read from flag_wall.tscn and
laid out again for the new length (x scaled by the length over the Flag Wall's 3.4 m, the chips kept as far
out from the face as on the Flag Wall, the rubble spread over the new footprint), so a change to the Flag Wall's
chips is one re-run away. A panel whose long side runs along z (the side walls) is the same arrangement turned
by -90 degrees about the vertical axis, with its box and shape sized the other way round.

Run from the repository root, after any change to flag_wall.tscn or to a line of PANELS:

    python3 tools/wall_panels/make_wall_panel.py            # every panel of PANELS
    python3 tools/wall_panels/make_wall_panel.py back       # one of them
    python3 tools/wall_panels/make_wall_panel.py --self-test  # the Flag Wall's own size gives flag_wall.tscn back

Evidence-adjacent tooling: nothing under src/ depends on this file; the scenes it writes are ordinary scenes.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FLAG_WALL = ROOT / "src/gameplay/defences/flag_wall.tscn"
OUT_DIR = ROOT / "src/gameplay/defences"

# The Flag Wall's own footprint, which its chips and rubble are laid out for: length 3.4 m, depth 1 m.
FLAG_LENGTH = 3.4
FLAG_DEPTH = 1.0
# A panel is as tall as the Flag Wall; the box is centred half its height up.
HEIGHT = 2.0

# name -> (length in metres along the wall, depth in metres, the axis the length runs along: "x" or "z").
# Story 018: each Base's back wall is 8 panels of 3.4625 m (27.7 m between the corner towers), each side wall 8
# of 3.2125 m (25.7 m), each Gate wall 3 of 2.7833333 m (8.35 m between the tower and the Gate post); every
# panel 1.3 m deep like the walls it replaces.
# Story 019: each Garage's back wall (14 m between its side walls) is 4 panels of 3.5 m and each Garage side wall
# (10 m) 3 of 3.3333333 m, 1 m deep like the walls they replace; each scrap wall in the field (12 m) is 4 panels of
# 3 m, 2.5 m deep like the scrap wall it replaces, its length along z.
PANELS = {
    "back": (3.4625, 1.3, "x"),
    "side": (3.2125, 1.3, "z"),
    "gate": (2.7833333, 1.3, "x"),
    "garage_back": (3.5, 1.0, "x"),
    "garage_side": (3.3333333, 1.0, "z"),
    "scrap": (3.0, 2.5, "z"),
}


def fmt(value):
    """A number as the scene files write it: up to 7 decimals, no trailing zeros, no negative zero."""
    text = ("%.7f" % value).rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def read_chunks(text):
    """Every Chunk node of flag_wall.tscn: {parent, name, basis (9 floats, row by row), origin, mesh}."""
    chunks = []
    pattern = re.compile(
        r'\[node name="(Chunk\d+)" type="MeshInstance3D" parent="([^"]+)"\]\n'
        r"transform = Transform3D\(([^)]*)\)\n"
        r"cast_shadow = 0\n"
        r'mesh = SubResource\("([^"]+)"\)')
    for name, parent, numbers, mesh in pattern.findall(text):
        values = [float(part) for part in numbers.split(",")]
        chunks.append({"parent": parent, "name": name, "basis": values[:9], "origin": values[9:], "mesh": mesh})
    return chunks


def turn(basis, origin, axis):
    """The chunk's basis and origin for a panel running along `axis`: unchanged for x, turned -90 degrees about
    the vertical axis for z (the matrix of that turn is [[0, 0, -1], [0, 1, 0], [1, 0, 0]])."""
    if axis == "x":
        return basis, origin
    r = [[0.0, 0.0, -1.0], [0.0, 1.0, 0.0], [1.0, 0.0, 0.0]]
    b = [basis[0:3], basis[3:6], basis[6:9]]
    turned = [[sum(r[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    moved = [sum(r[i][k] * origin[k] for k in range(3)) for i in range(3)]
    return [v for row in turned for v in row], moved


def lay_out(chunk, length, depth):
    """The chunk's origin on a panel of this length and depth (the panel's own frame: long side along x).
    The chips (y below the box's middle, outside the faces) keep their distance from the face; the rubble,
    which lies within the footprint, is spread over it."""
    x, y, z = chunk["origin"]
    x *= length / FLAG_LENGTH
    if chunk["parent"] == "Rubble":
        z *= depth / FLAG_DEPTH
    else:
        z += (depth - FLAG_DEPTH) / 2.0 * (1.0 if z > 0.0 else -1.0)
    return [x, y, z]


def transform_text(basis, origin):
    return "Transform3D(" + ", ".join(fmt(v) for v in list(basis) + list(origin)) + ")"


def build(name, length, depth, axis, root_name):
    flag = FLAG_WALL.read_text(encoding="utf-8")
    chunks = read_chunks(flag)
    size = "Vector3(%s, %s, %s)" % ((fmt(length), fmt(HEIGHT), fmt(depth)) if axis == "x"
                                    else (fmt(depth), fmt(HEIGHT), fmt(length)))
    # Everything of the Flag Wall scene up to its first node stays, with the box sizes replaced.
    head, _, _ = flag.partition("[node name=")
    head = head.replace("size = Vector3(3.4, 2, 1)", "size = " + size)
    out = [head.rstrip("\n"), ""]
    out.append('[node name="%s" type="StaticBody3D" node_paths=PackedStringArray("intact", "wreck", "damaged_looks")]' % root_name)
    out.append("collision_layer = 64\ncollision_mask = 0\nscript = ExtResource(\"1_structure\")\nstats = ExtResource(\"2_stats\")")
    out.append('intact = NodePath("Mesh")\nwreck = NodePath("Rubble")\ndamaged_looks = [NodePath("MeshDamaged1"), NodePath("MeshDamaged2")]')
    middle = "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)"
    out.append('\n[node name="Mesh" type="MeshInstance3D" parent="."]\ntransform = %s\nmesh = SubResource("BoxMesh_panel")' % middle)
    out.append('\n[node name="CollisionShape3D" type="CollisionShape3D" parent="."]\ntransform = %s\nshape = SubResource("BoxShape3D_panel")' % middle)
    for index, material in ((1, "4_damaged_1"), (2, "5_damaged_2")):
        out.append('\n[node name="MeshDamaged%d" type="MeshInstance3D" parent="."]\nvisible = false\ntransform = %s\nmaterial_override = ExtResource("%s")\nmesh = SubResource("BoxMesh_panel")' % (index, middle, material))
        for chunk in [c for c in chunks if c["parent"] == "MeshDamaged%d" % index]:
            basis, origin = turn(chunk["basis"], lay_out(chunk, length, depth), axis)
            out.append('\n[node name="%s" type="MeshInstance3D" parent="MeshDamaged%d"]\ntransform = %s\ncast_shadow = 0\nmesh = SubResource("%s")' % (
                chunk["name"], index, transform_text(basis, origin), chunk["mesh"]))
    out.append('\n[node name="Rubble" type="Node3D" parent="."]\nvisible = false')
    for chunk in [c for c in chunks if c["parent"] == "Rubble"]:
        basis, origin = turn(chunk["basis"], lay_out(chunk, length, depth), axis)
        out.append('\n[node name="%s" type="MeshInstance3D" parent="Rubble"]\ntransform = %s\ncast_shadow = 0\nmesh = SubResource("%s")' % (
            chunk["name"], transform_text(basis, origin), chunk["mesh"]))
    return "\n".join(out) + "\n"


def same_scene(a, b):
    """True when two scene texts are the same line for line, the numbers of a transform compared as numbers
    (flag_wall.tscn writes two of them as 1.0 where this script writes 1)."""
    lines_a, lines_b = a.split("\n"), b.split("\n")
    if len(lines_a) != len(lines_b):
        return False
    for x, y in zip(lines_a, lines_b):
        if x.startswith("transform = Transform3D(") and y.startswith("transform = Transform3D("):
            nx = [float(v) for v in x[len("transform = Transform3D("):-1].split(",")]
            ny = [float(v) for v in y[len("transform = Transform3D("):-1].split(",")]
            if len(nx) != len(ny) or any(abs(p - q) > 1e-9 for p, q in zip(nx, ny)):
                return False
        elif x != y:
            return False
    return True


def main(argv):
    if "--self-test" in argv:
        made = build("flag", FLAG_LENGTH, FLAG_DEPTH, "x", "FlagWall")
        same = same_scene(made, FLAG_WALL.read_text(encoding="utf-8"))
        print("self-test: the Flag Wall's own size gives flag_wall.tscn back:", "yes" if same else "NO")
        return 0 if same else 1
    wanted = [a for a in argv if not a.startswith("--")] or list(PANELS)
    for name in wanted:
        length, depth, axis = PANELS[name]
        target = OUT_DIR / ("wall_panel_%s.tscn" % name)
        root_name = "WallPanel" + "".join(part.capitalize() for part in name.split("_"))
        target.write_text(build(name, length, depth, axis, root_name), encoding="utf-8")
        print("wrote", target.relative_to(ROOT), "(%s m along %s, %s m deep)" % (length, axis, depth))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
