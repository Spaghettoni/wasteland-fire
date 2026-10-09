extends RefCounted
## What the Story 014 scenarios (mines with its modules, and mines_showcase) share on top of the
## Story 012 kit (flag_walls_kit.gd: the Units, Bases, Flags, Flag Walls, the real keys and the
## logs): both Players' MineLayers, a record of every count they report and every refusal they
## emit, a record of every Mine that enters the tree (its tick, where it was laid, when it left),
## the Mines lines and notice lines of both views, and the ways a Player's Unit is put in play as a
## new Truck or as a victim. Tooling only: nothing under src/ depends on this file; loaded with a
## preload constant. Implements: production/epics/wasteland-fire/story-014-truck-mines.md, Test
## Evidence.

## The Story 012 helpers (flag_walls_kit.gd): the kits they stand on, the waits, the places.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The physical keys of the lay actions, Player 1 first (only tools name key codes).
const LAY_KEYS: Array[Key] = [KEY_E, KEY_COMMA]
## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = 3
## Ticks a Unit stays out of play before it is put back, so that a MineLayer sees it leave and
## come in (it ticks after the Units, so one full tick out is enough; two keep clear of it).
const OUT_TICKS: int = 2

## The Story 012 kit: w.s (Story 011 kit), w.s.q (Story 009 kit: kit, map, tokens, units, controller).
var w: Walls
## Both Players' MineLayers, by Player.
var layers: Array[MineLayer] = [null, null]
## Every mines_changed of each Player's MineLayer, in order: Vector3i(left, capacity, tick).
var changes: Array = [[], []]
## Every lay_refused of each Player's MineLayer, in order: Vector2i(reason, tick).
var refused: Array = [[], []]
## Every Mine that entered the tree, in order: {mine, tick, frame, gone_tick, at, player}; tick and
## frame are the runner's and the engine's when it entered, gone_tick the runner's tick it left the
## tree or -1, at and player what it was when it left (read them with place_of() and owner_of()).
var laid: Array[Dictionary] = []


## Makes the Story 012 kit, finds both MineLayers and records their signals and every Mine.
func _init(harness_node: Node) -> void:
	w = Walls.new(harness_node)
	var split: SplitScreen = w.s.q.harness.split
	layers = [split.player_1_mine_layer, split.player_2_mine_layer]
	for player: int in Kit.PLAYERS:
		layers[player].mines_changed.connect(func(left: int, capacity: int) -> void:
			changes[player].append(Vector3i(left, capacity, w.s.q.harness.ticks)))
		layers[player].lay_refused.connect(func(reason: MineLayer.Refusal) -> void:
			refused[player].append(Vector2i(reason, w.s.q.harness.ticks)))
	w.s.q.harness.get_tree().node_added.connect(_on_node_added)


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	w.close()


## The Mines line in a Player's view (null when the view has none).
func count_label(player: int) -> MineCount:
	var found: Array[Node] = w.s.q.units.cameras[player].get_viewport().find_children("*", "MineCount", false, false)
	return found[0] as MineCount if not found.is_empty() else null


## The notice line in a Player's view (null when the view has none).
func notice(player: int) -> PlayerNotice:
	var found: Array[Node] = w.s.q.units.cameras[player].get_viewport().find_children("*", "PlayerNotice", false, false)
	return found[0] as PlayerNotice if not found.is_empty() else null


## The Mines in the tree now, in the order they were laid.
func standing() -> Array[Mine]:
	var found: Array[Mine] = []
	for record: Dictionary in laid:
		var mine: Variant = record["mine"]
		if is_instance_valid(mine) and (mine as Mine).is_inside_tree() and (mine as Mine).state != Mine.State.SPENT:
			found.append(mine as Mine)
	return found


## How many Mines the record holds from index `since` of `laid` on.
func laid_since(since: int) -> int:
	return laid.size() - since


## The record of the Mine laid last, or an empty Dictionary.
func last() -> Dictionary:
	return laid[-1] if not laid.is_empty() else {}


## Puts a Player in play as a new Truck at a world place facing a direction: the Player's Unit
## goes out of play for OUT_TICKS ticks and comes back as a Truck (spawn()), so its MineLayer sees
## a new Truck and refills; the Player must be one the controller has in play (revive() first).
## The place is settled. A coroutine: await it.
func put(player: int, type_index: int, at: Vector3, facing: Vector3) -> void:
	var unit: Unit = w.s.q.units.units[player]
	if unit.is_alive:
		unit.leave_play()
	await w.s.q.kit.advance(OUT_TICKS)
	w.s.q.units.retype(player, type_index, at, facing)
	await w.s.q.kit.advance(SETTLE)


## Puts a Player whose Unit was destroyed back in play the way the Round does, by its real keys (it
## costs a Token), so the controller and the Unit agree again: a Unit put down in place of a
## destroyed one leaves the controller waiting to respawn it, and it would respawn it from under
## the check. Nothing is done for a Player the controller has in play. A coroutine: await it.
func revive(player: int) -> void:
	if not w.s.q.controller.is_alive(player):
		await w.s.play(player, Quick.MOTORBIKE)


## The Player lays with the lay key: one real press, then the tick the MineLayer acts on it. The
## Mine it laid (the record), or an empty Dictionary when it laid none. A coroutine: await it.
func lay(player: int) -> Dictionary:
	var before: int = laid.size()
	await w.s.q.kit.press_settled([LAY_KEYS[player]] as Array[Key])
	return laid[before] if laid.size() > before else {}


## Waits until the Mine is spent and gone (or `limit` ticks): the runner's tick it left, or -1.
func wait_gone(record: Dictionary, limit: int) -> int:
	for _wait: int in limit:
		if int(record["gone_tick"]) >= 0:
			return int(record["gone_tick"])
		await w.s.q.kit.tick()
	return int(record["gone_tick"])


## Where a Mine of the record stands, or stood when it left the tree.
func place_of(record: Dictionary) -> Vector3:
	var mine: Variant = record["mine"]
	return (mine as Mine).global_position if is_instance_valid(mine) and (mine as Mine).is_inside_tree() else record["at"]


## The Player who laid a Mine of the record, as the Mine itself says.
func owner_of(record: Dictionary) -> int:
	var mine: Variant = record["mine"]
	return (mine as Mine).player_index if is_instance_valid(mine) and (mine as Mine).is_inside_tree() else int(record["player"])


## Files a Mine the tree gained: its tick now, its place and Player when it leaves.
func _on_node_added(node: Node) -> void:
	var mine: Mine = node as Mine
	if mine == null:
		return
	var record: Dictionary = {"mine": mine, "tick": w.s.q.harness.ticks,
		"frame": Engine.get_physics_frames(), "gone_tick": -1, "at": Vector3.INF, "player": -1}
	laid.append(record)
	mine.tree_exiting.connect(func() -> void:
		record["gone_tick"] = w.s.q.harness.ticks
		record["at"] = mine.global_position
		record["player"] = mine.player_index)


## The gap in metres between a ground Unit's box (its first CollisionShape3D, as it stands now) and
## a circle of the given radius on the ground at a place: positive when they do not touch.
func gap(unit: Unit, at: Vector3, radius: float) -> float:
	var shape: CollisionShape3D = unit.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape.shape as BoxShape3D
	var local: Vector3 = shape.global_transform.affine_inverse() * at
	var reach: Vector2 = Vector2(maxf(absf(local.x) - box.size.x / 2.0, 0.0), maxf(absf(local.z) - box.size.z / 2.0, 0.0))
	return reach.length() - radius


## The text of a Player's Mines line, or "hidden" while it is not shown.
func line(player: int) -> String:
	var label: MineCount = count_label(player)
	return label.text if label != null and label.visible else "hidden"


## The text of a Player's notice line, or "hidden" while it is not shown.
func note(player: int) -> String:
	var label: PlayerNotice = notice(player)
	return label.text if label != null and label.visible else "hidden"


## Puts a Player in play as a type whose stats the scenario made (a small tank, say) at a place facing a way.
func put_stats(player: int, stats: UnitStats, at: Vector3, facing: Vector3) -> void:
	var unit: Unit = w.s.q.units.units[player]
	if unit.is_alive:
		unit.leave_play()
	await w.s.q.kit.advance(OUT_TICKS)
	unit.spawn(w.s.q.units.pose(at, facing), stats)
	w.s.q.units.cameras[player].snap_to_target()
	await w.s.q.kit.advance(SETTLE)


## Puts a Player in play as a Truck with an empty tank (a stranded Truck) at a place facing a way.
func put_stranded(player: int, at: Vector3, facing: Vector3) -> void:
	await put_stats(player, w.s.q.small_tank(Quick.TRUCK, 0.0), at, facing)


## Where the arena lies: far from the Map in the shared world, a flat floor on the map layer, so a
## Mine and a victim have open ground with nothing near them and no Turret or Base in reach.
const ARENA: Vector3 = Vector3(0.0, 0.0, 400.0)
## The arena's floor is this many metres square.
const ARENA_SIZE: float = 300.0
## Ticks a Mine takes to arm (3 s) and a few more, so that it is live.
const LIVE_WAIT: int = 190
## The floor of the arena while make_arena() has made it, else null.
var floor_body: StaticBody3D


## Makes the arena (a floor under ARENA); free it with free_arena().
func make_arena() -> void:
	var world: Node = w.s.q.units.units[0].get_parent()
	floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.global_position = ARENA + Vector3.DOWN * 0.5


## Frees the arena's floor, if there is one.
func free_arena() -> void:
	if floor_body != null and floor_body.is_inside_tree():
		floor_body.get_parent().remove_child(floor_body)
		floor_body.free()
	floor_body = null


## A Player lays one Mine at `at` as a new Truck (its drop point is the place) facing east, waits until it is
## live and puts the Truck away at `away` (the arena's far corner when it is INF): the Mine's record. A
## coroutine: await it.
func live_mine(at: Vector3, player: int = 0, away: Vector3 = Vector3.INF) -> Dictionary:
	await revive(player)
	var facing: Vector3 = Vector3.RIGHT
	await put(player, Quick.TRUCK, at + Vector3(3.4, 0.0, 0.0), facing)
	var record: Dictionary = await lay(player)
	await w.s.q.kit.advance(LIVE_WAIT)
	var parking: Vector3 = away if away != Vector3.INF else ARENA + Vector3(120.0, 0.0, 120.0 * (1.0 if player == 0 else -1.0))
	await put(player, Quick.TRUCK, parking, facing)
	return record


## A Mine placed by the tool, as a tool may (the MineLayer would refuse the spot, or no Truck is at hand), for
## the Player's colour: it enters the tree, is laid at `at`, and (with `wait_live`) waits until it is live.
func place_mine(at: Vector3, player: int, wait_live: bool = true) -> Dictionary:
	var before: int = laid.size()
	var mine: Mine = layers[player].mine_scene.instantiate() as Mine
	w.s.q.units.units[player].get_parent().add_child(mine)
	mine.lay(at, player, w.s.q.units.units[player].team_material)
	if wait_live:
		await w.s.q.kit.advance(LIVE_WAIT)
	return laid[before]


## Frees every Mine in the tree, a tool's way of clearing the Map between two checks (the restart does it in the
## game): none stays to set a later check's victim off. A coroutine: await it.
func clear_mines() -> void:
	for node: Node in w.s.q.harness.get_tree().get_nodes_in_group(&"mines"):
		node.set_physics_process(false)
		node.queue_free()
	await w.s.q.kit.advance(2)
