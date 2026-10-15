extends RefCounted
## What the Story 018 scenarios (base_walls with its modules, and base_walls_showcase) share on top of the
## Story 014 kit (mines_kit.gd: the Mines, and under it the Story 012 kit with the Units, Bases, Flags,
## Flag Walls, real keys and logs): the 60 Wall Panels found by run and index under each Base's Walls node,
## a record of every hit_points_changed (with the look shown when it was emitted) and destroyed they emit,
## the four Turrets and every Shot they fire, where a Unit stands level with a panel on either side of its
## run, a staged Unit with the air cleared, and the restore of everything a Round leaves fallen. Story 019
## reuses it for the Garage walls and the scrap walls. Tooling only: nothing under src/ depends on this
## file; loaded with a preload constant. Implements:
## production/epics/wasteland-fire/story-018-base-wall-panels.md, Test Evidence.

## The Story 014 kit: m.w (Story 012 kit), m.w.s (Story 011 kit), m.w.s.q (Story 009 kit).
const Mines: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The five runs of a Base's walls, in the order of the nodes under its Walls node (WALL_RUN_NAMES in the
## runner).
const BACK: int = 0
const LEFT: int = 1
const RIGHT: int = 2
const GATE_LEFT: int = 3
const GATE_RIGHT: int = 4
const RUN_NAMES: Array[String] = ["WallBack", "WallLeft", "WallRight", "GateWallLeft", "GateWallRight"]
## The story's numbers, the test inputs (AC-1): panels in each run and the length of one, metres; where the
## first starts along the run (Base-local: the corner tower's inner face, or the Gate post), the run's
## outward direction (out of the yard) and how far from the Base's axis its yard face and its outer face lie
## along it; every panel's depth, height and hit points.
const COUNTS: Array[int] = [8, 8, 8, 3, 3]
const LENGTHS: Array[float] = [3.4625, 3.2125, 3.2125, 2.7833333, 2.7833333]
const STARTS: Array[float] = [-13.85, -12.85, -12.85, -13.85, 5.5]
const OUTWARD: Array[Vector3] = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, -1)]
const ALONG: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(1, 0, 0)]
const INNER_FACES: Array[float] = [13.7, 14.7, 14.7, 13.7, 13.7]
const OUTER_FACES: Array[float] = [15.0, 16.0, 16.0, 15.0, 15.0]
## Metres from each run's outer face to the nearest thing out there: how far the rear of a Unit may start outside
## it. The Map's shore edge stands 11.6 to 11.9 m behind a back wall (world x +-146.6 to 146.9, measured by a ray
## along the wall); the others have 34 m or more. A drive starts with the Unit's front RUN metres from the face,
## or less when the room behind it does not allow, and ROOM_MARGIN metres between its rear and the nearest thing.
const ROOM_OUTSIDE: Array[float] = [11.5, 34.0, 34.0, 60.0, 60.0]
const RUN: float = 14.0
const ROOM_MARGIN: float = 0.5
const DEPTH: float = 1.3
const HEIGHT: float = 2.0
const HIT_POINTS: float = 40.0
## The panel of each run a drive uses: a lane clear of the Flag Walls, the Garage, a Turret and a tower from
## both sides.
const LANE: Array[int] = [1, 3, 3, 0, 2]
## The node names of a panel's looks in the order of the hit points they stand for, and its rubble.
const LOOK_NAMES: Array[String] = ["Mesh", "MeshDamaged1", "MeshDamaged2"]
const RUBBLE_NAME: String = "Rubble"
## The two Turrets of a Base, by side, as the Turrets kit has them.
const TURRET_NAMES: Array[String] = ["TurretLeft", "TurretRight"]
## Ticks to let the physics space settle after a Unit is put down or a piece changes.
const SETTLE: int = 3
## A Shot's longest flight in ticks, so a Shot in the air cannot land on the next Unit staged.
const IN_FLIGHT_TICKS: int = 45

## The Story 014 kit.
var m: Mines
## The Wall Panels by Base, then run, then index along the run: panels[base][run][index].
var panels: Array = []
## The Turrets by Base, then side: turrets[base][side].
var turrets: Array = []
## Every hit_points_changed of a panel: {panel, hp, tick, look}, in order; look is the look shown when it
## was emitted.
var hits: Array[Dictionary] = []
## Every destroyed of a panel: {panel, tick}, in order.
var falls: Array[Dictionary] = []
## Every Shot a Turret fired: {turret, tick, shot, end}; end is Vector3.INF until the Shot leaves the tree.
var fired: Array[Dictionary] = []


## Makes the Story 014 kit, finds the 60 panels and the four Turrets and records what they emit.
func _init(harness_node: Node) -> void:
	m = Mines.new(harness_node)
	var q: Quick = m.w.s.q
	for base: Base in m.w.bases:
		var by_run: Array = []
		for run: int in RUN_NAMES.size():
			var row: Array[Structure] = []
			var holder: Node = base.get_node_or_null("Walls/" + RUN_NAMES[run])
			for index: int in COUNTS[run]:
				var panel: Structure = holder.get_node_or_null("Panel%d" % (index + 1)) as Structure if holder != null else null
				row.append(panel)
				if panel != null:
					panel.hit_points_changed.connect(func(hp: float, _maximum: float) -> void:
						hits.append({"panel": panel, "hp": hp, "tick": q.harness.ticks, "look": look_shown(panel)}))
					panel.destroyed.connect(func() -> void: falls.append({"panel": panel, "tick": q.harness.ticks}))
			by_run.append(row)
		panels.append(by_run)
		var sides: Array[Turret] = []
		for turret_name: String in TURRET_NAMES:
			var turret: Turret = base.get_node_or_null("Turrets/" + turret_name) as Turret
			sides.append(turret)
			if turret != null:
				turret.fired.connect(_on_fired.bind(turret))
		turrets.append(sides)


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	m.close()


## The Story 009 kit.
func q() -> Quick:
	return m.w.s.q


## A panel of a Base's run (null when the scene lacks it).
func panel(base_index: int, run: int, index: int) -> Structure:
	return panels[base_index][run][index] as Structure


## All 60 panels, Base A's first, run by run.
func every() -> Array[Structure]:
	var found: Array[Structure] = []
	for base_index: int in panels.size():
		for run: int in RUN_NAMES.size():
			for index: int in COUNTS[run]:
				found.append(panel(base_index, run, index))
	return found


## The Turret of a side of a Base (null when the scene lacks it), and all four.
func turret(base_index: int, side: int) -> Turret:
	return turrets[base_index][side] as Turret


func all_turrets() -> Array[Turret]:
	var found: Array[Turret] = []
	for base_index: int in turrets.size():
		for side: int in TURRET_NAMES.size():
			found.append(turret(base_index, side))
	return found


## Where a panel's middle lies along its run, Base-local metres (the story's lengths from the first panel's
## start).
func centre(run: int, index: int) -> float:
	return STARTS[run] + LENGTHS[run] * (float(index) + 0.5)


## The Base-local point `out` metres from the Base's axis along a run's outward direction, level with panel
## `index` along the run.
func local_at(run: int, index: int, out: float) -> Vector3:
	return OUTWARD[run] * out + ALONG[run] * centre(run, index)


## How far from the Base's axis, along a run's outward direction, a Unit of the given half length starts a drive
## into the run from the yard (outside false) or from outside (outside true): its front RUN metres from the face,
## or as far as the room behind it allows.
func start_out(run: int, half: float, outside: bool) -> float:
	if outside:
		return OUTER_FACES[run] + minf(RUN, ROOM_OUTSIDE[run] - 2.0 * half - ROOM_MARGIN) + half
	return INNER_FACES[run] - RUN - half


## The world point of that place at a Base.
func spot(base_index: int, run: int, index: int, out: float) -> Vector3:
	return m.w.point(base_index, local_at(run, index, out))


## The world direction out of the yard through a run (a Unit facing it faces the wall from the yard) and
## into the yard through it.
func outward(base_index: int, run: int) -> Vector3:
	return m.w.way(base_index, OUTWARD[run])


## The Base-local box of a panel's collider, read back from its shape.
func extent(base_index: int, target: Structure) -> AABB:
	var shape: CollisionShape3D = target.get_node("CollisionShape3D") as CollisionShape3D
	var size: Vector3 = (shape.shape as BoxShape3D).size
	return m.w.bases[base_index].global_transform.affine_inverse() * (shape.global_transform * AABB(-size / 2.0, size))


## Which look a panel shows, read from its scene's nodes by name: 0 whole, 1 or 2 a damaged look, -1 the
## rubble, -2 unless exactly one of them is shown.
func look_shown(target: Structure) -> int:
	return m.w.look_shown(target)


## The Structures a Round leaves standing or fallen at a Base: its panels, its Flag Walls and its Turrets.
func pieces() -> Array[Structure]:
	var found: Array[Structure] = []
	found.append_array(every())
	found.append_array(m.w.all())
	for each: Turret in all_turrets():
		found.append(each)
	return found


## Brings every panel and Flag Wall back whole, standing or fallen, with the physics space settled, and the four
## Turrets too when asked (a check that needs them down leaves them down). Only while no Unit stands in one
## (Structure.restore()).
func restore_all(with_turrets: bool = false) -> void:
	for piece: Structure in pieces():
		if with_turrets or not piece is Turret:
			piece.restore()
	await q().kit.advance(SETTLE)


## Takes both Bases' Turrets down, as a tool may, so a step at a Base is not shot at.
func turrets_down() -> void:
	for each: Turret in all_turrets():
		each.destroy()
	await q().kit.advance(SETTLE)


## True when a ray on the Shot's mask between two world points meets anything.
func blocked(from: Vector3, to: Vector3) -> bool:
	return m.w.blocked(from, to)


## The Player's Unit is put in play as a type at a world place facing a direction, after the air is empty and
## the other Player's Unit is parked in its own Garage: a Unit put down where another stands is perched on it,
## and a Shot still in the air would land on it. A coroutine: await it.
func stage(player: int, type_index: int, at: Vector3, facing: Vector3) -> void:
	await clear(player)
	await park(1 - player)
	q().units.retype(player, type_index, at, facing)
	await q().kit.advance(SETTLE)


## Puts a Player's Unit on its own Base's spare spawn spot in the Garage, facing out of the Gate: out of every
## Turret's view and out of the way of anything staged in front of the Gates. A coroutine: await it.
func park(player: int) -> void:
	await m.revive(player)
	var spot_in_garage: Vector3 = m.w.bases[player].spare_spawn_points[0].global_position
	if q().units.units[player].global_position.distance_to(spot_in_garage) <= 0.5:
		return
	m.w.s.flags.teleport(player, spot_in_garage, m.w.way(player, Vector3.FORWARD))
	await q().kit.advance(SETTLE)


## Takes the Player's Unit out of play and waits, at most a Shot's longest flight, until no Shot is in the air.
func clear(player: int) -> void:
	await m.revive(player)
	var unit: Unit = q().units.units[player]
	if unit.is_alive:
		unit.leave_play()
	for _tick: int in IN_FLIGHT_TICKS:
		if unit.get_tree().get_nodes_in_group(&"shots").is_empty():
			return
		await q().kit.tick()


## Lets `ticks` ticks pass and reports, for each Turret, whether it aimed (its state was AIMING or FIRING at
## some tick) and how many Shots it fired: {Turret: {aimed, shots}}. A coroutine: await it.
func watch(ticks: int) -> Dictionary:
	var seen: Dictionary = {}
	var mark: int = fired.size()
	for each: Turret in all_turrets():
		seen[each] = {"aimed": false, "shots": 0}
	var kit: Object = q().kit
	kit.on_tick = func() -> void:
		for each: Turret in seen:
			seen[each]["aimed"] = bool(seen[each]["aimed"]) or each.state == Turret.State.AIMING or each.state == Turret.State.FIRING
	await kit.advance(ticks)
	kit.on_tick = Callable()
	for index: int in range(mark, fired.size()):
		seen[fired[index]["turret"]]["shots"] += 1
	return seen


## Records one Shot a Turret fired and, when it leaves the tree, where it ended.
func _on_fired(shot: Shot, who: Turret) -> void:
	var record: Dictionary = {"turret": who, "tick": q().harness.ticks, "shot": shot, "end": Vector3.INF}
	fired.append(record)
	shot.tree_exiting.connect(func() -> void: record["end"] = shot.global_position)
