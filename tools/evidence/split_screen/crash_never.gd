extends RefCounted
## What never crashes a Unit, for the crash scenario (Story 021 AC-4): floor_never (the Floor, which the Gyrocopter's move reports on
## every tick it stands or turns, never crashes it), sea_edge_stops (each of the four shores flown into head-on at top speed, at
## the crash speed and more, only stops the Gyrocopter, because its bodies are in the Map's edge group), low_pieces_pass (the
## seven flights of Story 020 over every low piece, no contact), units_pass (a Gyrocopter flown through a standing Motorbike, Buggy
## and Truck and head-on through a second Gyrocopter) and ground_never (a Motorbike, a Buggy and a Truck driven at full throttle at
## a corner tower, a leg, a Turret and a tank stop as before: their crash speed is zero). Run by crash.gd. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs and the story's values.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")
## The lanes of Story 020's flights over the low pieces (heights_over.gd): the Base's axis, a field wall, a container, a wreck, the
## ridges and the canyon; and where a Gyrocopter is flown through a standing Unit.
const Over: GDScript = preload("res://tools/evidence/split_screen/heights_over.gd")

## The open ground the Floor flight is made on (the flat west of the ford) and the ticks of its three stretches.
const OPEN_START: Vector3 = Vector3(-95.0, 0.0, -12.0)
const STAND_TICKS: int = 60
const FLY_TICKS: int = 120
const SPIN_TICKS: int = 90
## The ticks a stopped Unit is held against what stopped it, and the travel it may add (m).
const HOLD_TICKS: int = 60
const STOP_MOVE: float = 0.05
## The ticks a crossing may take.
const LANE_LIMIT: int = 420
const LONG_LIMIT: int = 700
## The ticks of full throttle held against a piece after a ground Unit first touches it.
const GROUND_HOLD: int = 12

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().restore_all(true)
	await _k.walls().turrets_down()
	await _floor_never()
	await _sea_edge_stops()
	await _low_pieces_pass()
	await _units_pass()
	await _k.walls().restore_all(true)
	await _ground_never()


## floor_never (AC-4): a Gyrocopter stands, turns on the spot and flies at full throttle on open ground: the Floor is reported
## (normal up, angle zero) on every tick it stands or turns at rest, none of those ticks is a wall's, and it is alive at the end.
## The flight reports no collision at all: a move along the floor does not touch it (measured on 4.7.2 with Jolt).
func _floor_never() -> void:
	var problems: PackedStringArray = []
	await _k.stage(0, Kit21.GYRO, OPEN_START, Vector3.RIGHT)
	_k.watch.clear()
	_k.watch.logging = true
	_k.watch.phase = "stand"
	await _k.drive(0, STAND_TICKS, 0.0, 0)
	_k.watch.phase = "spin"
	await _k.drive(0, SPIN_TICKS, 0.0, 1)
	_k.watch.phase = "fly"
	await _k.drive(0, FLY_TICKS, 1.0, 0)
	_k.watch.logging = false
	var all: Dictionary = _k.watch.summary(0)
	var stand: Dictionary = _k.watch.summary(0, 0, -1, "stand")
	var fly: Dictionary = _k.watch.summary(0, 0, -1, "fly")
	var spin: Dictionary = _k.watch.summary(0, 0, -1, "spin")
	_q.kit.need(problems, all["alive"] and _q.units.units[0].is_alive, "the Floor flight ended with the Gyrocopter destroyed")
	_q.kit.need(problems, int(all["wall_ticks"]) == 0, "%d ticks of the flight had a wall's collision" % all["wall_ticks"])
	_q.kit.need(problems, int(stand["floor_ticks"]) >= STAND_TICKS - 2 and int(spin["floor_ticks"]) >= SPIN_TICKS - 2, "the Floor was reported on %d of %d standing ticks and %d of %d turning ticks" % [stand["floor_ticks"], stand["ticks"], spin["floor_ticks"], spin["ticks"]])
	_q.kit.need(problems, float(fly["max_real"]) >= 0.99 * _k.gyro_stats().max_speed, "the Gyrocopter flew at only %.2f m/s" % fly["max_real"])
	measured.append("floor_ticks=%d" % (int(stand["floor_ticks"]) + int(spin["floor_ticks"]) + int(fly["floor_ticks"])))
	_q.kit.verdict("floor_never", problems, "on open ground the Floor was reported on %d of %d standing ticks and %d of %d ticks of turning on the spot (its collider %s, its normal up) and on %d of %d flying ticks, never as a wall's, and the Gyrocopter, which then flew at %.1f m/s, was alive at the end" % [stand["floor_ticks"], stand["ticks"], spin["floor_ticks"], spin["ticks"], str((all["floors"] as Dictionary).keys()), fly["floor_ticks"], fly["ticks"], fly["max_real"]])


## sea_edge_stops (AC-4): head-on at top speed at each of the four shores. The first touch arrives at the crash speed or more (the
## top speed), the body it meets is one of the shore's and in the edge group, and the Gyrocopter, held against it with the throttle
## for 60 ticks, is alive, still and flush.
func _sea_edge_stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var bodies: Array[Node] = _k.map().get_node("Terrain/ShoreEdge").get_children()
	for aim: String in Kit21.SHORE_AIMS:
		var shore: Dictionary = _k.shore_run(Kit21.SHORE_AIMS[aim])
		var over: Callable = func() -> bool: return _k.watch.first_wall(0) >= 0 and (_k.watch.rows[0] as Array).size() > _k.watch.first_wall(0) + Kit21.AFTER_CONTACT
		var flight: Dictionary = await _k.fly(0, Kit21.GYRO, shore["start"], shore["dir"], 300, 1.0, 0, over)
		var hit: int = int(flight["hit"])
		var arrival: float = 0.0
		var who: String = ""
		if hit >= 0:
			var wall: Dictionary = Watch.walls(flight["rows"][hit])[0]
			arrival = float(wall["arrival"])
			who = String(wall["who"])
		var body: Node = get_body(who)
		_q.kit.need(problems, hit >= 0 and who.begins_with("/root") and who.contains("/Terrain/ShoreEdge/") and body != null and body.is_in_group(Unit.MAP_EDGE_GROUP), "the %s shore: the first touch at row %d was %s (in the group: %s)" % [aim, hit, who, body.is_in_group(Unit.MAP_EDGE_GROUP) if body != null else null])
		_q.kit.need(problems, arrival >= _k.crash_speed(), "the %s shore: it arrived at %.3f m/s, under the crash speed %.1f, so it proves nothing" % [aim, arrival, _k.crash_speed()])
		_k.watch.logging = true
		await _k.drive(0, HOLD_TICKS, 1.0, 0)
		_k.watch.logging = false
		var held: Dictionary = _k.watch.summary(0, hit + Kit21.AFTER_CONTACT)
		_q.kit.need(problems, flight["dead"] < 0 and held["alive"] and _q.units.units[0].is_alive and float(held["max_real"]) <= 0.01, "the %s shore: dead at row %d, alive %s, the real speed held against it %.4f" % [aim, flight["dead"], _q.units.units[0].is_alive, held["max_real"]])
		notes.append("%s: arrival %.2f m/s at %s, then held %d ticks, still, alive" % [aim, arrival, who.get_file(), HOLD_TICKS])
	var grouped: int = 0
	for node: Node in bodies:
		grouped += 1 if node.is_in_group(Unit.MAP_EDGE_GROUP) else 0
	_q.kit.need(problems, bodies.size() == 32 and grouped == 32, "%d of the %d shore bodies are in the group" % [grouped, bodies.size()])
	_q.kit.verdict("sea_edge_stops", problems, "flown head-on at the top speed into each of the four shores it arrived at the crash speed or more and was only stopped, because the body it met is in the group '%s' (%d of %d bodies): %s" % [Unit.MAP_EDGE_GROUP, grouped, bodies.size(), "; ".join(notes)])


## The body a collider path names, from the scene tree root.
func get_body(path: String) -> Node:
	return _q.harness.get_tree().root.get_node_or_null(NodePath(path))


## One crossing of Player 1's Gyrocopter from `start` along `dir` until `reached` says it is over: it must get there alive with no
## wall's collision on any tick. Returns {ok, rows, note}.
func _crossing(label: String, start: Vector3, dir: Vector3, reached: Callable, problems: PackedStringArray, ticks: int = LANE_LIMIT) -> Dictionary:
	var state: Dictionary = {"over": false}
	var stop: Callable = func() -> bool:
		state["over"] = state["over"] or reached.call()
		return state["over"]
	var flight: Dictionary = await _k.fly(0, Kit21.GYRO, start, dir, ticks, 1.0, 0, stop)
	var summary: Dictionary = _k.watch.summary(0)
	_q.kit.need(problems, state["over"] and flight["dead"] < 0 and flight["hit"] < 0 and summary["alive"], "%s: reached the end %s, dead at row %d, first wall's collision at row %d" % [label, state["over"], flight["dead"], flight["hit"]])
	return {"flight": flight, "summary": summary}


## low_pieces_pass (AC-4): the flights of Story 020's cross_low with the crash on: over a Base's Flag Walls, Garage and back walls
## and between the water tower's legs, over a field wall, a container, a wreck and the ridges and the water; then the canyon's two
## walls flown at to the sea edge, where it stops and lives. No flight touches a piece.
func _low_pieces_pass() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var flags: Object = _k.flags()
	var base: Base = flags.bases[0]
	var unit: Unit = _q.units.units[0]
	var axis: Dictionary = await _crossing("the Base's axis", flags.point(0, Over.AXIS_START), flags.way(0, Vector3.BACK), func() -> bool: return base.to_local(unit.global_position).z >= Over.AXIS_END_Z, problems)
	notes.append("the Base's axis (%d ticks, top speed %.1f m/s)" % [axis["summary"]["ticks"], axis["summary"]["max_real"]])
	var lanes: Array = [["a field wall", Over.FIELD_LANE, "x", LANE_LIMIT], ["a container", Over.CONTAINER_LANE, "z", LANE_LIMIT], ["a wreck", Over.WRECK_LANE, "z", LANE_LIMIT], ["the ridges and the water", Over.RIDGES_LANE, "x", LONG_LIMIT]]
	for lane: Array in lanes:
		var end: float = float(lane[1][2])
		var along_x: bool = lane[2] == "x"
		var result: Dictionary = await _crossing(lane[0], lane[1][0], lane[1][1], func() -> bool: return (unit.global_position.x if along_x else unit.global_position.z) >= end, problems, lane[3])
		notes.append("%s (%d ticks)" % [lane[0], result["summary"]["ticks"]])
	var canyon: Dictionary = await _k.fly(0, Kit21.GYRO, Over.CANYON_LANE[0], Over.CANYON_LANE[1], LANE_LIMIT, 1.0, 0, func() -> bool: return _k.watch.first_wall(0) >= 0 and (_k.watch.rows[0] as Array).size() > _k.watch.first_wall(0) + Kit21.AFTER_CONTACT)
	var hit: int = int(canyon["hit"])
	var who: String = String(Watch.walls(canyon["rows"][hit])[0]["who"]) if hit >= 0 else ""
	_q.kit.need(problems, hit >= 0 and who.contains("/Terrain/ShoreEdge/") and canyon["dead"] < 0 and unit.is_alive, "the canyon flight: first wall at row %d (%s), dead at row %d" % [hit, who, canyon["dead"]])
	notes.append("the canyon's two walls up to the sea edge (%s), where it stopped alive" % who.get_file())
	measured.append("low_flights=6")
	_q.kit.verdict("low_pieces_pass", problems, "six flights of Player 1's Gyrocopter at full throttle over every kind of low piece reached their ends alive with no wall's collision on any tick: %s" % "; ".join(notes))


## units_pass (AC-4): a Gyrocopter flown at full throttle through the middle of a standing Motorbike, Buggy and Truck, and head-on
## through a second Gyrocopter flown at it, touches nothing and lives; the standing Units do not move.
func _units_pass() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var start: Vector3 = Vector3(Over.THROUGH_START_X, 0.0, Over.THROUGH_Z)
	var other_at: Vector3 = Vector3(Over.THROUGH_UNIT_X, 0.0, Over.THROUGH_Z)
	var unit: Unit = _q.units.units[0]
	var other: Unit = _q.units.units[1]
	for ground: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK, Kit21.GYRO]:
		var head_on: bool = ground == Kit21.GYRO
		await _q.map.stage([Kit21.GYRO, ground], [start, Vector3(Over.HEAD_ON_OTHER_X, 0.0, Over.THROUGH_Z) if head_on else other_at], [Vector3.RIGHT, Vector3.LEFT], true)
		var parked: Vector3 = other.global_position
		_k.watch.clear()
		_k.watch.logging = true
		var nearest: float = INF
		for _tick: int in LANE_LIMIT:
			_q.harness.drive(0, 1, 0)
			if head_on:
				_q.harness.drive(1, 1, 0)
			await _q.kit.tick()
			nearest = minf(nearest, Vector2(unit.global_position.x - other.global_position.x, unit.global_position.z - other.global_position.z).length())
			if unit.global_position.x >= Over.THROUGH_END_X:
				break
		_k.watch.logging = false
		_q.harness.release_all()
		var mine: Dictionary = _k.watch.summary(0)
		var theirs: Dictionary = _k.watch.summary(1)
		var label: String = "through a %s" % _q.units.stats(ground).type_id
		_q.kit.need(problems, mine["alive"] and unit.is_alive and int(mine["wall_ticks"]) == 0 and unit.global_position.x >= Over.THROUGH_END_X, "%s: alive %s, %d wall's collisions, ended at x %.2f" % [label, unit.is_alive, mine["wall_ticks"], unit.global_position.x])
		_q.kit.need(problems, nearest <= 0.5 and (head_on or other.global_position.distance_to(parked) <= Kit21.PLACE_TOLERANCE), "%s: closest %.3f m, the other Unit moved %.4f m" % [label, nearest, other.global_position.distance_to(parked)])
		_q.kit.need(problems, not head_on or (theirs["alive"] and int(theirs["wall_ticks"]) == 0), "%s: the second Gyrocopter was alive %s with %d wall's collisions" % [label, theirs["alive"], theirs["wall_ticks"]])
		notes.append("%s%s: closest %.2f m, alive, no collision" % [label, " head-on" if head_on else "", nearest])
	measured.append("units_pass=4")
	_q.kit.verdict("units_pass", problems, "flown at full throttle at ground Units and a second Gyrocopter, the Gyrocopter passed through each and lived: %s" % "; ".join(notes))


## ground_never (AC-4): a Motorbike, a Buggy and a Truck driven at full throttle at a corner tower, a leg, a Turret and a tank are
## stopped as before and live: their crash speed is zero in the data, and each met the piece faster than the Gyrocopter's crash
## speed, so a crash speed given to every type would have destroyed them.
func _ground_never() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var unit: Unit = _q.units.units[0]
	var pieces: Array[Dictionary] = [
		{"label": "a corner tower", "path": Kit21.path_of("tower", 0), "dir": Kit21.toward(0)},
		{"label": "a leg", "path": Kit21.path_of("leg", 0), "dir": Kit21.toward(0)},
		{"label": "a Turret", "path": Kit21.path_of("turret", 0), "dir": Kit21.toward(0)},
		{"label": "a tank", "path": Kit21.path_of(Kit21.TANKS[0]), "dir": Vector3.RIGHT}]
	for ground: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(ground)
		_q.kit.need(problems, stats.crash_speed == 0.0, "the %s has a crash speed of %.1f" % [stats.type_id, stats.crash_speed])
		for piece: Dictionary in pieces:
			var gap: float = Kit21.RUN_UP - (stats.collision_size.z - _k.gyro_stats().collision_size.z) / 2.0
			var flight_line: Dictionary = _k.line(piece["path"], piece["dir"], 0.0, gap)
			var label: String = "a %s at %s" % [stats.type_id, piece["label"]]
			var flight: Dictionary = await _k.fly(0, ground, flight_line["start"], flight_line["dir"], LANE_LIMIT, 1.0, 0, func() -> bool: return _k.watch.first_wall(0) >= 0)
			var hit: int = int(flight["hit"])
			var arrival: float = float(Watch.walls(flight["rows"][hit])[0]["arrival"]) if hit >= 0 else 0.0
			var at_contact: Vector3 = unit.global_position
			_k.watch.logging = true
			await _k.drive(0, GROUND_HOLD, 1.0, 0)
			_k.watch.logging = false
			var moved: float = unit.global_position.distance_to(at_contact)
			_q.kit.need(problems, hit >= 0 and unit.is_alive and moved <= STOP_MOVE and arrival >= _k.crash_speed(), "%s: touched at row %d, alive %s, moved %.3f m more, arrived at %.2f m/s" % [label, hit, unit.is_alive, moved, arrival])
			notes.append("%s: %.1f m/s" % [label, arrival])
	measured.append("ground_never=12")
	_q.kit.verdict("ground_never", problems, "each ground type driven at full throttle at a corner tower, a leg, a Turret and a tank (a crash speed of zero in its data) arrived at the piece faster than the Gyrocopter's crash speed, %.1f m/s, and was stopped and alive: %s" % [_k.crash_speed(), "; ".join(notes)])
