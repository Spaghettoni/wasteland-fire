extends RefCounted
## Scenario quick_fixes_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 009 on Map 01 with the shipped data, every drive a real key event. Four
## moments, each held, then read: gyro_over_container (Player 1's Gyrocopter at full speed over the
## west container, its model above it; Player 2's Buggy stopped at the east container's face),
## truck_at_tank (Player 1's Truck stopped at the north-west depot tank; Player 2's Gyrocopter
## stopped at the north-east one), pivot (both standing, turning on the spot, read twice a quarter
## turn apart) and out_of_fuel (Player 1's Motorbike dry with the Self-destruct hint; Player 2's
## Buggy dry with its own). A SPLIT line per moment with frame=, the number of the PNG that shows
## it in a --write-movie recording (the line counts back MOMENT_FRAME_LAG main-loop iterations, as
## tokens_showcase_kit.gd measured), and what the moment's premise reads. No CHECK in a normal run:
## it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named
## premise, so an empty or false recording cannot pass as evidence.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md, Test Evidence (the
## hint in a Player's view, the Gyrocopter over a container, a Unit stopped at a depot tank).
## Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/quick.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=quick_fixes_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The frames show Map 01's own Token stock: nothing here spends a Token.
const USE_MAP_STOCK: bool = true
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The containers, by path from the Map: Player 1's (west) and Player 2's (east).
const CONTAINERS: Array[String] = ["Cover/Containers/ContainerWest", "Cover/Containers/ContainerEast"]
## The north depot tanks, by path from the Map: Player 1's (west) and Player 2's (east).
const TANKS: Array[String] = ["Depot/FuelTanks/FuelTankNorthWest", "Depot/FuelTanks/FuelTankNorthEast"]
## Metres of run-up before a face.
const RUN_UP: float = 15.0
## Ticks a run into a face lasts: the Truck covers RUN_UP in about two seconds.
const RUN_TICKS: int = 160
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 30
## Ticks between the two readings of the pivot: a quarter turn of the Truck's 0.45 rad/s is longer,
## so the Motorbike's 1.4 rad/s sets it, about a quarter turn in 1.1 s.
const PIVOT_TICKS: int = 67
## The share of its tank a dry run's copy of a type spawns with.
const SMALL_TANK: float = 0.005
## How near a held Unit must stand to its tank for the truck_at_tank premise, metres: a reading of
## the frame, looser than depot_tanks' measure of the stop, because a Unit held against the round
## side for the hold can ease a few centimetres round it.
const AT_TANK_TOLERANCE: float = 0.1

var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the four moments, then the premise CHECK (only when one failed) and the RESULT line. The
## runner awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	await _gyro_over_container()
	await _truck_at_tank()
	await _pivot()
	await _out_of_fuel()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_q.close()
	_q.harness.finish("moments=%d %s" % [_moments.size(), _q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(name: String, reads: String) -> void:
	_moments.append(name)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, name, reads])


## Player 1's Gyrocopter crosses its container while Player 2's Buggy drives into its own; read when
## the Gyrocopter's centre is over its container's middle. A coroutine.
func _gyro_over_container() -> void:
	var spots: Array[Vector3] = []
	var types: Array[int] = [Quick.GYROCOPTER, Quick.BUGGY]
	for lane: int in Kit.PLAYERS:
		var face: Vector2 = _q.face_point(CONTAINERS[lane], Vector2(0.0, -1.0))
		var half: float = _q.units.stats(types[lane]).collision_size.z / 2.0
		spots.append(Vector3(face.x, 0.0, face.y - half - RUN_UP))
	await _q.map.stage(types, spots, [Vector3.BACK, Vector3.BACK], true)
	_q.harness.drive(Harness.PLAYER_1, 1, 0)
	_q.harness.drive(Harness.PLAYER_2, 1, 0)
	var middle: float = (_q.map.find(CONTAINERS[0]) as Node3D).global_position.z
	for _tick: int in RUN_TICKS:
		if _q.units.units[0].global_position.z >= middle:
			break
		await _q.kit.tick()
	var over: float = Quick.model_bottom(_q.units.units[0]) - _q.top_of(CONTAINERS[0])
	var buggy: float = _q.units.units[1].current_speed
	_q.harness.drive(Harness.PLAYER_1, 0, 0)
	_line("gyro_over_container", "gyro_model_over_top=%.3f gyro_z=%.2f buggy_speed=%.2f" % [over, _q.units.units[0].global_position.z, buggy])
	_q.kit.need(_problems, over >= 0.0, "gyro_over_container: the model is %.3f m over the container's top" % over)
	await _q.kit.advance(RUN_TICKS)
	_q.harness.release_all()


## Player 1's Truck at its depot tank and Player 2's Gyrocopter at its own, from outside the depot;
## read once both stand there. A coroutine.
func _truck_at_tank() -> void:
	var types: Array[int] = [Quick.TRUCK, Quick.GYROCOPTER]
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for lane: int in Kit.PLAYERS:
		var axis: Vector2 = Quick.ground(_q.map.find(TANKS[lane]) as Node3D)
		var out: Vector2 = axis.normalized()
		var start: Vector2 = axis + out * (_radius(lane) + _q.units.stats(types[lane]).collision_size.z / 2.0 + RUN_UP)
		spots.append(Vector3(start.x, 0.0, start.y))
		facings.append(Vector3(-out.x, 0.0, -out.y))
	await _q.map.stage(types, spots, facings, true)
	_q.harness.drive(Harness.PLAYER_1, 1, 0)
	_q.harness.drive(Harness.PLAYER_2, 1, 0)
	await _q.kit.advance(RUN_TICKS + HOLD_TICKS)
	var reads: PackedStringArray = []
	for lane: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[lane]
		var axis: Vector2 = Quick.ground(_q.map.find(TANKS[lane]) as Node3D)
		var gap: float = Quick.ground(unit).distance_to(axis) - _radius(lane) - unit.stats.collision_size.z / 2.0
		reads.append("p%d_%s_gap=%.3f" % [lane + 1, unit.type_id, gap])
		_q.kit.need(_problems, absf(gap) <= AT_TANK_TOLERANCE, "truck_at_tank: p%d's %s stands %.3f m off the tank" % [lane + 1, unit.type_id, gap])
	_line("truck_at_tank", " ".join(reads))
	_q.harness.release_all()


## The radius of a north tank's collider (its Collider's cylinder), metres.
func _radius(lane: int) -> float:
	var body: Node = (_q.map.find(TANKS[lane]) as Node).get_node("Collider")
	return ((body.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius


## Both standing on the open flat, the steer-left key held: read at the start of the turn and a
## quarter turn of the Motorbike later. A coroutine.
func _pivot() -> void:
	var types: Array[int] = [Quick.MOTORBIKE, Quick.TRUCK]
	await _q.map.stage(types, [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)], [Vector3.RIGHT, Vector3.LEFT], true)
	var starts: Array[Vector2] = [Quick.ground(_q.units.units[0]), Quick.ground(_q.units.units[1])]
	var yaws: Array[float] = [Quick.yaw(_q.units.units[0]), Quick.yaw(_q.units.units[1])]
	_line("pivot_start", "p1_yaw=%.3f p2_yaw=%.3f" % [yaws[0], yaws[1]])
	_q.harness.drive(Harness.PLAYER_1, 0, 1)
	_q.harness.drive(Harness.PLAYER_2, 0, 1)
	await _q.kit.advance(PIVOT_TICKS)
	var reads: PackedStringArray = []
	for lane: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[lane]
		var turned: float = Quick.turned(yaws[lane], Quick.yaw(unit))
		var drift: float = Quick.ground(unit).distance_to(starts[lane])
		reads.append("p%d_%s_turned=%.3f drift=%.4f" % [lane + 1, unit.type_id, turned, drift])
		_q.kit.need(_problems, turned > 0.0 and drift <= 0.001, "pivot: p%d turned %.3f rad and drifted %.4f m" % [lane + 1, turned, drift])
	_line("pivot_quarter_turn", " ".join(reads))
	_q.harness.release_all()


## Both Players' ground Units run dry standing (copies of their stats with a small tank); read once
## both hints show. A coroutine.
func _out_of_fuel() -> void:
	var types: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY]
	for lane: int in Kit.PLAYERS:
		var spot: Vector3 = Quick.LANE_SPOT if lane == 0 else Quick.mirrored(Quick.LANE_SPOT)
		await _q.put(lane, _q.small_tank(types[lane], SMALL_TANK), spot, Vector3.RIGHT if lane == 0 else Vector3.LEFT)
	for _tick: int in 180:
		if _q.units.units[0].is_stranded and _q.units.units[1].is_stranded:
			break
		await _q.kit.tick()
	await _q.kit.advance(HOLD_TICKS)
	var shown: Array[bool] = [_q.hints[0].visible, _q.hints[1].visible]
	_q.kit.need(_problems, shown == [true, true], "out_of_fuel: the hints show %s" % [shown])
	_line("out_of_fuel", "p1_hint=%s '%s' p2_hint=%s '%s'" % [shown[0], _q.hints[0].text, shown[1], _q.hints[1].text])
