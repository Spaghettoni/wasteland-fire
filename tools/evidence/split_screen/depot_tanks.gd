extends RefCounted
## Scenario depot_tanks of the split screen evidence harness (split_screen_harness.gd): Map 01's
## three depot tanks are solid, on the shipped data and Map (Story 009 AC-1). Three CHECK lines:
## tank_data (each tank has one collider on the map layer, a cylinder as wide as the tank's band
## and as tall as the tank on the tank's axis, and every type's mask and the Shot mask take the map
## layer), tanks_stop (each of the four types driven at full throttle at each tank along a line
## through its axis, from outside the depot at the north-west and north-east tanks, one Player at
## each, and from the depot's middle at the south one: it meets the side at speed, is stopped within
## STOP_TICKS of its first wall contact with its centre the tank's radius and its half-length from
## the axis, and stays; one Shot fired on the way in ends on the tank's side) and depot_cans (a
## Truck on its spawn tank passes each depot Fuel Can on a line clear of the tanks, through the gaps
## between them, and takes it). A SPLIT line per run, shot and pass. The Players choose with their
## own keys (confirm_choices()); map_kit.gd stages every run.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-1. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=depot_tanks

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The three tanks, by path from the Map: the two the Players run at from outside the depot (Player
## 1 the west one), then the one a single run reaches from the depot's middle.
const TANKS: Array[String] = ["Depot/FuelTanks/FuelTankNorthWest", "Depot/FuelTanks/FuelTankNorthEast",
	"Depot/FuelTanks/FuelTankSouth"]
## A tank's collider, by path from the tank (Story 009's StaticBody3D child) and its shape's.
const COLLIDER_PATH: String = "Collider"
## A tank's band, the widest drawn part of it at the ground, by path from the tank.
const BAND_PATH: String = "Band"
## The map layer (project.godot layer 1): every type and every Shot collides with it.
const MAP_LAYER: int = 1
## Metres a Unit's nose runs before it meets a tank from outside the depot.
const RUN_UP_OUTSIDE: float = 12.0
## Metres a Unit's nose runs before it meets the south tank from the depot's middle (the gap
## between the north tanks leaves no more room in front of the first Fuel Can's ring).
const RUN_UP_INSIDE: float = 10.0
## Ticks of full throttle per run: the slowest, the Truck, covers 12 m from rest in under two
## seconds (9 m/s/s up to 10.9 m/s), then stays at the tank.
const RUN_TICKS: int = 150
## The tick of a run on which the runner presses fire, the Unit 9 m or more from the tank.
const FIRE_TICK: int = 20
## A run meets its tank at no less than this share of its type's top speed.
const IMPACT_SHARE: float = 0.75
## Where a Truck starts its pass at each depot Fuel Can, by the Can's name (world x, z): the north
## ones and the middle one from the north gap between the north tanks, the south ones along their
## row from outside the depot's west and east sides; each heads straight for its Can.
const PASS_STARTS: Dictionary[String, Vector2] = {"FuelCanDepot1": Vector2(0.0, -12.0),
	"FuelCanDepot2": Vector2(0.0, -12.0), "FuelCanDepot3": Vector2(0.0, -12.0),
	"FuelCanDepot4": Vector2(-15.0, 3.0), "FuelCanDepot5": Vector2(15.0, 3.0)}
## Ticks a depot pass may take before its Can counts as unreached.
const PASS_TICKS: int = 180

var _q: Quick
var _first_contact: Array[int] = [-1, -1]
var _taken: Dictionary[StringName, Vector2i] = {}
var _runs: int = 0
## The index into the Shot record of the first Shot of the run being judged.
var _shots_from: int = 0


## Runs the data check, the tank runs and the depot passes, then the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_q.kit.on_tick = _on_tick
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	_check_data()
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type_index: int in _q.controller.unit_types().size():
		notes.append(await _outside_runs(type_index, problems))
		notes.append(await _inside_run(type_index, problems))
	_q.kit.verdict("tanks_stop", problems, " | ".join(notes))
	await _depot_passes()
	_q.close()
	_q.harness.finish("runs=%d shots=%d depot_takes=%d %s" % [_runs, _q.units.shots.size(), _taken.size(), _q.engine_counts()])


## The check kit's hook after every tick: the Map's log, the Shots' first places and each Player's
## first wall contact since the log was last cleared (an index into the log).
func _on_tick() -> void:
	_q.map.log_tick()
	_q.units.note_tick()
	for lane: int in Kit.PLAYERS:
		if _first_contact[lane] < 0 and _q.map.wall_contact(_q.map.units[lane]):
			_first_contact[lane] = _q.map.places[lane].size() - 1


## The tank_data CHECK: each tank's one collider, its layer, mask and cylinder, and the masks.
func _check_data() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for path: String in TANKS:
		var tank: MeshInstance3D = _q.map.find(path) as MeshInstance3D
		var body: StaticBody3D = null
		if tank != null:
			body = tank.get_node_or_null(COLLIDER_PATH) as StaticBody3D
		var shapes: Array[Node] = []
		if body != null:
			shapes = body.find_children("*", "CollisionShape3D", false, false)
		var cylinder: CylinderShape3D = null
		if shapes.size() == 1:
			cylinder = (shapes[0] as CollisionShape3D).shape as CylinderShape3D
		if cylinder == null:
			problems.append("%s has no collider with one cylinder" % path)
			continue
		var band: CylinderMesh = (tank.get_node(BAND_PATH) as MeshInstance3D).mesh as CylinderMesh
		var body_mesh: CylinderMesh = tank.mesh as CylinderMesh
		var centre: Vector3 = (shapes[0] as CollisionShape3D).global_position
		_q.kit.need(problems, body.collision_layer == MAP_LAYER and body.collision_mask == 0, "%s's collider is on layer %d, mask %d" % [path, body.collision_layer, body.collision_mask])
		_q.kit.need(problems, is_equal_approx(cylinder.radius, band.bottom_radius) and is_equal_approx(cylinder.height, body_mesh.height),
			"%s's cylinder r=%.2f h=%.2f, the band r=%.2f, the tank h=%.2f" % [path, cylinder.radius, cylinder.height, band.bottom_radius, body_mesh.height])
		_q.kit.need(problems, centre.is_equal_approx(tank.global_position), "%s's cylinder centre %s is off the tank's %s" % [path, centre, tank.global_position])
		notes.append("%s: layer %d r=%.2f h=%.2f at (%.2f, %.2f, %.2f)" % [tank.name, body.collision_layer, cylinder.radius, cylinder.height, centre.x, centre.y, centre.z])
	for stats: UnitStats in _q.controller.unit_types():
		_q.kit.need(problems, (stats.collision_mask & MAP_LAYER) != 0, "%s's mask %d leaves out the map layer" % [stats.type_id, stats.collision_mask])
		notes.append("%s mask %d" % [stats.type_id, stats.collision_mask])
	var shot_mask: int = _q.controller.rules.shot_collision_mask
	_q.kit.need(problems, (shot_mask & MAP_LAYER) != 0, "the Shot mask %d leaves out the map layer" % shot_mask)
	notes.append("shot mask %d" % shot_mask)
	_q.kit.verdict("tank_data", problems, " | ".join(notes))


## The axis of a tank in the ground plane (world x, z).
func _axis(index: int) -> Vector2:
	return Quick.ground(_q.map.find(TANKS[index]) as Node3D)


## The radius of a tank's collider, metres.
func _radius(index: int) -> float:
	var body: Node = (_q.map.find(TANKS[index]) as Node).get_node(COLLIDER_PATH)
	return ((body.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius


## Both Players at once, each at its north tank from outside the depot along the line from the
## depot's middle through the tank's axis; the note with both runs' numbers. A coroutine.
func _outside_runs(type_index: int, problems: PackedStringArray) -> String:
	var stats: UnitStats = _q.units.stats(type_index)
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for lane: int in Kit.PLAYERS:
		var out: Vector2 = _axis(lane).normalized()
		var start: Vector2 = _axis(lane) + out * (_radius(lane) + stats.collision_size.z / 2.0 + RUN_UP_OUTSIDE)
		spots.append(Vector3(start.x, 0.0, start.y))
		facings.append(Vector3(-out.x, 0.0, -out.y))
	var notes: PackedStringArray = []
	var lanes: Array[int] = [Harness.PLAYER_1, Harness.PLAYER_2]
	await _drive([type_index, type_index], spots, facings, lanes)
	for lane: int in lanes:
		notes.append(_judge(lane, lane, stats, problems))
	return " ; ".join(notes)


## Player 1 alone at the south tank from the depot's middle, heading south through the gap between
## the north tanks; the note with the run's numbers. A coroutine.
func _inside_run(type_index: int, problems: PackedStringArray) -> String:
	var stats: UnitStats = _q.units.stats(type_index)
	var start: Vector2 = _axis(2) - Vector2(0.0, 1.0) * (_radius(2) + stats.collision_size.z / 2.0 + RUN_UP_INSIDE)
	await _drive([type_index, -1], [Vector3(start.x, 0.0, start.y), Vector3.ZERO], [Vector3.BACK, Vector3.FORWARD], [Harness.PLAYER_1])
	return _judge(Harness.PLAYER_1, 2, stats, problems)


## Stages the run (types -1 leave a Player alone), then full throttle for the listed Players for
## RUN_TICKS with one fire press on FIRE_TICK, logged from the first tick. A coroutine.
func _drive(types: Array[int], spots: Array[Vector3], facings: Array[Vector3], lanes: Array[int]) -> void:
	await _q.map.stage(types, spots, facings, true)
	_q.map.clear_log()
	_first_contact = [-1, -1]
	_shots_from = _q.units.shots.size()
	for lane: int in lanes:
		_q.harness.drive(lane, 1, 0)
	for tick: int in RUN_TICKS:
		for lane: int in lanes:
			_q.harness.set_key(_q.harness.fire_key(lane), tick == FIRE_TICK)
		await _q.kit.tick()
	_q.harness.release_all()
	_runs += lanes.size()



## Judges one Player's run at a tank (quick_fix_kit.gd judge_stop(): the centre's distance from the
## axis against the radius plus the half-length) and that Player's Shot, prints the SPLIT lines and
## returns the note.
func _judge(lane: int, tank: int, stats: UnitStats, problems: PackedStringArray) -> String:
	var axis: Vector2 = _axis(tank)
	var expected: float = _radius(tank) + stats.collision_size.z / 2.0
	var label: String = "p%d %s at %s" % [lane + 1, stats.type_id, (_q.map.find(TANKS[tank]) as Node).name]
	var from_axis: Callable = func(place: Vector3) -> float: return Vector2(place.x, place.z).distance_to(axis)
	var numbers: Array[float] = _q.judge_stop(lane, _first_contact[lane], from_axis, expected, label, problems)
	_q.kit.need(problems, numbers[0] >= IMPACT_SHARE * stats.max_speed, "%s met the tank at %.2f m/s" % [label, numbers[0]])
	var shot: float = _shot_offset(lane, axis, _radius(tank))
	_q.kit.need(problems, absf(shot) <= Quick.SHOT_TOLERANCE, "%s: its Shot ended %.3f m off the tank's side" % [label, shot])
	print("SPLIT %s t=%.3f run=%s hit=%.2f stop_ticks=%d from_axis=%.3f expected=%.3f end=%.2f shot_off=%.4f" % [
		_q.harness.scenario, _q.harness.time(), label.replace(" ", "_"), numbers[0], int(numbers[1]), numbers[2], expected, numbers[3], shot])
	return "%s hit %.2f m/s, stopped in %d, %.3f m from the axis (%.3f), Shot %.4f m off the side" % [
		label, numbers[0], int(numbers[1]), numbers[2], expected, shot]


## How far off a tank's side the Player's Shot of this run ended (its end's distance from the axis
## less the radius); INF when the Player fired none that ended. The Shot is the one first seen
## nearest that Player's Unit's starting place.
func _shot_offset(lane: int, axis: Vector2, radius: float) -> float:
	var start: Vector3 = _q.map.places[lane][0] if not _q.map.places[lane].is_empty() else Vector3.INF
	var best: float = INF
	var offset: float = INF
	for index: int in range(_shots_from, _q.units.shots.size()):
		var seen: Vector3 = _q.units.shot_firsts[index]
		var end: Vector3 = _q.units.shot_ends[index]
		if seen == Vector3.INF or end == Vector3.INF:
			continue
		var near: float = seen.distance_to(start)
		if near < best:
			best = near
			offset = Vector2(end.x, end.z).distance_to(axis) - radius
	return offset


## The depot_cans CHECK: Player 1's Truck on its spawn tank (a Can refuels only a Unit with room)
## passes each depot Can from its PASS_STARTS place straight at it and must take it; the line's
## clearance from every tank (its least distance from an axis less the radius and the Truck's half
## width) is printed and must be above zero. A coroutine.
func _depot_passes() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for node: Node in _q.map.members(&"fuel_cans"):
		if PASS_STARTS.has(String(node.name)):
			(node as FuelCan).taken.connect(_on_taken.bind(node.name))
	for can_name: String in PASS_STARTS:
		var can: FuelCan = _q.map.find("Depot/" + can_name) as FuelCan
		if can == null:
			problems.append("the depot has no %s" % can_name)
			continue
		notes.append(await _pass(can, PASS_STARTS[can_name], problems))
	_q.kit.verdict("depot_cans", problems, " | ".join(notes))


## One pass of Player 1's Truck at a Can, full throttle until the Can is taken or PASS_TICKS.
## Prints the SPLIT; returns the note. A coroutine.
func _pass(can: FuelCan, start: Vector2, problems: PackedStringArray) -> String:
	var at: Vector2 = Quick.ground(can)
	var heading: Vector2 = (at - start).normalized()
	var truck: UnitStats = _q.units.stats(Quick.TRUCK)
	var clearance: float = INF
	for index: int in TANKS.size():
		var axis: Vector2 = _axis(index)
		var along: float = clampf((axis - start).dot(heading), 0.0, start.distance_to(at))
		clearance = minf(clearance, (start + heading * along).distance_to(axis) - _radius(index) - truck.collision_size.x / 2.0)
	await _q.map.stage([Quick.TRUCK, -1], [Vector3(start.x, 0.0, start.y), Vector3.ZERO],
		[Vector3(heading.x, 0.0, heading.y), Vector3.FORWARD], false)
	var from: int = _q.harness.ticks
	_q.harness.drive(Harness.PLAYER_1, 1, 0)
	for _tick: int in PASS_TICKS:
		await _q.kit.tick()
		if _taken.has(can.name):
			break
	_q.harness.release_all()
	var take: Vector2i = _taken.get(can.name, Vector2i(-1, -1))
	var held: bool = take.y == Harness.PLAYER_1 and take.x >= from
	var seconds: float = float(take.x - from) / float(_q.harness.ticks_in(1.0)) if held else -1.0
	_q.kit.need(problems, held, "%s not taken by the Truck passing it from %s" % [can.name, start])
	_q.kit.need(problems, clearance > 0.0, "%s's line from %s passes %.2f m into a tank" % [can.name, start, -clearance])
	print("SPLIT %s t=%.3f depot=%s from=(%.1f,%.1f) taken_after=%.2f clearance=%.2f" % [
		_q.harness.scenario, _q.harness.time(), can.name, start.x, start.y, seconds, clearance])
	return "%s from (%.0f, %.0f) %.2f s, %.2f m clear of the tanks" % [can.name, start.x, start.y, seconds, clearance]


## Files the first take of each depot Can: the runner's tick and the Player whose Unit took it.
func _on_taken(unit: Unit, can_name: StringName) -> void:
	if not _taken.has(can_name):
		_taken[can_name] = Vector2i(_q.harness.ticks, _q.map.units.find(unit))
