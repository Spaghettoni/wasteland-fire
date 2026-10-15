extends RefCounted
## What stays Cover, for the garage_scrap_walls scenario (Story 019 AC-5): cover_unchanged (a Shot on a wreck and on a
## container ends on its face and changes nothing about it, the eight wrecks and two containers stand as they were,
## and the Gyrocopter still flies over both). Run by garage_scrap_walls.gd. Tooling only. Every number comes from the
## game's data; the scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The Cover pieces the Shots and the flights try, by path from the Map: a wreck and a container, and the side each is
## approached from (the piece's own frame, a unit vector on the ground).
const WRECK: String = "Cover/Wrecks/WreckWestOuterSouth"
const CONTAINER: String = "Cover/Containers/ContainerEast"
const WRECK_SIDE: Vector2 = Vector2(0, -1)
const CONTAINER_SIDE: Vector2 = Vector2(0, 1)
## Metres a shooter stands from a Cover piece's face, and how far from the surface of its box a Shot may end.
const SHOT_FROM: float = 12.0
const SURFACE_TOLERANCE: float = 0.02
## The ticks a flight may take, the least share of its top speed a Gyrocopter keeps over a piece, how far under the rise
## clearance its model may come and how far under the speed it had as its model came over the piece it may slow
## (metres, metres per second).
const RUN_LIMIT_TICKS: int = 420
const SPEED_SHARE: float = 0.9
const RISE_SLACK: float = 0.02
const SLOW_SLACK: float = 0.05

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick
## For the Gyrocopter being flown (Player 1's): the ticks its model was over the piece it crosses, the least height of
## its lowest point over that piece's top then, its slowest real speed then and the speed as it first came over.
var _over: int = 0
var _clear: float = INF
var _slowest: float = INF
var _entry: float = INF
var _piece: MeshInstance3D


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _cover_unchanged()


## The Gyrocopter's model.
func _model() -> UnitModel:
	return _q.units.units[0].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel


## Logs the Gyrocopter after a tick (the map kit's log), and the ticks its model's footprint covers the piece it crosses,
## the least height of its lowest point over that piece's top, and its slowest real speed then.
func _cross_tick() -> void:
	_q.map.log_tick()
	var box: AABB = Quick.model_box(_q.units.units[0])
	var piece_box: AABB = _piece.global_transform * _piece.get_aabb()
	if box.position.x < piece_box.end.x and box.end.x > piece_box.position.x and box.position.z < piece_box.end.z and box.end.z > piece_box.position.z:
		_over += 1
		_clear = minf(_clear, box.position.y - piece_box.end.y)
		_slowest = minf(_slowest, _q.map.real_speed(0, -1))
		_entry = _q.map.real_speed(0, -1) if _over == 1 else _entry


## How far a world point lies from the surface of a Cover piece's box, metres (the piece's collider is one box): the
## Shot that ends on a wreck turned 30 degrees ends on a face, not on the corner `Quick.face_point()` reads.
func _off_surface(piece: Node3D, point: Vector3) -> float:
	var shape: CollisionShape3D = piece.get_node("CollisionShape3D") as CollisionShape3D
	var half: Vector3 = (shape.shape as BoxShape3D).size / 2.0
	var local: Vector3 = shape.global_transform.affine_inverse() * point
	return absf(maxf(maxf(absf(local.x) - half.x, absf(local.y) - half.y), absf(local.z) - half.z))


## What a Cover piece is, for the before and after of cover_unchanged: its place, layers and shape.
func _cover_state() -> PackedStringArray:
	var found: PackedStringArray = []
	var cover: Node = _q.harness.split.field.get_node("Cover")
	for body: Node in cover.find_children("*", "StaticBody3D", true, false):
		var shape: CollisionShape3D = body.get_node("CollisionShape3D") as CollisionShape3D
		found.append("%s %s layer %d mask %d size %s" % [cover.get_path_to(body), (body as StaticBody3D).global_transform, (body as StaticBody3D).collision_layer, (body as StaticBody3D).collision_mask, (shape.shape as BoxShape3D).size])
	return found


## cover_unchanged (AC-5): a Buggy's Shot at the visible face of a wreck and of a container ends on that face and
## changes nothing about it (it is a plain body with no hit points; the ten pieces keep their places, layers and shapes);
## then one Gyrocopter crosses the wreck and another the container, at full speed, its model rising over each.
func _cover_unchanged() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var before: PackedStringArray = _cover_state()
	_q.kit.need(problems, before.size() == 10, "Cover holds %d bodies, not the 8 wrecks and 2 containers" % before.size())
	var matrix_hits: int = 0
	for entry: Array in [[WRECK, WRECK_SIDE], [CONTAINER, CONTAINER_SIDE]]:
		var path: String = entry[0]
		var normal: Vector2 = entry[1]
		var piece: Node3D = _q.map.find(path) as Node3D
		_q.kit.need(problems, piece != null and not piece.has_method("apply_damage"), "%s is missing or takes damage" % path)
		var from: Vector2 = Quick.ground(piece) + normal * (SHOT_FROM + 3.0)
		await _k.k.stage(0, Quick.BUGGY, Vector3(from.x, 0.0, from.y), Vector3(-normal.x, 0.0, -normal.y))
		await _q.kit.advance(_k.k.m.w.longest_cadence())
		var end: Vector3 = await _k.k.m.w.shoot(0)
		var off: float = _off_surface(piece, end) if end != Vector3.INF else INF
		_q.kit.need(problems, off <= SURFACE_TOLERANCE, "the Shot at %s ended %.3f m from the surface of its box" % [path, off])
		notes.append("%s %.3f m off the surface of its box" % [path.get_file(), off])
		matrix_hits += 1
	await _q.kit.advance(Kit19.Kit18.IN_FLIGHT_TICKS)
	_q.kit.need(problems, _cover_state() == before, "a Cover piece changed after a Shot ended on it")
	var crossings: PackedStringArray = []
	for entry: Array in [[WRECK, WRECK_SIDE], [CONTAINER, CONTAINER_SIDE]]:
		var path: String = entry[0]
		var normal: Vector2 = entry[1]
		var piece: Node3D = _q.map.find(path) as Node3D
		var half: float = _q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
		var centre: Vector2 = Quick.ground(piece)
		var start: Vector2 = centre + normal * (SHOT_FROM + half)
		var across: Vector3 = Vector3(-normal.x, 0.0, -normal.y)
		_piece = piece.get_node("Mesh") as MeshInstance3D
		await _q.map.stage([Quick.GYROCOPTER, -1], [Vector3(start.x, 0.0, start.y), Vector3.ZERO], [across, Vector3.ZERO], true)
		_over = 0
		_clear = INF
		_slowest = INF
		_entry = INF
		_q.map.clear_log()
		_q.kit.on_tick = _cross_tick
		var beyond: float = (SHOT_FROM + half) * 2.0
		for _tick: int in RUN_LIMIT_TICKS:
			var gone: float = (Quick.ground(_q.units.units[0]) - centre).dot(normal)
			_q.harness.drive(0, 0 if gone <= -beyond / 2.0 else 1, 0)
			await _q.kit.tick()
			if gone <= -beyond / 2.0:
				break
		_q.kit.on_tick = Callable()
		_q.harness.release_all()
		_q.kit.need(problems, _q.map.contacts[0] == 0 and _over > 0 and _clear >= _model().rise_clearance - RISE_SLACK and _slowest >= minf(SPEED_SHARE * _q.units.stats(Quick.GYROCOPTER).max_speed, _entry) - SLOW_SLACK, "the Gyrocopter over %s touched %d times, was over it %d ticks at %.3f m, slowest %.2f m/s" % [path, _q.map.contacts[0], _over, _clear, _slowest])
		crossings.append("%s %.2f m over for %d ticks" % [path.get_file(), _clear, _over])
	_q.kit.need(problems, _cover_state() == before, "a Cover piece changed after a Gyrocopter crossed it")
	measured.append("cover=%d" % before.size())
	_q.kit.verdict("cover_unchanged", problems, "Cover holds the 8 wrecks and 2 containers and nothing else; a Buggy's Shot at the visible face of a wreck and of a container ended on that face (%s) and changed nothing about it (the pieces have no hit points, and all ten keep their places, layers and shapes); a Gyrocopter flew over each at full speed with its model rising over it (%s)" % [", ".join(notes), ", ".join(crossings)])
