extends RefCounted
## Where the ammunition buildings stand in the Story 024 scenario ammo_buildings, AC-1: each building and each zone overlaps nothing but
## the floor and is clear of every other piece of the Map by the gaps the story measured; the building's face toward its Base is inside a
## Turret Shot's reach of the nearest Turret and the zone's nearest corner is outside it (35.0 m and 39.0 m of 36.6); and what the
## building hides from a Turret within that reach is a sliver: sampled every 3 cm round it, no point outside the building that a
## sight ray from the Turret's muzzle meets the building before is also within the reach but a strip no Unit can stand in. Tooling only.
## Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-1.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")

const TURRET_STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"
## The layers of the pieces that count for the nearest-piece test: map, cliffs and water, cover.
const PIECE_LAYERS: int = 1 | 32 | 64
## The clearances the story computed or measured, metres, and the slack a measured one may differ by.
const FACE_DISTANCE: float = 35.0
const CORNER_DISTANCE: float = 39.0
const GAP_SLACK: float = 0.05
## A ground Unit can drive round a building if the nearest other piece is at least this far from it, metres.
const PASSAGE: float = 3.0
## The probe box of the overlap test is this much smaller than the shape it probes on every side, and lifted this high, metres.
const SHRINK: float = 0.02
## The step the boundary of a footprint is sampled at for the cliffs and the sea edge, metres.
const OUTLINE_STEP: float = 0.25
## The sliver sampling: the step, the margin round the footprint, and the point heights are the shooting height.
const STEP: float = 0.03
const WINDOW: float = 3.0

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit24
var _q: Quick


func _init(kit: Kit24) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _q.kit.advance(60)
	_overlaps_and_gaps()
	_reach()
	_sliver()


## The building's box size and the footprint's centre.
func _box(side: int) -> Vector3:
	return ((_k.building(side).get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D).size


## The distance from a rectangle on the ground (centre, size x and z, axes along the world's) to a point, metres.
func _rect_gap(centre: Vector3, size: Vector3, point: Vector3) -> float:
	return Vector2(maxf(absf(point.x - centre.x) - size.x / 2.0, 0.0), maxf(absf(point.z - centre.z) - size.z / 2.0, 0.0)).length()


## The nearest Turret of a Base to a point, or null.
func _nearest_turret(base_index: int, point: Vector3) -> Turret:
	var nearest: Turret = null
	for node: Node in _q.map.map.find_children("*", "Turret", true, false):
		var turret: Turret = node as Turret
		if turret.get_parent().get_parent() == _q.units.bases[base_index] and (nearest == null or turret.global_position.distance_to(point) < nearest.global_position.distance_to(point)):
			nearest = turret
	return nearest


## The points of the boundary of a rectangle on the ground (centre, size), every OUTLINE_STEP metres, corners included.
func _boundary(centre: Vector3, size: Vector3) -> PackedVector3Array:
	var points: PackedVector3Array = []
	var columns: int = ceili(size.x / OUTLINE_STEP)
	var rows: int = ceili(size.z / OUTLINE_STEP)
	for column: int in columns + 1:
		var x: float = centre.x - size.x / 2.0 + size.x * float(column) / float(columns)
		points.append(Vector3(x, 0.0, centre.z - size.z / 2.0))
		points.append(Vector3(x, 0.0, centre.z + size.z / 2.0))
	for row: int in rows + 1:
		var z: float = centre.z - size.z / 2.0 + size.z * float(row) / float(rows)
		points.append(Vector3(centre.x - size.x / 2.0, 0.0, z))
		points.append(Vector3(centre.x + size.x / 2.0, 0.0, z))
	return points


## The shortest distance from the boundary of a rectangle to the outline of any of the Map's cliffs (a polygon each), metres: INF for
## none. A point inside a cliff's outline counts as zero.
func _cliff_gap(centre: Vector3, size: Vector3) -> float:
	var best: float = INF
	for node: Node in _q.map.find("Cliffs").get_children():
		var polygon: PackedVector2Array = _q.map.outline(String(_q.map.map.get_path_to(node)))
		if polygon.size() < 3:
			continue
		for point: Vector3 in _boundary(centre, size):
			var inside: float = _q.map.inside_by(point, polygon)
			best = minf(best, 0.0 if inside >= 0.0 else -inside)
	return best


## The shortest distance from the boundary of a rectangle to the sea, that is to the island's outline, metres; negative when a point of
## the boundary lies outside the island.
func _sea_gap(centre: Vector3, size: Vector3) -> float:
	var polygon: PackedVector2Array = _q.map.outline()
	var best: float = INF
	for point: Vector3 in _boundary(centre, size):
		best = minf(best, _q.map.inside_by(point, polygon))
	return best


## The building's footprint and each zone's box overlap nothing but the floor (a probe box a little smaller than the shape, lifted from the
## floor, on every layer), and the gaps from the footprint and from the zone to the nearest piece of the Map (map, cliffs and water, cover)
## that is not part of a Base are measured.
func _overlaps_and_gaps() -> void:
	var problems: PackedStringArray = []
	var summary: PackedStringArray = []
	var space: PhysicsDirectSpaceState3D = _q.map.map.get_world_3d().direct_space_state
	for side: int in 2:
		var building: StaticBody3D = _k.building(side)
		var shapes: Array = [[building.global_position, _box(side)], [_k.centre(_k.ammo_index(side)), _k.zone(_k.ammo_index(side)).size]]
		var names: Array[String] = ["building", "zone"]
		for index: int in 2:
			var probe: BoxShape3D = BoxShape3D.new()
			probe.size = (shapes[index][1] as Vector3) - Vector3.ONE * SHRINK * 2.0
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = probe
			query.transform = Transform3D(Basis.IDENTITY, Vector3(shapes[index][0].x, probe.size.y / 2.0 + SHRINK, shapes[index][0].z))
			query.collision_mask = 0xFFFFF
			query.exclude = [building.get_rid()]
			var hits: Array[Dictionary] = space.intersect_shape(query, 8)
			var found: PackedStringArray = []
			for hit: Dictionary in hits:
				var collider: Node = hit["collider"] as Node
				found.append(String(collider.name))
			_q.kit.need(problems, found.is_empty(), "side %d: the %s overlaps %s" % [side, names[index], found])
			var best: float = INF
			var which: String = ""
			var is_building: bool = index == 0
			for shape: Node in _q.map.map.find_children("*", "CollisionShape3D", true, false):
				var holder: Node = shape.get_parent()
				if not (holder is CollisionObject3D) or holder is Area3D or holder.name == &"Floor" or holder == building or building.is_ancestor_of(holder) or String(holder.get_path()).contains("Base") or holder.is_in_group("map_edge"):
					continue
				if ((holder as CollisionObject3D).collision_layer & PIECE_LAYERS) == 0 or (shape as CollisionShape3D).shape == null:
					continue
				var box: AABB = (shape as CollisionShape3D).global_transform * (shape as CollisionShape3D).shape.get_debug_mesh().get_aabb()
				var centre: Vector3 = shapes[index][0]
				var size: Vector3 = shapes[index][1]
				var apart: Vector2 = Vector2(maxf(maxf(centre.x - size.x / 2.0 - box.end.x, box.position.x - (centre.x + size.x / 2.0)), 0.0), maxf(maxf(centre.z - size.z / 2.0 - box.end.z, box.position.z - (centre.z + size.z / 2.0)), 0.0))
				if apart.length() < best:
					best = apart.length()
					which = String(holder.get_path()).trim_prefix(String(_q.map.map.get_path()) + "/")
			_q.kit.need(problems, best >= PASSAGE, "side %d: the %s is only %.2f m from %s" % [side, names[index], best, which])
			var cliff: float = _cliff_gap(shapes[index][0], shapes[index][1])
			var sea: float = _sea_gap(shapes[index][0], shapes[index][1])
			_q.kit.need(problems, cliff >= PASSAGE and sea >= PASSAGE, "side %d: the %s is %.2f m from the cliffs and %.2f m inside the island's edge" % [side, names[index], cliff, sea])
			summary.append("%s %d: %s %.2f m, cliffs %.2f m, sea edge %.2f m" % [names[index], side, which.get_file(), best, cliff, sea])
			measured.append("gap_%s%d=%s_%.2f_cliffs_%.2f_sea_%.2f" % [names[index], side, which.get_file(), best, cliff, sea])
	_q.kit.verdict("overlaps_and_gaps", problems, "neither building's footprint nor either ammunition zone overlaps anything but the floor, and each is at least %.0f m from the nearest piece of the Map outside the Bases (%s)" % [PASSAGE, "; ".join(summary)])


## The building's face toward its Base against a Turret Shot's reach (the range plus the muzzle's offset from the Turret's centre): the
## face is inside it of the nearest Turret, the zone's nearest corner outside it.
func _reach() -> void:
	var problems: PackedStringArray = []
	var data: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	var reach: float = data.weapon_range + data.muzzle_forward
	var summary: PackedStringArray = []
	for side: int in 2:
		var turret: Turret = _nearest_turret(side, _k.building(side).global_position)
		var building: Vector3 = _k.building(side).global_position
		var face: float = _rect_gap(building, _box(side), Vector3(turret.global_position.x, 0.0, turret.global_position.z))
		var zone: Vector3 = _k.centre(_k.ammo_index(side))
		var corner: float = _rect_gap(zone, _k.zone(_k.ammo_index(side)).size, Vector3(turret.global_position.x, 0.0, turret.global_position.z))
		_q.kit.need(problems, absf(face - FACE_DISTANCE) <= GAP_SLACK and face < reach, "side %d: the building is %.3f m from %s (the story says %.1f, the reach is %.1f)" % [side, face, turret.name, FACE_DISTANCE, reach])
		_q.kit.need(problems, absf(corner - CORNER_DISTANCE) <= GAP_SLACK and corner > reach, "side %d: the zone is %.3f m from %s (the story says %.1f, the reach is %.1f)" % [side, corner, turret.name, CORNER_DISTANCE, reach])
		summary.append("side %d: building %.3f m, zone %.3f m from the Turret at %s" % [side, face, corner, turret.global_position])
		measured.append("reach_side%d=building_%.3f_zone_%.3f_of_%.1f" % [side, face, corner, reach])
	_q.kit.verdict("building_is_in_reach_and_the_zone_is_not", problems, "against the Turrets' reach of %.1f m (range %.1f plus the muzzle's %.1f) the building's face is inside it of the nearest Turret and the zone's nearest corner outside it (%s)" % [reach, data.weapon_range, data.muzzle_forward, "; ".join(summary)])


## What the building hides from the nearest Turret within its reach: every point of a grid of STEP metres round the footprint that lies outside
## the building, within the reach of the Turret's centre and whose sight ray from the muzzle meets the building first. The widest circle that
## fits in those points (the farthest any of them is from a point that is not hidden or lies in the building) must be smaller than the
## smallest Unit's half width.
func _sliver() -> void:
	var problems: PackedStringArray = []
	var data: TurretStats = load(TURRET_STATS_PATH) as TurretStats
	var reach: float = data.weapon_range + data.muzzle_forward
	var mask: int = _q.controller.rules.shot_collision_mask | data.sight_extra_mask
	var space: PhysicsDirectSpaceState3D = _q.map.map.get_world_3d().direct_space_state
	var narrowest: float = INF
	for type_index: int in 4:
		narrowest = minf(narrowest, _q.units.stats(type_index).collision_size.x / 2.0)
	var summary: PackedStringArray = []
	for side: int in 2:
		var building: StaticBody3D = _k.building(side)
		var turret: Turret = _nearest_turret(side, building.global_position)
		var size: Vector3 = _box(side)
		var columns: int = ceili((size.x + 2.0 * WINDOW) / STEP)
		var rows: int = ceili((size.z + 2.0 * WINDOW) / STEP)
		var hidden: Dictionary[Vector2i, bool] = {}
		var corner: Vector3 = Vector3(building.global_position.x - size.x / 2.0 - WINDOW, 0.0, building.global_position.z - size.z / 2.0 - WINDOW)
		for column: int in columns:
			for row: int in rows:
				var point: Vector3 = Vector3(corner.x + column * STEP, _q.controller.rules.shooting_height, corner.z + row * STEP)
				var flat: Vector3 = Vector3(point.x - turret.global_position.x, 0.0, point.z - turret.global_position.z)
				if flat.length() > reach or _rect_gap(building.global_position, size, point) <= 0.0:
					continue
				var muzzle: Vector3 = Vector3(turret.global_position.x, 0.0, turret.global_position.z) + flat.normalized() * data.muzzle_forward + Vector3.UP * _q.controller.rules.shooting_height
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle, point, mask, [turret.get_rid()])
				query.hit_from_inside = true
				var hit: Dictionary = space.intersect_ray(query)
				if not hit.is_empty() and hit["collider"] == building:
					hidden[Vector2i(column, row)] = true
		var widest: float = 0.0
		for cell: Vector2i in hidden:
			var nearest: float = INF
			for step_x: int in range(-12, 13):
				for step_z: int in range(-12, 13):
					if not hidden.has(cell + Vector2i(step_x, step_z)):
						nearest = minf(nearest, Vector2(step_x, step_z).length() * STEP)
			widest = maxf(widest, nearest)
		_q.kit.need(problems, widest < narrowest, "side %d: a circle of %.3f m radius fits in what the building hides within the reach, the narrowest Unit's half width is %.3f m" % [side, widest, narrowest])
		summary.append("side %d: %d hidden points, widest circle %.3f m" % [side, hidden.size(), widest])
		measured.append("sliver_side%d=%d_points_circle_%.3f" % [side, hidden.size(), widest])
	_q.kit.verdict("what_the_building_hides_is_a_sliver", problems, "sampled every %.0f cm round each building, the points outside it that it hides from the nearest Turret within %.1f m of its centre (%s) hold no circle as wide as the narrowest Unit's half width of %.2f m" % [STEP * 100.0, reach, "; ".join(summary), narrowest])
