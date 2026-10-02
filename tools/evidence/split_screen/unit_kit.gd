extends RefCounted
## What the Story 005 scenarios (units, weapons, gyro, choice, units_showcase) share: the record of
## the MatchController's choice, spawn and destruction signals and of both Units' hit_points_changed
## with the runner's tick each arrived on; every Shot the tree gained, with the tick it was fired,
## where it was first seen and where it ended; the Units, Bases, cameras, Weapons and screens of the
## launch scene; the typed spawn of a Unit at a place (Unit.spawn(at, stats), the direct path a tool
## may take beside the choice keys the scenarios press); a held fire key; the waits for a hit and a
## spawn. The one shared helper TD-006 allows for Story 005, on check_kit.gd; tooling only.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The type ids of the data in the order of rules.unit_types (design/rules.md "Units"): a scenario
## names a type by this index and checks the data against it.
const TYPE_IDS: Array[StringName] = [&"motorbike", &"buggy", &"truck", &"gyrocopter"]
## Ticks a scenario waits after a typed spawn or a teleport before the next spawn, move or shot: the
## physics space shows a spawn one tick late, and a collider swapped on the tick after a teleport is
## thrown (the Story 005 evidence doc).
const SETTLE_TICKS: int = 3
## Ticks a wait for a hit may run after the fire key went down: the longest flight of the data, 40 m
## at 60 m/s, plus margin.
const HIT_LIMIT_TICKS: int = 60

## The runner.
var harness: Harness
## The shared check helpers.
var kit: Kit
## The controller under test.
var controller: MatchController
## The Units of the launch scene, by Player.
var units: Array[Unit] = []
## The Bases of the launch scene, by Player.
var bases: Array[Base] = []
## The chase cameras of the launch scene, by Player.
var cameras: Array[ChaseCamera] = []
## The Weapons of the launch scene, by Player.
var weapons: Array[Weapon] = [null, null]
## The HUDs under each Player's SubViewport, by Player.
var huds: Array[PlayerHud] = [null, null]
## The respawn countdowns under each Player's SubViewport, by Player.
var countdowns: Array[RespawnCountdown] = [null, null]
## The choice panels under each Player's SubViewport, by Player.
var panels: Array[UnitChoice] = [null, null]
## Every unit_chosen: (player_index, type_index, tick).
var chosen: Array[Vector3i] = []
## Every unit_spawned: (player_index, tick).
var spawns: Array[Vector2i] = []
## The type_id the Unit had at each unit_spawned, in the same order.
var spawn_types: Array[StringName] = []
## Every unit_destroyed: (player_index, tick).
var destroyed: Array[Vector2i] = []
## Every hit_points_changed of either Unit: (player_index, tick), in order.
var hp_changes: Array[Vector2i] = []
## The new hit points of each of those, in the same order.
var hp_values: Array[float] = []
## Every Shot added to the tree, in order.
var shots: Array[Shot] = []
## The tick each of those Shots was fired.
var shot_ticks: Array[int] = []
## Where note_tick() first saw each of those Shots.
var shot_firsts: Array[Vector3] = []
## Where each of those Shots left the tree (Vector3.INF until then).
var shot_ends: Array[Vector3] = []


func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	var split: SplitScreen = harness.split
	controller = split.match_controller
	units.assign([split.player_1_unit, split.player_2_unit])
	bases.assign([split.field.player_1_base, split.field.player_2_base])
	cameras.assign([split.player_1_camera, split.player_2_camera])
	for node: Node in split.find_children("*", "Node", true, false):
		if node is Weapon and units.has((node as Weapon).unit):
			weapons[units.find((node as Weapon).unit)] = node as Weapon
	for player: int in Kit.PLAYERS:
		for node: Node in (cameras[player].get_viewport() as SubViewport).get_children():
			if node is PlayerHud and (node as PlayerHud).player_index == player:
				huds[player] = node as PlayerHud
			elif node is RespawnCountdown and (node as RespawnCountdown).player_index == player:
				countdowns[player] = node as RespawnCountdown
			elif node is UnitChoice and (node as UnitChoice).player_index == player:
				panels[player] = node as UnitChoice
		units[player].hit_points_changed.connect(func(hit_points: float, _max_hit_points: float) -> void:
			hp_changes.append(Vector2i(player, harness.ticks))
			hp_values.append(hit_points))
	controller.unit_chosen.connect(func(player: int, type_index: int) -> void: chosen.append(Vector3i(player, type_index, harness.ticks)))
	controller.unit_spawned.connect(func(player: int) -> void:
		spawns.append(Vector2i(player, harness.ticks))
		spawn_types.append(units[player].type_id))
	controller.unit_destroyed.connect(func(player: int) -> void: destroyed.append(Vector2i(player, harness.ticks)))
	harness.get_tree().node_added.connect(_on_node_added)


## Records where each Shot in flight stands the first time it is seen after its tick (the muzzle
## test). Set it as the check kit's on_tick, or call it from the scenario's own hook.
func note_tick() -> void:
	for index: int in shots.size():
		if shot_firsts[index] == Vector3.INF and is_instance_valid(shots[index]) and shots[index].is_inside_tree():
			shot_firsts[index] = shots[index].global_position


## The UnitStats of a type index: the controller's own resource, never written.
func stats(type_index: int) -> UnitStats:
	return controller.unit_types()[type_index]


## A pose on the ground at a place, facing a direction.
func pose(at: Vector3, facing: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, atan2(-facing.x, -facing.z)), Vector3(at.x, 0.0, at.z))


## Puts a Player's Unit in play as a type at a place facing a direction, by Unit.spawn(at, stats),
## and snaps its camera (the Round's state is untouched: a Unit in play stays in play). Wait
## SETTLE_TICKS before the next spawn, move or shot.
func retype(player: int, type_index: int, at: Vector3, facing: Vector3) -> void:
	units[player].spawn(pose(at, facing), stats(type_index))
	cameras[player].snap_to_target()


## Holds a Player's fire key down for the given ticks, then lets it go: real key events through the
## runner (one tick fires one shot; a longer hold fires at the type's cadence). A coroutine: await
## it.
func hold_fire(player: int, ticks: int) -> void:
	harness.set_key(harness.fire_key(player), true)
	await kit.advance(ticks)
	harness.set_key(harness.fire_key(player), false)


## Waits until the Player's Unit's hit points change, at most HIT_LIMIT_TICKS: the hit points it
## lost (the hit's damage), or -1.0 when none came. A coroutine: await it.
func wait_hit(player: int) -> float:
	var before: float = units[player].hit_points
	for _tick: int in HIT_LIMIT_TICKS:
		await kit.tick()
		if not is_equal_approx(units[player].hit_points, before):
			return before - units[player].hit_points
	return -1.0


## Waits, keys as they are, until the Player's Unit is in play, at most limit ticks: the ticks
## waited, or -1. A coroutine: await it.
func wait_alive(player: int, limit: int) -> int:
	for count: int in range(0, limit + 1):
		if controller.is_alive(player):
			return count
		await kit.tick()
	return -1


## Files a Shot the tree gained: its tick now, its end when it leaves the tree (the hit position, or
## the end of its range).
func _on_node_added(node: Node) -> void:
	var shot: Shot = node as Shot
	if shot == null:
		return
	var index: int = shots.size()
	shots.append(shot)
	shot_ticks.append(harness.ticks)
	shot_firsts.append(Vector3.INF)
	shot_ends.append(Vector3.INF)
	shot.tree_exiting.connect(func() -> void: shot_ends[index] = shot.global_position)
