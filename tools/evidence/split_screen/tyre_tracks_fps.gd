extends RefCounted
## Scenario tyre_tracks_fps of the split screen evidence harness (split_screen_harness.gd): AC-4's drawn-tyre clause and AC-5 of Story 026, measured windowed
## on the real renderer, the way rotors_fps.gd measures the rotors. Each Player chooses a type with the real keys; then WINDOWS windows of WINDOW_SECONDS each,
## both Units driving at full speed in circles, a Buggy for Player 1 and a Truck for Player 2 (four tyres each: the most strokes a tick), every window staged
## by a new pair of circles round the outer wrecks near each end of the salt flat (each circle's ring misses every solid of the Map: the CHECK clean_circles
## holds that no Unit touches anything but the ground): (1) the view from above, (2) the chase view, (3) the view from above again, (4) the chase view again. The
## track map is never cleared in between, so each window drives on a map that holds what the windows before made: the frame rate should not fall from the
## first window to the last, the cost does not grow with what has been driven. One SPLIT line per second with the frame rate, the longest frame of that
## second and the render totals of the frame, all viewports together; the first second, and every second in which a window is being staged (a Unit
## spawned, a camera stepped: TD-013's and TD-016's single frames of 10 to 19 ms), are left out of fps_min_steady and frame_ms_max_steady: quote those, and
## the raw maxima beside them. AC-5's budget is the lowest one-second rate at 60 or over, a frame of at most 16.6 ms and at most 1,000 draw calls; the GPU
## time with and without tracks is an observation (run it with --rendering-driver vulkan, which reads it on this Mac). Two CHECKs. never_ahead (AC-4): on
## every rendered frame of window 1, for each Player and each tyre, the newest stroke of that tyre ends at or behind the tyre as it is drawn (the Unit's
## get_global_transform_interpolated() with the tyre's place), measured along the way the Unit faces, so a track never runs ahead of its tyre; the least and
## most the track lags the drawn tyre are reported, metres. Written without any reference to the tracks' classes, so the same file runs on a tree without them
## (the A/B base): the node is read as `field.get("tyre_tracks")`, and TRACKS_FPS_OFF=1 (an environment variable of a run by hand) removes it from the tree
## at the start, which is the runner's strip: the ground shader then reads a strength of 0. Use neither --write-movie nor --headless, which measures the
## real renderer (fps.gd says how the display caps the rate). Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-4 and AC-5. Tooling
## only. Run: godot --path . --windowed --resolution 1280x720 res://tools/evidence/split_screen_harness.tscn -- --scenario=tyre_tracks_fps

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

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
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 600.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The windows: how many, how long, seconds (about a Round of driving in all).
const WINDOWS: int = 4
const WINDOW_SECONDS: float = 30.0
## Where each Player's Unit is put, facing east and west: Player 1's Buggy circles round WreckWestOuterSouth and Player 2's Truck round
## WreckEastOuterSouth, each wreck inside its ring (a circle's radius is the type's max_speed / turn_rate, 8.6 and 12.3 m, at any speed),
## and the rings miss every wreck, container, tank, wall, rock and ford; the salt flat's middle has no room for the Truck's circle.
const SPOT_1: Vector3 = Vector3(-77.0, 0.0, -6.5)
const SPOT_2: Vector3 = Vector3(80.0, 0.0, -9.5)
## The least a tyre's newest stroke may lag the tyre as drawn (never ahead of it, with a millimetre of slack), metres, and the least rendered frames to a
## tick that make window 1 a measure at all (a 120 Hz display gives two; under about 1.5 a frame draws a tick, and the interpolation cannot show).
const NEVER_AHEAD_SLACK: float = 0.001
const LEAST_FRAMES_PER_TICK: float = 1.5
## The speed above which a Unit is moving the way it faces, metres a second, for the probe.
const MOVING_SPEED: float = 1.0

var _k: Kit25
var _harness: Harness
var _q: Quick
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
## While true, the circles of a window are driven: the steering each Player holds.
var _circling: bool = false
## The ticks of the circles on which each Player's Unit touched anything but the ground (map_kit.gd's wall_contact()), and the ticks circled.
var _touched: Array[int] = [0, 0]
var _circled: int = 0
## The never-ahead probe of window 1: on while it is sampled, and what it saw: the frames, the physics ticks they spanned, the tyre-frames judged, the
## least and most the newest stroke lagged the drawn tyre along the Unit's way (negative: ahead), and the newest end of each Player's tyres.
var _probing: bool = false
var _probe_frames: int = 0
var _probe_ticks: int = 0
var _probe_judged: int = 0
var _probe_least: float = INF
var _probe_most: float = -INF
var _ends: Array[Dictionary] = [{}, {}]
## The Map's tracks node, or null when there is none (a tree without the feature, or TRACKS_FPS_OFF).
var _tracks: Node


## The choice, the windows sampled once a second from the first tick after it, then the RESULT line.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit25.new(harness)
	_q = _k.q()
	_tracks = _harness.split.field.get("tyre_tracks") as Node
	if _tracks != null and not OS.get_environment("TRACKS_FPS_OFF").is_empty():
		_tracks.get_parent().remove_child(_tracks)
		_tracks.free()
		_tracks = null
	await _k.k.swap().play(0, Quick.BUGGY)
	await _k.k.swap().play(1, Quick.TRUCK)
	_harness.get_tree().process_frame.connect(_on_frame)
	_start = _harness.ticks
	_q.kit.on_tick = _sample
	for window: int in WINDOWS:
		_harness.phase = StringName("window_%d" % (window + 1))
		_staging = true
		await _stage(window)
		_staging = false
		_probing = window == 0
		var ticks_before: int = _harness.ticks
		await _q.kit.advance(_harness.ticks_in(WINDOW_SECONDS))
		if _probing:
			_probe_ticks = _harness.ticks - ticks_before
		_probing = false
	_circling = false
	_q.harness.release_all()
	_q.kit.on_tick = Callable()
	_harness.get_tree().process_frame.disconnect(_on_frame)
	_finish()


## The Units and the views of a window (the class doc).
func _stage(window: int) -> void:
	_circling = false
	_q.harness.release_all()
	if window > 0:
		await _switch_views()
	await _q.map.stage([Quick.BUGGY, Quick.TRUCK], [SPOT_1, SPOT_2], [Vector3.RIGHT, Vector3.LEFT], true)
	_circling = true


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	await _q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await _q.kit.advance(Looks.VIEW_TICKS)


## Stamps each frame of the main loop, keeps the longest interval since the last sample, and samples the never-ahead probe.
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _stamp != 0:
		_worst_us = maxi(_worst_us, now - _stamp)
	_stamp = now
	if _probing and _tracks != null:
		_sample_tyres()


## The probe: for each Player's tyres, the newest stroke's end against the tyre as the renderer draws it, along the way the Unit faces.
func _sample_tyres() -> void:
	_probe_frames += 1
	for stroke: Object in _tracks.get("strokes"):
		(_ends[int(stroke.get("unit_index"))] as Dictionary)[int(stroke.get("tyre_index"))] = stroke.get("to")
	for player: int in 2:
		var unit: Unit = _q.units.units[player]
		var real: Vector3 = unit.get_real_velocity()
		if not unit.is_alive or Vector2(real.x, real.z).length() < MOVING_SPEED:
			continue
		var drawn: Transform3D = unit.get_global_transform_interpolated()
		var forward: Vector3 = -drawn.basis.z * signf(real.dot(-unit.global_transform.basis.z))
		var tyres: Array = unit.stats.get("tyres")
		for tyre_index: int in tyres.size():
			if not (_ends[player] as Dictionary).has(tyre_index):
				continue
			var offset: Vector2 = (tyres[tyre_index] as Object).get("offset")
			var place: Vector3 = drawn * Vector3(offset.x, 0.0, offset.y)
			var end: Vector2 = (_ends[player] as Dictionary)[tyre_index]
			var lag: float = (Vector2(place.x, place.z) - end).dot(Vector2(forward.x, forward.z))
			_probe_least = minf(_probe_least, lag)
			_probe_most = maxf(_probe_most, lag)
			_probe_judged += 1


## After every tick: the circles of a window are held, and once a second since the choice the frame rate, the longest frame of the second and the
## render totals of the frame, all viewports together, in a SPLIT line with the tracks' clock; the maxima are kept.
func _sample() -> void:
	if _circling:
		_q.harness.drive(0, 1, -1)
		_q.harness.drive(1, 1, 1)
		_circled += 1
		for player: int in _touched.size():
			_touched[player] += 1 if _q.map.wall_contact(_q.units.units[player]) else 0
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
	print("SPLIT %s t=%.3f phase=%s staging=%d fps=%.1f frame_ms_max=%.2f draw_calls=%d primitives=%d objects=%d clock=%.1f" % [
		_harness.scenario, _harness.time(), _harness.phase, 1 if _staging else 0, fps, worst_ms, draw_calls, primitives, objects, float(_tracks.get("now")) if _tracks != null else -1.0])


## The CHECK, then the RESULT line, as map_fps.gd's: the frame rate's average and minimum over every sample and over the steady ones (the first and those
## of a staging second left out), the longest frame over every sample and over the steady ones, the display's refresh rate, the most draw calls and
## primitives of a sampled frame, the samples, the windows and the display driver; and the average frame rate of the first window's steady samples against
## the last's.
func _finish() -> void:
	var problems: PackedStringArray = []
	var count: int = _fps.size()
	var totals: Vector2 = Vector2.ZERO
	var minima: Vector2 = Vector2(INF, INF)
	var longest: Vector2 = Vector2.ZERO
	var steady: int = 0
	var first_window: Vector2 = Vector2.ZERO
	var last_window: Vector2 = Vector2.ZERO
	var per_window: int = int(WINDOW_SECONDS / SAMPLE_SECONDS)
	for index: int in count:
		totals.x += _fps[index]
		minima.x = minf(minima.x, _fps[index])
		longest.x = maxf(longest.x, _frame_ms[index])
		if index > 0 and not _staging_flags[index]:
			steady += 1
			totals.y += _fps[index]
			minima.y = minf(minima.y, _fps[index])
			longest.y = maxf(longest.y, _frame_ms[index])
			if index <= per_window:
				first_window += Vector2(_fps[index], 1.0)
			if index >= count - per_window:
				last_window += Vector2(_fps[index], 1.0)
	var per_tick: float = float(_probe_frames) / float(maxi(_probe_ticks, 1))
	if _tracks != null:
		_q.kit.need(problems, per_tick >= LEAST_FRAMES_PER_TICK, "window 1 drew %d frames in %d ticks: %.2f a tick, under %.1f, so the display cannot show interpolation (the refresh rate is %.1f Hz)" % [_probe_frames, _probe_ticks, per_tick, LEAST_FRAMES_PER_TICK, DisplayServer.screen_get_refresh_rate()])
		_q.kit.need(problems, _probe_judged > 0 and _probe_least >= -NEVER_AHEAD_SLACK, "a track ended %.4f m ahead of its tyre as drawn (%d tyre-frames judged)" % [-_probe_least, _probe_judged])
		_q.kit.verdict("never_ahead", problems, "in window 1 (%d frames over %d ticks, %.2f a tick, on a display of %.1f Hz) the newest stroke of each tyre of both Units ended at or behind the tyre as the renderer drew it, along the way the Unit faces, on all %d tyre-frames judged: the track lagged it by %.4f to %.4f m" % [_probe_frames, _probe_ticks, per_tick, DisplayServer.screen_get_refresh_rate(), _probe_judged, _probe_least, _probe_most])
	var clean: PackedStringArray = []
	_q.kit.need(clean, _circled > 0 and _touched[0] == 0 and _touched[1] == 0, "over %d ticks of circles Player 1's Unit touched something but the ground on %d and Player 2's on %d" % [_circled, _touched[0], _touched[1]])
	_q.kit.verdict("clean_circles", clean, "in all %d windows both Units circled at full lock and full throttle, Player 1's Buggy and Player 2's Truck each round an outer wreck, and over %d ticks neither touched anything but the ground" % [WINDOWS, _circled])
	_k.close()
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f frame_ms_max=%.2f frame_ms_max_steady=%.2f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(steady, 1)), minima.x, minima.y, longest.x, longest.y,
			DisplayServer.screen_get_refresh_rate()]
		+ "fps_first_window=%.1f fps_last_window=%.1f draw_calls_max=%d primitives_max=%d samples=%d steady_samples=%d windows=%d tracks=%d display=%s" % [
			first_window.x / maxf(first_window.y, 1.0), last_window.x / maxf(last_window.y, 1.0), _draw_calls_max, _primitives_max, count, steady, WINDOWS, 1 if _tracks != null else 0, DisplayServer.get_name()])
