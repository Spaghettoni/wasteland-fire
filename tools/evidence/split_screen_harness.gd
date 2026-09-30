extends Node
## Evidence harness for Story 002 (split screen for two): runs one named scenario against the
## split screen launch scene and prints machine-readable lines, so the acceptance criteria are
## backed by a run.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria and
## Test Evidence. Tooling only: nothing under src/ depends on this file. It couples to src/ by
## instancing split_screen.tscn and reading the exported members of SplitScreen (the field, both
## Units, both cameras) and the public members of Unit, ChaseCamera and GreyboxField.
##
## Scenarios, chosen with the user argument --scenario=NAME (after the "--"):
##   layout        AC-1, AC-2, AC-5, AC-6: view sizes, one current camera per view, one shared world
##                 and physics space, the world's physics interpolation (Story 001 AC-5's smooth
##                 chase, carried over), start positions, and the eight Input Map actions and keys.
##   isolation     AC-3: six phases, each holding one Player's keys only; only that Player's Unit
##                 moves, and it turns the way the steering convention says.
##   simultaneous  AC-4: both layouts held at once; Player 1's Unit does what it does alone.
##   showcase      About 11 s of two-Player driving with no collision, for the retained screenshots.
##   fps           AC-7: both Players circling for 10 s; frame rate and draw calls, no verdict.
##
## The driving keys' codes appear in this file and in the Input Map of project.godot; the ghosting
## tool names only Esc, to quit, and nothing under src/ names a key. The harness plays the keyboard: every drive command is a real InputEventKey
## pushed through Input.parse_input_event with the physical keycode of the key (W A S D for
## Player 1, the arrow keys for Player 2), so the Input Map bindings of AC-3 and AC-5,
## PlayerDriveInput and the Unit run exactly as under a real keyboard. Gameplay code names
## actions, never keys; the harness has to name keys because keys are what it presses. It never
## calls set_drive_input() and never reads an Input action itself.
##
## Injected events carry device InputEvent.DEVICE_ID_KEYBOARD (16), the id Godot 4.7 gives a real
## keyboard. Nothing here or in src/ compares a device with 0 (AC-6). The Input Map check asserts
## that every p1_ and p2_ event is bound to any device (ANY_DEVICE, -1), so a binding pinned to one
## device fails it, including a stored device 0, which 4.7 loads as 16. Input.use_accumulated_input
## is turned off, so an injected event takes effect at once; with the default the Input singleton
## holds it until the next frame, which would put a press up to a tick late. Both were measured on
## 4.7.2; the Story 002 evidence doc keeps the runs.
##
## Time is simulated: scenarios await the physics_frame signal and count ticks, so the Units'
## numbers are the same at any frame rate and headless with --fixed-fps 60 runs faster than real
## time. The continuation after physics_frame runs before the nodes' _physics_process of that tick
## (measured on 4.7.2; the Story 002 evidence doc keeps the run), so a key pressed there reaches
## PlayerDriveInput in the same tick, and what is read there is the finished previous tick.
##
## Start positions. layout and showcase use the field's markers, the real spawn. isolation and
## simultaneous teleport the Units into two corridors instead (Player 1 at x = -10, Player 2 at
## x = +10, 40 m apart along z, facing each other's end of the field): from the markers the
## straight phases would drive one Unit into the other (33.6 m in the 2.0 s hold plus a 22.5 m
## coast, against 40 m between the markers), and the Units do collide (layers 2, mask 3). The
## teleport is the public API in the order a spawn uses: transform, reset_motion(), snap_to_target().
##
## Output, one line per event, values as key=value:
##   SPLIT   <scenario> t=<seconds> ...   progress. yaw is the turn since the phase began, degrees,
##           positive is left; speed is the Unit's drive speed in m/s; x and z are in metres
##   CHECK   <scenario> <check name> PASS|FAIL <detail with the measured numbers>
##   RESULT  <scenario> ok|fail checks=<n> failed=<n> key=value ...   exactly one, always last
## Then get_tree().quit(): exit code 0 when every check passed, 1 when one failed, 2 for a missing
## or unknown scenario.
##
## Examples:
##   godot --headless --fixed-fps 60 --path . \
##       res://tools/evidence/split_screen_harness.tscn -- --scenario=isolation
##   godot --path . --windowed --resolution 1280x720 --write-movie shots/split.png --quit-after 700 \
##       res://tools/evidence/split_screen_harness.tscn -- --scenario=showcase
## Use neither --write-movie nor --headless for fps, which measures the real renderer. Quote
## fps_avg_steady, not fps_avg: the first sample covers start-up. The display caps the rate: on the
## dev Mac (Apple M4 Pro, Metal, macOS 26.5.2, a 120 Hz display) a windowed run stays at 120 fps
## with --disable-vsync too (fps_avg_steady 120.1, against 120.0 with vsync on), so headroom over
## 60 fps cannot be measured there; the frame rate and the draw-call totals are what the run gives.
##
## Known debt (TD-003 in docs/tech-debt-register.md): the five scenarios and their constants share
## this one script, which has grown long. It is coroutine-based with a few run-wide counters, not
## the per-scenario timeline state of drive_harness.gd (TD-001), and it is kept whole to get
## unattended evidence for Story 002 in one pass. Split it into one RefCounted per scenario when
## Story 003 adds Bases.

## The launch scene under test.
const SPLIT_SCENE: PackedScene = preload("res://src/gameplay/split_screen/split_screen.tscn")

## Prefix of the user argument that names the scenario.
const SCENARIO_ARGUMENT: String = "--scenario="

## The scenarios, in the order of the header.
const SCENARIO_NAMES: Array[StringName] = [&"layout", &"isolation", &"simultaneous", &"showcase", &"fps"]

## Printed when the scenario argument is missing or unknown.
const USAGE: String = "usage: split_screen_harness.tscn -- --scenario=layout|isolation|simultaneous|showcase|fps"

## Exit code when a check failed.
const EXIT_FAILED: int = 1

## Exit code for a missing or unknown scenario.
const EXIT_USAGE: int = 2

## A scenario still running after this many simulated seconds has hung (a script error stops a
## coroutine without a word): the watchdog prints a failing RESULT and quits.
const WATCHDOG_SECONDS: float = 120.0

## Player indexes, into the tracks and the layouts. BOTH is only used by DriveStep.
const PLAYER_1: int = 0
## Player 2's index, into the tracks and the layouts.
const PLAYER_2: int = 1
## Stands for both Players in a DriveStep: both layouts are held at once.
const BOTH: int = -1

## Physical keys of Player 1's layout, in the order of SLOT_*: the p1_ Input Map actions
## (project.godot [input]) are bound to these.
const PLAYER_1_KEYS: Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
## Physical keys of Player 2's layout, in the order of SLOT_*: the p2_ Input Map actions are bound
## to these.
const PLAYER_2_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

## Position of the throttle action in a layout, and of "throttle" in ACTION_SUFFIXES.
const SLOT_THROTTLE: int = 0
## Position of the reverse action in a layout.
const SLOT_REVERSE: int = 1
## Position of the steer-left action in a layout.
const SLOT_STEER_LEFT: int = 2
## Position of the steer-right action in a layout.
const SLOT_STEER_RIGHT: int = 3
## The first part of an Input Map action name, one per Player: prefix + suffix.
const ACTION_PREFIXES: Array[String] = ["p1_", "p2_"]
## The last part of an Input Map action name, one per slot: prefix + suffix.
const ACTION_SUFFIXES: Array[String] = ["throttle", "reverse", "steer_left", "steer_right"]

## The steering convention the isolation checks derive their expected signs from (unit.gd,
## _yaw_rate): steer is +1 for left, and the turn reverses while rolling backward.
const YAW_RULE: String = "yaw rate = steer(+1 left) * turn_rate * |speed|/max_speed * sign(speed)"

## Window size AC-1 asks for, pixels. A headless run has no real window (it starts at 64 x 64), so
## there the harness sets the window to this size before it looks.
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## The size AC-1 asks of each Player's view, pixels: half the window wide, as tall as the window.
const VIEW_SIZE: Vector2i = Vector2i(640, 720)
## Device id of an Input Map event bound to every device (the editor's All Devices), which is what
## project.godot stores for all eight actions. 4.7 loads a stored device 0 as DEVICE_ID_KEYBOARD
## (16), so an event pinned to one device never equals this.
const ANY_DEVICE: int = -1

## Frames the layout scenario waits before reading sizes: they are valid from the first frame.
const LAYOUT_SETTLE_TICKS: int = 10

## The project setting that turns physics interpolation on for the whole game (project.godot).
const PHYSICS_INTERPOLATION_SETTING: String = "physics/common/physics_interpolation"

## A Unit on its marker is within this distance of it, metres.
const START_TOLERANCE: float = 0.05
## A Unit on its marker faces the marker's way: the dot product of the two facings is at least this.
const START_FACING_DOT: float = 0.999

## The two Units must start at least this far apart, metres.
const MIN_APART: float = 1.0

## Corridor starts (isolation, simultaneous), metres. Player 1 faces -Z, Player 2 faces +Z.
const CORRIDOR_1_START: Vector3 = Vector3(-10.0, 0.0, 20.0)
## Player 2's corridor start, metres (see CORRIDOR_1_START).
const CORRIDOR_2_START: Vector3 = Vector3(10.0, 0.0, -20.0)

## Ticks each reset waits, with every key up, before the tracks start counting.
const SETTLE_TICKS: int = 5

## How long an isolation phase holds its keys, seconds.
const ISOLATION_HOLD_SECONDS: float = 2.0
## How long an isolation phase then leaves them released, seconds.
const ISOLATION_RELEASE_SECONDS: float = 1.5

## A driven Unit going forward must move more than this, metres.
const MOVE_MIN_DISTANCE: float = 5.0
## A Unit that must stand still moves less than this, metres.
const STILL_DISTANCE: float = 0.001
## A Unit that must stand still turns less than this, radians.
const STILL_YAW: float = 0.001
## A turning Unit must turn at least this much, radians.
const MIN_TURN: float = 0.5

## Length of the straight stretch of the simultaneous scenario, seconds.
const SIM_STRAIGHT_SECONDS: float = 2.0
## Length of its steering stretch, seconds.
const SIM_STEER_SECONDS: float = 1.0
## Interval between its progress lines, seconds.
const SIM_REPORT_SECONDS: float = 0.25
## The share of max_speed both Units must reach.
const SIM_TOP_SPEED_SHARE: float = 0.9
## How closely Player 1's distance must match its solo run, metres.
const SIM_DISTANCE_TOLERANCE: float = 0.05
## How closely Player 1's yaw must match its solo run, radians.
const SIM_YAW_TOLERANCE: float = 0.02

## Interval between progress lines in the showcase, seconds.
const SHOWCASE_REPORT_SECONDS: float = 1.0

## The showcase choreography, both Players giving the same commands: label, seconds, throttle (1
## forward, -1 reverse), steer (1 left, -1 right). Idle at the markers, throttle, a gentle S-shaped
## pass (right, then left), a U-turn, a second pass, a weave, then brake, reverse, coast and rest.
## The same commands make the two paths mirror images through the centre of the field, so the Units
## can meet only there; the RESULT line reports the closest approach and the least wall clearance.
const SHOWCASE_PLAN: Array[Array] = [
	[&"idle", 0.5, 0, 0],
	[&"throttle", 1.0, 1, 0],
	[&"pass_right", 0.25, 1, -1],
	[&"pass_left", 0.25, 1, 1],
	[&"straight", 0.5, 1, 0],
	[&"u_turn_left", 1.1, 1, 1],
	[&"second_pass", 1.0, 1, 0],
	[&"weave_left", 0.4, 1, 1],
	[&"weave_right", 0.4, 1, -1],
	[&"brake", 0.7, -1, 0],
	[&"reverse", 1.5, -1, 0],
	[&"coast", 2.5, 0, 0],
	[&"rest", 0.6, 0, 0],
]

## Length of the fps scenario in seconds; one sample per second.
const FPS_SECONDS: int = 10

## Half the side of the playfield, metres (the inner faces of the four walls, greybox_field.tscn).
const FIELD_HALF_EXTENT: float = 40.0


## One stretch of a scripted scenario: hold these keys for this long. The step gives the whole key
## state: the Player it names holds the throttle and steer keys, everyone else has every key up.
class DriveStep:
	## Name printed in the SPLIT lines and used in check names.
	var label: StringName
	## Length in seconds.
	var seconds: float
	## PLAYER_1, PLAYER_2, or BOTH (-1): whose keys are held.
	var player: int
	## Throttle key held: 1 is W or Up, -1 is S or Down, 0 is neither.
	var throttle: int
	## Steer key held: 1 is A or Left, -1 is D or Right, 0 is neither.
	var steer: int

	func _init(step_label: StringName, step_seconds: float, step_player: int, step_throttle: int, step_steer: int) -> void:
		label = step_label
		seconds = step_seconds
		player = step_player
		throttle = step_throttle
		steer = step_steer


## Follows one Unit through a phase: where it started, how far it is from there, how far it has
## turned and the top speed it reached. Yaw is summed tick by tick, so a turn of more than half a
## circle does not wrap.
class UnitTrack:
	## The Unit followed.
	var unit: Unit
	## Where the phase began.
	var start: Vector3 = Vector3.ZERO
	## Turn since the phase began, radians, positive is left.
	var yaw_total: float = 0.0
	## Highest drive speed since the phase began, m/s.
	var speed_max: float = 0.0
	var _last_yaw: float = 0.0

	func _init(tracked: Unit) -> void:
		unit = tracked
		begin()

	## Starts a new phase from the Unit's present place and heading.
	func begin() -> void:
		start = unit.global_position
		yaw_total = 0.0
		speed_max = 0.0
		_last_yaw = heading()

	## Adds the tick that just finished.
	func update() -> void:
		var yaw: float = heading()
		yaw_total += angle_difference(_last_yaw, yaw)
		_last_yaw = yaw
		speed_max = maxf(speed_max, unit.current_speed)

	## Straight-line distance from where the phase began, metres.
	func moved() -> float:
		return start.distance_to(unit.global_position)

	## Heading in radians: 0 faces -Z, positive turns left. The Unit's basis z axis is (sin, 0, cos)
	## of its yaw.
	func heading() -> float:
		var back: Vector3 = unit.global_transform.basis.z
		return atan2(back.x, back.z)


var _scenario: StringName = &""
var _split: SplitScreen
var _tracks: Array[UnitTrack] = []
## Which physical keys the harness holds down now, so an event is sent only on a change.
var _held: Dictionary[int, bool] = {}
var _ticks_per_second: int = 60
## Physics ticks simulated so far. Simulated time is this over _ticks_per_second.
var _ticks: int = 0
var _phase: StringName = &"start"
## Ticks between SPLIT progress lines; 0 prints none.
var _report_ticks: int = 0
var _checks: int = 0
var _failed: int = 0
var _finished: bool = false
## Closest the two Units' origins came, metres, and the least room any origin left to a wall.
var _separation_min: float = INF
var _wall_clearance_min: float = INF


func _ready() -> void:
	_ticks_per_second = Engine.physics_ticks_per_second
	_scenario = _read_scenario()
	if not SCENARIO_NAMES.has(_scenario):
		# quit() only takes effect after the current frame, so nothing else may run first.
		_finished = true
		print("RESULT %s fail checks=0 failed=0 reason=unknown_scenario %s" % [
			"none" if _scenario.is_empty() else String(_scenario), USAGE])
		get_tree().quit(EXIT_USAGE)
		return
	Input.use_accumulated_input = false
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	_split = SPLIT_SCENE.instantiate() as SplitScreen
	add_child(_split)
	_run()


## Runs the chosen scenario as a coroutine: after the first frame, so the window and the layout
## exist, then straight-line code that awaits physics ticks.
func _run() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		get_window().size = WINDOW_SIZE
	_tracks.append(UnitTrack.new(_split.player_1_unit))
	_tracks.append(UnitTrack.new(_split.player_2_unit))
	match _scenario:
		&"layout":
			await _scenario_layout()
		&"isolation":
			await _scenario_isolation()
		&"simultaneous":
			await _scenario_simultaneous()
		&"showcase":
			await _scenario_showcase()
		&"fps":
			await _scenario_fps()


## The scenario named by --scenario=NAME among the user arguments, or an empty name.
func _read_scenario() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARGUMENT):
			return StringName(argument.trim_prefix(SCENARIO_ARGUMENT))
	return &""


## Whole physics ticks in a time, at least one.
func _ticks_in(seconds: float) -> int:
	return maxi(1, roundi(seconds * _ticks_per_second))


## Simulated seconds since the scenario began.
func _time() -> float:
	return float(_ticks) / float(_ticks_per_second)


## Waits the given number of physics ticks, sampling both Units after each one.
func _advance_ticks(count: int) -> void:
	for _tick: int in count:
		await get_tree().physics_frame
		_ticks += 1
		_sample()


## Waits the given simulated seconds.
func _advance(seconds: float) -> void:
	await _advance_ticks(_ticks_in(seconds))


## Updates both tracks and the run-wide minimums after a tick, and prints a progress line when one
## is due.
func _sample() -> void:
	for track: UnitTrack in _tracks:
		track.update()
		var at: Vector3 = track.unit.global_position
		_wall_clearance_min = minf(_wall_clearance_min, FIELD_HALF_EXTENT - maxf(absf(at.x), absf(at.z)))
	_separation_min = minf(_separation_min,
		_tracks[PLAYER_1].unit.global_position.distance_to(_tracks[PLAYER_2].unit.global_position))
	if _report_ticks > 0 and _ticks % _report_ticks == 0:
		_print_progress()


## One SPLIT line with both Units' place, drive speed and turn since the phase began.
func _print_progress() -> void:
	var first: UnitTrack = _tracks[PLAYER_1]
	var second: UnitTrack = _tracks[PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s p1_x=%.2f p1_z=%.2f p1_speed=%.2f p1_yaw=%.1f "
		% [_scenario, _time(), _phase, first.unit.global_position.x, first.unit.global_position.z,
			first.unit.current_speed, rad_to_deg(first.yaw_total)]
		+ "p2_x=%.2f p2_z=%.2f p2_speed=%.2f p2_yaw=%.1f"
		% [second.unit.global_position.x, second.unit.global_position.z,
			second.unit.current_speed, rad_to_deg(second.yaw_total)])


## Presses or releases one physical key by pushing a real key event through the Input singleton,
## the way the OS does. Sends nothing when the key is already in that state.
func _set_key(key: Key, pressed: bool) -> void:
	if _held.get(key, false) == pressed:
		return
	_held[key] = pressed
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	Input.parse_input_event(event)


## Holds one Player's throttle and steer keys: throttle 1 forward, -1 reverse; steer 1 left, -1
## right; 0 releases the pair.
func _drive(player: int, throttle: int, steer: int) -> void:
	var keys: Array[Key] = PLAYER_1_KEYS if player == PLAYER_1 else PLAYER_2_KEYS
	_set_key(keys[SLOT_THROTTLE], throttle > 0)
	_set_key(keys[SLOT_REVERSE], throttle < 0)
	_set_key(keys[SLOT_STEER_LEFT], steer > 0)
	_set_key(keys[SLOT_STEER_RIGHT], steer < 0)


## Sets the whole key state of a step: its Player (or both) holds the step's keys, the other has
## every key up.
func _apply(step: DriveStep) -> void:
	_phase = step.label
	for player: int in [PLAYER_1, PLAYER_2]:
		if step.player == BOTH or step.player == player:
			_drive(player, step.throttle, step.steer)
		else:
			_drive(player, 0, 0)


## Releases every key of both layouts.
func _release_all() -> void:
	_drive(PLAYER_1, 0, 0)
	_drive(PLAYER_2, 0, 0)


## Holds the step's keys for its length.
func _run_step(step: DriveStep) -> void:
	_apply(step)
	await _advance(step.seconds)


## Teleports a Unit and snaps its camera, in the order a spawn uses: transform first, then
## reset_motion(), then snap_to_target().
func _place(unit: Unit, where: Transform3D, camera: ChaseCamera) -> void:
	unit.global_transform = where
	unit.reset_motion()
	camera.snap_to_target()


## The corridor start of a Player: x = -10 facing -Z for Player 1, x = +10 facing +Z for Player 2.
func _corridor_transform(player: int) -> Transform3D:
	if player == PLAYER_1:
		return Transform3D(Basis.IDENTITY, CORRIDOR_1_START)
	return Transform3D(Basis(Vector3.UP, PI), CORRIDOR_2_START)


## A reset of both Units to their corridors with every key up: teleport, wait SETTLE_TICKS,
## then start both tracks from where the Units stand.
func _reset_to_corridors() -> void:
	_release_all()
	_place(_split.player_1_unit, _corridor_transform(PLAYER_1), _split.player_1_camera)
	_place(_split.player_2_unit, _corridor_transform(PLAYER_2), _split.player_2_camera)
	await _advance_ticks(SETTLE_TICKS)
	for track: UnitTrack in _tracks:
		track.begin()


## Prints one CHECK line and counts it.
func _check(check_name: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failed += 1
	print("CHECK %s %s %s %s" % [_scenario, check_name, "PASS" if passed else "FAIL", detail])


## Prints the one RESULT line, releases the keys and quits: exit code 0 when no check failed, 1
## otherwise. The fields are the scenario's own key=value numbers.
func _finish(fields: String) -> void:
	if _finished:
		return
	_finished = true
	_release_all()
	var line: String = "RESULT %s %s checks=%d failed=%d t=%.3f" % [
		_scenario, "ok" if _failed == 0 else "fail", _checks, _failed, _time()]
	if not fields.is_empty():
		line += " " + fields
	print(line)
	get_tree().quit(0 if _failed == 0 else EXIT_FAILED)


## Fires when the scenario has not finished in WATCHDOG_SECONDS: a hung coroutine fails loudly.
func _on_watchdog() -> void:
	if _finished:
		return
	_check("watchdog", false, "the scenario did not finish within %.0f simulated seconds" % WATCHDOG_SECONDS)
	_finish("reason=watchdog")


## AC-1, AC-2, AC-5, AC-6: reads the launch scene as it stands LAYOUT_SETTLE_TICKS ticks after it
## started. Nothing is driven.
func _scenario_layout() -> void:
	await _advance_ticks(LAYOUT_SETTLE_TICKS)
	var window: Window = get_window()
	var visible: Vector2 = get_viewport().get_visible_rect().size
	print("SPLIT layout t=%.3f window=%dx%d content_scale_size=%dx%d visible_rect=%dx%d display=%s" % [
		_time(), window.size.x, window.size.y, window.content_scale_size.x, window.content_scale_size.y,
		int(visible.x), int(visible.y), DisplayServer.get_name()])
	_check_view_sizes()
	_check_current_cameras()
	_check_camera_targets()
	_check_node_counts()
	_check_shared_world()
	_check_shared_physics_space()
	_check_world_interpolation()
	_check_start_positions()
	_check_input_map()
	_finish("window=%dx%d" % [window.size.x, window.size.y])


## The SubViewport a camera sits in, or null when it is in the window's own viewport.
func _view_of(camera: ChaseCamera) -> SubViewport:
	return camera.get_viewport() as SubViewport


## A node's name, or "null" for a missing node, for check details.
func _name_of(node: Node) -> String:
	return String(node.name) if node != null else "null"


## An object's instance id, or 0 for a missing object, for check details.
func _id_of(object: Object) -> int:
	return object.get_instance_id() if object != null else 0


## The Camera3D a SubViewport draws with, or null for a missing view.
func _camera_in(view: SubViewport) -> Camera3D:
	if view == null:
		return null
	return view.get_camera_3d()


## Every Camera3D in the tree that is current.
func _current_cameras() -> Array[Camera3D]:
	var current: Array[Camera3D] = []
	for node: Node in get_tree().root.find_children("*", "Camera3D", true, false):
		var camera: Camera3D = node as Camera3D
		if camera.current:
			current.append(camera)
	return current


## AC-1: each Player's view is a SubViewportContainer of exactly VIEW_SIZE holding a SubViewport of
## VIEW_SIZE, side by side from x = 0.
func _check_view_sizes() -> void:
	var passed: bool = true
	var detail: PackedStringArray = []
	var cameras: Array[ChaseCamera] = [_split.player_1_camera, _split.player_2_camera]
	for index: int in cameras.size():
		var view: SubViewport = _view_of(cameras[index])
		var container: SubViewportContainer = null
		if view != null:
			container = view.get_parent() as SubViewportContainer
		if container == null:
			passed = false
			detail.append("player_%d has no SubViewport in a SubViewportContainer" % (index + 1))
			continue
		var expected_x: float = float(index * VIEW_SIZE.x)
		var fits: bool = Vector2i(container.size) == VIEW_SIZE and view.size == VIEW_SIZE \
			and is_equal_approx(container.global_position.x, expected_x) \
			and is_zero_approx(container.global_position.y)
		passed = passed and fits
		detail.append("player_%d container=%dx%d at x=%.0f viewport=%dx%d expected=%dx%d at x=%.0f" % [
			index + 1, int(container.size.x), int(container.size.y), container.global_position.x,
			view.size.x, view.size.y, VIEW_SIZE.x, VIEW_SIZE.y, expected_x])
	_check("view_sizes", passed, " | ".join(detail))


## AC-1: exactly two current Camera3D nodes, one in each SubViewport, none in the window's own
## viewport.
func _check_current_cameras() -> void:
	var current: Array[Camera3D] = _current_cameras()
	var view_1: SubViewport = _view_of(_split.player_1_camera)
	var view_2: SubViewport = _view_of(_split.player_2_camera)
	var in_view_1: Camera3D = _camera_in(view_1)
	var in_view_2: Camera3D = _camera_in(view_2)
	var in_root: Camera3D = get_viewport().get_camera_3d()
	var views_ok: bool = view_1 != null and view_2 != null and view_1 != view_2
	var cameras_match: bool = in_view_1 == _split.player_1_camera and in_view_2 == _split.player_2_camera
	var only_these: bool = current.size() == 2 and current.has(_split.player_1_camera) \
		and current.has(_split.player_2_camera)
	_check("one_current_camera_per_view", views_ok and cameras_match and only_these and in_root == null,
		"current_cameras=%d player_1_view_camera=%s player_2_view_camera=%s root_viewport_camera=%s"
		% [current.size(), _name_of(in_view_1), _name_of(in_view_2), _name_of(in_root)])


## AC-1: each ChaseCamera follows its own Player's Unit.
func _check_camera_targets() -> void:
	var passed: bool = _split.player_1_camera.target == _split.player_1_unit \
		and _split.player_2_camera.target == _split.player_2_unit
	_check("camera_targets", passed, "player_1_camera->%s (expected %s) player_2_camera->%s (expected %s)" % [
		_name_of(_split.player_1_camera.target), _name_of(_split.player_1_unit),
		_name_of(_split.player_2_camera.target), _name_of(_split.player_2_unit)])


## AC-2: two Motorbikes and one field in the whole tree, not two copies of the scene.
func _check_node_counts() -> void:
	var units: int = 0
	var fields: int = 0
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if node is Unit:
			units += 1
		elif node is GreyboxField:
			fields += 1
	_check("node_counts", units == 2 and fields == 1,
		"units=%d (expected 2) greybox_fields=%d (expected 1)" % [units, fields])


## AC-2: both SubViewports render the window's own World3D (one object, neither sets a world of its
## own).
func _check_shared_world() -> void:
	var root_world: World3D = get_viewport().find_world_3d()
	var view_1: SubViewport = _view_of(_split.player_1_camera)
	var view_2: SubViewport = _view_of(_split.player_2_camera)
	if view_1 == null or view_2 == null:
		_check("shared_world", false, "a camera is not inside a SubViewport")
		return
	var world_1: World3D = view_1.find_world_3d()
	var world_2: World3D = view_2.find_world_3d()
	var worlds_shared: bool = root_world != null and world_1 == root_world and world_2 == root_world
	var own_world_off: bool = not view_1.own_world_3d and not view_2.own_world_3d
	var world_3d_unset: bool = view_1.world_3d == null and view_2.world_3d == null
	_check("shared_world", worlds_shared and own_world_off and world_3d_unset,
		"root_world=%d view_1_world=%d view_2_world=%d own_world_3d=%s/%s world_3d_set=%s/%s" % [
			_id_of(root_world), _id_of(world_1), _id_of(world_2), view_1.own_world_3d, view_2.own_world_3d,
			view_1.world_3d != null, view_2.world_3d != null])


## AC-2: both Units live in one physics space, the window's own.
func _check_shared_physics_space() -> void:
	var root_space: RID = get_viewport().find_world_3d().space
	var space_1: RID = _split.player_1_unit.get_world_3d().space
	var space_2: RID = _split.player_2_unit.get_world_3d().space
	_check("shared_physics_space", space_1.is_valid() and space_1 == space_2 and space_1 == root_space,
		"unit_1_space=%d unit_2_space=%d root_space=%d" % [space_1.get_id(), space_2.get_id(), root_space.get_id()])


## Story 001 AC-5 in the launch scene: both Units are drawn from their interpolated transforms, so
## they, and the ChaseCameras that follow where they are drawn, move smoothly on a display that does
## not run at the physics tick rate. A node is interpolated as the first explicit mode above it says
## (INHERIT asks the parent, and the top of the tree is ON), and a Control is OFF by default, so a
## Node3D below the Control root needs an ON of its own. The check reads those modes rather than the
## rendered motion, which a fixed-rate or headless run cannot show, and rather than
## is_physics_interpolated_and_enabled(), which reads true below a Control that turns it off
## (measured on 4.7.2; the Story 002 evidence doc keeps the run). The project setting must be on as well.
func _check_world_interpolation() -> void:
	var enabled: bool = bool(ProjectSettings.get_setting(PHYSICS_INTERPOLATION_SETTING, false))
	var passed: bool = enabled
	var detail: PackedStringArray = ["project_setting=%s" % enabled]
	var units: Array[Unit] = [_split.player_1_unit, _split.player_2_unit]
	for index: int in units.size():
		var decider: Node = _interpolation_decider(units[index])
		var mode: int = Node.PHYSICS_INTERPOLATION_MODE_ON
		var source: String = "the tree's default"
		if decider != null:
			mode = decider.physics_interpolation_mode
			source = "%s (%s)" % [decider.name, decider.get_class()]
		passed = passed and mode == Node.PHYSICS_INTERPOLATION_MODE_ON
		detail.append("player_%d unit mode=%s set by %s" % [index + 1, _mode_text(mode), source])
	_check("world_interpolation", passed, " | ".join(detail) + " (every mode must be ON)")


## The node whose own mode decides how a node is interpolated: the node itself, or its nearest
## ancestor that does not say INHERIT. Null when every node up to the root says INHERIT.
func _interpolation_decider(node: Node) -> Node:
	var current: Node = node
	var inherit: int = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	while current != null and current.physics_interpolation_mode == inherit:
		current = current.get_parent()
	return current


## The name of a physics interpolation mode, for check details.
func _mode_text(mode: int) -> String:
	match mode:
		Node.PHYSICS_INTERPOLATION_MODE_ON:
			return "ON"
		Node.PHYSICS_INTERPOLATION_MODE_OFF:
			return "OFF"
	return "INHERIT"


## AC-2: each Unit stands on its own marker, facing the marker's way, and the two are apart.
func _check_start_positions() -> void:
	var markers: Array[Marker3D] = [_split.field.player_start, _split.field.player_2_start]
	var units: Array[Unit] = [_split.player_1_unit, _split.player_2_unit]
	var passed: bool = true
	var detail: PackedStringArray = []
	for index: int in units.size():
		var at: Vector3 = units[index].global_position
		var error: float = at.distance_to(markers[index].global_position)
		var facing_dot: float = (-units[index].global_transform.basis.z).dot(-markers[index].global_transform.basis.z)
		passed = passed and error <= START_TOLERANCE and facing_dot >= START_FACING_DOT
		detail.append("player_%d at (%.2f,%.2f,%.2f) marker_error=%.4f facing_dot=%.4f" % [
			index + 1, at.x, at.y, at.z, error, facing_dot])
	var apart: float = units[PLAYER_1].global_position.distance_to(units[PLAYER_2].global_position)
	passed = passed and apart > MIN_APART
	_check("start_positions", passed,
		"%s | apart=%.2f m (must be more than %.0f)" % [" | ".join(detail), apart, MIN_APART])


## AC-5 and AC-6: the eight actions exist in the Input Map, each with exactly one key event on the
## expected physical key, and every event is bound to any device (ANY_DEVICE, -1). Prints each key
## with OS.get_keycode_string and each event's device.
func _check_input_map() -> void:
	for player: int in [PLAYER_1, PLAYER_2]:
		var keys: Array[Key] = PLAYER_1_KEYS if player == PLAYER_1 else PLAYER_2_KEYS
		var passed: bool = true
		var detail: PackedStringArray = []
		for slot: int in ACTION_SUFFIXES.size():
			var action: StringName = StringName(ACTION_PREFIXES[player] + ACTION_SUFFIXES[slot])
			var events: Array[InputEvent] = []
			if InputMap.has_action(action):
				events = InputMap.action_get_events(action)
			var key_event: InputEventKey = null
			if events.size() == 1:
				key_event = events[0] as InputEventKey
			if key_event == null:
				passed = false
				detail.append("%s=missing_or_not_one_key_event(%d events)" % [action, events.size()])
				continue
			var matches: bool = key_event.physical_keycode == keys[slot] and key_event.device == ANY_DEVICE
			passed = passed and matches
			detail.append("%s=%s(device=%d)%s" % [
				action, OS.get_keycode_string(key_event.physical_keycode), key_event.device,
				"" if matches else "!expected_%s_on_device_%d" % [OS.get_keycode_string(keys[slot]), ANY_DEVICE]])
		_check("input_map_player_%d" % (player + 1), passed, " ".join(detail))


## AC-3: six phases, each from a reset to the corridors, each holding one Player's keys for
## ISOLATION_HOLD_SECONDS and then releasing them for ISOLATION_RELEASE_SECONDS. Only the driven
## Player's Unit may move.
func _scenario_isolation() -> void:
	var phases: Array[DriveStep] = _isolation_phases()
	for phase: DriveStep in phases:
		await _reset_to_corridors()
		_apply(phase)
		await _advance(phase.seconds)
		var held_moved: float = _tracks[phase.player].moved()
		var held_speed: float = _tracks[phase.player].unit.current_speed
		var held_yaw: float = _tracks[phase.player].yaw_total
		_print_summary("hold_end", phase)
		_release_all()
		await _advance(ISOLATION_RELEASE_SECONDS)
		_print_summary("phase_end", phase)
		_check_isolation_phase(phase, held_moved, held_speed, held_yaw)
	_finish("phases=%d" % phases.size())


## The isolation phases: W+A, S+D (Player 1), Up+Left, Down+Right (Player 2), then W alone and Up
## alone. For a step, steer * throttle is the expected sign of the turn (YAW_RULE).
func _isolation_phases() -> Array[DriveStep]:
	var phases: Array[DriveStep] = []
	phases.append(DriveStep.new(&"p1_forward_left", ISOLATION_HOLD_SECONDS, PLAYER_1, 1, 1))
	phases.append(DriveStep.new(&"p1_reverse_right", ISOLATION_HOLD_SECONDS, PLAYER_1, -1, -1))
	phases.append(DriveStep.new(&"p2_forward_left", ISOLATION_HOLD_SECONDS, PLAYER_2, 1, 1))
	phases.append(DriveStep.new(&"p2_reverse_right", ISOLATION_HOLD_SECONDS, PLAYER_2, -1, -1))
	phases.append(DriveStep.new(&"p1_forward", ISOLATION_HOLD_SECONDS, PLAYER_1, 1, 0))
	phases.append(DriveStep.new(&"p2_forward", ISOLATION_HOLD_SECONDS, PLAYER_2, 1, 0))
	return phases


## The keys a step holds, for example "W+A" or "Down+Right".
func _keys_text(step: DriveStep) -> String:
	var keys: Array[Key] = PLAYER_1_KEYS if step.player == PLAYER_1 else PLAYER_2_KEYS
	var names: PackedStringArray = []
	if step.throttle > 0:
		names.append(OS.get_keycode_string(keys[SLOT_THROTTLE]))
	if step.throttle < 0:
		names.append(OS.get_keycode_string(keys[SLOT_REVERSE]))
	if step.steer > 0:
		names.append(OS.get_keycode_string(keys[SLOT_STEER_LEFT]))
	if step.steer < 0:
		names.append(OS.get_keycode_string(keys[SLOT_STEER_RIGHT]))
	return "+".join(names)


## One SPLIT line with the distance moved, the drive speed and the yaw change of both Units.
func _print_summary(at: String, step: DriveStep) -> void:
	var first: UnitTrack = _tracks[PLAYER_1]
	var second: UnitTrack = _tracks[PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s at=%s keys=%s p1_moved=%.3f p1_speed=%.3f p1_yaw=%.1f "
		% [_scenario, _time(), step.label, at, _keys_text(step), first.moved(), first.unit.current_speed,
			rad_to_deg(first.yaw_total)]
		+ "p2_moved=%.3f p2_speed=%.3f p2_yaw=%.1f"
		% [second.moved(), second.unit.current_speed, rad_to_deg(second.yaw_total)])


## The four checks of one isolation phase. The driven Unit's numbers are those at the end of the
## hold; the other Unit's are those at the end of the phase, after the release as well.
func _check_isolation_phase(phase: DriveStep, held_moved: float, held_speed: float, held_yaw: float) -> void:
	var driven: UnitTrack = _tracks[phase.player]
	var other: UnitTrack = _tracks[1 - phase.player]
	var keys: String = _keys_text(phase)
	var reverse: bool = phase.throttle < 0
	var moves: bool = held_speed < 0.0 if reverse else held_moved > MOVE_MIN_DISTANCE
	_check("%s.driven_moves" % phase.label, moves, "keys=%s held %.1f s: moved=%.3f m speed=%.3f m/s (%s)" % [
		keys, phase.seconds, held_moved, held_speed,
		"reverse: speed must be below 0" if reverse else "must move more than %.0f m" % MOVE_MIN_DISTANCE])
	var expected_sign: int = phase.steer * phase.throttle
	var turned: bool = false
	if expected_sign == 0:
		turned = absf(held_yaw) < STILL_YAW
	else:
		turned = signf(held_yaw) == float(expected_sign) and absf(held_yaw) >= MIN_TURN
	_check("%s.driven_yaw" % phase.label, turned,
		"keys=%s: %s: steer %+d * sign(speed) %+d gives expected sign %+d (0 is straight); "
		% [keys, YAW_RULE, phase.steer, phase.throttle, expected_sign]
		+ "measured yaw change=%.3f rad (%.1f deg)" % [held_yaw, rad_to_deg(held_yaw)])
	var end_speed: float = driven.unit.current_speed
	_check("%s.driven_released" % phase.label, absf(end_speed) < absf(held_speed),
		"keys released: |speed| %.3f m/s at the release, %.3f m/s %.1f s later (must be lower)" % [
			absf(held_speed), absf(end_speed), ISOLATION_RELEASE_SECONDS])
	var still: bool = other.moved() < STILL_DISTANCE and absf(other.yaw_total) < STILL_YAW \
		and is_zero_approx(other.unit.current_speed)
	_check("%s.other_still" % phase.label, still,
		"the other Unit over the whole phase: moved=%.6f m (must be below %.3f) "
		% [other.moved(), STILL_DISTANCE]
		+ "yaw change=%.6f rad (below %.3f) speed=%.3f m/s"
		% [other.yaw_total, STILL_YAW, other.unit.current_speed])


## AC-4: both layouts held at once in the corridors: W and Up for SIM_STRAIGHT_SECONDS, then W+A
## and Up+Right for SIM_STEER_SECONDS. A second run gives Player 1's keys alone from the same start,
## the reference for "the second Player does not disturb the first". Each check reads the tracks at
## the end of the stretch it is about, before the next stretch or the second run resets them.
func _scenario_simultaneous() -> void:
	await _reset_to_corridors()
	_report_ticks = _ticks_in(SIM_REPORT_SECONDS)
	await _run_step(DriveStep.new(&"both_straight", SIM_STRAIGHT_SECONDS, BOTH, 1, 0))
	_check_both_moved_at_once()
	var straight_yaw: Array[float] = [_tracks[PLAYER_1].yaw_total, _tracks[PLAYER_2].yaw_total]
	_phase = &"both_steer"
	_drive(PLAYER_1, 1, 1)
	_drive(PLAYER_2, 1, -1)
	await _advance(SIM_STEER_SECONDS)
	_report_ticks = 0
	var top_speed: Array[float] = [_tracks[PLAYER_1].speed_max, _tracks[PLAYER_2].speed_max]
	var both_moved: float = _tracks[PLAYER_1].moved()
	var both_yaw: float = _tracks[PLAYER_1].yaw_total
	_check_both_reach_top_speed(top_speed)
	_check_yaw_signs_opposite(straight_yaw)
	await _reset_to_corridors()
	await _run_step(DriveStep.new(&"solo_straight", SIM_STRAIGHT_SECONDS, PLAYER_1, 1, 0))
	await _run_step(DriveStep.new(&"solo_steer", SIM_STEER_SECONDS, PLAYER_1, 1, 1))
	_check_player_1_matches_solo(both_moved, both_yaw)
	_finish("top_speed_1=%.3f top_speed_2=%.3f" % [top_speed[0], top_speed[1]])


## AC-4: after the straight stretch both Units have moved: W and Up held together drive both.
func _check_both_moved_at_once() -> void:
	var first: UnitTrack = _tracks[PLAYER_1]
	var second: UnitTrack = _tracks[PLAYER_2]
	_check("both_moved_at_once", first.moved() > MOVE_MIN_DISTANCE and second.moved() > MOVE_MIN_DISTANCE,
		"after %.1f s of W and Up together: player_1 moved=%.3f m speed=%.3f m/s, "
		% [SIM_STRAIGHT_SECONDS, first.moved(), first.unit.current_speed]
		+ "player_2 moved=%.3f m speed=%.3f m/s (each must move more than %.0f m)"
		% [second.moved(), second.unit.current_speed, MOVE_MIN_DISTANCE])


## AC-4: over both stretches each Unit reached SIM_TOP_SPEED_SHARE of its max_speed. top_speed is
## the highest drive speed of each Unit, in the order of the Players.
func _check_both_reach_top_speed(top_speed: Array[float]) -> void:
	var max_speed: Array[float] = [_split.player_1_unit.stats.max_speed, _split.player_2_unit.stats.max_speed]
	var required: Array[float] = [SIM_TOP_SPEED_SHARE * max_speed[0], SIM_TOP_SPEED_SHARE * max_speed[1]]
	_check("both_reach_top_speed", top_speed[0] >= required[0] and top_speed[1] >= required[1],
		"top speed player_1=%.3f m/s player_2=%.3f m/s, max_speed=%.1f m/s, "
		% [top_speed[0], top_speed[1], max_speed[0]]
		+ "required %.0f percent = %.3f m/s" % [SIM_TOP_SPEED_SHARE * 100.0, required[0]])


## AC-4: in the steering stretch Player 1 (W+A) turned left and Player 2 (Up+Right) turned right.
## straight_yaw is each track's yaw at the end of the straight stretch, in the order of the Players.
func _check_yaw_signs_opposite(straight_yaw: Array[float]) -> void:
	var steer_yaw: Array[float] = [
		_tracks[PLAYER_1].yaw_total - straight_yaw[0], _tracks[PLAYER_2].yaw_total - straight_yaw[1]]
	_check("yaw_signs_opposite", steer_yaw[0] >= MIN_TURN and steer_yaw[1] <= -MIN_TURN,
		"steering second: player_1 (W+A) yaw change=%.3f rad (%.1f deg, must be left, +), "
		% [steer_yaw[0], rad_to_deg(steer_yaw[0])]
		+ "player_2 (Up+Right) yaw change=%.3f rad (%.1f deg, must be right, -)"
		% [steer_yaw[1], rad_to_deg(steer_yaw[1])])


## AC-4: Player 1's run with Player 2 driving equals its run alone, within SIM_DISTANCE_TOLERANCE
## and SIM_YAW_TOLERANCE. The tracks hold the solo run now; both_moved and both_yaw are what Player 1
## measured with Player 2 driving.
func _check_player_1_matches_solo(both_moved: float, both_yaw: float) -> void:
	var solo_moved: float = _tracks[PLAYER_1].moved()
	var solo_yaw: float = _tracks[PLAYER_1].yaw_total
	var distance_error: float = absf(both_moved - solo_moved)
	var yaw_error: float = absf(both_yaw - solo_yaw)
	print("SPLIT simultaneous t=%.3f phase=result p1_moved=%.3f p1_yaw=%.1f solo_moved=%.3f solo_yaw=%.1f" % [
		_time(), both_moved, rad_to_deg(both_yaw), solo_moved, rad_to_deg(solo_yaw)])
	_check("player_1_matches_solo", distance_error <= SIM_DISTANCE_TOLERANCE and yaw_error <= SIM_YAW_TOLERANCE,
		"player_1 with player_2 driving: moved=%.4f m yaw=%.4f rad; player_1 alone: moved=%.4f m yaw=%.4f rad; "
		% [both_moved, both_yaw, solo_moved, solo_yaw]
		+ "difference %.4f m (tolerance %.2f) and %.4f rad (tolerance %.2f)"
		% [distance_error, SIM_DISTANCE_TOLERANCE, yaw_error, SIM_YAW_TOLERANCE])


## For the retained screenshots: about 11 s in which both Players drive from the markers, pass each
## other, turn round, brake, reverse and coast. Both Players give the same commands, so the two
## paths are mirror images through the centre of the field and the Units can meet only there. No
## checks: it ends by itself, and the RESULT line carries the closest approach of the two Units and
## the least room any Unit left to a wall.
func _scenario_showcase() -> void:
	_report_ticks = _ticks_in(SHOWCASE_REPORT_SECONDS)
	_print_progress()
	for step: DriveStep in _showcase_steps():
		await _run_step(step)
	_finish("separation_min=%.2f wall_clearance_min=%.2f" % [_separation_min, _wall_clearance_min])


## AC-7: both Players at full throttle steering left for FPS_SECONDS, which is about four circles of
## 8.6 m radius (max_speed / turn_rate = 24 / 2.8, so 17 m across; the field is 80 m across). One
## line per second with the frame rate and the render totals of the frame, all viewports together.
## No pass or fail: the numbers are the evidence. The first sample covers start-up (window, shader
## compilation), so fps_min_steady and fps_avg_steady leave it out: quote those two.
func _scenario_fps() -> void:
	_apply(DriveStep.new(&"circle", float(FPS_SECONDS), BOTH, 1, 1))
	var fps_total: float = 0.0
	var fps_total_steady: float = 0.0
	var fps_min: float = INF
	var fps_min_steady: float = INF
	var draw_calls_max: int = 0
	var primitives_max: int = 0
	for second: int in FPS_SECONDS:
		await _advance(1.0)
		var fps: float = Engine.get_frames_per_second()
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		fps_total += fps
		fps_min = minf(fps_min, fps)
		if second > 0:
			fps_total_steady += fps
			fps_min_steady = minf(fps_min_steady, fps)
		draw_calls_max = maxi(draw_calls_max, draw_calls)
		primitives_max = maxi(primitives_max, primitives)
		print("SPLIT fps t=%.3f fps=%.1f draw_calls=%d primitives=%d objects=%d" % [
			_time(), fps, draw_calls, primitives, objects])
	var steady_seconds: int = maxi(FPS_SECONDS - 1, 1)
	_finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f refresh_hz=%.1f " % [
			fps_total / float(FPS_SECONDS), fps_total_steady / float(steady_seconds), fps_min,
			fps_min_steady, DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d display=%s" % [
			draw_calls_max, primitives_max, FPS_SECONDS, DisplayServer.get_name()])


## The showcase choreography as steps, both Players at once, from SHOWCASE_PLAN.
func _showcase_steps() -> Array[DriveStep]:
	var steps: Array[DriveStep] = []
	for row: Array in SHOWCASE_PLAN:
		steps.append(DriveStep.new(row[0], row[1], BOTH, row[2], row[3]))
	return steps
