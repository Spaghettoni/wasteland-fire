extends RefCounted
## What the Story 013 scenarios (turrets with turrets_clear, turrets_aim, turrets_lead, turrets_fall
## and turrets_rule, and turrets_showcase and turrets_fps) share on top of the Story 012 kit
## (flag_walls_kit.gd: the Units, Bases, Flags, Flag Walls, the real keys and the logs): the four
## Turrets found by name under each Base's Turrets node, a record of every Shot a Turret fires (its
## tick, where it left and where it ended), the places a Unit is put in a Turret's view, the hit
## points a Player's Unit lost, the gap between a Unit's box and a Turret's drum and the restore of
## everything a Round leaves standing or fallen. Tooling only: nothing under src/ depends on this
## file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-013-turrets.md, Test Evidence.

## The Story 012 helpers (flag_walls_kit.gd): the kits they stand on, the Flag Walls, the waits.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The two Turrets of a Base, by side: the node names under its Turrets node, and where each stands
## in Base-local metres (Story 013 AC-1: 10 m either side of the Gate's axis, 4 m in front of the
## Gate wall's outer face).
const LEFT: int = 0
const RIGHT: int = 1
const NAMES: Array[String] = ["TurretLeft", "TurretRight"]
const PLACES: Array[Vector3] = [Vector3(-10.0, 0.0, -19.0), Vector3(10.0, 0.0, -19.0)]
## A Turret's drum is this wide, metres (the radius of its collider; AC-1).
const RADIUS: float = 1.0
## Ticks to let the physics space settle after a Unit is put down or a piece changes.
const SETTLE: int = 3
## A Shot's longest flight in ticks (35 m at 60 m/s is 35 ticks, and a few more to be safe).
const IN_FLIGHT_TICKS: int = 45
## The Turret's scene, and where the open ground of the arena lies: far from the Map in the shared
## world, a flat floor on the map layer big enough for every run (ARENA_SIZE metres square).
const SCENE_PATH: String = "res://src/gameplay/defences/turret.tscn"
const ARENA_CENTRE: Vector3 = Vector3(0.0, 0.0, 400.0)
const ARENA_SIZE: float = 300.0

## The Story 012 kit: w.s (Story 011 kit), w.s.q (Story 009 kit: kit, map, tokens, units, controller).
var w: Walls
## The physics frame of the last stage(): the frame the Unit was put in play in.
var staged_frame: int = 0
## The arena's floor and its fixture Turret while make_arena() has made them, else null.
var floor_body: StaticBody3D
var fixture: Turret
## The Turrets by Base, then by side: turrets[base][side].
var turrets: Array = []
## Every Shot a Turret fired, in order: {turret, tick, frame, shot, muzzle, direction, error, end,
## end_frame}; tick is the runner's, frame the engine's physics frame, error how far in metres the
## barrel was from the aim point when it fired; end is Vector3.INF until the Shot leaves the tree,
## then where it ended (end_frame the physics frame it did).
var firing: Array[Dictionary] = []
## The physics frames in which each Player's Unit's hit points changed, by Player (a spawn too).
var hp_frames: Array = [[], []]


## Makes the Story 012 kit, finds the four Turrets and records their Shots.
func _init(harness_node: Node) -> void:
	w = Walls.new(harness_node)
	for base_index: int in w.bases.size():
		var row: Array[Turret] = []
		for name: String in NAMES:
			var turret: Turret = w.bases[base_index].get_node_or_null("Turrets/" + name) as Turret
			row.append(turret)
			if turret != null:
				turret.fired.connect(_on_fired.bind(turret))
		turrets.append(row)
	for player: int in Kit.PLAYERS:
		var unit: Unit = w.s.q.units.units[player]
		unit.hit_points_changed.connect(func(_hp: float, _most: float) -> void: hp_frames[player].append(Engine.get_physics_frames()))


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	w.close()


## The Turret of a side of a Base (null when the scene lacks it).
func turret(base_index: int, side: int) -> Turret:
	return turrets[base_index][side] as Turret


## The notice Label in a Player's view (null when the view has none).
func notice(player: int) -> PlayerNotice:
	var found: Array[Node] = w.s.q.units.cameras[player].get_viewport().find_children("*", "PlayerNotice", false, false)
	return found[0] as PlayerNotice if not found.is_empty() else null


## All four Turrets, Base A's two first.
func all() -> Array[Turret]:
	var found: Array[Turret] = []
	for base_index: int in turrets.size():
		for side: int in NAMES.size():
			found.append(turret(base_index, side))
	return found


## The world place of a Turret's centre on the ground.
func place_of(base_index: int, side: int) -> Vector3:
	return w.point(base_index, PLACES[side])


## The Shots of one Turret in the record, in order.
func shots_of(who: Turret) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for record: Dictionary in firing:
		if record["turret"] == who:
			found.append(record)
	return found


## How many Shots of a Turret the record holds from index `since` of `firing` on.
func fired_since(who: Turret, since: int) -> int:
	var count: int = 0
	for index: int in range(since, firing.size()):
		count += 1 if firing[index]["turret"] == who else 0
	return count


## Puts a Player whose Unit a Turret destroyed back in play the way the Round does, by its real
## keys (it costs a Token), so the controller and the Unit agree again: a Unit put down in place of
## a destroyed one (retype) leaves the controller waiting to respawn it, and it would respawn it
## from under the check. Nothing is done for a Player the controller has in play. A coroutine: await
## it.
func revive(player: int) -> void:
	if not w.s.q.controller.is_alive(player):
		await w.s.play(player, Quick.MOTORBIKE)


## Puts a Player's Unit on its own Base's spare spawn spot in the Garage, facing out of the Gate:
## out of every Turret's view and out of the way of anything staged in front of the Gates. Nothing is
## done for a Unit already there. A coroutine: await it.
func park(player: int) -> void:
	await revive(player)
	var spot: Vector3 = w.bases[player].spare_spawn_points[0].global_position
	if w.s.q.units.units[player].global_position.distance_to(spot) <= 0.5:
		return
	w.s.flags.teleport(player, spot, w.way(player, Vector3.FORWARD))
	await w.s.q.kit.advance(SETTLE)


## Takes the Player's Unit out of play (leave_play(): a benched Unit is nobody's target and nobody's
## victim) and waits, at most a Shot's longest flight, until no Shot is left in the air, so a Shot
## fired at where a Unit stood cannot land on the next one put there. A coroutine: await it.
func clear(player: int) -> void:
	await revive(player)
	var unit: Unit = w.s.q.units.units[player]
	if unit.is_alive:
		unit.leave_play()
	for _tick: int in IN_FLIGHT_TICKS:
		if unit.get_tree().get_nodes_in_group(&"shots").is_empty():
			return
		await w.s.q.kit.tick()


## The Player's Unit is put in play as a type at a world place facing a direction (the Units kit's
## typed spawn, settled), after clear() has taken the Unit out of play and the air is empty, with
## the other Player's Unit parked out of the way first.
func stage(player: int, type_index: int, at: Vector3, facing: Vector3) -> void:
	await clear(player)
	await park(1 - player)
	staged_frame = Engine.get_physics_frames()
	w.s.q.units.retype(player, type_index, at, facing)
	await w.s.q.kit.advance(SETTLE)


## Makes the arena: a flat floor on the map layer around ARENA_CENTRE and, at its centre, a fixture
## Turret of the shipped scene and data that belongs to Player `owner` and is armed at the other
## Player's Unit, added under World like the Map's. Open ground for the lead: nothing hides a target
## from it. Returns the fixture. Free it with free_arena().
func make_arena(owner_player: int) -> Turret:
	var q: Object = w.s.q
	var world: Node = q.units.units[0].get_parent()
	floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(ARENA_SIZE, 1.0, ARENA_SIZE)
	shape.shape = box
	floor_body.add_child(shape)
	world.add_child(floor_body)
	floor_body.global_position = ARENA_CENTRE + Vector3.DOWN * 0.5
	fixture = (load(SCENE_PATH) as PackedScene).instantiate() as Turret
	fixture.player_index = owner_player
	world.add_child(fixture)
	fixture.global_position = ARENA_CENTRE
	fixture.arm(q.units.units[1 - owner_player], world, q.controller.rules)
	fixture.fired.connect(_on_fired.bind(fixture))
	return fixture


## Frees the arena's floor and fixture, if there are any.
func free_arena() -> void:
	for node: Node in [fixture, floor_body]:
		if node != null and node.is_inside_tree():
			node.get_parent().remove_child(node)
			node.free()
	fixture = null
	floor_body = null


## Lets `ticks` ticks pass and reports, for each Turret, whether it aimed (its state was AIMING or
## FIRING at some tick), whether its head turned and how many Shots it fired:
## {Turret: {aimed, turned, shots}}. With a Player in fire_player (0 or 1) that Player's fire key is
## held the whole time (real key events). A coroutine: await it.
func watch(ticks: int, fire_player: int = -1) -> Dictionary:
	var seen: Dictionary = {}
	var yaws: Dictionary = {}
	var mark: int = firing.size()
	for each: Turret in all():
		seen[each] = {"aimed": false, "turned": false, "shots": 0}
		yaws[each] = each.head.rotation.y
	var kit: Object = w.s.q.kit
	if fire_player >= 0:
		w.s.q.harness.set_key(w.s.q.harness.fire_key(fire_player), true)
	kit.on_tick = func() -> void:
		for each: Turret in seen:
			var state: Turret.State = each.state
			seen[each]["aimed"] = bool(seen[each]["aimed"]) or state == Turret.State.AIMING or state == Turret.State.FIRING
			seen[each]["turned"] = bool(seen[each]["turned"]) or not is_equal_approx(each.head.rotation.y, yaws[each])
	await kit.advance(ticks)
	kit.on_tick = Callable()
	if fire_player >= 0:
		w.s.q.harness.set_key(w.s.q.harness.fire_key(fire_player), false)
	for each: Turret in seen:
		seen[each]["shots"] = fired_since(each, mark)
	return seen


## The unit direction a Base's Turrets rest facing and the place `metres` ahead of a Turret along it.
func ahead(who: Turret, base_index: int, metres: float) -> Vector3:
	return who.global_position + w.way(base_index, Vector3.FORWARD).normalized() * metres


## Brings every Turret and every Flag Wall back whole, standing or fallen, with the physics space
## settled. Only while no Unit stands in one (Structure.restore()).
func restore_all() -> void:
	for piece: Turret in all():
		piece.restore()
	await w.restore_all()


## Where the Player's Unit's hit points stand in the Units kit's record: its length, for hits_since().
func hp_mark() -> int:
	return w.s.q.units.hp_changes.size()


## How many times the Player's Unit's hit points changed since a mark of hp_mark(), and the hit
## points it lost in all (the destruction included).
func hits_since(player: int, mark: int) -> Vector2:
	var units: Object = w.s.q.units
	var count: float = 0.0
	var lost: float = 0.0
	var before: float = INF
	for index: int in range(mark, units.hp_changes.size()):
		if units.hp_changes[index].x != player:
			continue
		count += 1.0
		var now: float = units.hp_values[index]
		if before != INF:
			lost += before - now
		before = now
	return Vector2(count, lost)


## The gap in metres between a ground Unit's box (its first CollisionShape3D, a BoxShape3D, as it
## stands now) and a Turret's drum, positive when they do not touch: the distance from the drum's
## axis to the box in the horizontal plane, less the drum's radius.
func gap(unit: Unit, who: Turret) -> float:
	var shape: CollisionShape3D = unit.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape.shape as BoxShape3D if shape != null else null
	if box == null:
		return INF
	var local: Vector3 = (shape.global_transform.affine_inverse()) * who.global_position
	var reach: Vector3 = Vector3(maxf(absf(local.x) - box.size.x / 2.0, 0.0), 0.0, maxf(absf(local.z) - box.size.z / 2.0, 0.0))
	return reach.length() - RADIUS


## True when the Unit's box touches any wall since its last move: the Unit's own record of a contact.
func touching_wall(unit: Unit) -> bool:
	return unit.is_on_wall()


## Records one Shot a Turret fired: its tick, muzzle and direction, and where it ends.
func _on_fired(shot: Shot, who: Turret) -> void:
	var record: Dictionary = {"turret": who, "tick": w.s.q.harness.ticks, "frame": Engine.get_physics_frames(), "shot": shot,
		"muzzle": shot.global_position, "direction": -shot.global_transform.basis.z, "error": who.aim_error,
		"end": Vector3.INF, "end_frame": -1}
	firing.append(record)
	shot.tree_exiting.connect(func() -> void:
		record["end"] = shot.global_position
		record["end_frame"] = Engine.get_physics_frames())


## True when a Shot of the record ended in the physics frame the Player's Unit's hit points changed:
## it hit that Unit (the Shot applies its damage from its own tick, before it frees itself).
func hit(record: Dictionary, player: int) -> bool:
	return record["end_frame"] >= 0 and hp_frames[player].has(record["end_frame"])
