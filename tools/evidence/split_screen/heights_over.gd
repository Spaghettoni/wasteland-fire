extends RefCounted
## What the Gyrocopter flies over, and through, for the heights scenario (Story 020 AC-2, AC-4, AC-5): cross_low (seven flights of
## Player 1's Gyrocopter at full throttle, each judged against the drawn box of every low piece under its model: a Base's
## axis from outside its Gate over its Flag Walls, between the water tower's legs and under its tank, over the Garage's
## back wall and the Base's back wall; a field wall standing and with its lane panel fallen, over the rubble; a
## container; a wreck; the ridges and the water channels; the canyon's two walls up to the sea edge, which stops it) and
## passes_through (a Gyrocopter flown through a standing Motorbike, Buggy and Truck, and head-on through a Gyrocopter).
## Run by heights.gd. Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The share of its top speed a Gyrocopter has reached in a flight, and the most its speed may fall between two ticks
## while its model is over a piece (m/s).
const TOP_SPEED_SHARE: float = 0.99
const SPEED_DROP: float = 0.05
## The Base-local places of the flight along a Base's axis: out in front of its Gate and where it is over (past the back wall).
const AXIS_START: Vector3 = Vector3(0.0, 0.0, -25.0)
const AXIS_END_Z: float = 19.0
## The field wall's lane (world z, through the middle of its third panel) and the container's, the wreck's, the ridges' and
## the canyon's lanes: [start, direction, x or z where the flight is over].
const FIELD_LANE: Array = [Vector3(-28.0, 0.0, 13.5), Vector3.RIGHT, -4.0]
const CONTAINER_LANE: Array = [Vector3(-58.0, 0.0, -17.0), Vector3.BACK, 8.0]
const WRECK_LANE: Array = [Vector3(-80.0, 0.0, -13.0), Vector3.BACK, 16.0]
const RIDGES_LANE: Array = [Vector3(-80.0, 0.0, 30.0), Vector3.RIGHT, 70.0]
const CANYON_LANE: Array = [Vector3(-15.0, 0.0, -4.0), Vector3.FORWARD, -60.0]
## Where a Gyrocopter is flown through a standing ground Unit: the flat west of the ford (Quick.LANE_SPOT's row), the Gyrocopter
## from 25 m before the Unit and over where it is 20 m past it.
const THROUGH_Z: float = -12.0
const THROUGH_START_X: float = -95.0
const THROUGH_UNIT_X: float = -70.0
const THROUGH_END_X: float = -50.0
const HEAD_ON_OTHER_X: float = -45.0
## The ticks of full throttle held against the sea edge after the first touch, the travel they may add (m) and how far from flush
## against its face the Gyrocopter may stand (m).
const STOP_TICKS: int = 12
const STOP_MOVE: float = 0.05
const FLUSH_SLACK: float = 0.15
## The ticks a flight may take.
const LIMIT: int = 420
const LONG_LIMIT: int = 700

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick
## The low pieces: {kind, path, box (drawn), top}.
var _lows: Array[Dictionary] = []


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.k.turrets_down()
	for row: Dictionary in _k.solid_rows(_k.map()):
		var index: int = _k.family_of(row["path"])
		if index >= 0 and Kit20.FAMILIES[index][3] == "low" and row["drawn"] != null:
			_lows.append({"kind": Kit20.FAMILIES[index][0], "path": row["path"], "box": row["drawn"], "top": row["drawn_top"]})
	await _cross_low()
	await _passes_through()


## Judges one flight against the pieces `lows` (up to the tick `upto`, exclusive): returns {kinds: kind -> {paths, ticks,
## clear}, drop: the biggest fall of the speed between two ticks while over a piece, fastest} and adds the problems of a
## flight: a wall contact before `upto`, a model within the clearance of a piece's top, a speed lost, a kind not crossed.
func _judge(label: String, rec: Dictionary, upto: int, lows: Array[Dictionary], expect: Dictionary, problems: PackedStringArray) -> Dictionary:
	var kinds: Dictionary = {}
	var drop: float = 0.0
	var fastest: float = 0.0
	var speeds: PackedFloat64Array = rec["speeds"]
	for tick: int in upto:
		var box: AABB = rec["boxes"][tick]
		fastest = maxf(fastest, speeds[tick])
		var over: bool = false
		for piece: Dictionary in lows:
			if Kit20.overlap_plan(box, piece["box"]):
				over = true
				var entry: Dictionary = kinds.get(piece["kind"], {"paths": {}, "ticks": 0, "clear": INF})
				entry["paths"][piece["path"]] = true
				entry["ticks"] += 1
				entry["clear"] = minf(entry["clear"], box.position.y - float(piece["top"]))
				kinds[piece["kind"]] = entry
		if over and tick > 0:
			drop = maxf(drop, speeds[tick - 1] - speeds[tick])
	var top_speed: float = _q.units.stats(Kit20.GYRO).max_speed
	_q.kit.need(problems, not (rec["touches"] as Array).slice(0, upto).has(true), "%s: the Gyrocopter touched a wall before the end of the crossing" % label)
	_q.kit.need(problems, fastest >= TOP_SPEED_SHARE * top_speed, "%s: reached only %.2f m/s of %.1f" % [label, fastest, top_speed])
	_q.kit.need(problems, drop <= SPEED_DROP, "%s: its speed fell %.3f m/s between two ticks over a piece" % [label, drop])
	for kind: String in expect:
		var seen: int = (kinds[kind]["paths"] as Dictionary).size() if kinds.has(kind) else 0
		_q.kit.need(problems, seen >= int(expect[kind]), "%s: flew over %d %s, expected %d" % [label, seen, kind, expect[kind]])
	for kind: String in kinds:
		_q.kit.need(problems, kinds[kind]["clear"] >= Kit20.CLEARANCE, "%s: its model came %.3f m over a %s, under the %.2f m clearance" % [label, kinds[kind]["clear"], kind, Kit20.CLEARANCE])
	return {"kinds": kinds, "drop": drop, "fastest": fastest}


## "3 Flag Wall (2 pieces, 0.500 m)" for each kind a flight crossed.
func _kinds_text(result: Dictionary) -> String:
	var parts: PackedStringArray = []
	for kind: String in result["kinds"]:
		parts.append("%d %s (%.3f m over)" % [(result["kinds"][kind]["paths"] as Dictionary).size(), kind, result["kinds"][kind]["clear"]])
	return ", ".join(parts)


## One flight of Player 1's Gyrocopter from `start` along `dir` until `stop`: judged, and the note returned.
func _flight(label: String, start: Vector3, dir: Vector3, stop: Callable, expect: Dictionary, problems: PackedStringArray, limit: int = LIMIT, lows: Array[Dictionary] = _lows) -> Dictionary:
	var rec: Dictionary = await _k.fly(0, Kit20.GYRO, start, dir, limit, stop)
	var result: Dictionary = _judge(label, rec, rec["boxes"].size(), lows, expect, problems)
	result["record"] = rec
	return result


## cross_low (AC-2, AC-4, AC-5).
func _cross_low() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var walls: Object = _k.k.k.m.w
	var base: Base = walls.bases[0]
	var least: float = INF
	var start: Vector3 = walls.point(0, AXIS_START)
	var axis: Vector3 = walls.way(0, Vector3.BACK)
	_q.kit.need(problems, _k.lane_free(start, walls.point(0, Vector3(0.0, 0.0, AXIS_END_Z)), 0.8), "the Base's axis lane is not free of map-layer bodies")
	var done_axis: Callable = func(u: Unit) -> bool: return base.to_local(u.global_position).z >= AXIS_END_Z
	var axis_result: Dictionary = await _flight("the Base's axis", start, axis, done_axis, {"Flag Wall": 2, "Garage panel": 1, "Base wall panel": 1}, problems)
	var to_base: Transform3D = base.global_transform.affine_inverse()
	var tank: AABB = to_base * (Kit20.drawn_box(base.get_node("WaterTower/Tank")) as AABB)
	var legs: Array[AABB] = []
	for leg_name: String in ["LegGateLeft", "LegGateRight", "LegGarageLeft", "LegGarageRight"]:
		var shape_node: CollisionShape3D = base.get_node("WaterTower/%s/CollisionShape3D" % leg_name) as CollisionShape3D
		legs.append(to_base * (shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb()))
	var under: int = 0
	var between: float = INF
	var blades: float = -INF
	var half: Vector3 = _q.units.stats(Kit20.GYRO).collision_size / 2.0
	for tick: int in axis_result["record"]["boxes"].size():
		var box: AABB = to_base * (axis_result["record"]["boxes"][tick] as AABB)
		var local_place: Vector3 = to_base * (axis_result["record"]["places"][tick] as Vector3)
		var body: AABB = AABB(local_place - Vector3(half.x, 0.0, half.z), Vector3(half.x * 2.0, half.y * 2.0, half.z * 2.0))
		if Kit20.overlap_plan(box, tank):
			under += 1
			_q.kit.need(problems, box.end.y < tank.position.y, "the model (top %.3f m) is not under the tank (bottom %.3f m)" % [box.end.y, tank.position.y])
		for leg_box: AABB in legs:
			if body.position.z < leg_box.end.z and body.end.z > leg_box.position.z:
				between = minf(between, maxf(leg_box.position.x - body.end.x, body.position.x - leg_box.end.x))
			if box.position.z < leg_box.end.z and box.end.z > leg_box.position.z:
				blades = maxf(blades, minf(box.end.x - leg_box.position.x, leg_box.end.x - box.position.x))
	_q.kit.need(problems, under > 0 and between > 0.0, "the flight was under the tank on %d ticks and its body came %.3f m from a leg" % [under, between])
	notes.append("the Base's axis (%s; under the tank for %d ticks, its body %.3f m from the legs, its drawn rotor blades reaching %.3f m into them)" % [_kinds_text(axis_result), under, between, maxf(blades, 0.0)])
	var field_start: Vector3 = FIELD_LANE[0]
	var field_done: Callable = func(u: Unit) -> bool: return u.global_position.x >= float(FIELD_LANE[2])
	var field_result: Dictionary = await _flight("a field wall", field_start, FIELD_LANE[1], field_done, {"field panel": 1}, problems)
	notes.append("a field wall (%s)" % _kinds_text(field_result))
	var lane_panel: Structure = _k.k.panel(0, Kit20.Kit19.WEST, Kit20.Kit19.LANE[Kit20.Kit19.WEST])
	lane_panel.destroy()
	var fallen: Array[Dictionary] = []
	for piece: Dictionary in _lows:
		fallen.append(piece if piece["path"] != str(_k.map().get_path_to(lane_panel)) else {"kind": "fallen panel", "path": piece["path"], "box": piece["box"], "top": Kit20.drawn_top(lane_panel)})
	var rubble: Dictionary = await _flight("over rubble", field_start, FIELD_LANE[1], field_done, {"fallen panel": 1}, problems, LIMIT, fallen)
	_q.kit.need(problems, not lane_panel.is_standing, "the lane panel is still standing")
	notes.append("over the rubble of a fallen panel (%s)" % _kinds_text(rubble))
	lane_panel.restore()
	for lane: Array in [["a container", CONTAINER_LANE, {"container": 1}, "z"], ["a wreck", WRECK_LANE, {"wreck": 1}, "z"]]:
		var from: Vector3 = lane[1][0]
		var over_z: float = float(lane[1][2])
		var result: Dictionary = await _flight(lane[0], from, lane[1][1], func(u: Unit) -> bool: return u.global_position.z >= over_z, lane[2], problems)
		notes.append("%s (%s)" % [lane[0], _kinds_text(result)])
	var ridge_end: float = float(RIDGES_LANE[2])
	var ridges: Dictionary = await _flight("the ridges and channels", RIDGES_LANE[0], RIDGES_LANE[1], func(u: Unit) -> bool: return u.global_position.x >= ridge_end, {"cliff": 3, "water channel": 2}, problems, LONG_LIMIT)
	notes.append("the ridges and the water (%s)" % _kinds_text(ridges))
	var canyon_rec: Dictionary = await _k.fly(0, Kit20.GYRO, CANYON_LANE[0], CANYON_LANE[1], LIMIT, func(u: Unit) -> bool: return _q.map.wall_contact(u))
	var touch_at: int = (canyon_rec["touches"] as Array).find(true)
	var canyon: Dictionary = _judge("the canyon", canyon_rec, touch_at if touch_at >= 0 else canyon_rec["boxes"].size(), _lows, {"cliff": 2}, problems)
	var unit: Unit = _q.units.units[0]
	var contact_z: float = unit.global_position.z
	for _tick: int in STOP_TICKS:
		_q.harness.drive(0, 1, 0)
		await _q.kit.tick()
	_q.harness.release_all()
	var face_z: float = -INF
	for row: Dictionary in _k.solid_rows(_k.map()):
		var shore: Variant = row["shape_box"]
		if _k.family_of(row["path"]) >= 0 and Kit20.FAMILIES[_k.family_of(row["path"])][0] == "sea edge" and shore != null and (shore as AABB).end.z < 0.0 and (shore as AABB).position.x < contact_z + 1000.0 and (shore as AABB).position.x <= unit.global_position.x and (shore as AABB).end.x >= unit.global_position.x:
			face_z = (shore as AABB).end.z
	var moved: float = absf(unit.global_position.z - contact_z)
	var flush: float = absf(contact_z - (face_z + _q.units.stats(Kit20.GYRO).collision_size.z / 2.0))
	_q.kit.need(problems, touch_at >= 0 and moved <= STOP_MOVE and flush <= FLUSH_SLACK, "the canyon flight ended with a touch at tick %d, %.3f m of further travel in %d ticks of full throttle, %.3f m from flush against the sea edge at z %.2f" % [touch_at, moved, STOP_TICKS, flush, face_z])
	notes.append("the canyon's two walls to the sea edge, where it stopped flush (%.3f m off, %.3f m of travel in %d more ticks of throttle) (%s)" % [flush, moved, STOP_TICKS, _kinds_text(canyon)])
	for result: Dictionary in [axis_result, field_result, rubble, ridges, canyon]:
		for kind: String in result["kinds"]:
			least = minf(least, result["kinds"][kind]["clear"])
	measured.append("cross_low=7 least_clear=%.3f" % least)
	_q.kit.verdict("cross_low", problems, "seven flights of Player 1's Gyrocopter at full throttle, each judged on every tick against the drawn box of every low piece under its model: no wall contact, its speed never falling over a piece, the top speed reached, its model at least %.3f m over the top of every piece it was over (the clearance is %.2f m): %s" % [least, Kit20.CLEARANCE, "; ".join(notes)])


## passes_through (AC-5): a Gyrocopter flown at full throttle through the middle of a standing Motorbike, Buggy and Truck passes through it with no
## contact and no loss of speed, its model over the Unit's body by the clearance (the Truck's pod 0.2955 m, the whip antenna drawn into its
## gear); two Gyrocopters flown head-on at each other pass through each other, their drawn models overlapping while they pass.
func _passes_through() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var start: Vector3 = Vector3(THROUGH_START_X, 0.0, THROUGH_Z)
	var end_x: float = THROUGH_END_X
	var done: Callable = func(u: Unit) -> bool: return u.global_position.x >= end_x
	for ground: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		await _q.map.stage([Kit20.GYRO, ground], [start, Vector3(THROUGH_UNIT_X, 0.0, THROUGH_Z)], [Vector3.RIGHT, Vector3.LEFT], true)
		var other: Unit = _q.units.units[1]
		var parked: Vector3 = other.global_position
		var rec: Dictionary = await _k.run_staged(0, LIMIT, done)
		var label: String = "through a %s" % _q.units.stats(ground).type_id
		var tops: Dictionary = _k.ground_tops(ground)
		var nearest: float = INF
		for place: Vector3 in rec["places"]:
			nearest = minf(nearest, Vector2(place.x - parked.x, place.z - parked.z).length())
		var low: float = INF
		var over: int = 0
		for box: AABB in rec["boxes"]:
			if absf((box.position.x + box.end.x) / 2.0 - parked.x) < 3.0:
				low = minf(low, box.position.y)
				over += 1
		var judged: Dictionary = _judge(label, rec, rec["boxes"].size(), [], {}, problems)
		_q.kit.need(problems, nearest <= 0.5 and other.global_position.distance_to(parked) <= Kit20.TOLERANCE and rec["contacts"] == 0, "%s: closest %.3f m, the Unit moved %.4f m, %d contacts" % [label, nearest, other.global_position.distance_to(parked), rec["contacts"]])
		_q.kit.need(problems, low - float(tops["body"]) >= Kit20.CLEARANCE, "%s: the model came %.3f m over the body (top %.4f m)" % [label, low - float(tops["body"]), tops["body"]])
		var thin_into: float = maxf(0.0, float(tops["all"]) - low)
		notes.append("a %s: closest %.2f m, %.3f m over its body%s" % [_q.units.stats(ground).type_id, nearest, low - float(tops["body"]), ", its thin part drawn %.3f m into the gear" % thin_into if thin_into > 0.0 else ""])
		_q.kit.need(problems, judged["fastest"] > 0.0, "%s: no speed" % label)
	await _q.map.stage([Kit20.GYRO, Kit20.GYRO], [start, Vector3(HEAD_ON_OTHER_X, 0.0, THROUGH_Z)], [Vector3.RIGHT, Vector3.LEFT], true)
	var head_rec: Dictionary = await _k.run_staged(0, LIMIT, func(u: Unit) -> bool: return u.global_position.x >= end_x, 1)
	var overlapped: int = 0
	var inside: float = 0.0
	for tick: int in head_rec["boxes"].size():
		var a: AABB = head_rec["boxes"][tick]
		var b: AABB = head_rec["boxes2"][tick]
		if a.intersects(b):
			overlapped += 1
			var common: AABB = a.intersection(b)
			inside = maxf(inside, common.size.x * common.size.y * common.size.z)
	var other_speed: float = 0.0
	for speed: float in _q.map.speeds[1]:
		other_speed = maxf(other_speed, speed)
	_q.kit.need(problems, overlapped > 0 and head_rec["contacts"] == 0 and _q.map.contacts[1] == 0, "the Gyrocopters' models overlapped on %d ticks, with %d and %d wall contacts" % [overlapped, head_rec["contacts"], _q.map.contacts[1]])
	_q.kit.need(problems, other_speed >= TOP_SPEED_SHARE * _q.units.stats(Kit20.GYRO).max_speed, "the second Gyrocopter reached only %.2f m/s" % other_speed)
	_judge("head-on", head_rec, head_rec["boxes"].size(), [], {}, problems)
	notes.append("two Gyrocopters head-on: their drawn models overlapped on %d ticks (up to %.2f m3), no contact, both at %.1f m/s" % [overlapped, inside, other_speed])
	measured.append("passes_through=4 head_on_ticks=%d" % overlapped)
	_q.kit.verdict("passes_through", problems, "%s" % "; ".join(notes))
