extends RefCounted
## The damage and the fall of the turrets scenario (Story 013 AC-4), on the shipped Turrets and Map
## 01. damage: a Turret has 100 hit points and every type's Shots, Player 1's by Space and Player 2's
## by Period, take their damage times the matrix off it, so it falls to 20 Motorbike Shots, 9 Buggy,
## 4 Truck or 7 Gyrocopter Shots; the Unit fires from behind the canyon's rock, where no Turret sees
## it. friendly: a Player's own Shots end on that Player's Turret and take nothing, and a Turret's
## Shot that meets its own Player's Unit, Turret or Flag Wall ends there and takes nothing. fall: at 0
## the Turret stops on that tick (no turn, no Shot, a Shot in flight still lands), its rubble stops no
## Unit and no Shot, it stays down and no key builds, repairs or takes it over, and the tick its layer
## change acts in is measured. Run by turrets.gd. Implements:
## production/epics/wasteland-fire/story-013-turrets.md AC-4. Tooling only. Every number comes from
## the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, the mirror.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Walls' names and sizes.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## The Shots that bring a Turret down by type index (Motorbike, Buggy, Truck, Gyrocopter): the
## story's numbers, asserted against the data below.
const SHOTS_TO_FALL: Array[int] = [20, 9, 4, 7]
## The canyon Fuel Can behind the canyon's south rock, world (x, z) of Base A's side: a Unit there is
## hidden from both Turrets by a cliff its own Shots pass through.
const CANYON_CAN: Vector3 = Vector3(-88.0, 0.0, -26.0)
## Ticks a Unit may fire at a Turret before it must have brought it down.
const FIRE_LIMIT_TICKS: int = 480
## How far beyond a Turret's reach, metres from its aimed muzzle, the Truck stands that breaks one
## unanswered (its Shots fly further than the Turret's reach).
const OUTRANGE_BEYOND: float = 1.5
## Ticks a settled scene is watched for.
const WATCH: int = 120
## Metres in front of a Turret, along its rest heading, a Unit is put at, and the bearing off that
## heading a turning Turret is shown at, degrees.
const AHEAD: float = 12.0
const FAR_AHEAD: float = 20.0
const TURNING_DEGREES: float = 60.0
## The yaw, radians, a Turret must have turned before it is brought down mid-turn.
const MID_TURN: float = 0.3
## The place just inside the Gate (Base-local) a Unit is put at for the Flag Wall case (AC-4): 8 m
## to the Turret's side and 7 m in, so the Shot that misses it ends on the Gate-side Flag Wall.
const INSIDE_GATE: Vector3 = Vector3(2.0, 0.0, -12.0)
## How far past the Turret's axis, metres, a Shot through its fallen place must end, and the speed
## share of its top speed a Truck driven through it must keep.
const PAST_AXIS: float = 2.0
const THROUGH_SHARE: float = 0.9
## Metres out of a Turret a Truck is put at to be driven through its fallen place, and the least gap
## a layer-timing drive starts at.
const DRIVE_OUT: float = 14.0
const PRESSED_OUT: float = 1.0
## Ticks a layer-timing drive gets to come to rest against a Turret.
const REST_LIMIT_TICKS: int = 180

var _k: Kit13
## What each check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The three checks, in order.
func run() -> void:
	await _damage()
	await _friendly()
	await _fall()


## The Turret of Base `base_index` on the canyon side (z < 0 in the world: Base A's left, Base B's
## right) and the other one.
func _canyon_side(base_index: int) -> int:
	return Kit13.LEFT if base_index == 0 else Kit13.RIGHT


## The canyon Fuel Can's place on the side of Base `base_index`.
func _canyon_can(base_index: int) -> Vector3:
	return CANYON_CAN if base_index == 0 else Quick.mirrored(CANYON_CAN)


## damage (AC-4): each Player's Unit of each type fires at the canyon-side Turret of the other Base
## from behind the rock until it falls.
func _damage() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	var result: PackedStringArray = []
	var rules: MatchRules = q.controller.rules
	for type_index: int in q.controller.unit_types().size():
		var stats: UnitStats = q.units.stats(type_index)
		var turret_stats: TurretStats = _k.turret(0, Kit13.LEFT).stats as TurretStats
		var each: float = stats.damage * rules.damage_matrix.multiplier(stats.type_id, turret_stats.type_id)
		var wanted: int = ceili(turret_stats.max_hit_points / each)
		q.kit.need(problems, wanted == SHOTS_TO_FALL[type_index] and is_equal_approx(each, stats.damage), "the data brings a Turret down in %d %s Shots of %.1f, not %d" % [wanted, stats.type_id, each, SHOTS_TO_FALL[type_index]])
		var counts: PackedStringArray = []
		for shooter: int in Kit.PLAYERS:
			var base_index: int = 1 - shooter
			var target: Turret = _k.turret(base_index, _canyon_side(base_index))
			await _k.restore_all()
			var spot: Vector3 = _canyon_can(base_index)
			await _k.stage(shooter, type_index, spot, (target.global_position - spot).normalized())
			await q.kit.advance(_k.w.longest_cadence())
			var heard: Array[float] = []
			var record: Callable = func(hit_points: float, _most: float) -> void: heard.append(hit_points)
			target.hit_points_changed.connect(record)
			var fired: int = _k.firing.size()
			var hurt: int = _k.hp_mark()
			q.harness.set_key(q.harness.fire_key(shooter), true)
			var ticks: int = 0
			while target.is_standing and ticks < FIRE_LIMIT_TICKS:
				await q.kit.tick()
				ticks += 1
			q.harness.set_key(q.harness.fire_key(shooter), false)
			target.hit_points_changed.disconnect(record)
			var label: String = "Player %d's %s at Base %d's canyon-side Turret" % [shooter + 1, stats.type_id, base_index + 1]
			var steps: PackedStringArray = []
			for index: int in heard.size():
				q.kit.need(problems, is_equal_approx(heard[index], maxf(turret_stats.max_hit_points - each * (index + 1), 0.0)), "%s: hit %d left %.1f hit points" % [label, index + 1, heard[index]])
			q.kit.need(problems, heard.size() == wanted and not target.is_standing and target.hit_points == 0.0 and target.state == Turret.State.DESTROYED, "%s: %d hits, standing %s, %.1f hit points (%d wanted)" % [label, heard.size(), target.is_standing, target.hit_points, wanted])
			q.kit.need(problems, _k.firing.size() == fired and _k.hits_since(shooter, hurt).x == 0.0, "%s: a Turret fired %d Shots at the hidden Unit, %d hits on it" % [label, _k.firing.size() - fired, int(_k.hits_since(shooter, hurt).x)])
			counts.append("%d" % heard.size())
		notes.append("%s %s (%d wanted, %.0f each)" % [stats.type_id, "/".join(counts), wanted, each])
		result.append("%s:%s" % [stats.type_id, "/".join(counts)])
	# a Truck's Shots reach further than a Turret does: breaking one from outside its reach, unanswered
	await _k.restore_all()
	var far: Turret = _k.turret(0, Kit13.RIGHT)
	var truck: UnitStats = q.units.stats(Quick.TRUCK)
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var apart: float = far.stats.weapon_range + OUTRANGE_BEYOND
	await _k.stage(1, Quick.TRUCK, _k.ahead(far, 0, apart + far.stats.muzzle_forward), -out)
	await q.kit.advance(_k.w.longest_cadence())
	var seen: Array[float] = []
	var count: Callable = func(hit_points: float, _most: float) -> void: seen.append(hit_points)
	far.hit_points_changed.connect(count)
	var before: int = _k.firing.size()
	var truck_mark: int = _k.hp_mark()
	q.harness.set_key(q.harness.fire_key(1), true)
	var waited: int = 0
	while far.is_standing and waited < FIRE_LIMIT_TICKS:
		await q.kit.tick()
		waited += 1
	q.harness.set_key(q.harness.fire_key(1), false)
	far.hit_points_changed.disconnect(count)
	var sees: float = far.global_position.distance_to(q.units.units[1].global_position)
	q.kit.need(problems, not far.is_standing and seen.size() == SHOTS_TO_FALL[Quick.TRUCK] and _k.firing.size() == before and _k.hits_since(1, truck_mark).x == 0.0, "a Truck %.1f m from the Turret (its reach is %.0f m, the Truck's Shots %.0f m): %d hits, standing %s, %d Turret Shots, %d hits on the Truck" % [sees, far.stats.weapon_range, truck.weapon_range, seen.size(), far.is_standing, _k.firing.size() - before, int(_k.hits_since(1, truck_mark).x)])
	notes.append("a Truck %.0f m out, beyond the Turret's %.0f m reach and inside its own %.0f m, broke a Turret in %d Shots without drawing one" % [sees, far.stats.weapon_range, truck.weapon_range, seen.size()])
	await _k.restore_all()
	measured.append("damage=%s" % ",".join(result))
	q.kit.verdict("damage", problems, "a Turret of 100 hit points fell to the Shots (Player 2 at Base A, Player 1 at Base B), none fired at the Unit behind the rock and none hurt it: %s" % ", ".join(notes))


## The Shot a Turret fired first among those since `mark` of the record, or an empty Dictionary.
func _first_since(who: Turret, mark: int) -> Dictionary:
	for index: int in range(mark, _k.firing.size()):
		if _k.firing[index]["turret"] == who:
			return _k.firing[index]
	return {}


## Waits at most `limit` ticks for a recorded Turret Shot to end: its record, or {} when it never did.
func _await_end(record: Dictionary, limit: int) -> Dictionary:
	for _tick: int in limit:
		if not record.is_empty() and record["end_frame"] >= 0:
			return record
		await _k.w.s.q.kit.tick()
	return record if not record.is_empty() and record["end_frame"] >= 0 else {}


## The horizontal distance from a point to a Turret's axis.
func _from_axis(at: Vector3, who: Turret) -> float:
	return Vector2(at.x - who.global_position.x, at.z - who.global_position.z).length()


## friendly (AC-4): see the class doc.
func _friendly() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	var right: Turret = _k.turret(0, Kit13.RIGHT)
	var left: Turret = _k.turret(0, Kit13.LEFT)
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD)
	# a Player's own Shots end on that Player's Turret and take nothing off it
	for owner_player: int in Kit.PLAYERS:
		await _k.restore_all()
		var own: Turret = _k.turret(owner_player, Kit13.RIGHT)
		var out: Vector3 = _k.w.way(owner_player, Vector3.FORWARD)
		await _k.stage(owner_player, Quick.MOTORBIKE, own.global_position + out * AHEAD, -out)
		await q.kit.advance(_k.w.longest_cadence())
		var mark: int = q.units.shots.size()
		var hurt: int = _k.hp_mark()
		await q.units.hold_fire(owner_player, WATCH / 2)
		await q.kit.advance(Kit13.IN_FLIGHT_TICKS)
		var count: int = q.units.shot_ends.size() - mark
		var all_on: bool = count > 0
		for index: int in range(mark, q.units.shot_ends.size()):
			all_on = all_on and _from_axis(q.units.shot_ends[index], own) <= Kit13.RADIUS + 0.05
		q.kit.need(problems, all_on and is_equal_approx(own.hit_points, own.stats.max_hit_points) and _k.hits_since(owner_player, hurt).x == 0.0, "Player %d's own Shots: %d Shots, all ended on its Turret %s, it has %.0f hit points" % [owner_player + 1, count, all_on, own.hit_points])
		notes.append("Player %d's %d Motorbike Shots ended on its own Turret, 100 hit points left" % [owner_player + 1, count])
	# a Turret's Shot that meets its own Player's Unit
	await _k.restore_all()
	left.destroy()
	var victim_at: Vector3 = _k.ahead(right, 0, AHEAD)
	await _k.stage(1, Quick.MOTORBIKE, victim_at, -forward)
	q.units.retype(0, Quick.TRUCK, _k.ahead(right, 0, AHEAD + 12.0), -forward)
	await q.kit.advance(Kit13.SETTLE)
	var own_unit: Unit = q.units.units[0]
	var hurt_own: int = _k.hp_mark()
	var seen: Dictionary = await _overshoot(right, 1)
	var size: Vector3 = own_unit.stats.collision_size
	var inside: bool = not seen.is_empty() and absf(seen["end"].x - own_unit.global_position.x) <= size.z / 2.0 + 0.1 and absf(seen["end"].z - own_unit.global_position.z) <= size.x / 2.0 + 0.1
	q.kit.need(problems, inside and _k.hits_since(0, hurt_own).x == 0.0 and own_unit.hit_points == own_unit.stats.max_hit_points, "the Turret's Shot at the other Player's Unit that missed: ended inside its own Player's Truck %s (%s), the Truck lost %.0f hit points" % [inside, seen.get("end", Vector3.INF), own_unit.stats.max_hit_points - own_unit.hit_points])
	notes.append("a Turret's Shot that missed the other Player's Unit ended on its own Player's Truck beyond it, which lost nothing")
	# its own Turret
	await _k.restore_all()
	await _k.stage(1, Quick.MOTORBIKE, Vector3(left.global_position.x, 0.0, 0.0), -forward)
	var before: int = _k.firing.size()
	var shot_seen: Dictionary = await _overshoot(left, 1)
	q.kit.need(problems, not shot_seen.is_empty() and _from_axis(shot_seen["end"], right) <= Kit13.RADIUS + 0.1 and is_equal_approx(right.hit_points, right.stats.max_hit_points) and is_equal_approx(left.hit_points, left.stats.max_hit_points), "the Turret's Shot at the Unit between the two Turrets that missed: ended %s from the other Turret's axis, %.0f and %.0f hit points" % [(" %.2f m" % _from_axis(shot_seen["end"], right)) if not shot_seen.is_empty() else "never", left.hit_points, right.hit_points])
	notes.append("a Turret's Shot that missed ended on its own Player's other Turret, which lost nothing (%d Shots)" % (_k.firing.size() - before))
	# its own Flag Wall
	await _k.restore_all()
	left.destroy()
	var gate_wall: Structure = _k.w.wall(0, Walls.GATE)
	await _k.stage(1, Quick.MOTORBIKE, _k.w.point(0, INSIDE_GATE), _k.w.way(0, Vector3.BACK))
	var flag_seen: Dictionary = await _overshoot(right, 1)
	var face_z: float = Walls.SEAT.z - Walls.FACE
	var local_end: Vector3 = _k.w.bases[0].to_local(flag_seen["end"]) if not flag_seen.is_empty() else Vector3.INF
	q.kit.need(problems, not flag_seen.is_empty() and absf(local_end.z - face_z) <= 0.1 and absf(local_end.x) <= Walls.FACE and is_equal_approx(gate_wall.hit_points, Walls.HIT_POINTS), "the Turret's Shot at the Unit just inside the Gate that missed: ended at Base-local %s, the Gate-side Flag Wall has %.0f hit points" % [local_end, gate_wall.hit_points])
	notes.append("a Turret's Shot at the Unit just inside the Gate that missed ended on the Gate-side Flag Wall at Base-local x %.2f, which kept its %.0f hit points" % [local_end.x, gate_wall.hit_points])
	await _k.restore_all()
	q.kit.verdict("friendly", problems, "; ".join(notes))


## Lets the Turret fire its first Shot at the Player's Unit, benches that Unit at once (the Unit
## has left the line, so the Shot misses) and waits for the Shot to end. The record of that Shot, or
## {} when it never fired or never ended. A coroutine: await it.
func _overshoot(who: Turret, victim: int) -> Dictionary:
	var q: Quick = _k.w.s.q
	var mark: int = _k.firing.size()
	var unit: Unit = q.units.units[victim]
	var bench: Callable = func(_shot: Shot) -> void: unit.leave_play()
	who.fired.connect(bench, CONNECT_ONE_SHOT)
	for _tick: int in 2 * WATCH:
		if _k.fired_since(who, mark) > 0:
			break
		await q.kit.tick()
	if who.fired.is_connected(bench):
		who.fired.disconnect(bench)
	var record: Dictionary = _first_since(who, mark)
	return await _await_end(record, Kit13.IN_FLIGHT_TICKS)


## fall (AC-4): see the class doc.
func _fall() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var notes: PackedStringArray = []
	var right: Turret = _k.turret(0, Kit13.RIGHT)
	var left: Turret = _k.turret(0, Kit13.LEFT)
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD)
	# at 0 it stops on that tick: no turn
	await _k.restore_all()
	left.destroy()
	var bearing: Vector3 = forward.rotated(Vector3.UP, deg_to_rad(TURNING_DEGREES))
	await _k.stage(1, Quick.TRUCK, right.global_position + bearing * AHEAD, -bearing)
	for _tick: int in WATCH:
		if absf(right.head.rotation.y) >= MID_TURN:
			break
		await q.kit.tick()
	var yaw: float = right.head.rotation.y
	var shots: int = _k.fired_since(right, 0)
	q.kit.need(problems, absf(yaw) >= MID_TURN and right.state == Turret.State.AIMING, "the Turret was not turning when it was brought down (yaw %.3f, %s)" % [yaw, Turret.State.keys()[right.state]])
	right.destroy()
	await q.kit.advance(WATCH)
	q.kit.need(problems, right.head.rotation.y == yaw and _k.fired_since(right, 0) == shots and right.state == Turret.State.DESTROYED and right.aim_point == Vector3.INF and right.aim_error == INF, "brought down mid-turn: yaw %.4f then %.4f, %d more Shots, aim %s error %s" % [yaw, right.head.rotation.y, _k.fired_since(right, 0) - shots, right.aim_point, right.aim_error])
	notes.append("brought down mid-turn at yaw %.2f it turned no further and fired nothing in %d ticks" % [yaw, WATCH])
	# a Shot in flight still lands
	await _k.restore_all()
	left.destroy()
	var truck: Unit = q.units.units[1]
	var mark: int = _k.firing.size()
	var fall_frames: Array[int] = []
	var down: Callable = func(_shot: Shot) -> void:
		fall_frames.append(Engine.get_physics_frames())
		right.destroy()
	right.fired.connect(down, CONNECT_ONE_SHOT)
	await _k.stage(1, Quick.TRUCK, _k.ahead(right, 0, FAR_AHEAD), -forward)
	var hurt: int = _k.hp_mark()
	await q.kit.advance(2 * WATCH)
	var hits: Vector2 = _k.hits_since(1, hurt)
	var landing: int = _k.hp_frames[1][-1] if not _k.hp_frames[1].is_empty() else -1
	var fall_frame: int = fall_frames[0] if not fall_frames.is_empty() else -1
	q.kit.need(problems, fall_frame >= 0 and not right.is_standing and _k.fired_since(right, mark) == 1 and hits.x == 1.0 and landing > fall_frame, "the Turret brought down in the tick it fired: %d Shots, %d hits on the Truck, landing frame %d, fall frame %d" % [_k.fired_since(right, mark), int(hits.x), landing, fall_frame])
	notes.append("brought down in the tick it fired, its Shot still landed %d ticks later (%.0f hit points off the Truck) and it fired no other" % [landing - fall_frame, truck.stats.max_hit_points - truck.hit_points])
	if right.fired.is_connected(down):
		right.fired.disconnect(down)
	# the rubble stops no Unit and no Shot
	await _k.restore_all()
	left.destroy()
	right.destroy()
	await q.kit.advance(Kit13.SETTLE)
	var stats: UnitStats = q.units.stats(Quick.TRUCK)
	var side: Vector3 = _k.w.way(0, Vector3.RIGHT)
	await _k.stage(1, Quick.TRUCK, right.global_position - side * DRIVE_OUT, side)
	q.harness.drive(1, 1, 0)
	var pass_speed: float = 0.0
	var contacts: int = 0
	for _tick: int in REST_LIMIT_TICKS:
		await q.kit.tick()
		contacts += 1 if q.map.wall_contact(q.units.units[1]) else 0
		if _from_axis(q.units.units[1].global_position, right) <= 0.5:
			pass_speed = maxf(pass_speed, q.units.units[1].get_real_velocity().length())
		if (q.units.units[1].global_position - right.global_position).dot(side) > PAST_AXIS + stats.collision_size.z / 2.0:
			break
	q.harness.drive(1, 0, 0)
	var beyond: float = (q.units.units[1].global_position - right.global_position).dot(side)
	q.kit.need(problems, contacts == 0 and pass_speed >= THROUGH_SHARE * stats.max_speed and beyond > PAST_AXIS, "a Truck driven through the fallen Turret: %d wall contacts, %.1f m/s through the axis (of %.1f), %.1f m past it" % [contacts, pass_speed, stats.max_speed, beyond])
	notes.append("a Truck drove through the rubble's place at %.1f m/s of %.1f without touching a wall" % [pass_speed, stats.max_speed])
	await _k.stage(1, Quick.TRUCK, right.global_position - side * AHEAD, side)
	await q.kit.advance(_k.w.longest_cadence())
	var shot_mark: int = q.units.shots.size()
	await q.units.hold_fire(1, 1)
	await q.kit.advance(Kit13.IN_FLIGHT_TICKS)
	var end: Vector3 = q.units.shot_ends[shot_mark] if q.units.shot_ends.size() > shot_mark else Vector3.INF
	var past: float = (end - right.global_position).dot(side)
	q.kit.need(problems, end != Vector3.INF and past > PAST_AXIS, "a Shot fired through the fallen Turret's place ended %.2f m past its axis, not beyond %.1f" % [past, PAST_AXIS])
	notes.append("a Truck's Shot flew through the place and ended %.1f m past its axis" % past)
	# stays down; no key builds, repairs or takes over
	var keys: PackedStringArray = []
	await q.kit.advance(Kit13.SETTLE)
	for player: int in Kit.PLAYERS:
		q.harness.drive(player, 1, 1)
	await q.kit.advance(WATCH)
	for player: int in Kit.PLAYERS:
		q.harness.drive(player, -1, -1)
	await q.kit.advance(WATCH)
	q.harness.release_all()
	q.kit.need(problems, not right.is_standing and right.hit_points == 0.0 and right.collision_layer == 0 and right.get_node("Rubble").visible, "the fallen Turret came back during the Round: standing %s, %.0f hit points" % [right.is_standing, right.hit_points])
	keys.append("a fallen Turret stayed down under every drive key of both layouts held for %d ticks" % (2 * WATCH))
	await _k.restore_all()
	right.apply_damage(60.0)
	await _k.stage(0, Quick.MOTORBIKE, _k.ahead(right, 0, 4.0), forward)
	for player: int in Kit.PLAYERS:
		q.harness.drive(player, 1, -1)
	await q.kit.advance(WATCH)
	q.harness.release_all()
	q.kit.need(problems, right.is_standing and is_equal_approx(right.hit_points, 40.0), "a damaged Turret changed under the drive keys: %.1f hit points" % right.hit_points)
	keys.append("a damaged one kept its 40 hit points beside its own Player's Unit under the same keys")
	notes.append("; ".join(keys))
	await _layer_timing(problems, notes)
	await _k.restore_all()
	q.kit.verdict("fall", problems, "; ".join(notes))


## The tick a Turret's layer change acts in (the story's Measure first, as story 012 measured the Flag
## Walls'): a ray on the Shots' mask across its drum is blocked while it stands, clear right after
## destroy() in the same tick and a tick later, blocked at once after restore(); and a Truck pressed
## against it with the throttle held moves in the first tick after it fell.
func _layer_timing(problems: PackedStringArray, notes: PackedStringArray) -> void:
	var q: Quick = _k.w.s.q
	var right: Turret = _k.turret(0, Kit13.RIGHT)
	var forward: Vector3 = _k.w.way(0, Vector3.FORWARD)
	var height: Vector3 = Vector3.UP * q.controller.rules.shooting_height
	await _k.restore_all()
	var from: Vector3 = right.global_position + forward * 3.0 + height
	var to: Vector3 = right.global_position - forward * 3.0 + height
	var standing: bool = _k.w.blocked(from, to)
	right.destroy()
	var same: bool = _k.w.blocked(from, to)
	await q.kit.tick()
	var later: bool = _k.w.blocked(from, to)
	right.restore()
	var restored: bool = _k.w.blocked(from, to)
	q.kit.need(problems, standing and not same and not later and restored, "the layer change: blocked while standing %s, right after destroy() %s, a tick later %s, right after restore() %s" % [standing, same, later, restored])
	await _k.restore_all()
	var stats: UnitStats = q.units.stats(Quick.TRUCK)
	await _k.stage(1, Quick.TRUCK, right.global_position + forward * (Kit13.RADIUS + stats.collision_size.z / 2.0 + PRESSED_OUT), -forward)
	q.harness.drive(1, 1, 0)
	var rest: int = 0
	for _tick: int in REST_LIMIT_TICKS:
		await q.kit.tick()
		rest = rest + 1 if q.units.units[1].get_real_velocity().length() < Quick.STOP_SPEED and q.map.wall_contact(q.units.units[1]) else 0
		if rest >= 6:
			break
	var at: Vector3 = q.units.units[1].global_position
	right.destroy()
	await q.kit.tick()
	var moved: float = Vector2(q.units.units[1].global_position.x - at.x, q.units.units[1].global_position.z - at.z).length()
	q.harness.drive(1, 0, 0)
	q.kit.need(problems, rest >= 6 and moved > 0.0, "a Truck pressed against the Turret with the throttle held: at rest %s, moved %.3f m in the first tick after it fell" % [rest >= 6, moved])
	measured.append("layer=ray:%s/%s/%s/%s,moved:%.3f" % [standing, same, later, restored, moved])
	notes.append("the layer change acts in the same tick: a ray across the drum was blocked while it stood, clear right after destroy() and a tick later, blocked at once after restore(); a Truck pressed against it with the throttle held moved %.3f m in the first tick after it fell" % moved)
