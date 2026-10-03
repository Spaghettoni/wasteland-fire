extends RefCounted
## Scenario weapons of the split screen evidence harness (split_screen_harness.gd): the weapons and
## the damage matrix of Story 005, every shot a real press of a fire key (Space), judged from the
## Shots the tree gains and the Units' hit points. Three CHECK lines, every number measured:
## weapon_fire (AC-3: a Buggy 12 m from a Truck with the trigger held 3 s fires the data's count of
## shots at the data's spacing, the first seen on the muzzle's line at the shooting height, each hit
## taking damage times multiplier off the Truck, the shooter unhurt; a Truck beyond the range is
## untouched by a shot that ends at its range; a shot at a wall ends on the wall's face), matrix
## (AC-4: all sixteen ordered type pairs through one real shot each at 10 m, the damage the
## attacker's damage times the table of the design held below, then all sixteen at 1.0 after the
## shooter's Weapon is given a duplicate of the rules whose matrix has no entries and default 1.0,
## then restored) and carrier_fires (AC-7: a Motorbike that picked up a Flag fires and hurts
## with it on its tail; a Buggy, a Truck and a Gyrocopter standing on a Flag never pick it up).
## The Units are put down as types with Unit.spawn(at, stats); a single shot waits out the longest
## fire interval of the data first (the Weapon's next-fire frame is absolute and keeps the interval
## of the type that last fired). The shipped data, no legacy override. Tooling only; the shared
## helpers are check_kit.gd, unit_kit.gd and flag_kit.gd (the drive at the Flag).
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3, AC-4
## and AC-7; design/rules.md "Units"; design/game-brief.md MVP feature 5.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=weapons

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the shot and hit record, the typed spawn, the fire key.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 004 helpers (flag_kit.gd): the drive at a Flag and the pick-up record.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")

## The Player who shoots in every check: Player 1, whose fire key is Space.
const SHOOTER: int = Harness.PLAYER_1
## The Player shot at in every check: Player 2.
const TARGET: int = Harness.PLAYER_2
## The Motorbike's index into the data.
const MOTORBIKE: int = 0
## The Buggy's index into the data.
const BUGGY: int = 1
## The Truck's index into the data.
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## The target type of a shot with nothing to aim at: it flies on to the wall or the end of its
## range.
const NO_TARGET: int = -1
## Where the Buggy stands in the burst, along x at z = 0: a lane clear of both Base zones
## (|z| >= 14) and, within |x| <= 24, of the cliff and water stand-ins (|x| >= 26).
const BURST_SHOOTER: Vector3 = Vector3(-6.0, 0.0, 0.0)
## Where the Truck stands in the burst: 12 m from the Buggy, facing it.
const BURST_TARGET: Vector3 = Vector3(6.0, 0.0, 0.0)
## Seconds the Buggy's trigger is held in the burst.
const BURST_SECONDS: float = 3.0
## Where the Buggy stands for the out-of-range shot: 44 m from the target, 9 m more than its range.
const FAR_SHOOTER: Vector3 = Vector3(-24.0, 0.0, 0.0)
## Where the target stands for the out-of-range shot.
const FAR_TARGET: Vector3 = Vector3(20.0, 0.0, 0.0)
## The Buggy 6 m from the west wall's inner face, facing it, on a lane clear of the cliff.
const WALL_SHOOTER: Vector3 = Vector3(-34.0, 0.0, 12.0)
## The west wall's inner face, x.
const WALL_X: float = -40.0
## A shot's seen or final place may be off its line, the wall or its range by this, metres.
const PLACE_TOLERANCE: float = 0.1
## Where the shooter stands for the matrix pairs and the carrier's exchange: 10 m from the target,
## facing it.
const PAIR_SHOOTER: Vector3 = Vector3(-5.0, 0.0, 0.0)
## Where the target stands for the matrix pairs and the carrier's exchange.
const PAIR_TARGET: Vector3 = Vector3(5.0, 0.0, 0.0)
## The design's matrix (design/rules.md, the triangle) keyed attacker>target; every other pair,
## the own-type pairs and the Motorbike's row and column read DEFAULT_MULTIPLIER.
const MULTIPLIERS: Dictionary[StringName, float] = {&"buggy>truck": 1.5, &"buggy>gyrocopter": 0.5,
	&"truck>buggy": 0.5, &"truck>gyrocopter": 1.5, &"gyrocopter>buggy": 1.5, &"gyrocopter>truck": 0.5}
## The multiplier of every pair the matrix does not name.
const DEFAULT_MULTIPLIER: float = 1.0
## Toward Base 1 (+Z): the side the Motorbike approaches Flag 2 from.
const TO_BASE_1: Vector3 = Vector3(0.0, 0.0, 1.0)
## Where the Motorbike is put as a type before it drives at Flag 2, clear of Base 2's zone.
const STEAL_START: Vector3 = Vector3(0.0, 0.0, -8.0)
## Ticks a non-carrier stands on a Flag.
const HOLD_TICKS: int = 30
## Ticks the physics server may take to report the touch after the Unit was put down.
const TOUCH_SLACK_TICKS: int = 4

var _harness: Harness
var _kit: Kit
var _units: Units
## What the target lost to the last single shot (-1.0 when nothing), set by _single_shot().
var _taken: float = -1.0


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_kit.on_tick = _units.note_tick
	await _kit.advance(Kit.START_TICKS)
	await _check_weapon_fire()
	await _check_matrix()
	await _check_carrier_fires()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("shots=%d hits=%d destroyed=%d" % [_units.shots.size(), _units.hp_changes.size(), _units.destroyed.size()])


## AC-3: the burst, the shot out of range and the shot at the wall.
func _check_weapon_fire() -> void:
	_harness.phase = &"weapon_fire"
	var problems: PackedStringArray = []
	var burst: String = await _check_burst(problems)
	var out_of_range: String = await _check_out_of_range(problems)
	var at_wall: String = await _check_wall(problems)
	_kit.verdict("weapon_fire", problems, burst + " | " + out_of_range + " | " + at_wall)


## The burst: a Buggy 12 m from a Truck holds the trigger. The shots are as many as the cadence
## allows, evenly spaced, each hit takes damage x multiplier, the first shot starts on the muzzle's
## line and the shooter is unhurt. Adds to the problems and returns the burst's part of the verdict.
func _check_burst(problems: PackedStringArray) -> String:
	var shooter: Unit = _units.units[SHOOTER]
	var target: Unit = _units.units[TARGET]
	_units.retype(SHOOTER, BUGGY, BURST_SHOOTER, Vector3.RIGHT)
	_units.retype(TARGET, TRUCK, BURST_TARGET, Vector3.LEFT)
	await _kit.advance(Units.SETTLE_TICKS)
	var stats: UnitStats = shooter.stats
	var interval: int = maxi(roundi(stats.fire_interval_seconds * float(Engine.physics_ticks_per_second)), 1)
	var hold: int = _harness.ticks_in(BURST_SECONDS)
	var expected_shots: int = ceili(float(hold) / float(interval))
	var expected_damage: float = stats.damage * float(MULTIPLIERS.get(_pair(shooter, target), DEFAULT_MULTIPLIER))
	var shooter_hp: float = shooter.hit_points
	var target_hp: float = target.hit_points
	var first_shot: int = _units.shots.size()
	var first_change: int = _units.hp_changes.size()
	var muzzle: Vector3 = _muzzle(shooter, Vector3.RIGHT)
	await _units.hold_fire(SHOOTER, hold)
	await _kit.advance(Units.HIT_LIMIT_TICKS)
	var ticks: Array[int] = _units.shot_ticks.slice(first_shot)
	var spaced: bool = _evenly_spaced(ticks, expected_shots, interval)
	var hits: PackedFloat64Array = _hits_on_target(first_change, target_hp)
	var hit_right: bool = hits.size() == expected_shots
	for hit: float in hits:
		hit_right = hit_right and is_equal_approx(hit, expected_damage)
	var seen: Vector3 = _units.shot_firsts[first_shot] if first_shot < _units.shot_firsts.size() else Vector3.INF
	var along: float = (seen - muzzle).dot(Vector3.RIGHT)
	var off_line: float = (seen - muzzle - Vector3.RIGHT * along).length()
	var step: float = stats.shot_speed / float(Engine.physics_ticks_per_second)
	var on_line: bool = seen != Vector3.INF and off_line <= PLACE_TOLERANCE and along >= -PLACE_TOLERANCE and along <= 2.0 * step + PLACE_TOLERANCE
	_kit.need(problems, spaced, "%d shots at ticks %s, expected %d every %d ticks" % [ticks.size(), ticks, expected_shots, interval])
	_kit.need(problems, hit_right, "hits %s, expected %d of %.1f" % [hits, expected_shots, expected_damage])
	_kit.need(problems, on_line, "the first shot was seen %.3f m off the muzzle's line, %.2f m along it" % [off_line, along])
	_kit.need(problems, is_equal_approx(shooter.hit_points, shooter_hp) and target.is_alive, "the shooter was hurt, or the target destroyed")
	return ("buggy 12 m from a truck, trigger held %.1f s (%d ticks): %d shots (expected ceil(%d / %d) = %d) at ticks %s, "
		+ "spacing %d ticks = round(%.2f s x %d); the first shot seen %.3f m off the muzzle's line and %.2f m along it (muzzle_forward %.1f, shooting_height "
		+ "%.2f, at most two steps of %.1f m); hits %s (each expected %.1f = damage %.1f x %.1f); truck %.1f -> %.1f hp; buggy %.1f/%.1f unhurt=%s") % [
			BURST_SECONDS, hold, ticks.size(), hold, interval, expected_shots, ticks, interval, stats.fire_interval_seconds, Engine.physics_ticks_per_second, off_line, along,
			stats.muzzle_forward, _units.controller.rules.shooting_height, step, hits, expected_damage, stats.damage, expected_damage / stats.damage,
			target_hp, target.hit_points, shooter.hit_points, shooter_hp, is_equal_approx(shooter.hit_points, shooter_hp)]


## True when there are exactly `count` shots and each follows the one before by `interval` ticks.
func _evenly_spaced(ticks: Array[int], count: int, interval: int) -> bool:
	var spaced: bool = ticks.size() == count
	for index: int in range(1, ticks.size()):
		spaced = spaced and ticks[index] - ticks[index - 1] == interval
	return spaced


## The hit points the target lost at each of its hit_points_changed since index `first_change`, in
## order.
func _hits_on_target(first_change: int, from_hp: float) -> PackedFloat64Array:
	var hits: PackedFloat64Array = []
	var last_hp: float = from_hp
	for index: int in range(first_change, _units.hp_changes.size()):
		if _units.hp_changes[index].x == TARGET:
			hits.append(last_hp - _units.hp_values[index])
			last_hp = _units.hp_values[index]
	return hits


## The shot out of range: a fresh Truck 44 m away is not hit and the shot ends at the Buggy's range.
## Adds to the problems and returns this part of the verdict.
func _check_out_of_range(problems: PackedStringArray) -> String:
	var shooter: Unit = _units.units[SHOOTER]
	var target: Unit = _units.units[TARGET]
	var stats: UnitStats = shooter.stats
	var far_end: Vector3 = await _single_shot(BUGGY, FAR_SHOOTER, Vector3.RIGHT, TRUCK, FAR_TARGET)
	var far_taken: float = _taken
	var far_flown: float = far_end.distance_to(_muzzle(shooter, Vector3.RIGHT)) if far_end != Vector3.INF else -1.0
	var apart: float = shooter.global_position.distance_to(target.global_position)
	_kit.need(problems, far_taken < 0.0 and apart > stats.weapon_range and absf(far_flown - stats.weapon_range) <= PLACE_TOLERANCE,
		"out of range: the truck lost %.1f (-1 is none), the shot flew %.2f m" % [far_taken, far_flown])
	return ("out of range: a fresh truck %.1f m away (range %.1f): one shot flew %.2f m to (%.2f, %.2f) and ended, the truck lost %.1f (-1 is none; hp %.1f)") % [
		apart, stats.weapon_range, far_flown, far_end.x, far_end.z, far_taken, target.hit_points]


## The shot at the west wall: it ends on the wall's inner face, well short of its range. Adds to the
## problems and returns this part of the verdict.
func _check_wall(problems: PackedStringArray) -> String:
	var shooter: Unit = _units.units[SHOOTER]
	var stats: UnitStats = shooter.stats
	var wall_end: Vector3 = await _single_shot(BUGGY, WALL_SHOOTER, Vector3.LEFT, NO_TARGET, Vector3.ZERO)
	var wall_flown: float = wall_end.distance_to(_muzzle(shooter, Vector3.LEFT)) if wall_end != Vector3.INF else -1.0
	_kit.need(problems, absf(wall_end.x - WALL_X) <= PLACE_TOLERANCE and wall_flown < stats.weapon_range - 1.0,
		"wall: the shot ended at x=%.2f (wall %.0f) after %.2f m" % [wall_end.x, WALL_X, wall_flown])
	return ("wall: buggy at x=%.0f facing the west wall (inner face x=%.0f): one shot ended at (%.2f, %.2f, %.2f) after %.2f m of its range") % [
		WALL_SHOOTER.x, WALL_X, wall_end.x, wall_end.y, wall_end.z, wall_flown]


## AC-4: the sixteen pairs with the data's matrix, then with a flat one on the shooter's Weapon.
func _check_matrix() -> void:
	_harness.phase = &"matrix"
	var problems: PackedStringArray = []
	var weapon: Weapon = _units.weapons[SHOOTER]
	var original: MatchRules = weapon.rules
	var flat: DamageMatrix = DamageMatrix.new()
	flat.default_multiplier = DEFAULT_MULTIPLIER
	var other: MatchRules = original.duplicate_deep() as MatchRules
	other.damage_matrix = flat
	var with_table: String = await _fire_every_pair(true, problems)
	weapon.rules = other
	var with_flat: String = await _fire_every_pair(false, problems)
	weapon.rules = original
	_kit.need(problems, weapon.rules == original and flat.multipliers.is_empty(), "the shooter's rules were not restored")
	_kit.verdict("matrix", problems, ("16 ordered pairs at 10 m, one real shot each after the longest cadence of the data (%d ticks), damage taken = attacker "
		+ "damage x multiplier (the table %s, else %.1f), each cell with the x where the shot ended: %s | the shooter's Weapon given a duplicate of the rules "
		+ "whose matrix has no entries and default %.1f: %s | rules restored=%s") % [_cadence_ticks(), MULTIPLIERS, DEFAULT_MULTIPLIER, with_table,
			flat.default_multiplier, with_flat, weapon.rules == original])


## Every attacker type against every target type, one shot each; the damage taken as cells.
func _fire_every_pair(table: bool, problems: PackedStringArray) -> String:
	var cells: PackedStringArray = []
	var shooter: Unit = _units.units[SHOOTER]
	var target: Unit = _units.units[TARGET]
	for attacker: int in Units.TYPE_IDS.size():
		for defender: int in Units.TYPE_IDS.size():
			var end: Vector3 = await _single_shot(attacker, PAIR_SHOOTER, Vector3.RIGHT, defender, PAIR_TARGET)
			var multiplier: float = float(MULTIPLIERS.get(_pair(shooter, target), DEFAULT_MULTIPLIER)) if table else DEFAULT_MULTIPLIER
			var expected: float = shooter.stats.damage * multiplier
			_kit.need(problems, is_equal_approx(_taken, expected) and target.is_alive, "%s took %.1f, expected %.1f (%s), the shot ended at (%.2f, %.2f, %.2f)" % [
				_pair(shooter, target), _taken, expected, "table" if table else "flat", end.x, end.y, end.z])
			cells.append("%s=%.1f@x%.1f" % [_pair(shooter, target), _taken, end.x])
	return " ".join(cells)


## AC-7: the Motorbike picks up Flag 2 and fires with it; the other three types never pick up.
func _check_carrier_fires() -> void:
	_harness.phase = &"carrier_fires"
	var problems: PackedStringArray = []
	var flag_kit: Flags = Flags.new(_harness, _kit)
	var flag: Flag = flag_kit.flags[TARGET]
	var carrier: Unit = _units.units[SHOOTER]
	var target: Unit = _units.units[TARGET]
	_units.retype(TARGET, TRUCK, PAIR_TARGET, Vector3.LEFT)
	_units.retype(SHOOTER, MOTORBIKE, STEAL_START, -TO_BASE_1)
	await _kit.advance(Units.SETTLE_TICKS)
	flag_kit.approach(SHOOTER, flag.global_position, TO_BASE_1)
	await _kit.advance(Units.SETTLE_TICKS)
	var drove: int = await flag_kit.drive_until(SHOOTER, 1, Flags.APPROACH_SPEED, func() -> bool: return flag.carrier == carrier)
	await flag_kit.rest(SHOOTER)
	var carried: bool = drove > 0 and carrier.can_carry and flag.state == Flag.State.CARRIED
	_kit.need(problems, carried, "the Motorbike did not pick up flag 2 (drove %d ticks, can_carry=%s, flag_2=%s)" % [drove, carrier.can_carry, flag_kit.state_name(TARGET)])
	_harness.place(carrier, _units.pose(PAIR_SHOOTER, Vector3.RIGHT), _units.cameras[SHOOTER])
	await _kit.advance(_cadence_ticks())
	var expected: float = carrier.stats.damage * float(MULTIPLIERS.get(_pair(carrier, target), DEFAULT_MULTIPLIER))
	await _units.hold_fire(SHOOTER, 1)
	var taken: float = await _units.wait_hit(TARGET)
	var still: bool = flag.carrier == carrier and flag.state == Flag.State.CARRIED and flag.get_parent() == carrier
	_kit.need(problems, is_equal_approx(taken, expected) and still, "the carrier's shot took %.1f (expected %.1f), flag still carried=%s" % [taken, expected, still])
	var holds: String = await _hold_on_flag(flag_kit, problems)
	_kit.verdict("carrier_fires", problems, ("motorbike can_carry=%s drove %d ticks into flag 2 and picked it up (%s); put 10 m from a truck with it on "
		+ "its tail: one shot took %.1f (expected %.1f = damage %.1f x %.1f), flag_2 still CARRIED by it=%s | standing on flag 1 (AT_HOME on Base 1's "
		+ "seat) for %d ticks each: %s") % [carrier.can_carry, drove, flag_kit.state_name(TARGET), taken, expected, carrier.stats.damage,
			expected / carrier.stats.damage, still, HOLD_TICKS, holds])


## The Buggy, the Truck and the Gyrocopter each stand on Flag 1 for HOLD_TICKS: none picks it up
## (`can_carry` is false in their data). Adds to the problems and returns one row per type.
func _hold_on_flag(flag_kit: Flags, problems: PackedStringArray) -> String:
	var target: Unit = _units.units[TARGET]
	var holds: PackedStringArray = []
	var seat: Vector3 = flag_kit.flags[SHOOTER].global_position
	for type_index: int in [BUGGY, TRUCK, GYROCOPTER]:
		var picks: int = flag_kit.pick_ups.size()
		_units.retype(TARGET, type_index, seat, -TO_BASE_1)
		var touched: int = 0
		for _tick: int in HOLD_TICKS:
			await _kit.tick()
			touched += 1 if flag_kit.touching(SHOOTER, TARGET) else 0
		var seen: bool = touched >= HOLD_TICKS - TOUCH_SLACK_TICKS or type_index == GYROCOPTER
		var no_pick: bool = flag_kit.pick_ups.size() == picks and flag_kit.flags[SHOOTER].state == Flag.State.AT_HOME and not target.can_carry
		_kit.need(problems, seen and no_pick, "%s on flag 1: touching %d/%d ticks, pick_ups %d (before %d), can_carry=%s" % [
			target.type_id, touched, HOLD_TICKS, flag_kit.pick_ups.size(), picks, target.can_carry])
		holds.append("%s: can_carry=%s touching %d/%d ticks%s pick_ups=%d (before %d) flag_1=%s" % [target.type_id, target.can_carry, touched, HOLD_TICKS,
			" (its layer is outside the zone's mask)" if type_index == GYROCOPTER else "", flag_kit.pick_ups.size(), picks, flag_kit.state_name(SHOOTER)])
	return " | ".join(holds)


## Puts the shooter down as a type at a place facing a direction and, unless target_type is
## NO_TARGET, the target as a type at its place facing back; waits the longest cadence of the data;
## one tick of the fire key; then waits for the hit (_taken) or, with no target, for the shot to
## end. Where the shot ended (Vector3.INF when it never did). A coroutine: await it.
func _single_shot(shooter_type: int, at: Vector3, facing: Vector3, target_type: int, target_at: Vector3) -> Vector3:
	_units.retype(SHOOTER, shooter_type, at, facing)
	if target_type != NO_TARGET:
		_units.retype(TARGET, target_type, target_at, -facing)
	await _kit.advance(_cadence_ticks())
	var index: int = _units.shots.size()
	await _units.hold_fire(SHOOTER, 1)
	if target_type != NO_TARGET:
		_taken = await _units.wait_hit(TARGET)
	else:
		await _kit.advance(Units.HIT_LIMIT_TICKS)
	return _units.shot_ends[index] if index < _units.shot_ends.size() else Vector3.INF


## The longest fire interval of the data in ticks, plus the settle: what a single shot waits after
## the Units were put down, so the Weapon's cadence from its last shot has run out whatever type
## fired.
func _cadence_ticks() -> int:
	var longest: int = Units.SETTLE_TICKS
	for stats: UnitStats in _units.controller.unit_types():
		longest = maxi(longest, roundi(stats.fire_interval_seconds * float(Engine.physics_ticks_per_second)) + Units.SETTLE_TICKS)
	return longest


## Where a Unit's next shot starts: its origin, muzzle_forward along the facing, shooting_height up.
func _muzzle(unit: Unit, facing: Vector3) -> Vector3:
	return unit.global_position + facing * unit.stats.muzzle_forward + Vector3.UP * _units.controller.rules.shooting_height


## The matrix key of an attacker and a target: attacker>target by type_id.
func _pair(attacker: Unit, defender: Unit) -> StringName:
	return StringName("%s>%s" % [attacker.type_id, defender.type_id])
