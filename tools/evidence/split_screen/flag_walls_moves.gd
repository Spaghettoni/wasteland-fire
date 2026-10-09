extends RefCounted
## The movement checks of the flag_walls scenario (Story 012 AC-1, AC-2 and AC-6): spawn_and_exits
## (every type from both Garage spots of both Bases straight out of the Gate on the throttle alone,
## touching nothing, with the Truck's gaps to a Gate post and to the box) and stops (each ground
## type into the Gate-side Flag Wall at full throttle stops flush at its face, and a Shot fired
## pressed against it ends at the muzzle inside it); flag_walls_over.gd then runs the Gyrocopter
## over a Flag Wall and the view of the seated Flag. Run by flag_walls.gd. Implements:
## production/epics/wasteland-fire/story-012-flag-walls.md AC-1, AC-2 and AC-6. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs.

## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, the model's box, judge_stop().
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The checks of what goes over a Flag Wall (flag_walls_over.gd).
const Over: GDScript = preload("res://tools/evidence/split_screen/flag_walls_over.gd")

## Base-local z where an exit ends, and the ticks it may take (map_bases.gd's rule).
const EXIT_END_Z: float = -30.0
const EXIT_LIMIT_TICKS: int = 900
## The Truck's gaps the story states: to a Gate post and to the box, metres, and their tolerance.
const POST_GAP: float = 0.3
const BOX_GAP: float = 0.5
const GAP_TOLERANCE: float = 0.02
## Metres out of a face where a run starts (the centre is that and the half-length further).
const RUN: float = 14.0
## Ticks a run may take, and a stop is a real speed below this, m/s, for this many ticks.
const RUN_LIMIT_TICKS: int = 420
const HIT_SHARE: float = 0.75

var _w: Walls
## The Truck's least gap to a Gate post and to the box over all its exits.
var _truck_gaps: Vector2 = Vector2(INF, INF)


func _init(kit: Walls) -> void:
	_w = kit


## The checks, in order, then the ones of flag_walls_over.gd. A coroutine: await it.
func run() -> void:
	await _exits()
	await _stops()
	var over: Over = Over.new(_w)
	await over.run()


## spawn_and_exits (AC-6): each type from the first spot and the spare of both Bases, two at a time.
func _exits() -> void:
	var problems: PackedStringArray = []
	var parts: PackedStringArray = []
	for type_index: int in _w.s.q.controller.unit_types().size():
		var times: PackedStringArray = []
		for spot: int in 2:
			var pair: Array[Dictionary] = await _exit_pair(type_index, spot, problems)
			times.append("%.2f/%.2f" % [pair[0]["seconds"], pair[1]["seconds"]])
		parts.append("%s %s s" % [_w.s.q.units.stats(type_index).type_id, " ".join(times)])
	_w.s.q.kit.need(problems, absf(_truck_gaps.x - POST_GAP) <= GAP_TOLERANCE and absf(_truck_gaps.y - BOX_GAP) <= GAP_TOLERANCE,
		"the Truck passes %.3f m from a Gate post and %.3f m from the box, not %.1f and %.1f" % [_truck_gaps.x, _truck_gaps.y, POST_GAP, BOX_GAP])
	_w.s.q.kit.verdict("spawn_and_exits", problems, "16 runs, two at a time, straight from rest to Base-local z %.0f on the throttle alone, no wall contact; seconds from the first spot and the spare (Base A / Base B): %s; the Truck passes %.3f m from a Gate post and %.3f m from the box" % [
		EXIT_END_Z, "; ".join(parts), _truck_gaps.x, _truck_gaps.y])


## One exit for each Player at once, both of one type from the spot of one index in their own Base
## (map_bases.gd's pattern). Returns {seconds, contacts, gate, box} per Player and adds the
## problems.
func _exit_pair(type_index: int, spot: int, problems: PackedStringArray) -> Array[Dictionary]:
	var q: Quick = _w.s.q
	var markers: Array[Marker3D] = []
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for base: Base in _w.bases:
		var marker: Marker3D = base.spawn_point if spot == 0 else base.spare_spawn_points[0]
		markers.append(marker)
		spots.append(marker.global_position)
		facings.append(-marker.global_transform.basis.z)
	var types: Array[int] = [type_index, type_index]
	await q.map.stage(types, spots, facings, true)
	var done: Array[int] = [-1, -1]
	var touched: Array[int] = [0, 0]
	for count: int in range(0, EXIT_LIMIT_TICKS + 1):
		for player: int in Kit.PLAYERS:
			var unit: Unit = q.units.units[player]
			if count > 0 and done[player] < 0:
				touched[player] += 1 if q.map.wall_contact(unit) else 0
				done[player] = count if _w.bases[player].to_local(unit.global_position).z <= EXIT_END_Z else -1
			q.harness.drive(player, -1 if done[player] > 0 and unit.current_speed > 0.0 else (1 if done[player] < 0 else 0), 0)
		if done[0] > 0 and done[1] > 0:
			break
		await q.kit.tick()
	q.harness.release_all()
	var results: Array[Dictionary] = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = q.units.units[player]
		var gaps: Vector3 = _gaps(_w.bases[player], markers[player], unit.stats.collision_size)
		var label: String = "%s P%d %s/%s" % [unit.type_id, player + 1, _w.bases[player].name, markers[player].name]
		q.kit.need(problems, done[player] > 0, label + " did not reach local z %.0f" % EXIT_END_Z)
		q.kit.need(problems, touched[player] == 0 and gaps.z > 0.0, label + " touched on %d ticks, least gap %.3f m" % [touched[player], gaps.z])
		if unit.type_id == &"truck":
			_truck_gaps = Vector2(minf(_truck_gaps.x, gaps.x), minf(_truck_gaps.y, gaps.y))
		results.append({"seconds": float(done[player]) / 60.0, "contacts": touched[player]})
	return results


## The least lateral gap, metres, between a straight run's swept box (from its marker to EXIT_END_Z)
## and a static body of the Base whose span along the run meets it: x to a Gate wall (a Gate post),
## y to a Flag Wall, z to any (below zero the boxes overlap). The Flag Walls count as static bodies.
func _gaps(base: Base, marker: Marker3D, size: Vector3) -> Vector3:
	var start: Vector3 = base.to_local(marker.global_position)
	var least: Vector3 = Vector3(INF, INF, INF)
	for node: Node in base.find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		var box: BoxShape3D = shape.shape as BoxShape3D
		if box == null or not (shape.get_parent() is StaticBody3D):
			continue
		var bounds: AABB = base.global_transform.affine_inverse() * shape.global_transform * AABB(-box.size / 2.0, box.size)
		if bounds.end.z > EXIT_END_Z - size.z / 2.0 and bounds.position.z < start.z + size.z / 2.0:
			var gap: float = maxf(bounds.position.x - (start.x + size.x / 2.0), (start.x - size.x / 2.0) - bounds.end.x)
			least.z = minf(least.z, gap)
			least.x = minf(least.x, gap) if String(shape.get_parent().name).begins_with("GateWall") else least.x
			least.y = minf(least.y, gap) if shape.get_parent().get_parent().name == &"Defences" else least.y
	return least


## stops (AC-2): each ground type, at once from each Player, into the Gate-side Flag Wall of the
## other Player's Base at full throttle: met at speed, stopped flush at the face within the ticks
## the quick-fix kit allows; then a Shot fired from where it stands ends at its muzzle, inside the
## wall.
func _stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var q: Quick = _w.s.q
	var face_z: float = Walls.SEAT.z - Walls.FACE
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		await _w.restore_all()
		var stats: UnitStats = q.units.stats(type_index)
		var spots: Array[Vector3] = []
		var facings: Array[Vector3] = []
		for player: int in Kit.PLAYERS:
			var at: Array[Vector3] = _w.pose(1 - player, Walls.GATE, Walls.FACE + RUN + stats.collision_size.z / 2.0)
			spots.append(at[0])
			facings.append(at[1])
		await q.map.stage([type_index, type_index], spots, facings, true)
		q.map.clear_log()
		q.kit.on_tick = q.map.log_tick
		var contact: Array[int] = [-1, -1]
		var rest: int = 0
		for _tick: int in RUN_LIMIT_TICKS:
			for player: int in Kit.PLAYERS:
				q.harness.drive(player, 1, 0)
			await q.kit.tick()
			for player: int in Kit.PLAYERS:
				contact[player] = q.map.places[player].size() - 1 if contact[player] < 0 and q.map.wall_contact(q.units.units[player]) else contact[player]
			rest = rest + 1 if contact[0] >= 0 and contact[1] >= 0 and q.map.real_speed(0, -1) < Quick.STOP_SPEED and q.map.real_speed(1, -1) < Quick.STOP_SPEED else 0
			if rest >= 6:
				break
		q.kit.on_tick = Callable()
		q.harness.release_all()
		for player: int in Kit.PLAYERS:
			var base: Base = _w.bases[1 - player]
			var label: String = "p%d %s into %s's Gate-side Flag Wall" % [player + 1, stats.type_id, base.name]
			var numbers: Array[float] = q.judge_stop(player, contact[player], func(at: Vector3) -> float: return absf(base.to_local(at).z - face_z),
					stats.collision_size.z / 2.0, label, problems)
			q.kit.need(problems, numbers[0] >= HIT_SHARE * stats.max_speed, "%s met it at %.2f m/s, under %.0f%% of %.1f" % [label, numbers[0], HIT_SHARE * 100.0, stats.max_speed])
			notes.append("%s met it at %.1f m/s, stopped in %d ticks at %.3f m" % [label.get_slice(" into", 0), numbers[0], int(numbers[1]), numbers[2]])
			var unit: Unit = q.units.units[player]
			var muzzle: Vector3 = unit.global_position - unit.global_transform.basis.z * stats.muzzle_forward + Vector3.UP * q.controller.rules.shooting_height
			await q.kit.advance(_w.longest_cadence())
			var end: Vector3 = await _w.shoot(player)
			q.kit.need(problems, end.distance_to(muzzle) <= Quick.SHOT_TOLERANCE, "%s: the Shot fired pressed against the face ended %.3f m from the muzzle" % [label, end.distance_to(muzzle)])
	await _w.restore_all()
	q.kit.verdict("stops", problems, "full throttle from %.0f m out: %s; a Shot fired pressed against the face ended at the muzzle inside the wall (a Shot at the face from afar ends on it: damage)" % [RUN, " | ".join(notes)])
