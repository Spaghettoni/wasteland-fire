extends RefCounted
## The mesh file and the older model for the rotors scenario (Story 025 AC-5 and AC-8): file (the rebuilt mesh file holds the body's
## Accent and Neutral and the four turning meshes; its vertex boxes, as the game reads them with MeshUnitModel.hull_of(), are the
## frozen copy's to the bit, at no height limit and at hull_top; the 13,231 vertices of its six meshes, each with its normal and
## its colour as the file holds them (read from the .glb itself, not through the importer, which stores each mesh's positions at
## 16 bits over the mesh's own box), are the 13,231 of the frozen copy's two, one for one, so the occlusion bake and every height
## the evidence reads from the file stay), frozen_copy (the byte copy of the file taken at the start of the story is the file git has at 14eec71 and holds
## only the Accent and the Neutral; the kit fallback scene and the frozen scene of Story 019 are the files git has) and
## older_model (the model the runner gives a scenario that does not declare ROTORS draws the copy's meshes with no pivot, no smear
## and nothing that turns, from the shipped scene and from the frozen scene of Story 019 alike), and rest_pose (a model made from the
## shipped scene and not yet ticked draws every turning mesh exactly where the mesh file has it: each of their vertices, carried
## through its pivot at angle 0, is at its place in the file's frame within a hundredth of a millimetre, and the union of the six
## meshes' boxes is the frozen model's two to the imported meshes' own rounding). Run by rotors.gd. Tooling only.
## Every number comes from the game's files; the scenario types only the md5 sums of the files git has, read by `git show
## 14eec71:<path> | md5`, as test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The md5 sums of the files as git has them at 14eec71, the commit the story starts from: the Gyrocopter's mesh file (the frozen
## copy must be it), the kit fallback model's scene (the story leaves it as it is) and the frozen model scene of Story 019.
const GIT_MESH_FILE_MD5: String = "3499714fba6af15fa07d7bdfeb0acfd3"
const GIT_KIT_SCENE_MD5: String = "62c0265980255b3d092ea252b1103c48"
const GIT_FROZEN_019_MD5: String = "d66059dccf8e58106915740297015cb4"
const KIT_SCENE_PATH: String = "res://src/gameplay/units/models/gyrocopter_kit_model.tscn"
const FROZEN_SCENE_PATH: String = "res://tools/evidence/frozen/gyrocopter_model_story_019.tscn"
## The meshes of the rebuilt file, and of the frozen copy.
const NEW_MESHES: Array[StringName] = [&"Accent", &"Neutral", &"PropellerAccent", &"PropellerNeutral", &"RotorAccent", &"RotorNeutral"]
const OLD_MESHES: Array[StringName] = [&"Accent", &"Neutral"]
## The heights the hull boxes are read at: no limit, and the model scenes' hull_top.
const HULL_TOPS: Array[float] = [INF, 1.4]
## What a turning mesh's vertex carried through its pivot at angle 0 may differ from its place in the file by (a hundredth of a
## millimetre: the float arithmetic of hub plus a vertex minus the hub), and what the box of the six meshes may differ from the frozen
## model's two by (the importer stores the positions of every mesh but the Neutral at 16 bits over the mesh's own box: up to 6.5e-5 m
## in the frozen Accent, which has the longest box).
const REST_TOLERANCE: float = 0.00001
const IMPORT_ROUNDING: float = 0.0001

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_file()
	_frozen_copy()
	await _older_model()
	await _rest_pose()


## The six floats of a box as raw bytes, so that two boxes are the same only to the bit.
static func _bits(box: AABB) -> String:
	return PackedFloat32Array([box.position.x, box.position.y, box.position.z, box.end.x, box.end.y, box.end.z]).to_byte_array().hex_encode()


## The vertices of the meshes of a .glb file, as the file holds them, as one key each (position, normal and colour as raw bytes) in
## a Dictionary of counts; `only` names the meshes to take (all when empty). {table, triangles, count}.
func _vertex_table(path: String, only: Array[StringName] = []) -> Dictionary:
	var table: Dictionary = {}
	var triangles: int = 0
	var count: int = 0
	var meshes: Dictionary = Kit25.glb_meshes(path)
	for mesh_name: StringName in meshes:
		if not only.is_empty() and not only.has(mesh_name):
			continue
		var arrays: Dictionary = meshes[mesh_name]
		var positions: PackedVector3Array = arrays["POSITION"]
		var normals: PackedVector3Array = arrays["NORMAL"]
		var colours: PackedColorArray = arrays["COLOR_0"]
		triangles += int(arrays["triangles"])
		for index: int in positions.size():
			var key: String = PackedVector3Array([positions[index], normals[index]]).to_byte_array().hex_encode() + PackedColorArray([colours[index]]).to_byte_array().hex_encode()
			table[key] = int(table.get(key, 0)) + 1
			count += 1
	return {"table": table, "triangles": triangles, "count": count}


## A list of names as text in alphabetical order: Array.sort() of StringNames orders them by the address of their interned text, which moves with whatever
## else the run has loaded (found at Story 026, when new scripts changed the order this check printed), so the sentence prints them by their letters.
static func _by_text(names: Array) -> Array:
	var texts: Array[String] = []
	for name: StringName in names:
		texts.append(String(name))
	texts.sort()
	var sorted: Array = []
	for text: String in texts:
		sorted.append(StringName(text))
	return sorted


## file (AC-5): see the class doc.
func _file() -> void:
	var problems: PackedStringArray = []
	var shipped: PackedScene = load(Kit25.MESH_FILE_PATH) as PackedScene
	var frozen: PackedScene = load(Kit25.FROZEN_FILE_PATH) as PackedScene
	var names: Array = MeshFile.meshes_of(shipped).keys()
	var old_names: Array = MeshFile.meshes_of(frozen).keys()
	names.sort()
	old_names.sort()
	var expected: Array = NEW_MESHES.duplicate()
	var expected_old: Array = OLD_MESHES.duplicate()
	expected.sort()
	expected_old.sort()
	_q.kit.need(problems, names == expected and old_names == expected_old, "the rebuilt file holds %s and the frozen copy %s" % [_by_text(names), _by_text(old_names)])
	var boxes: PackedStringArray = []
	for top: float in HULL_TOPS:
		var now: AABB = MeshUnitModel.hull_of(shipped, top)
		var then: AABB = MeshUnitModel.hull_of(frozen, top)
		_q.kit.need(problems, _bits(now) == _bits(then) and now.has_volume(), "the hull at %s is %s in the rebuilt file and %s in the frozen copy (%s against %s)" % [top, now, then, _bits(now), _bits(then)])
		boxes.append("%s: %s" % [top, now])
	var now_table: Dictionary = _vertex_table(Kit25.MESH_FILE_PATH)
	var old_table: Dictionary = _vertex_table(Kit25.FROZEN_FILE_PATH)
	var now_keys: Dictionary = now_table["table"]
	var old_keys: Dictionary = old_table["table"]
	var differing: int = 0
	for key: String in now_keys:
		differing += 0 if int(old_keys.get(key, 0)) == int(now_keys[key]) else 1
	for key: String in old_keys:
		differing += 0 if now_keys.has(key) else 1
	_q.kit.need(problems, differing == 0 and int(now_table["count"]) == int(old_table["count"]) and int(now_table["count"]) > 0, "the rebuilt file holds %d vertices and the frozen copy %d, and %d vertex keys (position, normal, colour) are held a different number of times" % [now_table["count"], old_table["count"], differing])
	_q.kit.need(problems, int(now_table["triangles"]) == int(old_table["triangles"]), "the rebuilt file has %d triangles, the frozen copy %d" % [now_table["triangles"], old_table["triangles"]])
	var body_now: Dictionary = _vertex_table(Kit25.MESH_FILE_PATH, OLD_MESHES)["table"]
	var body_then: Dictionary = _vertex_table(Kit25.FROZEN_FILE_PATH, OLD_MESHES)["table"]
	var body_missing: int = 0
	for key: String in body_now:
		body_missing += 0 if int(body_then.get(key, 0)) >= int(body_now[key]) else 1
	_q.kit.need(problems, body_missing == 0 and not body_now.is_empty(), "%d vertex keys of the rebuilt Accent and Neutral are not in the frozen Accent and Neutral with their colours" % body_missing)
	measured.append("file_vertices=%d keys=%d triangles=%d" % [now_table["count"], now_keys.size(), now_table["triangles"]])
	_q.kit.verdict("file", problems, "the rebuilt file holds %s and the frozen copy %s; MeshUnitModel.hull_of() reads the same box to the bit from both (%s); the %d vertices of the six meshes, each with its normal and its vertex colour as the .glb holds them, are the %d of the frozen copy's two, one for one (%d distinct), the body's Accent and Neutral a part of them with the same colours (so the occlusion baked into the colours is the one the older outputs were measured with), and both hold %d triangles" % [_by_text(names), _by_text(old_names), "; ".join(boxes), now_table["count"], old_table["count"], now_keys.size(), now_table["triangles"]])


## frozen_copy (AC-8): the copies and the files the story leaves alone are the files git has.
func _frozen_copy() -> void:
	var problems: PackedStringArray = []
	var frozen_md5: String = FileAccess.get_md5(Kit25.FROZEN_FILE_PATH)
	_q.kit.need(problems, frozen_md5 == GIT_MESH_FILE_MD5, "the frozen mesh file's md5 is %s, git's %s" % [frozen_md5, GIT_MESH_FILE_MD5])
	_q.kit.need(problems, FileAccess.get_md5(Kit25.MESH_FILE_PATH) != GIT_MESH_FILE_MD5, "the shipped mesh file is still the one git has: it was not rebuilt")
	_q.kit.need(problems, FileAccess.get_md5(KIT_SCENE_PATH) == GIT_KIT_SCENE_MD5, "the kit fallback scene's md5 is %s, git's %s" % [FileAccess.get_md5(KIT_SCENE_PATH), GIT_KIT_SCENE_MD5])
	_q.kit.need(problems, FileAccess.get_md5(FROZEN_SCENE_PATH) == GIT_FROZEN_019_MD5, "the frozen scene of Story 019 has md5 %s, git's %s" % [FileAccess.get_md5(FROZEN_SCENE_PATH), GIT_FROZEN_019_MD5])
	var kit_scene: PackedScene = load(KIT_SCENE_PATH) as PackedScene
	var scratch: Node3D = Node3D.new()
	_q.harness.add_child(scratch)
	var kit_model: Node = kit_scene.instantiate()
	scratch.add_child(kit_model)
	_q.kit.need(problems, kit_model is KitUnitModel and kit_model.find_children("*", "RotorPivot", true, false).is_empty(), "the kit fallback model is a %s with %d pivots" % [kit_model.get_class(), kit_model.find_children("*", "RotorPivot", true, false).size()])
	scratch.queue_free()
	_q.kit.verdict("frozen_copy", problems, "the frozen mesh file is the file git has at 14eec71 (md5 %s) and the rebuilt one is not; the kit fallback scene (md5 %s) and the frozen scene of Story 019 (md5 %s) are the files git has, and the kit fallback model, built, has no pivot: it stays still" % [frozen_md5, GIT_KIT_SCENE_MD5, GIT_FROZEN_019_MD5])


## older_model (AC-8): the models the runner gives a scenario that does not declare ROTORS (its _without_rotors()), made from the
## shipped scene and from the frozen scene of Story 019, draw the frozen file's meshes and nothing else: no pivot, no smear, no
## settings, the same hover and hull as the scene they were made from, and the same hull box to the bit as the shipped file.
func _older_model() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var frozen_file: PackedScene = load(Kit25.FROZEN_FILE_PATH) as PackedScene
	for path: String in [Kit25.MODEL_PATH, FROZEN_SCENE_PATH]:
		var source: PackedScene = load(path) as PackedScene
		var made: PackedScene = _q.harness._without_rotors(source)
		var scratch: Node3D = Node3D.new()
		_q.harness.add_child(scratch)
		var original: MeshUnitModel = source.instantiate() as MeshUnitModel
		var model: MeshUnitModel = made.instantiate() as MeshUnitModel
		scratch.add_child(model)
		var names: PackedStringArray = []
		for child: Node in model.get_children():
			names.append(child.name)
		names.sort()
		var drawn: int = model.find_children("*", "MeshInstance3D", true, false).size()
		_q.kit.need(problems, model.mesh_scene == frozen_file and model.rotor_settings == null and names == PackedStringArray(["Accent", "Neutral"]), "%s: the older model has mesh_scene %s, settings %s and children %s" % [path.get_file(), model.mesh_scene.resource_path, model.rotor_settings, names])
		_q.kit.need(problems, model.find_children("*", "RotorPivot", true, false).is_empty() and model.find_children("Smear", "MeshInstance3D", true, false).is_empty() and drawn == 2 and model.is_physics_processing() == original.rise_over_cliffs, "%s: the older model has %d meshes, a pivot or a smear, or a physics tick that is not the rise's" % [path.get_file(), drawn])
		_q.kit.need(problems, model.hover_height == original.hover_height and model.hull_top == original.hull_top and model.rise_over_cliffs == original.rise_over_cliffs and model.smoke_scene == original.smoke_scene and model.offset == original.offset, "%s: the older model's hover, hull_top, rise or smoke differ from its scene's" % path.get_file())
		_q.kit.need(problems, _bits(MeshUnitModel.hull_of(model.mesh_scene, model.hull_top)) == _bits(MeshUnitModel.hull_of(load(Kit25.MESH_FILE_PATH) as PackedScene, original.hull_top)), "%s: the older model's hull differs from the shipped file's" % path.get_file())
		notes.append("%s: %s, hover %.2f m, rise %s" % [path.get_file(), ", ".join(names), model.hover_height, model.rise_over_cliffs])
		scratch.queue_free()
		original.free()
	await _q.kit.advance(1)
	_q.kit.verdict("older_model", problems, "from the shipped model scene and from the frozen scene of Story 019 the runner's older model has the frozen mesh file, no rotor settings, the Accent and the Neutral as its only children, no pivot and no smear, a physics tick only where its scene has the rise, the hover, hull_top, rise and smoke of the scene it was made from, and the hull box of the shipped file to the bit (%s)" % "; ".join(notes))


## rest_pose (AC-5): a model made from the shipped scene, in the tree and not yet ticked, has every pivot at angle 0, so each turning
## mesh stands where the mesh file has it: the vertices of the four meshes read from the .glb itself, carried through the node tree to
## the world (the model stands at the world's origin), are where the file puts them to REST_TOLERANCE, and the world box of the six
## meshes together equals the frozen model's two, to what the importer's 16-bit positions allow (IMPORT_ROUNDING).
func _rest_pose() -> void:
	var problems: PackedStringArray = []
	var scratch: Node3D = Node3D.new()
	_q.harness.add_child(scratch)
	var model: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	model.hover_height = 0.0
	scratch.add_child(model)
	var raw: Dictionary = Kit25.glb_meshes(Kit25.MESH_FILE_PATH)
	var worst: float = 0.0
	var counted: int = 0
	var box: Variant = null
	for mesh_name: StringName in [&"RotorAccent", &"RotorNeutral", &"PropellerAccent", &"PropellerNeutral"]:
		var mesh: MeshInstance3D = model.find_child(String(mesh_name), true, false) as MeshInstance3D
		_q.kit.need(problems, mesh != null, "the model has no %s" % mesh_name)
		if mesh == null:
			continue
		var pivot: RotorPivot = mesh.get_parent() as RotorPivot
		_q.kit.need(problems, pivot != null and pivot.angle == 0.0, "%s is not under a pivot at angle 0" % mesh_name)
		for point: Vector3 in (raw[mesh_name]["POSITION"] as PackedVector3Array):
			worst = maxf(worst, (mesh.global_transform * point).distance_to(point))
			counted += 1
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var drawn: MeshInstance3D = node as MeshInstance3D
		if drawn.name == &"Smear":
			continue
		var world: AABB = drawn.global_transform * drawn.get_aabb()
		box = world if box == null else (box as AABB).merge(world)
	var old_box: Variant = null
	var frozen_model: MeshUnitModel = _q.harness._without_rotors(load(Kit25.MODEL_PATH) as PackedScene).instantiate() as MeshUnitModel
	frozen_model.hover_height = 0.0
	scratch.add_child(frozen_model)
	for node: Node in frozen_model.find_children("*", "MeshInstance3D", true, false):
		var then: AABB = (node as MeshInstance3D).global_transform * (node as MeshInstance3D).get_aabb()
		old_box = then if old_box == null else (old_box as AABB).merge(then)
	var miss: float = 0.0
	if box != null and old_box != null:
		for corner: Vector3 in [(box as AABB).position, (box as AABB).end]:
			miss = maxf(miss, minf((old_box as AABB).position.distance_to(corner), (old_box as AABB).end.distance_to(corner)))
		miss = maxf(absf((box as AABB).position.y - (old_box as AABB).position.y), maxf(absf((box as AABB).end.y - (old_box as AABB).end.y), absf((box as AABB).size.x - (old_box as AABB).size.x)))
	_q.kit.need(problems, counted > 0 and worst <= REST_TOLERANCE, "a turning mesh's vertex stands %.6f m from where the file has it at angle 0 (%d vertices)" % [worst, counted])
	_q.kit.need(problems, box != null and old_box != null and miss <= IMPORT_ROUNDING, "the six meshes' box %s differs from the frozen model's %s by %.6f m" % [box, old_box, miss])
	scratch.queue_free()
	await _q.kit.advance(1)
	measured.append("rest_pose_error=%.7f box_error=%.7f" % [worst, miss])
	_q.kit.verdict("rest_pose", problems, "a model made from the shipped scene and not yet ticked has all %d vertices of its four turning meshes within %.6f m of their place in the .glb (the pivots stand at angle 0 at the hubs with the meshes at minus the hub), and the box of its six meshes is the frozen model's two to %.6f m: the rounding of the importer's 16-bit positions (the imported meshes of the Accent and the turning parts stand up to 6.5e-5 m from the file's)" % [counted, worst, miss])
