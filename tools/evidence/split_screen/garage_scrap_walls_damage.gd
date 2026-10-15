extends RefCounted
## What hurts a Garage panel and a field panel and how they look, for the garage_scrap_walls scenario (Story 019 AC-1,
## AC-3 and AC-4): damage (one Shot of each type from each Player at a Garage side panel of the other Player's Base,
## of its own and at a field panel: the other Player's Garage panel and the field panel take the damage times the
## matrix's multiplier from either Player, the own Garage panel takes nothing; the Shots each type needs to bring one
## down, the Motorbike's never, even held for 30 s) and looks (every one of the 28 panels, hurt step by step through the
## strict thresholds of 80% and 35% to its fall: exactly one look at a time, the colliders and layers unchanged, the
## rubble at the end). Run by garage_scrap_walls.gd. Tooling only. Every number comes from the game's data; the
## scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Metres out of a face where a shooter stands: the yard beside a Garage is 7.7 m wide, a field wall has room.
const GARAGE_SHOT_FROM: float = 4.5
const FIELD_SHOT_FROM: float = 8.0
## Shots a Motorbike's long fire is counted over: the ticks it holds the fire key (30 s) and the least number of Shots
## that must have flown for the check to mean anything.
const LONG_FIRE_TICKS: int = 1800
const LEAST_SHOTS: int = 20
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.01
## The steps of the looks check: hit points taken off a panel of 40 in turn, so that it stands at exactly 80% (32), just
## under it, exactly 35% (14), just under it, and then falls.
const STEPS: Array[float] = [8.0, 0.5, 17.5, 0.5, 13.5]
const STEP_LOOKS: Array[int] = [0, 1, 1, 2, -1]
## The physics layer the panels stand on (cover, value 64).
const COVER_LAYER: int = 64

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick
## The Shots' record to the fall, for the looks check: {type id: [[hit points, look shown], ...]}.
var _runs: Dictionary = {}


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _damage()
	await _looks()


## The Player's Unit of a type stands level with a panel of a run, `from` metres out of its outer face, facing it, and
## waits out the Weapon's cadence.
func _aim(player: int, type_index: int, base_index: int, run: int, from: float) -> void:
	var at: Vector3 = _k.spot(base_index, run, Kit19.LANE[run], Kit19.OUTER_FACES[run] + from)
	await _k.k.stage(player, type_index, at, -_k.outward(base_index, run))
	await _q.kit.advance(_k.k.m.w.longest_cadence())


## One Shot of Player `player` of the type at the lane panel of a run (a Base's Garage, or the field): the problems it
## shows against `want` hit points off, an end on the face and, when it hurt, the first look.
func _one_shot(player: int, type_index: int, base_index: int, run: int, want: float, label: String, problems: PackedStringArray) -> void:
	await _k.restore_all()
	var target: Structure = _k.panel(base_index, run, Kit19.LANE[run])
	await _aim(player, type_index, base_index, run, FIELD_SHOT_FROM if _k.is_field(run) else GARAGE_SHOT_FROM)
	var hits_before: int = _k.hits.size()
	var end: Vector3 = await _k.k.m.w.shoot(player)
	_q.kit.need(problems, is_equal_approx(Kit19.HIT_POINTS - target.hit_points, want), "%s took %.2f, expected %.2f" % [label, Kit19.HIT_POINTS - target.hit_points, want])
	_q.kit.need(problems, _k.hits.size() == hits_before + (1 if want > 0.0 else 0), "%s: %d hit_points_changed emitted" % [label, _k.hits.size() - hits_before])
	_q.kit.need(problems, end != Vector3.INF and absf(_k.along_out(base_index, run, end) - Kit19.OUTER_FACES[run]) <= TOLERANCE, "%s ended at %s, not on the face" % [label, end])
	_q.kit.need(problems, _k.k.look_shown(target) == (1 if want > 0.0 else 0), "%s: look %d shown after one Shot" % [label, _k.k.look_shown(target)])


## damage (AC-3, AC-4): per-shot damage from each Player at the other Player's Garage panel, at its own and at a field
## panel (the same one from both Players); then the Shots to the fall at a Garage side panel and at the field walls,
## and the Motorbike's long fire.
func _damage() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var fall_notes: PackedStringArray = []
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	for type_index: int in 4:
		var stats: UnitStats = _q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		for player: int in Kit.PLAYERS:
			await _one_shot(player, type_index, 1 - player, Kit19.LEFT, per_shot, "p%d %s at the other Player's Garage panel" % [player + 1, stats.type_id], problems)
			await _one_shot(player, type_index, player, Kit19.LEFT, 0.0, "p%d %s at its own Garage panel" % [player + 1, stats.type_id], problems)
			await _one_shot(player, type_index, 0, Kit19.WEST, per_shot, "p%d %s at the west field panel" % [player + 1, stats.type_id], problems)
		notes.append("%s %.0f" % [stats.type_id, per_shot])
	var falls_total: int = 0
	var cases: Array = [[Kit19.LEFT, 0, 1], [Kit19.WEST, 0, 0], [Kit19.EAST, 1, 0], [Kit19.WEST, 1, 0], [Kit19.EAST, 0, 0]]
	for type_index: int in 4:
		var stats: UnitStats = _q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		var predicted: int = ceili(Kit19.HIT_POINTS / per_shot) if per_shot > 0.0 else -1
		for entry: Array in cases:
			var run: int = entry[0]
			var player: int = entry[1]
			var base_index: int = entry[2]
			await _k.restore_all()
			var target: Structure = _k.panel(base_index, run, Kit19.LANE[run])
			await _aim(player, type_index, base_index, run, FIELD_SHOT_FROM if _k.is_field(run) else GARAGE_SHOT_FROM)
			var falls_before: int = _k.falls.size()
			var hits_before: int = _k.hits.size()
			var fell_on: int = -1
			var seen: Array = []
			if predicted > 0:
				for shot: int in range(1, predicted + 1):
					if shot > 1:
						await _q.kit.advance(_k.k.m.w.cadence(type_index))
					await _k.k.m.w.shoot(player)
					fell_on = shot if fell_on < 0 and not target.is_standing else fell_on
					seen.append([target.hit_points, _k.k.look_shown(target)])
			else:
				var shots_before: int = _q.units.shots.size()
				await _q.units.hold_fire(player, LONG_FIRE_TICKS)
				var fired: int = _q.units.shots.size() - shots_before
				_q.kit.need(problems, fired >= LEAST_SHOTS, "the Motorbike fired only %d Shots in %d s" % [fired, LONG_FIRE_TICKS / 60])
				await _q.kit.advance(Kit19.Kit18.IN_FLIGHT_TICKS)
			if entry == cases[0]:
				_runs[stats.type_id] = seen
			falls_total += _k.falls.size() - falls_before
			var label: String = "p%d %s at %s" % [player + 1, stats.type_id, Kit19.RUN_NAMES[run]]
			_q.kit.need(problems, fell_on == predicted and _k.falls.size() == falls_before + (1 if predicted > 0 else 0), "%s: the panel fell on shot %d (%d falls), expected %d" % [label, fell_on, _k.falls.size() - falls_before, predicted])
			_q.kit.need(problems, predicted > 0 or (target.is_standing and _k.hits.size() == hits_before and is_equal_approx(target.hit_points, Kit19.HIT_POINTS)), "%s changed a panel after %d s of fire" % [label, LONG_FIRE_TICKS / 60])
		if predicted > 0:
			fall_notes.append("%s falls on shot %d" % [stats.type_id, predicted])
	await _k.restore_all()
	_q.kit.verdict("damage", problems, "per-shot damage (%s): each Player's Shots of every type took the multiplier off the other Player's Garage side panel and off a field panel (the same panel from both Players: it belongs to nobody) and nothing off its own Garage's, every Shot ended on the outer face and the first one that hurt showed the first damaged look; the Shots to the fall at a Garage side panel (Player 1 at Base B's) and at the west and east field walls (each from both Players): %s, the Motorbike's never, however long it fires (%d s held, at least %d Shots flown)" % [
		", ".join(notes), ", ".join(fall_notes), LONG_FIRE_TICKS / 60, LEAST_SHOTS])
	measured.append("panel_falls=%d" % falls_total)


## looks (AC-3): every one of the 28 panels is hurt in the STEPS to exactly 80% (still whole), just under it (the first
## look), exactly 35% (still the first), just under it (the second) and then to its fall (the rubble), one look shown at
## a time, its collider, layer and height unchanged until it falls; the Shots of damage showed the same looks; every look
## and the rubble are meshes with no collider of their own.
func _looks() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	for target: Structure in _k.every():
		var shape: CollisionShape3D = target.get_node("CollisionShape3D") as CollisionShape3D
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var label: String = String(target.get_path())
		_q.kit.need(problems, _k.k.look_shown(target) == 0, "%s shows look %d whole" % [label, _k.k.look_shown(target)])
		for step: int in STEPS.size():
			target.apply_damage(STEPS[step])
			checked += 1
			_q.kit.need(problems, _k.k.look_shown(target) == STEP_LOOKS[step], "%s at %.2f hit points shows look %d, expected %d" % [label, target.hit_points, _k.k.look_shown(target), STEP_LOOKS[step]])
			var standing: bool = STEP_LOOKS[step] >= 0
			_q.kit.need(problems, (target.collision_layer == COVER_LAYER if standing else target.collision_layer == 0) and target.collision_mask == 0 and (shape.shape as BoxShape3D).size == size, "%s at %.2f hit points: layer %d, mask %d, shape %s" % [label, target.hit_points, target.collision_layer, target.collision_mask, (shape.shape as BoxShape3D).size])
		var colliders: int = target.find_children("*", "CollisionObject3D", true, false).size() + target.find_children("*", "CollisionShape3D", true, false).size()
		_q.kit.need(problems, colliders == 1, "%s has %d colliders and shapes under it, expected its one shape" % [label, colliders])
		_q.kit.need(problems, target.get_node("MeshDamaged1").get_child_count() == 4 and target.get_node("MeshDamaged2").get_child_count() == 8 and target.get_node(Kit19.Kit18.RUBBLE_NAME).get_child_count() == 5, "%s: chunks %d, %d and %d, not 4, 8 and 5" % [label, target.get_node("MeshDamaged1").get_child_count(), target.get_node("MeshDamaged2").get_child_count(), target.get_node(Kit19.Kit18.RUBBLE_NAME).get_child_count()])
	var shots: PackedStringArray = []
	for type_id: StringName in _runs:
		var seen: Array = _runs[type_id]
		if seen.is_empty():
			continue
		shots.append("%s %s" % [type_id, ", ".join(seen.map(func(entry: Array) -> String: return "%.0f:%d" % [entry[0], entry[1]]))])
		for entry: Array in seen:
			var hp: float = float(entry[0])
			var expected: int = -1 if hp <= 0.0 else (2 if hp < 0.35 * Kit19.HIT_POINTS else (1 if hp < 0.8 * Kit19.HIT_POINTS else 0))
			_q.kit.need(problems, int(entry[1]) == expected, "%s at %.0f hit points showed look %d after a Shot, expected %d" % [type_id, hp, int(entry[1]), expected])
	await _k.restore_all()
	measured.append("look_steps=%d" % checked)
	_q.kit.verdict("looks", problems, "all 28 panels, hurt in %d steps each by apply_damage() (a tool may): whole at 40 and at exactly 32 (80%%), the first look at 31.5 and at exactly 14 (35%%), the second at 13.5, the rubble at 0, one look at a time and the layer, mask and shape of the whole panel until the fall; each look is a mesh with 4, 8 and 5 chunks and no collider; the looks the real Shots showed (hit points:look, by type) agree: %s" % [STEPS.size(), " | ".join(shots)])
