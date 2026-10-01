extends RefCounted
## Scenario isolation of the split screen evidence harness (split_screen_harness.gd): AC-3 of Story
## 002, one Player's keys at a time. Six phases, each from a reset to the corridors, each holding one
## Player's keys for ISOLATION_HOLD_SECONDS and then releasing them for ISOLATION_RELEASE_SECONDS.
## Only the driven Player's Unit may move, and it must turn the way the steering convention says
## (YAW_RULE). Prints two SPLIT lines per phase (hold_end, phase_end) and four CHECK lines per phase.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=isolation

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## The steering convention the isolation checks derive their expected signs from (unit.gd,
## _yaw_rate): steer is +1 for left, and the turn reverses while rolling backward.
const YAW_RULE: String = "yaw rate = steer(+1 left) * turn_rate * |speed|/max_speed * sign(speed)"

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

var _harness: Harness
var _tracks: Array[UnitTrack] = []


## AC-3: six phases, each from a reset to the corridors, each holding one Player's keys for
## ISOLATION_HOLD_SECONDS and then releasing them for ISOLATION_RELEASE_SECONDS. Only the driven
## Player's Unit may move. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_tracks = _harness.tracks
	var phases: Array[DriveStep] = _phases()
	for phase: DriveStep in phases:
		await _harness.reset_to_corridors()
		_harness.apply(phase)
		await _harness.advance(phase.seconds)
		var held_moved: float = _tracks[phase.player].moved()
		var held_speed: float = _tracks[phase.player].unit.current_speed
		var held_yaw: float = _tracks[phase.player].yaw_total
		_print_summary("hold_end", phase)
		_harness.release_all()
		await _harness.advance(ISOLATION_RELEASE_SECONDS)
		_print_summary("phase_end", phase)
		_check_phase(phase, held_moved, held_speed, held_yaw)
	_harness.finish("phases=%d" % phases.size())


## The isolation phases: W+A, S+D (Player 1), Up+Left, Down+Right (Player 2), then W alone and Up
## alone. For a step, steer * throttle is the expected sign of the turn (YAW_RULE).
func _phases() -> Array[DriveStep]:
	var phases: Array[DriveStep] = []
	phases.append(DriveStep.new(&"p1_forward_left", ISOLATION_HOLD_SECONDS, Harness.PLAYER_1, 1, 1))
	phases.append(DriveStep.new(&"p1_reverse_right", ISOLATION_HOLD_SECONDS, Harness.PLAYER_1, -1, -1))
	phases.append(DriveStep.new(&"p2_forward_left", ISOLATION_HOLD_SECONDS, Harness.PLAYER_2, 1, 1))
	phases.append(DriveStep.new(&"p2_reverse_right", ISOLATION_HOLD_SECONDS, Harness.PLAYER_2, -1, -1))
	phases.append(DriveStep.new(&"p1_forward", ISOLATION_HOLD_SECONDS, Harness.PLAYER_1, 1, 0))
	phases.append(DriveStep.new(&"p2_forward", ISOLATION_HOLD_SECONDS, Harness.PLAYER_2, 1, 0))
	return phases


## The keys a step holds, for example "W+A" or "Down+Right".
func _keys_text(step: DriveStep) -> String:
	var keys: Array[Key] = Harness.PLAYER_1_KEYS if step.player == Harness.PLAYER_1 else Harness.PLAYER_2_KEYS
	var names: PackedStringArray = []
	if step.throttle > 0:
		names.append(OS.get_keycode_string(keys[Harness.SLOT_THROTTLE]))
	if step.throttle < 0:
		names.append(OS.get_keycode_string(keys[Harness.SLOT_REVERSE]))
	if step.steer > 0:
		names.append(OS.get_keycode_string(keys[Harness.SLOT_STEER_LEFT]))
	if step.steer < 0:
		names.append(OS.get_keycode_string(keys[Harness.SLOT_STEER_RIGHT]))
	return "+".join(names)


## One SPLIT line with the distance moved, the drive speed and the yaw change of both Units.
func _print_summary(at: String, step: DriveStep) -> void:
	var first: UnitTrack = _tracks[Harness.PLAYER_1]
	var second: UnitTrack = _tracks[Harness.PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s at=%s keys=%s p1_moved=%.3f p1_speed=%.3f p1_yaw=%.1f "
		% [_harness.scenario, _harness.time(), step.label, at, _keys_text(step), first.moved(),
			first.unit.current_speed, rad_to_deg(first.yaw_total)]
		+ "p2_moved=%.3f p2_speed=%.3f p2_yaw=%.1f"
		% [second.moved(), second.unit.current_speed, rad_to_deg(second.yaw_total)])


## The four checks of one isolation phase. The driven Unit's numbers are those at the end of the
## hold; the other Unit's are those at the end of the phase, after the release as well.
func _check_phase(phase: DriveStep, held_moved: float, held_speed: float, held_yaw: float) -> void:
	var driven: UnitTrack = _tracks[phase.player]
	var other: UnitTrack = _tracks[1 - phase.player]
	var keys: String = _keys_text(phase)
	var reverse: bool = phase.throttle < 0
	var moves: bool = held_speed < 0.0 if reverse else held_moved > MOVE_MIN_DISTANCE
	_harness.check("%s.driven_moves" % phase.label, moves, "keys=%s held %.1f s: moved=%.3f m speed=%.3f m/s (%s)" % [
		keys, phase.seconds, held_moved, held_speed,
		"reverse: speed must be below 0" if reverse else "must move more than %.0f m" % MOVE_MIN_DISTANCE])
	var expected_sign: int = phase.steer * phase.throttle
	var turned: bool = false
	if expected_sign == 0:
		turned = absf(held_yaw) < STILL_YAW
	else:
		turned = signf(held_yaw) == float(expected_sign) and absf(held_yaw) >= MIN_TURN
	_harness.check("%s.driven_yaw" % phase.label, turned,
		"keys=%s: %s: steer %+d * sign(speed) %+d gives expected sign %+d (0 is straight); "
		% [keys, YAW_RULE, phase.steer, phase.throttle, expected_sign]
		+ "measured yaw change=%.3f rad (%.1f deg)" % [held_yaw, rad_to_deg(held_yaw)])
	var end_speed: float = driven.unit.current_speed
	_harness.check("%s.driven_released" % phase.label, absf(end_speed) < absf(held_speed),
		"keys released: |speed| %.3f m/s at the release, %.3f m/s %.1f s later (must be lower)" % [
			absf(held_speed), absf(end_speed), ISOLATION_RELEASE_SECONDS])
	var still: bool = other.moved() < STILL_DISTANCE and absf(other.yaw_total) < STILL_YAW \
		and is_zero_approx(other.unit.current_speed)
	_harness.check("%s.other_still" % phase.label, still,
		"the other Unit over the whole phase: moved=%.6f m (must be below %.3f) "
		% [other.moved(), STILL_DISTANCE]
		+ "yaw change=%.6f rad (below %.3f) speed=%.3f m/s"
		% [other.yaw_total, STILL_YAW, other.unit.current_speed])
