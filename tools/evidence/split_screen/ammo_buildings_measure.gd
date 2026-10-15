extends RefCounted
## What the Story 024 scenario ammo_buildings measures first (the story's "Measure first"): the latency of an ammunition zone's list (how many
## ticks after a Unit is brought into it the zone lists it and gives it a share, and how many ticks after it has been taken out the zone still
## lists it), the horizontal real speed of a Unit that stands in a zone, of one pinned against the building with the throttle held and of
## a Gyrocopter hovering in a zone (the noise the stopped speed is set above), and the ticks a load takes from empty to full for every
## type. The numbers are recorded and the checks pin them to what the other modules rely on. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md "Measure first" (1), (3).

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Ticks a Unit stands, a Unit is held against the building, and a Unit is watched after it has been taken out of a zone.
const STAND_TICKS: int = 120
const HELD_TICKS: int = 150
const AFTER_TICKS: int = 12
## The listing latency the other modules rely on: a Unit brought into a zone is listed in this row and given Shots in the next, and a Unit
## taken out is still listed this many rows after (measured on 4.7.2 with Jolt, as the Fuel zones' were).
const LISTED_IN_ROW: int = 2
const GIFT_ROW: int = 3
const LISTED_AFTER_OUT: int = 2

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
	await _latency()
	await _noise()


## A Buggy brought into the west ammunition zone and, after it, taken out again: the rows of the first listing, the first gift and the last
## listing.
func _latency() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var stats: UnitStats = _q.units.stats(Quick.BUGGY)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	await _k.record_after_move(0, _k.centre(zone_index), Vector3.LEFT, 30)
	var first_listed: int = _k.first_listed(0, zone_index)
	var gift: int = _k.gift_rows(0, zone_index, _settings.stopped_speed)[0]
	_q.kit.need(problems, first_listed == LISTED_IN_ROW - 1 or first_listed == LISTED_IN_ROW, "the zone listed the Buggy first in row %d" % first_listed)
	_q.kit.need(problems, gift == GIFT_ROW, "the zone gave first in row %d" % gift)
	_k.watch.clear()
	_k.watch.logging = true
	_k.move(0, _k.arena_spot(), Vector3.RIGHT)
	await _q.kit.advance(AFTER_TICKS)
	_k.watch.logging = false
	var last_listed: int = _k.last_listed(0, zone_index)
	_q.kit.need(problems, last_listed == LISTED_AFTER_OUT - 1 or last_listed == LISTED_AFTER_OUT, "the zone listed the Buggy last in row %d after it was taken out" % last_listed)
	measured.append("latency=listed_in_row_%d_first_gift_row_%d_last_listed_row_%d_after_out" % [first_listed, gift, last_listed])
	_q.kit.verdict("listing_latency", problems, "a %s with an empty gun brought into the west ammunition zone was listed from row %d and given its first share in row %d (rows count from the tick of the move); taken out again it was listed until row %d" % [stats.type_id, first_listed, gift, last_listed])
	await _k.park(0)


## The horizontal real speed of a standing Unit of each ground type in the zone, of a Truck held against the building and of a hovering Gyrocopter:
## the largest value over the rows, recorded, and all under the stopped speed by a wide margin.
func _noise() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var worst: float = 0.0
	var summary: PackedStringArray = []
	for type_index: int in 4:
		var stats: UnitStats = _q.units.stats(type_index)
		await _k.empty_in_the_arena(0, type_index)
		await _k.record_after_move(0, _k.centre(zone_index), Vector3.LEFT, STAND_TICKS)
		var fastest: float = 0.0
		for row: Dictionary in _k.rows(0):
			fastest = maxf(fastest, float(row["speed"]))
		worst = maxf(worst, fastest)
		summary.append("%s %.4f" % [stats.type_id, fastest])
		_q.kit.need(problems, fastest <= _settings.stopped_speed / 10.0, "%s standing in the zone reached a real speed of %.4f m/s" % [stats.type_id, fastest])
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.drive_after_move(0, _k.centre(zone_index), Vector3.LEFT, HELD_TICKS + STAND_TICKS)
	var pinned: float = 0.0
	for row: Dictionary in _k.rows(0).slice(-STAND_TICKS):
		pinned = maxf(pinned, float(row["speed"]))
	_q.kit.need(problems, pinned <= _settings.stopped_speed / 10.0, "the Truck held against the building reached a real speed of %.4f m/s" % pinned)
	measured.append("noise_standing=%s_pinned_%.4f" % [",".join(summary), pinned])
	_q.kit.verdict("real_speed_noise", problems, "over %d ticks a standing Unit in the west ammunition zone read a real speed of at most %s m/s (%s) and a Truck held against the building with the throttle on at most %.4f m/s, against the stopped speed of %.2f m/s" % [STAND_TICKS, "%.4f" % worst, ", ".join(summary), pinned, _settings.stopped_speed])
	await _k.park(0)
