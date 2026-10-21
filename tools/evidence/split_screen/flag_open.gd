extends RefCounted
## Scenario flag_open of the split screen evidence harness (split_screen_harness.gd): no Turret locks a Flag any more, and the
## Motorbike breaks walls (Story 039). The shipped launch scene on Map 01 with every shipped piece of the game. CHECK lines:
##  F1 the Flag is open: with both of Player 2's Turrets standing, Player 1's Motorbike on Player 2's Flag takes it at once, the
##     lock is never reported (is_flag_locked_for), and brought home it wins the Round.
##  F2 the Motorbike breaks walls: Player 1's Motorbike firing at one of Player 2's Gate Wall Panels and at one of its Flag Walls
##     damages both; at one of its own Player's Wall Panels it still does nothing (no friendly damage).
##  F3 the Motorbike still damages a Turret: at one of Player 2's Turrets it takes hit points off.
##  F4 the data: turret_stats.tres does not lock the Flag; the damage matrix lists no motorbike>flag_wall pair (1.0, its default).
## Implements: production/epics/wasteland-fire/story-039-open-flag-and-motorbike-walls.md AC-1 to AC-4.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=flag_open

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

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
const FLAG_OPEN: bool = true
const WATCHDOG_SECONDS: float = 600.0

const FLAG_TICKS: int = 10
const FIRE_TICKS: int = 60
const SETTLE_SHOTS: int = 30
## How far in front of a piece the Motorbike fires from, metres.
const SHOOT_FROM: float = 7.0
const ENEMY_PANEL: String = "Walls/GateWallLeft/Panel2"
const ENEMY_FLAG_WALL: String = "Defences/FlagWallGate"
const OWN_PANEL: String = "Walls/GateWallLeft/Panel2"
const ENEMY_TURRET: String = "Turrets/TurretLeft"
const PAIR: StringName = &"motorbike>flag_wall"

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	await _check_flag()
	await _check_walls()
	await _check_turret()
	_check_data()
	_m.h.finish("map=%s" % _m.field.scene_file_path.get_file())


func _check_flag() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var enemy: Base = _m.field.player_2_base
	var standing: int = 0
	for piece: Structure in enemy.structures:
		if piece is Turret and piece.is_standing:
			standing += 1
	await _m.park(1)
	var locked: bool = false
	await _m.put(0, M2.MOTORBIKE, enemy.flag_seat.global_position, Vector3.FORWARD)
	for _tick: int in FLAG_TICKS:
		locked = locked or _m.controller.is_flag_locked_for(0)
		await _m.kit.tick()
	var taken: bool = enemy.flag.state == Flag.State.CARRIED
	_m.h.place(_m.units[0], Transform3D(_m.units[0].global_basis, _m.field.player_1_base.zone.global_position), _m.split.player_1_camera)
	await _m.kit.advance(FLAG_TICKS)
	var won: bool = _m.controller.is_round_over() and _m.controller.winner_index() == 0
	_m.kit.need(problems, standing == 2, "%d of Player 2's Turrets standing" % standing)
	_m.kit.need(problems, taken and not locked, "Flag taken %s, the lock reported %s" % [taken, locked])
	_m.kit.need(problems, won, "the Round is not won by Player 1")
	_m.controller.restart()
	await _m.kit.advance(FLAG_TICKS)
	await _m.h.confirm_choices()
	_m.kit.verdict("F1_flag_open", problems, "%d Turrets standing; Flag taken %s, lock reported %s; won %s" % [standing, taken, locked, won])


func _check_walls() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var enemy: Base = _m.field.player_2_base
	var own: Base = _m.field.player_1_base
	var enemy_panel: Structure = enemy.get_node(ENEMY_PANEL) as Structure
	var flag_wall: Structure = enemy.get_node(ENEMY_FLAG_WALL) as Structure
	var own_panel: Structure = own.get_node(OWN_PANEL) as Structure
	await _m.park(1)
	var losses: Array[float] = []
	for piece: Structure in [enemy_panel, own_panel]:
		losses.append(await _shoot(piece, enemy if piece == enemy_panel else own))
	# The Flag Wall stands inside the yard: fire at it from its Flag's side, between the water tower's legs.
	var seat: Vector3 = enemy.flag_seat.global_position
	var way: Vector3 = (flag_wall.global_position - seat).normalized()
	await _m.put(0, M2.MOTORBIKE, seat - way * 0.5, way)
	var before: float = flag_wall.hit_points
	await _fire()
	losses.append(before - flag_wall.hit_points)
	await _m.park(0)
	_m.kit.need(problems, losses[0] > 0.0, "Player 2's Wall Panel lost %.1f" % losses[0])
	_m.kit.need(problems, is_zero_approx(losses[1]), "Player 1's own Wall Panel lost %.1f" % losses[1])
	_m.kit.need(problems, losses[2] > 0.0, "Player 2's Flag Wall lost %.1f" % losses[2])
	_m.kit.verdict("F2_motorbike_walls", problems, "Motorbike's Shots: Player 2's Wall Panel -%.1f, Player 1's own -%.1f, Player 2's Flag Wall -%.1f" % [losses[0], losses[1], losses[2]])


func _check_turret() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var enemy: Base = _m.field.player_2_base
	var turret: Structure = enemy.get_node(ENEMY_TURRET) as Structure
	var loss: float = await _shoot(turret, enemy)
	_m.kit.need(problems, loss > 0.0, "the Turret lost %.1f" % loss)
	_m.kit.verdict("F3_motorbike_turret", problems, "Motorbike's Shots: Player 2's Turret -%.1f" % loss)


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var turret: TurretStats = load("res://src/gameplay/defences/data/turret_stats.tres") as TurretStats
	var matrix: DamageMatrix = _m.controller.rules.damage_matrix
	_m.kit.need(problems, not turret.locks_flag, "turret_stats.tres locks the Flag")
	_m.kit.need(problems, not matrix.multipliers.has(PAIR) and is_equal_approx(matrix.multiplier(&"motorbike", &"flag_wall"), 1.0), "the matrix holds %s at %.2f" % [PAIR, matrix.multiplier(&"motorbike", &"flag_wall")])
	_m.kit.verdict("F4_data", problems, "locks_flag %s; motorbike>flag_wall %.2f (listed %s)" % [turret.locks_flag, matrix.multiplier(&"motorbike", &"flag_wall"), matrix.multipliers.has(PAIR)])


## Puts Player 1's Motorbike SHOOT_FROM in front of a piece, on the side away from its Base, facing it, fires and returns the
## hit points it lost.
func _shoot(piece: Structure, base: Base) -> float:
	var way: Vector3 = piece.global_position - base.global_position
	way.y = 0.0
	way = way.normalized()
	await _m.put(0, M2.MOTORBIKE, piece.global_position + way * SHOOT_FROM, -way)
	var before: float = piece.hit_points
	await _fire()
	return before - piece.hit_points


func _fire() -> void:
	var key: Key = _m.h.fire_key(0)
	_m.h.set_key(key, true)
	await _m.kit.advance(FIRE_TICKS)
	_m.h.set_key(key, false)
	await _m.kit.advance(SETTLE_SHOTS)
