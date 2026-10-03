extends RefCounted
## What the Story 007 scenarios (map_layout, map_edges, map_ford, map_bases, map_cover) share on
## Map 01: its nodes by path and group; the world points of a node's collision (a CSG's baked faces
## too) and AC-2's mirror test over them; the island's outline and a signed distance to a polygon;
## a ray and a wall contact; both Units staged as types at rest; a pursuit controller (pure pursuit
## 6 m ahead, the throttle held, steer keys from a sigma-delta quantiser); a log of both Units
## per tick; both Units onto the other's Flag. Story 007's helper (TD-006) on check_kit.gd; tooling.
## A point in a Base's frame is base.to_local(point), where local -Z leads out of its gate.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## Ticks stage() waits after a teleport and after a typed spawn (a collider swapped on the tick
## after a teleport is thrown: Story 005).
const SETTLE_TICKS: int = 3
## How far along its path the pursuit aims, metres: at 10 m the Truck cuts corners (the Story 007
## evidence doc keeps the run).
const LOOK_AHEAD: float = 6.0
## Segments past the current one the pursuit searches when it projects a Unit on its path.
const SEARCH_SEGMENTS: int = 2
## A slide collision with |normal.y| below this is a wall contact (the floor's has y 1, every tick).
const WALL_NORMAL_Y: float = 0.7
## Points closer than this count once (a CSG's faces repeat each vertex), metres; the pursuit's
## least divisor too.
const POINT_SNAP: float = 0.001
## The island's sand surface, whose polygon is the island's outline.
const ISLAND_PATH: String = "Terrain/Island"

## The runner.
var harness: Harness
## The shared check helpers.
var kit: Kit
## The Map of the launch scene: Map 01 on the main composition.
var map: MapField
## The Units of the launch scene, by Player.
var units: Array[Unit] = []
## Where each Player's Unit stood after every logged tick (log_tick()), by Player.
var places: Array[PackedVector3Array] = [PackedVector3Array(), PackedVector3Array()]
## Each Player's drive speed (Unit.current_speed) after every logged tick, by Player.
var speeds: Array[PackedFloat64Array] = [PackedFloat64Array(), PackedFloat64Array()]
## How many logged ticks each Player's Unit touched a wall on (wall_contact()), by Player.
var contacts: Array[int] = [0, 0]
var _paths: Array[PackedVector2Array] = [PackedVector2Array(), PackedVector2Array()]
var _arcs: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
var _segments: Array[int] = [0, 0]
var _sums: Array[float] = [0.0, 0.0]


func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	map = harness.split.field
	units.assign([harness.split.player_1_unit, harness.split.player_2_unit])


## The Map's node at a path from the Map (for example "Base1/SpawnPoint"), or null.
func find(path: String) -> Node:
	return map.get_node_or_null(NodePath(path))


## The Map's nodes in a node group (for example fuel_cans), in tree order.
func members(group_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in map.get_tree().get_nodes_in_group(group_name):
		if map.is_ancestor_of(node):
			found.append(node)
	return found


## A flat CSG polygon's outline in world (x, z) metres: the island's by default.
func outline(path: String = ISLAND_PATH) -> PackedVector2Array:
	var csg: CSGPolygon3D = find(path) as CSGPolygon3D
	var points: PackedVector2Array = []
	for point: Vector2 in (csg.polygon if csg != null else PackedVector2Array()):
		var world: Vector3 = csg.global_transform * Vector3(point.x, point.y, 0.0)
		points.append(Vector2(world.x, world.z))
	return points


## Metres a point lies inside a polygon of world (x, z) points: to its nearest edge, negative
## outside (two points are a segment: always outside).
func inside_by(point: Vector3, polygon: PackedVector2Array) -> float:
	var at: Vector2 = Vector2(point.x, point.z)
	var nearest: float = INF
	for index: int in polygon.size():
		var next: Vector2 = polygon[(index + 1) % polygon.size()]
		nearest = minf(nearest, at.distance_to(Geometry2D.get_closest_point_to_segment(at, polygon[index], next)))
	return nearest if polygon.size() > 2 and Geometry2D.is_point_in_polygon(at, polygon) else -nearest


## The world points of a node's collision: a collision CSG's baked face vertices and the corners
## of each CollisionShape3D's box (another shape's bounds) of the node and its children, else its
## mesh's box corners; points within POINT_SNAP count once.
func footprint(node: Node) -> PackedVector3Array:
	var points: Dictionary[Vector3, bool] = {}
	var csg: CSGShape3D = node as CSGShape3D
	if csg != null and csg.use_collision:
		for vertex: Vector3 in csg.bake_collision_shape().get_faces():
			points[(csg.global_transform * vertex).snappedf(POINT_SNAP)] = true
	for child: Node in [node] + node.get_children():
		_add_shape(points, child as CollisionShape3D)
	var mesh: MeshInstance3D = node as MeshInstance3D
	if points.is_empty() and mesh != null:
		_add_box(points, mesh.global_transform, mesh.get_aabb())
	return PackedVector3Array(points.keys())


## AC-2's mirror test: each collider (grouped by class, layer and mask), each Base's SpawnPoint
## markers and Flag seat (its point and the point 1 m ahead, for the heading) and each Fuel Can spot
## pairs with the item of its group nearest its own points with x negated (itself across X = 0),
## within tolerance metres (Hausdorff). A problem per item with no mirror; returns the numbers.
func mirror(problems: PackedStringArray, tolerance: float) -> String:
	var items: Dictionary[String, PackedVector3Array] = _mirror_items()
	var partner: Dictionary[String, String] = {}
	var worst: float = 0.0
	for label: String in items:
		var flipped: PackedVector3Array = _flip(items[label])
		var best: String = ""
		var best_distance: float = INF
		for other: String in items:
			var same_group: bool = other.get_slice("|", 0) == label.get_slice("|", 0)
			var distance: float = _hausdorff(flipped, items[other], tolerance) if same_group and not partner.has(other) else INF
			if not partner.has(label) and distance < best_distance:
				best = other
				best_distance = distance
		if not best.is_empty():
			partner[label] = best
			partner[best] = label
			worst = maxf(worst, best_distance)
		elif not partner.has(label):
			problems.append("no mirror within %.2f m for %s" % [tolerance, label])
	var selves: int = partner.keys().filter(func(label: String) -> bool: return partner[label] == label).size()
	return "mirror items=%d self=%d worst=%.4f m" % [items.size(), selves, worst]


## The first hit of a ray between two world points on mask's layers, or Vector3.INF (call it from a
## scenario's tick).
func ray(from: Vector3, to: Vector3, mask: int) -> Vector3:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, mask)
	return map.get_world_3d().direct_space_state.intersect_ray(query).get("position", Vector3.INF)


## True when the Unit's last move touched a wall (a slide collision below WALL_NORMAL_Y).
func wall_contact(unit: Unit) -> bool:
	for index: int in unit.get_slide_collision_count():
		if absf(unit.get_slide_collision(index).get_normal().y) < WALL_NORMAL_Y:
			return true
	return false


## Each Player's Unit at rest as a type (an index of unit_types; -1 leaves it alone) at a spot
## facing a way, keys up: place(), SETTLE_TICKS, Unit.spawn(at, stats), SETTLE_TICKS. The Units are
## in play already (the choice keys); full_tank refuel()s them. A coroutine: await it.
func stage(types: Array[int], spots: Array[Vector3], facings: Array[Vector3], full_tank: bool) -> void:
	harness.release_all()
	var cameras: Array[ChaseCamera] = [harness.split.player_1_camera, harness.split.player_2_camera]
	var poses: Array[Transform3D] = []
	for player: int in Kit.PLAYERS:
		var yaw: float = atan2(-facings[player].x, -facings[player].z)
		poses.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(spots[player].x, 0.0, spots[player].z)))
		if types[player] >= 0:
			harness.place(units[player], poses[player], cameras[player])
	await kit.advance(SETTLE_TICKS)
	for player: int in Kit.PLAYERS:
		if types[player] >= 0:
			units[player].spawn(poses[player], harness.split.match_controller.unit_types()[types[player]])
			cameras[player].snap_to_target()
			if full_tank:
				units[player].refuel(units[player].fuel_capacity)
	await kit.advance(SETTLE_TICKS)


## Gives a Player's Unit a path of world (x, z) points in driving order for steer().
func set_path(player: int, path: PackedVector2Array) -> void:
	var arcs: PackedFloat32Array = [0.0]
	for index: int in range(1, path.size()):
		arcs.append(arcs[index - 1] + path[index - 1].distance_to(path[index]))
	_paths[player] = path
	_arcs[player] = arcs
	_segments[player] = 0
	_sums[player] = 0.0


## One pursuit tick, after a tick for the next: aims LOOK_AHEAD past the Unit's projection on
## its path, turns that curvature into a share of full lock (radius max_speed / turn_rate), feeds a
## sigma-delta sum to the steer keys and holds the throttle key. Returns the metres along the path.
func steer(player: int, throttle: int) -> float:
	var unit: Unit = units[player]
	var at: Vector2 = Vector2(unit.global_position.x, unit.global_position.z)
	var arc: float = _project(player, at)
	var facing: Vector3 = -unit.global_transform.basis.z
	var ahead: Vector2 = Vector2(facing.x, facing.z).normalized()
	var to_target: Vector2 = _point_at(player, arc + LOOK_AHEAD) - at
	var angle: float = atan2(to_target.x * ahead.y - to_target.y * ahead.x, to_target.dot(ahead))
	var curvature: float = 2.0 * sin(angle) / maxf(to_target.length(), POINT_SNAP)
	_sums[player] += clampf(curvature * unit.stats.max_speed / unit.stats.turn_rate, -1.0, 1.0)
	var key: float = clampf(roundf(_sums[player]), -1.0, 1.0)
	_sums[player] -= key
	harness.drive(player, throttle, int(key))
	return arc


## Logs both Units' place, drive speed and wall contact after a tick: a check kit's on_tick.
func log_tick() -> void:
	for player: int in Kit.PLAYERS:
		var trail: PackedVector3Array = places[player]
		var drive: PackedFloat64Array = speeds[player]
		trail.append(units[player].global_position)
		drive.append(units[player].current_speed)
		places[player] = trail
		speeds[player] = drive
		contacts[player] += 1 if wall_contact(units[player]) else 0


## Empties the log and the contact counts.
func clear_log() -> void:
	for player: int in Kit.PLAYERS:
		places[player] = PackedVector3Array()
		speeds[player] = PackedFloat64Array()
		contacts[player] = 0


## A Player's measured speed over logged tick index (from the end when negative), m/s.
func real_speed(player: int, index: int) -> float:
	var trail: PackedVector3Array = places[player]
	var at: int = index if index >= 0 else trail.size() + index
	if at < 1 or at >= trail.size():
		return 0.0
	var move: Vector3 = trail[at] - trail[at - 1]
	return Vector2(move.x, move.z).length() * harness.ticks_in(1.0)


## Drives both Players' Units at once onto the other Player's Flag: each one's throttle key
## feathered under cruise m/s until it carries that Flag, then its reverse key until it rolls no
## faster than stop m/s. The ticks until both carry and stand, or -1 past limit. A coroutine.
func drive_to_flags(cruise: float, stop: float, limit: int) -> int:
	var controller: MatchController = harness.split.match_controller
	for count: int in range(1, limit + 1):
		var done: bool = true
		for player: int in Kit.PLAYERS:
			var carrying: bool = controller.canister_status(player) == MatchController.CanisterStatus.CARRYING_ENEMY
			var speed: float = units[player].current_speed
			harness.drive(player, (-1 if speed > stop else 0) if carrying else (1 if speed < cruise else 0), 0)
			done = done and carrying and speed <= stop
		await kit.tick()
		if done:
			harness.release_all()
			return count
	harness.release_all()
	return -1


func _add_shape(points: Dictionary[Vector3, bool], shape: CollisionShape3D) -> void:
	if shape == null or shape.shape == null or shape.disabled:
		return
	var box: BoxShape3D = shape.shape as BoxShape3D
	_add_box(points, shape.global_transform, AABB(-box.size / 2.0, box.size) if box != null else shape.shape.get_debug_mesh().get_aabb())


func _flip(points: PackedVector3Array) -> PackedVector3Array:
	var flipped: PackedVector3Array = []
	for point: Vector3 in points:
		flipped.append(Vector3(-point.x, point.y, point.z))
	return flipped


func _add_box(points: Dictionary[Vector3, bool], where: Transform3D, box: AABB) -> void:
	for corner: int in 8:
		points[(where * box.get_endpoint(corner)).snappedf(POINT_SNAP)] = true


## AC-2's mirror items by label (group|path from the Map): each collider's world points (grouped
## by class, layer and mask), each Fuel Can's spot, each Base marker's spot and 1 m ahead; metres.
func _mirror_items() -> Dictionary[String, PackedVector3Array]:
	var items: Dictionary[String, PackedVector3Array] = {}
	for node: Node in map.find_children("*", "Node", true, false):
		var body: CollisionObject3D = node as CollisionObject3D
		var csg: CSGShape3D = node as CSGShape3D
		if body != null:
			items["%s %d %d|%s" % [body.get_class(), body.collision_layer, body.collision_mask, map.get_path_to(node)]] = footprint(node)
		elif csg != null and csg.use_collision:
			items["CSG %d %d|%s" % [csg.collision_layer, csg.collision_mask, map.get_path_to(node)]] = footprint(node)
		elif node is FuelCan:
			items["FuelCan|%s" % map.get_path_to(node)] = PackedVector3Array([(node as Node3D).global_position])
	for base: Base in [map.player_1_base, map.player_2_base]:
		var markers: Array[Marker3D] = [base.spawn_point, base.canister_seat]
		markers.append_array(base.spare_spawn_points)
		for marker: Marker3D in markers:
			var ahead: Vector3 = marker.global_position - marker.global_transform.basis.z
			items["Marker|%s" % map.get_path_to(marker)] = PackedVector3Array([marker.global_position, ahead])
	return items


## The Hausdorff distance of two point sets, or INF past the limit (their centres first).
func _hausdorff(first: PackedVector3Array, second: PackedVector3Array, limit: float) -> float:
	if first.is_empty() or second.is_empty():
		return INF
	var centres: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for point: Vector3 in first:
		centres[0] += point / first.size()
	for point: Vector3 in second:
		centres[1] += point / second.size()
	if centres[0].distance_to(centres[1]) > limit:
		return INF
	var distance: float = maxf(_directed(first, second), _directed(second, first))
	return distance if distance <= limit else INF


## The directed Hausdorff distance, metres: the largest distance from a point of from to its
## nearest point of to.
func _directed(from: PackedVector3Array, to: PackedVector3Array) -> float:
	var worst: float = 0.0
	for point: Vector3 in from:
		var nearest: float = INF
		for other: Vector3 in to:
			nearest = minf(nearest, point.distance_squared_to(other))
		worst = maxf(worst, nearest)
	return sqrt(worst)


## The metres along a Player's path (set_path()) of a world (x, z) point's nearest point on it,
## searched from the current segment over SEARCH_SEGMENTS more; that segment becomes the current.
func _project(player: int, at: Vector2) -> float:
	var path: PackedVector2Array = _paths[player]
	var best: float = INF
	var arc: float = 0.0
	for index: int in range(_segments[player], mini(_segments[player] + SEARCH_SEGMENTS + 1, path.size() - 1)):
		var span: Vector2 = path[index + 1] - path[index]
		var along: float = clampf((at - path[index]).dot(span) / span.length_squared(), 0.0, 1.0)
		if at.distance_to(path[index] + span * along) < best:
			best = at.distance_to(path[index] + span * along)
			_segments[player] = index
			arc = _arcs[player][index] + along * span.length()
	return arc


## The world (x, z) point arc metres along a Player's path (clamped to its ends), searched forward
## from the current segment.
func _point_at(player: int, arc: float) -> Vector2:
	var path: PackedVector2Array = _paths[player]
	var arcs: PackedFloat32Array = _arcs[player]
	var clamped: float = clampf(arc, 0.0, arcs[arcs.size() - 1])
	var index: int = _segments[player]
	while index < path.size() - 2 and arcs[index + 1] < clamped:
		index += 1
	return path[index] + (path[index + 1] - path[index]) * ((clamped - arcs[index]) / maxf(arcs[index + 1] - arcs[index], POINT_SNAP))
