extends RefCounted
## The checks of the bases scenario (bases.gd) that read the Bases' physics setup and spare spawn points, kept
## here so that file stays the size TD-003 asks of a scenario: zone_layers (each Base's zone sits on the layer named
## "zones", watches the one named "units" and has a box shape), layer_names (project.godot names the first
## three 3D physics layers map, units and zones) and spare_spawns (each Base has spare spawn points on its pad,
## facing the way its spawn point does and further from it and from each other than a Unit is long, so one
## Unit cannot stand on two of them).
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3 and AC-4 (a
## destroyed Unit always respawns: the Base gives the controller somewhere to put it when the spawn point is
## taken) and the layer setup the story's implementation notes ask for. Made by bases.gd. Tooling only: nothing
## under src/ depends on this file.

## The runner, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The layer names project.godot gives the first three 3D physics layers, in layer order.
const LAYER_NAMES: Array[String] = ["map", "units", "zones"]
## The ProjectSettings key of the name of a 3D physics layer, for a layer number from 1.
const LAYER_SETTING: String = "layer_names/3d_physics/layer_%d"

var _harness: Harness
var _kit: Kit
var _bases: Array[Base] = []
var _units: Array[Unit] = []


func _init(harness: Node, bases: Array[Base], units: Array[Unit]) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_bases.assign(bases)
	_units.assign(units)


## AC-1 and the story's layer notes: each zone sits on the layer named "zones" (LAYER_NAMES[2]), watches the
## layer named "units" (LAYER_NAMES[1]), which is where the Units are, and has a box shape. The bits come
## from ProjectSettings.
func check_zone_layers() -> void:
	var zones_bit: int = _layer_bit(LAYER_NAMES[2])
	var units_bit: int = _layer_bit(LAYER_NAMES[1])
	var passed: bool = zones_bit != 0 and units_bit != 0
	var detail: PackedStringArray = ["layer '%s' is bit %d, layer '%s' is bit %d (project layer names)" % [
		LAYER_NAMES[2], zones_bit, LAYER_NAMES[1], units_bit]]
	for index: int in _bases.size():
		var zone: Area3D = _bases[index].zone
		var box: BoxShape3D = _box_of(zone)
		passed = passed and zone.collision_layer == zones_bit and zone.collision_mask == units_bit \
			and box != null and (_units[index].collision_layer & units_bit) != 0
		detail.append("player_%d zone layer=%d (expected %d) mask=%d (expected %d) box=%s unit_layer=%d" % [
			index + 1, zone.collision_layer, zones_bit, zone.collision_mask, units_bit,
			box.size if box != null else "none", _units[index].collision_layer])
	_harness.check("zone_layers", passed, " | ".join(detail))


## Story 003's layer setup: the first three 3D physics layers are named map, units and zones.
func check_layer_names() -> void:
	var passed: bool = true
	var detail: PackedStringArray = []
	for index: int in LAYER_NAMES.size():
		var named: String = String(ProjectSettings.get_setting(LAYER_SETTING % (index + 1), ""))
		passed = passed and named == LAYER_NAMES[index]
		detail.append("layer_%d='%s' (expected '%s')" % [index + 1, named, LAYER_NAMES[index]])
	_harness.check("layer_names", passed, " ".join(detail))


## AC-3 and AC-4: each Base has at least one spare spawn point; every spawn point of it (the spawn point and
## the spares) lies on the pad, faces the way the spawn point does and is further from every other than the
## longest horizontal side of a Unit's collider, so one Unit cannot stand on two of them and a Round of two
## Players always has a free one.
func check_spare_spawns() -> void:
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	var span: float = _collider_span(_units[0])
	_kit.need(problems, span > 0.0, "the Unit has no box collider to measure")
	for index: int in _bases.size():
		detail.append(_judge_spare_spawns(index, span, problems))
	_kit.verdict("spare_spawns", problems, "collider span %.2f m | %s" % [span, " | ".join(detail)])


## AC-1: a Base moved without its spawn point is reported, not silent. Each Base is moved sideways by two pad
## widths for a moment (its spawn point is a loose marker of the field, so it stays where it was) and
## first_spawn_problem() must then name that spawn point; put back, it must say nothing.
func check_spawn_guard() -> void:
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	for index: int in _bases.size():
		var base: Base = _bases[index]
		var home: Transform3D = base.global_transform
		var shift: float = 2.0 * base.pad.get_aabb().size.x
		base.global_position += Vector3(shift, 0.0, 0.0)
		var moved: String = base.first_spawn_problem()
		base.global_transform = home
		var back: String = base.first_spawn_problem()
		_kit.need(problems, moved.contains(String(base.spawn_point.name)) and back.is_empty(),
			"player_%d: moved %.1f m the Base said '%s', put back it said '%s'" % [index + 1, shift, moved, back])
		detail.append("player_%d: moved %.1f m: '%s'; put back: '%s'" % [index + 1, shift, moved, back])
	_kit.verdict("spawn_guard", problems, " | ".join(detail))


## Judges one Base's spawn points: spares present, all on the pad, all facing alike, all further apart than
## the collider's span. Adds to problems and returns the numbers.
func _judge_spare_spawns(index: int, span: float, problems: PackedStringArray) -> String:
	var base: Base = _bases[index]
	var points: Array[Marker3D] = [base.spawn_point]
	points.append_array(base.spare_spawn_points)
	var footprint: AABB = base.pad.get_aabb()
	var heading: Vector3 = -base.spawn_point.global_transform.basis.z
	var on_pad: int = 0
	var facing_min: float = 1.0
	var apart_min: float = INF
	for first: int in points.size():
		var at: Vector3 = base.pad.to_local(points[first].global_position)
		on_pad += 1 if absf(at.x) <= footprint.size.x * 0.5 and absf(at.z) <= footprint.size.z * 0.5 else 0
		facing_min = minf(facing_min, heading.dot(-points[first].global_transform.basis.z))
		for second: int in range(first + 1, points.size()):
			apart_min = minf(apart_min, points[first].global_position.distance_to(points[second].global_position))
	var tag: String = "player_%d" % (index + 1)
	_kit.need(problems, not base.spare_spawn_points.is_empty(), "%s: the Base has no spare spawn point" % tag)
	_kit.need(problems, on_pad == points.size(), "%s: %d of %d spawn points lie on the pad" % [tag, on_pad, points.size()])
	_kit.need(problems, facing_min >= Kit.FACING_DOT_MIN, "%s: a spare spawn point faces another way (dot %.4f)" % [tag, facing_min])
	_kit.need(problems, apart_min > span, "%s: two spawn points are %.2f m apart, not more than the collider's %.2f m" % [tag, apart_min, span])
	_kit.need(problems, base.first_spawn_problem().is_empty(), "%s: first_spawn_problem() says '%s'" % [tag, base.first_spawn_problem()])
	return "%s: %d spare spawn points, %d of %d on the pad, facing dot min %.4f, closest pair %.2f m" % [
		tag, base.spare_spawn_points.size(), on_pad, points.size(), facing_min, apart_min]


## The longest horizontal side of the Unit's box collider, metres, or 0 when it has none.
func _collider_span(unit: Unit) -> float:
	for child: Node in unit.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			return maxf(size.x, size.z)
	return 0.0


## The bit of the physics layer with this name in the project's layer names, or 0 when no layer has it.
func _layer_bit(layer_name: String) -> int:
	for number: int in range(1, 33):
		if String(ProjectSettings.get_setting(LAYER_SETTING % number, "")) == layer_name:
			return 1 << (number - 1)
	return 0


## The BoxShape3D of the first CollisionShape3D child of a zone, or null.
func _box_of(zone: Area3D) -> BoxShape3D:
	for child: Node in zone.get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node.shape as BoxShape3D
	return null
