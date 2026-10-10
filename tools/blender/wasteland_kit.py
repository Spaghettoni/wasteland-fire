"""Shared helpers for the Wasteland Fire models built in Blender from Python, headless.

A model script beside this file (build_motorbike.py, build_buggy.py, build_truck.py,
build_gyrocopter.py) builds its parts with the shape helpers below, each part a mesh object tagged
with a palette key, then calls finish(): it bakes ambient occlusion into the vertex colours, joins
the parts into the three objects the game reads, renders preview images and exports one .glb file.
Run a model script with Blender's own Python, never the system one:

    blender --background --factory-startup --python tools/blender/build_truck.py -- \
        --out assets/art/vehicles/wasteland_truck/wasteland_truck.glb --previews <dir>

The three objects, and how the game draws them (src/gameplay/units/models/mesh_unit_model.gd):

    Accent   the Team paint. Its vertex colour is the key's tone (1.0, or DARK_TONE for
             accent_dark) times the baked occlusion. The Unit paints it with its Team material,
             which multiplies the vertex colour, as the kit models' accent fold does
             (src/gameplay/units/models/kit_merge.gd).
    Neutral  every other part. Its vertex colour is the key's palette colour times the occlusion.
    Lamp     the lamp lenses, drawn with the palette's glowing lamp material.

The vertex colours hold sRGB numbers written straight into a float attribute, so the .glb carries
them unchanged and the game's materials read them with vertex_color_is_srgb on, as for the kit
models. PALETTE copies the colours of assets/art/shared/wasteland_palette.gd.

Axes and units: metres, +Z up, the model's front toward +Y. The glTF exporter's +Y-up conversion
turns +Y into -Z, the forward of a Unit in Godot. The origin is the middle of the Unit's collider
footprint on the ground.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

# The palette keys of the neutral parts, sRGB, copied from assets/art/shared/wasteland_palette.gd.
PALETTE = {
    "bone_white": (0.93, 0.90, 0.82),
    "rust_dark": (0.30, 0.16, 0.10),
    "scrap": (0.46, 0.42, 0.38),
    "steel": (0.66, 0.67, 0.68),
    "steel_dark": (0.30, 0.31, 0.33),
    "gunmetal": (0.19, 0.20, 0.22),
    "olive": (0.36, 0.38, 0.26),
    "rubber": (0.10, 0.09, 0.08),
    "tread": (0.17, 0.15, 0.13),
    "glass": (0.16, 0.22, 0.26),
    "hole": (0.02, 0.02, 0.02),
    # The saddles and seats: the palette's LEATHER (0.42, 0.22, 0.13) darkened, which beside a Team
    # colour read as orange, as "rust" does.
    "leather": (0.26, 0.17, 0.12),
}
# The tone of the vertex colour under the Team material, as KitMerge.DARK_TONE gives the kit's dark
# Team paints: 0.68 under ORANGE or TEAL comes within 0.02 a channel of ORANGE_DARK and TEAL_DARK.
DARK_TONE = 0.68
# The Team accent keys and their tones; "rim" is the wheel rims, Team paint as on the kit models.
ACCENT_TONES = {"accent": 1.0, "rim": 1.0, "accent_dark": DARK_TONE}
# The key whose parts become the Lamp object.
LAMP_KEY = "lamp"
# The colour the previews paint the Accent with: the palette's ORANGE, the Team colour of Player 1.
PREVIEW_TEAM = (0.90, 0.45, 0.14)
# The lamp colour of the previews (the palette's LAMP).
PREVIEW_LAMP = (1.0, 0.86, 0.60)
# How much of the baked occlusion reaches the vertex colour: 0 none, 1 all of it.
AO_STRENGTH = 0.7
# The distance the occlusion bake looks for nearby geometry, metres: about a wheel's radius.
AO_DISTANCE = 0.45
# The bake's samples per corner.
AO_SAMPLES = 96
# The skull emblem of assets/art/shared/procedural_textures.gd (SKULL_ROWS), one row a line: on the
# Truck's and the Buggy's doors, the Motorbike's tank and the Gyrocopter's fin.
SKULL_ROWS = [
    "....XXXXXX....",
    "..XXXXXXXXXX..",
    ".XXXXXXXXXXXX.",
    ".XXXXXXXXXXXX.",
    "XXXXXXXXXXXXXX",
    "XX...XXXX...XX",
    "XX...XXXX...XX",
    "XX...XXXX...XX",
    "XXXXXXXXXXXXXX",
    "XXXXXX..XXXXXX",
    ".XXXXX..XXXXX.",
    ".XXXXXXXXXXXX.",
    "..XXXXXXXXXX..",
    "..X.X.X.X.X.X.",
    "..X.X.X.X.X.X.",
    "..............",
]


def parse_args():
    """The --out and --previews arguments after Blender's own "--"."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args = {"out": None, "previews": None}
    for index, arg in enumerate(argv):
        if arg in ("--out", "--previews") and index + 1 < len(argv):
            args[arg[2:]] = argv[index + 1]
    return args


def reset_scene():
    """Empties the factory scene: no cube, light or camera is left to be joined or exported."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


# ---------------------------------------------------------------------------------------------
# Shapes. Every helper builds one part in world coordinates (the object keeps an identity
# transform) and returns the object, tagged with its palette key in obj["key"].
# ---------------------------------------------------------------------------------------------

def _finish_part(name, bm, key):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj["key"] = key
    return obj


def _matrix(center, rotation_deg):
    rx, ry, rz = (math.radians(a) for a in rotation_deg)
    rot = Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(ry, 4, "Y") @ Matrix.Rotation(rx, 4, "X")
    return Matrix.Translation(Vector(center)) @ rot


def _bevel(bm, width):
    if width > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=width, segments=1, affect="EDGES",
                profile=0.5, clamp_overlap=True)


def box(name, size, center, key, bevel=0.0, rotation=(0.0, 0.0, 0.0)):
    """A box of size (x, y, z) centred on center, its edges chamfered by bevel metres, turned by
    rotation (degrees about X, then Y, then Z)."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts[:])
    _bevel(bm, min(bevel, min(size) * 0.45))
    bm.transform(_matrix(center, rotation))
    return _finish_part(name, bm, key)


def _solid_from_rings(bm, rings):
    """Faces between consecutive rings of vertices (each ring the same length) and caps on the
    first and the last ring."""
    for a, b in zip(rings, rings[1:]):
        count = len(a)
        for i in range(count):
            j = (i + 1) % count
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(rings[0])
    bm.faces.new(list(reversed(rings[-1])))


def prism_x(name, profile, x_min, x_max, key, bevel=0.0):
    """A solid from a side profile: profile is a convex or simple polygon of (y, z) points,
    extruded across x from x_min to x_max."""
    bm = bmesh.new()
    left = [bm.verts.new((x_min, y, z)) for y, z in profile]
    right = [bm.verts.new((x_max, y, z)) for y, z in profile]
    _solid_from_rings(bm, [left, right])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel)
    return _finish_part(name, bm, key)


def prism_y(name, profile, y_min, y_max, key, bevel=0.0):
    """A solid from a front profile: a polygon of (x, z) points extruded along y."""
    bm = bmesh.new()
    back = [bm.verts.new((x, y_min, z)) for x, z in profile]
    front = [bm.verts.new((x, y_max, z)) for x, z in profile]
    _solid_from_rings(bm, [back, front])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel)
    return _finish_part(name, bm, key)


def loft(name, sections, key, bevel=0.0):
    """A solid through cross-sections: each section a list of (x, y, z) points, all with the same
    number of points, in order; caps close the first and the last."""
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in section] for section in sections]
    _solid_from_rings(bm, rings)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    _bevel(bm, bevel)
    return _finish_part(name, bm, key)


def cylinder(name, radius, depth, center, axis, key, segments=12, bevel=0.0, radius_end=None):
    """A cylinder (a cone frustum when radius_end is given) of the given depth along axis "X",
    "Y" or "Z", centred on center."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
            radius2=radius if radius_end is None else radius_end, depth=depth)
    _bevel(bm, bevel)
    turn = {"X": (0.0, 90.0, 0.0), "Y": (-90.0, 0.0, 0.0), "Z": (0.0, 0.0, 0.0)}[axis]
    bm.transform(_matrix(center, turn))
    return _finish_part(name, bm, key)


def cone(name, radius, length, base_center, direction, key, segments=6):
    """A pointed cone from base_center along direction (a vector), length metres long."""
    direction = Vector(direction).normalized()
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
            radius2=0.0, depth=length)
    rot = direction.to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm.transform(Matrix.Translation(Vector(base_center) + direction * (length / 2.0)) @ rot)
    return _finish_part(name, bm, key)


def tube(name, start, end, radius, key, segments=8):
    """A round bar from start to end."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segments, radius1=radius,
            radius2=radius, depth=axis.length)
    rot = axis.normalized().to_track_quat("Z", "Y").to_matrix().to_4x4()
    bm.transform(Matrix.Translation((start + end) / 2.0) @ rot)
    return _finish_part(name, bm, key)


def torus(name, radius, section, center, axis, key, segments=24, section_segments=8,
        section_width=None):
    """A ring around axis "X", "Y" or "Z" through center: radius to the middle of its section,
    whose half-height (along the radius) is section and half-width (along the axis) section_width,
    or section when it is None. A motorbike tyre, a rim hoop."""
    width = section if section_width is None else section_width
    bm = bmesh.new()
    rings = []
    for i in range(segments):
        a = 2.0 * math.pi * i / segments
        ring = []
        for j in range(section_segments):
            b = 2.0 * math.pi * j / section_segments
            r = radius + section * math.cos(b)
            ring.append(bm.verts.new((r * math.cos(a), r * math.sin(a), width * math.sin(b))))
        rings.append(ring)
    for i in range(segments):
        here, there = rings[i], rings[(i + 1) % segments]
        for j in range(section_segments):
            k = (j + 1) % section_segments
            bm.faces.new((here[j], here[k], there[k], there[j]))
    turn = {"X": (0.0, 90.0, 0.0), "Y": (-90.0, 0.0, 0.0), "Z": (0.0, 0.0, 0.0)}[axis]
    bm.transform(_matrix(center, turn))
    return _finish_part(name, bm, key)


def pixel_plate(name, rows, pixel, center, side, depth, key):
    """A flat emblem extruded from pixel rows ("X" filled, anything else empty), facing outward
    along +X when side is 1 and -X when side is -1: the skull on a door. pixel is one pixel's size
    in metres; center the emblem's middle on the panel's surface."""
    height, width = len(rows), len(rows[0])
    bm = bmesh.new()
    for r, row in enumerate(rows):
        for c, cell in enumerate(row):
            if cell != "X":
                continue
            # Seen from outside, column 0 is at the front (+Y) on the left side and the back on
            # the right side, so the emblem never reads mirrored.
            u = (c - width / 2.0 + 0.5) * pixel * -side
            v = (height / 2.0 - r - 0.5) * pixel
            cube = bmesh.ops.create_cube(bm, size=1.0)["verts"]
            bmesh.ops.scale(bm, vec=Vector((depth, pixel, pixel)), verts=cube)
            bmesh.ops.translate(bm, vec=Vector((center[0] + side * depth / 2.0, center[1] - u,
                    center[2] + v)), verts=cube)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=0.0001)
    return _finish_part(name, bm, key)


def wheel(prefix, center, radius, width, side, lugs=14, rim_key="rim", lug_length=0.13,
        lug_height=0.06):
    """A knobby tyre on a Team rim, its axle along X, its outer face toward side (1 or -1). The
    tyre is a 16-sided drum with lugs tread blocks around it, lug_length along the tread and
    lug_height out of it, alternately offset across the width (the chevron of the concept sheet's
    tyres)."""
    x, y, z = center
    # The lugs stand out of the drum and stop 5 mm inside radius.
    parts = [cylinder(prefix + "_tyre", radius - 0.015 - lug_height / 2.0, width, center, "X",
            "rubber", segments=16, bevel=0.025)]
    out = radius - 0.005 - lug_height / 2.0
    for k in range(lugs):
        a = 2.0 * math.pi * k / lugs
        shift = (0.09 if k % 2 == 0 else -0.09) * width
        at = (x + shift, y + math.cos(a) * out, z + math.sin(a) * out)
        parts.append(box("%s_lug%d" % (prefix, k), (width * 0.66, lug_length, lug_height), at,
                "tread", bevel=0.012, rotation=(math.degrees(a) + 90.0, 0.0, 0.0)))
    face = x + side * (width / 2.0)
    parts.append(cylinder(prefix + "_rim", radius * 0.56, 0.05, (face - side * 0.02, y, z), "X",
            rim_key, segments=10, bevel=0.01))
    parts.append(cylinder(prefix + "_hub", radius * 0.22, 0.08, (face, y, z), "X", "gunmetal",
            segments=8, bevel=0.008))
    for k in range(5):
        a = 2.0 * math.pi * k / 5 + 0.3
        at = (face + side * 0.015, y + math.cos(a) * radius * 0.36,
                z + math.sin(a) * radius * 0.36)
        parts.append(box("%s_nut%d" % (prefix, k), (0.03, 0.035, 0.035), at, "steel"))
    return parts


def rotate_parts(parts, pivot, rotation_deg):
    """Turns parts already built about pivot by rotation (degrees about X, then Y, then Z): a
    group built level, such as the Truck's rocket pod, pitched as one."""
    turn = (Matrix.Translation(Vector(pivot)) @ _matrix((0.0, 0.0, 0.0), rotation_deg)
            @ Matrix.Translation(-Vector(pivot)))
    for obj in parts:
        obj.data.transform(turn)


def arch(name, center_yz, radius, x_min, x_max, key, start_deg=10.0, end_deg=170.0, steps=6,
        thickness=0.07):
    """A faceted fender arch over a wheel: a band following the circle of radius around center_yz
    (y, z) from start_deg to end_deg (0 is the front, 90 the top), across x from x_min to x_max."""
    cy, cz = center_yz
    outer, inner = [], []
    for i in range(steps + 1):
        a = math.radians(start_deg + (end_deg - start_deg) * i / steps)
        outer.append((cy + math.cos(a) * (radius + thickness),
                cz + math.sin(a) * (radius + thickness)))
        inner.append((cy + math.cos(a) * radius, cz + math.sin(a) * radius))
    profile = outer + list(reversed(inner))
    return prism_x(name, profile, x_min, x_max, key)


# ---------------------------------------------------------------------------------------------
# Finishing: colours, occlusion, joining, previews, export.
# ---------------------------------------------------------------------------------------------

def _group_of(key):
    if key in ACCENT_TONES:
        return "Accent"
    if key == LAMP_KEY:
        return "Lamp"
    if key not in PALETTE:
        raise ValueError("unknown palette key '%s'" % key)
    return "Neutral"


def _colour_of(key):
    if key in ACCENT_TONES:
        tone = ACCENT_TONES[key]
        return (tone, tone, tone, 1.0)
    if key == LAMP_KEY:
        return (1.0, 1.0, 1.0, 1.0)
    return tuple(PALETTE[key]) + (1.0,)


def _fill(obj, name, colour):
    attr = obj.data.color_attributes.new(name, "FLOAT_COLOR", "CORNER")
    for datum in attr.data:
        datum.color = colour
    return attr


def _join(objs, name):
    target = objs[0]
    with bpy.context.temp_override(active_object=target, selected_editable_objects=objs,
            object=target):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    return target


def _box_uvs(obj):
    """Box-projected UVs (no texture uses them; the importer generates tangents from them)."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    layer = bm.loops.layers.uv.new("UVMap")
    for face in bm.faces:
        n = face.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop in face.loops:
            co = loop.vert.co
            loop[layer].uv = ((co.y, co.z) if axis == 0 else (co.x, co.z) if axis == 1
                    else (co.x, co.y))
    bm.to_mesh(obj.data)
    bm.free()


def _bake_occlusion(objs, ground_size, distance):
    """Bakes ambient occlusion, looking distance metres for nearby geometry, into a corner attribute
    "ao" of each object, with a ground plane ground_size metres across under the model as an
    occluder (removed after; none when ground_size is 0), and multiplies it into "base" as
    "Col"."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = AO_SAMPLES
    scene.cycles.device = "CPU"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.light_settings.distance = distance
    ground = None
    if ground_size > 0.0:
        bpy.ops.mesh.primitive_plane_add(size=ground_size, location=(0.0, 0.0, 0.0))
        ground = bpy.context.active_object
    for obj in objs:
        ao = _fill(obj, "ao", (1.0, 1.0, 1.0, 1.0))
        obj.data.color_attributes.active_color = ao
        with bpy.context.temp_override(active_object=obj, selected_objects=[obj], object=obj):
            bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
        base = obj.data.color_attributes["base"]
        col = obj.data.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for b, o, c in zip(base.data, obj.data.color_attributes["ao"].data, col.data):
            shade = 1.0 - AO_STRENGTH + AO_STRENGTH * o.color[0]
            c.color = (b.color[0] * shade, b.color[1] * shade, b.color[2] * shade, 1.0)
    if ground is not None:
        bpy.data.objects.remove(ground, do_unlink=True)


def _material(name, colour_attr=True, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    if colour_attr:
        attr = nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    if emission is not None:
        bsdf.inputs["Base Color"].default_value = emission + (1.0,)
        bsdf.inputs["Emission Color"].default_value = emission + (1.0,)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    bsdf.inputs["Roughness"].default_value = 0.8
    return mat


def _preview_material(name, tint=None):
    """A preview-only material: the "Col" sRGB numbers turned linear (gamma 2.2), times tint."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    gamma = nodes.new("ShaderNodeGamma")
    gamma.inputs["Gamma"].default_value = 2.2
    links.new(attr.outputs["Color"], gamma.inputs["Color"])
    out = gamma.outputs["Color"]
    if tint is not None:
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        links.new(out, mix.inputs[6])
        mix.inputs[7].default_value = tuple(c ** 2.2 for c in tint) + (1.0,)
        out = mix.outputs[2]
    links.new(out, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.75
    return mat


def _render_previews(objs, directory, views):
    """Renders the model with EEVEE from each view: name -> (camera location, look-at point,
    orthographic scale or None for a 40 mm perspective)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 960, 640
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    world = scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.72, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    bpy.ops.mesh.primitive_plane_add(size=40.0, location=(0.0, 0.0, 0.0))
    ground = bpy.context.active_object
    sand = bpy.data.materials.new("preview_sand")
    sand.use_nodes = True
    sand_colour = sand.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
    sand_colour.default_value = (0.55, 0.42, 0.28, 1.0)
    ground.data.materials.append(sand)
    bpy.ops.object.light_add(type="SUN", rotation=(math.radians(50.0), 0.0, math.radians(-35.0)))
    sun = bpy.context.active_object
    sun.data.energy = 3.5
    sun.data.angle = math.radians(3.0)
    tints = {"Accent": PREVIEW_TEAM, "Neutral": None}
    saved = {}
    for obj in objs:
        saved[obj.name] = list(obj.data.materials)
        obj.data.materials.clear()
        if obj.name == "Lamp":
            obj.data.materials.append(_material("preview_lamp", False, PREVIEW_LAMP))
        else:
            obj.data.materials.append(_preview_material("preview_" + obj.name, tints[obj.name]))
    bpy.ops.object.camera_add()
    cam = bpy.context.active_object
    scene.camera = cam
    Path(directory).mkdir(parents=True, exist_ok=True)
    for name, (location, target, ortho) in views.items():
        cam.location = Vector(location)
        cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
        cam.data.type = "ORTHO" if ortho else "PERSP"
        if ortho:
            cam.data.ortho_scale = ortho
        else:
            cam.data.lens = 40.0
        scene.render.filepath = str(Path(directory) / ("%s.png" % name))
        bpy.ops.render.render(write_still=True)
        print("PREVIEW %s" % scene.render.filepath)
    for obj in objs:
        obj.data.materials.clear()
        for mat in saved[obj.name]:
            obj.data.materials.append(mat)
    for extra in (ground, sun, cam):
        bpy.data.objects.remove(extra, do_unlink=True)


def finish(out_path, previews_dir, views, ground_size=12.0, ao_distance=AO_DISTANCE):
    """Colours, joins, bakes and exports every part in the scene; renders the views first when
    previews_dir is given. Prints one line per object with its triangle count. ao_distance is how
    far the occlusion bake looks: about a wheel's radius; ground_size the ground plane the bake
    takes as an occluder, 0 for none (a model drawn in the air)."""
    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and "key" in obj]
    groups = {"Accent": [], "Neutral": [], "Lamp": []}
    for obj in parts:
        _fill(obj, "base", _colour_of(obj["key"]))
        groups[_group_of(obj["key"])].append(obj)
    joined = [_join(objs, name) for name, objs in groups.items() if objs]
    for obj in joined:
        _box_uvs(obj)
    _bake_occlusion([o for o in joined if o.name != "Lamp"], ground_size, ao_distance)
    lamp = next((o for o in joined if o.name == "Lamp"), None)
    if lamp is not None:
        _fill(lamp, "Col", (1.0, 1.0, 1.0, 1.0))
    for obj in joined:
        for name in ("base", "ao"):
            if name in obj.data.color_attributes:
                obj.data.color_attributes.remove(obj.data.color_attributes[name])
        obj.data.color_attributes.active_color = obj.data.color_attributes["Col"]
        obj.data.materials.clear()
        if obj.name == "Lamp":
            obj.data.materials.append(_material("lamp", False, PREVIEW_LAMP))
        else:
            obj.data.materials.append(_material(obj.name.lower()))
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        print("OBJECT %s triangles=%d" % (obj.name, tris))
    if previews_dir:
        _render_previews(joined, previews_dir, views)
    if out_path:
        Path(out_path).parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in joined:
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(out_path), export_format="GLB", use_selection=True,
                export_apply=True, export_yup=True, export_normals=True, export_texcoords=True,
                export_tangents=False, export_materials="EXPORT", export_vertex_color="NAME",
                export_vertex_color_name="Col", export_image_format="NONE")
        print("EXPORTED %s" % out_path)
