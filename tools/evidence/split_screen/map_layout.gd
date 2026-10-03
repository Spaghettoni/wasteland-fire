extends RefCounted
## Scenario map_layout of the split screen evidence harness (split_screen_harness.gd): Map 01 as
## built, against the story's positions table and its own mirror, on the main composition; nothing
## drives (OWN_CHOICE, and no choice is made). Two CHECK lines with the measured numbers:
## map_positions (AC-1: Map 01 is World's first child, the greybox nodes are gone, the nine Fuel
## Cans are the Map's; each table entry within 1 m of its built node, the canyon rock's north face
## excepted, built out to the shore; a SPLIT line per entry, table beside built) and
## map_mirror_data (AC-2, AC-9: each collider, zone, SpawnPoint marker, Flag seat and Fuel Can spot
## mirrors within 0.1 m with its heading (map_kit.gd); Tokens 5, 3, 2, 2; one shared ford fraction
## 0.5; each Base's own SpawnPoint markers, no loose start markers; one floor slab under the rock,
## the water and the island; only the scripts this story names). Implements:
## production/epics/wasteland-fire/story-007-the-map.md AC-1, AC-2, AC-9 and its positions table
## (the Story 007 evidence doc lists the deviations from it); design/rules.md "Units". Tooling.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=map_layout

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks and the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the Map's nodes, their collision points, the mirror test.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: it makes none, as nothing here drives.
const OWN_CHOICE: bool = true
## AC-1: a built place lies within this of its table entry, metres.
const TOLERANCE: float = 1.0
## AC-2: a collider, marker or spot lies within this of its partner's mirror, metres.
const MIRROR_TOLERANCE: float = 0.1
## A built heading lies within this of the table's, degrees.
const HEADING_TOLERANCE: float = 1.0
## Float noise of world points (single precision, snapped to 1 mm), metres: an offset this far
## past its limit still counts as within it.
const MEASURE_EPSILON: float = 1e-4
## Places of the table, west half and centre: node path from the Map to (x, z), metres. The east
## half is each west path's mirror (_east()) at x negated.
const POINTS: Dictionary[String, Vector2] = {"Base1/SpawnPoint": Vector2(-125, 0),
	"Base1/SpareSpawnLeft": Vector2(-125, -4), "Base1/SpareSpawnRight": Vector2(-125, 4),
	"Base1/CanisterSeat": Vector2(-113, 0), "Base1/Walls/TowerGateLeft": Vector2(-105, -16),
	"Base1/Walls/TowerGateRight": Vector2(-105, 16), "Base1/Walls/TowerBackLeft": Vector2(-135, -16),
	"Base1/Walls/TowerBackRight": Vector2(-135, 16), "FuelCanCanyonWest": Vector2(-88, -26),
	"FuelCanFlatWest": Vector2(-62, 14), "Depot/FuelCanDepot1": Vector2(-3, -3),
	"Depot/FuelCanDepot2": Vector2(3, -3), "Depot/FuelCanDepot3": Vector2(0, 0),
	"Depot/FuelCanDepot4": Vector2(-3, 3), "Depot/FuelCanDepot5": Vector2(3, 3),
	"Cover/Wrecks/WreckWestMiddleNorth": Vector2(-53, -8), "Cover/Wrecks/WreckWestOuterSouth": Vector2(-80, 5),
	"Cover/Wrecks/WreckWestInnerNorth": Vector2(-22, -10), "Cover/Wrecks/WreckWestInnerSouth": Vector2(-26, 7.6)}
## Headings of the table: node path to (yaw, the period it repeats at), degrees: 360 for a marker's
## facing (+X is -90), 180 for a wreck's long axis. The east half negates the yaw.
const HEADINGS: Dictionary[String, Vector2] = {"Base1/SpawnPoint": Vector2(-90, 360),
	"Base1/SpareSpawnLeft": Vector2(-90, 360), "Base1/SpareSpawnRight": Vector2(-90, 360),
	"Cover/Wrecks/WreckWestMiddleNorth": Vector2(-30, 180), "Cover/Wrecks/WreckWestOuterSouth": Vector2(30, 180),
	"Cover/Wrecks/WreckWestInnerNorth": Vector2(20, 180), "Cover/Wrecks/WreckWestInnerSouth": Vector2(-45, 180)}
## Extents of the table: node paths (joined by "|") to (x min, x max, z min, z max) of their
## collision, or of their mesh when they have none, metres; the east half mirrored.
const RECTS: Dictionary[String, Vector4] = {"Base1/Walls/WallLeft|Base1/Walls/WallRight": Vector4(-135, -105, -16, 16),
	"Base1/Walls/GateWallLeft": Vector4(-106.3, -105, -16, -5), "Base1/Walls/GateWallRight": Vector4(-106.3, -105, 5, 16),
	"Base1/Garage/GarageFloor": Vector4(-132, -122, -6, 6), "Base1/Zone": Vector4(-133.6, -106.1, -14.7, 14.7),
	"Base1/WaterTower/Tank": Vector4(-117, -109, -4, 4), "Terrain/SaltFlat": Vector4(-95, 95, -18, 18),
	"FordWest": Vector4(-46, -34, -20, 20), "Water/ChannelWest": Vector4(-46, -34, 20, 47),
	"Cover/Containers/ContainerWest": Vector4(-64, -52, -1.25, 1.25),
	"Cover/ScrapWalls/ScrapWallWest": Vector4(-13.25, -10.75, 6, 18)}
## The canyon road's centreline of the table, west to east, (x, z) metres.
const ROAD: Array[Vector2] = [Vector2(-102, -26), Vector2(-80, -26), Vector2(-67, -36), Vector2(-43, -36),
	Vector2(-28, -28), Vector2(28, -28), Vector2(43, -36), Vector2(67, -36), Vector2(80, -26), Vector2(102, -26)]
## The depot's ring marking of the table: centre (x, z) and radius, metres.
const RING: Vector3 = Vector3(0, 0, 9)
## The sea panel of the table (x min, x max, z min, z max), which the sea's surface covers.
const SEA: Vector4 = Vector4(-162, 162, -60, 60)
## Nodes these checks read, by path from the Map.
const PATHS: Dictionary[StringName, String] = {&"road": "Terrain/CanyonRoad", &"ring": "Depot/RingMarking",
	&"sea": "Water/Sea", &"floor": "Floor"}
## The greybox composition's nodes, which the main scene's World no longer holds (AC-1).
const GREYBOX_NODES: Array[String] = ["GreyboxField", "TerrainStandIns", "FuelCans"]
## TD-005's loose start markers, which no Map holds any more (AC-9).
const LOOSE_MARKERS: Array[String] = ["PlayerStart", "Player2Start"]
## The node group of the Fuel Cans.
const FUEL_CAN_GROUP: StringName = &"fuel_cans"
## The Fuel Cans Map 01 holds: the depot's five and four outside it (AC-8).
const FUEL_CAN_COUNT: int = 9
## The Token stock of AC-9 (the source's example) by type id; the empty id reads 0.
const TOKENS: Dictionary[StringName, int] = {&"motorbike": 5, &"buggy": 3, &"truck": 2, &"gyrocopter": 2, &"": 0}
## The fords' one shared settings file (AC-5, AC-9).
const FORD_SETTINGS_PATH: String = "res://src/gameplay/maps/data/ford_settings.tres"
## The ford speed fraction it holds.
const FORD_FRACTION: float = 0.5
## Fords on Map 01.
const FORD_COUNT: int = 2
## The floor's one box (AC-9): (x min, x max, z min, z max), metres; its top is y 0, the one floor.
const FLOOR_RECT: Vector4 = Vector4(-150, 150, -50, 50)
## The map physics layer (layer 1) and the cliffs_water layer (layer 6), by value.
const LAYERS: Vector2i = Vector2i(1, 32)
## The scripts a node of Map 01 may carry: the Map's, the Fords', the Bases', the Flags', the Cans'.
const SCRIPTS: Array[String] = ["res://src/gameplay/maps/map_field.gd", "res://src/gameplay/maps/ford.gd",
	"res://src/gameplay/maps/base.gd", "res://src/gameplay/canister/water_canister.gd",
	"res://src/gameplay/fuel/fuel_can.gd"]

## Points of the table on built edges, (x, z) metres, west half and centre, by the CSG polygons
## they lie on: the island's outline (as the story's table has it), the canyon rock's slanted end
## and south strip (its north face is built out to the shore), the ridge's edges.
## A var, not a const: a PackedVector2Array is never a constant expression in GDScript.
var _edge_points: Dictionary[String, PackedVector2Array] = {"Terrain/Island": PackedVector2Array([
	Vector2(0, -46), Vector2(-30, -47), Vector2(-60, -45), Vector2(-90, -46), Vector2(-112, -43.5),
	Vector2(-130, -38), Vector2(-141, -28), Vector2(-146.5, -14), Vector2(-147, 0),
	Vector2(-146.5, 14), Vector2(-141, 28), Vector2(-130, 38), Vector2(-112, 43), Vector2(-90, 46),
	Vector2(-60, 45), Vector2(-30, 47), Vector2(0, 46)]),
	"Cliffs/RockCanyonNorth|Cliffs/RockCanyonSouth": PackedVector2Array([Vector2(-95, -44),
	Vector2(-100, -30.5), Vector2(-96, -20), Vector2(-90, -22)]),
	"Cliffs/RidgeWest|Cliffs/RidgeCentre|Cliffs/RidgeEast": PackedVector2Array([Vector2(-95, 22),
	Vector2(-100, 32), Vector2(-95, 45), Vector2(-70, 22), Vector2(0, 21)])}
var _harness: Harness
var _kit: Kit
var _map: Map
var _worst: Dictionary[String, float] = {}
var _entries: int = 0


## Runs both checks once the Map has settled (a CSG's collision exists from its second tick), then
## the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_map = Map.new(harness, _kit)
	await _kit.advance(Kit.START_TICKS)
	var problems: PackedStringArray = []
	var notes: PackedStringArray = [_composition(problems)]
	notes.append_array([_points(problems), _rects(problems), _edges(problems), _landmarks(problems)])
	_kit.verdict("map_positions", problems, " | ".join(notes))
	problems = []
	_kit.verdict("map_mirror_data", problems, _mirror_data(problems))
	_harness.finish("entries=%d" % _entries)


## AC-1's composition: World's first child is the Map, no greybox node is left under World, and
## the tree's only Fuel Cans are the Map's FUEL_CAN_COUNT. Its detail.
func _composition(problems: PackedStringArray) -> String:
	var world: Node = _harness.split.get_node("World")
	var first: bool = world.get_child(0) == _map.map and _map.map.name == &"Map"
	var greybox: int = 0
	for node_name: String in GREYBOX_NODES:
		greybox += 0 if world.find_child(node_name, true, false) == null else 1
	var cans: int = _map.members(FUEL_CAN_GROUP).size()
	var all_cans: int = _harness.get_tree().get_nodes_in_group(FUEL_CAN_GROUP).size()
	_kit.need(problems, first and greybox == 0 and cans == FUEL_CAN_COUNT and all_cans == cans,
		"the main scene's World does not hold Map 01 first with its own %d Fuel Cans alone" % FUEL_CAN_COUNT)
	return "Map is World's child 0=%s, greybox nodes=%d, Fuel Cans %d of %d in the Map" % [first, greybox, cans, all_cans]


## AC-1's places and headings: each POINTS entry (and its east twin) within TOLERANCE of its
## node's (x, z), each HEADINGS entry within HEADING_TOLERANCE of its node's yaw. Its detail.
func _points(problems: PackedStringArray) -> String:
	for path: String in POINTS:
		for side: int in _sides(path):
			var node: Node3D = _map.find(_side(path, side)) as Node3D
			var table: Vector2 = POINTS[path] * Vector2(side, 1)
			var built: Vector2 = Vector2(node.global_position.x, node.global_position.z) if node != null else Vector2.INF
			_note(problems, "place", _side(path, side), _xz(table), _xz(built), table.distance_to(built), TOLERANCE)
	for path: String in HEADINGS:
		for side: int in _sides(path):
			var node: Node3D = _map.find(_side(path, side)) as Node3D
			var spec: Vector2 = HEADINGS[path]
			var yaw: float = rad_to_deg(node.global_transform.basis.get_euler().y) if node != null else INF
			var off: float = absf(wrapf(yaw - spec.x * side, -spec.y / 2.0, spec.y / 2.0)) if node != null else INF
			_note(problems, "heading", _side(path, side), "%.1f" % (spec.x * side), "%.1f" % yaw, off, HEADING_TOLERANCE)
	return "places max %.3f m, headings max %.3f deg" % [_worst.get("place", INF), _worst.get("heading", INF)]


## AC-1's extents: each RECTS entry (and its east twin) within TOLERANCE of its nodes' extent.
func _rects(problems: PackedStringArray) -> String:
	for paths: String in RECTS:
		for side: int in _sides(paths):
			var points: PackedVector3Array = []
			for path: String in _side(paths, side).split("|"):
				points.append_array(_map.footprint(_map.find(path)) if _map.find(path) != null else PackedVector3Array())
			var west: Vector4 = RECTS[paths]
			var table: Vector4 = west if side == 1 else Vector4(-west.y, -west.x, west.z, west.w)
			var difference: Vector4 = (table - _extent(points)).abs()
			_note(problems, "extent", _side(paths, side), _box(table), _box(_extent(points)),
				difference[difference.max_axis_index()], TOLERANCE)
	return "extents max %.3f m" % _worst.get("extent", INF)


## AC-1's edge points: each point of the table on a built edge, and its mirror off the centre line,
## within TOLERANCE of the nearest edge of the built polygons it lies on. Its detail, the worst.
func _edges(problems: PackedStringArray) -> String:
	for paths: String in _edge_points:
		var outlines: Array[PackedVector2Array] = []
		for path: String in paths.split("|"):
			outlines.append(_map.outline(path))
		for point: Vector2 in _edge_points[paths]:
			for side: int in ([1] if is_zero_approx(point.x) else [1, -1]):
				var at: Vector2 = point * Vector2(side, 1)
				var nearest: Vector2 = Vector2.INF
				for polygon: PackedVector2Array in outlines:
					for index: int in polygon.size():
						var on_edge: Vector2 = Geometry2D.get_closest_point_to_segment(at, polygon[index], polygon[(index + 1) % polygon.size()])
						nearest = on_edge if at.distance_to(on_edge) < at.distance_to(nearest) else nearest
				_note(problems, paths.get_slice("/", 1).get_slice("|", 0), paths.get_slice("|", 0), _xz(at), _xz(nearest), at.distance_to(nearest), TOLERANCE)
	return "edges max island %.3f, rock %.3f, ridge %.3f m" % [_worst.get("Island", INF), _worst.get("RockCanyonNorth", INF), _worst.get("RidgeWest", INF)]


## AC-1's road, ring and sea: the road strip's centreline against ROAD, the ring's dashes (their
## mean centre and radius) against RING, the sea's surface covering SEA. Its detail.
func _landmarks(problems: PackedStringArray) -> String:
	var road: PackedVector2Array = _map.outline(PATHS[&"road"])
	for index: int in ROAD.size():
		var built: Vector2 = (road[index] + road[road.size() - 1 - index]) / 2.0 if road.size() == 2 * ROAD.size() else Vector2.INF
		_note(problems, "road", PATHS[&"road"], _xz(ROAD[index]), _xz(built), ROAD[index].distance_to(built), TOLERANCE)
	var dashes: Array[Node] = _map.find(PATHS[&"ring"]).get_children() if _map.find(PATHS[&"ring"]) != null else []
	var centre: Vector2 = Vector2.ZERO
	var radius: float = 0.0
	for dash: Node in dashes:
		centre += Vector2((dash as Node3D).global_position.x, (dash as Node3D).global_position.z) / dashes.size()
	for dash: Node in dashes:
		radius += Vector2((dash as Node3D).global_position.x, (dash as Node3D).global_position.z).distance_to(centre) / dashes.size()
	var ring_off: float = maxf(centre.distance_to(Vector2(RING.x, RING.y)), absf(radius - RING.z)) if not dashes.is_empty() else INF
	_note(problems, "ring", PATHS[&"ring"], "%s r=%.2f" % [_xz(Vector2(RING.x, RING.y)), RING.z], "%s r=%.3f" % [_xz(centre), radius], ring_off, TOLERANCE)
	var sea: Vector4 = _extent(_map.footprint(_map.find(PATHS[&"sea"]))) if _map.find(PATHS[&"sea"]) != null else Vector4.ZERO
	var short: float = maxf(maxf(sea.x - SEA.x, SEA.y - sea.y), maxf(sea.z - SEA.z, SEA.w - sea.w))
	_note(problems, "sea", PATHS[&"sea"], _box(SEA), _box(sea), maxf(short, 0.0), 0.0)
	return "road max %.3f m, ring %.3f m, sea short of the panel by %.3f m" % [_worst.get("road", INF), ring_off, maxf(short, 0.0)]


## AC-2 and AC-9: the mirror test (map_kit.gd mirror()) and the Token stock against TOKENS, then
## the fords, the Garages, the floor and the scripts. Their details, joined.
func _mirror_data(problems: PackedStringArray) -> String:
	var notes: PackedStringArray = [_map.mirror(problems, MIRROR_TOLERANCE)]
	var counts: PackedStringArray = []
	for type_id: StringName in TOKENS:
		var count: int = _map.map.token_stock.count_of(type_id) if _map.map.token_stock != null else -1
		counts.append("%s=%d" % [type_id if not type_id.is_empty() else &"(none)", count])
		_kit.need(problems, count == TOKENS[type_id], "the Token stock reads %d for '%s', not %d" % [count, type_id, TOKENS[type_id]])
	notes.append_array(["tokens " + " ".join(counts), _fords(problems), _garages(problems), _floor(problems), _scripts(problems)])
	return " | ".join(notes)


## AC-9: FORD_COUNT Fords share the one FordSettings at FORD_SETTINGS_PATH, at FORD_FRACTION.
func _fords(problems: PackedStringArray) -> String:
	var settings: Array[FordSettings] = []
	for node: Node in _map.map.find_children("*", "Ford", true, false):
		settings.append((node as Ford).settings)
	var one: FordSettings = settings[0] if settings.size() == FORD_COUNT and settings[0] == settings[1] else null
	var fraction: float = one.speed_fraction if one != null else -1.0
	_kit.need(problems, one != null and one.resource_path == FORD_SETTINGS_PATH and fraction == FORD_FRACTION,
		"the %d fords do not share %s at %.2f" % [FORD_COUNT, FORD_SETTINGS_PATH, FORD_FRACTION])
	return "fords=%d sharing one settings=%s (%s) fraction=%.2f" % [settings.size(), one != null,
		one.resource_path.get_file() if one != null else "-", fraction]


## AC-9's Garages: each Base holds its own SpawnPoint markers and first_spawn_problem() names
## none; the launch scene holds no loose start marker. Its detail.
func _garages(problems: PackedStringArray) -> String:
	var own: PackedStringArray = []
	for base: Base in [_map.map.player_1_base, _map.map.player_2_base]:
		var markers: Array[Marker3D] = [base.spawn_point]
		markers.append_array(base.spare_spawn_points)
		for marker: Marker3D in markers:
			_kit.need(problems, marker != null and base.is_ancestor_of(marker), "%s points at a SpawnPoint marker it does not hold" % base.name)
		_kit.need(problems, base.first_spawn_problem().is_empty(), "%s: %s" % [base.name, base.first_spawn_problem()])
		own.append("%s %d own" % [base.name, markers.size()])
	var loose: int = 0
	for marker_name: String in LOOSE_MARKERS:
		loose += 0 if _harness.split.find_child(marker_name, true, false) == null else 1
	_kit.need(problems, loose == 0, "the launch scene still holds a loose PlayerStart or Player2Start")
	return "SpawnPoint markers %s, first_spawn_problem none; loose start markers=%d" % [", ".join(own), loose]


## AC-9's floor: one layer-1 box FLOOR_RECT wide, its top at y 0, reaching past every
## cliffs_water collider and the island's outline. Its detail.
func _floor(problems: PackedStringArray) -> String:
	var body: StaticBody3D = _map.find(PATHS[&"floor"]) as StaticBody3D
	if body == null:
		problems.append("the Map has no Floor")
		return "no floor"
	var points: PackedVector3Array = _map.footprint(body)
	var top: float = -INF
	for point: Vector3 in points:
		top = maxf(top, point.y)
	var slab: Vector4 = _extent(points)
	var shapes: int = body.find_children("*", "CollisionShape3D", false, false).size()
	var whole: bool = shapes == 1 and slab.is_equal_approx(FLOOR_RECT) and is_zero_approx(top) and body.collision_layer == LAYERS.x
	var spread: Vector4 = _extent(_rock_water_island())
	var under: bool = _covers(slab, spread)
	_kit.need(problems, whole and under, "the floor is not one %s box on layer %d, top y 0, under the rock, water and island" % [_box(FLOOR_RECT), LAYERS.x])
	return "floor %d box %s on layer %d, top y %.3f; rock, water and island span %s over it=%s" % [shapes, _box(slab),
		body.collision_layer, top, _box(spread), under]


## True when the extent inner (x min, x max, z min, z max) lies strictly inside the extent outer.
func _covers(outer: Vector4, inner: Vector4) -> bool:
	return inner.x > outer.x and inner.y < outer.y and inner.z > outer.z and inner.w < outer.w


## The world points of the Map's cliffs_water colliders and of the island's outline.
func _rock_water_island() -> PackedVector3Array:
	var points: PackedVector3Array = []
	for node: Node in _map.map.find_children("*", "Node", true, false):
		points.append_array(_map.footprint(node) if _layer_of(node) == LAYERS.y else PackedVector3Array())
	for point: Vector2 in _map.outline():
		points.append(Vector3(point.x, 0.0, point.y))
	return points


## The collision layer of a collision object or a collision CSG, else 0.
func _layer_of(node: Node) -> int:
	var csg: CSGShape3D = node as CSGShape3D
	if csg != null and csg.use_collision:
		return csg.collision_layer
	return (node as CollisionObject3D).collision_layer if node is CollisionObject3D else 0


## AC-9: every script a node of the Map carries is one of SCRIPTS. Its detail, the files found.
func _scripts(problems: PackedStringArray) -> String:
	var found: PackedStringArray = []
	for node: Node in [_map.map] + _map.map.find_children("*", "Node", true, false):
		var script: Script = node.get_script() as Script
		if script != null and not found.has(script.resource_path):
			found.append(script.resource_path)
			_kit.need(problems, SCRIPTS.has(script.resource_path), "a Map node carries a script this story does not name: " + script.resource_path)
	var names: PackedStringArray = []
	for path: String in found:
		names.append(path.get_file())
	return "scripts " + ", ".join(names)


## Prints one SPLIT line for a table entry, keeps the worst offset of its group and adds a problem
## when the offset exceeds the limit.
func _note(problems: PackedStringArray, group: String, label: String, table: String, built: String, off: float, limit: float) -> void:
	_entries += 1
	_worst[group] = maxf(_worst.get(group, 0.0), off)
	print("SPLIT %s t=%.3f entry=%s group=%s table=%s built=%s off=%.3f" % [_harness.scenario, _harness.time(), label, group, table, built, off])
	_kit.need(problems, off <= limit + MEASURE_EPSILON, "%s %s: built %s against the table's %s, %.3f off" % [group, label, built, table, off])


## A point (x, z) as text for a SPLIT line, to the centimetre.
func _xz(point: Vector2) -> String:
	return "(%.2f,%.2f)" % [point.x, point.y]


## An extent (x min, x max, z min, z max) as text for a SPLIT line, to the centimetre.
func _box(extent: Vector4) -> String:
	return "(x%.2f..%.2f,z%.2f..%.2f)" % [extent.x, extent.y, extent.z, extent.w]


## The extent (x min, x max, z min, z max) of world points, (INF, -INF, INF, -INF) for none.
func _extent(points: PackedVector3Array) -> Vector4:
	var extent: Vector4 = Vector4(INF, -INF, INF, -INF)
	for point: Vector3 in points:
		extent = Vector4(minf(extent.x, point.x), maxf(extent.y, point.x), minf(extent.z, point.z), maxf(extent.w, point.z))
	return extent


## 1 for the table's own entry, and -1 for its mirror when the mirror is another node.
func _sides(paths: String) -> Array[int]:
	var sides: Array[int] = [1]
	if _east(paths) != paths:
		sides.append(-1)
	return sides


## The table's own node paths for side 1, their east twins (_east()) for side -1.
func _side(paths: String, side: int) -> String:
	return paths if side == 1 else _east(paths)


## The east half's node for a west node: Base2 for Base1 with left and right swapped (Base B is
## Base A turned, so its left part mirrors Base A's right one), East for West elsewhere.
func _east(paths: String) -> String:
	var parts: PackedStringArray = paths.split("|")
	for index: int in parts.size():
		var part: String = parts[index]
		parts[index] = part.replace("West", "East") if not part.begins_with("Base1/") else \
			"Base2/" + part.trim_prefix("Base1/").replace("Left", "#").replace("Right", "Left").replace("#", "Right")
	return "|".join(parts)
