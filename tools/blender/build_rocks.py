"""Builds Map 01's rocks in Blender from the outlines of its cliff colliders and exports them as one
.glb file, one mesh per cliff (wasteland_kit.py says how the parts are coloured, joined and baked).
Run headless with Blender's own Python:

    blender --background --factory-startup --python tools/blender/build_rocks.py -- \
        --out assets/art/map_01/rocks/map_01_rocks.glb --previews <dir>

The cliffs are the CSGPolygon3D nodes of src/gameplay/maps/map_01/map_01_cliffs.tscn: each an
outline on the ground extruded to a flat top 2.0 m up, the collider the Units meet and the drawn top
the Gyrocopter's model rises over. This script reads those outlines from the scene, so the rocks
follow any change to them after a rebuild, and wraps each in a wall of layered desert rock: a
buried foot flaring out at the ground, bands of harder and softer stone stepping in and out, a lip
and a broken, faceted top, all within a few tens of centimetres of the outline (the face never more
than RIM_OUT outside it, so a Unit stopped by the collider touches the rock it sees) and never above
the collider's top (the Gyrocopter's model clears the top as before). Fallen stones lie along the
foot. The canyon walls take a red sandstone, the ridges a darker stone, as the scene's two
materials did. Each face has one colour (low-poly bands), and Blender bakes ambient occlusion into
the vertex colours.

Axes: Godot's world X and Z (the outlines' coordinates) become Blender X and -Y, its height
Blender Z; the glTF exporter turns them back. The meshes are in world coordinates: the scene draws
them at the origin.
"""

import math
import random
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402
from mathutils.geometry import delaunay_2d_cdt  # noqa: E402

import wasteland_kit as kit  # noqa: E402  (Blender's Python finds it only after the path insert)

# The scene whose CSGPolygon3D nodes the rocks follow.
CLIFFS_SCENE = Path(__file__).resolve().parents[2] / "src/gameplay/maps/map_01/map_01_cliffs.tscn"
# The CSG transform the outlines are read under: the polygon in the ground plane, extruded upward.
CSG_BASIS = [1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0]
# The rock's wall: metres between two points along an outline.
SEGMENT = 1.2
# Bands of the wall, bottom to top: (height above the ground, metres out from the outline). The
# last is the lip, whose height follows TOP_LOW..collider top along the outline.
BANDS = [(-0.35, 0.34), (0.12, 0.3), (0.55, 0.12), (1.0, 0.2), (1.35, 0.06), (None, 0.0)]
# Metres the face may stray in or out of its band (slow along the outline, and per point).
BAND_SWAY = 0.08
BAND_JITTER = 0.05
# The farthest the face reaches outside the outline, metres (above the buried foot).
RIM_OUT = 0.42
# Heights the lip and the top lie between, below the collider's top by at least TOP_MARGIN.
TOP_LOW = 1.78
TOP_MARGIN = 0.02
# Metres the top's edge steps in from the lip, and the longest edge of the top's facets.
TOP_INSET = 0.45
TOP_FACET = 2.6
# The top's facets: their middle height and how far they rise and fall about it, metres.
TOP_MIDDLE = 1.8
TOP_RELIEF = 0.16
TOP_DETAIL = 0.35
# The top's lightening per metre of height.
TOP_LIGHTEN = 0.9
# Fallen stones at the foot: one about every STONE_SPACING metres, radius between the two values,
# centred up to STONE_OUT outside the outline.
STONE_SPACING = 5.0
STONE_RADIUS = (0.14, 0.3)
STONE_OUT = 0.3
# Palettes (sRGB): the bands from the foot up, the lip, the top, and the stones.
PALETTES = {
    "rock": {"bands": [(0.32, 0.18, 0.11), (0.47, 0.28, 0.17), (0.55, 0.35, 0.22),
            (0.44, 0.26, 0.16), (0.58, 0.4, 0.26)], "top": (0.57, 0.38, 0.25),
            "stone": (0.42, 0.26, 0.16)},
    "ridge": {"bands": [(0.24, 0.13, 0.08), (0.34, 0.19, 0.11), (0.41, 0.24, 0.14),
            (0.31, 0.17, 0.1), (0.45, 0.29, 0.18)], "top": (0.46, 0.31, 0.2),
            "stone": (0.32, 0.18, 0.11)},
}
# The material ext_resource ids of the scene and the palette each means.
MATERIAL_PALETTE = {"1_rock": "rock", "2_ridge": "ridge"}
# Darker vertical streaks down the walls (desert varnish): how often along the outline and how dark.
STREAK_SIZE = 7.0
STREAK_DARK = 0.18
# Colour variation per face.
FACE_JITTER = 0.06
# The occlusion bake's reach and ground, metres.
AO_DISTANCE = 0.9
GROUND_SIZE = 320.0
# Preview cameras (Blender coordinates): name -> (location, look-at point, orthographic scale).
VIEWS = {
    "canyon_oblique": ((-38.0, -6.0, 20.0), (-45.0, 30.0, 0.0), None),
    "canyon_close": ((-55.0, 27.5, 2.6), (-50.0, 33.5, 1.2), None),
    "canyon_from_above": ((-55.0, 34.0, 60.0), (-55.0, 34.001, 0.0), 60.0),
    "ridge": ((-62.0, 4.0, 12.0), (-72.0, -32.0, 0.0), None),
}


def read_cliffs(path):
    """The cliffs of the scene: name -> (outline [(x, z) in Godot metres], top height, palette)."""
    text = path.read_text()
    cliffs = {}
    nodes = r'\[node name="(\w+)" type="CSGPolygon3D" parent="\."\]\n(.*?)(?=\n\[|\Z)'
    for name, body in re.findall(nodes, text, re.S):
        transform = re.search(r"transform = Transform3D\(([^)]*)\)", body).group(1)
        values = [float(v) for v in transform.split(",")]
        if [round(v, 6) for v in values[:9]] != CSG_BASIS:
            raise ValueError("cliff %s is not an upright extrusion" % name)
        polygon = re.search(r"polygon = PackedVector2Array\(([^)]*)\)", body).group(1)
        numbers = [float(v) for v in polygon.split(",")]
        depth = float(re.search(r"depth = ([\d.]+)", body).group(1))
        material = re.search(r'material = ExtResource\("(\w+)"\)', body).group(1)
        cliffs[name] = (list(zip(numbers[0::2], numbers[1::2])), values[10] + depth,
                MATERIAL_PALETTE[material])
    return cliffs


def blender_outline(points):
    """The outline in Blender's XY (Godot x, -z), counter-clockwise."""
    loop = [Vector((x, -z)) for x, z in points]
    area = sum(a.x * b.y - b.x * a.y for a, b in zip(loop, loop[1:] + loop[:1]))
    return loop if area > 0.0 else list(reversed(loop))


def densify(loop):
    """Points along the outline about SEGMENT apart, each with its outward normal (the corners'
    normals averaged from their two edges)."""
    points, normals = [], []
    count = len(loop)
    for index in range(count):
        a, b = loop[index], loop[(index + 1) % count]
        steps = max(1, math.ceil((b - a).length / SEGMENT))
        for step in range(steps):
            points.append(a.lerp(b, step / steps))
    for index, point in enumerate(points):
        prev_point, next_point = points[index - 1], points[(index + 1) % len(points)]
        edge_in = (point - prev_point).normalized()
        edge_out = (next_point - point).normalized()
        normal = Vector((edge_in.y, -edge_in.x)) + Vector((edge_out.y, -edge_out.x))
        normals.append(normal.normalized() if normal.length > 1e-6
                else Vector((edge_out.y, -edge_out.x)))
    return points, normals


def slow(seed, distance, size):
    """Smooth noise -1..1 along an outline, distance metres from its start."""
    return noise.noise(Vector((distance / size, seed * 7.31, 0.5)))


def _part(name, bm, colour, face_up=False):
    """A rock part from a bmesh, its faces coloured by colour(centre, normal). face_up: every face
    is turned to face up instead of recalculated (Story 037): the top is an open sheet, and
    recalc_face_normals guesses an open sheet's side from its shape, which turned RidgeWest's top
    face down, so Godot culled it and the ridge looked hollow from above."""
    if face_up:
        for face in bm.faces:
            face.normal_update()
            if face.normal.z < 0.0:
                face.normal_flip()
    else:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    obj = kit._finish_part(name, bm, "rock", recalc=not face_up)
    kit.face_colours(obj, colour)
    return obj


def build_cliff(name, points_xz, top, palette, rng, seed):
    """One cliff's wall, top and fallen stones as parts; returns them."""
    loop = blender_outline(points_xz)
    points, normals = densify(loop)
    count = len(points)
    lengths = [0.0]
    for index in range(1, count):
        lengths.append(lengths[-1] + (points[index] - points[index - 1]).length)
    top_high = top - TOP_MARGIN

    # The wall: rings of the bands from the buried foot to the lip, then in to the top's edge.
    bm = bmesh.new()
    rings = []
    for band_index, (height, out) in enumerate(BANDS):
        ring = []
        for index in range(count):
            along = lengths[index]
            sway = (slow(seed + band_index, along, 9.0) * BAND_SWAY
                    + rng.uniform(-1.0, 1.0) * BAND_JITTER)
            reach = min(out + sway, RIM_OUT) if band_index > 0 else out + sway
            if height is None:
                z = TOP_LOW + (top_high - TOP_LOW) * (0.5 + 0.5 * slow(seed + 40, along, 14.0))
            elif band_index > 0:
                z = height + slow(seed + 20 + band_index, along, 11.0) * 0.08
            else:
                z = height
            xy = points[index] + normals[index] * reach
            ring.append(bm.verts.new((xy.x, xy.y, z)))
        rings.append(ring)
    edge = []
    for index in range(count):
        xy = points[index] - normals[index] * TOP_INSET
        edge.append((xy.x, xy.y, min(rings[-1][index].co.z + rng.uniform(0.0, 0.04), top_high)))
    rings.append([bm.verts.new(co) for co in edge])
    for lower, upper in zip(rings, rings[1:]):
        for index in range(count):
            nxt = (index + 1) % count
            bm.faces.new((lower[index], lower[nxt], upper[nxt], upper[index]))
    band_tops = [BANDS[i + 1][0] for i in range(len(BANDS) - 2)] + [9.0]

    def wall_colour(centre, normal):
        if normal.z > 0.7:
            base, shade = palette["top"], 1.0
        else:
            band = next(i for i, t in enumerate(band_tops) if centre.z < t)
            base = palette["bands"][min(band, len(palette["bands"]) - 1)]
            streak = noise.noise(Vector((centre.x / STREAK_SIZE, centre.y / STREAK_SIZE,
                    seed + 9.0)))
            shade = 1.0 - max(0.0, streak) * STREAK_DARK
        shade *= 1.0 + rng.uniform(-FACE_JITTER, FACE_JITTER)
        return tuple(min(1.0, c * shade) for c in base)

    parts = [_part(name + "_wall", bm, wall_colour)]

    # The top: the edge ring and points scattered inside it, a constrained Delaunay triangulation,
    # the inner points raised or sunk, never above the collider's top.
    ring2d = [Vector((co[0], co[1])) for co in edge]
    inner = inner_points(ring2d, rng)
    out = delaunay_2d_cdt(ring2d + inner, [], [list(range(len(ring2d)))], 1, 1e-5)
    bm = bmesh.new()
    verts = []
    for co, originals in zip(out[0], out[3]):
        on_edge = [i for i in originals if i < len(ring2d)]
        if on_edge:
            z = edge[on_edge[0]][2]
        else:
            rise = noise.noise(Vector((co.x / 9.0, co.y / 9.0, seed * 3.1)))
            detail = noise.noise(Vector((co.x / 3.0, co.y / 3.0, seed * 5.7))) * TOP_DETAIL
            z = min(TOP_MIDDLE + (rise + detail) * TOP_RELIEF, top_high)
        verts.append(bm.verts.new((co.x, co.y, z)))
    for face in out[2]:
        bm.faces.new([verts[i] for i in face])

    def top_colour(centre, normal):
        shade = 1.0 + (centre.z - TOP_MIDDLE) * TOP_LIGHTEN
        shade += noise.noise(Vector((centre.x / 7.0, centre.y / 7.0, seed))) * 0.06
        return tuple(min(1.0, c * shade) for c in palette["top"])

    parts.append(_part(name + "_top", bm, top_colour, face_up=True))

    along = rng.uniform(0.0, STONE_SPACING)
    total = lengths[-1]
    while along < total:
        index = min(range(count), key=lambda i: abs(lengths[i] - along))
        radius = rng.uniform(*STONE_RADIUS)
        centre = points[index] + normals[index] * rng.uniform(0.05, STONE_OUT)
        parts.append(stone(name + "_stone", (centre.x, centre.y, radius * 0.35), radius, palette,
                rng))
        along += STONE_SPACING * rng.uniform(0.6, 1.4)
    return parts


def inside(point, ring):
    """Whether a 2D point lies inside a closed ring of 2D points (even-odd rule)."""
    result = False
    for a, b in zip(ring, ring[1:] + ring[:1]):
        if (a.y > point.y) != (b.y > point.y):
            x = a.x + (point.y - a.y) * (b.x - a.x) / (b.y - a.y)
            if point.x < x:
                result = not result
    return result


def distance_to_ring(point, ring):
    """The distance from a 2D point to the nearest segment of a closed ring."""
    best = float("inf")
    for a, b in zip(ring, ring[1:] + ring[:1]):
        ab = b - a
        t = 0.0 if ab.length_squared == 0.0 else max(0.0, min(1.0,
                (point - a).dot(ab) / ab.length_squared))
        best = min(best, (point - (a + ab * t)).length)
    return best


def inner_points(ring, rng):
    """Points on a jittered grid TOP_FACET apart inside a ring, none nearer its edge than half a
    step."""
    xs, ys = [p.x for p in ring], [p.y for p in ring]
    points = []
    y = min(ys) + TOP_FACET / 2.0
    while y < max(ys):
        x = min(xs) + TOP_FACET / 2.0
        while x < max(xs):
            p = Vector((x + rng.uniform(-0.35, 0.35) * TOP_FACET,
                    y + rng.uniform(-0.35, 0.35) * TOP_FACET))
            if inside(p, ring) and distance_to_ring(p, ring) > TOP_FACET * 0.5:
                points.append(p)
            x += TOP_FACET
        y += TOP_FACET
    return points


def stone(name, centre, radius, palette, rng):
    """A fallen stone: an icosahedron, pressed flat and jittered, half sunk in the sand."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    for vert in bm.verts:
        vert.co.x *= rng.uniform(0.8, 1.2)
        vert.co.y *= rng.uniform(0.8, 1.2)
        vert.co.z *= 0.65
        jitter = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        vert.co += jitter * radius * 0.12
    bm.transform(kit._matrix(centre, (0.0, 0.0, rng.uniform(0.0, 360.0))))
    obj = kit._finish_part(name, bm, "rock")
    tone = rng.uniform(0.85, 1.12)
    kit.face_colours(obj, lambda c, n: tuple(min(1.0, v * tone * (1.08 if n.z > 0.6 else 0.92))
            for v in palette["stone"]))
    return obj


def main():
    args = kit.parse_args()
    kit.reset_scene()
    rng = random.Random(20261010)
    groups = {}
    cliffs = sorted(read_cliffs(CLIFFS_SCENE).items())
    for seed, (name, (points, top, palette)) in enumerate(cliffs):
        groups[name] = build_cliff(name, points, top, PALETTES[palette], rng, seed + 1)
    kit.finish(args["out"], args["previews"], VIEWS, ground_size=GROUND_SIZE,
            ao_distance=AO_DISTANCE, groups=groups, preview_ground=GROUND_SIZE)


main()
