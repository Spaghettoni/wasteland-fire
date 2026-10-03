extends RefCounted
## Scenario map_showcase of the split screen evidence harness (split_screen_harness.gd): about
## 35 s of staged moments on Map 01 for the retained screenshots of Story 007's look, both views at
## once, every Player key a real event. The choice panels; Player 2 steps right to the Buggy, both
## confirm (Player 1 the Motorbike) and the Units appear in their Garages. Then each moment is
## staged by map_kit.gd's stage() (place(), three ticks, a typed spawn of a Unit in play, three
## ticks, full tanks) and held still (STILLS) or driven by real keys: each bend of the canyon road
## (Player 1's Truck in the west half, Player 2's Buggy in the east, by map_kit.gd's pursuit); the
## Gyrocopters crossing rock (Player 1 north over the south canyon wall, Player 2 south over the
## east ridge); last, each Motorbike drives in through the other Player's gate and takes that Flag
## under the water tower (drive_to_flags()), its cream heading cue in view. SPLIT lines come at
## every moment (moment=, after its hold) and spawn, bend, rock crossing and Flag taken (event=),
## with both Units' type, place and heading and frame=, in a --write-movie run the number of the
## PNG that shows the moment (the hold's last, MOMENT_FRAME_LAG back) or the event. It ends with
## RESULT ok, or one failing CHECK named premise when the run did not reach its steps, so an empty
## recording cannot pass as evidence. OWN_CHOICE; the shipped data; tooling only.
## Implements: production/epics/wasteland-fire/story-007-the-map.md, Test Evidence (AC-11 to 15).
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/map.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=map_showcase

## The types in the data's order (unit_kit.gd TYPE_IDS): each value indexes unit_types.
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the controller, the Units, the spawn record.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 007 helpers (map_kit.gd): the staging, the pursuit, the drive onto the Flags.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The still moments in order: name to [the types, the spots (Player 1's x, z, then Player 2's),
## the facings (likewise)], metres. under_towers: 3.5 m before each Flag's seat facing the gate;
## gates: 15 m out of each gate; towers_*: each Player faces its own water tower from a corner of
## the salt flat (3 m inside, 7 m at the far end so the camera clears the near Base's corner
## tower; Player 2 from the mirrored one) or its centre (the depot fills it: 11 m and 16 m north,
## so neither Unit hides the other's view); depot: 20 m either side; fords: a Unit in each, facing
## south.
const STILLS: Dictionary[StringName, Array] = {
	&"under_towers": [Vector2i(Type.GYROCOPTER, Type.MOTORBIKE), Vector4(-109.5, 0, 109.5, 0), Vector4(1, 0, -1, 0)],
	&"gates": [Vector2i(Type.BUGGY, Type.TRUCK), Vector4(-90, 0, 90, 0), Vector4(-1, 0, 1, 0)],
	&"towers_north_west": [Vector2i(Type.TRUCK, Type.BUGGY), Vector4(-92, -15, 92, -15), Vector4(-21, 15, 21, 15)],
	&"towers_south_west": [Vector2i(Type.TRUCK, Type.BUGGY), Vector4(-92, 15, 92, 15), Vector4(-21, -15, 21, -15)],
	&"towers_north_east": [Vector2i(Type.TRUCK, Type.BUGGY), Vector4(88, -15, -88, -15), Vector4(-201, 15, 201, 15)],
	&"towers_south_east": [Vector2i(Type.TRUCK, Type.BUGGY), Vector4(88, 15, -88, 15), Vector4(-201, -15, 201, -15)],
	&"towers_centre": [Vector2i(Type.TRUCK, Type.BUGGY), Vector4(0, -11, 0, -16), Vector4(-113, 11, 113, 16)],
	&"depot": [Vector2i(Type.MOTORBIKE, Type.TRUCK), Vector4(-20, 0, 20, 0), Vector4(1, 0, -1, 0)],
	&"fords": [Vector2i(Type.BUGGY, Type.MOTORBIKE), Vector4(-40, -12, 40, -12), Vector4(0, 1, 0, 1)],
}
## The canyon road's west half for Player 1's Truck, (x, z) metres: from 14 m past the west mouth,
## due east, through the four bends of the story file's road centreline to 8 m past the last one.
const ROAD_WEST: Array[Vector2] = [Vector2(-116, -26), Vector2(-102, -26), Vector2(-80, -26),
	Vector2(-67, -36), Vector2(-43, -36), Vector2(-28, -28), Vector2(-20, -28)]
## The index of the first bend in ROAD_WEST; the bends run to its last point but one.
const FIRST_BEND: int = 2
## A bend's line comes this far past the bend along the path, metres: the camera looks round it.
const BEND_LEAD: float = 4.0
## A drive along a path ends this close to the path's end, metres.
const END_MARGIN: float = 1.0
## The Gyrocopters' starts (Player 1's x, z, then Player 2's), metres: 16 m south of the south
## canyon wall (its face at Z -20) at x -14, and 16 m north of the east ridge (its face at Z 22).
const GYRO_SPOTS: Vector4 = Vector4(-14, -4, 70, 6)
## The Gyrocopters' facings (likewise): Player 1 north, Player 2 south.
const GYRO_FACINGS: Vector4 = Vector4(0, -1, 0, 1)
## Seconds the Gyrocopters fly with the throttle held.
const GYRO_SECONDS: float = 3.0
## The cliffs and water physics layer, by value (Story 005).
const CLIFFS_WATER_LAYER: int = 32
## Height above a Unit the rock probe's ray starts, metres: above the 2 m rock.
const PROBE_HEIGHT: float = 10.0
## The Motorbikes' starts (likewise), metres: 9 m out of the other Player's gate on its axis.
const RAID_SPOTS: Vector4 = Vector4(96, 0, -96, 0)
## Their facings: Player 1 east into Base B, Player 2 west into Base A.
const RAID_FACINGS: Vector4 = Vector4(1, 0, -1, 0)
## Cruise of the drive onto the Flags, m/s: slow enough to stop under the tower.
const RAID_CRUISE: float = 6.0
## Seconds each moment is held still before its line (and its frame) is taken.
const HOLD_SECONDS: float = 1.0
## Main-loop iterations from a moment's line back to the PNG that shows it: the next staging moves
## the Units in the line's own iteration, before that frame is drawn (measured, --write-movie).
const MOMENT_FRAME_LAG: int = 1
## A Unit rolling slower than this, m/s, stands: the brakes let go.
const STOP_SPEED: float = 0.5
## The most ticks a drive or a brake may take before it gives up.
const LIMIT_TICKS: int = 900
## The moments besides STILLS: panels, garage_spawn, road_end, gyro_start, gyro_end, flags_taken.
const OTHER_MOMENTS: int = 6

var _harness: Harness
var _kit: Kit
var _units: Units
var _map: Map
## The moments reached, in order.
var _reached: PackedStringArray = []
## Whether each Player's Unit reached the end of its road path.
var _road_done: Array[bool] = [false, false]
## Ticks each Player's Gyrocopter was over rock, and whether it is over rock now.
var _rock_ticks: Array[int] = [0, 0]
var _over: Array[bool] = [false, false]
## Ticks the drive onto the Flags took, -1 when it gave up.
var _flag_ticks: int = -1


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_map = Map.new(harness, _kit)
	_units.controller.unit_spawned.connect(func(player: int) -> void: _line("event=p%d_appears_as_%s" % [player + 1, _units.units[player].type_id]))
	_units.controller.flag_picked_up.connect(func(carrier: int, flag: int) -> void: _line("event=p%d_takes_flag_of_p%d" % [carrier + 1, flag + 1]))
	await _moment(&"panels")
	await _kit.press_settled(Kit.KEYS_NEXT_2)
	await _harness.confirm_choices()
	await _moment(&"garage_spawn")
	for still: StringName in STILLS:
		await _still(still)
	await _road()
	await _gyro()
	await _flags()
	_finish()


## Holds the keys as they are for HOLD_SECONDS under the moment's name, files it, prints its line.
func _moment(moment: StringName) -> void:
	_harness.phase = moment
	await _kit.advance(_harness.ticks_in(HOLD_SECONDS))
	_reached.append(moment)
	_line("moment=%s" % moment, MOMENT_FRAME_LAG)


## Stages a moment of STILLS (map_kit.gd stage(): types, spots, facings, keys up, full tanks).
func _still(still: StringName) -> void:
	var row: Array = STILLS[still]
	var types: Vector2i = row[0]
	var kinds: Array[int] = [types.x, types.y]
	await _map.stage(kinds, _pair(row[1]), _pair(row[2]), true)
	await _moment(still)


## Each bend of the canyon road: Player 1's Truck drives ROAD_WEST and Player 2's Buggy its mirror
## at once, by map_kit.gd's pursuit with the throttle held (_road_tick()), until both reach their
## ends; both brake to a stand, then hold a moment.
func _road() -> void:
	var mirrored: PackedVector2Array = []
	for point: Vector2 in ROAD_WEST:
		mirrored.append(Vector2(-point.x, point.y))
	var paths: Array[PackedVector2Array] = [PackedVector2Array(ROAD_WEST), mirrored]
	var kinds: Array[int] = [Type.TRUCK, Type.BUGGY]
	var start: Vector4 = Vector4(ROAD_WEST[0].x, ROAD_WEST[0].y, -ROAD_WEST[0].x, ROAD_WEST[0].y)
	await _map.stage(kinds, _pair(start), _pair(Vector4(1, 0, -1, 0)), true)
	_harness.phase = &"road"
	for player: int in Kit.PLAYERS:
		_map.set_path(player, paths[player])
	var bends: Array[int] = [FIRST_BEND, FIRST_BEND]
	for _count: int in LIMIT_TICKS:
		_road_tick(paths, bends)
		await _kit.tick()
		if _road_done[0] and _road_done[1]:
			break
	await _brake()
	await _moment(&"road_end")


## One tick of the road drive: each Player still driving steers by the pursuit, prints a bend's
## line when due (bends holds each Player's next bend index) and is done near its path's end; a
## Player done holds its reverse key while it still rolls forward.
func _road_tick(paths: Array[PackedVector2Array], bends: Array[int]) -> void:
	for player: int in Kit.PLAYERS:
		var path: PackedVector2Array = paths[player]
		if not _road_done[player]:
			var arc: float = _map.steer(player, 1)
			if bends[player] <= path.size() - 2 and arc >= _arc_at(path, bends[player]) + BEND_LEAD:
				_line("event=p%d_bend_%d" % [player + 1, bends[player] - FIRST_BEND + 1])
				bends[player] += 1
			_road_done[player] = arc >= _arc_at(path, path.size() - 1) - END_MARGIN
		if _road_done[player]:
			_harness.drive(player, -1 if _units.units[player].current_speed > STOP_SPEED else 0, 0)


## Metres along a path from its start to its point at an index.
func _arc_at(path: PackedVector2Array, index: int) -> float:
	var arc: float = 0.0
	for at: int in range(1, index + 1):
		arc += path[at - 1].distance_to(path[at])
	return arc


## The Gyrocopters cross rock: both put in play as Gyrocopters at GYRO_SPOTS (Units in play, so
## the Round sees them alive), held a moment, then flown with the throttle held for GYRO_SECONDS;
## a line comes each time one goes over rock or off it (_over_rock()). Both brake to a stand.
func _gyro() -> void:
	var kinds: Array[int] = [Type.GYROCOPTER, Type.GYROCOPTER]
	await _map.stage(kinds, _pair(GYRO_SPOTS), _pair(GYRO_FACINGS), true)
	await _moment(&"gyro_start")
	_harness.phase = &"gyro_crossing"
	for _count: int in _harness.ticks_in(GYRO_SECONDS):
		for player: int in Kit.PLAYERS:
			_harness.drive(player, 1, 0)
		await _kit.tick()
		for player: int in Kit.PLAYERS:
			var over: bool = _over_rock(_units.units[player])
			_rock_ticks[player] += 1 if over else 0
			if over != _over[player]:
				_over[player] = over
				_line("event=p%d_%s" % [player + 1, "over_rock" if over else "off_rock"])
	await _brake()
	await _moment(&"gyro_end")


## True when a ray down through the Unit's place meets a drawn cliff of the cliffs and water layer:
## the canyon rock or the ridge, whose CSG node is the collider the query returns, and not a
## channel's water, a bare StaticBody3D.
func _over_rock(unit: Unit) -> bool:
	var at: Vector3 = unit.global_position
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3.UP * PROBE_HEIGHT, at + Vector3.DOWN, CLIFFS_WATER_LAYER)
	return unit.get_world_3d().direct_space_state.intersect_ray(query).get("collider") is CSGShape3D


## A Motorbike carries each Flag: both put in play as Motorbikes at RAID_SPOTS drive in through
## the other Player's gate until each carries that Flag and stands (drive_to_flags()); held.
func _flags() -> void:
	var kinds: Array[int] = [Type.MOTORBIKE, Type.MOTORBIKE]
	await _map.stage(kinds, _pair(RAID_SPOTS), _pair(RAID_FACINGS), true)
	_harness.phase = &"flags_in"
	_flag_ticks = await _map.drive_to_flags(RAID_CRUISE, STOP_SPEED, LIMIT_TICKS)
	await _moment(&"flags_taken")


## Holds each Player's key against its Unit's motion until both stand (at most LIMIT_TICKS).
func _brake() -> void:
	for _count: int in LIMIT_TICKS:
		var rolling: bool = false
		for player: int in Kit.PLAYERS:
			var speed: float = _units.units[player].current_speed
			var against: int = 0 if absf(speed) <= STOP_SPEED else (-1 if speed > 0.0 else 1)
			_harness.drive(player, against, 0)
			rolling = rolling or against != 0
		if not rolling:
			break
		await _kit.tick()
	_harness.release_all()


## The two (x, z) pairs of a Vector4 (Player 1's, then Player 2's) as points on the ground.
func _pair(values: Vector4) -> Array[Vector3]:
	var pair: Array[Vector3] = [Vector3(values.x, 0.0, values.y), Vector3(values.z, 0.0, values.w)]
	return pair


## Prints one SPLIT line: time, frame= (main-loop iterations less lag), phase, the label (moment=
## or event=), both Units' type, place and heading (degrees from north toward east), Round state.
func _line(label: String, lag: int = 0) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units.units[player]
		var ahead: Vector3 = -unit.global_transform.basis.z
		fields.append("p%d_type=%s p%d_x=%.2f p%d_z=%.2f p%d_heading=%.0f" % [player + 1, unit.type_id, player + 1,
			unit.global_position.x, player + 1, unit.global_position.z, player + 1, fposmod(rad_to_deg(atan2(ahead.x, -ahead.z)), 360.0)])
	print("SPLIT %s t=%.3f frame=%d phase=%s %s %s round=%s" % [_harness.scenario, _harness.time(), Engine.get_process_frames() - lag,
		_harness.phase, label, " ".join(fields), "OVER" if _units.controller.is_round_over() else "RUNNING"])


## The problems that show the run did not reach its steps: a moment missed; no Motorbike for
## Player 1 or Buggy for Player 2 at the start; a road not driven to its end; a Gyrocopter never
## over rock; a Flag not carried; a destruction or the Round over.
func _premise_problems(spawns: PackedStringArray) -> PackedStringArray:
	var problems: PackedStringArray = []
	var expected: int = STILLS.size() + OTHER_MOMENTS
	var carrying: int = 0
	for player: int in Kit.PLAYERS:
		carrying += int(_units.controller.flag_status(player) == MatchController.FlagStatus.CARRYING_ENEMY)
	_kit.need(problems, _reached.size() == expected, "moments reached %d of %d" % [_reached.size(), expected])
	_kit.need(problems, int(spawns.has("p1_motorbike")) + int(spawns.has("p2_buggy")) == 2, "no Motorbike for Player 1 or Buggy for Player 2")
	_kit.need(problems, _road_done.count(true) == Kit.PLAYERS.size(), "a road path not driven to its end")
	_kit.need(problems, mini(_rock_ticks[0], _rock_ticks[1]) > 0, "a Gyrocopter never over rock")
	_kit.need(problems, _flag_ticks >= 0, "the drive onto the Flags gave up")
	_kit.need(problems, carrying == Kit.PLAYERS.size(), "a Flag not carried")
	_kit.need(problems, _units.destroyed.is_empty(), "a destruction")
	_kit.need(problems, not _units.controller.is_round_over(), "the Round over")
	return problems


## Prints the failing premise check when the run did not reach its steps (_premise_problems()),
## then the RESULT line.
func _finish() -> void:
	var spawns: PackedStringArray = []
	for index: int in _units.spawns.size():
		spawns.append("p%d_%s" % [_units.spawns[index].x + 1, _units.spawn_types[index]])
	var problems: PackedStringArray = _premise_problems(spawns)
	var detail: String = "moments=%d spawns=%s road_done=%s,%s rock_ticks=%d,%d flag_ticks=%d destroyed=%d" % [_reached.size(),
		",".join(spawns), _road_done[0], _road_done[1], _rock_ticks[0], _rock_ticks[1], _flag_ticks, _units.destroyed.size()]
	if not problems.is_empty():
		_kit.verdict("premise", problems, "the run did not reach its steps: " + detail)
	_harness.finish(detail)
