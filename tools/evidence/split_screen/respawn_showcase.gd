extends RefCounted
## Scenario respawn_showcase of the split screen evidence harness (split_screen_harness.gd): about 14 s
## for the retained screenshots of Story 003's destruction and respawn. Both Units idle on their Bases,
## drive out toward the centre and veer apart, Player 1 presses Tab (Self-destruct) and its Unit vanishes
## where it stood. Player 1's view shows the countdown 3, 2, 1 over an empty field while Player 2 keeps
## driving (a U-turn, a short run, a stop). Player 1 is back on its Base when the wait ends; both idle a
## moment, drive on a little and stop.
##
## No checks in a normal run: it ends by itself with RESULT ok. A run whose premise failed (Player 1
## never destroyed, or never back) prints one failing CHECK named premise, so an empty recording cannot
## pass as evidence. The paths keep the Units apart: the RESULT line carries the closest the two came
## while both were in play and the distance at which two motorbike boxes can touch, read from the Unit's
## own collision shape.
##
## SPLIT lines come every 0.5 s and at the destruction and the respawn (an event= field). They carry both
## Units' positions, hit points and alive flags, each countdown's text or none, and frame=, the frames
## drawn so far: in a --write-movie run that is the number of the next PNG, so a moment can be found in
## the recording (a recording of this project runs at 60 frames a second, so the PNG of time t is about
## t x 60).
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md, Test Evidence for
## AC-1 to AC-6 (UI and Visual/Feel: retained screenshots). Tooling only: nothing under src/ depends on it.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/show.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=respawn_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the Self-destruct key, the Players and the wait limit.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Interval between progress lines, seconds.
const REPORT_SECONDS: float = 0.5

## Before the key: label, seconds, then Player 1's throttle and steer, then Player 2's (throttle 1 forward,
## -1 reverse; steer 1 left, -1 right). Idle on the Bases, then 1.5 s out toward the centre, both veering
## right for a moment: Player 1 goes to +x and Player 2, facing the other way, to -x, so they pass 9 m
## apart and never meet. Player 1 is at full speed when it presses the key.
const PLAN_BEFORE: Array[Array] = [
	[&"idle", 1.0, 0, 0, 0, 0],
	[&"drive_out", 0.3, 1, 0, 1, 0],
	[&"drive_out_veer_right", 0.25, 1, -1, 1, -1],
	[&"drive_out", 0.95, 1, 0, 1, 0],
]
## While Player 1 waits, Player 2 only: label, seconds, throttle, steer. A U-turn to the left, a short
## run and a hard stop, so it is away from Player 1's Base when that Unit returns.
const PLAN_WAIT: Array[Array] = [
	[&"p2_u_turn_left", 1.1, 1, 1],
	[&"p2_straight", 0.6, 1, 0],
	[&"p2_brake", 0.65, -1, 0],
]
## After the respawn, both Players: the same columns as PLAN_BEFORE. A moment at rest with Player 1 on its
## Base, a run of a second, a stop, and a rest at the end.
const PLAN_AFTER: Array[Array] = [
	[&"respawned_idle", 2.0, 0, 0, 0, 0],
	[&"drive_on", 1.0, 1, 0, 1, 0],
	[&"brake", 0.55, -1, 0, -1, 0],
	[&"rest", 4.9, 0, 0, 0, 0],
]

var _harness: Harness
var _kit: Kit
var _controller: MatchController
var _units: Array[Unit] = []
var _labels: Array[RespawnCountdown] = [null, null]
var _report_ticks: int = 1
## The runner's simulated time of Player 1's destruction and of its respawn, or -1.0 before it happens.
var _destroyed_at: float = -1.0
var _respawned_at: float = -1.0
## The runner's tick of each of them, or -1.
var _destroyed_tick: int = -1
var _respawned_tick: int = -1
## Closest the two Units' origins came while both were in play, metres.
var _gap_min: float = INF
## What Player 1's label showed, in order, as [text, ticks] pairs.
var _runs: Array[Array] = []


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_kit.on_tick = _note_tick
	var split: SplitScreen = _harness.split
	_controller = split.match_controller
	_units.assign([split.player_1_unit, split.player_2_unit])
	_find_labels()
	_report_ticks = _harness.ticks_in(REPORT_SECONDS)
	_controller.unit_destroyed.connect(_on_destroyed)
	_controller.unit_spawned.connect(_on_spawned)
	_line("")
	await _play_both(PLAN_BEFORE)
	_harness.phase = &"self_destruct"
	_harness.drive(Harness.PLAYER_1, 0, 0)
	await _kit.press(Kit.KEYS_DESTRUCT_1)
	await _play_p2(PLAN_WAIT)
	_harness.drive(Harness.PLAYER_2, 0, 0)
	_harness.phase = &"p1_waiting"
	await _wait_for_respawn()
	await _play_both(PLAN_AFTER)
	_harness.phase = &"end"
	_line("")
	_finish()


## Holds each row of a plan for Players 1 and 2: the rows of PLAN_BEFORE and PLAN_AFTER.
func _play_both(plan: Array[Array]) -> void:
	for row: Array in plan:
		_harness.phase = row[0]
		_harness.drive(Harness.PLAYER_1, row[2], row[3])
		_harness.drive(Harness.PLAYER_2, row[4], row[5])
		await _hold(row[1])


## Holds each row of a plan for Player 2 alone: the rows of PLAN_WAIT.
func _play_p2(plan: Array[Array]) -> void:
	for row: Array in plan:
		_harness.phase = row[0]
		_harness.drive(Harness.PLAYER_2, row[2], row[3])
		await _hold(row[1])


## Waits on, with both Players at rest, until Player 1's Unit is back or the limit passes.
func _wait_for_respawn() -> void:
	var limit: int = _harness.ticks_in(_controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	while _destroyed_tick >= 0 and _respawned_tick < 0 and limit > 0:
		await _kit.tick()
		limit -= 1


## Prints the failing premise check when the recording shows no respawn, then the RESULT line.
func _finish() -> void:
	if _destroyed_tick < 0 or _respawned_tick < 0:
		_harness.check("premise", false, "Player 1 destroyed at tick %d, respawned at tick %d (-1 is never): the recording shows no respawn" % [
			_destroyed_tick, _respawned_tick])
	var runs: PackedStringArray = []
	for run_entry: Array in _runs:
		runs.append("%s:%d" % [String(run_entry[0]).replace(" ", "_"), run_entry[1]])
	_harness.finish(("destroyed_t=%.3f respawned_t=%.3f wait_ticks=%d countdown_runs=%s gap_min_both_alive=%.2f "
		+ "contact_distance=%.2f wall_clearance_min=%.2f") % [
		_destroyed_at, _respawned_at, _respawned_tick - _destroyed_tick, ",".join(runs), _gap_min, _contact_distance(),
		_harness.wall_clearance_min])


## Finds the two RespawnCountdown labels by class and files them by player_index.
func _find_labels() -> void:
	for node: Node in _harness.get_tree().root.find_children("*", "", true, false):
		var label: RespawnCountdown = node as RespawnCountdown
		if label != null and label.player_index >= 0 and label.player_index < _labels.size():
			_labels[label.player_index] = label


## The distance at which two motorbike collision boxes can touch: the diagonal of the box, read from the
## Unit's own shape. 0.0 when the Unit has no box shape.
func _contact_distance() -> float:
	for child: Node in _units[0].get_children():
		var shape_node: CollisionShape3D = child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			var size: Vector3 = (shape_node.shape as BoxShape3D).size
			return Vector2(size.x, size.z).length()
	return 0.0


## After every tick the kit waits: notes the gap between the Units, what Player 1's label shows, and
## prints a progress line when one is due.
func _note_tick() -> void:
	if _units[0].is_alive and _units[1].is_alive:
		_gap_min = minf(_gap_min, _units[0].global_position.distance_to(_units[1].global_position))
	var label: RespawnCountdown = _labels[0]
	if label.is_visible_in_tree():
		if _runs.is_empty() or (_runs[_runs.size() - 1] as Array)[0] != label.text:
			_runs.append([label.text, 0])
		var current: Array = _runs[_runs.size() - 1]
		current[1] += 1
	if _harness.ticks % _report_ticks == 0:
		_line("")


## Holds the current keys for the given seconds.
func _hold(seconds: float) -> void:
	await _kit.advance(_harness.ticks_in(seconds))


## Player 1's Unit left play: note when, and print the moment.
func _on_destroyed(player_index: int) -> void:
	if player_index == Harness.PLAYER_1 and _destroyed_tick < 0:
		_destroyed_tick = _harness.ticks
		_destroyed_at = _harness.time()
		_line("p1_destroyed")


## Player 1's Unit is back on its Base after the destruction: note when, and print the moment. The
## spawns at the start of the Round came before this scenario connected.
func _on_spawned(player_index: int) -> void:
	if player_index == Harness.PLAYER_1 and _destroyed_tick >= 0 and _respawned_tick < 0:
		_respawned_tick = _harness.ticks
		_respawned_at = _harness.time()
		_line("p1_respawned")


## Prints one SPLIT line: time, frames drawn, phase, both Units' place, hit points and alive flag, each
## countdown's text or none, and the event when there is one.
func _line(event: String) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units[player]
		var label: RespawnCountdown = _labels[player]
		var shown: String = "\"%s\"" % label.text if label.is_visible_in_tree() else "none"
		fields.append("p%d_x=%.2f p%d_z=%.2f p%d_hp=%.0f p%d_alive=%s p%d_countdown=%s" % [
			player + 1, unit.global_position.x, player + 1, unit.global_position.z, player + 1, unit.hit_points,
			player + 1, unit.is_alive, player + 1, shown])
	print("SPLIT %s t=%.3f frame=%d phase=%s %s%s" % [
		_harness.scenario, _harness.time(), Engine.get_frames_drawn(), _harness.phase, " ".join(fields),
		"" if event.is_empty() else " event=" + event])
