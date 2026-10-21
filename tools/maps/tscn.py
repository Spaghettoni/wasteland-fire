"""A small writer of Godot 4 text scenes (.tscn) for the map build scripts in this folder.

Tooling only: nothing under src/ depends on this file. The build scripts (build_cover_pieces.py,
build_map_02.py) describe a scene with ext_resource(), sub_resource() and node() and write it
with save(); the scenes they write are never edited by hand (tools/maps/readme.md).
"""

import math


def num(value):
    """A number as Godot writes it: integers without a point, floats trimmed to 6 decimals."""
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    text = f"{value:.6f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def vec3(x, y, z):
    return f"Vector3({num(x)}, {num(y)}, {num(z)})"


def vec2(x, y):
    return f"Vector2({num(x)}, {num(y)})"


def color(r, g, b, a=1.0):
    return f"Color({num(r)}, {num(g)}, {num(b)}, {num(a)})"


def transform(x=0.0, y=0.0, z=0.0, yaw_degrees=0.0, scale=(1.0, 1.0, 1.0), tilt_degrees=0.0):
    """A Transform3D: scale, then a tilt about the local x axis, then a turn of yaw_degrees about +Y
    (counter-clockwise seen from above, Godot's sense), then the origin (x, y, z)."""
    yaw = math.radians(yaw_degrees)
    tilt = math.radians(tilt_degrees)
    cy, sy = math.cos(yaw), math.sin(yaw)
    ct, st = math.cos(tilt), math.sin(tilt)
    sx, syy, sz = scale
    # Columns of R_yaw * R_tilt * S.
    col_x = (cy * sx, 0.0, -sy * sx)
    col_y = (sy * st * syy, ct * syy, cy * st * syy)
    col_z = (sy * ct * sz, -st * sz, cy * ct * sz)
    # Godot's text format writes the basis row by row.
    rows = [(col_x[i], col_y[i], col_z[i]) for i in range(3)]
    values = [v for row in rows for v in row] + [x, y, z]
    return "Transform3D(" + ", ".join(num(v) for v in values) + ")"


def packed_vec2(points):
    return "PackedVector2Array(" + ", ".join(f"{num(x)}, {num(y)}" for x, y in points) + ")"


def node_paths(paths):
    return "[" + ", ".join(f'NodePath("{p}")' for p in paths) + "]"


class Scene:
    """One .tscn: external resources, sub-resources and nodes, written in that order."""

    def __init__(self):
        self._ext = []
        self._ext_ids = {}
        self._sub = []
        self._nodes = []
        self._editable = []

    def ext_resource(self, kind, path):
        """The id of the external resource at path, added once."""
        if path in self._ext_ids:
            return f'ExtResource("{self._ext_ids[path]}")'
        ident = f"{len(self._ext) + 1}_{path.rsplit('/', 1)[-1].split('.')[0]}"
        self._ext_ids[path] = ident
        self._ext.append(f'[ext_resource type="{kind}" path="{path}" id="{ident}"]')
        return f'ExtResource("{ident}")'

    def sub_resource(self, kind, ident, props):
        self._sub.append((kind, ident, props))
        return f'SubResource("{ident}")'

    def node(self, name, kind=None, parent=None, props=None, instance=None, groups=None, paths=None, index=None):
        head = f'[node name="{name}"'
        if kind is not None:
            head += f' type="{kind}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if paths:
            head += " node_paths=PackedStringArray(" + ", ".join(f'"{p}"' for p in paths) + ")"
        if index is not None:
            head += f' index="{index}"'
        if instance is not None:
            head += f" instance={instance}"
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        head += "]"
        self._nodes.append((head, props or {}))

    def editable(self, path):
        self._editable.append(path)

    def text(self):
        out = ["[gd_scene format=3]", ""]
        out += self._ext
        if self._ext:
            out.append("")
        for kind, ident, props in self._sub:
            out.append(f'[sub_resource type="{kind}" id="{ident}"]')
            out += [f"{k} = {v}" for k, v in props.items()]
            out.append("")
        for head, props in self._nodes:
            out.append(head)
            out += [f"{k} = {v}" for k, v in props.items()]
            out.append("")
        for path in self._editable:
            out.append(f'[editable path="{path}"]')
        return "\n".join(out).rstrip() + "\n"

    def save(self, path):
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(self.text())
