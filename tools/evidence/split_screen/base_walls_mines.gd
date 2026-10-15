extends RefCounted
## mines_at_the_walls, for the base_walls scenario (Story 018 AC-6): the no-Mine area does not follow the walls.
## area: its answer at points across the Gate walls and the footprints of a side and a back wall, and at its edges,
## is the story's box with every panel standing and again with every panel fallen. probe: outside the area the
## open-ground test decides, and a standing panel shuts a drop point within a Mine's reach of it while a fallen one
## opens the ground. lays: a Truck's E key, in a Gate wall's breach and the inner part of a back wall's, is refused
## with "No Mines in or near a Base" (panel standing or fallen); in the outer part of a side or back wall's it is
## refused with "No room for a Mine here" while the panel stands and lays at the drop point once it has fallen.
## victims: each of those Mines, live, destroys the Buggy that drives through the breach over it. Run by
## base_walls.gd. Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The area's edges in a Base's frame (AC-6): |x| up to 15.5, z from -25.7 to 14.4.
const EDGE_X: float = 15.5
const EDGE_GATE: float = -25.7
const EDGE_BACK: float = 14.4
## How far from a face the probe is read, metres: just inside and just outside a Mine's reach (its 0.8 m radius).
const INSIDE_REACH: float = 0.79
const OUTSIDE_REACH: float = 0.81
## Metres from a Base's axis where the drop points of the lays stand: the outer part of a side wall's breach (the
## wall is 14.7 to 16.0 m out, the area ends at 15.5), of a back wall's (13.7 to 15.0, the area ends at 14.4), the
## inner part of a back wall's, and the middle of a Gate wall (z -15.0 to -13.7).
const SIDE_OUT: float = 15.75
const BACK_OUT: float = 14.7
const BACK_IN: float = 14.0
const GATE_OUT: float = 14.35
## The distances from the axis the area is read at across a back wall's footprint and a side wall's (two inside the area, two
## outside it), metres.
const BACK_STEPS: Array[float] = [13.75, 14.35, 14.45, 14.95]
const SIDE_STEPS: Array[float] = [14.75, 15.45, 15.55, 15.95]
## How many readings the area check makes: three along by three across each Gate wall panel, four across each of three
## footprints, and two either side of four edges.
const GATE_READINGS: int = 9
const AREA_FOOTPRINTS: int = 12
const AREA_EDGES: int = 8
const NEAR_TEXT: String = "No Mines in or near a Base"
const ROOM_TEXT: String = "No room for a Mine here"
## The ticks a refusal may stay on the notice line, the ticks a drive may take and a Mine's wait to be spent, and how
## far from its Mine, metres, a victim may be destroyed (its half length, the trigger and the zone's latency).
const QUIET_LIMIT: int = 200
const DRIVE_LIMIT: int = 420
const SPENT_WAIT: int = 60
const DEATH_REACH: float = 3.5
## How far a Mine may lie from the Truck's drop point, metres.
const DROP_TOLERANCE: float = 0.01

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit18
var _q: Quick
var _problems: PackedStringArray = []
var _notes: PackedStringArray = []
## The Mines the lays left: {base, run, record, drop}.
var _laid: Array[Dictionary] = []
var _readings: int = 0
var _probes: int = 0
var _refusals: int = 0


func _init(kit: Kit18) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.turrets_down()
	await _area()
	await _probe()
	await _lays()
	await _q.kit.advance(_k.m.LIVE_WAIT)
	for lay: Dictionary in _laid:
		await _victim(lay)
	await _k.restore_all()
	var per_base: int = (Kit18.COUNTS[Kit18.GATE_LEFT] + Kit18.COUNTS[Kit18.GATE_RIGHT]) * GATE_READINGS + AREA_FOOTPRINTS + AREA_EDGES
	_q.kit.need(_problems, _readings == 2 * 2 * per_base and _probes == 2 * 2 * 2 * 3 and _refusals == 2 * (3 * 2 + 2) and _laid.size() == 4, "the checks made %d area readings (not %d), %d probe readings (not 24), %d refusals (not 16) and %d lays (not 4)" % [_readings, 2 * 2 * per_base, _probes, _refusals, _laid.size()])
	measured.append("area_readings=%d probes=%d refusals=%d mines=%d" % [_readings, _probes, _refusals, _laid.size()])
	_q.kit.verdict("mines_at_the_walls", _problems, "the no-Mine area answered %d drop points (across every Gate wall panel, the footprints of a side and a back wall, and %.2f / %.1f / %.1f either side of its edges) as the story's box does, with every panel standing and again with every panel fallen; outside it the open-ground test shut a drop point within a Mine's reach (%.2f m) of a standing panel and opened it once the panel had fallen; a Truck's E key was refused with \"%s\" in a Gate wall's breach and the inner part of a back wall's (panel standing or fallen: %d refusals in all), refused with \"%s\" in the outer part of a side or back wall's while the panel stood and laid at the drop point once it had fallen (%d Mines); each live Mine destroyed the Buggy that drove through the breach over it (%s)" % [
		_readings, EDGE_X, EDGE_GATE, EDGE_BACK, INSIDE_REACH, NEAR_TEXT, _refusals, ROOM_TEXT, _laid.size(), "; ".join(_notes)])


## The drop points of the area check, Base-local: across every Gate wall panel (three along by three across), the
## footprints of a side and a back wall (two inside the area, two outside) and either side of each edge.
func _area_points() -> Array[Vector3]:
	var found: Array[Vector3] = []
	for run: int in [Kit18.GATE_LEFT, Kit18.GATE_RIGHT]:
		for index: int in Kit18.COUNTS[run]:
			for along: float in [0.05, 0.5, 0.95]:
				for z: float in [-14.95, -14.35, -13.75]:
					found.append(Vector3(Kit18.STARTS[run] + Kit18.LENGTHS[run] * (float(index) + along), 0.0, z))
	for run: int in [Kit18.LEFT, Kit18.RIGHT, Kit18.BACK]:
		var steps: Array[float] = []
		steps.assign(BACK_STEPS if run == Kit18.BACK else SIDE_STEPS)
		for out: float in steps:
			found.append(Kit18.OUTWARD[run] * out + Kit18.ALONG[run] * _k.centre(run, Kit18.LANE[run]))
	for step: float in [-0.05, 0.05]:
		found.append_array([Vector3(EDGE_X + step, 0.0, 0.0), Vector3(-EDGE_X - step, 0.0, 0.0), Vector3(0.0, 0.0, EDGE_GATE + step), Vector3(0.0, 0.0, EDGE_BACK + step)])
	return found


## The story's answer for a Base-local drop point.
func _refused_by_the_area(point: Vector3) -> bool:
	return absf(point.x) <= EDGE_X and point.z >= EDGE_GATE and point.z <= EDGE_BACK


## Reads the area at every point of _area_points() at both Bases.
func _area_readings(state: String) -> void:
	var layer: MineLayer = _k.m.layers[0]
	for base_index: int in Kit.PLAYERS:
		for point: Vector3 in _area_points():
			var got: bool = layer.is_in_no_mine_area(_k.m.w.point(base_index, point))
			_readings += 1
			_q.kit.need(_problems, got == _refused_by_the_area(point), "%s, Base %d: the area %s the drop point %s" % [state, base_index + 1, "refuses" if got else "does not refuse", point])


## area: the same answers with every panel standing and with every panel fallen.
func _area() -> void:
	await _k.restore_all()
	_area_readings("panels standing")
	for panel: Structure in _k.every():
		panel.destroy()
	await _q.kit.advance(Kit18.SETTLE)
	_area_readings("every panel fallen")
	await _k.restore_all()


## probe: at the lane panel of a side wall and of a back wall of each Base, three drop points outside the area (just
## inside a Mine's reach of the outer face, just outside it, and in the outer part of the footprint): standing, the
## probe shuts the first and the third and opens the second; fallen, it opens all three.
func _probe() -> void:
	var layer: MineLayer = _k.m.layers[0]
	for base_index: int in Kit.PLAYERS:
		for run: int in [Kit18.LEFT if base_index == 0 else Kit18.RIGHT, Kit18.BACK]:
			var panel: Structure = _k.panel(base_index, run, Kit18.LANE[run])
			var outer: float = Kit18.OUTER_FACES[run]
			var inner_part: float = BACK_OUT if run == Kit18.BACK else SIDE_OUT
			var reads: Array[float] = [outer + INSIDE_REACH, outer + OUTSIDE_REACH, inner_part]
			for state: String in ["standing", "fallen"]:
				if state == "fallen":
					panel.destroy()
					await _q.kit.advance(Kit18.SETTLE)
				var want: Array[bool] = [false, true, false]
				if state == "fallen":
					want = [true, true, true]
				for index: int in reads.size():
					var at: Vector3 = _k.spot(base_index, run, Kit18.LANE[run], reads[index])
					_probes += 1
					_q.kit.need(_problems, not layer.is_in_no_mine_area(at) and layer.is_open_ground(at) == want[index], "%s %s, %s: the drop point %.2f m out reads open ground %s (outside the area %s)" % [_k.m.w.bases[base_index].name, Kit18.RUN_NAMES[run], state, reads[index], layer.is_open_ground(at), not layer.is_in_no_mine_area(at)])
			await _k.restore_all()


## Waits until the notice line of Player 1 is hidden (a refusal stays about 1.5 s).
func _quiet() -> void:
	for _tick: int in QUIET_LIMIT:
		if _k.m.note(0) == "hidden":
			return
		await _q.kit.tick()


## A new Truck of Player 1 stands outside a run, facing away from it, with its drop point `drop_out` metres from the
## Base's axis along the run, level with panel `index`, and presses E. {laid, reason, note, left, record, drop}.
func _press(base_index: int, run: int, index: int, drop_out: float) -> Dictionary:
	var behind: float = _q.units.stats(Quick.TRUCK).mine_drop_offset.z
	await _quiet()
	await _k.m.revive(0)
	await _k.m.put(0, Quick.TRUCK, _k.spot(base_index, run, index, drop_out + behind), _k.outward(base_index, run))
	var truck: Unit = _q.units.units[0]
	var laid: int = _k.m.laid.size()
	var refused: int = _k.m.refused[0].size()
	var record: Dictionary = await _k.m.lay(0)
	return {"laid": _k.m.laid.size() > laid, "reason": int(_k.m.refused[0][-1].x) if _k.m.refused[0].size() > refused else -1, "note": _k.m.note(0),
		"left": _k.m.layers[0].mines_left, "record": record, "drop": truck.global_transform * truck.stats.mine_drop_offset}


## The press was refused for the reason, the notice says so and the Truck keeps its load.
func _refused(label: String, got: Dictionary, reason: int, text: String) -> void:
	var load_size: int = _q.units.stats(Quick.TRUCK).mine_capacity
	_refusals += 1
	_q.kit.need(_problems, not got["laid"] and got["reason"] == reason and got["note"] == text and got["left"] == load_size, "%s: %s" % [label, {"laid": got["laid"], "reason": got["reason"], "note": got["note"], "left": got["left"]}])


## The press laid one Mine at the drop point, with no notice.
func _lay_ok(label: String, got: Dictionary) -> void:
	var load_size: int = _q.units.stats(Quick.TRUCK).mine_capacity
	var off: float = _k.m.place_of(got["record"]).distance_to(got["drop"]) if got["laid"] else INF
	_q.kit.need(_problems, got["laid"] and got["left"] == load_size - 1 and got["note"] == "hidden" and off <= DROP_TOLERANCE, "%s: laid %s, %s left, note '%s', %.3f m from the drop point" % [label, got["laid"], got["left"], got["note"], off])


## lays: at each Base the refusals of the area, then the outer parts of a side and a back wall, standing and fallen.
func _lays() -> void:
	for base_index: int in Kit.PLAYERS:
		var name: String = _k.m.w.bases[base_index].name
		for spot: Array in [[Kit18.GATE_LEFT, 2, GATE_OUT], [Kit18.GATE_RIGHT, 0, GATE_OUT], [Kit18.BACK, Kit18.LANE[Kit18.BACK], BACK_IN]]:
			for state: String in ["standing", "fallen"]:
				var panel: Structure = _k.panel(base_index, spot[0], spot[1])
				if state == "fallen":
					panel.destroy()
				var label: String = "%s %s panel %d, %s, drop point %.2f m out" % [name, Kit18.RUN_NAMES[spot[0]], spot[1] + 1, state, spot[2]]
				_refused(label, await _press(base_index, spot[0], spot[1], spot[2]), MineLayer.Refusal.NEAR_BASE, NEAR_TEXT)
			await _k.restore_all()
		for run: int in [Kit18.LEFT if base_index == 0 else Kit18.RIGHT, Kit18.BACK]:
			var out: float = BACK_OUT if run == Kit18.BACK else SIDE_OUT
			var panel: Structure = _k.panel(base_index, run, Kit18.LANE[run])
			var label: String = "%s %s panel %d, drop point %.2f m out" % [name, Kit18.RUN_NAMES[run], Kit18.LANE[run] + 1, out]
			_refused(label + ", standing", await _press(base_index, run, Kit18.LANE[run], out), MineLayer.Refusal.NO_ROOM, ROOM_TEXT)
			panel.destroy()
			var got: Dictionary = await _press(base_index, run, Kit18.LANE[run], out)
			_lay_ok(label + ", fallen", got)
			_laid.append({"base": base_index, "run": run, "record": got["record"], "drop": out})


## victims: Player 2's Buggy, put outside the breach facing in, drives at full throttle over the Mine in the breach's
## outer part and is destroyed within DEATH_REACH metres of it, and the Mine is spent.
func _victim(lay: Dictionary) -> void:
	var base_index: int = lay["base"]
	var run: int = lay["run"]
	var half: float = _q.units.stats(Quick.BUGGY).collision_size.z / 2.0
	var label: String = "%s %s" % [_k.m.w.bases[base_index].name, Kit18.RUN_NAMES[run]]
	await _k.stage(1, Quick.BUGGY, _k.spot(base_index, run, Kit18.LANE[run], _k.start_out(run, half, true)), -_k.outward(base_index, run))
	var buggy: Unit = _q.units.units[1]
	var died: Vector3 = Vector3.INF
	for _tick: int in DRIVE_LIMIT:
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
		if not buggy.is_alive:
			died = buggy.global_position
			break
	_q.harness.release_all()
	var gone: int = await _k.m.wait_gone(lay["record"], SPENT_WAIT)
	var at: float = _k.m.w.bases[base_index].to_local(died).dot(Kit18.OUTWARD[run]) if died != Vector3.INF else INF
	_q.kit.need(_problems, died != Vector3.INF and absf(at - float(lay["drop"])) <= DEATH_REACH and gone >= 0, "%s: the Buggy was destroyed %s at %.2f m from the axis (the Mine lay at %.2f), the Mine gone at tick %d" % [label, died != Vector3.INF, at, lay["drop"], gone])
	_notes.append("%s: destroyed %.2f m from the Mine" % [label, absf(at - float(lay["drop"]))])
