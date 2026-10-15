extends RefCounted
## What counts as stopped in the Story 024 scenario ammo_buildings, AC-2 (second part): a Unit rolling through an ammunition zone at
## any speed is not rearmed, one crawling just over the stopped speed is not and one just under is, a Unit held against the building
## with the throttle on (its drive speed stays up, its real speed is zero) is, a parked Unit another Unit drives into is measured and
## recorded with no outcome fixed (the rows are judged by the rule, whichever way it goes), one that moves off stops rearming by its
## first moving tick, and the zone's own edge is where the box says: a Truck whose nose is 0.2 m inside it is rearmed and one 0.2 m
## outside is not. Every Unit has an empty gun. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

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
## How far from the zone's middle a Unit starts its roll along the zone, metres, and the ticks it rolls for.
const ROLL_START: float = 18.0
const ROLL_TICKS: int = 100
## Rows a roll through the zone is listed on at least (a zone 6 m across at more than 6 m/s lists it for under a second).
const ROLL_LISTED: int = 20

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit24
var _q: Quick
var _settings: SupplySettings


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()
	_settings = load(SETTINGS_PATH) as SupplySettings


func run() -> void:
	await _rolling_through()
	await _crawling()
	await _held_against_the_building()
	await _held_against_a_unit()
	await _moving_off()
	await _edge()


## How many rows of a Player's record gained Shots.
func _gains(player: int) -> int:
	return _k.gains(player)


## The first row whose real speed is above the stopped speed, or -1.
func _first_moving(player: int, from: int = 0) -> int:
	for index: int in range(from, _k.rows(player).size()):
		if float(_k.rows(player)[index]["speed"]) > _settings.stopped_speed:
			return index
	return -1


## A Buggy at full throttle along the zone from its south side, empty gun: listed for dozens of ticks, never given a Shot.
func _rolling_through() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var middle: Vector3 = _k.centre(zone_index)
	await _k.park(1)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	await _k.drive_after_move(0, middle + Vector3(0.0, 0.0, ROLL_START), Vector3.FORWARD, ROLL_TICKS)
	var listed_rows: int = 0
	var fastest: float = 0.0
	for row: Dictionary in _k.rows(0):
		listed_rows += 1 if bool(row["listed"][zone_index]) else 0
		fastest = maxf(fastest, float(row["speed"]) if bool(row["listed"][zone_index]) else 0.0)
	_q.kit.need(problems, listed_rows >= ROLL_LISTED and fastest > _q.units.stats(Quick.BUGGY).max_speed * 0.5, "the Buggy was listed on only %d rows, at most %.2f m/s" % [listed_rows, fastest])
	_q.kit.need(problems, _gains(0) == 0 and int(_k.rows(0).back()["left"]) == 0, "the Buggy rolling through gained Shots on %d rows and ended with %d" % [_gains(0), _k.rows(0).back()["left"]])
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "rolling"))
	measured.append("rolling_through_listed_rows=%d_at_%.1f_m_per_s" % [listed_rows, fastest])
	_q.kit.verdict("rolling_through_gets_nothing", problems, "a Buggy with an empty gun drove along the west ammunition zone at up to %.1f m/s (its top speed %.1f), the zone listing it on %d rows, and gained no Shot (%d rows judged by the rule)" % [fastest, _q.units.stats(Quick.BUGGY).max_speed, listed_rows, _k.oracle_judged])


## A Truck crawling at a share of its top speed: under the stopped speed it is rearmed, over it it is not.
func _crawling() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var result: PackedStringArray = []
	for multiple: float in [CRAWL_UNDER, CRAWL_OVER]:
		var share: float = multiple * _settings.stopped_speed / stats.max_speed
		await _k.empty_in_the_arena(0, Quick.TRUCK)
		await _k.drive_after_move(0, _k.centre(zone_index) + Vector3(2.0, 0.0, 0.0), Vector3.LEFT, WATCH_TICKS, share)
		var speed: float = float(_k.rows(0).back()["speed"])
		var under: bool = multiple < 1.0
		_q.kit.need(problems, (speed <= _settings.stopped_speed) == under, "at %.2f of the stopped speed the Truck's real speed was %.4f" % [multiple, speed])
		_q.kit.need(problems, (_gains(0) > 0) == under, "at %.2f of the stopped speed (%.4f m/s) the Truck gained Shots on %d rows" % [multiple, speed, _gains(0)])
		problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "crawl x%.1f" % multiple))
		result.append("x%.1f=%.4f m/s, %d gain rows" % [multiple, speed, _gains(0)])
	measured.append("crawl=%s" % ";".join(result))
	_q.kit.verdict("crawl_over_and_under_the_stopped_speed", problems, "a Truck with an empty gun crept through the west ammunition zone at %.2f and at %.2f times the stopped speed (%.2f m/s): %s; rearmed under it, given nothing over it" % [CRAWL_UNDER, CRAWL_OVER, _settings.stopped_speed, "; ".join(result)])


## A Truck driven at the building with the throttle held: its drive speed stays up while its real speed is zero, and it is rearmed.
func _held_against_the_building() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.drive_after_move(0, _k.centre(zone_index), Vector3.LEFT, 2 * WATCH_TICKS)
	var list: Array = _k.rows(0)
	var pinned_from: int = list.size() - WATCH_TICKS
	var slowest_drive: float = INF
	var fastest_real: float = 0.0
	var touching: int = 0
	for index: int in range(pinned_from, list.size()):
		slowest_drive = minf(slowest_drive, float(list[index]["drive"]))
		fastest_real = maxf(fastest_real, float(list[index]["speed"]))
		for slide: String in list[index]["slides"]:
			touching += 1 if slide.ends_with("AmmoBuildingWest") else 0
	_q.kit.need(problems, slowest_drive >= DRIVE_UP * _settings.stopped_speed, "the drive speed fell to %.3f while the Truck was held" % slowest_drive)
	_q.kit.need(problems, fastest_real <= _settings.stopped_speed, "the real speed was %.4f while the Truck was held" % fastest_real)
	_q.kit.need(problems, touching >= WATCH_TICKS - 1, "the Truck slid against the building on %d of %d rows" % [touching, WATCH_TICKS])
	_q.kit.need(problems, bool(list.back()["listed"][zone_index]), "the zone did not list the Truck at the building")
	_q.kit.need(problems, int(list.back()["left"]) == stats.ammo_capacity, "the Truck held against the building ended with %d of %d Shots" % [list.back()["left"], stats.ammo_capacity])
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "held against the building"))
	measured.append("held_against_building_drive=%.2f_real=%.4f" % [slowest_drive, fastest_real])
	_q.kit.verdict("held_against_the_building_is_stopped", problems, "a Truck with an empty gun driven at the west ammunition building with the throttle held: its drive speed stayed at %.2f m/s or more and its real speed at %.4f m/s or less over its last %d ticks, touching the building on %d of them, and it was rearmed to %d Shots" % [slowest_drive, fastest_real, WATCH_TICKS, touching, stats.ammo_capacity])


## Player 1's Buggy, empty, stands parked in the west zone and Player 2's Truck drives into it with the throttle held. What the parked Unit
## does is measured and recorded, whichever way it goes; both rows are judged by the rule.
func _held_against_a_unit() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var middle: Vector3 = _k.centre(zone_index)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	await _k.f.put(1, Quick.TRUCK, middle + Vector3(9.0, 0.0, 0.0), Vector3.LEFT, 1.0)
	_k.move(0, middle, Vector3.BACK)
	var before: Vector3 = _k.unit(0).global_position
	_k.watch.clear()
	_k.watch.logging = true
	await _k.a().k.drive(1, 2 * WATCH_TICKS)
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
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "parked Unit"))
	measured.append("parked_unit_driven_into=%s_moved_%.3f_m_fastest_%.4f_m_per_s" % ["rearms" if parked_gained else "does_not_rearm", moved, parked_speed])
	_q.kit.verdict("parked_unit_driven_into_is_measured", problems, "a Truck driven into an empty Buggy parked in the west ammunition zone with the throttle held, pinned against it on %d of the last %d rows: the parked Buggy %s (pushed %.3f m, its real speed at most %.4f m/s), and every row of the parked Unit equals the rule run again" % [pinned, WATCH_TICKS, "was rearmed" if parked_gained else "was not rearmed", moved, parked_speed])
	await _k.park(1)


## A Truck sits in the zone for SIT_TICKS filling, then the throttle goes down: the last gift is no later than its first moving tick.
func _moving_off() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var middle: Vector3 = _k.centre(zone_index)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	_k.move(0, middle + Vector3(1.0, 0.0, 0.0), Vector3.LEFT)
	_k.watch.clear()
	_k.watch.logging = true
	await _q.kit.advance(SIT_TICKS)
	await _k.a().k.drive(0, 90, -1.0)
	_k.watch.logging = false
	var moving: int = _first_moving(0)
	var last_gain: int = -1
	for index: int in range(1, _k.rows(0).size()):
		if int(_k.rows(0)[index]["left"]) > int(_k.rows(0)[index - 1]["left"]):
			last_gain = index
	var gifts: PackedInt32Array = _k.gift_rows(0, zone_index, _settings.stopped_speed)
	_q.kit.need(problems, moving > SIT_TICKS - 1 and last_gain >= SIT_TICKS - 12, "the Buggy moved in row %d, last gained in row %d" % [moving, last_gain])
	_q.kit.need(problems, not gifts.is_empty() and gifts[gifts.size() - 1] <= moving, "the zone gave in row %d, after the Buggy's first moving row %d" % [gifts[gifts.size() - 1] if not gifts.is_empty() else -1, moving])
	var last_listed: int = _k.last_listed(0, zone_index)
	_q.kit.need(problems, last_listed > moving, "the Buggy left the zone before it was listed again (row %d, moving row %d)" % [last_listed, moving])
	problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "moving off"))
	measured.append("moving_off_last_gift_minus_first_moving=%d" % (gifts[gifts.size() - 1] - moving))
	_q.kit.verdict("moving_off_ends_the_rearm", problems, "a Buggy rearming in the west ammunition zone set off backwards at row %d: its last gift came in row %d (no later than its first moving row), its last Shot in row %d, while the zone still listed it until row %d" % [moving, gifts[gifts.size() - 1], last_gain, last_listed])


## A Truck standing with its nose EDGE_DEPTH inside the east face of the zone is rearmed, one with its nose EDGE_DEPTH outside is not.
func _edge() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	var face: float = _k.centre(zone_index).x + _k.zone(zone_index).size.x / 2.0
	var gained: Array[bool] = []
	for depth: float in [EDGE_DEPTH, -EDGE_DEPTH]:
		await _k.empty_in_the_arena(0, Quick.TRUCK)
		await _k.record_after_move(0, Vector3(face + stats.collision_size.z / 2.0 - depth, 0.0, _k.centre(zone_index).z), Vector3.LEFT, WATCH_TICKS)
		gained.append(_gains(0) > 0)
		problems.append_array(_k.oracle(0, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "edge %.1f" % depth))
	_q.kit.need(problems, gained == [true, false], "the Truck %.1f m inside / %.1f m outside the face gained Shots: %s" % [EDGE_DEPTH, EDGE_DEPTH, gained])
	_q.kit.verdict("zone_edge_is_the_box", problems, "a Truck with an empty gun stopped with its nose %.1f m inside the centre-side face of the west ammunition zone (x %.1f) was rearmed and one stopped %.1f m outside it was not" % [EDGE_DEPTH, face, EDGE_DEPTH])
