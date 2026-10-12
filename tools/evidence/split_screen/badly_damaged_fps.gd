extends RefCounted
## Scenario badly_damaged_fps of the split screen evidence harness (split_screen_harness.gd): AC-4 of Story 017, the frame rate, the frame time and the draw
## calls of both views on Map 01 as the build ships it (the Flag Walls, the Turrets with their looks, the view from above) with BOTH Units badly damaged and
## smoking, each puff drawn in both views. WINDOWS windows, each: both Players choose again with the real keys, both Trucks (the larger box) are put down, the
## state begins in the odd windows (a tool brings both to their edge; the even ones are the controls with the Units whole), and the window is sampled for
## WINDOW_SECONDS: the pairs of windows are standing (facing each other 12 m apart: a column of smoke each) and moving (side by side on two lanes, at their
## half speed with the trail behind them, or at their full speed in the control). One SPLIT line per half second with the frame rate and the render totals of
## the frame (all viewports together and each Player's view), the puffs showing and the longest frame of the half second; the first sample of the run is left
## out of fps_min_steady and fps_avg_steady exactly as map_fps.gd and explosions_fps.gd do: quote those two. No pass or fail: the numbers are the evidence (the
## story asks for the lowest second at 60 fps or over, a frame of at most 16.6 ms and at most 1000 draw calls for both views together, and records what the
## smoke adds in each view). Not in the runner's GREYBOX_SCENARIOS: it runs on Map 01. Use neither --write-movie nor --headless, which measures the real
## renderer (fps.gd says how the display caps the rate). Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-4. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=badly_damaged_fps

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
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
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 400.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 0.5
## The windows (even: whole, the control; odd: badly damaged), the seconds before the state and the seconds sampled after.
const WINDOWS: int = 8
const BEFORE_SECONDS: float = 1.0
const WINDOW_SECONDS: float = 3.0
## Metres either side of the middle of the Map each Truck stands, the lanes of the moving pair and where they start.
const TRUCK_X: float = 6.0
const LANE_Z: float = 6.0
const START_X: float = 30.0
## Frames after the state's tick that count as "the first frames" of the Round's first state, and frames whose intervals each window prints.
const FIRST_FRAMES: int = 30
const FRAMES_PRINTED: int = 90

var _k: Kit17
var _harness: Harness
var _stamps: PackedFloat64Array = PackedFloat64Array()
var _fps: PackedFloat64Array = PackedFloat64Array()
## The most draw calls of a sampled frame, all viewports and then each Player's view, kept apart for the whole windows (control) and the badly damaged ones.
var _calls: Dictionary = {"control": [0, 0, 0], "smoke": [0, 0, 0]}
var _frame_ms_max: float = 0.0
var _first_ms: PackedStringArray = []
var _first_ms_max: float = 0.0
var _puffs_max: int = 0
var _window: int = 0
var _last_index: int = 0
var _samples: int = 0


## The windows, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit17.new(harness)
	_harness.get_tree().process_frame.connect(func() -> void: _stamps.append(float(Time.get_ticks_usec()) / 1000.0))
	await _k.e.t.w.s.both_play()
	for window: int in WINDOWS:
		_window = window
		_harness.phase = StringName("window_%d" % (window + 1))
		await _play_window()
	_finish()


## One window, see the class doc.
func _play_window() -> void:
	var moving: bool = (_window / 2) % 2 == 1
	var damaged: bool = _window % 2 == 1
	await _k.e.fresh()
	await _k.t.clear(0)
	if moving:
		_k.q.units.retype(0, Quick.TRUCK, Vector3(-START_X, 0.0, -LANE_Z), Vector3.RIGHT)
		_k.q.units.retype(1, Quick.TRUCK, Vector3(START_X, 0.0, LANE_Z), Vector3.LEFT)
	else:
		_k.q.units.retype(0, Quick.TRUCK, Vector3(-TRUCK_X, 0.0, 0.0), Vector3.RIGHT)
		_k.q.units.retype(1, Quick.TRUCK, Vector3(TRUCK_X, 0.0, 0.0), Vector3.LEFT)
	await _k.q.kit.advance(_harness.ticks_in(BEFORE_SECONDS))
	var at: int = _stamps.size()
	if damaged:
		for player: int in 2:
			_k.unit(player).apply_damage(_k.unit(player).hit_points - _k.edge_of(Quick.TRUCK))
	if moving:
		_harness.drive(0, 1, 0)
		_harness.drive(1, 1, 0)
	_last_index = _stamps.size()
	for _sample: int in roundi(WINDOW_SECONDS / SAMPLE_SECONDS):
		await _k.q.kit.advance(_harness.ticks_in(SAMPLE_SECONDS))
		_sample_now(damaged)
	_harness.release_all()
	_print_frames(at)
	if _window == 1:
		_keep_first(at)


## The frame intervals in milliseconds from the frame the state began in, the first FIRST_FRAMES of them: kept for the Round's first state.
func _keep_first(at: int) -> void:
	_first_ms.clear()
	for index: int in range(at, mini(at + FIRST_FRAMES, _stamps.size())):
		var gap: float = _stamps[index] - _stamps[index - 1]
		_first_ms.append("%.1f" % gap)
		_first_ms_max = maxf(_first_ms_max, gap)


## One SPLIT line with the frame intervals of the window, in milliseconds, from the frame the state began in (the control window's too).
func _print_frames(at: int) -> void:
	var gaps: PackedStringArray = []
	for index: int in range(at, mini(at + FRAMES_PRINTED, _stamps.size())):
		gaps.append("%.1f" % (_stamps[index] - _stamps[index - 1]))
	print("SPLIT %s t=%.3f phase=%s frames_ms_from_the_state_frame=%s" % [_harness.scenario, _harness.time(), _harness.phase, ",".join(gaps)])


## The draw calls of the frame in a Player's SubViewport.
func _view_calls(player: int) -> int:
	var viewport: RID = _k.q.units.cameras[player].get_viewport().get_viewport_rid()
	return RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)


## One SPLIT line: the frame rate, the render totals of the frame and of each view, the puffs showing and the longest frame since the last sample.
func _sample_now(damaged: bool) -> void:
	var fps: float = Engine.get_frames_per_second()
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var views: Array[int] = [_view_calls(0), _view_calls(1)]
	var worst: float = 0.0
	for index: int in range(maxi(_last_index, 1), _stamps.size()):
		worst = maxf(worst, _stamps[index] - _stamps[index - 1])
	_last_index = _stamps.size()
	var puffs: int = 0
	for player: int in 2:
		puffs += _k.smoke(player).shown_count() if damaged and _k.smoke(player) != null else 0
	_fps.append(fps)
	var kept: Array = _calls["smoke" if damaged else "control"]
	kept[0] = maxi(kept[0], draw_calls)
	kept[1] = maxi(kept[1], views[0])
	kept[2] = maxi(kept[2], views[1])
	_puffs_max = maxi(_puffs_max, puffs)
	_frame_ms_max = maxf(_frame_ms_max, worst) if _samples > 0 else _frame_ms_max
	_samples += 1
	print("SPLIT %s t=%.3f phase=%s fps=%.1f draw_calls=%d view1=%d view2=%d puffs=%d frame_ms_max=%.1f" % [
		_harness.scenario, _harness.time(), _harness.phase, fps, draw_calls, views[0], views[1], puffs, worst])


## The RESULT line: the frame rate's average and minimum over every sample and over the steady ones (the first left out), the longest frame of the
## steady samples in milliseconds, the longest of the first FIRST_FRAMES frames of the Round's first state, the display's refresh rate, the most draw
## calls of a sampled frame in the control windows and in the smoking ones (all viewports, then Player 1's view, then Player 2's), the most puffs showing
## and the display driver. No check.
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
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f frame_ms_max_steady=%.1f first_state_frame_ms_max=%.1f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(count - 1, 1)), minima.x, minima.y, _frame_ms_max, _first_ms_max,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_control_max=%s draw_calls_smoke_max=%s puffs_max=%d samples=%d windows=%d first_frames_ms=%s display=%s" % [
			_calls["control"], _calls["smoke"], _puffs_max, count, WINDOWS, ",".join(_first_ms), DisplayServer.get_name()])
