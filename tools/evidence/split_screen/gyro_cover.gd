extends RefCounted
## Scenario gyro_cover of the split screen evidence harness (split_screen_harness.gd): the
## Gyrocopter flies over Map 01's cover and everything else still stops what it stopped, on the
## shipped data and Map (Story 009 AC-2). Five CHECK lines. cover_data: the twelve pieces on the
## cover layer, the ground types' masks and the Shot mask taking it, the Gyrocopter's leaving it
## out, its model rising over it (rise_body_mask) and the Base walls still on the map layer.
## gyro_crosses: at each of the twelve pieces (Player 1 the west one, Player 2 its east twin at the
## same time) the Gyrocopter crosses square to the long side through the middle at full throttle
## from RUN_UP before the face, then brakes to a stop past it: no wall contact, never slower than
## its top speed while any of it is over the piece, past it at the end, its model's lowest point at
## least the rise clearance above the piece's top on every tick the model's footprint (its box,
## turned with it) overlaps the piece's, and, where nothing the model rises over lies under the
## stop (the model's own query, widened by its margin), back at its hover once settled; at least
## SETTLES_JUDGED_MIN of the stops are judged. ground_stopped:
## a ground Unit (the Motorbike at a wreck, the Buggy at a container, the Truck at a scrap wall,
## map_cover's three runs, one Player per twin) is still stopped flush at the face and its Shot ends
## on it. walls_stop_gyro: the Gyrocopter driven at its own Base's gate wall is stopped flush.
## fire_over_cover: a Gyrocopter standing over the middle of a container fires, and its Shot ends at
## its muzzle, inside the container; a Motorbike's Shot at it from the open ground ends on the
## container's face and takes no hit point (Shots fly at the one shooting height, design/rules.md
## "Units"). A SPLIT line per run and shot.
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md AC-2. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=gyro_cover

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks and verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd).
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The west pieces by path from the Map; each one's twin is the same path with East for West.
const COVER: Array[String] = ["Cover/Wrecks/WreckWestOuterSouth", "Cover/Wrecks/WreckWestMiddleNorth",
	"Cover/Wrecks/WreckWestInnerSouth", "Cover/Wrecks/WreckWestInnerNorth", "Cover/Containers/ContainerWest",
	"Cover/ScrapWalls/ScrapWallWest"]
## The axis of each piece of COVER, in its own frame, a crossing runs along: square to its long side.
const ACROSS: Array[Vector3] = [Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.RIGHT]
## The pieces the ground runs use (map_cover's three) as indices into COVER, the type run at each
## (the Motorbike, the Buggy, the Truck), the side each run comes from in the piece's frame and the
## shift of the hit point along the face (world x, z) for the west piece.
const GROUND_PIECES: Array[int] = [0, 4, 5]
const GROUND_TYPES: Array[int] = [0, 1, 2]
const GROUND_SIDES: Array[Vector3] = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
const GROUND_SHIFTS: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2(0, 3)]
## The cover layer (project.godot layer 7) and the map layer (layer 1).
const COVER_LAYER: int = 64
const MAP_LAYER: int = 1
## Each Player's gate wall, by path from the Map, and the Gyrocopter's run at it from the open flat.
const GATE_WALLS: Array[String] = ["Base1/Walls/GateWallLeft", "Base2/Walls/GateWallLeft"]
## Metres a Unit's nose runs before it meets a face.
const RUN_UP: float = 15.0
## Ticks per crossing: RUN_UP and the piece at full throttle, the brake past it, then the settle.
const CROSS_TICKS: int = 240
## Metres past the piece's far face, beyond the Gyrocopter's half-length, at which a crossing
## switches from the throttle to the reverse key (the brake), released once it stands.
const BRAKE_AFTER: float = 1.0
## The least number of crossings whose stop is clear of everything the model rises over, so that
## its settle back to the hover is judged.
const SETTLES_JUDGED_MIN: int = 6
## Ticks of full throttle per run into a face (map_cover's 160: the Truck covers RUN_UP in about 2 s).
const STOP_RUN_TICKS: int = 160
## The tick of a run on which the runner presses fire.
const FIRE_TICK: int = 30
## A crossing never drops below this share of the Gyrocopter's top speed while it is over a piece.
const SPEED_SHARE: float = 0.99
## A model's lowest point may sit this far under the rise clearance over a piece, metres.
const CLEARANCE_SLACK: float = 0.01
## Ticks the Gyrocopter stands over the container before it fires: its model has risen by then.
const RISE_WAIT_TICKS: int = 60
## Metres between the Motorbike's nose and the container's face when it fires at the Gyrocopter.
const FIRE_RANGE: float = 10.0

var _q: Quick
var _first_contact: Array[int] = [-1, -1]
var _bottoms: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
var _boxes: Array[Array] = [[], []]
var _settles_judged: int = 0
## The height of the Gyrocopter's model's lowest point over its Unit's origin at its hover, measured
## on the open salt flat in cover_data: what a settle returns to.
var _hover: float = INF
var _runs: int = 0
var _shots_from: int = 0


## Runs the five checks, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_q = Quick.new(harness)
	_q.kit.on_tick = _on_tick
	await _q.harness.confirm_choices()
	await _q.kit.advance(Kit.START_TICKS)
	await _check_data()
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for index: int in COVER.size():
		notes.append(await _cross(index, problems))
	_q.kit.need(problems, _settles_judged >= SETTLES_JUDGED_MIN, "only %d stops were clear enough to judge the settle" % _settles_judged)
	notes.append("settles judged at %d stops" % _settles_judged)
	_q.kit.verdict("gyro_crosses", problems, " | ".join(notes))
	await _ground_runs()
	await _gate_runs()
	await _fire_over_cover()
	_q.close()
	_q.harness.finish("runs=%d shots=%d %s" % [_runs, _q.units.shots.size(), _q.engine_counts()])


## The check kit's hook after every tick: the Map's log, the Shots' first places, each Player's
## first wall contact and its model's lowest point and box.
func _on_tick() -> void:
	_q.map.log_tick()
	_q.units.note_tick()
	for lane: int in Kit.PLAYERS:
		var unit: Unit = _q.map.units[lane]
		if _first_contact[lane] < 0 and _q.map.wall_contact(unit):
			_first_contact[lane] = _q.map.places[lane].size() - 1
		_bottoms[lane].append(Quick.model_bottom(unit))
		_boxes[lane].append(_model_footprint(unit))


## Empties the logs before a run.
func _clear() -> void:
	_q.map.clear_log()
	_first_contact = [-1, -1]
	_bottoms = [PackedFloat64Array(), PackedFloat64Array()]
	_boxes = [[], []]
	_shots_from = _q.units.shots.size()


## The path of a piece of COVER for a Player: the west one, or its east twin.
func _path(index: int, lane: int) -> String:
	return COVER[index] if lane == 0 else COVER[index].replace("West", "East")


## The cover_data CHECK; it spawns a Gyrocopter to read its model. A coroutine.
func _check_data() -> void:
	var problems: PackedStringArray = []
	var bodies: int = 0
	for body: Node in (_q.map.find("Cover") as Node).find_children("*", "CollisionObject3D", true, false):
		bodies += 1
		_q.kit.need(problems, (body as CollisionObject3D).collision_layer == COVER_LAYER and (body as CollisionObject3D).collision_mask == 0,
			"%s is on layer %d, mask %d" % [body.name, (body as CollisionObject3D).collision_layer, (body as CollisionObject3D).collision_mask])
	_q.kit.need(problems, bodies == 12, "the cover holds %d bodies, not 12" % bodies)
	var masks: PackedStringArray = []
	for stats: UnitStats in _q.controller.unit_types():
		var takes: bool = (stats.collision_mask & COVER_LAYER) != 0
		_q.kit.need(problems, takes != stats.can_fly and (stats.collision_mask & MAP_LAYER) != 0, "%s's mask %d" % [stats.type_id, stats.collision_mask])
		masks.append("%s %d" % [stats.type_id, stats.collision_mask])
	var shot_mask: int = _q.controller.rules.shot_collision_mask
	_q.kit.need(problems, (shot_mask & COVER_LAYER) != 0, "the Shot mask %d leaves out the cover layer" % shot_mask)
	var walls: int = 0
	for base: String in ["Base1/Walls", "Base2/Walls"]:
		for body: Node in (_q.map.find(base) as Node).find_children("*", "CollisionObject3D", true, false):
			walls += 1
			_q.kit.need(problems, (body as CollisionObject3D).collision_layer == MAP_LAYER, "%s/%s is on layer %d" % [base, body.name, (body as CollisionObject3D).collision_layer])
	await _q.put(Harness.PLAYER_1, _q.units.stats(Quick.GYROCOPTER), Quick.LANE_SPOT, Vector3.RIGHT)
	await _q.kit.advance(RISE_WAIT_TICKS)
	var model: KitUnitModel = _q.units.units[0].get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as KitUnitModel
	_hover = Quick.model_bottom(_q.units.units[0]) - _q.units.units[0].global_position.y
	var rises: bool = model != null and model.rise_over_cliffs and model.rise_body_mask == COVER_LAYER
	_q.kit.need(problems, rises, "the Gyrocopter's model does not rise over the cover layer")
	_q.kit.verdict("cover_data", problems, "%d cover bodies on layer %d | masks %s | shot mask %d | %d Base wall bodies on layer %d | Gyrocopter model rise_body_mask=%d, hover %.3f m over the floor" % [
		bodies, COVER_LAYER, ", ".join(masks), shot_mask, walls, MAP_LAYER, model.rise_body_mask if model != null else -1, _hover])


## One crossing of a piece and its twin by both Players' Gyrocopters at once; the note.
func _cross(index: int, problems: PackedStringArray) -> String:
	var gyro: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	var axes: Array[Vector2] = []
	for lane: int in Kit.PLAYERS:
		var piece: Node3D = _q.map.find(_path(index, lane)) as Node3D
		var across: Vector3 = piece.global_transform.basis * ACROSS[index]
		var axis: Vector2 = Vector2(across.x, across.z).normalized()
		axes.append(axis)
		var start: Vector2 = _q.face_point(_path(index, lane), -axis) - axis * (gyro.collision_size.z / 2.0 + RUN_UP)
		spots.append(Vector3(start.x, 0.0, start.y))
		facings.append(Vector3(axis.x, 0.0, axis.y))
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], spots, facings, true)
	_clear()
	var brakes: Array[float] = []
	for lane: int in Kit.PLAYERS:
		var centre: Vector2 = Quick.ground(_q.map.find(_path(index, lane)) as Node3D)
		brakes.append(_q.face_point(_path(index, lane), axes[lane]).distance_to(centre) + gyro.collision_size.z / 2.0 + BRAKE_AFTER)
	var throttles: Array[int] = [1, 1]
	for _tick: int in CROSS_TICKS:
		for lane: int in Kit.PLAYERS:
			var unit: Unit = _q.map.units[lane]
			var centre: Vector2 = Quick.ground(_q.map.find(_path(index, lane)) as Node3D)
			if throttles[lane] == 1 and (Quick.ground(unit) - centre).dot(axes[lane]) > brakes[lane]:
				throttles[lane] = -1
			elif throttles[lane] == -1 and unit.current_speed <= 0.0:
				throttles[lane] = 0
			_q.harness.drive(lane, throttles[lane], 0)
		await _q.kit.tick()
	_q.harness.release_all()
	_runs += 2
	var notes: PackedStringArray = []
	for lane: int in Kit.PLAYERS:
		notes.append(_judge_cross(_path(index, lane), axes[lane], lane, gyro, problems))
	return " ; ".join(notes)


## Judges one Gyrocopter's crossing from the logs (the class doc's gyro_crosses), prints its SPLIT
## line and returns the note.
func _judge_cross(path: String, axis: Vector2, lane: int, gyro: UnitStats, problems: PackedStringArray) -> String:
	var piece: Node3D = _q.map.find(path) as Node3D
	var mesh: MeshInstance3D = piece.get_node(Quick.MESH_NAME) as MeshInstance3D
	var footprint: PackedVector2Array = _footprint(mesh, mesh.get_aabb())
	var top: float = (mesh.global_transform * mesh.get_aabb()).end.y
	var centre: Vector2 = Quick.ground(piece)
	var reach: float = _q.face_point(path, axis).distance_to(centre) + gyro.collision_size.z / 2.0
	var slowest: float = INF
	var clearance: float = INF
	var over_ticks: int = 0
	for index: int in _q.map.places[lane].size():
		var at: Vector3 = _q.map.places[lane][index]
		if absf((Vector2(at.x, at.z) - centre).dot(axis)) <= reach and index > 0:
			slowest = minf(slowest, _q.map.real_speed(lane, index))
		var model: PackedVector2Array = _boxes[lane][index]
		if not model.is_empty() and not Geometry2D.intersect_polygons(model, footprint).is_empty():
			over_ticks += 1
			clearance = minf(clearance, _bottoms[lane][index] - top)
	var unit: Unit = _q.map.units[lane]
	var last: Vector3 = _q.map.places[lane][-1]
	var past: float = (Vector2(last.x, last.z) - centre).dot(axis) - reach
	var settled: float = _bottoms[lane][-1] - (last.y + _hover)
	var judged: bool = _stop_is_clear(unit)
	var label: String = "p%d gyrocopter over %s" % [lane + 1, piece.name]
	var rise_clearance: float = (unit.get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as KitUnitModel).rise_clearance
	_q.kit.need(problems, _q.map.contacts[lane] == 0, "%s touched a wall %d times" % [label, _q.map.contacts[lane]])
	_q.kit.need(problems, slowest >= SPEED_SHARE * gyro.max_speed, "%s slowed to %.2f m/s over it" % [label, slowest])
	_q.kit.need(problems, past > 0.0, "%s ended %.2f m short of clearing it" % [label, -past])
	_q.kit.need(problems, over_ticks > 0 and clearance >= rise_clearance - CLEARANCE_SLACK, "%s: its model came to %.3f m over the top in %d ticks over it" % [label, clearance, over_ticks])
	_q.kit.need(problems, not judged or absf(settled) <= CLEARANCE_SLACK, "%s: its model ended %.3f m off its hover at a clear stop" % [label, settled])
	_settles_judged += 1 if judged else 0
	var settle: String = ("back to hover (%.3f)" % settled) if judged else "stop under a riser, settle not judged"
	print("SPLIT %s t=%.3f cross=%s lane=%d slowest=%.2f model_over_top_min=%.3f over_ticks=%d past=%.2f settled=%.3f judged=%s contacts=%d" % [
		_q.harness.scenario, _q.harness.time(), piece.name, lane + 1, slowest, clearance, over_ticks, past, settled, judged, _q.map.contacts[lane]])
	return "%s at %.2f m/s or more, model >= %.3f m over the %.2f m top for %d ticks, %s" % [label, slowest, clearance, top, over_ticks, settle]


## A box's footprint on the ground (world x, z), its four corners turned and placed by the node's
## transform, in order round the box.
static func _footprint(node: Node3D, box: AABB) -> PackedVector2Array:
	var corners: PackedVector2Array = []
	for corner: Vector2 in [Vector2(box.position.x, box.position.z), Vector2(box.end.x, box.position.z),
			Vector2(box.end.x, box.end.z), Vector2(box.position.x, box.end.z)]:
		var world: Vector3 = node.global_transform * Vector3(corner.x, box.position.y, corner.y)
		corners.append(Vector2(world.x, world.z))
	return corners


## The footprint of a Unit's model: the box of its meshes in the model's own frame, turned and placed
## with the model (empty without a model).
static func _model_footprint(unit: Unit) -> PackedVector2Array:
	var model: Node3D = unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as Node3D
	if model == null:
		return PackedVector2Array()
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", false, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var part: AABB = mesh.transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return _footprint(model, box)


## True when nothing the Unit's model rises over (its rise_mask and rise_body_mask) lies under the
## model's footprint widened by its rise_margin on every side, from the floor to high above: the
## model's own query, with no lead (the Unit stands), so its target there is its hover.
func _stop_is_clear(unit: Unit) -> bool:
	var model: KitUnitModel = unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME))) as KitUnitModel
	if model == null:
		return false
	var shape: BoxShape3D = BoxShape3D.new()
	var reach: float = 0.0
	for point: Vector2 in _model_footprint(unit):
		reach = maxf(reach, point.distance_to(Quick.ground(unit)))
	shape.size = Vector3(2.0 * (reach + model.rise_margin), KitUnitModel.RISE_BOX_HEIGHT, 2.0 * (reach + model.rise_margin))
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = model.rise_mask | model.rise_body_mask
	query.transform = Transform3D(Basis.IDENTITY, unit.global_position + Vector3.UP * KitUnitModel.RISE_BOX_HEIGHT / 2.0)
	return unit.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## The ground_stopped CHECK: map_cover's three ground runs on the shipped Map. A coroutine.
func _ground_runs() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for run_index: int in GROUND_PIECES.size():
		var index: int = GROUND_PIECES[run_index]
		var stats: UnitStats = _q.units.stats(GROUND_TYPES[run_index])
		var normals: Array[Vector2] = []
		var faces: Array[Vector2] = []
		for lane: int in Kit.PLAYERS:
			var side: Vector3 = (_q.map.find(_path(index, lane)) as Node3D).global_transform.basis * GROUND_SIDES[run_index]
			var normal: Vector2 = Vector2(side.x, side.z).normalized()
			if lane == 1 and normal.dot(Vector2(-normals[0].x, normals[0].y)) < 0.0:
				normal = -normal
			normals.append(normal)
			faces.append(_q.face_point(_path(index, lane), normal, GROUND_SHIFTS[run_index] * Vector2(-1.0 if lane == 1 else 1.0, 1.0)))
		notes.append(await _stop_runs([GROUND_TYPES[run_index], GROUND_TYPES[run_index]], faces, normals, stats, problems))
	_q.kit.verdict("ground_stopped", problems, " | ".join(notes))


## The walls_stop_gyro CHECK: each Player's Gyrocopter at its own Base's gate wall. A coroutine.
func _gate_runs() -> void:
	var problems: PackedStringArray = []
	var faces: Array[Vector2] = []
	var normals: Array[Vector2] = []
	for lane: int in Kit.PLAYERS:
		var wall: Node3D = _q.map.find(GATE_WALLS[lane]) as Node3D
		var normal: Vector2 = Vector2(-signf(wall.global_position.x), 0.0)
		normals.append(normal)
		faces.append(_q.face_point(GATE_WALLS[lane], normal))
	var note: String = await _stop_runs([Quick.GYROCOPTER, Quick.GYROCOPTER], faces, normals, _q.units.stats(Quick.GYROCOPTER), problems)
	_q.kit.verdict("walls_stop_gyro", problems, note)


## Both Players run at a face each (its point and the normal it looks along) as a type, full
## throttle from RUN_UP, firing once on FIRE_TICK; each run judged as a stop flush at the face
## (quick_fix_kit.gd judge_stop()) and its Shot as ending on it. The note. A coroutine.
func _stop_runs(types: Array[int], faces: Array[Vector2], normals: Array[Vector2], stats: UnitStats, problems: PackedStringArray) -> String:
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for lane: int in Kit.PLAYERS:
		var start: Vector2 = faces[lane] + normals[lane] * (stats.collision_size.z / 2.0 + RUN_UP)
		spots.append(Vector3(start.x, 0.0, start.y))
		facings.append(Vector3(-normals[lane].x, 0.0, -normals[lane].y))
	await _q.map.stage(types, spots, facings, true)
	_clear()
	for lane: int in Kit.PLAYERS:
		_q.harness.drive(lane, 1, 0)
	for tick: int in STOP_RUN_TICKS:
		for lane: int in Kit.PLAYERS:
			_q.harness.set_key(_q.harness.fire_key(lane), tick == FIRE_TICK)
		await _q.kit.tick()
	_q.harness.release_all()
	_runs += 2
	var notes: PackedStringArray = []
	for lane: int in Kit.PLAYERS:
		var face: Vector2 = faces[lane]
		var normal: Vector2 = normals[lane]
		var off_face: Callable = func(place: Vector3) -> float: return (Vector2(place.x, place.z) - face).dot(normal)
		var label: String = "p%d %s at (%.1f, %.1f)" % [lane + 1, stats.type_id, face.x, face.y]
		var numbers: Array[float] = _q.judge_stop(lane, _first_contact[lane], off_face, stats.collision_size.z / 2.0, label, problems)
		var shot: float = _shot_off(lane, face, normal)
		_q.kit.need(problems, absf(shot) <= Quick.SHOT_TOLERANCE, "%s: its Shot ended %.3f m off the face" % [label, shot])
		print("SPLIT %s t=%.3f stop=%s hit=%.2f stop_ticks=%d gap=%.3f end=%.2f shot_off=%.4f" % [
			_q.harness.scenario, _q.harness.time(), label.replace(" ", "_"), numbers[0], int(numbers[1]), numbers[2], numbers[3], shot])
		notes.append("%s hit %.2f m/s, stopped in %d, %.3f m off the face, Shot %.4f off it" % [label, numbers[0], int(numbers[1]), numbers[2], shot])
	return " ; ".join(notes)


## How far off a face (along its normal) the Shot first seen on a Player's side of X = 0 ended.
func _shot_off(lane: int, face: Vector2, normal: Vector2) -> float:
	var offset: float = INF
	for index: int in range(_shots_from, _q.units.shots.size()):
		var seen: Vector3 = _q.units.shot_firsts[index]
		var end: Vector3 = _q.units.shot_ends[index]
		if seen != Vector3.INF and end != Vector3.INF and (seen.x < 0.0) == (lane == 0):
			offset = (Vector2(end.x, end.z) - face).dot(normal)
	return offset


## The fire_over_cover CHECK (class doc). A coroutine.
func _fire_over_cover() -> void:
	var problems: PackedStringArray = []
	var container: Node3D = _q.map.find(COVER[4]) as Node3D
	var gyro_at: Vector3 = Vector3(container.global_position.x, 0.0, container.global_position.z)
	var normal: Vector2 = Vector2(0.0, 1.0)
	var face: Vector2 = _q.face_point(COVER[4], normal)
	var motorbike: UnitStats = _q.units.stats(Quick.MOTORBIKE)
	var bike_at: Vector2 = face + normal * (motorbike.collision_size.z / 2.0 + FIRE_RANGE)
	await _q.map.stage([Quick.GYROCOPTER, Quick.MOTORBIKE], [gyro_at, Vector3(bike_at.x, 0.0, bike_at.y)], [Vector3.RIGHT, Vector3.FORWARD], true)
	await _q.kit.advance(RISE_WAIT_TICKS)
	_clear()
	var hit_points: float = _q.units.units[0].hit_points
	await _q.units.hold_fire(Harness.PLAYER_1, 1)
	await _q.kit.advance(30)
	await _q.units.hold_fire(Harness.PLAYER_2, 1)
	await _q.kit.advance(30)
	var gyro_stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var unit: Unit = _q.units.units[0]
	var muzzle: Vector3 = unit.global_position + (-unit.global_transform.basis.z) * gyro_stats.muzzle_forward
	var ends: Array[Vector3] = [_q.units.shot_ends[_shots_from] if _q.units.shots.size() > _shots_from else Vector3.INF,
		_q.units.shot_ends[_shots_from + 1] if _q.units.shots.size() > _shots_from + 1 else Vector3.INF]
	var own: float = Vector2(ends[0].x, ends[0].z).distance_to(Vector2(muzzle.x, muzzle.z))
	var at_it: float = (Vector2(ends[1].x, ends[1].z) - face).dot(normal)
	var bottom: float = Quick.model_bottom(unit) - _q.top_of(COVER[4])
	_q.kit.need(problems, own <= Quick.SHOT_TOLERANCE, "the Gyrocopter's own Shot ended %.3f m from its muzzle" % own)
	_q.kit.need(problems, absf(at_it) <= Quick.SHOT_TOLERANCE, "the Motorbike's Shot ended %.3f m off the container's face" % at_it)
	_q.kit.need(problems, is_equal_approx(unit.hit_points, hit_points), "the Gyrocopter lost %.1f hit points" % (hit_points - unit.hit_points))
	_q.kit.verdict("fire_over_cover", problems, "Gyrocopter over %s (model %.3f m over its top): its Shot ended %.4f m from its muzzle; the Motorbike's Shot at it ended %.4f m off the face; hit points %.0f -> %.0f" % [
		container.name, bottom, own, at_it, hit_points, unit.hit_points])
