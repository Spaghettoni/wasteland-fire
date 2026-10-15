extends RefCounted
## The movement checks of the base_walls scenario (Story 018 AC-1 and AC-2): spawn_exits (every type from both
## Garage spots of both Bases straight out of the Gate on the throttle alone, touching no Flag Wall, leg, Gate
## post or panel, with the Truck's gaps to a Gate post and to the box: Story 012 AC-6 again, now that the Gate
## walls are panels) and stops (each ground type into a panel of each of the five runs at full throttle, from the
## yard and from outside, stops flush at its face; a Shot fired pressed against it ends at the muzzle inside it).
## Run by base_walls.gd. Tooling only. Every number comes from the game's data; the scenario types only its test
## inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Base-local z where an exit ends, and the ticks it may take (map_bases.gd's rule).
const EXIT_END_Z: float = -30.0
const EXIT_LIMIT_TICKS: int = 900
## The Truck's gaps the story states (Story 012 AC-6): to a Gate post and to the box, metres, and their
## tolerance.
const POST_GAP: float = 0.3
const BOX_GAP: float = 0.5
const GAP_TOLERANCE: float = 0.02
## The ticks a run may take; a stop is a real speed below the kit's STOP_SPEED for this many ticks.
const RUN_LIMIT_TICKS: int = 420
const REST_TICKS: int = 6
## A Unit meets a panel at least at this share of its top speed.
const HIT_SHARE: float = 0.75

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick
## The Truck's least gap to a Gate post and to the box over all its exits.
var _truck_gaps: Vector2 = Vector2(INF, INF)


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _exits()
	await _stops()


## spawn_exits (AC-1): each type from the first spot and the spare of both Bases, two at a time.
func _exits() -> void:
	var problems: PackedStringArray = []
	var parts: PackedStringArray = []
	for type_index: int in _q.controller.unit_types().size():
		var times: PackedStringArray = []
		for spot: int in 2:
			var pair: Array[Dictionary] = await _exit_pair(type_index, spot, problems)
			times.append("%.2f/%.2f" % [pair[0]["seconds"], pair[1]["seconds"]])
		parts.append("%s %s s" % [_q.units.stats(type_index).type_id, " ".join(times)])
	_q.kit.need(problems, absf(_truck_gaps.x - POST_GAP) <= GAP_TOLERANCE and absf(_truck_gaps.y - BOX_GAP) <= GAP_TOLERANCE,
		"the Truck passes %.3f m from a Gate post and %.3f m from the box, not %.1f and %.1f" % [_truck_gaps.x, _truck_gaps.y, POST_GAP, BOX_GAP])
	_q.kit.verdict("spawn_exits", problems, "16 runs, two at a time, straight from rest to Base-local z %.0f on the throttle alone, no wall contact (a Flag Wall, a leg, a Gate post and a panel are all walls to the Unit's own record); seconds from the first spot and the spare (Base A / Base B): %s; the Truck passes %.3f m from a Gate post (a Gate-wall panel's inner end) and %.3f m from the box, as in Story 012" % [
		EXIT_END_Z, "; ".join(parts), _truck_gaps.x, _truck_gaps.y])
	measured.append("truck_gaps=%.3f/%.3f" % [_truck_gaps.x, _truck_gaps.y])


## One exit for each Player at once, both of one type from the spot of one index in their own Base. Returns
## {seconds} per Player and adds the problems.
func _exit_pair(type_index: int, spot: int, problems: PackedStringArray) -> Array[Dictionary]:
	var markers: Array[Marker3D] = []
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for base: Base in _k.m.w.bases:
		var marker: Marker3D = base.spawn_point if spot == 0 else base.spare_spawn_points[0]
		markers.append(marker)
		spots.append(marker.global_position)
		facings.append(-marker.global_transform.basis.z)
	await _q.map.stage([type_index, type_index], spots, facings, true)
	var done: Array[int] = [-1, -1]
	var touched: Array[int] = [0, 0]
	for count: int in range(0, EXIT_LIMIT_TICKS + 1):
		for player: int in Kit.PLAYERS:
			var unit: Unit = _q.units.units[player]
			if count > 0 and done[player] < 0:
				touched[player] += 1 if _q.map.wall_contact(unit) else 0
				done[player] = count if _k.m.w.bases[player].to_local(unit.global_position).z <= EXIT_END_Z else -1
			_q.harness.drive(player, -1 if done[player] > 0 and unit.current_speed > 0.0 else (1 if done[player] < 0 else 0), 0)
		if done[0] > 0 and done[1] > 0:
			break
		await _q.kit.tick()
	_q.harness.release_all()
	var results: Array[Dictionary] = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[player]
		var gaps: Vector3 = _gaps(_k.m.w.bases[player], markers[player], unit.stats.collision_size)
		var label: String = "%s P%d %s/%s" % [unit.type_id, player + 1, _k.m.w.bases[player].name, markers[player].name]
		_q.kit.need(problems, done[player] > 0, label + " did not reach local z %.0f" % EXIT_END_Z)
		_q.kit.need(problems, touched[player] == 0 and gaps.z > 0.0, label + " touched on %d ticks, least gap %.3f m" % [touched[player], gaps.z])
		if unit.type_id == &"truck":
			_truck_gaps = Vector2(minf(_truck_gaps.x, gaps.x), minf(_truck_gaps.y, gaps.y))
		results.append({"seconds": float(done[player]) / 60.0})
	return results


## The least lateral gap, metres, between a straight run's swept box (from its marker to EXIT_END_Z) and a static
## body of the Base whose span along the run meets it: x to a Gate-wall panel (a Gate post), y to a Flag Wall, z to
## any (below zero the boxes overlap).
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
			var run_name: String = String(shape.get_parent().get_parent().name)
			least.z = minf(least.z, gap)
			least.x = minf(least.x, gap) if run_name.begins_with("GateWall") else least.x
			least.y = minf(least.y, gap) if run_name == "Defences" else least.y
	return least


## stops (AC-2): each ground type, at once from each Player into a panel of each run of its own Base's walls at full
## throttle, from the yard and from outside: met at speed, stopped flush at the face within the ticks the quick-fix
## kit allows; then a Shot fired from where it stands ends at its muzzle, inside the wall.
func _stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var drives: int = 0
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type_index)
		var met: Array[float] = []
		for run: int in Kit18.RUN_NAMES.size():
			for outside: bool in [false, true]:
				drives += 2
				met.append_array(await _stop_pair(type_index, run, outside, problems))
		var slowest: float = INF
		for speed: float in met:
			slowest = minf(slowest, speed)
		notes.append("%s %.1f to %.1f m/s" % [stats.type_id, slowest, stats.max_speed])
	await _q.kit.advance(Kit18.SETTLE)
	measured.append("stops=%d" % drives)
	_q.kit.verdict("stops", problems, "%d drives at full throttle from %.0f m out, two at a time (each Player into its own Base's panel), a Motorbike, a Buggy and a Truck into a panel of the back wall, each side wall and each Gate wall, from the yard and from outside: each met it at speed (slowest met, by type: %s) and stopped flush at its face; a Shot fired pressed against the face ended at the muzzle inside the wall (outside a back wall the Map's shore edge stands %.1f m behind it, so those runs start 6.6 to 8.4 m out; none met a panel under %.0f%% of its top speed)" % [drives, Kit18.RUN, " | ".join(notes), Kit18.ROOM_OUTSIDE[Kit18.BACK], HIT_SHARE * 100.0])


## One pair of drives: both Players' Units of one type at the lane panel of one run of their own Base, on the yard
## side or the outer side. Returns the speeds they met the face at.
func _stop_pair(type_index: int, run: int, outside: bool, problems: PackedStringArray) -> Array[float]:
	var stats: UnitStats = _q.units.stats(type_index)
	var half: float = stats.collision_size.z / 2.0
	var face: float = Kit18.OUTER_FACES[run] if outside else Kit18.INNER_FACES[run]
	var start: float = _k.start_out(run, half, outside)
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.spot(player, run, Kit18.LANE[run], start))
		facings.append(_k.outward(player, run) * (-1.0 if outside else 1.0))
	await _q.map.stage([type_index, type_index], spots, facings, true)
	_q.map.clear_log()
	_q.kit.on_tick = _q.map.log_tick
	var contact: Array[int] = [-1, -1]
	var rest: int = 0
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			_q.harness.drive(player, 1, 0)
		await _q.kit.tick()
		for player: int in Kit.PLAYERS:
			contact[player] = _q.map.places[player].size() - 1 if contact[player] < 0 and _q.map.wall_contact(_q.units.units[player]) else contact[player]
		rest = rest + 1 if contact[0] >= 0 and contact[1] >= 0 and _q.map.real_speed(0, -1) < Quick.STOP_SPEED and _q.map.real_speed(1, -1) < Quick.STOP_SPEED else 0
		if rest >= REST_TICKS:
			break
	_q.kit.on_tick = Callable()
	_q.harness.release_all()
	var met: Array[float] = []
	for player: int in Kit.PLAYERS:
		var base: Base = _k.m.w.bases[player]
		var label: String = "p%d %s into %s's %s from %s" % [player + 1, stats.type_id, base.name, Kit18.RUN_NAMES[run], "outside" if outside else "the yard"]
		var across: Vector3 = Kit18.OUTWARD[run]
		var numbers: Array[float] = _q.judge_stop(player, contact[player], func(at: Vector3) -> float: return absf(base.to_local(at).dot(across) - face), half, label, problems)
		_q.kit.need(problems, numbers[0] >= HIT_SHARE * stats.max_speed, "%s met it at %.2f m/s, under %.0f%% of %.1f" % [label, numbers[0], HIT_SHARE * 100.0, stats.max_speed])
		met.append(numbers[0])
		var unit: Unit = _q.units.units[player]
		var muzzle: Vector3 = unit.global_position - unit.global_transform.basis.z * stats.muzzle_forward + Vector3.UP * _q.controller.rules.shooting_height
		await _q.kit.advance(_k.m.w.longest_cadence())
		var end: Vector3 = await _k.m.w.shoot(player)
		_q.kit.need(problems, end.distance_to(muzzle) <= Quick.SHOT_TOLERANCE, "%s: the Shot fired pressed against the face ended %.3f m from the muzzle" % [label, end.distance_to(muzzle)])
	return met
