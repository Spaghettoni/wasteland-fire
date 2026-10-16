extends RefCounted
## What the turning parts leave alone, for the rotors scenario (Story 025 AC-5): destroy (a Gyrocopter destroyed in the air by its own
## Self-destruct key explodes where its model stood, exactly where the model of the story before did: the Unit's place raised by the
## model's hover and the box's collision centre, never by what the turning meshes or the smears draw; and a badly damaged Gyrocopter's
## smoke stands at the top centre of the hull of the mesh file below its rotor, the place it had, whatever turns under it). Run by
## rotors.gd. Tooling only. Every number comes from the game's data and files; the scenario types only its test inputs.

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## Where each Player's Gyrocopter is staged: the open middle of the Map, 30 m either side of its middle.
const OPEN: Vector3 = Vector3(-30.0, 0.0, -16.0)
## The share of its hit points a smoking Gyrocopter has left (the badly damaged state is at 20%), and the ticks the smoke is given.
const HURT_SHARE: float = 0.15
const SMOKE_TICKS: int = 20
## What a place may differ from the one the data gives by, metres (a single-precision float's worth).
const PLACE_TOLERANCE: float = 0.001

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit25
var _q: Quick


func _init(kit: Kit25) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.walls().turrets_down()
	await _explosions()
	await _smoke()


## destroy (AC-5): see the class doc.
func _explosions() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Kit25.GYRO)
	var model_scene: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	var raise: float = model_scene.hover_height + model_scene.offset.y + stats.collision_center.y
	model_scene.free()
	for player: int in 2:
		var spot: Vector3 = OPEN if player == 0 else Vector3(-OPEN.x, OPEN.y, OPEN.z)
		await _k.k.stage(player, Kit25.GYRO, spot, Vector3.RIGHT if player == 0 else Vector3.LEFT)
		var before: int = _k.k.destroyed.size()
		var blasts_before: int = _k.k.blasts().size()
		await _q.tokens.destruct(player)
		await _q.kit.advance(1)
		_q.kit.need(problems, _k.k.destroyed.size() == before + 1 and _k.k.blasts().size() == blasts_before + 1, "Player %d: %d destructions and %d Explosions after the Self-destruct" % [player + 1, _k.k.destroyed.size() - before, _k.k.blasts().size() - blasts_before])
		if _k.k.destroyed.size() != before + 1 or _k.k.blasts().size() != blasts_before + 1:
			continue
		var record: Dictionary = _k.k.destroyed[before]
		var blast: Node3D = _k.k.blasts()[-1] as Node3D
		var where: Vector3 = (record["at"] as Vector3) + Vector3.UP * raise
		_q.kit.need(problems, blast.global_position.distance_to(where) <= PLACE_TOLERANCE, "Player %d: the Explosion's centre %s is %.5f m from the Unit's place raised by the model's hover and the collision centre (%s)" % [player + 1, blast.global_position, blast.global_position.distance_to(where), where])
		_q.kit.need(problems, blast.global_position.distance_to(record["expected"]) <= PLACE_TOLERANCE, "Player %d: the Explosion's centre %s is %.5f m from the model's place raised by the collision centre (%s)" % [player + 1, blast.global_position, blast.global_position.distance_to(record["expected"]), record["expected"]])
		notes.append("Player %d's Explosion at %s, %.3f m up over the Unit's body (the model's hover %.2f and the box's centre %.2f)" % [player + 1, blast.global_position, blast.global_position.y - (record["at"] as Vector3).y, raise - stats.collision_center.y, stats.collision_center.y])
		_q.kit.need(problems, int(record["in_handler"]) == 1, "Player %d: %d Explosions were in the tree inside the handler of the destruction" % [player + 1, record["in_handler"]])
		await _q.tokens.spawn(player, Kit25.GYRO)
	measured.append("explosion_raise=%.3f" % raise)
	_q.kit.verdict("destroy", problems, "a Gyrocopter destroyed in the air by its Self-destruct key explodes at its place raised by %.3f m, the model's hover and the box's collision centre, to the millimetre (%s): the place the explosion had before the model turned, since it is read from the model's own origin, not from what is drawn under it" % [raise, "; ".join(notes)])


## The smoke (AC-5): a badly damaged Gyrocopter's smoke is the model's last child, at the top centre of the hull of the mesh file
## (up to hull_top, under the rotor), where it was, while the rotor and the propeller turn.
func _smoke() -> void:
	var problems: PackedStringArray = []
	var frozen: PackedScene = load(Kit25.FROZEN_FILE_PATH) as PackedScene
	var model_scene: MeshUnitModel = load(Kit25.MODEL_PATH).instantiate() as MeshUnitModel
	var hull: AABB = MeshUnitModel.hull_of(frozen, model_scene.hull_top)
	var lift: float = model_scene.hover_height + model_scene.offset.y
	model_scene.free()
	await _k.k.stage(0, Kit25.GYRO, OPEN, Vector3.RIGHT)
	var unit: Unit = _q.units.units[0]
	unit.apply_damage(unit.hit_points - unit.stats.max_hit_points * HURT_SHARE)
	await _q.kit.advance(SMOKE_TICKS)
	var model: Node3D = _k.model_of(0)
	var smoke: Node3D = model.get_node_or_null("Smoke") as Node3D
	_q.kit.need(problems, unit.is_badly_damaged and smoke != null and smoke.get_parent() == model and model.get_child(model.get_child_count() - 1) == smoke, "the Gyrocopter is badly damaged %s and its smoke is %s" % [unit.is_badly_damaged, smoke])
	var want_local: Vector3 = Vector3(hull.get_center().x, hull.end.y, hull.get_center().z)
	var want: Vector3 = unit.global_transform * (Vector3.UP * lift + want_local)
	if smoke != null:
		_q.kit.need(problems, smoke.position.distance_to(want_local) <= PLACE_TOLERANCE and smoke.global_position.distance_to(want) <= PLACE_TOLERANCE, "the smoke stands at %s (local %s), expected %s (local %s): %.5f m off" % [smoke.global_position, smoke.position, want, want_local, smoke.global_position.distance_to(want)])
	var turning: bool = true
	for pivot: RotorPivot in _k.pivots_of(0):
		turning = turning and pivot.angle > 0.0 and pivot.current_turns_per_second > 0.0
	_q.kit.need(problems, turning and _k.pivots_of(0).size() == 2, "the parts do not turn while the Gyrocopter smokes")
	measured.append("smoke_at=%s" % [smoke.global_position if smoke != null else Vector3.ZERO])
	_q.kit.verdict("smoke", problems, "a badly damaged Gyrocopter's smoke is the model's last child at the top centre of the hull of the mesh file up to hull_top (%s in the file's frame, from the frozen copy's boxes, the same to the bit as the rebuilt file's), %s in the world over the Unit at its flying height, while its rotor and propeller turn" % [want_local, want])
