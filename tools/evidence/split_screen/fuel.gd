extends RefCounted
## Scenario fuel of the split screen evidence harness (split_screen_harness.gd): Story 006's Fuel
## on the shipped data, every key a real event (W, Up, Space, Period, Tab). Two CHECK lines, each
## detail carrying the measured numbers: fuel_burn (AC-1, AC-2, AC-5: the data, the starting tank
## of every spawn, no burn standing, the burn at full throttle, coasting and pinned at a wall with
## the throttle held, the starting tank after a respawn) and fuel_empty (AC-3, AC-4, AC-8: a Truck
## run dry ignores throttle and reverse, turns on the spot, fires, drives again after refuel() and
## Self-destructs at zero Fuel; a Gyrocopter run dry crashes from its own tick, the Round respawns
## it and the Flags stay put; no ERROR or WARNING in the run, counted by a Logger). Types are given
## by Unit.spawn(at, stats) only while the Round has the Unit in play, moves are place(), and every
## spot keeps clear of the Fuel Cans, Bases and stand-ins. OWN_CHOICE. Tooling only.
## Implements: production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-1 to AC-5, AC-8;
## design/rules.md "Resources", "Destruction and respawn".
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=fuel

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the typed spawn, the signal record, the fire key, the waits.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 004 helpers (flag_kit.gd): the Flags' states and drops.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")
## The Story 006 helpers (fuel_kit.gd): the fuel_changed record, the holds, the coast.
const Fuel: GDScript = preload("res://tools/evidence/split_screen/fuel_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The Truck's index into the data.
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## The types Player 1 takes in turn at the sweep: all four, the Truck last (the burn runs on it).
const SWEEP_ORDER: Array[int] = [0, 1, 3, 2]
## Where Units stand, each 20 m or more from every Fuel Can, off the Base zones (x -6 to 6, z 14 to
## 26 and -26 to -14) and the stand-ins: sweep (34 m of lane west to the wall), hover, pin_1 (1.8 m
## off the south wall's face, z 40), pin_2 (2.8 m off the north wall's, z -40), turn (open ground,
## 10 m or more from any wall) and target (12 m east of turn).
const SPOTS: Dictionary[StringName, Vector3] = {&"sweep": Vector3(-6.0, 0.0, 32.0), &"hover": Vector3(24.0, 0.0, -30.0),
	&"pin_1": Vector3(-20.0, 0.0, 36.0), &"pin_2": Vector3(20.0, 0.0, -36.0), &"turn": Vector3(-24.0, 0.0, 30.0),
	&"target": Vector3(-12.0, 0.0, 30.0)}
## Tick counts: stand (still, 3 s), throttle (from rest), run_up (west to the wall), pin (pinned,
## throttle held), rest (after a stop: no burn may come), confirm (into a countdown before the
## choice), empty (the most a run dry may take: 1000 burning ticks at 3.0), decay (empty, throttle
## held), hold (throttle, then reverse, when empty), turn, drive (after the refuel), report (the
## runner's SPLIT lines).
const TICKS: Dictionary[StringName, int] = {&"stand": 180, &"throttle": 90, &"run_up": 150, &"pin": 120, &"rest": 30,
	&"confirm": 30, &"empty": 1200, &"decay": 150, &"hold": 30, &"turn": 60, &"drive": 60, &"report": 60}
## The Fuel refuel() gives the empty Truck: 40 burning ticks at 3.0 and a 41st clamped at zero.
const REFUEL_AMOUNT: float = 2.01
## The least the refuelled Truck covers to count as driving again, metres.
const DRIVE_AGAIN_MIN: float = 1.0
## A Unit that is not driving moves less than this in the ground plane, metres.
const STILL_TOLERANCE: float = 0.01
## Two Fuel values that ought to be equal differ by less than this (sums of 64-bit ticks).
const FUEL_EPSILON: float = 1e-9

var _harness: Harness
var _kit: Kit
var _units: Units
var _flags: Flags
var _fuel: Fuel
var _log: LogCounter
var _destroyed_signals: Array[int] = []
var _gyro_hp: float = -1.0
var _tps: float = 0.0


## Runs both checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_log = LogCounter.new()
	OS.add_logger(_log)
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_flags = Flags.new(harness, _kit)
	_fuel = Fuel.new(harness, _kit)
	_tps = float(_harness.ticks_in(1.0))
	_harness.report_ticks = TICKS[&"report"]
	for player: int in Kit.PLAYERS:
		_units.units[player].destroyed.connect(func() -> void: _destroyed_signals.append(player))
	await _harness.confirm_choices()
	await _kit.advance(Kit.START_TICKS)
	var problems: PackedStringArray = []
	var notes: PackedStringArray = [await _spawns_and_standing(problems)]
	notes.append_array([await _throttle_and_coast(problems), await _pinned(problems), await _respawn_tank(problems)])
	_kit.verdict("fuel_burn", problems, " | ".join(notes))
	problems = []
	notes = [await _run_dry(problems), await _decay(problems), await _empty_in_open_ground(problems)]
	notes.append_array([await _drive_again_and_destruct(problems), "run: errors=%d warnings=%d" % [_log.errors, _log.warnings]])
	_kit.need(problems, _log.errors + _log.warnings == 0, "the engine logged an ERROR or WARNING")
	_kit.verdict("fuel_empty", problems, " | ".join(notes))
	OS.remove_logger(_log)
	_harness.finish("p1=%s p1_fuel=%.2f p2=%s p2_fuel=%.2f errors=%d warnings=%d" % [_units.units[0].type_id,
		_fuel.fuel(0), _units.units[1].type_id, _fuel.fuel(1), _log.errors, _log.warnings])


## AC-1, AC-5, AC-2: the data; each spawn (the Round's, then Player 1 as each type of SWEEP_ORDER)
## says fuel_changed once with capacity x share; both Units then stand still and burn nothing.
func _spawns_and_standing(problems: PackedStringArray) -> String:
	_harness.phase = &"spawn_sweep"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var seen: PackedStringArray = ["data(capacity/use/share)", _data(problems), "spawns(said x Fuel/capacity) round p1=%dx%.1f p2=%dx%.1f" % [
		_fuel.counts[0], _fuel.last_said(0), _fuel.counts[1], _fuel.last_said(1)]]
	_kit.need(problems, _fuel.counts[0] == 1 and _fuel.counts[1] == 1 and _fuel.last_said(0) == _fuel.start_tank(0)
		and _fuel.last_said(1) == _fuel.start_tank(1), "round start tanks")
	for type_index: int in SWEEP_ORDER:
		var before: int = _fuel.counts[0]
		_units.retype(Harness.PLAYER_1, type_index, SPOTS[&"sweep"], Vector3.LEFT)
		var said: int = _fuel.counts[0] - before
		seen.append("%s=%dx%.2f/%.1f" % [unit.type_id, said, _fuel.last_said(0), unit.fuel_capacity])
		_kit.need(problems, said == 1 and _fuel.last_said(0) == _fuel.start_tank(0) and unit.fuel == _fuel.start_tank(0), "%s spawn tank" % unit.type_id)
		await _kit.advance(Units.SETTLE_TICKS)
	_harness.phase = &"standing"
	_units.retype(Harness.PLAYER_2, GYROCOPTER, SPOTS[&"hover"], Vector3.LEFT)
	await _kit.advance(Units.SETTLE_TICKS)
	var said_before: int = _fuel.counts[0] + _fuel.counts[1]
	var fuels: PackedFloat64Array = [_fuel.fuel(0), _fuel.fuel(1)]
	await _kit.advance(TICKS[&"stand"])
	var still: int = _fuel.counts[0] + _fuel.counts[1] - said_before
	_kit.need(problems, still == 0 and fuels[0] == _fuel.fuel(0) and fuels[1] == _fuel.fuel(1), "a standing Unit burned")
	seen.append("| standing %d ticks: %s %.4f->%.4f, %s %.4f->%.4f, said=%d" % [TICKS[&"stand"], _units.units[0].type_id, fuels[0],
		_fuel.fuel(0), _units.units[1].type_id, fuels[1], _fuel.fuel(1), still])
	return " ".join(seen)


## AC-1: each type's tank, burn and share in (0, 1], the Gyrocopter's burn the strict maximum.
func _data(problems: PackedStringArray) -> String:
	var seen: PackedStringArray = []
	var top: UnitStats = _units.stats(GYROCOPTER)
	for stats: UnitStats in _units.controller.unit_types():
		seen.append("%s=%.1f/%.1f/%.2f" % [stats.type_id, stats.fuel_capacity, stats.fuel_use, stats.spawn_fuel_fraction])
		_kit.need(problems, stats.fuel_capacity > 0.0 and stats.fuel_use > 0.0 and stats.spawn_fuel_fraction > 0.0
			and stats.spawn_fuel_fraction <= 1.0 and (stats == top or stats.fuel_use < top.fuel_use), "%s Fuel data" % stats.type_id)
	return " ".join(seen)


## AC-2: full throttle from rest burns fuel_use x time within one tick (its first tick starts at a
## standstill); let go, the Truck burns on each tick that starts moving, then on none at rest.
func _throttle_and_coast(problems: PackedStringArray) -> String:
	_harness.phase = &"throttle"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var before: float = unit.fuel
	await _fuel.hold(Harness.PLAYER_1, 1, 0, TICKS[&"throttle"])
	var burned: float = before - unit.fuel
	var expected: float = unit.stats.fuel_use * TICKS[&"throttle"] / _tps
	var coast: Vector3i = await _fuel.coast(Harness.PLAYER_1, TICKS[&"rest"])
	_kit.need(problems, absf(burned - expected) <= unit.stats.fuel_use / _tps + FUEL_EPSILON, "full throttle burn")
	_kit.need(problems, coast.x > 0 and coast.y == coast.x and coast.z == 0, "coast burn")
	return "throttle %d ticks: burned=%.4f expected=%.4f+-%.4f; let go: moving=%d burns=%d at_rest=%d" % [
		TICKS[&"throttle"], burned, expected, unit.stats.fuel_use / _tps, coast.x, coast.y, coast.z]


## AC-2's moving is the drive speed: the Truck runs west into the wall, and pinned with the throttle
## held keeps its drive speed, stays put and burns every tick; let go, it burns until it is still.
func _pinned(problems: PackedStringArray) -> String:
	_harness.phase = &"pinned"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	_harness.drive(Harness.PLAYER_1, 1, 0)
	await _kit.advance(TICKS[&"run_up"])
	var before: float = unit.fuel
	var said: int = _fuel.counts[0]
	var at: Vector3 = unit.global_position
	await _kit.advance(TICKS[&"pin"])
	var burned: float = before - unit.fuel
	var calls: int = _fuel.counts[0] - said
	var moved: float = _fuel.ground_distance(at, unit.global_position)
	var speed: float = unit.current_speed
	var coast: Vector3i = await _fuel.coast(Harness.PLAYER_1, TICKS[&"rest"])
	var expected: float = unit.stats.fuel_use * TICKS[&"pin"] / _tps
	_kit.need(problems, calls == TICKS[&"pin"] and absf(burned - expected) < FUEL_EPSILON * calls and moved < STILL_TOLERANCE
		and speed > unit.stats.blocked_speed, "pinned burn")
	_kit.need(problems, coast.x > 0 and coast.y == coast.x and coast.z == 0, "pinned let-go burn")
	return "pinned at x=%.2f %d ticks: speed=%.2f moved=%.4f burned=%.4f expected=%.4f calls=%d; let go: moving=%d burns=%d at_rest=%d" % [
		at.x, TICKS[&"pin"], speed, moved, burned, expected, calls, coast.x, coast.y, coast.z]


## AC-5: the Truck refuelled to full, then destroyed by a lethal apply_damage() (its tank and its
## last fuel_changed both say zero), comes back through the Round (Player 1's choice in the
## countdown) with the starting share, not full.
func _respawn_tank(problems: PackedStringArray) -> String:
	_harness.phase = &"respawn"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var capacity: float = unit.fuel_capacity
	var room: float = capacity - unit.fuel
	var added: float = unit.refuel(capacity)
	var full: float = unit.fuel
	unit.apply_damage(unit.hit_points)
	var dead: float = unit.fuel
	var said_dead: float = _fuel.last_said(Harness.PLAYER_1)
	var gap: int = await _choose_again(Harness.PLAYER_1, Kit.KEYS_FIRE_1)
	_kit.need(problems, is_equal_approx(added, room) and full == capacity and dead == 0.0 and said_dead == 0.0 and gap >= 0
		and unit.fuel == _fuel.start_tank(0) and _fuel.last_said(0) == unit.fuel and unit.fuel < full, "respawn tank")
	return "refuel(%.0f) added=%.4f room=%.4f -> %.1f; destroyed -> %.1f (said %.1f); back as %s %d ticks later -> %.1f (said %.1f)" % [
		capacity, added, room, full, dead, said_dead, unit.type_id, gap, unit.fuel, _fuel.last_said(0)]


## AC-4: the Truck and the Gyrocopter put in play facing their walls, both throttles held until the
## Truck is dry; the Gyrocopter crashes on the tick its tank empties and its choice brings it back.
func _run_dry(problems: PackedStringArray) -> String:
	_harness.phase = &"run_dry"
	await _kit.advance(Units.SETTLE_TICKS)
	_units.retype(Harness.PLAYER_1, TRUCK, SPOTS[&"pin_1"], Vector3.BACK)
	_units.retype(Harness.PLAYER_2, GYROCOPTER, SPOTS[&"pin_2"], Vector3.FORWARD)
	await _kit.advance(Units.SETTLE_TICKS)
	var flags: PackedStringArray = [_flags.state_name(0), _flags.state_name(1), str(_flags.drops.size())]
	var since: int = _fuel.changes.size()
	var before: Vector2i = Vector2i(_destroyed_signals.count(Harness.PLAYER_2), _units.destroyed.size())
	var emptied: int = await _hold_until_empty()
	var crash: int = _fuel.last_tick(_units.destroyed, Harness.PLAYER_2)
	var zero: int = _fuel.first_zero_tick(Harness.PLAYER_2, since)
	var gap: int = _fuel.last_tick(_units.spawns, Harness.PLAYER_2) - crash
	var delay: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	var crashes: Vector2i = Vector2i(_destroyed_signals.count(Harness.PLAYER_2), _units.destroyed.size()) - before
	var after: PackedStringArray = [_flags.state_name(0), _flags.state_name(1), str(_flags.drops.size())]
	_kit.need(problems, emptied > 0 and crashes == Vector2i(1, 1) and crash == zero
		and _gyro_hp == _units.stats(GYROCOPTER).max_hit_points, "gyrocopter crash")
	_kit.need(problems, absi(gap - delay) <= Kit.TICK_SLACK and flags == after, "after the crash")
	return "truck dry after %d ticks; gyrocopter Fuel 0 at tick %d, destroyed at tick %d (hp %.0f), destroyed=%d unit_destroyed=%d, back %d ticks later (delay %d+-%d) as %s; flags %s -> %s" % [
		emptied, zero, crash, _gyro_hp, crashes.x, crashes.y, gap, delay, Kit.TICK_SLACK, _units.units[1].type_id, "/".join(flags), "/".join(after)]


## Holds Player 1's throttle, and Player 2's while its Unit lives, until Player 1's tank is empty;
## the confirm ticks after Player 2's Unit is gone, its fire key is down one tick. The ticks, or -1.
func _hold_until_empty() -> int:
	var gyro: Unit = _units.units[Harness.PLAYER_2]
	var gone_at: int = -1
	for count: int in range(1, TICKS[&"empty"] + 1):
		gone_at = _harness.ticks if gone_at < 0 and not gyro.is_alive else gone_at
		_gyro_hp = gyro.hit_points if gone_at < 0 else _gyro_hp
		_harness.drive(Harness.PLAYER_1, 1, 0)
		_harness.drive(Harness.PLAYER_2, 1 if gone_at < 0 else 0, 0)
		_harness.set_key(_harness.fire_key(Harness.PLAYER_2), gone_at >= 0 and _harness.ticks == gone_at + TICKS[&"confirm"])
		await _kit.tick()
		if _units.units[Harness.PLAYER_1].is_fuel_empty:
			return count
	return -1


## AC-3: the empty Truck at the wall with its throttle still held: the drive speed only falls, gets
## to approximately zero, stays there, and nothing burns.
func _decay(problems: PackedStringArray) -> String:
	_harness.phase = &"decay"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var said: int = _fuel.counts[0]
	var from_speed: float = unit.current_speed
	var to_zero: int = -1
	var rose: int = 0
	for count: int in range(1, TICKS[&"decay"] + 1):
		var speed: float = unit.current_speed
		await _kit.tick()
		rose += 1 if unit.current_speed > speed else 0
		to_zero = count if to_zero < 0 and is_zero_approx(unit.current_speed) else to_zero
	_harness.release_all()
	said = _fuel.counts[0] - said
	_kit.need(problems, to_zero > 0 and rose == 0 and is_zero_approx(unit.current_speed) and said == 0 and unit.fuel == 0.0, "empty throttle")
	return "empty, throttle held: drive speed %.2f -> ~0 after %d ticks (%.1f / %.1f m/s2 = %d), rises=%d end=%.6f burns=%d" % [
		from_speed, to_zero, from_speed, unit.stats.coast_deceleration, _harness.ticks_in(from_speed / unit.stats.coast_deceleration),
		rose, unit.current_speed, said]


## AC-3 in open ground, Player 2's Unit 12 m ahead: held throttle and reverse move the empty Truck
## nowhere, its fire key sends a Shot that hits, the left steer key turns it on the spot.
func _empty_in_open_ground(problems: PackedStringArray) -> String:
	_harness.phase = &"open_ground"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	_harness.place(unit, _units.pose(SPOTS[&"turn"], Vector3.RIGHT), _units.cameras[0])
	_harness.place(_units.units[1], _units.pose(SPOTS[&"target"], Vector3.LEFT), _units.cameras[1])
	await _kit.advance(Harness.SETTLE_TICKS)
	var at: Vector3 = unit.global_position
	var peak: float = await _fuel.hold(Harness.PLAYER_1, 1, 0, TICKS[&"hold"])
	peak = maxf(peak, await _fuel.hold(Harness.PLAYER_1, -1, 0, TICKS[&"hold"]))
	var held: float = _fuel.ground_distance(at, unit.global_position)
	var shots: int = _units.shots.size()
	await _units.hold_fire(Harness.PLAYER_1, 1)
	var damage: float = await _units.wait_hit(Harness.PLAYER_2)
	shots = _units.shots.size() - shots
	at = unit.global_position
	_harness.tracks[0].begin()
	await _fuel.hold(Harness.PLAYER_1, 0, 1, TICKS[&"turn"])
	var rate: float = _harness.tracks[0].yaw_total * _tps / TICKS[&"turn"]
	var turned: float = _fuel.ground_distance(at, unit.global_position)
	var target: float = unit.stats.empty_turn_rate
	_kit.need(problems, peak == 0.0 and held < STILL_TOLERANCE and unit.is_fuel_empty, "empty Truck moved")
	_kit.need(problems, shots > 0 and damage > 0.0, "empty Truck fire")
	_kit.need(problems, absf(rate - target) <= target / TICKS[&"turn"] + FUEL_EPSILON and turned < STILL_TOLERANCE, "empty turn")
	return "open ground: throttle, reverse %d ticks each: peak speed=%.4f moved=%.4f; fire: shots=%d damage=%.1f to %s; steer left %d ticks: yaw rate=%.4f rad/s (empty_turn_rate %.4f) moved=%.4f" % [
		TICKS[&"hold"], peak, held, shots, damage, _units.units[1].type_id, TICKS[&"turn"], rate, target, turned]


## AC-3, AC-8: refuel() lets the empty Truck drive until the refill burns away; empty again, Tab
## (Self-destruct) destroys it and its choice in the countdown brings it back after the delay.
func _drive_again_and_destruct(problems: PackedStringArray) -> String:
	_harness.phase = &"drive_again"
	var unit: Unit = _units.units[Harness.PLAYER_1]
	var at: Vector3 = unit.global_position
	var added: float = unit.refuel(REFUEL_AMOUNT)
	var live: bool = not unit.is_fuel_empty
	var peak: float = await _fuel.hold(Harness.PLAYER_1, 1, 0, TICKS[&"drive"])
	await _fuel.coast(Harness.PLAYER_1, TICKS[&"rest"])
	var drove: float = _fuel.ground_distance(at, unit.global_position)
	var empty: bool = unit.is_fuel_empty and unit.fuel == 0.0
	var destroyed: int = _units.destroyed.size()
	_harness.phase = &"self_destruct"
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	var gone: bool = not unit.is_alive and _units.destroyed.size() == destroyed + 1
	var gap: int = await _choose_again(Harness.PLAYER_1, Kit.KEYS_FIRE_1)
	var delay: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	_kit.need(problems, added == REFUEL_AMOUNT and live and peak > 0.0 and drove > DRIVE_AGAIN_MIN and empty, "refuel drive")
	_kit.need(problems, gone and absi(gap - delay) <= Kit.TICK_SLACK and unit.fuel == _fuel.start_tank(0), "self-destruct at zero Fuel")
	return "refuel(%.2f) added=%.2f moving=%s: drove %.2f m (peak %.2f m/s), empty again=%s; Tab at Fuel 0: destroyed=%s, back as %s %d ticks later (delay %d+-%d), Fuel %.1f" % [
		REFUEL_AMOUNT, added, live, drove, peak, empty, gone, unit.type_id, gap, delay, Kit.TICK_SLACK, unit.fuel]


## A destroyed Player confirms its cursor's type with its own key the confirm ticks into the
## countdown: the ticks from its last unit_destroyed to its spawn, or -1 when it is not back.
func _choose_again(player: int, keys: Array[Key]) -> int:
	await _kit.advance(TICKS[&"confirm"])
	await _kit.press_settled(keys)
	var delay: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	if await _units.wait_alive(player, delay + Kit.RESPAWN_SLACK_TICKS) < 0:
		return -1
	return _fuel.last_tick(_units.spawns, player) - _fuel.last_tick(_units.destroyed, player)


## Counts the lines the engine logs as ERROR or WARNING: a logger added with OS.add_logger() (Godot
## 4.5 and later).
class LogCounter extends Logger:
	## ERROR lines (every error type but a warning) since the counter was added.
	var errors: int = 0
	## WARNING lines since the counter was added.
	var warnings: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1
