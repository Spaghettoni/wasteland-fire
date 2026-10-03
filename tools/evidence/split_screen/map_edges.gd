extends RefCounted
## Scenario map_edges of the split screen evidence harness (split_screen_harness.gd): Map 01's
## edges on the main composition, every key a real event (W and Up held, A / D and Left / Right
## from the road pursuit, Space and Period for the shots). The Players run side by side, Player 1
## on the west half and Player 2 the mirrored run on the east half; before each run both Units are
## staged as types at rest with full tanks (map_kit.gd stage(); a Truck's road run needs more
## Fuel than a spawn gives). Two CHECK lines with the measured numbers, judged by LIMITS:
## edge_shore (AC-3): the shore boxes' thickness; each type at full throttle for four seconds,
## head-on into the west, east, north and south shores and into a channel through its ford: never
## near the sea or off the floor, stopped on the tick after its first wall contact, the shot-layer
## ray ending on the outline, no ground collider in the water, the Gyrocopter across to the shore.
## edge_cliffs (AC-4): each type head-on into the south canyon wall, the north one at its slanted
## west end and the ridge, a ground Unit stopped and the Gyrocopter across; each ground type through
## the canyon road both ways by map_kit.gd's pursuit, never the reverse key, with its time from
## mouth to mouth; a shot across the south canyon wall and one across a channel fly on.
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-3, AC-4; design/rules.md
## "Units". OWN_CHOICE. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=map_edges

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks, the key presses, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the type data, the Weapons, the record of every Shot.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 007 helpers (map_kit.gd): the Map's nodes and outlines, the staging, the pursuit.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself, with the runner's confirm_choices() in run().
const OWN_CHOICE: bool = true
## The runner's watchdog for this scenario, simulated seconds: its runs take about 137
## (the Story 007 evidence doc keeps the run).
const WATCHDOG_SECONDS: float = 300.0
## The Motorbike's index into the data (unit_kit.gd TYPE_IDS).
const MOTORBIKE: int = 0
## The Buggy's index into the data.
const BUGGY: int = 1
## The Truck's index into the data: the longest weapon range, 40 m.
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## Seconds a straight run holds the throttle.
const RUN_SECONDS: float = 4.0
## Metres from a straight run's start to the face it meets head-on: 15.8 or more ahead of the
## collider (a Motorbike reaches 24 m/s in 14.4).
const RUN_UP: float = 18.0
## Points the shore runs meet on the west half, snapped to the nearest point of the built outline;
## Player 2 runs each at x negated, so the west shore's mirror is the east one.
const SHORE_AIMS: Dictionary[StringName, Vector2] = {&"west": Vector2(-141.55, -26.6),
	&"north": Vector2(-105, -44.2), &"south": Vector2(-105, 43.86)}
## The straight runs into water and rock on the west half, (start x, start z, facing x, facing z),
## each head-on to its face: the channel from inside its ford, the south canyon wall from the salt
## flat, the north one along its slanted west end's normal, the ridge. Player 2's at x negated.
const BODY_RUNS: Dictionary[StringName, Vector4] = {&"channel": Vector4(-40, 2, 0, 1),
	&"canyon_south": Vector4(-14, -2, 0, -1), &"canyon_north": Vector4(-115.95, -38.85, 14, 5),
	&"ridge": Vector4(-70, 4, 0, 1)}
## The node each of those runs into, by path from the Map; Player 2's is a West node's East twin.
const BODY_NODES: Dictionary[StringName, String] = {&"channel": "Water/ChannelWest",
	&"canyon_south": "Cliffs/RockCanyonSouth", &"canyon_north": "Cliffs/RockCanyonNorth",
	&"ridge": "Cliffs/RidgeWest"}
## The body runs after which the Gyrocopter, past the water or rock, meets the shore head-on.
const GYRO_SHORE_RUNS: Array[StringName] = [&"channel", &"canyon_south", &"ridge"]
## The canyon road's centreline west to east, (x, z) metres (the story's positions table).
const ROAD: Array[Vector2] = [Vector2(-102, -26), Vector2(-80, -26), Vector2(-67, -36),
	Vector2(-43, -36), Vector2(-28, -28), Vector2(28, -28), Vector2(43, -36), Vector2(67, -36),
	Vector2(80, -26), Vector2(102, -26)]
## Metres a road run's path runs on past each mouth; its Unit starts there, at rest.
const ROAD_RUN_ON: float = 14.0
## Metres further back the slower Unit of a road pair starts, behind the faster one.
const ROAD_BEHIND: float = 14.0
## Seconds a road run may take beyond its path's length at its type's top speed.
const ROAD_SLACK_SECONDS: float = 4.0
## A road run is through when it is this close to its path's end, metres.
const ROAD_END_MARGIN: float = 1.0
## The shots (AC-4), (start x, start z, facing x, facing z): Player 1's Truck north across the
## south canyon wall (z -20 to -24 there), Player 2's south from the east ford into its channel.
const SHOT_RUNS: Array[Vector4] = [Vector4(-14, -6, 0, -1), Vector4(40, 4, 0, 1)]
## The limits, metres (stop in m/s): inside (a Unit's centre stays at least this far inside the
## island's outline), y (|y| stays within it: no climb, no fall), stop (the real speed on the tick
## after the first wall contact stays under it), ray (the shot-layer ray ends this close to the
## outline), pen (a ground collider corner goes at most this far into water or rock, where the stops
## are flush: the Story 007 evidence doc keeps the run), cross (the Gyrocopter's centre goes at
## least this far in), shore (AC-3: each shore box at least this thick), reach (a shot ends this far
## out along its facing's z or more: past the road into the north rock, 20 m into the channel's
## water).
const LIMITS: Dictionary[StringName, float] = {&"inside": 0.5, &"y": 0.1, &"stop": 0.5,
	&"ray": 0.01, &"pen": 0.02, &"cross": 1.0, &"shore": 1.0, &"reach": 40.0}
## A shore run's ray starts this far inside the outline (x), ends this far outside it (y), metres.
const RAY_SPAN: Vector2 = Vector2(8.0, 4.0)
## The shore chain, by path from the Map.
const SHORE_PATH: String = "Terrain/ShoreEdge"

var _harness: Harness
var _kit: Kit
var _units: Units
var _map: Map
var _outline: PackedVector2Array = PackedVector2Array()
var _lanes: Array[Lane] = []


## One Player's run in a pair: what it is, where it starts, what it meets, and its log.
class Lane extends RefCounted:
	## The Player (0 or 1); Player 2 runs on the east half.
	var player: int = 0
	## &"shore", &"body" (water or rock) or &"road".
	var kind: StringName = &""
	## The run's name in the detail; a body run's starts with its BODY_RUNS key.
	var label: String = ""
	## The type's index into the data.
	var type_index: int = 0
	## Where the Unit starts, at rest; a straight run meets its face RUN_UP ahead.
	var spot: Vector3 = Vector3.ZERO
	## The way it faces there, in the ground plane.
	var facing: Vector3 = Vector3.FORWARD
	## A body run's water or rock, world (x, z) metres.
	var body: PackedVector2Array = PackedVector2Array()
	## A road run's path, world (x, z) metres.
	var path: PackedVector2Array = PackedVector2Array()
	## The path's length, metres.
	var length: float = 0.0
	## Ticks a straight run holds the throttle; the most a road run may take.
	var ticks: int = 0
	## A shore run's ray: metres from its hit to the outline.
	var ray: float = 0.0
	## The Unit's transform after each logged tick.
	var poses: Array[Transform3D] = []
	## 1 on each logged tick the Unit touched a wall.
	var contact: PackedByteArray = PackedByteArray()
	## The Unit's drive speed after each logged tick.
	var drive: PackedFloat64Array = PackedFloat64Array()
	## True once the run has let its keys go.
	var done: bool = false


## Runs both checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_map = Map.new(harness, _kit)
	_kit.on_tick = _log_tick
	await _harness.confirm_choices()
	await _kit.advance(Kit.START_TICKS)
	_outline = _map.outline()
	var problems: PackedStringArray = []
	var boxes: String = _shore_boxes(problems)
	var shore: Array[Lane] = _shore_lanes()
	_kit.verdict("edge_shore", problems, boxes + " | " + await _drive_pairs(shore, problems))
	problems = []
	var cliffs: Array[Lane] = _cliff_lanes()
	var detail: String = await _drive_pairs(cliffs, problems)
	_kit.verdict("edge_cliffs", problems, "tanks full before each run (refuel()) | " + detail + " | " + await _shots(problems))
	_harness.finish("shore_lanes=%d cliff_lanes=%d tanks=full" % [shore.size(), cliffs.size()])


## The shore runs (AC-3) as pairs (Player 1, Player 2): each type at the west shore beside the east
## one, each type at the north shore beside the south one, then the channels (Motorbike beside
## Buggy, Truck beside Gyrocopter).
func _shore_lanes() -> Array[Lane]:
	var lanes: Array[Lane] = []
	for type_index: int in Units.TYPE_IDS.size():
		lanes.append(_shore_lane(Harness.PLAYER_1, &"west", type_index))
		lanes.append(_shore_lane(Harness.PLAYER_2, &"west", type_index))
	for type_index: int in Units.TYPE_IDS.size():
		lanes.append(_shore_lane(Harness.PLAYER_1, &"north", type_index))
		lanes.append(_shore_lane(Harness.PLAYER_2, &"south", type_index))
	for types: Vector2i in [Vector2i(MOTORBIKE, BUGGY), Vector2i(TRUCK, GYROCOPTER)]:
		lanes.append(_body_lane(Harness.PLAYER_1, &"channel", types.x))
		lanes.append(_body_lane(Harness.PLAYER_2, &"channel", types.y))
	return lanes


## The cliff runs (AC-4) as pairs: each type head-on into the south canyon wall, the north one and
## the ridge; the road with the faster Unit ahead, Motorbike and Truck west to east and back, then
## the Buggy each way beside the ridge's Truck and Gyrocopter.
func _cliff_lanes() -> Array[Lane]:
	var lanes: Array[Lane] = []
	for run: StringName in [&"canyon_south", &"canyon_north", &"ridge"]:
		for types: Vector2i in [Vector2i(MOTORBIKE, BUGGY), Vector2i(TRUCK, GYROCOPTER)]:
			if run != &"ridge" or types.x == MOTORBIKE:
				lanes.append(_body_lane(Harness.PLAYER_1, run, types.x))
				lanes.append(_body_lane(Harness.PLAYER_2, run, types.y))
	for from_east: bool in [false, true]:
		lanes.append(_road_lane(Harness.PLAYER_1, MOTORBIKE, from_east, 0.0))
		lanes.append(_road_lane(Harness.PLAYER_2, TRUCK, from_east, ROAD_BEHIND))
	for from_east: bool in [false, true]:
		lanes.append(_road_lane(Harness.PLAYER_1, BUGGY, from_east, 0.0))
		lanes.append(_body_lane(Harness.PLAYER_2, &"ridge", GYROCOPTER if from_east else TRUCK))
	return lanes


## A lane of a Player's run as a type, holding its keys RUN_SECONDS.
func _lane(player: int, kind: StringName, type_index: int) -> Lane:
	var lane: Lane = Lane.new()
	lane.player = player
	lane.kind = kind
	lane.type_index = type_index
	lane.ticks = _harness.ticks_in(RUN_SECONDS)
	return lane


## A shore run: full throttle along the outline's outward normal at its point nearest the aim
## (x negated for Player 2), from RUN_UP inside it.
func _shore_lane(player: int, aim: StringName, type_index: int) -> Lane:
	var lane: Lane = _lane(player, &"shore", type_index)
	lane.label = "east" if player == Harness.PLAYER_2 and aim == &"west" else String(aim)
	var at: Vector2 = SHORE_AIMS[aim] * (Vector2(-1, 1) if player == Harness.PLAYER_2 else Vector2.ONE)
	var nearest: float = INF
	for index: int in _outline.size():
		var start: Vector2 = _outline[index]
		var end: Vector2 = _outline[(index + 1) % _outline.size()]
		var foot: Vector2 = Geometry2D.get_closest_point_to_segment(at, start, end)
		if foot.distance_to(at) < nearest:
			nearest = foot.distance_to(at)
			var normal: Vector2 = (end - start).orthogonal().normalized()
			lane.facing = Vector3(normal.x, 0.0, normal.y) * signf(normal.dot(foot))
			lane.spot = Vector3(foot.x, 0.0, foot.y) - lane.facing * RUN_UP
	return lane


## A straight run into water or rock (BODY_RUNS, mirrored for Player 2) and that body's outline in
## world (x, z): a CSG rock's polygon, or the hull of a water body's box (map_kit.gd footprint()).
func _body_lane(player: int, run: StringName, type_index: int) -> Lane:
	var lane: Lane = _lane(player, &"body", type_index)
	var flip: float = -1.0 if player == Harness.PLAYER_2 else 1.0
	var data: Vector4 = BODY_RUNS[run]
	lane.label = "%s %s" % [run, "E" if flip < 0.0 else "W"]
	lane.spot = Vector3(data.x * flip, 0.0, data.y)
	lane.facing = Vector3(data.z * flip, 0.0, data.w).normalized()
	var path: String = BODY_NODES[run].replace("West", "East") if flip < 0.0 else BODY_NODES[run]
	var node: Node = _map.find(path)
	if node is CSGPolygon3D:
		lane.body = _map.outline(path)
	elif node != null:
		var points: PackedVector2Array = []
		for point: Vector3 in _map.footprint(node):
			points.append(Vector2(point.x, point.z))
		lane.body = Geometry2D.convex_hull(points)
	return lane


## A road run on the centreline from its west mouth (or its east one) extended ROAD_RUN_ON
## past both mouths; the Unit starts at rest behind metres before the extension, along the road.
func _road_lane(player: int, type_index: int, from_east: bool, behind: float) -> Lane:
	var lane: Lane = _lane(player, &"road", type_index)
	var line: PackedVector2Array = PackedVector2Array(ROAD)
	if from_east:
		line.reverse()
	var out: Vector2 = line[0].direction_to(line[1])
	var last: int = line.size() - 1
	lane.path = PackedVector2Array([line[0] - out * (ROAD_RUN_ON + behind)])
	lane.path.append_array(line)
	lane.path.append(line[last] + line[last - 1].direction_to(line[last]) * ROAD_RUN_ON)
	for index: int in range(1, lane.path.size()):
		lane.length += lane.path[index - 1].distance_to(lane.path[index])
	lane.label = "E>W" if from_east else "W>E"
	lane.spot = Vector3(lane.path[0].x, 0.0, lane.path[0].y)
	lane.facing = Vector3(out.x, 0.0, out.y)
	lane.ticks = _harness.ticks_in(lane.length / _units.stats(type_index).max_speed + ROAD_SLACK_SECONDS)
	return lane


## Drives the lanes two at a time (Player 1, Player 2): stages both Units with full tanks, casts
## each shore lane's ray, sets both lanes' keys (_control()) after every tick until both are done,
## logging each tick (_log_tick()), prints a SPLIT line and judges both. Their details, joined.
func _drive_pairs(lanes: Array[Lane], problems: PackedStringArray) -> String:
	var details: PackedStringArray = []
	for index: int in range(0, lanes.size(), 2):
		var pair: Array[Lane] = [lanes[index], lanes[index + 1]]
		var types: Array[int] = [pair[0].type_index, pair[1].type_index]
		var spots: Array[Vector3] = [pair[0].spot, pair[1].spot]
		var facings: Array[Vector3] = [pair[0].facing, pair[1].facing]
		await _map.stage(types, spots, facings, true)
		for lane: Lane in pair:
			lane.ray = _ray_error(lane)
			if lane.kind == &"road":
				_map.set_path(lane.player, lane.path)
			_control(lane)
		_lanes = pair
		while not (pair[0].done and pair[1].done):
			await _kit.tick()
			for lane: Lane in pair:
				_control(lane)
		_lanes = []
		_harness.phase = StringName("%s|%s" % [pair[0].label, pair[1].label])
		_harness.print_progress()
		details.append(_judge(pair[0], problems))
		details.append(_judge(pair[1], problems))
	return "; ".join(details)


## Sets a lane's keys for the next tick: a straight run holds the throttle for its ticks, a road
## run steers by the pursuit to its path's end or its tick limit; then every key goes up for good.
func _control(lane: Lane) -> void:
	if not lane.done and lane.kind == &"road":
		lane.done = lane.poses.size() >= lane.ticks or _map.steer(lane.player, 1) >= lane.length - ROAD_END_MARGIN
	elif not lane.done:
		lane.done = lane.poses.size() >= lane.ticks
		_harness.drive(lane.player, 1, 0)
	if lane.done:
		_harness.drive(lane.player, 0, 0)


## Logs each driven lane's Unit after a tick: its transform, a wall contact (map_kit.gd), its drive
## speed. The check kit's on_tick.
func _log_tick() -> void:
	for lane: Lane in _lanes:
		var unit: Unit = _map.units[lane.player]
		lane.poses.append(unit.global_transform)
		lane.contact.append(1 if _map.wall_contact(unit) else 0)
		lane.drive.append(unit.current_speed)


## A shore lane's ray, RAY_SPAN about the outline's point the run meets, at the Weapons'
## shooting height on their shot layers: metres from its hit to that point (INF with no hit).
func _ray_error(lane: Lane) -> float:
	if lane.kind != &"shore":
		return 0.0
	var rules: MatchRules = _units.weapons[Harness.PLAYER_1].rules
	var foot: Vector3 = lane.spot + lane.facing * RUN_UP + Vector3.UP * rules.shooting_height
	var hit: Vector3 = _map.ray(foot - lane.facing * RAY_SPAN.x, foot + lane.facing * RAY_SPAN.y, rules.shot_collision_mask)
	return INF if hit == Vector3.INF else Vector2(hit.x - foot.x, hit.z - foot.z).length()


## Judges a lane from its log against LIMITS and returns its detail. Every lane: inside and y. A
## road lane: _judge_road(). A run that ends head-on (every one but the Gyrocopter's off the shore
## rock): stop. A shore lane: ray. A body lane: pen for a ground Unit, cross for the Gyrocopter.
func _judge(lane: Lane, problems: PackedStringArray) -> String:
	var seen: Dictionary[StringName, float] = _measure(lane)
	var who: String = "%s %s" % [lane.label, Units.TYPE_IDS[lane.type_index]]
	_kit.need(problems, seen[&"inside"] >= LIMITS[&"inside"], "%s came within %.2f m of the sea" % [who, seen[&"inside"]])
	_kit.need(problems, seen[&"y"] <= LIMITS[&"y"], "%s left the floor (|y| %.3f)" % [who, seen[&"y"]])
	if lane.kind == &"road":
		return _judge_road(lane, problems, who)
	var detail: String = "%s in=%.2f end=%.2f y=%.3f" % [who, seen[&"inside"], seen[&"end"], seen[&"y"]]
	if lane.kind == &"shore" or lane.type_index != GYROCOPTER or GYRO_SHORE_RUNS.has(StringName(lane.label.get_slice(" ", 0))):
		_kit.need(problems, seen[&"stop"] < LIMITS[&"stop"], "%s did not stop at its first contact" % who)
		detail += " v=%.2f" % seen[&"stop"]
	if lane.kind == &"shore":
		_kit.need(problems, lane.ray <= LIMITS[&"ray"], "%s ray %.3f m off the outline" % [who, lane.ray])
		return detail + " ray=%.3f" % lane.ray
	if lane.type_index == GYROCOPTER:
		_kit.need(problems, seen[&"depth"] >= LIMITS[&"cross"], "%s did not cross" % who)
		return detail + " depth=%.2f" % seen[&"depth"]
	_kit.need(problems, not lane.body.is_empty() and seen[&"pen"] <= LIMITS[&"pen"], "%s went %.3f m in" % [who, seen[&"pen"]])
	return detail + " pen=%.3f" % seen[&"pen"]


## A lane's numbers: inside (the centre's least distance inside the island's outline) and end
## (after its last tick), y (the largest |y|), stop (the real speed on the tick after the first
## wall contact, INF without one), pen (the deepest a collider corner went into the lane's body)
## and depth (the deepest its centre went in).
func _measure(lane: Lane) -> Dictionary[StringName, float]:
	var seen: Dictionary[StringName, float] = {&"inside": INF, &"y": 0.0, &"stop": INF, &"pen": -INF, &"depth": -INF, &"end": -INF}
	var stats: UnitStats = _units.stats(lane.type_index)
	for pose: Transform3D in lane.poses:
		seen[&"inside"] = minf(seen[&"inside"], _map.inside_by(pose.origin, _outline))
		seen[&"y"] = maxf(seen[&"y"], absf(pose.origin.y))
		if not lane.body.is_empty():
			seen[&"depth"] = maxf(seen[&"depth"], _map.inside_by(pose.origin, lane.body))
			for corner: Vector3 in _corners(pose, stats):
				seen[&"pen"] = maxf(seen[&"pen"], _map.inside_by(corner, lane.body))
	var first: int = lane.contact.find(1)
	if first >= 1 and first + 1 < lane.poses.size():
		seen[&"stop"] = _speed(lane, first + 1)
	if not lane.poses.is_empty():
		seen[&"end"] = _map.inside_by(lane.poses[lane.poses.size() - 1].origin, _outline)
	return seen


## A road lane: through from mouth to mouth within its ticks and never in reverse (its drive
## speed never below zero; no reverse key is pressed); its detail: the time between the mouths
## (interpolated within the tick), the lowest drive speed and the wall-contact ticks there.
func _judge_road(lane: Lane, problems: PackedStringArray, who: String) -> String:
	var last: int = lane.path.size() - 1
	var sense: float = signf(lane.path[last].x - lane.path[0].x)
	var enter: float = _crossing(lane, lane.path[1].x, sense)
	var leave: float = _crossing(lane, lane.path[last - 1].x, sense)
	var lowest: float = INF
	var touches: int = 0
	for index: int in range(ceili(maxf(enter, 0.0)), floori(leave) + 1):
		lowest = minf(lowest, lane.drive[index])
		touches += lane.contact[index]
	var backward: float = 0.0
	for speed: float in lane.drive:
		backward = minf(backward, speed)
	_kit.need(problems, enter >= 0.0 and leave > enter, "%s did not get through the canyon" % who)
	_kit.need(problems, backward >= 0.0, "%s drove in reverse" % who)
	return "%s %.2fs low=%.2f contact=%d" % [who, (leave - enter) / _harness.ticks_in(1.0), lowest, touches]


## The logged tick, interpolated, on which a lane's Unit first reaches x going the sense's way,
## or -1.0.
func _crossing(lane: Lane, x: float, sense: float) -> float:
	for index: int in range(1, lane.poses.size()):
		if (lane.poses[index].origin.x - x) * sense >= 0.0:
			var before: float = lane.poses[index - 1].origin.x
			return index - 1 + (x - before) / (lane.poses[index].origin.x - before)
	return -1.0


## AC-4's shots: a Truck each at SHOT_RUNS fires once, both fire keys (Space, Period) down for one
## tick; each Shot must end LIMITS reach or more out along its facing's z.
func _shots(problems: PackedStringArray) -> String:
	var types: Array[int] = [TRUCK, TRUCK]
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for shot: Vector4 in SHOT_RUNS:
		spots.append(Vector3(shot.x, 0.0, shot.y))
		facings.append(Vector3(shot.z, 0.0, shot.w))
	await _map.stage(types, spots, facings, true)
	var first: int = _units.shots.size()
	var keys: Array[Key] = [_harness.fire_key(Harness.PLAYER_1), _harness.fire_key(Harness.PLAYER_2)]
	await _kit.press(keys)
	await _kit.advance(Units.HIT_LIMIT_TICKS)
	var ends: PackedStringArray = []
	for index: int in range(first, _units.shots.size()):
		var end: Vector3 = _units.shot_ends[index]
		var shot: Vector4 = SHOT_RUNS[Harness.PLAYER_1 if end.x < 0.0 else Harness.PLAYER_2]
		ends.append("(%.2f, %.2f)" % [end.x, end.z])
		_kit.need(problems, end != Vector3.INF and end.z * shot.w >= LIMITS[&"reach"], "a shot stopped at z %.2f" % end.z)
	_kit.need(problems, ends.size() == SHOT_RUNS.size(), "%d shots, not %d" % [ends.size(), SHOT_RUNS.size()])
	return "shots from z -6 north and z 4 south end at %s" % ", ".join(ends)


## AC-3's shore chain as built: its box count and the thinnest (the thinner
## horizontal side of each BoxShape3D), which must be LIMITS shore or more.
func _shore_boxes(problems: PackedStringArray) -> String:
	var thinnest: float = INF
	var count: int = 0
	var chain: Node = _map.find(SHORE_PATH)
	for node: Node in (chain.find_children("*", "CollisionShape3D", true, false) if chain != null else []):
		var box: BoxShape3D = (node as CollisionShape3D).shape as BoxShape3D
		thinnest = minf(thinnest, minf(box.size.x, box.size.z) if box != null else 0.0)
		count += 1
	_kit.need(problems, count > 0 and thinnest >= LIMITS[&"shore"], "a shore box is under %.1f m thick" % LIMITS[&"shore"])
	return "shore boxes=%d thinnest=%.2f m" % [count, thinnest]


## A Unit's collider corners in the ground plane at a pose: its type's collision_size about its
## collision_center.
func _corners(pose: Transform3D, stats: UnitStats) -> PackedVector3Array:
	var half: Vector3 = stats.collision_size / 2.0
	var corners: PackedVector3Array = []
	for side: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		corners.append(pose * (stats.collision_center + Vector3(half.x * side.x, 0.0, half.z * side.y)))
	return corners


## A lane's real speed over one logged tick, in the ground plane, m/s.
func _speed(lane: Lane, index: int) -> float:
	var move: Vector3 = lane.poses[index].origin - lane.poses[index - 1].origin
	return Vector2(move.x, move.z).length() * _harness.ticks_in(1.0)
