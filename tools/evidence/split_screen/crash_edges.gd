extends RefCounted
## What only stops a Gyrocopter, and where the edge of the crash lies, for the crash scenario (Story 021 AC-3): only_stops (a slow
## nudge at 3.5 m/s into each Tall kind, a graze at top speed along a tower's face shallower than the crash angle and a turn on the
## spot flush against each Tall kind leave it alive, stopped or sliding as before), pinned (a Gyrocopter pinned against a leg with
## the throttle held for 3 s, from a standstill and from a slow nudge, commands its top speed and moves at zero, and lives), then the
## edges measured on both sides: speed_edge (0.1 m/s either side of the crash speed head-on at a tower's face), angle_edge (a degree
## either side of the computed angle, asin(crash speed / top speed), at top speed along a tower's face) and offset_edges (the grazing
## offset at a Turret and at a tank, from the computed 0.8 m plus 0.97 times the radius). Run by crash.gd. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")

## The slow nudge (AC-3): its speed, m/s.
const NUDGE_SPEED: float = 3.5
## The step either side of an edge: m/s for the speed, degrees for the angle, metres for an offset off the axis.
const SPEED_STEP: float = 0.1
const ANGLE_STEP: float = 1.0
const OFFSET_STEP: float = 0.01
## The gap a nudge starts from, metres: room for the stick to bring the Unit to its speed.
const NUDGE_GAP: float = 3.0
## The gap a Unit is put flush at, metres: closer than the contact margin shows.
const FLUSH_GAP: float = 0.02
## The ticks a Unit spins on the spot each way, held against a piece (0.77 rad/s turns it about 88 degrees in 120), and the
## ticks it is pinned with the throttle held (3 s).
const SPIN_TICKS: int = 120
const PIN_TICKS: int = 180
## The share of its top speed along the face that a Unit which slid along a tower's face must keep.
const SLID_SHARE: float = 0.9
## The ticks a graze is followed after its first touch.
const GRAZE_FOLLOW: int = 12
## The ticks after its first touch from which a pinned Unit is judged to be at rest: the tick of the touch moved it part of a
## step, and the next tick's previous velocity is that part.
const SETTLE_AFTER_CONTACT: int = 2

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().restore_all(true)
	await _only_stops()
	await _pinned()
	await _speed_edge()
	await _angle_edge()
	await _offset_edges()


## The Tall pieces the nudge and the spin are made at: [label, kind, direction, gap]; Player 1 at Base 1's tower, leg and Turret
## (its own, which does not shoot it) and at the depot's south tank from the middle.
func _pieces() -> Array[Dictionary]:
	return [
		{"label": "the corner tower", "path": Kit21.path_of("tower", 0), "dir": Kit21.toward(0)},
		{"label": "the water tower's leg", "path": Kit21.path_of("leg", 0), "dir": Kit21.toward(0)},
		{"label": "the Turret", "path": Kit21.path_of("turret", 0), "dir": Kit21.toward(0)},
		{"label": "the depot's south tank", "path": Kit21.path_of(Kit21.TANKS[2]), "dir": Vector3.BACK}]


## The top speed from the data, m/s.
func _top() -> float:
	return _k.gyro_stats().max_speed


## The Gyrocopter of Player 1 flown as a stick pressed to `speed` m/s at a piece, from NUDGE_GAP, until 12 ticks after its first
## touch (or its death). Returns the flight and the line.
func _nudge(piece: Dictionary, speed: float) -> Dictionary:
	var flight_line: Dictionary = _k.line(piece["path"], piece["dir"], 0.0, NUDGE_GAP)
	var over: Callable = func() -> bool: return not _q.units.units[0].is_alive or (_k.watch.first_wall(0) >= 0 and (_k.watch.rows[0] as Array).size() > _k.watch.first_wall(0) + Kit21.AFTER_CONTACT)
	var flight: Dictionary = await _k.fly(0, Kit21.GYRO, flight_line["start"], flight_line["dir"], 200, speed / _top(), 0, over)
	flight["line"] = flight_line
	return flight


## The real speed of a Unit on its last row, and how far its nose is from the face it was flown at (negative: past it).
func _stopped_flush(flight: Dictionary) -> Array[float]:
	var last: Dictionary = (flight["rows"] as Array)[-1]
	return [Watch.flat(last["real"]), _k.nose_gap(last["at"], flight["line"])]


## only_stops (AC-3): the slow nudge into each Tall kind, the grazes and the turn on the spot flush against each.
func _only_stops() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for piece: Dictionary in _pieces():
		var flight: Dictionary = await _nudge(piece, NUDGE_SPEED)
		var summary: Dictionary = _k.watch.summary(0, int(flight["hit"]))
		var stopped: Array[float] = _stopped_flush(flight)
		_q.kit.need(problems, flight["hit"] >= 0 and flight["dead"] < 0 and flight["unit"].is_alive, "the nudge into %s: touched at row %d, dead at row %d" % [piece["label"], flight["hit"], flight["dead"]])
		_q.kit.need(problems, stopped[0] < Quick.STOP_SPEED and absf(stopped[1]) <= Kit21.FLUSH_SLACK, "the nudge into %s ended at %.3f m/s with its nose %.3f m from the face" % [piece["label"], stopped[0], stopped[1]])
		var first_arrival: float = float(Watch.walls(flight["rows"][flight["hit"]])[0]["arrival"]) if flight["hit"] >= 0 else -1.0
		_q.kit.need(problems, absf(first_arrival - NUDGE_SPEED) <= 0.01 and float(summary["max_arrival"]) < _k.crash_speed(), "the nudge into %s arrived at %.3f m/s (%.1f asked), the largest arrival %.3f" % [piece["label"], first_arrival, NUDGE_SPEED, summary["max_arrival"]])
		notes.append("%s at %.1f m/s: alive, stopped flush (%.3f m)" % [piece["label"], first_arrival, stopped[1]])
	for alpha: float in [8.0, 10.0, 12.0, 13.0]:
		var flight: Dictionary = await _graze(alpha)
		var slid: Dictionary = _slid(flight)
		_q.kit.need(problems, flight["dead"] < 0 and slid["moved"] >= 2.0 and slid["speed"] >= SLID_SHARE * _top() * cos(deg_to_rad(alpha)), "the graze at %.0f degrees: dead at row %d, slid %.2f m at %.2f m/s" % [alpha, flight["dead"], slid["moved"], slid["speed"]])
		notes.append("a graze at %.0f degrees to the face (arrival %.2f m/s): alive, slid %.1f m along it at %.1f m/s" % [alpha, slid["arrival"], slid["moved"], slid["speed"]])
	for piece: Dictionary in _pieces():
		var spun: Dictionary = await _spin(piece)
		_q.kit.need(problems, spun["alive"] and spun["wall_ticks"] >= 5 and float(spun["max_arrival"]) < _k.crash_speed(), "the spin against %s: alive %s, %d ticks of wall contact, the largest arrival %.3f" % [piece["label"], spun["alive"], spun["wall_ticks"], spun["max_arrival"]])
		notes.append("a turn on the spot flush against %s: alive, %d ticks of contact, the largest arrival %.3f m/s" % [piece["label"], spun["wall_ticks"], spun["max_arrival"]])
	_q.kit.verdict("only_stops", problems, "below the crash speed (%.1f m/s) a Tall piece only stops the Gyrocopter: %s" % [_k.crash_speed(), "; ".join(notes)])


## A graze of the tower's north face at an angle to it, at full throttle; the flight, with the line.
func _graze(alpha: float) -> Dictionary:
	var graze_line: Dictionary = _k.graze_line(Kit21.path_of("tower", 0), alpha)
	var over: Callable = func() -> bool: return not _q.units.units[0].is_alive or (_k.watch.first_wall(0) >= 0 and (_k.watch.rows[0] as Array).size() > _k.watch.first_wall(0) + GRAZE_FOLLOW)
	var flight: Dictionary = await _k.fly(0, Kit21.GYRO, graze_line["start"], graze_line["dir"], 240, 1.0, 0, over)
	flight["graze"] = graze_line
	return flight


## What a graze did after its first touch: the arrival on it (the previous tick's real velocity into the face), how far along the
## face the Unit moved in the ticks that followed and the real speed it ended at.
func _slid(flight: Dictionary) -> Dictionary:
	var rows: Array = flight["rows"]
	var hit: int = int(flight["hit"])
	if hit < 0:
		return {"arrival": 0.0, "moved": 0.0, "speed": 0.0}
	var first: Dictionary = rows[hit]
	var last: Dictionary = rows[-1]
	return {"arrival": float(Watch.walls(first)[0]["arrival"]), "moved": absf(((last["at"] as Vector3) - (first["at"] as Vector3)).x), "speed": Watch.flat(last["real"])}


## A turn on the spot flush against a piece: the nose FLUSH_GAP from the face, no throttle, steered left, right and left again.
## {alive, wall_ticks (rows with a wall's collision), max_arrival}.
func _spin(piece: Dictionary) -> Dictionary:
	var flight_line: Dictionary = _k.line(piece["path"], piece["dir"], 0.0, FLUSH_GAP)
	await _k.stage(0, Kit21.GYRO, flight_line["start"], flight_line["dir"])
	_k.watch.clear()
	_k.watch.logging = true
	_k.watch.phase = "spin"
	await _k.drive(0, SPIN_TICKS, 0.0, 1)
	await _k.drive(0, 2 * SPIN_TICKS, 0.0, -1)
	await _k.drive(0, SPIN_TICKS, 0.0, 1)
	_k.watch.logging = false
	var summary: Dictionary = _k.watch.summary(0)
	return {"alive": summary["alive"] and _q.units.units[0].is_alive, "wall_ticks": summary["wall_ticks"], "max_arrival": summary["max_arrival"]}


## pinned (AC-3): a Gyrocopter flush against a leg with the throttle held for 3 s commands its top speed and moves at zero; the
## same after a slow nudge at 3.9 m/s into the leg, whose command climbs from 3.9 to the top while it does not move. A test on the
## command would destroy it a quarter of a second after it crept into the leg.
func _pinned() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var leg: String = Kit21.path_of("leg", 0)
	for start_speed: float in [0.0, _k.crash_speed() - SPEED_STEP]:
		var flight_line: Dictionary = _k.line(leg, Kit21.toward(0), 0.0, FLUSH_GAP if start_speed == 0.0 else NUDGE_GAP)
		await _k.stage(0, Kit21.GYRO, flight_line["start"], flight_line["dir"])
		_k.watch.clear()
		_k.watch.logging = true
		_k.watch.phase = "approach"
		if start_speed > 0.0:
			var touched: Callable = func() -> bool: return _k.watch.first_wall(0) >= 0
			await _k.drive(0, 200, start_speed / _top(), 0, touched)
		_k.watch.phase = "pinned"
		var held: int = await _k.drive(0, PIN_TICKS, 1.0, 0)
		_k.watch.logging = false
		var contact: int = _k.watch.first_wall(0)
		var whole: Dictionary = _k.watch.summary(0)
		var pinned: Dictionary = _k.watch.summary(0, contact + SETTLE_AFTER_CONTACT)
		var unit: Unit = _q.units.units[0]
		_q.kit.need(problems, contact >= 0 and held == PIN_TICKS and unit.is_alive and whole["alive"], "pinned from %.1f m/s: touched at row %d, held %d of %d ticks, alive %s" % [start_speed, contact, held, PIN_TICKS, unit.is_alive])
		_q.kit.need(problems, float(whole["max_cmd"]) >= 0.99 * _top() and float(whole["max_arrival"]) < _k.crash_speed(), "pinned from %.1f m/s: the command reached %.2f of %.1f, the largest arrival on the way in %.3f against the crash speed %.1f" % [start_speed, whole["max_cmd"], _top(), whole["max_arrival"], _k.crash_speed()])
		_q.kit.need(problems, float(pinned["max_real"]) <= 0.01 and float(pinned["max_arrival"]) <= 0.01 and int(pinned["wall_ticks"]) == int(pinned["ticks"]), "pinned from %.1f m/s, from %d ticks after the touch: the real speed %.4f, the largest arrival %.4f, contact on %d of %d ticks" % [start_speed, SETTLE_AFTER_CONTACT, pinned["max_real"], pinned["max_arrival"], pinned["wall_ticks"], pinned["ticks"]])
		notes.append("from %.1f m/s: arrival %.2f m/s on the way in, then the command %.1f m/s, the real speed %.4f m/s, contact on %d of %d ticks, alive" % [start_speed, whole["max_arrival"], whole["max_cmd"], pinned["max_real"], pinned["wall_ticks"], pinned["ticks"]])
	_q.kit.verdict("pinned", problems, "a Gyrocopter against a leg with the throttle held for %.0f s (%d ticks) commands its top speed while its real motion stays at zero, and lives (%s)" % [PIN_TICKS / 60.0, PIN_TICKS, "; ".join(notes)])


## speed_edge (AC-3): head-on at the tower's face as a stick pressed to a speed: 0.1 m/s under the crash speed it only stops the
## Gyrocopter, 0.1 m/s over it destroys it on the tick of the contact; well under and well over agree.
func _speed_edge() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var piece: Dictionary = _pieces()[0]
	for speed: float in [NUDGE_SPEED, _k.crash_speed() - SPEED_STEP, _k.crash_speed() + SPEED_STEP, 2.0 * _k.crash_speed()]:
		var flight: Dictionary = await _nudge(piece, speed)
		var should_die: bool = speed >= _k.crash_speed()
		var dead: int = int(flight["dead"])
		var rows: Array = flight["rows"]
		var before: float = -1.0
		if dead > 0:
			before = Watch.flat(rows[dead - 1]["real"])
		elif int(flight["hit"]) >= 0:
			before = Watch.flat(rows[int(flight["hit"])]["prev"])
		_q.kit.need(problems, (dead >= 0) == should_die and flight["unit"].is_alive != should_die, "head-on at %.2f m/s: dead at row %d (a crash was %s)" % [speed, dead, "expected" if should_die else "not expected"])
		_q.kit.need(problems, absf(before - speed) <= 0.01, "head-on at %.2f m/s: the speed it arrived with was %.3f" % [speed, before])
		notes.append("%.2f m/s: %s (arrival %.3f)" % [speed, "destroyed at the contact" if dead >= 0 else "stopped, alive", before])
	_q.kit.verdict("speed_edge", problems, "head-on at the corner tower's face as a stick pressed to a speed (the crash speed is %.1f m/s): %s" % [_k.crash_speed(), "; ".join(notes)])


## angle_edge (AC-3): a graze of the tower's face at full throttle, a degree either side of asin(crash speed / top speed): the
## first only stops the Gyrocopter and slides it on, the second destroys it at the contact; the arrival on each is the top speed
## times the sine of its angle to the face.
func _angle_edge() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var computed: float = rad_to_deg(asin(_k.crash_speed() / _top()))
	for alpha: float in [computed - ANGLE_STEP, computed - 0.1, computed + 0.1, computed + ANGLE_STEP]:
		var flight: Dictionary = await _graze(alpha)
		var should_die: bool = _top() * sin(deg_to_rad(alpha)) >= _k.crash_speed()
		var dead: int = int(flight["dead"])
		var rows: Array = flight["rows"]
		var arrival: float = 0.0
		if dead > 0:
			arrival = Watch.flat(rows[dead - 1]["real"]) * sin(deg_to_rad(alpha))
		elif int(flight["hit"]) >= 0:
			arrival = float(Watch.walls(rows[int(flight["hit"])])[0]["arrival"])
		_q.kit.need(problems, (dead >= 0) == should_die, "the graze at %.2f degrees: dead at row %d (a crash was %s, the arrival should be %.3f)" % [alpha, dead, "expected" if should_die else "not expected", _top() * sin(deg_to_rad(alpha))])
		_q.kit.need(problems, absf(arrival - _top() * sin(deg_to_rad(alpha))) <= 0.02, "the graze at %.2f degrees arrived at %.3f m/s, the top speed times the sine is %.3f" % [alpha, arrival, _top() * sin(deg_to_rad(alpha))])
		notes.append("%.2f degrees: %s (arrival %.3f)" % [alpha, "destroyed at the contact" if dead >= 0 else "slid on, alive", arrival])
	_q.kit.verdict("angle_edge", problems, "at the top speed (%.1f m/s) along the corner tower's face, a degree either side of the computed %.2f degrees (asin(%.1f / %.1f)): %s" % [_top(), computed, _k.crash_speed(), _top(), "; ".join(notes)])
	measured.append("angle=%.2f" % computed)


## offset_edges (AC-3): flown at full throttle at a Turret (radius from its data) and at a tank on a line `offset` metres off its
## axis: on the near side of the computed grazing offset (half the Gyrocopter's width plus 0.97 of the radius) the front corner
## meets the cylinder's side at the crash speed or more and the Gyrocopter is destroyed; on the far side it arrives under it and
## flies on, alive.
func _offset_edges() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var half: float = _k.gyro_stats().collision_size.x / 2.0
	var share: float = sqrt(1.0 - pow(_k.crash_speed() / _top(), 2.0))
	for target: Dictionary in [{"label": "the Turret", "path": Kit21.path_of("turret", 0), "dir": Kit21.toward(0), "gap": Kit21.RUN_UP}, {"label": "the depot's south tank", "path": Kit21.path_of(Kit21.TANKS[2]), "dir": Vector3.BACK, "gap": Kit21.RUN_UP}]:
		var shape: CylinderShape3D = null
		for child: Node in _k.map().get_node(target["path"]).get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is CylinderShape3D:
				shape = (child as CollisionShape3D).shape as CylinderShape3D
		var radius: float = shape.radius
		var computed: float = half + share * radius
		for offset: float in [computed - OFFSET_STEP, computed + OFFSET_STEP]:
			var flight_line: Dictionary = _k.line(target["path"], target["dir"], offset, target["gap"])
			var flight: Dictionary = await _k.crashing(0, flight_line["start"], flight_line["dir"])
			var should_die: bool = offset < computed
			var dead: int = int(flight["dead"])
			var arrival: float = 0.0
			if dead > 0:
				arrival = Watch.flat(flight["rows"][dead - 1]["real"])
			elif int(flight["hit"]) >= 0:
				arrival = float(Watch.walls(flight["rows"][int(flight["hit"])])[0]["arrival"])
			_q.kit.need(problems, (dead >= 0) == should_die, "%s %.3f m off its axis (the computed offset is %.3f): dead at row %d, a crash was %s" % [target["label"], offset, computed, dead, "expected" if should_die else "not expected"])
			notes.append("%s %.3f m off the axis: %s%s" % [target["label"], offset, "destroyed" if dead >= 0 else "grazed it, alive", "" if dead >= 0 else " (arrival %.2f m/s)" % arrival])
		measured.append("offset_%s=%.3f" % [String(target["label"]).replace("the ", "").replace(" ", "_").replace("'s", ""), computed])
	_q.kit.verdict("offset_edges", problems, "flown at full throttle on a line off the axis of a cylinder: %s (the computed offset is half the Gyrocopter's width plus %.3f of the radius)" % ["; ".join(notes), share])
