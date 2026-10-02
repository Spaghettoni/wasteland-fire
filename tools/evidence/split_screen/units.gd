extends RefCounted
## Scenario units of the split screen evidence harness (split_screen_harness.gd): the four Unit
## types of Story 005 as data and as bodies. Two CHECK lines, every number measured against the
## design's table held in the constants below: unit_data (AC-1, AC-2, AC-9: each entry of
## rules.unit_types, in the data's order, carries the type id, the name and every starting value of
## the table, the Motorbike its 40 hit points, damage 5, 24 m/s and 2.8 rad/s, can_fly for the
## Gyrocopter only, can_carry for the Motorbike only; the Motorbike is the fastest and most agile;
## the rules' shooting height and shot mask) and silhouettes (AC-1, AC-8: Player 1 is put in play
## as each type through the real spawn path, the Motorbike by the runner's first choice and the
## other three by a Self-destruct, the steer-right key and the fire key, and each time its Model
## child exists, every team-colour mesh of it wears the Player's team_material, the scene's own
## meshes are hidden, the collider is the type's box, the HUD bar and line read the type's hit
## points; the four models' bounds differ pairwise). Real key events (Tab, D, Space); the shipped
## data, no legacy override. Tooling only: nothing under src/ depends on this file; the shared
## helpers are check_kit.gd and unit_kit.gd.
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-1, AC-2,
## AC-8 and AC-9; design/rules.md "Units".
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=units

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the signal record, the screens, the waits.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## The display names of the types, in the data's order (design/rules.md "Units").
const DISPLAY_NAMES: Array[String] = ["Motorbike", "Buggy", "Truck", "Gyrocopter"]
## The starting values of the design's table, one row per UnitStats field, the four types' values in
## the data's order as a Vector4: the Motorbike's Story 001 movement and the other three scaled from
## the source, the hit points, the weapon, the controller settings all four share, the layers as
## ints.
const NUMBERS: Dictionary[StringName, Vector4] = {
	&"max_speed": Vector4(24.0, 19.6, 10.9, 16.4),
	&"acceleration": Vector4(20.0, 17.0, 9.0, 15.0),
	&"braking": Vector4(36.0, 32.0, 22.0, 26.0),
	&"coast_deceleration": Vector4(12.0, 10.0, 6.0, 8.0),
	&"reverse_max_speed": Vector4(9.0, 8.0, 5.0, 6.0),
	&"turn_rate": Vector4(2.8, 2.29, 0.89, 1.53),
	&"max_hit_points": Vector4(40.0, 100.0, 220.0, 70.0),
	&"damage": Vector4(5.0, 12.0, 25.0, 15.0),
	&"fire_interval_seconds": Vector4(0.2, 0.4, 0.8, 0.5),
	&"weapon_range": Vector4(25.0, 35.0, 40.0, 35.0),
	&"shot_speed": Vector4(60.0, 60.0, 60.0, 60.0),
	&"muzzle_forward": Vector4(1.6, 2.0, 2.8, 1.6),
	&"ground_snap_length": Vector4(0.1, 0.1, 0.1, 0.1),
	&"wall_min_slide_angle_degrees": Vector4(15.0, 15.0, 15.0, 15.0),
	&"blocked_speed": Vector4(0.5, 0.5, 0.5, 0.5),
	&"collision_layer": Vector4(2.0, 2.0, 2.0, 16.0),
	&"collision_mask": Vector4(35.0, 35.0, 35.0, 1.0),
	&"spot_mask": Vector4(18.0, 18.0, 18.0, 18.0),
}
## The collider box of each type, in the data's order.
const COLLISION_SIZES: Array[Vector3] = [Vector3(1.4, 1.0, 2.6), Vector3(1.8, 1.1, 3.0), Vector3(2.4, 1.6, 4.4), Vector3(1.6, 1.0, 2.4)]
## Where each type's collider box sits, its centre relative to the Unit, in the data's order.
const COLLISION_CENTERS: Array[Vector3] = [Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.55, 0.0), Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.5, 0.0)]
## Which types fly, in the data's order: the Gyrocopter only.
const CAN_FLY: Array[bool] = [false, false, false, true]
## Which types carry, in the data's order: the Motorbike only.
const CAN_CARRY: Array[bool] = [true, false, false, false]
## The Motorbike's tail mount for a carried canister (UnitStats.carry_offset).
const CARRY_OFFSET: Vector3 = Vector3(0.0, 0.5, 1.7)
## The rules' shooting height, metres (MatchRules.shooting_height).
const SHOOTING_HEIGHT: float = 0.5
## The layers that stop a shot: map, units and gyrocopters (MatchRules.shot_collision_mask).
const SHOT_COLLISION_MASK: int = 19
## The node group a model scene puts its team-coloured meshes in (Unit.TEAM_COLOUR_GROUP).
const TEAM_COLOUR_GROUP: StringName = &"team_colour"
## Two models whose bounds agree within this in every component of size and position look the same,
## metres.
const BOUNDS_DIFFERENCE_MIN: float = 0.05

var _harness: Harness
var _kit: Kit
var _units: Units


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	await _kit.advance(Kit.START_TICKS)
	_check_unit_data()
	await _check_silhouettes()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("types=%d spawned=%d destroyed=%d" % [
		_units.controller.unit_types().size(), _units.spawns.size(), _units.destroyed.size()])


## AC-1, AC-2, AC-9: every entry of rules.unit_types against the table, in order; the first type
## the fastest and most agile; both Units in play hold the data's first type; the rules' weapon
## values.
func _check_unit_data() -> void:
	_harness.phase = &"unit_data"
	var problems: PackedStringArray = []
	var rows: PackedStringArray = []
	var types: Array[UnitStats] = _units.controller.unit_types()
	_kit.need(problems, types.size() == Units.TYPE_IDS.size(), "rules.unit_types has %d entries, expected %d" % [types.size(), Units.TYPE_IDS.size()])
	for index: int in mini(types.size(), Units.TYPE_IDS.size()):
		var stats: UnitStats = types[index]
		var label: String = String(Units.TYPE_IDS[index])
		_kit.need(problems, stats.type_id == Units.TYPE_IDS[index] and stats.display_name == DISPLAY_NAMES[index]
			and stats.first_problem().is_empty() and stats.model != null, "%s: type_id, display_name, first_problem() or model is off" % label)
		for field: StringName in NUMBERS:
			var actual: float = float(stats.get(field))
			_kit.need(problems, is_equal_approx(actual, NUMBERS[field][index]), "%s.%s=%s expected %s" % [label, field, actual, NUMBERS[field][index]])
		_kit.need(problems, stats.collision_size.is_equal_approx(COLLISION_SIZES[index]) and stats.collision_center.is_equal_approx(COLLISION_CENTERS[index]),
			"%s: collider %s at %s, expected %s at %s" % [label, stats.collision_size, stats.collision_center, COLLISION_SIZES[index], COLLISION_CENTERS[index]])
		var carries: bool = stats.can_carry == CAN_CARRY[index] and (not stats.can_carry or stats.carry_offset.is_equal_approx(CARRY_OFFSET))
		_kit.need(problems, stats.can_fly == CAN_FLY[index] and carries, "%s: can_fly=%s can_carry=%s is off" % [label, stats.can_fly, stats.can_carry])
		rows.append("%s (%s): hp=%.0f dmg=%.0f speed=%.1f turn=%.2f fire=%.1fs range=%.0f shot=%.0f muzzle=%.1f box=%s fly=%s carry=%s" % [
			stats.display_name, stats.resource_path.get_file(), stats.max_hit_points, stats.damage, stats.max_speed, stats.turn_rate,
			stats.fire_interval_seconds, stats.weapon_range, stats.shot_speed, stats.muzzle_forward, stats.collision_size, stats.can_fly, stats.can_carry])
	var first: UnitStats = types[0] if not types.is_empty() else null
	var fastest: bool = first != null
	for index: int in range(1, types.size()):
		fastest = fastest and first.max_speed > types[index].max_speed and first.turn_rate > types[index].turn_rate
	_kit.need(problems, fastest, "the first type is not the fastest and most agile of the data")
	var rules: MatchRules = _units.controller.rules
	var in_play: bool = first != null and _units.units[0].stats == first and _units.units[1].stats == first
	var weapon_rules: bool = rules.damage_matrix != null and is_equal_approx(rules.shooting_height, SHOOTING_HEIGHT) and rules.shot_collision_mask == SHOT_COLLISION_MASK
	_kit.need(problems, in_play and weapon_rules, "the Units in play do not hold the data's first type, or the rules' weapon values are off")
	_kit.verdict("unit_data", problems, ("%d types in rules.unit_types, %d numbers and the collider of the table checked per type | %s | fastest and most agile: "
		+ "the first type (max_speed %.1f, turn_rate %.2f rad/s)=%s | units in play hold the first type: %s | shooting_height=%.2f shot_collision_mask=%d "
		+ "damage_matrix=%s") % [types.size(), NUMBERS.size(), " | ".join(rows), first.max_speed if first != null else 0.0,
			first.turn_rate if first != null else 0.0, fastest, in_play, rules.shooting_height, rules.shot_collision_mask,
			rules.damage_matrix.resource_path.get_file() if rules.damage_matrix != null else "null"])


## AC-1, AC-8: Player 1 as each type through the real spawn path, read each time it appears; the
## four models' bounds differ pairwise.
func _check_silhouettes() -> void:
	_harness.phase = &"silhouettes"
	var problems: PackedStringArray = []
	var readings: PackedStringArray = []
	var bounds: Array[AABB] = []
	var limit: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	readings.append(_read_silhouette(0, "the runner's first choice", problems, bounds))
	for type_index: int in range(1, Units.TYPE_IDS.size()):
		await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
		var gone: bool = not _units.units[0].is_alive and _units.controller.is_choosing(Harness.PLAYER_1)
		await _kit.press_settled(Kit.KEYS_NEXT_1)
		var cursor: int = _units.panels[0].choice_input.cursor
		await _kit.press_settled(Kit.KEYS_FIRE_1)
		var waited: int = await _units.wait_alive(Harness.PLAYER_1, limit)
		_kit.need(problems, gone and cursor == type_index and waited >= 0,
			"%s: Self-destruct=%s cursor=%d (expected %d) respawn after %d ticks" % [Units.TYPE_IDS[type_index], gone, cursor, type_index, waited])
		await _kit.advance(Kit.TICK_SLACK)
		readings.append(_read_silhouette(type_index, "Tab, D, Space, respawned %d ticks after the choice" % waited, problems, bounds))
	var pairs: PackedStringArray = []
	for first: int in bounds.size():
		for second: int in range(first + 1, bounds.size()):
			var differ: bool = not _same_bounds(bounds[first], bounds[second])
			_kit.need(problems, differ, "the %s and %s models have the same bounds" % [Units.TYPE_IDS[first], Units.TYPE_IDS[second]])
			pairs.append("%s/%s=%s" % [Units.TYPE_IDS[first], Units.TYPE_IDS[second], "differ" if differ else "same"])
	_kit.verdict("silhouettes", problems, " | ".join(readings) + " | bounds pairwise: " + " ".join(pairs))


## Reads Player 1's Unit as the type it should be: alive as that type, its Model child, the scene's
## own meshes hidden, the team-colour meshes painted, the collider, the HUD; files its bounds.
func _read_silhouette(type_index: int, how: String, problems: PackedStringArray, bounds: Array[AABB]) -> String:
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var stats: UnitStats = _units.stats(type_index)
	var model: Node3D = unit.get_node_or_null(^"Model") as Node3D
	var alive_as: bool = unit.is_alive and unit.stats == stats and unit.type_id == Units.TYPE_IDS[type_index]
	var own: int = 0
	var own_hidden: int = 0
	var shape_node: CollisionShape3D = null
	for child: Node in unit.get_children():
		if child is MeshInstance3D:
			own += 1
			own_hidden += 0 if (child as MeshInstance3D).visible else 1
		elif child is CollisionShape3D and shape_node == null:
			shape_node = child as CollisionShape3D
	var painted: int = 0
	var unpainted: int = 0
	if model != null:
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			if node.is_in_group(TEAM_COLOUR_GROUP):
				painted += 1 if (node as MeshInstance3D).material_override == unit.team_material else 0
				unpainted += 0 if (node as MeshInstance3D).material_override == unit.team_material else 1
	var box: BoxShape3D = (shape_node.shape as BoxShape3D) if shape_node != null else null
	var collider: bool = box != null and box.size.is_equal_approx(stats.collision_size) and shape_node.position.is_equal_approx(stats.collision_center)
	var hud: PlayerHud = _units.huds[Harness.PLAYER_1]
	var bar: ProgressBar = hud.find_child("HitPointsBar", true, false) as ProgressBar
	var line: Label = hud.find_child("HitPointsLabel", true, false) as Label
	var hp_text: String = hud.tr(hud.hit_points_format) % [ceili(unit.hit_points), ceili(stats.max_hit_points)]
	var hud_right: bool = is_equal_approx(bar.max_value, stats.max_hit_points) and is_equal_approx(bar.value, unit.hit_points) and line.text == hp_text
	var aabb: AABB = _model_bounds(unit, model)
	bounds.append(aabb)
	_kit.need(problems, alive_as and model != null and own_hidden == own and painted > 0 and unpainted == 0 and unit.team_material != null and collider and hud_right,
		"%s: alive_as=%s model=%s own_hidden=%d/%d painted=%d unpainted=%d collider=%s hud=%s" % [
			Units.TYPE_IDS[type_index], alive_as, model != null, own_hidden, own, painted, unpainted, collider, hud_right])
	return ("%s (%s): alive as %s=%s, Model=%s, own meshes hidden %d/%d, team_colour meshes painted %d (unpainted %d), collider box %s at %s=%s, "
		+ "bounds=(%.2f,%.2f,%.2f %.2fx%.2fx%.2f), HUD bar %.0f/%.0f line=\"%s\"") % [
			Units.TYPE_IDS[type_index], how, stats.display_name, alive_as, model != null, own_hidden, own, painted, unpainted, stats.collision_size,
			stats.collision_center, collider, aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z, bar.value,
			bar.max_value, line.text]


## The box around every mesh of the Unit's Model child, in the Unit's own space; empty without one.
func _model_bounds(unit: Unit, model: Node3D) -> AABB:
	var bounds: AABB = AABB()
	if model == null:
		return bounds
	var into_unit: Transform3D = unit.global_transform.affine_inverse()
	var started: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local: Transform3D = into_unit * mesh.global_transform
		var box: AABB = mesh.mesh.get_aabb()
		for corner: int in 8:
			var offset: Vector3 = Vector3(box.size.x * float(corner & 1), box.size.y * float((corner >> 1) & 1), box.size.z * float((corner >> 2) & 1))
			var point: Vector3 = local * (box.position + offset)
			bounds = bounds.expand(point) if started else AABB(point, Vector3.ZERO)
			started = true
	return bounds


## Whether two bounds agree within BOUNDS_DIFFERENCE_MIN in every component.
func _same_bounds(first: AABB, second: AABB) -> bool:
	var size_gap: Vector3 = (first.size - second.size).abs()
	var place_gap: Vector3 = (first.position - second.position).abs()
	return maxf(size_gap.x, maxf(size_gap.y, size_gap.z)) < BOUNDS_DIFFERENCE_MIN and maxf(place_gap.x, maxf(place_gap.y, place_gap.z)) < BOUNDS_DIFFERENCE_MIN
