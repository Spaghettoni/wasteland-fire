extends RefCounted
## Targets, reach and sight of the turrets scenario (Story 013 AC-2), on the shipped Turrets and Map
## 01. targets: a Base's Turrets aim at and fire on the other Player's Unit of every type and hit
## it, never take their own Player's Unit as a target, hold fire while that Unit stands between them
## and the other Player's, and aim at no Unit that is benched or destroyed. reach: a Unit 34.5 m from
## the aimed muzzle is fired on and hit, one at 35.5 m never, at a bearing where the resting muzzle
## would read both over 35 m. sight: whatever stops a Shot hides a target (a Base wall, the cover, a
## Gyrocopter over a wreck, a Flag Wall, the other Turret, a Unit) and so does a cliff, although
## the Unit's own Shots pass through the rock and hit the Turret. path: the second hold, the Shot's
## own path to the point ahead of the target: with a panel on that path and none on the line to the
## Motorbike, the Turret sees it, is on the aim and holds fire. Run by turrets.gd. Implements:
## production/epics/wasteland-fire/story-013-turrets.md AC-2. Tooling only. Every number comes from
## the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

## Metres in front of a Turret, along its rest heading, a target is put at (AC-2: in reach and sight).
const AHEAD: float = 15.0
## Ticks a target is watched for: long enough for a first Shot to fly and land (15 m takes 15 ticks),
## short enough that two Turrets cannot destroy the weakest Unit.
const WATCH: int = 60
## Ticks an idle Turret is watched for, two cadences.
const IDLE_WATCH: int = 96
## The bearing of the reach check from the rest heading toward the canyon, degrees (AC-2: at least
## 50, where the resting muzzle and the aimed muzzle differ by enough), and the two distances from
## the aimed muzzle, metres: one inside the data's range, one outside it.
const REACH_DEGREES: float = 50.0
const REACH_IN: float = 34.5
const REACH_OUT: float = 35.5
## A control at the same bearing, well inside the range, so a Turret that holds fire at REACH_OUT
## does so for the range and not for what stands in the line.
const REACH_CONTROL: float = 30.0
## The line the path check drives along (world): south along x -72 from z 24, and for how long, ticks.
const PATH_FROM: Vector3 = Vector3(-72.0, 0.0, 24.0)
const PATH_TICKS: int = 150
## How far out on the probe's Shot line the panel stands, metres: far enough that the line to the
## Motorbike itself passes it by more than the panel's half width, and a Shot that ends within
## PANEL_NEAR metres of its centre ended on it.
const PANEL_ALONG: float = 14.0
const PANEL_NEAR: float = 2.5
## The wreck that stands in front of Base A (world x, z), the point behind it from the ridge-side
## Turret and a point beside it at the same distance (the control), the canyon Fuel Can behind the
## canyon's south wall, and where the other Turret hides a target from the ridge-side one.
const WRECK: Vector3 = Vector3(-80.0, 0.0, 5.0)
const BEHIND_WRECK: Vector3 = Vector3(-72.0, 0.0, 3.0)
const BESIDE_WRECK: Vector3 = Vector3(-72.0, 0.0, 12.0)
const CANYON_CAN: Vector3 = Vector3(-88.0, 0.0, -26.0)
const BEHIND_TURRET: Vector3 = Vector3(-101.0, 0.0, -15.0)
## A point just inside the Gate wall of a Base, in Base-local metres, behind the right-hand Turret.
const BEHIND_GATE_WALL: Vector3 = Vector3(10.0, 0.0, -9.0)
## Base A's right-hand corner tower hides the first of these from the right-hand Turret; the second,
## beside it, is in sight (Base-local metres).
const BEHIND_TOWER: Vector3 = Vector3(22.0, 0.0, -12.0)
const BESIDE_TOWER: Vector3 = Vector3(22.0, 0.0, -26.0)
## Where a Flag Wall panel is put in the open: this far in front of the Turret, turned across the
## line to the target.
const PANEL_AT: float = 8.0
const PANEL_SCENE: String = "res://src/gameplay/defences/flag_wall.tscn"

var _k: Kit13
## What each check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The four checks, in order.
func run() -> void:
	await _targets()
	await _reach()
	await _sight()
	await _path()


## True when a watched Turret neither aimed, nor turned its head, nor fired.
func _quiet(seen: Dictionary, who: Turret) -> bool:
	return not bool(seen[who]["aimed"]) and not bool(seen[who]["turned"]) and int(seen[who]["shots"]) == 0


## targets (AC-2).
func _targets() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var seen_types: PackedStringArray = []
	for base_index: int in Kit.PLAYERS:
		var target: int = 1 - base_index
		var near: Turret = _k.turret(base_index, Kit13.RIGHT)
		for type_index: int in 4:
			await _k.restore_all()
			await _k.stage(target, type_index, _k.ahead(near, base_index, AHEAD), -_k.w.way(base_index, Vector3.FORWARD))
			var mark: int = _k.hp_mark()
			var seen: Dictionary = await _k.watch(WATCH)
			var label: String = "Base %d's Turrets at Player %d's %s" % [base_index + 1, target + 1, q.units.stats(type_index).type_id]
			for side: int in Kit13.NAMES.size():
				q.kit.need(problems, bool(seen[_k.turret(base_index, side)]["aimed"]), "%s: the %s Turret never aimed" % [label, Kit13.NAMES[side]])
			q.kit.need(problems, int(seen[near]["shots"]) >= 1 and _k.hits_since(target, mark).x >= 1.0, "%s: %d Shots, %d hits" % [label, int(seen[near]["shots"]), int(_k.hits_since(target, mark).x)])
			for side: int in Kit13.NAMES.size():
				q.kit.need(problems, _quiet(seen, _k.turret(1 - base_index, side)), "%s: the other Base's %s Turret stirred" % [label, Kit13.NAMES[side]])
			seen_types.append("%d%s" % [base_index + 1, String(q.units.stats(type_index).type_id).left(1)])
	var own: PackedStringArray = []
	for base_index: int in Kit.PLAYERS:
		await _k.restore_all()
		var near: Turret = _k.turret(base_index, Kit13.RIGHT)
		await _k.stage(base_index, Quick.MOTORBIKE, _k.ahead(near, base_index, AHEAD), -_k.w.way(base_index, Vector3.FORWARD))
		var mark: int = _k.hp_mark()
		var seen: Dictionary = await _k.watch(IDLE_WATCH)
		for side: int in Kit13.NAMES.size():
			q.kit.need(problems, _quiet(seen, _k.turret(base_index, side)), "Base %d's %s Turret stirred for its own Player's Unit" % [base_index + 1, Kit13.NAMES[side]])
		q.kit.need(problems, _k.hits_since(base_index, mark).x == 0.0, "Player %d's own Unit was hit beside its own Turret" % [base_index + 1])
		own.append("%d" % [base_index + 1])
	await _k.restore_all()
	var between: Turret = _k.turret(0, Kit13.RIGHT)
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(between, 0, AHEAD + 7.0), -_k.w.way(0, Vector3.FORWARD))
	q.units.retype(0, Quick.TRUCK, _k.ahead(between, 0, 8.0), -_k.w.way(0, Vector3.FORWARD))
	await q.kit.advance(Kit13.SETTLE)
	var seen_between: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(seen_between, between), "the ridge-side Turret stirred with its own Player's Unit between it and the other Player's")
	await _k.restore_all()
	var near: Turret = _k.turret(0, Kit13.RIGHT)
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(near, 0, AHEAD), -_k.w.way(0, Vector3.FORWARD))
	var control: Dictionary = await _k.watch(WATCH)
	q.kit.need(problems, bool(control[near]["aimed"]) and int(control[near]["shots"]) >= 1, "the control Unit was not fired on")
	var unit: Unit = q.units.units[1]
	unit.leave_play()
	await q.kit.advance(2)
	var benched: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(benched, near), "the Turret aimed at or fired on a benched Unit")
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(near, 0, AHEAD), -_k.w.way(0, Vector3.FORWARD))
	var again: Dictionary = await _k.watch(WATCH / 2)
	q.kit.need(problems, bool(again[near]["aimed"]), "the Turret did not aim at the Unit once it was back in play")
	unit.destroy()
	await q.kit.advance(2)
	var destroyed: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(destroyed, near), "the Turret aimed at or fired on a destroyed Unit")
	q.kit.verdict("targets", problems, "both Bases' Turrets aimed at, fired on and hit the other Player's Unit of every type (%s) and no other Base's Turret stirred; neither Base's Turrets stirred, turned or fired at their own Player's Unit (Players %s), nor with that Unit between them and the other Player's; none aimed at a benched or a destroyed Unit" % [
		", ".join(seen_types), ", ".join(own)])


## reach (AC-2): 34.5 m from the aimed muzzle is fired on and hit, 35.5 m never, at a bearing where
## the resting muzzle would read over 35 m for both.
func _reach() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var who: Turret = _k.turret(0, Kit13.RIGHT)
	var canyon_side: Turret = _k.turret(0, Kit13.LEFT)
	await _k.restore_all()
	canyon_side.destroy()
	var bearing: Vector3 = _k.w.way(0, Vector3.FORWARD).rotated(Vector3.UP, deg_to_rad(REACH_DEGREES))
	var forward: float = who.stats.muzzle_forward
	var rest_muzzle: Vector3 = who.global_position + _k.w.way(0, Vector3.FORWARD) * forward
	var notes: PackedStringArray = []
	for metres: float in [REACH_CONTROL, REACH_IN, REACH_OUT]:
		var at: Vector3 = who.global_position + bearing * (metres + forward)
		await _k.stage(1, Quick.MOTORBIKE, at, -bearing)
		var mark: int = _k.hp_mark()
		var seen: Dictionary = await _k.watch(2 * WATCH)
		var resting: float = Vector2(rest_muzzle.x - at.x, rest_muzzle.z - at.z).length()
		var hit: bool = _k.hits_since(1, mark).x >= 1.0
		if metres <= REACH_IN:
			q.kit.need(problems, bool(seen[who]["aimed"]) and int(seen[who]["shots"]) >= 1 and hit, "a Unit %.1f m from the aimed muzzle was not fired on and hit (%d Shots, hit %s)" % [metres, int(seen[who]["shots"]), hit])
		else:
			q.kit.need(problems, _quiet(seen, who) and not hit, "a Unit %.1f m from the aimed muzzle was aimed at or fired on" % metres)
		if is_equal_approx(metres, REACH_IN):
			q.kit.need(problems, resting > who.stats.weapon_range, "the resting muzzle reads %.2f m, not over the range: the bearing does not tell the muzzles apart" % resting)
		notes.append("%.1f m (resting muzzle %.2f): %d Shots, hit %s" % [metres, resting, int(seen[who]["shots"]), hit])
	canyon_side.restore()
	await q.kit.advance(Kit13.SETTLE)
	measured.append("reach=%s" % "|".join(notes))
	q.kit.verdict("reach", problems, "at %.0f degrees off the rest heading toward the canyon, the canyon-side Turret broken first: %s; the range is %.0f m from the aimed muzzle" % [
		REACH_DEGREES, "; ".join(notes), who.stats.weapon_range])


## sight (AC-2): what hides a target, each with the Turret that was held fire.
func _sight() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var who: Turret = _k.turret(0, Kit13.RIGHT)
	var held: PackedStringArray = []
	await _k.restore_all()
	var other: Turret = _k.turret(0, Kit13.LEFT)
	other.destroy()
	for base_index: int in Kit.PLAYERS:
		var side_turret: Turret = _k.turret(base_index, Kit13.RIGHT)
		await _k.stage(1 - base_index, Quick.MOTORBIKE, _k.w.point(base_index, BEHIND_GATE_WALL), -_k.w.way(base_index, Vector3.FORWARD))
		var seen_wall: Dictionary = await _k.watch(IDLE_WATCH)
		q.kit.need(problems, _quiet(seen_wall, side_turret), "Base %d's Turret stirred for a Unit behind its Gate wall" % [base_index + 1])
	held.append("a Base wall")
	var out: Vector3 = _k.w.way(0, Vector3.FORWARD)
	await _k.stage(1, Quick.MOTORBIKE, _k.w.point(0, BEHIND_TOWER), -out)
	var hidden_by_tower: Dictionary = await _k.watch(IDLE_WATCH)
	await _k.stage(1, Quick.MOTORBIKE, _k.w.point(0, BESIDE_TOWER), -out)
	var by_tower: Dictionary = await _k.watch(WATCH)
	q.kit.need(problems, _quiet(hidden_by_tower, who) and bool(by_tower[who]["aimed"]) and int(by_tower[who]["shots"]) >= 1, "the corner tower: behind it the Turret stirred (%s), beside it it aimed %s with %d Shots" % [not _quiet(hidden_by_tower, who), by_tower[who]["aimed"], int(by_tower[who]["shots"])])
	held.append("a corner tower")
	await _k.stage(1, Quick.MOTORBIKE, BEHIND_WRECK, Vector3.LEFT)
	var behind: Dictionary = await _k.watch(IDLE_WATCH)
	await _k.stage(1, Quick.MOTORBIKE, BESIDE_WRECK, Vector3.LEFT)
	var beside: Dictionary = await _k.watch(WATCH)
	q.kit.need(problems, _quiet(behind, who) and bool(beside[who]["aimed"]) and int(beside[who]["shots"]) >= 1, "the wreck: behind it the Turret stirred (%s), beside it it aimed %s with %d Shots" % [not _quiet(behind, who), beside[who]["aimed"], int(beside[who]["shots"])])
	held.append("the cover")
	await _k.stage(1, Quick.GYROCOPTER, WRECK, Vector3.LEFT)
	var over: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(over, who), "the Turret stirred for a Gyrocopter over the wreck")
	held.append("a Gyrocopter over a wreck")
	var panel: Structure = (load(PANEL_SCENE) as PackedScene).instantiate() as Structure
	var world: Node = q.units.units[0].get_parent()
	world.add_child(panel)
	panel.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0), _k.ahead(who, 0, PANEL_AT))
	await _k.stage(1, Quick.MOTORBIKE, _k.ahead(who, 0, AHEAD), -_k.w.way(0, Vector3.FORWARD))
	var screened: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(screened, who), "the Turret stirred for a Unit behind a Flag Wall panel in the open")
	panel.destroy()
	var exposed: Dictionary = await _k.watch(WATCH)
	q.kit.need(problems, bool(exposed[who]["aimed"]) and int(exposed[who]["shots"]) >= 1, "the Turret did not fire once the panel had fallen")
	world.remove_child(panel)
	panel.free()
	held.append("a Flag Wall")
	other.restore()
	await q.kit.advance(Kit13.SETTLE)
	await _k.stage(1, Quick.MOTORBIKE, BEHIND_TURRET, Vector3.BACK)
	var shadowed: Dictionary = await _k.watch(IDLE_WATCH)
	q.kit.need(problems, _quiet(shadowed, who), "the ridge-side Turret stirred for a Unit behind the canyon-side Turret")
	held.append("the other Turret")
	await _k.restore_all()
	var canyon_side: Turret = _k.turret(0, Kit13.LEFT)
	var facing: Vector3 = (canyon_side.global_position - CANYON_CAN).normalized()
	await _k.stage(1, Quick.MOTORBIKE, CANYON_CAN, facing)
	var before: float = canyon_side.hit_points
	var rock: Dictionary = await _k.watch(2 * WATCH, 1)
	q.kit.need(problems, _quiet(rock, canyon_side), "the canyon-side Turret aimed at or fired on a Unit at the canyon Fuel Can behind the rock")
	q.kit.need(problems, canyon_side.hit_points < before, "the Unit's Shots did not pass through the rock and hit the Turret (%.0f of %.0f hit points)" % [canyon_side.hit_points, before])
	held.append("a cliff (its Shots pass through it and hit the Turret: %.0f of %.0f hit points left)" % [canyon_side.hit_points, before])
	await _k.restore_all()
	q.kit.verdict("sight", problems, "no Turret aimed at or fired on a Unit hidden by: %s" % ", ".join(held))


## path (AC-2): the second hold, the Shot's own path to the point ahead of a moving target. A Motorbike
## is driven south along x -72 from where the ridge-side Turret sees it all the way, twice. The first
## run is the probe: it finds where the Turret's first Shot leaves and which way. In the second a Flag
## Wall panel stands PANEL_ALONG metres out on that line, across it, clear of the line to the
## Motorbike itself: the Turret sees the Motorbike, is on the aim and ready, and holds fire while the
## panel is on its Shot's path, so the panel takes nothing.
func _path() -> void:
	var problems: PackedStringArray = []
	var probe: Dictionary = await _approach(Vector3.INF, 0.0)
	var first: Dictionary = probe["first"]
	var aim: Vector3 = first.get("direction", Vector3.ZERO)
	var centre: Vector3 = first.get("muzzle", Vector3.ZERO) + aim * PANEL_ALONG
	var held: Dictionary = await _approach(centre, atan2(aim.x, aim.z))
	var stats: StructureStats = held["panel_stats"]
	_k.w.s.q.kit.need(problems, not first.is_empty() and int(held["held"]) > 0 and float(held["panel_hp"]) == stats.max_hit_points and int(held["on_panel"]) == 0, "the probe fired %s; with the panel on its path the Turret held fire for %d aimed ticks, the panel has %.0f of %.0f hit points, %d Shots ended on it" % [not first.is_empty(), int(held["held"]), float(held["panel_hp"]), stats.max_hit_points, int(held["on_panel"])])
	measured.append("path=held:%d,panel_hp:%.0f" % [int(held["held"]), float(held["panel_hp"])])
	_k.w.s.q.kit.verdict("path", problems, "a Motorbike driven south at up to %.0f m/s: the probe's first Shot left %s along %s; with a Flag Wall panel %.0f m out on that line the Turret saw the Motorbike, was on the aim and ready, and held fire for %d ticks with the panel on its Shot's path, where the probe had fired at once (the panel kept %.0f of %.0f hit points, no Shot ended on it)" % [
		_k.w.s.q.units.units[1].stats.max_speed, first.get("muzzle", Vector3.ZERO), aim, PANEL_ALONG, int(held["held"]), float(held["panel_hp"]), stats.max_hit_points])


## One run of the path check: the Turret and the Unit put as the Round has them, a panel across `at`
## (turned `yaw`) when `at` is not INF, the Motorbike driven south for PATH_TICKS. {first (the record
## of the Turret's first Shot, {} when none), shots, held (aimed ticks with the first Shot not yet
## fired and the panel on the Shot's path), on_panel (Shots that ended within a metre and a half of
## the panel), panel_hp, panel_stats}. A coroutine.
func _approach(at: Vector3, yaw: float) -> Dictionary:
	var q: Quick = _k.w.s.q
	var who: Turret = _k.turret(0, Kit13.RIGHT)
	var rules: MatchRules = q.controller.rules
	await _k.restore_all()
	_k.turret(0, Kit13.LEFT).destroy()
	var world: Node = q.units.units[0].get_parent()
	var panel: Structure = (load(PANEL_SCENE) as PackedScene).instantiate() as Structure
	world.add_child(panel)
	if at == Vector3.INF:
		panel.destroy()
	else:
		panel.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.MOTORBIKE, PATH_FROM, Vector3.FORWARD)
	var unit: Unit = q.units.units[1]
	var held: Array[int] = [0]
	q.kit.on_tick = func() -> void:
		if who.state != Turret.State.AIMING or who.aim_error > who.stats.aim_tolerance or _k.fired_since(who, mark) > 0 or not panel.is_standing:
			return
		var flat: Vector3 = Vector3(who.aim_point.x - who.global_position.x, 0.0, who.aim_point.z - who.global_position.z).normalized()
		var muzzle: Vector3 = who.global_position + flat * who.stats.muzzle_forward + Vector3.UP * rules.shooting_height
		var excluded: Array[RID] = [who.get_rid(), unit.get_rid()]
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle, who.aim_point, rules.shot_collision_mask, excluded)
		query.hit_from_inside = true
		held[0] += 1 if who.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == panel else 0
	q.harness.drive(1, 1, 0)
	await q.kit.advance(PATH_TICKS)
	q.harness.drive(1, 0, 0)
	q.kit.on_tick = Callable()
	var found: Dictionary = {"first": {}, "shots": _k.fired_since(who, mark), "held": held[0], "on_panel": 0, "panel_hp": panel.hit_points, "panel_stats": panel.stats}
	for index: int in range(mark, _k.firing.size()):
		if found["first"].is_empty() and _k.firing[index]["turret"] == who:
			found["first"] = _k.firing[index]
		var end: Vector3 = _k.firing[index]["end"]
		found["on_panel"] = int(found["on_panel"]) + (1 if end != Vector3.INF and at != Vector3.INF and Vector2(end.x - at.x, end.z - at.z).length() < PANEL_NEAR else 0)
	world.remove_child(panel)
	panel.free()
	await _k.restore_all()
	return found
