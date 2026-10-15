extends RefCounted
## The Garage and the movement checks of the garage_scrap_walls scenario (Story 019 AC-1 and AC-2): garage_unchanged
## (every type chosen with the real keys appears on each of the four Garage spots, standing on it and facing out of
## the Garage; a Mine's lay in either Garage is refused with "No Mines in or near a Base" with its walls standing and
## with them fallen), spawn_exits (story 018's check again: every type from both spots of both Bases straight out of
## the Gate on the throttle alone, touching no wall now that the Garage walls are panels) and stops (each ground type
## into a panel of each Garage run and each field run at full throttle, from inside and from outside, stops flush at
## its face; a Shot fired pressed against it ends at the muzzle inside it). Run by garage_scrap_walls.gd. Tooling
## only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## Story 018's movement checks, whose spawn_exits is run again here on the Garage panels.
const Moves18: GDScript = preload("res://tools/evidence/split_screen/base_walls_moves.gd")

## The ticks a run may take; a stop is a real speed below the kit's STOP_SPEED for this many ticks.
const RUN_LIMIT_TICKS: int = 420
const REST_TICKS: int = 6
## A Unit meets a panel at least at this share of its top speed when the run is the whole RUN; with less room it must
## still meet it at this speed (m/s), far over a wall's standstill.
const HIT_SHARE: float = 0.75
const MET_FLOOR: float = 3.0
## Where Player 1's Truck stands in a Garage for a lay, Base-local: its tail's drop point lies 3.4 m behind it, inside.
const LAY_AT: Vector3 = Vector3(0.0, 0.0, 5.0)
const NEAR_TEXT: String = "No Mines in or near a Base"
## The ticks a refusal may stay on the notice line.
const QUIET_LIMIT: int = 200

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _garage_unchanged()
	var exits: RefCounted = Moves18.new(_k.k)
	await exits._exits()
	measured.append_array(exits.measured)
	await _stops()


## garage_unchanged (AC-1): the spawns on the four spots, then the refused lays.
func _garage_unchanged() -> void:
	var problems: PackedStringArray = []
	var spawns: int = 0
	for base_index: int in Kit.PLAYERS:
		var base: Base = _k.k.m.w.bases[base_index]
		for spot_index: int in 2:
			var marker: Marker3D = base.spawn_point if spot_index == 0 else base.spare_spawn_points[0]
			for type_index: int in _q.controller.unit_types().size():
				await _k.k.m.revive(base_index)
				await _k.k.m.w.park(1 - base_index)
				if spot_index == 1:
					_k.k.m.w.s.flags.teleport(1 - base_index, base.spawn_point.global_position, -base.spawn_point.global_transform.basis.z)
					await _q.kit.advance(Kit19.Kit18.SETTLE)
				await _q.tokens.destruct(base_index)
				var came: bool = await _q.tokens.spawn(base_index, type_index)
				var unit: Unit = _q.units.units[base_index]
				var facing: float = (-unit.global_transform.basis.z).dot(-marker.global_transform.basis.z)
				var label: String = "%s spot %d, %s" % [base.name, spot_index + 1, _q.units.stats(type_index).type_id]
				_q.kit.need(problems, came and unit.type_id == _q.units.stats(type_index).type_id and unit.global_position.distance_to(marker.global_position) <= Kit.SPAWN_TOLERANCE and facing >= Kit.FACING_DOT_MIN, "%s: chosen and in play %s, %.3f m from the spot, facing dot %.4f" % [label, came, unit.global_position.distance_to(marker.global_position), facing])
				spawns += 1
	await _k.k.m.revive(0)
	await _k.k.m.revive(1)
	var refusals: int = 0
	for base_index: int in Kit.PLAYERS:
		for state: String in ["standing", "fallen"]:
			if state == "fallen":
				for run: int in Kit19.GARAGE_RUNS:
					for index: int in Kit19.COUNTS[run]:
						_k.panel(base_index, run, index).destroy()
			await _quiet()
			await _k.k.m.revive(0)
			await _k.k.m.put(0, Quick.TRUCK, _k.k.m.w.point(base_index, LAY_AT), _k.k.m.w.way(base_index, Vector3.FORWARD))
			var laid: int = _k.k.m.laid.size()
			var refused: int = _k.k.m.refused[0].size()
			await _k.k.m.lay(0)
			var reason: int = int(_k.k.m.refused[0][-1].x) if _k.k.m.refused[0].size() > refused else -1
			var note: String = _k.k.m.note(0)
			var load_size: int = _q.units.stats(Quick.TRUCK).mine_capacity
			_q.kit.need(problems, _k.k.m.laid.size() == laid and reason == MineLayer.Refusal.NEAR_BASE and note == NEAR_TEXT and _k.k.m.layers[0].mines_left == load_size, "%s Garage, panels %s: laid %d, reason %d, note '%s', %d Mines left" % [_k.k.m.w.bases[base_index].name, state, _k.k.m.laid.size() - laid, reason, note, _k.k.m.layers[0].mines_left])
			refusals += 1
		await _k.restore_all()
	measured.append("spawns=%d refusals=%d" % [spawns, refusals])
	_q.kit.verdict("garage_unchanged", problems, "every type chosen with the real keys appeared on each of the four Garage spots (the first and the spare of both Bases, the spare taken by a Unit on the first) and stood on it within %.2f m facing out of the Garage (%d spawns), the Garage panels counting for nothing in the test for a free spot; a Truck's E key in either Garage, with its drop point inside, was refused with \"%s\" with the Garage's ten panels standing and with them all fallen (%d refusals), the Truck keeping its load" % [Kit.SPAWN_TOLERANCE, spawns, NEAR_TEXT, refusals])


## Waits until the notice line of Player 1 is hidden (a refusal stays about 1.5 s).
func _quiet() -> void:
	for _tick: int in QUIET_LIMIT:
		if _k.k.m.note(0) == "hidden":
			return
		await _q.kit.tick()


## stops (AC-2): each ground type, at once from each Player into a panel of a run at full throttle, from inside the run
## (the Garage; the middle of the Map) and from outside it (the yard beside the Garage; away from the middle): met at
## speed, stopped flush at the face within the ticks the quick-fix kit allows; then a Shot fired from where it stands
## ends at its muzzle, inside the wall.
func _stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var drives: int = 0
	var cases: Array = [[Kit19.BACK, Kit19.BACK, false, false], [Kit19.LEFT, Kit19.LEFT, false, false], [Kit19.RIGHT, Kit19.RIGHT, false, false],
		[Kit19.LEFT, Kit19.LEFT, true, true], [Kit19.RIGHT, Kit19.RIGHT, true, true],
		[Kit19.WEST, Kit19.EAST, false, true], [Kit19.WEST, Kit19.EAST, true, false], [Kit19.EAST, Kit19.WEST, false, true], [Kit19.EAST, Kit19.WEST, true, false]]
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		var stats: UnitStats = _q.units.stats(type_index)
		var slowest: float = INF
		for entry: Array in cases:
			drives += 2
			for speed: float in await _stop_pair(type_index, [entry[0], entry[1]], [entry[2], entry[3]], problems):
				slowest = minf(slowest, speed)
		notes.append("%s %.1f to %.1f m/s" % [stats.type_id, slowest, stats.max_speed])
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	measured.append("stops=%d" % drives)
	_q.kit.verdict("stops", problems, "%d drives at full throttle, two at a time (each Player into a panel of its own Base's Garage or of a field wall), a Motorbike, a Buggy and a Truck into a panel of the Garage's back wall (from the Garage), each side wall (from the Garage and from the yard beside it) and each field wall (from the middle of the Map and from away from it): each met it at speed (slowest met, by type: %s; a full %.0f m run where the room allowed it, the Garage's 12 m and the yard's 7.7 m allow less, so a run there must meet it at %.0f m/s or more) and stopped flush at its face; a Shot fired pressed against the face ended at the muzzle inside the wall" % [drives, " | ".join(notes), Kit19.RUN, MET_FLOOR])


## One pair of drives: both Players' Units of one type at the lane panel of a run each, from inside or outside it. Every
## panel is whole when it starts: a Shot pressed against a field panel is a Shot of a Player on a panel of nobody's, and
## a few of them bring it down. Returns the speeds they met the face at.
func _stop_pair(type_index: int, runs: Array, outsides: Array, problems: PackedStringArray) -> Array[float]:
	await _k.restore_all()
	var stats: UnitStats = _q.units.stats(type_index)
	var half: float = stats.collision_size.z / 2.0
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	var faces: Array[float] = []
	var full: Array[bool] = []
	for player: int in Kit.PLAYERS:
		var run: int = runs[player]
		var outside: bool = outsides[player]
		var out: float = _k.start_out(run, half, outside)
		spots.append(_k.spot(player, run, Kit19.LANE[run], out))
		facings.append(_k.outward(player, run) * (-1.0 if outside else 1.0))
		faces.append(Kit19.OUTER_FACES[run] if outside else Kit19.INNER_FACES[run])
		full.append(absf(out - faces[player]) >= Kit19.RUN + half - 0.01)
	await _q.map.stage([type_index, type_index], spots, facings, true)
	_q.map.clear_log()
	_q.kit.on_tick = _q.map.log_tick
	var contact: Array[int] = [-1, -1]
	var rest: int = 0
	for _tick: int in RUN_LIMIT_TICKS:
		for player: int in Kit.PLAYERS:
			_q.harness.drive(player, 1, 0)
		await _q.kit.tick()
		for player: int in Kit.PLAYERS:
			contact[player] = _q.map.places[player].size() - 1 if contact[player] < 0 and _q.map.wall_contact(_q.units.units[player]) else contact[player]
		rest = rest + 1 if contact[0] >= 0 and contact[1] >= 0 and _q.map.real_speed(0, -1) < Quick.STOP_SPEED and _q.map.real_speed(1, -1) < Quick.STOP_SPEED else 0
		if rest >= REST_TICKS:
			break
	_q.kit.on_tick = Callable()
	_q.harness.release_all()
	var met: Array[float] = []
	for player: int in Kit.PLAYERS:
		var run: int = runs[player]
		var label: String = "p%d %s into %s from %s" % [player + 1, stats.type_id, Kit19.RUN_NAMES[run], "outside" if outsides[player] else "inside"]
		var face: float = faces[player]
		var numbers: Array[float] = _q.judge_stop(player, contact[player], func(at: Vector3) -> float: return absf(_k.along_out(player, run, at) - face), half, label, problems)
		_q.kit.need(problems, numbers[0] >= (HIT_SHARE * stats.max_speed if full[player] else MET_FLOOR), "%s met it at %.2f m/s, under %s" % [label, numbers[0], "%.0f%% of %.1f" % [HIT_SHARE * 100.0, stats.max_speed] if full[player] else "%.1f" % MET_FLOOR])
		met.append(numbers[0])
		var unit: Unit = _q.units.units[player]
		var muzzle: Vector3 = unit.global_position - unit.global_transform.basis.z * stats.muzzle_forward + Vector3.UP * _q.controller.rules.shooting_height
		await _q.kit.advance(_k.k.m.w.longest_cadence())
		var end: Vector3 = await _k.k.m.w.shoot(player)
		_q.kit.need(problems, end.distance_to(muzzle) <= Quick.SHOT_TOLERANCE, "%s: the Shot fired pressed against the face ended %.3f m from the muzzle" % [label, end.distance_to(muzzle)])
	return met
