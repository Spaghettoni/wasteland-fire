extends RefCounted
## Scenario badly_damaged_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 017 on Map 01 with the
## shipped data, every Player's act a real key event or a real Shot. Player 1's view is the view from above and Player 2's the chase view in every frame
## (the Slash key steps Player 2's view once), so both kinds of view show the smoke. A moment is one frame: column_motorbike_buggy and
## column_truck_gyrocopter (two badly damaged Units standing 12 m apart, each view showing both: the four types, a column of smoke over each, the Team
## accent of Player 1's Unit seen from above), moving_trails (a Motorbike and a Buggy driving side by side at half speed, the trail left behind),
## in_the_ford (a Buggy in the west ford), gyro_over_cliff and gyro_over_cover (a Gyrocopter risen over the canyon rock and a container, smoking from its
## drawn model), destroyed_flash and destroyed_smoke (a badly damaged Motorbike shot down: its own smoke gone, only the explosion's), respawned_clean (the
## Unit chosen at the respawn, no smoke). A SPLIT line per moment with frame=, the number of the PNG that shows it in a --write-movie recording, and what
## the moment's premise reads. No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named
## premise, so an empty or false recording cannot pass as evidence. Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md, Test
## Evidence (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/badly_damaged.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=badly_damaged_showcase

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
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
## Tokens enough that the destruction never ends the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 40, &"buggy": 40, &"truck": 40, &"gyrocopter": 40}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 600.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks the cameras need to settle after a view is stepped, the smoke needs to fill (a puff lives 72 ticks) and a driving pair runs.
const VIEW_TICKS: int = 60
const SMOKE_TICKS: int = 90
const DRIVE_TICKS: int = 130
## Where each Player's Unit stands in the open: x either side of the middle of the Map.
const SIDE_X: float = 6.0
## The lanes of the driving pair (z), where they start (x), the lane and the start of the ford run, and the ticks a Gyrocopter takes to rise.
const LANE_Z: float = 6.0
const DRIVE_X: float = -30.0
const FORD_LANE_Z: float = -16.0
const FORD_START_X: float = -70.0
const RISE_WAIT: int = 90
## The pieces a Gyrocopter is put over.
const RIDGE: String = "Cliffs/RockCanyonSouth"
const COVER: String = "Cover/Containers/ContainerWest"
## The ticks after the destruction at which its two frames are taken.
const FLASH_AGE: int = 6
const SMOKE_AGE: int = 40

var _k: Kit17
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit17.new(harness)
	await _k.e.t.w.s.both_play()
	await _k.q.kit.press_settled([KEY_SLASH] as Array[Key])
	await _k.q.kit.advance(VIEW_TICKS)
	await _pair(Quick.MOTORBIKE, Quick.BUGGY, "column_motorbike_buggy")
	await _pair(Quick.TRUCK, Quick.GYROCOPTER, "column_truck_gyrocopter")
	await _trails()
	await _ford()
	await _over(RIDGE, "gyro_over_cliff")
	await _over(COVER, "gyro_over_cover")
	await _destroyed()
	await _respawned()
	if not _problems.is_empty():
		_k.q.kit.verdict("premise", _problems, " | ".join(_moments))
	var made: int = _k.changes.size()
	_k.close()
	harness.finish("moments=%d changes=%d" % [_moments.size(), made])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_k.q.harness.scenario, _k.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_k.q.kit.need(_problems, holds, problem)


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in 2:
		found.append(_k.q.units.cameras[player].settings.resource_path.get_file())
	return found


## Both Units are brought to the edge of their type: they smoke from now on.
func _hurt(types: Array[int]) -> void:
	for player: int in 2:
		var unit: Unit = _k.unit(player)
		unit.apply_damage(unit.hit_points - _k.edge_of(types[player]))


## The reading of the smoke of both Units for a moment's line.
func _reads() -> String:
	var shown: Array[int] = [_k.smoke(0).shown_count() if _k.smoke(0) != null else -1, _k.smoke(1).shown_count() if _k.smoke(1) != null else -1]
	return "smoking=%s,%s puffs=%s,%s views=%s" % [_k.smoking(0), _k.smoking(1), shown[0], shown[1], _views()]


## Two Units of the given types standing 12 m apart facing each other, badly damaged, the smoke full.
func _pair(first: int, second: int, moment: String) -> void:
	await _k.e.fresh()
	await _k.t.clear(0)
	_k.q.units.retype(0, first, Vector3(-SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	_k.q.units.retype(1, second, Vector3(SIDE_X, 0.0, 0.0), Vector3.LEFT)
	await _k.q.kit.advance(Kit17.SETTLE + _k.t.w.longest_cadence())
	_hurt([first, second])
	await _k.q.kit.advance(SMOKE_TICKS)
	_need(_k.smoking(0) and _k.smoking(1), "%s: not both smoking" % moment)
	_line(moment, _reads())


## A Motorbike and a Buggy side by side, badly damaged, driving east at their half speeds: the trail behind each.
func _trails() -> void:
	await _k.e.fresh()
	await _k.t.clear(0)
	_k.q.units.retype(0, Quick.MOTORBIKE, Vector3(DRIVE_X, 0.0, -LANE_Z), Vector3.RIGHT)
	_k.q.units.retype(1, Quick.BUGGY, Vector3(DRIVE_X, 0.0, LANE_Z), Vector3.RIGHT)
	await _k.q.kit.advance(Kit17.SETTLE)
	_hurt([Quick.MOTORBIKE, Quick.BUGGY])
	_k.q.harness.drive(0, 1, 0)
	_k.q.harness.drive(1, 1, 0)
	await _k.q.kit.advance(DRIVE_TICKS)
	_need(_k.smoking(0) and _k.smoking(1) and _k.unit(0).current_speed > 0.0, "moving_trails: not both smoking and driving")
	_line("moving_trails", _reads() + " speeds=%.1f,%.1f" % [_k.unit(0).current_speed, _k.unit(1).current_speed])
	_k.q.harness.release_all()


## Player 1's Buggy, badly damaged, at the middle of the west ford at its half speed.
func _ford() -> void:
	await _k.e.fresh()
	await _k.t.clear(0)
	var ford: Node3D = _k.q.harness.split.find_child("FordWest", true, false) as Node3D
	_k.q.units.retype(0, Quick.BUGGY, Vector3(FORD_START_X, 0.0, FORD_LANE_Z), Vector3.RIGHT)
	await _k.q.kit.advance(Kit17.SETTLE)
	_hurt([Quick.BUGGY, Quick.BUGGY])
	_k.q.harness.drive(0, 1, 0)
	for _tick: int in 600:
		await _k.q.kit.tick()
		if _k.unit(0).global_position.x >= ford.global_position.x:
			break
	_need(_k.smoking(0) and absf(_k.unit(0).global_position.x - ford.global_position.x) < 1.0, "in_the_ford: not smoking in the ford")
	_line("in_the_ford", _reads() + " speed=%.2f x=%.1f" % [_k.unit(0).current_speed, _k.unit(0).global_position.x])
	_k.q.harness.release_all()


## Player 2's Gyrocopter risen over a piece of the Map, badly damaged: smoking from its drawn model, above the piece.
func _over(path: String, moment: String) -> void:
	await _k.e.fresh()
	await _k.t.clear(0)
	var piece: Node3D = _k.q.map.find(path) as Node3D
	var shape: GeometryInstance3D = piece as GeometryInstance3D
	if shape == null:
		shape = piece.get_node("Mesh") as GeometryInstance3D
	var box: AABB = shape.global_transform * shape.get_aabb()
	await _k.q.put(1, _k.q.units.stats(Quick.GYROCOPTER), Vector3(box.get_center().x, 0.0, box.get_center().z), Vector3.RIGHT)
	await _k.q.kit.advance(RISE_WAIT)
	_k.unit(1).apply_damage(_k.unit(1).hit_points - _k.edge_of(Quick.GYROCOPTER))
	await _k.q.kit.advance(SMOKE_TICKS)
	_need(_k.smoking(1) and Quick.model_bottom(_k.unit(1)) > box.end.y, "%s: not smoking above the piece" % moment)
	_line(moment, _reads() + " model_bottom=%.2f piece_top=%.2f" % [Quick.model_bottom(_k.unit(1)), box.end.y])


## Player 2's Motorbike, badly damaged and smoking, shot down by Player 1's real Shot: the explosion, its own smoke gone.
func _destroyed() -> void:
	await _k.face_off(Quick.MOTORBIKE, Quick.MOTORBIKE)
	var victim: Unit = _k.unit(1)
	victim.apply_damage(victim.hit_points - 1.0)
	await _k.q.kit.advance(SMOKE_TICKS)
	_need(_k.smoking(1), "destroyed: the Motorbike did not smoke before the Shot")
	var mark: int = _k.e.destroyed.size()
	await _k.q.tokens.shoot(0)
	await _k.e.wait_destroyed(mark)
	var d: Dictionary = _k.e.destroyed[mark] if _k.e.destroyed.size() > mark else {}
	_need(not d.is_empty() and not d["blast"].is_empty() and not _k.smoking(1), "destroyed: no destruction or no Explosion, or its smoke stands")
	for step: Array in [[FLASH_AGE, "destroyed_flash"], [SMOKE_AGE, "destroyed_smoke"]]:
		if not d.is_empty():
			await _k.q.kit.advance(maxi(step[0] - (Engine.get_physics_frames() - int(d["frame"])), 0))
			_need(_k.smoke(1) == null or _k.smoke(1).shown_count() == 0, "%s: puffs of the wreck's Unit show" % step[1])
			_line(step[1], "explosions=%d own_smoke_puffs=%d views=%s" % [_k.e.playing().size(), _k.smoke(1).shown_count() if _k.smoke(1) != null else 0, _views()])


## Player 1's Unit smoking in the middle of the Map while Player 2, whose Unit was shot down, chooses again: the new Unit has no smoke.
func _respawned() -> void:
	_k.unit(0).apply_damage(_k.unit(0).hit_points - _k.edge_of(Quick.MOTORBIKE))
	_need(await _k.q.tokens.spawn(1, Quick.TRUCK), "respawned_clean: Player 2's Unit did not come back")
	await _k.q.kit.advance(SMOKE_TICKS)
	_need(not _k.smoking(1) and _k.smoking(0) and _k.unit(1).hit_points == _k.unit(1).stats.max_hit_points, "respawned_clean: the new Unit smokes or is not whole")
	_line("respawned_clean", _reads())
