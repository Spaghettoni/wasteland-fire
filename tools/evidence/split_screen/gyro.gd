extends RefCounted
## Scenario gyro of the split screen evidence harness (split_screen_harness.gd): what sets the
## Gyrocopter of Story 005 apart, on the greybox cliff and water stand-ins of split_screen.tscn.
## One CHECK line, gyro_terrain (AC-5), every number measured with real key events (W to drive,
## Space to fire): each of the four types is put down 9 m from the cliff block and driven at it, and
## then 8 m from the water strip and driven at it, for 3 s; the three ground types stop at the near
## face, the Gyrocopter (can_fly in its data) crosses both and stops at the field wall behind them;
## a Gyrocopter and a Buggy driven head-on pass through each other with no wall contact and swap
## sides; and a Truck's shot hits the Gyrocopter standing over the water strip at the shooting
## height, for the Truck's damage times the design's multiplier. The Units are put down as types
## with Unit.spawn(at, stats); the shipped data, no legacy override. Tooling only: nothing under
## src/ depends on this file; the shared helpers are check_kit.gd and unit_kit.gd.
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-5;
## design/rules.md "Units" (the Gyrocopter crosses cliffs and water).
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=gyro

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the typed spawn, the fire key, the hit wait, the shots.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## The Buggy's index into the data.
const BUGGY: int = 1
## The Truck's index into the data.
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## Where the drive at the cliff block starts, facing west. The block of terrain_stand_ins.tscn is 6
## x 4 x 12 m centred at x = -30; the lane z = 0 along x runs through the middle of both stand-ins.
const CLIFF_START: Vector3 = Vector3(-18.0, 0.0, 0.0)
## The cliff block's near face, the one the drive meets, x.
const CLIFF_NEAR_X: float = -27.0
## The cliff block's far face, x.
const CLIFF_FAR_X: float = -33.0
## Where the drive at the water strip starts, facing east. The strip of terrain_stand_ins.tscn is 8
## x 0.4 x 14 m centred at x = 30.
const WATER_START: Vector3 = Vector3(18.0, 0.0, 0.0)
## The water strip's near face, the one the drive meets, x.
const WATER_NEAR_X: float = 26.0
## The water strip's far face, x.
const WATER_FAR_X: float = 34.0
## The inner faces of the field's east and west walls (greybox_field.tscn).
const WALL_X: float = 40.0
## Seconds each drive at a stand-in holds the throttle.
const DRIVE_SECONDS: float = 3.0
## A stopped Unit's origin lies within half its length plus this of the face it stopped at, metres.
const FACE_SLACK: float = 0.5
## The head-on pass: a Gyrocopter from x = -12 and a Buggy from x = 12, each this far from the
## middle, metres.
const HEAD_ON_X: float = 12.0
## The lane z of the head-on pass, clear of the stand-ins and the Base zones.
const HEAD_ON_Z: float = 10.0
## Seconds both Units throttle in the head-on pass.
const HEAD_ON_SECONDS: float = 1.5
## The most their closest approach may be for them to count as passing through each other, metres.
const PASS_SEPARATION_MAX: float = 1.0
## Where the Gyrocopter hovers for the shot over the water: the middle of the strip.
const WATER_HOVER: Vector3 = Vector3(30.0, 0.0, 0.0)
## Where the Truck stands for that shot: 12 m west of the Gyrocopter, facing it.
const WATER_SHOOTER: Vector3 = Vector3(18.0, 0.0, 0.0)
## The design's multiplier of a Truck against a Gyrocopter (design/rules.md, the triangle).
const TRUCK_VS_GYROCOPTER: float = 1.5

var _harness: Harness
var _kit: Kit
var _units: Units


## Runs the scenario. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_kit.on_tick = _units.note_tick
	await _kit.advance(Kit.START_TICKS)
	await _check_gyro_terrain()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("shots=%d destroyed=%d" % [_units.shots.size(), _units.destroyed.size()])


## AC-5: the eight drives at the stand-ins, the head-on pass and the shot over the water.
func _check_gyro_terrain() -> void:
	var problems: PackedStringArray = []
	var rows: PackedStringArray = []
	for type_index: int in Units.TYPE_IDS.size():
		rows.append(await _drive_at(type_index, &"cliff", CLIFF_START, Vector3.LEFT, CLIFF_NEAR_X, CLIFF_FAR_X, -WALL_X, problems))
		rows.append(await _drive_at(type_index, &"water", WATER_START, Vector3.RIGHT, WATER_NEAR_X, WATER_FAR_X, WALL_X, problems))
	rows.append(await _head_on(problems))
	rows.append(await _shot_over_water(problems))
	_kit.verdict("gyro_terrain", problems, " | ".join(rows))


## Player 1 as a type driven from start along facing for DRIVE_SECONDS: a ground type must stop at
## the near face, a flying type (can_fly in its data) cross the far face and stop at the wall.
func _drive_at(type_index: int, label: StringName, start: Vector3, facing: Vector3, near_x: float, far_x: float, wall_x: float, problems: PackedStringArray) -> String:
	_harness.phase = label
	var unit: Unit = _units.units[Harness.PLAYER_1]
	_units.retype(Harness.PLAYER_1, type_index, start, facing)
	await _kit.advance(Units.SETTLE_TICKS)
	var flies: bool = unit.stats.can_fly
	var half: float = unit.stats.collision_size.z / 2.0
	var progress: float = 0.0
	var on_wall: bool = false
	for _tick: int in _harness.ticks_in(DRIVE_SECONDS):
		_harness.drive(Harness.PLAYER_1, 1, 0)
		await _kit.tick()
		progress = maxf(progress, (unit.global_position.x - start.x) * facing.x)
		on_wall = unit.is_on_wall()
	_harness.drive(Harness.PLAYER_1, 0, 0)
	var to_face: float = (near_x - start.x) * facing.x
	var to_far: float = (far_x - start.x) * facing.x
	var to_wall: float = (wall_x - start.x) * facing.x
	var crossed: bool = progress > to_far
	var at_face: bool = progress < to_face and progress > to_face - half - FACE_SLACK
	var at_wall: bool = progress < to_wall and progress > to_wall - half - FACE_SLACK
	var right: bool = (crossed and at_wall) if flies else at_face
	_kit.need(problems, right, "%s at the %s: reached %.2f m (face at %.0f, far face at %.0f, wall at %.0f): crossed=%s at_face=%s at_wall=%s" % [
		Units.TYPE_IDS[type_index], label, progress, to_face, to_far, to_wall, crossed, at_face, at_wall])
	return "%s at the %s (can_fly=%s): drove %.1f s from x=%.0f, farthest x=%.2f (near face x=%.0f, far face x=%.0f, wall x=%.0f): crossed=%s stopped_at_face=%s stopped_at_wall=%s on_wall=%s" % [
		Units.TYPE_IDS[type_index], label, flies, DRIVE_SECONDS, start.x, start.x + progress * facing.x, near_x, far_x, wall_x, crossed, at_face, at_wall, on_wall]


## A Gyrocopter and a Buggy driven at each other: they pass through, touch no wall and swap sides.
func _head_on(problems: PackedStringArray) -> String:
	_harness.phase = &"head_on"
	var gyro: Unit = _units.units[Harness.PLAYER_1]
	var buggy: Unit = _units.units[Harness.PLAYER_2]
	_units.retype(Harness.PLAYER_1, GYROCOPTER, Vector3(-HEAD_ON_X, 0.0, HEAD_ON_Z), Vector3.RIGHT)
	_units.retype(Harness.PLAYER_2, BUGGY, Vector3(HEAD_ON_X, 0.0, HEAD_ON_Z), Vector3.LEFT)
	await _kit.advance(Units.SETTLE_TICKS)
	var closest: float = INF
	var wall_ticks: int = 0
	for _tick: int in _harness.ticks_in(HEAD_ON_SECONDS):
		_harness.drive(Harness.PLAYER_1, 1, 0)
		_harness.drive(Harness.PLAYER_2, 1, 0)
		await _kit.tick()
		closest = minf(closest, gyro.global_position.distance_to(buggy.global_position))
		wall_ticks += (1 if gyro.is_on_wall() else 0) + (1 if buggy.is_on_wall() else 0)
	_harness.release_all()
	var swapped: bool = gyro.global_position.x > buggy.global_position.x
	var passed: bool = closest <= PASS_SEPARATION_MAX and swapped and wall_ticks == 0
	_kit.need(problems, passed, "head-on: closest %.2f m, swapped=%s, wall ticks=%d" % [closest, swapped, wall_ticks])
	return "head-on on z=%.0f: gyrocopter from x=%.0f east and buggy from x=%.0f west for %.1f s: closest %.2f m (at most %.1f), swapped sides=%s (gyrocopter x=%.2f, buggy x=%.2f), ticks touching a wall=%d" % [
		HEAD_ON_Z, -HEAD_ON_X, HEAD_ON_X, HEAD_ON_SECONDS, closest, PASS_SEPARATION_MAX, swapped, gyro.global_position.x, buggy.global_position.x, wall_ticks]


## A Truck fires at the Gyrocopter standing over the water strip: hit at the shooting height for the
## Truck's damage times the multiplier.
func _shot_over_water(problems: PackedStringArray) -> String:
	_harness.phase = &"shot_over_water"
	var truck: Unit = _units.units[Harness.PLAYER_1]
	var gyro: Unit = _units.units[Harness.PLAYER_2]
	_units.retype(Harness.PLAYER_2, GYROCOPTER, WATER_HOVER, Vector3.LEFT)
	_units.retype(Harness.PLAYER_1, TRUCK, WATER_SHOOTER, Vector3.RIGHT)
	await _kit.advance(Units.SETTLE_TICKS)
	var at: Vector3 = gyro.global_position
	var over_water: bool = at.x > WATER_NEAR_X and at.x < WATER_FAR_X and absf(at.y) < FACE_SLACK
	var expected: float = truck.stats.damage * TRUCK_VS_GYROCOPTER
	var index: int = _units.shots.size()
	await _units.hold_fire(Harness.PLAYER_1, 1)
	var taken: float = await _units.wait_hit(Harness.PLAYER_2)
	var end: Vector3 = _units.shot_ends[index] if index < _units.shot_ends.size() else Vector3.INF
	var hit: bool = over_water and is_equal_approx(taken, expected) and gyro.is_alive and end.x > WATER_NEAR_X and is_equal_approx(end.y, _units.controller.rules.shooting_height)
	_kit.need(problems, hit, "shot over the water: gyrocopter at (%.2f, %.2f, %.2f) took %.1f (expected %.1f), the shot ended at (%.2f, %.2f, %.2f)" % [
		at.x, at.y, at.z, taken, expected, end.x, end.y, end.z])
	return "shot over the water: truck at x=%.0f fired at the gyrocopter standing at (%.2f, %.2f, %.2f) over the strip (x %.0f to %.0f): the shot ended at (%.2f, %.2f, %.2f), it took %.1f (expected %.1f = damage %.1f x %.1f), alive=%s" % [
		WATER_SHOOTER.x, at.x, at.y, at.z, WATER_NEAR_X, WATER_FAR_X, end.x, end.y, end.z, taken, expected, truck.stats.damage, TRUCK_VS_GYROCOPTER, gyro.is_alive]
