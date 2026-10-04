extends RefCounted
## What the Story 011 scenarios (unit_swap, unit_swap_flows and unit_swap_showcase) share beyond the
## Story 009 kit (quick_fix_kit.gd: the Map, the Token kit, the Units, both hints) and the Story 004
## flag kit (flag_kit.gd: the Flags, the Bases, the teleports and the feathered drive): a record of
## the controller's swaps with a reading taken inside each handler (connected after every UI node, so
## it is what the screens show when the signal arrives), an ordered log of the Round's events with
## the runner's tick, a log of every spawn with the Unit's hit points and Fuel at the moment it
## appeared, the places of a Base in its own frame (outside the gate, inside the yard, the way out),
## and the waits for a Unit to be reported by its Base's zone. Tooling only: nothing under src/
## depends on this file; loaded with a preload constant.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The Story 009 helpers (quick_fix_kit.gd): the kits they stand on, the type indices, put().
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 004 helpers (flag_kit.gd): Flags, Bases, teleport(), drive_until().
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")
## The Story 008 helpers (token_kit.gd): the real keys.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## Metres out of a Base's gate, along the gate's way from the Base's origin, where a Unit stands
## outside the zone and the walls (the zone ends 13.9 m from the origin; the gate walls span 13.7 to 15.0 m).
const OUTSIDE_M: float = 24.0
## Ticks a wait for the zone to report a Unit may take (the zone is about two ticks behind).
const ZONE_WAIT_TICKS: int = 10
## Ticks a wait for any state may take before the scenario gives up on it.
const WAIT_TICKS: int = 300
## The drive speed a feathered approach holds, m/s.
const CRUISE: float = 6.0
## Where a Unit is put just inside a Base's walls, in the Base's own frame: in the yard, clear of the
## Flag's seat (7 m in front of the origin) and of the tower's legs.
const INSIDE_LOCAL: Vector3 = Vector3(6.0, 0.0, -3.0)
## Ticks a Unit put outside waits for the zone to let go of it before it is put inside again.
const OUT_SETTLE_TICKS: int = 4

## The Story 009 kit: the Map, the Tokens, the Units (q.units), both hints (q.hints), put().
var q: Quick
## The Story 004 kit: the Flags and Bases by Player, teleport(), drive_until(), the Flag logs.
var flags: Flags
## The launch scene's MatchController.
var controller: MatchController
## Every unit_swapped: {player, tick, choosing, alive, panel, other_panel, countdown, hud,
## panel_counts, counts, paused, wait_s}, read inside the handler.
var swaps: Array[Dictionary] = []
## Every unit_spawned: {player, tick, type, hp, fuel, at}, read inside the handler (before any burn).
var spawned: Array[Dictionary] = []
## The Round's events in the order they arrived, each "<tick> <what>": destroyed, swapped, picked,
## seated and over.
var order: PackedStringArray = []
## The ticks the zone took to report each Unit that appeared, after its spawn tick.
var latencies: Array[int] = []


## Makes the kits and connects the records; call close() before the scenario's finish().
func _init(harness_node: Node) -> void:
	q = Quick.new(harness_node)
	flags = Flags.new(harness_node, q.kit)
	controller = q.controller
	controller.unit_swapped.connect(_on_swapped)
	controller.unit_spawned.connect(_on_spawned)
	controller.unit_destroyed.connect(func(player: int) -> void: _note("destroyed %d" % player))
	controller.flag_picked_up.connect(func(carrier: int, index: int) -> void: _note("picked %d by %d" % [index, carrier]))
	controller.flag_seated.connect(func(index: int) -> void: _note("seated %d" % index))
	controller.round_over.connect(func(winner: int) -> void: _note("over %d" % winner))


## Removes the engine log counter (token_kit.gd).
func close() -> void:
	q.close()


## How many entries of the order log, from index `since` on, start with the text after the tick.
func count(what: String, since: int = 0) -> int:
	var found: int = 0
	for index: int in range(since, order.size()):
		if order[index].split(" ", true, 1)[1].begins_with(what):
			found += 1
	return found


## The world position of a point given in a Base's own frame (x to the right, z along its back; the
## gate is in local -Z).
func base_point(player: int, local: Vector3) -> Vector3:
	return q.units.bases[player].global_transform * local


## The way out of a Base's gate in the world: the Base's local -Z.
func gate_way(player: int) -> Vector3:
	return -q.units.bases[player].global_transform.basis.z


## The way into a Base through its gate: the Base's local +Z.
func into_base(player: int) -> Vector3:
	return q.units.bases[player].global_transform.basis.z


## The place OUTSIDE_M out of a Base's gate: outside the zone, where a Self-destruct destroys.
func outside_point(player: int) -> Vector3:
	return base_point(player, Vector3(0.0, 0.0, -OUTSIDE_M))


## The place just inside a Base's walls where a Unit is put to be reported by the zone.
func inside_point(player: int) -> Vector3:
	return base_point(player, INSIDE_LOCAL)


## The Base's spawn point and the way its Unit faces there (the spawn point's local -Z).
func spawn_pose(player: int) -> Array[Vector3]:
	var marker: Marker3D = q.units.bases[player].spawn_point
	return [marker.global_position, -marker.global_transform.basis.z]


## True when the Unit of `player` stands on its own Base's spawn point or on a spare one.
func on_a_spawn_point(player: int) -> bool:
	var base: Base = q.units.bases[player]
	var spots: Array[Marker3D] = [base.spawn_point]
	spots.append_array(base.spare_spawn_points)
	for spot: Marker3D in spots:
		if q.units.units[player].global_position.distance_to(spot.global_position) <= 0.05:
			return true
	return false


## Waits until the Base zone of `player` reports that Player's Unit and the controller can swap it:
## the ticks since the Unit's last spawn, or -1 when it never did within ZONE_WAIT_TICKS. A
## coroutine: await it.
func wait_swappable(player: int) -> int:
	for _wait: int in ZONE_WAIT_TICKS + 1:
		if controller.can_swap(player):
			var since: int = q.harness.ticks - spawned_tick(player)
			latencies.append(since)
			return since
		await q.kit.tick()
	return -1


## Puts the Player's Unit outside its Base, waits for the zone to let go of it, then puts it inside
## facing in: the runner's tick it was put in on. A coroutine: await it.
func enter(player: int) -> int:
	flags.teleport(player, outside_point(player), into_base(player))
	await q.kit.advance(OUT_SETTLE_TICKS)
	flags.teleport(player, inside_point(player), into_base(player))
	return q.harness.ticks


## The ticks from putting the Player's Unit inside its Base until the zone reports it (can_swap()), or
## -1 when it never did. The same put-in always takes the same number: the physics server's lag. A
## coroutine: await it.
func zone_latency(player: int) -> int:
	var put_in: int = await enter(player)
	for _wait: int in ZONE_WAIT_TICKS + 1:
		await q.kit.tick()
		if controller.can_swap(player):
			return q.harness.ticks - put_in
	return -1


## Puts the Player's Unit inside its Base (enter()) and sets the Self-destruct key so that the press
## acts `after` ticks after the zone first reports the Unit (zone_latency(), measured before; a negative
## `after` acts before it): the key set at a tick's start acts on the next tick. The tick the press
## acts on, as the runner counts it. A coroutine: await it.
func enter_pressing(player: int, latency: int, after: int) -> int:
	var put_in: int = await enter(player)
	await q.kit.advance(latency - 1 + after)
	await q.kit.press_settled(Tokens.keys(&"destruct", player))
	return put_in + latency + after


## The runner's tick of the Player's last spawn, or -1000.
func spawned_tick(player: int) -> int:
	for index: int in range(spawned.size() - 1, -1, -1):
		if int(spawned[index]["player"]) == player:
			return int(spawned[index]["tick"])
	return -1000


## The Player chooses the type with real keys, waits for its Unit and for the zone to report it:
## the zone's latency in ticks, or -1 when the Unit did not appear or was never reported. A coroutine:
## await it.
func play(player: int, type_index: int) -> int:
	if not await q.tokens.spawn(player, type_index):
		return -1
	return await wait_swappable(player)


## Both Players choose the Motorbike and wait for the zone: the start of a Round or a restart. A
## coroutine: await it.
func both_play() -> void:
	for player: int in [0, 1]:
		await play(player, Quick.MOTORBIKE)


## The restart key, then both Players choose the Motorbike. A coroutine: await it.
func restart_and_play() -> void:
	await q.tokens.restart()
	await both_play()


## Ticks until the condition holds, at most WAIT_TICKS: whether it did. A coroutine.
func wait_until(condition: Callable) -> bool:
	for _wait: int in WAIT_TICKS:
		if condition.call():
			return true
		await q.kit.tick()
	return condition.call()


func _note(what: String) -> void:
	order.append("%d %s" % [q.harness.ticks, what])


func _on_swapped(player: int) -> void:
	_note("swapped %d" % player)
	swaps.append({"player": player, "tick": q.harness.ticks, "choosing": controller.is_choosing(player),
		"alive": controller.is_alive(player), "panel": q.units.panels[player].visible,
		"other_panel": q.units.panels[1 - player].visible, "countdown": q.units.countdowns[player].visible,
		"hud": q.tokens.hud_line(player), "panel_counts": q.tokens.panel_counts(player),
		"counts": q.tokens.counts(), "paused": q.harness.get_tree().paused,
		"wait_s": controller.seconds_until_respawn(player)})


func _on_spawned(player: int) -> void:
	var unit: Unit = q.units.units[player]
	spawned.append({"player": player, "tick": q.harness.ticks, "type": unit.type_id,
		"hp": unit.hit_points, "fuel": unit.fuel, "at": unit.global_position})
