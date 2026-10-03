extends RefCounted
## Scenario map_ford of the split screen evidence harness (split_screen_harness.gd): the fords of
## Map 01 slow ground Units and not the Gyrocopter (Story 007 AC-5), on the main composition and
## the shipped data, every key a real event (W and Up held). Each type in turn, both Players at
## once: Player 1 across FordWest, Player 2 across FordEast, west to east on one salt flat lane
## (LANE_Z) clear of the cover, the channels' mouths and the depot, from rest RUN_UP metres before
## the ford, so every type is at its top speed before it reaches the ford. One CHECK, ford_speed,
## with each run's numbers: a ground Unit's drive speed and measured speed (its move in a tick x
## the tick rate) within 0.1 m/s of max_speed x the ford fraction from the fourth tick after its
## centre crosses in to the fourth tick after it leaves, its top speed again FULL_SPEED_TICKS after
## it leaves; the Gyrocopter at its top speed across and never capped; no wall contact. The zone
## lists a Unit a tick late and the cap holds a tick of grace, so the cap bites before that window
## opens and lifts after it closes (the Story 007 evidence doc keeps the run). A SPLIT line per
## run. OWN_CHOICE: both Players confirm with their fire keys (confirm_choices()), then each type
## is given by Unit.spawn(at, stats) on the Unit in play, with a full tank (map_kit.gd stage()).
## Implements: production/epics/wasteland-fire/story-007-the-map.md AC-5 (the ford fraction 0.5,
## data in the Map); design/rules.md "Units". Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=map_ford

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the ticks and the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the Map's nodes and collision, the staging, the tick log.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")

## This scenario makes the first choice itself: both Players confirm with their own fire keys.
const OWN_CHOICE: bool = true
## The ford each Player crosses, by Player: its node path from the Map.
const FORDS: Array[String] = ["FordWest", "FordEast"]
## The types both Players take in turn, indexes into the data: Motorbike, Buggy, Truck, Gyrocopter.
const TYPE_ORDER: Array[int] = [0, 1, 2, 3]
## The Gyrocopter's index into the data: the one type a ford leaves at its top speed.
const GYROCOPTER: int = 3
## The lane's Z, metres: inside the fords' Z range (-20 to 20) on the salt flat, clear of the
## wrecks near Z -10 and of the canyon rock's foot at Z -20 (the CHECK counts every wall contact).
const LANE_Z: float = -16.0
## The run-up from rest to a ford's near edge, metres: the Motorbike needs 14.4 to reach its top
## speed, the other types less.
const RUN_UP: float = 24.0
## AC-5's ford fraction, the shipped data's starting value: in a ford the speed is max_speed x this.
const FORD_FRACTION: float = 0.5
## AC-5's tolerance on a speed, m/s.
const SPEED_TOLERANCE: float = 0.1
## AC-5's window, ticks: from this many after the centre crosses in to this many after it leaves.
const WINDOW_TICKS: int = 4
## Ticks after the centre leaves at which the top speed is asserted again.
const FULL_SPEED_TICKS: int = 64
## The most ticks one run may take before it is a problem.
const RUN_LIMIT_TICKS: int = 900

var _harness: Harness
var _kit: Kit
var _map: Map
var _runs: int = 0


## Puts both Units in play with the fire keys, runs each type across both fords, then the CHECK
## and RESULT lines. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_map = Map.new(harness, _kit)
	_kit.on_tick = _map.log_tick
	await _harness.confirm_choices()
	await _kit.advance(Kit.START_TICKS)
	var problems: PackedStringArray = []
	var notes: PackedStringArray = [_data(problems)]
	if problems.is_empty():
		for type_index: int in TYPE_ORDER:
			notes.append(await _round(type_index, problems))
	_kit.verdict("ford_speed", problems, " | ".join(notes))
	_harness.finish("runs=%d problems=%d" % [_runs, problems.size()])


## Both fords' settings, the speed fraction as data in the Map: a problem for a missing Ford or
## settings. Returns their fractions and whether the two fords share one resource.
func _data(problems: PackedStringArray) -> String:
	var fractions: PackedStringArray = []
	var resources: Array[FordSettings] = []
	for path: String in FORDS:
		var ford: Ford = _map.find(path) as Ford
		_kit.need(problems, ford != null and ford.settings != null, "no Ford with settings at %s" % path)
		if ford != null and ford.settings != null:
			fractions.append("%s %.2f" % [path, ford.settings.speed_fraction])
			resources.append(ford.settings)
	var shared: bool = resources.size() == FORDS.size() and resources[0] == resources[1]
	return "data: fraction %s, one resource %s; lane z %.1f, run-up %.1f m, a full tank at each staging" % [
		", ".join(fractions), shared, LANE_Z, RUN_UP]


## One type across both fords at once: both Units staged at rest RUN_UP before their fords on
## LANE_Z facing east with a full tank, driven across, judged. Returns both runs' notes.
func _round(type_index: int, problems: PackedStringArray) -> String:
	var spans: Array[Vector2] = []
	var spots: Array[Vector3] = []
	for path: String in FORDS:
		var span: Vector2 = _span(path)
		spans.append(span)
		spots.append(Vector3(span.x - RUN_UP, 0.0, LANE_Z))
	var types: Array[int] = [type_index, type_index]
	var facings: Array[Vector3] = [Vector3.RIGHT, Vector3.RIGHT]
	await _map.stage(types, spots, facings, true)
	_map.clear_log()
	_harness.phase = StringName("ford_%s" % _map.units[Harness.PLAYER_1].type_id)
	await _drive_across(spans)
	var notes: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		notes.append(_judge(player, type_index == GYROCOPTER, spans[player], problems))
	return " | ".join(notes)


## Holds both throttles until each Unit's centre has been FULL_SPEED_TICKS past its ford's far edge
## (its keys then go up) or RUN_LIMIT_TICKS pass. A coroutine: await it.
func _drive_across(spans: Array[Vector2]) -> void:
	var leaves: Array[int] = [-1, -1]
	var running: Array[bool] = [true, true]
	for player: int in Kit.PLAYERS:
		_harness.drive(player, 1, 0)
	for _tick: int in RUN_LIMIT_TICKS:
		await _kit.tick()
		for player: int in Kit.PLAYERS:
			var trail: PackedVector3Array = _map.places[player]
			if leaves[player] < 0 and trail[trail.size() - 1].x > spans[player].y:
				leaves[player] = trail.size() - 1
			if running[player] and leaves[player] >= 0 and trail.size() > leaves[player] + FULL_SPEED_TICKS:
				running[player] = false
				_harness.drive(player, 0, 0)
		if not running.has(true):
			break
	_harness.release_all()


## The X range of a ford's zone, (near edge, far edge) going east, from its collision box, metres.
func _span(path: String) -> Vector2:
	var span: Vector2 = Vector2(INF, -INF)
	for point: Vector3 in _map.footprint(_map.find(path)):
		span = Vector2(minf(span.x, point.x), maxf(span.y, point.x))
	return span


## Judges one Player's run from the log (AC-5) and prints its SPLIT line. Returns its note.
func _judge(player: int, flies: bool, span: Vector2, problems: PackedStringArray) -> String:
	var unit: Unit = _map.units[player]
	var label: String = "p%d %s %s" % [player + 1, FORDS[player], unit.type_id]
	var trail: PackedVector3Array = _map.places[player]
	var enter: int = _first_past(trail, span.x)
	var leave: int = _first_past(trail, span.y)
	_runs += 1
	if enter < 1 or leave < enter or trail.size() <= leave + FULL_SPEED_TICKS:
		problems.append("%s: no crossing with %d ticks after it (in %d, out %d, logged %d)" % [
			label, FULL_SPEED_TICKS, enter, leave, trail.size()])
		return label + ": no crossing"
	var top: float = unit.stats.max_speed
	var reading: Dictionary[StringName, float] = _read(player, enter, leave, top)
	_need(problems, label, reading, top, flies)
	print("SPLIT %s t=%.3f run=%s top=%.2f in_tick=%d out_tick=%d %s" % [_harness.scenario, _harness.time(),
		label.replace(" ", "_"), top, enter, leave, _fields(reading)])
	return "%s: %s" % [label, _note(reading, top, flies)]


## One run's readings, enter and leave being the first logged ticks with the centre past the
## ford's near and far edges: the window's (_read_window()), the marks (_read_marks()); approach,
## the top drive speed before enter; full_drive and full_real, the speeds FULL_SPEED_TICKS after
## leave; drift, the most the centre strayed from LANE_Z; contacts, the ticks with a wall contact.
func _read(player: int, enter: int, leave: int, top: float) -> Dictionary[StringName, float]:
	var drive: PackedFloat64Array = _map.speeds[player]
	var reading: Dictionary[StringName, float] = _read_window(player, enter + WINDOW_TICKS, leave + WINDOW_TICKS)
	reading[&"approach"] = 0.0
	for index: int in enter:
		reading[&"approach"] = maxf(reading[&"approach"], drive[index])
	_read_marks(reading, drive, Vector2i(enter, leave), top)
	reading[&"full_drive"] = drive[leave + FULL_SPEED_TICKS]
	reading[&"full_real"] = _map.real_speed(player, leave + FULL_SPEED_TICKS)
	reading[&"drift"] = 0.0
	for place: Vector3 in _map.places[player]:
		reading[&"drift"] = maxf(reading[&"drift"], absf(place.z - LANE_Z))
	reading[&"contacts"] = float(_map.contacts[player])
	return reading


## The least and most drive speed and measured speed of a Player from logged tick first to last,
## and the window's length in ticks.
func _read_window(player: int, first: int, last: int) -> Dictionary[StringName, float]:
	var drive: PackedFloat64Array = _map.speeds[player]
	var window: Dictionary[StringName, float] = {&"ticks": float(last - first + 1), &"drive_min": INF,
		&"drive_max": -INF, &"real_min": INF, &"real_max": -INF}
	for index: int in range(first, last + 1):
		var real: float = _map.real_speed(player, index)
		window[&"drive_min"] = minf(window[&"drive_min"], drive[index])
		window[&"drive_max"] = maxf(window[&"drive_max"], drive[index])
		window[&"real_min"] = minf(window[&"real_min"], real)
		window[&"real_max"] = maxf(window[&"real_max"], real)
	return window


## A run's marks in ticks, NAN for never (looked for up to FULL_SPEED_TICKS after leave): bite,
## from the tick the centre crossed in (crossing.x) to the first at or under the capped speed
## (max_speed x FORD_FRACTION + SPEED_TOLERANCE) after the top speed; lift and again, from the tick
## it left (crossing.y) to the first at or over the capped speed and the first at the top speed.
func _read_marks(reading: Dictionary[StringName, float], drive: PackedFloat64Array, crossing: Vector2i,
		top: float) -> void:
	var capped: float = top * FORD_FRACTION + SPEED_TOLERANCE
	var last: int = crossing.y + FULL_SPEED_TICKS
	var peak: int = _first_in(drive, Vector2(top - SPEED_TOLERANCE, INF), 0, last)
	var bite: int = _first_in(drive, Vector2(-INF, capped), peak, last) if peak >= 0 else -1
	var lift: int = _first_in(drive, Vector2(capped, INF), crossing.y, last)
	var again: int = _first_in(drive, Vector2(top - SPEED_TOLERANCE, INF), crossing.y, last)
	reading[&"bite"] = float(bite - crossing.x) if bite >= 0 else NAN
	reading[&"lift"] = float(lift - crossing.y) if lift >= 0 else NAN
	reading[&"again"] = float(again - crossing.y) if again >= 0 else NAN


## The first index from first to last whose value is within bounds (x least, y most), or -1.
func _first_in(values: PackedFloat64Array, bounds: Vector2, first: int, last: int) -> int:
	for index: int in range(first, mini(last, values.size() - 1) + 1):
		if values[index] >= bounds.x and values[index] <= bounds.y:
			return index
	return -1


## AC-5 on one run's readings: its top speed before the ford and FULL_SPEED_TICKS after it, no wall
## contact, and in the window within SPEED_TOLERANCE of max_speed x FORD_FRACTION (a ground Unit)
## or of its top speed, never capped (the Gyrocopter: flies).
func _need(problems: PackedStringArray, label: String, reading: Dictionary[StringName, float], top: float,
		flies: bool) -> void:
	var least: float = top - SPEED_TOLERANCE
	_kit.need(problems, reading[&"approach"] >= least, "%s reached %.3f m/s before the ford, not its top %.2f" % [
		label, reading[&"approach"], top])
	_kit.need(problems, reading[&"contacts"] == 0.0, "%s touched a wall on %d ticks" % [label, int(reading[&"contacts"])])
	_kit.need(problems, reading[&"full_drive"] >= least and reading[&"full_real"] >= least,
		"%s at %.3f / %.3f m/s %d ticks after the ford, not its top %.2f" % [label, reading[&"full_drive"],
		reading[&"full_real"], FULL_SPEED_TICKS, top])
	var target: float = top if flies else top * FORD_FRACTION
	var low: float = minf(reading[&"drive_min"], reading[&"real_min"])
	var high: float = maxf(reading[&"drive_max"], reading[&"real_max"])
	_kit.need(problems, low >= target - SPEED_TOLERANCE and high <= target + SPEED_TOLERANCE,
		"%s in the ford at %.3f..%.3f m/s, not %.2f +- %.1f" % [label, low, high, target, SPEED_TOLERANCE])
	_kit.need(problems, not flies or is_nan(reading[&"bite"]), "%s capped from tick %s of the crossing" % [
		label, _mark(reading[&"bite"])])


## A run's note for the CHECK detail.
func _note(reading: Dictionary[StringName, float], top: float, flies: bool) -> String:
	var marks: String = "never capped" if flies and is_nan(reading[&"bite"]) else "bite %s, lift %s, top again %s" % [
		_mark(reading[&"bite"]), _mark(reading[&"lift"]), _mark(reading[&"again"])]
	return ("approach %.3f, window %d ticks drive %.3f..%.3f measured %.3f..%.3f (%.2f +- %.1f), %s, "
		+ "at +%d %.3f/%.3f, drift %.3f, contacts %d") % [reading[&"approach"], int(reading[&"ticks"]),
		reading[&"drive_min"], reading[&"drive_max"], reading[&"real_min"], reading[&"real_max"],
		top if flies else top * FORD_FRACTION, SPEED_TOLERANCE, marks, FULL_SPEED_TICKS,
		reading[&"full_drive"], reading[&"full_real"], reading[&"drift"], int(reading[&"contacts"])]


## A mark in ticks, signed, or never (NAN).
func _mark(ticks: float) -> String:
	return "never" if is_nan(ticks) else "%+d" % int(ticks)


## A run's readings as key=value fields (_number()).
func _fields(reading: Dictionary[StringName, float]) -> String:
	var fields: PackedStringArray = []
	for key: StringName in reading:
		fields.append("%s=%s" % [key, _number(reading[key])])
	return " ".join(fields)


## A reading as text: never for NAN, a whole number as an integer, any other to 6 decimals.
func _number(value: float) -> String:
	if is_nan(value):
		return "never"
	return str(int(value)) if value == roundf(value) else "%.6f" % value


## The first logged tick on which a trail's centre is east of x, or -1.
func _first_past(trail: PackedVector3Array, x: float) -> int:
	for index: int in trail.size():
		if trail[index].x > x:
			return index
	return -1
