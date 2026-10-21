extends RefCounted
## Scenario bushes of the split screen evidence harness (split_screen_harness.gd): the Bushes of Map 02 (Story 038). The launch
## scene plays Map 02 (MAP_SCENE) with every shipped piece of the game. CHECK lines:
##  B1 hiding: Player 2's Motorbike 3.5 m behind a Bush, seen from Player 1's west outpost Turret about 23 m away, is not fired on; with
##     the Bush flattened the same Turret fires on it.
##  B2 Shots pass: Player 1's Buggy on the near side of a standing Bush fires through it and hits Player 2's Truck behind it.
##  B3 the Motorbike passes: driven through the middle Bush it comes out on the far side and the Bush still stands.
##  B4 Buggy and Truck flatten, the Gyrocopter flies over: each driven through the middle Bush (stood again before each run)
##     comes out on the far side; after the Buggy and the Truck the Bush is flat and its sight body is off its layer; after the
##     Gyrocopter it stands.
##  B5 the restart: every Bush flattened, then the Round starts again: all 9 stand, their sight bodies on the sight layer.
##  B6 the data: only the Buggy and the Truck crush Bushes; the Turret's ground sight holds the sight layer (160) and its flying
##     sight does not (0); the project names layer 8 "sight"; no Unit's mask and no Shot's mask holds it.
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-6 and AC-8.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=bushes

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const MINES: bool = true
const TURRET_LOOKS: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const USE_MAP_STOCK: bool = true
const BUSHES: bool = true
const MAP_CHOICE: bool = true
const WATCHDOG_SECONDS: float = 600.0

## The physics layer of a Bush's sight body (project.godot layer 8, "sight").
const SIGHT_LAYER: int = 128
const SIGHT_SETTING: String = "layer_names/3d_physics/layer_8"
const SIGHT_NAME: String = "sight"
const GROUND_SIGHT: int = 160
## The hiding test: the Bush (the top half's first, schematic (30, 92)) and how far behind it the target stands.
const HIDE_BUSH: String = "Cover/BushNorth1"
const BEHIND: float = 3.5
## A Truck is 4.6 m long, so it stands farther behind the Bush, clear of its trigger.
const BEHIND_TRUCK: float = 6.0
const IN_FRONT: float = 6.0
const WATCH_TICKS: int = 240
const FIRE_TICKS: int = 45
## The drive-through test: the middle Bush, a start 8 m west of it facing east and the ticks driven.
const MIDDLE_BUSH: String = "Cover/BushMiddle"
const RUN_FROM: float = 8.0
const RUN_TICKS: int = 180
## Who crushes: by type index.
const CRUSHERS: Array[int] = [1, 2]

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _check_hiding()
	await _check_shots_pass()
	await _check_drives()
	await _check_restart()
	_check_data()
	_m.h.finish("bushes=%d" % _m.field.bushes.size())


func _turret() -> Turret:
	return _m.field.player_1_outposts[0] as Turret


func _check_hiding() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var bush: Bush = _m.piece(HIDE_BUSH) as Bush
	var turret: Turret = _turret()
	var way: Vector3 = Vector3(bush.global_position.x - turret.global_position.x, 0.0, bush.global_position.z - turret.global_position.z).normalized()
	var spot: Vector3 = bush.global_position + way * BEHIND
	var fired: Array[int] = [0]
	turret.fired.connect(func(_shot: Shot) -> void: fired[0] += 1)
	await _m.park(0)
	await _m.put(1, M2.MOTORBIKE, spot, -way)
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var hidden_shots: int = fired[0]
	bush.flatten()
	await _m.kit.advance(M2.SETTLE_TICKS)
	await _m.put(1, M2.MOTORBIKE, spot, -way)
	fired[0] = 0
	await _m.kit.advance(WATCH_TICKS)
	var open_shots: int = fired[0]
	bush.restore()
	await _m.park(1)
	var distance: float = turret.global_position.distance_to(spot)
	_m.kit.need(problems, hidden_shots == 0, "behind the standing Bush the Turret fired %d Shots" % hidden_shots)
	_m.kit.need(problems, open_shots > 0, "with the Bush flat the Turret fired %d Shots" % open_shots)
	_m.kit.verdict("B1_hiding", problems, "target %.1f m from the Turret: %d Shots behind the Bush, %d with it flat" % [distance, hidden_shots, open_shots])


func _check_shots_pass() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var bush: Bush = _m.piece(HIDE_BUSH) as Bush
	var turret: Turret = _turret()
	var way: Vector3 = Vector3(bush.global_position.x - turret.global_position.x, 0.0, bush.global_position.z - turret.global_position.z).normalized()
	var target: Vector3 = bush.global_position + way * BEHIND_TRUCK
	var shooter: Vector3 = bush.global_position - way * IN_FRONT
	await _m.put(1, M2.TRUCK, target, way)
	await _m.put(0, M2.BUGGY, shooter, way)
	var before: float = _m.units[1].hit_points
	var key: Key = _m.h.fire_key(0)
	_m.h.set_key(key, true)
	await _m.kit.advance(FIRE_TICKS)
	_m.h.set_key(key, false)
	await _m.kit.advance(M2.SETTLE_TICKS * 10)
	var after: float = _m.units[1].hit_points
	_m.kit.need(problems, bush.is_standing, "the Bush fell")
	_m.kit.need(problems, after < before, "Player 2's Truck behind the Bush kept %.1f of %.1f hit points" % [after, before])
	await _m.park(0)
	await _m.park(1)
	_m.kit.verdict("B2_shots_pass", problems, "Truck behind the Bush %.1f -> %.1f hit points, the Bush standing %s" % [before, after, bush.is_standing])


func _check_drives() -> void:
	var problems_moto: PackedStringArray = PackedStringArray()
	var problems: PackedStringArray = PackedStringArray()
	var bush: Bush = _m.piece(MIDDLE_BUSH) as Bush
	var lines: PackedStringArray = PackedStringArray()
	await _m.park(1)
	for type_index: int in [M2.MOTORBIKE, M2.BUGGY, M2.TRUCK, M2.GYROCOPTER]:
		bush.restore()
		await _m.kit.advance(M2.SETTLE_TICKS)
		await _m.put(0, type_index, bush.global_position + Vector3.LEFT * RUN_FROM, Vector3.RIGHT)
		await _m.drive_for(0, 1, 0, RUN_TICKS)
		await _m.kit.advance(M2.SETTLE_TICKS)
		var past: float = _m.units[0].global_position.x - bush.global_position.x
		var sight_layer: int = bush.sight_body.collision_layer
		var crushes: bool = CRUSHERS.has(type_index)
		var target: PackedStringArray = problems if type_index != M2.MOTORBIKE else problems_moto
		_m.kit.need(target, past > RUN_FROM, "the %s ended %.1f m past the Bush" % [_m.stats(type_index).type_id, past])
		_m.kit.need(target, bush.is_standing != crushes, "after the %s the Bush stands: %s" % [_m.stats(type_index).type_id, bush.is_standing])
		_m.kit.need(target, (sight_layer == 0) == crushes, "after the %s the sight body's layer is %d" % [_m.stats(type_index).type_id, sight_layer])
		lines.append("%s %.1f m past, standing %s, sight layer %d" % [_m.stats(type_index).type_id, past, bush.is_standing, sight_layer])
	bush.restore()
	await _m.park(0)
	_m.kit.verdict("B3_motorbike_passes", problems_moto, lines[0])
	_m.kit.verdict("B4_flatten", problems, "; ".join(lines.slice(1)))


func _check_restart() -> void:
	var problems: PackedStringArray = PackedStringArray()
	for bush: Bush in _m.field.bushes:
		bush.flatten()
	await _m.kit.advance(M2.SETTLE_TICKS)
	var flat: int = 0
	for bush: Bush in _m.field.bushes:
		flat += 0 if bush.is_standing else 1
	_m.controller.round_started.emit()
	await _m.kit.advance(M2.SETTLE_TICKS)
	var standing: int = 0
	for bush: Bush in _m.field.bushes:
		standing += 1 if bush.is_standing and bush.sight_body.collision_layer == SIGHT_LAYER else 0
	_m.kit.need(problems, flat == _m.field.bushes.size(), "%d of %d Bushes flat before the restart" % [flat, _m.field.bushes.size()])
	_m.kit.need(problems, standing == _m.field.bushes.size(), "%d of %d Bushes stand after it" % [standing, _m.field.bushes.size()])
	_m.kit.verdict("B5_restart", problems, "%d flat, then %d standing on the sight layer" % [flat, standing])


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var crushers: PackedStringArray = PackedStringArray()
	for stats: UnitStats in _m.controller.unit_types():
		if stats.crushes_bushes:
			crushers.append(String(stats.type_id))
		_m.kit.need(problems, stats.collision_mask & SIGHT_LAYER == 0, "%s's mask holds the sight layer" % stats.type_id)
	_m.kit.need(problems, crushers == PackedStringArray(["buggy", "truck"]), "the types that crush Bushes are %s" % [crushers])
	var turret: TurretStats = _turret().stats as TurretStats
	_m.kit.need(problems, turret.sight_extra_mask == GROUND_SIGHT and turret.flying_sight_extra_mask == 0, "Turret sight %d, flying %d" % [turret.sight_extra_mask, turret.flying_sight_extra_mask])
	var name: String = str(ProjectSettings.get_setting(SIGHT_SETTING, ""))
	_m.kit.need(problems, name == SIGHT_NAME, "layer 8 is named '%s'" % name)
	_m.kit.need(problems, _m.controller.rules.shot_collision_mask & SIGHT_LAYER == 0, "the Shots' mask %d holds the sight layer" % _m.controller.rules.shot_collision_mask)
	_m.kit.verdict("B6_data", problems, "crushers %s; Turret sight %d / flying %d; layer 8 '%s'; Shot mask %d" % [crushers, turret.sight_extra_mask, turret.flying_sight_extra_mask, name, _m.controller.rules.shot_collision_mask])
