extends RefCounted
## The data of the crash, for the crash scenario (Story 021 AC-7): data_lines (crash_speed is a UnitStats value in m/s, zero by
## default, 4.0 in gyrocopter_stats.tres and no line at all in the other three files, refused by first_problem() when negative or
## not a number; the code that tests a crash holds no type name and no number but zero) and sea_edge_group (the 32 bodies of the
## Map's invisible sea edge are told apart by a group stored in map_01_terrain.tscn, the one name written once in unit.gd, and not
## by a physics layer: they stay on the map layer with the Floor and the project names no new layer). Run by crash.gd. Tooling
## only. Every number comes from the game's data; the scenario types only its test inputs and the story's values.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The four types' data files, by type id, and the Unit and the Map's terrain scene whose text is read.
const STATS_PATHS: Dictionary = {
	&"motorbike": "res://src/gameplay/units/data/motorbike_stats.tres",
	&"buggy": "res://src/gameplay/units/data/buggy_stats.tres",
	&"truck": "res://src/gameplay/units/data/truck_stats.tres",
	&"gyrocopter": "res://src/gameplay/units/data/gyrocopter_stats.tres"}
const UNIT_PATH: String = "res://src/gameplay/units/unit.gd"
const TERRAIN_PATH: String = "res://src/gameplay/maps/map_01/map_01_terrain.tscn"
## The function whose text is read, and the line of the data file that holds the value.
const CRASH_FUNCTION: String = "func _has_crashed()"
const DATA_LINE: String = "\ncrash_speed = "
## The physics layers the project names (project.godot layer_names/3d_physics): the seven it had before the story. A crash adds none.
const KNOWN_LAYERS: int = 7

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_data_lines()
	_sea_edge_group()


## The text of a function from its first line to the two blank lines that end it.
static func function_text(source: String, header: String) -> String:
	var start: int = source.find(header)
	if start < 0:
		return ""
	var end: int = source.find("\n\n\n", start)
	return source.substr(start, (end if end >= 0 else source.length()) - start)


## The lines of a script that are code: not blank and not a comment.
static func code_lines(source: String) -> PackedStringArray:
	var found: PackedStringArray = []
	for line: String in source.split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			found.append(line)
	return found


## data_lines (AC-7).
func _data_lines() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type_id: StringName in STATS_PATHS:
		var path: String = STATS_PATHS[type_id]
		var text: String = FileAccess.get_file_as_string(path)
		var fresh: UnitStats = ResourceLoader.load(path, "UnitStats", ResourceLoader.CACHE_MODE_IGNORE) as UnitStats
		var is_gyro: bool = type_id == &"gyrocopter"
		_q.kit.need(problems, fresh != null and fresh.type_id == type_id, "%s did not load as the %s" % [path, type_id])
		_q.kit.need(problems, text.contains(DATA_LINE) == is_gyro, "%s %s a crash_speed line" % [path.get_file(), "lacks" if is_gyro else "has"])
		_q.kit.need(problems, (fresh.crash_speed == 4.0) if is_gyro else (fresh.crash_speed == 0.0), "%s has crash_speed %.2f" % [path.get_file(), fresh.crash_speed])
		_q.kit.need(problems, fresh.first_problem().is_empty(), "%s is refused: %s" % [path.get_file(), fresh.first_problem()])
		notes.append("%s: %s" % [type_id, "crash_speed = %.1f" % fresh.crash_speed if is_gyro else "no line, %.1f" % fresh.crash_speed])
	for type_index: int in _q.controller.unit_types().size():
		var live: UnitStats = _q.units.stats(type_index)
		_q.kit.need(problems, (live.crash_speed == 4.0) == (live.type_id == &"gyrocopter") and (live.crash_speed == 0.0) == (live.type_id != &"gyrocopter"), "the live %s has crash_speed %.2f in this scenario, which declares GYRO_CRASH" % [live.type_id, live.crash_speed])
	_q.kit.need(problems, UnitStats.new().crash_speed == 0.0, "the script default is %.2f" % UnitStats.new().crash_speed)
	var hint: String = ""
	for property: Dictionary in UnitStats.new().get_property_list():
		if property["name"] == "crash_speed":
			hint = str(property["hint_string"])
	_q.kit.need(problems, hint.begins_with("0.0,") and hint.contains("suffix:m/s"), "the property's range hint is '%s'" % hint)
	var refused: PackedStringArray = []
	for bad: float in [-0.1, -4.0, NAN]:
		var copy: UnitStats = _k.gyro_stats().duplicate() as UnitStats
		copy.crash_speed = bad
		_q.kit.need(problems, copy.first_problem().contains("crash_speed"), "crash_speed %s was not refused (%s)" % [bad, copy.first_problem()])
		refused.append(str(bad))
	for fine: float in [0.0, 4.0, 100.0]:
		var copy: UnitStats = _k.gyro_stats().duplicate() as UnitStats
		copy.crash_speed = fine
		_q.kit.need(problems, copy.first_problem().is_empty(), "crash_speed %s was refused (%s)" % [fine, copy.first_problem()])
	var source: String = FileAccess.get_file_as_string(UNIT_PATH)
	var body: String = function_text(source, CRASH_FUNCTION)
	_q.kit.need(problems, not body.is_empty(), "%s was not found in %s" % [CRASH_FUNCTION, UNIT_PATH])
	var numbers: PackedStringArray = []
	var digits: RegEx = RegEx.new()
	digits.compile("(?<![A-Za-z_0-9.])[0-9]+(\\.[0-9]+)?")
	for found: RegExMatch in digits.search_all("\n".join(code_lines(body))):
		numbers.append(found.get_string())
	var stray: PackedStringArray = []
	for number: String in numbers:
		if number != "0" and number != "0.0":
			stray.append(number)
	_q.kit.need(problems, stray.is_empty() and not body.contains("\"") and not body.contains("can_fly"), "the crash test holds %s, a string or can_fly" % [stray])
	var names: PackedStringArray = []
	for line: String in code_lines(source):
		var lower: String = line.to_lower()
		for type_name: String in ["gyrocopter", "motorbike", "buggy", "truck"]:
			if lower.contains(type_name):
				names.append(type_name)
	_q.kit.need(problems, names.is_empty(), "unit.gd names a type in code: %s" % [names])
	measured.append("crash_numbers=%d" % numbers.size())
	_q.kit.verdict("data_lines", problems, "crash_speed is a UnitStats value in m/s (range 0 and up, suffix m/s), zero by default: %s; first_problem() refuses %s and accepts 0, 4 and 100; the crash test (%d lines) holds the numbers %s and no string and no type name, and none of unit.gd's code lines names a type" % ["; ".join(notes), ", ".join(refused), code_lines(body).size(), numbers])


## sea_edge_group (AC-7).
func _sea_edge_group() -> void:
	var problems: PackedStringArray = []
	var group: StringName = Unit.MAP_EDGE_GROUP
	var shore: Node = _k.map().get_node("Terrain/ShoreEdge")
	var bodies: Array[Node] = shore.get_children()
	var members: Array[Node] = _q.harness.get_tree().get_nodes_in_group(group)
	var outside: PackedStringArray = []
	for node: Node in members:
		if not shore.is_ancestor_of(node) and node != shore:
			outside.append(str(node.get_path()))
	var floor_layer: int = (_k.map().get_node("Floor") as CollisionObject3D).collision_layer
	var layers: PackedInt32Array = []
	for body: Node in bodies:
		_q.kit.need(problems, body.is_in_group(group), "%s is not in the group" % body.name)
		layers.append((body as CollisionObject3D).collision_layer)
		_q.kit.need(problems, (body as CollisionObject3D).collision_layer == floor_layer and (body as CollisionObject3D).collision_mask == 0, "%s is on layer %d, mask %d (the Floor's layer is %d)" % [body.name, (body as CollisionObject3D).collision_layer, (body as CollisionObject3D).collision_mask, floor_layer])
	_q.kit.need(problems, bodies.size() == 32 and members.size() == 32 and outside.is_empty(), "%d shore bodies, %d members of the group, %d of them outside the shore (%s)" % [bodies.size(), members.size(), outside.size(), outside])
	var scene: String = FileAccess.get_file_as_string(TERRAIN_PATH)
	var stored: int = scene.count("groups=[\"%s\"]" % group)
	var declared: int = scene.count("parent=\"ShoreEdge\"")
	_q.kit.need(problems, stored == 32 and declared == 32, "map_01_terrain.tscn stores the group on %d of its %d shore bodies" % [stored, declared])
	var names: int = 0
	for layer: int in range(1, 33):
		names += 1 if not str(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer, "")).is_empty() else 0
	_q.kit.need(problems, names == KNOWN_LAYERS, "the project names %d physics layers, %d before the story" % [names, KNOWN_LAYERS])
	var unit_source: String = FileAccess.get_file_as_string(UNIT_PATH)
	var written: int = 0
	for line: String in code_lines(unit_source):
		written += line.count("\"%s\"" % group)
	_q.kit.need(problems, written == 1 and String(group) == "map_edge", "unit.gd writes the group's name %d times in code" % written)
	measured.append("edge_bodies=%d" % bodies.size())
	_q.kit.verdict("sea_edge_group", problems, "the %d bodies of the sea edge are in the group '%s' (no other node is), stored in map_01_terrain.tscn on %d of %d shore bodies, on the map layer (%d) with the Floor and with no mask, the project names %d physics layers as before, and unit.gd writes the group's name once in code" % [bodies.size(), group, stored, declared, floor_layer, names])
