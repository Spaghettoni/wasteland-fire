extends RefCounted
## Scenario simultaneous of the split screen evidence harness (split_screen_harness.gd): AC-4 of
## Story 002, both layouts held at once in the corridors: W and Up for SIM_STRAIGHT_SECONDS, then W+A
## and Up+Right for SIM_STEER_SECONDS. A second run gives Player 1's keys alone from the same start,
## the reference for "the second Player does not disturb the first". Each check reads the tracks at
## the end of the stretch it is about, before the next stretch or the second run resets them.
## Prints a SPLIT line every SIM_REPORT_SECONDS, a result SPLIT line and four CHECK lines.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=simultaneous

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## Length of the straight stretch, seconds.
const SIM_STRAIGHT_SECONDS: float = 2.0
## Length of the steering stretch, seconds.
const SIM_STEER_SECONDS: float = 1.0
## Interval between the progress lines, seconds.
const SIM_REPORT_SECONDS: float = 0.25
## The share of max_speed both Units must reach.
const SIM_TOP_SPEED_SHARE: float = 0.9
## How closely Player 1's distance must match its solo run, metres.
const SIM_DISTANCE_TOLERANCE: float = 0.05
## How closely Player 1's yaw must match its solo run, radians.
const SIM_YAW_TOLERANCE: float = 0.02

## A driven Unit going forward must move more than this, metres.
const MOVE_MIN_DISTANCE: float = 5.0
## A turning Unit must turn at least this much, radians.
const MIN_TURN: float = 0.5

var _harness: Harness
var _split: SplitScreen
var _tracks: Array[UnitTrack] = []


## AC-4: both layouts held at once in the corridors, then Player 1's keys alone from the same start.
## The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_split = _harness.split
	_tracks = _harness.tracks
	await _harness.reset_to_corridors()
	_harness.report_ticks = _harness.ticks_in(SIM_REPORT_SECONDS)
	await _harness.run_step(DriveStep.new(&"both_straight", SIM_STRAIGHT_SECONDS, Harness.BOTH, 1, 0))
	_check_both_moved_at_once()
	var straight_yaw: Array[float] = [_tracks[Harness.PLAYER_1].yaw_total, _tracks[Harness.PLAYER_2].yaw_total]
	_harness.phase = &"both_steer"
	_harness.drive(Harness.PLAYER_1, 1, 1)
	_harness.drive(Harness.PLAYER_2, 1, -1)
	await _harness.advance(SIM_STEER_SECONDS)
	_harness.report_ticks = 0
	var top_speed: Array[float] = [_tracks[Harness.PLAYER_1].speed_max, _tracks[Harness.PLAYER_2].speed_max]
	var both_moved: float = _tracks[Harness.PLAYER_1].moved()
	var both_yaw: float = _tracks[Harness.PLAYER_1].yaw_total
	_check_both_reach_top_speed(top_speed)
	_check_yaw_signs_opposite(straight_yaw)
	await _harness.reset_to_corridors()
	await _harness.run_step(DriveStep.new(&"solo_straight", SIM_STRAIGHT_SECONDS, Harness.PLAYER_1, 1, 0))
	await _harness.run_step(DriveStep.new(&"solo_steer", SIM_STEER_SECONDS, Harness.PLAYER_1, 1, 1))
	_check_player_1_matches_solo(both_moved, both_yaw)
	_harness.finish("top_speed_1=%.3f top_speed_2=%.3f" % [top_speed[0], top_speed[1]])


## AC-4: after the straight stretch both Units have moved: W and Up held together drive both.
func _check_both_moved_at_once() -> void:
	var first: UnitTrack = _tracks[Harness.PLAYER_1]
	var second: UnitTrack = _tracks[Harness.PLAYER_2]
	_harness.check("both_moved_at_once", first.moved() > MOVE_MIN_DISTANCE and second.moved() > MOVE_MIN_DISTANCE,
		"after %.1f s of W and Up together: player_1 moved=%.3f m speed=%.3f m/s, "
		% [SIM_STRAIGHT_SECONDS, first.moved(), first.unit.current_speed]
		+ "player_2 moved=%.3f m speed=%.3f m/s (each must move more than %.0f m)"
		% [second.moved(), second.unit.current_speed, MOVE_MIN_DISTANCE])


## AC-4: over both stretches each Unit reached SIM_TOP_SPEED_SHARE of its max_speed. top_speed is
## the highest drive speed of each Unit, in the order of the Players.
func _check_both_reach_top_speed(top_speed: Array[float]) -> void:
	var max_speed: Array[float] = [_split.player_1_unit.stats.max_speed, _split.player_2_unit.stats.max_speed]
	var required: Array[float] = [SIM_TOP_SPEED_SHARE * max_speed[0], SIM_TOP_SPEED_SHARE * max_speed[1]]
	_harness.check("both_reach_top_speed", top_speed[0] >= required[0] and top_speed[1] >= required[1],
		"top speed player_1=%.3f m/s player_2=%.3f m/s, max_speed=%.1f m/s, "
		% [top_speed[0], top_speed[1], max_speed[0]]
		+ "required %.0f percent = %.3f m/s" % [SIM_TOP_SPEED_SHARE * 100.0, required[0]])


## AC-4: in the steering stretch Player 1 (W+A) turned left and Player 2 (Up+Right) turned right.
## straight_yaw is each track's yaw at the end of the straight stretch, in the order of the Players.
func _check_yaw_signs_opposite(straight_yaw: Array[float]) -> void:
	var steer_yaw: Array[float] = [
		_tracks[Harness.PLAYER_1].yaw_total - straight_yaw[0], _tracks[Harness.PLAYER_2].yaw_total - straight_yaw[1]]
	_harness.check("yaw_signs_opposite", steer_yaw[0] >= MIN_TURN and steer_yaw[1] <= -MIN_TURN,
		"steering second: player_1 (W+A) yaw change=%.3f rad (%.1f deg, must be left, +), "
		% [steer_yaw[0], rad_to_deg(steer_yaw[0])]
		+ "player_2 (Up+Right) yaw change=%.3f rad (%.1f deg, must be right, -)"
		% [steer_yaw[1], rad_to_deg(steer_yaw[1])])


## AC-4: Player 1's run with Player 2 driving equals its run alone, within SIM_DISTANCE_TOLERANCE
## and SIM_YAW_TOLERANCE. The tracks hold the solo run now; both_moved and both_yaw are what Player 1
## measured with Player 2 driving.
func _check_player_1_matches_solo(both_moved: float, both_yaw: float) -> void:
	var solo_moved: float = _tracks[Harness.PLAYER_1].moved()
	var solo_yaw: float = _tracks[Harness.PLAYER_1].yaw_total
	var distance_error: float = absf(both_moved - solo_moved)
	var yaw_error: float = absf(both_yaw - solo_yaw)
	print("SPLIT simultaneous t=%.3f phase=result p1_moved=%.3f p1_yaw=%.1f solo_moved=%.3f solo_yaw=%.1f" % [
		_harness.time(), both_moved, rad_to_deg(both_yaw), solo_moved, rad_to_deg(solo_yaw)])
	_harness.check("player_1_matches_solo", distance_error <= SIM_DISTANCE_TOLERANCE and yaw_error <= SIM_YAW_TOLERANCE,
		"player_1 with player_2 driving: moved=%.4f m yaw=%.4f rad; player_1 alone: moved=%.4f m yaw=%.4f rad; "
		% [both_moved, both_yaw, solo_moved, solo_yaw]
		+ "difference %.4f m (tolerance %.2f) and %.4f rad (tolerance %.2f)"
		% [distance_error, SIM_DISTANCE_TOLERANCE, yaw_error, SIM_YAW_TOLERANCE])
