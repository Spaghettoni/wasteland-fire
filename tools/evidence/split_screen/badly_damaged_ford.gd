extends RefCounted
## In a ford the lower cap wins (Story 017 AC-3), on Map 01's west ford with every key a real event: a ground Unit
## crosses it west to east on the salt flat lane, from rest 24 m before it, whole (a control: half its top speed
## there) and badly damaged with the starting share (a half, the ford's fraction too: half its top speed, never a
## quarter), with a share of 0.4 on a copy of its stats (the share holds inside the ford) and with 0.6 (the ford's
## fraction does), and out of the ford it accelerates back only to its share; the Gyrocopter, which no ford slows,
## holds its share everywhere. The window is the one map_ford.gd reads: from 6 ticks after the Unit's centre
## crosses in to the tick it leaves. Run by badly_damaged.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-3.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## The lane's Z (map_ford.gd): inside the ford's Z range on the salt flat, clear of the cover and the cliff's foot.
const LANE_Z: float = -16.0
## Metres from rest to the ford's near edge, and from its far edge to where a run ends.
const RUN_UP: float = 24.0
const RUN_OUT: float = 25.0
## Ticks after the centre crosses in at which the window opens, and a run's longest length in ticks.
const WINDOW_OPEN: int = 6
const RUN_LIMIT_TICKS: int = 900
## The shares the copies of a type's stats take: below the ford's fraction, and above it.
const LOWER_SHARE: float = 0.4
const HIGHER_SHARE: float = 0.6
## A speed may be off by this much, m/s.
const TOLERANCE: float = 0.05

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick
var _ford_x: float = 0.0
var _half_width: float = 0.0
var _fraction: float = 0.0


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	var ford: Ford = _q.harness.split.find_child("FordWest", true, false) as Ford
	_ford_x = ford.global_position.x
	_half_width = ((ford.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.x / 2.0
	_fraction = ford.settings.speed_fraction
	await _ground_types()
	await _gyrocopter()


## A copy of a type's stats with a full tank and another share of its top speed.
func _copy(type: int, share: float) -> UnitStats:
	var copy: UnitStats = _q.small_tank(type, 1.0)
	copy.badly_damaged_speed_share = share
	return copy


## One crossing: the Unit as the stats given, badly damaged or not, from rest RUN_UP metres before the ford with the
## throttle held. Returns {inside: the speeds in the window, after: the last speed, ticks_in: the window's length}.
func _cross(stats: UnitStats, damaged: bool) -> Dictionary:
	await _k.on_floor(0, stats, 0.0)
	var unit: Unit = _k.unit(0)
	unit.global_transform = _q.units.pose(Vector3(_ford_x - _half_width - RUN_UP, 0.0, LANE_Z), Vector3.RIGHT)
	unit.reset_motion()
	_q.units.cameras[0].snap_to_target()
	await _q.kit.advance(Kit17.SETTLE)
	if damaged:
		unit.apply_damage(unit.hit_points - stats.max_hit_points * stats.badly_damaged_fraction)
	_q.harness.drive(0, 1, 0)
	var inside: PackedFloat64Array = PackedFloat64Array()
	var entered: int = -1
	var last: float = 0.0
	for tick: int in RUN_LIMIT_TICKS:
		await _q.kit.tick()
		last = unit.current_speed
		var x: float = unit.global_position.x
		if entered < 0 and x >= _ford_x - _half_width:
			entered = tick
		if entered >= 0 and tick >= entered + WINDOW_OPEN and x <= _ford_x + _half_width:
			inside.append(last)
		if x >= _ford_x + _half_width + RUN_OUT:
			break
	_q.harness.drive(0, 0, 0)
	return {"inside": inside, "after": last, "ticks_in": inside.size()}


## The least and the greatest of a series.
func _range_of(values: PackedFloat64Array) -> Vector2:
	var low: float = INF
	var high: float = -INF
	for value: float in values:
		low = minf(low, value)
		high = maxf(high, value)
	return Vector2(low, high)


## ford_lower_cap_wins: every ground type, the control and the three shares.
func _ground_types() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type)
		var top: float = stats.max_speed
		var share: float = stats.badly_damaged_speed_share
		var cases: Array[Dictionary] = [
			{"label": "whole", "stats": _copy(type, share), "damaged": false, "inside": _fraction * top, "after": top},
			{"label": "share %s" % share, "stats": _copy(type, share), "damaged": true, "inside": minf(share, _fraction) * top, "after": share * top},
			{"label": "share %s" % LOWER_SHARE, "stats": _copy(type, LOWER_SHARE), "damaged": true, "inside": minf(LOWER_SHARE, _fraction) * top, "after": LOWER_SHARE * top},
			{"label": "share %s" % HIGHER_SHARE, "stats": _copy(type, HIGHER_SHARE), "damaged": true, "inside": minf(HIGHER_SHARE, _fraction) * top, "after": HIGHER_SHARE * top},
		]
		var line: PackedStringArray = []
		for case: Dictionary in cases:
			var crossing: Dictionary = await _cross(case["stats"], case["damaged"])
			var seen: Vector2 = _range_of(crossing["inside"])
			var name: String = "%s %s" % [Units.TYPE_IDS[type], case["label"]]
			_q.kit.need(problems, crossing["ticks_in"] >= 20, "%s: only %d ticks in the window" % [name, crossing["ticks_in"]])
			_q.kit.need(problems, absf(seen.x - float(case["inside"])) <= TOLERANCE and absf(seen.y - float(case["inside"])) <= TOLERANCE, "%s: %s to %s m/s inside the ford, not %s" % [name, seen.x, seen.y, case["inside"]])
			_q.kit.need(problems, absf(float(crossing["after"]) - float(case["after"])) <= TOLERANCE, "%s: %s m/s %d m past the ford, not %s" % [name, crossing["after"], RUN_OUT, case["after"]])
			line.append("%s %.2f in, %.2f after" % [case["label"], seen.y, crossing["after"]])
		notes.append("%s (top %s, ford fraction %s): %s" % [Units.TYPE_IDS[type], top, _fraction, "; ".join(line)])
	_q.kit.verdict("ford_lower_cap_wins", problems, " | ".join(notes))


## gyrocopter_holds_its_share_in_the_ford: no ford slows it; badly damaged it flies at its share through the ford's
## place and after it.
func _gyrocopter() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var kept: float = stats.max_speed * stats.badly_damaged_speed_share
	var crossing: Dictionary = await _cross(_copy(Quick.GYROCOPTER, stats.badly_damaged_speed_share), true)
	var seen: Vector2 = _range_of(crossing["inside"])
	_q.kit.need(problems, crossing["ticks_in"] >= 20, "only %d ticks in the window" % crossing["ticks_in"])
	_q.kit.need(problems, absf(seen.x - kept) <= TOLERANCE and absf(seen.y - kept) <= TOLERANCE and absf(float(crossing["after"]) - kept) <= TOLERANCE, "%s to %s m/s over the ford and %s after it, not %s" % [seen.x, seen.y, crossing["after"], kept])
	_q.kit.verdict("gyrocopter_holds_its_share_in_the_ford", problems, "a badly damaged Gyrocopter flew over the ford at %.2f m/s (%d ticks) and %.2f m/s after it: its share, %s of %s" % [seen.y, crossing["ticks_in"], crossing["after"], stats.badly_damaged_speed_share, stats.max_speed])
