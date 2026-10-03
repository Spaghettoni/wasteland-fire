extends RefCounted
## What the Story 009 scenarios (depot_tanks, gyro_cover, spot_turn, idle_burn, fuel_hint and
## quick_fixes_showcase) share: the Story 007 and 008 kits they stand on (map_kit.gd for staging and
## the log, token_kit.gd for real-key choices, Self-destructs and the engine log), the readings of a
## Unit's heading and of its model's lowest point, both Players' Self-destruct hints, a copy of a
## type's stats with a small tank, the point of a Map piece's face, and the judge of a run into an
## obstacle (met at speed, stopped within STOP_TICKS of the first wall contact, the centre where
## the obstacle's surface and the half-length put it, still there at the end).
## Implements: production/epics/wasteland-fire/story-009-playtest-quick-fixes.md, Test Evidence.
## Tooling only: nothing under src/ depends on this file. Loaded with a preload constant: nothing
## under tools/ declares a class_name.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the Map's nodes, the staging, the log, the wall contact.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")
## The Story 008 helpers (token_kit.gd): real-key choices, Self-destructs, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 005 helpers (unit_kit.gd): the type data and the record of every Shot.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## The Motorbike's index into the data (unit_kit.gd TYPE_IDS).
const MOTORBIKE: int = 0
## The Buggy's index into the data.
const BUGGY: int = 1
## The Truck's index into the data.
const TRUCK: int = 2
## The Gyrocopter's index into the data.
const GYROCOPTER: int = 3
## Where Player 1 stands for the standing and lane runs: on the salt flat west of the ford, clear of
## cover, Fuel Cans, cliffs and the Base (map_layout's table: the flat spans z -18 to 18, the nearest
## wreck is at (-80, 5), the canyon Fuel Can at (-88, -26)). Player 2 stands at the mirror.
const LANE_SPOT: Vector3 = Vector3(-85.0, 0.0, -12.0)
## A Unit is stopped below this real speed, m/s (the data's blocked_speed).
const STOP_SPEED: float = 0.5
## A Unit is stopped within this many ticks of its first wall contact.
const STOP_TICKS: int = 2
## A stopped Unit's centre lies where the surface and its half-length put it, within this, metres.
const FLUSH_TOLERANCE: float = 0.05
## A Shot ends within this of the surface it was fired at, metres.
const SHOT_TOLERANCE: float = 0.01
## The name of a Map piece's drawn box (the cover's and the Base walls' Mesh child).
const MESH_NAME: String = "Mesh"

## The runner.
var harness: Harness
## The check helpers.
var kit: Kit
## The Story 007 helpers: staging, the log of places and speeds, wall contacts.
var map: Map
## The Story 008 helpers: real-key choices and Self-destructs, the engine log, the signal record.
var tokens: Tokens
## The Story 005 record (the Units, cameras, HUDs, panels and every Shot), tokens.units.
var units: Units
## The launch scene's MatchController.
var controller: MatchController
## Each Player's Self-destruct hint (split_screen.tscn), found under that Player's SubViewport.
var hints: Array[SelfDestructHint] = [null, null]


## Makes the kits (one check kit, one map kit, one token kit with its Story 005 record) and finds
## both hints. Set kit.on_tick to the scenario's hook; call close() before finish().
func _init(harness_node: Node) -> void:
	harness = harness_node as Harness
	kit = Kit.new(harness)
	map = Map.new(harness, kit)
	tokens = Tokens.new(harness, kit)
	units = tokens.units
	controller = tokens.controller
	for player: int in Kit.PLAYERS:
		for node: Node in (units.cameras[player].get_viewport() as SubViewport).get_children():
			var hint: SelfDestructHint = node as SelfDestructHint
			if hint != null and hint.unit == units.units[player]:
				hints[player] = hint


## Removes the engine log counter (token_kit.gd): call it before the scenario's finish().
func close() -> void:
	tokens.close()


## The engine's ERROR and WARNING lines since the kit was made, as "errors=n warnings=n".
func engine_counts() -> String:
	return "errors=%d warnings=%d" % [tokens.engine_log.errors.size(), tokens.engine_log.warnings.size()]


## A Unit's heading as a yaw in radians about +Y (positive turns left), from its facing (-Z).
static func yaw(unit: Unit) -> float:
	var facing: Vector3 = -unit.global_transform.basis.z
	return atan2(-facing.x, -facing.z)


## The turn from one yaw to the next, wrapped into -PI to PI, radians (positive turns left).
static func turned(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)


## A Unit's place on the ground (world x, z).
static func ground(node: Node3D) -> Vector2:
	return Vector2(node.global_position.x, node.global_position.z)


## The lowest point of a Unit's model in the world, metres: the least y of the world boxes of the
## model's meshes (its Accent and Neutral parts); INF when the Unit has no model.
static func model_bottom(unit: Unit) -> float:
	var model: Node = unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME)))
	var lowest: float = INF
	if model == null:
		return lowest
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		lowest = minf(lowest, (mesh.global_transform * mesh.get_aabb()).position.y)
	return lowest


## The world box of a Unit's model (the merge of its meshes' world boxes); an empty box without one.
static func model_box(unit: Unit) -> AABB:
	var model: Node = unit.get_node_or_null(NodePath(String(Unit.MODEL_NODE_NAME)))
	var box: AABB = AABB()
	var first: bool = true
	if model == null:
		return box
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var part: AABB = mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## A copy of a type's stats with another starting share of the tank (spawn_fuel_fraction), for a
## Unit that must run dry soon; the controller's resource is never written.
func small_tank(type_index: int, fraction: float) -> UnitStats:
	var copy: UnitStats = units.stats(type_index).duplicate() as UnitStats
	copy.spawn_fuel_fraction = fraction
	return copy


## Puts a Player's Unit in play with the given stats at a place facing a way, keys up, snaps its
## camera and waits Map.SETTLE_TICKS: a spawn as the Round would do, with stats the scenario made.
func put(player: int, stats: UnitStats, at: Vector3, facing: Vector3) -> void:
	harness.drive(player, 0, 0)
	units.units[player].spawn(units.pose(at, facing), stats)
	units.cameras[player].snap_to_target()
	await kit.advance(Map.SETTLE_TICKS)


## The mirror of a place across X = 0 (Player 2's side of Map 01).
static func mirrored(at: Vector3) -> Vector3:
	return Vector3(-at.x, at.y, at.z)


## The point of a Map piece's visible face that looks along normal (world x, z), shifted by shift
## along the ground: the piece's ground centre plus shift, then out along normal to the farthest
## corner of its drawn box (its MESH_NAME child). Vector2.INF when the piece or its mesh is missing.
func face_point(path: String, normal: Vector2, shift: Vector2 = Vector2.ZERO) -> Vector2:
	var piece: Node3D = map.find(path) as Node3D
	var mesh: MeshInstance3D = (piece.get_node_or_null(MESH_NAME) as MeshInstance3D) if piece != null else null
	if mesh == null:
		return Vector2.INF
	var centre: Vector2 = ground(piece) + shift
	var reach: float = -INF
	for corner: int in 8:
		var point: Vector3 = mesh.global_transform * mesh.get_aabb().get_endpoint(corner)
		reach = maxf(reach, (Vector2(point.x, point.z) - centre).dot(normal))
	return centre + normal * reach


## The top of a Map piece's drawn box in the world, metres; -INF when the piece or its mesh is
## missing.
func top_of(path: String) -> float:
	var piece: Node3D = map.find(path) as Node3D
	var mesh: MeshInstance3D = (piece.get_node_or_null(MESH_NAME) as MeshInstance3D) if piece != null else null
	if mesh == null:
		return -INF
	return (mesh.global_transform * mesh.get_aabb()).end.y


## Judges one Player's logged run into an obstacle (the map kit's log, cleared at the start of the
## run, and the first logged tick with a wall contact): the real speed it met the obstacle at, the
## ticks from the first contact until it moved slower than STOP_SPEED, the least `distance` the
## log reached (the caller's measure of the centre's place: off a flat face, or from a tank's axis)
## against `expected`, and the real speed at the end. Adds the problems it finds and returns
## [hit speed, stop ticks, least distance, end speed].
func judge_stop(player: int, contact: int, distance: Callable, expected: float, label: String,
		problems: PackedStringArray) -> Array[float]:
	var nearest: float = INF
	var stop: int = -1
	for index: int in map.places[player].size():
		nearest = minf(nearest, distance.call(map.places[player][index]))
		if stop < 0 and contact >= 0 and index >= contact and map.real_speed(player, index) < STOP_SPEED:
			stop = index - contact
	var hit: float = map.real_speed(player, contact - 1) if contact > 1 else 0.0
	var end: float = map.real_speed(player, -1)
	var last: float = distance.call(map.places[player][-1]) if not map.places[player].is_empty() else INF
	kit.need(problems, contact >= 0, "%s never touched it" % label)
	kit.need(problems, stop >= 0 and stop <= STOP_TICKS, "%s not stopped within %d ticks of its contact (%d)" % [label, STOP_TICKS, stop])
	kit.need(problems, absf(nearest - expected) <= FLUSH_TOLERANCE and absf(last - expected) <= FLUSH_TOLERANCE,
		"%s came to %.3f and ended at %.3f, not %.3f" % [label, nearest, last, expected])
	kit.need(problems, end < STOP_SPEED, "%s still moving at %.2f m/s at the end" % [label, end])
	return [hit, float(stop), nearest, end]
