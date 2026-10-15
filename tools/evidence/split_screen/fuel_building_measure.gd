extends RefCounted
## What the story asks to be measured first, in the Story 023 scenario fuel_building: the real velocity of a Unit standing still (a Gyrocopter
## hovering among them), the noise stopped_speed is set above, and the latency of a box zone on this engine (Godot 4.7.2, Jolt) for a Unit driven
## in, one spawned in it and one leaving: how many ticks after its box overlaps the zone lists it, and how many after it has left it still does.
## (The real velocities of a Unit held against a tank and against a parked Unit, the fill times and the clearances are measured by the stopped,
## rate and places modules.) Real keys. Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md, "Measure first".

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Ticks a Unit stands still before and while it is read, and the rows skipped at the start.
const STAND_TICKS: int = 120
const SKIPPED: int = 10
## Where a Buggy starts its drive through the west zone, metres west of the zone's face, and for how many ticks it is driven.
const RUN_UP: float = 18.0
const RUN_TICKS: int = 150
## The latency a box zone may show and still be useful: at most this many ticks either way (it is measured and recorded, not fixed).
const MOST_LATENCY: int = 3
## Where a Truck waits before it is spawned into the zone.
const WAIT_SPOT: Vector3 = Vector3(-60.0, 0.0, 20.0)

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit23
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit23) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	await _standing()
	await _latency()


## Each of the four types stands still in the west zone (the Gyrocopter hovering) for STAND_TICKS ticks with no key down: the largest real
## horizontal speed after the first rows is the noise, which stopped_speed must be above.
func _standing() -> void:
	var problems: PackedStringArray = []
	var worst: float = 0.0
	var seen: PackedStringArray = []
	await _k.park(1)
	for type_index: int in 4:
		await _k.put(0, type_index, _k.centre(0), Vector3.RIGHT, 0.5)
		await _k.record(STAND_TICKS)
		var top: float = 0.0
		for row: Dictionary in _k.rows(0).slice(SKIPPED):
			top = maxf(top, float(row["speed"]))
		worst = maxf(worst, top)
		seen.append("%s %.9f" % [_q.units.stats(type_index).type_id, top])
	_q.kit.need(problems, worst < _settings.stopped_speed, "the noise of a standing Unit, %.9f m/s, is not below the stopped speed %.3f" % [worst, _settings.stopped_speed])
	measured.append("standing_noise_max=%.9f" % worst)
	_q.kit.verdict("stopped_speed_is_above_the_noise", problems, "the real horizontal speed of a Unit standing still in a zone (%s m/s, over %d ticks after %d) is below the stopped speed %.2f m/s" % [", ".join(seen), STAND_TICKS - SKIPPED, SKIPPED, _settings.stopped_speed])
	await _k.park(0)


## A Buggy driven at full throttle through the west zone, and a Truck spawned in it: the rows at which the zone lists them against the rows at
## which their boxes overlap it (a row is the state at the end of a tick).
func _latency() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.BUGGY)
	var west_face: float = _k.centre(0).x - _k.zone(0).size.x / 2.0
	var east_face: float = _k.centre(0).x + _k.zone(0).size.x / 2.0
	await _k.put(0, Quick.BUGGY, Vector3(west_face - RUN_UP, 0.0, 0.0), Vector3.RIGHT, 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a.k.drive(0, RUN_TICKS)
	_k.watch.logging = false
	var list: Array = _k.rows(0)
	var half: float = stats.collision_size.z / 2.0
	var in_first: int = -1
	var in_last: int = -1
	for index: int in list.size():
		var x: float = (list[index]["at"] as Vector3).x
		if in_first < 0 and x + half >= west_face:
			in_first = index
		if x - half <= east_face:
			in_last = index
	var driven_in: int = _k.first_listed(0, 0) - in_first
	var kept: int = _k.last_listed(0, 0) - in_last
	_q.kit.need(problems, in_first >= 0 and in_last < list.size() - MOST_LATENCY - 1, "the Buggy was in the zone from row %d to row %d of %d: it never left within the record" % [in_first, in_last, list.size()])
	_q.kit.need(problems, driven_in >= 1 and driven_in <= MOST_LATENCY and kept >= 1 and kept <= MOST_LATENCY, "a driven-in Unit was listed %d rows after its box overlapped the zone and kept %d rows after it left" % [driven_in, kept])
	await _k.park(0)
	await _k.put(0, Quick.TRUCK, WAIT_SPOT, Vector3.RIGHT, 0.5)
	_k.unit(0).leave_play()
	await _q.kit.advance(_k.a.mines().OUT_TICKS)
	_k.watch.clear()
	_k.watch.logging = true
	_q.units.retype(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT)
	await _q.kit.advance(2 * MOST_LATENCY + 2)
	_k.watch.logging = false
	var spawned_in: int = _k.first_listed(0, 0)
	var gift: int = _k.first_gain(0)
	_q.kit.need(problems, spawned_in >= 1 and spawned_in <= MOST_LATENCY and gift == spawned_in + 1, "a Truck spawned in the zone was listed in row %d and given Fuel in row %d" % [spawned_in, gift])
	measured.append("latency=driven_in_%d_kept_%d_spawned_in_%d_first_gift_%d" % [driven_in, kept, spawned_in, gift])
	_q.kit.verdict("zone_latency_is_measured", problems, "a box zone on this engine lists a Unit driven in %d ticks after its box overlaps it and still lists it %d ticks after it has left; one spawned in it is listed in row %d and, by the two-tick rule, given Fuel in row %d" % [driven_in, kept, spawned_in, gift])
	await _k.park(0)
