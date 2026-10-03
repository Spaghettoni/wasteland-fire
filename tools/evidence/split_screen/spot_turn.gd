extends RefCounted
## Scenario spot_turn of the split screen evidence harness (split_screen_harness.gd): every Unit type
## turns on the spot, on the shipped data and Map (Story 009 AC-3). Two pairs of types, one per
## Player at a time (the Motorbike and the Buggy, then the Truck and the Gyrocopter), each staged
## standing on the open salt flat (quick_fix_kit.gd LANE_SPOT and its mirror) with real keys. Five
## CHECK lines, every rate measured from the heading after each tick: spot_data (each type's
## spot_turn_rate above zero and below its turn_rate), spot_pivot (standing, the steer-left key
## alone turns it left at spot_turn_rate and the steer-right key right at it, and it does not move),
## drive_off (from standing, the throttle and the steer-left key together: on every tick the turn is
## steer * max(turn_rate * |speed| / max_speed, spot_turn_rate), so it never drops below the spot
## rate as it rolls away and is the rate of before Story 009 once that is higher), reverse (from
## standing, the reverse and the steer-left keys: rolling backward the turn is that rate flipped,
## to the right) and stranded (a ground type out of Fuel turns at its empty_turn_rate, not its spot
## rate: the run uses a copy of the type's stats with a small tank and a spot rate that differs).
## A SPLIT line per type and phase.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=spot_turn

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
## Ticks each steer key is held standing.
const PIVOT_TICKS: int = 60
## Ticks of a drive-off and of a reverse: long enough for every type's turn to pass its spot rate
## going forward (at half its top speed, about 0.6 s), short enough to stay on the open flat.
const ROLL_TICKS: int = 50
## The first ticks of a phase left out of a rate, while the key's event reaches the Unit.
const KEY_TICKS: int = 2
## A measured rate may differ from the expected one by this much, radians per second.
const RATE_TOLERANCE: float = 0.001
## A standing Unit's centre may drift this far while it turns on the spot, metres.
const DRIFT_TOLERANCE: float = 0.001
## The share of its tank a stranded run's copy of a type spawns with: it runs dry standing, within a
## second at the idle Fuel rate.
const STRANDED_TANK: float = 0.005
## The stranded run's copy of a type turns on the spot at its spot_turn_rate times this, so a turn
## at the spot rate cannot pass for the empty turn rate (the shipped data has them equal).
const STRANDED_SPOT_SCALE: float = 1.5
## Ticks a stranded run waits standing for its tank to run dry.
const DRY_LIMIT_TICKS: int = 180

var _q: Quick
## Each Player's heading and drive speed after every tick of the phase running.
var _yaws: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var _speeds: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var _starts: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _drift: Array[float] = [0.0, 0.0]
var _problems: Dictionary[String, PackedStringArray] = {}
var _notes: Dictionary[String, PackedStringArray] = {}


## Runs the data check and the four phases for both pairs, then the CHECK lines and the RESULT line.
## The runner awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_q.kit.on_tick = _on_tick
	for check: String in ["spot_pivot", "drive_off", "reverse", "stranded"]:
		_problems[check] = PackedStringArray()
		_notes[check] = PackedStringArray()
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	_check_data()
	for pair: Array in PAIRS:
		var types: Array[int] = [int(pair[0]), int(pair[1])]
		await _pivot(types)
		await _roll(types, 1, "drive_off")
		await _roll(types, -1, "reverse")
		await _stranded(types)
	for check: String in ["spot_pivot", "drive_off", "reverse", "stranded"]:
		_q.kit.verdict(check, _problems[check], " | ".join(_notes[check]))
	_q.close()
	_q.harness.finish("types=%d %s" % [_q.controller.unit_types().size(), _q.engine_counts()])


## The check kit's hook after every tick: each Player's heading, drive speed and drift from the
## phase's start.
func _on_tick() -> void:
	for lane: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[lane]
		_yaws[lane].append(Quick.yaw(unit))
		_speeds[lane].append(unit.current_speed)
		_drift[lane] = maxf(_drift[lane], Quick.ground(unit).distance_to(Vector2(_starts[lane].x, _starts[lane].z)))


## Both Players' Units standing as the pair's types (Player 1 at LANE_SPOT facing east, Player 2 at
## its mirror facing west), the logs emptied. A coroutine.
func _stage(types: Array[int], stats: Array[UnitStats]) -> void:
	_starts = [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)]
	for lane: int in Kit.PLAYERS:
		if stats[lane] != null:
			await _q.put(lane, stats[lane], _starts[lane], Vector3.RIGHT if lane == 0 else Vector3.LEFT)
	_clear()


## Empties the logs.
func _clear() -> void:
	_yaws = [PackedFloat64Array(), PackedFloat64Array()]
	_speeds = [PackedFloat64Array(), PackedFloat64Array()]
	_drift = [0.0, 0.0]


## The spot_data part of the run: one CHECK line.
func _check_data() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for stats: UnitStats in _q.controller.unit_types():
		_q.kit.need(problems, stats.spot_turn_rate > 0.0 and stats.spot_turn_rate < stats.turn_rate,
			"%s's spot_turn_rate %.2f is not above zero and below its turn_rate %.2f" % [stats.type_id, stats.spot_turn_rate, stats.turn_rate])
		notes.append("%s spot %.2f turn %.2f empty %.2f rad/s" % [stats.type_id, stats.spot_turn_rate, stats.turn_rate, stats.empty_turn_rate])
	_q.kit.verdict("spot_data", problems, " | ".join(notes))


## The per-tick turn rates of a Player's log after its first KEY_TICKS, radians per second.
func _rates(lane: int) -> PackedFloat64Array:
	var rates: PackedFloat64Array = []
	for index: int in range(KEY_TICKS, _yaws[lane].size()):
		rates.append(Quick.turned(_yaws[lane][index - 1], _yaws[lane][index]) * _q.harness.ticks_in(1.0))
	return rates


## The spot_pivot phase: steer left, then steer right, standing. A coroutine.
func _pivot(types: Array[int]) -> void:
	await _stage(types, [_q.units.stats(types[0]), _q.units.stats(types[1])])
	for steer: int in [1, -1]:
		_clear()
		for lane: int in Kit.PLAYERS:
			_q.harness.drive(lane, 0, steer)
		await _q.kit.advance(PIVOT_TICKS)
		_q.harness.release_all()
		for lane: int in Kit.PLAYERS:
			var stats: UnitStats = _q.units.stats(types[lane])
			var worst: float = 0.0
			for rate: float in _rates(lane):
				worst = maxf(worst, absf(rate - steer * stats.spot_turn_rate))
			var label: String = "p%d %s steer %+d" % [lane + 1, stats.type_id, steer]
			_q.kit.need(_problems["spot_pivot"], worst <= RATE_TOLERANCE and _drift[lane] <= DRIFT_TOLERANCE,
				"%s turned up to %.5f rad/s off %+.2f and drifted %.5f m" % [label, worst, steer * stats.spot_turn_rate, _drift[lane]])
			_notes["spot_pivot"].append("%s at %+.4f rad/s (off by <= %.5f), drift %.5f m" % [label, steer * stats.spot_turn_rate, worst, _drift[lane]])
			print("SPLIT %s t=%.3f pivot=%s type=%s steer=%d worst=%.6f drift=%.6f" % [_q.harness.scenario, _q.harness.time(), lane + 1, stats.type_id, steer, worst, _drift[lane]])
		await _q.kit.advance(KEY_TICKS)


## A drive_off (throttle 1) or reverse (throttle -1) phase from standing with the steer-left key: on
## every tick the turn must be the rate the class doc gives for that tick's drive speed. A coroutine.
func _roll(types: Array[int], throttle: int, check: String) -> void:
	await _stage(types, [_q.units.stats(types[0]), _q.units.stats(types[1])])
	for lane: int in Kit.PLAYERS:
		_q.harness.drive(lane, throttle, 1)
	await _q.kit.advance(ROLL_TICKS)
	_q.harness.release_all()
	for lane: int in Kit.PLAYERS:
		var stats: UnitStats = _q.units.stats(types[lane])
		var rates: PackedFloat64Array = _rates(lane)
		var worst: float = 0.0
		var least: float = INF
		var crossover: int = -1
		for index: int in rates.size():
			var speed: float = _speeds[lane][index + KEY_TICKS]
			var rolling: float = stats.turn_rate * minf(absf(speed) / stats.max_speed, 1.0)
			var direction: float = -1.0 if speed < 0.0 else 1.0
			worst = maxf(worst, absf(rates[index] - direction * maxf(rolling, stats.spot_turn_rate)))
			least = minf(least, absf(rates[index]))
			if crossover < 0 and rolling >= stats.spot_turn_rate:
				crossover = index + KEY_TICKS
		var label: String = "p%d %s" % [lane + 1, stats.type_id]
		_q.kit.need(_problems[check], worst <= RATE_TOLERANCE and least >= stats.spot_turn_rate - RATE_TOLERANCE,
			"%s turned up to %.5f rad/s off the rate, least %.4f (spot %.2f)" % [label, worst, least, stats.spot_turn_rate])
		var speed_end: float = _speeds[lane][-1]
		_notes[check].append("%s to %.2f m/s, off by <= %.5f rad/s, never under %.4f (spot %.2f), turn rate above it from tick %d" % [
			label, speed_end, worst, least, stats.spot_turn_rate, crossover])
		print("SPLIT %s t=%.3f %s=%d type=%s speed_end=%.3f worst=%.6f least=%.5f crossover_tick=%d" % [
			_q.harness.scenario, _q.harness.time(), check, lane + 1, stats.type_id, speed_end, worst, least, crossover])
	await _q.kit.advance(KEY_TICKS)


## The stranded phase: each ground type of the pair as a copy with a small tank and a spot rate off
## its empty rate, standing until dry, then the steer-left key alone. A coroutine.
func _stranded(types: Array[int]) -> void:
	var copies: Array[UnitStats] = [null, null]
	for lane: int in Kit.PLAYERS:
		if not _q.units.stats(types[lane]).can_fly:
			copies[lane] = _q.small_tank(types[lane], STRANDED_TANK)
			copies[lane].spot_turn_rate *= STRANDED_SPOT_SCALE
	await _stage(types, copies)
	for _tick: int in DRY_LIMIT_TICKS:
		if _dry(copies):
			break
		await _q.kit.tick()
	_clear()
	for lane: int in Kit.PLAYERS:
		_q.harness.drive(lane, 0, 1 if copies[lane] != null else 0)
	await _q.kit.advance(PIVOT_TICKS)
	_q.harness.release_all()
	for lane: int in Kit.PLAYERS:
		if copies[lane] == null:
			continue
		var unit: Unit = _q.units.units[lane]
		var worst: float = 0.0
		for rate: float in _rates(lane):
			worst = maxf(worst, absf(rate - copies[lane].empty_turn_rate))
		var label: String = "p%d %s out of Fuel" % [lane + 1, copies[lane].type_id]
		_q.kit.need(_problems["stranded"], unit.is_stranded and worst <= RATE_TOLERANCE, "%s (stranded=%s) turned up to %.5f rad/s off its empty rate %.2f" % [
			label, unit.is_stranded, worst, copies[lane].empty_turn_rate])
		_notes["stranded"].append("%s at its empty rate %.2f (off by <= %.5f; its spot rate %.3f)" % [label, copies[lane].empty_turn_rate, worst, copies[lane].spot_turn_rate])
		print("SPLIT %s t=%.3f stranded=%d type=%s fuel=%.3f worst=%.6f" % [_q.harness.scenario, _q.harness.time(), lane + 1, copies[lane].type_id, unit.fuel, worst])
	await _q.kit.advance(KEY_TICKS)


## True when every Player given a copy stands stranded.
func _dry(copies: Array[UnitStats]) -> bool:
	for lane: int in Kit.PLAYERS:
		if copies[lane] != null and not _q.units.units[lane].is_stranded:
			return false
	return true
