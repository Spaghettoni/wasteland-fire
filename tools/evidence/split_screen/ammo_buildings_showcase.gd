extends RefCounted
## Scenario ammo_buildings_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 024 on Map 01
## with the shipped data, every key a real key event. Eight moments, each read where its premise holds: building_above (each Player's Truck
## short of the ammunition zone on its side, the view from above: the building and its pale yellow zone in both views), building_chase (the
## same, the chase view), rearm_early and rearm_late (each Player's empty-gunned Unit stopped in its own zone, the chase view, the Ammo line
## rising, two frames 2 s apart), gyro_hover (each Player's empty-gunned Gyrocopter hovering over its zone at its flying height, the building
## beside it), gyro_over_building (each Gyrocopter over its building, its model clear of the crates, the zone ahead), refusals (Player 1's
## Truck refused a Mine in a Fuel zone, Player 2's in an ammunition zone, both notices on screen, the chase view) and kinds_above (Player
## 1 in the depot's west Fuel zone, Player 2 in the east ammunition zone, the view from above: the two kinds side by side). A SPLIT line
## per moment with frame=, the number of the PNG that shows it in a --write-movie recording, and what the moment's premise reads. No CHECK
## in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty or
## false recording cannot pass as evidence. The guns of the rearm and gyro moments are emptied by setting the Weapon's count to nought
## (and its report), not by firing the load away (20 s of recorded frames a gun, 80 s in all): the scenario ammo_buildings fires every
## load away with the real key and proves the rate; this one shows the look of the rearm. AMMOB_MOMENTS (an environment variable of a run
## by hand) names the moments to play, "building,rearm". Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md, Test Evidence (retained frames).
## Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/ammo.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo_buildings_showcase

const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")
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
const AMMO_BUILDINGS: bool = true
## Tokens enough that the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 20, &"buggy": 20, &"truck": 20, &"gyrocopter": 20}
## Simulated seconds this scenario may take (the loads fired away take 20 s each).
const WATCHDOG_SECONDS: float = 1500.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 20
## How far short of a zone's centre-side face (metres) a Truck stands for the building moments.
const SHORT_OF_THE_FACE: float = 6.0
## Ticks after the move at which the early and the late frame of the fill are read: about 2 s apart.
const EARLY_TICKS: int = 48
const LATE_TICKS: int = 168
## A Gyrocopter hovers at least this high (its drawn model's lowest point), metres.
const FLYING_HEIGHT: float = 2.4
## Ticks a refusal is given to reach the notice line before the frame is read.
const NOTICE_TICKS: int = 12
## The refusal's text.
const SUPPLY_TEXT: String = "No Mines at a supply building"

var _k: Kit24
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _wanted: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit24.new(harness)
	_q = _k.q()
	_wanted = OS.get_environment("AMMOB_MOMENTS").split(",", false)
	await _k.a().swap().play(0, Quick.MOTORBIKE)
	await _k.a().swap().play(1, Quick.MOTORBIKE)
	await _q.kit.advance(HOLD_TICKS)
	await _building()
	await _rearm()
	await _gyro()
	await _refusals()
	await _kinds()
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


## A Player's facing toward its building: Player 1 west, Player 2 east.
func _toward_building(player: int) -> Vector3:
	return Vector3.LEFT if player == 0 else Vector3.RIGHT


## Whether a point is inside a Player's view and in front of its camera.
func _on_screen(player: int, point: Vector3) -> bool:
	var camera: ChaseCamera = _q.units.cameras[player]
	return camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(point)) and not camera.is_position_behind(point)


## The Ammo line of a Player's view.
func _ammo(player: int) -> String:
	return _k.a().line(player)


## Both Players put in play as Units of the types given on their lane spots outside their Gates, their guns emptied (the file's header says
## how): they are alive and empty when they are brought to a place together.
func _both_empty(types: Array[int]) -> void:
	for player: int in 2:
		var spot: Vector3 = Quick.LANE_SPOT if player == 0 else Quick.mirrored(Quick.LANE_SPOT)
		await _k.f.put(player, types[player], spot, Vector3.RIGHT if player == 0 else Vector3.LEFT, 1.0)
		var gun: Weapon = _k.gun(player)
		gun.set(&"_left", 0)
		gun.ammo_changed.emit(0, gun.capacity)


## building_above and building_chase: each Player's Truck stands short of the zone on its side facing its building; first the view from above,
## then the chase view.
func _building() -> void:
	if not _plays("building"):
		return
	for player: int in 2:
		var side: int = player
		var at: Vector3 = _k.centre(_k.ammo_index(side)) - _toward_building(player) * (_k.zone(_k.ammo_index(side)).size.x / 2.0 + SHORT_OF_THE_FACE)
		await _k.f.put(player, Quick.TRUCK, at, _toward_building(player), 1.0)
	for above: bool in [true, false]:
		await _k.view(0, above)
		await _k.view(1, above)
		await _q.kit.advance(HOLD_TICKS)
		var seen: PackedStringArray = []
		for player: int in 2:
			var index: int = _k.ammo_index(player)
			_need(_on_screen(player, _k.centre(index)) and _on_screen(player, _k.building(player).global_position), "building_%s: the zone or the building is not in Player %d's view" % ["above" if above else "chase", player + 1])
			seen.append("p%d_zone=%s p%d_building=%s" % [player + 1, _on_screen(player, _k.centre(index)), player + 1, _on_screen(player, _k.building(player).global_position)])
		_line("building_above" if above else "building_chase", " ".join(seen))
	await _k.park(0)
	await _k.park(1)


## rearm_early and rearm_late: each Player's empty-gunned Unit (Player 1's Motorbike, Player 2's Buggy) put in its zone, the chase view; the Ammo
## lines at two moments 2 s apart.
func _rearm() -> void:
	if not _plays("rearm"):
		return
	await _both_empty([Quick.MOTORBIKE, Quick.BUGGY])
	await _k.view(0, false)
	await _k.view(1, false)
	_k.watch.clear()
	for player: int in 2:
		_k.move(player, _k.centre(_k.ammo_index(player)), _toward_building(player))
	var started: int = _q.harness.ticks
	var counts: Array[int] = []
	for read: int in [EARLY_TICKS, LATE_TICKS]:
		while _q.harness.ticks - started < read:
			await _q.kit.tick()
		var now: Array[int] = [_k.gun(0).shots_left, _k.gun(1).shots_left]
		_need(now[0] > 0 and now[1] > 0 and now[0] < _k.gun(0).capacity and now[1] < _k.gun(1).capacity, "rearming at %d ticks: the guns hold %s" % [read, now])
		_need(_ammo(0) == "Ammo %d / %d" % [now[0], _k.gun(0).capacity] and _ammo(1) == "Ammo %d / %d" % [now[1], _k.gun(1).capacity], "rearming at %d ticks: the lines read '%s' and '%s'" % [read, _ammo(0), _ammo(1)])
		counts.append(now[0])
		_line("rearm_early" if read == EARLY_TICKS else "rearm_late", "line_p1='%s' line_p2='%s' listed_p1=%s listed_p2=%s" % [_ammo(0), _ammo(1), _k.ammo_zone(0).get_overlapping_bodies().has(_k.unit(0)), _k.ammo_zone(1).get_overlapping_bodies().has(_k.unit(1))])
	_need(counts[1] > counts[0], "rearming: the load went from %d to %d" % [counts[0], counts[1]])
	await _k.park(0)
	await _k.park(1)


## gyro_hover and gyro_over_building: each Player's empty-gunned Gyrocopter hovering over its zone (its Ammo line rising, the building beside
## it), then over the middle of its building facing the zone, its model clear of the crates.
func _gyro() -> void:
	if not _plays("gyro"):
		return
	await _both_empty([Quick.GYROCOPTER, Quick.GYROCOPTER])
	await _k.view(0, false)
	await _k.view(1, false)
	for player: int in 2:
		_k.move(player, _k.centre(_k.ammo_index(player)), _toward_building(player))
	await _q.kit.advance(EARLY_TICKS)
	var heights: PackedFloat64Array = [Quick.model_bottom(_k.unit(0)), Quick.model_bottom(_k.unit(1))]
	_need(heights[0] >= FLYING_HEIGHT and heights[1] >= FLYING_HEIGHT and _k.gun(0).shots_left > 0 and _k.gun(1).shots_left > 0, "gyro_hover: the models hover at %s and the guns hold %d and %d" % [heights, _k.gun(0).shots_left, _k.gun(1).shots_left])
	_line("gyro_hover", "model_p1=%.2f model_p2=%.2f line_p1='%s' line_p2='%s'" % [heights[0], heights[1], _ammo(0), _ammo(1)])
	for player: int in 2:
		_k.move(player, _k.building(player).global_position, -_toward_building(player))
	await _q.kit.advance(HOLD_TICKS * 2)
	_need(Quick.model_bottom(_k.unit(0)) >= FLYING_HEIGHT and _k.unit(0).is_alive and _k.unit(1).is_alive, "gyro_over_building: the models are at %.2f and %.2f m" % [Quick.model_bottom(_k.unit(0)), Quick.model_bottom(_k.unit(1))])
	_line("gyro_over_building", "model_p1=%.2f model_p2=%.2f building_on_screen_p1=%s building_on_screen_p2=%s" % [Quick.model_bottom(_k.unit(0)), Quick.model_bottom(_k.unit(1)), _on_screen(0, _k.building(0).global_position), _on_screen(1, _k.building(1).global_position)])
	await _k.park(0)
	await _k.park(1)


## A Truck put at a place facing a way with its drop point at the middle of a zone, then one real press of the lay key.
func _press_at_zone(player: int, zone_index: int, facing: Vector3) -> void:
	var behind: float = _q.units.stats(Quick.TRUCK).mine_drop_offset.z
	await _k.mines().revive(player)
	await _k.mines().put(player, Quick.TRUCK, _k.centre(zone_index) + facing * behind, facing)
	await _k.mines().lay(player)


## refusals: Player 1's Truck pressed in the depot's west Fuel zone, Player 2's in the east ammunition zone; both notices on screen in the chase
## view.
func _refusals() -> void:
	if not _plays("refusals"):
		return
	await _k.view(0, false)
	await _k.view(1, false)
	await _press_at_zone(0, 0, Vector3.RIGHT)
	await _press_at_zone(1, _k.ammo_index(1), Vector3.RIGHT)
	await _q.kit.advance(NOTICE_TICKS)
	var notes: PackedStringArray = [_k.mines().note(0), _k.mines().note(1)]
	_need(notes[0] == SUPPLY_TEXT and notes[1] == SUPPLY_TEXT and _k.mines().layers[0].mines_left == _q.units.stats(Quick.TRUCK).mine_capacity and _k.mines().layers[1].mines_left == _q.units.stats(Quick.TRUCK).mine_capacity, "refusals: the notices read %s" % [notes])
	_line("refusals", "note_p1='%s' note_p2='%s' mines_p1=%d mines_p2=%d" % [notes[0], notes[1], _k.mines().layers[0].mines_left, _k.mines().layers[1].mines_left])
	await _k.park(0)
	await _k.park(1)


## kinds_above: Player 1's Truck in the depot's west Fuel zone and Player 2's in the east ammunition zone, the view from above: the two kinds
## of building and zone side by side.
func _kinds() -> void:
	if not _plays("kinds"):
		return
	await _k.view(0, true)
	await _k.view(1, true)
	await _k.f.put(0, Quick.TRUCK, _k.centre(0), Vector3.RIGHT, 1.0)
	await _k.f.put(1, Quick.TRUCK, _k.centre(_k.ammo_index(1)), Vector3.RIGHT, 1.0)
	await _q.kit.advance(HOLD_TICKS * 3)
	_need(_on_screen(0, _k.centre(0)) and _on_screen(1, _k.centre(_k.ammo_index(1))) and _on_screen(1, _k.building(1).global_position), "kinds_above: the Fuel zone is on Player 1's screen %s, the ammunition zone on Player 2's %s" % [_on_screen(0, _k.centre(0)), _on_screen(1, _k.centre(_k.ammo_index(1)))])
	_line("kinds_above", "p1_fuel_zone_on_screen=%s p2_ammo_zone_on_screen=%s p2_building_on_screen=%s" % [_on_screen(0, _k.centre(0)), _on_screen(1, _k.centre(_k.ammo_index(1))), _on_screen(1, _k.building(1).global_position)])
	await _k.park(0)
	await _k.park(1)
