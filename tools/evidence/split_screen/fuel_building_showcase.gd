extends RefCounted
## Scenario fuel_building_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 023 on Map 01
## with the shipped data, every key a real key event. Eight moments, each read where its premise holds: depot_above (both Players' Trucks
## south of the depot, the view from above: both Fuel zones in both views), zone_chase (each Truck stopped short of the zone on its side, the
## chase view), filling_early and filling_late (each Player's low-tank Truck stopped in its own zone, the chase view, the Fuel bar rising,
## two frames 2 s apart), both_at_one_zone (Player 1's Motorbike and Player 2's Buggy side by side in the west zone, the view from above),
## gyro_hover (each Player's Gyrocopter hovering over its zone at its flying height, the chase view), old_spots_empty (the old canyon Can spot
## and the old salt-flat spot, empty, the view from above) and old_spots_parked (a low-tank Truck parked on each, its Fuel bar not rising). A SPLIT line per moment with frame=, the number of the PNG that shows it in a --write-movie recording, and what
## the moment's premise reads. No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK
## named premise, so an empty or false recording cannot pass as evidence. FUEL_MOMENTS (an environment variable of a run by hand) names the
## moments to play, "depot_above,filling". Implements: production/epics/wasteland-fire/story-023-fuel-building.md, Test Evidence (retained
## frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/fuel.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=fuel_building_showcase

const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const FUEL_BUILDING: bool = true
## Tokens enough that the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 900.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 20
## How far short of a zone's face (metres) a Truck stands for zone_chase, where the two Trucks stand for depot_above (south of the depot, a
## little either side of the middle line, facing north), and the share of a tank a Truck starts the fills with.
const SHORT_OF_THE_FACE: float = 9.0
const SOUTH_OF_THE_DEPOT: Vector3 = Vector3(4.0, 0.0, 15.0)
const LOW_TANK: float = 0.2
## Ticks after the put at which the early and the late frame of the fill are read: about 2 s apart.
const EARLY_TICKS: int = 48
const LATE_TICKS: int = 168
## Where the two Units stand across the west zone for both_at_one_zone, metres either side of its middle line.
const SIDE_BY_SIDE: float = 1.6
## Where the Units stand for old_spots_empty: this far west of the canyon spot and east of the salt-flat spot, metres; and the Fuel a Truck
## parked on an old spot may hold above what it started with after the wait (none: it only burns).
const OLD_SPOT_RUN: float = 10.0
const CANYON_SPOT: Vector3 = Vector3(-88.0, 0.0, -26.0)
const FLAT_SPOT_EAST: Vector3 = Vector3(62.0, 0.0, 14.0)
## A Gyrocopter hovers at least this high (its drawn model's lowest point), metres.
const FLYING_HEIGHT: float = 2.4

var _k: Kit23
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _wanted: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit23.new(harness)
	_q = _k.q()
	_wanted = OS.get_environment("FUEL_MOMENTS").split(",", false)
	await _k.a.swap().play(0, Quick.MOTORBIKE)
	await _k.a.swap().play(1, Quick.MOTORBIKE)
	await _q.kit.advance(HOLD_TICKS)
	await _depot()
	await _filling()
	await _both_at_one_zone()
	await _gyro_hover()
	await _old_spots()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d %s" % [_moments.size(), _q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Whether a named group of moments plays in this run.
func _plays(group: String) -> bool:
	return _wanted.is_empty() or _wanted.has(group)


## A Player's facing across the Map (Player 1 east, Player 2 west) and the zone on its side.
func _face(player: int) -> Vector3:
	return Vector3.RIGHT if player == 0 else Vector3.LEFT


## Whether a point is inside a Player's view and in front of its camera.
func _on_screen(player: int, point: Vector3) -> bool:
	var camera: ChaseCamera = _q.units.cameras[player]
	return camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(point)) and not camera.is_position_behind(point)


## The Fuel a Player's HUD bar reads now, and its text.
func _bar(player: int) -> float:
	return _k.fuel_bar(player).value


## depot_above and zone_chase: both Trucks south of the depot, the view from above (both zones in both views); then each stopped short of the
## zone on its side, the chase view.
func _depot() -> void:
	if not _plays("depot"):
		return
	await _k.put(0, Quick.TRUCK, Vector3(-SOUTH_OF_THE_DEPOT.x, 0.0, SOUTH_OF_THE_DEPOT.z), Vector3.FORWARD, 0.5)
	await _k.put(1, Quick.TRUCK, SOUTH_OF_THE_DEPOT, Vector3.FORWARD, 0.5)
	await _k.view(0, true)
	await _k.view(1, true)
	await _q.kit.advance(HOLD_TICKS)
	var seen: PackedStringArray = []
	for player: int in 2:
		for side: int in 2:
			_need(_on_screen(player, _k.centre(side)), "depot_above: zone %d's middle is not in Player %d's view" % [side, player + 1])
			seen.append("p%d_zone%d=%s" % [player + 1, side, _on_screen(player, _k.centre(side))])
	_line("depot_above", " ".join(seen))
	for player: int in 2:
		var side: float = -1.0 if player == 0 else 1.0
		await _k.put(player, Quick.TRUCK, _k.centre(player) + Vector3(side * SHORT_OF_THE_FACE, 0.0, 0.0), _face(player), 0.5)
	await _k.view(0, false)
	await _k.view(1, false)
	for player: int in 2:
		_need(_on_screen(player, _k.centre(player)), "zone_chase: the zone's middle is not in Player %d's view" % (player + 1))
	_line("zone_chase", "p1_zone_on_screen=%s p2_zone_on_screen=%s" % [_on_screen(0, _k.centre(0)), _on_screen(1, _k.centre(1))])


## filling_early and filling_late: each Player's Truck put in its zone with a low tank, the chase view; the Fuel bars at two moments 2 s apart.
func _filling() -> void:
	if not _plays("filling"):
		return
	await _k.view(0, false)
	await _k.view(1, false)
	for player: int in 2:
		await _k.put(player, Quick.TRUCK, _k.centre(player), _face(player), LOW_TANK)
	var started: int = _q.harness.ticks
	var bars: Array[float] = []
	for read: int in [EARLY_TICKS, LATE_TICKS]:
		while _q.harness.ticks - started < read - Kit23.SETTLE:
			await _q.kit.tick()
		var now: PackedFloat64Array = [_bar(0), _bar(1)]
		_need(now[0] > _k.unit(0).fuel_capacity * LOW_TANK and now[1] > _k.unit(1).fuel_capacity * LOW_TANK and now[0] < _k.unit(0).fuel_capacity and now[1] < _k.unit(1).fuel_capacity, "filling at %d ticks: the bars read %.1f and %.1f" % [read, now[0], now[1]])
		bars.append(now[0])
		_line("filling_early" if read == EARLY_TICKS else "filling_late", "bar_p1=%.1f bar_p2=%.1f listed_p1=%s listed_p2=%s" % [now[0], now[1], _k.zone(0).get_overlapping_bodies().has(_k.unit(0)), _k.zone(1).get_overlapping_bodies().has(_k.unit(1))])
	_need(bars[1] > bars[0], "filling: the bar went from %.1f to %.1f" % [bars[0], bars[1]])


## both_at_one_zone: Player 1's Motorbike and Player 2's Buggy side by side in the west zone, the view from above, both bars rising.
func _both_at_one_zone() -> void:
	if not _plays("both"):
		return
	await _k.view(0, true)
	await _k.view(1, true)
	await _k.put_many_recorded([
		{"player": 0, "type": Quick.MOTORBIKE, "at": _k.centre(0) + Vector3(0.0, 0.0, -SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": LOW_TANK},
		{"player": 1, "type": Quick.BUGGY, "at": _k.centre(0) + Vector3(0.0, 0.0, SIDE_BY_SIDE), "facing": Vector3.RIGHT, "fraction": LOW_TANK}], EARLY_TICKS + 12)
	var early: PackedFloat64Array = [_bar(0), _bar(1)]
	await _q.kit.advance(HOLD_TICKS)
	var late: PackedFloat64Array = [_bar(0), _bar(1)]
	_need(early[0] > _k.unit(0).fuel_capacity * LOW_TANK and early[1] > _k.unit(1).fuel_capacity * LOW_TANK and late[0] > early[0] and late[1] > early[1] and late[0] < _k.unit(0).fuel_capacity and late[1] < _k.unit(1).fuel_capacity, "both_at_one_zone: the bars read %s then %s" % [early, late])
	_line("both_at_one_zone", "bar_p1=%.1f bar_p2=%.1f listed_both=%s" % [late[0], late[1], _k.zone(0).get_overlapping_bodies().has(_k.unit(0)) and _k.zone(0).get_overlapping_bodies().has(_k.unit(1))])
	await _k.park(0)
	await _k.park(1)


## gyro_hover: each Player's Gyrocopter hovering over its zone, the chase view: its model about 2.5 m up, its Fuel rising.
func _gyro_hover() -> void:
	if not _plays("gyro"):
		return
	await _k.view(0, false)
	await _k.view(1, false)
	for player: int in 2:
		await _k.put(player, Quick.GYROCOPTER, _k.centre(player), _face(player), LOW_TANK)
	await _q.kit.advance(EARLY_TICKS)
	var heights: PackedFloat64Array = [Quick.model_bottom(_k.unit(0)), Quick.model_bottom(_k.unit(1))]
	_need(heights[0] >= FLYING_HEIGHT and heights[1] >= FLYING_HEIGHT and _bar(0) > _k.unit(0).fuel_capacity * LOW_TANK and _bar(1) > _k.unit(1).fuel_capacity * LOW_TANK, "gyro_hover: the models hover at %s and the bars read %.1f and %.1f" % [heights, _bar(0), _bar(1)])
	_line("gyro_hover", "model_p1=%.2f model_p2=%.2f bar_p1=%.1f bar_p2=%.1f listed_p1=%s listed_p2=%s" % [heights[0], heights[1], _bar(0), _bar(1), _k.zone(0).get_overlapping_bodies().has(_k.unit(0)), _k.zone(1).get_overlapping_bodies().has(_k.unit(1))])
	await _k.park(0)
	await _k.park(1)


## old_spots_empty and old_spots_parked: Player 1's Truck faces the empty canyon spot, Player 2's the empty salt-flat spot on its side, the view
## from above; then each Truck is parked ON its old spot with a low tank for two seconds: no Can, and no Fuel gained.
func _old_spots() -> void:
	if not _plays("old_spots"):
		return
	await _k.view(0, true)
	await _k.view(1, true)
	await _k.put(0, Quick.TRUCK, CANYON_SPOT + Vector3(-OLD_SPOT_RUN, 0.0, 0.0), Vector3.RIGHT, 0.5)
	await _k.put(1, Quick.TRUCK, FLAT_SPOT_EAST + Vector3(OLD_SPOT_RUN, 0.0, 0.0), Vector3.LEFT, 0.5)
	await _q.kit.advance(HOLD_TICKS * 3)
	var cans: int = _q.harness.get_tree().get_nodes_in_group(&"fuel_cans").size()
	_need(cans == 0 and _on_screen(0, CANYON_SPOT) and _on_screen(1, FLAT_SPOT_EAST), "old_spots_empty: %d Cans in the group, the spots on screen %s and %s" % [cans, _on_screen(0, CANYON_SPOT), _on_screen(1, FLAT_SPOT_EAST)])
	_line("old_spots_empty", "cans=%d p1_canyon_on_screen=%s p2_flat_on_screen=%s" % [cans, _on_screen(0, CANYON_SPOT), _on_screen(1, FLAT_SPOT_EAST)])
	await _k.put(0, Quick.TRUCK, CANYON_SPOT, Vector3.RIGHT, LOW_TANK)
	await _k.put(1, Quick.TRUCK, FLAT_SPOT_EAST, Vector3.LEFT, LOW_TANK)
	var started: PackedFloat64Array = [_bar(0), _bar(1)]
	await _q.kit.advance(LATE_TICKS)
	var now: PackedFloat64Array = [_bar(0), _bar(1)]
	_need(now[0] <= started[0] and now[1] <= started[1] and now[0] > 0.0 and now[1] > 0.0 and _k.unit(0).global_position.distance_to(CANYON_SPOT) < 0.05 and _k.unit(1).global_position.distance_to(FLAT_SPOT_EAST) < 0.05, "old_spots_parked: the bars went from %s to %s" % [started, now])
	_line("old_spots_parked", "bar_p1=%.1f(was %.1f) bar_p2=%.1f(was %.1f) cans=%d" % [now[0], started[0], now[1], started[1], cans])
