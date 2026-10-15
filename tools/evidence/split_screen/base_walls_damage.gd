extends RefCounted
## What hurts a Wall Panel and how it looks, for the base_walls scenario (Story 018 AC-3): damage (one Shot of each
## type from each Player at a panel of the other Player's back wall and of its own: the other Player's takes the
## damage times the matrix's multiplier, the own takes nothing; the Shots each type needs to bring one down, the
## Motorbike's never, even held for 30 s), turret_shots (a Turret's own Shot ends on its own Base's panel and takes
## nothing, one of the other Player's takes its 12) and looks (every panel, hurt step by step through the strict
## thresholds of 80% and 35% to its fall: exactly one look at a time, the colliders and layers unchanged, the rubble
## at the end). Run by base_walls.gd. Tooling only. Every number comes from the game's data; the scenario types only
## its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Metres out of the back wall's outer face where a shooter stands, and the lane panel it shoots at.
const SHOT_FROM: float = 8.0
## Shots a Motorbike's long fire is counted over: the ticks it holds the fire key (30 s) and the least number of
## Shots that must have flown for the check to mean anything.
const LONG_FIRE_TICKS: int = 1800
const LEAST_SHOTS: int = 20
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.01
## The steps of the looks check: hit points taken off a panel of 40 in turn, so that it stands at exactly 80%
## (32), just under it, exactly 35% (14), just under it, and then falls.
const STEPS: Array[float] = [8.0, 0.5, 17.5, 0.5, 13.5]
const STEP_LOOKS: Array[int] = [0, 1, 1, 2, -1]
## The physics layer the panels stand on (cover, value 64).
const COVER_LAYER: int = 64
## The panel of each Gate wall a Turret's Shot is fired at (the middle one).
const TURRET_PANEL: int = 1

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick
## damage's runs to the fall, for the looks check: {type id: [[hit points, look shown], ...]}.
var _runs: Dictionary = {}


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _damage()
	await _turret_shots()
	await _looks()


## Where a shooter of a Player stands to shoot the lane panel of a Base's back wall, and its facing.
func _shoot_at(player: int, target_base: int, type_index: int) -> void:
	var run: int = Kit18.BACK
	var at: Vector3 = _k.spot(target_base, run, Kit18.LANE[run], Kit18.OUTER_FACES[run] + SHOT_FROM)
	await _k.stage(player, type_index, at, -_k.outward(target_base, run))
	await _q.kit.advance(_k.m.w.longest_cadence())


## damage (AC-3): per-shot damage from each Player at the other Player's and its own back-wall panel, then the Shots
## to the fall, then the Motorbike's long fire.
func _damage() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	var run: int = Kit18.BACK
	var face: float = Kit18.OUTER_FACES[run]
	for type_index: int in 4:
		var stats: UnitStats = _q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		for player: int in Kit.PLAYERS:
			for target_base: int in [1 - player, player]:
				await _k.restore_all()
				var target: Structure = _k.panel(target_base, run, Kit18.LANE[run])
				await _shoot_at(player, target_base, type_index)
				var hits_before: int = _k.hits.size()
				var end: Vector3 = await _k.m.w.shoot(player)
				var want: float = per_shot if target_base != player else 0.0
				var label: String = "p%d %s at %s panel" % [player + 1, stats.type_id, "its own" if target_base == player else "the other Player's"]
				_q.kit.need(problems, is_equal_approx(Kit18.HIT_POINTS - target.hit_points, want), "%s took %.2f, expected %.2f" % [label, Kit18.HIT_POINTS - target.hit_points, want])
				_q.kit.need(problems, _k.hits.size() == hits_before + (1 if want > 0.0 else 0), "%s: %d hit_points_changed emitted" % [label, _k.hits.size() - hits_before])
				_q.kit.need(problems, end != Vector3.INF and absf(_k.m.w.bases[target_base].to_local(end).dot(Kit18.OUTWARD[run]) - face) <= TOLERANCE, "%s ended at %s, not on the face" % [label, end])
				_q.kit.need(problems, _k.look_shown(target) == (1 if want > 0.0 else 0), "%s: look %d shown after one Shot" % [label, _k.look_shown(target)])
		notes.append("%s %.0f" % [stats.type_id, per_shot])
	var falls_total: int = 0
	for type_index: int in 4:
		var stats: UnitStats = _q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		var predicted: int = ceili(Kit18.HIT_POINTS / per_shot) if per_shot > 0.0 else -1
		await _k.restore_all()
		var target: Structure = _k.panel(1, run, Kit18.LANE[run])
		await _shoot_at(0, 1, type_index)
		var falls_before: int = _k.falls.size()
		var hits_before: int = _k.hits.size()
		var fell_on: int = -1
		var seen: Array = []
		if predicted > 0:
			for shot: int in range(1, predicted + 1):
				if shot > 1:
					await _q.kit.advance(_k.m.w.cadence(type_index))
				await _k.m.w.shoot(0)
				fell_on = shot if fell_on < 0 and not target.is_standing else fell_on
				seen.append([target.hit_points, _k.look_shown(target)])
		else:
			var shots_before: int = _q.units.shots.size()
			await _q.units.hold_fire(0, LONG_FIRE_TICKS)
			var fired: int = _q.units.shots.size() - shots_before
			_q.kit.need(problems, fired >= LEAST_SHOTS, "the Motorbike fired only %d Shots in %d s" % [fired, LONG_FIRE_TICKS / 60])
			notes.append("the Motorbike %d Shots in %d s took nothing" % [fired, LONG_FIRE_TICKS / 60])
			await _q.kit.advance(Kit18.IN_FLIGHT_TICKS)
		_runs[stats.type_id] = seen
		falls_total += _k.falls.size() - falls_before
		_q.kit.need(problems, fell_on == predicted and _k.falls.size() == falls_before + (1 if predicted > 0 else 0), "%s: the panel fell on shot %d (%d falls), expected %d" % [stats.type_id, fell_on, _k.falls.size() - falls_before, predicted])
		_q.kit.need(problems, predicted > 0 or (target.is_standing and _k.hits.size() == hits_before and is_equal_approx(target.hit_points, Kit18.HIT_POINTS)), "the Motorbike changed a panel after %d s of fire" % (LONG_FIRE_TICKS / 60))
		notes.append("%s falls on shot %d" % [stats.type_id, predicted])
	await _k.restore_all()
	_q.kit.verdict("damage", problems, "per-shot damage and the Shots to the fall (%s): each Player's Shots of every type, at the back wall's lane panel, took the multiplier off the other Player's panel and nothing off its own, every Shot ended on the outer face (%.1f m from the axis) and the first one showed the first damaged look; the Truck brings a panel down with its 2nd Shot, the Gyrocopter with its 3rd, the Buggy with its 4th and the Motorbike never" % [", ".join(notes), face])
	measured.append("panel_falls=%d" % falls_total)


## turret_shots (AC-3): a Shot of a Turret, the barrel turned at a Gate-wall panel of its own Base from 4 m in front of
## it and fired as the Turret does, ends on the face and takes nothing off a panel of its own Player's Base; once the
## Turret belongs to the other Player (a tool sets it) the same Shot takes the Turret's 12 off.
func _turret_shots() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	await _k.restore_all()
	for base_index: int in Kit.PLAYERS:
		var base: Base = _k.m.w.bases[base_index]
		for side: int in Kit18.TURRET_NAMES.size():
			var turret: Turret = _k.turret(base_index, side)
			turret.restore()
			await _q.kit.advance(Kit18.SETTLE)
			var run: int = Kit18.GATE_LEFT if side == 0 else Kit18.GATE_RIGHT
			var target: Structure = _k.panel(base_index, run, TURRET_PANEL)
			var aim: Vector3 = _k.spot(base_index, run, TURRET_PANEL, Kit18.OUTER_FACES[run]) + Vector3.UP * _q.controller.rules.shooting_height
			var local: Vector3 = turret.to_local(aim)
			turret.head.rotation.y = atan2(-local.x, -local.z)
			var owner: int = turret.player_index
			var damage: float = (turret.stats as TurretStats).damage * matrix.multiplier(turret.type_id, &"flag_wall")
			for shooter: int in [owner, 1 - owner]:
				turret.player_index = shooter
				var before: float = target.hit_points
				var mark: int = _k.fired.size()
				turret._fire()
				for _tick: int in Kit18.IN_FLIGHT_TICKS:
					if _k.fired.size() > mark and _k.fired[mark]["end"] != Vector3.INF:
						break
					await _q.kit.tick()
				var end: Vector3 = _k.fired[mark]["end"] if _k.fired.size() > mark else Vector3.INF
				var want: float = 0.0 if shooter == owner else damage
				var label: String = "%s's %s Turret, a Shot of Player %d, at its Gate-wall panel" % [base.name, Kit18.TURRET_NAMES[side], shooter + 1]
				_q.kit.need(problems, end != Vector3.INF and absf(base.to_local(end).dot(Kit18.OUTWARD[run]) - Kit18.OUTER_FACES[run]) <= TOLERANCE, "%s ended at %s, not on the face" % [label, end])
				_q.kit.need(problems, is_equal_approx(before - target.hit_points, want), "%s took %.2f, expected %.2f" % [label, before - target.hit_points, want])
				notes.append("%s %s %.0f" % [base.name, "own" if shooter == owner else "other", before - target.hit_points])
				target.restore()
				await _q.kit.advance(Kit18.SETTLE)
			turret.player_index = owner
			turret.destroy()
	_q.kit.verdict("turret_shots", problems, "the barrel of each of the four Turrets turned at the Gate-wall panel in front of it and fired as the Turret fires: its own Player's Shot ended on the panel's outer face and took nothing, the same Shot with the Turret given to the other Player (a tool sets it) took the Turret's damage (%s)" % ", ".join(notes))


## looks (AC-3): every one of the 60 panels is hurt in the STEPS to exactly 80% (still whole), just under it (the
## first look), exactly 35% (still the first), just under it (the second) and then to its fall (the rubble), one
## look shown at a time, its collider, layer and height unchanged until it falls; the Shots of damage showed the
## same looks; every look and the rubble are meshes with no collider of their own.
func _looks() -> void:
	var problems: PackedStringArray = []
	var checked: int = 0
	var every: Array[Structure] = _k.every()
	for number: int in every.size():
		var target: Structure = every[number]
		var base_index: int = 1 if number >= every.size() / 2 else 0
		var shape: CollisionShape3D = target.get_node("CollisionShape3D") as CollisionShape3D
		var size: Vector3 = (shape.shape as BoxShape3D).size
		var label: String = "%s/%s/%s" % [_k.m.w.bases[base_index].name, target.get_parent().name, target.name]
		_q.kit.need(problems, _k.look_shown(target) == 0, "%s shows look %d whole" % [label, _k.look_shown(target)])
		for step: int in STEPS.size():
			target.apply_damage(STEPS[step])
			checked += 1
			_q.kit.need(problems, _k.look_shown(target) == STEP_LOOKS[step], "%s at %.2f hit points shows look %d, expected %d" % [label, target.hit_points, _k.look_shown(target), STEP_LOOKS[step]])
			var standing: bool = STEP_LOOKS[step] >= 0
			_q.kit.need(problems, (target.collision_layer == COVER_LAYER if standing else target.collision_layer == 0) and target.collision_mask == 0 and (shape.shape as BoxShape3D).size == size, "%s at %.2f hit points: layer %d, mask %d, shape %s" % [label, target.hit_points, target.collision_layer, target.collision_mask, (shape.shape as BoxShape3D).size])
		var colliders: int = target.find_children("*", "CollisionObject3D", true, false).size() + target.find_children("*", "CollisionShape3D", true, false).size()
		_q.kit.need(problems, colliders == 1, "%s has %d colliders and shapes under it, expected its one shape" % [label, colliders])
		_q.kit.need(problems, target.get_node("MeshDamaged1").get_child_count() == 4 and target.get_node("MeshDamaged2").get_child_count() == 8 and target.get_node(Kit18.RUBBLE_NAME).get_child_count() == 5, "%s: chunks %d, %d and %d, not 4, 8 and 5" % [label, target.get_node("MeshDamaged1").get_child_count(), target.get_node("MeshDamaged2").get_child_count(), target.get_node(Kit18.RUBBLE_NAME).get_child_count()])
	var shots: PackedStringArray = []
	for type_id: StringName in _runs:
		var seen: Array = _runs[type_id]
		shots.append("%s %s" % [type_id, ", ".join(seen.map(func(entry: Array) -> String: return "%.0f:%d" % [entry[0], entry[1]]))])
		for entry: Array in seen:
			var hp: float = float(entry[0])
			var expected: int = -1 if hp <= 0.0 else (2 if hp < 0.35 * Kit18.HIT_POINTS else (1 if hp < 0.8 * Kit18.HIT_POINTS else 0))
			_q.kit.need(problems, int(entry[1]) == expected, "%s at %.0f hit points showed look %d after a Shot, expected %d" % [type_id, hp, int(entry[1]), expected])
	await _k.restore_all()
	measured.append("look_steps=%d" % checked)
	_q.kit.verdict("looks", problems, "all 60 panels, hurt in %d steps each by apply_damage() (a tool may): whole at 40 and at exactly 32 (80%%), the first look at 31.5 and at exactly 14 (35%%), the second at 13.5, the rubble at 0, one look at a time and the layer, mask and shape of the whole panel until the fall; each look is a mesh with 4, 8 and 5 chunks and no collider; the looks the real Shots showed (hit points:look, by type) agree: %s" % [STEPS.size(), " | ".join(shots)])
