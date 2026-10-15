extends RefCounted
## Scenario fuel_building_fps of the split screen evidence harness (split_screen_harness.gd): AC-6 of Story 023, the frame rate, the longest
## frame and the draw calls of both views on Map 01 with the two Fuel zones drawn, the way turrets_fps measures them for the Turrets. Each
## Player chooses a Truck with the real keys. Then WINDOWS windows of WINDOW_SECONDS each, every Unit put down by the kit's put() with a low
## tank so the zones are working: (1) both Trucks south of the depot, the view from above (both zones, the tanks and the ring in both views),
## (2) each Truck in the zone on its side, the chase view, (3) each Player's Gyrocopter hovering over its zone, the chase view, and (4) a
## Motorbike and a Buggy side by side in the west zone, the view from above. One SPLIT line per second with the frame rate, the longest
## frame of that second and the render totals of the frame, all viewports together; the first second, and every second in which a window is
## being staged (a Unit spawned, a camera stepped: TD-013's 10 to 17 ms frames), are left out of fps_min_steady and frame_ms_max_steady
## (map_fps.gd leaves out the first): quote those, and the raw maxima beside them. No pass or fail: the numbers are the evidence (the budget is the lowest
## one-second rate at 60 or over, a frame of at most 16.6 ms and at most 1,000 draw calls). Use neither --write-movie nor --headless, which
## measures the real renderer (fps.gd says how the display caps the rate). Implements:
## production/epics/wasteland-fire/story-023-fuel-building.md AC-6. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=fuel_building_fps

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const FUEL_BUILDING: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 300.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The windows: how many, how long, seconds.
const WINDOWS: int = 4
const WINDOW_SECONDS: float = 6.0
## The share of a tank a Unit starts a window with, where the Trucks stand south of the depot, and the offset of the two Units side by side.
const LOW_TANK: float = 0.2
const SOUTH_OF_THE_DEPOT: Vector3 = Vector3(4.0, 0.0, 15.0)
const SIDE_BY_SIDE: float = 1.6

var _k: Kit23
var _harness: Harness
var _start: int = 0
var _fps: PackedFloat64Array = []
var _frame_ms: PackedFloat64Array = []
var _draw_calls_max: int = 0
var _primitives_max: int = 0
var _stamp: int = 0
var _worst_us: int = 0
## The samples that fell in a second a window was being staged in (one flag per sample).
var _staging_flags: Array[bool] = []
var _staging: bool = false


## The choice, the windows sampled once a second from the first tick after it, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit23.new(harness)
	var q: Quick = _k.q()
	await _k.a.swap().play(0, Quick.TRUCK)
	await _k.a.swap().play(1, Quick.TRUCK)
	_harness.get_tree().process_frame.connect(_on_frame)
	_start = _harness.ticks
	q.kit.on_tick = _sample
	for window: int in WINDOWS:
		_harness.phase = StringName("window_%d" % (window + 1))
		_staging = true
		await _stage(window)
		_staging = false
		await q.kit.advance(_harness.ticks_in(WINDOW_SECONDS))
	q.kit.on_tick = Callable()
	_harness.get_tree().process_frame.disconnect(_on_frame)
	_finish()


## The Units and the views of a window (the class doc).
func _stage(window: int) -> void:
	match window:
		0:
			await _k.put(0, Quick.TRUCK, Vector3(-SOUTH_OF_THE_DEPOT.x, 0.0, SOUTH_OF_THE_DEPOT.z), Vector3.FORWARD, LOW_TANK)
			await _k.put(1, Quick.TRUCK, SOUTH_OF_THE_DEPOT, Vector3.FORWARD, LOW_TANK)
			await _k.view(0, true)
			await _k.view(1, true)
		1:
			await _k.view(0, false)
			await _k.view(1, false)
			await _k.put(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, LOW_TANK)
			await _k.put(1, Quick.TRUCK, _k.centre(1), Vector3.LEFT, LOW_TANK)
		2:
			await _k.put(0, Quick.GYROCOPTER, _k.centre(0), Vector3.RIGHT, LOW_TANK)
			await _k.put(1, Quick.GYROCOPTER, _k.centre(1), Vector3.LEFT, LOW_TANK)
		3:
			await _k.view(0, true)
			await _k.view(1, true)
			await _k.put_many_recorded([
				{"player": 0, "type": Quick.MOTORBIKE, "at": _k.centre(0) + Vector3(0.0, 0.0, -SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": LOW_TANK},
				{"player": 1, "type": Quick.BUGGY, "at": _k.centre(0) + Vector3(0.0, 0.0, SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": LOW_TANK}], 1)


## Stamps each frame of the main loop and keeps the longest interval since the last sample.
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _stamp != 0:
		_worst_us = maxi(_worst_us, now - _stamp)
	_stamp = now


## After every tick: once a second since the choice, the frame rate, the longest frame of the second and the render totals of the frame,
## all viewports together, in a SPLIT line with both Units' Fuel; the maxima are kept.
func _sample() -> void:
	if (_harness.ticks - _start) % _harness.ticks_in(SAMPLE_SECONDS) != 0:
		return
	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var worst_ms: float = float(_worst_us) / 1000.0
	_worst_us = 0
	_fps.append(fps)
	_frame_ms.append(worst_ms)
	_staging_flags.append(_staging)
	_draw_calls_max = maxi(_draw_calls_max, draw_calls)
	_primitives_max = maxi(_primitives_max, primitives)
	print("SPLIT %s t=%.3f phase=%s staging=%d fps=%.1f frame_ms_max=%.2f draw_calls=%d primitives=%d objects=%d fuel_p1=%.1f fuel_p2=%.1f" % [
		_harness.scenario, _harness.time(), _harness.phase, 1 if _staging else 0, fps, worst_ms, draw_calls, primitives, objects, _k.unit(0).fuel, _k.unit(1).fuel])


## The RESULT line, as map_fps.gd's: the frame rate's average and minimum over every sample and over the steady ones (the first and those of
## a staging second left out),
## the longest frame over every sample and over the steady ones, the display's refresh rate, the most draw calls and primitives of a sampled
## frame, the samples, the windows and the display driver. No check.
func _finish() -> void:
	var count: int = _fps.size()
	var totals: Vector2 = Vector2.ZERO
	var minima: Vector2 = Vector2(INF, INF)
	var longest: Vector2 = Vector2.ZERO
	var steady: int = 0
	for index: int in count:
		totals.x += _fps[index]
		minima.x = minf(minima.x, _fps[index])
		longest.x = maxf(longest.x, _frame_ms[index])
		if index > 0 and not _staging_flags[index]:
			steady += 1
			totals.y += _fps[index]
			minima.y = minf(minima.y, _fps[index])
			longest.y = maxf(longest.y, _frame_ms[index])
	_k.close()
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f frame_ms_max=%.2f frame_ms_max_steady=%.2f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(steady, 1)), minima.x, minima.y, longest.x, longest.y,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d steady_samples=%d windows=%d display=%s" % [
			_draw_calls_max, _primitives_max, count, steady, WINDOWS, DisplayServer.get_name()])
