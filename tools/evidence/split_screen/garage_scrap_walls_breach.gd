extends RefCounted
## What a fallen Garage panel and a fallen field panel let through, for the garage_scrap_walls scenario (Story 019 AC-3
## and AC-4): garage_exposed (with the side panel beside a spawn spot down, the other Player's Buggy in the yard hits the
## Truck standing on that spot through the breach, while with the panel standing the same Shot ends on the panel; every
## ground type drives into and out of the Garage through a side panel's breach; a back panel down opens only onto the
## 0.7 m gap in front of the Base's back wall, where nothing fits and nothing gets through; with both fallen a Shot from
## outside the Base reaches the Garage) and field_breach (a Unit and a Shot through a field panel's breach, the neighbours
## standing; a lay beside or in a standing field panel refused with "No room for a Mine here" and laid once it has fallen,
## and the Mine destroys the Buggy that drives over it). Run by garage_scrap_walls.gd. Tooling only. Every number comes
## from the game's data; the scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The ticks a run may take and the tolerance of a place, metres.
const RUN_LIMIT_TICKS: int = 420
const TOLERANCE: float = 0.01
## Where the shooter of the exposed spot stands: metres out of the Garage wall's outer face, in the yard beside it; and
## the panel along the side wall whose span holds the spot's z (the panel beside the spawn spot).
const YARD_FROM: float = 4.5
const SPOT_PANEL: int = 0
## The types: the Unit on the spot (a Truck, the widest) and the shooter (a Buggy).
const TARGET_TYPE: int = Quick.TRUCK
const SHOOTER_TYPE: int = Quick.BUGGY
## Base-local, along the back wall: the Garage back wall's lane panel (x 0 to 3.5) and the Base's back wall panel behind
## it (x 0 to 3.4625); the Truck stands in the Garage at this z when the Shot from outside is to reach it; the shooter
## outside stands this far out of the Base's back wall's outer face.
const TARGET_Z: float = 8.0
const OUTSIDE_FROM: float = 6.0
## The index of the Base's back wall panel behind the Garage's lane panel (Story 018's panels).
const BASE_BACK_PANEL: int = 4

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _garage_exposed()


## The Base-local point of the spot's line out in the yard: `out` metres from the Base's axis along a side run's outward
## direction, at the spot's z.
func _yard_point(base_index: int, run: int, out: float) -> Vector3:
	return _k.frame(base_index, run) * Vector3(Kit19.OUTWARD[run].x * out, 0.0, Kit19.SPOT_Z)


## garage_exposed (AC-3): see the class doc.
func _garage_exposed() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var shots: int = 0
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	var shooter_stats: UnitStats = _q.units.stats(SHOOTER_TYPE)
	var target_stats: UnitStats = _q.units.stats(TARGET_TYPE)
	var want_unit: float = shooter_stats.damage * matrix.multiplier(shooter_stats.type_id, target_stats.type_id)
	var want_panel: float = shooter_stats.damage * matrix.multiplier(shooter_stats.type_id, &"flag_wall")
	for base_index: int in Kit.PLAYERS:
		var shooter: int = 1 - base_index
		for run: int in [Kit19.LEFT, Kit19.RIGHT]:
			var near: Structure = _k.panel(base_index, run, SPOT_PANEL)
			var span: AABB = _k.extent(base_index, run, near)
			_q.kit.need(problems, span.position.z <= Kit19.SPOT_Z and span.end.z >= Kit19.SPOT_Z, "%s %s panel %d spans z %.2f to %.2f, not the spot's z %.1f" % [_k.k.m.w.bases[base_index].name, Kit19.RUN_NAMES[run], SPOT_PANEL + 1, span.position.z, span.end.z, Kit19.SPOT_Z])
			for state: String in ["standing", "fallen"]:
				await _k.restore_all()
				if state == "fallen":
					near.destroy()
				await _k.k.stage(base_index, TARGET_TYPE, _k.spot_point(base_index, run), _k.k.m.w.way(base_index, Vector3.FORWARD))
				var target: Unit = _q.units.units[base_index]
				_q.units.retype(shooter, SHOOTER_TYPE, _yard_point(base_index, run, Kit19.OUTER_FACES[run] + YARD_FROM), -_k.outward(base_index, run))
				await _q.kit.advance(Kit19.Kit18.SETTLE)
				await _q.kit.advance(_k.k.m.w.longest_cadence())
				var panel_before: float = near.hit_points
				var unit_before: float = target.hit_points
				var end: Vector3 = await _k.k.m.w.shoot(shooter)
				shots += 1
				var label: String = "%s %s, panel beside the spot %s" % [_k.k.m.w.bases[base_index].name, Kit19.RUN_NAMES[run], state]
				var ground_off: float = Vector2(end.x, end.z).distance_to(Vector2(target.global_position.x, target.global_position.z))
				var reach: float = Vector2(target_stats.collision_size.x, target_stats.collision_size.z).length() / 2.0
				if state == "standing":
					_q.kit.need(problems, end != Vector3.INF and absf(_k.along_out(base_index, run, end) - Kit19.OUTER_FACES[run]) <= TOLERANCE, "%s: the Shot ended at %s, not on the panel's face" % [label, end])
					_q.kit.need(problems, is_equal_approx(panel_before - near.hit_points, want_panel) and is_equal_approx(unit_before, target.hit_points), "%s: the panel took %.2f (expected %.2f) and the Unit %.2f" % [label, panel_before - near.hit_points, want_panel, unit_before - target.hit_points])
				else:
					_q.kit.need(problems, end != Vector3.INF and ground_off <= reach and absf(_k.along_out(base_index, run, end) - Kit19.INNER_FACES[run]) > TOLERANCE, "%s: the Shot ended %.2f m from the Unit's middle (its half diagonal is %.2f) at %s" % [label, ground_off, reach, end])
					_q.kit.need(problems, is_equal_approx(unit_before - target.hit_points, want_unit) and is_equal_approx(panel_before, near.hit_points), "%s: the Unit took %.2f (expected %.2f) and the fallen panel %.2f" % [label, unit_before - target.hit_points, want_unit, panel_before - near.hit_points])
				notes.append("%s %s %s" % [_k.k.m.w.bases[base_index].name, Kit19.RUN_NAMES[run].trim_prefix("Garage"), "panel" if state == "standing" else "Unit"])
	var drives: int = 0
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		for outside: bool in [true, false]:
			drives += 2
			await _k.drive_pair(type_index, [Kit19.LEFT, Kit19.LEFT], [outside, outside], problems)
	var gap: float = Kit19.LENGTHS[Kit19.LEFT]
	_q.kit.need(problems, absf(gap - 3.3333333) <= TOLERANCE and _q.units.stats(Quick.TRUCK).collision_size.x < gap, "the Truck (%.2f m wide) does not fit the Garage side breach (%.4f m)" % [_q.units.stats(Quick.TRUCK).collision_size.x, gap])
	var back: String = await _back_breach(problems)
	measured.append("exposed_shots=%d garage_drives=%d" % [shots, drives])
	_q.kit.verdict("garage_exposed", problems, "with the panel beside a spawn spot down (the first panel of the side wall, z 2 to 5.33, which the spot's line z 5 crosses) the other Player's Buggy in the yard 4.5 m out hit the Truck standing on that spot through the breach and took %.0f off it (the Buggy's 12 times the matrix), at either Garage and either spot, while with the panel standing the same Shot ended on its outer face and took %.0f off the panel and nothing off the Truck (%d Shots: %s); %d drives, a Motorbike, a Buggy and a Truck of each Player through the middle panel's breach of a side wall, from the yard into the Garage and out, with its neighbours standing and blocking a ray, touching nothing (the Truck, %.2f m wide, passes the %.3f m gap); %s" % [
		want_unit, want_panel, shots, ", ".join(notes), drives, _q.units.stats(Quick.TRUCK).collision_size.x, gap, back])
	await _k.restore_all()


## The back wall's breach (AC-3): with the Garage's lane panel down and the Base's back wall panel behind it standing, a
## Motorbike driven at the breach stops at the Base's wall, a Shot from inside the Garage ends on it and one from
## outside the Base ends on its outer face; with both down the Shot from outside reaches a Truck in the Garage.
func _back_breach(problems: PackedStringArray) -> String:
	var gap: float = Kit19.Kit18.INNER_FACES[Kit19.Kit18.BACK] - Kit19.OUTER_FACES[Kit19.BACK]
	var narrowest: float = INF
	for stats: UnitStats in _q.controller.rules.unit_types:
		narrowest = minf(narrowest, minf(stats.collision_size.x, stats.collision_size.z))
	_q.kit.need(problems, absf(gap - 0.7) <= TOLERANCE and gap < narrowest, "the gap behind the Garage's back wall is %.3f m and the narrowest Unit side is %.2f m" % [gap, narrowest])
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	var shooter_stats: UnitStats = _q.units.stats(SHOOTER_TYPE)
	var want_unit: float = shooter_stats.damage * matrix.multiplier(shooter_stats.type_id, _q.units.stats(TARGET_TYPE).type_id)
	var lane_x: float = _k.centre(Kit19.BACK, Kit19.LANE[Kit19.BACK])
	var half: float = _q.units.stats(Quick.MOTORBIKE).collision_size.z / 2.0
	var base_face: float = Kit19.Kit18.INNER_FACES[Kit19.Kit18.BACK]
	var outer_face: float = Kit19.Kit18.OUTER_FACES[Kit19.Kit18.BACK]
	var notes: PackedStringArray = []
	for base_index: int in Kit.PLAYERS:
		var base: Base = _k.k.m.w.bases[base_index]
		var other: int = 1 - base_index
		var lane: Structure = _k.panel(base_index, Kit19.BACK, Kit19.LANE[Kit19.BACK])
		var behind: Structure = _k.k.panel(base_index, Kit19.Kit18.BACK, BASE_BACK_PANEL)
		var span: AABB = _k.extent(base_index, Kit19.BACK, lane)
		var wall_span: AABB = _k.k.extent(base_index, behind)
		_q.kit.need(problems, absf(span.position.x) <= TOLERANCE and absf(wall_span.position.x) <= TOLERANCE, "%s: the Garage's lane panel starts at x %.3f and the Base wall's panel behind it at x %.3f" % [base.name, span.position.x, wall_span.position.x])
		await _k.restore_all()
		lane.destroy()
		var types: Array[int] = [-1, -1]
		var spots: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		var facings: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
		types[base_index] = Quick.MOTORBIKE
		spots[base_index] = _k.spot(base_index, Kit19.BACK, Kit19.LANE[Kit19.BACK], _k.start_out(Kit19.BACK, half, false))
		facings[base_index] = _k.outward(base_index, Kit19.BACK)
		await _q.map.stage(types, spots, facings, true)
		_q.map.clear_log()
		_q.kit.on_tick = _q.map.log_tick
		var contact: int = -1
		var rest: int = 0
		for _tick: int in RUN_LIMIT_TICKS:
			_q.harness.drive(base_index, 1, 0)
			await _q.kit.tick()
			contact = _q.map.places[base_index].size() - 1 if contact < 0 and _q.map.wall_contact(_q.units.units[base_index]) else contact
			rest = rest + 1 if contact >= 0 and _q.map.real_speed(base_index, -1) < Quick.STOP_SPEED else 0
			if rest >= 6:
				break
		_q.kit.on_tick = Callable()
		_q.harness.release_all()
		var label: String = "%s: a Motorbike driven at the Garage's back breach" % base.name
		var numbers: Array[float] = _q.judge_stop(base_index, contact, func(at: Vector3) -> float: return absf(base.to_local(at).z - base_face), half, label, problems)
		# A Shot from inside the Garage along the breach ends on the Base's wall; one from outside ends on its outer face.
		await _k.restore_all()
		lane.destroy()
		var inside_end: Vector3 = await _fire_along(base_index, base_index, Vector3(lane_x, 0.0, 4.0), Vector3.BACK)
		_q.kit.need(problems, inside_end != Vector3.INF and absf(base.to_local(inside_end).z - base_face) <= TOLERANCE, "%s: a Shot from inside the Garage through the back breach ended at z %.3f, not on the Base wall's inner face %.1f" % [base.name, base.to_local(inside_end).z, base_face])
		await _k.restore_all()
		lane.destroy()
		var outside_end: Vector3 = await _fire_along(other, base_index, Vector3(lane_x, 0.0, outer_face_z(OUTSIDE_FROM)), Vector3.FORWARD)
		_q.kit.need(problems, outside_end != Vector3.INF and absf(base.to_local(outside_end).z - outer_face) <= TOLERANCE and lane.is_standing == false and is_equal_approx(behind.hit_points, Kit19.HIT_POINTS - shooter_stats.damage * matrix.multiplier(shooter_stats.type_id, &"flag_wall")), "%s: a Shot from outside the Base ended at z %.3f (the Base wall's outer face is %.1f) with the wall's panel at %.1f hit points" % [base.name, base.to_local(outside_end).z, outer_face, behind.hit_points])
		# With both down the Shot from outside reaches a Truck in the Garage.
		await _k.restore_all()
		lane.destroy()
		behind.destroy()
		await _k.k.stage(base_index, TARGET_TYPE, base.global_transform * Vector3(lane_x, 0.0, TARGET_Z), _k.k.m.w.way(base_index, Vector3.FORWARD))
		var target: Unit = _q.units.units[base_index]
		var before: float = target.hit_points
		var through_end: Vector3 = await _fire_along(other, base_index, Vector3(lane_x, 0.0, outer_face_z(OUTSIDE_FROM)), Vector3.FORWARD, false)
		var local_end: Vector3 = base.to_local(through_end)
		_q.kit.need(problems, through_end != Vector3.INF and local_end.z < Kit19.INNER_FACES[Kit19.BACK] and is_equal_approx(before - target.hit_points, want_unit), "%s: with both back panels down the Shot from outside ended at z %.3f and took %.2f off the Truck in the Garage (expected %.2f)" % [base.name, local_end.z, before - target.hit_points, want_unit])
		notes.append("%s: stopped %.2f m from the Base wall's inner face by it at %.1f m/s, inside Shot on z %.1f, outside Shot on z %.1f, both down: Truck -%.0f" % [base.name, numbers[2], numbers[0], base.to_local(inside_end).z, base.to_local(outside_end).z, before - target.hit_points])
	await _k.restore_all()
	return "a back panel down opens only onto the %.1f m gap before the Base's back wall, where no Unit fits (the narrowest side of any Unit is %.2f m): a Motorbike driven at the breach from the Garage stopped flush against the Base wall's panel, a Shot from inside the Garage ended on that panel's inner face and one from outside the Base on its outer face (so the Garage stays closed), and with both panels down a Shot from outside the Base flew through the two breaches into the Garage and took the Buggy's %.0f off a Truck standing there (%s)" % [gap, narrowest, want_unit, "; ".join(notes)]


## The Base-local z of a point `out` metres beyond the Base's back wall's outer face.
func outer_face_z(out: float) -> float:
	return Kit19.Kit18.OUTER_FACES[Kit19.Kit18.BACK] + out


## Player `player`'s Buggy is put at a Base-local place of a Base, facing a Base-local direction, and fires one Shot: its
## end. With `clear_target` the Unit of the Base's owner is parked out of the line first.
func _fire_along(player: int, base_index: int, at: Vector3, facing: Vector3, clear_target: bool = true) -> Vector3:
	if clear_target:
		await _k.k.park(base_index)
	_q.units.retype(player, SHOOTER_TYPE, _k.k.m.w.point(base_index, at), _k.k.m.w.way(base_index, facing))
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	await _q.kit.advance(_k.k.m.w.longest_cadence())
	return await _k.k.m.w.shoot(player)
