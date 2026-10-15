extends RefCounted
## What the Story 019 scenarios (garage_scrap_walls with its modules, and garage_scrap_walls_showcase) share on top
## of the Story 018 kit (base_walls_kit.gd: the 60 Base-wall panels, the Turrets and the staging; under it the
## Story 014, 012, 011 and 009 kits): the 28 Wall Panels of the Garages (10 a Base, in the three nodes under its
## Garage) and of the two walls in the field (8, in the Map's FieldWalls node) found by run and index, the five
## runs' numbers (the test inputs of AC-1 and AC-4), a record of every hit_points_changed and destroyed they emit,
## a place on a run in its frame (a Base-local one for a Garage wall, a world one for a field wall) and the
## restore of everything a Round leaves fallen. Tooling only: nothing under src/ depends on this file; loaded with
## a preload constant. Implements: production/epics/wasteland-fire/story-019-garage-and-scrap-wall-panels.md, Test
## Evidence.

## The Story 018 kit: k.m is the Story 014 kit, k.m.w the Story 012 kit, k.m.w.s the Story 011 kit.
const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The five runs: a Garage's back wall and its two side walls, then the two walls in the field.
const BACK: int = 0
const LEFT: int = 1
const RIGHT: int = 2
const WEST: int = 3
const EAST: int = 4
const GARAGE_RUNS: Array[int] = [0, 1, 2]
const FIELD_RUNS: Array[int] = [3, 4]
## Each run's node under a Base (a Garage wall) or under the Map (a field wall).
const RUN_PATHS: Array[String] = ["Garage/GarageBack", "Garage/GarageSideLeft", "Garage/GarageSideRight", "FieldWalls/FieldWallWest", "FieldWalls/FieldWallEast"]
const RUN_NAMES: Array[String] = ["GarageBack", "GarageSideLeft", "GarageSideRight", "FieldWallWest", "FieldWallEast"]
## The story's numbers, the test inputs (AC-1, AC-4): panels in each run and the length of one, metres; where the
## first starts along the run (Base-local for a Garage wall, world z for a field wall); the run's outward direction
## (out of the Garage; away from the middle of the Map) and the direction along it; how far from the frame's axis
## (the Base's, or the Map's) its inner and its outer face lie along that direction; every panel's depth.
const COUNTS: Array[int] = [4, 3, 3, 4, 4]
const LENGTHS: Array[float] = [3.5, 3.3333333, 3.3333333, 3.0, 3.0]
const STARTS: Array[float] = [-7.0, 2.0, 2.0, 6.0, 6.0]
const OUTWARD: Array[Vector3] = [Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
const ALONG: Array[Vector3] = [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1), Vector3(0, 0, 1)]
const INNER_FACES: Array[float] = [12.0, 6.0, 6.0, 10.75, 10.75]
const OUTER_FACES: Array[float] = [13.0, 7.0, 7.0, 13.25, 13.25]
const DEPTHS: Array[float] = [1.0, 1.0, 1.0, 2.5, 2.5]
const HEIGHT: float = 2.0
const HIT_POINTS: float = 40.0
## The scene of each run's panels.
const SCENES: Array[String] = ["wall_panel_garage_back", "wall_panel_garage_side", "wall_panel_garage_side", "wall_panel_scrap", "wall_panel_scrap"]
## The panel of each run a drive uses: a lane clear of the Flag Walls, a spawn spot's line, a Turret and a tower.
## The back wall's third panel lies at x 0 to 3.5, clear of the Flag box's lane at the Garage's front corner; a side
## wall's middle panel lies at z 5.67 to 8.33, between the spawn spots' line (z 5) and the back; the field walls'
## third panel lies at z 12 to 15, clear of the wreck beyond the west wall.
const LANE: Array[int] = [2, 1, 1, 2, 2]
## Metres of clear room behind a Unit that drives at a run's face from inside (the Garage; the middle of the Map) and
## from outside it (the yard beside the Garage; away from the middle), measured from that face to the nearest thing
## behind. The back wall's outside is the 0.7 m gap behind it, where no Unit fits (zero).
const ROOM_INSIDE: Array[float] = [16.0, 12.0, 12.0, 21.5, 21.5]
const ROOM_OUTSIDE: Array[float] = [0.0, 7.7, 7.7, 28.0, 28.0]
## A drive starts with the Unit's front RUN metres from the face, or less when the room behind it does not allow,
## and ROOM_MARGIN metres between its rear and the nearest thing.
const RUN: float = 14.0
const ROOM_MARGIN: float = 0.5
## How far in or out of a run's faces a shot-mask ray along a panel's middle runs, metres (a back wall's outer end
## stays in the 0.7 m gap: the Base's own back wall stands behind it).
const RAY_OUT: Array[float] = [0.3, 4.0, 4.0, 4.0, 4.0]
const RAY_IN: float = 4.0
## The physics layers of the Units (2) and the Gyrocopters (16), which a Shot stops on and a ray at a panel leaves out.
const UNIT_LAYERS: int = 2 | 16
## The ticks a drive may take, and the metres past the far face where a drive through a breach is over (a Garage side wall
## has the Base's own wall 7.7 m behind it, so a Truck's centre stops 4 m past; a field wall has room).
const RUN_LIMIT_TICKS: int = 420
const PAST_GARAGE: float = 4.0
const PAST_FIELD: float = 6.0
## The first Garage spot's side wall: the left spot (-4, 0, 5) lies by the left wall, the right one by the right.
const SPOT_X: float = 4.0
const SPOT_Z: float = 5.0

## The Story 018 kit.
var k: Kit18
## The Garage panels by Base, then run (0 to 2), then index along the run: garage[base_index][run][index].
var garage: Array = []
## The field panels by run (3 or 4), then index: field[run - 3][index].
var field: Array = []
## Every hit_points_changed of one of these panels: {panel, hp, tick, look}, in order; look is the look shown when
## it was emitted.
var hits: Array[Dictionary] = []
## Every destroyed of one of these panels: {panel, tick}, in order.
var falls: Array[Dictionary] = []


## Makes the Story 018 kit, finds the 28 panels and records what they emit.
func _init(harness_node: Node) -> void:
	k = Kit18.new(harness_node)
	for base: Base in k.m.w.bases:
		var by_run: Array = []
		for run: int in GARAGE_RUNS:
			by_run.append(_find(base, run))
		garage.append(by_run)
	var map: MapField = k.q().harness.split.field
	for run: int in FIELD_RUNS:
		field.append(_find(map, run))


## The panels of a run under a node (a Base or the Map), in order, each recorded; null where the scene lacks one.
func _find(holder_parent: Node, run: int) -> Array[Structure]:
	var row: Array[Structure] = []
	var holder: Node = holder_parent.get_node_or_null(RUN_PATHS[run])
	for index: int in COUNTS[run]:
		var panel: Structure = holder.get_node_or_null("Panel%d" % (index + 1)) as Structure if holder != null else null
		row.append(panel)
		if panel != null:
			panel.hit_points_changed.connect(func(hp: float, _maximum: float) -> void:
				hits.append({"panel": panel, "hp": hp, "tick": k.q().harness.ticks, "look": k.look_shown(panel)}))
			panel.destroyed.connect(func() -> void: falls.append({"panel": panel, "tick": k.q().harness.ticks}))
	return row


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	k.close()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## True for a field wall.
static func is_field(run: int) -> bool:
	return run >= WEST


## A panel of a run: of a Base's Garage (the base index) or of the field (the index is ignored).
func panel(base_index: int, run: int, index: int) -> Structure:
	if is_field(run):
		return field[run - WEST][index] as Structure
	return garage[base_index][run][index] as Structure


## All 28 panels: Base A's Garage's 10, Base B's 10, then the west wall's 4 and the east wall's 4.
func every() -> Array[Structure]:
	var found: Array[Structure] = []
	for base_index: int in garage.size():
		for run: int in GARAGE_RUNS:
			for index: int in COUNTS[run]:
				found.append(panel(base_index, run, index))
	for run: int in FIELD_RUNS:
		for index: int in COUNTS[run]:
			found.append(panel(0, run, index))
	return found


## The frame a run's numbers are in: the Base for a Garage wall, the world for a field wall.
func frame(base_index: int, run: int) -> Transform3D:
	return Transform3D.IDENTITY if is_field(run) else k.m.w.bases[base_index].global_transform


## Where a panel's middle lies along its run (the story's lengths from the first panel's start).
func centre(run: int, index: int) -> float:
	return STARTS[run] + LENGTHS[run] * (float(index) + 0.5)


## The frame-local point `out` metres from the frame's axis along a run's outward direction, level with panel
## `index` along the run.
func local_at(run: int, index: int, out: float) -> Vector3:
	return OUTWARD[run] * out + ALONG[run] * centre(run, index)


## The world point of that place.
func spot(base_index: int, run: int, index: int, out: float) -> Vector3:
	return frame(base_index, run) * local_at(run, index, out)


## The world direction out of the Garage (away from the middle of the Map) through a run.
func outward(base_index: int, run: int) -> Vector3:
	return frame(base_index, run).basis * OUTWARD[run]


## How far from the frame's axis, along a run's outward direction, a Unit of the given half length starts a drive
## into the run from inside it (outside false) or from outside it (outside true): its front RUN metres from the
## face, or as far as the room behind it allows.
func start_out(run: int, half: float, outside: bool) -> float:
	if outside:
		return OUTER_FACES[run] + minf(RUN, ROOM_OUTSIDE[run] - 2.0 * half - ROOM_MARGIN) + half
	return INNER_FACES[run] - minf(RUN, ROOM_INSIDE[run] - 2.0 * half - ROOM_MARGIN) - half


## How far a point lies from the frame's axis along a run's outward direction.
func along_out(base_index: int, run: int, world: Vector3) -> float:
	return (frame(base_index, run).affine_inverse() * world).dot(OUTWARD[run])


## The box of a panel's collider in the run's frame, read back from its shape.
func extent(base_index: int, run: int, target: Structure) -> AABB:
	var shape: CollisionShape3D = target.get_node("CollisionShape3D") as CollisionShape3D
	var size: Vector3 = (shape.shape as BoxShape3D).size
	return frame(base_index, run).affine_inverse() * (shape.global_transform * AABB(-size / 2.0, size))


## True while a shot-mask ray along a panel's middle at the shooting height, from just outside the run to inside it,
## meets anything: a standing panel does, a fallen one does not (the neighbours do not lie on it). The units and the
## gyrocopters layers are left out of the mask, so that a Unit staged on the line cannot answer for the panel.
func ray(base_index: int, run: int, index: int) -> bool:
	var height: Vector3 = Vector3.UP * q().controller.rules.shooting_height
	var mask: int = q().controller.rules.shot_collision_mask & ~UNIT_LAYERS
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			spot(base_index, run, index, OUTER_FACES[run] + RAY_OUT[run]) + height, spot(base_index, run, index, INNER_FACES[run] - RAY_IN) + height, mask)
	return not k.m.w.bases[0].get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Brings every panel (the Base walls, the Garages', the field's) and Flag Wall back whole, and the Turrets too when
## asked, with the physics space settled. Only while no Unit stands in one (Structure.restore()).
func restore_all(with_turrets: bool = false) -> void:
	for target: Structure in every():
		target.restore()
	await k.restore_all(with_turrets)


## The Base-local place of a Garage spot's wall panel line: the first panel along the left or right wall whose span
## holds the spot's z, and the spot itself.
func spot_point(base_index: int, side: int) -> Vector3:
	return k.m.w.point(base_index, Vector3(-SPOT_X if side == LEFT else SPOT_X, 0.0, SPOT_Z))


## One pair of drives through a lane panel's breach, one Unit of each Player: in its own Garage, from the yard into it
## (outside) or out of it, or at a field wall each, one from away from the middle of the Map and the other from the
## middle, so that the two Units drive the same way and never cross. The neighbours are tested standing while the lane
## panel is down.
func drive_pair(type_index: int, runs: Array, outsides: Array, problems: PackedStringArray) -> void:
	var stats: UnitStats = q().units.stats(type_index)
	var half: float = stats.collision_size.z / 2.0
	var lanes: Array[int] = [LANE[runs[0]], LANE[runs[1]]]
	await restore_all()
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		var run: int = runs[player]
		panel(player, run, lanes[player]).destroy()
		spots.append(spot(player, run, lanes[player], start_out(run, half, outsides[player])))
		facings.append(outward(player, run) * (-1.0 if outsides[player] else 1.0))
	await q().map.stage([type_index, type_index], spots, facings, true)
	for player: int in Kit.PLAYERS:
		var run: int = runs[player]
		var standing: int = 0
		var blocking: int = 0
		for index: int in COUNTS[run]:
			if index != lanes[player]:
				standing += 1 if panel(player, run, index).is_standing else 0
				blocking += 1 if ray(player, run, index) else 0
		q().kit.need(problems, standing == COUNTS[run] - 1 and blocking == COUNTS[run] - 1 and not ray(player, run, lanes[player]), "%s with its lane panel down: %d standing and %d blocking of %d neighbours, the breach's ray blocked %s" % [RUN_NAMES[run], standing, blocking, COUNTS[run] - 1, ray(player, run, lanes[player])])
	q().map.clear_log()
	var done: Array[bool] = [false, false]
	var touched: Array[int] = [0, 0]
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			var run: int = runs[player]
			var unit: Unit = q().units.units[player]
			var past: float = PAST_FIELD if is_field(run) else PAST_GARAGE
			var far_face: float = INNER_FACES[run] if outsides[player] else OUTER_FACES[run]
			var along: float = along_out(player, run, unit.global_position)
			done[player] = done[player] or (along <= far_face - past if outsides[player] else along >= far_face + past)
			touched[player] += 1 if q().map.wall_contact(unit) else 0
			q().harness.drive(player, 0 if done[player] else 1, 0)
		await q().kit.tick()
		if done[0] and done[1]:
			break
	q().harness.release_all()
	for player: int in Kit.PLAYERS:
		var label: String = "p%d %s through %s's lane breach from %s" % [player + 1, stats.type_id, RUN_NAMES[runs[player]], "outside" if outsides[player] else "inside"]
		q().kit.need(problems, done[player] and touched[player] == 0, "%s: got through %s, touched a wall on %d ticks" % [label, done[player], touched[player]])
