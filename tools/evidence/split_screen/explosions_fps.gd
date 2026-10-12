extends RefCounted
## Scenario explosions_fps of the split screen evidence harness (split_screen_harness.gd): AC-8 of Story 016, the frame
## rate, the frame time and the draw calls of both views on Map 01 as the build ships it (the Flag Walls, the Turrets with
## their looks, the view from above) with THREE explosions playing at once, each drawn in both views: both Players'
## Trucks (the largest box) destroyed by a tool's destroy() in the same tick as a third Explosion the tool adds beside
## them (only two Units exist, so a third at once needs the tool). WINDOWS windows, each: both Players choose again with
## the real keys (a destruction costs a Token and the controller must see a Unit alive to count the next one), both
## Trucks are put down facing each other 12 m apart in the open, EXPLODE_AFTER_SECONDS pass, then both are destroyed
## and the third explosion added and the window is sampled for WINDOW_SECONDS. The first window is a control with no
## explosion; the second holds the Round's first explosion, whose frame times are kept apart. One SPLIT line per half
## second with the frame rate and the render totals of the frame, all viewports together, the explosions playing and the
## longest frame of the half second; the first sample of the run is left out of fps_min_steady and fps_avg_steady exactly
## as map_fps.gd, turrets_fps.gd and turret_looks_fps.gd do: quote those two. No pass or fail: the numbers are the
## evidence (the story asks for the lowest second at 60 fps or over, a frame of at most 16.6 ms and at most 1000 draw
## calls). Not in the runner's GREYBOX_SCENARIOS: it runs on Map 01. Use neither --write-movie nor --headless, which
## measures the real renderer (fps.gd says how the display caps the rate). Implements:
## production/epics/wasteland-fire/story-016-unit-explosions.md AC-8. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=explosions_fps

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 016 helpers (explosions_kit.gd).
const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 300.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 0.5
## The windows (the first without an explosion), the seconds before the explosions and the seconds sampled after.
const WINDOWS: int = 8
const EXPLODE_AFTER_SECONDS: float = 1.0
const WINDOW_SECONDS: float = 2.5
## Metres either side of the middle of the Map each Truck stands, and where the third explosion is added (x, z).
const TRUCK_X: float = 6.0
const THIRD_AT: Vector2 = Vector2(0.0, 6.0)
## Frames after the explosions' tick that count as "the first frames" of the Round's first explosion.
const FIRST_FRAMES: int = 30
## Frames whose intervals each window prints.
const FRAMES_PRINTED: int = 90

var _k: Kit16
var _harness: Harness
var _stamps: PackedFloat64Array = PackedFloat64Array()
var _fps: PackedFloat64Array = PackedFloat64Array()
var _draw_calls_max: int = 0
var _draw_calls_control_max: int = 0
var _primitives_max: int = 0
var _frame_ms_max: float = 0.0
var _first_ms: PackedStringArray = []
var _first_ms_max: float = 0.0
var _explosions_max: int = 0
var _window: int = 0
var _last_index: int = 0
var _samples: int = 0


## The windows, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit16.new(harness)
	_harness.get_tree().process_frame.connect(func() -> void: _stamps.append(float(Time.get_ticks_usec()) / 1000.0))
	await _k.t.w.s.both_play()
	for window: int in WINDOWS:
		_window = window
		_harness.phase = StringName("window_%d" % (window + 1))
		await _play_window()
	_finish()


## One window: the Players choose again, the Trucks are put down, the explosions come (not in the control window) and the
## stretch after them is sampled every SAMPLE_SECONDS.
func _play_window() -> void:
	await _k.fresh()
	await _k.t.clear(0)
	_k.q.units.retype(0, Quick.TRUCK, Vector3(-TRUCK_X, 0.0, 0.0), Vector3.RIGHT)
	_k.q.units.retype(1, Quick.TRUCK, Vector3(TRUCK_X, 0.0, 0.0), Vector3.LEFT)
	await _k.q.kit.advance(_harness.ticks_in(EXPLODE_AFTER_SECONDS))
	var at: int = _stamps.size()
	if _window > 0:
		_explode()
	_last_index = _stamps.size()
	var samples: int = roundi(WINDOW_SECONDS / SAMPLE_SECONDS)
	for _sample: int in samples:
		await _k.q.kit.advance(_harness.ticks_in(SAMPLE_SECONDS))
		_sample_now()
	_print_frames(at)
	if _window == 1:
		_keep_first(at)


## Both Trucks are destroyed by a tool and a third Explosion is added beside them, in one tick: three at once.
func _explode() -> void:
	var units: Array[Unit] = _k.q.units.units
	for unit: Unit in units:
		unit.destroy()
	var blast: Explosion = (_harness.split.explosion_scene.instantiate()) as Explosion
	var stats: UnitStats = _k.q.units.stats(Quick.TRUCK)
	units[0].get_parent().add_child(blast)
	blast.blast(Vector3(THIRD_AT.x, stats.collision_center.y, THIRD_AT.y), maxf(stats.collision_size.x, stats.collision_size.z), 0.0)


## The frame intervals in milliseconds from the frame the explosions came on (the interval that ends with the first frame
## after the tick they were made in), the first FIRST_FRAMES of them: kept for the Round's first explosions.
func _keep_first(at: int) -> void:
	_first_ms.clear()
	for index: int in range(at, mini(at + FIRST_FRAMES, _stamps.size())):
		var gap: float = _stamps[index] - _stamps[index - 1]
		_first_ms.append("%.1f" % gap)
		_first_ms_max = maxf(_first_ms_max, gap)


## One SPLIT line with the frame intervals of the window, in milliseconds, from the frame the explosions came on (the
## control window's too, from the same moment): a hitch shows by the frame it is on.
func _print_frames(at: int) -> void:
	var gaps: PackedStringArray = []
	for index: int in range(at, mini(at + FRAMES_PRINTED, _stamps.size())):
		gaps.append("%.1f" % (_stamps[index] - _stamps[index - 1]))
	print("SPLIT %s t=%.3f phase=%s frames_ms_from_the_explosions_frame=%s" % [_harness.scenario, _harness.time(), _harness.phase, ",".join(gaps)])


## One SPLIT line: the frame rate and the render totals of the frame, the explosions playing and the longest frame of the
## stretch since the last sample.
func _sample_now() -> void:
	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var worst: float = 0.0
	for index: int in range(maxi(_last_index, 1), _stamps.size()):
		worst = maxf(worst, _stamps[index] - _stamps[index - 1])
	_last_index = _stamps.size()
	var playing: int = _k.playing().size()
	_fps.append(fps)
	_draw_calls_max = maxi(_draw_calls_max, draw_calls)
	_primitives_max = maxi(_primitives_max, primitives)
	_frame_ms_max = maxf(_frame_ms_max, worst) if _samples > 0 else _frame_ms_max
	_explosions_max = maxi(_explosions_max, playing)
	if _window == 0:
		_draw_calls_control_max = maxi(_draw_calls_control_max, draw_calls)
	_samples += 1
	print("SPLIT %s t=%.3f phase=%s fps=%.1f draw_calls=%d primitives=%d objects=%d explosions=%d frame_ms_max=%.1f" % [
		_harness.scenario, _harness.time(), _harness.phase, fps, draw_calls, primitives, objects, playing, worst])


## The RESULT line: the frame rate's average and minimum over every sample and over the steady ones (the first left out),
## the longest frame of the steady samples in milliseconds, the longest of the first FIRST_FRAMES frames of the Round's
## first explosions, the display's refresh rate, the most draw calls and primitives of a sampled frame and of the control
## window, the most explosions playing at once and the display driver. No check.
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
	_k.close()
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f frame_ms_max_steady=%.1f first_explosion_frame_ms_max=%.1f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(count - 1, 1)), minima.x, minima.y, _frame_ms_max, _first_ms_max,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d draw_calls_control_max=%d primitives_max=%d explosions_max=%d samples=%d windows=%d first_frames_ms=%s display=%s" % [
			_draw_calls_max, _draw_calls_control_max, _primitives_max, _explosions_max, count, WINDOWS, ",".join(_first_ms), DisplayServer.get_name()])
