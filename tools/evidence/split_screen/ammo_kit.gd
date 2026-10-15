extends RefCounted
## What the Story 022 scenarios (ammo with its modules, and ammo_showcase) share on top of the Story 021 kit
## (crash_kit.gd: the crash flights, and under it the Story 020, 019, 018, 014, 012, 011 and 009 kits): a record of
## what each Player's Weapon reports (every ammo_changed with the Ammo line's text read inside the same emission, every
## out_of_ammo with the notice line's text), of every Shot that enters the tree and of every Unit the Round puts in play
## (its Fuel and its load on that tick), and the ways a Unit is brought to a count: fired down by real keys, put in the
## arena far from the Map, killed by each cause the build has. Tooling only: nothing under src/ depends on this file;
## loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md, Test Evidence.

## The Story 021 kit: k.k is the Story 020 kit, k.k.k the Story 019 kit, k.k.k.k the Story 018 kit, and k.mines() the Story 014 one.
const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
## The Story 014 kit (mines_kit.gd): the arena, put(), the notice and the lay.
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = Kit14.SETTLE
## Where in the arena a Player's Unit stands: west of the arena's centre, facing east (Shots fly 25 to 40 m and meet nothing).
const ARENA_SPOT: Vector3 = Vector3(-20.0, 0.0, 0.0)
## The most ticks a hold of the fire key may take to spend a load (the longest is the Truck's 25 Shots 48 ticks apart).
const HOLD_LIMIT: int = 4000

## The Story 021 kit.
var k: Kit21
## Per Player, every ammo_changed in order: {left, capacity, tick, frame, text (the Ammo line as it read inside the emission)}.
var changes: Array = [[], []]
## Per Player, every out_of_ammo in order: {tick, frame, note (the notice line as it read inside the emission)}.
var empties: Array = [[], []]
## Every Shot that entered the tree, in order: {shot, tick, frame, first (where it stood the first time it was seen after its tick)}.
var shots: Array[Dictionary] = []
## Every Unit the Round put in play, in order: {player, tick, frame, type, fuel, fuel_capacity, hp, max_hp, left, capacity
## (the Weapon's, read inside the controller's handler, before the Weapon's own tick of that frame)}.
var spawned: Array[Dictionary] = []
var _tracked: int = 0


## Makes the Story 021 kit and files what the Weapons say, every Shot and every spawn.
func _init(harness_node: Node) -> void:
	k = Kit21.new(harness_node)
	for player: int in Kit.PLAYERS:
		var gun: Weapon = q().units.weapons[player]
		gun.ammo_changed.connect(func(left: int, capacity: int) -> void:
			changes[player].append({"left": left, "capacity": capacity, "tick": q().harness.ticks, "frame": Engine.get_physics_frames(), "text": line(player)}))
		gun.out_of_ammo.connect(func() -> void:
			empties[player].append({"tick": q().harness.ticks, "frame": Engine.get_physics_frames(), "note": note(player)}))
	q().controller.unit_spawned.connect(_on_spawned)
	q().harness.get_tree().node_added.connect(_on_node_added)


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	k.close()


## The Story 009 kit: kit, map, tokens, units, controller.
func q() -> Quick:
	return k.q()


## The Story 014 kit (mines_kit.gd): revive(), put(), lay(), the arena.
func mines() -> Kit14:
	return k.mines() as Kit14


## The Story 011 kit (unit_swap_kit.gd): play().
func swap() -> Object:
	return k.swap()


## A Player's Weapon and Unit.
func weapon(player: int) -> Weapon:
	return q().units.weapons[player]


func unit(player: int) -> Unit:
	return q().units.units[player]


## The Ammo line in a Player's view (null when the view has none).
func count_label(player: int) -> AmmoCount:
	var found: Array[Node] = q().units.cameras[player].get_viewport().find_children("*", "AmmoCount", false, false)
	return found[0] as AmmoCount if not found.is_empty() else null


## The text of a Player's Ammo line, or "hidden" while it is not shown.
func line(player: int) -> String:
	var label: AmmoCount = count_label(player)
	return label.text if label != null and label.visible else "hidden"


## The text of a Player's notice line, or "hidden" while it is not shown.
func note(player: int) -> String:
	return mines().note(player)


## The Shots of the record from index `since` on, as a typed array.
func shots_since(since: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	found.assign(shots.slice(since))
	return found


## Notes where each Shot that entered since the last call stands now (call it after a tick: the Shot was launched in the
## tick it entered, so this is its first sight).
func track() -> void:
	for index: int in range(_tracked, shots.size()):
		var shot: Variant = shots[index]["shot"]
		if is_instance_valid(shot) and (shot as Shot).is_inside_tree():
			shots[index]["first"] = (shot as Shot).global_position
	_tracked = shots.size()


## Holds a Player's fire key (a real key event) for `ticks` ticks and lets it go; the Shots that entered meanwhile. A
## coroutine: await it.
func hold(player: int, ticks: int) -> Array[Dictionary]:
	var mark: int = shots.size()
	q().harness.set_key(q().harness.fire_key(player), true)
	for _tick: int in ticks:
		await q().kit.tick()
		track()
	q().harness.set_key(q().harness.fire_key(player), false)
	await q().kit.tick()
	track()
	return shots_since(mark)


## Holds the key until `count` Shots have entered (at most HOLD_LIMIT ticks), then lets it go and waits one tick: the Shots
## that entered. A coroutine: await it.
func fire_n(player: int, count: int) -> Array[Dictionary]:
	var mark: int = shots.size()
	q().harness.set_key(q().harness.fire_key(player), true)
	var waited: int = 0
	while shots.size() - mark < count and waited < HOLD_LIMIT:
		await q().kit.tick()
		track()
		waited += 1
	q().harness.set_key(q().harness.fire_key(player), false)
	await q().kit.tick()
	track()
	return shots_since(mark)


## Fires a Player's whole load away, the gun left empty. A coroutine: await it.
func empty_gun(player: int) -> void:
	await fire_n(player, weapon(player).shots_left)


## One real press of the fire key (the tick it goes down and the tick after), the Shots that entered. A coroutine.
func press(player: int) -> Array[Dictionary]:
	var mark: int = shots.size()
	await q().kit.press_settled(Kit.KEYS_FIRE_1 if player == 0 else Kit.KEYS_FIRE_2)
	track()
	return shots_since(mark)


## Puts a Player in play as a type in the arena (the other Player's Unit parked in its Garage first): the Unit leaves play
## for OUT_TICKS ticks and comes back, so its Weapon sees a new Unit and refills. The arena must be made (mines().make_arena()).
## A coroutine: await it.
func arena_put(player: int, type_index: int, at: Vector3 = ARENA_SPOT) -> void:
	await k.walls().park(1 - player)
	await mines().revive(player)
	await mines().put(player, type_index, Kit14.ARENA + at, Vector3.RIGHT)
	for unit_in_play: Unit in q().units.units:
		unit_in_play.refuel(unit_in_play.fuel_capacity)


## The first record of `changes[player]` from index `since` on whose capacity is above zero, or {}.
func load_since(player: int, since: int) -> Dictionary:
	for index: int in range(since, changes[player].size()):
		if int(changes[player][index]["capacity"]) > 0:
			return changes[player][index]
	return {}


## The first record of `spawned` from index `since` on that is a Player's, or {}.
func spawn_since(player: int, since: int) -> Dictionary:
	for index: int in range(since, spawned.size()):
		if int(spawned[index]["player"]) == player:
			return spawned[index]
	return {}


## The frames between a Unit's spawn and the Weapon's first report of its load that the story's reading allows (the Weapon ticks
## after the MatchController in the same physics frame, measured by the start module: 0).
const REPORT_LAG: int = 0


## Judges the new Unit a Player's choice put in play after the marks (an index of `spawned` and one of `changes[player]`): on the
## spawn tick its Fuel is the whole tank and its hit points are whole; its Weapon reports a full load of the chosen type in the
## physics frame of the spawn, the Ammo line reading "Ammo n / n" inside that very emission. Adds the problems under a label and
## returns {spawn, load, lag}, or {} when the Unit or the report never came.
func judge_new_unit(problems: PackedStringArray, label: String, player: int, spawn_mark: int, change_mark: int, type_index: int) -> Dictionary:
	var stats: UnitStats = q().units.stats(type_index)
	var spawn: Dictionary = spawn_since(player, spawn_mark)
	var report: Dictionary = load_since(player, change_mark)
	q().kit.need(problems, not spawn.is_empty() and not report.is_empty(), "%s: no new %s came (%s) or its load was never reported (%s)" % [label, stats.type_id, spawn, report])
	if spawn.is_empty() or report.is_empty():
		return {}
	q().kit.need(problems, spawn["type"] == stats.type_id, "%s: a %s came, not a %s" % [label, spawn["type"], stats.type_id])
	q().kit.need(problems, is_equal_approx(float(spawn["fuel"]), stats.fuel_capacity) and is_equal_approx(float(spawn["fuel_capacity"]), stats.fuel_capacity), "%s: the new %s started with %.1f of %.1f Fuel" % [label, stats.type_id, spawn["fuel"], spawn["fuel_capacity"]])
	q().kit.need(problems, is_equal_approx(float(spawn["hp"]), float(spawn["max_hp"])), "%s: the new %s started with %.1f of %.1f hit points" % [label, stats.type_id, spawn["hp"], spawn["max_hp"]])
	q().kit.need(problems, int(report["left"]) == stats.ammo_capacity and int(report["capacity"]) == stats.ammo_capacity and stats.ammo_capacity > 0, "%s: the new %s was reported with %d of %d Shots (the data say %d)" % [label, stats.type_id, report["left"], report["capacity"], stats.ammo_capacity])
	q().kit.need(problems, report["text"] == "Ammo %d / %d" % [stats.ammo_capacity, stats.ammo_capacity], "%s: the Ammo line read '%s' inside the report" % [label, report["text"]])
	var lag: int = int(report["frame"]) - int(spawn["frame"])
	q().kit.need(problems, lag == REPORT_LAG, "%s: the load was reported %d frames after the spawn, expected %d" % [label, lag, REPORT_LAG])
	return {"spawn": spawn, "load": report, "lag": lag}


## What a destroyed or benched Unit holds, read now: no Fuel, no hit points, a Weapon reporting 0 of 0 and an Ammo line that is
## hidden. Adds the problems under a label.
func judge_out_of_play(problems: PackedStringArray, label: String, player: int) -> void:
	var gun: Weapon = weapon(player)
	q().kit.need(problems, not unit(player).is_alive and is_zero_approx(unit(player).fuel) and is_zero_approx(unit(player).hit_points), "%s: the Unit is alive %s with %.1f Fuel and %.1f hit points" % [label, unit(player).is_alive, unit(player).fuel, unit(player).hit_points])
	q().kit.need(problems, gun.shots_left == 0 and gun.capacity == 0 and line(player) == "hidden", "%s: the Weapon holds %d of %d and the Ammo line reads '%s'" % [label, gun.shots_left, gun.capacity, line(player)])
	var last: Dictionary = changes[player][-1] if not changes[player].is_empty() else {}
	q().kit.need(problems, not last.is_empty() and int(last["left"]) == 0 and int(last["capacity"]) == 0, "%s: the last report was %s" % [label, last])


## The cadence of a type in ticks, as the Weapon rounds it.
func cadence_ticks(type_index: int) -> int:
	return maxi(roundi(q().units.stats(type_index).fire_interval_seconds * Engine.physics_ticks_per_second), 1)


## Files a Unit the Round put in play: its Fuel and its load right now, inside the controller's handler.
func _on_spawned(player: int) -> void:
	var put_in: Unit = unit(player)
	spawned.append({"player": player, "tick": q().harness.ticks, "frame": Engine.get_physics_frames(), "type": put_in.type_id,
		"fuel": put_in.fuel, "fuel_capacity": put_in.fuel_capacity, "hp": put_in.hit_points, "max_hp": put_in.stats.max_hit_points,
		"left": weapon(player).shots_left, "capacity": weapon(player).capacity})


## Files a Shot the tree gained: its tick now.
func _on_node_added(node: Node) -> void:
	var shot: Shot = node as Shot
	if shot != null:
		shots.append({"shot": shot, "tick": q().harness.ticks, "frame": Engine.get_physics_frames(), "first": Vector3.INF})
