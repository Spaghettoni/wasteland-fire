extends Node
## Evidence harness runner for the split screen launch scene (Story 002, and the scenarios Story 003 adds):
## runs one named scenario against split_screen.tscn and prints machine-readable lines, so the acceptance
## criteria are backed by a run.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria and Test
## Evidence. Tooling only: nothing under src/ depends on this file; it couples to src/ by instancing
## split_screen.tscn and reading the exported members of SplitScreen.
##
## Scenarios, chosen with --scenario=NAME (after the "--"): layout, isolation, simultaneous, showcase, fps,
## bases, destruction, countdown, respawn_showcase, canister_run, hud, round_over and
## canister_showcase. Each is a script under tools/evidence/split_screen/,
## a RefCounted with `func run(harness: Node) -> void`, a coroutine this runner awaits; its top says what it
## proves and how to run it. SCENARIOS maps the name to the script, so a new scenario is a script and one
## line there. A scenario reaches this script, DriveStep, UnitTrack and check_kit.gd through preload
## constants (nothing under tools/ declares a class_name, so they are PascalCase: the style guide's exception to
## SCREAMING_SNAKE for a constant that holds a class) and uses only the public members below.
##
## The harness plays the keyboard: every drive command is a real InputEventKey pushed through
## Input.parse_input_event with the physical keycode of the key, so the Input Map, PlayerDriveInput and
## the Unit run as under a real keyboard. Gameplay code names actions, never keys; tools are the only place
## key codes appear. Events carry InputEvent.DEVICE_ID_KEYBOARD (16), the id Godot 4.7 gives a keyboard, and
## Input.use_accumulated_input is off, so an event acts at once (measured on 4.7.2; Story 002 evidence doc).
##
## Time is simulated: scenarios await the physics_frame signal and count ticks, so the numbers are the same
## at any frame rate and a headless --fixed-fps 60 run is faster than real time. The continuation after
## physics_frame runs before the nodes' _physics_process of that tick (measured on 4.7.2), so a key pressed
## there reaches PlayerDriveInput in the same tick and what is read there is the previous tick.
##
## Output: SPLIT <scenario> t=<seconds> key=value ... (progress), CHECK <scenario> <check name> PASS|FAIL
## <detail> and exactly one last RESULT <scenario> ok|fail checks=<n> failed=<n> key=value ...; then quit with
## exit code 0 when every check passed, 1 when one failed, 2 for a missing or unknown scenario. TD-003
## (docs/tech-debt-register.md) is paid by Story 003; this runner is still coroutine-based with run-wide counters (TD-001).

## The launch scene under test.
const SPLIT_SCENE: PackedScene = preload("res://src/gameplay/split_screen/split_screen.tscn")

## Prefix of the user argument that names the scenario.
const SCENARIO_ARGUMENT: String = "--scenario="

## The scenarios, name to script, in the order of the header. Each script is a RefCounted with
## run(harness: Node) -> void, a coroutine. A new scenario is its script and one line here.
const SCENARIOS: Dictionary[StringName, GDScript] = {
	&"layout": preload("res://tools/evidence/split_screen/layout.gd"),
	&"isolation": preload("res://tools/evidence/split_screen/isolation.gd"),
	&"simultaneous": preload("res://tools/evidence/split_screen/simultaneous.gd"),
	&"showcase": preload("res://tools/evidence/split_screen/showcase.gd"),
	&"fps": preload("res://tools/evidence/split_screen/fps.gd"),
	&"bases": preload("res://tools/evidence/split_screen/bases.gd"),
	&"destruction": preload("res://tools/evidence/split_screen/destruction.gd"),
	&"countdown": preload("res://tools/evidence/split_screen/countdown.gd"),
	&"respawn_showcase": preload("res://tools/evidence/split_screen/respawn_showcase.gd"),
	&"canister_run": preload("res://tools/evidence/split_screen/canister_run.gd"),
	&"hud": preload("res://tools/evidence/split_screen/hud.gd"),
	&"round_over": preload("res://tools/evidence/split_screen/round_over.gd"),
	&"canister_showcase": preload("res://tools/evidence/split_screen/canister_showcase.gd"),
}

## The shared step class (drive_step.gd): keys held for a time.
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd): follows one Unit through a phase.
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## Exit code when a check failed.
const EXIT_FAILED: int = 1
## Exit code for a missing or unknown scenario.
const EXIT_USAGE: int = 2
## A scenario still running after this many simulated seconds has hung (a script error stops a
## coroutine without a word): the watchdog prints a failing RESULT and quits.
const WATCHDOG_SECONDS: float = 120.0

## Player 1's index, into the tracks and the layouts.
const PLAYER_1: int = 0
## Player 2's index, into the tracks and the layouts.
const PLAYER_2: int = 1
## Stands for both Players in a DriveStep: both layouts are held at once.
const BOTH: int = -1

## Physical keys of Player 1's layout, in the order of SLOT_*: the p1_ Input Map actions are bound to these.
const PLAYER_1_KEYS: Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
## Physical keys of Player 2's layout, in the order of SLOT_*: the p2_ Input Map actions are bound to these.
const PLAYER_2_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

## Position of the throttle key in a layout (PLAYER_1_KEYS, PLAYER_2_KEYS).
const SLOT_THROTTLE: int = 0
## Position of the reverse key in a layout.
const SLOT_REVERSE: int = 1
## Position of the steer-left key in a layout.
const SLOT_STEER_LEFT: int = 2
## Position of the steer-right key in a layout.
const SLOT_STEER_RIGHT: int = 3

## Window size AC-1 asks for, pixels. A headless run has no real window (it starts at 64 x 64), so
## there the harness sets the window to this size before a scenario looks.
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## Ticks each reset waits, with every key up, before the tracks start counting.
const SETTLE_TICKS: int = 5
## Corridor starts (isolation, simultaneous), metres. Player 1 faces -Z, Player 2 faces +Z.
const CORRIDOR_1_START: Vector3 = Vector3(-10.0, 0.0, 20.0)
## Player 2's corridor start, metres (see CORRIDOR_1_START).
const CORRIDOR_2_START: Vector3 = Vector3(10.0, 0.0, -20.0)
## Half the side of the playfield, metres (the inner faces of the four walls, greybox_field.tscn).
const FIELD_HALF_EXTENT: float = 40.0

## The scenario running, from --scenario=NAME: the second word of every SPLIT, CHECK and RESULT line.
var scenario: StringName = &""
## The launch scene under test: the field, both Units and both cameras a scenario reads.
var split: SplitScreen
## One track per Player, in the order of PLAYER_1 and PLAYER_2, updated after every tick.
var tracks: Array[UnitTrack] = []
## Name of the stretch running, printed in the SPLIT lines. apply() sets it from the step.
var phase: StringName = &"start"
## Ticks between SPLIT progress lines; 0 prints none.
var report_ticks: int = 0
## Physics ticks simulated so far. Simulated time is this over the tick rate; read it, do not set it.
var ticks: int = 0
## The Players whose unit_spawned signal arrived while the launch scene was added to the tree, in the
## order it came: the start of the Round. MatchController.begin() runs inside add_child(split), before
## any scenario exists to connect to it, so the runner listens from before that and keeps the log here.
var round_start_spawns: Array[int] = []
## Closest the two Units' origins came since the run began, metres.
var separation_min: float = INF
## The least room any Unit's origin left to a wall since the run began, metres.
var wall_clearance_min: float = INF
## Which physical keys the harness holds down now, so an event is sent only on a change.
var _held: Dictionary[int, bool] = {}
var _ticks_per_second: int = 60
var _checks: int = 0
var _failed: int = 0
var _finished: bool = false


func _ready() -> void:
	_ticks_per_second = Engine.physics_ticks_per_second
	scenario = _read_scenario()
	if not SCENARIOS.has(scenario):
		# quit() only takes effect after the current frame, so nothing else may run first.
		_finished = true
		print("RESULT %s fail checks=0 failed=0 reason=unknown_scenario %s" % [
			"none" if scenario.is_empty() else String(scenario), _usage()])
		get_tree().quit(EXIT_USAGE)
		return
	Input.use_accumulated_input = false
	get_tree().create_timer(WATCHDOG_SECONDS).timeout.connect(_on_watchdog)
	split = SPLIT_SCENE.instantiate() as SplitScreen
	if split.match_controller != null:
		split.match_controller.unit_spawned.connect(_on_round_start_spawn)
	add_child(split)
	_run()


## Runs the chosen scenario as a coroutine: after the first frame, so the window and the layout
## exist, then the scenario script's run(), which awaits physics ticks. The log of the Round's start
## (round_start_spawns) is closed first, so a respawn is never taken for it.
func _run() -> void:
	await get_tree().process_frame
	if split.match_controller != null and split.match_controller.unit_spawned.is_connected(_on_round_start_spawn):
		split.match_controller.unit_spawned.disconnect(_on_round_start_spawn)
	if DisplayServer.get_name() == "headless":
		get_window().size = WINDOW_SIZE
	tracks.append(UnitTrack.new(split.player_1_unit))
	tracks.append(UnitTrack.new(split.player_2_unit))
	var entry: RefCounted = SCENARIOS[scenario].new()
	await entry.run(self)


## Logs a unit_spawned that arrives before the first frame: the start of the Round (round_start_spawns).
func _on_round_start_spawn(player_index: int) -> void:
	round_start_spawns.append(player_index)


## The scenario named by --scenario=NAME among the user arguments, or an empty name.
func _read_scenario() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARGUMENT):
			return StringName(argument.trim_prefix(SCENARIO_ARGUMENT))
	return &""


## The usage line: the tool name, then SCENARIO_ARGUMENT and the names of SCENARIOS separated by "|".
func _usage() -> String:
	var names: PackedStringArray = []
	for scenario_name: StringName in SCENARIOS:
		names.append(String(scenario_name))
	return "usage: split_screen_harness.tscn -- " + SCENARIO_ARGUMENT + "|".join(names)


## Whole physics ticks in a time, at least one.
func ticks_in(seconds: float) -> int:
	return maxi(1, roundi(seconds * _ticks_per_second))


## Simulated seconds since the scenario began.
func time() -> float:
	return float(ticks) / float(_ticks_per_second)


## Waits the given number of physics ticks, sampling both Units after each one. A coroutine: await it.
func advance_ticks(count: int) -> void:
	for _tick: int in count:
		await get_tree().physics_frame
		ticks += 1
		_sample()


## Waits the given simulated seconds. A coroutine: await it.
func advance(seconds: float) -> void:
	await advance_ticks(ticks_in(seconds))


## Updates both tracks and the run-wide minimums after a tick; prints a progress line when one is due.
func _sample() -> void:
	for track: UnitTrack in tracks:
		track.update()
		var at: Vector3 = track.unit.global_position
		wall_clearance_min = minf(wall_clearance_min, FIELD_HALF_EXTENT - maxf(absf(at.x), absf(at.z)))
	separation_min = minf(separation_min,
		tracks[PLAYER_1].unit.global_position.distance_to(tracks[PLAYER_2].unit.global_position))
	if report_ticks > 0 and ticks % report_ticks == 0:
		print_progress()


## Prints one SPLIT line with both Units' place, drive speed and turn since the phase began.
func print_progress() -> void:
	var first: UnitTrack = tracks[PLAYER_1]
	var second: UnitTrack = tracks[PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s p1_x=%.2f p1_z=%.2f p1_speed=%.2f p1_yaw=%.1f "
		% [scenario, time(), phase, first.unit.global_position.x, first.unit.global_position.z,
			first.unit.current_speed, rad_to_deg(first.yaw_total)]
		+ "p2_x=%.2f p2_z=%.2f p2_speed=%.2f p2_yaw=%.1f"
		% [second.unit.global_position.x, second.unit.global_position.z,
			second.unit.current_speed, rad_to_deg(second.yaw_total)])


## Presses or releases one physical key by pushing a real key event through the Input singleton,
## the way the OS does. Sends nothing when the key is already in that state.
func set_key(key: Key, pressed: bool) -> void:
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
func drive(player: int, throttle: int, steer: int) -> void:
	var keys: Array[Key] = PLAYER_1_KEYS if player == PLAYER_1 else PLAYER_2_KEYS
	set_key(keys[SLOT_THROTTLE], throttle > 0)
	set_key(keys[SLOT_REVERSE], throttle < 0)
	set_key(keys[SLOT_STEER_LEFT], steer > 0)
	set_key(keys[SLOT_STEER_RIGHT], steer < 0)


## Sets the whole key state of a step and names the phase after it: its Player (or both) holds the
## step's keys, the other has every key up.
func apply(step: DriveStep) -> void:
	phase = step.label
	for player: int in [PLAYER_1, PLAYER_2]:
		if step.player == BOTH or step.player == player:
			drive(player, step.throttle, step.steer)
		else:
			drive(player, 0, 0)


## Releases every key of both layouts.
func release_all() -> void:
	drive(PLAYER_1, 0, 0)
	drive(PLAYER_2, 0, 0)


## Holds the step's keys for its length. A coroutine: await it.
func run_step(step: DriveStep) -> void:
	apply(step)
	await advance(step.seconds)


## Teleports a Unit and snaps its camera, in the order a spawn uses: transform first, then
## reset_motion(), then snap_to_target().
func place(unit: Unit, where: Transform3D, camera: ChaseCamera) -> void:
	unit.global_transform = where
	unit.reset_motion()
	camera.snap_to_target()


## The corridor start of a Player: x = -10 facing -Z for Player 1, x = +10 facing +Z for Player 2.
func corridor_transform(player: int) -> Transform3D:
	if player == PLAYER_1:
		return Transform3D(Basis.IDENTITY, CORRIDOR_1_START)
	return Transform3D(Basis(Vector3.UP, PI), CORRIDOR_2_START)


## A reset of both Units to their corridors with every key up: teleport, wait SETTLE_TICKS, then
## start both tracks from where the Units stand. A coroutine: await it.
func reset_to_corridors() -> void:
	release_all()
	place(split.player_1_unit, corridor_transform(PLAYER_1), split.player_1_camera)
	place(split.player_2_unit, corridor_transform(PLAYER_2), split.player_2_camera)
	await advance_ticks(SETTLE_TICKS)
	for track: UnitTrack in tracks:
		track.begin()


## Prints one CHECK line and counts it.
func check(check_name: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failed += 1
	print("CHECK %s %s %s %s" % [scenario, check_name, "PASS" if passed else "FAIL", detail])


## Prints the one RESULT line, releases the keys and quits: exit code 0 when no check failed, 1
## otherwise. The fields are the scenario's own key=value numbers. A scenario ends with it, once.
func finish(fields: String) -> void:
	if _finished:
		return
	_finished = true
	release_all()
	var line: String = "RESULT %s %s checks=%d failed=%d t=%.3f" % [
		scenario, "ok" if _failed == 0 else "fail", _checks, _failed, time()]
	if not fields.is_empty():
		line += " " + fields
	print(line)
	get_tree().quit(0 if _failed == 0 else EXIT_FAILED)


## Fires when the scenario has not finished in WATCHDOG_SECONDS: a hung coroutine fails loudly.
func _on_watchdog() -> void:
	if _finished:
		return
	check("watchdog", false, "the scenario did not finish within %.0f simulated seconds" % WATCHDOG_SECONDS)
	finish("reason=watchdog")
