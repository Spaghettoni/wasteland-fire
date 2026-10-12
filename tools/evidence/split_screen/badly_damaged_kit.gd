extends RefCounted
## What the Story 017 scenarios (badly_damaged and the modules it runs, badly_damaged_off,
## badly_damaged_showcase and badly_damaged_fps) share on top of the Story 016 kit (explosions_kit.gd: the
## record of destructions and Explosions, the ways a Unit is destroyed, and under it the Story 013, 012,
## 011, 009 kits: the Turrets, the Units, Bases, the real keys and the engine log counter): a record of
## every badly_damaged_changed and every hit_points_changed of either Unit with the physics frame it came
## in, the readings of a Unit's smoke, real Shots fired and landed one at a time, the duel and a flat arena
## for the speed runs, and the series of a drive speed. Tooling only: nothing under src/ depends on this
## file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md, Test Evidence.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = 3
## Where a duel is fought: each Unit this many metres out of the middle of Map 01.
const DUEL_X: float = 5.0
## Where the flat arena lies (far from the Map in the shared world) and how big it is, metres.
const ARENA_CENTRE: Vector3 = Vector3(0.0, 0.0, 800.0)
const ARENA_SIZE: float = 400.0
## A speed or a rate matches when it is within this (m/s, rad/s).
const TOLERANCE: float = 0.001
## Ticks a drive waits to be at its steady speed: the Motorbike needs 72 to reach 24 m/s.
const STEADY_TICKS: int = 100
## The node path of a Unit's smoke from the Unit.
static var SMOKE_PATH: NodePath = NodePath("%s/%s" % [Unit.MODEL_NODE_NAME, UnitModel.SMOKE_NODE_NAME])

## The Story 016 kit: t (Story 013 kit), q (Story 009 kit: kit, map, tokens, units, controller).
var e: Kit16
var t: Object
var q: Quick
## Every badly_damaged_changed of either Unit, in order: {player, state, frame, tick, hp, alive, visible,
## badly, destroyed_seen}; destroyed_seen is how many destructions the Round had filed when it arrived.
var changes: Array[Dictionary] = []
## Every hit_points_changed of either Unit: {player, hp, frame, tick}.
var hits: Array[Dictionary] = []
## The floor of the arena while make_floor() has made it.
var floor_body: StaticBody3D


func _init(harness_node: Node) -> void:
	e = Kit16.new(harness_node)
	t = e.t
	q = e.q
	for player: int in Kit.PLAYERS:
		q.units.units[player].badly_damaged_changed.connect(_on_changed.bind(player))
		q.units.units[player].hit_points_changed.connect(_on_hit_points.bind(player))


## Removes the engine log counter and the arena: call it before the scenario's finish().
func close() -> void:
	free_floor()
	e.close()


## The Player's Unit.
func unit(player: int) -> Unit:
	return q.units.units[player]


## The smoke of the Player's Unit, or null before the first badly damaged state.
func smoke(player: int) -> BadlyDamagedSmoke:
	return unit(player).get_node_or_null(SMOKE_PATH) as BadlyDamagedSmoke


## Whether the Player's Unit shows smoke now.
func smoking(player: int) -> bool:
	var found: BadlyDamagedSmoke = smoke(player)
	return found != null and found.is_smoking() and found.shown_count() > 0


## The BadlyDamagedSmoke nodes in the tree, at any depth.
func smoke_nodes() -> int:
	return q.harness.split.find_children("*", "BadlyDamagedSmoke", true, false).size()


## The hit points at or below which a type is badly damaged, from its data.
func edge_of(type_index: int) -> float:
	var stats: UnitStats = q.units.stats(type_index)
	return stats.max_hit_points * stats.badly_damaged_fraction


## The top speed of a type in the state, forward or in reverse, from its data.
func share_speed(type_index: int, forward: bool) -> float:
	var stats: UnitStats = q.units.stats(type_index)
	return (stats.max_speed if forward else stats.reverse_max_speed) * stats.badly_damaged_speed_share


## The record of changes from index `since` on, for a Player.
func changes_of(player: int, since: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for index: int in range(since, changes.size()):
		if int(changes[index]["player"]) == player:
			found.append(changes[index])
	return found


## Player 1's Unit of a type and Player 2's stand DUEL_X metres either side of the middle of Map 01
## facing each other with every key up, both whole; the Weapon's longest interval has run out.
func face_off(attacker_type: int, victim_type: int) -> void:
	await e.fresh()
	await t.clear(0)
	q.units.retype(0, attacker_type, Vector3(-DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	q.units.retype(1, victim_type, Vector3(DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await q.kit.advance(SETTLE + t.w.longest_cadence())


## `shooter` fires one Shot with its real fire key and waits until it landed on the other Player's Unit:
## the hit points the victim lost, or -1.0 when none came. Then waits the shooter's cadence out.
func fire(shooter: int) -> float:
	var victim: int = 1 - shooter
	var before: float = unit(victim).hit_points
	var cadence: int = t.w.cadence(Units.TYPE_IDS.find(unit(shooter).type_id))
	var lost: float = -1.0
	if await q.tokens.shoot(shooter) >= 0:
		for _wait: int in Units.HIT_LIMIT_TICKS:
			if not is_equal_approx(unit(victim).hit_points, before):
				lost = before - unit(victim).hit_points
				break
			await q.kit.tick()
	await q.kit.advance(cadence)
	return lost


## Makes the flat arena: a floor on the map layer around ARENA_CENTRE under World, where a Unit drives
## 150 m either way without meeting anything.
func make_floor() -> void:
	free_floor()
	floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	floor_body.add_child(shape)
	unit(0).get_parent().add_child(floor_body)
	floor_body.global_position = ARENA_CENTRE + Vector3.DOWN * 0.5


## Frees the arena's floor, if there is one.
func free_floor() -> void:
	if floor_body != null and floor_body.is_inside_tree():
		floor_body.get_parent().remove_child(floor_body)
		floor_body.free()
	floor_body = null


## A Player's Unit is put in play on the arena as the stats it is given (a type's own or a copy),
## heading east (+X) from `start` metres west of the arena's middle, every key up, a tank as full as the
## stats spawn it with; the other Player's Unit is parked. A coroutine: await it.
func on_floor(player: int, stats: UnitStats, start: float = -100.0) -> void:
	await t.park(1 - player)
	q.harness.drive(player, 0, 0)
	unit(player).spawn(q.units.pose(ARENA_CENTRE + Vector3(start, 0.0, 0.0), Vector3.RIGHT), stats)
	q.units.cameras[player].snap_to_target()
	await q.kit.advance(SETTLE)


## The drive speed of a Player's Unit after each of `ticks` ticks with the keys held as given (a throttle
## of 1 forward, -1 reverse, a steer of 1 left, -1 right; 0 for none).
func series(player: int, throttle: int, steer: int, ticks: int) -> PackedFloat64Array:
	q.harness.drive(player, throttle, steer)
	var found: PackedFloat64Array = PackedFloat64Array()
	for _tick: int in ticks:
		await q.kit.tick()
		found.append(unit(player).current_speed)
	return found


## What a drive speed does from `from` toward `target` at `rate` m/s^2, per tick: move_toward() at
## rate / the tick rate, the model the Unit's step 1 is judged against.
func model_series(from: float, target: float, rate: float, ticks: int) -> PackedFloat64Array:
	var found: PackedFloat64Array = PackedFloat64Array()
	var speed: float = from
	for _tick: int in ticks:
		speed = move_toward(speed, target, rate / float(Engine.physics_ticks_per_second))
		found.append(speed)
	return found


## The index of the first value of a series that equals `target` (within TOLERANCE), or -1.
func first_at(values: PackedFloat64Array, target: float) -> int:
	for index: int in values.size():
		if absf(values[index] - target) <= TOLERANCE:
			return index
	return -1


func _on_changed(state: bool, player: int) -> void:
	var u: Unit = unit(player)
	changes.append({"player": player, "state": state, "frame": Engine.get_physics_frames(), "tick": q.harness.ticks,
		"hp": u.hit_points, "alive": u.is_alive, "visible": u.visible, "badly": u.is_badly_damaged,
		"destroyed_seen": e.destroyed.size()})


func _on_hit_points(hit_points: float, _max_hit_points: float, player: int) -> void:
	hits.append({"player": player, "hp": hit_points, "frame": Engine.get_physics_frames(), "tick": q.harness.ticks})
