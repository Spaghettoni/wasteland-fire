extends RefCounted
## The Gyrocopter at the Fuel zones in the Story 023 scenario fuel_building, AC-4: a Gyrocopter flown from its own Base's spawn point to
## each zone with real keys reaches it without touching a Tall piece (it is not destroyed), brakes to a hover in it and is refuelled as a
## ground Unit is (its body is on the floor, its drawn model about 2.5 m up); while it hovers in a Fuel zone its tank never runs dry, where
## the same one-Fuel tank outside a zone crashes it. Every recorded row is also run through the rule again. Real keys. Tooling only.
## Implements: production/epics/wasteland-fire/story-023-fuel-building.md AC-4.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## The Gyrocopter's half width for the lane test, a little over its box's, metres.
const LANE_HALF_WIDTH: float = 0.8
## The share of the tank a Gyrocopter leaves its Base with: what the flight burns leaves it low at the zone.
const START_FRACTION: float = 0.6
## Metres short of the braking distance at which the reverse key goes down.
const BRAKE_MARGIN: float = 1.0
## The drive speed at which the reverse key comes up.
const BRAKE_RELEASE: float = 0.3
## Ticks watched after the brake is released: a fill from what the flight left.
const HOVER_TICKS: int = 360
## The longest a flight may take, ticks.
const FLIGHT_LIMIT: int = 1500
## The Gyrocopter's tank for the survival pair: one Fuel, under a second of hovering.
const TINY_TANK: float = 0.01
## Ticks the survival pair is watched.
const SURVIVE_TICKS: int = 300
## The drawn model's lowest point is at least this high while the Gyrocopter flies, metres (the flying height, 2.5 m).
const FLYING_HEIGHT: float = 2.4

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
	for player: int in 2:
		await _from_its_base(player)
	await _never_runs_dry()


## The Player's Gyrocopter appears on its Base's spawn point facing the zone on its side, flies there at full throttle, brakes with the
## reverse key to a hover and is refuelled: not destroyed on the way, in the zone and at rest, its model in the air, its tank whole.
func _from_its_base(player: int) -> void:
	var problems: PackedStringArray = []
	var side: int = player
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var spawn: Vector3 = _k.a.swap().spawn_pose(player)[0]
	var target: Vector3 = _k.centre(side)
	var heading: Vector3 = Vector3(target.x - spawn.x, 0.0, target.z - spawn.z).normalized()
	_q.kit.need(problems, _k.a.k.k.lane_free(spawn, target, LANE_HALF_WIDTH), "a Tall piece lies on the lane from the spawn point %s to the zone" % spawn)
	await _k.park(1 - player)
	await _k.put(player, Quick.GYROCOPTER, spawn, heading, START_FRACTION)
	var gyro: Unit = _k.unit(player)
	var braking_distance: float = stats.max_speed * stats.max_speed / (2.0 * stats.braking)
	_k.watch.clear()
	_k.watch.logging = true
	_q.harness.drive(player, 1, 0)
	var waited: int = 0
	while gyro.is_alive and Vector2(target.x - gyro.global_position.x, target.z - gyro.global_position.z).length() > braking_distance + BRAKE_MARGIN and waited < FLIGHT_LIMIT:
		await _q.kit.tick()
		waited += 1
	var top_speed: float = gyro.current_speed
	_q.harness.drive(player, -1, 0)
	while gyro.is_alive and gyro.current_speed > BRAKE_RELEASE and waited < FLIGHT_LIMIT:
		await _q.kit.tick()
		waited += 1
	_q.harness.drive(player, 0, 0)
	var arrived: int = _k.rows(player).size()
	await _q.kit.advance(HOVER_TICKS)
	_k.watch.logging = false
	var list: Array = _k.rows(player)
	_q.kit.need(problems, gyro.is_alive and bool(list.back()["alive"]), "the Gyrocopter was destroyed on its way (row %d of %d)" % [_first_dead(player), list.size()])
	_q.kit.need(problems, top_speed >= stats.max_speed - 0.5, "the Gyrocopter reached %.2f m/s of %.1f" % [top_speed, stats.max_speed])
	_q.kit.need(problems, bool(list.back()["listed"][side]) and float(list.back()["speed"]) <= _settings.stopped_speed, "at the end the zone lists it %s and its real speed is %.4f" % [list.back()["listed"], list.back()["speed"]])
	var inside: Vector2 = Vector2(absf(gyro.global_position.x - target.x), absf(gyro.global_position.z - target.z))
	_q.kit.need(problems, inside.x <= _k.zone(side).size.x / 2.0 and inside.y <= _k.zone(side).size.z / 2.0, "it hovers %.2f m and %.2f m from the middle of the zone" % [inside.x, inside.y])
	_q.kit.need(problems, Quick.model_bottom(gyro) >= FLYING_HEIGHT, "its drawn model's lowest point is %.2f m up" % Quick.model_bottom(gyro))
	_q.kit.need(problems, absf(gyro.global_position.y) < 0.01, "its body is %.3f m up, not on the floor" % gyro.global_position.y)
	var low: float = INF
	for row: Dictionary in list:
		low = minf(low, float(row["fuel"]))
	var fill: Dictionary = _k.fill_of(player)
	_q.kit.need(problems, int(fill["full"]) >= 0 and float(list.back()["fuel"]) >= stats.fuel_capacity - 1.0, "the tank ended at %.2f of %.1f" % [float(list.back()["fuel"]), stats.fuel_capacity])
	_q.kit.need(problems, int(fill["first"]) > arrived - 12 and float(list[int(fill["first"]) - 1]["speed"]) <= _settings.stopped_speed, "the first gift came in row %d (the brake came up in row %d) after a real speed of %.4f" % [fill["first"], arrived, list[maxi(int(fill["first"]) - 1, 0)]["speed"]])
	_q.kit.need(problems, float(fill["most"]) <= stats.fuel_capacity, "the tank held %.4f above its capacity" % fill["most"])
	problems.append_array(_k.oracle(player, side, _settings.fuel_seconds_to_full, _settings.stopped_speed, "flight %d" % (player + 1)))
	measured.append("gyro_p%d=flight_%d_ticks_low_%.1f_fuel_model_%.2f_m" % [player + 1, arrived, low, Quick.model_bottom(gyro)])
	_q.kit.verdict("gyrocopter_from_its_base_to_the_zone_p%d" % (player + 1), problems, "Player %d's Gyrocopter left its Base's spawn point %s with %.0f%% of a tank, flew %d ticks at %.1f m/s straight to the %s zone (not destroyed), braked to a hover %.2f m from its middle with its model %.2f m up and its body on the floor, ended with %.1f of %.1f Fuel after a low of %.1f, and every row equals the rule run again" % [player + 1, spawn, START_FRACTION * 100.0, arrived, top_speed, "west" if side == 0 else "east", inside.length(), Quick.model_bottom(gyro), float(list.back()["fuel"]), stats.fuel_capacity, low])
	await _k.park(player)


## The first row a Player's Unit was not alive in, or -1.
func _first_dead(player: int) -> int:
	for index: int in _k.rows(player).size():
		if not bool(_k.rows(player)[index]["alive"]):
			return index
	return -1


## A Gyrocopter spawned with one Fuel: inside a Fuel zone it hovers on and fills (its tank never reaches zero), 30 m from either zone the
## same tank is gone in under a second and it crashes.
func _never_runs_dry() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	await _k.park(1)
	await _k.park(0)
	await _k.put_recorded(0, Quick.GYROCOPTER, _k.centre(0), Vector3.RIGHT, TINY_TANK, SURVIVE_TICKS)
	var low: float = INF
	for row: Dictionary in _k.rows(0):
		low = minf(low, float(row["fuel"]))
	var ended: float = float(_k.rows(0).back()["fuel"])
	_q.kit.need(problems, _first_dead(0) == -1 and _k.unit(0).is_alive, "the Gyrocopter in the zone was destroyed in row %d" % _first_dead(0))
	_q.kit.need(problems, low > 0.0 and absf(float(_k.rows(0)[0]["fuel"]) - stats.fuel_capacity * TINY_TANK) < 0.1, "its tank went down to %.4f from %.4f" % [low, float(_k.rows(0)[0]["fuel"])])
	_q.kit.need(problems, ended >= stats.fuel_capacity - 1.0, "it ended with %.2f Fuel" % ended)
	problems.append_array(_k.oracle(0, 0, _settings.fuel_seconds_to_full, _settings.stopped_speed, "tiny tank in the zone"))
	await _k.park(0)
	var away: Vector3 = Vector3(_k.centre(0).x - 30.0, 0.0, 0.0)
	await _k.put_recorded(0, Quick.GYROCOPTER, away, Vector3.RIGHT, TINY_TANK, SURVIVE_TICKS)
	var dead: int = _first_dead(0)
	var burn_ticks: float = stats.fuel_capacity * TINY_TANK / stats.fuel_use_idle * Engine.physics_ticks_per_second
	_q.kit.need(problems, dead >= 0 and absf(float(dead) - burn_ticks) <= 3.0, "the control Gyrocopter 30 m away was destroyed in row %d (its Fuel lasts %.1f ticks)" % [dead, burn_ticks])
	_q.kit.need(problems, not _k.unit(0).is_alive and not bool(_k.rows(0)[0]["listed"][0]) and _k.first_listed(0, 0) == -1, "the control was listed by the zone or still flies")
	measured.append("tiny_tank_low=%.3f_control_destroyed_row=%d" % [low, dead])
	_q.kit.verdict("hovering_gyrocopter_never_runs_dry", problems, "a Gyrocopter spawned with %.1f Fuel hovered %d ticks in the west zone and its tank never fell under %.3f (alive, ended with %.1f), where the same tank 30 m from the zone ran out and crashed it in row %d (its Fuel lasts %.0f ticks at the standing burn)" % [stats.fuel_capacity * TINY_TANK, SURVIVE_TICKS, low, ended, dead, burn_ticks])
	await _k.a.mines().revive(0)
	await _k.park(0)
