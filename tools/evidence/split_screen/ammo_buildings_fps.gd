extends RefCounted
## Scenario ammo_buildings_fps of the split screen evidence harness (split_screen_harness.gd): AC-5 of Story 024, the frame rate, the longest
## frame and the draw calls of both views on Map 01 with both ammunition buildings and all four zones drawn, the way fuel_building_fps
## measures them for the Fuel building. Each Player chooses a Truck with the real keys. Then WINDOWS windows of WINDOW_SECONDS each, every
## Unit put down by the kit with its gun emptied so the zones are working: (1) both Trucks short of the ammunition zone on their side, the
## view from above (both buildings and zones in both views), (2) each Truck in its ammunition zone, the chase view, (3) each Player's
## Gyrocopter hovering over its ammunition zone, the chase view, and (4) Player 1's Truck in the depot's west Fuel zone and Player 2's in
## the east ammunition zone, the view from above (both kinds drawn). One SPLIT line per second with the frame rate, the longest frame of
## that second and the render totals of the frame, all viewports together; the first second, and every second in which a window is being
## staged (a Unit spawned, a camera stepped: TD-013's 10 to 17 ms frames), are left out of fps_min_steady and frame_ms_max_steady
## (map_fps.gd leaves out the first): quote those, and the raw maxima beside them. No pass or fail: the numbers are the evidence (the budget
## is the lowest one-second rate at 60 or over, a frame of at most 16.6 ms and at most 1,000 draw calls). Use neither --write-movie nor
## --headless, which measures the real renderer (fps.gd says how the display caps the rate). Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-5. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo_buildings_fps

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")
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
const AMMO_BUILDINGS: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 300.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The windows: how many, how long, seconds.
const WINDOWS: int = 4
const WINDOW_SECONDS: float = 6.0
## How far short of an ammunition zone's centre-side face a Truck stands in the first window, metres.
const SHORT_OF_THE_FACE: float = 6.0

var _k: Kit24
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
	_k = Kit24.new(harness)
	var q: Quick = _k.q()
	await _k.a().swap().play(0, Quick.TRUCK)
	await _k.a().swap().play(1, Quick.TRUCK)
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


## A Player's Unit of a type put at a place facing a way with its gun emptied (the Weapon's count set to nought and reported).
func _put_empty(player: int, type_index: int, at: Vector3, facing: Vector3) -> void:
	await _k.f.put(player, type_index, at, facing, 1.0)
	var gun: Weapon = _k.gun(player)
	gun.set(&"_left", 0)
	gun.ammo_changed.emit(0, gun.capacity)


## The facing toward the building of the Player's side: Player 1 west, Player 2 east.
func _toward(player: int) -> Vector3:
	return Vector3.LEFT if player == 0 else Vector3.RIGHT


## The Units and the views of a window (the class doc).
func _stage(window: int) -> void:
	match window:
		0:
			for player: int in 2:
				var index: int = _k.ammo_index(player)
				await _put_empty(player, Quick.TRUCK, _k.centre(index) - _toward(player) * (_k.zone(index).size.x / 2.0 + SHORT_OF_THE_FACE), _toward(player))
			await _k.view(0, true)
			await _k.view(1, true)
		1:
			await _k.view(0, false)
			await _k.view(1, false)
			for player: int in 2:
				await _put_empty(player, Quick.TRUCK, _k.centre(_k.ammo_index(player)), _toward(player))
		2:
			for player: int in 2:
				await _put_empty(player, Quick.GYROCOPTER, _k.centre(_k.ammo_index(player)), _toward(player))
		3:
			await _k.view(0, true)
			await _k.view(1, true)
			await _put_empty(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT)
			await _put_empty(1, Quick.TRUCK, _k.centre(_k.ammo_index(1)), Vector3.RIGHT)


## Stamps each frame of the main loop and keeps the longest interval since the last sample.
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _stamp != 0:
		_worst_us = maxi(_worst_us, now - _stamp)
	_stamp = now


## After every tick: once a second since the choice, the frame rate, the longest frame of the second and the render totals of the frame,
## all viewports together, in a SPLIT line with both Units' Shots; the maxima are kept.
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
	print("SPLIT %s t=%.3f phase=%s staging=%d fps=%.1f frame_ms_max=%.2f draw_calls=%d primitives=%d objects=%d shots_p1=%d shots_p2=%d" % [
		_harness.scenario, _harness.time(), _harness.phase, 1 if _staging else 0, fps, worst_ms, draw_calls, primitives, objects, _k.gun(0).shots_left, _k.gun(1).shots_left])


## The RESULT line, as map_fps.gd's: the frame rate's average and minimum over every sample and over the steady ones (the first and those of
## a staging second left out), the longest frame over every sample and over the steady ones, the display's refresh rate, the most draw calls
## and primitives of a sampled frame, the samples, the windows and the display driver. No check.
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
