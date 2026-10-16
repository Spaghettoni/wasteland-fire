extends RefCounted
## What the Story 025 scenarios (rotors with its modules, rotors_showcase and rotors_fps) share on top of the Story 021 kit
## (crash_kit.gd: the flights, the staging, the watch of slide collisions; and under it the Story 020 kit (heights_kit.gd) and
## the kits below it): the watch node that files each Player's turning parts and speed on every tick (rotors_watch.gd), the
## settings the build ships, and readers of a Unit's pivots, smears and drawn parts. Tooling only: nothing under src/ depends on
## this file; loaded with a preload constant. Implements: production/epics/wasteland-fire/story-025-gyrocopter-rotor.md, Test
## Evidence.

## The Story 021 kit: k.k is the Story 020 kit.
const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, a model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The watch node (rotors_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/rotors_watch.gd")

## The settings the build ships, and the mesh file and model scene they belong to.
const SETTINGS_PATH: String = "res://src/gameplay/units/data/gyrocopter_rotor_settings.tres"
const MESH_FILE_PATH: String = "res://assets/art/vehicles/wasteland_gyrocopter/wasteland_gyrocopter.glb"
const FROZEN_FILE_PATH: String = "res://tools/evidence/frozen/wasteland_gyrocopter_story_024.glb"
const MODEL_PATH: String = "res://src/gameplay/units/models/gyrocopter_mesh_model.tscn"
## The Gyrocopter's index into the data.
const GYRO: int = Quick.GYROCOPTER

## The Story 021 kit.
var k: Kit21
## The watch node under the launch scene.
var watch: Watch


## Makes the Story 021 kit and starts the watch.
func _init(harness_node: Node) -> void:
	k = Kit21.new(harness_node)
	watch = Watch.new()
	watch.harness = harness_node
	watch.units = [q().units.units[0], q().units.units[1]]
	harness_node.split.add_child(watch)


## Removes the watch and the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	watch.queue_free()
	k.close()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## The settings the build ships.
func settings() -> RotorSettings:
	return load(SETTINGS_PATH) as RotorSettings


## A Player's Unit's model node, or null.
func model_of(player: int) -> Node3D:
	return q().units.units[player].get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as Node3D


## The pivots under a Player's Unit's model, in the order of its children (the settings' order).
func pivots_of(player: int) -> Array[RotorPivot]:
	var found: Array[RotorPivot] = []
	var model: Node3D = model_of(player)
	if model != null:
		for child: Node in model.get_children():
			if child is RotorPivot:
				found.append(child as RotorPivot)
	return found


## The pivot of the part with the given name ("Rotor" or "Propeller") under a Player's Unit's model, or null.
func pivot_of(player: int, part_name: String) -> RotorPivot:
	for pivot: RotorPivot in pivots_of(player):
		if pivot.name == part_name:
			return pivot
	return null


## Every vertex of a mesh (all its surfaces), in the mesh file's frame.
static func vertices_of(mesh: Mesh) -> PackedVector3Array:
	var found: PackedVector3Array = PackedVector3Array()
	for surface: int in mesh.get_surface_count():
		found.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return found


## A mesh file's mesh by name, from the cache the game reads (MeshFile).
static func mesh_in(file: PackedScene, mesh_name: StringName) -> Mesh:
	return MeshFile.meshes_of(file).get(mesh_name) as Mesh


## A point's coordinates about a part: x the distance along the unit axis from the plane through the hub (h), y the distance from
## the axis (r), as a Vector2(h, r).
static func about(point: Vector3, hub: Vector3, axis: Vector3) -> Vector2:
	var along: float = (point - hub).dot(axis)
	return Vector2(along, (point - hub - axis * along).length())


## A point turned by `angle` radians right-handed about the line through `hub` along the unit `axis`.
static func turned(point: Vector3, hub: Vector3, axis: Vector3, angle: float) -> Vector3:
	return hub + Basis(axis, angle) * (point - hub)


## The raw arrays of a .glb file's meshes, read from the file itself (its JSON chunk and its binary chunk), not through the importer
## (which stores each mesh's vertex positions at 16 bits over the mesh's own box): mesh name -> {POSITION (PackedVector3Array),
## NORMAL (PackedVector3Array), COLOR_0 (PackedColorArray), triangles (int)}. A file without a mesh or an attribute reads empty.
static func glb_meshes(path: String) -> Dictionary:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var json_length: int = bytes.decode_u32(12)
	var document: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8()) as Dictionary
	var binary: int = 20 + json_length + 8
	var found: Dictionary = {}
	for mesh: Dictionary in document.get("meshes", []):
		var primitive: Dictionary = (mesh["primitives"] as Array)[0]
		var attributes: Dictionary = primitive["attributes"]
		found[StringName(mesh["name"])] = {
			"POSITION": _glb_vectors(document, bytes, binary, int(attributes["POSITION"])),
			"NORMAL": _glb_vectors(document, bytes, binary, int(attributes["NORMAL"])),
			"COLOR_0": _glb_colours(document, bytes, binary, int(attributes["COLOR_0"])),
			"triangles": int(((document["accessors"] as Array)[int(primitive["indices"])] as Dictionary)["count"]) / 3}
	return found


## An accessor's bytes: [byte offset of its first element, the distance between elements, its count, its component type, its type].
static func _glb_accessor(document: Dictionary, binary: int, index: int) -> Array:
	var accessor: Dictionary = (document["accessors"] as Array)[index]
	var view: Dictionary = (document["bufferViews"] as Array)[int(accessor["bufferView"])]
	var type_sizes: Dictionary = {"VEC3": 3, "VEC4": 4}
	var component_sizes: Dictionary = {5126: 4, 5123: 2, 5121: 1}
	var width: int = int(type_sizes[accessor["type"]]) * int(component_sizes[int(accessor["componentType"])])
	return [binary + int(view.get("byteOffset", 0)) + int(accessor.get("byteOffset", 0)), int(view.get("byteStride", width)), int(accessor["count"]), int(accessor["componentType"]), String(accessor["type"])]


static func _glb_vectors(document: Dictionary, bytes: PackedByteArray, binary: int, index: int) -> PackedVector3Array:
	var read: Array = _glb_accessor(document, binary, index)
	var out: PackedVector3Array = PackedVector3Array()
	for element: int in int(read[2]):
		var at: int = int(read[0]) + element * int(read[1])
		out.append(Vector3(bytes.decode_float(at), bytes.decode_float(at + 4), bytes.decode_float(at + 8)))
	return out


static func _glb_colours(document: Dictionary, bytes: PackedByteArray, binary: int, index: int) -> PackedColorArray:
	var read: Array = _glb_accessor(document, binary, index)
	var out: PackedColorArray = PackedColorArray()
	var count: int = 4 if String(read[4]) == "VEC4" else 3
	for element: int in int(read[2]):
		var at: int = int(read[0]) + element * int(read[1])
		var parts: Array[float] = []
		for part: int in count:
			match int(read[3]):
				5126:
					parts.append(bytes.decode_float(at + part * 4))
				5123:
					parts.append(bytes.decode_u16(at + part * 2) / 65535.0)
				_:
					parts.append(bytes.decode_u8(at + part) / 255.0)
		out.append(Color(parts[0], parts[1], parts[2], parts[3] if count == 4 else 1.0))
	return out
