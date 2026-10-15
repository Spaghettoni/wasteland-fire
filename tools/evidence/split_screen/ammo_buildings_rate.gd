extends RefCounted
## The rate of the ammunition zones in the Story 024 scenario ammo_buildings, AC-2 (first part): a Unit that has stopped in an
## ammunition zone with an empty gun rearms from empty to a full load in the time the data say, a whole Shot at a time, up to full and
## no further, each of the four types at each of the two zones; a zone gives Shots only (no Fuel, no hit points, no Mines come back)
## and a Fuel zone gives no Shot; the Ammo line of the Player's view rises as the load fills. Every row the watch filed is also run
## through the rule again (the kit's oracle); and the zone ticks before the Weapon, so a Shot fired by a held key leaves in the very frame the
## zone makes the gun whole (the story's "pin the order from the run"). Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-2.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

## The shipped settings, by path.
const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## Rows recorded after the load is whole, and a few more than the fill needs.
const TAIL_TICKS: int = 90
## A fill may differ from the rule's count by this many ticks (the story says give or take one).
const TICK_SLACK: int = 1
## The row of the first gift to a Unit brought into a zone: the zone lists it two ticks after the move and gives on the third
## (measured by the measure module); the first whole Shot comes later, the carry holding the parts.
const FIRST_GIFT_ROW: int = 3
## Hit points taken, Fuel left and Mines laid before the zone is asked for Shots, to see it give nothing else.
const DAMAGE: float = 10.0
const TANK_SHARE: float = 0.5
const LAID: int = 2
## Ticks an empty Motorbike stands in a Fuel zone.
const FUEL_ZONE_TICKS: int = 300
## Ticks between the readings of the Ammo line.
const LINE_STEP: int = 60
## Ticks an empty Motorbike holds its fire key in the zone: enough for several Shots.
const FIRE_TICKS: int = 60

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
	await _every_type_at_every_zone()
	await _only_ammo()
	await _fuel_zone_gives_no_shot()
	await _the_line_rises()
	await _rearm_comes_before_the_weapon()


## The facing of a Unit that stopped in a zone of a side: toward its building.
func _toward_building(side: int) -> Vector3:
	return -_k.inward(side)


## Each type, empty, stopped at each ammunition zone: the ticks it takes against the rule's, nothing above the capacity, the load held at
## the whole once it is, one report of the Weapon for every Shot (the Ammo line reading each in the same emission), and the oracle quiet.
func _every_type_at_every_zone() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	for side: int in 2:
		var player: int = side
		var zone_index: int = _k.ammo_index(side)
		for type_index: int in 4:
			var stats: UnitStats = _q.units.stats(type_index)
			var expected: int = _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full)
			await _k.empty_in_the_arena(player, type_index)
			var mark: int = _k.a().changes[player].size()
			await _k.record_after_move(player, _k.centre(zone_index), _toward_building(side), expected + TAIL_TICKS)
			var fill: Dictionary = _k.fill_of(player, zone_index, _settings.stopped_speed)
			var label: String = "%s at ammunition zone %d" % [stats.type_id, side]
			var reports: Array = _k.a().changes[player].slice(mark)
			_q.kit.need(problems, int(fill["gift"]) == FIRST_GIFT_ROW and int(fill["first"]) > int(fill["gift"]) and int(fill["full"]) >= 0 and int(fill["start"]) == 0, "%s: the first gift came in row %d (expected %d), the first Shot in row %d from %d Shots, the whole load in row %d" % [label, fill["gift"], FIRST_GIFT_ROW, fill["first"], fill["start"], fill["full"]])
			_q.kit.need(problems, int(fill["ticks"]) == expected, "%s: the fill took %d ticks from the first gift, the rule says %d" % [label, fill["ticks"], expected])
			_q.kit.need(problems, absi(int(fill["ticks"]) - roundi(_settings.ammo_seconds_to_full * Engine.physics_ticks_per_second)) <= TICK_SLACK, "%s: the fill took %d ticks, %.1f s is %d" % [label, fill["ticks"], _settings.ammo_seconds_to_full, roundi(_settings.ammo_seconds_to_full * Engine.physics_ticks_per_second)])
			_q.kit.need(problems, int(fill["most"]) == stats.ammo_capacity and int(fill["capacity"]) == stats.ammo_capacity, "%s: the load held %d Shots at most, the capacity is %d" % [label, fill["most"], stats.ammo_capacity])
			for index: int in range(maxi(int(fill["full"]), 0), _k.rows(player).size()):
				_q.kit.need(problems, int(_k.rows(player)[index]["left"]) == stats.ammo_capacity, "%s: row %d held %d Shots after the load was whole" % [label, index, _k.rows(player)[index]["left"]])
			_q.kit.need(problems, reports.size() == stats.ammo_capacity, "%s: the Weapon reported %d times for a load of %d" % [label, reports.size(), stats.ammo_capacity])
			for index: int in reports.size():
				_q.kit.need(problems, int(reports[index]["left"]) == index + 1 and reports[index]["text"] == "Ammo %d / %d" % [index + 1, stats.ammo_capacity], "%s: report %d was %s" % [label, index, reports[index]])
			problems.append_array(_k.oracle(player, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, label))
			_q.kit.need(problems, _k.oracle_judged > expected, "%s: the oracle judged only %d rows" % [label, _k.oracle_judged])
			summary.append("%s=%d" % [stats.type_id, fill["ticks"]])
			measured.append("fill_%s_zone%d=%d_ticks_%d_shots" % [stats.type_id, side, fill["ticks"], stats.ammo_capacity])
	_q.kit.verdict("fill_time_every_type_every_zone", problems, "each of the four types, with an empty gun, stopped in each of the two ammunition zones, filled in the ticks the rule gives within %d (%s) at %.1f s to full, a whole Shot at a time (one report for each Shot, the Ammo line reading it in the same emission), never above its capacity, held at the whole load once there, and every recorded row equals the rule run again from the listing and the real speed" % [TICK_SLACK, ", ".join(summary), _settings.ammo_seconds_to_full])


## A Truck takes ten hit points, runs on half a tank and lays two Mines (the Mines are cleared at once: a live Mine under a stopped
## Truck would go off), fires its load away, and stands in the west ammunition zone: its load fills and its hit points, its Fuel (but
## for the burn of standing) and its Mines are what they were.
func _only_ammo() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.TRUCK)
	await _k.park(1)
	await _k.mines().revive(0)
	await _k.mines().put_stats(0, _q.small_tank(Quick.TRUCK, TANK_SHARE), _k.arena_spot(), Vector3.RIGHT)
	_k.unit(0).apply_damage(DAMAGE)
	for _lay: int in LAID:
		await _k.mines().lay(0)
	await _k.mines().clear_mines()
	await _k.a().empty_gun(0)
	var hit_points: float = _k.unit(0).hit_points
	var mines: int = _k.mines().layers[0].mines_left
	var fuel: float = _k.unit(0).fuel
	await _k.record_after_move(0, _k.centre(_k.ammo_index(0)), _toward_building(0), _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full) + TAIL_TICKS)
	var rows: Array = _k.rows(0)
	var rose: int = 0
	for index: int in range(1, rows.size()):
		rose += 1 if float(rows[index]["fuel"]) > float(rows[index - 1]["fuel"]) else 0
	_q.kit.need(problems, is_equal_approx(hit_points, stats.max_hit_points - DAMAGE) and mines == stats.mine_capacity - LAID and fuel < stats.fuel_capacity, "set-up: %.1f hit points, %d Mines, %.2f Fuel" % [hit_points, mines, fuel])
	_q.kit.need(problems, int(rows.back()["left"]) == stats.ammo_capacity, "the Truck ended with %d of %d Shots" % [rows.back()["left"], stats.ammo_capacity])
	_q.kit.need(problems, rose == 0 and float(rows.back()["fuel"]) < fuel, "the Truck's Fuel rose on %d rows (from %.3f to %.3f): the zone gave Fuel" % [rose, fuel, float(rows.back()["fuel"])])
	_q.kit.need(problems, _k.unit(0).hit_points == hit_points, "the hit points went from %.1f to %.1f" % [hit_points, _k.unit(0).hit_points])
	_q.kit.need(problems, _k.mines().layers[0].mines_left == mines, "the Mines went from %d to %d" % [mines, _k.mines().layers[0].mines_left])
	_q.kit.verdict("ammo_only", problems, "a Truck with %.0f hit points, %.1f Fuel of %.1f, %d of %d Mines and an empty gun stood in the west ammunition zone until its load was whole (%d Shots): its hit points and its Mines were what they were and its Fuel only fell (the burn of standing, %.2f at the end)" % [hit_points, fuel, stats.fuel_capacity, mines, stats.mine_capacity, stats.ammo_capacity, float(rows.back()["fuel"])])
	await _k.park(0)


## An empty Motorbike on half a tank stands in a Fuel zone: its tank fills and its gun stays empty.
func _fuel_zone_gives_no_shot() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.MOTORBIKE)
	await _k.park(1)
	await _k.mines().revive(0)
	await _k.mines().put_stats(0, _q.small_tank(Quick.MOTORBIKE, TANK_SHARE), _k.arena_spot(), Vector3.RIGHT)
	await _k.a().empty_gun(0)
	await _k.record_after_move(0, _k.centre(0), _toward_building(0), FUEL_ZONE_TICKS)
	var rows: Array = _k.rows(0)
	_q.kit.need(problems, int(rows.back()["left"]) == 0 and _k.gains(0) == 0, "the Motorbike in a Fuel zone gained Shots on %d rows and ended with %d" % [_k.gains(0), rows.back()["left"]])
	_q.kit.need(problems, float(rows.back()["fuel"]) > stats.fuel_capacity * TANK_SHARE and bool(rows[FIRST_GIFT_ROW + 1]["listed"][0]), "the Motorbike in the Fuel zone ended with %.2f Fuel (it began with %.2f) and was listed %s" % [float(rows.back()["fuel"]), stats.fuel_capacity * TANK_SHARE, rows[FIRST_GIFT_ROW + 1]["listed"]])
	_q.kit.need(problems, not bool(rows.back()["listed"][_k.ammo_index(0)]) and not bool(rows.back()["listed"][_k.ammo_index(1)]), "an ammunition zone listed the Motorbike in the Fuel zone")
	_q.kit.verdict("fuel_zone_gives_no_shot", problems, "an empty Motorbike on half a tank stood %d ticks in the west Fuel zone: its tank rose to %.1f and its gun stayed at 0 Shots" % [FUEL_ZONE_TICKS, float(rows.back()["fuel"])])
	await _k.park(0)


## An empty Motorbike with its fire key held (a real key event) is brought into the west zone: the first whole Shot the zone gives it is
## reported and fired in the same physics frame, because the zone ticks before the Weapon; a Weapon ticking first would fire it a frame later.
## The gun's cadence from the last Shot of the emptying is waited out first, or it would hold the Shot back by itself.
func _rearm_comes_before_the_weapon() -> void:
	var problems: PackedStringArray = []
	var zone_index: int = _k.ammo_index(0)
	await _k.empty_in_the_arena(0, Quick.MOTORBIKE)
	await _q.kit.advance(_k.a().cadence_ticks(Quick.MOTORBIKE))
	var changes_mark: int = _k.a().changes[0].size()
	var shots_mark: int = _k.a().shots.size()
	_q.harness.set_key(_q.harness.fire_key(0), true)
	await _k.record_after_move(0, _k.centre(zone_index), _toward_building(0), FIRE_TICKS)
	_q.harness.set_key(_q.harness.fire_key(0), false)
	await _q.kit.tick()
	var reports: Array = _k.a().changes[0].slice(changes_mark)
	var shots: Array = _k.a().shots.slice(shots_mark)
	_q.kit.need(problems, not reports.is_empty() and not shots.is_empty() and int(reports[0]["left"]) == 1, "the first report was %s and %d Shots were fired" % [reports[0] if not reports.is_empty() else "none", shots.size()])
	if not reports.is_empty() and not shots.is_empty():
		_q.kit.need(problems, int(shots[0]["frame"]) == int(reports[0]["frame"]), "the first Shot entered in frame %d, the zone's first Shot was reported in frame %d" % [shots[0]["frame"], reports[0]["frame"]])
		_q.kit.need(problems, shots.size() >= 2 and int(shots[1]["frame"]) - int(shots[0]["frame"]) == _k.a().cadence_ticks(Quick.MOTORBIKE), "the next Shot came %d frames after the first, the cadence is %d" % [int(shots[1]["frame"]) - int(shots[0]["frame"]) if shots.size() >= 2 else -1, _k.a().cadence_ticks(Quick.MOTORBIKE)])
		measured.append("first_shot_frame_minus_report_frame=%d" % (int(shots[0]["frame"]) - int(reports[0]["frame"])))
	_q.kit.verdict("rearm_comes_before_the_weapons_tick", problems, "an empty Motorbike with its fire key held, brought into the west ammunition zone, fired the first Shot the zone made whole in the very physics frame it was reported (frame %d), so the zone ticks before the Weapon, and went on firing at its cadence of %d ticks" % [int(reports[0]["frame"]) if not reports.is_empty() else -1, _k.a().cadence_ticks(Quick.MOTORBIKE)])
	await _k.park(0)


## The Ammo line of the Player's view at every LINE_STEP ticks of a fill: it reads the Weapon's own count, rises each time, and ends whole.
func _the_line_rises() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.BUGGY)
	await _k.empty_in_the_arena(0, Quick.BUGGY)
	_k.watch.clear()
	_k.move(0, _k.centre(_k.ammo_index(0)), _toward_building(0))
	var seen: PackedInt32Array = []
	for _step: int in 4:
		await _q.kit.advance(LINE_STEP)
		seen.append(_k.gun(0).shots_left)
		_q.kit.need(problems, _k.a().line(0) == "Ammo %d / %d" % [_k.gun(0).shots_left, stats.ammo_capacity], "the line read '%s' with %d Shots in the gun" % [_k.a().line(0), _k.gun(0).shots_left])
	for index: int in range(1, seen.size()):
		_q.kit.need(problems, seen[index] > seen[index - 1], "the load went from %d to %d" % [seen[index - 1], seen[index]])
	await _q.kit.advance(LINE_STEP)
	_q.kit.need(problems, _k.a().line(0) == "Ammo %d / %d" % [stats.ammo_capacity, stats.ammo_capacity], "the line ended at '%s'" % _k.a().line(0))
	measured.append("ammo_line=%s" % ",".join(Array(seen).map(func(value: int) -> String: return str(value))))
	_q.kit.verdict("ammo_line_rises", problems, "the Buggy's Ammo line read %s Shots of %d after each second of the fill, the Weapon's own count every time, and ended at 'Ammo %d / %d'" % [", ".join(Array(seen).map(func(value: int) -> String: return str(value))), stats.ammo_capacity, stats.ammo_capacity, stats.ammo_capacity])
	await _k.park(0)
