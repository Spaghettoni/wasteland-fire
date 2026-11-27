extends RefCounted
## Builds flat-shaded low-poly meshes for the art overhaul (2026-11-27; Martin: "paci sa mi low poly, ale asi nie take
## pravouhle. nech to nie je ako minecraft"): triangles with one normal and one colour each, so every face reads as a
## facet under the sun. Tooling only: tools/art/build_voxel_props.gd uses it.

var _st := SurfaceTool.new()


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


## One flat triangle, wound clockwise as seen from where `outward` points (Godot's front face).
func tri(a: Vector3, b: Vector3, c: Vector3, colour: Color, outward: Vector3 = Vector3.ZERO) -> void:
	var n: Vector3 = (c - a).cross(b - a).normalized()
	if outward != Vector3.ZERO and n.dot(outward) < 0.0:
		var t: Vector3 = b; b = c; c = t
		n = -n
	for v: Vector3 in [a, b, c]:
		_st.set_normal(n)
		_st.set_color(colour)
		_st.add_vertex(v)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color, outward: Vector3) -> void:
	tri(a, b, c, colour, outward)
	tri(a, c, d, colour, outward)


## A jittered icosphere (one subdivision) at centre with radii, its faces coloured from `tones` by `pick`.
func blob(centre: Vector3, radii: Vector3, tones: Array[Color], rng: RandomNumberGenerator, jitter: float) -> void:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var unit: Array[Vector3] = []
	for v: Vector3 in verts:
		unit.append(v.normalized())
	# One subdivision, midpoints shared so the jitter keeps the surface closed.
	var mids: Dictionary = {}
	var fine: Array = []
	for f: Array in faces:
		var m: Array[int] = []
		for e: int in 3:
			var a: int = f[e]
			var b: int = f[(e + 1) % 3]
			var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
			if not mids.has(key):
				mids[key] = unit.size()
				unit.append((unit[a] + unit[b]).normalized())
			m.append(mids[key])
		fine += [[f[0], m[0], m[2]], [f[1], m[1], m[0]], [f[2], m[2], m[1]], [m[0], m[1], m[2]]]
	var placed: Array[Vector3] = []
	for v: Vector3 in unit:
		placed.append(centre + v * radii * (1.0 + rng.randf_range(-jitter, jitter)))
	for f: Array in fine:
		var a: Vector3 = placed[f[0]]
		var b: Vector3 = placed[f[1]]
		var c: Vector3 = placed[f[2]]
		if a.y < 0.0 and b.y < 0.0 and c.y < 0.0:
			continue
		var mid: Vector3 = (a + b + c) / 3.0
		var tone: Color = tones[rng.randi_range(0, tones.size() - 1)]
		# Faces higher up catch a little more light.
		tone = tone.lightened(clampf((mid.y - centre.y) / maxf(radii.y, 0.01), 0.0, 1.0) * 0.12)
		tri(Vector3(a.x, maxf(a.y, 0.0), a.z), Vector3(b.x, maxf(b.y, 0.0), b.z), Vector3(c.x, maxf(c.y, 0.0), c.z), tone, mid - centre)


func commit() -> ArrayMesh:
	return _st.commit()
