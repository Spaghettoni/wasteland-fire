extends RefCounted
## Scenario map_cover of the split screen evidence harness (split_screen_harness.gd): Map 01's
## cover stops every Unit and every shot, and every Fuel Can of the depot stays reachable by a
## Truck, on the main composition (Story 007 AC-7). One CHECK line with the measured numbers,
## cover_stops. At one wreck, one long container and one scrap wall west of X = 0 and at each
## one's twin east of it, the Gyrocopter and a ground Unit (the Motorbike at the wreck, the Buggy
## at the container, the Truck at the scrap wall) drive head-on into the visible face at full
## throttle from RUN_UP, one Player per twin, then swapped, each firing one shot on the way in:
## each Unit meets the face at its top speed, is stopped within STOP_TICKS of its first wall
## contact with its centre its half-length from the face, and stays there; each shot ends on the
## face. Then a Truck on its spawn tank passes each Fuel Can of the depot in turn and takes it (the
## dressing tanks and the ring marking stop nothing). The Players choose with their own keys
## (confirm_choices()); map_kit.gd stages every run. A SPLIT line per run, shot and depot pass.
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-7; design/rules.md "Units"
## and "Resources". Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=map_cover

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks and the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the Map's nodes, the staging, the log, the wall contact.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")
## The Story 005 helpers (unit_kit.gd): the type data and the record of every Shot.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The Truck's index into the data (unit_kit.gd TYPE_IDS).
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## The cover tried west of X = 0, by path from the Map: one wreck, one long container, one scrap
## wall. Each one's twin east of X = 0 is the same path with East for West.
const COVER: Array[String] = ["Cover/Wrecks/WreckWestOuterSouth", "Cover/Containers/ContainerWest",
	"Cover/ScrapWalls/ScrapWallWest"]
## The ground type run at each piece of COVER: the Motorbike, the Buggy, the Truck.
const GROUND: Array[int] = [0, 1, 2]
## The side of each piece of COVER a run comes from, in the piece's own frame: from its centre out
## through the long face that looks onto open ground.
const SIDES: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
## Where on each face a run hits, from the piece's centre along the face (world x, z), metres: the
## scrap wall 3 m south of its middle, clear of the wreck west of it.
const SHIFTS: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2(0, 3)]
## Metres a Unit's nose runs before it meets a face (a Motorbike needs 14.4 m to reach 24 m/s).
const RUN_UP: float = 15.0
## Ticks of full throttle per run: the slowest, the Truck, covers RUN_UP from rest in about two
## seconds (its data: 9 m/s/s up to 10.9 m/s), then stays on the face.
const RUN_TICKS: int = 160
## A run meets its face at no less than this share of its type's top speed.
const IMPACT_SHARE: float = 0.95
## A Unit is stopped below this real speed, m/s (the data's blocked_speed).
const STOP_SPEED: float = 0.5
## A Unit is stopped within this many ticks of its first wall contact.
const STOP_TICKS: int = 2
## A stopped Unit's centre lies its half-length from the visible face, within this, metres.
const FLUSH_TOLERANCE: float = 0.05
## The tick of a run on which both Players press fire, each Unit 12 m or more from its face: the
## shot lands long before the Unit does.
const FIRE_TICK: int = 30
## A shot ends within this of the face it was fired at, metres.
const SHOT_TOLERANCE: float = 0.01
## Metres outward from a depot Can the Truck's line passes: its inner side 0.2 m past the Can's
## centre, every other corner Can 4 m or more off its side.
const PASS_OFFSET: float = 1.0
## Metres a Truck runs to the point of its line nearest its Can.
const DEPOT_RUN_UP: float = 12.0
## Ticks a depot pass may take before its Can counts as unreached.
const DEPOT_TICKS: int = 180
## A depot Can within this of the depot's centre is its middle one, passed last, metres.
const MIDDLE_RADIUS: float = 0.5
## The Fuel Cans the depot holds (the story's positions table and AC-8: five of the Map's nine).
const DEPOT_CANS: int = 5

var _harness: Harness
var _kit: Kit
var _map: Map
var _units: Units
var _faces: Array[Vector2] = []
var _normals: Array[Vector2] = []
var _labels: Array[String] = []
var _first_contact: Array[int] = [-1, -1]
var _worst: Dictionary[StringName, float] = {}
var _taken: Dictionary[StringName, Vector2i] = {}
var _runs: int = 0


## Runs the cover runs and the depot passes, then the CHECK and the RESULT line. The runner awaits
## this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_map = Map.new(harness, _kit)
	_units = Units.new(harness, _kit)
	_kit.on_tick = _on_tick
	await _harness.confirm_choices()
	await _kit.advance(Kit.START_TICKS)
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for index: int in COVER.size():
		notes.append(await _try_cover(index, problems))
	notes.append(await _try_depot(problems))
	_kit.verdict("cover_stops", problems, " | ".join(notes))
	_harness.finish("runs=%d shots=%d depot_takes=%d" % [_runs, _units.shots.size(), _taken.size()])


## The check kit's hook after every tick: the Map's log of both Units, the Shots' first places and
## each Player's first wall contact since the log was last cleared (an index into the log).
func _on_tick() -> void:
	_map.log_tick()
	_units.note_tick()
	for lane: int in Kit.PLAYERS:
		if _first_contact[lane] < 0 and _map.wall_contact(_map.units[lane]):
			_first_contact[lane] = _map.places[lane].size() - 1


## Files the first take of each depot Can: the runner's tick and the Player whose Unit took it.
func _on_taken(unit: Unit, can_name: StringName) -> void:
	if not _taken.has(can_name):
		_taken[can_name] = Vector2i(_harness.ticks, _map.units.find(unit))


## The path from the Map of a piece of COVER (lane 0) or of its twin east of X = 0 (lane 1).
func _path(index: int, lane: int) -> String:
	return COVER[index] if lane == 0 else COVER[index].replace("West", "East")


## A node's place in the ground plane (world x, z).
func _ground(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)


## One piece of COVER and its twin: the Gyrocopter at the west piece and the ground type at the
## east one, then swapped. Returns the note with the worst numbers of the four runs and shots.
func _try_cover(index: int, problems: PackedStringArray) -> String:
	if not _aim(index):
		problems.append("%s or its twin, or a Mesh of theirs, is missing" % COVER[index])
		return "%s missing" % COVER[index]
	_worst = {&"hit": INF, &"stop": 0.0, &"gap": 0.0, &"end": 0.0, &"shot": 0.0}
	for swap: int in 2:
		var types: Array[int] = [GYROCOPTER, GROUND[index]]
		if swap == 1:
			types.reverse()
		await _drive_run(types, problems)
	return "%s: 4 runs met the face at >= %.3f of top speed, stop ticks <= %d, gap off the half-length <= %.3f m, end speed <= %.2f m/s; 4 shots ended <= %.3f m off the face" % [
		" and ".join(_labels), _worst[&"hit"], int(_worst[&"stop"]), _worst[&"gap"], _worst[&"end"], _worst[&"shot"]]


## Aims the runs at one piece of COVER and its twin: per lane the face's normal (SIDES in the
## piece's frame, the twin's turned to mirror the west one's) and the point where a run meets the
## visible box (the piece's Mesh), SHIFTS along the face. False when a piece or its Mesh is missing.
func _aim(index: int) -> bool:
	_faces.clear()
	_normals.clear()
	_labels.clear()
	for lane: int in Kit.PLAYERS:
		var piece: Node3D = _map.find(_path(index, lane)) as Node3D
		var mesh: MeshInstance3D = null
		if piece != null:
			mesh = piece.get_node_or_null("Mesh") as MeshInstance3D
		if mesh == null:
			return false
		var side: Vector3 = piece.global_transform.basis * SIDES[index]
		var normal: Vector2 = Vector2(side.x, side.z).normalized()
		if lane == 1 and normal.dot(Vector2(-_normals[0].x, _normals[0].y)) < 0.0:
			normal = -normal
		var centre: Vector2 = _ground(piece) + SHIFTS[index] * Vector2(-1.0 if lane == 1 else 1.0, 1.0)
		var reach: float = -INF
		for corner: int in 8:
			var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
			reach = maxf(reach, (Vector2(point.x, point.z) - centre).dot(normal))
		_faces.append(centre + normal * reach)
		_normals.append(normal)
		_labels.append(String(piece.name))
	return true


## One run per Player at full throttle, its nose RUN_UP before its lane's face, both firing on
## FIRE_TICK, logged for RUN_TICKS; then each lane's run and shot judged. A coroutine.
func _drive_run(types: Array[int], problems: PackedStringArray) -> void:
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for lane: int in Kit.PLAYERS:
		var start: Vector2 = _faces[lane] + _normals[lane] * (_units.stats(types[lane]).collision_size.z / 2.0 + RUN_UP)
		spots.append(Vector3(start.x, 0.0, start.y))
		facings.append(Vector3(-_normals[lane].x, 0.0, -_normals[lane].y))
	await _map.stage(types, spots, facings, true)
	_map.clear_log()
	_first_contact = [-1, -1]
	var first_shot: int = _units.shots.size()
	for lane: int in Kit.PLAYERS:
		_harness.drive(lane, 1, 0)
	for tick: int in RUN_TICKS:
		for lane: int in Kit.PLAYERS:
			_harness.set_key(_harness.fire_key(lane), tick == FIRE_TICK)
		await _kit.tick()
	_harness.release_all()
	for lane: int in Kit.PLAYERS:
		_judge_run(lane, _units.stats(types[lane]), problems)
		_judge_shot(first_shot, lane, problems)
	_runs += Kit.PLAYERS.size()


## Judges one Player's run from the log (class doc), keeps the worst numbers and prints its SPLIT.
func _judge_run(lane: int, stats: UnitStats, problems: PackedStringArray) -> void:
	var contact: int = _first_contact[lane]
	var nearest: float = INF
	var stop: int = -1
	for index: int in _map.places[lane].size():
		var place: Vector3 = _map.places[lane][index]
		nearest = minf(nearest, (Vector2(place.x, place.z) - _faces[lane]).dot(_normals[lane]))
		if stop < 0 and contact >= 0 and index >= contact and _map.real_speed(lane, index) < STOP_SPEED:
			stop = index - contact
	var half: float = stats.collision_size.z / 2.0
	var hit: float = _map.real_speed(lane, contact - 1) if contact > 1 else 0.0
	var end: float = _map.real_speed(lane, -1)
	var label: String = "p%d %s at %s" % [lane + 1, stats.type_id, _labels[lane]]
	_kit.need(problems, hit >= IMPACT_SHARE * stats.max_speed, "%s met the face at %.2f m/s (contact at log tick %d)" % [label, hit, contact])
	_kit.need(problems, stop >= 0 and stop <= STOP_TICKS, "%s not stopped within %d ticks of its contact (%d)" % [label, STOP_TICKS, stop])
	_kit.need(problems, absf(nearest - half) <= FLUSH_TOLERANCE, "%s came to %.3f m of the face (half-length %.3f)" % [label, nearest, half])
	_kit.need(problems, end < STOP_SPEED, "%s still moving at %.2f m/s at the end" % [label, end])
	_worst[&"hit"] = minf(_worst[&"hit"], hit / stats.max_speed)
	_worst[&"stop"] = maxf(_worst[&"stop"], float(stop if stop >= 0 else RUN_TICKS))
	_worst[&"gap"] = maxf(_worst[&"gap"], absf(nearest - half))
	_worst[&"end"] = maxf(_worst[&"end"], end)
	print("SPLIT %s t=%.3f run=%s type=%s player=%d hit=%.2f contact_tick=%d stop_ticks=%d gap=%.3f half=%.3f end=%.2f" % [
		_harness.scenario, _harness.time(), _labels[lane], stats.type_id, lane + 1, hit, contact, stop, nearest, half, end])


## How far from its lane's face the Player's shot of the run ended (the side of X = 0 it was first
## seen on names the Player), with its SPLIT line; a problem above SHOT_TOLERANCE.
func _judge_shot(first: int, lane: int, problems: PackedStringArray) -> void:
	var offset: float = INF
	var end: Vector3 = Vector3.INF
	for index: int in range(first, _units.shots.size()):
		var seen: Vector3 = _units.shot_firsts[index]
		if seen != Vector3.INF and _units.shot_ends[index] != Vector3.INF and (seen.x < 0.0) == (lane == 0):
			end = _units.shot_ends[index]
			offset = (Vector2(end.x, end.z) - _faces[lane]).dot(_normals[lane])
	_kit.need(problems, absf(offset) <= SHOT_TOLERANCE, "p%d's shot at %s ended %.3f m off the face" % [lane + 1, _labels[lane], offset])
	_worst[&"shot"] = maxf(_worst[&"shot"], absf(offset))
	print("SPLIT %s t=%.3f shot=%s player=%d end_x=%.3f end_y=%.3f end_z=%.3f face_offset=%.3f" % [
		_harness.scenario, _harness.time(), _labels[lane], lane + 1, end.x, end.y, end.z, offset])


## The depot passes: the depot must hold DEPOT_CANS Fuel Cans, and Player 1's Truck on its spawn
## tank (a Can refuels only a Unit with room) passes each in turn, the middle one last, and must
## take it. A coroutine. Returns the note.
func _try_depot(problems: PackedStringArray) -> String:
	var depot: Node3D = _map.find("Depot") as Node3D
	var cans: Array[FuelCan] = []
	for node: Node in _map.members(&"fuel_cans"):
		if depot != null and depot.is_ancestor_of(node):
			cans.append(node as FuelCan)
			(node as FuelCan).taken.connect(_on_taken.bind(node.name))
	_kit.need(problems, cans.size() == DEPOT_CANS, "the depot holds %d Fuel Cans, not %d" % [cans.size(), DEPOT_CANS])
	var notes: PackedStringArray = []
	for middle: bool in [false, true]:
		for can: FuelCan in cans:
			if (_ground(can).distance_to(_ground(depot)) < MIDDLE_RADIUS) == middle:
				notes.append(await _depot_pass(can, _ground(depot), problems))
	return "depot: the passing Truck took %s" % ", ".join(notes)


## Where a Truck starts to pass a depot Can and the way it faces (x, z): on a line square to the
## way out from the depot's centre, PASS_OFFSET out past the Can, DEPOT_RUN_UP back along it,
## heading away from X = 0; the middle Can from the north, straight over it.
func _pass(can: FuelCan, centre: Vector2) -> PackedVector2Array:
	var at: Vector2 = _ground(can)
	var out: Vector2 = at - centre
	if out.length() < MIDDLE_RADIUS:
		return PackedVector2Array([at - Vector2(0.0, DEPOT_RUN_UP), Vector2(0.0, 1.0)])
	out = out.normalized()
	var along: Vector2 = Vector2(out.y, -out.x)
	if signf(along.x) != signf(out.x):
		along = -along
	return PackedVector2Array([at + out * PASS_OFFSET - along * DEPOT_RUN_UP, along])


## One pass of Player 1's Truck at a depot Can from the start of its line (_pass()), full throttle
## until the Can is taken or DEPOT_TICKS; the Can must go to that Truck during the pass. Prints the
## SPLIT; returns the Can's name and the seconds from the start to the take. A coroutine.
func _depot_pass(can: FuelCan, centre: Vector2, problems: PackedStringArray) -> String:
	var line: PackedVector2Array = _pass(can, centre)
	await _map.stage([TRUCK, -1], [Vector3(line[0].x, 0.0, line[0].y), Vector3.ZERO],
		[Vector3(line[1].x, 0.0, line[1].y), Vector3.FORWARD], false)
	_map.clear_log()
	var start: int = _harness.ticks
	_harness.drive(Harness.PLAYER_1, 1, 0)
	for _tick: int in DEPOT_TICKS:
		await _kit.tick()
		if _taken.has(can.name):
			break
	_harness.release_all()
	var take: Vector2i = _taken.get(can.name, Vector2i(-1, -1))
	var held: bool = take.y == Harness.PLAYER_1 and take.x >= start
	var seconds: float = float(take.x - start) / float(_harness.ticks_in(1.0)) if held else -1.0
	var taker: String = "never taken" if take.x < 0 else "taken at tick %d by p%d" % [take.x, take.y + 1]
	_kit.need(problems, held, "%s not taken by the Truck passing it: pass from tick %d, %s" % [can.name, start, taker])
	print("SPLIT %s t=%.3f depot=%s taken_after=%.2f wall_contacts=%d" % [
		_harness.scenario, _harness.time(), can.name, seconds, _map.contacts[Harness.PLAYER_1]])
	return "%s %.2f s" % [can.name, seconds]
