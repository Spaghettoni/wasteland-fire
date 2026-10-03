extends Node
## Evidence drive harness for Story 001 (the driving toy): runs one named scenario against the
## launch scene and prints machine-readable lines, so the acceptance criteria are backed by a run.
##
## Implements: production/epics/wasteland-fire/story-001-driving-toy.md, Acceptance Criteria and
## Test Evidence. Tooling only: nothing under src/ depends on this file. It couples to src/ by
## instancing driving_toy.tscn and reading the public members of DrivingToy, GreyboxField, Unit and
## ChaseCamera.
##
## Scenarios, chosen with the user argument --scenario=NAME (after the "--"):
##   showcase  About 13 s of varied driving, for the retained screenshot and movie (AC-1, AC-5, AC-8).
##   coast     Throttle for 2 s, release, print the speed every 0.25 s until it is 0 (AC-2).
##   walls     Drive into each of the four walls and each of the four corners, 8 s per target, and
##             steer out of each one the way a Player would (AC-3, AC-6).
##   soak      300 simulated seconds of seeded random input, checked against the field (AC-3, AC-6).
##   fps       Drive a circle for 10 s and print the frame rate each second (AC-7). The first second
##             covers start-up: it counts in fps_avg and fps_min, but the verdict uses the rest.
##
## Driving goes only through Input.action_press and Input.action_release on the Player 1 actions,
## so the Input Map, PlayerDriveInput and the Unit run exactly as they do under a keyboard.
## Time is simulated: scenarios count physics ticks, so the Unit's numbers are the same at any frame
## rate and headless with --fixed-fps 60 runs faster than real time. The camera's numbers are not:
## it follows once per rendered frame, so cam= differs a little between frame rates.
##
## Output, one line per event, values as key=value:
##   DRIVE    t (s), phase, pos (x,y,z m), yaw (degrees, positive is left), speed (the Unit's drive
##            speed in m/s, which stays up while it is pressed against a wall with the throttle still
##            held into it), real (the speed it actually moves at, m/s), cam (x,y,z m)
##   PINNED, VIOLATION, WALLS, FPS, SOAK RESULT    scenario events and verdicts
##   RESULT   always the last line: scenario, ok or fail, then the numbers
## Then get_tree().quit(): exit code 0, or 2 for a missing or unknown scenario.
##
## Every scenario here was written before Story 009, which made a standing Unit turn on the spot
## (UnitStats.spot_turn_rate, in the shipped Motorbike data the driving toy uses): before the toy is
## instanced the harness sets the shared Motorbike stats' spot turn rate to PRE_009_SPOT_TURN_RATE,
## zero, the data the scenarios were measured with, so their numbers stay what they were. Nothing
## else of Story 009 reaches the toy: its Unit never spawns, so it has no tank to burn standing.
##
## Examples:
##   godot --path . --windowed --resolution 1280x720 \
##       res://tools/evidence/drive_harness.tscn -- --scenario=showcase
##   godot --headless --fixed-fps 60 --path . \
##       res://tools/evidence/drive_harness.tscn -- --scenario=soak
## Footage: add --write-movie shots/showcase.png to the first command. Use neither --write-movie
## nor --headless for fps, which measures the real renderer.

## The launch scene under test.
const TOY_SCENE: PackedScene = preload("res://src/gameplay/driving_toy.tscn")

## The driving toy's Motorbike stats: the one resource its Unit uses (one cached object), so a
## value written here before the toy is instanced reaches the Unit.
const MOTORBIKE_STATS_PATH: String = "res://src/gameplay/units/data/motorbike_stats.tres"

## The spot turn rate every scenario here was measured with: none, so a standing Unit did not turn
## (UnitStats.spot_turn_rate, which Story 009 added; the class doc).
const PRE_009_SPOT_TURN_RATE: float = 0.0

## Prefix of the user argument that names the scenario.
const SCENARIO_ARGUMENT: String = "--scenario="

## Printed when the scenario argument is missing or unknown.
const USAGE: String = "usage: drive_harness.tscn -- --scenario=showcase|coast|walls|soak|fps"

## Exit code for a missing or unknown scenario. A scenario that ran always exits 0.
const EXIT_USAGE: int = 2

## Player 1's forward throttle Input Map action (project.godot [input]), pressed and released like
## a key. The three below are the rest of Player 1's layout.
const ACTION_THROTTLE: StringName = &"p1_throttle"
## Player 1's reverse Input Map action.
const ACTION_REVERSE: StringName = &"p1_reverse"
## Player 1's steer-left Input Map action.
const ACTION_STEER_LEFT: StringName = &"p1_steer_left"
## Player 1's steer-right Input Map action.
const ACTION_STEER_RIGHT: StringName = &"p1_steer_right"

## Physics priority of the harness. It runs after PlayerDriveInput (-1) and the Unit (0), so each
## sample shows a finished tick and the keys it sets are read on the next one.
const LATE_PHYSICS_PRIORITY: int = 100

## Half the side of the playfield, metres: the inner faces of the four walls in greybox_field.tscn
## (an 80 x 80 m floor centred on the origin). Keep it in step with that scene.
const FIELD_HALF_EXTENT: float = 40.0

## Height of the floor's top face, metres (greybox_field.tscn).
const FLOOR_Y: float = 0.0

## How far below the floor the Unit's origin may sink before it counts as fallen through, metres.
const FLOOR_TOLERANCE: float = 0.1

## How many VIOLATION lines are printed. Every violation is counted whatever this is.
const MAX_VIOLATION_LINES: int = 10

## Start position for the scenarios that drive a long straight run (showcase and coast). The stock
## start facing north leaves less runway to the north wall than 3 s of full throttle covers at the
## tuned stats, so the showcase turns would run into the north wall and the coast would stop just
## short of it. Starting in the south-west corner region facing north-east gives a diagonal run
## with the turns mid-field.
## Applied by moving the field's player_start marker before the toy enters the tree, so the toy's
## own spawn code (transform, reset_motion, snap_to_target) places the Unit and the camera.
const RUNWAY_START_POSITION: Vector3 = Vector3(-28.0, 0.0, 28.0)
## Start heading for the same runs, degrees, positive turning left from north: -45 faces north-east.
const RUNWAY_START_YAW_DEGREES: float = -45.0

## Interval between DRIVE lines in the showcase, seconds.
const SHOWCASE_REPORT_SECONDS: float = 0.5

## How long the coast scenario holds the throttle before releasing it, seconds.
const COAST_THROTTLE_SECONDS: float = 2.0
## Interval between DRIVE lines in the coast scenario, seconds.
const COAST_REPORT_SECONDS: float = 0.25
## Give up waiting for the Unit to stop this long after the release.
const COAST_TIMEOUT_SECONDS: float = 6.0
## How long the stopped Unit is watched to confirm it stays put.
const COAST_CONFIRM_SECONDS: float = 1.0
## The stop may differ from max_speed / coast_deceleration by this many ticks.
const COAST_TOLERANCE_TICKS: int = 1
## A stopped Unit that moves more than this, metres, was not stopped.
const COAST_STILL_DISTANCE: float = 0.001

## The eight targets in tour order (walls, then the corners between them). Their directions from
## the field centre are in WALL_DIRECTIONS, in the same order.
const WALL_NAMES: Array[StringName] = [
	&"north", &"north_east", &"east", &"south_east", &"south", &"south_west", &"west", &"north_west"]
## Direction of each target from the field centre (x east, z south), in WALL_NAMES order. The face
## point of a target is where its wall or corner is; the Unit aims at a point WALLS_AIM_OVERSHOOT
## beyond it, so it pushes into the wall or corner, and counts as arrived within WALLS_ARRIVE_RADIUS
## of the face point. Keep the overshoot small: a Unit that meets a wall within its stats'
## wall_min_slide_angle_degrees of head-on stops dead, so with a far aim point it would stop
## wherever the bearing to that point drops under that angle, short of the target.
const WALL_DIRECTIONS: Array[Vector2] = [
	Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0),
	Vector2(0.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, 0.0), Vector2(-1.0, -1.0)]
## Time spent on each target, seconds: driving there, then steering out.
const WALLS_SEGMENT_SECONDS: float = 8.0
## How far beyond the face point the Unit aims, metres.
const WALLS_AIM_OVERSHOOT: float = 2.0
## Within this distance of the face point, metres, the target counts as reached.
const WALLS_ARRIVE_RADIUS: float = 4.0
## A Unit touching a wall and moving slower than this, m/s, is blocked and steers to get free.
const WALLS_BLOCKED_SPEED: float = 1.0
## Steering error, degrees, under which the aim needs no correction.
const WALLS_AIM_DEADBAND_DEGREES: float = 3.0
## How long the Unit holds full left steering after being blocked on the way to a target, seconds,
## before it aims again: a Player's committed swing away from the wall. Long enough to turn well
## past parallel to the wall at full turn rate. Re-aiming every tick instead makes the Unit hover
## at the edge of the wall's dead zone and crawl along the wall into a corner.
const WALLS_SWING_SECONDS: float = 1.5
## Once it has reached a target, the Unit must get this far from the face point, metres, within
## ESCAPE_SECONDS, with the throttle down and full steering held, or it is pinned. Five metres is
## past the arrive radius and past any jiggle against the wall or in the corner.
const ESCAPE_DISTANCE: float = 5.0
## How long after reaching a target the escape is judged, seconds. A Unit that turns free at full
## turn rate faces away from the wall in about pi / turn_rate seconds (the stats' turn_rate) and
## drives off at max speed after that. A target reached with less than this left in its segment
## is not judged.
const ESCAPE_SECONDS: float = 3.0

## Length of the soak, simulated seconds.
const SOAK_SECONDS: float = 300.0
## Seed of the soak's random commands, so every run is the same run.
const SOAK_SEED: int = 20260930
## Shortest time a random soak command is held, seconds.
const SOAK_HOLD_MIN_SECONDS: float = 0.3
## Longest time a random soak command is held, seconds.
const SOAK_HOLD_MAX_SECONDS: float = 2.5
## Share of soak commands with the throttle forward. With SOAK_REVERSE_SHARE, the rest coast.
const SOAK_FORWARD_SHARE: float = 0.6
## Share of soak commands with the throttle in reverse.
const SOAK_REVERSE_SHARE: float = 0.25

## Length of the fps scenario's circle, seconds; one FPS sample per second.
const FPS_SECONDS: float = 10.0
## Lowest one-second frame rate that still counts as holding 60 fps: one late frame in a second
## is timer noise.
const FPS_FLOOR: float = 58.0

## One stretch of a scripted scenario: hold these keys for this long.
class PlanStep:
	## Name printed in the DRIVE lines while the step runs.
	var phase: StringName
	## Length in seconds.
	var seconds: float
	## Throttle key held: 1 is W, -1 is S, 0 is neither.
	var throttle: int
	## Steer key held: 1 is A (left), -1 is D (right), 0 is neither.
	var steer: int

	func _init(step_phase: StringName, step_seconds: float, step_throttle: int, step_steer: int) -> void:
		phase = step_phase
		seconds = step_seconds
		throttle = step_throttle
		steer = step_steer


var _scenario: StringName = &""
var _unit: Unit
var _camera: ChaseCamera
var _ticks_per_second: int = 60
## Physics ticks simulated so far. Simulated time is this over _ticks_per_second.
var _tick: int = 0
var _end_tick: int = 0
var _finished: bool = false
var _ok: bool = true
var _phase: StringName = &"start"
var _report_ticks: int = 60
var _drive_lines: bool = true
## The keys held for the next tick: throttle 1 W, -1 S; steer 1 A, -1 D.
var _throttle_key: int = 0
var _steer_key: int = 0

var _plan: Array[PlanStep] = []
var _plan_ends: PackedInt32Array = PackedInt32Array()
var _plan_index: int = 0

var _last_position: Vector3 = Vector3.ZERO
var _distance: float = 0.0
var _speed_max: float = 0.0
var _speed_min: float = 0.0
var _y_min: float = INF
var _y_max: float = -INF
var _tilt_max: float = 0.0
var _wall_contact_ticks: int = 0
var _camera_outside_ticks: int = 0
var _violations: int = 0

var _release_tick: int = -1
var _release_speed: float = 0.0
var _stop_tick: int = -1
var _stop_position: Vector3 = Vector3.ZERO

var _wall_index: int = -1
var _wall_end_tick: int = 0
var _wall_reached_tick: int = -1
var _wall_reached_count: int = 0
## Farthest the Unit got from the current target's face point within ESCAPE_SECONDS of reaching it,
## metres.
var _escape_distance_max: float = 0.0
## Tick until which a swing away from a wall met on the way to the target holds the steering.
var _swing_until_tick: int = -1
var _pinned_count: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _soak_next_change_tick: int = 0

var _fps_samples: Array[float] = []


func _ready() -> void:
	_ticks_per_second = Engine.physics_ticks_per_second
	_scenario = _read_scenario()
	if not _configure():
		# quit() only takes effect after the current frame, so stop the tick from running first.
		_finished = true
		print("RESULT %s fail reason=unknown_scenario %s" % [
			"none" if _scenario.is_empty() else String(_scenario), USAGE])
		get_tree().quit(EXIT_USAGE)
		return
	_apply_pre_009_data()
	var toy: DrivingToy = TOY_SCENE.instantiate() as DrivingToy
	if _scenario == &"showcase" or _scenario == &"coast":
		toy.field.player_start.transform = Transform3D(
			Basis(Vector3.UP, deg_to_rad(RUNWAY_START_YAW_DEGREES)), RUNWAY_START_POSITION)
	add_child(toy)
	_unit = toy.motorbike
	_camera = toy.chase_camera
	process_physics_priority = LATE_PHYSICS_PRIORITY
	_last_position = _unit.global_position
	_decide()
	_apply_keys()
	_print_drive()


## Gives the driving toy's Motorbike the spot turn rate the scenarios were measured with
## (PRE_009_SPOT_TURN_RATE; the class doc), on the shared stats before the toy is instanced. Stats
## that fail to load are an error, and nothing is applied.
func _apply_pre_009_data() -> void:
	var stats: UnitStats = load(MOTORBIKE_STATS_PATH) as UnitStats
	if stats == null:
		push_error("drive_harness: %s did not load as UnitStats, so the pre-009 spot turn rate is not applied." % MOTORBIKE_STATS_PATH)
		return
	stats.spot_turn_rate = PRE_009_SPOT_TURN_RATE


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	_tick += 1
	_observe()
	if _drive_lines and _tick % _report_ticks == 0:
		_print_drive()
	if _decide():
		_conclude()
	else:
		_apply_keys()


## The scenario named by --scenario=NAME among the user arguments, or an empty name.
func _read_scenario() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARGUMENT):
			return StringName(argument.trim_prefix(SCENARIO_ARGUMENT))
	return &""


## Sets up the chosen scenario; false when the name is not one of them.
func _configure() -> bool:
	_phase = _scenario
	_report_ticks = _ticks(1.0)
	match _scenario:
		&"showcase":
			_report_ticks = _ticks(SHOWCASE_REPORT_SECONDS)
			_set_plan([
				PlanStep.new(&"idle", 0.5, 0, 0),
				PlanStep.new(&"throttle", 3.0, 1, 0),
				PlanStep.new(&"throttle_left", 2.5, 1, 1),
				PlanStep.new(&"throttle_right", 2.5, 1, -1),
				PlanStep.new(&"brake", 1.0, -1, 0),
				PlanStep.new(&"reverse", 1.5, -1, 0),
				PlanStep.new(&"coast", 2.0, 0, 0),
			])
		&"coast":
			_report_ticks = _ticks(COAST_REPORT_SECONDS)
			_set_plan([PlanStep.new(&"throttle", COAST_THROTTLE_SECONDS, 1, 0)])
		&"walls":
			_end_tick = _ticks(WALLS_SEGMENT_SECONDS) * WALL_NAMES.size()
		&"soak":
			_end_tick = _ticks(SOAK_SECONDS)
			_rng.seed = SOAK_SEED
			_phase = &"random"
		&"fps":
			_set_plan([PlanStep.new(&"circle", FPS_SECONDS, 1, 1)])
		_:
			return false
	return true


## Whole physics ticks in a time, at least one.
func _ticks(seconds: float) -> int:
	return maxi(1, roundi(seconds * _ticks_per_second))


func _time() -> float:
	return float(_tick) / float(_ticks_per_second)


func _set_plan(steps: Array[PlanStep]) -> void:
	_plan = steps
	var end: int = 0
	for step: PlanStep in steps:
		end += _ticks(step.seconds)
		_plan_ends.append(end)


## Chooses the keys for the next tick and returns true once the scenario is over.
func _decide() -> bool:
	match _scenario:
		&"showcase":
			return _decide_plan()
		&"coast":
			return _decide_coast()
		&"walls":
			return _decide_walls()
		&"soak":
			return _decide_soak()
		&"fps":
			return _decide_fps()
	return true


## Follows the scripted plan; true once it has run out, with every key released.
func _decide_plan() -> bool:
	while _plan_index < _plan.size() and _tick >= _plan_ends[_plan_index]:
		_plan_index += 1
	if _plan_index >= _plan.size():
		_set_keys(0, 0)
		return true
	var step: PlanStep = _plan[_plan_index]
	_phase = step.phase
	_set_keys(step.throttle, step.steer)
	return false


## Throttle per the plan, then release and wait for the Unit to stop and stay stopped.
func _decide_coast() -> bool:
	if not _decide_plan():
		return false
	_phase = &"release"
	if _release_tick < 0:
		_release_tick = _tick
		_release_speed = _unit.current_speed
	if _stop_tick >= 0:
		return _tick - _stop_tick >= _ticks(COAST_CONFIRM_SECONDS)
	if is_zero_approx(_unit.current_speed):
		_stop_tick = _tick
		_stop_position = _unit.global_position
		_drive_lines = false
		if _tick % _report_ticks != 0:
			_print_drive()
	return _tick - _release_tick > _ticks(COAST_TIMEOUT_SECONDS)


## Marks the target reached the first time the Unit is inside WALLS_ARRIVE_RADIUS of its face point,
## and starts a swing away from the wall when the Unit is blocked and no swing is running.
func _track_wall_progress(to_face: float) -> void:
	if _wall_reached_tick < 0 and to_face < WALLS_ARRIVE_RADIUS:
		_wall_reached_tick = _tick
		_wall_reached_count += 1
	var blocked: bool = _unit.is_on_wall() and _unit.get_real_velocity().length() < WALLS_BLOCKED_SPEED
	if blocked and _tick >= _swing_until_tick:
		_swing_until_tick = _tick + _ticks(WALLS_SWING_SECONDS)


## Tours the eight targets. The throttle stays down. The steering aims at the target; once the Unit
## has reached the wall or corner, it holds full left steering for the rest of the segment, as a
## Player does to get away from a wall, and PINNED reports it if that has not taken the Unit
## ESCAPE_DISTANCE from the face point within ESCAPE_SECONDS. Blocked against a wall on the way
## there, it swings left for WALLS_SWING_SECONDS and then aims again.
func _decide_walls() -> bool:
	if _tick >= _wall_end_tick:
		if _wall_index >= 0:
			_print_wall_summary()
		_wall_index += 1
		if _wall_index >= WALL_NAMES.size():
			return true
		_wall_end_tick = _tick + _ticks(WALLS_SEGMENT_SECONDS)
		_wall_reached_tick = -1
		_escape_distance_max = 0.0
		_swing_until_tick = -1
		_phase = WALL_NAMES[_wall_index]
	var direction: Vector2 = WALL_DIRECTIONS[_wall_index]
	var face: Vector3 = Vector3(direction.x, 0.0, direction.y) * FIELD_HALF_EXTENT
	var aim: Vector3 = Vector3(direction.x, 0.0, direction.y) * (FIELD_HALF_EXTENT + WALLS_AIM_OVERSHOOT)
	var to_face: float = _unit.global_position.distance_to(face)
	_track_wall_progress(to_face)
	var steer: int = 1
	if _wall_reached_tick < 0 and _tick >= _swing_until_tick:
		steer = _aim_steer(aim)
	_set_keys(1, steer)
	_watch_escape(to_face)
	return false


## A new random command whenever the last one has run its time; ends after SOAK_SECONDS.
func _decide_soak() -> bool:
	if _tick >= _soak_next_change_tick:
		var roll: float = _rng.randf()
		var throttle: int = 0
		if roll < SOAK_FORWARD_SHARE:
			throttle = 1
		elif roll < SOAK_FORWARD_SHARE + SOAK_REVERSE_SHARE:
			throttle = -1
		_set_keys(throttle, _rng.randi_range(-1, 1))
		_soak_next_change_tick = _tick + _rng.randi_range(
			_ticks(SOAK_HOLD_MIN_SECONDS), _ticks(SOAK_HOLD_MAX_SECONDS))
	return _tick >= _end_tick


## The circle, plus one frame-rate sample per simulated second.
func _decide_fps() -> bool:
	if _tick > 0 and _tick % _ticks_per_second == 0:
		var fps: float = Engine.get_frames_per_second()
		_fps_samples.append(fps)
		print("FPS t=%.3f fps=%.1f" % [_time(), fps])
	return _decide_plan()


## The steer key (1 left, -1 right, 0 none) that turns the Unit toward a point on the ground.
func _aim_steer(point: Vector3) -> int:
	var forward: Vector3 = -_unit.global_transform.basis.z
	var to_point: Vector3 = point - _unit.global_position
	to_point.y = 0.0
	var error: float = forward.signed_angle_to(to_point, Vector3.UP)
	var deadband: float = deg_to_rad(WALLS_AIM_DEADBAND_DEGREES)
	if error > deadband:
		return 1
	if error < -deadband:
		return -1
	return 0


## Prints PINNED once per target when the Unit has not been ESCAPE_DISTANCE from the face point at
## any time in the ESCAPE_SECONDS after reaching it, with the throttle down and full steering held.
## The farthest distance in that window is the escape_far of the WALLS line.
func _watch_escape(to_face: float) -> void:
	if _wall_reached_tick < 0:
		return
	var since: int = _tick - _wall_reached_tick
	if since > _ticks(ESCAPE_SECONDS):
		return
	_escape_distance_max = maxf(_escape_distance_max, to_face)
	if since == _ticks(ESCAPE_SECONDS) and _escape_distance_max < ESCAPE_DISTANCE:
		_pinned_count += 1
		var p: Vector3 = _unit.global_position
		print("PINNED t=%.3f target=%s escape_far=%.3f pos=%.3f,%.3f,%.3f" % [
			_time(), _phase, _escape_distance_max, p.x, p.y, p.z])


func _print_wall_summary() -> void:
	var p: Vector3 = _unit.global_position
	var reached: String = "none"
	if _wall_reached_tick >= 0:
		reached = "%.3f" % (float(_wall_reached_tick) / float(_ticks_per_second))
	print("WALLS target=%s reached_t=%s escape_far=%.3f pinned_total=%d pos=%.3f,%.3f,%.3f" % [
		_phase, reached, _escape_distance_max, _pinned_count, p.x, p.y, p.z])


## Samples the Unit after a tick: the totals for the RESULT line and the field check.
func _observe() -> void:
	var p: Vector3 = _unit.global_position
	_distance += p.distance_to(_last_position)
	_last_position = p
	_speed_max = maxf(_speed_max, _unit.current_speed)
	_speed_min = minf(_speed_min, _unit.current_speed)
	_y_min = minf(_y_min, p.y)
	_y_max = maxf(_y_max, p.y)
	_tilt_max = maxf(_tilt_max, _unit.global_transform.basis.y.angle_to(Vector3.UP))
	if _unit.is_on_wall():
		_wall_contact_ticks += 1
	var c: Vector3 = _camera.global_position
	if absf(c.x) > FIELD_HALF_EXTENT or absf(c.z) > FIELD_HALF_EXTENT:
		_camera_outside_ticks += 1
	var outside: bool = absf(p.x) > FIELD_HALF_EXTENT or absf(p.z) > FIELD_HALF_EXTENT
	var fallen: bool = p.y < FLOOR_Y - FLOOR_TOLERANCE
	if outside or fallen:
		_violations += 1
		if _violations <= MAX_VIOLATION_LINES:
			print("VIOLATION t=%.3f reason=%s pos=%.3f,%.3f,%.3f" % [
				_time(), "outside_field" if outside else "below_floor", p.x, p.y, p.z])


## Yaw in degrees: 0 faces north (-Z), positive turns left.
func _yaw_degrees() -> float:
	var forward: Vector3 = -_unit.global_transform.basis.z
	return rad_to_deg(atan2(-forward.x, -forward.z))


func _print_drive() -> void:
	var p: Vector3 = _unit.global_position
	var c: Vector3 = _camera.global_position
	print("DRIVE t=%.3f phase=%s pos=%.3f,%.3f,%.3f yaw=%.1f speed=%.3f real=%.3f cam=%.3f,%.3f,%.3f" % [
		_time(), _phase, p.x, p.y, p.z, _yaw_degrees(), _unit.current_speed,
		_unit.get_real_velocity().length(), c.x, c.y, c.z])


func _set_keys(throttle: int, steer: int) -> void:
	_throttle_key = throttle
	_steer_key = steer


## Presses or releases the four actions to match the keys. Done every tick, not only on change, so
## a key the engine releases behind the harness's back (a window losing focus, say) is pressed again.
func _apply_keys() -> void:
	_set_action(ACTION_THROTTLE, _throttle_key > 0)
	_set_action(ACTION_REVERSE, _throttle_key < 0)
	_set_action(ACTION_STEER_LEFT, _steer_key > 0)
	_set_action(ACTION_STEER_RIGHT, _steer_key < 0)


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Prints the closing lines and quits. Each scenario's verdict is set in its _conclude function.
func _conclude() -> void:
	_finished = true
	var fields: String = ""
	match _scenario:
		&"showcase":
			fields = _conclude_showcase()
		&"coast":
			fields = _conclude_coast()
		&"walls":
			fields = _conclude_walls()
		&"soak":
			fields = _conclude_soak()
		&"fps":
			fields = _conclude_fps()
	if _violations > 0 or _distance <= 0.0:
		_ok = false
	print("RESULT %s %s t=%.3f ticks=%d %s distance=%.2f speed_max=%.3f speed_min=%.3f "
		% [_scenario, "ok" if _ok else "fail", _time(), _tick, fields, _distance, _speed_max, _speed_min]
		+ "y_min=%.4f y_max=%.4f tilt_max_deg=%.4f wall_ticks=%d camera_outside_ticks=%d violations=%d"
		% [_y_min, _y_max, rad_to_deg(_tilt_max), _wall_contact_ticks, _camera_outside_ticks, _violations])
	_set_keys(0, 0)
	_apply_keys()
	get_tree().quit(0)


## Ok when the keys reached the Unit in both directions.
func _conclude_showcase() -> String:
	_ok = _speed_max > 0.0 and _speed_min < 0.0
	return "end_speed=%.3f" % _unit.current_speed


## Ok when the Unit stopped by coasting, not by a wall, after the release_speed / coast_deceleration
## ticks the stats resource gives, and stayed stopped.
func _conclude_coast() -> String:
	var stopped: bool = _stop_tick >= 0
	var stop_ticks: int = _stop_tick - _release_tick if stopped else -1
	var coast_per_tick: float = _unit.stats.coast_deceleration / float(_ticks_per_second)
	var expected_ticks: int = roundi(_release_speed / coast_per_tick)
	var drift: float = _unit.global_position.distance_to(_stop_position) if stopped else -1.0
	_ok = stopped and _wall_contact_ticks == 0 and drift <= COAST_STILL_DISTANCE \
		and absi(stop_ticks - expected_ticks) <= COAST_TOLERANCE_TICKS
	return "release_speed=%.3f stop_ticks=%d expected_ticks=%d stop_seconds=%.3f drift=%.5f" % [
		_release_speed, stop_ticks, expected_ticks, float(stop_ticks) / float(_ticks_per_second), drift]


## Ok when every wall and corner was reached and the Unit steered clear of each within
## ESCAPE_SECONDS.
func _conclude_walls() -> String:
	_ok = _wall_reached_count == WALL_NAMES.size() and _pinned_count == 0
	return "targets=%d reached=%d pinned=%d" % [WALL_NAMES.size(), _wall_reached_count, _pinned_count]


## Ok when the Unit stayed inside the field and above the floor for the whole run.
func _conclude_soak() -> String:
	if _violations == 0:
		print("SOAK RESULT ok")
	else:
		print("SOAK RESULT violations=%d (the first %d are listed above)" % [_violations, MAX_VIOLATION_LINES])
	return "seed=%d" % SOAK_SEED


## Ok when a real renderer held FPS_FLOOR or better in every one-second sample after the first,
## which covers start-up (window creation, shader compilation) and is reported but not judged.
func _conclude_fps() -> String:
	var total: float = 0.0
	var lowest: float = INF
	var lowest_steady: float = INF
	for index: int in _fps_samples.size():
		var sample: float = _fps_samples[index]
		total += sample
		lowest = minf(lowest, sample)
		if index > 0:
			lowest_steady = minf(lowest_steady, sample)
	var average: float = total / maxf(1.0, float(_fps_samples.size()))
	var display: String = DisplayServer.get_name()
	var window: Vector2i = DisplayServer.window_get_size()
	_ok = display != "headless" and _fps_samples.size() > 1 and lowest_steady >= FPS_FLOOR
	var refresh: float = DisplayServer.screen_get_refresh_rate()
	return "fps_avg=%.1f fps_min=%.1f fps_min_steady=%.1f fps_floor=%.0f " % [
		average, lowest, lowest_steady, FPS_FLOOR] \
		+ "refresh_hz=%.1f window=%dx%d display=%s" % [refresh, window.x, window.y, display]
