extends RefCounted
## Scenario explosions_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of
## Story 016 on Map 01 with the shipped data, every Player's act a real key event where a Player acts. Player 1's view is
## the view from above and Player 2's the chase view in every frame (the Slash key steps Player 2's view once), so both
## kinds of view show every explosion. A moment is one frame at an age of an Explosion: shot_flash and shot_fireball (a
## Motorbike shot down by the other Player), turret_buggy (a Buggy taken by a Turret), mine_truck_fireball (a Truck on a
## live Mine) and mine_motorbike_both (a Motorbike on one, the Mine's own larger flash showing round the explosion's still
## small fireball), self_destruct_fireball, self_destruct_chunks and self_destruct_smoke_thin (a Truck's, from the blast to
## the smoke thinning), gyro_dry (a Gyrocopter that ran dry while it hovered), gyro_over_cover (a Gyrocopter risen over a
## container, in the air above it), carrier_wreck_fireball and carrier_wreck_smoke (a Carrier's wreck: the Flag dropped
## there reads through the smoke), three_at_once (both Trucks and a third), round_over_a and round_over_b (the explosion
## that ends a Round, playing under the Round-over screen, two frames apart), swap_no_blast (a Swap at the own Base: no
## blast) and after_r (none left). A SPLIT line per moment with frame=, the number of the PNG that shows it in a
## --write-movie recording, and what the moment's premise reads. No CHECK in a normal run: it ends with RESULT ok; a moment
## whose premise does not hold prints one failing CHECK named premise, so an empty or false recording cannot pass as
## evidence. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md, Test Evidence (retained frames).
## Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/explosions.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=explosions_showcase

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
## Tokens enough that the destructions of the moments never end the Round (the loss moment sets its own).
const STOCK_COUNTS: Dictionary = {&"motorbike": 40, &"buggy": 40, &"truck": 40, &"gyrocopter": 40}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 600.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The ages, in ticks after the blast, the frames are taken at: the flash, the fireball near its peak, the chunks in the air
## and the smoke thinning near the end.
const FLASH_AGE: int = 4
const FIREBALL_AGE: int = 14
const CHUNKS_AGE: int = 50
const THIN_AGE: int = 105
## The age at which a Motorbike's fireball is still smaller than a Mine's flash (the Mine's flash shows round it).
const MINE_RING_AGE: int = 8
## The two frames under the Round-over screen, in ticks after the blast.
const OVER_AGES: Array[int] = [8, 24]
## Ticks the cameras need to settle after a view is stepped.
const VIEW_TICKS: int = 60
## The Round-over screen's stock of Motorbikes, and the container of the cover moment.
const LAST_MOTORBIKE: int = 1
const COVER: String = "Cover/Containers/ContainerWest"
const RISE_WAIT: int = 90
const SMALL_TANK: float = 0.03
## Where each Player's Unit stands in the open for a moment: x either side of the middle of the Map.
const SIDE_X: float = 6.0

var _k: Kit16
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit16.new(harness)
	await _k.t.w.s.both_play()
	await _k.q.kit.press_settled([KEY_SLASH] as Array[Key])
	await _k.q.kit.advance(VIEW_TICKS)
	await _shot()
	await _turret()
	await _mine()
	await _self_destruct()
	await _gyro_dry()
	await _gyro_over_cover()
	await _carrier()
	await _three_at_once()
	await _swap()
	await _round_over()
	await _after_r()
	if not _problems.is_empty():
		_k.q.kit.verdict("premise", _problems, " | ".join(_moments))
	var made: int = _k.blasts.size()
	_k.close()
	harness.finish("moments=%d explosions=%d" % [_moments.size(), made])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_k.q.harness.scenario, _k.q.harness.time(),
		Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_k.q.kit.need(_problems, holds, problem)


## Waits until `age` ticks after the destruction `d` and prints the moment, reading how many Explosions play.
func _at(d: Dictionary, age: int, moment: String) -> void:
	_need(not d.is_empty() and not d["blast"].is_empty(), "%s: no destruction or no Explosion" % moment)
	if d.is_empty():
		return
	await _k.q.kit.advance(maxi(age - (Engine.get_physics_frames() - int(d["frame"])), 0))
	_line(moment, "type=%s age=%d explosions=%d views=%s" % [d["type"], Engine.get_physics_frames() - int(d["frame"]), _k.playing().size(), _views()])


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in 2:
		found.append(_k.q.units.cameras[player].settings.resource_path.get_file())
	return found


## Both Units in the open, 12 m apart, Player 1's Motorbike facing Player 2's Unit of a type (a duel, without the one hit
## point): every cause but the Turret's and the Mine's starts here.
func _stage(victim_type: int) -> void:
	await _k.fresh()
	await _k.t.clear(0)
	_k.q.units.retype(0, Quick.MOTORBIKE, Vector3(-SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	_k.q.units.retype(1, victim_type, Vector3(SIDE_X, 0.0, 0.0), Vector3.LEFT)
	await _k.q.kit.advance(Kit16.SETTLE + 15)


func _shot() -> void:
	var d: Dictionary = await _k.shot_kill(Quick.MOTORBIKE)
	await _at(d, FLASH_AGE, "shot_flash")
	await _at(d, FIREBALL_AGE, "shot_fireball")


func _turret() -> void:
	await _k.fresh()
	var turret: Turret = _k.t.turret(0, Kit13.RIGHT)
	_k.t.w.s.flags.teleport(0, _k.t.w.point(0, Vector3(0.0, 0.0, -27.0)), _k.t.w.way(0, Vector3.BACK))
	await _k.t.stage(1, Quick.BUGGY, _k.t.ahead(turret, 0, Kit16.TURRET_AHEAD), -_k.t.w.way(0, Vector3.FORWARD))
	_k.t.w.s.flags.teleport(0, _k.t.w.point(0, Vector3(0.0, 0.0, -27.0)), _k.t.w.way(0, Vector3.BACK))
	var before: int = _k.destroyed.size()
	_k.q.units.units[1].apply_damage(_k.q.units.units[1].hit_points - Kit16.ONE_SHOT)
	await _k.wait_destroyed(before)
	await _at(_k.destroyed[before] if _k.destroyed.size() > before else {}, FIREBALL_AGE, "turret_buggy")


func _mine() -> void:
	await _mine_on(Quick.TRUCK, FIREBALL_AGE, "mine_truck_fireball")
	await _mine_on(Quick.MOTORBIKE, MINE_RING_AGE, "mine_motorbike_both")


## Player 2's Unit of a type is put onto a live Mine and destroyed by it; read at an age, the Mine's own flash showing.
func _mine_on(victim_type: int, age: int, moment: String) -> void:
	await _stage(victim_type)
	await _k.t.park(1)
	_k.q.units.retype(0, Quick.MOTORBIKE, Vector3(-SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	var mine: Mine = await _k.live_mine(Vector3(SIDE_X, 0.0, 0.0), 0)
	var before: int = _k.destroyed.size()
	_k.q.units.retype(1, victim_type, Vector3(SIDE_X, 0.0, 0.0), Vector3.LEFT)
	await _k.wait_destroyed(before)
	var d: Dictionary = _k.destroyed[before] if _k.destroyed.size() > before else {}
	await _at(d, age, moment)
	_need(is_instance_valid(mine) and mine.is_inside_tree() and mine.flash.visible, "%s: the Mine's own flash is not showing" % moment)
	await _k.clear_mines()


func _self_destruct() -> void:
	await _stage(Quick.TRUCK)
	var before: int = _k.destroyed.size()
	await _k.q.tokens.destruct(1)
	await _k.wait_destroyed(before)
	var d: Dictionary = _k.destroyed[before] if _k.destroyed.size() > before else {}
	await _at(d, FIREBALL_AGE, "self_destruct_fireball")
	await _at(d, CHUNKS_AGE, "self_destruct_chunks")
	await _at(d, THIN_AGE, "self_destruct_smoke_thin")


func _gyro_dry() -> void:
	await _k.fresh()
	await _k.t.clear(0)
	_k.q.units.retype(0, Quick.MOTORBIKE, Vector3(-SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	var before: int = _k.destroyed.size()
	await _k.q.put(1, _k.q.small_tank(Quick.GYROCOPTER, SMALL_TANK), Vector3(SIDE_X, 0.0, 0.0), Vector3.LEFT)
	await _k.wait_destroyed(before)
	await _at(_k.destroyed[before] if _k.destroyed.size() > before else {}, FIREBALL_AGE, "gyro_dry")


func _gyro_over_cover() -> void:
	await _k.fresh()
	await _k.t.clear(0)
	var piece: Node3D = _k.q.map.find(COVER) as Node3D
	var at: Vector3 = Vector3(piece.global_position.x, 0.0, piece.global_position.z)
	_k.q.units.retype(0, Quick.MOTORBIKE, at + Vector3(-2.0 * SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	await _k.q.put(1, _k.q.units.stats(Quick.GYROCOPTER), at, Vector3.LEFT)
	await _k.q.kit.advance(RISE_WAIT)
	var before: int = _k.destroyed.size()
	await _k.q.tokens.destruct(1)
	await _k.wait_destroyed(before)
	await _at(_k.destroyed[before] if _k.destroyed.size() > before else {}, FIREBALL_AGE, "gyro_over_cover")


## Base A's Turrets and Gate wall down, Player 2's Motorbike carrying Base A's Flag backed out of the box: the Carrier.
func _make_carrier() -> bool:
	await _k.fresh()
	await _k.t.restore_all()
	for side: int in Kit13.NAMES.size():
		_k.t.turret(0, side).destroy()
	_k.t.w.wall(0, Walls.GATE).destroy()
	await _k.q.kit.advance(Kit16.SETTLE)
	var taken: bool = await _k.t.w.take_flag(1, 0, Walls.GATE)
	await _k.t.w.back_out(1, 0, Walls.GATE)
	return taken


func _carrier() -> void:
	var taken: bool = await _make_carrier()
	_need(taken, "carrier_wreck: Player 2 did not take Base A's Flag")
	var out: Vector3 = _k.t.w.way(0, Walls.OUT[Walls.GATE]).normalized()
	_k.t.w.s.flags.teleport(0, _k.q.units.units[1].global_position + out * 8.0, -out)
	await _k.q.kit.advance(Kit16.SETTLE)
	var before: int = _k.destroyed.size()
	await _k.q.tokens.destruct(1)
	await _k.wait_destroyed(before)
	var d: Dictionary = _k.destroyed[before] if _k.destroyed.size() > before else {}
	await _at(d, FIREBALL_AGE, "carrier_wreck_fireball")
	await _at(d, CHUNKS_AGE, "carrier_wreck_smoke")
	await _k.t.restore_all()


func _three_at_once() -> void:
	await _stage(Quick.TRUCK)
	_k.q.units.retype(0, Quick.TRUCK, Vector3(-SIDE_X, 0.0, 0.0), Vector3.RIGHT)
	await _k.q.kit.advance(Kit16.SETTLE)
	var before: int = _k.destroyed.size()
	for unit: Unit in _k.q.units.units:
		unit.destroy()
	var stats: UnitStats = _k.q.units.stats(Quick.TRUCK)
	var blast: Explosion = _k.q.harness.split.explosion_scene.instantiate() as Explosion
	_k.q.units.units[0].get_parent().add_child(blast)
	blast.blast(Vector3(0.0, stats.collision_center.y, SIDE_X), maxf(stats.collision_size.x, stats.collision_size.z), 0.0)
	await _at(_k.destroyed[before] if _k.destroyed.size() > before else {}, FIREBALL_AGE, "three_at_once")
	_need(_k.playing().size() == 3, "three_at_once: %d Explosions play, not three" % _k.playing().size())


func _swap() -> void:
	await _k.fresh()
	var s: Swap = _k.t.w.s
	var mark: Vector2i = _k.mark()
	await s.enter(1)
	await s.wait_swappable(1)
	await _k.q.tokens.destruct(1)
	await _k.q.kit.advance(FIREBALL_AGE)
	_need(_k.blasts.size() == mark.x and _k.playing().is_empty(), "swap_no_blast: %d Explosions came" % (_k.blasts.size() - mark.x))
	_line("swap_no_blast", "explosions=%d panels=%s" % [_k.playing().size(), [_k.q.units.panels[0].visible, _k.q.units.panels[1].visible]])


## The Round ends by a delivery, R starts one with a Motorbike each, and Player 2's last one Self-destructs: its Explosion
## plays on under the Round-over screen, read at two ages.
func _round_over() -> void:
	var taken: bool = await _make_carrier()
	_need(taken and await _k.t.w.deliver(1) and _k.q.controller.is_round_over(), "round_over: the Round did not end by a delivery")
	_k.q.harness.split.field.token_stock.counts[&"motorbike"] = LAST_MOTORBIKE
	await _k.t.w.restart()
	await _stage(Quick.MOTORBIKE)
	var before: int = _k.destroyed.size()
	await _k.q.tokens.destruct(1)
	await _k.wait_destroyed(before)
	var d: Dictionary = _k.destroyed[before] if _k.destroyed.size() > before else {}
	_need(_k.q.controller.is_round_over() and _k.q.harness.get_tree().paused, "round_over: the Round is not over under the pause")
	await _at(d, OVER_AGES[0], "round_over_a")
	await _at(d, OVER_AGES[1], "round_over_b")


func _after_r() -> void:
	_k.q.harness.split.field.token_stock.counts[&"motorbike"] = int(STOCK_COUNTS[&"motorbike"])
	var started: bool = await _k.q.tokens.restart()
	await _k.t.w.s.both_play()
	await _k.q.kit.advance(VIEW_TICKS)
	_need(started and _k.playing().is_empty(), "after_r: R started %s and %d Explosions play" % [started, _k.playing().size()])
	_line("after_r", "explosions=%d views=%s" % [_k.playing().size(), _views()])
