extends RefCounted
## What the Story 006 scenarios (fuel, fuel_cans, fuel_showcase) share: both Units' fuel_changed
## with the runner's tick of each and a count per Player, a Player's Unit's Fuel and starting tank,
## the Fuel Cans found by their node group, key holds, a coast that counts the burns, and a drive
## with real keys onto a point. The one shared helper Story 006 allows, on check_kit.gd; loaded by
## a preload constant (nothing under tools/ declares a class_name). Tooling only.
## Implements: production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md, Test Evidence.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The node group every Fuel Can's root joins: fuel_can.tscn stores it, SplitScreen restocks it.
const CAN_GROUP: StringName = &"fuel_cans"
## Heading error under which drive_to() holds no steer key, radians.
const STEER_DEADBAND: float = 0.05
## Ticks drive_to() or coast() runs before it gives up.
const DRIVE_LIMIT_TICKS: int = 900

## The runner.
var harness: Harness
## The shared check helpers.
var kit: Kit
## The Units of the launch scene, by Player.
var units: Array[Unit] = []
## Every fuel_changed of either Unit since the kit was made: (player_index, tick), in order.
var changes: Array[Vector2i] = []
## The Fuel each of those said, in the same order (64-bit floats: a Vector2 would round them).
var fuels: Array[float] = []
## How many of those each Player's Unit emitted, by Player.
var counts: Array[int] = [0, 0]


func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	units.assign([harness.split.player_1_unit, harness.split.player_2_unit])
	for player: int in Kit.PLAYERS:
		units[player].fuel_changed.connect(func(fuel_now: float, _capacity: float) -> void:
			counts[player] += 1
			changes.append(Vector2i(player, harness.ticks))
			fuels.append(fuel_now))


## The Fuel in a Player's Unit's tank now (Unit.fuel).
func fuel(player: int) -> float:
	return units[player].fuel


## The Fuel a Player's Unit said with its last fuel_changed since the kit was made, or -1.0.
func last_said(player: int) -> float:
	for index: int in range(changes.size() - 1, -1, -1):
		if changes[index].x == player:
			return fuels[index]
	return -1.0


## The starting tank of a Player's Unit's type: fuel_capacity x spawn_fuel_fraction in 0..1.
func start_tank(player: int) -> float:
	return units[player].stats.fuel_capacity * clampf(units[player].stats.spawn_fuel_fraction, 0.0, 1.0)


## The tick of a Player's last entry in a (player_index, tick) record of unit_kit.gd, or -1.
func last_tick(records: Array[Vector2i], player: int) -> int:
	for index: int in range(records.size() - 1, -1, -1):
		if records[index].x == player:
			return records[index].y
	return -1


## The tick of a Player's first fuel_changed that said zero Fuel, from a record index on, or -1.
func first_zero_tick(player: int, since: int) -> int:
	for index: int in range(since, changes.size()):
		if changes[index].x == player and fuels[index] == 0.0:
			return changes[index].y
	return -1


## The FuelCans in CAN_GROUP, sorted by node name (FuelCan1 to FuelCan5, greybox_fuel_cans.tscn).
func cans() -> Array[FuelCan]:
	var found: Array[FuelCan] = []
	for node: Node in harness.get_tree().get_nodes_in_group(CAN_GROUP):
		if node is FuelCan:
			found.append(node as FuelCan)
	found.sort_custom(func(a: FuelCan, b: FuelCan) -> bool: return String(a.name) < String(b.name))
	return found


## The distance between two points in the ground plane (x and z), metres: how a Can measures a Unit.
func ground_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))


## The signed angle from a Player's Unit's facing to a point in the ground plane, radians: + is
## left.
func heading_error(player: int, point: Vector3) -> float:
	var facing: Vector3 = -units[player].global_transform.basis.z
	var to_point: Vector3 = point - units[player].global_position
	return atan2(facing.z * to_point.x - facing.x * to_point.z, facing.x * to_point.x + facing.z * to_point.z)


## Holds a Player's throttle (1, -1, 0) and steer (1 left, -1 right) keys for the ticks, then lets
## go: the highest absolute drive speed its Unit showed. A coroutine: await it.
func hold(player: int, throttle: int, steer: int, ticks: int) -> float:
	var peak: float = 0.0
	harness.drive(player, throttle, steer)
	for _tick: int in ticks:
		await kit.tick()
		peak = maxf(peak, absf(units[player].current_speed))
	harness.drive(player, 0, 0)
	return peak


## Lets go of a Player's keys and waits until its Unit's drive speed is approximately zero, at most
## DRIVE_LIMIT_TICKS, then rest_ticks more. Returns Vector3i(the ticks that began with a drive speed
## not approximately zero, the fuel_changed until the stop, the fuel_changed in the rest): Story 006
## AC-2 has the first two equal and the third zero. A coroutine: await it.
func coast(player: int, rest_ticks: int) -> Vector3i:
	harness.drive(player, 0, 0)
	var start: int = counts[player]
	var moving: int = 0
	while not is_zero_approx(units[player].current_speed) and moving < DRIVE_LIMIT_TICKS:
		moving += 1
		await kit.tick()
	var stopped: int = counts[player]
	await kit.advance(rest_ticks)
	return Vector3i(moving, stopped - start, counts[player] - stopped)


## Drives a Player's Unit onto a point with real keys: every tick it holds the steer key toward the
## point while the heading is off by STEER_DEADBAND or more, and the throttle while the drive speed
## is under cruise (feathered: an event per change), until the Unit's origin is within radius of the
## point in the ground plane, at most DRIVE_LIMIT_TICKS. A Unit with Fuel turns only while it rolls
## (max_speed / turn_rate is its turning radius): put it down facing the point. Its keys are up on
## return. The ticks driven, or -1. A coroutine: await it.
func drive_to(player: int, point: Vector3, cruise: float, radius: float) -> int:
	for count: int in range(1, DRIVE_LIMIT_TICKS + 1):
		var error: float = heading_error(player, point)
		var steer: int = 0 if absf(error) < STEER_DEADBAND else int(signf(error))
		harness.drive(player, 1 if absf(units[player].current_speed) < cruise else 0, steer)
		await kit.tick()
		if ground_distance(units[player].global_position, point) <= radius:
			harness.drive(player, 0, 0)
			return count
	harness.drive(player, 0, 0)
	return -1
