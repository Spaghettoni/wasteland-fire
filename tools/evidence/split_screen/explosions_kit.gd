extends RefCounted
## What the Story 016 scenarios (explosions and the modules it runs, explosions_off, explosions_showcase and
## explosions_fps) share on top of the Story 013 kit (turrets_kit.gd: the Turrets, their Shots and the staging,
## and under it the Story 012, 011 and 009 kits: the Units, Bases, Flags, the real keys and the engine log
## counter): a record of every destruction the Round announced (its tick, the Unit's type, where its model
## stood and what the Explosion it made held on that tick) and of every Explosion that entered the tree (its
## tick, when it left and how many ticks it counted), the ways a Unit is destroyed by each cause, and a few
## readings of an Explosion's pieces by name. Tooling only: nothing under src/ depends on this file; loaded
## with a preload constant. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md, Test
## Evidence.

## The Story 013 kit: w (Story 012 kit), w.s (Story 011 kit), w.s.q (Story 009 kit: kit, map, tokens, units).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices and the model's box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The node group an Explosion belongs to, and the path of its scene.
const GROUP: StringName = &"explosions"
const SCENE_PATH: String = "res://src/gameplay/effects/explosion.tscn"
## The pieces of an Explosion by name (and its two holders of copies).
const FLASH: String = "Flash"
const FIREBALL: String = "Fireball"
const DEBRIS: String = "Debris"
const SMOKE: String = "Smoke"
## The story's lifetime in physics ticks: about 2 s at 60 ticks a second.
const LIFETIME_TICKS: int = 120
## Metres a place or a box edge may be off by (a single-precision float's worth).
const TOLERANCE: float = 0.001
## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = 3
## Ticks a Mine takes to arm (3 s) and a few more, so that it is live.
const LIVE_WAIT: int = 190
## Ticks a flow waits for its destruction before it gives up.
const KILL_WAIT: int = 240
## Where a duel is fought: the middle of Map 01, each Unit this many metres out of the centre line.
const DUEL_X: float = 5.0
## Metres in front of a Turret, along its rest heading, a victim is put at.
const TURRET_AHEAD: float = 15.0
## Metres from a Mine's centre a Unit is put at, so that its box overlaps the trigger with room to spare.
const MINE_REACH: float = 1.5
## The share of its tank a Gyrocopter that must run dry soon spawns with.
const SMALL_TANK: float = 0.005
## A Unit left with this many hit points dies of any Shot.
const ONE_SHOT: float = 1.0

## The Story 013 kit.
var t: Kit13
## The Story 009 kit: kit, map, tokens, units, controller.
var q: Quick
## Every Explosion that entered the tree, in order: {node, tick, frame, player, gone_tick, gone_frame,
## played, at, victim_alive, paused}; tick and frame are the runner's and the engine's when it entered, player the
## Player whose Unit it was made for (-1 until the destruction is filed), gone_* when it left (-1 while it
## stays), played the ticks it had counted, at where it stood and victim_alive whether that Player's Unit was
## back in play when it left and paused whether the tree was paused then.
var blasts: Array[Dictionary] = []
## Every destruction the Round announced, in order: {player, tick, frame, type, expected, box, size, floor,
## blast, centre, flash, fireball, in_group}; expected is where the story puts the centre (the Unit's model,
## raised by its type's collision_center), box the model's world box, blast the record of the Explosion that
## was made for it ({} for none), centre and flash and fireball what that Explosion held on the tick.
var destroyed: Array[Dictionary] = []
## The engine errors and warnings a scenario expects (a refused scene, a refused note): the noise check removes
## one log line for each entry, which must be contained in its text.
var expected_errors: Array[String] = []
var expected_warnings: Array[String] = []
## The last Mine mine_kill() used, as it stood once its Unit was destroyed: {state, flash, explosions} (the Mine's
## State, whether its own flash showed, and how many Explosions played then).
var last_mine: Dictionary = {}


## Makes the Story 013 kit and files every destruction and every Explosion.
func _init(harness_node: Node) -> void:
	t = Kit13.new(harness_node)
	q = t.w.s.q
	q.harness.get_tree().node_added.connect(_on_node_added)
	q.controller.unit_destroyed.connect(_on_destroyed)


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	t.close()


## The length of both records, as a mark to read them from: x the Explosions, y the destructions.
func mark() -> Vector2i:
	return Vector2i(blasts.size(), destroyed.size())


## The Explosions in the tree now (the node group, which the scene stores).
func playing() -> Array[Explosion]:
	var found: Array[Explosion] = []
	for node: Node in q.harness.get_tree().get_nodes_in_group(GROUP):
		if node is Explosion and node.is_inside_tree():
			found.append(node as Explosion)
	return found


## How many CollisionObject3D (a body, an Area3D) hang under a node, at any depth.
func bodies_under(node: Node) -> int:
	return node.find_children("*", "CollisionObject3D", true, false).size()


## Both Players' Units in play: a Unit that was destroyed comes back by the Round's own respawn with a real
## choice (it costs a Token). A coroutine: await it.
func fresh() -> void:
	for player: int in Kit.PLAYERS:
		await t.revive(player)


## The duel: Player 1's Motorbike and Player 2's Unit of a type stand DUEL_X metres either side of the middle
## of Map 01 facing each other, Player 1's and Player 2's keys up, and Player 2's Unit is left with one hit
## point, so one Shot kills it. A coroutine: await it.
func duel(victim_type: int) -> void:
	await fresh()
	await t.clear(0)
	q.units.retype(0, Quick.MOTORBIKE, Vector3(-DUEL_X, 0.0, 0.0), Vector3.RIGHT)
	q.units.retype(1, victim_type, Vector3(DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await q.kit.advance(SETTLE + 15)
	q.units.units[1].apply_damage(q.units.units[1].hit_points - ONE_SHOT)


## Player 2's Unit of a type is destroyed by Player 1's one real Shot in the duel: the destruction's record,
## or {} when none came. A coroutine: await it.
func shot_kill(victim_type: int) -> Dictionary:
	await duel(victim_type)
	var before: int = destroyed.size()
	await q.tokens.shoot(0)
	await wait_destroyed(before)
	return destroyed[before] if destroyed.size() > before else {}


## Player 2's Unit of a type is destroyed by its own Self-destruct key outside its Base: the record or {}.
func self_destruct(victim_type: int) -> Dictionary:
	await duel(victim_type)
	var before: int = destroyed.size()
	await q.tokens.destruct(1)
	await wait_destroyed(before)
	return destroyed[before] if destroyed.size() > before else {}


## Player 2's Unit of a type is destroyed by a tool's direct Unit.destroy() (story 021's stand-in): the
## record or {}.
func direct_destroy(victim_type: int) -> Dictionary:
	await duel(victim_type)
	var before: int = destroyed.size()
	q.units.units[1].destroy()
	await wait_destroyed(before)
	return destroyed[before] if destroyed.size() > before else {}


## Player 2's Unit of a type is destroyed by Base A's right Turret's Shot, 15 m ahead of it: the record or {}.
func turret_kill(victim_type: int) -> Dictionary:
	await fresh()
	var turret: Turret = t.turret(0, Kit13.RIGHT)
	var forward: Vector3 = t.w.way(0, Vector3.FORWARD)
	await t.stage(1, victim_type, t.ahead(turret, 0, TURRET_AHEAD), -forward)
	var before: int = destroyed.size()
	q.units.units[1].apply_damage(q.units.units[1].hit_points - ONE_SHOT)
	await wait_destroyed(before)
	return destroyed[before] if destroyed.size() > before else {}


## A Gyrocopter spawned with an empty tank runs dry over the middle of the Map and crashes: the record or {}.
func fuel_crash() -> Dictionary:
	await fresh()
	await t.clear(0)
	var before: int = destroyed.size()
	await q.put(1, q.small_tank(Quick.GYROCOPTER, SMALL_TANK), Vector3(DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await wait_destroyed(before)
	return destroyed[before] if destroyed.size() > before else {}


## A Mine of a Player's colour placed by the tool at a place, waiting until it is live (the MineLayer would
## refuse some spots, and no Truck is at hand). A coroutine: await it.
func live_mine(at: Vector3, owner_player: int) -> Mine:
	var layer: MineLayer = q.harness.split.player_1_mine_layer if owner_player == 0 else q.harness.split.player_2_mine_layer
	var mine: Mine = layer.mine_scene.instantiate() as Mine
	q.units.units[owner_player].get_parent().add_child(mine)
	mine.lay(at, owner_player, q.units.units[owner_player].team_material)
	await q.kit.advance(LIVE_WAIT)
	return mine


## Frees every Mine in the tree (the restart does it in the game). A coroutine: await it.
func clear_mines() -> void:
	for node: Node in q.harness.get_tree().get_nodes_in_group(&"mines"):
		node.set_physics_process(false)
		node.queue_free()
	await q.kit.advance(2)


## Player 2's Unit of a type is put on a live Mine at the middle of the Map and destroyed by it: the record or
## {}. With `both`, Player 1's Motorbike is put on the other side of the same Mine, so that it takes two Units.
func mine_kill(victim_type: int, both: bool = false) -> Dictionary:
	await fresh()
	await t.clear(0)
	var centre: Vector3 = Vector3(0.0, 0.0, 0.0)
	var mine: Mine = await live_mine(centre, 0)
	var before: int = destroyed.size()
	if both:
		q.units.retype(0, Quick.MOTORBIKE, centre + Vector3(0.0, 0.0, -MINE_REACH), Vector3.BACK)
	q.units.retype(1, victim_type, centre + Vector3(0.0, 0.0, MINE_REACH if both else 0.0), Vector3.FORWARD if both else Vector3.LEFT)
	await wait_destroyed(before + (1 if both else 0))
	await q.kit.advance(SETTLE)
	var found: Dictionary = destroyed[before] if destroyed.size() > before else {}
	var standing: bool = is_instance_valid(mine) and mine.is_inside_tree()
	last_mine = {"state": mine.state if standing else -1, "flash": mine.flash.visible if standing else false, "explosions": playing().size()}
	if standing:
		mine.queue_free()
	return found


## Waits until the record of destructions is longer than `count` (at most KILL_WAIT ticks), then two ticks more. A coroutine.
func wait_destroyed(count: int) -> void:
	for _wait: int in KILL_WAIT:
		if destroyed.size() > count:
			break
		await q.kit.tick()
	await q.kit.advance(2)


## Files an Explosion the tree gained: its tick now, and when it leaves the tree its tick, how many ticks it
## counted and where it stood.
func _on_node_added(node: Node) -> void:
	var blast: Explosion = node as Explosion
	if blast == null:
		return
	var record: Dictionary = {"node": blast, "tick": q.harness.ticks, "frame": Engine.get_physics_frames(), "player": -1,
		"gone_tick": -1, "gone_frame": -1, "played": -1, "at": Vector3.INF, "victim_alive": false, "paused": false}
	blasts.append(record)
	blast.tree_exiting.connect(func() -> void:
		record["gone_tick"] = q.harness.ticks
		record["gone_frame"] = Engine.get_physics_frames()
		record["played"] = blast.ticks_played()
		record["at"] = blast.global_position
		record["victim_alive"] = int(record["player"]) >= 0 and q.controller.is_alive(int(record["player"]))
		record["paused"] = q.harness.get_tree().paused)


## Files a destruction the Round announced, with where the story puts its centre and what the Explosion made
## for it held on this very tick (the handler of SplitScreen ran first: it was connected before this one).
func _on_destroyed(player: int) -> void:
	var unit: Unit = q.units.units[player]
	var model: Node3D = unit.get_node_or_null(String(Unit.MODEL_NODE_NAME)) as Node3D
	var origin: Vector3 = model.global_position if model != null else unit.global_position
	var record: Dictionary = {"player": player, "tick": q.harness.ticks, "frame": Engine.get_physics_frames(), "type": unit.type_id,
		"expected": origin + Vector3.UP * unit.stats.collision_center.y, "box": Quick.model_box(unit),
		"size": maxf(unit.stats.collision_size.x, unit.stats.collision_size.z), "floor": unit.global_position.y,
		"blast": {}, "centre": Vector3.INF, "flash": -1.0, "fireball": -1.0, "in_group": playing().size()}
	if not blasts.is_empty() and blasts[-1]["frame"] == record["frame"] and int(blasts[-1]["player"]) < 0:
		var blast: Explosion = blasts[-1]["node"] as Explosion
		blasts[-1]["player"] = player
		record["blast"] = blasts[-1]
		record["centre"] = blast.global_position
		record["flash"] = (blast.get_node(FLASH) as Node3D).scale.x
		record["fireball"] = (blast.get_node(FIREBALL) as Node3D).scale.x
	destroyed.append(record)
