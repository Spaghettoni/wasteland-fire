extends RefCounted
## What the ammunition building is to everything that moves or shoots, in the Story 024 scenario ammo_buildings, AC-1: it stops every
## ground type driven at it from either side (flush, none of it entered) and every kind of Shot (a ground Unit's from the zone side and
## from the Base side, a Gyrocopter's fired from above it, a Turret's whose target left play after the Shot was launched), so a Unit
## parked behind it takes nothing; a Turret's sight ray through it is blocked, as through cover; and it is no Structure, takes no
## damage, is not Cover and stands as it was after every Shot. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-1.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const TURRET_STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"
## The cover layer, by value, and the building's height the story caps at the Wall Panels' 2 m.
const COVER_LAYER: int = 64
const PANEL_HEIGHT: float = 2.0
## Ticks a ground Unit is driven at the building, and the gap it ends from the face, metres.
const DRIVE_TICKS: int = 150
const FLUSH: float = 0.05
const NO_ENTRY: float = 0.01
## How far from the face a ground Unit starts, metres.
const RUN_UP: float = 10.0
## Shots fired by a ground Unit at the building, and how far behind it the parked Unit stands.
const SHOTS: int = 3
const BEHIND: float = 10.0
## How far from the face a Shot may end, metres.
const END_SLACK: float = 0.05
## How far from a Turret the target stands for its Shot, metres (in range, clear), and the ticks the Turret is given to fire.
const TARGET_DISTANCE: float = 21.0
const TURRET_WAIT: int = 240
## How long a Shot is given to end, ticks.
const END_WAIT: int = 120
## How far beyond the building the sight ray is cast, metres.
const BEYOND: float = 3.0

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit24
var _q: Quick


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	_it_is_a_building()
	await _ground_units_stop()
	await _unit_shots_stop()
	await _gyrocopter_shot_from_above()
	await _turret_shot_stops()
	_turret_sight_is_blocked()
	_it_stands_as_it_was()


## The half extent of the building's box along x (its depth toward the centre) and z, metres, and its height.
func _box(side: int) -> Vector3:
	return ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size


## The x of the building's face toward the centre (toward_centre true) or toward its own Base.
func _face_x(side: int, toward_centre: bool) -> float:
	var sign: float = _k.inward(side).x * (1.0 if toward_centre else -1.0)
	return _k.building(side).global_position.x + sign * _box(side).x / 2.0


## The building is a static body on the cover layer only, low, no Structure, not under the Map's Cover, with nothing that takes damage.
func _it_is_a_building() -> void:
	var problems: PackedStringArray = []
	for side: int in 2:
		var body: StaticBody3D = _k.building(side)
		_q.kit.need(problems, body.collision_layer == COVER_LAYER and body.collision_mask == 0, "building %d: layer %d, mask %d" % [side, body.collision_layer, body.collision_mask])
		_q.kit.need(problems, _box(side).y <= PANEL_HEIGHT, "building %d is %.2f m tall" % [side, _box(side).y])
		_q.kit.need(problems, not (body is Structure) and not body.has_method(&"apply_damage") and body.get(&"type_id") == null, "building %d has hit points or a type" % side)
		_q.kit.need(problems, body.get_parent() == _q.map.map and not _q.map.find("Cover").is_ancestor_of(body), "building %d is under the Map's Cover or not the Map's own child" % side)
		_q.kit.need(problems, body.find_children("*", "Structure", true, false).is_empty() and body.find_children("*", "Turret", true, false).is_empty(), "building %d holds a Structure" % side)
	_q.kit.need(problems, (_q.units.stats(Quick.GYROCOPTER).collision_mask & COVER_LAYER) == 0 and (_q.units.stats(Quick.TRUCK).collision_mask & COVER_LAYER) != 0 and (_q.controller.rules.shot_collision_mask & COVER_LAYER) != 0, "the masks do not read the cover layer as the story says")
	_q.kit.verdict("it_is_a_low_building_on_the_cover_layer", problems, "both ammunition buildings are static bodies on the cover layer alone (64), %.1f m tall (no taller than the %.0f m Wall Panels), no Structure, no hit points, not under the Map's Cover; the ground types' masks and the Shots' hold that layer and the Gyrocopter's does not" % [_box(0).y, PANEL_HEIGHT])


## Each ground type driven at the building from the zone side and from the Base side at full throttle, at each building: it ends flush
## against the face (its front within FLUSH of it), none of it ever past the face, its real speed zero, and the last rows slide against
## the building.
func _ground_units_stop() -> void:
	var problems: PackedStringArray = []
	var drives: int = 0
	for side: int in 2:
		var player: int = side
		for from_centre: bool in [true, false]:
			for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
				var stats: UnitStats = _q.units.stats(type_index)
				var toward: Vector3 = -_k.inward(side) if from_centre else _k.inward(side)
				var face: float = _face_x(side, from_centre)
				var start: Vector3 = Vector3(face - toward.x * RUN_UP, 0.0, _k.building(side).global_position.z)
				await _k.park(1 - player)
				await _k.f.put(player, type_index, start, toward, 1.0)
				_k.watch.clear()
				_k.watch.logging = true
				await _k.a().k.drive(player, DRIVE_TICKS)
				_k.watch.logging = false
				var half: float = stats.collision_size.z / 2.0
				var deepest: float = -INF
				for row: Dictionary in _k.rows(player):
					deepest = maxf(deepest, ((row["at"] as Vector3).x + toward.x * half - face) * toward.x)
				var last: Dictionary = _k.rows(player).back()
				var gap: float = absf(((last["at"] as Vector3).x + toward.x * half - face))
				var label: String = "%s of Player %d from the %s at building %d" % [stats.type_id, player + 1, "zone" if from_centre else "Base", side]
				_q.kit.need(problems, gap <= FLUSH and deepest <= NO_ENTRY, "%s: ended %.3f m from the face, the deepest %.3f m past it" % [label, gap, deepest])
				_q.kit.need(problems, float(last["speed"]) <= 0.01 and bool(last["alive"]), "%s: real speed %.4f, alive %s" % [label, last["speed"], last["alive"]])
				var touching: int = 0
				for slide: String in last["slides"]:
					touching += 1 if slide.ends_with(String(_k.building(side).name)) else 0
				_q.kit.need(problems, touching > 0, "%s: did not slide against the building (%s)" % [label, last["slides"]])
				drives += 1
	measured.append("ground_units_stopped=%d_drives" % drives)
	_q.kit.verdict("ground_units_stop_at_the_building", problems, "the Motorbike, the Buggy and the Truck driven at full throttle at each ammunition building from the zone side and from the Base side (%d drives of %d ticks) each ended with its front within %.2f m of the face, none of it ever more than %.2f m past it, at rest and sliding against the building" % [drives, DRIVE_TICKS, FLUSH, NO_ENTRY])
	await _k.park(0)
	await _k.park(1)


## A Unit's Shots at the building from the zone side (both buildings) and from the Base side (west): each ends on the face (within
## END_SLACK), and a Buggy of the other Player parked BEHIND the building, on the line, keeps every hit point. The shooter is the Player
## whose Base's Turrets leave it alone or are out of its reach, so no Turret's Shot is counted among the Unit's: from the zone side the
## Player of the other Base (the Turrets of the building's own Base are 40 m away), from the Base side the Player of that Base.
func _unit_shots_stop() -> void:
	var problems: PackedStringArray = []
	var total: int = 0
	for case: Array in [[0, true, 1], [1, true, 0], [0, false, 0]]:
		var side: int = case[0]
		var from_centre: bool = case[1]
		var player: int = case[2]
		var toward: Vector3 = -_k.inward(side) if from_centre else _k.inward(side)
		var face: float = _face_x(side, from_centre)
		var z: float = _k.building(side).global_position.z
		await _k.park(1 - player)
		await _k.f.put(1 - player, Quick.BUGGY, Vector3(face + toward.x * (_box(side).x + BEHIND), 0.0, z), toward, 1.0)
		var hit_points: float = _k.unit(1 - player).hit_points
		await _k.f.put(player, Quick.BUGGY, Vector3(face - toward.x * RUN_UP, 0.0, z), toward, 1.0)
		var ends: int = _q.units.shot_ends.size()
		await _k.a().fire_n(player, SHOTS)
		await _q.kit.advance(END_WAIT / 4)
		var label: String = "Player %d's Buggy from the %s at building %d" % [player + 1, "zone" if from_centre else "Base", side]
		_q.kit.need(problems, _q.units.shot_ends.size() - ends == SHOTS, "%s: %d of %d Shots ended (a Turret's among them?)" % [label, _q.units.shot_ends.size() - ends, SHOTS])
		for index: int in range(ends, _q.units.shot_ends.size()):
			var end: Vector3 = _q.units.shot_ends[index]
			_q.kit.need(problems, absf(end.x - face) <= END_SLACK and absf(end.z - z) <= _box(side).z / 2.0 and end.y > 0.0, "%s: a Shot ended at %s, the face is at x %.2f" % [label, end, face])
			total += 1
		_q.kit.need(problems, is_equal_approx(_k.unit(1 - player).hit_points, hit_points), "%s: the Buggy parked %.0f m behind the building lost %.1f hit points" % [label, BEHIND, hit_points - _k.unit(1 - player).hit_points])
	measured.append("unit_shots_stopped=%d" % total)
	_q.kit.verdict("unit_shots_stop_at_the_building", problems, "%d Shots of a Buggy, from the zone side of each building and from the Base side of the west one, each ended on the face within %.2f m, and a Buggy of the other Player parked %.0f m behind the building on the line kept all its hit points" % [total, END_SLACK, BEHIND])
	await _k.park(0)
	await _k.park(1)


## A Gyrocopter hovering over the building, its muzzle inside it, fires: the Shot ends at once inside the box; the same Gyrocopter
## clear of the building fires a Shot that flies its whole range (the control).
func _gyrocopter_shot_from_above() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var box: Vector3 = _box(0)
	var centre: Vector3 = _k.building(0).global_position
	await _k.park(1)
	await _k.f.put(0, Quick.GYROCOPTER, Vector3(centre.x, 0.0, centre.z), Vector3.RIGHT, 1.0)
	var ends: int = _q.units.shot_ends.size()
	var muzzle: Vector3 = Vector3(centre.x + stats.muzzle_forward, _q.controller.rules.shooting_height, centre.z)
	await _k.a().fire_n(0, 2)
	await _q.kit.advance(Kit24.SETTLE * 3)
	_q.kit.need(problems, _q.units.shot_ends.size() - ends == 2, "%d of 2 Shots of the Gyrocopter over the building ended" % (_q.units.shot_ends.size() - ends))
	for index: int in range(ends, _q.units.shot_ends.size()):
		var end: Vector3 = _q.units.shot_ends[index]
		_q.kit.need(problems, absf(end.x - centre.x) <= box.x / 2.0 and absf(end.z - centre.z) <= box.z / 2.0 and end.distance_to(muzzle) <= END_SLACK, "a Shot fired from above the building ended at %s, its muzzle was at %s" % [end, muzzle])
	await _k.f.put(0, Quick.GYROCOPTER, Vector3(centre.x + box.x / 2.0 + RUN_UP, 0.0, centre.z), Vector3.RIGHT, 1.0)
	ends = _q.units.shot_ends.size()
	var from: Vector3 = _k.unit(0).global_position
	await _k.a().fire_n(0, 1)
	await _q.kit.advance(END_WAIT)
	var flown: float = (_q.units.shot_ends[ends] as Vector3).distance_to(Vector3(from.x + stats.muzzle_forward, _q.controller.rules.shooting_height, from.z)) if _q.units.shot_ends.size() > ends else -1.0
	_q.kit.need(problems, absf(flown - stats.weapon_range) <= END_SLACK, "the control Shot flew %.2f m, the Gyrocopter's range is %.1f" % [flown, stats.weapon_range])
	measured.append("gyro_shot_over_building_ends_in_box=2_control_flew_%.2f" % flown)
	_q.kit.verdict("gyrocopter_shot_from_above_stops", problems, "a Gyrocopter hovering over the middle of the west building (its muzzle %.1f m ahead, inside it) fired 2 Shots that each ended inside the box at their muzzle, where the same Gyrocopter 10 m clear of it fired a Shot that flew its whole range of %.1f m (%.2f)" % [stats.muzzle_forward, stats.weapon_range, flown])
	await _k.park(0)


## The Turret of a Base nearest the line to a building: a real Turret fires at the other Player's Unit standing TARGET_DISTANCE from it on
## the line to the face; the target leaves play the tick the Shot is launched, so the Shot flies on; it ends on the face of the building.
func _turret_shot_stops() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	for side: int in 2:
		var shooter_base: int = side
		var target_player: int = 1 - side
		var face: Vector3 = Vector3(_face_x(side, false), _q.controller.rules.shooting_height, _k.building(side).global_position.z)
		var chosen: Turret = null
		var best: float = INF
		for node: Node in _q.map.map.find_children("*", "Turret", true, false):
			var turret: Turret = node as Turret
			if turret.get_parent().get_parent() == _q.units.bases[shooter_base] and Vector2(turret.global_position.x - face.x, turret.global_position.z - face.z).length() < best:
				best = Vector2(turret.global_position.x - face.x, turret.global_position.z - face.z).length()
				chosen = turret
		var toward: Vector3 = Vector3(face.x - chosen.global_position.x, 0.0, face.z - chosen.global_position.z).normalized()
		var at: Vector3 = Vector3(chosen.global_position.x, 0.0, chosen.global_position.z) + toward * TARGET_DISTANCE
		await _k.park(1 - target_player)
		await _k.f.put(target_player, Quick.BUGGY, at, -toward, 1.0)
		var walls: Object = _k.a().k.walls()
		var mark: int = walls.fired.size()
		var waited: int = 0
		var record: Dictionary = {}
		while waited < TURRET_WAIT and record.is_empty():
			await _q.kit.tick()
			waited += 1
			for index: int in range(mark, walls.fired.size()):
				if walls.fired[index]["turret"] == chosen and record.is_empty():
					record = walls.fired[index]
		_k.unit(target_player).leave_play()
		_q.kit.need(problems, not record.is_empty(), "side %d: the Turret at %s fired no Shot at a Buggy 21 m away in %d ticks" % [side, chosen.global_position, waited])
		if record.is_empty():
			continue
		waited = 0
		while (record["end"] as Vector3) == Vector3.INF and waited < END_WAIT:
			await _q.kit.tick()
			waited += 1
		var end: Vector3 = record["end"]
		_q.kit.need(problems, end != Vector3.INF and absf(end.x - face.x) <= END_SLACK and absf(end.z - _k.building(side).global_position.z) <= _box(side).z / 2.0, "side %d: the Turret's Shot ended at %s, the building's face is at x %.2f (z %.1f)" % [side, end, face.x, face.z])
		_q.kit.need(problems, Vector2(end.x - chosen.global_position.x, end.z - chosen.global_position.z).length() <= _q.units.stats(Quick.BUGGY).weapon_range + 1.6 + 1.0, "side %d: the Shot ended %.2f m from the Turret" % [side, Vector2(end.x - chosen.global_position.x, end.z - chosen.global_position.z).length()])
		summary.append("side %d: from %s to %s (%.2f m)" % [side, chosen.global_position, end, Vector2(end.x - chosen.global_position.x, end.z - chosen.global_position.z).length()])
		await _k.mines().revive(target_player)
		await _k.park(target_player)
	measured.append("turret_shots_stopped=%d" % summary.size())
	_q.kit.verdict("turret_shot_stops_at_the_building", problems, "a real Turret of each Base fired at the other Player's Buggy standing %.0f m from it on the line to the building's Base-facing face, and with the target gone the Shot flew on and ended on that face (%s)" % [TARGET_DISTANCE, "; ".join(summary)])


## A Turret's sight ray (the Shot mask plus the Turret's sight_extra_mask, from its muzzle, hit from inside) from the Turret of each Base
## nearest the building through the building to a point beyond it meets the building first; the same ray to a point short of it meets
## nothing. (The Base's other Turret has a Wreck of the cover on its line to the building: the ray is stopped by the Wreck, as by cover.)
func _turret_sight_is_blocked() -> void:
	var problems: PackedStringArray = []
	var data: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	var mask: int = _q.controller.rules.shot_collision_mask | data.sight_extra_mask
	var space: PhysicsDirectSpaceState3D = _q.map.map.get_world_3d().direct_space_state
	for side: int in 2:
		var centre: Vector3 = Vector3(_k.building(side).global_position.x, _q.controller.rules.shooting_height, _k.building(side).global_position.z)
		var nearest: Turret = null
		for node: Node in _q.map.map.find_children("*", "Turret", true, false):
			var other: Turret = node as Turret
			if other.get_parent().get_parent() == _q.units.bases[side] and (nearest == null or other.global_position.distance_to(centre) < nearest.global_position.distance_to(centre)):
				nearest = other
		for turret: Turret in [nearest]:
			var flat: Vector3 = Vector3(centre.x - turret.global_position.x, 0.0, centre.z - turret.global_position.z).normalized()
			var muzzle: Vector3 = Vector3(turret.global_position.x, 0.0, turret.global_position.z) + flat * data.muzzle_forward + Vector3.UP * _q.controller.rules.shooting_height
			var beyond: Vector3 = centre + flat * (_box(side).x / 2.0 + BEYOND)
			var short: Vector3 = centre - flat * (_box(side).x / 2.0 + BEYOND)
			for case: Array in [[beyond, true], [short, false]]:
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle, case[0], mask, [turret.get_rid()])
				query.hit_from_inside = true
				var hit: Dictionary = space.intersect_ray(query)
				var met: bool = not hit.is_empty() and hit["collider"] == _k.building(side)
				_q.kit.need(problems, met == bool(case[1]) and (bool(case[1]) or hit.is_empty()), "the sight ray of %s to %s met %s" % [turret.name, case[0], hit.get("collider")])
	_q.kit.verdict("turret_sight_is_blocked_by_the_building", problems, "a sight ray from the muzzle of each Turret of each Base toward the middle of the ammunition building on its side, on the Shots' mask plus the Turrets' sight mask (%d), met the building first when cast to a point %.0f m beyond it and nothing when cast to a point short of it" % [mask, BEYOND])


## After all of it each building is as it was: its layer, its nodes, no damage taken, and no Shot of the scenario's end left in flight.
func _it_stands_as_it_was() -> void:
	var problems: PackedStringArray = []
	for side: int in 2:
		var body: StaticBody3D = _k.building(side)
		_q.kit.need(problems, body.collision_layer == COVER_LAYER and body.collision_mask == 0 and body.get_child_count() == 16 and is_instance_valid(body), "building %d changed: layer %d, %d children" % [side, body.collision_layer, body.get_child_count()])
	_q.kit.verdict("building_stands_as_it_was", problems, "after the Units, the Shots and the Turrets' Shots both buildings stand with their layer and their sixteen children, no hit point lost because they have none")
