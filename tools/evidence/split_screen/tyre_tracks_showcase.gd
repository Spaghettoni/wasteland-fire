extends RefCounted
## Scenario tyre_tracks_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 026 on Map 01 with the
## shipped data, every key a real key event, each moment in the view from above and then in the chase view (Q and Slash step both Players' views).
## Both Players choose a Motorbike with their own keys, and then the scenes, each staged and driven on its own ground: sand (a Motorbike for each Player
## drives a figure eight on the sand at each end of the Map), sand_wide (a Buggy and a Truck drive a straight and a long curve on the sand south of the
## Garages: two lines each), salt (a Buggy and a Truck drive a circle and on on the salt flat), road (a Motorbike and a
## Truck drive the length of the canyon road in two lanes), ford (each Player drives through a ford: no track in the water, tracks again on the far bank),
## pad (each Player drives out of its Garage over the floor's edge: no track on the floor), cross (two tracks cross), far (the salt scene's circles, then each Unit
## turns about and rolls back toward them in the chase view: two sets of four consecutive frames while the camera moves, slowly and then faster, for the
## far marks to be compared frame by frame, the story's question whether marks far down the view shimmer, the track map having no mipmaps), gyro (a Gyrocopter and a Motorbike on
## the same sand: the Gyrocopter leaves none), wall (a wall of the ground's own material stands across a track: the track is on the ground and not on the
## wall, so a side face takes none, as the island's shore edge does), fade (the same ground at 0 s, 30 s and 60 s of the Round's time) and restart (a Round won and R pressed: the
## ground clean). Every scene but the fade starts on clean ground: it clears the track map, which is what R does. A SPLIT line per moment with frame=, the number of
## the PNG that shows it in a --write-movie recording. Environment variables of a run by hand: TRACKS_SCENES=sand,road (the named scenes only),
## TRACKS_LOOK=0.5,0.04,0.25 (the look's darkness, rut depth and smoothing, sent to the ground shader for this run), TRACKS_FADE_POKE=1 (the fade scene
## moves the tracks' clock by a call instead of waiting a minute of ticks; the retained recording waits), TRACKS_DUMP=folder (the track map around Player
## 1's Unit as PNGs). No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so
## an empty or false recording cannot pass as evidence. Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md, Test Evidence (retained
## frames). Tooling only. Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/tracks.png
## res://tools/evidence/split_screen_harness.tscn -- --scenario=tyre_tracks_showcase

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd): the views' settings files and the ticks a moment holds.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Gate wall that is broken to take the Flag, for the restart.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

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
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 1800.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The scenes, in the order they play.
const SCENES: Array[StringName] = [&"sand", &"sand_wide", &"salt", &"road", &"ford", &"pad", &"cross", &"far", &"gyro", &"wall", &"fade", &"restart"]
## Where each scene stages Player 1 (Player 2 on the other side of the Map): fade, the sand south of the Garage, facing east; sand, the NW sand patch, facing north; wall, the open salt flat west of the middle,
## facing east (Player 2 at +22 m facing west: SALT_1, SALT_2); salt and far, CIRCLE_1 and CIRCLE_2 (below); road, the canyon road's southern lane, facing east; ford, west of the west ford, facing east; pad, the yard of
## Base A facing its Garage; cross, the salt flat east of Base A's Gate, facing east (Player 2 north across Player 1's way). Every spot and plan was chosen
## so that no Unit touches anything but the ground (a scan of the Map's colliders, then the premise every moment asks: none since the scene began).
## The sand scene's crossing point of the figure eight, in the sand patch north of Base A (between the Base's wall and towers at z -16 to -18 and the
## shore at z -38, x -130 to -100), facing north; and the share of the throttle it is driven at: under the spot turn speed, where a loop's radius is the
## speed over the spot turn rate (about 5 m) and the eight fits the patch (at full throttle a loop is 8.6 m and the eight does not).
const SAND: Vector3 = Vector3(-115.0, 0.0, -28.0)
const SAND_THROTTLE: float = 0.3
const SALT_1: Vector3 = Vector3(-16.0, 0.0, -16.0)
const SALT_2: Vector3 = Vector3(22.0, 0.0, -16.0)
## Where the salt and far scenes start their circles, facing east and west: Player 1's Buggy circles round WreckWestOuterSouth and Player 2's
## Truck round WreckEastOuterSouth, each wreck inside its ring, which misses every solid of the Map (the salt flat's middle has no room for
## the Truck's circle, whose radius is 12.3 m at any speed); then each drives on CIRCLE_RUN_ON ticks, short of the next wreck.
const CIRCLE_1: Vector3 = Vector3(-77.0, 0.0, -6.5)
const CIRCLE_2: Vector3 = Vector3(80.0, 0.0, -9.5)
const CIRCLE_RUN_ON: int = 20
const ROAD_1: Vector3 = Vector3(-24.0, 0.0, -27.0)
const ROAD_2: Vector3 = Vector3(24.0, 0.0, -30.0)
const FORD_1: Vector3 = Vector3(-58.0, 0.0, 15.0)
const FORD_2: Vector3 = Vector3(58.0, 0.0, 15.0)
## The spawn spot left of the middle of a Garage, in the Base's own frame (z grows into the Base): the floor's open edge is 3 m ahead along local -z.
const PAD_LOCAL: Vector3 = Vector3(-4.0, 0.0, 5.0)
const FADE_1: Vector3 = Vector3(-128.0, 0.0, 32.0)
const CROSS_1: Vector3 = Vector3(-92.0, 0.0, -12.0)
const CROSS_2: Vector3 = Vector3(-86.0, 0.0, 10.0)
## The sand_wide scene's start, in the sand patch south of Base A (Player 2 at the mirror, south of Base B), facing east (west).
const WIDE_1: Vector3 = Vector3(-127.0, 0.0, 30.0)
## The gyro scene's start and the restart scene's first drive, in the sand patch north of Base A (Player 2 at the mirror), facing east (west), along
## the patch: the restart's marks run under SAND, where both Units stand again after R (facing north from SAND, a drive would reach the shore).
const GYRO_1: Vector3 = Vector3(-125.0, 0.0, -28.0)
## The track map read around a Unit: half its side in pixels, the coverage above which a pixel counts, the least pixels a scene's tracks cover there, how far the
## most coverage may be from 1, and how far a stroke time may be outside the clock's span or before the Unit's own last stroke, seconds.
const MAP_HALF: int = 128
const COVER_MIN: float = 0.5
const MAP_LEAST: int = 60
const MAP_SLACK: float = 0.001
const MAP_STAMP_SLACK: float = 0.1
## Ticks a mark is made, braked and waited for in each scene, and the seconds of the Round's time the fade scene shows after the first (30 and 60).
const BRAKE_TICKS: int = 30
const FADE_SECONDS: Array[float] = [30.0, 60.0]
## The ford scene: where Player 1 stops east of the west ford (its far edge is x = -34), Player 2 at the mirror, and the most ticks it may take.
const FORD_STOP_X: float = -26.0
const FORD_LIMIT_TICKS: int = 900
## The wall scene: the ground material the wall wears (the sand's), its size (width across the track, height), how far behind where the Unit stops it stands
## along the track, the Units' ticks at full throttle, the screen's luminance (0 to 1) two points on the wall may differ by, and how much darker than the sand
## beside it the track must be on the ground for the premise to hold.
const WALL_MATERIAL: String = "res://src/gameplay/maps/map_01/materials/sand.tres"
const WALL_SIZE: Vector2 = Vector2(8.0, 3.0)
const WALL_BEHIND: float = 7.0
const WALL_TICKS: int = 45
const WALL_TOLERANCE: float = 0.02
## The sand_wide scene: by type, the ticks driven straight and then curving north at full lock (about 50 degrees for either), short of Base A's wall.
const SAND_WIDE_TICKS: Dictionary = {Quick.BUGGY: Vector2i(40, 30), Quick.TRUCK: Vector2i(60, 60)}
## The fade scene: how far behind a standing Unit, metres, the points are read at on its track (and WALL_SIDE to either side), the contrast the fresh mark must show
## at least, the most a mark that has faded may show, and how the contrast at 30 s may differ from a straight-line share of the fresh one's (the strength line is
## 0.75 there, and luminance is not a straight line of strength: only an order is asked, the middle reading at least FADE_MIDDLE_SHARE of the fresh one, which a
## fade that began at once instead of after the hold would not reach).
const FADE_BACK: Array[float] = [1.5, 2.5, 3.5, 4.5]
const FADE_VISIBLE: float = 0.06
const FADE_GONE: float = 0.03
const FADE_MIDDLE_SHARE: float = 0.4
## How far beside the track the comparison points lie, metres, the heights up the wall and the distances in front of its foot, toward the camera, they are read at.
const WALL_SIDE: float = 0.4
const WALL_HEIGHTS: Array[float] = [0.5, 1.0, 1.5, 2.0, 2.5]
const WALL_FOOTS: Array[float] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
const WALL_TRACK_DARKER: float = 0.08
## The ticks the gyro scene's Gyrocopter and Motorbike drive at full throttle (they start at GYRO_1 and its mirror).
const GYRO_TICKS: int = 60
## The far scene: the ticks the Units roll at full throttle toward their circles before each set of frames is filed (a slow camera, then a faster one),
## and how many consecutive frames each set files.
const FAR_ROLL_TICKS: Array[int] = [12, 36]
const FAR_FRAMES: int = 4

var _k: Kit26
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
## The fade scene's contrast readings by moment, one per Player.
var _contrasts: Dictionary = {}
## The Round's time of each Player's Unit's last stroke since the track map was last cleared, from the node's own strokes (read on each tick's clock),
## -1 before any: the latest time stamped around a Unit is at least this. A Unit that stops before the other stands while the other drives on, so its
## stamps grow old by however long that is.
var _last_strokes: PackedFloat64Array = PackedFloat64Array([-1.0, -1.0])
## The ticks since the track map was last cleared on which each Player's Unit touched anything but the ground (map_kit.gd's wall_contact(),
## read at the next tick's clock): every moment asks for none, so no frame shows a track a bounce off a wreck has bent.
var _touches: Array[int] = [0, 0]


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit26.new(harness)
	_q = _k.q()
	_k.tracks().published.connect(_note_strokes)
	_apply_look(OS.get_environment("TRACKS_LOOK"))
	await _k.choose([Quick.MOTORBIKE, Quick.MOTORBIKE])
	_line("garage_spawn", "both Players chose a Motorbike with their own keys")
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _k.walls().turrets_down()
	var only: PackedStringArray = OS.get_environment("TRACKS_SCENES").split(",", false)
	for scene: StringName in SCENES:
		if only.is_empty() or only.has(String(scene)):
			match scene:
				&"sand":
					await _scene_sand()
				&"sand_wide":
					await _scene_sand_wide()
				&"salt":
					await _scene_salt()
				&"road":
					await _scene_road()
				&"ford":
					await _scene_ford()
				&"pad":
					await _scene_pad()
				&"cross":
					await _scene_cross()
				&"far":
					await _scene_far()
				&"gyro":
					await _scene_gyro()
				&"wall":
					await _scene_wall()
				&"fade":
					await _scene_fade()
				&"restart":
					await _scene_restart()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d" % _moments.size())


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Sends a look (darkness, rut depth, smoothing) to the ground shader in place of the data's, for a run by hand.
func _apply_look(text: String) -> void:
	if text.is_empty():
		return
	var parts: PackedFloat64Array = text.split_floats(",")
	RenderingServer.global_shader_parameter_set(TyreTracks.LOOK_GLOBAL, Vector4(parts[0], parts[1], parts[2], 1.0))


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	await _q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await _q.kit.advance(Looks.VIEW_TICKS)


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		found.append(_q.units.cameras[player].settings.resource_path.get_file())
	return found


## What the track map holds around a Player's Unit, read back from the real renderer (a windowed run only: the headless renderer keeps no texture): the
## pixels within MAP_HALF of the Unit's own that are covered (R above COVER_MIN), the most coverage there and the earliest and latest stroke time stamped
## there (G over R), or an empty Dictionary when there is no texture.
func _read_map(player: int) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {}
	var tracks: TyreTracks = _k.tracks()
	var image: Image = tracks.track_viewport.get_texture().get_image()
	var unit: Unit = _q.units.units[player]
	var at: Vector2 = tracks.settings.world_to_pixel(Vector2(unit.global_position.x, unit.global_position.z))
	var box: Rect2i = Rect2i(int(at.x) - MAP_HALF, int(at.y) - MAP_HALF, MAP_HALF * 2, MAP_HALF * 2).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var found: Dictionary = {"covered": 0, "most": 0.0, "first": INF, "last": -INF, "size": image.get_size(), "format": image.get_format(), "used": image.get_used_rect()}
	for y: int in range(box.position.y, box.end.y):
		for x: int in range(box.position.x, box.end.x):
			var texel: Color = image.get_pixel(x, y)
			if texel.r > COVER_MIN:
				found["covered"] += 1
				found["most"] = maxf(found["most"], texel.r)
				found["first"] = minf(found["first"], texel.g / texel.r)
				found["last"] = maxf(found["last"], texel.g / texel.r)
	return found


## On each tick's clock (and at a clear, which sets the clock to 0 and forgets them): the time of each Unit's newest stroke.
func _note_strokes(parameter: StringName, _value: Variant) -> void:
	if parameter != TyreTracks.CLOCK_GLOBAL:
		return
	if _k.tracks().now == 0.0:
		_last_strokes = PackedFloat64Array([-1.0, -1.0])
		_touches = [0, 0]
	else:
		for player: int in _touches.size():
			_touches[player] += 1 if _q.map.wall_contact(_q.units.units[player]) else 0
	for stroke: TyreTracks.Stroke in _k.tracks().strokes:
		_last_strokes[stroke.unit_index] = maxf(_last_strokes[stroke.unit_index], stroke.time)


## The premise of a moment's track map: where a Player's tracks are expected, the pixels around its Unit are covered, nowhere is covered more than fully (a
## later stroke replaces an earlier one, never adds to it), the stroke times stamped there lie between the start of the scene's clock and now and the latest is
## no earlier than the Unit's own last stroke; where none is expected, nothing is covered. One SPLIT line with the numbers.
func _check_map(moment: String, expected: Array[bool]) -> void:
	var now: float = _k.tracks().now
	for player: int in Kit.PLAYERS:
		var facts: Dictionary = _read_map(player)
		if facts.is_empty():
			continue
		var covered: int = facts["covered"]
		_need(covered >= MAP_LEAST if expected[player] else covered == 0, "%s: Player %d's surroundings hold %d covered pixels (tracks expected: %s)" % [moment, player + 1, covered, expected[player]])
		if expected[player] and covered > 0:
			_need(facts["most"] <= 1.0 + MAP_SLACK and facts["most"] >= 1.0 - MAP_SLACK, "%s: Player %d's most coverage is %.4f, not 1" % [moment, player + 1, facts["most"]])
			_need(facts["first"] >= -MAP_STAMP_SLACK and facts["last"] <= now + MAP_STAMP_SLACK and facts["last"] >= _last_strokes[player] - MAP_STAMP_SLACK, "%s: Player %d's stamps run %.2f to %.2f s at a clock of %.2f s, its Unit's last stroke at %.2f s" % [moment, player + 1, facts["first"], facts["last"], now, _last_strokes[player]])
		if not expected[0] and not expected[1]:
			_need((facts["used"] as Rect2i).size == Vector2i.ZERO, "%s: the track map holds marks within %s, where none is expected anywhere" % [moment, facts["used"]])
		print("SPLIT %s t=%.3f map moment=%s player=%d covered=%d most=%.4f first_stamp=%.2f last_stamp=%.2f own_last_stroke=%.2f clock=%.2f used_rect=%s format=%s size=%s" % [_q.harness.scenario, _q.harness.time(), moment, player + 1, covered, facts["most"], facts["first"] if covered > 0 else -1.0, facts["last"] if covered > 0 else -1.0, _last_strokes[player], now, facts["used"], facts["format"], facts["size"]])


## Files a moment in the view from above, steps both views to the chase view and files it again, then steps back to the view from above for the next
## scene. The premise: both Units are alive, the cameras are on the view each line says and the track map holds what the moment shows (`expected`: whether
## to expect tracks around each Player's Unit; `probe`: a coroutine called once the cameras are on the chase view, before its line).
func _show(moment: String, reads: String, expected: Array[bool] = [true, true], probe: Callable = Callable()) -> void:
	_dump(moment)
	_check_map(moment, expected)
	_need(_touches[0] == 0 and _touches[1] == 0, "%s: since the scene began Player 1's Unit touched something but the ground on %d ticks and Player 2's on %d" % [moment, _touches[0], _touches[1]])
	for pass_index: int in 2:
		var want: String = Looks.ABOVE_FILE if pass_index == 0 else Looks.CHASE_FILE
		_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and _views() == PackedStringArray([want, want]), "%s: Units alive %s, the cameras are on %s" % [moment, _q.units.units[0].is_alive and _q.units.units[1].is_alive, _views()])
		if pass_index == 1 and probe.is_valid():
			await probe.call()
		_line("%s_%s" % [moment, "above" if pass_index == 0 else "chase"], "%s | strokes this tick %d, clock %.2f s, views=%s" % [reads, _k.tracks().strokes.size(), _k.tracks().now, ", ".join(_views())])
		await _switch_views()


## Both Players' Units staged as the types at the spots, facing the ways, then the plans run, then a settle.
func _drive(types: Array[int], spots: Array[Vector3], facings: Array[Vector3], plans: Array) -> void:
	await _q.map.stage(types, spots, facings, true)
	await _k.run(plans)
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Players' Units staged as the types at the spots, facing the ways, then driven together by segments of [ticks, throttle, steer] each: a throttle
## of 1 is the real key, -1 the real reverse key, a share between 0 and 1 a stick pressed that far (Input.action_press with that strength, as
## crash_kit.gd's drive() does), and steer 1 left, -1 right by the real keys; then a settle. A coroutine: await it.
func _drive_shares(types: Array[int], spots: Array[Vector3], facings: Array[Vector3], segments: Array) -> void:
	await _q.map.stage(types, spots, facings, true)
	var steps: Array[Array] = [[], []]
	for player: int in Kit.PLAYERS:
		for segment: Array in segments[player]:
			for _tick: int in int(segment[0]):
				steps[player].append([float(segment[1]), int(segment[2])])
	for tick: int in maxi(steps[0].size(), steps[1].size()):
		for player: int in Kit.PLAYERS:
			var step: Array = steps[player][tick] if tick < steps[player].size() else [0.0, 0]
			var throttle: float = step[0]
			if throttle > 0.0 and throttle < 1.0:
				Input.action_press(Kit26.Kit25.Kit21.THROTTLE_ACTIONS[player], throttle)
			else:
				Input.action_release(Kit26.Kit25.Kit21.THROTTLE_ACTIONS[player])
			_q.harness.drive(player, 1 if throttle >= 1.0 else (-1 if throttle <= -1.0 else 0), step[1])
		await _q.kit.tick()
	for player: int in Kit.PLAYERS:
		Input.action_release(Kit26.Kit25.Kit21.THROTTLE_ACTIONS[player])
	_q.harness.release_all()
	await _q.kit.advance(Looks.HOLD_TICKS)


## Both Units drive east or west (ways +1 and -1 along x) at full throttle until each reaches its target x, brake there (the data's braking decides when),
## and stop. A coroutine: await it.
func _stop_at(targets: Array[float], ways: Array[float]) -> void:
	for _tick: int in FORD_LIMIT_TICKS:
		var moving: bool = false
		for player: int in Kit.PLAYERS:
			var unit: Unit = _q.units.units[player]
			var speed: float = absf(unit.current_speed)
			var left: float = (targets[player] - unit.global_position.x) * ways[player]
			var margin: float = speed * speed / (2.0 * unit.stats.braking)
			var held: int = 1 if left > margin else (-1 if speed > Quick.STOP_SPEED else 0)
			_q.harness.drive(player, held, 0)
			moving = moving or held != 0
		await _q.kit.tick()
		if not moving:
			break
	_q.harness.release_all()


## Both Units turn on the spot, to the left for Player 1 and to the right for Player 2, half a turn each (the data's spot turn rate decides how long).
func _turn_around() -> void:
	var plans: Array = []
	for player: int in Kit.PLAYERS:
		var stats: UnitStats = _q.units.units[player].stats
		plans.append(Kit26.plan([[int(ceil(PI / stats.spot_turn_rate * float(Engine.physics_ticks_per_second))), 0, 1 if player == 0 else -1]]))
	await _k.run(plans)


## One full circle at top speed, to the left (steer 1) or right (-1), then the brake.
func _circle(type_index: int, steer: int, then: Array = []) -> Array[Vector2i]:
	var ticks: int = _k.circle_ticks(_q.units.stats(type_index))
	var segments: Array = [[ticks, 1, steer]]
	segments.append_array(then)
	segments.append([BRAKE_TICKS, -1, 0])
	return Kit26.plan(segments)


## Debug: writes the track map's R and G around Player 1's Unit as PNGs into TRACKS_DUMP (an environment variable of a run by hand).
func _dump(label: String) -> void:
	var folder: String = OS.get_environment("TRACKS_DUMP")
	if folder.is_empty():
		return
	var tracks: TyreTracks = _k.tracks()
	var image: Image = tracks.track_viewport.get_texture().get_image()
	var unit: Unit = _q.units.units[0]
	var at: Vector2 = tracks.settings.world_to_pixel(Vector2(unit.global_position.x, unit.global_position.z))
	var box: Rect2i = Rect2i(int(at.x) - 40, int(at.y) - 30, 80, 60)
	var part: Image = image.get_region(box)
	var cover: Image = Image.create_empty(box.size.x, box.size.y, false, Image.FORMAT_RGB8)
	for y: int in box.size.y:
		for x: int in box.size.x:
			var c: Color = part.get_pixel(x, y)
			cover.set_pixel(x, y, Color(c.r, c.r, c.r))
	cover.resize(box.size.x * 8, box.size.y * 8, Image.INTERPOLATE_NEAREST)
	cover.save_png("%s/%s-cover.png" % [folder, label])


func _scene_sand() -> void:
	_k.tracks().clear()
	var loop: int = int(ceil(TAU / _q.units.stats(Quick.MOTORBIKE).spot_turn_rate * float(Engine.physics_ticks_per_second)))
	var eight: Array = [[loop, SAND_THROTTLE, 1], [loop, SAND_THROTTLE, -1], [BRAKE_TICKS, -1.0, 0]]
	await _drive_shares([Quick.MOTORBIKE, Quick.MOTORBIKE], [SAND, Quick.mirrored(SAND)], [Vector3.FORWARD, Vector3.FORWARD], [eight, eight])
	await _show("sand_eight", "both Motorbikes have driven a figure eight on the sand at the two ends of the Map")


func _scene_sand_wide() -> void:
	_k.tracks().clear()
	var buggy: Vector2i = SAND_WIDE_TICKS[Quick.BUGGY]
	var truck: Vector2i = SAND_WIDE_TICKS[Quick.TRUCK]
	var plans: Array = [Kit26.plan([[buggy.x, 1, 0], [buggy.y, 1, 1], [BRAKE_TICKS, -1, 0]]), Kit26.plan([[truck.x, 1, 0], [truck.y, 1, -1], [BRAKE_TICKS, -1, 0]])]
	await _drive([Quick.BUGGY, Quick.TRUCK], [WIDE_1, Quick.mirrored(WIDE_1)], [Vector3.RIGHT, Vector3.LEFT], plans)
	await _show("sand_two_lines", "a Buggy (Player 1) and a Truck (Player 2) have driven a straight and a long curve on the sand south of the Garages: two lines each")


func _scene_salt() -> void:
	_k.tracks().clear()
	await _drive([Quick.BUGGY, Quick.TRUCK], [CIRCLE_1, CIRCLE_2], [Vector3.RIGHT, Vector3.LEFT], [_circle(Quick.BUGGY, -1, [[CIRCLE_RUN_ON, 1, 0]]), _circle(Quick.TRUCK, 1, [[CIRCLE_RUN_ON, 1, 0]])])
	await _show("salt_circle", "a Buggy (Player 1, two lines) and a Truck (Player 2, two lines) have driven a circle and on, on the salt flat")


func _scene_road() -> void:
	_k.tracks().clear()
	await _drive([Quick.MOTORBIKE, Quick.TRUCK], [ROAD_1, ROAD_2], [Vector3.RIGHT, Vector3.LEFT], [Kit26.plan([[90, 1, 0], [BRAKE_TICKS, -1, 0]]), Kit26.plan([[260, 1, 0], [BRAKE_TICKS, -1, 0]])])
	await _show("road_lanes", "a Motorbike (Player 1) and a Truck (Player 2) have driven the canyon road in two lanes")


func _scene_ford() -> void:
	_k.tracks().clear()
	await _q.map.stage([Quick.MOTORBIKE, Quick.TRUCK], [FORD_1, FORD_2], [Vector3.RIGHT, Vector3.LEFT], true)
	await _stop_at([FORD_STOP_X, -FORD_STOP_X], [1.0, -1.0])
	await _turn_around()
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _show("ford_crossing", "both Units drove through a ford and turned round to face it: tracks on the near bank, none in the water, tracks again on the far bank")


func _scene_pad() -> void:
	_k.tracks().clear()
	var flags: Object = _k.flags()
	var out: Array[Vector2i] = Kit26.plan([[40, 1, 0], [BRAKE_TICKS, -1, 0]])
	await _drive([Quick.MOTORBIKE, Quick.MOTORBIKE], [flags.point(0, PAD_LOCAL), flags.point(1, PAD_LOCAL)], [flags.way(0, Vector3.FORWARD), flags.way(1, Vector3.FORWARD)], [out, out])
	await _show("pad_edge", "each Motorbike has driven out of its Garage over the floor's open edge into the yard: no track on the floor, the track begins at its edge")


func _scene_cross() -> void:
	_k.tracks().clear()
	await _drive([Quick.MOTORBIKE, Quick.MOTORBIKE], [CROSS_1, CROSS_2], [Vector3.RIGHT, Vector3.FORWARD], [Kit26.plan([[60, 1, 0], [BRAKE_TICKS, -1, 0]]), Kit26.plan([[110, 0, 0], [80, 1, 0], [BRAKE_TICKS, -1, 0]])])
	await _show("tracks_cross", "Player 2's Motorbike drove across the track Player 1's had left: where they cross the ground is no darker than one track")


## The screen's luminance (0 to 1) around where a world point is seen in a Player's view, the mean of the 3 x 3 pixels there.
func _luminance(player: int, image: Image, point: Vector3) -> float:
	var seen: Vector2 = _q.units.cameras[player].unproject_position(point)
	var sum: float = 0.0
	var count: int = 0
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var at: Vector2i = Vector2i(int(seen.x) + dx, int(seen.y) + dy)
			if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height():
				sum += image.get_pixelv(at).get_luminance()
				count += 1
	return sum / float(maxi(count, 1))


## The wall scene's premise (windowed only), in each Player's chase view: at WALL_HEIGHTS up the wall, where the track crosses it the wall is as bright as it is
## WALL_SIDE m to either side of it (the means differ by no more than WALL_TOLERANCE), while along the ground in front of the wall, at WALL_FOOTS m from its foot,
## the track is darker than the ground WALL_SIDE m to either side of it by WALL_TRACK_DARKER at least (the means of the screen's luminance over the points). A
## coroutine: it waits for a rendered frame. One SPLIT line with the numbers.
func _check_wall(walls: Array[MeshInstance3D]) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	for player: int in Kit.PLAYERS:
		var image: Image = _q.units.cameras[player].get_viewport().get_texture().get_image()
		var wall: MeshInstance3D = walls[player]
		var centre: Vector3 = wall.global_position
		var side: Vector3 = wall.global_transform.basis.x * WALL_SIDE
		var toward: Vector3 = wall.global_transform.basis.z
		var on_wall: float = 0.0
		var beside: float = 0.0
		for height: float in WALL_HEIGHTS:
			var at: Vector3 = centre + Vector3.UP * (height - centre.y)
			on_wall += _luminance(player, image, at)
			beside += (_luminance(player, image, at + side) + _luminance(player, image, at - side)) / 2.0
		var ground_on: float = 0.0
		var ground_beside: float = 0.0
		for foot: float in WALL_FOOTS:
			var at: Vector3 = Vector3(centre.x, 0.0, centre.z) + toward * foot
			ground_on += _luminance(player, image, at)
			ground_beside += (_luminance(player, image, at + side) + _luminance(player, image, at - side)) / 2.0
		on_wall /= float(WALL_HEIGHTS.size())
		beside /= float(WALL_HEIGHTS.size())
		ground_on /= float(WALL_FOOTS.size())
		ground_beside /= float(WALL_FOOTS.size())
		_need(absf(on_wall - beside) <= WALL_TOLERANCE and ground_beside - ground_on >= WALL_TRACK_DARKER, "wall: Player %d's wall is %.3f where the track crosses it and %.3f beside it, and the ground is %.3f on the track and %.3f beside it" % [player + 1, on_wall, beside, ground_on, ground_beside])
		var folder: String = OS.get_environment("TRACKS_DUMP")
		if not folder.is_empty():
			image.save_png("%s/wall-player-%d.png" % [folder, player + 1])
		print("SPLIT %s t=%.3f wall player=%d wall_on_track=%.4f wall_beside=%.4f ground_on_track=%.4f ground_beside=%.4f" % [_q.harness.scenario, _q.harness.time(), player + 1, on_wall, beside, ground_on, ground_beside])


## The far scene: see the class doc. The circles and the run on are the salt scene's (a Buggy for Player 1, a Truck for Player 2); each Unit then turns
## about on the spot, so it faces the circle it laid, the views step to the chase view, and both roll back along the way they came at full throttle, where
## nothing stands; after each roll of FAR_ROLL_TICKS, FAR_FRAMES consecutive frames are filed as moments (a --write-movie recording draws one frame a
## tick), then both brake and the views step back to the view from above.
func _scene_far() -> void:
	_k.tracks().clear()
	await _drive([Quick.BUGGY, Quick.TRUCK], [CIRCLE_1, CIRCLE_2], [Vector3.RIGHT, Vector3.LEFT], [_circle(Quick.BUGGY, -1, [[CIRCLE_RUN_ON, 1, 0]]), _circle(Quick.TRUCK, 1, [[CIRCLE_RUN_ON, 1, 0]])])
	await _turn_around()
	await _switch_views()
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive and _views() == PackedStringArray([Looks.CHASE_FILE, Looks.CHASE_FILE]), "far: Units alive %s, the cameras are on %s" % [_q.units.units[0].is_alive and _q.units.units[1].is_alive, _views()])
	for player: int in Kit.PLAYERS:
		_q.harness.drive(player, 1, 0)
	for set_index: int in FAR_ROLL_TICKS.size():
		await _q.kit.advance(FAR_ROLL_TICKS[set_index])
		for index: int in FAR_FRAMES:
			_line("far_%d_%d" % [set_index + 1, index + 1], "both Units roll back toward the circle each laid, in the chase view: set %d, consecutive frame %d of %d while the camera moves (speeds %.1f and %.1f m/s, clock %.2f s)" % [set_index + 1, index + 1, FAR_FRAMES, absf(_q.units.units[0].current_speed), absf(_q.units.units[1].current_speed), _k.tracks().now])
			await _q.kit.tick()
	_q.harness.release_all()
	await _k.run([Kit26.plan([[BRAKE_TICKS, -1, 0]]), Kit26.plan([[BRAKE_TICKS, -1, 0]])])
	_need(_touches[0] == 0 and _touches[1] == 0, "far: since the scene began Player 1's Unit touched something but the ground on %d ticks and Player 2's on %d" % [_touches[0], _touches[1]])
	await _switch_views()


func _scene_wall() -> void:
	_k.tracks().clear()
	var one: Array[Vector2i] = Kit26.plan([[WALL_TICKS, 1, 0], [BRAKE_TICKS, -1, 0]])
	await _q.map.stage([Quick.MOTORBIKE, Quick.MOTORBIKE], [SALT_1, SALT_2], [Vector3.RIGHT, Vector3.LEFT], true)
	await _k.run([one, one])
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _turn_around()
	await _q.kit.advance(Looks.HOLD_TICKS)
	var walls: Array[MeshInstance3D] = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[player]
		var behind: Vector3 = unit.global_position + unit.global_transform.basis.z * -WALL_BEHIND
		var wall: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = WALL_SIZE
		wall.mesh = quad
		wall.material_override = load(WALL_MATERIAL) as Material
		wall.global_transform = Transform3D(Basis(Vector3.UP, atan2(unit.global_transform.basis.z.x, unit.global_transform.basis.z.z)), Vector3(behind.x, WALL_SIZE.y / 2.0, behind.z))
		unit.get_parent().add_child(wall)
		walls.append(wall)
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _show("wall_across_a_track", "a wall of the ground's own material across each Motorbike's track: the track is on the ground and not on the wall", [true, true], _check_wall.bind(walls))
	for wall: MeshInstance3D in walls:
		wall.queue_free()


## The luminance contrast of a standing Unit's track in its chase view: the mean luminance beside the track less the mean on it, at FADE_BACK metres behind the
## Unit, each side WALL_SIDE m away. A coroutine: it waits for a rendered frame. Appends to `_contrasts` and prints a SPLIT line; empty headless.
func _read_contrast(moment: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var found: PackedFloat64Array = PackedFloat64Array()
	for player: int in Kit.PLAYERS:
		var image: Image = _q.units.cameras[player].get_viewport().get_texture().get_image()
		var unit: Unit = _q.units.units[player]
		if not OS.get_environment("TRACKS_DUMP").is_empty():
			image.save_png("%s/fade-%s-%d.png" % [OS.get_environment("TRACKS_DUMP"), moment, player + 1])
		var side: Vector3 = unit.global_transform.basis.x * WALL_SIDE
		var on: float = 0.0
		var beside: float = 0.0
		for back: float in FADE_BACK:
			var at: Vector3 = unit.global_position + unit.global_transform.basis.z * back
			on += _luminance(player, image, at)
			beside += (_luminance(player, image, at + side) + _luminance(player, image, at - side)) / 2.0
		found.append((beside - on) / float(FADE_BACK.size()))
	_contrasts[moment] = found
	print("SPLIT %s t=%.3f contrast moment=%s player_1=%.4f player_2=%.4f clock=%.2f" % [_q.harness.scenario, _q.harness.time(), moment, found[0], found[1], _k.tracks().now])


func _scene_fade() -> void:
	_k.tracks().clear()
	await _drive([Quick.MOTORBIKE, Quick.MOTORBIKE], [FADE_1, Quick.mirrored(FADE_1)], [Vector3.RIGHT, Vector3.LEFT], [Kit26.plan([[60, 1, 0], [BRAKE_TICKS, -1, 0]]), Kit26.plan([[60, 1, 0], [BRAKE_TICKS, -1, 0]])])
	var tracks: TyreTracks = _k.tracks()
	await _show("fade_0s", "the marks just made (the clock reads %.1f s)" % tracks.now, [true, true], _read_contrast.bind("fade_0s"))
	var made: float = tracks.now
	for seconds: float in FADE_SECONDS:
		if OS.get_environment("TRACKS_FADE_POKE").is_empty():
			await _q.kit.advance(int(ceil((made + seconds - tracks.now) * float(Engine.physics_ticks_per_second))))
		else:
			tracks.set(&"_now", made + seconds)
			await _q.kit.advance(Looks.HOLD_TICKS)
		await _show("fade_%ds" % int(seconds), "the same ground %.0f s of the Round's time later (the clock reads %.1f s; hold %.0f s, fade %.0f s)" % [tracks.now - made, tracks.now, tracks.settings.hold_seconds, tracks.settings.fade_seconds], [true, true], _read_contrast.bind("fade_%ds" % int(seconds)))
	if not _contrasts.is_empty():
		for player: int in Kit.PLAYERS:
			var fresh: float = (_contrasts["fade_0s"] as PackedFloat64Array)[player]
			var middle: float = (_contrasts["fade_30s"] as PackedFloat64Array)[player]
			var last: float = (_contrasts["fade_60s"] as PackedFloat64Array)[player]
			_need(fresh >= FADE_VISIBLE and middle < fresh and middle >= fresh * FADE_MIDDLE_SHARE and middle > last and last <= FADE_GONE, "fade: Player %d's track shows a contrast of %.3f fresh, %.3f at 30 s and %.3f at 60 s" % [player + 1, fresh, middle, last])


func _scene_restart() -> void:
	_k.tracks().clear()
	var flags: Object = _k.flags()
	await _drive([Quick.MOTORBIKE, Quick.MOTORBIKE], [GYRO_1, Quick.mirrored(GYRO_1)], [Vector3.RIGHT, Vector3.LEFT], [Kit26.plan([[60, 1, 0], [BRAKE_TICKS, -1, 0]]), Kit26.plan([[60, 1, 0], [BRAKE_TICKS, -1, 0]])])
	_need(_touches[0] == 0 and _touches[1] == 0, "restart: the drive before the Round was won touched something but the ground on %d and %d ticks" % [_touches[0], _touches[1]])
	flags.wall(1, Walls.GATE).destroy()
	var took: bool = await flags.take_flag(0, 1, Walls.GATE)
	var won: bool = await flags.deliver(0)
	_need(took and won and _q.controller.is_round_over(), "restart: the Flag taken %s, the Round won %s" % [took, won])
	await flags.restart()
	await _q.map.stage([Quick.MOTORBIKE, Quick.MOTORBIKE], [SAND, Quick.mirrored(SAND)], [Vector3.FORWARD, Vector3.FORWARD], true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _show("after_restart", "the sand where the marks were, after a Round was won and R pressed: clean ground (the clock reads %.2f s)" % _k.tracks().now, [false, false])


func _scene_gyro() -> void:
	_k.tracks().clear()
	var one: Array[Vector2i] = Kit26.plan([[GYRO_TICKS, 1, 0], [BRAKE_TICKS, -1, 0]])
	await _drive([Quick.GYROCOPTER, Quick.MOTORBIKE], [GYRO_1, Quick.mirrored(GYRO_1)], [Vector3.RIGHT, Vector3.LEFT], [one, one])
	await _show("gyro_none", "Player 1's Gyrocopter and Player 2's Motorbike have both driven the same stretch of sand at their end of the Map: only the Motorbike left a track", [false, true])
