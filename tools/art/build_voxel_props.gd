extends SceneTree
## Writes the voxel props of the art overhaul (2026-11-26) to assets/art/voxel/: cactuses, mesas (layered cliffs),
## rocks and shrubs, each an ArrayMesh .res with vertex colours (drawn with assets/art/voxel/voxel_material.tres).
## Seeded, so a rerun writes the same meshes. Tooling only.
## Run: godot --headless --path . -s res://tools/art/build_voxel_props.gd

const Voxels: GDScript = preload("res://tools/art/voxel_builder.gd")
const OUT: String = "res://assets/art/voxel/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 20261126
	for i: int in 4:
		_save(_cactus(i), "cactus_%d" % i)
	for i: int in 4:
		_save(_mesa(i), "mesa_%d" % i)
	for i: int in 4:
		_save(_rock(i), "rock_%d" % i)
	for i: int in 2:
		_save(_shrub(i), "shrub_%d" % i)
	_save(_bush(false), "bush_standing")
	_save(_bush(true), "bush_flat")
	quit()


func _save(mesh: ArrayMesh, name: String) -> void:
	var err: int = ResourceSaver.save(mesh, OUT + name + ".res")
	print("VOXEL %s faces=%d err=%d aabb=%s" % [name, mesh.surface_get_array_len(0) / 6, err, mesh.get_aabb()])


func _jit(c: Color, amount: float) -> Color:
	var f: float = 1.0 + rng.randf_range(-amount, amount)
	return Color(c.r * f, c.g * f, c.b * f)


## A saguaro: a 2x2 trunk (0.2 m voxels), one to three arms out and up, ribbed in two greens, lighter tips.
func _cactus(i: int) -> ArrayMesh:
	var v = Voxels.new(0.22)
	var green := Color(0.30, 0.52, 0.20)
	var dark := Color(0.20, 0.38, 0.14)
	var tip := Color(0.52, 0.70, 0.30)
	var height: int = rng.randi_range(7, 9)
	for y: int in height:
		for x: int in 3:
			for z: int in 3:
				var c: Color = dark if (x + z) % 2 == 1 else green
				v.put(Vector3i(x, y, z), _jit(tip if y == height - 1 else c, 0.06))
	var arms: int = 1 + (i % 3)
	var used: Array[int] = []
	for a: int in arms:
		var side: int = [0, 1, 2, 3][(a + i) % 4]
		var dir: Vector3i = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)][side]
		var start_y: int = rng.randi_range(3, height - 4)
		var out: int = rng.randi_range(2, 3)
		var up: int = rng.randi_range(2, height - start_y - 1)
		var base := Vector3i(1 + dir.x, start_y, 1 + dir.z)
		var p: Vector3i = base
		for s: int in out:
			p += dir
			_cactus_block(v, p, green, dark)
		for s: int in up:
			p += Vector3i(0, 1, 0)
			_cactus_block(v, p, tip if s == up - 1 else green, dark)
	return v.build(Vector3(1.5, 0.0, 1.5))


## A 2x2 arm section of a cactus at p (its low corner), ribbed.
func _cactus_block(v, p: Vector3i, green: Color, dark: Color) -> void:
	for x: int in 2:
		for z: int in 2:
			var q := p + Vector3i(x if p.x >= 1 else -x, 0, z if p.z >= 1 else -z)
			v.put(q, _jit(dark if (q.x + q.z) % 2 == 1 else green, 0.06))


## A mesa: a blob footprint (0.6 m voxels) rising in stepped terraces, its sides in bands of red, peach and rust, its
## tops sand. i picks the size.
func _mesa(i: int) -> ArrayMesh:
	var v = Voxels.new(0.6)
	var bands: Array[Color] = [Color(0.72, 0.36, 0.26), Color(0.86, 0.54, 0.38), Color(0.78, 0.44, 0.30), Color(0.92, 0.66, 0.46), Color(0.64, 0.31, 0.24), Color(0.84, 0.48, 0.34)]
	var top := Color(0.88, 0.62, 0.40)
	var radius: float = [9.0, 13.0, 7.0, 16.0][i]
	var height: int = [14, 20, 10, 24][i]
	var noise := FastNoiseLite.new()
	noise.seed = 77 + i
	noise.frequency = 0.08
	var r: int = int(radius) + 4
	var band_of: Array[int] = []
	var b: int = 0
	var y: int = 0
	while y < height + 2:
		var thick: int = rng.randi_range(1, 3)
		for t: int in thick:
			band_of.append(b)
		y += thick
		b += 1
	for x: int in range(-r, r + 1):
		for z: int in range(-r, r + 1):
			var d: float = Vector2(x, z).length() / radius
			var n: float = noise.get_noise_2d(x, z)
			var edge: float = 1.0 - d + n * 0.35
			if edge <= 0.0:
				continue
			# A sheer cliff with a flat, slightly stepped top, and a low skirt of fallen blocks round its foot.
			var h: int
			if edge > 0.3:
				h = int(height * (0.82 + 0.18 * clampf(noise.get_noise_2d(x * 3.0 + 50.0, z * 3.0) + 0.5, 0.0, 1.0)))
			else:
				h = 1 + int(height * 0.3 * edge / 0.3 * clampf(0.5 + noise.get_noise_2d(x * 4.0, z * 4.0 + 9.0), 0.0, 1.0))
			for yy: int in h:
				var c: Color = bands[band_of[yy] % bands.size()]
				v.put(Vector3i(x, yy, z), _jit(top if yy == h - 1 else c, 0.05))
	return v.build(Vector3(0.0, 0.0, 0.0))


## A rock: a lumpy cluster (0.3 m voxels) in rust and dusty red.
func _rock(i: int) -> ArrayMesh:
	var v = Voxels.new(0.3)
	var tones: Array[Color] = [Color(0.62, 0.34, 0.25), Color(0.74, 0.44, 0.32), Color(0.55, 0.36, 0.30)]
	var lumps: int = 2 + i
	for l: int in lumps:
		var c := Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
		var rad: float = rng.randf_range(1.6, 2.8)
		var tone: Color = tones[rng.randi_range(0, 2)]
		for x: int in range(-4, 5):
			for y: int in range(0, 6):
				for z: int in range(-4, 5):
					var p := Vector3(x, y * 0.9, z) - c
					if p.length() < rad:
						v.put(Vector3i(int(c.x) + x, y, int(c.z) + z), _jit(tone.lightened(0.12) if y >= 2 else tone, 0.07))
	return v.build(Vector3(0.0, 0.0, 0.0))


## The Bush's two looks (src/gameplay/cover/bush.tscn) in voxels (0.2 m): standing, the union of the six lumps the
## scene had (ellipsoids, centre and radii in metres); flat, the same footprint pressed into a mat one or two voxels high.
func _bush(flat: bool) -> ArrayMesh:
	var v = Voxels.new(0.2)
	var lumps: Array = [[Vector3(0, 0.892, 0), Vector3(1.25, 1.04, 1.25)], [Vector3(1.25, 0.722, 0.35), Vector3(0.95, 0.8, 0.95)],
		[Vector3(-1.15, 0.68, 0.55), Vector3(0.9, 0.8, 0.9)], [Vector3(0.3, 0.68, -1.2), Vector3(0.9, 0.8, 0.9)],
		[Vector3(-0.55, 0.595, -0.95), Vector3(0.8, 0.68, 0.8)], [Vector3(0.85, 0.552, 1.05), Vector3(0.75, 0.64, 0.75)]]
	var greens: Array[Color] = [Color(0.34, 0.38, 0.16), Color(0.26, 0.31, 0.12), Color(0.42, 0.44, 0.20), Color(0.30, 0.35, 0.14)]
	var dry: Array[Color] = [Color(0.52, 0.50, 0.28), Color(0.44, 0.44, 0.22), Color(0.58, 0.54, 0.32)]
	for x: int in range(-13, 14):
		for z: int in range(-13, 14):
			for y: int in range(0, 11):
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5) * 0.2
				var inside: bool = false
				for l: Array in lumps:
					var q: Vector3 = (p - l[0]) / l[1]
					if flat:
						q.y = 0.0
					if q.length() < 1.0:
						inside = true
						break
				if not inside:
					continue
				if flat and y > (1 if (x * 7 + z * 3) % 5 == 0 else 0):
					continue
				var c: Color = (dry[rng.randi_range(0, 2)] if flat else greens[rng.randi_range(0, 3)])
				# Dry tips on the top of the standing bush.
				if not flat and y >= 8 and rng.randf() < 0.3:
					c = dry[rng.randi_range(0, 2)]
				v.put(Vector3i(x, y, z), _jit(c, 0.06))
	return v.build(Vector3(0.0, 0.0, 0.0))


## A desert shrub: a dome (0.25 m voxels) in olive greens with dry tips.
func _shrub(i: int) -> ArrayMesh:
	var v = Voxels.new(0.25)
	var greens: Array[Color] = [Color(0.40, 0.48, 0.20), Color(0.32, 0.42, 0.16), Color(0.52, 0.56, 0.26)]
	var rad: float = 4.5 + i
	for x: int in range(-6, 7):
		for y: int in range(0, 7):
			for z: int in range(-6, 7):
				var p := Vector3(x, y * 1.5, z)
				var n: float = sin(x * 1.7 + z * 0.9 + i) * 0.4
				if p.length() < rad + n:
					v.put(Vector3i(x, y, z), _jit(greens[rng.randi_range(0, 2)], 0.08))
	return v.build(Vector3(0.0, 0.0, 0.0))
