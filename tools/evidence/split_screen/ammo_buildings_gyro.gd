extends RefCounted
## The Gyrocopter at the ammunition zones in the Story 024 scenario ammo_buildings, AC-3 (and the Gyrocopter's half of AC-1): a Gyrocopter
## flown from outside its own Base's Gate to the ammunition zone on its side with real keys flies over the building (its model clear of
## the building's top, no stop, no crash, no slide against it), is not destroyed on the way (it touches no Tall piece), brakes to a hover
## in the zone and is rearmed as a ground Unit is (its body is on the floor, its drawn model about 2.5 m up); one flown over the building at
## its top speed keeps it (no stop, no crash, no slide); a Gyrocopter hovering at its
## flying height in either zone is rearmed in the time a ground Unit takes, and one hovering over the building itself, outside the zone,
## is not. The gun is empty at the start. Real keys. Tooling only. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-3 and AC-1.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const SETTINGS_PATH: String = "res://src/gameplay/supply/data/supply_settings.tres"
## The Gyrocopter's half width for the lane test, a little over its box's, metres.
const LANE_HALF_WIDTH: float = 0.8
## The stick the flight is made with, a share of full (the Gyrocopter cruises at that share of its top speed, so its braking distance
## from the far face of the building ends inside the zone), the drive speed at which the reverse key comes up, the metres past the
## building's far face at which the brake goes down, and the longest flight.
const CRUISE_SHARE: float = 0.5
const BRAKE_RELEASE: float = 0.3
const BRAKE_AFTER: float = 0.3
const FLIGHT_LIMIT: int = 1500
## Ticks watched after the brake is released: a fill, and some more.
const TAIL_TICKS: int = 90
## The drawn model's lowest point is at least this high while the Gyrocopter flies, metres (the flying height, 2.5 m).
const FLYING_HEIGHT: float = 2.4
## The building's top is at least this far under the model's lowest point, metres.
const CLEARANCE: float = 0.5
## How far past the building's far face the full-speed flight goes on before the brake goes down, metres.
const TOP_SPEED_RUN: float = 8.0
## A flight over the building keeps its speed within this many metres a second of the speed it had on the way in.
const SPEED_LOSS: float = 0.5
## Ticks a Gyrocopter hovers over the building, outside the zone.
const OVER_TICKS: int = 300
## The rows before the building's footprint the speed on the way in is read from.
const RUN_IN: int = 10

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
	for player: int in 2:
		await _from_its_base(player)
	for player: int in 2:
		await _at_full_speed_over_the_building(player)
	await _hovering_in_each_zone()
	await _hovering_over_the_building()


## True when a place lies over a building's footprint (x and z only), grown by `grow` metres.
func _over(side: int, at: Vector3, grow: float = 0.0) -> bool:
	var box: AABB = ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).get_debug_mesh().get_aabb()
	var local: Vector3 = _k.building(side).global_transform.affine_inverse() * at
	return absf(local.x) <= box.size.x / 2.0 + grow and absf(local.z) <= box.size.z / 2.0 + grow


## The first row a Player's Unit was not alive in, or -1.
func _first_dead(player: int) -> int:
	for index: int in _k.rows(player).size():
		if not bool(_k.rows(player)[index]["alive"]):
			return index
	return -1


## The Player's Gyrocopter appears on its Base's spawn point facing the ammunition zone on its side with an empty gun, flies there at
## full throttle over the building, brakes with the reverse key to a hover and is rearmed: not destroyed on the way, over the building
## with its model clear of its top and no loss of speed and no slide against it, in the zone and at rest, its model in the air.
func _from_its_base(player: int) -> void:
	var problems: PackedStringArray = []
	var side: int = player
	var zone_index: int = _k.ammo_index(side)
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var spawn: Vector3 = Vector3(_k.a().swap().outside_point(player).x, 0.0, 0.0)
	var target: Vector3 = _k.centre(zone_index)
	var heading: Vector3 = Vector3(target.x - spawn.x, 0.0, target.z - spawn.z).normalized()
	_q.kit.need(problems, _k.a().k.k.lane_free(spawn, target, LANE_HALF_WIDTH), "a Tall piece lies on the lane from the spawn point %s to the zone" % spawn)
	await _k.empty_in_the_arena(player, Quick.GYROCOPTER)
	var gyro: Unit = _k.unit(player)
	var far_face: float = ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.x / 2.0 + BRAKE_AFTER
	var past: Callable = func() -> bool: return (gyro.global_position - _k.building(side).global_position).dot(_k.inward(side)) >= far_face
	_k.watch.clear()
	_k.watch.logging = true
	_k.move(player, spawn, heading)
	var waited: int = await _k.a().k.drive(player, FLIGHT_LIMIT, CRUISE_SHARE, 0, past)
	var top_speed: float = gyro.current_speed
	_q.harness.drive(player, -1, 0)
	while gyro.is_alive and gyro.current_speed > BRAKE_RELEASE and waited < FLIGHT_LIMIT:
		await _q.kit.tick()
		waited += 1
	_q.harness.drive(player, 0, 0)
	var arrived: int = _k.rows(player).size()
	await _q.kit.advance(TAIL_TICKS + _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full))
	_k.watch.logging = false
	var list: Array = _k.rows(player)
	var over: Array[int] = []
	for index: int in list.size():
		if _over(side, list[index]["at"]) and bool(list[index]["alive"]):
			over.append(index)
	_q.kit.need(problems, gyro.is_alive and bool(list.back()["alive"]), "the Gyrocopter was destroyed on its way (row %d of %d)" % [_first_dead(player), list.size()])
	_q.kit.need(problems, absf(top_speed - stats.max_speed * CRUISE_SHARE) <= SPEED_LOSS, "the Gyrocopter cruised at %.2f m/s, a stick at %.2f of %.1f is %.2f" % [top_speed, CRUISE_SHARE, stats.max_speed, stats.max_speed * CRUISE_SHARE])
	_q.kit.need(problems, over.size() > 2, "the Gyrocopter was over the building on only %d rows" % over.size())
	if over.size() > 2:
		var entering: float = float(list[maxi(over[0] - RUN_IN, 0)]["speed"])
		var lowest: float = INF
		var bottom: float = INF
		var touched: int = 0
		for index: int in over:
			lowest = minf(lowest, float(list[index]["speed"]))
			bottom = minf(bottom, float(list[index]["bottom"]))
			for slide: String in list[index]["slides"]:
				touched += 1 if slide.contains("AmmoBuilding") else 0
		var top_of_building: float = ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size.y
		_q.kit.need(problems, lowest >= entering - SPEED_LOSS, "over the building its speed fell from %.2f to %.2f m/s" % [entering, lowest])
		_q.kit.need(problems, bottom >= FLYING_HEIGHT and bottom - top_of_building >= CLEARANCE, "over the building the model's lowest point was %.2f m up, the building's top is %.2f m" % [bottom, top_of_building])
		_q.kit.need(problems, touched == 0, "the Gyrocopter slid against the building on %d rows" % touched)
		measured.append("gyro_p%d_over_building=%d_rows_speed_%.2f_to_%.2f_bottom_%.2f" % [player + 1, over.size(), entering, lowest, bottom])
	_q.kit.need(problems, bool(list.back()["listed"][zone_index]) and float(list.back()["speed"]) <= _settings.stopped_speed, "at the end the zone lists it %s and its real speed is %.4f" % [list.back()["listed"], list.back()["speed"]])
	var inside: Vector2 = Vector2(absf(gyro.global_position.x - target.x), absf(gyro.global_position.z - target.z))
	_q.kit.need(problems, inside.x <= _k.zone(zone_index).size.x / 2.0 and inside.y <= _k.zone(zone_index).size.z / 2.0, "it hovers %.2f m and %.2f m from the middle of the zone" % [inside.x, inside.y])
	_q.kit.need(problems, Quick.model_bottom(gyro) >= FLYING_HEIGHT and absf(gyro.global_position.y) < 0.01, "its drawn model's lowest point is %.2f m up and its body %.3f m" % [Quick.model_bottom(gyro), gyro.global_position.y])
	var fill: Dictionary = _k.fill_of(player, zone_index, _settings.stopped_speed)
	_q.kit.need(problems, int(fill["full"]) >= 0 and int(list.back()["left"]) == stats.ammo_capacity, "the load ended at %d of %d" % [list.back()["left"], stats.ammo_capacity])
	_q.kit.need(problems, int(fill["gift"]) > arrived - 12 and float(list[int(fill["gift"]) - 1]["speed"]) <= _settings.stopped_speed, "the first gift came in row %d (the brake came up in row %d) after a real speed of %.4f" % [fill["gift"], arrived, list[maxi(int(fill["gift"]) - 1, 0)]["speed"]])
	_q.kit.need(problems, int(fill["ticks"]) == _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full), "the fill took %d ticks from the first gift" % fill["ticks"])
	problems.append_array(_k.oracle(player, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "flight %d" % (player + 1)))
	measured.append("gyro_p%d=flight_%d_ticks_fill_%d_model_%.2f_m" % [player + 1, arrived, fill["ticks"], Quick.model_bottom(gyro)])
	_q.kit.verdict("gyrocopter_from_its_base_to_the_zone_p%d" % (player + 1), problems, "Player %d's Gyrocopter with an empty gun left the place %s outside its Base's Gate, flew %d ticks at %.1f m/s straight to the ammunition zone on its side, over the building on %d rows with its model clear of the top and no loss of speed (not destroyed, no slide), braked to a hover %.2f m from the middle of the zone with its model %.2f m up and its body on the floor, ended with %d of %d Shots after a fill of %d ticks, and every row equals the rule run again" % [player + 1, spawn, arrived, top_speed, over.size(), inside.length(), Quick.model_bottom(gyro), stats.ammo_capacity, stats.ammo_capacity, fill["ticks"]])
	await _k.park(player)


## The Gyrocopter flown from outside its Gate at full throttle over the building on its side and TOP_SPEED_RUN metres beyond it, then braked: it
## holds its top speed over the building (no stop), is not destroyed (the building is no Tall piece: no crash), slides against nothing, and
## its model clears the building's top.
func _at_full_speed_over_the_building(player: int) -> void:
	var problems: PackedStringArray = []
	var side: int = player
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var start: Vector3 = Vector3(_k.a().swap().outside_point(player).x, 0.0, 0.0)
	var target: Vector3 = _k.centre(_k.ammo_index(side))
	var heading: Vector3 = Vector3(target.x - start.x, 0.0, target.z - start.z).normalized()
	var box: Vector3 = ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size
	await _k.empty_in_the_arena(player, Quick.GYROCOPTER)
	var gyro: Unit = _k.unit(player)
	var past: Callable = func() -> bool: return (gyro.global_position - _k.building(side).global_position).dot(_k.inward(side)) >= box.x / 2.0 + TOP_SPEED_RUN
	_k.watch.clear()
	_k.watch.logging = true
	_k.move(player, start, heading)
	var waited: int = await _k.a().k.drive(player, FLIGHT_LIMIT, 1.0, 0, past)
	var top_speed: float = gyro.current_speed
	_q.harness.drive(player, -1, 0)
	while gyro.is_alive and gyro.current_speed > BRAKE_RELEASE and waited < FLIGHT_LIMIT:
		await _q.kit.tick()
		waited += 1
	_q.harness.drive(player, 0, 0)
	_k.watch.logging = false
	var list: Array = _k.rows(player)
	var over: Array[int] = []
	for index: int in list.size():
		if _over(side, list[index]["at"]) and bool(list[index]["alive"]):
			over.append(index)
	_q.kit.need(problems, gyro.is_alive and _first_dead(player) == -1 and top_speed >= stats.max_speed - SPEED_LOSS, "the Gyrocopter was destroyed (row %d) or reached only %.2f m/s of %.1f" % [_first_dead(player), top_speed, stats.max_speed])
	_q.kit.need(problems, over.size() > 2, "the Gyrocopter was over the building on only %d rows" % over.size())
	if over.size() > 2:
		var lowest: float = INF
		var bottom: float = INF
		var touched: int = 0
		for index: int in over:
			lowest = minf(lowest, float(list[index]["speed"]))
			bottom = minf(bottom, float(list[index]["bottom"]))
			for slide: String in list[index]["slides"]:
				touched += 1 if slide.contains("AmmoBuilding") else 0
		_q.kit.need(problems, lowest >= stats.max_speed - SPEED_LOSS and touched == 0, "over the building its speed fell to %.2f m/s of %.1f and it slid against it on %d rows" % [lowest, stats.max_speed, touched])
		_q.kit.need(problems, bottom - box.y >= CLEARANCE, "over the building the model's lowest point was %.2f m up, the building's top is %.2f m" % [bottom, box.y])
		measured.append("gyro_p%d_top_speed_over_building=%d_rows_speed_%.2f_bottom_%.2f" % [player + 1, over.size(), lowest, bottom])
		_q.kit.verdict("gyrocopter_at_top_speed_over_the_building_p%d" % (player + 1), problems, "Player %d's Gyrocopter flown from outside its Gate at full throttle over the building on its side held %.2f m/s of its top %.1f on the %d rows it was over it (not destroyed, no slide, its model at least %.2f m over the building's top) and was braked %.0f m beyond it" % [player + 1, lowest, stats.max_speed, over.size(), bottom - box.y, TOP_SPEED_RUN])
	else:
		_q.kit.verdict("gyrocopter_at_top_speed_over_the_building_p%d" % (player + 1), problems, "the flight did not cross the building")
	await _k.park(player)


## A Gyrocopter with an empty gun placed in each zone (either Player at either building), hovering: rearmed from row 3 in the ticks a ground
## Unit takes, its model in the air.
func _hovering_in_each_zone() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var expected: int = _k.fill_ticks(stats.ammo_capacity, _settings.ammo_seconds_to_full)
	var summary: PackedStringArray = []
	for side: int in 2:
		var player: int = 1 - side
		var zone_index: int = _k.ammo_index(side)
		await _k.empty_in_the_arena(player, Quick.GYROCOPTER)
		await _k.record_after_move(player, _k.centre(zone_index), -_k.inward(side), expected + TAIL_TICKS)
		var fill: Dictionary = _k.fill_of(player, zone_index, _settings.stopped_speed)
		_q.kit.need(problems, int(fill["gift"]) == 3 and int(fill["ticks"]) == expected, "zone %d: the first gift came in row %d and the fill took %d ticks (the rule says %d)" % [side, fill["gift"], fill["ticks"], expected])
		_q.kit.need(problems, Quick.model_bottom(_k.unit(player)) >= FLYING_HEIGHT and absf(_k.unit(player).global_position.y) < 0.01, "zone %d: the model is %.2f m up and the body %.3f m" % [side, Quick.model_bottom(_k.unit(player)), _k.unit(player).global_position.y])
		problems.append_array(_k.oracle(player, zone_index, _settings.ammo_seconds_to_full, _settings.stopped_speed, "hover at zone %d" % side))
		summary.append("zone %d: %d ticks, model %.2f m" % [side, fill["ticks"], Quick.model_bottom(_k.unit(player))])
		await _k.park(player)
	measured.append("gyro_hover=%s" % ";".join(summary))
	_q.kit.verdict("gyrocopter_hovering_in_a_zone_rearms", problems, "a Gyrocopter with an empty gun placed at rest in each ammunition zone (Player 2 at the west one, Player 1 at the east one) was rearmed from row 3 in the %d ticks a ground Unit takes (%s), its model at its flying height and its body on the floor" % [expected, "; ".join(summary)])


## A Gyrocopter hovering over the middle of the building, 3 m from the zone's edge... outside the zone: not rearmed in OVER_TICKS ticks.
func _hovering_over_the_building() -> void:
	var problems: PackedStringArray = []
	var side: int = 0
	var zone_index: int = _k.ammo_index(side)
	var building: Vector3 = _k.building(side).global_position
	await _k.empty_in_the_arena(0, Quick.GYROCOPTER)
	await _k.record_after_move(0, building, Vector3.RIGHT, OVER_TICKS)
	var list: Array = _k.rows(0)
	_q.kit.need(problems, _over(side, list.back()["at"]) and not bool(list.back()["listed"][zone_index]) and _k.first_listed(0, zone_index) == -1, "the Gyrocopter over the building was listed by the zone %s" % [list.back()["listed"]])
	_q.kit.need(problems, _k.gains(0) == 0 and int(list.back()["left"]) == 0, "the Gyrocopter over the building gained Shots on %d rows and ended with %d" % [_k.gains(0), list.back()["left"]])
	_q.kit.need(problems, float(list.back()["bottom"]) >= FLYING_HEIGHT and float(list.back()["speed"]) <= _settings.stopped_speed, "the model was %.2f m up at a real speed of %.4f" % [list.back()["bottom"], list.back()["speed"]])
	_q.kit.verdict("hovering_over_the_building_is_not_in_the_zone", problems, "a Gyrocopter with an empty gun hovering %d ticks over the middle of the west ammunition building (its model %.2f m up, the zone 2 m beside it) was never listed by the zone and gained no Shot" % [OVER_TICKS, float(list.back()["bottom"])])
	await _k.park(0)
