extends RefCounted
## The half speed (Story 017 AC-2) on a flat arena far from the Map, every key a real event, one type after
## another with a full tank: a Unit at its full speed that is brought down to its edge (a tool's
## apply_damage(), as a tool may) slows to its type's share of that speed at its own acceleration, tick by tick
## as an independent model of move_toward() says, with no jolt, in about 0.6 s (the story's figures per type);
## it settles at the share forward and in reverse, in the drive speed and in the real velocity; from a standstill
## it never passes it; and what is not the top speed stays: the acceleration, the braking and the coasting (the
## largest change of the speed in one tick), the yaw rate at the halved top speed (the type's spot turn rate)
## and on the spot. Run by badly_damaged.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-2.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The story's figures per type, in the order of the data: the speed a badly damaged Unit keeps forward and in
## reverse (half of 24 and 9, 19.6 and 8, 10.9 and 5, 16.4 and 6) and the seconds it takes to slow to it from its
## full speed.
const STORY: Array[Dictionary] = [
	{"name": "motorbike", "forward": 12.0, "reverse": 4.5, "seconds": 0.60},
	{"name": "buggy", "forward": 9.8, "reverse": 4.0, "seconds": 0.58},
	{"name": "truck", "forward": 5.45, "reverse": 2.5, "seconds": 0.61},
	{"name": "gyrocopter", "forward": 8.2, "reverse": 3.0, "seconds": 0.55},
]
## Ticks a rate is held for when its largest per-tick change is read.
const RATE_TICKS: int = 40
## Ticks the yaw is read over, and the speed a rate may be off by (m/s) or the yaw rate (rad/s).
const YAW_TICKS: int = 30
const RATE_TOLERANCE: float = 0.002

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	_k.make_floor()
	await _forward_ease()
	await _reverse_ease()
	await _rates_unchanged()
	await _turn_rates()
	_k.free_floor()


## A Player 1 Unit of a type on the arena with a full tank, at its full speed (forward or in reverse) with
## the key still held, then brought to its edge: the series of its drive speed after each tick that follows.
func _slow_down(type: int, forward: bool, ticks: int) -> Dictionary:
	await _k.on_floor(0, _q.small_tank(type, 1.0))
	var unit: Unit = _k.unit(0)
	var throttle: int = 1 if forward else -1
	await _k.series(0, throttle, 0, Kit17.STEADY_TICKS)
	var full: float = unit.current_speed
	var mark: int = _k.changes.size()
	unit.apply_damage(unit.hit_points - _k.edge_of(type))
	var seen: PackedFloat64Array = await _k.series(0, throttle, 0, ticks)
	return {"full": full, "series": seen, "changes": _k.changes_of(0, mark), "real": unit.get_real_velocity().length()}


## ease_forward: the slowing is move_toward() at the acceleration, tick by tick.
func _forward_ease() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var ease_ticks: PackedStringArray = []
	for type: int in STORY.size():
		var stats: UnitStats = _q.units.stats(type)
		var kept: float = _k.share_speed(type, true)
		var needed: int = ceili((stats.max_speed - kept) / (stats.acceleration / float(Engine.physics_ticks_per_second)))
		var run: Dictionary = await _slow_down(type, true, needed + RATE_TICKS)
		var seen: PackedFloat64Array = run["series"]
		var model: PackedFloat64Array = _k.model_series(stats.max_speed, kept, stats.acceleration, seen.size())
		var name: String = STORY[type]["name"]
		_q.kit.need(problems, absf(float(run["full"]) - stats.max_speed) <= Kit17.TOLERANCE, "%s: %s at full throttle before the state, not %s" % [name, run["full"], stats.max_speed])
		_q.kit.need(problems, absf(kept - float(STORY[type]["forward"])) <= Kit17.TOLERANCE, "%s: the data give %s, the story %s" % [name, kept, STORY[type]["forward"]])
		_q.kit.need(problems, run["changes"].size() == 1 and run["changes"][0]["state"], "%s: %d changes when it was brought down" % [name, run["changes"].size()])
		var worst: float = 0.0
		var largest_drop: float = 0.0
		for index: int in seen.size():
			worst = maxf(worst, absf(seen[index] - model[index]))
			largest_drop = maxf(largest_drop, (seen[index - 1] if index > 0 else stats.max_speed) - seen[index])
		var reached: int = _k.first_at(seen, kept) + 1
		_q.kit.need(problems, worst <= RATE_TOLERANCE, "%s: the slowing leaves the model by up to %s m/s" % [name, worst])
		_q.kit.need(problems, reached == needed, "%s: slowed in %d ticks, the data say %d" % [name, reached, needed])
		_q.kit.need(problems, absf(float(reached) / 60.0 - float(STORY[type]["seconds"])) <= 0.02, "%s: %.3f s, the story says %s" % [name, float(reached) / 60.0, STORY[type]["seconds"]])
		_q.kit.need(problems, largest_drop <= stats.acceleration / 60.0 + RATE_TOLERANCE, "%s: a jolt of %s m/s in one tick" % [name, largest_drop])
		_q.kit.need(problems, absf(seen[-1] - kept) <= Kit17.TOLERANCE and absf(float(run["real"]) - kept) <= 0.01, "%s: settled at %s, really %s, not %s" % [name, seen[-1], run["real"], kept])
		notes.append("%s %s to %s m/s in %d ticks (%.2f s), largest drop %.3f" % [name, stats.max_speed, kept, reached, float(reached) / 60.0, largest_drop])
		ease_ticks.append(str(reached))
	_q.kit.verdict("ease_forward", problems, " | ".join(notes))
	measured.append("ease_ticks=" + ",".join(ease_ticks))


## ease_reverse: the same in reverse, and from a standstill the share is never passed.
func _reverse_ease() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in STORY.size():
		var stats: UnitStats = _q.units.stats(type)
		var kept: float = _k.share_speed(type, false)
		var needed: int = ceili((stats.reverse_max_speed - kept) / (stats.acceleration / float(Engine.physics_ticks_per_second)))
		var run: Dictionary = await _slow_down(type, false, needed + RATE_TICKS)
		var seen: PackedFloat64Array = run["series"]
		var model: PackedFloat64Array = _k.model_series(-stats.reverse_max_speed, -kept, stats.acceleration, seen.size())
		var name: String = STORY[type]["name"]
		var worst: float = 0.0
		for index: int in seen.size():
			worst = maxf(worst, absf(seen[index] - model[index]))
		_q.kit.need(problems, absf(float(run["full"]) + stats.reverse_max_speed) <= Kit17.TOLERANCE, "%s: %s in full reverse before the state" % [name, run["full"]])
		_q.kit.need(problems, absf(kept - float(STORY[type]["reverse"])) <= Kit17.TOLERANCE, "%s: the data give %s in reverse, the story %s" % [name, kept, STORY[type]["reverse"]])
		_q.kit.need(problems, worst <= RATE_TOLERANCE and absf(seen[-1] + kept) <= Kit17.TOLERANCE, "%s: the reverse slowing leaves the model by %s, settled at %s" % [name, worst, seen[-1]])
		_q.kit.need(problems, absf(float(run["real"]) - kept) <= 0.01, "%s: really %s m/s in reverse, not %s" % [name, run["real"], kept])
		# From a standstill, with the state on, neither direction passes the share.
		_k.unit(0).reset_motion()
		await _q.kit.advance(Kit17.SETTLE)
		var forward: PackedFloat64Array = await _k.series(0, 1, 0, Kit17.STEADY_TICKS)
		await _k.series(0, 0, 0, Kit17.STEADY_TICKS)
		var backward: PackedFloat64Array = await _k.series(0, -1, 0, Kit17.STEADY_TICKS)
		var high: float = _extreme(forward, true)
		var low: float = _extreme(backward, false)
		_q.kit.need(problems, absf(forward[-1] - _k.share_speed(type, true)) <= Kit17.TOLERANCE and high <= _k.share_speed(type, true) + Kit17.TOLERANCE, "%s: from rest forward it reached %s, not the share %s" % [name, high, _k.share_speed(type, true)])
		_q.kit.need(problems, absf(backward[-1] + kept) <= Kit17.TOLERANCE and low >= -kept - Kit17.TOLERANCE, "%s: from rest in reverse it reached %s, not the share %s" % [name, low, kept])
		notes.append("%s %s to %s m/s in reverse" % [name, -stats.reverse_max_speed, -kept])
	_q.kit.verdict("ease_reverse", problems, " | ".join(notes))


## rates_unchanged: while badly damaged, the speed builds at the acceleration, is shed at the braking while the
## throttle opposes the travel and at the coasting with none, each the largest change in one tick.
func _rates_unchanged() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in STORY.size():
		var stats: UnitStats = _q.units.stats(type)
		await _k.on_floor(0, _q.small_tank(type, 1.0))
		_k.unit(0).apply_damage(_k.unit(0).hit_points - _k.edge_of(type))
		var rising: PackedFloat64Array = await _k.series(0, 1, 0, RATE_TICKS)
		var settled: float = rising[-1]
		var braking: PackedFloat64Array = await _k.series(0, -1, 0, RATE_TICKS)
		await _k.series(0, 1, 0, Kit17.STEADY_TICKS)
		var coasting: PackedFloat64Array = await _k.series(0, 0, 0, RATE_TICKS * 2)
		var name: String = STORY[type]["name"]
		var rise: float = _largest(rising, true)
		var brake: float = _largest(braking, false)
		var coast: float = _largest(coasting, false)
		_q.kit.need(problems, absf(rise - stats.acceleration / 60.0) <= RATE_TOLERANCE, "%s: builds %s m/s a tick, the acceleration gives %s" % [name, rise, stats.acceleration / 60.0])
		_q.kit.need(problems, absf(settled - _k.share_speed(type, true)) <= Kit17.TOLERANCE, "%s: %s m/s after %d ticks of throttle" % [name, settled, RATE_TICKS])
		_q.kit.need(problems, absf(brake - stats.braking / 60.0) <= RATE_TOLERANCE, "%s: sheds %s m/s a tick against the throttle, the braking gives %s" % [name, brake, stats.braking / 60.0])
		_q.kit.need(problems, absf(coast - stats.coast_deceleration / 60.0) <= RATE_TOLERANCE, "%s: coasts %s m/s a tick, the coasting gives %s" % [name, coast, stats.coast_deceleration / 60.0])
		notes.append("%s builds %.3f, brakes %.3f, coasts %.3f m/s a tick" % [name, rise, brake, coast])
	_q.kit.verdict("rates_unchanged", problems, " | ".join(notes))


## The highest (or lowest) value of a series.
func _extreme(values: PackedFloat64Array, high: bool) -> float:
	var found: float = values[0]
	for value: float in values:
		found = maxf(found, value) if high else minf(found, value)
	return found


## The largest change of the speed in one tick of a series, upward or downward.
func _largest(values: PackedFloat64Array, upward: bool) -> float:
	var largest: float = 0.0
	for index: int in range(1, values.size()):
		largest = maxf(largest, (values[index] - values[index - 1]) * (1.0 if upward else -1.0))
	return largest


## turn_rates: at its halved top speed with the steer held, a badly damaged Unit turns at its spot turn rate
## (the story's reading: the speed-scaled turn comes to the spot rate or just under it), and on the spot at it.
func _turn_rates() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in STORY.size():
		var stats: UnitStats = _q.units.stats(type)
		await _k.on_floor(0, _q.small_tank(type, 1.0))
		_k.unit(0).apply_damage(_k.unit(0).hit_points - _k.edge_of(type))
		await _k.series(0, 1, 0, Kit17.STEADY_TICKS)
		var before: float = Quick.yaw(_k.unit(0))
		await _k.series(0, 1, 1, YAW_TICKS)
		var moving: float = absf(Quick.turned(before, Quick.yaw(_k.unit(0)))) / (float(YAW_TICKS) / 60.0)
		await _k.series(0, 0, 0, Kit17.STEADY_TICKS)
		before = Quick.yaw(_k.unit(0))
		await _k.series(0, 0, 1, YAW_TICKS)
		var standing: float = absf(Quick.turned(before, Quick.yaw(_k.unit(0)))) / (float(YAW_TICKS) / 60.0)
		var name: String = STORY[type]["name"]
		_q.kit.need(problems, absf(moving - stats.spot_turn_rate) <= 0.02, "%s: turns %.3f rad/s at the halved top speed, the spot rate is %s" % [name, moving, stats.spot_turn_rate])
		_q.kit.need(problems, absf(standing - stats.spot_turn_rate) <= 0.02, "%s: turns %.3f rad/s on the spot, the spot rate is %s" % [name, standing, stats.spot_turn_rate])
		notes.append("%s %.3f rad/s moving, %.3f standing (spot rate %s)" % [name, moving, standing, stats.spot_turn_rate])
	_q.kit.verdict("turn_rates", problems, " | ".join(notes))
