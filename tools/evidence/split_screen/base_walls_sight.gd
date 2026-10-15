extends RefCounted
## turret_sight, for the base_walls scenario (Story 018 AC-5): the middle panel of a Gate wall hides the yard
## from the Turret in front of it. At each Base, for each of its two Turrets (the other one down, as a tool may),
## the other Player's Truck stands in the yard where that Turret's sight line crosses the panel, inside its range:
## with the panel standing the Turret neither sees it, nor turns, nor fires; with the panel fallen it sees it
## through the breach, turns on it, fires, and its Shot reaches the Truck. Then all four panels are brought down,
## a Round is won and R pressed, and the restored panels hide the Truck again. Run by base_walls.gd. Tooling
## only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Wall that is broken to take the Flag.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")

## How far into the yard the target stands, Base-local z, metres; its x is its Turret's.
const SPOT_Z: float = -5.0
## Ticks a Turret is watched for: a half turn at its turn rate, the cadence and the Shot's flight, with a margin.
const WATCH_TICKS: int = 300
## A Shot's end may lie this far, metres, outside the half diagonal of the Truck's box and still be a hit.
const REACH_SLACK: float = 0.5

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick
var _problems: PackedStringArray = []
## What the checks found, for the verdict: the range, the ticks and the Shots of each Turret.
var _notes: PackedStringArray = []


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	for base_index: int in Kit.PLAYERS:
		for side: int in Kit18.TURRET_NAMES.size():
			await _k.restore_all(true)
			await _hidden(base_index, side, "standing")
			_panel(base_index, side).destroy()
			await _seen(base_index, side)
	await _k.restore_all(true)
	for base_index: int in Kit.PLAYERS:
		for side: int in Kit18.TURRET_NAMES.size():
			_panel(base_index, side).destroy()
	await _round_and_r()
	for base_index: int in Kit.PLAYERS:
		for side: int in Kit18.TURRET_NAMES.size():
			await _hidden(base_index, side, "after R")
	measured.append("sight_turrets=4")
	_q.kit.verdict("turret_sight", _problems, "at both Bases, for both Turrets (the other one down), the other Player's Truck stood in the yard where the sight line crosses the middle panel of the Gate wall in front of the Turret, inside its range: standing, the panel was the first thing the sight ray met and the Turret stayed idle (not aimed, head still, no Shot, the Truck unhurt) for %d ticks; fallen, the ray met the Truck and the Turret turned on it, fired and hurt it; after the four panels were brought down, a Round won and R pressed, the panels stood again and hid it again (%s)" % [WATCH_TICKS, "; ".join(_notes)])


## The middle panel of the Gate wall in front of a Turret: the Gate wall on the Turret's side of the Gate, the panel
## in the middle of its run.
func _panel(base_index: int, side: int) -> Structure:
	return _k.panel(base_index, _run_of(base_index, side), _middle(_run_of(base_index, side)))


func _run_of(base_index: int, side: int) -> int:
	return Kit18.GATE_LEFT if _spot_local(base_index, side).x < 0.0 else Kit18.GATE_RIGHT


@warning_ignore("integer_division")
func _middle(run: int) -> int:
	return Kit18.COUNTS[run] / 2


## Where the target stands, Base-local: behind the Turret, in the yard.
func _spot_local(base_index: int, side: int) -> Vector3:
	var turret_at: Vector3 = _k.m.w.bases[base_index].to_local(_k.turret(base_index, side).global_position)
	return Vector3(turret_at.x, 0.0, SPOT_Z)


## The collider a Turret's sight ray meets first on its way to a Unit's centre, built as the Turret builds it
## (Turret._sees): from the muzzle, muzzle_forward out toward the target at the shooting height, to the target's
## centre at that height, on the Shot's mask plus the cliffs, the Turret's own body left out. {hit, range}.
func _probe(turret: Turret, target: Unit) -> Dictionary:
	var rules: MatchRules = _q.controller.rules
	var data: TurretStats = turret.stats as TurretStats
	var centre: Vector3 = Vector3(target.global_position.x, rules.shooting_height, target.global_position.z)
	var flat: Vector3 = Vector3(centre.x - turret.global_position.x, 0.0, centre.z - turret.global_position.z).normalized()
	var muzzle: Vector3 = turret.global_position + flat * data.muzzle_forward + Vector3.UP * rules.shooting_height
	var excluded: Array[RID] = [turret.get_rid()]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(muzzle, centre, rules.shot_collision_mask | data.sight_extra_mask, excluded)
	query.hit_from_inside = true
	var hit: Dictionary = turret.get_world_3d().direct_space_state.intersect_ray(query)
	return {"hit": hit.get("collider"), "range": muzzle.distance_to(centre), "limit": data.weapon_range}


## The other Player's Truck is put in the yard behind a Turret, the Turret's twin taken down so that this Turret
## alone can see it (and the Turret itself stood up again if the previous case took it down as a twin).
func _stage(base_index: int, side: int) -> Unit:
	if not _k.turret(base_index, side).is_standing:
		_k.turret(base_index, side).restore()
	_k.turret(base_index, 1 - side).destroy()
	var victim: int = 1 - base_index
	await _k.stage(victim, Quick.TRUCK, _k.m.w.point(base_index, _spot_local(base_index, side)), _k.m.w.way(base_index, Vector3.BACK))
	return _q.units.units[victim]


## hidden (standing, or after R): the panel is the first thing the Turret's sight ray meets, and for WATCH_TICKS
## ticks the Turret does not aim, turn or fire and the Truck takes nothing.
func _hidden(base_index: int, side: int, when: String) -> void:
	var label: String = "%s Turret %d, %s" % [_k.m.w.bases[base_index].name, side + 1, when]
	var turret: Turret = _k.turret(base_index, side)
	var panel: Structure = _panel(base_index, side)
	var truck: Unit = await _stage(base_index, side)
	var probe: Dictionary = _probe(turret, truck)
	_q.kit.need(_problems, panel.is_standing and probe["hit"] == panel and float(probe["range"]) <= float(probe["limit"]), "%s: the sight ray's first hit is %s (the panel stands %s), %.1f m of a %.0f m range" % [label, probe["hit"], panel.is_standing, probe["range"], probe["limit"]])
	var yaw: float = turret.head.rotation.y
	var seen: Dictionary = await _k.watch(WATCH_TICKS)
	_q.kit.need(_problems, not bool(seen[turret]["aimed"]) and int(seen[turret]["shots"]) == 0 and turret.state == Turret.State.IDLE and is_equal_approx(turret.head.rotation.y, yaw), "%s: the Turret aimed %s, fired %d Shots, is %s, turned %.3f rad" % [label, seen[turret]["aimed"], seen[turret]["shots"], turret.state, turret.head.rotation.y - yaw])
	_q.kit.need(_problems, truck.is_alive and is_equal_approx(truck.hit_points, truck.stats.max_hit_points), "%s: the Truck has %.1f of %.1f hit points" % [label, truck.hit_points, truck.stats.max_hit_points])
	if when == "standing":
		_notes.append("%s %.1f m" % [label.get_slice(",", 0), float(probe["range"])])


## seen (the panel fallen): the sight ray meets the Truck, and the Turret aims, fires and hurts it with a Shot that
## ends on its box.
func _seen(base_index: int, side: int) -> void:
	var label: String = "%s Turret %d, panel fallen" % [_k.m.w.bases[base_index].name, side + 1]
	var turret: Turret = _k.turret(base_index, side)
	var truck: Unit = await _stage(base_index, side)
	await _q.kit.advance(Kit18.SETTLE)
	var probe: Dictionary = _probe(turret, truck)
	_q.kit.need(_problems, not _panel(base_index, side).is_standing and probe["hit"] == truck, "%s: the sight ray's first hit is %s, not the Truck" % [label, probe["hit"]])
	var hp: float = truck.hit_points
	var mark: int = _k.fired.size()
	var seen: Dictionary = await _k.watch(WATCH_TICKS)
	var half_diagonal: float = Vector2(truck.stats.collision_size.x, truck.stats.collision_size.z).length() / 2.0
	var ends: int = 0
	for index: int in range(mark, _k.fired.size()):
		var end: Vector3 = _k.fired[index]["end"]
		ends += 1 if _k.fired[index]["turret"] == turret and end != Vector3.INF and Vector2(end.x - truck.global_position.x, end.z - truck.global_position.z).length() <= half_diagonal + REACH_SLACK else 0
	_q.kit.need(_problems, bool(seen[turret]["aimed"]) and int(seen[turret]["shots"]) >= 1 and ends >= 1 and truck.hit_points < hp, "%s: aimed %s, %d Shots (%d ended on the Truck), the Truck lost %.1f hit points" % [label, seen[turret]["aimed"], seen[turret]["shots"], ends, hp - truck.hit_points])
	_notes.append("%s fired %d, %d on the Truck, -%.0f hit points" % [label.get_slice(",", 0), int(seen[turret]["shots"]), ends, hp - truck.hit_points])


## A Round is won for Player 1 (Base B's Turrets down and its Gate-side Flag Wall broken so the Motorbike can take the
## Flag, then in through Base A's Gate) and R pressed: every piece is back, the Units benched first.
func _round_and_r() -> void:
	var s: Object = _k.m.w.s
	await _k.turrets_down()
	_k.m.w.wall(1, Walls.GATE).destroy()
	var carries: bool = await _k.m.w.take_flag(0, 1, Walls.GATE)
	var won: bool = await _k.m.w.deliver(0) and s.controller.winner_index() == 0
	_q.kit.need(_problems, carries and won, "the Round was not won by Player 1 (the Flag taken %s, won %s)" % [carries, won])
	await _k.m.w.restart()
	var standing: int = 0
	for base_index: int in Kit.PLAYERS:
		for side: int in Kit18.TURRET_NAMES.size():
			standing += 1 if _panel(base_index, side).is_standing and _k.turret(base_index, side).is_standing else 0
	_q.kit.need(_problems, standing == 4, "after R %d of the four panels and Turrets in question stand with their Turrets, not 4" % standing)
