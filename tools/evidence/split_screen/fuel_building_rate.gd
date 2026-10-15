extends RefCounted
## The rate of the Fuel zones in the Story 023 scenario fuel_building, AC-3 (first part): a Unit that has stopped in a Fuel zone fills
## from empty to full in the time the data say, net of its own standing burn, up to full and no further, each of the four types at each
## of the two zones; a zone gives Fuel only (no hit points, no Shots, no Mines come back), and the Fuel bar of the Player's HUD rises as
## the tank fills. Every row the watch filed is also run through the rule again (the kit's oracle). Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-023-fuel-building.md AC-3.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

## The shipped settings, by path.
const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Rows recorded after the tank is whole, and a few more than the fill needs.
const TAIL_TICKS: int = 90
## A fill from a share of the tank may differ from the rule's count from that share by this many ticks (the Unit burns two ticks
## before the first gift).
const TICK_SLACK: int = 1
## The row of the first gift to a Unit spawned in a zone: the zone lists it two ticks after the spawn and gives on the third (measured).
const FIRST_GIFT_ROW: int = 3
## The share of its tank a Gyrocopter starts with: an empty one would crash on its first tick.
const GYRO_FRACTION: float = 0.05
## Hit points taken, Shots fired and Mines laid before the zone is asked for Fuel, to see it give nothing else.
const DAMAGE: float = 10.0
const FIRED: int = 3
const LAID: int = 2
## Ticks between the readings of the Fuel bar.
const BAR_STEP: int = 60

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
	await _every_type_at_every_zone()
	await _only_fuel()
	await _the_bar_rises()


## The type's share of its tank a test starts with.
func _fraction(type_index: int) -> float:
	return GYRO_FRACTION if type_index == Quick.GYROCOPTER else 0.0


## Each type, empty (the Gyrocopter nearly), stopped at each zone: the ticks it takes against the rule's, nothing above the capacity,
## the tank held at the whole once it is, and the oracle quiet.
func _every_type_at_every_zone() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	for side: int in 2:
		var player: int = side
		await _k.park(1 - player)
		for type_index: int in 4:
			await _k.park(player)
			var stats: UnitStats = _q.units.stats(type_index)
			var from_empty: int = _k.fill_ticks(stats, _settings.fuel_seconds_to_full, stats.fuel_capacity * _fraction(type_index))
			await _k.put_recorded(player, type_index, _k.centre(side), Vector3.RIGHT if side == 0 else Vector3.LEFT, _fraction(type_index), from_empty + TAIL_TICKS)
			var fill: Dictionary = _k.fill_of(player)
			var label: String = "%s at zone %d" % [stats.type_id, side]
			var expected: int = _k.fill_ticks(stats, _settings.fuel_seconds_to_full, float(fill["start"]))
			_q.kit.need(problems, int(fill["first"]) == FIRST_GIFT_ROW and int(fill["full"]) >= 0, "%s: the first gain came in row %d (expected %d), the whole tank in row %d" % [label, fill["first"], FIRST_GIFT_ROW, fill["full"]])
			_q.kit.need(problems, int(fill["ticks"]) == expected, "%s: the fill took %d ticks from the first gift, the rule says %d" % [label, fill["ticks"], expected])
			_q.kit.need(problems, absi(int(fill["ticks"]) - from_empty) <= TICK_SLACK, "%s: the fill took %d ticks, the rule from %.2f Fuel says %d" % [label, fill["ticks"], stats.fuel_capacity * _fraction(type_index), from_empty])
			_q.kit.need(problems, float(fill["most"]) <= stats.fuel_capacity, "%s: the tank held %.6f above its capacity %.1f" % [label, fill["most"], stats.fuel_capacity])
			var held: float = stats.fuel_capacity - stats.fuel_use_idle / Engine.physics_ticks_per_second
			for index: int in range(maxi(int(fill["full"]) + 1, 0), _k.rows(player).size()):
				_q.kit.need(problems, absf(float(_k.rows(player)[index]["fuel"]) - held) < 1.0e-6, "%s: row %d held %.6f Fuel after the tank was whole, expected %.6f" % [label, index, _k.rows(player)[index]["fuel"], held])
			problems.append_array(_k.oracle(player, side, _settings.fuel_seconds_to_full, _settings.stopped_speed, label))
			_q.kit.need(problems, _k.oracle_judged > expected, "%s: the oracle judged only %d rows" % [label, _k.oracle_judged])
			summary.append("%s=%d/%d" % [stats.type_id, fill["ticks"], from_empty])
			measured.append("fill_%s_zone%d=%d_ticks_rule_%d" % [stats.type_id, side, fill["ticks"], from_empty])
	_q.kit.verdict("fill_time_every_type_every_zone", problems, "each of the four types, empty (the Gyrocopter with %.0f%%), stopped in each of the two Fuel zones, filled in the ticks the rule gives within %d (fill/rule: %s) at %.1f s to full less its standing burn, never above its capacity, held at the whole tank once there, and every recorded row equals the rule run again from the listing, the real speed and the drive speed" % [GYRO_FRACTION * 100.0, TICK_SLACK, ", ".join(summary), _settings.fuel_seconds_to_full])


## A Truck takes ten hit points, fires three Shots and lays two Mines (the Mines are cleared at once: a live Mine under a stopped Truck
## would go off), then stands in the west zone: its tank fills and its hit points, its Shots and its Mines are what they were.
func _only_fuel() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	await _k.put(0, Quick.TRUCK, _k.centre(0) + Vector3(-2.0, 0.0, 0.0), Vector3.RIGHT, 0.0)
	_k.unit(0).apply_damage(DAMAGE)
	await _k.a.fire_n(0, FIRED)
	for _lay: int in LAID:
		await _k.a.mines().lay(0)
	await _k.a.mines().clear_mines()
	var hit_points: float = _k.unit(0).hit_points
	var shots: int = _k.a.weapon(0).shots_left
	var mines: int = _k.a.mines().layers[0].mines_left
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	_q.harness.drive(0, 0, 0)
	await _k.record(_k.fill_ticks(stats, _settings.fuel_seconds_to_full) + TAIL_TICKS)
	_q.kit.need(problems, hit_points == stats.max_hit_points - DAMAGE and shots == stats.ammo_capacity - FIRED and mines == stats.mine_capacity - LAID, "set-up: %.1f hit points, %d Shots, %d Mines" % [hit_points, shots, mines])
	_q.kit.need(problems, is_equal_approx(_k.unit(0).fuel, stats.fuel_capacity - stats.fuel_use_idle / Engine.physics_ticks_per_second), "the Truck ended with %.5f Fuel" % _k.unit(0).fuel)
	_q.kit.need(problems, _k.unit(0).hit_points == hit_points, "the hit points went from %.1f to %.1f" % [hit_points, _k.unit(0).hit_points])
	_q.kit.need(problems, _k.a.weapon(0).shots_left == shots, "the Shots went from %d to %d" % [shots, _k.a.weapon(0).shots_left])
	_q.kit.need(problems, _k.a.mines().layers[0].mines_left == mines, "the Mines went from %d to %d" % [mines, _k.a.mines().layers[0].mines_left])
	_q.kit.verdict("fuel_only", problems, "a Truck with %.0f hit points, %d of %d Shots and %d of %d Mines stood in the west zone until its tank was whole (%.1f Fuel): its hit points, Shots and Mines were what they were" % [hit_points, shots, stats.ammo_capacity, mines, stats.mine_capacity, _k.unit(0).fuel])


## The Fuel bar of the Player's HUD at every BAR_STEP ticks of a fill: it reads the Unit's Fuel, rises each time, and ends whole.
func _the_bar_rises() -> void:
	var problems: PackedStringArray = []
	await _k.park(1)
	await _k.put(0, Quick.BUGGY, _k.centre(0), Vector3.RIGHT, 0.0)
	var bar: ProgressBar = _k.fuel_bar(0)
	var seen: PackedFloat64Array = []
	for _step: int in 4:
		await _q.kit.advance(BAR_STEP)
		seen.append(bar.value)
		_q.kit.need(problems, absf(bar.value - _k.unit(0).fuel) <= bar.step and bar.max_value == _k.unit(0).fuel_capacity, "the bar read %.4f of %.1f (step %.2f), the Unit holds %.4f" % [bar.value, bar.max_value, bar.step, _k.unit(0).fuel])
	for index: int in range(1, seen.size()):
		_q.kit.need(problems, seen[index] > seen[index - 1], "the bar went from %.2f to %.2f" % [seen[index - 1], seen[index]])
	await _q.kit.advance(BAR_STEP)
	_q.kit.need(problems, bar.value >= _k.unit(0).fuel_capacity - 1.0, "the bar ended at %.2f" % bar.value)
	measured.append("fuel_bar=%s" % ",".join(Array(seen).map(func(value: float) -> String: return "%.1f" % value)))
	_q.kit.verdict("fuel_bar_rises", problems, "the Buggy's Fuel bar read %s Fuel after each second of the fill, the Unit's own Fuel every time, and ended at %.1f of %.1f" % [", ".join(Array(seen).map(func(value: float) -> String: return "%.1f" % value)), bar.value, bar.max_value])
