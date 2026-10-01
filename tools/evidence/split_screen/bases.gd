extends RefCounted
## Scenario bases of the split screen evidence harness (split_screen_harness.gd): AC-1 of Story 003, two
## greybox Bases, one per Player, told apart by the Player colours, each with a spawn point, and each
## Player's Unit starting the Round on its own Base. Ten CHECK lines, every number measured: where the
## Bases stand and what they are made of, the spawn points, that each spawn point lies on its own Base's
## pad (the field keeps loose start markers that the spawn points are, so nothing else ties a moved Base
## to its spawn), the Units on the spawn points after the start, the zone's physics layers (from the layer
## names in project.godot, never typed here), the spare spawn points a blocked respawn falls back on and the
## report of a Base moved without its spawn point (all in bases_audit.gd, with the layer names), and a drive
## off the Base with W held that must cover what the same drive covers from the corridor (the isolation
## scenario's W-alone phase): the pad is no obstacle.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1 and the layer
## setup its implementation notes ask for; design/game-brief.md MVP feature 3. Tooling only: nothing under
## src/ depends on this file. The start of the Round happens inside add_child() of the launch scene, before
## any scenario runs, so the runner logs its unit_spawned signals (round_start_spawns) for units_on_bases.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=bases

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the spawn tolerances.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")
## The layer and spare spawn point checks (bases_audit.gd).
const Audit: GDScript = preload("res://tools/evidence/split_screen/bases_audit.gd")

## The Player body materials the Bases' colours must match, in Player order.
const PLAYER_MATERIALS: Array[String] = [
	"res://src/gameplay/split_screen/data/player_1_body_material.tres",
	"res://src/gameplay/split_screen/data/player_2_body_material.tres",
]
## Ticks waited before the Units are read, so every tick that could move them has run.
const SETTLE_TICKS: int = 10
## Distance between the two spawn points, metres: Base1 at z = 20 and Base2 at z = -20 (the Map stand-in).
const BASE_SEPARATION: float = 40.0
## How far the separation of the spawn points may differ from BASE_SEPARATION, metres.
const SEPARATION_TOLERANCE: float = 0.01
## How long W is held in each drive, seconds: the hold of the isolation scenario's W-alone phase.
const DRIVE_SECONDS: float = 2.0
## The drive off the Base must cover what the corridor drive covers, within this, metres.
const DRIVE_TOLERANCE: float = 0.001
## A drive that moves the Unit less than this has not driven, metres.
const DRIVE_MIN_DISTANCE: float = 5.0
## The node names of the Base parts that must not be solid (base.tscn): the pad first, then the beacon.
const SOFT_PARTS: Array[String] = ["Pad", "Beacon"]

var _harness: Harness
var _split: SplitScreen
var _bases: Array[Base] = []


## AC-1: reads the launch scene just after the start of the Round and checks it, then drives Player 1
## from its Base and from the corridor. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_split = _harness.split
	_bases.assign([_split.field.player_1_base, _split.field.player_2_base])
	await _harness.advance_ticks(SETTLE_TICKS)
	_harness.print_progress()
	if not _check_bases_exist():
		_harness.finish("reason=no_bases")
		return
	_check_bases_distinct()
	_check_spawn_points()
	_check_spawn_in_pad()
	_check_units_on_bases()
	var audit: Audit = Audit.new(_harness, _bases, [_split.player_1_unit, _split.player_2_unit] as Array[Unit])
	audit.check_zone_layers()
	audit.check_spare_spawns()
	audit.check_spawn_guard()
	var from_base: float = await _drive_distance(&"p1_forward_from_base")
	await _harness.reset_to_corridors()
	var from_corridor: float = await _drive_distance(&"p1_forward_from_corridor")
	_check_no_solid_pad(from_base, from_corridor)
	audit.check_layer_names()
	_harness.finish("base_separation=%.3f drive_from_base=%.3f drive_from_corridor=%.3f" % [
		_spawn(0).origin.distance_to(_spawn(1).origin), from_base, from_corridor])


## The world transform of a Base's spawn point.
func _spawn(index: int) -> Transform3D:
	return _bases[index].spawn_point.global_transform


## AC-1: two Base nodes in the whole tree, the field's two exports are different nodes, and each has
## the spawn point and the zone the later checks read. Returns whether the rest can run.
func _check_bases_exist() -> bool:
	var in_tree: int = 0
	for node: Node in _harness.get_tree().root.find_children("*", "", true, false):
		in_tree += 1 if node is Base else 0
	var detail: PackedStringArray = []
	var complete: bool = true
	for index: int in _bases.size():
		complete = _describe_base(index, detail) and complete
	var distinct: bool = _bases[0] != null and _bases[0] != _bases[1]
	_harness.check("bases_exist", in_tree == 2 and complete and distinct,
		"bases_in_tree=%d (expected 2) exports_distinct=%s | %s" % [in_tree, distinct, " | ".join(detail)])
	return in_tree == 2 and complete and distinct


## Appends what one Base is to detail and returns whether it has the spawn point and the zone.
func _describe_base(index: int, detail: PackedStringArray) -> bool:
	var base: Base = _bases[index]
	if base == null:
		detail.append("player_%d_base=null" % (index + 1))
		return false
	detail.append("player_%d_base=%s at (%.1f, %.1f, %.1f) has_spawn_point=%s has_zone=%s" % [
		index + 1, base.name, base.global_position.x, base.global_position.y, base.global_position.z,
		base.spawn_point != null, base.zone != null])
	return base.spawn_point != null and base.zone != null


## AC-1: each Base carries its Player's colour: its colour material has the albedo of that Player's
## body material (loaded from its .tres), the Pad and the Beacon draw with that material, and the two
## Bases' albedos differ.
func _check_bases_distinct() -> void:
	var passed: bool = true
	var detail: PackedStringArray = []
	var colors: Array[Color] = []
	for index: int in _bases.size():
		passed = _base_color_matches(index, colors, detail) and passed
	var differ: bool = colors.size() == 2 and colors[0] != colors[1]
	_harness.check("bases_distinct", passed and differ, "%s | the two albedos differ=%s" % [" | ".join(detail), differ])


## Judges one Base's colour: its material, the Player's body material and the two meshes. Appends the
## numbers to detail and the Base's albedo to colors, and returns whether all four agree.
func _base_color_matches(index: int, colors: Array[Color], detail: PackedStringArray) -> bool:
	var base: Base = _bases[index]
	var expected: StandardMaterial3D = load(PLAYER_MATERIALS[index]) as StandardMaterial3D
	var own: StandardMaterial3D = base.color_material as StandardMaterial3D
	var pad: MeshInstance3D = base.get_node_or_null(SOFT_PARTS[0]) as MeshInstance3D
	var beacon: MeshInstance3D = base.get_node_or_null(SOFT_PARTS[1]) as MeshInstance3D
	if expected == null or own == null or pad == null or beacon == null:
		detail.append("player_%d: expected_material=%s color_material=%s pad=%s beacon=%s (all must exist)" % [
			index + 1, expected != null, own != null, pad != null, beacon != null])
		return false
	colors.append(own.albedo_color)
	detail.append("player_%d: base albedo=%s, %s albedo=%s, pad_uses_it=%s beacon_uses_it=%s" % [
		index + 1, own.albedo_color, PLAYER_MATERIALS[index].get_file(), expected.albedo_color,
		pad.material_override == own, beacon.material_override == own])
	return own.albedo_color == expected.albedo_color and pad.material_override == own and beacon.material_override == own


## AC-1: the spawn points are BASE_SEPARATION apart and face each other, and the field's two
## read-only start properties are those spawn points.
func _check_spawn_points() -> void:
	var first: Transform3D = _spawn(0)
	var second: Transform3D = _spawn(1)
	var apart: float = first.origin.distance_to(second.origin)
	var toward: Vector3 = (second.origin - first.origin).normalized()
	var dot_1: float = (-first.basis.z).dot(toward)
	var dot_2: float = (-second.basis.z).dot(-toward)
	var field: GreyboxField = _split.field
	var same_1: bool = field.player_start == _bases[0].spawn_point
	var same_2: bool = field.player_2_start == _bases[1].spawn_point
	var passed: bool = absf(apart - BASE_SEPARATION) <= SEPARATION_TOLERANCE \
		and dot_1 >= Kit.FACING_DOT_MIN and dot_2 >= Kit.FACING_DOT_MIN and same_1 and same_2
	_harness.check("spawn_points", passed,
		"apart=%.3f m (expected %.1f +-%.2f) player_1_faces_player_2_dot=%.4f player_2_faces_player_1_dot=%.4f "
		% [apart, BASE_SEPARATION, SEPARATION_TOLERANCE, dot_1, dot_2]
		+ "field.player_start_is_base_1_spawn=%s field.player_2_start_is_base_2_spawn=%s" % [same_1, same_2])


## AC-1: each Base's spawn point lies inside that Base's own pad, the footprint of its Pad mesh. The
## field keeps its loose start markers and each Base's spawn_point points at one (greybox_field.gd), so
## nothing else ties a Base moved in the editor to the place its Units spawn: this does.
func _check_spawn_in_pad() -> void:
	var passed: bool = true
	var detail: PackedStringArray = []
	for index: int in _bases.size():
		var pad: MeshInstance3D = _bases[index].get_node_or_null(SOFT_PARTS[0]) as MeshInstance3D
		var box: BoxMesh = (pad.mesh as BoxMesh) if pad != null else null
		if box == null:
			passed = false
			detail.append("player_%d: no Pad with a box mesh" % (index + 1))
			continue
		var at: Vector3 = pad.to_local(_spawn(index).origin)
		var inside: bool = absf(at.x) <= box.size.x / 2.0 and absf(at.z) <= box.size.z / 2.0
		passed = passed and inside
		detail.append("player_%d: spawn point at (%.2f, %.2f) in the Pad's frame, pad %.1f x %.1f m, inside=%s" % [
			index + 1, at.x, at.z, box.size.x, box.size.z, inside])
	_harness.check("spawn_in_pad", passed, " | ".join(detail))


## AC-1: after the start each Player's Unit stands on its own Base's spawn point, facing its way, the
## MatchController says it is alive, and the start of the Round sent unit_spawned once per Player.
func _check_units_on_bases() -> void:
	var units: Array[Unit] = [_split.player_1_unit, _split.player_2_unit]
	var spawned: Array[int] = [0, 0]
	for player_index: int in _harness.round_start_spawns:
		if player_index >= 0 and player_index < spawned.size():
			spawned[player_index] += 1
	var passed: bool = _harness.round_start_spawns.size() == units.size()
	var detail: PackedStringArray = []
	for index: int in units.size():
		var spawn: Transform3D = _spawn(index)
		var error: float = units[index].global_position.distance_to(spawn.origin)
		var facing_dot: float = (-units[index].global_transform.basis.z).dot(-spawn.basis.z)
		var alive: bool = _split.match_controller.is_alive(index)
		passed = passed and error <= Kit.SPAWN_TOLERANCE and facing_dot >= Kit.FACING_DOT_MIN and alive and spawned[index] == 1
		var other: float = units[index].global_position.distance_to(_spawn(1 - index).origin)
		detail.append(("player_%d base_error=%.4f (max %.2f) facing_dot=%.4f other_base_distance=%.2f alive=%s "
			+ "unit_spawned_at_start=%d") % [index + 1, error, Kit.SPAWN_TOLERANCE, facing_dot, other, alive, spawned[index]])
	_harness.check("units_on_bases", passed, "%s | start-of-Round unit_spawned signals=%d (expected 1 per Player)" % [
		" | ".join(detail), _harness.round_start_spawns.size()])


## Holds W for DRIVE_SECONDS with Player 1 where it stands and returns the distance it covered. The
## keys are released after it.
func _drive_distance(label: StringName) -> float:
	var track: UnitTrack = _harness.tracks[Harness.PLAYER_1]
	track.begin()
	_harness.apply(DriveStep.new(label, DRIVE_SECONDS, Harness.PLAYER_1, 1, 0))
	await _harness.advance(DRIVE_SECONDS)
	var moved: float = track.moved()
	_harness.print_progress()
	_harness.release_all()
	return moved


## AC-1: nothing on the pad or the beacon is a physics body, and Player 1 driving off its Base with W
## covers what it covers from the corridor (the isolation scenario's p1_forward phase), so neither
## the pad nor anything else on the Base slowed or stopped it.
func _check_no_solid_pad(from_base: float, from_corridor: float) -> void:
	var solid: int = 0
	var missing: int = 0
	for base: Base in _bases:
		for part_name: String in SOFT_PARTS:
			var part: Node = base.get_node_or_null(part_name)
			if part == null:
				missing += 1
				continue
			for node: Node in part.find_children("*", "", true, false) + [part]:
				solid += 1 if node is CollisionObject3D else 0
	var equal: bool = absf(from_base - from_corridor) <= DRIVE_TOLERANCE
	_harness.check("no_solid_pad", solid == 0 and missing == 0 and equal and from_corridor >= DRIVE_MIN_DISTANCE,
		"collision objects under Pad and Beacon of both Bases=%d (expected 0) missing_parts=%d | W held %.1f s: "
		% [solid, missing, DRIVE_SECONDS]
		+ "from Base 1=%.3f m, from the corridor=%.3f m, difference=%.6f (max %.3f, and at least %.0f m)"
		% [from_base, from_corridor, absf(from_base - from_corridor), DRIVE_TOLERANCE, DRIVE_MIN_DISTANCE])
