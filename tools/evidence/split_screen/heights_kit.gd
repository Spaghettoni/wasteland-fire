extends RefCounted
## What the Story 020 scenarios (heights with its modules, and heights_showcase) share on top of the Story 019 kit
## (garage_scrap_walls_kit.gd: the 88 Wall Panels; under it the Story 018, 014, 012, 011 and 009 kits): the flying height
## the build's data gives, the story's own test inputs (the clearance, the rounding, the two Heights by physics layer),
## the watch node that reads every flying Unit's lowest drawn point after the Units' tick, a Unit's drawn top and the
## lanes a Gyrocopter is flown along. Tooling only: nothing under src/ depends on this file; loaded with a preload
## constant. Implements: production/epics/wasteland-fire/story-020-two-heights.md, Test Evidence.

## The Story 019 kit: k.k is the Story 018 kit, k.k.m the Story 014 kit, k.k.m.w the Story 012 kit.
const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices, a model's lowest point and box.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The shared helpers (check_kit.gd): the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The watch node (heights_watch.gd).
const Watch: GDScript = preload("res://tools/evidence/split_screen/heights_watch.gd")

## The story's test inputs. The clearance the flying height keeps over the tallest low piece or ground Unit body
## (the rise's clearance of Stories 009 to 019), the step the height is rounded up to, the least a drawn height is
## trusted to (1 mm) and the tallest a low piece is (2 m: the Wall Panels).
const CLEARANCE: float = 0.25
const ROUND_STEP: float = 0.05
const TOLERANCE: float = 0.001
## What a height read in floating point may differ from the one it is judged against by, metres (0.01 mm): the Unit's
## body floats up to its safe margin over the floor, 1 mm (CharacterBody3D's default), which the floor-relative
## reading includes and the model-relative one does not.
const FLOAT_SLACK: float = 0.00001
const LOW_TOP_MAX: float = 2.0
## The two Heights by physics layer (project.godot: 1 map, 6 cliffs_water, 7 cover): low is cliffs_water and cover, high
## is the map layer.
const LOW_LAYERS: int = 32 | 64
const HIGH_LAYERS: int = 1
## Metres a Unit's nose runs before it meets what it is driven at, and past the far side where a crossing is over.
const RUN_UP: float = 14.0
const PAST: float = 6.0
## The ticks a drive may take.
const RUN_LIMIT_TICKS: int = 420
## The Gyrocopter's index into the data.
const GYRO: int = Quick.GYROCOPTER

## The solid colliders of Map 01 by family: [kind, path from the Map, the count, the Height their layer puts them in,
## whether they are Tall pieces]. The two Heights are the story's; the paths and counts are the Map's (stories 007 to 019).
const FAMILIES: Array = [
	["Base wall panel", "^Base\\d/Walls/\\w+/Panel\\d+$", 60, "low", false],
	["Garage panel", "^Base\\d/Garage/\\w+/Panel\\d+$", 20, "low", false],
	["field panel", "^FieldWalls/\\w+/Panel\\d+$", 8, "low", false],
	["Flag Wall", "^Base\\d/Defences/FlagWall\\w+$", 8, "low", false],
	["wreck", "^Cover/Wrecks/\\w+$", 8, "low", false],
	["container", "^Cover/Containers/\\w+$", 2, "low", false],
	["cliff", "^Cliffs/\\w+$", 5, "low", false],
	["water channel", "^Water/\\w+$", 2, "low", false],
	["corner tower", "^Base\\d/Walls/Tower\\w+$", 8, "high", true],
	["water tower leg", "^Base\\d/WaterTower/Leg\\w+$", 8, "high", true],
	["depot tank", "^Depot/FuelTanks/\\w+/Collider$", 3, "high", true],
	["Turret", "^Base\\d/Turrets/\\w+$", 4, "high", true],
	["Floor", "^Floor$", 1, "high", false],
	["sea edge", "^Terrain/ShoreEdge/\\w+$", 32, "high", false]]
## The thin parts of the ground Units' mesh files, found by story 015 (boxes in the file's frame, by type): the Buggy's whip and
## pennant, the Truck's whip antenna. A "body top" is the highest vertex outside them.
const THIN: Dictionary = {
	"buggy": [["whip and pennant", AABB(Vector3(0.38, 1.2, 0.95), Vector3(0.08, 0.85, 0.6))]],
	"truck": [["whip antenna", AABB(Vector3(-0.82, 1.5, 0.2), Vector3(0.14, 1.25, 0.25))]]}
## The Story 019 kit.
var k: Kit19
## The watch node under the launch scene.
var watch: Watch
## The compiled path patterns of FAMILIES, made on first use.
var _expressions: Array[RegEx] = []
## The height the build's data gives the lowest drawn point of the Gyrocopter's model, metres.
var height: float = 0.0


## Makes the Story 019 kit, reads the flying height from the data and starts the watch.
func _init(harness_node: Node) -> void:
	k = Kit19.new(harness_node)
	height = data_height()
	watch = Watch.new()
	watch.harness = harness_node
	watch.units = [q().units.units[0], q().units.units[1]]
	watch.expected = height
	harness_node.split.add_child(watch)
	q().controller.unit_spawned.connect(watch.on_spawned)


## Removes the watch and the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	watch.queue_free()
	k.close()


## The Story 009 kit.
func q() -> Quick:
	return k.q()


## The Gyrocopter's drawn band in the world: x its lowest drawn point (the flying height), y the top of its rotor, metres.
func band() -> Vector2:
	var model: MeshUnitModel = q().units.stats(GYRO).model.instantiate() as MeshUnitModel
	var top: float = model.hover_height + model.offset.y + model.model_scale * MeshUnitModel.hull_of(model.mesh_scene, INF).end.y
	model.free()
	return Vector2(height, top)


## The Map 01 root of the launch scene.
func map() -> MapField:
	return q().harness.split.field


## The index into FAMILIES of the family a collider's path (from the Map) belongs to; -1 when it belongs to none, -2 when
## to more than one.
func family_of(path: String) -> int:
	if _expressions.is_empty():
		for family: Array in FAMILIES:
			var expression: RegEx = RegEx.new()
			expression.compile(family[1])
			_expressions.append(expression)
	var found: int = -1
	for index: int in FAMILIES.size():
		if _expressions[index].search(path) != null:
			found = index if found == -1 else -2
	return found


## The flying height the data gives: the Gyrocopter's model scene's hover_height, plus the lowest vertex of its mesh
## file as the scene scales and offsets it. The scene is instanced and freed here, never entered into the tree.
func data_height() -> float:
	var scene: PackedScene = q().units.stats(GYRO).model
	var model: MeshUnitModel = scene.instantiate() as MeshUnitModel
	var low: float = model.hover_height + model.offset.y + model.model_scale * MeshUnitModel.hull_of(model.mesh_scene, INF).position.y
	model.free()
	return low


## The highest vertex of a mesh file outside the type's thin boxes, and the highest of the boxes by name.
static func file_tops(type_id: String, file: PackedScene) -> Dictionary:
	var body: float = -INF
	var thin: Dictionary = {}
	var meshes: Dictionary = MeshFile.meshes_of(file)
	for mesh_name: StringName in meshes:
		var mesh: Mesh = meshes[mesh_name]
		for surface: int in mesh.get_surface_count():
			for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var inside: String = ""
				for box: Array in THIN.get(type_id, []):
					inside = box[0] if (box[1] as AABB).has_point(point) else inside
				if inside.is_empty():
					body = maxf(body, point.y)
				else:
					thin[inside] = maxf(thin.get(inside, -INF), point.y)
	return {"body": body, "thin": thin, "all": MeshUnitModel.hull_of(file, INF).end.y}


## What a ground type's model draws, in metres over the Unit's floor: {body: the highest vertex outside the thin parts, all: the highest
## vertex, thin: the highest vertex of each thin part by name}, from its model scene and mesh file (the placement of the scene included).
func ground_tops(type_index: int) -> Dictionary:
	var stats: UnitStats = q().units.stats(type_index)
	var model: MeshUnitModel = stats.model.instantiate() as MeshUnitModel
	var tops: Dictionary = file_tops(String(stats.type_id), model.mesh_scene)
	var lift: float = model.hover_height + model.offset.y
	var placed: Dictionary = {"body": lift + model.model_scale * tops["body"], "all": lift + model.model_scale * tops["all"], "thin": {}}
	for thin_name: String in tops["thin"]:
		placed["thin"][thin_name] = lift + model.model_scale * tops["thin"][thin_name]
	model.free()
	return placed


## The drawn box of a node in the world: the merge of the boxes of its own geometry and of the visible geometry below it
## (the smoke of a badly damaged Unit left out); null when nothing is drawn.
static func drawn_box(node: Node) -> Variant:
	var box: Variant = null
	var parts: Array[Node] = [node]
	parts.append_array(node.find_children("*", "GeometryInstance3D", true, false))
	for part: Node in parts:
		var drawn: GeometryInstance3D = part as GeometryInstance3D
		if drawn != null and drawn.is_visible_in_tree() and not (part.get_parent() is BadlyDamagedSmoke):
			var world: AABB = drawn.global_transform * drawn.get_aabb()
			box = world if box == null else (box as AABB).merge(world)
	return box


## The highest drawn point of a node, world metres (drawn_box()); -INF when nothing is drawn.
static func drawn_top(node: Node) -> float:
	var box: Variant = drawn_box(node)
	return -INF if box == null else (box as AABB).end.y


## Every solid collider of the Map under `root`: a StaticBody3D (a Structure, a tower, a leg, a tank's collider) or a
## CSG shape with collision (a cliff), never an Area3D (a zone, a ford, a pick-up). One entry each: {node, path from the
## root, layer, top (of its collision shapes), drawn (the drawn box, or the collision box for a CSG shape; null when
## nothing is drawn), drawn_top}.
func solid_rows(root: Node) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	_collect(root, root, found)
	return found


func _collect(node: Node, root: Node, found: Array[Dictionary]) -> void:
	var body: StaticBody3D = node as StaticBody3D
	if body != null:
		var shape_box: Variant = null
		for child: Node in body.get_children():
			var shape_node: CollisionShape3D = child as CollisionShape3D
			if shape_node != null and shape_node.shape != null and not shape_node.disabled:
				var world: AABB = shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb()
				shape_box = world if shape_box == null else (shape_box as AABB).merge(world)
		found.append({"node": body, "path": str(root.get_path_to(body)), "layer": body.collision_layer, "top": -INF if shape_box == null else (shape_box as AABB).end.y, "shape_box": shape_box, "drawn": drawn_box(body), "drawn_top": drawn_top(body)})
	var csg: CSGShape3D = node as CSGShape3D
	if csg != null and csg.use_collision and csg.is_root_shape():
		var box: AABB = csg.global_transform * csg.get_aabb()
		found.append({"node": csg, "path": str(root.get_path_to(csg)), "layer": csg.collision_layer, "top": box.end.y, "shape_box": box, "drawn": box, "drawn_top": box.end.y})
	for child: Node in node.get_children():
		_collect(child, root, found)


## The lowest point of a Gyrocopter's model in the world (Quick.model_bottom()).
static func low_of(unit: Unit) -> float:
	return Quick.model_bottom(unit)


## True when nothing on a mask (the Gyrocopter's own, the map layer, when none is given) lies along a lane from `from` to
## `to` for a body of half_width, checked by three rays at two heights of its collider: the lane a flight needs.
func lane_free(from: Vector3, to: Vector3, half_width: float, mask: int = -1) -> bool:
	if mask < 0:
		mask = q().units.stats(GYRO).collision_mask
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized() * half_width
	var space: PhysicsDirectSpaceState3D = map().get_world_3d().direct_space_state
	for offset: Vector3 in [-side, Vector3.ZERO, side]:
		for up: float in [0.2, 0.8]:
			var lift: Vector3 = Vector3.UP * up + offset
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from + lift, to + lift, mask)).is_empty():
				return false
	return true


## True when the floor lies under a point (a downward ray on the map layer finds a body about the floor's top).
func floor_under(point: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 1.0, point + Vector3.DOWN * 1.0, HIGH_LAYERS)
	return not map().get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## True when two boxes overlap in plan (x and z), whatever their heights.
static func overlap_plan(a: AABB, b: AABB) -> bool:
	return a.position.x < b.end.x and a.end.x > b.position.x and a.position.z < b.end.z and a.end.z > b.position.z


## One drive of Player `player`'s Unit as a type from `start` along `dir` at full throttle, after staging it there (the other
## Player's Unit is parked in its Garage): until `limit` ticks have passed or `stop`, called with the Unit after each tick,
## holds. Returns {boxes: the model's world box after each tick, touches: whether the Unit touched a wall on that tick,
## places and speeds: the map kit's log, contacts: the ticks with a wall contact, ticks}. A coroutine: await it.
func fly(player: int, type_index: int, start: Vector3, dir: Vector3, limit: int, stop: Callable = Callable()) -> Dictionary:
	await k.k.stage(player, type_index, start, dir)
	return await run_staged(player, limit, stop)


## The drive of fly() for a Unit already staged (both Units staged by the map kit, say). `also` is another Player whose throttle is
## held down too, its model's boxes filed as boxes2.
func run_staged(player: int, limit: int, stop: Callable = Callable(), also: int = -1) -> Dictionary:
	var unit: Unit = q().units.units[player]
	var boxes: Array[AABB] = []
	var boxes2: Array[AABB] = []
	var touches: Array[bool] = []
	q().map.clear_log()
	q().kit.on_tick = func() -> void:
		q().map.log_tick()
		boxes.append(Quick.model_box(unit))
		touches.append(q().map.wall_contact(unit))
		if also >= 0:
			boxes2.append(Quick.model_box(q().units.units[also]))
	var ran: int = 0
	for _tick: int in limit:
		q().harness.drive(player, 1, 0)
		if also >= 0:
			q().harness.drive(also, 1, 0)
		await q().kit.tick()
		ran += 1
		if stop.is_valid() and stop.call(unit):
			break
	q().kit.on_tick = Callable()
	q().harness.release_all()
	return {"boxes": boxes, "boxes2": boxes2, "touches": touches, "places": q().map.places[player], "speeds": q().map.speeds[player], "contacts": q().map.contacts[player], "ticks": ran}


## True when the floor lies under the centre of a Unit's footprint at `at` and under its four corners (heading `dir`, a box of
## `size`): a Unit put down with a corner over the sea edge's boxes is pushed out of them and sinks.
func footprint_on_floor(at: Vector3, dir: Vector3, size: Vector3) -> bool:
	var heading: Basis = Basis(Vector3.UP, atan2(-dir.x, -dir.z))
	if not floor_under(at):
		return false
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		if not floor_under(at + heading * (corner * size * 0.5)):
			return false
	return true


## The two Heights a layer puts a body in: "low" (cliffs_water or cover, and not the map layer), "high" (the map layer
## and neither low layer), "" when it is in both or neither.
static func height_of(layer: int) -> String:
	var low: bool = (layer & LOW_LAYERS) != 0
	var high: bool = (layer & HIGH_LAYERS) != 0
	if low and not high:
		return "low"
	if high and not low:
		return "high"
	return ""
