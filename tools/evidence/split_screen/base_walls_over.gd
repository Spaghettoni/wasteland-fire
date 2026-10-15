extends RefCounted
## What flies over a panel, for the base_walls scenario (Story 018 AC-2): gyro_over (a Gyrocopter flies over a
## panel of each of the five runs at full speed, from outside into the yard and from the yard out again, its model
## rising over the 2 m top and settling back as over a Flag Wall, never slowing) and stopped_by (a corner tower, a
## Garage wall and a leg of the water tower, the pieces of the Map layer, still stop it). Run by base_walls.gd.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The ticks a run may take.
const RUN_LIMIT_TICKS: int = 420
## Metres past the far face where a crossing is over, the least share of its top speed a Gyrocopter keeps over a
## panel, and how far under the rise clearance its model may come, metres.
const PAST: float = 6.0
const SPEED_SHARE: float = 0.9
const RISE_SLACK: float = 0.02
## The face a Gyrocopter flown at a corner tower, at the Garage's back wall or at a leg meets first, Base-local
## metres (the tower's outer face on the side wall's axis, at z 15; the Garage wall's yard face; the leg's
## Gate-side face), and how far short of it, past its half length, the Gyrocopter may stop.
const TOWER_FACE_X: float = -18.15
const TOWER_Z: float = 15.0
const GARAGE_BACK_FACE: float = 12.0
const LEG_FACE_Z: float = -9.3
const FACE_SLACK: float = 0.15

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick
## Per Player: the ticks its model was over the panel in its lane, the least height of its lowest point over the
## panel's top then, and its slowest real speed then (logged by _cross_tick()).
var _over: Array[int] = [0, 0]
var _clear: Array[float] = [INF, INF]
var _slowest: Array[float] = [INF, INF]
var _lane: Array[Structure] = [null, null]


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _gyro_over()
	await _stopped_by()


## gyro_over (AC-2): both Players' Gyrocopters cross the lane panel of a run of their own Base, from outside into
## the yard and from the yard out again, at full speed.
func _gyro_over() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var half: float = stats.collision_size.z / 2.0
	var clearance: float = 0.0
	var crossings: int = 0
	var least: float = INF
	var slowest: float = INF
	for run: int in Kit18.RUN_NAMES.size():
		for outside: bool in [true, false]:
			var face: float = Kit18.OUTER_FACES[run] if outside else Kit18.INNER_FACES[run]
			var far_face: float = Kit18.INNER_FACES[run] if outside else Kit18.OUTER_FACES[run]
			var start: float = _k.start_out(run, half, outside)
			var spots: Array[Vector3] = []
			var facings: Array[Vector3] = []
			for player: int in Kit.PLAYERS:
				spots.append(_k.spot(player, run, Kit18.LANE[run], start))
				facings.append(_k.outward(player, run) * (-1.0 if outside else 1.0))
				_lane[player] = _k.panel(player, run, Kit18.LANE[run])
			await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], spots, facings, true)
			clearance = (_q.units.units[0].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel).rise_clearance
			_over = [0, 0]
			_clear = [INF, INF]
			_slowest = [INF, INF]
			_q.map.clear_log()
			_q.kit.on_tick = _cross_tick
			var finished: Array[bool] = [false, false]
			for _tick: int in RUN_LIMIT_TICKS:
				for player: int in Kit.PLAYERS:
					var along: float = _k.m.w.bases[player].to_local(_q.units.units[player].global_position).dot(Kit18.OUTWARD[run])
					finished[player] = finished[player] or (along <= far_face - PAST if outside else along >= far_face + PAST)
					_q.harness.drive(player, 0 if finished[player] else 1, 0)
				await _q.kit.tick()
				if finished[0] and finished[1]:
					break
			_q.kit.on_tick = Callable()
			_q.harness.release_all()
			for player: int in Kit.PLAYERS:
				var label: String = "p%d over %s from %s" % [player + 1, Kit18.RUN_NAMES[run], "outside" if outside else "the yard"]
				_q.kit.need(problems, _q.map.contacts[player] == 0, "%s touched a wall %d times" % [label, _q.map.contacts[player]])
				_q.kit.need(problems, _over[player] > 0 and _clear[player] >= clearance - RISE_SLACK, "%s: its model came to %.3f m over the panel's top in %d ticks over it (rise clearance %.3f)" % [label, _clear[player], _over[player], clearance])
				_q.kit.need(problems, _slowest[player] >= SPEED_SHARE * stats.max_speed, "%s slowed to %.2f m/s over the panel" % [label, _slowest[player]])
				_q.kit.need(problems, finished[player], "%s did not get %.0f m past the far face" % [label, PAST])
				crossings += 1
				least = minf(least, _clear[player])
				slowest = minf(slowest, _slowest[player])
			notes.append("%s %s %.2f m over for %d ticks" % [Kit18.RUN_NAMES[run], "in" if outside else "out", _clear[0], _over[0]])
	measured.append("gyro_crossings=%d rise_min=%.3f speed_min=%.2f" % [crossings, least, slowest])
	_q.kit.verdict("gyro_over", problems, "%d crossings at full throttle, one Gyrocopter of each Player over a panel of each of the five runs of its own Base, from outside into the yard and from the yard out again: no wall contact, its model's lowest point at least %.3f m over the 2 m top at the least (rise clearance %.2f m), never under %.2f m/s (top %.1f) while over the panel, %.0f m past the far face (Player 1: %s)" % [
		crossings, least, clearance, slowest, stats.max_speed, PAST, ", ".join(notes)])


## Logs both Gyrocopters after a tick (the map kit's log), and for each the ticks its model's footprint covers the
## panel of its lane, the least height of its lowest point over that panel's top, and its slowest real speed then.
func _cross_tick() -> void:
	_q.map.log_tick()
	for player: int in Kit.PLAYERS:
		var box: AABB = Quick.model_box(_q.units.units[player])
		var mesh: MeshInstance3D = _lane[player].get_node("Mesh") as MeshInstance3D
		var panel_box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.position.x < panel_box.end.x and box.end.x > panel_box.position.x and box.position.z < panel_box.end.z and box.end.z > panel_box.position.z:
			_over[player] += 1
			_clear[player] = minf(_clear[player], box.position.y - panel_box.end.y)
			_slowest[player] = minf(_slowest[player], _q.map.real_speed(player, -1))


## stopped_by (AC-2): Player 1's Gyrocopter is flown at full throttle at a corner tower of its own Base's back wall
## (along the side wall's axis, outside it), at the Garage's back wall from the yard and at the water tower's
## Gate-side leg, each a body on the Map layer, which its collider's mask has: each stops it, with a wall contact,
## short of its face.
func _stopped_by() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var half: float = _q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	var cases: Array = [
		["a corner tower", Vector3(TOWER_FACE_X - Kit18.RUN - half, 0.0, TOWER_Z), Vector3.RIGHT, Vector3.RIGHT, TOWER_FACE_X],
		["the Garage's back wall", Vector3(-2.0, 0.0, GARAGE_BACK_FACE - Kit18.RUN - half), Vector3.BACK, Vector3.BACK, GARAGE_BACK_FACE],
		["the Gate-side leg", Vector3(-2.0, 0.0, LEG_FACE_Z - Kit18.RUN - half), Vector3.BACK, Vector3.BACK, LEG_FACE_Z]]
	for entry: Array in cases:
		var start: Vector3 = _k.m.w.point(0, entry[1])
		var facing: Vector3 = _k.m.w.way(0, entry[2])
		await _q.map.stage([Quick.GYROCOPTER, -1], [start, Vector3.ZERO], [facing, Vector3.ZERO], true)
		_q.map.clear_log()
		_q.kit.on_tick = _q.map.log_tick
		for _tick: int in RUN_LIMIT_TICKS / 2:
			_q.harness.drive(0, 1, 0)
			await _q.kit.tick()
		_q.kit.on_tick = Callable()
		_q.harness.release_all()
		var local: Vector3 = _k.m.w.bases[0].to_local(_q.units.units[0].global_position)
		var reached: float = local.x if entry[2] == Vector3.RIGHT else local.z
		_q.kit.need(problems, _q.map.contacts[0] > 0 and reached <= float(entry[4]) - half + FACE_SLACK, "flown at %s, the Gyrocopter had %d wall contacts and ended at local %.2f (the face is at %.2f)" % [entry[0], _q.map.contacts[0], reached, float(entry[4])])
		notes.append("%s: %d contacts, stopped at %.2f short of its face at %.2f" % [entry[0], _q.map.contacts[0], reached, float(entry[4])])
	_q.kit.verdict("stopped_by", problems, "flown at full throttle for %d s, the Gyrocopter is still stopped by a corner tower, the Garage's back wall and a water tower leg, which stand on the Map layer: %s" % [RUN_LIMIT_TICKS / 120, "; ".join(notes)])
