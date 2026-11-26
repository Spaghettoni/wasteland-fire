extends SceneTree
## Places the voxel scenery of the art overhaul (2026-11-26) on one Map and writes it as a scene beside the Map
## (map_0N_scenery.tscn), which the Map instances as its Scenery node. Seeded per Map, so a rerun writes the same scene.
##  - Mesas (assets/art/voxel/mesa_*.res): out of play, on a ring 14 to 80 m beyond the Map's edges (the map_edge bodies),
##    at least 28 m apart; drawn only, no collider.
##  - Cactuses and rocks: on the ground in play (on an Island on a Map that has Island* polygons), at least CLEAR_M from
##    anything that collides or watches (Structures, Bases, zones, Bushes, spawn points), at least SPACING_M from each
##    other, mostly near a shore or an edge; each a StaticBody3D on layer 1 with a small collider no taller than
##    COLLIDER_TOP_M, well under the flying height (Story 015), so a Gyrocopter never touches one; on a Map without
##    Islands, none nearer the edge than EDGE_CLEAR_M.
##  - Maps without a sea get a wide plain sand plane under everything, so the desert runs on to the horizon.
##  - Nothing is put within CLEAR_M of a terrain piece other than an Island (a ridge, a cliff), so a run over or along
##    one meets nothing new.
## Tooling only. Run: godot --headless --path . -s res://tools/art/place_scenery.gd -- <map.tscn> <out.tscn> <seed>

const MESAS: int = 4
const CACTUSES: int = 4
const ROCKS: int = 4
const CLEAR_M: float = 9.0
const SPACING_M: float = 7.0
const COLLIDER_TOP_M: float = 1.2
## On a Map without Islands nothing is put nearer its edge than this, so the runs along and at the edge meet nothing.
const EDGE_CLEAR_M: float = 12.0
const VOXEL: String = "res://assets/art/voxel/"

var rng := RandomNumberGenerator.new()


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	rng.seed = int(args[2])
	var map: Node3D = (load(args[0]) as PackedScene).instantiate()
	get_root().add_child(map)
	for _i: int in 4:
		await physics_frame
	var bounds: Rect2 = _bounds(map)
	var islands: Array[PackedVector2Array] = _islands(map)
	var space: PhysicsDirectSpaceState3D = map.get_world_3d().direct_space_state
	var floor_rid: RID = (map.get_node("Floor") as CollisionObject3D).get_rid() if map.has_node("Floor") else RID()

	var scenery := Node3D.new()
	scenery.name = "Scenery"
	var material: Material = load(VOXEL + "voxel_material.tres")
	if islands.is_empty():
		var sand := MeshInstance3D.new()
		sand.name = "FarSand"
		var plane := PlaneMesh.new()
		plane.size = Vector2(1200, 1200)
		sand.mesh = plane
		# Its own plain material: the ground shader (sand.tres) draws tyre tracks and stays on the play area's ground.
		var far := StandardMaterial3D.new()
		far.albedo_color = Color(0.8, 0.58, 0.37)
		far.roughness = 1.0
		sand.material_override = far
		sand.position = Vector3(bounds.get_center().x, -0.06, bounds.get_center().y)
		sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(scenery, sand)

	# Mesas on a ring beyond the edges.
	var mesas: Array[Vector2] = []
	var tries: int = 0
	while mesas.size() < 26 and tries < 4000:
		tries += 1
		var angle: float = rng.randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var half: Vector2 = bounds.size * 0.5
		# The distance from the middle to the edge along dir, then out beyond it.
		var to_edge: float = minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var p: Vector2 = bounds.get_center() + dir * (to_edge + rng.randf_range(10.0, 55.0))
		if mesas.any(func(q: Vector2) -> bool: return q.distance_to(p) < 28.0):
			continue
		mesas.append(p)
		var mi := MeshInstance3D.new()
		mi.name = "Mesa%d" % mesas.size()
		mi.mesh = load(VOXEL + "mesa_%d.res" % rng.randi_range(0, MESAS - 1))
		mi.material_override = material
		var s: float = rng.randf_range(1.6, 3.0)
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, -0.3, p.y))
		_add(scenery, mi)

	# Cactuses and rocks in play.
	var props: Array[Vector2] = []
	var wanted: int = 34 if not islands.is_empty() else 40
	tries = 0
	while props.size() < wanted and tries < 20000:
		tries += 1
		var p := Vector2(rng.randf_range(bounds.position.x + 4.0, bounds.end.x - 4.0), rng.randf_range(bounds.position.y + 4.0, bounds.end.y - 4.0))
		var shore: float = _to_shore(p, islands, bounds)
		if shore < (1.5 if not islands.is_empty() else EDGE_CLEAR_M):
			continue
		# Mostly near a shore or an edge: the farther in, the rarer.
		var inward: float = shore if not islands.is_empty() else shore - EDGE_CLEAR_M
		if rng.randf() > clampf(1.4 - inward / 12.0, 0.08, 1.0):
			continue
		if props.any(func(q: Vector2) -> bool: return q.distance_to(p) < SPACING_M):
			continue
		if _crowded(space, Vector3(p.x, 1.0, p.y), floor_rid):
			continue
		props.append(p)
		var cactus: bool = rng.randf() < 0.6
		var body := StaticBody3D.new()
		body.name = ("Cactus%d" if cactus else "Rock%d") % props.size()
		body.collision_layer = 1
		body.collision_mask = 0
		var grow: float = rng.randf_range(1.2, 1.5) if cactus else rng.randf_range(1.0, 1.6)
		body.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, 0.0, p.y))
		_add(scenery, body)
		var mi := MeshInstance3D.new()
		mi.name = "Look"
		mi.mesh = load(VOXEL + ("cactus_%d.res" % rng.randi_range(0, CACTUSES - 1) if cactus else "rock_%d.res" % rng.randi_range(0, ROCKS - 1)))
		mi.material_override = material
		mi.scale = Vector3.ONE * grow
		_add(body, mi, scenery)
		var shape := CollisionShape3D.new()
		shape.name = "Collider"
		var aabb: AABB = mi.mesh.get_aabb()
		aabb = AABB(aabb.position * grow, aabb.size * grow)
		if cactus:
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.35 * grow
			cyl.height = minf(aabb.size.y, COLLIDER_TOP_M)
			shape.shape = cyl
			shape.position = Vector3(0.0, cyl.height * 0.5, 0.0)
		else:
			var box := BoxShape3D.new()
			box.size = Vector3(aabb.size.x * 0.8, minf(aabb.size.y, COLLIDER_TOP_M), aabb.size.z * 0.8)
			shape.shape = box
			shape.position = Vector3(aabb.get_center().x, box.size.y * 0.5, aabb.get_center().z)
		_add(body, shape, scenery)

	var packed := PackedScene.new()
	packed.pack(scenery)
	var err: int = ResourceSaver.save(packed, args[1])
	print("SCENERY %s bounds=%s islands=%d mesas=%d props=%d err=%d" % [args[0], bounds, islands.size(), mesas.size(), props.size(), err])
	quit()


func _add(parent: Node, child: Node, owner_node: Node = null) -> void:
	parent.add_child(child)
	child.owner = owner_node if owner_node != null else parent


## The play area on the ground (x, z), inside the map_edge bodies.
func _bounds(map: Node) -> Rect2:
	var box := AABB()
	var first: bool = true
	for body: Node in map.get_tree().get_nodes_in_group(&"map_edge"):
		for shape: Node in body.get_children():
			var cs := shape as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var b: AABB = cs.global_transform * (cs.shape.get_debug_mesh().get_aabb())
			box = b if first else box.merge(b)
			first = false
	return Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(-2.0)


## The Islands' outlines on the ground (x, z), from the Map's Island* CSG polygons.
func _islands(map: Node) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for node: Node in map.find_children("Island*", "CSGPolygon3D", true, false):
		var csg := node as CSGPolygon3D
		var poly := PackedVector2Array()
		for q: Vector2 in csg.polygon:
			var w: Vector3 = csg.global_transform * Vector3(q.x, q.y, 0.0)
			poly.append(Vector2(w.x, w.z))
		out.append(poly)
	return out


## Metres to the nearest shore (Islands) or edge (no Islands); 0 when not on an Island.
func _to_shore(p: Vector2, islands: Array[PackedVector2Array], bounds: Rect2) -> float:
	if islands.is_empty():
		return minf(minf(p.x - bounds.position.x, bounds.end.x - p.x), minf(p.y - bounds.position.y, bounds.end.y - p.y))
	for poly: PackedVector2Array in islands:
		if Geometry2D.is_point_in_polygon(p, poly):
			var best: float = INF
			for i: int in poly.size():
				var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
				best = minf(best, c.distance_to(p))
			return best
	return 0.0


## True when anything but the floor and the Islands collides or watches within CLEAR_M of `at`.
func _crowded(space: PhysicsDirectSpaceState3D, at: Vector3, floor_rid: RID) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CLEAR_M
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	if floor_rid.is_valid():
		query.exclude = [floor_rid]
	for hit: Dictionary in space.intersect_shape(query, 64):
		var collider: Object = hit.get("collider")
		# The Islands are the ground itself; any other terrain piece (a ridge, a cliff, a channel's bank) is in the way.
		if collider is CSGShape3D and String((collider as Node).name).begins_with("Island"):
			continue
		if collider is Node and ((collider as Node).is_in_group(&"map_edge") or String((collider as Node).name).begins_with("Sea")):
			continue
		return true
	return false
