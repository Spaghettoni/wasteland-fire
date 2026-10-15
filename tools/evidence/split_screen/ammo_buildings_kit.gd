extends RefCounted
## What the Story 024 scenarios (ammo_buildings with its modules, ammo_buildings_showcase) share on top of the Story 023 kit
## (fuel_building_kit.gd: the depot's Fuel zones and their ways of putting a Unit down, and under it the Story 022 kit, whose record of
## the Weapons, the Shots and the arena they use, and the Story 021, 020, 019, 018, 014, 012, 011 and 009 kits): the Map's four supply
## zones in the order of MapField.supply_zones, the two ammunition buildings, a watch that files each Unit's Shots, Fuel, hit points,
## Mines, motion and listing every tick, and the ways a Unit is brought to a place with an empty gun. Tooling only: nothing under src/
## depends on this file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-024-ammunition-buildings.md, Test Evidence.

## The Story 023 kit: f.a is the Story 022 kit, f.a.k the Story 021 kit, f.a.mines() the Story 014 one.
const Kit23: GDScript = preload("res://tools/evidence/split_screen/fuel_building_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The watch (ammo_buildings_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_watch.gd")

## The Map's four supply zones by node path from the Map, in the order of MapField.supply_zones: the two Fuel zones, west before
## east, then the two ammunition zones, west before east. Side 0 is the west half (Base A, Player 1's), side 1 the east.
const ZONE_PATHS: Array[String] = ["Depot/FuelZoneWest", "Depot/FuelZoneEast", "AmmoBuildingWest/AmmoZone", "AmmoBuildingEast/AmmoZone"]
## The two ammunition buildings by node path from the Map, west before east.
const BUILDING_PATHS: Array[String] = ["AmmoBuildingWest", "AmmoBuildingEast"]
## The index in ZONE_PATHS of the first ammunition zone.
const AMMO_ZONE_FROM: int = 2
## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = Kit23.SETTLE
## The camera keys of the two Players (only tools name key codes: project.godot p1_camera, p2_camera) and the ticks a camera is given to
## settle after it is stepped to another view.
const CAMERA_KEYS: Array[Key] = Kit23.CAMERA_KEYS
const VIEW_TICKS: int = Kit23.VIEW_TICKS

## The Story 023 kit.
var f: Kit23
## The watch.
var watch: Watch


## Makes the Story 023 kit and the watch.
func _init(harness_node: Node) -> void:
	f = Kit23.new(harness_node)
	watch = Watch.new()
	watch.name = &"AmmoBuildingsWatch"
	q().harness.split.add_child(watch)
	var zones: Array[SupplyZone] = []
	for index: int in ZONE_PATHS.size():
		zones.append(zone(index))
	watch.setup(q().units.units, q().units.weapons, mines().layers, zones)


## Removes the watch and the engine log counter: call it before the scenario's finish().
func close() -> void:
	watch.get_parent().remove_child(watch)
	watch.free()
	f.close()


## The Story 009 kit: kit, map, tokens, units, controller.
func q() -> Quick:
	return f.q()


## The Story 022 kit: the Weapons' record, fire_n(), empty_gun(), the arena.
func a() -> Object:
	return f.a


## The Story 014 kit (mines_kit.gd): revive(), put(), lay(), the arena, the notice.
func mines() -> Object:
	return f.a.mines()


## A Player's Unit and Weapon.
func unit(player: int) -> Unit:
	return f.unit(player)


func gun(player: int) -> Weapon:
	return f.a.weapon(player)


## A supply zone of the Map by its index in ZONE_PATHS.
func zone(index: int) -> SupplyZone:
	return q().map.find(ZONE_PATHS[index]) as SupplyZone


## The ammunition zone of a side (0 west, 1 east) and its index in ZONE_PATHS.
func ammo_zone(side: int) -> SupplyZone:
	return zone(AMMO_ZONE_FROM + side)


func ammo_index(side: int) -> int:
	return AMMO_ZONE_FROM + side


## The ammunition building of a side.
func building(side: int) -> StaticBody3D:
	return q().map.find(BUILDING_PATHS[side]) as StaticBody3D


## The middle of a zone on the ground.
func centre(index: int) -> Vector3:
	return zone(index).global_position


## The direction a Unit faces to drive from the Base of a side toward its centre (east on the west side): +x on side 0, -x on side 1.
func inward(side: int) -> Vector3:
	return Vector3.RIGHT if side == 0 else Vector3.LEFT


## Brings a Player's Unit, already in play, to a place facing a way, without a new spawn: its gun keeps what it holds. The keys are
## released, the motion cleared, the camera snapped, then SETTLE ticks pass. A coroutine: await it.
func place(player: int, at: Vector3, facing: Vector3) -> void:
	move(player, at, facing)
	await q().kit.advance(SETTLE)


## The move of place() without the wait: the Unit is at its new place from the next tick.
func move(player: int, at: Vector3, facing: Vector3) -> void:
	q().harness.drive(player, 0, 0)
	var moved: Unit = unit(player)
	moved.global_transform = q().units.pose(at, facing)
	moved.reset_motion()
	q().units.cameras[player].snap_to_target()


## Where a Player's Unit stands in the arena: west of its middle, facing east (the Story 022 kit's spot, in world coordinates).
func arena_spot() -> Vector3:
	return f.a.mines().ARENA + f.a.ARENA_SPOT


## Puts a Player in play as a type in the arena (the other Player's Unit parked first), fires its whole load away there, where the
## Shots meet nothing, and leaves it there with an empty gun, a full tank and whole hit points. The arena must stand
## (mines().make_arena()). A coroutine: await it.
func empty_in_the_arena(player: int, type_index: int) -> void:
	await f.a.arena_put(player, type_index)
	await f.a.empty_gun(player)


## empty_in_the_arena(), then the Unit is brought to a place facing a way with the watch filing from the very tick of the move and for
## `ticks` ticks after it (row 0 is the first tick the zone sees the Unit at its new place). The watch is off again at the end. A
## coroutine: await it.
func empty_into(player: int, type_index: int, at: Vector3, facing: Vector3, ticks: int) -> void:
	await empty_in_the_arena(player, type_index)
	await record_after_move(player, at, facing, ticks)


## Brings a Player's Unit to a place facing a way and files `ticks` ticks of rows from the tick of the move. A coroutine.
func record_after_move(player: int, at: Vector3, facing: Vector3, ticks: int) -> void:
	watch.clear()
	watch.logging = true
	move(player, at, facing)
	await q().kit.advance(ticks)
	watch.logging = false


## record_after_move() for several Players at once, every Unit brought to its place in the same tick: each entry of `specs` is
## {player, at, facing}. A coroutine: await it.
func record_after_moves(specs: Array, ticks: int) -> void:
	watch.clear()
	watch.logging = true
	for spec: Dictionary in specs:
		move(int(spec["player"]), spec["at"], spec["facing"])
	await q().kit.advance(ticks)
	watch.logging = false


## Brings a Player's Unit to a place facing a way and drives it with the throttle held (a share of full, 1.0 by default) for `ticks`
## ticks, the watch filing from the tick of the move. A coroutine: await it.
func drive_after_move(player: int, at: Vector3, facing: Vector3, ticks: int, throttle: float = 1.0) -> void:
	watch.clear()
	watch.logging = true
	move(player, at, facing)
	await f.a.k.drive(player, ticks, throttle)
	watch.logging = false


## Runs `count` ticks with the watch filing: the rows start empty. A coroutine: await it.
func record(count: int) -> void:
	watch.clear()
	watch.logging = true
	await q().kit.advance(count)
	watch.logging = false


## Puts a Player's Unit away on its lane spot (a Unit that is not in the way), settled. A coroutine.
func park(player: int) -> void:
	await f.park(player)


## The rows the watch filed for a Player.
func rows(player: int) -> Array:
	return watch.rows[player]


## The index of the first row from `from` on whose Shots are above the row before's (a rearm), or -1.
func first_gain(player: int, from: int = 1) -> int:
	var list: Array = rows(player)
	for index: int in range(maxi(from, 1), list.size()):
		if int(list[index]["left"]) > int(list[index - 1]["left"]):
			return index
	return -1


## The index of the first row from `from` on that the zone lists the Unit in, or -1; the last such row.
func first_listed(player: int, zone_index: int, from: int = 0) -> int:
	var list: Array = rows(player)
	for index: int in range(from, list.size()):
		if bool(list[index]["listed"][zone_index]):
			return index
	return -1


func last_listed(player: int, zone_index: int) -> int:
	var list: Array = rows(player)
	for index: int in range(list.size() - 1, -1, -1):
		if bool(list[index]["listed"][zone_index]):
			return index
	return -1


## The rows on which a Player's Unit gained Shots, as a count.
func gains(player: int) -> int:
	var count: int = 0
	var list: Array = rows(player)
	for index: int in range(1, list.size()):
		count += 1 if int(list[index]["left"]) > int(list[index - 1]["left"]) else 0
	return count


## The rows in which an ammunition zone gives a Player's Unit a share, by the story's rule and nothing else: the Unit is alive in this
## row and the row before, the zone lists it in both and its real speed in the row before was at most `stopped` (the zone reads it before
## the Unit's own tick).
func gift_rows(player: int, zone_index: int, stopped: float) -> PackedInt32Array:
	var found: PackedInt32Array = []
	var list: Array = rows(player)
	for index: int in range(1, list.size()):
		var now: Dictionary = list[index]
		var before: Dictionary = list[index - 1]
		if bool(now["alive"]) and bool(before["alive"]) and bool(now["listed"][zone_index]) and bool(before["listed"][zone_index]) and float(before["speed"]) <= stopped:
			found.append(index)
	return found


## What the rows of a Player say about a fill at a zone: {gift (the row of the first gift, -1 for none), first (the row of the first
## gain, -1 for none: a gift is a part of a Shot, so a Shot comes later), full (the first row holding the whole load, -1 for none),
## ticks (full - gift + 1, -1 when either is missing: the ticks from the first gift to the whole load), start (the Shots in the row
## before the first gain), most (the most Shots any row held), capacity}.
func fill_of(player: int, zone_index: int, stopped: float) -> Dictionary:
	var list: Array = rows(player)
	var capacity: int = gun(player).capacity
	var gifts: PackedInt32Array = gift_rows(player, zone_index, stopped)
	var gift: int = gifts[0] if not gifts.is_empty() else -1
	var first: int = first_gain(player)
	var full: int = -1
	var most: int = 0
	for index: int in list.size():
		most = maxi(most, int(list[index]["left"]))
		if full < 0 and first >= 0 and index >= first and int(list[index]["left"]) >= capacity:
			full = index
	return {"gift": gift, "first": first, "full": full, "ticks": full - gift + 1 if full >= 0 and gift >= 0 else -1,
		"start": int(list[first - 1]["left"]) if first >= 1 else -1, "most": most, "capacity": capacity}


## The ticks an ammunition zone takes to fill a gun of `capacity` Shots from `start` Shots by the story's rule and nothing else: each
## tick it gives the capacity over `seconds` times the tick, and a whole Shot counts when the running total reaches it. -1 when never.
func fill_ticks(capacity: int, seconds: float, start: int = 0) -> int:
	var share: float = float(capacity) / seconds / float(Engine.physics_ticks_per_second)
	for count: int in range(1, 100000):
		if start + floori(float(count) * share + SHARE_EPSILON) >= capacity:
			return count
	return -1


## A float sum that lands just under a whole Shot is still the Shot (the Weapon's carry reads it so).
const SHARE_EPSILON: float = 1.0e-6


## The rule, run again from what the watch filed, tick by tick: a Unit is given a share in a row when it was alive in this row and the
## row before, the zone listed it in both and its real speed in the row before was at most `stopped` (the zone reads it before the
## Unit's own tick); the Shots it holds from the first row on are the first row's plus the whole Shots of the gifts so far (the
## running total of `capacity / seconds / ticks per second` a gift, the Weapon's carry), never above the capacity. Every row from the
## second on must equal that. Returns the problems for the rows that do not (the first three), under a label; oracle_judged says how
## many rows were judged.
func oracle(player: int, zone_index: int, seconds: float, stopped: float, label: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var list: Array = rows(player)
	var share: float = float(gun(player).capacity) / seconds / float(Engine.physics_ticks_per_second)
	var gifts: int = 0
	var judged: int = 0
	var base: int = int(list[0]["left"]) if not list.is_empty() else 0
	for index: int in range(1, list.size()):
		var now: Dictionary = list[index]
		var before: Dictionary = list[index - 1]
		if not bool(now["alive"]) or not bool(before["alive"]):
			continue
		if bool(now["listed"][zone_index]) and bool(before["listed"][zone_index]) and float(before["speed"]) <= stopped:
			gifts += 1
		var expected: int = mini(base + floori(float(gifts) * share + SHARE_EPSILON), int(now["capacity"]))
		judged += 1
		if int(now["left"]) != expected and problems.size() < 3:
			problems.append("%s: row %d held %d Shots, the rule says %d after %d gifts (listed %s, real speed %.4f)" % [label, index, int(now["left"]), expected, gifts, now["listed"], float(before["speed"])])
	oracle_judged = judged
	return problems


## How many rows the last oracle() call judged.
var oracle_judged: int = 0


## Steps a Player's camera with its real key until it is in the view from above (or in the chase view) and lets it settle. A coroutine.
func view(player: int, above: bool) -> void:
	await f.view(player, above)
