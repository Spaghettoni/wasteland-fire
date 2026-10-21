extends RefCounted
## The data for the tyre_tracks scenario (Story 026 AC-1, AC-2, AC-5 and AC-6), read from the shipped files and the models: data (the Map's track
## settings cover the island, the track map is the size the story names with a pixel of about 7 cm, the viewport is two-dimensional, transparent and half
## float, the look, the hold and the fade are the story's starting values, and each type lists the tyres and widths of AC-1: the Motorbike's front 0.20 m
## and rear 0.25 m, the Buggy's four of 0.30 m, the Truck's four of 0.36 m, the Gyrocopter's none), tyres_match_blender (every tyre's place and width are
## the constants of the Blender script that builds its model, a Blender point (x, y, z) being (x, z, -y) in Godot, and the model scenes set no offset and no
## scale, so the model's frame is the Unit's), tyres_touch_the_ground (in the imported mesh, the vertices within 2 cm of the ground are all inside a tyre's
## footprint, each tyre has some, and the model stands within 1 cm of the ground) and ground_surfaces (the ground shader is on exactly the three ground
## materials, and those are used on exactly the island, the canyon road and the salt flat: no water, ford, channel, Garage floor or prop draws a track).
## Run by tyre_tracks.gd. Tooling only. Every number comes from the game's data and files; the scenario types only the story's values.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The story's values: the size of the track map, the metres of a pixel it is "about", the hold and the fade to start with (AC-3, AC-5).
const TEXTURE_SIZE: Vector2i = Vector2i(4096, 1284)
const PIXEL_LOW: float = 0.07
const PIXEL_HIGH: float = 0.075
const HOLD: float = 20.0
const FADE: float = 40.0
## The tyres of AC-1 by type: widths front to back (the Motorbike's differ), and how many.
const WIDTHS: Dictionary = {&"motorbike": [0.20, 0.25], &"buggy": [0.30, 0.30, 0.30, 0.30], &"truck": [0.36, 0.36, 0.36, 0.36], &"gyrocopter": []}
## The Blender scripts: the constants that name where a type's tyres are and how wide, by type.
const SCRIPTS: Dictionary = {&"motorbike": "res://tools/blender/build_motorbike.py", &"buggy": "res://tools/blender/build_buggy.py", &"truck": "res://tools/blender/build_truck.py"}
## How near the ground a vertex counts as touching it, and how far a model's lowest point may be from the ground, metres; how many such vertices a
## tyre has at least, and how far from a tyre's place (along the Unit's length) its footprint reaches.
const TOUCH_HEIGHT: float = 0.02
const STAND_SLACK: float = 0.01
const LEAST_TOUCHING: int = 10
const FOOTPRINT_LENGTH: float = 0.2
## How far a place or a width may differ from its Blender constant, metres (the data is typed to the script's digits).
const BLENDER_TOLERANCE: float = 0.000001
## The ground shader and the folder of Map 01's materials, and the scene that uses them.
const GROUND_SHADER: String = "res://src/gameplay/maps/spatial_env_ground.gdshader"
const MATERIALS_DIR: String = "res://src/gameplay/maps/map_01/materials"
const TERRAIN_SCENE: String = "res://src/gameplay/maps/map_01/map_01_terrain.tscn"
const GROUND_MATERIALS: PackedStringArray = ["road.tres", "salt_flat.tres", "sand.tres"]
const GROUND_USERS: PackedStringArray = ["CanyonRoad", "Island", "PlaneMesh_salt_flat"]
## The other Maps whose ground is drawn by the ground shader (Story 038), each with the one node allowed to use a ground
## material: Map 02's Ground, its sand floor inside the canyon.
const OTHER_GROUNDS: Dictionary = {"res://src/gameplay/maps/map_02/map_02.tscn": "Ground"}

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit26
var _q: Quick


func _init(kit: Kit26) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. They read files and the loaded scene and wait for nothing.
func run() -> void:
	_data()
	_tyres_match_blender()
	_tyres_touch_the_ground()
	_ground_surfaces()


## data (AC-1, AC-2, AC-3, AC-5, AC-6): see the class doc.
func _data() -> void:
	var problems: PackedStringArray = []
	var tracks: TyreTracks = _k.tracks()
	var settings: TyreTrackSettings = tracks.settings
	var outline: PackedVector2Array = _q.map.outline()
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for point: Vector2 in outline:
		low = low.min(point)
		high = high.max(point)
	_q.kit.need(problems, outline.size() > 2 and settings.area_origin.x <= low.x and settings.area_origin.y <= low.y and settings.area_origin + settings.area_size >= high, "the area %s + %s does not cover the island's outline %s to %s" % [settings.area_origin, settings.area_size, low, high])
	var pixel: Vector2 = settings.metres_per_pixel()
	_q.kit.need(problems, settings.texture_size == TEXTURE_SIZE and pixel.x >= PIXEL_LOW and pixel.x <= PIXEL_HIGH and pixel.y >= PIXEL_LOW and pixel.y <= PIXEL_HIGH, "the texture is %s with a pixel of %s m" % [settings.texture_size, pixel])
	_q.kit.need(problems, settings.first_problem().is_empty() and is_equal_approx(settings.hold_seconds, HOLD) and is_equal_approx(settings.fade_seconds, FADE), "the settings read '%s', hold %.1f s, fade %.1f s" % [settings.first_problem(), settings.hold_seconds, settings.fade_seconds])
	var viewport: SubViewport = tracks.track_viewport
	_q.kit.need(problems, viewport.size == settings.texture_size and viewport.disable_3d and viewport.transparent_bg and viewport.use_hdr_2d, "the viewport is %s, 3D disabled %s, transparent %s, high dynamic range %s" % [viewport.size, viewport.disable_3d, viewport.transparent_bg, viewport.use_hdr_2d])
	_q.kit.need(problems, tracks.painter.material is ShaderMaterial and (tracks.painter.material as ShaderMaterial).shader.resource_path.ends_with("canvas_env_tyre_track.gdshader"), "the painter's brush is not the tyre track shader")
	var seen: PackedStringArray = []
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK, Quick.GYROCOPTER]:
		var stats: UnitStats = _q.units.stats(type_index)
		var widths: Array = WIDTHS[stats.type_id]
		var listed: Array[float] = []
		for tyre: TyreContact in stats.tyres:
			listed.append(tyre.width)
		var same: bool = listed.size() == widths.size()
		for index: int in mini(listed.size(), widths.size()):
			same = same and is_equal_approx(listed[index], float(widths[index]))
		_q.kit.need(problems, same and stats.first_problem().is_empty(), "%s lists tyres of %s, the story's %s (first problem '%s')" % [stats.type_id, listed, widths, stats.first_problem()])
		seen.append("%s %d" % [stats.type_id, listed.size()])
	_q.kit.verdict("data", problems, "Map 01's track settings: area %s + %s covers the island's outline (%s to %s), a %s texture of %.4f x %.4f m pixels, hold %.0f s and fade %.0f s, look darkness %.2f rut %.3f m smoothing %.2f; the viewport is two-dimensional, transparent and half float; tyres listed: %s" % [settings.area_origin, settings.area_size, low, high, settings.texture_size, pixel.x, pixel.y, settings.hold_seconds, settings.fade_seconds, settings.darkness, settings.rut_depth, settings.smoothing, ", ".join(seen)])


## The number a Blender script gives a constant (a line "NAME = 0.76"), or NAN when the script has none.
static func _constant(text: String, name: String) -> float:
	var found: RegExMatch = RegEx.create_from_string("(?m)^%s\\s*=\\s*(-?[0-9.]+)" % name).search(text)
	return float(found.get_string(1)) if found != null else NAN


## tyres_match_blender (AC-1): see the class doc.
func _tyres_match_blender() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	for type_id: StringName in SCRIPTS:
		var text: String = FileAccess.get_file_as_string(SCRIPTS[type_id])
		var stats: UnitStats = _q.units.stats(Quick.MOTORBIKE if type_id == &"motorbike" else (Quick.BUGGY if type_id == &"buggy" else Quick.TRUCK))
		var expected: Array[Vector3] = []
		if type_id == &"motorbike":
			expected = [Vector3(0.0, -_constant(text, "FRONT_Y"), _constant(text, "FRONT_W")), Vector3(0.0, -_constant(text, "REAR_Y"), _constant(text, "REAR_W"))]
		else:
			var x: float = _constant(text, "TRACK_X")
			var width: float = _constant(text, "WHEEL_W")
			for z: float in [-_constant(text, "FRONT_Y"), -_constant(text, "REAR_Y")]:
				expected.append(Vector3(-x, z, width))
				expected.append(Vector3(x, z, width))
		_q.kit.need(problems, expected.size() == stats.tyres.size(), "%s: the script makes %d tyres, the data lists %d" % [type_id, expected.size(), stats.tyres.size()])
		for tyre: TyreContact in stats.tyres:
			var matched: bool = false
			for place: Vector3 in expected:
				matched = matched or (absf(tyre.offset.x - place.x) <= BLENDER_TOLERANCE and absf(tyre.offset.y - place.y) <= BLENDER_TOLERANCE and absf(tyre.width - place.z) <= BLENDER_TOLERANCE)
			_q.kit.need(problems, matched, "%s: the tyre at %s of %.3f m is no tyre of %s" % [type_id, tyre.offset, tyre.width, SCRIPTS[type_id]])
			checked += 1
		var scene: Node = stats.model.instantiate()
		var model: UnitModel = scene as UnitModel
		_q.kit.need(problems, model != null and model.offset == Vector3.ZERO and is_equal_approx(model.model_scale, 1.0), "%s: the model scene sets an offset or a scale, so its frame is not the Unit's" % type_id)
		scene.free()
	_q.kit.verdict("tyres_match_blender", problems, "%d tyres of the Motorbike, the Buggy and the Truck are at the places and widths of the constants of their Blender scripts (a Blender point (x, y, z) being (x, z, -y)), and the three model scenes set no offset and no scale" % checked)


## tyres_touch_the_ground (AC-1): see the class doc.
func _tyres_touch_the_ground() -> void:
	var problems: PackedStringArray = []
	var found: PackedStringArray = []
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type_index)
		var scene: Node = stats.model.instantiate()
		var meshes: Dictionary = MeshFile.meshes_of((scene as MeshUnitModel).mesh_scene)
		scene.free()
		var touching: PackedVector3Array = PackedVector3Array()
		var lowest: float = INF
		for mesh_name: StringName in meshes:
			var mesh: Mesh = meshes[mesh_name]
			for surface: int in mesh.get_surface_count():
				for vertex: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					lowest = minf(lowest, vertex.y)
					if vertex.y <= TOUCH_HEIGHT:
						touching.append(vertex)
		var counts: Array[int] = []
		counts.resize(stats.tyres.size())
		counts.fill(0)
		var strays: int = 0
		for vertex: Vector3 in touching:
			var inside: bool = false
			for index: int in stats.tyres.size():
				var tyre: TyreContact = stats.tyres[index]
				if absf(vertex.x - tyre.offset.x) <= tyre.width / 2.0 + TOUCH_HEIGHT and absf(vertex.z - tyre.offset.y) <= FOOTPRINT_LENGTH:
					counts[index] += 1
					inside = true
			strays += 0 if inside else 1
		_q.kit.need(problems, strays == 0 and counts.min() >= LEAST_TOUCHING and absf(lowest) <= STAND_SLACK, "%s: %d vertices within %.0f cm of the ground, %d outside every tyre's footprint, per tyre %s, lowest point %.4f m" % [stats.type_id, touching.size(), TOUCH_HEIGHT * 100.0, strays, counts, lowest])
		found.append("%s %d vertices, lowest %.4f m" % [stats.type_id, touching.size(), lowest])
	_q.kit.verdict("tyres_touch_the_ground", problems, "in the imported meshes the vertices within %.0f cm of the ground are all inside a tyre's footprint (its width and %.1f m along the Unit) and every tyre has at least %d: %s" % [TOUCH_HEIGHT * 100.0, FOOTPRINT_LENGTH, LEAST_TOUCHING, ", ".join(found)])


## The nodes of a scene that use one of the ground materials (Story 038's other Maps).
func _ground_users_of(path: String) -> PackedStringArray:
	var ids: Dictionary = {}
	var users: PackedStringArray = []
	var holder: String = ""
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("[ext_resource") and GROUND_MATERIALS.has(line.get_slice("path=\"", 1).get_slice("\"", 0).get_file()):
			ids[line.get_slice("id=\"", 1).get_slice("\"", 0)] = true
		elif line.begins_with("["):
			holder = line.get_slice("name=\"", 1).get_slice("\"", 0)
		elif line.begins_with("material = ExtResource(\"") and ids.has(line.get_slice("(\"", 1).get_slice("\"", 0)):
			users.append(holder)
	return users


## ground_surfaces (AC-2): see the class doc.
func _ground_surfaces() -> void:
	var problems: PackedStringArray = []
	var using: PackedStringArray = []
	var ids: Dictionary = {}
	for file: String in DirAccess.get_files_at(MATERIALS_DIR):
		if file.ends_with(".tres") and FileAccess.get_file_as_string(MATERIALS_DIR.path_join(file)).contains(GROUND_SHADER):
			using.append(file)
	using.sort()
	_q.kit.need(problems, using == GROUND_MATERIALS, "the ground shader is on %s, not on %s" % [using, GROUND_MATERIALS])
	var users: PackedStringArray = []
	var holder: String = ""
	for line: String in FileAccess.get_file_as_string(TERRAIN_SCENE).split("\n"):
		if line.begins_with("[ext_resource") and GROUND_MATERIALS.has(line.get_slice("path=\"", 1).get_slice("\"", 0).get_file()):
			ids[line.get_slice("id=\"", 1).get_slice("\"", 0)] = true
		elif line.begins_with("["):
			holder = line.get_slice("id=\"", 1).get_slice("\"", 0) if line.begins_with("[sub_resource") else line.get_slice("name=\"", 1).get_slice("\"", 0)
		elif line.begins_with("material = ExtResource(\"") and ids.has(line.get_slice("(\"", 1).get_slice("\"", 0)):
			users.append(holder)
	users.sort()
	_q.kit.need(problems, users == GROUND_USERS, "the ground materials are used by %s, not %s" % [users, GROUND_USERS])
	var elsewhere: PackedStringArray = []
	for path: String in _scenes_under("res://src"):
		if OTHER_GROUNDS.has(path):
			_q.kit.need(problems, _ground_users_of(path) == PackedStringArray([OTHER_GROUNDS[path]]), "%s uses a ground material on %s, not only on %s" % [path, _ground_users_of(path), OTHER_GROUNDS[path]])
		elif path != TERRAIN_SCENE and (FileAccess.get_file_as_string(path).contains("/materials/sand.tres") or FileAccess.get_file_as_string(path).contains("/materials/road.tres") or FileAccess.get_file_as_string(path).contains("/materials/salt_flat.tres")):
			elsewhere.append(path)
	_q.kit.need(problems, elsewhere.is_empty(), "other scenes use a ground material: %s" % [elsewhere])
	_q.kit.verdict("ground_surfaces", problems, "the ground shader, which reads the track map, is on %s, and those three materials are used by %s of Map 01's terrain and by no other scene: the water, the fords, the channels and the Garage floors draw no track" % [", ".join(using), ", ".join(users)])


## Every .tscn under a folder, recursively.
static func _scenes_under(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tscn"):
			found.append(folder.path_join(file))
	for sub: String in DirAccess.get_directories_at(folder):
		found.append_array(_scenes_under(folder.path_join(sub)))
	return found
