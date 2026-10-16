extends RefCounted
## Scenario rotors_fps of the split screen evidence harness (split_screen_harness.gd): AC-4's drawn-between-ticks clause and AC-7 of
## Story 025, measured windowed on the real renderer: two Gyrocopters with their rotors and propellers turning, in both views, the way
## ammo_buildings_fps measures the ammunition buildings. Each Player chooses a Gyrocopter with the real keys. Then WINDOWS windows of
## WINDOW_SECONDS each: (1) both standing in the open, the view from above, (2) both flying at full speed in circles, the chase view,
## (3) the same circles from above, (4) both standing, the chase view; after them a Swap and a new Gyrocopter for each Player, where
## the frame of a new model's first appearance is read. One SPLIT line per second with the frame rate, the longest frame of that
## second and the render totals of the frame, all viewports together; the first second, and every second in which a window is being
## staged (a Unit spawned, a camera stepped: TD-013's and TD-016's single frames of 10 to 19 ms), are left out of fps_min_steady and
## frame_ms_max_steady (map_fps.gd leaves out the first): quote those, and the raw maxima beside them. The numbers are the evidence
## of AC-7 (the budget is the lowest one-second rate at 60 or over, a frame of at most 16.6 ms and at most 1,000 draw calls; the
## draw calls the parts and smears add and the first appearance's frame are observations beside TD-016 and TD-017, never
## thresholds): the same run with ROTORS taken off in a copy of this file is the A/B. One CHECK, interpolated (AC-4): in window 1 on
## every rendered frame the drawn pose of each rotor (Node3D.get_global_transform_interpolated(), what the renderer draws) is the
## pose between its last two ticks at the engine's interpolation fraction, so the rotor is drawn at a new angle on every frame of a
## 120 Hz display and not on every second one, and each frame advances it by a share of the step. Use neither --write-movie nor
## --headless, which measures the real renderer (fps.gd says how the display caps the rate). Implements:
## production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-4 and AC-7. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=rotors_fps

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
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 300.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The windows: how many, how long, seconds.
const WINDOWS: int = 4
const WINDOW_SECONDS: float = 6.0
## Where each Player's Gyrocopter is put: the open middle of the Map, clear of both Bases' Turrets, 30 m either side of its middle.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## What the interpolated pose of a rotor may differ from the pose between its last two ticks by, radians, the least share of a tick's
## step a frame must advance it by, and the least rendered frames to a tick that make the window a measure at all (a 120 Hz display
## gives two; under about 1.5 a frame draws a tick, and the interpolation cannot show).
const POSE_TOLERANCE: float = 0.02
const LEAST_ADVANCE_SHARE: float = 0.05
const LEAST_FRAMES_PER_TICK: float = 1.5
## Ticks after a spawn in which the frame of a new model's first appearance is read.
const APPEARANCE_TICKS: int = 12

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
## While true, the circles of the flying windows are flown: the steering each Player holds.
var _circling: bool = false
## The interpolation probe of window 1: on while it is sampled, and what it saw: the frames, the physics ticks they spanned, the
## worst distance of a drawn pose from the pose between the last two ticks, the frames that drew a rotor at the angle of the frame
## before (stalls) and the least and most a frame advanced it, radians.
var _probing: bool = false
var _probe_frames: int = 0
var _probe_ticks: int = 0
var _probe_worst: float = 0.0
var _probe_stalls: int = 0
var _probe_least: float = INF
var _probe_most: float = 0.0
var _probe_last: Array[float] = [NAN, NAN]
## The worst frame in the ticks right after a new model first appeared, milliseconds.
var _appearance_ms: float = 0.0
var _appearing: bool = false
var _appearing_left: int = 0


## The choice, the windows sampled once a second from the first tick after it, the appearance of new models, then the RESULT line.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit25.new(harness)
	_q = _k.q()
	for player: int in 2:
		await _k.k.swap().play(player, Quick.GYROCOPTER)
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
	_harness.phase = &"appearance"
	_staging = true
	await _appear()
	_staging = false
	_q.kit.on_tick = Callable()
	_harness.get_tree().process_frame.disconnect(_on_frame)
	_finish()


## The Units and the views of a window (the class doc).
func _stage(window: int) -> void:
	_circling = false
	_q.harness.release_all()
	match window:
		0:
			await _put_pair(false)
		1:
			await _switch_views()
			await _put_pair(true)
		2:
			await _switch_views()
			await _put_pair(true)
		3:
			await _switch_views()
			await _put_pair(false)


## Both Gyrocopters staged in the open (Player 2 at the mirror), standing or about to circle at full throttle.
func _put_pair(circle: bool) -> void:
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], [OPEN, Vector3(-OPEN.x, OPEN.y, OPEN.z)], [Vector3.RIGHT, Vector3.LEFT], true)
	_circling = circle


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	await _q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await _q.kit.advance(Looks.VIEW_TICKS)


## Both Players destroy their Gyrocopter and choose a new one: the frame of each new model's first appearance is the longest frame
## in the APPEARANCE_TICKS ticks after the controller put it in play (_on_spawned()).
func _appear() -> void:
	await _q.tokens.destruct(0)
	await _q.tokens.destruct(1)
	await _q.kit.advance(_harness.ticks_in(1.0))
	_appearance_ms = 0.0
	_q.controller.unit_spawned.connect(_on_spawned)
	await _q.tokens.spawn(0, Quick.GYROCOPTER)
	await _q.kit.advance(APPEARANCE_TICKS)
	await _q.tokens.spawn(1, Quick.GYROCOPTER)
	await _q.kit.advance(APPEARANCE_TICKS)
	_q.controller.unit_spawned.disconnect(_on_spawned)


## A Unit was put in play: the frames of the next APPEARANCE_TICKS ticks are the new model's first.
func _on_spawned(_player: int) -> void:
	_appearing = true
	_appearing_left = APPEARANCE_TICKS


## Stamps each frame of the main loop, keeps the longest interval since the last sample, and samples the interpolation probe.
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _stamp != 0:
		_worst_us = maxi(_worst_us, now - _stamp)
		if _appearing:
			_appearance_ms = maxf(_appearance_ms, float(now - _stamp) / 1000.0)
	_stamp = now
	if _probing:
		_sample_pose()


## The probe: for each Player's rotor, the pose the renderer draws against the pose between its last two ticks.
func _sample_pose() -> void:
	_probe_frames += 1
	var step: float = TAU * _k.settings().parts[0].full_turns_per_second / Engine.physics_ticks_per_second
	var fraction: float = Engine.get_physics_interpolation_fraction()
	for player: int in 2:
		var pivot: RotorPivot = _k.pivot_of(player, "Rotor")
		var model: Node3D = _k.model_of(player)
		if pivot == null or model == null:
			continue
		var mesh: Node3D = pivot.get_node_or_null("RotorAccent") as Node3D
		var drawn: Basis = (model.get_global_transform_interpolated().affine_inverse() * mesh.get_global_transform_interpolated()).basis
		var turned: Quaternion = drawn.orthonormalized().get_rotation_quaternion()
		var angle: float = turned.get_angle() * (1.0 if turned.get_axis().dot(pivot.part.axis_direction()) >= 0.0 else -1.0)
		var between: float = wrapf(pivot.angle - (1.0 - fraction) * step, -PI, PI)
		_probe_worst = maxf(_probe_worst, absf(wrapf(angle - between, -PI, PI)))
		if not is_nan(_probe_last[player]):
			var advanced: float = wrapf(angle - _probe_last[player], -PI, PI)
			if absf(advanced) < step * LEAST_ADVANCE_SHARE:
				_probe_stalls += 1
			_probe_least = minf(_probe_least, absf(advanced))
			_probe_most = maxf(_probe_most, absf(advanced))
		_probe_last[player] = angle


## After every tick: the circles of a flying window are held, and once a second since the choice the frame rate, the longest frame of
## the second and the render totals of the frame, all viewports together, in a SPLIT line with the rotors' angles; the maxima are kept.
func _sample() -> void:
	if _appearing:
		_appearing_left -= 1
		_appearing = _appearing_left > 0
	if _circling:
		_q.harness.drive(0, 1, 1)
		_q.harness.drive(1, 1, -1)
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
	var rotor: RotorPivot = _k.pivot_of(0, "Rotor")
	print("SPLIT %s t=%.3f phase=%s staging=%d fps=%.1f frame_ms_max=%.2f draw_calls=%d primitives=%d objects=%d rotor_deg=%.1f" % [
		_harness.scenario, _harness.time(), _harness.phase, 1 if _staging else 0, fps, worst_ms, draw_calls, primitives, objects, rad_to_deg(rotor.angle) if rotor != null else -1.0])


## The CHECK, then the RESULT line, as map_fps.gd's: the frame rate's average and minimum over every sample and over the steady ones (the
## first and those of a staging second left out), the longest frame over every sample and over the steady ones, the display's refresh
## rate, the most draw calls and primitives of a sampled frame, the first appearance's worst frame, the samples, the windows and the
## display driver.
func _finish() -> void:
	var problems: PackedStringArray = []
	var per_tick: float = float(_probe_frames) / float(maxi(_probe_ticks, 1))
	_q.kit.need(problems, per_tick >= LEAST_FRAMES_PER_TICK, "window 1 drew %d frames in %d ticks: %.2f a tick, under %.1f, so the display cannot show interpolation (the refresh rate is %.1f Hz)" % [_probe_frames, _probe_ticks, per_tick, LEAST_FRAMES_PER_TICK, DisplayServer.screen_get_refresh_rate()])
	_q.kit.need(problems, _probe_worst <= POSE_TOLERANCE, "a rotor was drawn %.4f rad from the pose between its last two ticks at the engine's interpolation fraction" % _probe_worst)
	_q.kit.need(problems, _probe_stalls == 0 and _probe_least > 0.0, "%d frames drew a rotor at the angle of the frame before (the least advance of a frame was %.5f rad)" % [_probe_stalls, _probe_least])
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
	var step: float = TAU * _k.settings().parts[0].full_turns_per_second / Engine.physics_ticks_per_second
	_q.kit.verdict("interpolated", problems, "in window 1 (%d frames over %d ticks, %.2f a tick, on a display of %.1f Hz) the pose the renderer drew for each rotor was within %.5f rad of the pose between its last two ticks at the engine's interpolation fraction, and every frame advanced it: by %.4f rad at least and %.4f at most (the step of a tick is %.4f rad), %d frames at its angle of the frame before" % [
			_probe_frames, _probe_ticks, per_tick, DisplayServer.screen_get_refresh_rate(), _probe_worst, _probe_least, _probe_most, step, _probe_stalls])
	_k.close()
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f frame_ms_max=%.2f frame_ms_max_steady=%.2f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(steady, 1)), minima.x, minima.y, longest.x, longest.y,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d appearance_frame_ms=%.2f samples=%d steady_samples=%d windows=%d display=%s" % [
			_draw_calls_max, _primitives_max, _appearance_ms, count, steady, WINDOWS, DisplayServer.get_name()])
