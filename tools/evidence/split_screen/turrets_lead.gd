extends RefCounted
## The barrel and the lead of the turrets scenario (Story 013 AC-3), on open ground: a fixture Turret
## of the shipped scene and data on the arena's flat floor (turrets_kit.gd make_arena()), where
## nothing hides a target. shot_timing: a Shot first moves in the tick after the one it was fired
## in, successive Shots are one cadence apart, each hit takes the damage times the matrix's 1.0 off
## the Unit and the HUD says so. barrel: the barrel turns at the data's rate and a Shot leaves only
## with the barrel on the aim. lead: against a Motorbike that holds its line at top speed 20 m and
## 30 m away every Shot hits; a close crossing is held fire at where the barrel cannot keep up; a
## Buggy circling at its tightest radius can make it miss. Run by turrets.gd. Implements:
## production/epics/wasteland-fire/story-013-turrets.md AC-3. Tooling only. Every number comes from
## the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

## The story's cadence: a Shot every 0.8 s, 48 ticks at 60 a second (AC-3).
const CADENCE_TICKS: int = 48
## A Unit is at its top speed from this fraction of the data's maximum.
const TOP_SPEED: float = 0.98
## A swing of 90 degrees takes 1.0 s: the ticks it may take, one more or less (AC-3).
const SWING_TICKS: int = 60
## Metres a crossing starts before and ends after the fixture's own line, so the Unit is at top speed
## before it comes into reach and every Shot it draws has ended before the run does.
const RUN: float = 55.0
## The crossings' perpendicular distances from the fixture, metres, and the close one.
const CROSS_NEAR: float = 20.0
const CROSS_FAR: float = 30.0
## The circle's centre lies this far east of the fixture, metres (AC-3: about 20 m away).
const CIRCLE_AT: float = 20.0
## Ticks the hard turn of a dodge is held after the Shot leaves, long enough for the Shot to fly.
const DODGE_TICKS: int = 40
## The crossings the barrel cannot keep up with at the closest approach (a Motorbike at top speed goes
## round it faster than 90 degrees a second inside speed / turn rate = 15.3 m, AC-3: about 15), the
## last of them past that limit, so it is tracked all the way. A Shot may be fired this close to the
## radius inside which the angular rate is over the barrel's, metres.
const CLOSE_CROSSINGS: Array[float] = [8.0, 12.0, 18.0]
const HOLD_SLACK: float = 0.5
## How far, metres, the mean of where the steady Shots of the crossings ended along the Motorbike's
## track may differ from what the geometry says. A Shot ends on the box's near side, half its width
## before the centre line it was aimed at, and on the first tick whose step reaches it, half a tick
## late on average, so it ends ahead of the Motorbike's centre by the Motorbike's speed times
## (half the width over the Shot's speed plus half a tick); a launch lag assumed in the aim (the
## measured one is none) would shift that by the speed times the lag.
const TRACK_TOLERANCE: float = 0.2
## Passes of a kind, and the length of the circling run in seconds.
const PASSES: int = 4
const CIRCLE_SECONDS: int = 12

var _k: Kit13
## The Unit's place and real speed in each physics frame of a pass, by frame.
var _frames: Dictionary = {}
## What each check found, for the CHECK lines and the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The three checks, on a fixture of Player 1's, armed at Player 2's Unit.
func run() -> void:
	_k.make_arena(0)
	await _shot_timing()
	await _barrel()
	await _lead()
	_k.free_arena()


## The world place of a point of the arena, dx east and dz south of the fixture.
func at(dx: float, dz: float) -> Vector3:
	return Kit13.ARENA_CENTRE + Vector3(dx, 0.0, dz)


## shot_timing (AC-3): the first Shot's first move, the cadence, the damage and the HUD.
func _shot_timing() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var who: Turret = _k.fixture
	var step: float = who.stats.shot_speed / float(Engine.physics_ticks_per_second)
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.TRUCK, at(0.0, -20.0), Vector3.BACK)
	var before: float = q.units.units[1].hit_points
	await q.kit.advance(5 * CADENCE_TICKS + CADENCE_TICKS / 2)
	var rows: Array[Dictionary] = _k.firing.slice(mark)
	q.kit.need(problems, rows.size() >= 4, "the fixture fired %d Shots in five cadences" % rows.size())
	var gaps: Array[int] = []
	for index: int in range(1, rows.size()):
		gaps.append(int(rows[index]["frame"]) - int(rows[index - 1]["frame"]))
	q.kit.need(problems, gaps.all(func(gap: int) -> bool: return gap == CADENCE_TICKS), "Shots %s frames apart, not %d" % [gaps, CADENCE_TICKS])
	var moves: int = ceili(_entry(rows[0], q.units.units[1]) / step - 0.0001) if not rows.is_empty() else -1
	var flight: int = int(rows[0]["end_frame"]) - int(rows[0]["frame"]) if not rows.is_empty() else -1
	q.kit.need(problems, flight == moves and _k.hit(rows[0], 1), "the first Shot flew %d ticks to a face %d moves away (hit %s): its first move is not the tick after it was fired" % [flight, moves, _k.hit(rows[0], 1)])
	var landed: int = 0
	for row: Dictionary in rows:
		landed += 1 if _k.hit(row, 1) and int(row["end_frame"]) >= 0 else 0
	var lost: float = before - q.units.units[1].hit_points
	q.kit.need(problems, landed == rows.size(), "%d of %d Shots hit a Truck that stood still" % [landed, rows.size()])
	q.kit.need(problems, is_equal_approx(lost, who.stats.damage * landed), "the Truck lost %.1f for %d hits of %.1f" % [lost, landed, who.stats.damage])
	await _k.stage(1, Quick.MOTORBIKE, at(0.0, -20.0), Vector3.BACK)
	await _wait_first_hit(1)
	var hud: Label = q.units.huds[1].find_child("HitPointsLabel", true, false) as Label
	var line: String = hud.text if hud != null else ""
	q.kit.need(problems, line == "HP %d / %d" % [roundi(q.units.units[1].stats.max_hit_points - who.stats.damage), roundi(q.units.units[1].stats.max_hit_points)], "the Motorbike's HUD reads '%s' after one hit" % line)
	q.kit.verdict("shot_timing", problems, "a Shot first moves the tick after it is fired (flew %d ticks to a face %d moves away); successive Shots %s ticks apart (data: %.1f s); each hit took %.0f off a Truck that stood still (%d hits, 1.0 against every type); the Motorbike's HUD read '%s' after its first hit" % [
		flight, moves, gaps, who.stats.fire_interval_seconds, who.stats.damage, landed, line])


## barrel (AC-3): a 90-degree swing takes about a second at the data's rate, each tick no more than
## the rate times the tick, and every Shot of the module left with the barrel within the tolerance.
func _barrel() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var who: Turret = _k.fixture
	var per_tick: float = who.stats.turn_rate / float(Engine.physics_ticks_per_second)
	who.restore()
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.MOTORBIKE, at(CROSS_NEAR, 0.0), Vector3.BACK)
	var yaws: Array[float] = [who.head.rotation.y]
	for _tick: int in 2 * SWING_TICKS:
		await q.kit.tick()
		yaws.append(who.head.rotation.y)
	var biggest: float = 0.0
	var turned: int = 0
	var full: int = 0
	for index: int in range(1, yaws.size()):
		var step: float = absf(yaws[index] - yaws[index - 1])
		biggest = maxf(biggest, step)
		turned += 1 if step > 0.0000001 else 0
		full += 1 if absf(step - per_tick) <= 0.000001 else 0
	q.kit.need(problems, biggest <= per_tick + 0.000001, "the head turned %.6f rad in a tick, the rate allows %.6f" % [biggest, per_tick])
	q.kit.need(problems, full >= turned - 1, "the head turned at the full rate in %d of the %d ticks it turned" % [full, turned])
	q.kit.need(problems, is_equal_approx(absf(yaws.back()), PI / 2.0), "the head ended %.4f rad round, not a quarter turn" % yaws.back())
	var first: Dictionary = _k.firing[mark] if _k.firing.size() > mark else {}
	var swing_frames: int = int(first["frame"]) - _k.staged_frame if not first.is_empty() else -1
	q.kit.need(problems, not first.is_empty() and absi(swing_frames - SWING_TICKS) <= 2, "the first Shot left %d ticks after the Unit was put in play, a swing is %d" % [swing_frames, SWING_TICKS])
	var worst: float = 0.0
	for record: Dictionary in _k.firing:
		worst = maxf(worst, float(record["error"]))
	q.kit.need(problems, not _k.firing.is_empty() and worst <= who.stats.aim_tolerance, "a Shot left with the barrel %.3f m from the aim, the tolerance is %.2f" % [worst, who.stats.aim_tolerance])
	q.kit.verdict("barrel", problems, "a quarter turn: the head turned at the full %.4f rad/s (%.5f rad a tick, %.5f at most seen) in all but the last of %d ticks after the first sample and the first Shot left %d ticks after the Unit appeared; all %d Shots of the module so far left with the barrel within %.2f m of the aim (worst %.3f m)" % [
		who.stats.turn_rate, per_tick, biggest, turned, swing_frames, _k.firing.size(), who.stats.aim_tolerance, worst])


## lead (AC-3): crossings at top speed, a close one, a dodge and a circle.
func _lead() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var summary: PackedStringArray = []
	var along_total: float = 0.0
	var along_count: int = 0
	var along_worst: float = 0.0
	for distance: float in [CROSS_NEAR, CROSS_FAR]:
		var shots: int = 0
		var hits: int = 0
		for pass_index: int in PASSES:
			var rows: Array[Dictionary] = await _straight(Quick.MOTORBIKE, distance, 1.0 if pass_index % 2 == 0 else -1.0, false)
			for row: Dictionary in rows:
				shots += 1 if bool(row["steady"]) else 0
				hits += 1 if bool(row["steady"]) and bool(row["hit"]) else 0
				if bool(row["steady"]) and bool(row["hit"]):
					along_total += float(row["offset"])
					along_count += 1
					along_worst = maxf(along_worst, absf(float(row["offset"])))
		q.kit.need(problems, shots >= 2 * PASSES and hits == shots, "%d of %d steady Shots hit a Motorbike crossing at top speed %.0f m away" % [hits, shots, distance])
		summary.append("%d of %d Shots hit at %.0f m" % [hits, shots, distance])
	var along_mean: float = along_total / float(maxi(along_count, 1))
	var bike: UnitStats = q.units.stats(Quick.MOTORBIKE)
	var along_wanted: float = bike.max_speed * (bike.collision_size.x / 2.0 / _k.fixture.stats.shot_speed + 0.5 / float(Engine.physics_ticks_per_second))
	q.kit.need(problems, along_count > 0 and absf(along_mean - along_wanted) <= TRACK_TOLERANCE, "the steady Shots ended %.2f m ahead of the Motorbike's centre on average, the geometry says %.2f (within %.2f)" % [along_mean, along_wanted, TRACK_TOLERANCE])
	summary.append("on average %.2f m ahead of the Motorbike's centre along its track (the geometry says %.2f), %.2f m at most" % [along_mean, along_wanted, along_worst])
	measured.append("along=%.2f/%.2f" % [along_mean, along_worst])
	var close: PackedStringArray = []
	for crossing: float in CLOSE_CROSSINGS:
		var nearest: float = INF
		var count: int = 0
		for pass_index: int in PASSES:
			for row: Dictionary in await _straight(Quick.MOTORBIKE, crossing, 1.0 if pass_index % 2 == 0 else -1.0, false):
				nearest = minf(nearest, float(row["distance"]))
				count += 1
		var speed: float = q.units.stats(Quick.MOTORBIKE).max_speed
		var rate: float = _k.fixture.stats.turn_rate
		var holds: float = sqrt(speed * crossing / rate) if speed / crossing > rate else 0.0
		q.kit.need(problems, count > 0 and nearest >= holds - HOLD_SLACK, "a Shot was fired at a Motorbike %.1f m away in a crossing %.0f m off, where the barrel cannot keep up inside %.1f m" % [nearest, crossing, holds])
		close.append("%.0f m off: %d Shots, nearest %.1f m, held fire inside %.1f m" % [crossing, count, nearest, holds])
	var dodged: int = 0
	var dodge_shots: int = 0
	for pass_index: int in PASSES:
		for row: Dictionary in await _straight(Quick.MOTORBIKE, CROSS_NEAR, 1.0 if pass_index % 2 == 0 else -1.0, true):
			if bool(row["dodged"]):
				dodge_shots += 1
				dodged += 0 if bool(row["hit"]) else 1
	q.kit.need(problems, dodge_shots >= 1 and dodged >= 1, "%d of %d Shots missed a Motorbike that turned hard as they flew" % [dodged, dodge_shots])
	var laps: Array[Dictionary] = await _circle(Quick.BUGGY)
	var steady: int = 0
	var circle_hits: int = 0
	for row: Dictionary in laps:
		steady += 1 if bool(row["steady"]) else 0
		circle_hits += 1 if bool(row["steady"]) and bool(row["hit"]) else 0
	measured.append("circling_buggy_hits=%d/%d" % [circle_hits, steady])
	q.kit.verdict("lead", problems, "%s; close crossings (the barrel cannot follow a Unit whose angular rate round it is over the data's): %s; %d of %d Shots missed a Motorbike that turned hard while they flew; a Buggy circling at its tightest radius about %.0f m away drew %d Shots at speed and %d hit it (recorded)" % [
		", ".join(summary), "; ".join(close), dodged, dodge_shots, CIRCLE_AT, steady, circle_hits])


## One straight pass: Player 2's Unit as a type from RUN metres before the fixture's line to RUN
## metres after it, at `distance` east of it, the throttle held, going +z (forward 1) or -z. Returns
## one row per Shot of the fixture: {frame, speed, steady, distance, hit, error}. A coroutine.
func _straight(type_index: int, distance: float, forward: float, dodge: bool) -> Array[Dictionary]:
	var q: Quick = _k.w.s.q
	var unit: Unit = q.units.units[1]
	var heading: Vector3 = Vector3(0.0, 0.0, forward)
	var start: Vector3 = at(distance, -forward * RUN)
	await _k.stage(1, type_index, start, heading)
	var mark: int = _k.firing.size()
	_frames.clear()
	q.kit.on_tick = func() -> void:
		_frames[Engine.get_physics_frames()] = {"at": unit.global_position, "speed": unit.get_real_velocity().length(), "velocity": unit.get_real_velocity()}
	var turning: int = 0
	var dodged_at: int = -1
	for _tick: int in 600:
		if dodge and dodged_at < 0:
			for row: Dictionary in _rows(mark, unit):
				if bool(row["steady"]):
					dodged_at = int(row["frame"])
					turning = DODGE_TICKS
					break
		q.harness.drive(1, 1, 1 if turning > 0 else 0)
		turning = maxi(turning - 1, 0)
		await q.kit.tick()
		if (unit.global_position - start).dot(heading) >= 2.0 * RUN or (dodge and dodged_at >= 0 and turning == 0):
			break
	q.harness.release_all()
	q.kit.on_tick = Callable()
	await q.kit.advance(CADENCE_TICKS)
	var rows: Array[Dictionary] = _rows(mark, unit)
	for row: Dictionary in rows:
		row["dodged"] = dodged_at >= 0 and int(row["frame"]) == dodged_at
	return rows


## One pass round a circle the Unit's own turning makes, east of the fixture: Player 2's Unit on the
## west of the circle facing north with the right key held, for CIRCLE_SECONDS. Returns the rows of
## _rows().
func _circle(type_index: int) -> Array[Dictionary]:
	var q: Quick = _k.w.s.q
	var unit: Unit = q.units.units[1]
	var radius: float = q.units.stats(type_index).max_speed / q.units.stats(type_index).turn_rate
	await _k.stage(1, type_index, at(CIRCLE_AT - radius, 0.0), Vector3.FORWARD)
	var mark: int = _k.firing.size()
	_frames.clear()
	q.kit.on_tick = func() -> void:
		_frames[Engine.get_physics_frames()] = {"at": unit.global_position, "speed": unit.get_real_velocity().length(), "velocity": unit.get_real_velocity()}
	for _tick: int in CIRCLE_SECONDS * Engine.physics_ticks_per_second:
		q.harness.drive(1, 1, 1)
		await q.kit.tick()
	q.harness.release_all()
	q.kit.on_tick = Callable()
	return _rows(mark, unit)


## The rows of the Shots the fixture fired since `mark`: the frame, the Unit's real speed then, whether
## it was at top speed, the distance to it, whether the Shot hit it and the barrel's error.
func _rows(mark: int, unit: Unit) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in _k.firing.slice(mark):
		var frame: Dictionary = _frames.get(int(record["frame"]), {})
		var speed: float = float(frame.get("speed", -1.0))
		var place: Vector3 = frame.get("at", Vector3.INF)
		rows.append({"frame": record["frame"], "speed": snappedf(speed, 0.1), "steady": speed >= TOP_SPEED * unit.stats.max_speed,
			"distance": snappedf(place.distance_to(Kit13.ARENA_CENTRE), 0.1) if place != Vector3.INF else -1.0,
			"hit": _k.hit(record, 1), "error": snappedf(float(record["error"]), 0.01), "offset": _along(record)})
	return rows


## How far, metres, a Shot ended ahead of the Unit's centre along its track at the frame it ended in
## (the Unit has moved first in that frame; negative: behind it), or 0.0 when either is unknown.
func _along(record: Dictionary) -> float:
	var frame: Dictionary = _frames.get(int(record["end_frame"]), {})
	var place: Vector3 = frame.get("at", Vector3.INF)
	var velocity: Vector3 = frame.get("velocity", Vector3.ZERO)
	var end: Vector3 = record["end"]
	if place == Vector3.INF or end == Vector3.INF or velocity.length() < 0.001:
		return 0.0
	return snappedf((end - place).dot(velocity.normalized()), 0.01)


## Where a Shot of the record, flying along its direction from its muzzle, first meets the Unit's
## box: the distance in metres (the ray against the box in the Unit's own frame).
func _entry(record: Dictionary, unit: Unit) -> float:
	var shape: CollisionShape3D = unit.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = shape.shape as BoxShape3D
	var to_local: Transform3D = shape.global_transform.affine_inverse()
	var origin: Vector3 = to_local * (record["muzzle"] as Vector3)
	var heading: Vector3 = to_local.basis * (record["direction"] as Vector3)
	var half: Vector3 = box.size / 2.0
	var near: float = -INF
	var far: float = INF
	for axis: int in 3:
		if absf(heading[axis]) < 0.000001:
			continue
		var t1: float = (-half[axis] - origin[axis]) / heading[axis]
		var t2: float = (half[axis] - origin[axis]) / heading[axis]
		near = maxf(near, minf(t1, t2))
		far = minf(far, maxf(t1, t2))
	return near if near <= far else INF


## Waits until the Player's Unit has lost hit points, at most five cadences.
func _wait_first_hit(player: int) -> void:
	var unit: Unit = _k.w.s.q.units.units[player]
	var full: float = unit.hit_points
	for _tick: int in 5 * CADENCE_TICKS:
		await _k.w.s.q.kit.tick()
		if unit.hit_points < full:
			return
