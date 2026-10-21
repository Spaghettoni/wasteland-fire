extends RefCounted
## Helpers shared by the Map 02 scenarios of the split screen evidence harness (Story 038): map_02, bushes and cover_pieces.
## The launch scene plays Map 02 (each scenario declares MAP_SCENE). Places are given in the schematic's numbers
## (design/source/wasteland-fire-map-02-2026-10-16.svg: x 0..160 across, z 0..290 down) and turned into the Map's frame by
## at(): world x = sx - 80, world z = sz - 145, as tools/maps/build_map_02.py builds it.
## Tooling only: nothing under src/ depends on this file.

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Map 02's scene, the one every Map 02 scenario names in MAP_SCENE.
const MAP_02_PATH: String = "res://src/gameplay/maps/map_02/map_02.tscn"
## The schematic's centre, the Map's origin.
const CENTRE: Vector2 = Vector2(80.0, 145.0)
## The floor inside the canyon (schematic numbers) and its corners' radius.
const FLOOR_MIN: Vector2 = Vector2(20.0, 20.0)
const FLOOR_MAX: Vector2 = Vector2(140.0, 270.0)
const FLOOR_CORNER: float = 50.0
## The type indices of match_rules.tres's unit_types.
const MOTORBIKE: int = 0
const BUGGY: int = 1
const TRUCK: int = 2
const GYROCOPTER: int = 3
## Ticks a Unit is left alone after a spawn or a teleport.
const SETTLE_TICKS: int = 3

var h: Harness
var kit: Kit
var split: SplitScreen
var field: MapField
var controller: MatchController
var units: Array[Unit] = []


func _init(harness: Node) -> void:
	h = harness as Harness
	kit = Kit.new(h)
	split = h.split
	field = split.field
	controller = split.match_controller
	units = [split.player_1_unit, split.player_2_unit]


## A schematic point (sx, sz) on the ground of the Map's frame.
static func at(sx: float, sz: float) -> Vector3:
	return Vector3(sx - CENTRE.x, 0.0, sz - CENTRE.y)


## How far a world point lies inside the floor's outline, metres (negative outside it).
static func inside_by(point: Vector3) -> float:
	var s: Vector2 = Vector2(point.x + CENTRE.x, point.z + CENTRE.y)
	var lo: Vector2 = FLOOR_MIN + Vector2(FLOOR_CORNER, FLOOR_CORNER)
	var hi: Vector2 = FLOOR_MAX - Vector2(FLOOR_CORNER, FLOOR_CORNER)
	var nearest: Vector2 = s.clamp(lo, hi)
	if nearest.is_equal_approx(s):
		return minf(minf(s.x - FLOOR_MIN.x, FLOOR_MAX.x - s.x), minf(s.y - FLOOR_MIN.y, FLOOR_MAX.y - s.y))
	return FLOOR_CORNER - s.distance_to(nearest)


## The controller's own UnitStats of a type, never written.
func stats(type_index: int) -> UnitStats:
	return controller.unit_types()[type_index]


## Puts a Player's Unit in play as a type at a place facing a way, keys up, and waits SETTLE_TICKS.
func put(player: int, type_index: int, where: Vector3, facing: Vector3, with_stats: UnitStats = null) -> void:
	h.drive(player, 0, 0)
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, atan2(-facing.x, -facing.z)), Vector3(where.x, 0.0, where.z))
	units[player].spawn(pose, with_stats if with_stats != null else stats(type_index))
	var camera: ChaseCamera = split.player_1_camera if player == 0 else split.player_2_camera
	camera.snap_to_target()
	await kit.advance(SETTLE_TICKS)


## Where a Player's Unit waits out of the way of a test: the middle of the field (Player 1) or of the passage
## (Player 2), out of every Turret's reach.
const PARK_SPOTS: Array[Vector2] = [Vector2(60.0, 145.0), Vector2(128.0, 145.0)]


## Moves a Player's Unit to its park spot as a Motorbike.
func park(player: int) -> void:
	await put(player, MOTORBIKE, at(PARK_SPOTS[player].x, PARK_SPOTS[player].y), Vector3.FORWARD)


## Holds a Player's throttle (and steer) for a number of ticks, then lets go.
func drive_for(player: int, throttle: int, steer: int, ticks: int) -> void:
	h.drive(player, throttle, steer)
	await kit.advance(ticks)
	h.drive(player, 0, 0)


## A copy of a type's stats with another starting share of the tank; the controller's resource is never written.
func small_tank(type_index: int, fraction: float) -> UnitStats:
	var copy: UnitStats = stats(type_index).duplicate() as UnitStats
	copy.spawn_fuel_fraction = fraction
	return copy


## Every node a scene path names under the Map, or null.
func piece(path: String) -> Node3D:
	return field.get_node_or_null(NodePath(path)) as Node3D
