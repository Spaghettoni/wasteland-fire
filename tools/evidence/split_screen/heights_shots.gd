extends RefCounted
## Shooting is unchanged by the Heights, and how a Shot from a high gun is drawn, for the heights scenario (Story 020 AC-6 and
## AC-8): shots_hit (a Shot of the Motorbike, the Buggy and the Truck hits the flying Gyrocopter, the Gyrocopter's Shot hits each
## of them and a Turret, and a Turret's Shot hits the Gyrocopter, each for the damage matrix's damage, at the one shooting height
## and ending on the body's box), shots_stopped (a standing Wall Panel and a piece of cover between shooter and target stop the
## Shot both ways, the same Shots go through once the panel has fallen, and a Gyrocopter standing over a container fires into
## it) and tracer (the gaps between each drawn gun and its tracer, recorded). Run by heights.gd. Tooling only. Every number comes
## from the game's data; the scenario types only its test inputs.

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where two Units stand on the flat west of the ford, 18 m apart on one row, and the row's z: the Gyrocopter at the first (facing +x),
## the other at the second (facing -x).
const ROW_Z: float = -12.0
const FIRST_X: float = -88.0
const SECOND_X: float = -70.0
## The field wall's lane (its third panel, z 13.5) with the Units 9 m either side of the wall's middle, and the container's lane (x = -58)
## with the Units 10 m either side of it.
const FIELD_Z: float = 13.5
const FIELD_X: Array[float] = [-28.0, -4.0]
const CONTAINER_X: float = -58.0
const CONTAINER_Z: float = 10.0
## Metres from a Turret the Gyrocopter stands to be shot at and to shoot (within its reach of 35 m), and the ticks the Turret may take to aim and fire.
const TURRET_RANGE: float = 21.0
const AIM_TICKS: int = 300
## The ticks a Shot may take to hit, and a hit's tolerance on the end of the Shot, metres.
const HIT_WAIT_TICKS: int = 60
const END_TOLERANCE: float = 0.1
const SHOT_SCENE: String = "res://src/gameplay/combat/shot.tscn"

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit20
var _q: Quick
var _tracer_half: float = 0.0
var _rows: Array[Dictionary] = []
## The firing Gyrocopter's lowest drawn point, the Shot's height and the Turret barrel's drawn box when each fired: the gaps of tracer.
var _gyro_low: float = INF
var _shot_height: float = INF
var _barrel: AABB = AABB()


func _init(kit: Kit20) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.k.restore_all(false)
	await _k.k.k.turrets_down()
	var shot: Node = (load(SHOT_SCENE) as PackedScene).instantiate()
	_tracer_half = ((shot.get_node("Tracer") as MeshInstance3D).mesh as BoxMesh).size.y / 2.0
	shot.free()
	_rows = _k.solid_rows(_k.map())
	await _shots_hit()
	await _shots_stopped()
	_tracer()
	await _k.k.k.restore_all(true)


## The damage the matrix gives one Shot of a type against a type (the attacker's damage times its multiplier).
func _damage(attacker: UnitStats, target_type: StringName) -> float:
	return attacker.damage * _q.controller.rules.damage_matrix.multiplier(attacker.type_id, target_type)


## The height a recorded Shot flew at: where it ended (a Shot flies horizontally), else where it was first seen; INF when neither was filed.
func _height_of(index: int) -> float:
	if index < 0:
		return INF
	var end: Vector3 = _q.units.shot_ends[index]
	return end.y if end != Vector3.INF else (_q.units.shot_firsts[index] as Vector3).y


## Fires Player `player`'s Shot with its real key, after the longest cadence has passed since any earlier Shot (a Weapon that fired
## a moment ago does not fire again), and waits two ticks so that the Shot is filed in the record: its index there, or -1.
func _fire(player: int) -> int:
	await _q.kit.advance(_k.k.k.m.w.longest_cadence())
	var before: int = _q.units.shots.size()
	await _q.units.hold_fire(player, 1)
	await _q.kit.advance(2)
	return before if _q.units.shots.size() > before else -1


## Waits at most `limit` ticks for a Unit's or a Structure's hit points to change: the amount lost, or -1.0.
func _lost(read: Callable, limit: int) -> float:
	var before: float = read.call()
	for _tick: int in limit:
		await _q.kit.tick()
		if not is_equal_approx(read.call(), before):
			return before - float(read.call())
	return -1.0


## One Shot between two Units of the row: `shooter` fires and the target (the other) loses the matrix's damage; the Shot flew at the shooting
## height and ended on the target's box (its near face along x). Returns a note.
func _duel(label: String, shooter: int, shooter_type: int, target_type: int, problems: PackedStringArray) -> String:
	var types: Array[int] = [Kit20.GYRO, Kit20.GYRO]
	types[shooter] = shooter_type
	types[1 - shooter] = target_type
	await _q.map.stage(types, [Vector3(FIRST_X, 0.0, ROW_Z), Vector3(SECOND_X, 0.0, ROW_Z)], [Vector3.RIGHT, Vector3.LEFT], true)
	var target: Unit = _q.units.units[1 - shooter]
	var shooter_stats: UnitStats = _q.units.stats(shooter_type)
	var expected: float = _damage(shooter_stats, target.type_id)
	var index: int = await _fire(shooter)
	var lost: float = await _lost(func() -> float: return target.hit_points, HIT_WAIT_TICKS)
	_q.kit.need(problems, index >= 0 and absf(lost - expected) <= Kit20.TOLERANCE, "%s: the target lost %.3f, the matrix gives %.3f" % [label, lost, expected])
	var end: Vector3 = _q.units.shot_ends[index] if index >= 0 else Vector3.INF
	var half: float = _q.units.stats(target_type).collision_size.z / 2.0
	var face: float = target.global_position.x + (half if shooter == 1 else -half)
	var height: float = _q.controller.rules.shooting_height
	_q.kit.need(problems, index >= 0 and absf(_height_of(index) - height) <= Kit20.TOLERANCE, "%s: the Shot flew at %.3f m, not the shooting height %.2f m" % [label, _height_of(index), height])
	_q.kit.need(problems, index >= 0 and absf(end.x - face) <= END_TOLERANCE, "%s: the Shot ended at x %.3f, the target's face is at %.3f" % [label, end.x, face])
	return "%s %.1f" % [label, lost]


## shots_hit (AC-6).
func _shots_hit() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for ground: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var name: String = String(_q.units.stats(ground).type_id)
		notes.append(await _duel("%s hits the Gyrocopter" % name, 1, ground, Kit20.GYRO, problems))
	for ground: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var name: String = String(_q.units.stats(ground).type_id)
		notes.append(await _duel("the Gyrocopter hits the %s" % name, 0, Kit20.GYRO, ground, problems))
	var turret: Turret = _k.k.k.turret(1, 0)
	var other: Turret = _k.k.k.turret(1, 1)
	turret.restore()
	var turret_stats: TurretStats = turret.stats as TurretStats
	var spot: Vector3 = Vector3(turret.global_position.x - TURRET_RANGE, 0.0, turret.global_position.z)
	var fired_before: int = _k.k.k.fired.size()
	await _q.map.stage([Kit20.GYRO, -1], [spot, Vector3.ZERO], [Vector3.RIGHT, Vector3.ZERO], true)
	var gyro: Unit = _q.units.units[0]
	var gyro_stats: UnitStats = _q.units.stats(Kit20.GYRO)
	var lost: float = await _lost(func() -> float: return gyro.hit_points, AIM_TICKS)
	await _q.kit.advance(2)
	var expected: float = turret_stats.damage * _q.controller.rules.damage_matrix.multiplier(turret_stats.type_id, gyro_stats.type_id)
	var record: Dictionary = _k.k.k.fired[fired_before] if _k.k.k.fired.size() > fired_before else {}
	var turret_end: Vector3 = record.get("end", Vector3.INF)
	_q.kit.need(problems, not record.is_empty() and absf(lost - expected) <= Kit20.TOLERANCE, "the Turret's Shot took %.3f off the Gyrocopter, the matrix gives %.3f" % [lost, expected])
	_q.kit.need(problems, absf(turret_end.y - _q.controller.rules.shooting_height) <= Kit20.TOLERANCE, "the Turret's Shot ended at %.3f m" % turret_end.y)
	notes.append("the Turret hits the Gyrocopter %.1f" % lost)
	var hp_before: float = turret.hit_points
	_barrel = Kit20.drawn_box(turret.get_node("Look/Head/Barrel")) as AABB
	_gyro_low = Quick.model_bottom(gyro)
	var index: int = await _fire(0)
	var turret_lost: float = await _lost(func() -> float: return turret.hit_points, HIT_WAIT_TICKS)
	await _q.kit.advance(2)
	_shot_height = _height_of(index)
	var turret_expected: float = gyro_stats.damage * _q.controller.rules.damage_matrix.multiplier(gyro_stats.type_id, turret.type_id)
	_q.kit.need(problems, index >= 0 and absf(turret_lost - turret_expected) <= Kit20.TOLERANCE, "the Gyrocopter's Shot took %.3f off the Turret (from %.1f), the matrix gives %.3f" % [turret_lost, hp_before, turret_expected])
	notes.append("the Gyrocopter hits the Turret %.1f" % turret_lost)
	turret.destroy()
	measured.append("shots_hit=8")
	_q.kit.verdict("shots_hit", problems, "every Shot still flies at the one shooting height (%.1f m) and ends on its target's box, with the Gyrocopter's model drawn %.2f m above it, for the damage matrix's damage (the attacker's damage times its multiplier): %s" % [_q.controller.rules.shooting_height, _k.height - _q.controller.rules.shooting_height, "; ".join(notes)])


## The collision box of a piece by its path from the Map.
func _box(path: String) -> AABB:
	for row: Dictionary in _rows:
		if row["path"] == path:
			return row["shape_box"]
	return AABB()


## Fires `shooter`'s Shot, waits for it to land and judges that `target` lost nothing and that the Shot ended on the face at `face` (along
## `axis`, x or z); with `through` the target loses the matrix's damage instead. Returns a note.
func _across(label: String, shooter: int, face: float, axis: String, through: bool, problems: PackedStringArray) -> String:
	var target: Unit = _q.units.units[1 - shooter]
	var shooter_stats: UnitStats = _q.units.units[shooter].stats
	var before: float = target.hit_points
	var index: int = await _fire(shooter)
	await _q.kit.advance(HIT_WAIT_TICKS)
	var lost: float = before - target.hit_points
	var end: Vector3 = _q.units.shot_ends[index] if index >= 0 else Vector3.INF
	var expected: float = _damage(shooter_stats, target.type_id) if through else 0.0
	_q.kit.need(problems, index >= 0 and absf(lost - expected) <= Kit20.TOLERANCE, "%s: the target lost %.3f, expected %.3f" % [label, lost, expected])
	if not through:
		var got: float = end.x if axis == "x" else end.z
		_q.kit.need(problems, absf(got - face) <= END_TOLERANCE, "%s: the Shot ended at %s %.3f, the face is at %.3f" % [label, axis, got, face])
	return "%s: %s" % [label, "took %.1f" % lost if through else "ended on the face at %.2f, nothing lost" % (end.x if axis == "x" else end.z)]


## shots_stopped (AC-6): a standing Wall Panel and a piece of cover between shooter and target stop the Shot both ways (the Shot ends on the
## near face, the target loses nothing); with the panel fallen the same two Shots hit; a Gyrocopter standing over the middle of a container
## fires into it, its Shot ending at its muzzle, inside the piece.
func _shots_stopped() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var lane_panel: Structure = _k.k.panel(0, Kit20.Kit19.WEST, Kit20.Kit19.LANE[Kit20.Kit19.WEST])
	lane_panel.restore()
	var wall: AABB = _k.k.extent(0, Kit20.Kit19.WEST, lane_panel)
	var field_stage: Callable = func() -> void: await _q.map.stage([Kit20.GYRO, Quick.BUGGY], [Vector3(FIELD_X[0], 0.0, FIELD_Z), Vector3(FIELD_X[1], 0.0, FIELD_Z)], [Vector3.RIGHT, Vector3.LEFT], true)
	await field_stage.call()
	notes.append(await _across("a Wall Panel, the Buggy at the Gyrocopter", 1, wall.end.x, "x", false, problems))
	notes.append(await _across("a Wall Panel, the Gyrocopter at the Buggy", 0, wall.position.x, "x", false, problems))
	lane_panel.destroy()
	await field_stage.call()
	notes.append(await _across("the panel fallen, the Buggy at the Gyrocopter", 1, 0.0, "x", true, problems))
	notes.append(await _across("the panel fallen, the Gyrocopter at the Buggy", 0, 0.0, "x", true, problems))
	lane_panel.restore()
	var container: AABB = _box("Cover/Containers/ContainerWest")
	await _q.map.stage([Kit20.GYRO, Quick.BUGGY], [Vector3(CONTAINER_X, 0.0, -CONTAINER_Z), Vector3(CONTAINER_X, 0.0, CONTAINER_Z)], [Vector3.BACK, Vector3.FORWARD], true)
	notes.append(await _across("a container, the Buggy at the Gyrocopter", 1, container.end.z, "z", false, problems))
	notes.append(await _across("a container, the Gyrocopter at the Buggy", 0, container.position.z, "z", false, problems))
	await _q.map.stage([Kit20.GYRO, -1], [Vector3(CONTAINER_X, 0.0, 0.0), Vector3.ZERO], [Vector3.RIGHT, Vector3.ZERO], true)
	var gyro: Unit = _q.units.units[0]
	var index: int = await _fire(0)
	await _q.kit.advance(2)
	var end: Vector3 = _q.units.shot_ends[index] if index >= 0 else Vector3.INF
	var muzzle: float = gyro.global_position.x + gyro.stats.muzzle_forward
	_q.kit.need(problems, index >= 0 and container.has_point(end) and absf(end.x - muzzle) <= END_TOLERANCE, "the Gyrocopter over the container: its Shot ended at %s, the muzzle is at x %.3f, the container's box is %s" % [end, muzzle, container])
	notes.append("a Gyrocopter over the middle of a container: its Shot ended at x %.2f, its muzzle (inside the piece)" % end.x)
	measured.append("shots_stopped=7")
	_q.kit.verdict("shots_stopped", problems, "%s" % "; ".join(notes))


## tracer (AC-8): recorded, not changed. Every Shot flew at the shooting height and its hit test stayed there; the flying Gyrocopter's lowest
## drawn point stands that far over its tracer, and the raised Turret's drawn barrel this far over its own.
func _tracer() -> void:
	var problems: PackedStringArray = []
	var height: float = _q.controller.rules.shooting_height
	_q.kit.need(problems, absf(_shot_height - height) <= Kit20.TOLERANCE, "the Gyrocopter's Shot flew at %.3f m, not %.2f" % [_shot_height, height])
	var top: float = height + _tracer_half
	_q.kit.need(problems, _barrel.has_surface() and _gyro_low < INF, "no gap was recorded")
	measured.append("tracer_gyro=%.3f tracer_barrel=%.3f" % [_gyro_low - height, _barrel.position.y - height])
	_q.kit.verdict("tracer", problems, "a Shot from a high gun is drawn at the shooting height (%.2f m, the tracer %.2f to %.2f m) and decided there: the flying Gyrocopter's lowest drawn point (%.3f m) stands %.3f m over the tracer's line and %.3f m over its top; the raised Turret's drawn barrel (%.3f to %.3f m, centre %.3f m) stands %.3f m over the line at its bottom, %.3f m at its middle and %.3f m over the tracer's top" % [
		height, height - _tracer_half, top, _gyro_low, _gyro_low - height, _gyro_low - top, _barrel.position.y, _barrel.end.y, _barrel.get_center().y, _barrel.position.y - height, _barrel.get_center().y - height, _barrel.position.y - top])
