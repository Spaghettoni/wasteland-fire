extends RefCounted
## The readings of the countdown scenario (countdown.gd). Two readings, because a label is only as current
## as its last rendered frame. A tick reading is taken in the runner's physics_frame continuation, before
## that tick's own _process: the label there still shows what its last frame drew, one tick behind the
## controller's seconds. A frame reading is taken by a probe node that runs after every label in the same
## rendered frame (a later process_priority), so label and controller are read at one instant. Both logs
## are public; countdown_audit.gd judges them.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-6. Made by
## countdown.gd. Tooling only: nothing under src/ depends on this file.

## The runner, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## One instant (countdown_sample.gd).
const Sample: GDScript = preload("res://tools/evidence/split_screen/countdown_sample.gd")
## process_priority of the probe: above every label's (0), so it runs after them in the same frame.
const PROBE_PRIORITY: int = 1000


## Calls back once per rendered frame, after every RespawnCountdown has processed (the trace gives it a
## later process_priority), so the callback sees what that frame draws.
class Probe extends Node:
	## Called with no arguments from _process.
	var sampler: Callable

	func _process(_delta: float) -> void:
		sampler.call()


## Tick readings taken in the whole run.
var tick_total: int = 0
## Frame readings taken in the whole run.
var frame_total: int = 0
## Readings after every physics tick since the trace began.
var tick_log: Array[Sample] = []
## Readings after every rendered frame since the trace began.
var frame_log: Array[Sample] = []

var _harness: Harness
var _controller: MatchController
## The two labels, by the player_index each carries.
var _labels: Array[RespawnCountdown] = []
var _probe: Probe
var _recording: bool = false


func _init(harness: Node, labels: Array[RespawnCountdown]) -> void:
	_harness = harness as Harness
	_controller = _harness.split.match_controller
	_labels = labels


## Adds the probe that takes the frame readings to the runner.
func add_probe() -> void:
	_probe = Probe.new()
	_probe.process_priority = PROBE_PRIORITY
	_probe.sampler = _on_frame
	_harness.add_child(_probe)


## Takes the probe out again.
func remove_probe() -> void:
	_probe.queue_free()


## Starts a trace: empties both logs and records from now.
func begin() -> void:
	tick_log = []
	frame_log = []
	_recording = true


## Ends the trace; its logs stay readable until the next one begins.
func end() -> void:
	_recording = false
	tick_total += tick_log.size()
	frame_total += frame_log.size()


## The kit's after-every-tick hook: a tick reading, while a trace is recording.
func on_tick() -> void:
	if _recording:
		tick_log.append(_read())


## How many tick readings show this Player's label.
func shown_ticks(player: int) -> int:
	return _count_shown(tick_log, player)


## How many frame readings show this Player's label.
func shown_frames(player: int) -> int:
	return _count_shown(frame_log, player)


## How many tick readings have this Player's Unit not alive, the controller's word for waiting.
func waiting_ticks(player: int) -> int:
	return _count_waiting(tick_log, player)


## How many frame readings have this Player's Unit not alive.
func waiting_frames(player: int) -> int:
	return _count_waiting(frame_log, player)


## Tick readings in which both labels are shown.
func together() -> int:
	var count: int = 0
	for sample: Sample in tick_log:
		count += 1 if sample.visible[0] and sample.visible[1] else 0
	return count


## Tick readings in which both labels are shown with different text.
func differing() -> int:
	var count: int = 0
	for sample: Sample in tick_log:
		count += 1 if sample.visible[0] and sample.visible[1] and sample.text[0] != sample.text[1] else 0
	return count


## Tick readings in which Player 1's label is gone while Player 2's still counts.
func first_gone() -> int:
	var count: int = 0
	for sample: Sample in tick_log:
		count += 1 if not sample.visible[0] and sample.visible[1] else 0
	return count


## The probe's callback: a frame reading, while a trace is recording.
func _on_frame() -> void:
	if _recording:
		frame_log.append(_read())


## Reads both labels and the controller now.
func _read() -> Sample:
	var sample: Sample = Sample.new()
	for player: int in Kit.PLAYERS:
		var label: RespawnCountdown = _labels[player]
		sample.visible[player] = label.is_visible_in_tree()
		sample.text[player] = label.text
		sample.seconds[player] = _controller.seconds_until_respawn(player)
		sample.alive[player] = _controller.is_alive(player)
	return sample


## How many readings show this Player's label.
func _count_shown(samples: Array[Sample], player: int) -> int:
	var count: int = 0
	for sample: Sample in samples:
		count += 1 if sample.visible[player] else 0
	return count


## How many readings have this Player's Unit not alive.
func _count_waiting(samples: Array[Sample], player: int) -> int:
	var count: int = 0
	for sample: Sample in samples:
		count += 0 if sample.alive[player] else 1
	return count
