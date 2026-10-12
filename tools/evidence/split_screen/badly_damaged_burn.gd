extends RefCounted
## What the state leaves alone besides the driving (Story 017 AC-2), on the same flat arena: the Fuel a Unit burns in a
## second, moving and standing (and so about twice the Fuel per metre, recorded for the author), a stranded ground Unit
## (an empty tank) that is badly damaged and still turns at its empty turn rate and fires, the weapon (the interval
## between Shots, the damage a Shot does and how far it flies, the badly damaged Unit against the same Unit whole) and
## the HUD ("HP n / max", the bar and the Fuel line, with no control added or shown). Run by badly_damaged.gd. Tooling
## only. Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-2.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## Ticks a burn is read over (a second), a turn is read over, and the most a coast to a standstill may take.
const SECOND_TICKS: int = 60
const STAND_LIMIT_TICKS: int = 400
const TURN_TICKS: int = 30
## The Fuel a burn may be off by, Fuel units.
const BURN_TOLERANCE: float = 0.01
## Shots a weapon run fires, and the metres a Shot's end may be off by (a Shot moves 1 m a tick).
const SHOTS: int = 3
const REACH_TOLERANCE: float = 1.5
## Where a victim stands in a weapon run, metres east of the attacker.
const VICTIM_AHEAD: float = 12.0

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	_k.make_floor()
	await _fuel()
	await _stranded()
	await _weapon()
	await _hud()
	_k.free_floor()


## burn_per_second: moving at its steady speed it burns fuel_use a second and standing fuel_use_idle, whole or
## badly damaged, so it burns the same a second at half the speed: twice the Fuel per metre.
func _fuel() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in 4:
		var stats: UnitStats = _q.units.stats(type)
		var unit: Unit = _k.unit(0)
		var burns: Array[float] = []
		for damaged: bool in [false, true]:
			await _k.on_floor(0, _q.small_tank(type, 1.0))
			if damaged:
				unit.apply_damage(unit.hit_points - _k.edge_of(type))
			await _k.series(0, 1, 0, Kit17.STEADY_TICKS)
			var start: float = unit.fuel
			await _k.series(0, 1, 0, SECOND_TICKS)
			burns.append(start - unit.fuel)
			await _stand_still(unit)
			start = unit.fuel
			await _k.series(0, 0, 0, SECOND_TICKS)
			burns.append(start - unit.fuel)
		var name: String = Units.TYPE_IDS[type]
		_q.kit.need(problems, absf(burns[0] - stats.fuel_use) <= BURN_TOLERANCE and absf(burns[2] - stats.fuel_use) <= BURN_TOLERANCE, "%s: moving burns %s and %s a second, the data give %s" % [name, burns[0], burns[2], stats.fuel_use])
		_q.kit.need(problems, absf(burns[1] - stats.fuel_use_idle) <= BURN_TOLERANCE and absf(burns[3] - stats.fuel_use_idle) <= BURN_TOLERANCE, "%s: standing burns %s and %s a second, the data give %s" % [name, burns[1], burns[3], stats.fuel_use_idle])
		notes.append("%s %.2f moving and %.3f standing a second (%.2f m of top speed per Fuel whole, %.2f badly damaged)" % [name, burns[2], burns[3], stats.max_speed / stats.fuel_use, _k.share_speed(type, true) / stats.fuel_use])
	_q.kit.verdict("burn_per_second", problems, " | ".join(notes))


## Waits, no key held, until the Unit's drive speed is exactly zero (the longest coast takes about 2 s).
func _stand_still(unit: Unit) -> void:
	for _wait: int in STAND_LIMIT_TICKS:
		if unit.current_speed == 0.0:
			return
		await _k.series(0, 0, 0, 1)


## stranded_still_turns_and_fires: an empty tank, a ground type, badly damaged: no throttle, the empty turn rate, a
## real Shot.
func _stranded() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type)
		await _k.on_floor(0, _q.small_tank(type, 0.0))
		var unit: Unit = _k.unit(0)
		unit.apply_damage(unit.hit_points - _k.edge_of(type))
		_q.kit.need(problems, unit.is_stranded and unit.is_badly_damaged, "%s: stranded %s, badly damaged %s" % [Units.TYPE_IDS[type], unit.is_stranded, unit.is_badly_damaged])
		var start: float = Quick.yaw(unit)
		var speeds: PackedFloat64Array = await _k.series(0, 1, 1, TURN_TICKS)
		var turned: float = absf(Quick.turned(start, Quick.yaw(unit))) / (float(TURN_TICKS) / 60.0)
		var shots: int = _q.units.shots.size()
		await _q.units.hold_fire(0, 1)
		await _q.kit.advance(2)
		_q.kit.need(problems, speeds[-1] == 0.0 and unit.global_position.distance_to(Kit17.ARENA_CENTRE + Vector3(-100.0, 0.0, 0.0)) < 0.5, "%s: drove (speed %s) on an empty tank" % [Units.TYPE_IDS[type], speeds[-1]])
		_q.kit.need(problems, absf(turned - stats.empty_turn_rate) <= 0.02, "%s: turned %.3f rad/s, the empty turn rate is %s" % [Units.TYPE_IDS[type], turned, stats.empty_turn_rate])
		_q.kit.need(problems, _q.units.shots.size() == shots + 1, "%s: %d Shots fired by the fire key" % [Units.TYPE_IDS[type], _q.units.shots.size() - shots])
		notes.append("%s turned %.3f rad/s (empty turn rate %s), stayed at 0 m/s and fired" % [Units.TYPE_IDS[type], turned, stats.empty_turn_rate])
	_q.kit.verdict("stranded_still_turns_and_fires", problems, " | ".join(notes))


## weapon_unchanged: a Buggy against a Truck 12 m ahead with the fire key held, whole and then badly damaged: the
## same ticks between its Shots, the same hit points taken off for every Shot (damage x the matrix) and the same end
## of a Shot into the open.
func _weapon() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.BUGGY)
	var matrix: DamageMatrix = _q.controller.rules.damage_matrix
	var expected: float = stats.damage * matrix.multiplier(stats.type_id, &"truck")
	var interval: int = _q.harness.ticks_in(stats.fire_interval_seconds)
	var runs: Array[Dictionary] = []
	for damaged: bool in [false, true]:
		await _k.on_floor(0, _q.small_tank(Quick.BUGGY, 1.0))
		var unit: Unit = _k.unit(0)
		if damaged:
			unit.apply_damage(unit.hit_points - _k.edge_of(Quick.BUGGY))
		await _q.kit.advance(_k.t.w.longest_cadence())
		_q.units.retype(1, Quick.TRUCK, unit.global_position + Vector3(VICTIM_AHEAD, 0.0, 0.0), Vector3.LEFT)
		await _q.kit.advance(Kit17.SETTLE)
		var victim: Unit = _k.unit(1)
		var first_shot: int = _q.units.shots.size()
		var before: float = victim.hit_points
		await _q.units.hold_fire(0, interval * (SHOTS - 1) + 1)
		await _q.kit.advance(Units.HIT_LIMIT_TICKS)
		var fired: int = _q.units.shots.size() - first_shot
		var lost: float = before - victim.hit_points
		var gaps: Array[int] = []
		for index: int in range(first_shot + 1, _q.units.shots.size()):
			gaps.append(_q.units.shot_ticks[index] - _q.units.shot_ticks[index - 1])
		_q.units.retype(1, Quick.TRUCK, unit.global_position + Vector3(0.0, 0.0, 60.0), Vector3.LEFT)
		await _q.kit.advance(Kit17.SETTLE)
		var open: int = _q.units.shots.size()
		await _q.units.hold_fire(0, 1)
		await _q.kit.advance(Units.HIT_LIMIT_TICKS)
		var reach: float = _q.units.shot_ends[open].distance_to(unit.global_position) if _q.units.shot_ends.size() > open else -1.0
		runs.append({"fired": fired, "lost": lost, "gaps": gaps, "reach": reach, "badly": unit.is_badly_damaged})
	for run: Dictionary in runs:
		_q.kit.need(problems, run["fired"] == SHOTS and is_equal_approx(run["lost"], expected * SHOTS), "%d Shots took %s hit points off the Truck, the data give %s each" % [run["fired"], run["lost"], expected])
		_q.kit.need(problems, run["gaps"] == [interval, interval], "ticks between Shots %s, the data give %d" % [run["gaps"], interval])
		_q.kit.need(problems, absf(float(run["reach"]) - (stats.muzzle_forward + stats.weapon_range)) <= REACH_TOLERANCE, "a Shot into the open ended %s m out, the data give %s" % [run["reach"], stats.muzzle_forward + stats.weapon_range])
	_q.kit.need(problems, not runs[0]["badly"] and runs[1]["badly"], "the second run was not the badly damaged one")
	_q.kit.need(problems, runs[0]["lost"] == runs[1]["lost"] and runs[0]["gaps"] == runs[1]["gaps"] and absf(float(runs[0]["reach"]) - float(runs[1]["reach"])) <= Kit17.TOLERANCE, "whole %s and badly damaged %s differ" % [runs[0], runs[1]])
	_q.kit.verdict("weapon_unchanged", problems, "a Buggy whole and badly damaged: %d Shots of %s hit points each off a Truck (12 x 1.5), %d ticks between Shots, a Shot into the open ends %.2f m out (muzzle %s + range %s)" % [SHOTS, expected, interval, runs[1]["reach"], stats.muzzle_forward, stats.weapon_range])


## hud_unchanged: the Player's HUD shows "HP n / max" and the bar from the hit points as it always did, and the same
## controls: nothing is added or shown when the state begins.
func _hud() -> void:
	var problems: PackedStringArray = []
	await _k.on_floor(0, _q.small_tank(Quick.TRUCK, 1.0))
	var unit: Unit = _k.unit(0)
	var hud: PlayerHud = _q.units.huds[0]
	var whole: Dictionary = _snapshot(hud)
	unit.apply_damage(unit.hit_points - _k.edge_of(Quick.TRUCK))
	await _q.kit.advance(2)
	var damaged: Dictionary = _snapshot(hud)
	var line: String = hud.tr(hud.hit_points_format) % [ceili(_k.edge_of(Quick.TRUCK)), ceili(unit.stats.max_hit_points)]
	_q.kit.need(problems, whole["controls"] == damaged["controls"], "the HUD's visible controls changed: %s -> %s" % [whole["controls"], damaged["controls"]])
	_q.kit.need(problems, damaged["hp"] == line and damaged["bar"] == [0.0, unit.stats.max_hit_points, _k.edge_of(Quick.TRUCK)], "the HUD shows %s %s, not %s" % [damaged["hp"], damaged["bar"], line])
	_q.kit.need(problems, whole["fuel"] == damaged["fuel"] and whole["hp"] != damaged["hp"], "the Fuel line or the hit-point line did not behave: %s -> %s" % [whole["fuel"], damaged["fuel"]])
	_q.kit.verdict("hud_unchanged", problems, "a Truck at its edge: the HUD reads '%s' and the bar %s, the same %d controls show as before, the Fuel line is '%s'" % [damaged["hp"], damaged["bar"], damaged["controls"].size(), damaged["fuel"]])


## What the HUD shows now: its visible controls by path, its two lines and its bar.
func _snapshot(hud: PlayerHud) -> Dictionary:
	var controls: Array[String] = []
	for node: Node in hud.find_children("*", "Control", true, false):
		if (node as Control).is_visible_in_tree():
			controls.append(String(hud.get_path_to(node)))
	return {"controls": controls, "hp": hud._hit_points_label.text, "fuel": hud._fuel_label.text,
		"bar": [hud._bar.min_value, hud._bar.max_value, hud._bar.value]}
