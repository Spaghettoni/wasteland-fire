extends RefCounted
## Scenario camera_showcase of the split screen evidence harness (split_screen_harness.gd): the
## retained frames of Story 010 on Map 01 with the shipped data and the build's own cameras, every
## drive a real key event. Seven moments, each held, then read: round_start (both Units on their
## Bases in the view from above), open_flat (both driving on the salt flat), water_tower (each
## Player's Motorbike coming in toward the other Player's water tower and the Flag on its seat),
## flag_taken (both at the seat, each carrying the other's Flag), canyon (both on the canyon road
## between its rock walls), depot (a Truck and a Buggy at the Fuel Cans and tanks of the depot) and
## one_player_switched (Player 1 pressed Q, so Player 1 is in the chase view and Player 2 still
## above). A SPLIT line per moment with frame=, the number of the PNG that shows it in a
## --write-movie recording (the line counts back MOMENT_FRAME_LAG main-loop iterations, as
## tokens_showcase_kit.gd measured), and what the moment's premise reads: the view each camera is
## in and where the things that must be seen are on the screen. No CHECK in a normal run: it ends
## with RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so
## an empty or false recording cannot pass as evidence.
## Implements: production/epics/wasteland-fire/story-010-camera-from-above.md, Test Evidence (both
## views from above at the Round start, on the open flat, by a water tower with the Flag on its
## seat, over the canyon, at the depot, one Player switched to the chase view). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/camera.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=camera_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): staging, the Map, the Token kit.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario runs on the camera the build ships with, the view from above.
const SHIPPED_CAMERA: bool = true
## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The frames show Map 01's own Token stock: nothing here spends a Token.
const USE_MAP_STOCK: bool = true
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 90
## Ticks the open flat is driven before it is read.
const DRIVE_TICKS: int = 75
## Metres short of the other Player's Flag seat a Motorbike starts its approach.
const APPROACH: float = 10.0
## The cruise speed, m/s, and the speed below which a Unit counts as stopped, for the run to the
## Flag.
const CRUISE: float = 8.0
const STOP: float = 1.0
## Ticks the run to the Flags may take.
const FLAG_LIMIT_TICKS: int = 900
## The canyon road's centre line z, metres, and how far from the middle each Unit stands.
const ROAD_Z: float = -28.0
const ROAD_HALF_GAP: float = 14.0
## How far from the depot's middle the two Units stand, metres.
const DEPOT_HALF_GAP: float = 12.0
## Player 1's camera key.
const KEY_CAMERA_1: Key = KEY_Q

var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner
## awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	await _round_start()
	await _open_flat()
	await _water_tower()
	await _flag_taken()
	await _canyon()
	await _depot()
	await _one_player_switched()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_q.close()
	_q.harness.finish("moments=%d %s" % [_moments.size(), _q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(name: String, reads: String) -> void:
	_moments.append(name)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, name, reads])


## Both Units are on their Bases, in play, in the view from above. A coroutine.
func _round_start() -> void:
	await _q.kit.advance(HOLD_TICKS)
	_line("round_start", _views())
	for player: int in Kit.PLAYERS:
		_must_see("round_start", player, _q.units.units[player].global_position, "its Unit")
	_expect_views("round_start", [true, true])


## Both Motorbikes drive on the open flat, the throttle held; read mid-drive. A coroutine.
func _open_flat() -> void:
	var types: Array[int] = [Quick.MOTORBIKE, Quick.MOTORBIKE]
	await _q.map.stage(types, [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)], [Vector3.RIGHT, Vector3.LEFT], true)
	_q.harness.drive(Harness.PLAYER_1, 1, 0)
	_q.harness.drive(Harness.PLAYER_2, 1, 0)
	await _q.kit.advance(DRIVE_TICKS)
	_line("open_flat", "%s speeds=%.1f,%.1f" % [_views(), _q.units.units[0].current_speed, _q.units.units[1].current_speed])
	_expect_views("open_flat", [true, true])
	_q.harness.release_all()


## Each Player's Motorbike a few metres short of the other Player's Flag seat, facing it; read once
## the cameras have settled. A coroutine.
func _water_tower() -> void:
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		var enemy: Base = _enemy_base(player)
		var seat: Vector3 = enemy.flag_seat.global_position
		var way: Vector3 = (seat - enemy.spawn_point.global_position).normalized()
		spots.append(seat - way * APPROACH)
		facings.append(way)
	await _q.map.stage([Quick.MOTORBIKE, Quick.MOTORBIKE] as Array[int], spots, facings, true)
	await _q.kit.advance(HOLD_TICKS)
	_line("water_tower", _views())
	for player: int in Kit.PLAYERS:
		_must_see("water_tower", player, _enemy_base(player).flag_seat.global_position + Vector3.UP, "the Flag on its seat")
	_expect_views("water_tower", [true, true])


## Both Motorbikes drive on to the seats and each takes the other's Flag; read when both are
## stopped at the seat carrying it. A coroutine.
func _flag_taken() -> void:
	var count: int = await _q.map.drive_to_flags(CRUISE, STOP, FLAG_LIMIT_TICKS)
	await _q.kit.advance(HOLD_TICKS)
	var carrying: Array[bool] = []
	for player: int in Kit.PLAYERS:
		carrying.append(_q.controller.flag_status(player) == MatchController.FlagStatus.CARRYING_ENEMY)
	_line("flag_taken", "%s ticks=%d carrying=%s" % [_views(), count, carrying])
	_q.kit.need(_problems, count > 0 and carrying == [true, true], "flag_taken: the run took %d ticks and the Players carry %s" % [count, carrying])
	for player: int in Kit.PLAYERS:
		_must_see("flag_taken", player, _q.units.units[player].global_position, "its Unit at the seat")
	_expect_views("flag_taken", [true, true])
	_q.harness.release_all()


## Both Units on the canyon road facing each other; read once settled. A coroutine.
func _canyon() -> void:
	var spots: Array[Vector3] = [Vector3(-ROAD_HALF_GAP, 0.0, ROAD_Z), Vector3(ROAD_HALF_GAP, 0.0, ROAD_Z)]
	await _q.map.stage([Quick.BUGGY, Quick.MOTORBIKE] as Array[int], spots, [Vector3.RIGHT, Vector3.LEFT] as Array[Vector3], true)
	await _q.kit.advance(HOLD_TICKS)
	_line("canyon", _views())
	for player: int in Kit.PLAYERS:
		_must_see("canyon", player, _q.units.units[player].global_position, "its Unit")
	_expect_views("canyon", [true, true])


## A Truck and a Buggy at the depot's middle Fuel Can and tanks; read once settled. A coroutine.
func _depot() -> void:
	var middle: Vector3 = (_q.map.find("Depot/FuelCanDepot3") as Node3D).global_position
	var spots: Array[Vector3] = [middle + Vector3(-DEPOT_HALF_GAP, 0.0, 0.0), middle + Vector3(DEPOT_HALF_GAP, 0.0, 0.0)]
	await _q.map.stage([Quick.TRUCK, Quick.BUGGY] as Array[int], spots, [Vector3.RIGHT, Vector3.LEFT] as Array[Vector3], true)
	await _q.kit.advance(HOLD_TICKS)
	_line("depot", _views())
	for player: int in Kit.PLAYERS:
		_must_see("depot", player, middle + Vector3.UP, "the middle Fuel Can")
	_expect_views("depot", [true, true])


## Both Motorbikes back on the open flat; Player 1 presses Q, so its view is the chase view and
## Player 2's is still the view from above. A coroutine.
func _one_player_switched() -> void:
	var types: Array[int] = [Quick.MOTORBIKE, Quick.MOTORBIKE]
	await _q.map.stage(types, [Quick.LANE_SPOT, Quick.mirrored(Quick.LANE_SPOT)], [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.press_settled([KEY_CAMERA_1] as Array[Key])
	await _q.kit.advance(HOLD_TICKS)
	_line("one_player_switched", _views())
	_expect_views("one_player_switched", [false, true])


## The Base of the other Player (the one whose Flag a Player takes).
func _enemy_base(player: int) -> Base:
	var field: MapField = _q.harness.split.field
	return field.player_2_base if player == 0 else field.player_1_base


## The view each camera is in, for the moment's line: "p1=above p2=chase".
func _views() -> String:
	var names: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var settings: ChaseCameraSettings = _q.units.cameras[player].settings
		names.append("p%d=%s" % [player + 1, "above" if settings.distance > 0.0 else "chase"])
	return " ".join(names)


## Files a problem unless each camera is in the view the list says (true: from above).
func _expect_views(moment: String, from_above: Array[bool]) -> void:
	for player: int in Kit.PLAYERS:
		var above: bool = _q.units.cameras[player].settings.distance > 0.0
		_q.kit.need(_problems, above == from_above[player], "%s: p%d's camera is %s" % [moment, player + 1, "above" if above else "chase"])


## Files a problem unless the point is inside the Player's view and in front of its camera.
func _must_see(moment: String, player: int, point: Vector3, what: String) -> void:
	var camera: ChaseCamera = _q.units.cameras[player]
	var on_screen: Vector2 = camera.unproject_position(point)
	var inside: bool = camera.get_viewport().get_visible_rect().has_point(on_screen) and not camera.is_position_behind(point)
	_q.kit.need(_problems, inside, "%s: %s is not in p%d's view (screen %s)" % [moment, what, player + 1, on_screen])
