extends RefCounted
## The clearances and the solid of the turrets scenario (Story 013 AC-1), on the shipped Turrets and
## Map 01. exits: every type from both Garage spots of both Bases straight out of the Gate on the
## throttle alone. turns: from each spot a hard turn held at full throttle from the moment the tail
## clears the Gate wall's outer face, once toward the spot's own side and once across the Gate.
## inbound: in through the Gate from 20 m out, on the two lanes at Base-local x = +-4 and on the two
## lines 45 degrees off the Gate's axis through the middle of the Gate wall's outer face. Each run is
## recorded up to its first wall contact with its least gap to either Turret of its Base. solid:
## every type, the Gyrocopter included, driven into a Turret at full throttle stops flush at its
## drum, and a Shot fired pressed against it ends at the muzzle inside it. Run by turrets.gd.
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-1. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, judge_stop().
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The map kit (map_kit.gd): what a wall contact is.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")
## The Story 012 movement checks (flag_walls_moves.gd): where an exit ends.
const Moves: GDScript = preload("res://tools/evidence/split_screen/flag_walls_moves.gd")

## Metres out of the Gate wall's outer face where an inbound run starts (AC-1: 20 m, along its
## line), the angle of the diagonal lines off the Gate's axis, degrees, and the Base-local x of the
## lanes (AC-1: the Garage spots' x).
const OUT: float = 20.0
const DIAGONAL_DEGREES: float = 45.0
const LANE_X: float = 4.0
## The Base-local z where an inbound run ends: past the Turrets and the Gate wall.
const INBOUND_END_Z: float = -10.0
## Ticks a run may take.
const RUN_LIMIT_TICKS: int = 420
## A least gap this small or smaller is a touch, metres.
const TOUCH: float = 0.05
## What a gap measured on a straight run may differ from the geometry's, metres, and what a gap
## measured on a turn may differ from the story's computed one.
const GEOMETRY_TOLERANCE: float = 0.05
const COMPUTED_TOLERANCE: float = 0.15
## The story's computed least gaps (AC-1), metres: a turn toward the spot's own side leaves the
## near Turret between AROUND_LOW (the Buggy's) and AROUND_HIGH (the Truck's); a turn across the
## Gate leaves the far Turret ACROSS by type index (Motorbike, Buggy, Truck, Gyrocopter).
const AROUND_LOW: float = 2.99
const AROUND_HIGH: float = 3.57
const ACROSS: Array[float] = [0.76, 0.61, 3.72, 4.37]
## Metres out of a Turret's drum where a drive into it starts, the share of its top speed it must
## meet the drum at, and the ticks the drive may take.
const RUN: float = 14.0
const HIT_SHARE: float = 0.75
const SOLID_LIMIT_TICKS: int = 420

var _k: Kit13
## What each check found, for the RESULT line.
var measured: PackedStringArray = []


## One run in Base-local terms, the same for each Player in their own Base: where the Unit starts
## and which way it faces, the steer held (1 left, -1 right, 0 none) once its centre is at or
## below `turn_z`, and where the run ends (`end_z`: reached going out, or going in when `inbound`).
class Run:
	var start: Vector3
	var look: Vector3
	var steer: int
	var turn_z: float
	var end_z: float
	var inbound: bool


	func _init(at: Vector3, facing: Vector3, steering: int, turns_at: float, ends_at: float,
			going_in: bool) -> void:
		start = at
		look = facing
		steer = steering
		turn_z = turns_at
		end_z = ends_at
		inbound = going_in


func _init(kit: Kit13) -> void:
	_k = kit


## The four checks, in order.
func run() -> void:
	await _exits()
	await _turns()
	await _inbound()
	await _solid()


## The type indices of the data, in order.
func _types() -> Array[int]:
	var found: Array[int] = []
	for type_index: int in _k.w.s.q.controller.unit_types().size():
		found.append(type_index)
	return found


## The two Garage spawn spots of a Base, Base-local: the first spot of its scene, then the spare.
func _spots() -> Array[Vector3]:
	var base: Base = _k.w.bases[0]
	var found: Array[Vector3] = [base.to_local(base.spawn_point.global_position)]
	for marker: Marker3D in base.spare_spawn_points:
		found.append(base.to_local(marker.global_position))
	return found


## The Base-local z of the Gate wall's outer face (AC-1: -15): a Gate wall's centre less half its
## depth.
func _face_z() -> float:
	var base: Base = _k.w.bases[0]
	var wall: StaticBody3D = base.get_node("Walls/GateWallLeft") as StaticBody3D
	var box: BoxShape3D = (wall.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	return base.to_local(wall.global_position).z - box.size.z / 2.0


## The least gap, metres, a straight run leaves to either Turret: the nearer of their axes'
## distances from the line through `start` along `look`, less the drum's radius and half the
## Unit's width.
func _straight_gap(start: Vector3, look: Vector3, width: float) -> float:
	var least: float = INF
	for side: int in Kit13.NAMES.size():
		var offset: Vector3 = Kit13.PLACES[side] - start
		least = minf(least, absf(offset.x * look.z - offset.z * look.x))
	return least - Kit13.RADIUS - width / 2.0


## The least gap, metres, from a Unit's box to either Turret of Player `player`'s Base.
func _least(unit: Unit, player: int) -> float:
	var least: float = INF
	for side: int in Kit13.NAMES.size():
		least = minf(least, _k.gap(unit, _k.turret(player, side)))
	return least


## The body the Unit's last move touched with a wall (a slide collision below the map kit's wall
## normal), or null.
func _touched(unit: Unit) -> Node:
	for index: int in unit.get_slide_collision_count():
		var contact: KinematicCollision3D = unit.get_slide_collision(index)
		if absf(contact.get_normal().y) < Map.WALL_NORMAL_Y:
			return contact.get_collider() as Node
	return null


## One run of a type for each Player at once, each in their own Base, the throttle held from rest
## and the steer from its tick on, recorded up to the first wall contact, the run's end or the
## tick limit. One dictionary per Player: {gap (the least gap to either Turret of their Base),
## ended ("end", "contact" or "limit"), contact (the body touched), turret (it was a Turret),
## ticks}. A coroutine: await it.
func _pair(type_index: int, plan: Run) -> Array[Dictionary]:
	var q: Quick = _k.w.s.q
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	var found: Array[Dictionary] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.w.point(player, plan.start))
		facings.append(_k.w.way(player, plan.look))
		found.append({"gap": INF, "ended": "", "contact": "", "turret": false, "ticks": 0})
	await q.map.stage([type_index, type_index], spots, facings, true)
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			var live: bool = found[player]["ended"] == ""
			var local: Vector3 = _k.w.bases[player].to_local(q.units.units[player].global_position)
			q.harness.drive(player, 1 if live else 0, plan.steer if live and local.z <= plan.turn_z else 0)
		await q.kit.tick()
		for player: int in Kit.PLAYERS:
			if found[player]["ended"] != "":
				continue
			var unit: Unit = q.units.units[player]
			var local: Vector3 = _k.w.bases[player].to_local(unit.global_position)
			found[player]["ticks"] = int(found[player]["ticks"]) + 1
			found[player]["gap"] = minf(float(found[player]["gap"]), _least(unit, player))
			var hit: Node = _touched(unit)
			if hit != null:
				found[player]["ended"] = "contact"
				found[player]["contact"] = String(hit.name)
				found[player]["turret"] = hit is Turret
			elif (local.z >= plan.end_z) if plan.inbound else (local.z <= plan.end_z):
				found[player]["ended"] = "end"
		if found[0]["ended"] != "" and found[1]["ended"] != "":
			break
	q.harness.release_all()
	for player: int in Kit.PLAYERS:
		found[player]["ended"] = "limit" if found[player]["ended"] == "" else found[player]["ended"]
	return found


## What every run must show: it touched no Turret and its least gap is above a touch; with
## `clean` it also ended at its end line without any wall contact.
func _judge(problems: PackedStringArray, found: Dictionary, label: String, clean: bool) -> void:
	var q: Quick = _k.w.s.q
	q.kit.need(problems, not bool(found["turret"]) and float(found["gap"]) > TOUCH, "%s touched a Turret (least gap %.3f m, %s)" % [label, float(found["gap"]), found["contact"]])
	if clean:
		q.kit.need(problems, found["ended"] == "end", "%s ended by %s (%s) after %d ticks, not at its end line" % [label, found["ended"], found["contact"], int(found["ticks"])])


## exits (AC-1): each type from both spots of both Bases straight on to Base-local z -30.
func _exits() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	var least: PackedStringArray = []
	for type_index: int in _types():
		var stats: UnitStats = q.units.stats(type_index)
		var worst: float = INF
		for start: Vector3 in _spots():
			var plan: Run = Run.new(start, Vector3.FORWARD, 0, INF, Moves.EXIT_END_Z, false)
			var found: Array[Dictionary] = await _pair(type_index, plan)
			var want: float = _straight_gap(start, plan.look, stats.collision_size.x)
			for player: int in Kit.PLAYERS:
				var label: String = "%s of Player %d from the spot at x %.0f" % [stats.type_id, player + 1, start.x]
				_judge(problems, found[player], label, true)
				q.kit.need(problems, absf(float(found[player]["gap"]) - want) <= GEOMETRY_TOLERANCE, "%s: least gap %.3f m, the geometry gives %.3f" % [label, float(found[player]["gap"]), want])
				worst = minf(worst, float(found[player]["gap"]))
		notes.append("%s %.2f m" % [stats.type_id, worst])
		least.append("%s:%.2f" % [stats.type_id, worst])
	measured.append("exits=%s" % "/".join(least))
	q.kit.verdict("exits", problems, "16 runs, two at a time, from both spots of both Bases straight to Base-local z %.0f on the throttle alone: no wall contact and the least gap to either Turret as the geometry says (%s)" % [
		Moves.EXIT_END_Z, ", ".join(notes)])


## turns (AC-1): from each spot a hard turn at full throttle from the moment the tail clears the
## Gate wall's outer face, toward the spot's own side and across the Gate; each against the
## story's computed least gap, none touching a Turret; the walls they then meet are recorded.
func _turns() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var face_z: float = _face_z()
	var around: Array[float] = []
	var across: Array[float] = []
	var met: Array[PackedStringArray] = []
	for _type: int in _types():
		around.append(INF)
		across.append(INF)
		met.append(PackedStringArray())
	for type_index: int in _types():
		var stats: UnitStats = q.units.stats(type_index)
		for start: Vector3 in _spots():
			var own: int = 1 if start.x < 0.0 else -1
			for steer: int in [own, -own]:
				var plan: Run = Run.new(start, Vector3.FORWARD, steer, face_z - stats.collision_size.z / 2.0, -INF, false)
				var found: Array[Dictionary] = await _pair(type_index, plan)
				for player: int in Kit.PLAYERS:
					var label: String = "%s of Player %d from the spot at x %.0f turning %s" % [stats.type_id, player + 1, start.x, "toward its own side" if steer == own else "across the Gate"]
					_judge(problems, found[player], label, false)
					if steer == own:
						around[type_index] = minf(around[type_index], float(found[player]["gap"]))
					else:
						across[type_index] = minf(across[type_index], float(found[player]["gap"]))
						var list: PackedStringArray = met[type_index]
						if found[player]["ended"] == "contact" and not list.has(found[player]["contact"]):
							list.append(found[player]["contact"])
						met[type_index] = list
	var notes: PackedStringArray = []
	var around_notes: PackedStringArray = []
	var across_notes: PackedStringArray = []
	var tower_notes: PackedStringArray = []
	var around_result: PackedStringArray = []
	var across_result: PackedStringArray = []
	for type_index: int in _types():
		var name: String = String(q.units.stats(type_index).type_id)
		q.kit.need(problems, around[type_index] >= AROUND_LOW - COMPUTED_TOLERANCE and around[type_index] <= AROUND_HIGH + COMPUTED_TOLERANCE, "%s turning toward its own side: least gap %.3f m, outside the computed %.2f to %.2f" % [name, around[type_index], AROUND_LOW, AROUND_HIGH])
		q.kit.need(problems, absf(across[type_index] - ACROSS[type_index]) <= COMPUTED_TOLERANCE, "%s turning across the Gate: least gap %.3f m, the story computed %.2f" % [name, across[type_index], ACROSS[type_index]])
		around_notes.append("%s %.2f" % [name, around[type_index]])
		across_notes.append("%s %.2f (computed %.2f)" % [name, across[type_index], ACROSS[type_index]])
		around_result.append("%s:%.2f" % [name, around[type_index]])
		across_result.append("%s:%.2f" % [name, across[type_index]])
		tower_notes.append("%s %s" % [name, "/".join(met[type_index]) if not met[type_index].is_empty() else "none"])
	q.kit.need(problems, absf(around[Quick.BUGGY] - AROUND_LOW) <= COMPUTED_TOLERANCE and absf(around[Quick.TRUCK] - AROUND_HIGH) <= COMPUTED_TOLERANCE, "own-side extremes: Buggy %.3f (computed %.2f), Truck %.3f (computed %.2f)" % [around[Quick.BUGGY], AROUND_LOW, around[Quick.TRUCK], AROUND_HIGH])
	measured.append("around=%s" % "/".join(around_result))
	measured.append("across=%s" % "/".join(across_result))
	notes.append("toward its own side, the near Turret: %s m (computed %.2f to %.2f)" % [", ".join(around_notes), AROUND_LOW, AROUND_HIGH])
	notes.append("across the Gate, the far Turret: %s m" % ", ".join(across_notes))
	notes.append("the wall met first after the turn across: %s" % ", ".join(tower_notes))
	q.kit.verdict("turns", problems, "32 runs, two at a time, a hard turn at full throttle from the tick the tail cleared the Gate wall's outer face (Base-local z %.0f): no Turret touched; %s" % [face_z, "; ".join(notes)])


## The four inbound runs of a Unit of a given length, Base-local: the lanes at x = +-LANE_X, from
## where its tail is OUT metres out of the Gate wall's outer face (a Truck's tail at z -35 would
## stand in the corner of the outer south wreck), and the lines DIAGONAL_DEGREES off the Gate's
## axis through the middle of the face, from OUT metres along each.
func _inbound_plans(face_z: float, length: float) -> Array[Run]:
	var plans: Array[Run] = []
	var rad: float = deg_to_rad(DIAGONAL_DEGREES)
	for side: float in [-1.0, 1.0]:
		plans.append(Run.new(Vector3(side * LANE_X, 0.0, face_z - OUT + length / 2.0), Vector3.BACK, 0, INF, INBOUND_END_Z, true))
	for side: float in [-1.0, 1.0]:
		var start: Vector3 = Vector3(side * OUT * sin(rad), 0.0, face_z - OUT * cos(rad))
		plans.append(Run.new(start, (Vector3(0.0, 0.0, face_z) - start).normalized(), 0, INF, INBOUND_END_Z, true))
	return plans


## inbound (AC-1): in through the Gate from 20 m out, on the two lanes and the two lines 45 degrees
## off the Gate's axis through the middle of the Gate wall's outer face.
func _inbound() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var face_z: float = _face_z()
	var lanes: PackedStringArray = []
	var lines: PackedStringArray = []
	var lane_result: PackedStringArray = []
	var line_result: PackedStringArray = []
	var bumps: PackedStringArray = []
	for type_index: int in _types():
		var stats: UnitStats = q.units.stats(type_index)
		var lane_worst: float = INF
		var line_worst: float = INF
		var plans: Array[Run] = _inbound_plans(face_z, stats.collision_size.z)
		for index: int in plans.size():
			var found: Array[Dictionary] = await _pair(type_index, plans[index])
			var lane: bool = index < 2
			var want: float = _straight_gap(plans[index].start, plans[index].look, stats.collision_size.x)
			for player: int in Kit.PLAYERS:
				var label: String = "%s of Player %d on the %s" % [stats.type_id, player + 1, "lane x %.0f" % plans[index].start.x if lane else "%.0f-degree line from x %.1f" % [DIAGONAL_DEGREES, plans[index].start.x]]
				_judge(problems, found[player], label, lane)
				if found[player]["ended"] == "end":
					q.kit.need(problems, absf(float(found[player]["gap"]) - want) <= GEOMETRY_TOLERANCE, "%s: least gap %.3f m, the geometry gives %.3f" % [label, float(found[player]["gap"]), want])
				elif found[player]["ended"] == "contact":
					bumps.append("%s met %s after %d ticks" % [label, found[player]["contact"], int(found[player]["ticks"])])
				if lane:
					lane_worst = minf(lane_worst, float(found[player]["gap"]))
				else:
					line_worst = minf(line_worst, float(found[player]["gap"]))
		lanes.append("%s %.2f" % [stats.type_id, lane_worst])
		lines.append("%s %.2f" % [stats.type_id, line_worst])
		lane_result.append("%s:%.2f" % [stats.type_id, lane_worst])
		line_result.append("%s:%.2f" % [stats.type_id, line_worst])
	measured.append("lanes=%s" % "/".join(lane_result))
	measured.append("lines=%s" % "/".join(line_result))
	q.kit.verdict("inbound", problems, "32 runs, two at a time, from 20 m out (on the lanes with the tail 20 m out): no Turret touched, the lanes without any wall contact; least gap on the lanes %s m, on the 45-degree lines %s m%s" % [
		", ".join(lanes), ", ".join(lines), "; walls met on the lines: %s" % "; ".join(bumps) if not bumps.is_empty() else ""])


## solid (AC-1): each type at once from each Player into its own Base's right-hand Turret at full
## throttle from RUN metres out: met at speed, stopped flush at the drum within the ticks the
## quick-fix kit allows; then a Shot fired from where it stands ends at its muzzle, inside the drum,
## and takes nothing off the Player's own Turret.
func _solid() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var q: Quick = _k.w.s.q
	for type_index: int in _types():
		await _k.restore_all()
		var stats: UnitStats = q.units.stats(type_index)
		var spots: Array[Vector3] = []
		var facings: Array[Vector3] = []
		for player: int in Kit.PLAYERS:
			var out: Vector3 = _k.w.way(player, Vector3.FORWARD)
			spots.append(_k.turret(player, Kit13.RIGHT).global_position + out * (Kit13.RADIUS + RUN + stats.collision_size.z / 2.0))
			facings.append(-out)
		await q.map.stage([type_index, type_index], spots, facings, true)
		q.map.clear_log()
		q.kit.on_tick = q.map.log_tick
		var contact: Array[int] = [-1, -1]
		var rest: int = 0
		for _tick: int in SOLID_LIMIT_TICKS:
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
			var who: Turret = _k.turret(player, Kit13.RIGHT)
			var label: String = "p%d %s into %s of Base %d" % [player + 1, stats.type_id, who.name, player + 1]
			var axis: Vector3 = who.global_position
			var numbers: Array[float] = q.judge_stop(player, contact[player], func(at: Vector3) -> float: return Vector2(at.x - axis.x, at.z - axis.z).length(),
					Kit13.RADIUS + stats.collision_size.z / 2.0, label, problems)
			q.kit.need(problems, numbers[0] >= HIT_SHARE * stats.max_speed, "%s met it at %.2f m/s, under %.0f%% of %.1f" % [label, numbers[0], HIT_SHARE * 100.0, stats.max_speed])
			var unit: Unit = q.units.units[player]
			var muzzle: Vector3 = unit.global_position - unit.global_transform.basis.z * stats.muzzle_forward + Vector3.UP * q.controller.rules.shooting_height
			var inside: float = Vector2(muzzle.x - axis.x, muzzle.z - axis.z).length()
			q.kit.need(problems, inside < Kit13.RADIUS, "%s: its muzzle is %.2f m from the drum's axis, not inside it" % [label, inside])
			await q.kit.advance(_k.w.longest_cadence())
			var end: Vector3 = await _k.w.shoot(player)
			q.kit.need(problems, end.distance_to(muzzle) <= Quick.SHOT_TOLERANCE, "%s: the Shot fired pressed against the drum ended %.3f m from the muzzle" % [label, end.distance_to(muzzle)])
			q.kit.need(problems, is_equal_approx(who.hit_points, who.stats.max_hit_points), "%s: its own Shot took %.1f hit points off its Turret" % [label, who.stats.max_hit_points - who.hit_points])
			notes.append("%s met it at %.1f m/s, stopped in %d ticks at %.3f m" % [label.get_slice(" into", 0), numbers[0], int(numbers[1]), numbers[2]])
	await _k.restore_all()
	q.kit.verdict("solid", problems, "full throttle from %.0f m out: %s; a Shot fired pressed against the drum ended at the muzzle inside it and took nothing off the Player's own Turret" % [RUN, " | ".join(notes)])
