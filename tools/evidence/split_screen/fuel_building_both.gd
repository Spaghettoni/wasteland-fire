extends RefCounted
## Both Players at the Fuel zones in the Story 023 scenario fuel_building, AC-3 (third part): Units of both Players stopped in one zone are
## refuelled on the same ticks and each at the full rate (the zone serves every Unit in it, not the nearest), Units in the two zones fill
## on the same ticks too, and a zone never runs dry: the fifth fill takes the ticks the first did, and the zone keeps nothing but the list
## of its last tick. Real keys. Tooling only. Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Rows recorded after a fill's expected end.
const TAIL_TICKS: int = 30
## The row a Unit spawned in a zone is first given Fuel on (measured by the rate module).
const FIRST_GIFT_ROW: int = 3
## How far apart across the zone the two Units stand, metres.
const SIDE_BY_SIDE: float = 1.6
## Fills in a row at one zone.
const FILLS: int = 5
## The only variable of the zone's script that holds state and is not an export: its private list of its last tick (the class doc of
## SupplyZone).
const ONLY_STATE: String = "_listed_before"
## The other variable of the zone's script that is not an export, since Story 024: the Weapons SplitScreen hands an ammunition zone, a
## list of references the zone only reads, never state a Round has to restore (a Fuel zone leaves it empty).
const HANDED: String = "weapons"

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
	await _two_in_one_zone()
	await _one_in_each_zone()
	await _never_runs_dry()


## Judges the fill of a Player's Unit that was put down empty in a zone: the first gift on the third row, and the whole tank after the
## ticks the rule gives from there, with the oracle quiet. Adds the problems under a label; returns the fill.
func _judge(problems: PackedStringArray, player: int, side: int, label: String) -> Dictionary:
	var stats: UnitStats = _k.unit(player).stats
	var fill: Dictionary = _k.fill_of(player)
	_q.kit.need(problems, int(fill["first"]) == FIRST_GIFT_ROW, "%s: the first gift came in row %d" % [label, fill["first"]])
	_q.kit.need(problems, int(fill["ticks"]) == _k.fill_ticks(stats, _settings.fuel_seconds_to_full, float(fill["start"])), "%s: the fill took %d ticks, the rule says %d" % [label, fill["ticks"], _k.fill_ticks(stats, _settings.fuel_seconds_to_full, float(fill["start"]))])
	_q.kit.need(problems, float(fill["most"]) <= stats.fuel_capacity, "%s: the tank held %.6f above its capacity" % [label, fill["most"]])
	problems.append_array(_k.oracle(player, side, _settings.fuel_seconds_to_full, _settings.stopped_speed, label))
	return fill


## The ticks the longest fill of the types takes from an empty tank, and the tail.
func _span(types: Array[int]) -> int:
	var longest: int = 0
	for type_index: int in types:
		longest = maxi(longest, _k.fill_ticks(_q.units.stats(type_index), _settings.fuel_seconds_to_full))
	return longest + TAIL_TICKS


## Player 1's Motorbike and Player 2's Buggy, both empty, side by side in the west zone: they are given Fuel on the same row and each
## fills in the ticks it would alone.
func _two_in_one_zone() -> void:
	var problems: PackedStringArray = []
	await _k.park(0)
	await _k.park(1)
	var centre: Vector3 = _k.centre(0)
	await _k.put_many_recorded([
		{"player": 0, "type": Quick.MOTORBIKE, "at": centre + Vector3(0.0, 0.0, -SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": 0.0},
		{"player": 1, "type": Quick.BUGGY, "at": centre + Vector3(0.0, 0.0, SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": 0.0}],
		_span([Quick.MOTORBIKE, Quick.BUGGY]))
	var first: Dictionary = _judge(problems, 0, 0, "the Motorbike")
	var second: Dictionary = _judge(problems, 1, 0, "the Buggy")
	_q.kit.need(problems, bool(_k.rows(0)[FIRST_GIFT_ROW]["listed"][0]) and bool(_k.rows(1)[FIRST_GIFT_ROW]["listed"][0]), "the zone did not list both Units on the row of the first gift")
	measured.append("two_in_one_zone=motorbike_%d_buggy_%d" % [first["ticks"], second["ticks"]])
	_q.kit.verdict("both_players_in_one_zone", problems, "Player 1's Motorbike and Player 2's Buggy, empty and side by side in the west zone, were both given Fuel from row %d and filled in %d and %d ticks, what each takes alone" % [FIRST_GIFT_ROW, first["ticks"], second["ticks"]])
	await _k.park(0)
	await _k.park(1)


## Player 1's Truck in the east zone and Player 2's Gyrocopter in the west one at once (a Player may use either zone): on the same row.
func _one_in_each_zone() -> void:
	var problems: PackedStringArray = []
	await _k.put_many_recorded([
		{"player": 0, "type": Quick.TRUCK, "at": _k.centre(1), "facing": Vector3.LEFT, "fraction": 0.0},
		{"player": 1, "type": Quick.GYROCOPTER, "at": _k.centre(0), "facing": Vector3.RIGHT, "fraction": 0.05}],
		_span([Quick.TRUCK, Quick.GYROCOPTER]))
	var truck: Dictionary = _judge(problems, 0, 1, "the Truck in the east zone")
	var gyro: Dictionary = _judge(problems, 1, 0, "the Gyrocopter in the west zone")
	_q.kit.need(problems, not bool(_k.rows(0)[FIRST_GIFT_ROW]["listed"][0]) and not bool(_k.rows(1)[FIRST_GIFT_ROW]["listed"][1]), "a Unit was listed by the zone it is not in")
	measured.append("one_in_each_zone=truck_%d_gyrocopter_%d" % [truck["ticks"], gyro["ticks"]])
	_q.kit.verdict("one_player_in_each_zone", problems, "Player 1's Truck in the east zone and Player 2's Gyrocopter in the west zone, at once, were given Fuel from row %d and filled in %d and %d ticks, what each takes alone, neither zone listing the other's Unit" % [FIRST_GIFT_ROW, truck["ticks"], gyro["ticks"]])
	await _k.park(0)
	await _k.park(1)


## Five empty Trucks in turn, the two Players alternating, at the one west zone: every fill takes the ticks of the first, and the zone
## holds no variable but the list of its last tick.
func _never_runs_dry() -> void:
	var problems: PackedStringArray = []
	var times: PackedInt32Array = []
	for round_index: int in FILLS:
		var player: int = round_index % 2
		await _k.park(1 - player)
		await _k.park(player)
		await _k.put_recorded(player, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 0.0, _span([Quick.TRUCK]))
		var fill: Dictionary = _judge(problems, player, 0, "fill %d" % (round_index + 1))
		times.append(int(fill["ticks"]))
	_q.kit.need(problems, times.count(times[0]) == FILLS, "the fills took %s ticks" % [times])
	var state: PackedStringArray = []
	for property: Dictionary in _k.zone(0).get_script().get_script_property_list():
		if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 and (int(property["usage"]) & PROPERTY_USAGE_STORAGE) == 0:
			state.append(String(property["name"]))
	_q.kit.need(problems, state.size() == 2 and state.has(ONLY_STATE) and state.has(HANDED), "the zone's script keeps %s besides its exports" % [state])
	measured.append("never_runs_dry=%d_fills_of_%d_ticks" % [FILLS, times[0]])
	_q.kit.verdict("zone_never_runs_dry", problems, "%d empty Trucks filled in turn at the west zone, every fill %d ticks (%s), and the zone's script keeps no variable besides its exports and the Weapons handed to it but %s" % [FILLS, times[0], times, ONLY_STATE])
	await _k.park(0)
	await _k.park(1)
