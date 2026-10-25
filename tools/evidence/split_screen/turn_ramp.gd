extends RefCounted
## Scenario turn_ramp of the split screen evidence harness (split_screen_harness.gd): Story 056, a turn on the spot picks up
## speed. Player 1's Buggy stands on Map 01 and turns on the spot with the A key. CHECK lines:
##  R1 the ramp: on the first tick of the press it turns at spot_turn_start_share of spot_turn_rate; the rate rises evenly and
##     reaches the whole of it after spot_turn_ramp_seconds; it stays there.
##  R2 a fresh start: released and pressed again, it starts slow again; a turn the other way starts slow too.
##  R3 a rolling Unit: at speed the turn has no ramp (its rate is the rolling rate on the first tick of the steer).
## Implements: production/epics/wasteland-fire/story-056-turn-ramp.md AC-1 to AC-3. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=turn_ramp

const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

const OWN_CHOICE: bool = true
const TURN_RAMP: bool = true
const FULL_THROTTLE: bool = true
const BUGGY: int = 1
const SETTLE: int = 30
const HOLD_TICKS: int = 45
const ROLL_TICKS: int = 60
const RATE_TOLERANCE: float = 0.02

var _h: Harness
var _kit: Kit
var _unit: Unit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_h.split.match_controller.choose(0, BUGGY)
	await _kit.advance(SETTLE)
	_unit = _h.split.all_units()[0]
	var stats: UnitStats = _unit.stats
	var rates: PackedFloat64Array = await _hold(1, HOLD_TICKS)
	var problems: PackedStringArray = PackedStringArray()
	var start: float = stats.spot_turn_rate * stats.spot_turn_start_share
	var ramp_ticks: int = int(round(stats.spot_turn_ramp_seconds * Engine.physics_ticks_per_second))
	_kit.need(problems, stats.spot_turn_ramp_seconds > 0.0 and stats.spot_turn_start_share > 0.0 and stats.spot_turn_start_share < 1.0, "no ramp in the data")
	_kit.need(problems, absf(rates[0] - start) < RATE_TOLERANCE, "the first tick turned at %.3f rad/s, the start %.3f" % [rates[0], start])
	var rising: bool = true
	for i: int in range(1, ramp_ticks):
		rising = rising and rates[i] > rates[i - 1]
	_kit.need(problems, rising, "the rate did not rise on every tick of the ramp")
	_kit.need(problems, absf(rates[ramp_ticks + 2] - stats.spot_turn_rate) < RATE_TOLERANCE and absf(rates[HOLD_TICKS - 1] - stats.spot_turn_rate) < RATE_TOLERANCE, "after the ramp %.3f and at the end %.3f, the spot rate %.3f" % [rates[ramp_ticks + 2], rates[HOLD_TICKS - 1], stats.spot_turn_rate])
	_kit.verdict("R1_ramp", problems, "rad/s on ticks 1, %d, %d, %d: %.3f, %.3f, %.3f, %.3f (start %.3f = %.2f of %.3f, %.2f s)" % [
		ramp_ticks / 2, ramp_ticks + 2, HOLD_TICKS, rates[0], rates[ramp_ticks / 2 - 1], rates[ramp_ticks + 2], rates[HOLD_TICKS - 1], start, stats.spot_turn_start_share, stats.spot_turn_rate, stats.spot_turn_ramp_seconds])
	problems = PackedStringArray()
	await _kit.advance(5)
	var again: PackedFloat64Array = await _hold(1, 3)
	var other: PackedFloat64Array = await _hold(-1, 3)
	_kit.need(problems, absf(again[0] - start) < RATE_TOLERANCE, "pressed again: %.3f" % again[0])
	_kit.need(problems, absf(absf(other[0]) - start) < RATE_TOLERANCE, "the other way: %.3f" % other[0])
	_kit.verdict("R2_fresh_start", problems, "pressed again %.3f, the other way %.3f rad/s on the first tick (start %.3f)" % [again[0], other[0], start])
	problems = PackedStringArray()
	_h.drive(0, 1, 0)
	await _kit.advance(ROLL_TICKS)
	var speed: float = absf(_unit.current_speed)
	var heading: float = _unit.global_rotation.y
	_h.drive(0, 1, 1)
	await _kit.advance(1)
	await _kit.advance(1)
	var rolled: float = angle_difference(heading, _unit.global_rotation.y) * Engine.physics_ticks_per_second / 2.0
	_h.drive(0, 0, 0)
	var expected: float = stats.turn_rate * minf(speed / stats.max_speed, 1.0)
	_kit.need(problems, expected > stats.spot_turn_rate and absf(rolled - expected) < 0.1 * expected, "rolling at %.1f m/s it turned at %.3f rad/s, the rolling rate %.3f" % [speed, rolled, expected])
	_kit.verdict("R3_rolling_no_ramp", problems, "at %.1f m/s the first two ticks of a steer turned at %.3f rad/s (the rolling rate %.3f)" % [speed, rolled, expected])
	_h.finish("ramp=%.2f" % stats.spot_turn_ramp_seconds)


## Holds steer left (1) or right (-1) on the standing Unit for the ticks and returns the yaw rate of each tick, rad/s.
func _hold(steer: int, ticks: int) -> PackedFloat64Array:
	var rates: PackedFloat64Array = PackedFloat64Array()
	var last: float = _unit.global_rotation.y
	_h.drive(0, 0, steer)
	for _i: int in ticks:
		await _kit.tick()
		var now: float = _unit.global_rotation.y
		rates.append(angle_difference(last, now) * Engine.physics_ticks_per_second)
		last = now
	_h.drive(0, 0, 0)
	return rates
