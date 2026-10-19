extends RefCounted
## Scenario turret_flying_sight of the split screen evidence harness (split_screen_harness.gd): a Turret sees and fires at a
## Gyrocopter flying over a cliff, while a cliff still hides a ground Unit behind it (Story 037). In the Turrets kit's arena (a
## flat floor far from Map 01 and a fixture Turret of Player 2, armed at Player 1's Unit), with a cliff block on the
## cliffs_water layer (32) 20 m ahead of the Turret. CHECK lines:
##  F1 over the cliff: Player 1's Gyrocopter hovering over the middle of the block is aimed at and fired on, and the
##     Shots reach it (its hit points drop).
##  F2 the old sight: the same with flying_sight_extra_mask set back to the cliffs (32), the Turret stays idle and fires
##     nothing, so F1 measures the change and could fail.
##  F3 a ground Unit behind the block: Player 1's Buggy standing behind the block, the block between it and the Turret,
##     is not aimed at and not fired on: the cliff still hides a ground target.
##  F4 the data: turret_stats.tres has sight_extra_mask 32 and flying_sight_extra_mask 0.
## Implements: production/epics/wasteland-fire/story-037-cliff-top-and-turret-sight.md AC-3 to AC-5.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=turret_flying_sight

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const HEIGHTS: bool = true
const TURRET_SEES_FLYING: bool = true
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
const WATCHDOG_SECONDS: float = 600.0
## The shipped Turret data.
const STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"
## The cliffs_water layer (project.godot layer 6).
const CLIFF_LAYER: int = 32
## The block: metres ahead of the Turret to its centre, its size (a Map 01 ridge is 2.5 m tall).
const BLOCK_AHEAD: float = 20.0
const BLOCK_SIZE: Vector3 = Vector3(10.0, 2.5, 10.0)
## Metres behind the block's far face a ground Unit stands.
const BEHIND: float = 3.0
## Ticks watched in each case (4 s: the Turret turns 90 degrees a second and fires every 0.8 s).
const WATCH_TICKS: int = 240

var _k: Kit13
var _block: StaticBody3D


func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	await _k.w.s.both_play()
	var turret: Turret = _k.make_arena(1)
	var ahead: Vector3 = Vector3.FORWARD
	var centre: Vector3 = turret.global_position + ahead * BLOCK_AHEAD
	_make_block(centre)
	var stats: TurretStats = load(STATS_PATH) as TurretStats
	_check_data(stats)
	var over: Dictionary = await _watch_unit(Quick.GYROCOPTER, centre, turret)
	_k.w.s.q.kit.verdict("F1_over_the_cliff", _need_fired(over, true), _line("Gyrocopter over the block", over))
	var shipped: int = stats.flying_sight_extra_mask
	stats.flying_sight_extra_mask = CLIFF_LAYER
	var old: Dictionary = await _watch_unit(Quick.GYROCOPTER, centre, turret)
	stats.flying_sight_extra_mask = shipped
	_k.w.s.q.kit.verdict("F2_old_sight_hides", _need_fired(old, false), _line("the same with the old sight (32)", old))
	var behind: Vector3 = centre + ahead * (BLOCK_SIZE.z * 0.5 + BEHIND)
	var ground: Dictionary = await _watch_unit(Quick.BUGGY, behind, turret)
	_k.w.s.q.kit.verdict("F3_ground_still_hidden", _need_fired(ground, false), _line("Buggy %.1f m behind the block" % BEHIND, ground))
	_k.free_arena()
	_block.free()
	_k.close()
	harness.finish("turret_flying_sight=1")


func _make_block(centre: Vector3) -> void:
	_block = StaticBody3D.new()
	_block.collision_layer = CLIFF_LAYER
	_block.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = BLOCK_SIZE
	shape.shape = box
	_block.add_child(shape)
	_k.w.s.q.units.units[0].get_parent().add_child(_block)
	_block.global_position = centre + Vector3.UP * (BLOCK_SIZE.y * 0.5)


func _check_data(stats: TurretStats) -> void:
	var problems: PackedStringArray = PackedStringArray()
	_k.w.s.q.kit.need(problems, stats.sight_extra_mask == CLIFF_LAYER, "sight_extra_mask %d" % stats.sight_extra_mask)
	_k.w.s.q.kit.need(problems, stats.flying_sight_extra_mask == 0, "flying_sight_extra_mask %d" % stats.flying_sight_extra_mask)
	_k.w.s.q.kit.verdict("F4_data", problems, "sight_extra_mask %d, flying_sight_extra_mask %d" % [stats.sight_extra_mask, stats.flying_sight_extra_mask])


## Stages Player 1's Unit of the type at the place, facing the Turret, then watches. Returns {aimed, shots, hp_from, hp_to}.
func _watch_unit(type_index: int, at: Vector3, turret: Turret) -> Dictionary:
	var facing: Vector3 = (turret.global_position - at) * Vector3(1.0, 0.0, 1.0)
	await _k.stage(0, type_index, at, facing.normalized())
	var unit: Unit = _k.w.s.q.units.units[0]
	var hp_from: float = unit.hit_points
	var result: Dictionary = await _watch_fixture(turret)
	result["hp_from"] = hp_from
	result["hp_to"] = unit.hit_points
	result["where"] = unit.global_position
	return result


## Watches the arena's fixture Turret (the kit's watch() covers the Map's four only): whether it aimed at some tick, and how
## many Shots it fired.
func _watch_fixture(turret: Turret) -> Dictionary:
	var mark: int = _k.firing.size()
	var aimed: Array[bool] = [false]
	var kit: Object = _k.w.s.q.kit
	kit.on_tick = func() -> void:
		aimed[0] = aimed[0] or turret.state == Turret.State.AIMING or turret.state == Turret.State.FIRING
	await kit.advance(WATCH_TICKS)
	kit.on_tick = Callable()
	return {"aimed": aimed[0], "shots": _k.fired_since(turret, mark)}


func _need_fired(result: Dictionary, fired: bool) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if fired:
		_k.w.s.q.kit.need(problems, bool(result["aimed"]) and int(result["shots"]) > 0, "aimed %s, %d Shots" % [result["aimed"], result["shots"]])
		_k.w.s.q.kit.need(problems, float(result["hp_to"]) < float(result["hp_from"]), "hit points %.0f -> %.0f" % [result["hp_from"], result["hp_to"]])
	else:
		_k.w.s.q.kit.need(problems, not bool(result["aimed"]) and int(result["shots"]) == 0, "aimed %s, %d Shots" % [result["aimed"], result["shots"]])
	return problems


func _line(what: String, result: Dictionary) -> String:
	return "%s at (%.1f, %.1f, %.1f), %d ticks: aimed %s, %d Shots, hit points %.0f -> %.0f" % [what, result["where"].x,
		result["where"].y, result["where"].z, WATCH_TICKS, result["aimed"], result["shots"], result["hp_from"], result["hp_to"]]
