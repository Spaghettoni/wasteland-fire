extends RefCounted
## What the Story 023 scenarios (fuel_building with its modules, fuel_building_showcase) share on top of the Story 022 kit
## (ammo_kit.gd: the Weapons' record, the Shots, the spawns, and under it the Story 021, 020, 019, 018, 014, 012, 011 and 009
## kits): the depot's two Fuel zones, a watch that files each Unit's Fuel, motion and listing every tick, and the ways a Unit is
## put in a zone with a tank of a given share. Tooling only: nothing under src/ depends on this file; loaded with a preload
## constant. Implements: production/epics/wasteland-fire/story-023-fuel-building.md, Test Evidence.

## The Story 022 kit: a.k is the Story 021 kit, a.k.k the Story 020 kit, and a.mines() the Story 014 one.
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The watch (fuel_building_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/fuel_building_watch.gd")

## The Fuel zones by node path from the Map: the west one faces Base A (Player 1's), the east one Base B.
const ZONE_PATHS: Array[String] = ["Depot/FuelZoneWest", "Depot/FuelZoneEast"]
## The depot's three tanks by node path from the Map.
const TANK_PATHS: Array[String] = ["Depot/FuelTanks/FuelTankNorthWest", "Depot/FuelTanks/FuelTankNorthEast", "Depot/FuelTanks/FuelTankSouth"]
## Where the nine Fuel Cans of the older Map stood: the old spots a Unit parked on gains nothing at.
const OLD_SPOTS: Array[Vector2] = [Vector2(-88, -26), Vector2(88, -26), Vector2(-62, 14), Vector2(62, 14),
	Vector2(-3, -3), Vector2(3, -3), Vector2(0, 0), Vector2(-3, 3), Vector2(3, 3)]
## Ticks to let the physics space settle after a Unit is put down.
const SETTLE: int = Kit22.SETTLE
## The camera keys of the two Players (only tools name key codes: project.godot p1_camera, p2_camera) and the ticks a camera is given to
## settle after it is stepped to another view.
const CAMERA_KEYS: Array[Key] = [KEY_Q, KEY_SLASH]
const VIEW_TICKS: int = 90

## The Story 022 kit.
var a: Kit22
## The watch.
var watch: Watch


## Makes the Story 022 kit and the watch.
func _init(harness_node: Node) -> void:
	a = Kit22.new(harness_node)
	watch = Watch.new()
	watch.name = &"FuelBuildingWatch"
	var typed: Array[SupplyZone] = [zone(0), zone(1)]
	q().harness.split.add_child(watch)
	watch.setup(q().units.units, typed, q().hints)


## Removes the watch and the engine log counter: call it before the scenario's finish().
func close() -> void:
	watch.get_parent().remove_child(watch)
	watch.free()
	a.close()


## The Story 009 kit: kit, map, tokens, units, controller.
func q() -> Quick:
	return a.q()


## A Player's Unit.
func unit(player: int) -> Unit:
	return a.unit(player)


## The Fuel zone on a side of the depot: 0 the west one (facing Base A), 1 the east one (facing Base B).
func zone(side: int) -> SupplyZone:
	return q().map.find(ZONE_PATHS[side]) as SupplyZone


## The middle of a zone on the ground.
func centre(side: int) -> Vector3:
	return zone(side).global_position


## Puts a Player in play as a type of the Round's data at a place facing a way, with the share of the tank given (1.0 the whole
## tank, 0.0 none), the Unit leaving play for two ticks and coming back as a new one, settled: the zone sees a fresh Unit. A
## coroutine: await it.
func put(player: int, type_index: int, at: Vector3, facing: Vector3, fraction: float = 1.0) -> void:
	await a.mines().revive(player)
	await a.mines().put_stats(player, q().small_tank(type_index, fraction), at, facing)


## Like put(), with the watch filing from the very frame of the spawn and for `ticks` ticks after it: the Unit leaves play, two ticks
## pass, the watch starts and the new Unit is spawned (a call from a scenario acts before the tick of its frame, so row 0 is the frame
## the Unit appeared in and the zone's first gift is on the tape). The watch is off again at the end. A coroutine: await it.
func put_recorded(player: int, type_index: int, at: Vector3, facing: Vector3, fraction: float, ticks: int) -> void:
	await put_many_recorded([{"player": player, "type": type_index, "at": at, "facing": facing, "fraction": fraction}], ticks)


## put_recorded() for several Players at once, every Unit spawned in the same frame: each entry of `specs` is {player, type, at,
## facing, fraction}. A coroutine: await it.
func put_many_recorded(specs: Array, ticks: int) -> void:
	for spec: Dictionary in specs:
		await a.mines().revive(int(spec["player"]))
		if unit(int(spec["player"])).is_alive:
			unit(int(spec["player"])).leave_play()
	await q().kit.advance(a.mines().OUT_TICKS)
	watch.clear()
	watch.logging = true
	for spec: Dictionary in specs:
		var player: int = int(spec["player"])
		q().harness.drive(player, 0, 0)
		unit(player).spawn(q().units.pose(spec["at"], spec["facing"]), q().small_tank(int(spec["type"]), float(spec["fraction"])))
		q().units.cameras[player].snap_to_target()
	await q().kit.advance(ticks)
	watch.logging = false


## Puts a Player's Unit away on its lane spot (a Unit that is not in the way), settled. A coroutine.
func park(player: int) -> void:
	await a.k.walls().park(player)


## The rows the watch filed for a Player, as a typed Array of Dictionaries.
func rows(player: int) -> Array:
	return watch.rows[player]


## The Fuel a Unit gained over a run of rows, tick by tick: the rise from one row to the next (a burn is negative).
func steps(player: int) -> PackedFloat64Array:
	var found: PackedFloat64Array = []
	var list: Array = rows(player)
	for index: int in range(1, list.size()):
		found.append(float(list[index]["fuel"]) - float(list[index - 1]["fuel"]))
	return found


## The index of the first row from `from` on whose Fuel is above the one before it (a refill), or -1.
func first_gain(player: int, from: int = 1) -> int:
	var list: Array = rows(player)
	for index: int in range(maxi(from, 1), list.size()):
		if float(list[index]["fuel"]) > float(list[index - 1]["fuel"]) + 1.0e-9:
			return index
	return -1


## The index of the first row from `from` on that a zone lists the Unit in, or -1.
func first_listed(player: int, side: int, from: int = 0) -> int:
	var list: Array = rows(player)
	for index: int in range(from, list.size()):
		if bool(list[index]["listed"][side]):
			return index
	return -1


## The index of the last row that a zone lists the Unit in, or -1.
func last_listed(player: int, side: int) -> int:
	var list: Array = rows(player)
	for index: int in range(list.size() - 1, -1, -1):
		if bool(list[index]["listed"][side]):
			return index
	return -1


## Runs `count` ticks with the watch filing: the Players' rows start empty. A coroutine: await it.
func record(count: int) -> void:
	watch.clear()
	watch.logging = true
	await q().kit.advance(count)
	watch.logging = false


## The Fuel bar of a Player's HUD (a ProgressBar), or null.
func fuel_bar(player: int) -> ProgressBar:
	return q().units.huds[player].find_child("FuelBar", true, false) as ProgressBar


## The ticks a Unit of the type takes to fill from `start_fuel` while stopped in a Fuel zone, counted from the tick of the first
## gift to the tick the tank is whole, by the story's rule and nothing else: each tick the zone gives the whole tank over
## `seconds` times the tick (less what the tank has room for) and then the Unit burns its standing rate. -1 when it never fills.
func fill_ticks(stats: UnitStats, seconds: float, start_fuel: float = 0.0) -> int:
	var tick: float = 1.0 / Engine.physics_ticks_per_second
	var fuel: float = start_fuel
	for count: int in range(1, 100000):
		fuel += stats.fuel_capacity / seconds * tick
		if fuel >= stats.fuel_capacity:
			return count
		fuel = maxf(fuel - stats.fuel_use_idle * tick, 0.0)
	return -1


## What the recorded rows of a Player say about a fill: {first (the row of the first gain, -1 for none), full (the row of the first
## fuel_changed that held the whole capacity, -1 for none), ticks (full - first + 1, -1 when either is missing), start (the Fuel in
## the row before the first gain), most (the most Fuel any row or any report held), capacity}.
func fill_of(player: int) -> Dictionary:
	var list: Array = rows(player)
	var capacity: float = unit(player).fuel_capacity
	var first: int = first_gain(player)
	var full_frame: int = -1
	var most: float = 0.0
	for change: Dictionary in watch.changes[player]:
		most = maxf(most, float(change["fuel"]))
		if full_frame < 0 and first >= 0 and float(change["fuel"]) >= capacity and int(change["frame"]) >= int(list[first]["frame"]):
			full_frame = int(change["frame"])
	var full: int = -1
	for index: int in list.size():
		most = maxf(most, float(list[index]["fuel"]))
		if full < 0 and full_frame >= 0 and int(list[index]["frame"]) == full_frame:
			full = index
	return {"first": first, "full": full, "ticks": full - first + 1 if full >= 0 and first >= 0 else -1,
		"start": float(list[first - 1]["fuel"]) if first >= 1 else -1.0, "most": most, "capacity": capacity}


## The rule, run again from what the watch filed, tick by tick: a Unit is given the whole tank over `seconds` times the tick (up to
## full) in a tick when it was alive, the zone listed it in this row and the row before (the list the zone read in its own tick is
## the one the watch reads after it, in the same frame) and its real speed in the row before was at most `stopped` (the zone reads
## it before the Unit's own tick); then it burns its standing rate when the drive speed in the row before was approximately zero,
## else its moving rate. Every row's Fuel from the second on must equal that to a millionth. Returns the problems for the rows
## that do not (the first three), under a label; oracle_judged says how many rows were judged.
func oracle(player: int, side: int, seconds: float, stopped: float, label: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var list: Array = rows(player)
	var stats: UnitStats = unit(player).stats
	var tick: float = 1.0 / Engine.physics_ticks_per_second
	var judged: int = 0
	for index: int in range(1, list.size()):
		var now: Dictionary = list[index]
		var before: Dictionary = list[index - 1]
		if not bool(now["alive"]) or not bool(before["alive"]):
			continue
		var gives: bool = bool(now["listed"][side]) and bool(before["listed"][side]) and float(before["speed"]) <= stopped
		var fuel: float = float(before["fuel"])
		if gives:
			fuel = minf(fuel + stats.fuel_capacity / seconds * tick, stats.fuel_capacity)
		var rate: float = stats.fuel_use_idle if is_zero_approx(float(before["drive"])) else stats.fuel_use
		if fuel > 0.0:
			fuel = maxf(fuel - rate * tick, 0.0)
		judged += 1
		if absf(fuel - float(now["fuel"])) > 1.0e-6 and problems.size() < 3:
			problems.append("%s: row %d held %.6f Fuel, the rule says %.6f (listed %s, real speed %.4f, drive %.4f)" % [label, index, float(now["fuel"]), fuel, gives, float(before["speed"]), float(before["drive"])])
	oracle_judged = judged
	return problems


## How many rows the last oracle() call judged.
var oracle_judged: int = 0


## Steps a Player's camera with its real key until it is in the view from above (or in the chase view; the view of a camera is the sign of
## its settings' distance: a view from above has one) and lets it settle. A coroutine: await it.
func view(player: int, above: bool) -> void:
	var camera: ChaseCamera = q().units.cameras[player]
	var steps: int = 0
	while (camera.settings.distance > 0.0) != above and steps < 3:
		await q().kit.press_settled([CAMERA_KEYS[player]] as Array[Key])
		steps += 1
	await q().kit.advance(VIEW_TICKS)
