extends RefCounted
## Both Players at the ammunition zones in the Story 024 scenario ammo_buildings, AC-2 (third part): Units of both Players rearm at one
## zone at once, on the same ticks and in the time each takes alone; a Player may use either building (no owner): the west Player at the
## east building and the east Player at the west one, at once; and a building never runs dry: five empty Trucks in turn fill in the same
## ticks, and the zone's script keeps no variable but the list of its last tick and the Weapons handed to it. Every Unit has an empty
## gun. Real keys. Tooling only. Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Rows recorded after the load is whole.
const TAIL_TICKS: int = 30
## The row a Unit brought into a zone is first given Shots on (measured by the rate module).
const FIRST_GIFT_ROW: int = 3
## How far apart across the zone the two Units stand, metres.
const SIDE_BY_SIDE: float = 1.6
## Fills in a row at one zone.
const FILLS: int = 5
## The only variable of the zone's script that holds state and is not an export: its list of its last tick; and the Weapons handed to it
## (a list of references the zone only reads).
const ONLY_STATE: String = "_listed_before"
const HANDED: String = "weapons"

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
	await _two_in_one_zone()
	await _one_in_each_zone()
	await _never_runs_dry()


## The ticks a fill of the types in a row needs, and some more.
func _span(types: Array[int]) -> int:
	var longest: int = 0
	for type_index: int in types:
		longest = maxi(longest, _k.fill_ticks(_q.units.stats(type_index).ammo_capacity, _settings.ammo_seconds_to_full))
	return longest + TAIL_TICKS


## Judges a Player's fill at a zone: the first gift on FIRST_GIFT_ROW, the whole load in the ticks the rule gives, the oracle quiet.
## Adds the problems under a label and returns the fill.
func _judge(problems: PackedStringArray, player: int, zone_index: int, label: String) -> Dictionary:
	var fill: Dictionary = _k.fill_of(player, zone_index, _settings.stopped_speed)
	var expected: int = _k.fill_ticks(_k.gun(player).capacity, _settings.ammo_seconds_to_full)
	_q.kit.need(problems, int(fill["gift"]) == FIRST_GIFT_ROW and int(fill["full"]) >= 0, "%s: the first gift came in row %d (expected %d), the whole load in row %d" % [label, fill["gift"], FIRST_GIFT_ROW, fill["full"]])
	_q.kit.need(problems, int(fill["ticks"]) == expected and int(fill["most"]) == _k.gun(player).capacity, "%s: the fill took %d ticks (the rule says %d) and the load held %d Shots at most" % [label, fill["ticks"], expected, fill["most"]])
	problems.append_array(_k.oracle(player, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, label))
	return fill


## Player 1's Motorbike and Player 2's Buggy, both with an empty gun, side by side in the west ammunition zone: both are given Shots from
## the same row and fill in the ticks each takes alone.
func _two_in_one_zone() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var middle: Vector3 = _k.centre(zone_index)
	await _k.empty_in_the_arena(0, Quick.MOTORBIKE)
	await _k.park(0)
	await _k.empty_in_the_arena(1, Quick.BUGGY)
	await _k.record_after_moves([
		{"player": 0, "at": middle + Vector3(0.0, 0.0, -SIDE_BY_SIDE), "facing": Vector3.LEFT},
		{"player": 1, "at": middle + Vector3(0.0, 0.0, SIDE_BY_SIDE), "facing": Vector3.LEFT}],
		_span([Quick.MOTORBIKE, Quick.BUGGY]))
	var first: Dictionary = _judge(problems, 0, zone_index, "the Motorbike")
	var second: Dictionary = _judge(problems, 1, zone_index, "the Buggy")
	_q.kit.need(problems, int(first["gift"]) == int(second["gift"]), "the two were first given Shots in rows %d and %d" % [first["gift"], second["gift"]])
	measured.append("two_in_one_zone=motorbike_%d_buggy_%d" % [first["ticks"], second["ticks"]])
	_q.kit.verdict("both_players_in_one_zone", problems, "Player 1's Motorbike and Player 2's Buggy, both empty and side by side in the west ammunition zone, were both given Shots from row %d and filled in %d and %d ticks, what each takes alone" % [FIRST_GIFT_ROW, first["ticks"], second["ticks"]])
	await _k.park(0)
	await _k.park(1)


## Player 1's Truck in the east ammunition zone and Player 2's Gyrocopter in the west one at once (a Player may use either building):
## on the same row, neither zone listing the other's Unit.
func _one_in_each_zone() -> void:
	var problems: PackedStringArray = []
	var west: int = _k.ammo_index(0)
	var east: int = _k.ammo_index(1)
	await _k.empty_in_the_arena(0, Quick.TRUCK)
	await _k.park(0)
	await _k.empty_in_the_arena(1, Quick.GYROCOPTER)
	await _k.record_after_moves([
		{"player": 0, "at": _k.centre(east), "facing": Vector3.RIGHT},
		{"player": 1, "at": _k.centre(west), "facing": Vector3.LEFT}],
		_span([Quick.TRUCK, Quick.GYROCOPTER]))
	var truck: Dictionary = _judge(problems, 0, east, "the Truck in the east zone")
	var gyro: Dictionary = _judge(problems, 1, west, "the Gyrocopter in the west zone")
	_q.kit.need(problems, not bool(_k.rows(0)[FIRST_GIFT_ROW]["listed"][west]) and not bool(_k.rows(1)[FIRST_GIFT_ROW]["listed"][east]), "a Unit was listed by the zone it is not in")
	measured.append("one_in_each_zone=truck_%d_gyrocopter_%d" % [truck["ticks"], gyro["ticks"]])
	_q.kit.verdict("one_player_in_each_zone", problems, "Player 1's Truck in the east ammunition zone and Player 2's Gyrocopter in the west one, at once (each at the other half's building), were given Shots from row %d and filled in %d and %d ticks, what each takes alone, neither zone listing the other's Unit" % [FIRST_GIFT_ROW, truck["ticks"], gyro["ticks"]])
	await _k.park(0)
	await _k.park(1)


## Five empty Trucks in turn, the two Players alternating, at the one west zone: every fill takes the ticks of the first, and the zone holds
## no variable but the list of its last tick and the Weapons handed to it.
func _never_runs_dry() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	var times: PackedInt32Array = []
	for round_index: int in FILLS:
		var player: int = round_index % 2
		await _k.park(1 - player)
		await _k.empty_in_the_arena(player, Quick.TRUCK)
		await _k.record_after_move(player, _k.centre(zone_index), Vector3.LEFT, _span([Quick.TRUCK]))
		var fill: Dictionary = _judge(problems, player, zone_index, "fill %d" % (round_index + 1))
		times.append(int(fill["ticks"]))
	_q.kit.need(problems, times.count(times[0]) == FILLS, "the fills took %s ticks" % [times])
	var state: PackedStringArray = []
	for property: Dictionary in _k.zone(zone_index).get_script().get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			state.append(String(property["name"]))
	_q.kit.need(problems, state.size() == 2 and state.has(ONLY_STATE) and state.has(HANDED), "the zone's script keeps %s besides its exports" % [state])
	measured.append("never_runs_dry=%d_fills_of_%d_ticks" % [FILLS, times[0]])
	_q.kit.verdict("zone_never_runs_dry", problems, "%d empty Trucks filled in turn at the west ammunition zone, every fill %d ticks (%s), and the zone's script keeps no variable besides its exports and the Weapons handed to it but %s" % [FILLS, times[0], times, ONLY_STATE])
	await _k.park(0)
	await _k.park(1)
