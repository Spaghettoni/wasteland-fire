extends RefCounted
## What a fallen Wall Panel lets through, for the base_walls scenario (Story 018 AC-4): layer_timing (the Measure
## first of Story 012 again, for a panel, and for the Mines' open-ground probe: when a panel that falls or is
## restored starts to answer a ray and a shape query, and when it frees or holds a Motorbike pressed against it)
## and breach (a Motorbike, a Buggy and a Truck through the breach of one panel of each of the five runs, from
## outside and from the yard, touching nothing, the neighbours standing and still blocking a ray; a Shot flies
## through). Run by base_walls.gd. Tooling only. Every number comes from the game's data; the scenario types only
## its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The ticks a run may take, the metres past the far face where a crossing is over, and the tolerance of a place,
## metres.
const RUN_LIMIT_TICKS: int = 420
const PAST: float = 6.0
const TOLERANCE: float = 0.01
## A Unit has moved when it has come this far, metres.
const MOVED: float = 0.01
## How far a Motorbike pressed against a face stands from it, metres, so that its box does not touch (0.3 m).
const PRESSED: float = 0.3
## How far in or out of a run's faces a ray along a panel's middle runs, metres.
const RAY_REACH: float = 4.0
## A Shot fired through a breach must end this far inside the yard face (or outside the outer face), metres.
const THROUGH: float = 1.0

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _layer_timing()
	await _breach()


## A shot-mask ray along a run's outward axis through panel `index` of a Base's run at the shooting height, from
## outside to inside the yard: true while that panel stops it.
func _ray(base_index: int, run: int, index: int) -> bool:
	var height: Vector3 = Vector3.UP * _q.controller.rules.shooting_height
	return _k.blocked(_k.spot(base_index, run, index, Kit18.OUTER_FACES[run] + RAY_REACH) + height, _k.spot(base_index, run, index, Kit18.INNER_FACES[run] - RAY_REACH) + height)


## layer_timing (AC-4; Story 012's Measure first for a panel): a shot-mask ray and the Mines' open-ground probe at a
## panel of Base B's back wall, in the tick the panel is destroyed or restored and the next; and a Motorbike driven
## at the panel, pressed against its face when it falls and approaching at speed when it is restored. The ticks are
## the measurement; the verdict is that a fallen panel blocks nothing from the next tick at the latest and a
## restored one blocks from the next tick at the latest.
func _layer_timing() -> void:
	var problems: PackedStringArray = []
	var run: int = Kit18.BACK
	var index: int = Kit18.LANE[run]
	var target: Structure = _k.panel(1, run, index)
	var layer: MineLayer = _k.m.layers[0]
	var middle: Vector3 = _k.spot(1, run, index, (Kit18.INNER_FACES[run] + Kit18.OUTER_FACES[run]) / 2.0)
	_q.kit.need(problems, _ray(1, run, index) and not layer.is_open_ground(middle), "the standing panel does not block the ray (%s) or the probe reads open ground (%s)" % [_ray(1, run, index), layer.is_open_ground(middle)])
	target.destroy()
	var ray_same: bool = _ray(1, run, index)
	var open_same: bool = layer.is_open_ground(middle)
	await _q.kit.tick()
	var ray_next: bool = _ray(1, run, index)
	var open_next: bool = layer.is_open_ground(middle)
	target.restore()
	var ray_back_same: bool = _ray(1, run, index)
	var open_back_same: bool = layer.is_open_ground(middle)
	await _q.kit.tick()
	var ray_back_next: bool = _ray(1, run, index)
	var open_back_next: bool = layer.is_open_ground(middle)
	_q.kit.need(problems, not ray_next and open_next and ray_back_next and not open_back_next, "the ray sees a fallen panel (next tick: %s) or no restored one (%s); the probe reads a fallen panel as not open (%s) or a restored one as open (%s)" % [ray_next, ray_back_next, not open_next, open_back_next])
	var half: float = _q.units.stats(Quick.MOTORBIKE).collision_size.z / 2.0
	var base: Base = _k.m.w.bases[1]
	var face: float = Kit18.OUTER_FACES[run]
	await _k.stage(0, Quick.MOTORBIKE, _k.spot(1, run, index, face + PRESSED + half), -_k.outward(1, run))
	_q.harness.drive(0, 1, 0)
	await _q.kit.advance(6)
	var start: float = base.to_local(_q.units.units[0].global_position).dot(Kit18.OUTWARD[run])
	target.destroy()
	await _q.kit.tick()
	var first: float = start - base.to_local(_q.units.units[0].global_position).dot(Kit18.OUTWARD[run])
	await _q.kit.tick()
	var second: float = start - base.to_local(_q.units.units[0].global_position).dot(Kit18.OUTWARD[run])
	_q.kit.need(problems, second > MOVED, "a Motorbike pressed against the fallen panel moved %.4f m in its first tick and %.4f by the second: it is still held" % [first, second])
	_q.harness.release_all()
	await _q.kit.advance(Kit18.SETTLE)
	await _k.restore_all()
	target.destroy()
	await _k.stage(0, Quick.MOTORBIKE, _k.spot(1, run, index, _k.start_out(run, half, true)), -_k.outward(1, run))
	_q.harness.drive(0, 1, 0)
	var restored_at: int = -1
	var blocked_after: float = INF
	for count: int in 90:
		await _q.kit.tick()
		var gap: float = base.to_local(_q.units.units[0].global_position).dot(Kit18.OUTWARD[run]) - face - half
		if restored_at < 0 and gap <= _q.units.units[0].current_speed / 60.0 and gap > 0.0:
			target.restore()
			restored_at = count
		elif restored_at >= 0 and count == restored_at + 1:
			blocked_after = gap
		elif restored_at >= 0 and count == restored_at + 3:
			break
	_q.harness.release_all()
	var end_gap: float = base.to_local(_q.units.units[0].global_position).dot(Kit18.OUTWARD[run]) - face - half
	_q.kit.need(problems, restored_at >= 0 and end_gap > -0.1 and end_gap < 0.2, "a Motorbike approaching at speed when the panel was restored ended %.3f m from the face (restored on tick %d)" % [end_gap, restored_at])
	_q.kit.verdict("layer_timing", problems, "a ray on mask %d and the Mines' open-ground probe (mask %d, from %.1f to %.0f m above the point) at a panel of Base B's back wall: standing, the ray is blocked and the probe reads shut; destroyed in the scenario's tick the ray answers %s and the probe %s in that tick and the ray %s and the probe %s a tick later; restored, the ray answers %s and the probe %s in that tick and the ray %s and the probe %s a tick later; a Motorbike pressed against the face when the panel fell moved %.4f m in the next tick and %.4f by the one after (held until the layer went); one approaching at speed when it was restored ended %.3f m from the face" % [
		_q.controller.rules.shot_collision_mask, layer.settings.open_ground_mask, layer.settings.probe_floor, layer.settings.probe_top, "blocked" if ray_same else "clear", "shut" if not open_same else "open", "blocked" if ray_next else "clear", "shut" if not open_next else "open",
		"blocked" if ray_back_same else "clear", "shut" if not open_back_same else "open", "blocked" if ray_back_next else "clear", "shut" if not open_back_next else "open", first, second - first, end_gap])
	measured.append("ray_after_destroy=%s/%s probe_after_destroy=%s/%s ray_after_restore=%s/%s probe_after_restore=%s/%s" % [ray_same, ray_next, open_same, open_next, ray_back_same, ray_back_next, open_back_same, open_back_next])
	await _k.restore_all()


## breach (AC-4): the lane panel of each run of both Bases is brought down, and a ground Unit of each type from each
## Player drives at full throttle through the breach of its own Base, from outside into the yard and from the yard
## out, touching nothing; the neighbours of the fallen panel stand and block a ray through their middles; a Shot
## flies through the breach.
func _breach() -> void:
	var problems: PackedStringArray = []
	var drives: int = 0
	var gate_gap: float = Kit18.LENGTHS[Kit18.GATE_LEFT]
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type_index)
		for run: int in Kit18.RUN_NAMES.size():
			for outside: bool in [true, false]:
				drives += 2
				await _pair(type_index, run, outside, problems)
	var shots: PackedStringArray = []
	for run: int in Kit18.RUN_NAMES.size():
		shots.append(await _shot_through(run, problems))
	_q.kit.need(problems, absf(gate_gap - 2.7833333) <= TOLERANCE and _q.units.stats(Quick.TRUCK).collision_size.x < gate_gap, "the Truck (%.2f m wide) does not fit the Gate-wall breach (%.4f m)" % [_q.units.stats(Quick.TRUCK).collision_size.x, gate_gap])
	measured.append("breach_drives=%d" % drives)
	_q.kit.verdict("breach", problems, "%d drives at full throttle, one of each Player through the breach of the lane panel of each of the five runs of its own Base, a Motorbike, a Buggy and a Truck, from outside into the yard and from the yard out: no wall contact, %.0f m past the far face; the other panels of the run stood and each blocked a ray through its middle; the Truck (%.2f m wide) passes the %.3f m breach of a single Gate-wall panel; a Shot fired from outside at the breach flew through (end past the yard face by at least %.1f m): %s" % [
		drives, PAST, _q.units.stats(Quick.TRUCK).collision_size.x, gate_gap, THROUGH, "; ".join(shots)])
	await _k.restore_all()


## One pair of drives through breaches: both Players' Units of one type through the lane panel of one run of their
## own Base, which is down; the neighbours are tested standing while it is.
func _pair(type_index: int, run: int, outside: bool, problems: PackedStringArray) -> void:
	var stats: UnitStats = _q.units.stats(type_index)
	var half: float = stats.collision_size.z / 2.0
	var lane: int = Kit18.LANE[run]
	var near_face: float = Kit18.OUTER_FACES[run] if outside else Kit18.INNER_FACES[run]
	var far_face: float = Kit18.INNER_FACES[run] if outside else Kit18.OUTER_FACES[run]
	var start: float = _k.start_out(run, half, outside)
	await _k.restore_all()
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		_k.panel(player, run, lane).destroy()
		spots.append(_k.spot(player, run, lane, start))
		facings.append(_k.outward(player, run) * (-1.0 if outside else 1.0))
	await _q.map.stage([type_index, type_index], spots, facings, true)
	for player: int in Kit.PLAYERS:
		var standing: int = 0
		var blocking: int = 0
		for index: int in Kit18.COUNTS[run]:
			if index != lane:
				standing += 1 if _k.panel(player, run, index).is_standing else 0
				blocking += 1 if _ray(player, run, index) else 0
		_q.kit.need(problems, standing == Kit18.COUNTS[run] - 1 and blocking == Kit18.COUNTS[run] - 1 and not _ray(player, run, lane), "%s/%s with its lane panel down: %d standing and %d blocking of %d neighbours, the breach's ray blocked %s" % [_k.m.w.bases[player].name, Kit18.RUN_NAMES[run], standing, blocking, Kit18.COUNTS[run] - 1, _ray(player, run, lane)])
	_q.map.clear_log()
	var done: Array[bool] = [false, false]
	var touched: Array[int] = [0, 0]
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			var unit: Unit = _q.units.units[player]
			var along: float = _k.m.w.bases[player].to_local(unit.global_position).dot(Kit18.OUTWARD[run])
			done[player] = done[player] or (along <= far_face - PAST if outside else along >= far_face + PAST)
			touched[player] += 1 if _q.map.wall_contact(unit) else 0
			_q.harness.drive(player, 0 if done[player] else 1, 0)
		await _q.kit.tick()
		if done[0] and done[1]:
			break
	_q.harness.release_all()
	for player: int in Kit.PLAYERS:
		var label: String = "p%d %s through %s's lane breach from %s" % [player + 1, stats.type_id, Kit18.RUN_NAMES[run], "outside" if outside else "the yard"]
		_q.kit.need(problems, done[player] and touched[player] == 0, "%s: got %.0f m past %s, touched a wall on %d ticks" % [label, PAST, done[player], touched[player]])


## A Shot fired from outside a run's lane breach by Player 1's Buggy at Base B (its panel down) flies through: its
## end lies past the yard face. Returns the note.
func _shot_through(run: int, problems: PackedStringArray) -> String:
	var lane: int = Kit18.LANE[run]
	await _k.restore_all()
	_k.panel(1, run, lane).destroy()
	await _k.stage(0, Quick.BUGGY, _k.spot(1, run, lane, Kit18.OUTER_FACES[run] + 8.0), -_k.outward(1, run))
	await _q.kit.advance(_k.m.w.longest_cadence())
	var end: Vector3 = await _k.m.w.shoot(0)
	var along: float = _k.m.w.bases[1].to_local(end).dot(Kit18.OUTWARD[run])
	_q.kit.need(problems, end != Vector3.INF and along <= Kit18.INNER_FACES[run] - THROUGH, "%s: the Shot through the breach ended at %.2f m from the axis along the run's outward direction, not inside the yard face (%.1f)" % [Kit18.RUN_NAMES[run], along, Kit18.INNER_FACES[run]])
	return "%s ended %.1f m" % [Kit18.RUN_NAMES[run], along]
