extends RefCounted
## Builds a voxel mesh: a grid of coloured cubes of one size, drawn as the faces that border empty space, each face its
## cube's colour, each corner darkened by the cubes around it (the classic voxel ambient occlusion), so the art reads as
## the chunky blocks of the art overhaul (2026-11-26, Martin's picture of a voxel desert). Tooling only:
## tools/art/build_voxel_props.gd uses it to write assets/art/voxel/*.res.

## The darkest a corner gets with all three neighbours filled, as a share of the face's colour.
const AO_FLOOR: float = 0.55

var size: float
## Vector3i -> Color.
var cells: Dictionary = {}


func _init(voxel_size: float) -> void:
	size = voxel_size


func put(at: Vector3i, colour: Color) -> void:
	cells[at] = colour


func has(at: Vector3i) -> bool:
	return cells.has(at)


## The mesh, its origin at `origin` in cells (the middle of the footprint on the ground, say), vertex colours in sRGB.
func build(origin: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirs: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	for at: Vector3i in cells:
		var colour: Color = cells[at]
		for d: Vector3i in dirs:
			if cells.has(at + d) or (d.y < 0 and at.y == 0):
				continue
			_face(st, at, d, colour, origin)
	return st.commit()


func _face(st: SurfaceTool, at: Vector3i, d: Vector3i, colour: Color, origin: Vector3) -> void:
	# Two axes across the face, u x v = d.
	var u: Vector3i
	var v: Vector3i
	if d.x != 0:
		u = Vector3i(0, 1, 0); v = Vector3i(0, 0, 1)
	elif d.y != 0:
		u = Vector3i(0, 0, 1); v = Vector3i(1, 0, 0)
	else:
		u = Vector3i(1, 0, 0); v = Vector3i(0, 1, 0)
	if Vector3(u).cross(Vector3(v)).dot(Vector3(d)) < 0.0:
		var t: Vector3i = u; u = v; v = t
	var centre: Vector3 = Vector3(at) + Vector3(0.5, 0.5, 0.5) + Vector3(d) * 0.5
	var corners: Array[Vector3] = []
	var shades: Array[float] = []
	for k: int in 4:
		var su: int = -1 if (k == 0 or k == 3) else 1
		var sv: int = -1 if (k == 0 or k == 1) else 1
		corners.append(centre + Vector3(u) * 0.5 * su + Vector3(v) * 0.5 * sv)
		var side1: bool = cells.has(at + d + u * su)
		var side2: bool = cells.has(at + d + v * sv)
		var corner: bool = cells.has(at + d + u * su + v * sv)
		var occ: int = 3 if (side1 and side2) else (int(side1) + int(side2) + int(corner))
		shades.append(lerpf(1.0, AO_FLOOR, float(occ) / 3.0))
	var normal: Vector3 = Vector3(d)
	# Flip the quad's diagonal toward the brighter pair, so the shading does not crease.
	# Godot's front faces wind clockwise as seen from outside.
	var order: Array[int] = [0, 2, 1, 0, 3, 2]
	if shades[0] + shades[2] < shades[1] + shades[3]:
		order = [0, 3, 1, 1, 3, 2]
	for i: int in order:
		st.set_normal(normal)
		var c: Color = colour * shades[i]
		c.a = 1.0
		st.set_color(c)
		st.add_vertex((corners[i] - origin) * size)
