extends RefCounted
## What counts as stopped in the Story 023 scenario fuel_building, AC-3 (second part): a Unit rolling through a Fuel zone at any speed is
## not refuelled, one crawling just over the stopped speed is not and one just under is, a Unit held against a tank with the throttle on
## (its drive speed stays up, its real speed is zero) is, a parked Unit another Unit drives into is measured and recorded with no outcome
## fixed (the rows are judged by the rule, whichever way it goes), one that moves off stops refuelling by its first moving tick, and the
## zone's own edges are where the box says: a Truck whose nose is 0.2 m inside the zone is refuelled and one 0.2 m outside is not. Real
## keys. Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## A crawl is a share of the top speed that gives this multiple of the stopped speed: under it and over it.
const CRAWL_UNDER: float = 0.5
const CRAWL_OVER: float = 1.1
## Ticks a crawl, a hold and a stay are watched.
const WATCH_TICKS: int = 150
## The Truck's reach into a zone from its face, metres, for the edge pair: inside and outside by this much.
const EDGE_DEPTH: float = 0.2
## Ticks the Truck sits in the zone before it moves off.
const SIT_TICKS: int = 60
## A drive speed is "up" when it is at least this many stopped speeds.
const DRIVE_UP: float = 10.0

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
	await _rolling_through()
	await _crawling()
	await _held_against_a_tank()
	await _held_against_a_unit()
	await _moving_off()
	await _edges()


## How many rows of a Player's record gained Fuel (net of the burn).
func _gains(player: int) -> int:
	var count: int = 0
	for step: float in _k.steps(player):
		count += 1 if step > 0.0 else 0
	return count


## The first row whose real speed is above the stopped speed, or -1.
func _first_moving(player: int, from: int = 0) -> int:
	for index: int in range(from, _k.rows(player).size()):
		if float(_k.rows(player)[index]["speed"]) > _settings.stopped_speed:
			return index
	return -1


## A Buggy at full throttle through the west zone, half a tank: listed for dozens of ticks, never given a drop.
func _rolling_through() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	await _k.put(0, Quick.BUGGY, Vector3(_k.centre(0).x - 18.0, 0.0, 0.0), Vector3.RIGHT, 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a.k.drive(0, 110)
	_k.watch.logging = false
	var listed_rows: int = 0
	for row: Dictionary in _k.rows(0):
		listed_rows += 1 if bool(row["listed"][0]) else 0
	_q.kit.need(problems, listed_rows > 20, "the Buggy was listed on only %d rows" % listed_rows)
	_q.kit.need(problems, _gains(0) == 0, "the Buggy rolling through gained Fuel on %d rows" % _gains(0))
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "rolling"))
	measured.append("rolling_through_listed_rows=%d" % listed_rows)
	_q.kit.verdict("rolling_through_gets_nothing", problems, "a Buggy at its top speed (%.1f m/s) crossed the west zone with half a tank, the zone listing it on %d rows, and gained Fuel on none (%d rows judged by the rule)" % [_q.units.stats(Quick.BUGGY).max_speed, listed_rows, _k.oracle_judged])


## A Truck crawling at a share of its top speed: under the stopped speed it is refuelled, over it it is not.
func _crawling() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var result: PackedStringArray = []
	for multiple: float in [CRAWL_UNDER, CRAWL_OVER]:
		var share: float = multiple * _settings.stopped_speed / stats.max_speed
		await _k.put(0, Quick.TRUCK, _k.centre(0) + Vector3(-2.0, 0.0, 0.0), Vector3.RIGHT, 0.5)
		_k.watch.clear()
		_k.watch.logging = true
		await _k.a.k.drive(0, WATCH_TICKS, share)
		_k.watch.logging = false
		var speed: float = float(_k.rows(0).back()["speed"])
		var under: bool = multiple < 1.0
		_q.kit.need(problems, (speed <= _settings.stopped_speed) == under, "at %.2f of the stopped speed the Truck's real speed was %.4f" % [multiple, speed])
		_q.kit.need(problems, (_gains(0) > 0) == under, "at %.2f of the stopped speed (%.4f m/s) the Truck gained Fuel on %d rows" % [multiple, speed, _gains(0)])
		problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "crawl x%.1f" % multiple))
		result.append("x%.1f=%.4f m/s, %d gain rows" % [multiple, speed, _gains(0)])
	measured.append("crawl=%s" % ";".join(result))
	_q.kit.verdict("crawl_over_and_under_the_stopped_speed", problems, "a Truck crept through the west zone at %.2f and at %.2f times the stopped speed (%.2f m/s): %s; refuelled under it, given nothing over it" % [CRAWL_UNDER, CRAWL_OVER, _settings.stopped_speed, "; ".join(result)])


## A Truck driven at the north-west tank with the throttle held: its drive speed stays up while its real speed is zero, and it is refuelled.
func _held_against_a_tank() -> void:
	var problems: PackedStringArray = []
	await _k.put(0, Quick.TRUCK, Vector3(-10.83, 0.0, 0.02), Vector3(0.518, 0.0, -0.856).normalized(), 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a.k.drive(0, 2 * WATCH_TICKS)
	_k.watch.logging = false
	var list: Array = _k.rows(0)
	var pinned_from: int = list.size() - WATCH_TICKS
	var slowest_drive: float = INF
	var fastest_real: float = 0.0
	var touching: int = 0
	for index: int in range(pinned_from, list.size()):
		slowest_drive = minf(slowest_drive, float(list[index]["drive"]))
		fastest_real = maxf(fastest_real, float(list[index]["speed"]))
		for slide: String in list[index]["slides"]:
			touching += 1 if slide.contains("FuelTanks/FuelTankNorthWest") else 0
	_q.kit.need(problems, slowest_drive >= DRIVE_UP * _settings.stopped_speed, "the drive speed fell to %.3f while the Truck was held" % slowest_drive)
	_q.kit.need(problems, fastest_real <= _settings.stopped_speed, "the real speed was %.4f while the Truck was held" % fastest_real)
	_q.kit.need(problems, touching >= WATCH_TICKS - 1, "the Truck slid against the tank on %d of %d rows" % [touching, WATCH_TICKS])
	_q.kit.need(problems, bool(list.back()["listed"][0]), "the zone did not list the Truck at the tank")
	var fill: Dictionary = _k.fill_of(0)
	_q.kit.need(problems, int(fill["full"]) >= 0 and absf(float(list.back()["fuel"]) - 100.0) < 1.0, "the Truck held against the tank ended with %.3f Fuel" % float(list.back()["fuel"]))
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "held against a tank"))
	measured.append("held_against_tank_drive=%.2f_real=%.4f" % [slowest_drive, fastest_real])
	_q.kit.verdict("held_against_a_tank_is_stopped", problems, "a Truck driven at the depot's north-west tank with the throttle held: its drive speed stayed at %.2f m/s or more and its real speed at %.4f m/s or less over its last %d ticks, touching the tank on %d of them, and it was refuelled to %.1f" % [slowest_drive, fastest_real, WATCH_TICKS, touching, float(list.back()["fuel"])])


## Player 1's Buggy stands parked in the west zone and Player 2's Truck drives into it with the throttle held. What the parked Unit does
## is measured and recorded, whichever way it goes; both rows are judged by the rule.
func _held_against_a_unit() -> void:
	var problems: PackedStringArray = []
	await _k.put(0, Quick.BUGGY, _k.centre(0), Vector3.BACK, 0.5)
	await _k.put(1, Quick.TRUCK, _k.centre(0) + Vector3(-9.0, 0.0, 0.0), Vector3.RIGHT, 0.5)
	var before: Vector3 = _k.unit(0).global_position
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a.k.drive(1, 2 * WATCH_TICKS)
	_k.watch.logging = false
	var parked_speed: float = 0.0
	for row: Dictionary in _k.rows(0):
		parked_speed = maxf(parked_speed, float(row["speed"]))
	var pinned: int = 0
	for row: Dictionary in _k.rows(1).slice(-WATCH_TICKS):
		for slide: String in row["slides"]:
			pinned += 1 if slide.contains(String(_k.unit(0).name)) else 0
	var moved: float = _k.unit(0).global_position.distance_to(before)
	var parked_gained: bool = _gains(0) > 0
	_q.kit.need(problems, pinned >= WATCH_TICKS - 1, "the driver slid against the parked Unit on %d of %d rows" % [pinned, WATCH_TICKS])
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "parked Unit"))
	problems.append_array(_k.oracle(1, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "driver"))
	measured.append("parked_unit_driven_into=%s_moved_%.3f_m_fastest_%.4f_m_per_s" % ["refuels" if parked_gained else "does_not_refuel", moved, parked_speed])
	_q.kit.verdict("parked_unit_driven_into_is_measured", problems, "a Truck driven into a Buggy parked in the west zone with the throttle held, pinned against it on %d of the last %d rows: the parked Buggy %s (pushed %.3f m, its real speed at most %.4f m/s), and every row of both Units equals the rule run again" % [pinned, WATCH_TICKS, "was refuelled" if parked_gained else "was not refuelled", moved, parked_speed])
	await _k.park(1)


## A Truck sits in the zone for SIT_TICKS filling, then the throttle goes down: the last gift is no later than its first moving tick.
func _moving_off() -> void:
	var problems: PackedStringArray = []
	await _k.put(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.5)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(SIT_TICKS)
	await _k.a.k.drive(0, 90)
	_k.watch.logging = false
	var moving: int = _first_moving(0)
	var last_gain: int = -1
	for index: int in range(1, _k.rows(0).size()):
		if float(_k.rows(0)[index]["fuel"]) > float(_k.rows(0)[index - 1]["fuel"]):
			last_gain = index
	_q.kit.need(problems, moving > SIT_TICKS - 1 and last_gain >= SIT_TICKS - 2, "the Truck moved in row %d, last gained in row %d" % [moving, last_gain])
	_q.kit.need(problems, last_gain <= moving, "the zone gave Fuel in row %d, after the Truck's first moving row %d" % [last_gain, moving])
	var last_listed: int = _k.last_listed(0, 0)
	_q.kit.need(problems, last_listed > moving, "the Truck left the zone before it was listed again (row %d, moving row %d)" % [last_listed, moving])
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "moving off"))
	measured.append("moving_off_last_gain_minus_first_moving=%d" % (last_gain - moving))
	_q.kit.verdict("moving_off_ends_the_refill", problems, "a Truck filling in the west zone set off at row %d and was last given Fuel in row %d (%d rows after its first moving row, none after it), while the zone still listed it until row %d" % [moving, last_gain, last_gain - moving, last_listed])


## A Truck standing with its nose EDGE_DEPTH inside the west face of the zone is refuelled, one with its nose EDGE_DEPTH outside is not.
func _edges() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var face: float = _k.centre(0).x - 3.0
	var gained: Array[bool] = []
	for depth: float in [EDGE_DEPTH, -EDGE_DEPTH]:
		await _k.put(0, Quick.TRUCK, Vector3(face - stats.collision_size.z / 2.0 + depth, 0.0, 0.0), Vector3.RIGHT, 0.5)
		_k.watch.clear()
		_k.watch.logging = true
		await _q.kit.advance(WATCH_TICKS)
		_k.watch.logging = false
		gained.append(_gains(0) > 0)
		problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "edge %.1f" % depth))
	_q.kit.need(problems, gained == [true, false], "the Truck %.1f m inside / %.1f m outside the face gained Fuel: %s" % [EDGE_DEPTH, EDGE_DEPTH, gained])
	_q.kit.verdict("zone_edge_is_the_box", problems, "a Truck stopped with its nose %.1f m inside the west face of the zone (x %.1f) was refuelled and one stopped %.1f m outside it was not" % [EDGE_DEPTH, face, EDGE_DEPTH])
