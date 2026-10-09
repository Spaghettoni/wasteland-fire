extends RefCounted
## Scenario turrets_fps of the split screen evidence harness (split_screen_harness.gd): AC-8 of Story
## 013, the frame rate and the draw calls of both views on Map 01 with the Flag Walls and the
## Turrets in, while both Players' Trucks stand in the view from above in front of the other Player's
## Gate under both of its Turrets' fire. Each Player chooses the Truck with the real keys. Then
## WINDOWS windows of WINDOW_SECONDS each: both Trucks are put down in front of the other Player's
## Gate on its axis, TRUCK_OUT metres out of the Turrets' line, with full hit points and a full tank
## (a tool may: map_kit.gd's stage()), and the four Turrets aim at them and fire at their cadence for
## the window, which is shorter than a Truck's life there (220 hit points against 2 x 12 every 0.8 s,
## about 7.3 s); every Turret is brought back whole between windows. One SPLIT line per second with the
## frame rate and the render totals of the frame, all viewports together; the first second is left out
## of fps_min_steady and fps_avg_steady exactly as map_fps.gd does: quote those two. No pass or fail:
## the numbers are the evidence (the story asks for the lowest second at 60 or over and at most 1000
## draw calls). Not in the runner's GREYBOX_SCENARIOS: it runs on Map 01. Use neither --write-movie
## nor --headless, which measures the real renderer (fps.gd says how the display caps the rate).
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-8. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=turrets_fps

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It measures the camera the build ships with, the Flag Walls and the Turrets.
const SHIPPED_CAMERA: bool = true
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 200.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The windows: how many, how long, seconds.
const WINDOWS: int = 4
const WINDOW_SECONDS: float = 5.0
## Where a Truck stands, metres out of the Turrets' line (Base-local z -19) on the Gate's axis: in
## sight and in reach of both Turrets of the Base it faces.
const TRUCK_OUT: float = 8.0

var _k: Kit13
var _harness: Harness
var _start: int = 0
var _fps: PackedFloat64Array = []
var _draw_calls_max: int = 0
var _primitives_max: int = 0
var _hits: int = 0


## The choice, the windows sampled once a second from the first tick after it, then the RESULT line.
## The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit13.new(harness)
	var q: Quick = _k.w.s.q
	await _k.w.s.play(0, Quick.TRUCK)
	await _k.w.s.play(1, Quick.TRUCK)
	_start = _harness.ticks
	q.kit.on_tick = _sample
	for window: int in WINDOWS:
		_harness.phase = StringName("window_%d" % (window + 1))
		await _restage()
		await q.kit.advance(_harness.ticks_in(WINDOW_SECONDS))
	q.kit.on_tick = Callable()
	_finish()


## Both Trucks put down in front of the other Player's Gate with full hit points and a full tank,
## every Turret whole again. A coroutine.
func _restage() -> void:
	var q: Quick = _k.w.s.q
	for turret: Turret in _k.all():
		turret.restore()
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		var base_index: int = 1 - player
		spots.append(_k.w.point(base_index, Vector3(0.0, 0.0, Kit13.PLACES[0].z - TRUCK_OUT)))
		facings.append(-_k.w.way(base_index, Vector3.FORWARD))
	await q.map.stage([Quick.TRUCK, Quick.TRUCK], spots, facings, true)


## After every tick: once a second since the choice, the frame rate and the render totals of the
## frame, all viewports together, in a SPLIT line with both Trucks' hit points; the maxima are kept.
func _sample() -> void:
	if (_harness.ticks - _start) % _harness.ticks_in(SAMPLE_SECONDS) != 0:
		return
	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_fps.append(fps)
	_draw_calls_max = maxi(_draw_calls_max, draw_calls)
	_primitives_max = maxi(_primitives_max, primitives)
	var units: Array[Unit] = _k.w.s.q.units.units
	_hits = _k.firing.size()
	print("SPLIT %s t=%.3f phase=%s fps=%.1f draw_calls=%d primitives=%d objects=%d p1_hp=%.0f p2_hp=%.0f turret_shots=%d" % [
		_harness.scenario, _harness.time(), _harness.phase, fps, draw_calls, primitives, objects,
		units[0].hit_points, units[1].hit_points, _hits])


## The RESULT line, as map_fps.gd's: the frame rate's average and minimum over every sample and over
## the steady ones (the first left out), the display's refresh rate, the most draw calls and
## primitives of a sampled frame, the samples, the windows, the Turrets' Shots and the display
## driver. No check.
func _finish() -> void:
	var count: int = _fps.size()
	var totals: Vector2 = Vector2.ZERO
	var minima: Vector2 = Vector2(INF, INF)
	for index: int in count:
		totals.x += _fps[index]
		minima.x = minf(minima.x, _fps[index])
		if index > 0:
			totals.y += _fps[index]
			minima.y = minf(minima.y, _fps[index])
	var shots: int = _k.firing.size()
	_k.close()
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(count - 1, 1)), minima.x, minima.y,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d windows=%d turret_shots=%d display=%s" % [
			_draw_calls_max, _primitives_max, count, WINDOWS, shots, DisplayServer.get_name()])
