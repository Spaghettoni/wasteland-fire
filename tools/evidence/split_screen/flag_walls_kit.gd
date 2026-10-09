extends RefCounted
## What the Story 012 scenarios (flag_walls and the scripts it runs: flag_walls_moves, _over,
## _flows, _returns, _bodies and _looks; and flag_walls_showcase) share on top of the Story 011 kit
## (unit_swap_kit.gd: the Units, Bases, Flags, the real keys and the logs): the eight Flag Walls
## found by name under each Base's Defences node, a record of every hit_points_changed (with the
## look shown when it was emitted) and destroyed they emit with the runner's tick, the places a
## Unit is put in front of each side of a box, the shot-mask ray that tells a standing Flag Wall
## from a fallen one, which look a Flag Wall shows, the shot cadence of a type and the Round's
## restart. Tooling only: nothing under src/ depends on this file; loaded with a preload constant.
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md, Test Evidence.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the kits they stand on, the waits, the Base's places.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## The sides of a box, in the order of SIDE_NAMES.
const GATE: int = 0
const GARAGE: int = 1
const LEFT: int = 2
const RIGHT: int = 3
## The node name of each side's Flag Wall under a Base's Defences node.
const SIDE_NAMES: Array[String] = ["FlagWallGate", "FlagWallGarage", "FlagWallLeft", "FlagWallRight"]
## The Base-local direction from the Flag's seat out to each side (the gate is in local -Z).
const OUT: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
## The Flag's seat in Base-local metres: the box is centred on it (AC-1).
const SEAT: Vector3 = Vector3(0, 0, -7)
## Metres from the seat to the outer face of every Flag Wall: flush with the water tower's legs
## (AC-1).
const FACE: float = 2.3
## A Flag Wall's drawn height, metres, and its hit points (AC-1, AC-3): test inputs from the story.
const HEIGHT: float = 2.0
const HIT_POINTS: float = 40.0
## The node names of a Flag Wall's looks in the order of the hit points they stand for: its whole
## look (AC-1) and its first and second damaged looks (AC-9); and its rubble (AC-4).
const LOOK_NAMES: Array[String] = ["Mesh", "MeshDamaged1", "MeshDamaged2"]
const RUBBLE_NAME: String = "Rubble"
## Ticks to let the physics space settle after a Unit is put down or a Flag Wall changes.
const SETTLE: int = 3
## Metres out of a box where a Unit starts a drive into it (AC-1: 6 m is a run-up a Motorbike can
## use).
const RUN_UP: float = 6.0

## The Story 011 kit: s.q (Story 009 kit: kit, map, tokens, units, controller), s.flags, the logs.
var s: Swap
## The two Bases, by Player (the Base a Player owns).
var bases: Array[Base] = []
## The Flag Walls by Base, then by side: walls[base][side].
var walls: Array = []
## Every hit_points_changed of a Flag Wall: {wall, hp, max, tick, look}, in order; look is
## look_shown() read in the handler, so it is the look the wall shows when it emits (AC-9).
var hits: Array[Dictionary] = []
## Every destroyed of a Flag Wall: {wall, tick}, in order.
var falls: Array[Dictionary] = []


## Makes the Story 011 kit, finds the eight Flag Walls and records what they emit.
func _init(harness_node: Node) -> void:
	s = Swap.new(harness_node)
	bases = s.q.units.bases
	for base: Base in bases:
		var row: Array[Structure] = []
		for side_name: String in SIDE_NAMES:
			var wall: Structure = base.get_node_or_null("Defences/" + side_name) as Structure
			row.append(wall)
			if wall != null:
				wall.hit_points_changed.connect(func(hp: float, maximum: float) -> void:
					hits.append({"wall": wall, "hp": hp, "max": maximum, "tick": s.q.harness.ticks, "look": look_shown(wall)}))
				wall.destroyed.connect(func() -> void: falls.append({"wall": wall, "tick": s.q.harness.ticks}))
		walls.append(row)


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	s.close()


## The Flag Wall of a side of a Base's box (null when the scene lacks it).
func wall(base_index: int, side: int) -> Structure:
	return walls[base_index][side] as Structure


## All eight Flag Walls, Base A's four first.
func all() -> Array[Structure]:
	var found: Array[Structure] = []
	for base_index: int in bases.size():
		for side: int in SIDE_NAMES.size():
			found.append(wall(base_index, side))
	return found


## The world point of a Base-local point.
func point(base_index: int, local: Vector3) -> Vector3:
	return bases[base_index].global_transform * local


## The world direction of a Base-local direction.
func way(base_index: int, local: Vector3) -> Vector3:
	return bases[base_index].global_transform.basis * local


## Where a Unit is put to face a side of a Base's box from `distance` metres out of the seat, along
## that side's axis: [world position, world facing (toward the seat)].
func pose(base_index: int, side: int, distance: float) -> Array[Vector3]:
	return [point(base_index, SEAT + OUT[side] * distance), way(base_index, -OUT[side])]


## True when a ray on the Shot's mask from one world point to another meets anything: a standing
## Flag Wall does, a fallen one does not (the mask has the cover layer the Flag Walls stand on).
func blocked(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to,
			s.controller.rules.shot_collision_mask)
	return not bases[0].get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The ray of `blocked()` along a side's axis through the box at the shooting height, from outside
## the side to the seat: false once that side's Flag Wall is down (the others do not lie on it).
func axis_blocked(base_index: int, side: int) -> bool:
	var height: Vector3 = Vector3.UP * s.controller.rules.shooting_height
	return blocked(point(base_index, SEAT + OUT[side] * 4.0) + height, point(base_index, SEAT) + height)


## Which look a Flag Wall shows, read from its scene's nodes by name, never from the Structure's
## own list: 0 the whole look, 1 or 2 the first or second damaged look, -1 the rubble, or -2 unless
## exactly one of them is shown.
func look_shown(piece: Structure) -> int:
	var shown: Array[int] = []
	for index: int in LOOK_NAMES.size():
		var look: Node3D = piece.get_node_or_null(LOOK_NAMES[index]) as Node3D
		if look != null and look.visible:
			shown.append(index)
	var rubble: Node3D = piece.get_node_or_null(RUBBLE_NAME) as Node3D
	if rubble != null and rubble.visible:
		shown.append(-1)
	return shown[0] if shown.size() == 1 else -2


## Ticks between two shots of a type's weapon, and a settle.
func cadence(type_index: int) -> int:
	return s.q.harness.ticks_in(s.q.units.stats(type_index).fire_interval_seconds) + SETTLE


## The longest cadence of the data: what a Player waits after a placement before its first shot,
## because the Weapon is one node per Player and the interval of the type that fired last may still
## be running.
func longest_cadence() -> int:
	var longest: int = SETTLE
	for type_index: int in s.q.controller.unit_types().size():
		longest = maxi(longest, cadence(type_index))
	return longest


## Brings every Flag Wall back whole, standing or fallen, with the physics space settled. Only while
## no Unit stands in a box (Structure.restore()).
func restore_all() -> void:
	for piece: Structure in all():
		piece.restore()
	await s.q.kit.advance(SETTLE)


## Player `player` is put in front of a side of a Base's box as a type, `distance` out of the seat
## (the typed spawn of the Units kit, settled), with the other Player's Unit parked out of the way.
func face(player: int, type_index: int, base_index: int, side: int, distance: float) -> void:
	await park(1 - player)
	var at: Array[Vector3] = pose(base_index, side, distance)
	s.q.units.retype(player, type_index, at[0], at[1])
	await s.q.kit.advance(SETTLE)


## Puts a Player's Unit on the salt flat on its own side, clear of both Bases, the cover and the
## Fuel Cans (Quick.LANE_SPOT and its mirror), facing across the Map, so it is never in a line of
## fire or on a spawn spot of another check. A Unit put down where another stands is perched on it
## and carried along when that one moves (Unit's class doc), so the physics space settles before
## anything else is put down. Nothing is done for a Unit already parked. A coroutine: await it.
func park(player: int) -> void:
	var spot: Vector3 = Quick.LANE_SPOT if player == 0 else Quick.mirrored(Quick.LANE_SPOT)
	if s.q.units.units[player].global_position.distance_to(spot) <= 0.5:
		return
	s.flags.teleport(player, spot, Vector3.RIGHT)
	await s.q.kit.advance(SETTLE)


## The Round's restart (R) and both Players' Motorbikes chosen again.
func restart() -> void:
	await s.restart_and_play()


## True when the Player's Unit stands on the first spawn spot of its Base (the spot a Unit appears
## on).
func on_first_spot(player: int) -> bool:
	return s.q.units.units[player].global_position.distance_to(bases[player].spawn_point.global_position) <= 0.05


## The Player's HUD line about the Flags (FlagStatusLabel): "You carry the enemy Flag", "Your Flag
## is at home" or "Your Flag is away".
func status_text(player: int) -> String:
	var label: Label = s.q.units.huds[player].find_child("FlagStatusLabel", true, false) as Label
	return label.text if label != null else ""


## True when the Player's Unit carries the other Player's Flag, as the Round's rules say.
func carrying(player: int) -> bool:
	return s.controller.flag_status(player) == MatchController.FlagStatus.CARRYING_ENEMY


## How far the Player's Unit is from the seat of a Base along a side's axis, metres (negative
## inside).
func along(player: int, base_index: int, side: int) -> float:
	return (bases[base_index].to_local(s.q.units.units[player].global_position) - SEAT).dot(OUT[side])


## The Player's Motorbike is put RUN_UP out of a face of the other Player's box and driven in on the
## throttle until it carries the Flag (true) or the drive's limit passes. The Round's own rules hand
## it the Flag; nothing here moves it. A coroutine: await it.
func take_flag(player: int, base_index: int, side: int) -> bool:
	await face(player, Quick.MOTORBIKE, base_index, side, FACE + RUN_UP)
	return await s.flags.drive_until(player, 1, Swap.CRUISE, carrying.bind(player)) > 0


## The Carrier reverses out of the box along a side's axis until its centre is 1.5 m past the face.
func back_out(player: int, base_index: int, side: int) -> void:
	await s.flags.drive_until(player, -1, Swap.CRUISE, func() -> bool: return along(player, base_index, side) >= FACE + 1.5)


## The Carrier is put 24 m out of its own Base's Gate and driven in until the Round is over (true).
func deliver(player: int) -> bool:
	s.flags.teleport(player, s.outside_point(player), s.into_base(player))
	await s.q.kit.advance(SETTLE)
	return await s.flags.drive_until(player, 1, Swap.CRUISE, func() -> bool: return s.controller.is_round_over()) > 0


## One Shot of Player `player` by the real fire key; where it ended, waiting for the end (the Shot
## leaves the tree on its hit), or Vector3.INF. A coroutine: await it.
func shoot(player: int) -> Vector3:
	var units: Object = s.q.units
	var index: int = units.shots.size()
	await units.hold_fire(player, 1)
	await s.wait_until(func() -> bool: return index < units.shot_ends.size() and units.shot_ends[index] != Vector3.INF)
	return units.shot_ends[index] if index < units.shot_ends.size() else Vector3.INF
