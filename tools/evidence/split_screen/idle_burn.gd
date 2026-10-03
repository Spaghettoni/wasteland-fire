extends RefCounted
## Scenario idle_burn of the split screen evidence harness (split_screen_harness.gd): Fuel burns at
## two rates, on the shipped data and Map (Story 009 AC-4). Two pairs of types, one per Player at a
## time (the Motorbike and the Buggy, then the Truck and the Gyrocopter), each staged standing on
## the open salt flat (quick_fix_kit.gd LANE_SPOT and its mirror). Four CHECK lines: burn_data (each
## type's fuel_use_idle above zero and below its fuel_use), two_rates (the Fuel after every tick of
## three phases with real keys, standing STAND_TICKS, the throttle MOVE_TICKS, then coasting to a
## stop and standing on: each tick burns fuel_use_idle / 60 when it starts with the drive speed
## zero and fuel_use / 60 when not, and emits fuel_changed once, so the gauge follows; the totals
## of the standing and the moving ticks are printed against the rates), hover_crash (a Gyrocopter
## hovering still with a small tank, a copy of its stats, burns its idle rate dry and is destroyed
## on the tick its tank empties, a destruction that costs its Player a Gyrocopter Token) and
## no_engine_noise (no ERROR or WARNING in the engine's log). A SPLIT line per type and phase.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-4. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=idle_burn

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The pairs of types, Player 1's then Player 2's, as indices into the data.
const PAIRS: Array[Array] = [[0, 1], [2, 3]]
## Ticks standing before the throttle.
const STAND_TICKS: int = 120
## Ticks of full throttle: every type stays on the open flat, the Motorbike reaching 20 m/s.
const MOVE_TICKS: int = 60
## Ticks after the throttle is released: every type coasts to a stop (the Gyrocopter's 15 m/s at
## 8 m/s/s takes under two seconds), then stands.
const COAST_TICKS: int = 150
## A tick's burn may differ from the expected one by this much, Fuel units.
const BURN_TOLERANCE: float = 0.000001
## The share of its tank the hover_crash copy of the Gyrocopter spawns with: one Fuel unit, under a
## second of hovering at its idle rate.
const HOVER_TANK: float = 0.01
## Ticks the hover_crash run waits for the crash.
const CRASH_LIMIT_TICKS: int = 120

var _q: Quick
## Each Player's Fuel and drive speed after every tick of the phase running, and its Unit's
## fuel_changed emits as (the runner's tick when emitted, the Fuel): the tick of an emit is the
## tick the Unit acted in, one ahead of the reading the check kit's hook makes after it (the
## runner's class doc: a reading after physics_frame is the previous tick's).
var _fuels: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var _speeds: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var _emits: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var _from_tick: int = 0


## Runs the data check, both pairs' phases and the hover crash, then the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_q.kit.on_tick = _on_tick
	for lane: int in Kit.PLAYERS:
		_q.units.units[lane].fuel_changed.connect(func(fuel: float, _capacity: float) -> void:
			_emits[lane].append(Vector2(_q.harness.ticks, fuel)))
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	_check_data()
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for pair: Array in PAIRS:
		notes.append(await _two_rates([int(pair[0]), int(pair[1])], problems))
	_q.kit.verdict("two_rates", problems, " | ".join(notes))
	await _hover_crash()
	var noise: PackedStringArray = []
	_q.kit.need(noise, _q.tokens.engine_log.errors.is_empty() and _q.tokens.engine_log.warnings.is_empty(), "the engine logged %s" % [_q.tokens.engine_log.errors + _q.tokens.engine_log.warnings])
	_q.kit.verdict("no_engine_noise", noise, _q.engine_counts())
	_q.close()
	_q.harness.finish("types=%d %s" % [_q.controller.unit_types().size(), _q.engine_counts()])


## The check kit's hook after every tick: each Player's Fuel and drive speed.
func _on_tick() -> void:
	for lane: int in Kit.PLAYERS:
		_fuels[lane].append(_q.units.units[lane].fuel)
		_speeds[lane].append(_q.units.units[lane].current_speed)


## Empties the logs; the first entry is the state now (the phase's start).
func _clear() -> void:
	_from_tick = _q.harness.ticks
	for lane: int in Kit.PLAYERS:
		_fuels[lane] = PackedFloat64Array([_q.units.units[lane].fuel])
		_speeds[lane] = PackedFloat64Array([_q.units.units[lane].current_speed])
		_emits[lane] = PackedVector2Array()


## The burn_data CHECK line.
func _check_data() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for stats: UnitStats in _q.controller.unit_types():
		_q.kit.need(problems, stats.fuel_use_idle > 0.0 and stats.fuel_use_idle < stats.fuel_use,
			"%s burns %.3f standing and %.3f moving" % [stats.type_id, stats.fuel_use_idle, stats.fuel_use])
		notes.append("%s %.3f standing, %.3f moving Fuel/s" % [stats.type_id, stats.fuel_use_idle, stats.fuel_use])
	_q.kit.verdict("burn_data", problems, " | ".join(notes))


## The three phases for a pair, both Players at once; judged tick by tick. The note. A coroutine.
func _two_rates(types: Array[int], problems: PackedStringArray) -> String:
	for lane: int in Kit.PLAYERS:
		var spot: Vector3 = Quick.LANE_SPOT if lane == 0 else Quick.mirrored(Quick.LANE_SPOT)
		await _q.put(lane, _q.units.stats(types[lane]), spot, Vector3.RIGHT if lane == 0 else Vector3.LEFT)
	_clear()
	await _q.kit.advance(STAND_TICKS)
	for lane: int in Kit.PLAYERS:
		_q.harness.drive(lane, 1, 0)
	await _q.kit.advance(MOVE_TICKS)
	_q.harness.release_all()
	await _q.kit.advance(COAST_TICKS)
	var notes: PackedStringArray = []
	for lane: int in Kit.PLAYERS:
		notes.append(_judge(lane, _q.units.stats(types[lane]), problems))
	return " ; ".join(notes)


## Judges one Player's log: every tick's burn against the rate its starting drive speed picks, one
## fuel_changed per burning tick; prints the SPLIT line and returns the note.
func _judge(lane: int, stats: UnitStats, problems: PackedStringArray) -> String:
	var per_second: float = float(_q.harness.ticks_in(1.0))
	var worst: float = 0.0
	var standing: Vector2 = Vector2.ZERO
	var moving: Vector2 = Vector2.ZERO
	for index: int in range(1, _fuels[lane].size()):
		var burned: float = _fuels[lane][index - 1] - _fuels[lane][index]
		var stands: bool = is_zero_approx(_speeds[lane][index - 1])
		var rate: float = stats.fuel_use_idle if stands else stats.fuel_use
		worst = maxf(worst, absf(burned - rate / per_second))
		if stands:
			standing += Vector2(burned, 1.0)
		else:
			moving += Vector2(burned, 1.0)
	var ticks: int = _fuels[lane].size() - 1
	var label: String = "p%d %s" % [lane + 1, stats.type_id]
	_q.kit.need(problems, worst <= BURN_TOLERANCE, "%s burned up to %.7f off the rate on a tick" % [label, worst])
	_q.kit.need(problems, _emits[lane].size() == ticks, "%s emitted fuel_changed %d times in %d burning ticks" % [label, _emits[lane].size(), ticks])
	_q.kit.need(problems, standing.y > 0.0 and moving.y > 0.0, "%s had %d standing and %d moving ticks" % [label, int(standing.y), int(moving.y)])
	var stand_rate: float = standing.x / standing.y * per_second if standing.y > 0.0 else 0.0
	var move_rate: float = moving.x / moving.y * per_second if moving.y > 0.0 else 0.0
	print("SPLIT %s t=%.3f burn=%d type=%s standing_ticks=%d standing_rate=%.4f moving_ticks=%d moving_rate=%.4f worst=%.8f emits=%d fuel_end=%.4f" % [
		_q.harness.scenario, _q.harness.time(), lane + 1, stats.type_id, int(standing.y), stand_rate, int(moving.y), move_rate, worst, _emits[lane].size(), _fuels[lane][-1]])
	return "%s: %d standing ticks at %.4f Fuel/s (data %.3f), %d moving at %.4f (data %.3f), every tick within %.7f, %d fuel_changed" % [
		label, int(standing.y), stand_rate, stats.fuel_use_idle, int(moving.y), move_rate, stats.fuel_use, worst, _emits[lane].size()]


## The hover_crash CHECK: Player 2's Gyrocopter as a copy with a small tank, hovering still until it
## crashes; its time counted from the tick of the spawn's fuel_changed (the starting tank, burned
## from that very tick) to the tick of the crash, both inclusive. A coroutine.
func _hover_crash() -> void:
	var problems: PackedStringArray = []
	var copy: UnitStats = _q.small_tank(Quick.GYROCOPTER, HOVER_TANK)
	_clear()
	var tokens_before: int = _q.controller.tokens_left(Harness.PLAYER_2, Quick.GYROCOPTER)
	var destroyed_before: int = _q.units.destroyed.size()
	await _q.put(Harness.PLAYER_2, copy, Quick.mirrored(Quick.LANE_SPOT), Vector3.LEFT)
	for _tick: int in CRASH_LIMIT_TICKS:
		if _q.units.destroyed.size() > destroyed_before:
			break
		await _q.kit.tick()
	var spawn_tick: int = -1
	var empty_tick: int = -1
	for emit: Vector2 in _emits[1]:
		if spawn_tick < 0 and is_equal_approx(emit.y, copy.fuel_capacity * HOVER_TANK):
			spawn_tick = int(emit.x)
		if empty_tick < 0 and spawn_tick >= 0 and emit.y == 0.0:
			empty_tick = int(emit.x)
	var crash: Vector2i = _q.units.destroyed[-1] if _q.units.destroyed.size() > destroyed_before else Vector2i(-1, -1)
	var tokens_after: int = _q.controller.tokens_left(Harness.PLAYER_2, Quick.GYROCOPTER)
	var seconds: float = float(crash.y - spawn_tick + 1) / float(_q.harness.ticks_in(1.0))
	var expected: float = copy.fuel_capacity * HOVER_TANK / copy.fuel_use_idle
	_q.kit.need(problems, crash.x == Harness.PLAYER_2 and crash.y == empty_tick, "the Gyrocopter's crash %s is not on the tick its tank emptied (%d)" % [crash, empty_tick])
	_q.kit.need(problems, absf(seconds - expected) <= 1.0 / float(_q.harness.ticks_in(1.0)), "it hovered %.3f s, not %.3f s at its idle rate" % [seconds, expected])
	_q.kit.need(problems, tokens_after == tokens_before - 1, "Player 2's Gyrocopter Tokens went %d -> %d" % [tokens_before, tokens_after])
	print("SPLIT %s t=%.3f hover_crash tank=%.2f idle=%.3f seconds=%.3f expected=%.3f empty_tick=%d crash_tick=%d tokens=%d->%d" % [
		_q.harness.scenario, _q.harness.time(), copy.fuel_capacity * HOVER_TANK, copy.fuel_use_idle, seconds, expected, empty_tick, crash.y, tokens_before, tokens_after])
	_q.kit.verdict("hover_crash", problems, "a Gyrocopter with %.2f Fuel hovering still burned %.3f Fuel/s and crashed after %.3f s (expected %.3f) on the tick its tank emptied; Gyrocopter Tokens %d -> %d" % [
		copy.fuel_capacity * HOVER_TANK, copy.fuel_use_idle, seconds, expected, tokens_before, tokens_after])
