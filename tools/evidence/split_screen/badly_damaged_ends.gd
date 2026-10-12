extends RefCounted
## How the state ends (Story 017 AC-1 and AC-5, with the smoke of AC-4): a badly damaged Unit destroyed by a Unit's Shot, a Turret's Shot,
## a Mine, a Self-destruct and the Gyrocopter's Fuel crash explodes as Story 016 built, its Token is taken, and in the physics frame of the
## destruction (before the Round files it) the state ends and the smoke is gone, so none hangs over the wreck and only the explosion's
## smoke remains; a Unit healthy until a Mine, a Self-destruct or the crash takes it passes through no state; a Swap at the own Base puts a
## badly damaged Unit away with no Explosion and the next Unit starts whole, out of the state, at full speed; so does a respawn. Run by
## badly_damaged.gd. Tooling only. Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-1, AC-4 and AC-5.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## Ticks a staged badly damaged Unit smokes before its cause comes, and the ticks the smoke is watched after the destruction.
const SMOKE_TICKS: int = 20
const AFTER_TICKS: int = 12
## The share of its tank a Gyrocopter that must run dry soon spawns with, and the hit points a victim is left with so one Shot kills it.
const SMALL_TANK: float = 0.005
const ONE_SHOT: float = 1.0
## The hit points of the frail copy a Motorbike's Shot takes whole.
const FRAIL_HIT_POINTS: float = 4.0

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _every_cause()
	await _healthy_passes_through_no_state()
	await _spawn_in_place()
	await _swap()
	await _respawn()


## One route to a destruction of Player 2's Unit of a type, staged with it badly damaged and smoking (or, for `healthy`, whole): the
## record of what was seen {pre, destroyed, change, counts}.
func _route(route: String, type: int, healthy: bool = false) -> Dictionary:
	await _k.e.fresh()
	var dmark: int = _k.e.destroyed.size()
	var counts: Array = _q.tokens.counts()
	var victim: Unit = _k.unit(1)
	var low: float = ONE_SHOT if route == "shot" else _k.edge_of(type)
	if route == "turret":
		var turret: Turret = _k.t.turret(0, Kit13.RIGHT)
		await _k.t.stage(1, type, _k.t.ahead(turret, 0, _k.e.TURRET_AHEAD), -_k.t.w.way(0, Vector3.FORWARD))
	elif route == "fuel_crash":
		await _k.t.clear(0)
		await _q.put(1, _q.small_tank(type, SMALL_TANK), Vector3(Kit17.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	else:
		await _k.face_off(Quick.MOTORBIKE, type)
	var mark: int = _k.changes.size()
	if not healthy:
		victim.apply_damage(victim.hit_points - low)
	var mine: Mine = null
	if route == "mine":
		mine = await _k.e.live_mine(Vector3.ZERO, 0)
		victim.global_transform = _q.units.pose(Vector3(Kit17.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	await _q.kit.advance(SMOKE_TICKS if route == "shot" or route == "self_destruct" or route == "mine" else 1)
	var pre: Dictionary = {"badly": victim.is_badly_damaged, "smoking": _k.smoking(1), "hp": victim.hit_points}
	match route:
		"shot":
			await _q.tokens.shoot(0)
		"self_destruct":
			await _q.tokens.destruct(1)
		"mine":
			victim.global_transform = _q.units.pose(Vector3.ZERO, Vector3.LEFT)
			victim.reset_motion()
	await _k.e.wait_destroyed(dmark)
	if mine != null and is_instance_valid(mine):
		mine.queue_free()
	var record: Dictionary = _k.e.destroyed[dmark] if _k.e.destroyed.size() > dmark else {}
	var after: Array = _q.tokens.counts()
	var shown: int = _k.smoke(1).shown_count() if _k.smoke(1) != null else 0
	await _q.kit.advance(AFTER_TICKS)
	var late: int = _k.smoke(1).shown_count() if _k.smoke(1) != null else 0
	return {"pre": pre, "destroyed": record, "changes": _k.changes_of(1, mark), "tokens": counts[1][type] - after[1][type], "shown": shown, "late": late, "smoking": _k.smoking(1), "playing": _k.e.playing().size()}


## ends_with_the_unit_in_the_frame_of_the_destruction: every cause, every type it can happen to.
func _every_cause() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var cases: Array[Array] = []
	for route: String in ["shot", "turret", "self_destruct"]:
		for type: int in 4:
			cases.append([route, type])
	cases.append_array([["mine", Quick.MOTORBIKE], ["mine", Quick.TRUCK], ["fuel_crash", Quick.GYROCOPTER]])
	for case: Array in cases:
		var seen: Dictionary = await _route(case[0], case[1])
		var label: String = "%s %s" % [Units.TYPE_IDS[case[1]], case[0]]
		var d: Dictionary = seen["destroyed"]
		var made: Array[Dictionary] = seen["changes"]
		_q.kit.need(problems, seen["pre"]["badly"] and (seen["pre"]["smoking"] or case[0] == "fuel_crash"), "%s: not badly damaged and smoking before its cause came (%s)" % [label, seen["pre"]])
		_q.kit.need(problems, not d.is_empty() and not d["blast"].is_empty() and seen["tokens"] == 1, "%s: no destruction, or no Explosion, or %s Tokens taken" % [label, seen["tokens"]])
		if d.is_empty() or made.is_empty():
			problems.append("%s: no record to read" % label)
			continue
		var last: Dictionary = made[-1]
		_q.kit.need(problems, made.size() == 2 and made[0]["state"] and not last["state"], "%s: the changes were %s, not [on, off]" % [label, made.map(func(c: Dictionary) -> bool: return c["state"])])
		_q.kit.need(problems, last["frame"] == d["frame"] and last["destroyed_seen"] == _k.e.destroyed.find(d) and not last["alive"] and not last["badly"], "%s: the state ended in frame %s (the destruction in %s), after %d filed destructions (it is number %d)" % [label, last["frame"], d["frame"], last["destroyed_seen"], _k.e.destroyed.find(d)])
		_q.kit.need(problems, seen["shown"] == 0 and seen["late"] == 0 and not seen["smoking"], "%s: %d puffs left at the destruction, %d later" % [label, seen["shown"], seen["late"]])
		notes.append("%s: off in frame %d, before the Round filed it" % [label, d["frame"]])
	_q.kit.verdict("state_and_smoke_end_in_the_frame_of_the_destruction", problems, "%d destructions (a Unit's Shot, a Turret's, a Self-destruct for each type, a Mine for two, the Gyrocopter's crash), each with its Explosion and one Token: %s" % [cases.size(), " | ".join(notes)])


## healthy_passes_through_no_state: a Mine, a Self-destruct, the Fuel crash and a lethal Shot take a whole Unit with no change signalled, no node.
func _healthy_passes_through_no_state() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _lethal_shot_from_whole(problems, notes)
	for case: Array in [["mine", Quick.BUGGY], ["self_destruct", Quick.TRUCK], ["fuel_crash", Quick.GYROCOPTER]]:
		var seen: Dictionary = await _route(case[0], case[1], true)
		var label: String = "%s %s" % [Units.TYPE_IDS[case[1]], case[0]]
		_q.kit.need(problems, not seen["destroyed"].is_empty() and not seen["destroyed"]["blast"].is_empty(), "%s: no destruction or no Explosion" % label)
		_q.kit.need(problems, seen["changes"].is_empty() and not seen["pre"]["badly"] and _k.smoke(1) == null, "%s: %d changes signalled, node %s" % [label, seen["changes"].size(), _k.smoke(1)])
		notes.append("%s: no change signalled, no smoke node" % label)
	_q.kit.verdict("whole_unit_destroyed_at_once_passes_no_state", problems, " | ".join(notes))


## A copy of the Motorbike's stats with so few hit points that one Motorbike Shot (5) kills it whole: Player 2's Unit as that copy is taken by Player 1's
## real Shot with no change signalled and no smoke node. Adds its findings to the lists of the check that calls it.
func _lethal_shot_from_whole(problems: PackedStringArray, notes: PackedStringArray) -> void:
	await _k.face_off(Quick.MOTORBIKE, Quick.MOTORBIKE)
	var frail: UnitStats = _q.small_tank(Quick.MOTORBIKE, 1.0)
	frail.max_hit_points = FRAIL_HIT_POINTS
	await _q.put(1, frail, Vector3(Kit17.DUEL_X, 0.0, 0.0), Vector3.LEFT)
	var dmark: int = _k.e.destroyed.size()
	var mark: int = _k.changes.size()
	await _q.tokens.shoot(0)
	await _k.e.wait_destroyed(dmark)
	_q.kit.need(problems, _k.e.destroyed.size() > dmark and _k.e.destroyed[dmark]["type"] == &"motorbike" and not _k.e.destroyed[dmark]["blast"].is_empty(), "the lethal Shot's destruction or its Explosion did not come")
	_q.kit.need(problems, _k.changes_of(1, mark).is_empty() and _k.smoke(1) == null, "a lethal Shot from whole signalled %d changes, node %s" % [_k.changes_of(1, mark).size(), _k.smoke(1)])
	notes.append("a Motorbike of %s hit points taken whole by one Shot (5): no change signalled, no smoke node" % FRAIL_HIT_POINTS)


## spawn_in_place_ends_the_state: spawn() on a badly damaged live Unit with no new stats (the Model stays) puts it back whole in the frame it ends
## the state and its smoke.
func _spawn_in_place() -> void:
	var problems: PackedStringArray = []
	await _k.face_off(Quick.MOTORBIKE, Quick.BUGGY)
	var victim: Unit = _k.unit(1)
	victim.apply_damage(victim.hit_points - _k.edge_of(Quick.BUGGY))
	await _q.kit.advance(SMOKE_TICKS)
	var smoke: BadlyDamagedSmoke = _k.smoke(1)
	_q.kit.need(problems, smoke != null and smoke.is_smoking(), "the Buggy does not smoke before the spawn")
	var mark: int = _k.changes.size()
	victim.spawn(victim.global_transform)
	await _q.kit.advance(2)
	var made: Array[Dictionary] = _k.changes_of(1, mark)
	_q.kit.need(problems, made.size() == 1 and not made[0]["state"] and made[0]["hp"] == victim.stats.max_hit_points, "the spawn made the changes %s" % [made])
	_q.kit.need(problems, victim.get_node(String(Unit.MODEL_NODE_NAME)).get_node_or_null(String(UnitModel.SMOKE_NODE_NAME)) == smoke and not smoke.is_smoking() and smoke.shown_count() == 0 and not victim.is_badly_damaged, "the smoke stands or the Unit is not whole after the spawn")
	_q.kit.verdict("spawn_in_place_ends_the_state", problems, "spawn() on a badly damaged Buggy with no new stats (its Model and its smoke node stay) put it back at %s hit points: the state and the smoke ended in that frame, %d puffs left" % [victim.hit_points, smoke.shown_count()])


## swap_puts_a_badly_damaged_unit_away_clean: a Swap at the own Base is no destruction (no Explosion, no Token), the bench ends the state
## and the smoke in its tick, and the Unit chosen next is whole at full speed with no smoke.
func _swap() -> void:
	var problems: PackedStringArray = []
	await _k.e.fresh()
	var s: Object = _k.t.w.s
	var victim: Unit = _k.unit(1)
	_q.units.retype(1, Quick.TRUCK, s.outside_point(1), s.gate_way(1))
	await _q.kit.advance(Kit17.SETTLE)
	victim.apply_damage(victim.hit_points - _k.edge_of(Quick.TRUCK))
	await s.enter(1)
	var latency: int = await s.wait_swappable(1)
	var mark: int = _k.changes.size()
	var blasts: int = _k.e.blasts.size()
	var swaps: int = s.swaps.size()
	var counts: Array = _q.tokens.counts()
	var smoking_before: bool = _k.smoking(1)
	await _q.tokens.destruct(1)
	await _q.kit.advance(2)
	var made: Array[Dictionary] = _k.changes_of(1, mark)
	_q.kit.need(problems, latency >= 0 and smoking_before and s.swaps.size() == swaps + 1, "the Swap did not happen (zone %d, smoking %s, swaps +%d)" % [latency, smoking_before, s.swaps.size() - swaps])
	_q.kit.need(problems, made.size() == 1 and not made[0]["state"] and not made[0]["alive"] and made[0]["tick"] == s.swaps[-1]["tick"] and not _k.smoking(1), "the bench's changes: %s (swap at tick %s)" % [made, s.swaps[-1]["tick"]])
	_q.kit.need(problems, _k.e.blasts.size() == blasts and _q.tokens.counts() == counts, "a Swap made %d Explosions and changed the Tokens" % (_k.e.blasts.size() - blasts))
	_q.kit.need(problems, await _q.tokens.spawn(1, Quick.MOTORBIKE), "Player 2's next Unit did not come")
	await _q.kit.advance(Kit17.SETTLE)
	var fresh: Dictionary = await _whole(1, Quick.MOTORBIKE)
	_q.kit.need(problems, fresh["whole"], "the Unit after the Swap: %s" % fresh)
	_q.kit.verdict("swap_puts_a_badly_damaged_unit_away_clean", problems, "a badly damaged Truck put away by the Self-destruct key inside its Base: state and smoke ended in the tick of the bench (tick %d), no Explosion, no Token; the Motorbike chosen next had %s hit points, no state, no smoke node and drove at %s m/s" % [s.swaps[-1]["tick"], fresh["hp"], fresh["speed"]])


## respawn_starts_whole: destroyed badly damaged, the Unit chosen at the respawn is whole at full speed with no smoke.
func _respawn() -> void:
	var problems: PackedStringArray = []
	var seen: Dictionary = await _route("shot", Quick.GYROCOPTER)
	_q.kit.need(problems, not seen["destroyed"].is_empty(), "no destruction")
	_q.kit.need(problems, await _q.tokens.spawn(1, Quick.BUGGY), "Player 2's Unit did not respawn")
	await _q.kit.advance(Kit17.SETTLE)
	var fresh: Dictionary = await _whole(1, Quick.BUGGY)
	_q.kit.need(problems, fresh["whole"], "the Unit after the respawn: %s" % fresh)
	_q.kit.verdict("respawn_starts_whole", problems, "a badly damaged Gyrocopter destroyed by a Shot; the Buggy chosen at the respawn had %s hit points, no state, no smoke and drove at %s m/s" % [fresh["hp"], fresh["speed"]])


## Whether a Player's Unit just put in play is whole: full hit points, out of the state, no smoke showing, and at its full speed after
## a drive on the arena.
func _whole(player: int, type: int) -> Dictionary:
	var unit: Unit = _k.unit(player)
	var stats: UnitStats = _q.units.stats(type)
	var clean: bool = unit.hit_points == stats.max_hit_points and not unit.is_badly_damaged and not _k.smoking(player)
	_k.make_floor()
	await _k.on_floor(player, _q.small_tank(type, 1.0))
	await _k.series(player, 1, 0, Kit17.STEADY_TICKS)
	var speed: float = unit.current_speed
	_q.harness.drive(player, 0, 0)
	_k.free_floor()
	return {"whole": clean and absf(speed - stats.max_speed) <= Kit17.TOLERANCE, "hp": stats.max_hit_points if clean else unit.hit_points, "speed": speed}
