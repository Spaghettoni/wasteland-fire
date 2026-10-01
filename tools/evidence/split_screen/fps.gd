extends RefCounted
## Scenario fps of the split screen evidence harness (split_screen_harness.gd): AC-7 of Story 002,
## both Players at full throttle steering left for FPS_SECONDS, which is about four circles of 8.6 m
## radius (max_speed / turn_rate = 24 / 2.8, so 17 m across; the field is 80 m across). One line per
## second with the frame rate and the render totals of the frame, all viewports together. No pass or
## fail: the numbers are the evidence. The first sample covers start-up (window, shader compilation),
## so fps_min_steady and fps_avg_steady leave it out: quote those two.
##
## Use neither --write-movie nor --headless for it, which measures the real renderer. The display
## caps the rate: on the dev Mac (Apple M4 Pro, Metal, macOS 26.5.2, a 120 Hz display) a windowed run
## stays at 120 fps with --disable-vsync too (fps_avg_steady 120.1, against 120.0 with vsync on), so
## headroom over 60 fps cannot be measured there; the frame rate and the draw-call totals are what
## the run gives. Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=fps
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria.
## Tooling only: nothing under src/ depends on this file.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")

## Length of the scenario in seconds; one sample per second.
const FPS_SECONDS: int = 10

var _harness: Harness


## AC-7: both Players at full throttle steering left for FPS_SECONDS; one line per second with the
## frame rate and the render totals, then the RESULT line with the averages and the worst frame. No
## check. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_harness.apply(DriveStep.new(&"circle", float(FPS_SECONDS), Harness.BOTH, 1, 1))
	var fps_total: float = 0.0
	var fps_total_steady: float = 0.0
	var fps_min: float = INF
	var fps_min_steady: float = INF
	var draw_calls_max: int = 0
	var primitives_max: int = 0
	for second: int in FPS_SECONDS:
		await _harness.advance(1.0)
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
			_harness.time(), fps, draw_calls, primitives, objects])
	var steady_seconds: int = maxi(FPS_SECONDS - 1, 1)
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f refresh_hz=%.1f " % [
			fps_total / float(FPS_SECONDS), fps_total_steady / float(steady_seconds), fps_min,
			fps_min_steady, DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d display=%s" % [
			draw_calls_max, primitives_max, FPS_SECONDS, DisplayServer.get_name()])
