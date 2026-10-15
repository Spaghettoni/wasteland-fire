extends RefCounted
## What flies over a Garage panel and a field panel, and what stays Cover, for the garage_scrap_walls scenario
## (Story 019 AC-2): drawn_height (a Gyrocopter chosen with the real keys appears on each Garage spot of both
## Bases, beside a Garage wall its model's rise now sees; its lowest point is read on the spawn tick and over the next
## second: the temporary look that story 020 replaces with one flying height), gyro_over (a Gyrocopter flies out of its
## Garage over the back wall and each side wall, into it over a side wall from the yard, and over a field wall from
## outside and from inside, at full speed, its model rising over the 2 m top and settling back), stopped_by (a corner
## tower and a leg of the water tower still stop it). Run by garage_scrap_walls.gd. Tooling only. Every number comes
## from the game's data; the scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## Ticks of the drawn height's record after the spawn tick: a second.
const RECORD_TICKS: int = 120
## The ticks a flight may take.
const RUN_LIMIT_TICKS: int = 420
## Metres past the far face where a crossing is over, the least share of its top speed a Gyrocopter keeps over a
## panel, and how far under the rise clearance its model may come, metres.
const PAST: float = 6.0
const SPEED_SHARE: float = 0.9
const RISE_SLACK: float = 0.02
## How far under the speed it had when its model first came over the panel a Gyrocopter may slow (m/s): it is
## accelerating then, so a run too short to reach SPEED_SHARE of the top speed (the yard beside a Garage is 7.7 m
## wide) is judged by not losing speed over the panel.
const SLOW_SLACK: float = 0.05
## The tolerance of a measured height, metres.
const TOLERANCE: float = 0.001
## The face a Gyrocopter flown at a corner tower or at a water tower leg meets first, Base-local metres (the tower's
## outer face on the side wall's axis, at z 15; the leg's Gate-side face), and how far short of it, past its half
## length, the Gyrocopter may stop.
const TOWER_FACE_X: float = -18.15
const TOWER_Z: float = 15.0
const LEG_FACE_Z: float = -9.3
const FACE_SLACK: float = 0.15

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick
## The lowest point and the top of the Gyrocopter being recorded, one entry per tick from the tick it is in play.
var _lows: Array[float] = []
var _tops: Array[float] = []
## Per Player: the ticks its model was over the piece it crosses, the least height of its lowest point over that
## piece's top then, and its slowest real speed then (logged by _cross_tick()).
var _over: Array[int] = [0, 0]
var _clear: Array[float] = [INF, INF]
var _slowest: Array[float] = [INF, INF]
var _entry: Array[float] = [INF, INF]
var _piece: Array[MeshInstance3D] = [null, null]


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _drawn_height()
	await _gyro_over()
	await _stopped_by()


## Logs the lowest point and the top of Player `player`'s model each tick once its Unit is in play.
func _record(player: int) -> void:
	var unit: Unit = _q.units.units[player]
	if unit.is_alive:
		var box: AABB = Quick.model_box(unit)
		_lows.append(box.position.y)
		_tops.append(box.end.y)


## The Gyrocopter's model of a Player.
func _model(player: int) -> UnitModel:
	return _q.units.units[player].get_node(NodePath(String(Unit.MODEL_NODE_NAME))) as UnitModel


## drawn_height (AC-2): per Base and spot, the Player's Unit is destroyed with its real key, the other Player's Unit is put
## on the first spot when the second is wanted (the respawn then takes the spare one), the Gyrocopter is chosen with the
## real keys and recorded from the tick it is in play. A Gyrocopter chosen at the same spawn in the open (a tool puts it
## down, as nothing spawns there) is the reference: its model stays at the hover.
func _drawn_height() -> void:
	var problems: PackedStringArray = []
	await _k.k.m.revive(0)
	await _k.k.m.w.park(1)
	_q.units.retype(0, Quick.GYROCOPTER, Quick.LANE_SPOT, Vector3.RIGHT)
	_lows = []
	_tops = []
	_q.kit.on_tick = _record.bind(0)
	await _q.kit.advance(RECORD_TICKS)
	_q.kit.on_tick = Callable()
	var rest: float = _lows[0]
	var rest_top: float = _tops[0]
	var rest_worst: float = 0.0
	for low: float in _lows:
		rest_worst = maxf(rest_worst, absf(low - rest))
	_q.kit.need(problems, rest_worst <= TOLERANCE, "the Gyrocopter in the open moved %.4f m up or down" % rest_worst)
	var rise_rate: float = _model(0).rise_rate
	var rate: float = rise_rate / float(Engine.physics_ticks_per_second)
	var notes: PackedStringArray = []
	var steps: int = 0
	var final_low: float = 0.0
	for base_index: int in Kit.PLAYERS:
		var base: Base = _k.k.m.w.bases[base_index]
		for spot_index: int in 2:
			var marker: Marker3D = base.spawn_point if spot_index == 0 else base.spare_spawn_points[0]
			await _k.k.m.revive(base_index)
			await _k.k.m.w.park(1 - base_index)
			if spot_index == 1:
				_k.k.m.w.s.flags.teleport(1 - base_index, base.spawn_point.global_position, -base.spawn_point.global_transform.basis.z)
				await _q.kit.advance(Kit19.Kit18.SETTLE)
			await _q.tokens.destruct(base_index)
			_lows = []
			_tops = []
			_q.kit.on_tick = _record.bind(base_index)
			var came: bool = await _q.tokens.spawn(base_index, Quick.GYROCOPTER)
			await _q.kit.advance(RECORD_TICKS)
			_q.kit.on_tick = Callable()
			var unit: Unit = _q.units.units[base_index]
			var label: String = "%s spot %d" % [base.name, spot_index + 1]
			_q.kit.need(problems, came and unit.global_position.distance_to(marker.global_position) <= 0.05, "%s: the Gyrocopter came %s and stands %.3f m from the spot" % [label, came, unit.global_position.distance_to(marker.global_position)])
			var near: Structure = _k.panel(base_index, Kit19.LEFT if marker.position.x < 0.0 else Kit19.RIGHT, 0)
			var top: float = ((near.get_node("Mesh") as MeshInstance3D).global_transform * (near.get_node("Mesh") as MeshInstance3D).get_aabb()).end.y
			var want: float = top + _model(base_index).rise_clearance
			var reached: int = -1
			for index: int in _lows.size():
				if reached < 0 and absf(_lows[index] - want) <= TOLERANCE:
					reached = index
			var fastest: float = 0.0
			for index: int in range(1, _lows.size()):
				fastest = maxf(fastest, _lows[index] - _lows[index - 1])
			var settle_ticks: int = ceili((want - rest) / rate)
			_q.kit.need(problems, _lows.size() == RECORD_TICKS + 1 and absf(_lows[0] - rest) <= TOLERANCE, "%s: the first sample (the spawn tick) is %.3f m, the hover is %.3f" % [label, _lows[0], rest])
			_q.kit.need(problems, reached >= 0 and reached <= settle_ticks + 1 and absf(_lows[-1] - want) <= TOLERANCE, "%s: the model reached %.3f m (its lowest point %.3f over a %.1f m panel top) on tick %d, expected %d, and ends at %.3f" % [label, want, _model(base_index).rise_clearance, top, reached, settle_ticks, _lows[-1]])
			_q.kit.need(problems, absf(fastest - rate) <= TOLERANCE, "%s: the model rose at most %.4f m a tick, the rise rate gives %.4f" % [label, fastest, rate])
			_q.kit.need(problems, absf((_tops[-1] - _lows[-1]) - (rest_top - rest)) <= TOLERANCE, "%s: the model's height changed (%.3f against %.3f)" % [label, _tops[-1] - _lows[-1], rest_top - rest])
			steps += 1
			final_low = _lows[-1]
			notes.append("%s: %.3f on the spawn tick, %.3f from tick %d (top %.3f)" % [label, _lows[0], _lows[-1], reached, _tops[-1]])
	measured.append("drawn_height=%d low=%.3f->%.3f" % [steps, rest, final_low])
	_q.kit.verdict("drawn_height", problems, "a Gyrocopter chosen with the real keys on each of the four Garage spots (the first and the spare of both Bases, the spare taken by a Unit standing on the first) is drawn beside a Garage wall at 2 m from its inner face: its model's lowest point is the hover (%.3f m, the same as in the open) on the spawn tick and rises %.2f m a tick (the rise rate %.1f m/s) to %.3f m, the Garage panel's 2 m top plus the rise clearance, in %d ticks and stays there for the rest of the second (%s); it is the rise over the cover as it was designed, temporary until story 020 draws it at one flying height" % [
		rest, rate, rise_rate, final_low, ceili((final_low - rest) / rate), "; ".join(notes)])


## One flight of both Players' Gyrocopters at once over a panel of their own: `run_a` is the run Player 1 crosses and
## `run_b` Player 2's (the same Garage run in each Base, or the west and east field walls), from outside or from
## inside the run. Returns the problems added, and logs the model's heights.
func _cross(run_a: int, run_b: int, outside: bool, problems: PackedStringArray) -> String:
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var half: float = stats.collision_size.z / 2.0
	var runs: Array[int] = [run_a, run_b]
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	var finished: Array[bool] = [false, false]
	for player: int in Kit.PLAYERS:
		var run: int = runs[player]
		spots.append(_k.spot(player, run, Kit19.LANE[run], _k.start_out(run, half, outside)))
		facings.append(_k.outward(player, run) * (-1.0 if outside else 1.0))
		_piece[player] = _k.panel(player, run, Kit19.LANE[run]).get_node("Mesh") as MeshInstance3D
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], spots, facings, true)
	var clearance: float = _model(0).rise_clearance
	_over = [0, 0]
	_clear = [INF, INF]
	_slowest = [INF, INF]
	_entry = [INF, INF]
	_q.map.clear_log()
	_q.kit.on_tick = _cross_tick
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			var run: int = runs[player]
			var along: float = _k.along_out(player, run, _q.units.units[player].global_position)
			var far: float = Kit19.INNER_FACES[run] if outside else Kit19.OUTER_FACES[run]
			finished[player] = finished[player] or (along <= far - PAST if outside else along >= far + PAST)
			_q.harness.drive(player, 0 if finished[player] else 1, 0)
		await _q.kit.tick()
		if finished[0] and finished[1]:
			break
	_q.kit.on_tick = Callable()
	_q.harness.release_all()
	for player: int in Kit.PLAYERS:
		var label: String = "p%d over %s from %s" % [player + 1, Kit19.RUN_NAMES[runs[player]], "outside" if outside else "inside"]
		_q.kit.need(problems, _q.map.contacts[player] == 0, "%s touched a wall %d times" % [label, _q.map.contacts[player]])
		_q.kit.need(problems, _over[player] > 0 and _clear[player] >= clearance - RISE_SLACK, "%s: its model came to %.3f m over the panel's top in %d ticks over it (rise clearance %.3f)" % [label, _clear[player], _over[player], clearance])
		_q.kit.need(problems, _slowest[player] >= minf(SPEED_SHARE * stats.max_speed, _entry[player]) - SLOW_SLACK, "%s slowed to %.2f m/s over the panel (%.2f m/s as its model came over it)" % [label, _slowest[player], _entry[player]])
		_q.kit.need(problems, finished[player], "%s did not get %.0f m past the far face" % [label, PAST])
	return "%s %s %.2f m over for %d ticks" % [Kit19.RUN_NAMES[run_a], "in" if outside else "out", _clear[0], _over[0]]


## Logs both Gyrocopters after a tick (the map kit's log), and for each the ticks its model's footprint covers the piece
## it crosses, the least height of its lowest point over that piece's top, and its slowest real speed then.
func _cross_tick() -> void:
	_q.map.log_tick()
	for player: int in Kit.PLAYERS:
		var box: AABB = Quick.model_box(_q.units.units[player])
		var piece_box: AABB = _piece[player].global_transform * _piece[player].get_aabb()
		if box.position.x < piece_box.end.x and box.end.x > piece_box.position.x and box.position.z < piece_box.end.z and box.end.z > piece_box.position.z:
			_over[player] += 1
			_clear[player] = minf(_clear[player], box.position.y - piece_box.end.y)
			_slowest[player] = minf(_slowest[player], _q.map.real_speed(player, -1))
			_entry[player] = _q.map.real_speed(player, -1) if _over[player] == 1 else _entry[player]


## gyro_over (AC-2, AC-4): both Players' Gyrocopters cross the lane panel of a Garage run of their own Base, out of the
## Garage over the back wall and each side wall and into it over each side wall from the yard, and the lane panel of
## a field wall from outside and from inside, at full speed.
func _gyro_over() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.GYROCOPTER)
	var cases: Array = [[Kit19.BACK, Kit19.BACK, false], [Kit19.LEFT, Kit19.LEFT, false], [Kit19.RIGHT, Kit19.RIGHT, false],
		[Kit19.LEFT, Kit19.LEFT, true], [Kit19.RIGHT, Kit19.RIGHT, true],
		[Kit19.WEST, Kit19.EAST, true], [Kit19.WEST, Kit19.EAST, false], [Kit19.EAST, Kit19.WEST, true], [Kit19.EAST, Kit19.WEST, false]]
	var least: float = INF
	var slowest: float = INF
	for entry: Array in cases:
		notes.append(await _cross(entry[0], entry[1], entry[2], problems))
		least = minf(least, minf(_clear[0], _clear[1]))
		slowest = minf(slowest, minf(_slowest[0], _slowest[1]))
	var clearance: float = _model(0).rise_clearance
	measured.append("gyro_crossings=%d rise_min=%.3f speed_min=%.2f" % [cases.size() * 2, least, slowest])
	_q.kit.verdict("gyro_over", problems, "%d crossings at full throttle, one Gyrocopter of each Player over a lane panel: out of its Garage over the back wall and each side wall (the back wall's crossing goes on over the Base's back wall behind it), into it over each side wall from the yard, and over a field wall from outside and from inside (the west wall and the east one, each Player one of them): no wall contact, its model's lowest point at least %.3f m over the 2 m top at the least (rise clearance %.2f m), never slower than the lesser of %.0f%% of its top speed and the speed it had as its model came over the panel (the slowest %.2f m/s, top %.1f: the yard beside a Garage is too narrow to reach the top speed in), %.0f m past the far face (Player 1's: %s)" % [
		cases.size() * 2, least, clearance, SPEED_SHARE * 100.0, slowest, stats.max_speed, PAST, ", ".join(notes)])


## stopped_by (AC-2): Player 1's Gyrocopter is flown at full throttle at a corner tower of its own Base's back wall (along
## the side wall's axis, outside it) and at the water tower's Gate-side leg, each a body on the Map layer, which its
## collider's mask has: each stops it, with a wall contact, short of its face.
func _stopped_by() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var half: float = _q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	var cases: Array = [
		["a corner tower", Vector3(TOWER_FACE_X - Kit19.RUN - half, 0.0, TOWER_Z), Vector3.RIGHT, Vector3.RIGHT, TOWER_FACE_X],
		["the Gate-side leg", Vector3(-2.0, 0.0, LEG_FACE_Z - Kit19.RUN - half), Vector3.BACK, Vector3.BACK, LEG_FACE_Z]]
	for entry: Array in cases:
		var start: Vector3 = _k.k.m.w.point(0, entry[1])
		var facing: Vector3 = _k.k.m.w.way(0, entry[2])
		await _q.map.stage([Quick.GYROCOPTER, -1], [start, Vector3.ZERO], [facing, Vector3.ZERO], true)
		_q.map.clear_log()
		_q.kit.on_tick = _q.map.log_tick
		for _tick: int in RUN_LIMIT_TICKS / 2:
			_q.harness.drive(0, 1, 0)
			await _q.kit.tick()
		_q.kit.on_tick = Callable()
		_q.harness.release_all()
		var local: Vector3 = _k.k.m.w.bases[0].to_local(_q.units.units[0].global_position)
		var reached: float = local.x if entry[2] == Vector3.RIGHT else local.z
		_q.kit.need(problems, _q.map.contacts[0] > 0 and reached <= float(entry[4]) - half + FACE_SLACK, "flown at %s, the Gyrocopter had %d wall contacts and ended at local %.2f (the face is at %.2f)" % [entry[0], _q.map.contacts[0], reached, float(entry[4])])
		notes.append("%s: %d contacts, stopped at %.2f short of its face at %.2f" % [entry[0], _q.map.contacts[0], reached, float(entry[4])])
	_q.kit.verdict("stopped_by", problems, "flown at full throttle for %d s, the Gyrocopter is still stopped by a corner tower and a water tower leg, which stand on the Map layer, while the Garage walls no longer stop it (gyro_over): %s" % [RUN_LIMIT_TICKS / 120, "; ".join(notes)])
