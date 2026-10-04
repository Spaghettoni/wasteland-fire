extends RefCounted
## Scenario map_fps of the split screen evidence harness (split_screen_harness.gd): AC-14 of Story
## 007, the frame rate and the draw calls of both views on Map 01 while both Units drive, every key
## a real event (map_kit.gd's pursuit holds the throttle and feeds the steer keys). Player 2 steps
## right to the Buggy and both confirm (Player 1 the Motorbike). First leg, at once: Player 1
## drives out of Base A's gate and over the salt flat end to end (FLAT_ROUTE) while Player 2 drives
## the canyon road end to end (ROAD_ROUTE); second leg: each drives in through the other Player's
## gate (BASE_ROUTE). Each leg starts with both Units put down on their routes (place()) with full
## tanks (refuel(): a tool may). One SPLIT line per second with the frame rate and the render totals
## of the frame, all viewports together; the first second is left out of fps_min_steady and
## fps_avg_steady exactly as fps.gd does: quote those two. No pass or fail: the numbers are the
## evidence. Not in the runner's GREYBOX_SCENARIOS: it runs on Map 01. Use neither --write-movie
## nor --headless, which measures the real renderer (fps.gd says how the display caps the rate).
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-14. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=map_fps

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the Units and the pursuit.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## Since Story 010 it measures the camera the build ships with, the view from above, which sees more
## of the Map than the chase view did (production/epics/wasteland-fire/
## story-010-camera-from-above.md AC-6). Its Story 007 and 009 numbers are the chase view's.
const SHIPPED_CAMERA: bool = true
## Seconds between samples, one SPLIT line each.
const SAMPLE_SECONDS: float = 1.0
## The first leg, Player 1's route, world (x, z) metres: from Base A's SpawnPoint out of the gate on
## its axis, round the wreck at (-80, 5) onto the lane along z -15.5 (between the north wrecks and
## the canyon rock's south face at Z -20, through both fords) and along it over the salt flat.
const FLAT_ROUTE: Array[Vector2] = [Vector2(-125, 0), Vector2(-88, 0), Vector2(-70, -15.5),
	Vector2(88, -15.5)]
## The first leg, Player 2's route: the canyon road east to west, from 14 m past its east mouth to
## 14 m past its west mouth, on the road centreline of the story file's positions table.
const ROAD_ROUTE: Array[Vector2] = [Vector2(116, -26), Vector2(102, -26), Vector2(80, -26),
	Vector2(67, -36), Vector2(43, -36), Vector2(28, -28), Vector2(-28, -28), Vector2(-43, -36),
	Vector2(-67, -36), Vector2(-80, -26), Vector2(-102, -26), Vector2(-116, -26)]
## The second leg, Player 1's route: from Base B-local z -50 on its gate axis (x 70, 35 m out of
## the gate at x 105, clear of the long container) to 1 m inside the gate, then braking to a stand
## inside, near the water tower; Player 2 drives it mirrored into Base A.
const BASE_ROUTE: Array[Vector2] = [Vector2(70, 0), Vector2(106, 0)]
## A Unit's leg ends this close to its route's end, metres; it then brakes.
const END_MARGIN: float = 1.0
## A Unit slower than this, m/s, stands: the brakes let go.
const STOP_SPEED: float = 0.5
## Ticks a leg may take before it gives up.
const LEG_LIMIT_TICKS: int = 1800
## Seconds held after the second leg, so a last sample sees both Units inside the Bases.
const END_HOLD_SECONDS: float = 1.0

var _harness: Harness
var _kit: Kit
var _map: Map
var _start: int = 0
var _fps: PackedFloat64Array = []
var _draw_calls_max: int = 0
var _primitives_max: int = 0
var _legs: PackedStringArray = []


## The choice, the two legs sampled once a second from the first tick after the choice, then the
## RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_map = Map.new(harness, _kit)
	await _kit.press_settled(Kit.KEYS_NEXT_2)
	await _harness.confirm_choices()
	_start = _harness.ticks
	_kit.on_tick = _sample
	var paths: Array[PackedVector2Array] = [PackedVector2Array(FLAT_ROUTE), PackedVector2Array(ROAD_ROUTE)]
	await _leg(&"flat_and_road", paths)
	var mirrored: PackedVector2Array = []
	for point: Vector2 in BASE_ROUTE:
		mirrored.append(Vector2(-point.x, point.y))
	paths = [PackedVector2Array(BASE_ROUTE), mirrored]
	await _leg(&"into_bases", paths)
	_harness.phase = &"end"
	await _kit.advance(_harness.ticks_in(END_HOLD_SECONDS))
	_finish()


## One leg: each Player's Unit put down at its path's start facing along it (place(); no typed
## spawn) with a full tank, then driven by the pursuit until it is within END_MARGIN of its path's
## end and braked (_leg_tick()) until both stand, at most LEG_LIMIT_TICKS. Files ok or gave_up.
func _leg(leg: StringName, paths: Array[PackedVector2Array]) -> void:
	_harness.phase = leg
	var cameras: Array[ChaseCamera] = [_harness.split.player_1_camera, _harness.split.player_2_camera]
	for player: int in Kit.PLAYERS:
		var path: PackedVector2Array = paths[player]
		var ahead: Vector2 = path[1] - path[0]
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, atan2(-ahead.x, -ahead.y)), Vector3(path[0].x, 0.0, path[0].y))
		_harness.place(_map.units[player], pose, cameras[player])
		_map.units[player].refuel(_map.units[player].fuel_capacity)
		_map.set_path(player, path)
	await _kit.advance(Map.SETTLE_TICKS)
	var done: Array[bool] = [false, false]
	var standing: bool = false
	for _count: int in LEG_LIMIT_TICKS:
		standing = _leg_tick(paths, done)
		if standing:
			break
		await _kit.tick()
	_harness.release_all()
	_legs.append("%s:%s" % [leg, "ok" if standing else "gave_up"])


## One tick of a leg: each Player not done steers by the pursuit and is done near its path's end;
## a Player done holds its reverse key while it rolls forward. True when both are done and stand.
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


## After every tick: once a second since the choice, the frame rate and the render totals of the
## frame, all viewports together, in a SPLIT line with both Units' places; the maxima are kept.
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
	var units: Array[Unit] = _map.units
	print("SPLIT %s t=%.3f phase=%s fps=%.1f draw_calls=%d primitives=%d objects=%d p1_x=%.2f p1_z=%.2f p2_x=%.2f p2_z=%.2f" % [
		_harness.scenario, _harness.time(), _harness.phase, fps, draw_calls, primitives, objects,
		units[0].global_position.x, units[0].global_position.z, units[1].global_position.x, units[1].global_position.z])


## The RESULT line, as fps.gd's: the frame rate's average and minimum over every sample and over
## the steady ones (the first left out), the display's refresh rate, the most draw calls and
## primitives of a sampled frame, the samples, the legs and the display driver. No check.
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
	_harness.finish("fps_avg=%.1f fps_avg_steady=%.1f fps_min=%.1f fps_min_steady=%.1f refresh_hz=%.1f " % [
			totals.x / float(maxi(count, 1)), totals.y / float(maxi(count - 1, 1)), minima.x, minima.y,
			DisplayServer.screen_get_refresh_rate()]
		+ "draw_calls_max=%d primitives_max=%d samples=%d legs=%s display=%s" % [
			_draw_calls_max, _primitives_max, count, ",".join(_legs), DisplayServer.get_name()])
