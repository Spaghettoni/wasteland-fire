extends RefCounted
## Scenario light_fps of the split screen evidence harness (split_screen_harness.gd): AC-6 of Story 027, the frame rate and the draw calls of both views on Map 01 with the build as it
## ships (the tone mapper, the glow, the grade and the see-through silhouettes) while both Units drive behind cover, the way map_fps.gd measures the Map: Player 2 steps right to the
## Buggy and both confirm (Player 1 the Motorbike), every key a real event (map_kit.gd's pursuit holds the throttle and feeds the steer keys); the Turrets are taken down first (a tool
## may: a Turret that shoots would end a drive), and stay in the picture as wrecks. Three legs in each of the two views (the view from above, then after the keys step both, the chase
## view): both Units out of their own Gates (the chase camera stands inside the Base, so the Base's towers, legs, walls and Turrets are between it and the Unit: the Unit is behind
## cover and drawn as its silhouette), Player 1 over the salt flat and Player 2 along the canyon road end to end (the canyon's rocks), and both into the other Player's Gate. One SPLIT
## line per second with the frame rate, the longest frame of that second and the render totals of the frame, all viewports together; the first second and every second in which a leg
## is being staged (a Unit placed, a camera stepped: TD-013's and TD-016's single frames of 10 to 19 ms) are left out of fps_min_steady and frame_ms_max_steady: quote those, and the raw
## maxima beside them. AC-6's bar is the lowest one-second rate at 60 or over, a frame of at most 16.6 ms and at most 1,000 draw calls. A/B on the same build, environment variables of
## a run by hand: LIGHT_FPS_NO_SIL=1 takes both Units' silhouette away (the runner's strip: no copy, no fill quad, the cameras' masks as before the story) and LIGHT_FPS_NO_LOOK=1 puts
## the Environment back as it was before the story (Linear, no glow, no grade); both together are the picture of the story before. LIGHT_FPS_NO_GLOW=1, LIGHT_FPS_NO_GRADE=1 and
## LIGHT_FPS_LINEAR=1 take one part of the look away each (the glow, the colour grade, the tone mapper). Use neither --write-movie nor --headless, which
## measures the real renderer (fps.gd says how the display caps the rate). Implements: production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md AC-6. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 res://tools/evidence/split_screen_harness.tscn -- --scenario=light_fps

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## This scenario makes the first choice itself, on the build as it ships.
const OWN_CHOICE: bool = true
const SHIPPED_CAMERA: bool = true
const OWN_BASE_SWAP: bool = true
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
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
## The silhouette is the build's, unless LIGHT_FPS_NO_SIL is set (the class doc): the runner then keeps what this scenario declares.
const SEE_THROUGH: bool = true
## Tokens enough that nothing here ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 900.0
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The legs' routes, world (x, z) metres. Out of the Gates: Player 1 from just outside the water tower's box of Flag Walls (the Gate's axis, 3 m past the box) out through the Gate,
## Player 2 the mirror. Over the flat and along the canyon road: map_fps.gd's routes. Into the Bases: map_fps.gd's, Player 1 into Base B and Player 2 into Base A.
const EXIT_ROUTE: Array[Vector2] = [Vector2(-108, 0), Vector2(-88, 0)]
const FLAT_ROUTE: Array[Vector2] = [Vector2(-88, 0), Vector2(-70, -15.5), Vector2(60, -15.5)]
const ROAD_ROUTE: Array[Vector2] = [Vector2(116, -26), Vector2(102, -26), Vector2(80, -26), Vector2(67, -36), Vector2(43, -36), Vector2(28, -28), Vector2(-28, -28), Vector2(-43, -36),
	Vector2(-67, -36), Vector2(-80, -26), Vector2(-102, -26), Vector2(-116, -26)]
const BASE_ROUTE: Array[Vector2] = [Vector2(70, 0), Vector2(106, 0)]
## A Unit's leg ends this close to its route's end, metres; it then brakes.
const END_MARGIN: float = 1.0
## A Unit slower than this, m/s, stands: the brakes let go.
const STOP_SPEED: float = 0.5
## Ticks a leg may take before it gives up, and the seconds held after the last leg.
const LEG_LIMIT_TICKS: int = 1800
const END_HOLD_SECONDS: float = 1.0

var _harness: Harness
var _k: Kit27
var _kit: Kit
var _map: Map
var _start: int = 0
var _fps: PackedFloat64Array = []
var _frame_ms: PackedFloat64Array = []
var _staging_flags: Array[bool] = []
var _staging: bool = false
var _draw_calls_max: int = 0
var _primitives_max: int = 0
var _stamp: int = 0
var _worst_us: int = 0
var _legs: PackedStringArray = []
var _pass: String = "above"


## The choice, the legs of both views sampled once a second from the first tick after the choice, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_k = Kit27.new(harness)
	_kit = _k.q().kit
	_map = _k.q().map
	var split: SplitScreen = _harness.split
	if not OS.get_environment("LIGHT_FPS_NO_SIL").is_empty():
		for unit: Unit in [split.player_1_unit, split.player_2_unit]:
			unit.silhouette = null
		for camera: ChaseCamera in [split.player_1_camera, split.player_2_camera]:
			camera.never_drawn_layers = 0
	var env: Environment = _k.environment()
	if not OS.get_environment("LIGHT_FPS_NO_LOOK").is_empty() or not OS.get_environment("LIGHT_FPS_LINEAR").is_empty():
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.tonemap_exposure = 1.0
	if not OS.get_environment("LIGHT_FPS_NO_LOOK").is_empty() or not OS.get_environment("LIGHT_FPS_NO_GLOW").is_empty():
		env.glow_enabled = false
	if not OS.get_environment("LIGHT_FPS_NO_LOOK").is_empty() or not OS.get_environment("LIGHT_FPS_NO_GRADE").is_empty():
		env.adjustment_enabled = false
	await _kit.press_settled(Kit.KEYS_NEXT_2)
	await _harness.confirm_choices()
	await _k.walls().turrets_down()
	_harness.get_tree().process_frame.connect(_on_frame)
	_start = _harness.ticks
	_kit.on_tick = _sample
	for pass_index: int in 2:
		_pass = "above" if pass_index == 0 else "chase"
		await _legs_of_a_view()
		if pass_index == 0:
			_staging = true
			await _kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
			await _kit.advance(Looks.VIEW_TICKS)
			_staging = false
	_harness.phase = &"end"
	await _kit.advance(_harness.ticks_in(END_HOLD_SECONDS))
	_kit.on_tick = Callable()
	_harness.get_tree().process_frame.disconnect(_on_frame)
	_finish()


## The three legs of a view (the class doc).
func _legs_of_a_view() -> void:
	var out_1: PackedVector2Array = PackedVector2Array(EXIT_ROUTE)
	var out_2: PackedVector2Array = _mirrored(out_1)
	await _leg("exit", [out_1, out_2])
	await _leg("flat_and_road", [PackedVector2Array(FLAT_ROUTE), PackedVector2Array(ROAD_ROUTE)])
	var into_1: PackedVector2Array = PackedVector2Array(BASE_ROUTE)
	await _leg("into_bases", [into_1, _mirrored(into_1)])


## A path as the other Player drives it: the mirror across x = 0.
func _mirrored(path: PackedVector2Array) -> PackedVector2Array:
	var mirrored: PackedVector2Array = []
	for point: Vector2 in path:
		mirrored.append(Vector2(-point.x, point.y))
	return mirrored


## One leg: each Player's Unit put down at its path's start facing along it with a full tank (the seconds that includes are staging), then driven by the pursuit until it is within
## END_MARGIN of its path's end and braked until both stand, at most LEG_LIMIT_TICKS. Files ok or gave_up.
func _leg(leg: StringName, paths: Array[PackedVector2Array]) -> void:
	_harness.phase = StringName("%s_%s" % [_pass, leg])
	_staging = true
	var cameras: Array[ChaseCamera] = [_harness.split.player_1_camera, _harness.split.player_2_camera]
	for player: int in Kit.PLAYERS:
		var path: PackedVector2Array = paths[player]
		var ahead: Vector2 = path[1] - path[0]
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, atan2(-ahead.x, -ahead.y)), Vector3(path[0].x, 0.0, path[0].y))
		_harness.place(_map.units[player], pose, cameras[player])
		_map.units[player].refuel(_map.units[player].fuel_capacity)
		_map.set_path(player, path)
	await _kit.advance(Map.SETTLE_TICKS)
	_staging = false
	var done: Array[bool] = [false, false]
	var standing: bool = false
	for _count: int in LEG_LIMIT_TICKS:
		standing = _leg_tick(paths, done)
		if standing:
			break
		await _kit.tick()
	_harness.release_all()
	_legs.append("%s_%s:%s" % [_pass, leg, "ok" if standing else "gave_up"])


## One tick of a leg: each Player not done steers by the pursuit and is done near its path's end; a Player done holds its reverse key while it rolls forward. True when both are done and
## stand.
func _leg_tick(paths: Array[PackedVector2Array], done: Array[bool]) -> bool:
	var standing: bool = true
	for player: int in Kit.PLAYERS:
		if not done[player]:
			done[player] = _map.steer(player, 1) >= _length(paths[player]) - END_MARGIN
		var speed: float = _map.units[player].current_speed
		if done[player]:
			_harness.drive(player, -1 if speed > STOP_SPEED else 0, 0)
		standing = standing and done[player] and speed <= STOP_SPEED
	return standing


## A path's length, metres.
func _length(path: PackedVector2Array) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length


## Stamps each frame of the main loop and keeps the longest interval since the last sample.
func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if _stamp != 0:
		_worst_us = maxi(_worst_us, now - _stamp)
	_stamp = now


## After every tick: once a second since the choice, the frame rate, the longest frame of the second and the render totals of the frame, all viewports together, in a SPLIT line; the
## maxima are kept.
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
	var units: Array[Unit] = _map.units
	print("SPLIT %s t=%.3f phase=%s staging=%d fps=%.1f frame_ms_max=%.2f draw_calls=%d primitives=%d objects=%d p1_x=%.2f p1_z=%.2f p2_x=%.2f p2_z=%.2f" % [
		_harness.scenario, _harness.time(), _harness.phase, 1 if _staging else 0, fps, worst_ms, draw_calls, primitives, objects, units[0].global_position.x, units[0].global_position.z, units[1].global_position.x, units[1].global_position.z])


## The RESULT line, as tyre_tracks_fps.gd's: the frame rate's average and minimum over every sample and over the steady ones (the first and those of a staging second left out), the
## longest frame over every sample and over the steady ones, the display's refresh rate, the most draw calls and primitives of a sampled frame, the samples, the legs, the A/B switches
## and the display driver. No check: the numbers are the evidence.
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
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(steady, 1)), minima.x, minima.y, longest.x, longest.y, DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d steady_samples=%d legs=%s no_sil=%d no_look=%d no_glow=%d no_grade=%d linear=%d display=%s" % [
			_draw_calls_max, _primitives_max, count, steady, ",".join(_legs), _flag("LIGHT_FPS_NO_SIL"), _flag("LIGHT_FPS_NO_LOOK"), _flag("LIGHT_FPS_NO_GLOW"), _flag("LIGHT_FPS_NO_GRADE"), _flag("LIGHT_FPS_LINEAR"), DisplayServer.get_name()])


## 1 when an A/B switch is set in the environment, else 0.
func _flag(name: String) -> int:
	return 0 if OS.get_environment(name).is_empty() else 1
