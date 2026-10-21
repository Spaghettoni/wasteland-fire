extends RefCounted
## Scenario cover_pieces of the split screen evidence harness (split_screen_harness.gd): the car wrecks and the small buildings of
## Map 02 (Story 038). The launch scene plays Map 02 (MAP_SCENE) with every shipped piece of the game. CHECK lines:
##  C1 they stop Units: a Buggy driven at the middle wreck stops at it; a Gyrocopter from the same place flies over it.
##  C2 they stop Shots: Player 1's Buggy fires at the middle wreck with Player 2's Truck behind it: the wreck loses hit points and
##     the Truck none.
##  C3 the Motorbike damages them: Player 1's Motorbike fires at a small building and it loses hit points (the matrix lists no
##     pair for either type, so every Shot counts in full).
##  C4 the looks and the fall: a small building below 80% of its hit points shows its first damaged look, below 35% its second,
##     and at 0 its rubble, off every layer, so a Buggy drives through where it stood.
##  C5 the restart: a fallen wreck and a fallen building stand again, whole, on the cover layer.
##  C6 the data: the wreck's and the building's stats (type ids, hit points, the damaged fractions), the cover layer, the
##     multiplier 1.0 for every type against both.
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-7 and AC-8.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=cover_pieces

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

const WRECK: String = "Cover/WreckMiddle"
const SHACK: String = "Cover/ShackNorth1"
const COVER_LAYER: int = 64
## The wreck's half width across its length (it lies along z), metres.
const WRECK_HALF_WIDTH: float = 1.2
const RUN_FROM: float = 10.0
const RUN_TICKS: int = 180
const FIRE_TICKS: int = 60
const SETTLE_SHOTS: int = 30
## How far behind the wreck the target stands, and in front the shooter, metres.
const BEHIND: float = 6.0
const IN_FRONT: float = 8.0
## How far north of the building the Motorbike fires from.
const SHACK_FROM: float = 9.0
## The fractions of hit points the looks are checked at.
const LOOK_STEPS: Array[float] = [0.79, 0.34]
const STATS: Dictionary = {&"wreck": 60.0, &"shack": 100.0}
const DAMAGED_BELOW: Array[float] = [0.8, 0.35]

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _m.park(1)
	await _check_blocks_units()
	await _check_blocks_shots()
	await _check_motorbike()
	await _check_looks()
	await _check_restart()
	_check_data()
	_m.h.finish("pieces=%d" % _m.field.neutral_structures.size())


func _check_blocks_units() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var wreck: Structure = _m.piece(WRECK) as Structure
	var ends: PackedFloat32Array = PackedFloat32Array()
	for type_index: int in [M2.BUGGY, M2.GYROCOPTER]:
		await _m.put(0, type_index, wreck.global_position + Vector3.LEFT * RUN_FROM, Vector3.RIGHT)
		await _m.drive_for(0, 1, 0, RUN_TICKS)
		ends.append(_m.units[0].global_position.x - wreck.global_position.x)
	_m.kit.need(problems, ends[0] < -WRECK_HALF_WIDTH, "the Buggy ended %.2f m from the wreck's middle" % ends[0])
	_m.kit.need(problems, ends[1] > WRECK_HALF_WIDTH, "the Gyrocopter ended %.2f m from the wreck's middle" % ends[1])
	_m.kit.verdict("C1_blocks_units", problems, "Buggy stopped %.2f m, Gyrocopter reached %.2f m from the wreck's middle (x)" % [ends[0], ends[1]])


func _check_blocks_shots() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var wreck: Structure = _m.piece(WRECK) as Structure
	await _m.put(1, M2.TRUCK, wreck.global_position + Vector3.RIGHT * BEHIND, Vector3.RIGHT)
	await _m.put(0, M2.BUGGY, wreck.global_position + Vector3.LEFT * IN_FRONT, Vector3.RIGHT)
	var wreck_before: float = wreck.hit_points
	var truck_before: float = _m.units[1].hit_points
	await _fire(0)
	var wreck_after: float = wreck.hit_points
	var truck_after: float = _m.units[1].hit_points
	await _m.park(1)
	_m.kit.need(problems, wreck_after < wreck_before, "the wreck kept %.1f hit points" % wreck_after)
	_m.kit.need(problems, is_equal_approx(truck_after, truck_before), "the Truck behind it went %.1f -> %.1f" % [truck_before, truck_after])
	_m.kit.verdict("C2_blocks_shots", problems, "wreck %.1f -> %.1f, Truck behind it %.1f -> %.1f" % [wreck_before, wreck_after, truck_before, truck_after])


func _check_motorbike() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var shack: Structure = _m.piece(SHACK) as Structure
	await _m.put(0, M2.MOTORBIKE, shack.global_position + Vector3.FORWARD * SHACK_FROM, Vector3.BACK)
	var before: float = shack.hit_points
	await _fire(0)
	var after: float = shack.hit_points
	_m.kit.need(problems, after < before, "the building kept %.1f hit points" % after)
	_m.kit.verdict("C3_motorbike", problems, "building %.1f -> %.1f under the Motorbike's Shots" % [before, after])


func _check_looks() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var shack: Structure = _m.piece(SHACK) as Structure
	shack.restore()
	var seen: PackedStringArray = PackedStringArray()
	var full: float = shack.stats.max_hit_points
	for index: int in LOOK_STEPS.size():
		shack.apply_damage(shack.hit_points - LOOK_STEPS[index] * full)
		var look: Node3D = shack.damaged_looks[index]
		_m.kit.need(problems, look.visible and not shack.intact.visible, "at %.0f%% damaged look %d is not the one shown" % [LOOK_STEPS[index] * 100.0, index + 1])
		seen.append("%.0f%%: look %d" % [LOOK_STEPS[index] * 100.0, index + 1])
	shack.apply_damage(shack.hit_points)
	_m.kit.need(problems, not shack.is_standing and shack.wreck.visible and shack.collision_layer == 0, "at 0 standing %s, rubble shown %s, layer %d" % [shack.is_standing, shack.wreck.visible, shack.collision_layer])
	await _m.put(0, M2.BUGGY, shack.global_position + Vector3.FORWARD * SHACK_FROM, Vector3.BACK)
	await _m.drive_for(0, 1, 0, RUN_TICKS)
	var past: float = _m.units[0].global_position.z - shack.global_position.z
	_m.kit.need(problems, past > 0.0, "the Buggy ended %.1f m short of the fallen building's middle" % -past)
	await _m.park(0)
	_m.kit.verdict("C4_looks", problems, "%s; at 0 rubble, layer %d; a Buggy drove %.1f m past its middle" % ["; ".join(seen), shack.collision_layer, past])


func _check_restart() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var pieces: Array[Structure] = [_m.piece(WRECK) as Structure, _m.piece(SHACK) as Structure]
	for piece: Structure in pieces:
		piece.destroy()
	_m.controller.round_started.emit()
	await _m.kit.advance(M2.SETTLE_TICKS)
	for piece: Structure in pieces:
		_m.kit.need(problems, piece.is_standing and is_equal_approx(piece.hit_points, piece.stats.max_hit_points) and piece.collision_layer == COVER_LAYER and piece.intact.visible, "%s after the restart: standing %s, %.1f hit points, layer %d" % [piece.name, piece.is_standing, piece.hit_points, piece.collision_layer])
	_m.kit.verdict("C5_restart", problems, "both fallen, then whole on layer %d" % COVER_LAYER)


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var lines: PackedStringArray = PackedStringArray()
	for path: String in [WRECK, SHACK]:
		var piece: Structure = _m.piece(path) as Structure
		var stats: StructureStats = piece.stats
		_m.kit.need(problems, STATS.has(stats.type_id) and is_equal_approx(stats.max_hit_points, STATS[stats.type_id]) and stats.damaged_below == DAMAGED_BELOW and not stats.locks_flag, "%s: %s %.0f %s" % [piece.name, stats.type_id, stats.max_hit_points, stats.damaged_below])
		_m.kit.need(problems, piece.collision_layer == COVER_LAYER, "%s on layer %d" % [piece.name, piece.collision_layer])
		for type: UnitStats in _m.controller.unit_types():
			var multiplier: float = _m.controller.rules.damage_matrix.multiplier(type.type_id, stats.type_id)
			_m.kit.need(problems, is_equal_approx(multiplier, 1.0), "%s>%s is %.2f" % [type.type_id, stats.type_id, multiplier])
		lines.append("%s %.0f hp %s" % [stats.type_id, stats.max_hit_points, stats.damaged_below])
	_m.kit.verdict("C6_data", problems, "; ".join(lines) + "; every type 1.0 against both")


func _fire(player: int) -> void:
	var key: Key = _m.h.fire_key(player)
	_m.h.set_key(key, true)
	await _m.kit.advance(FIRE_TICKS)
	_m.h.set_key(key, false)
	await _m.kit.advance(SETTLE_SHOTS)
