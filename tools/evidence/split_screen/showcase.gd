extends RefCounted
## Scenario showcase of the split screen evidence harness (split_screen_harness.gd): about 11 s in
## which both Players drive from the markers, pass each other, turn round, brake, reverse and coast,
## for the retained screenshots. Both Players give the same commands, so the two paths are mirror
## images through the centre of the field and the Units can meet only there. No checks: it ends by
## itself, and the RESULT line carries the closest approach of the two Units and the least room any
## Unit left to a wall (the runner's separation_min and wall_clearance_min).
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Test Evidence. Tooling
## only: nothing under src/ depends on this file.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/split.png --quit-after 700 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")

## Interval between progress lines, seconds.
const SHOWCASE_REPORT_SECONDS: float = 1.0

## The choreography, both Players giving the same commands: label, seconds, throttle (1 forward,
## -1 reverse), steer (1 left, -1 right). Idle at the markers, throttle, a gentle S-shaped pass
## (right, then left), a U-turn, a second pass, a weave, then brake, reverse, coast and rest. The
## same commands make the two paths mirror images through the centre of the field, so the Units can
## meet only there; the RESULT line reports the closest approach and the least wall clearance.
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

var _harness: Harness


## Drives SHOWCASE_PLAN with both Players at once and prints a progress line every
## SHOWCASE_REPORT_SECONDS. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_harness.report_ticks = _harness.ticks_in(SHOWCASE_REPORT_SECONDS)
	_harness.print_progress()
	for step: DriveStep in _steps():
		await _harness.run_step(step)
	_harness.finish("separation_min=%.2f wall_clearance_min=%.2f" % [
		_harness.separation_min, _harness.wall_clearance_min])


## The choreography as steps, both Players at once, from SHOWCASE_PLAN.
func _steps() -> Array[DriveStep]:
	var steps: Array[DriveStep] = []
	for row: Array in SHOWCASE_PLAN:
		steps.append(DriveStep.new(row[0], row[1], Harness.BOTH, row[2], row[3]))
	return steps
