extends RefCounted
## Where the Fuel building stands in the Story 023 scenario fuel_building, AC-2: the depot's three tanks are what they were, Tall pieces on the
## map layer that stop every Unit (the Gyrocopter's mask holds it) and every Shot, and nothing damages them; each zone is about 1.7 m clear of
## the nearer tank and 7.7 m of the south one and 3 m of the nearest Wall Panel; and each ground type driven from the outside of its own Base's
## Gate to the zone on its side arrives, stops and is refuelled without once sliding against a tank. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-023-fuel-building.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## The tanks as the depot's scene has had them since Story 009: collider radius and height, metres, and the layer they stand on.
const TANK_RADIUS: float = 2.56
const TANK_HEIGHT: float = 3.0
const MAP_LAYER: int = 1
## The clearances the story computed from the scene, metres, with the slack a measured one may differ by.
const NEAR_TANK_GAP: float = 1.7
const FAR_TANK_GAP: float = 7.7
const PANEL_GAP: float = 3.0
const GAP_SLACK: float = 0.1
## The layers of the pieces that count for the nearest-piece test: map, cliffs and water, cover.
const PIECE_LAYERS: int = 1 | 32 | 64
## A Shot fired at the north-west tank from this far, metres, and how many; it ends on the tank's wall within this much.
const SHOT_RANGE: float = 8.6
const SHOTS: int = 5
const WALL_SLACK: float = 0.15
## Metres short of the braking distance at which the reverse key goes down, the drive speed at which it comes up, and the longest drive.
const BRAKE_MARGIN: float = 1.0
const BRAKE_RELEASE: float = 0.3
const DRIVE_LIMIT: int = 2400
## Ticks watched after the Unit has stopped.
const SIT_TICKS: int = 90
## The route of a ground Unit: along z = ROUTE_Z (north of the centre line, which the container stands on) to the waypoint ROUTE_CORNER_X
## metres from the middle of the Map, then to the zone; a waypoint is reached within WAYPOINT_RADIUS; a steer key goes down beyond the dead
## band, radians.
const ROUTE_Z: float = -3.5
const ROUTE_CORNER_X: float = 46.0
const WAYPOINT_RADIUS: float = 8.0
const STEER_DEADBAND: float = 0.03

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	_tanks_are_tall()
	_clearances()
	await _tanks_stop_shots()
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		await _reach_the_zones(type_index)


## The distance from a zone's footprint to the wall of a tank, metres (the footprint is a rectangle on x and z).
func _gap_to_tank(side: int, tank: Node3D) -> float:
	var centre: Vector3 = _k.centre(side)
	var half: Vector3 = _k.zone(side).size / 2.0
	var near: Vector2 = Vector2(clampf(tank.global_position.x, centre.x - half.x, centre.x + half.x), clampf(tank.global_position.z, centre.z - half.z, centre.z + half.z))
	return near.distance_to(Vector2(tank.global_position.x, tank.global_position.z)) - TANK_RADIUS


func _tanks_are_tall() -> void:
	var problems: PackedStringArray = []
	var masks: Array[int] = [_q.units.stats(Quick.TRUCK).collision_mask, _q.units.stats(Quick.GYROCOPTER).collision_mask, _q.controller.rules.shot_collision_mask]
	for path: String in Kit23.TANK_PATHS:
		var tank: Node3D = _q.map.find(path) as Node3D
		var collider: StaticBody3D = tank.get_node("Collider") as StaticBody3D
		var shape: CylinderShape3D = (collider.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
		_q.kit.need(problems, collider.collision_layer == MAP_LAYER and is_equal_approx(shape.radius, TANK_RADIUS) and is_equal_approx(shape.height, TANK_HEIGHT), "%s: layer %d, radius %s, height %s" % [path.get_file(), collider.collision_layer, shape.radius, shape.height])
		for mask: int in masks:
			_q.kit.need(problems, (collider.collision_layer & mask) != 0, "%s is not in the mask %d of a Truck, the Gyrocopter or the Shots" % [path.get_file(), mask])
	var structures: Array[Node] = _q.map.find("Depot").find_children("*", "Structure", true, false)
	_q.kit.need(problems, structures.is_empty(), "the depot holds %d Structures (pieces with hit points)" % structures.size())
	_q.kit.verdict("tanks_are_tall_pieces", problems, "the depot's three tanks are still cylinders of radius %.2f and height %.1f on the map layer, in the Truck's mask, the Gyrocopter's and the Shots' (so they stop every Unit and every Shot), and the depot holds no piece with hit points" % [TANK_RADIUS, TANK_HEIGHT])


func _clearances() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	for side: int in 2:
		var centre: Vector3 = _k.centre(side)
		var rect: Rect2 = Rect2(Vector2(centre.x - _k.zone(side).size.x / 2.0, centre.z - _k.zone(side).size.z / 2.0), Vector2(_k.zone(side).size.x, _k.zone(side).size.z))
		var gaps: Array[float] = []
		for path: String in Kit23.TANK_PATHS:
			gaps.append(_gap_to_tank(side, _q.map.find(path) as Node3D))
		gaps.sort()
		_q.kit.need(problems, absf(gaps[0] - NEAR_TANK_GAP) <= GAP_SLACK, "zone %d is %.3f m from its nearer tank (the story says about %.1f)" % [side, gaps[0], NEAR_TANK_GAP])
		_q.kit.need(problems, gaps[1] > FAR_TANK_GAP - GAP_SLACK and gaps[1] < gaps[2], "zone %d is %.3f m from the south tank" % [side, gaps[1]])
		var best: float = INF
		var name: String = ""
		for shape: Node in _q.map.map.find_children("*", "CollisionShape3D", true, false):
			var holder: Node = shape.get_parent()
			if not (holder is CollisionObject3D) or holder is Area3D or holder.name == &"Floor" or String(holder.get_path()).contains("Base") or String(holder.get_path()).contains("FuelTanks") or holder.is_in_group("map_edge"):
				continue
			if ((holder as CollisionObject3D).collision_layer & PIECE_LAYERS) == 0 or (shape as CollisionShape3D).shape == null:
				continue
			var box: AABB = (shape as CollisionShape3D).global_transform * (shape as CollisionShape3D).shape.get_debug_mesh().get_aabb()
			var apart: Vector2 = Vector2(maxf(maxf(rect.position.x - box.end.x, box.position.x - rect.end.x), 0.0), maxf(maxf(rect.position.y - box.end.z, box.position.z - rect.end.y), 0.0))
			if apart.length() < best:
				best = apart.length()
				name = String(holder.get_path()).trim_prefix(String(_q.map.map.get_path()) + "/")
		_q.kit.need(problems, best >= PANEL_GAP - GAP_SLACK, "zone %d is %.3f m from %s" % [side, best, name])
		summary.append("zone %d: tanks %.2f / %.2f / %.2f m, nearest piece %s %.2f m" % [side, gaps[0], gaps[1], gaps[2], name, best])
		measured.append("clearance_zone%d=tank_%.3f_%.3f_%.3f_piece_%s_%.3f" % [side, gaps[0], gaps[1], gaps[2], name.get_file(), best])
	_q.kit.verdict("zone_clearances", problems, "%s (the story computed about %.1f, %.1f and %.1f m)" % ["; ".join(summary), NEAR_TANK_GAP, FAR_TANK_GAP, PANEL_GAP])


## A Truck 8.6 m south of the north-west tank fires five Shots at it: each ends on the tank's wall, and the tank is as it was.
func _tanks_stop_shots() -> void:
	var problems: PackedStringArray = []
	var tank: Node3D = _q.map.find(Kit23.TANK_PATHS[0]) as Node3D
	var before: Array[Node] = tank.find_children("*", "", true, false)
	await _k.park(1)
	await _k.put(0, Quick.TRUCK, tank.global_position + Vector3(0.0, 0.0, SHOT_RANGE), Vector3.FORWARD, 1.0)
	var ends: int = _q.units.shot_ends.size()
	await _k.a.fire_n(0, SHOTS)
	await _q.kit.advance(Kit23.SETTLE * 4)
	var wall: PackedFloat64Array = []
	for index: int in range(ends, _q.units.shot_ends.size()):
		var end: Vector3 = _q.units.shot_ends[index]
		wall.append(Vector2(end.x - tank.global_position.x, end.z - tank.global_position.z).length())
	_q.kit.need(problems, wall.size() == SHOTS, "%d of %d Shots ended" % [wall.size(), SHOTS])
	for distance: float in wall:
		_q.kit.need(problems, absf(distance - TANK_RADIUS) <= WALL_SLACK, "a Shot ended %.3f m from the tank's axis (the wall is at %.2f)" % [distance, TANK_RADIUS])
	_q.kit.need(problems, tank.find_children("*", "", true, false).size() == before.size() and (tank.get_node("Collider") as StaticBody3D).collision_layer == MAP_LAYER, "the tank's nodes or its layer changed")
	measured.append("shots_end_on_the_tank_wall=%s" % ["_".join(Array(wall).map(func(value: float) -> String: return "%.2f" % value))])
	_q.kit.verdict("tanks_stop_shots_and_stand", problems, "%d Shots fired at the north-west tank from %.1f m ended %s m from its axis (the wall is at %.2f m), and the tank stood unchanged" % [SHOTS, SHOT_RANGE, ", ".join(Array(wall).map(func(value: float) -> String: return "%.2f" % value)), TANK_RADIUS])
	await _k.park(0)


## A ground Unit of a type, from outside the Gate of its own Base to the zone on its side at full throttle, steered round the Map's
## container (a straight run along the centre line meets it) by a waypoint ROUTE_Z north of the line, braked by the reverse key, then left
## to stand: it slides against no tank, ends inside the zone at rest, and is refuelled.
func _reach_the_zones(type_index: int) -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(type_index)
	var braking_distance: float = stats.max_speed * stats.max_speed / (2.0 * stats.braking)
	var summary: PackedStringArray = []
	for player: int in 2:
		var side: int = player
		await _k.park(1 - player)
		var east: float = 1.0 if player == 1 else -1.0
		var start: Vector3 = Vector3(_k.a.swap().outside_point(player).x, 0.0, ROUTE_Z)
		var corner: Vector3 = Vector3(east * ROUTE_CORNER_X, 0.0, ROUTE_Z)
		var target: Vector3 = _k.centre(side)
		await _k.put(player, type_index, start, Vector3(-east, 0.0, 0.0), 0.5)
		var body: Unit = _k.unit(player)
		_k.watch.clear()
		_k.watch.logging = true
		var waited: int = 0
		var goal: Vector3 = corner
		while body.is_alive and waited < DRIVE_LIMIT:
			if goal == corner and _flat(body.global_position, corner).length() < WAYPOINT_RADIUS:
				goal = target
			if goal == target and _flat(body.global_position, target).length() <= braking_distance + BRAKE_MARGIN:
				break
			_q.harness.drive(player, 1, _steer(body, goal))
			await _q.kit.tick()
			waited += 1
		_q.harness.drive(player, -1, 0)
		while body.is_alive and body.current_speed > BRAKE_RELEASE and waited < DRIVE_LIMIT:
			await _q.kit.tick()
			waited += 1
		_q.harness.drive(player, 0, 0)
		await _q.kit.advance(SIT_TICKS)
		_k.watch.logging = false
		var touched: int = 0
		for row: Dictionary in _k.rows(player):
			for slide: String in row["slides"]:
				touched += 1 if slide.contains("FuelTanks") else 0
		var list: Array = _k.rows(player)
		_q.kit.need(problems, body.is_alive and waited < DRIVE_LIMIT, "%s of Player %d: alive %s after %d ticks, at %s" % [stats.type_id, player + 1, body.is_alive, waited, body.global_position])
		_q.kit.need(problems, touched == 0, "%s of Player %d slid against a tank on %d rows" % [stats.type_id, player + 1, touched])
		_q.kit.need(problems, bool(list.back()["listed"][side]) and float(list.back()["speed"]) <= _settings.stopped_speed, "%s of Player %d ended with the zone listing it %s at a real speed of %.4f" % [stats.type_id, player + 1, list.back()["listed"], list.back()["speed"]])
		_q.kit.need(problems, absf(body.global_position.x - target.x) <= _k.zone(side).size.x / 2.0 and absf(body.global_position.z - target.z) <= _k.zone(side).size.z / 2.0, "%s of Player %d stopped %s from the middle of the zone" % [stats.type_id, player + 1, body.global_position - target])
		_q.kit.need(problems, _k.first_gain(player) >= 0 and float(list.back()["fuel"]) > stats.fuel_capacity / 2.0 + 1.0, "%s of Player %d ended with %.2f Fuel from half a tank" % [stats.type_id, player + 1, list.back()["fuel"]])
		summary.append("P%d %d ticks" % [player + 1, waited])
		await _k.park(player)
	measured.append("reach_%s=%s" % [stats.type_id, ";".join(summary)])
	_q.kit.verdict("%s_reaches_each_zone_from_its_gate" % stats.type_id, problems, "a %s driven from outside the Gate of each Player's Base to the zone on its side (%s) braked, stopped inside it and was refuelled, sliding against no tank" % [stats.type_id, ", ".join(summary)])


## A point or the difference of two on the ground plane.
func _flat(a: Vector3, b: Vector3) -> Vector2:
	return Vector2(b.x - a.x, b.z - a.z)


## The steer key (1 left, -1 right, 0 none) that turns a Unit toward a point, with a dead band.
func _steer(body: Unit, goal: Vector3) -> int:
	var facing: Vector3 = -body.global_transform.basis.z
	var wanted: Vector3 = Vector3(goal.x - body.global_position.x, 0.0, goal.z - body.global_position.z)
	var turn: float = facing.signed_angle_to(wanted, Vector3.UP)
	return 1 if turn > STEER_DEADBAND else (-1 if turn < -STEER_DEADBAND else 0)
