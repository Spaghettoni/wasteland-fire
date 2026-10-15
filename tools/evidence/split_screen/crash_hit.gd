extends RefCounted
## A crash on the tick of something else that destroys the Gyrocopter, for the crash scenario (Story 021 AC-6, the sentences on a hit
## and on the Fuel): crash_with_a_hit (a Unit's Shot of Player 1's Motorbike lands on Player 2's one hit point Gyrocopter a frame
## before the frame it crashes into the depot's south tank, in that very frame and a frame after, and a tool's hit comes in the frame
## before it too: each time it is destroyed once, one Gyrocopter Token is taken, one Explosion plays, and where the Shot ends is
## pinned) and crash_with_an_empty_tank (a tank that empties on the tick of the contact destroys the Gyrocopter once, by the Fuel:
## its tick burns the Fuel first and ends there, so it stops one step short of the tank where a crash would have it flush). The
## frames are timed from control flights, as story 014's doubles are. Run by crash.gd. Tooling only. Every number comes from the
## game's data and the controls; the scenario types only its test inputs.

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const Watch: GDScript = preload("res://tools/evidence/split_screen/crash_watch.gd")

## Metres east of the tank's contact place Player 1's Motorbike stands, facing west, and the frames either side of the crash frame the
## Shot is timed to land in.
const SHOOTER_DISTANCE: float = 14.0
const SHOT_OFFSETS: Array[int] = [-1, 0, 1]
## The ticks a flight is followed after its crash frame, for the Shot to end.
const AFTER_TICKS: int = 90
## The frames a flight may take.
const FLIGHT_FRAMES: int = 300

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit21
var _q: Quick
## The geometry of the flight at the south tank: {start, dir, face, half, box} and the contact place of the Gyrocopter's origin.
var _line: Dictionary = {}
var _contact: Vector3 = Vector3.ZERO
var _shooter: Vector3 = Vector3.ZERO
## The frames the controls measured: from a spawn by the tool to the crash, and from the fire key to the Shot's kill of a stationary Gyrocopter.
var _crash_frames: int = -1
var _key_to_kill: int = -1


func _init(kit: Kit21) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_line = _k.line(Kit21.path_of(Kit21.TANKS[2]), Vector3.BACK)
	var dir: Vector3 = _line["dir"]
	_contact = (_line["start"] as Vector3) + dir * (float(_line["face"]) - dir.dot(_line["start"]) - float(_line["half"]))
	_shooter = _contact + Vector3(SHOOTER_DISTANCE, 0.0, 0.0)
	await _k.walls().restore_all(true)
	await _crash_with_a_hit()
	await _crash_with_an_empty_tank()


## Waits until the physics frame, however far off, then sets the keys (the Token kit's press_on() waits 60 ticks at most; this is the
## Round kit's wait of story 014). A coroutine.
func _press_on(frame: int, keys: Array[Key]) -> void:
	while Engine.get_physics_frames() < frame - 1:
		await _q.kit.tick()
	await _q.tokens.press_on(frame, keys)


## The destruction events of a Player since a mark of the Token kit's record.
func _deaths(player: int, mark: int) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in _q.tokens.events_of(&"destroyed", mark):
		if int(event["arg"]) == player:
			found.append(event)
	return found


## Player 1's Motorbike stands at the shooter's place facing west and Player 2's Unit is retyped as a Gyrocopter at `at` facing `facing`
## with one hit point and its tank full: the frame it was put down in. The throttle of Player 2 is held when `fly` says so.
func _setup(at: Vector3, facing: Vector3, fly: bool) -> int:
	await _k.walls().stage(0, Quick.MOTORBIKE, _shooter, Vector3.LEFT)
	_q.harness.drive(1, 1 if fly else 0, 0)
	var frame: int = Engine.get_physics_frames()
	_q.units.retype(1, Kit21.GYRO, at, facing)
	var unit: Unit = _q.units.units[1]
	unit.refuel(unit.fuel_capacity)
	unit.apply_damage(unit.hit_points - 1.0)
	return frame


## The two controls: the frames a Gyrocopter spawned at the line's start by the tool takes to crash into the tank, and the frames
## from Player 1's fire key to the kill of a stationary one hit point Gyrocopter on the contact place.
func _measure() -> void:
	var mark: int = _q.tokens.events.size()
	var spawned: int = await _setup(_line["start"], _line["dir"], true)
	for _tick: int in FLIGHT_FRAMES:
		await _q.kit.tick()
		if not _deaths(1, mark).is_empty():
			break
	_q.harness.release_all()
	var died: Array[Dictionary] = _deaths(1, mark)
	_crash_frames = int(died[0]["now"]["frame"]) - spawned if not died.is_empty() else -1
	await _k.mines().revive(1)
	mark = _q.tokens.events.size()
	await _setup(_contact, _line["dir"], false)
	var pressed: int = Engine.get_physics_frames()
	await _q.tokens.press_on(pressed, Tokens.keys(&"fire", 0))
	for _tick: int in FLIGHT_FRAMES:
		await _q.kit.tick()
		if not _deaths(1, mark).is_empty():
			break
	died = _deaths(1, mark)
	_key_to_kill = int(died[0]["now"]["frame"]) - pressed if not died.is_empty() else -1
	await _k.mines().revive(1)
	measured.append("crash_frames=%d key_to_kill=%d" % [_crash_frames, _key_to_kill])


## crash_with_a_hit (AC-6).
func _crash_with_a_hit() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _measure()
	_q.kit.need(problems, _crash_frames > _key_to_kill and _key_to_kill > 0, "the controls: %d frames to the crash, %d from the key to the kill" % [_crash_frames, _key_to_kill])
	var unit: Unit = _q.units.units[1]
	for offset: int in SHOT_OFFSETS:
		var mark: int = _q.tokens.events.size()
		var records: int = _k.destroyed.size()
		var tokens_before: int = _k.tokens(1)
		var blasts_before: int = _k.blasts().size()
		var shots: int = _q.units.shots.size()
		var spawned: int = await _setup(_line["start"], _line["dir"], true)
		await _press_on(spawned + _crash_frames + offset - _key_to_kill, Tokens.keys(&"fire", 0))
		var peak: int = 0
		for _tick: int in AFTER_TICKS + _crash_frames:
			await _q.kit.tick()
			peak = maxi(peak, _k.blasts().size() - blasts_before)
		_q.harness.release_all()
		var deaths: Array[Dictionary] = _deaths(1, mark)
		var label: String = "the Shot timed %+d frames from the crash" % offset
		_q.kit.need(problems, deaths.size() == 1 and _k.destroyed.size() == records + 1, "%s: %d destructions of Player 2 and %d records" % [label, deaths.size(), _k.destroyed.size() - records])
		_q.kit.need(problems, tokens_before - _k.tokens(1) == 1, "%s: the Gyrocopter Tokens went from %d to %d" % [label, tokens_before, _k.tokens(1)])
		_q.kit.need(problems, peak == 1, "%s: %d Explosions played at most at once" % [label, peak])
		var frame: int = int(deaths[0]["now"]["frame"]) if not deaths.is_empty() else -1
		var gap: float = _k.nose_gap(_k.destroyed[-1]["at"], _line) if _k.destroyed.size() > records else INF
		var by_crash: bool = frame == spawned + _crash_frames
		_q.kit.need(problems, frame == spawned + _crash_frames + mini(offset, 0) and by_crash == (offset >= 0), "%s: destroyed in frame %d (the crash frame is %d), %.3f m from the face" % [label, frame, spawned + _crash_frames, gap])
		_q.kit.need(problems, _q.units.shots.size() == shots + 1, "%s: %d Shots were fired" % [label, _q.units.shots.size() - shots])
		var end: Vector3 = _q.units.shot_ends[shots] if _q.units.shot_ends.size() > shots else Vector3.INF
		var end_note: String = "ended at x %.2f (the Gyrocopter's body spans x %.2f to %.2f, the Motorbike's range ends at x %.2f)" % [end.x, _contact.x - 0.8, _contact.x + 0.8, _shooter.x - 1.6 - _q.units.stats(Quick.MOTORBIKE).weapon_range] if end != Vector3.INF else "still flying"
		notes.append("%s: destroyed once in frame %d (%s), one Token, one Explosion; the Shot %s" % [label, frame, "by the crash, flush against the tank" if by_crash else "by the Shot, %.3f m short of the tank" % gap, end_note])
		await _k.mines().revive(1)
	# A tool's hit in the very frame of the crash, before the Unit's tick (a scenario resumes ahead of the nodes' ticks): the Unit's own
	# tick of the crash frame never runs.
	var mark_tool: int = _q.tokens.events.size()
	var tokens_before: int = _k.tokens(1)
	var blasts_before: int = _k.blasts().size()
	var spawned_tool: int = await _setup(_line["start"], _line["dir"], true)
	for _tick: int in _crash_frames:
		await _q.kit.tick()
	unit.apply_damage(5.0)
	for _tick: int in 10:
		await _q.kit.tick()
	_q.harness.release_all()
	var deaths_tool: Array[Dictionary] = _deaths(1, mark_tool)
	_q.kit.need(problems, deaths_tool.size() == 1 and tokens_before - _k.tokens(1) == 1 and _k.blasts().size() == blasts_before + 1, "a hit in the crash frame: %d destructions, the Gyrocopter Tokens %d to %d, %d Explosions" % [deaths_tool.size(), tokens_before, _k.tokens(1), _k.blasts().size() - blasts_before])
	notes.append("a tool's hit in the crash frame, ahead of the Unit's tick (frame %d of %d): destroyed once, one Token, one Explosion, and the crash did not come after it" % [int(deaths_tool[0]["now"]["frame"]) - spawned_tool if not deaths_tool.is_empty() else -1, _crash_frames])
	await _k.mines().revive(1)
	_q.kit.verdict("crash_with_a_hit", problems, "a one hit point Gyrocopter flown at the depot's south tank (it crashes %d frames after the tool put it down), hit by Player 1's Shot timed to land %s: %s" % [_crash_frames, SHOT_OFFSETS, "; ".join(notes)])


## crash_with_an_empty_tank (AC-6): the control flight (a copy of the stats with the crash off and a full tank) shows where the tank
## stands at each tick and the tick of the first contact; the real flight starts with the tank that is empty half a tick's burn
## after the tick before the contact and ends with the Fuel.
func _crash_with_an_empty_tank() -> void:
	var problems: PackedStringArray = []
	var base: UnitStats = _k.gyro_stats()
	var unit: Unit = _q.units.units[1]
	var plan: Dictionary = {}
	for variant: String in ["control", "real"]:
		var stats: UnitStats = base.duplicate() as UnitStats
		if variant == "control":
			stats.crash_speed = 0.0
			stats.spawn_fuel_fraction = 1.0
		else:
			stats.spawn_fuel_fraction = float(plan["share"])
		await _k.walls().stage(0, Quick.MOTORBIKE, _shooter, Vector3.LEFT)
		await _q.put(1, stats, _line["start"], _line["dir"])
		_k.watch.clear()
		_k.watch.logging = true
		var mark: int = _q.tokens.events.size()
		var records: int = _k.destroyed.size()
		var blasts_before: int = _k.blasts().size()
		var tokens_before: int = _k.tokens(1)
		var settled: float = unit.fuel
		for _tick: int in FLIGHT_FRAMES:
			_q.harness.drive(1, 1, 0)
			await _q.kit.tick()
			if not unit.is_alive or (variant == "control" and _k.watch.first_wall(1) >= 0 and (_k.watch.rows[1] as Array).size() > _k.watch.first_wall(1) + 2):
				break
		_k.watch.logging = false
		_q.harness.release_all()
		if variant == "control":
			var contact: int = _k.watch.first_wall(1)
			var rows: Array = _k.watch.rows[1]
			_q.kit.need(problems, contact > 0, "the control never touched the tank")
			var before_contact: float = float(rows[contact - 1]["fuel"])
			var at_contact: float = float(rows[contact]["fuel"])
			var spawn_tank: float = stats.fuel_capacity
			var needed: float = spawn_tank - before_contact + 0.5 * (before_contact - at_contact)
			plan = {"contact": contact, "share": needed / spawn_tank, "needed": needed}
			measured.append("tank_for_the_contact=%.4f" % needed)
		else:
			await _q.kit.advance(2)
			var deaths: Array[Dictionary] = _deaths(1, mark)
			var row: int = (_k.watch.rows[1] as Array).size() - 1
			var gap: float = _k.nose_gap(_k.destroyed[-1]["at"], _line) if _k.destroyed.size() > records else -INF
			_q.kit.need(problems, deaths.size() == 1 and _k.destroyed.size() == records + 1 and row == int(plan["contact"]), "the empty tank: %d destructions of Player 2 and %d records, on row %d (the contact was on row %d)" % [deaths.size(), _k.destroyed.size() - records, row, plan["contact"]])
			_q.kit.need(problems, unit.fuel == 0.0 and not unit.is_alive and gap > Kit21.FLUSH_SLACK, "the empty tank: %.3f Fuel left, %.3f m short of the face (a crash would be flush within %.2f m)" % [unit.fuel, gap, Kit21.FLUSH_SLACK])
			_q.kit.need(problems, tokens_before - _k.tokens(1) == 1 and _k.blasts().size() == blasts_before + 1, "the empty tank: the Gyrocopter Tokens went %d to %d, %d Explosions came" % [tokens_before, _k.tokens(1), _k.blasts().size() - blasts_before])
			_q.kit.verdict("crash_with_an_empty_tank", problems, "a Gyrocopter whose tank (%.4f of %.0f Fuel at the spawn, settled to %.4f) empties on the tick of its control's first contact (row %d) was destroyed once on that row, by the Fuel: it burned its Fuel first and ended its tick there, %.3f m short of the tank where a crash is flush (within %.2f m); one Token, one Explosion" % [float(plan["needed"]), stats.fuel_capacity, settled, row, gap, Kit21.FLUSH_SLACK])
	await _k.mines().revive(1)
