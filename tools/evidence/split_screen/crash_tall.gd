extends RefCounted
## What the crash does at each Tall kind, for the crash scenario (Story 021 AC-1 and AC-2): tall_crashes (a Gyrocopter flown
## straight at a corner tower's flat face, a water-tower leg's face, a Turret and a depot Fuel tank at full throttle, each cylinder
## on a line through its axis, for both Players at both Bases and at the depot from outside it and from its middle, is
## destroyed on the very tick the same flight with the crash switched off first touches the piece, flush against it, arriving at
## the crash speed or more), crash_costs (each of those crashes is a destruction like any other: it takes one Gyrocopter Token
## and no other, the respawn wait runs and the Player is choosing, one Explosion is made at the drawn model at the flying
## height and both views draw it, and the piece rammed is as it was: no hit point, no look, no place changed anywhere on the
## Map), two_crashes_one_tick (both Players' Gyrocopters crash on one tick and take a Token each) and reverse_crash (beyond the
## story's list: the rule reads the speed along the collision's normal whichever way the Unit travels, so a Gyrocopter backing
## tail first into a tower's face at its reverse speed, above the crash speed in the shipped data, crashes too: question 6).
## Run by crash.gd.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")

## Metres a Gyrocopter's nose runs before it meets a north tank from outside the depot, and the south tank from the depot's
## middle (the gap between the north tanks leaves no more room than this in front of the first Fuel Can's ring).
const OUTSIDE_GAP: float = 12.0
const MIDDLE_GAP: float = 4.0

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick
## What each flight showed, for the verdicts: {label, kind, problems for tall_crashes, problems for crash_costs, notes}.
var _tall_problems: PackedStringArray = []
var _cost_problems: PackedStringArray = []
var _tall_notes: PackedStringArray = []
var _cost_notes: PackedStringArray = []
var _flights: int = 0


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	var specs: Array[Dictionary] = _specs()
	await _k.walls().restore_all(true)
	await _k.walls().turrets_down()
	for spec: Dictionary in specs:
		if not bool(spec["turrets"]):
			await _crash(spec)
	await _k.walls().restore_all(true)
	for spec: Dictionary in specs:
		if bool(spec["turrets"]):
			await _crash(spec)
	measured.append("tall_flights=%d" % _flights)
	_q.kit.verdict("tall_crashes", _tall_problems, "%d Gyrocopter flights at full throttle, each judged against its control (the same flight with the crash switched off), arriving at the crash speed (%.1f m/s) or more: the Gyrocopter was destroyed on the very tick its control first touched the piece, flush against it, and at no tick before: %s" % [_flights, _k.crash_speed(), "; ".join(_tall_notes)])
	_q.kit.verdict("crash_costs", _cost_problems, "each of the %d crashes took one Gyrocopter Token and no other, started the respawn wait with the Player choosing, made one Explosion at the drawn model at the flying height that both views draw, and left every Structure of the Map (the piece rammed among them) as it was: %s" % [_flights, "; ".join(_cost_notes)])
	await _two_crashes_one_tick()
	await _reverse_crash()


## The flights, in the order they are made: {label, player, path, dir, gap, kind, turrets (whether the Turrets must stand)}.
## The towers and the legs are flown at by each Player at each Base with the Turrets down; a Turret by the Player whose Base
## it is (it does not shoot its own Player); the depot's north tanks from outside, one Player at each, and the south tank from
## its middle by each Player.
func _specs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for kind: String in ["tower", "leg"]:
		for player: int in Kit21.Kit.PLAYERS:
			for base_index: int in Kit21.Kit.PLAYERS:
				found.append({"label": "p%d at the %s of Base %d" % [player + 1, kind, base_index + 1], "player": player, "path": Kit21.path_of(kind, base_index), "dir": Kit21.toward(base_index), "gap": Kit21.RUN_UP, "kind": kind, "turrets": false})
	for player: int in Kit21.Kit.PLAYERS:
		found.append({"label": "p%d at the Turret of Base %d" % [player + 1, player + 1], "player": player, "path": Kit21.path_of("turret", player), "dir": Kit21.toward(player), "gap": Kit21.RUN_UP, "kind": "turret", "turrets": true})
	found.append({"label": "p1 at the north-west tank from outside", "player": 0, "path": Kit21.path_of(Kit21.TANKS[0]), "dir": Vector3.RIGHT, "gap": OUTSIDE_GAP, "kind": "tank", "turrets": false})
	found.append({"label": "p2 at the north-east tank from outside", "player": 1, "path": Kit21.path_of(Kit21.TANKS[1]), "dir": Vector3.LEFT, "gap": OUTSIDE_GAP, "kind": "tank", "turrets": false})
	for player: int in Kit21.Kit.PLAYERS:
		found.append({"label": "p%d at the south tank from the depot's middle" % [player + 1], "player": player, "path": Kit21.path_of(Kit21.TANKS[2]), "dir": Vector3.BACK, "gap": MIDDLE_GAP, "kind": "tank", "turrets": false})
	return found


## One flight at a piece, its control, and everything the two verdicts read off the pair.
func _crash(spec: Dictionary) -> void:
	var label: String = spec["label"]
	var player: int = spec["player"]
	var flight_line: Dictionary = _k.line(spec["path"], spec["dir"], 0.0, spec["gap"])
	var stats: UnitStats = _k.gyro_stats()
	var unit: Unit = _q.units.units[player]
	var dir: Vector3 = flight_line["dir"]
	var short_of: Vector3 = flight_line["start"] + dir * (float(flight_line["face"]) - dir.dot(flight_line["start"]) - 0.5)
	_q.kit.need(_tall_problems, _k.k.footprint_on_floor(flight_line["start"], dir, stats.collision_size) and _k.k.lane_free(flight_line["start"], short_of, stats.collision_size.x / 2.0, stats.collision_mask), "%s: the floor is missing under the Unit's footprint at the start %s or the lane to the piece is not free of other bodies" % [label, flight_line["start"]])
	var control: Dictionary = await _k.control(player, flight_line["start"], dir)
	var touch: int = int(control["hit"])
	var arrival: float = 0.0
	if touch >= 0:
		arrival = float(Watch.walls(control["rows"][touch])[0]["arrival"])
	_q.kit.need(_tall_problems, touch >= 0 and int(control["dead"]) < 0, "%s: its control (the crash off) touched at row %d and was dead at row %d" % [label, touch, control["dead"]])
	_q.kit.need(_tall_problems, arrival >= _k.crash_speed(), "%s: its control arrived at %.3f m/s, under the crash speed %.1f" % [label, arrival, _k.crash_speed()])
	var state_before: Dictionary = _k.structures_state()
	var tokens_before: int = _k.tokens(player)
	var others_before: Array[int] = _other_tokens(player)
	var records: int = _k.destroyed.size()
	var blasts_before: int = _k.blasts().size()
	var crash: Dictionary = await _k.crashing(player, flight_line["start"], dir)
	var dead: int = int(crash["dead"])
	_q.kit.need(_tall_problems, dead == touch and dead >= 0, "%s: destroyed at row %d, its control touched at row %d" % [label, dead, touch])
	_q.kit.need(_tall_problems, _k.destroyed.size() == records + 1, "%s: %d destructions were announced, expected 1" % [label, _k.destroyed.size() - records])
	var record: Dictionary = _k.destroyed[-1] if _k.destroyed.size() > records else {}
	if not record.is_empty():
		var gap: float = _k.nose_gap(record["at"], flight_line)
		_q.kit.need(_tall_problems, int(record["player"]) == player and record["type"] == stats.type_id and gap <= Kit21.FLUSH_SLACK and gap >= -Kit21.FLUSH_SLACK, "%s: destroyed as player %d, type %s, with its nose %.3f m from the face" % [label, int(record["player"]) + 1, record["type"], gap])
		_q.kit.need(_tall_problems, dead >= 0 and int(record["frame"]) == int(crash["rows"][dead]["tick"]), "%s: announced on frame %d, the Unit's row of its destruction is frame %s" % [label, record["frame"], crash["rows"][dead]["tick"] if dead >= 0 else -1])
		_tall_notes.append("%s: row %d, arrival %.2f m/s, nose %.3f m from the face" % [label, dead, arrival, gap])
	await _q.kit.advance(2)
	_judge_costs(label, player, spec, crash, record, state_before, tokens_before, others_before, blasts_before)
	_flights += 1
	_q.harness.release_all()
	if unit.is_alive:
		unit.destroy()


## The Token counts of the other types (the Gyrocopter's left out) a Player has, in the controller's order.
func _other_tokens(player: int) -> Array[int]:
	var counts: Array[int] = []
	for index: int in _q.controller.unit_types().size():
		counts.append(-1 if index == Kit21.GYRO else _k.tokens(player, index))
	return counts


## crash_costs for one crash (AC-2), read two ticks after it.
func _judge_costs(label: String, player: int, spec: Dictionary, crash: Dictionary, record: Dictionary, state_before: Dictionary, tokens_before: int, others_before: Array[int], blasts_before: int) -> void:
	var problems: PackedStringArray = _cost_problems
	_q.kit.need(problems, tokens_before - _k.tokens(player) == 1 and _other_tokens(player) == others_before, "%s: the Gyrocopter Tokens went from %d to %d and the others from %s to %s" % [label, tokens_before, _k.tokens(player), others_before, _other_tokens(player)])
	_q.kit.need(problems, not _q.controller.is_alive(player) and _q.controller.is_choosing(player) and _q.controller.seconds_until_respawn(player) > 0.0, "%s: alive %s, choosing %s, %.3f s until the respawn" % [label, _q.controller.is_alive(player), _q.controller.is_choosing(player), _q.controller.seconds_until_respawn(player)])
	var made: Array[Node] = _k.blasts()
	_q.kit.need(problems, made.size() == blasts_before + 1, "%s: %d Explosions in the tree, expected %d" % [label, made.size(), blasts_before + 1])
	var seen: String = ""
	if made.size() > blasts_before and not record.is_empty():
		var blast: Node3D = made[-1] as Node3D
		var expected: Vector3 = record["expected"]
		var box: AABB = record["box"]
		_q.kit.need(problems, blast.global_position.distance_to(expected) <= Kit21.PLACE_TOLERANCE, "%s: the Explosion is at %s, the story puts it at %s" % [label, blast.global_position, expected])
		_q.kit.need(problems, expected.y >= box.position.y and expected.y <= box.end.y and expected.y > _k.k.height, "%s: the centre %.3f m is outside the drawn model (%.3f to %.3f m) or under the flying height %.3f m" % [label, expected.y, box.position.y, box.end.y, _k.k.height])
		var views: PackedStringArray = []
		for viewer: int in Kit21.Kit.PLAYERS:
			var drawn: Dictionary = _k.pieces_seen_by(blast, _q.units.cameras[viewer])
			_q.kit.need(problems, int(drawn["total"]) > 0 and drawn["drawn"] == drawn["total"], "%s: player %d's view draws %d of the Explosion's %d pieces" % [label, viewer + 1, drawn["drawn"], drawn["total"]])
			views.append("%d of %d" % [drawn["drawn"], drawn["total"]])
		seen = ", centre %.3f m, pieces drawn %s" % [blast.global_position.y, " / ".join(views)]
	var after: Dictionary = _k.structures_state()
	var changed: PackedStringArray = []
	for path: String in state_before:
		if str(state_before[path]) != str(after.get(path)):
			changed.append(path)
	_q.kit.need(problems, changed.is_empty() and after.size() == state_before.size(), "%s: %d of %d Structures changed (%s)" % [label, changed.size(), state_before.size(), ", ".join(changed.slice(0, 3))])
	if spec["kind"] == "turret":
		var turret: Structure = _k.map().get_node(spec["path"]) as Structure
		_q.kit.need(problems, is_equal_approx(turret.hit_points, turret.stats.max_hit_points) and turret.is_standing, "%s: the Turret has %.1f of %.1f hit points" % [label, turret.hit_points, turret.stats.max_hit_points])
	_cost_notes.append("%s: Token %d to %d%s" % [label, tokens_before, _k.tokens(player), seen])


## reverse_crash (beyond the story's list, question 6): the corner tower's face flown at tail first, at the full reverse key. The
## Gyrocopter's reverse speed (data) arrives at the face, the same flight with the crash off first touches it on the very tick
## the crash destroys it, and it takes one Gyrocopter Token: backing into a Tall piece at speed crashes it as flying does.
func _reverse_crash() -> void:
	var problems: PackedStringArray = []
	var flight_line: Dictionary = _k.line(Kit21.path_of("tower", 0), Kit21.toward(0))
	var tail_first: Vector3 = -(flight_line["dir"] as Vector3)
	var reverse_top: float = _k.gyro_stats().reverse_max_speed
	var control: Dictionary = await _k.control(0, flight_line["start"], tail_first, -1.0)
	var touch: int = int(control["hit"])
	var arrival: float = float(Watch.walls(control["rows"][touch])[0]["arrival"]) if touch >= 0 else 0.0
	_q.kit.need(problems, touch >= 0 and int(control["dead"]) < 0 and absf(arrival - reverse_top) <= 0.02, "the control (the crash off) touched at row %d, dead at row %d, arriving at %.3f m/s, the reverse speed being %.1f" % [touch, control["dead"], arrival, reverse_top])
	_q.kit.need(problems, reverse_top >= _k.crash_speed(), "the reverse speed %.1f m/s is under the crash speed %.1f: the premise of the check fails" % [reverse_top, _k.crash_speed()])
	var tokens_before: int = _k.tokens(0)
	var records: int = _k.destroyed.size()
	var crash: Dictionary = await _k.crashing(0, flight_line["start"], tail_first, -1.0)
	var dead: int = int(crash["dead"])
	_q.kit.need(problems, dead == touch and dead >= 0, "destroyed at row %d, its control touched at row %d" % [dead, touch])
	_q.kit.need(problems, _k.destroyed.size() == records + 1 and tokens_before - _k.tokens(0) == 1, "%d destructions were announced and the Gyrocopter Tokens went from %d to %d" % [_k.destroyed.size() - records, tokens_before, _k.tokens(0)])
	_q.harness.release_all()
	await _q.kit.advance(2)
	measured.append("reverse_arrival=%.2f" % arrival)
	_q.kit.verdict("reverse_crash", problems, "backing tail first into the corner tower's face at the full reverse key, the Gyrocopter arrived at %.2f m/s (its reverse speed, %.1f m/s, above the crash speed %.1f) and was destroyed on row %d, the tick its control with the crash off first touched the face, taking one Gyrocopter Token: the rule reads the speed along the normal whichever way the Unit travels" % [arrival, reverse_top, _k.crash_speed(), dead])


## two_crashes_one_tick (AC-2): both Players' Gyrocopters fly at the corner tower of the Base ahead of them, mirror images of
## one another, and are destroyed on the same physics frame, each taking its own Gyrocopter Token.
func _two_crashes_one_tick() -> void:
	var problems: PackedStringArray = []
	for player: int in Kit21.Kit.PLAYERS:
		await _k.mines().revive(player)
	var lines: Array[Dictionary] = []
	for player: int in Kit21.Kit.PLAYERS:
		lines.append(_k.line(Kit21.path_of("tower", player), Kit21.toward(player)))
	await _q.map.stage([Kit21.GYRO, Kit21.GYRO], [lines[0]["start"], lines[1]["start"]], [lines[0]["dir"], lines[1]["dir"]], true)
	var before: Array[int] = [_k.tokens(0), _k.tokens(1)]
	var records: int = _k.destroyed.size()
	_k.watch.clear()
	_k.watch.logging = true
	for _tick: int in Kit21.FLIGHT_LIMIT:
		_q.harness.drive(0, 1, 0)
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
		if not _q.units.units[0].is_alive and not _q.units.units[1].is_alive:
			break
	_k.watch.logging = false
	_q.harness.release_all()
	await _q.kit.advance(2)
	var made: Array[Dictionary] = _k.destroyed.slice(records)
	_q.kit.need(problems, made.size() == 2 and made[0]["frame"] == made[1]["frame"] and made[0]["player"] != made[1]["player"], "the destructions were %s" % [made.map(func(d: Dictionary) -> String: return "p%d on frame %d" % [int(d["player"]) + 1, d["frame"]])])
	_q.kit.need(problems, before[0] - _k.tokens(0) == 1 and before[1] - _k.tokens(1) == 1, "the Gyrocopter Tokens went from %s to [%d, %d]" % [before, _k.tokens(0), _k.tokens(1)])
	_q.kit.need(problems, not _q.controller.is_round_over(), "the Round is over after two crashes")
	measured.append("pair_frame=%d" % (made[0]["frame"] if not made.is_empty() else -1))
	_q.kit.verdict("two_crashes_one_tick", problems, "both Players' Gyrocopters, flown at the corner tower of the Base ahead of them from mirrored starts, were destroyed on one physics frame (%s), each took one Gyrocopter Token (%s to [%d, %d]) and the Round went on" % [made.map(func(d: Dictionary) -> String: return str(d["frame"])), before, _k.tokens(0), _k.tokens(1)])
