extends RefCounted
## The still_fights check of the turret_looks scenario (Story 015 AC-2), on open ground: a fixture
## Turret of the shipped scene and data on the arena's flat floor (turrets_kit.gd make_arena()),
## where nothing hides a target. In each of its three looks, whole, first and second, the head turns
## toward a Motorbike put 90 degrees off its rest heading at the data's rate (never more in a tick, the
## full rate in all but one of the ticks it turns, a quarter turn ending on it) and its first Shot
## leaves about a swing later; then, against a Truck that stands still on its rest heading, it fires
## one Shot every cadence of the data and every Shot hits; at the fall the whole Turret, head
## included, gives way to the rubble, and a Turret that fell fires nothing more. Only the look
## changes: the same numbers in every look. Run by turret_looks.gd. Implements:
## production/epics/wasteland-fire/story-015-turret-damage-looks.md AC-2. Tooling only. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd).
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

## A swing of 90 degrees takes 1.0 s at the data's rate: the ticks it may take, two more or less.
const SWING_TICKS: int = 60
const SWING_SLACK: int = 2
## Metres east of the fixture a Motorbike is put for the quarter turn, and south (negative: in front
## of its rest heading) a Truck for the cadence.
const CROSS: float = 20.0
const AHEAD: float = 20.0
## Cadences watched for the Shots, and ticks a fallen Turret is watched for.
const CADENCES: int = 5
const WATCH: int = 120

var _k: Kit13
## What the check found, for the RESULT line.
var measured: PackedStringArray = []


func _init(kit: Kit13) -> void:
	_k = kit


## The world place of a point of the arena, dx east and dz south of the fixture.
func _at(dx: float, dz: float) -> Vector3:
	return Kit13.ARENA_CENTRE + Vector3(dx, 0.0, dz)


## The check, on a fixture of Player 1's armed at Player 2's Unit.
func run() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var who: Turret = _k.make_arena(0)
	var notes: PackedStringArray = []
	var cadence: int = q.harness.ticks_in(who.stats.fire_interval_seconds)
	for look: int in Looks.DAMAGED_BELOW.size() + 1:
		who.restore()
		who.apply_damage(_taken_for(who, look))
		q.kit.need(problems, Looks.look_shown(who) == look and who.is_standing, "the fixture shows look %d, the test wanted %d" % [Looks.look_shown(who), look])
		var turn: String = await _turn(who, look, problems)
		var fire: String = await _fire(who, look, cadence, problems)
		notes.append("look %d: %s; %s" % [look, turn, fire])
	var mark: int = _k.firing.size()
	who.destroy()
	await _k.stage(1, Quick.TRUCK, _at(0.0, -AHEAD), Vector3.BACK)
	var yaw: float = who.head.rotation.y
	await q.kit.advance(WATCH)
	q.kit.need(problems, Looks.look_shown(who) == -1 and not Looks.head_visible(who) and not who.is_standing, "at the fall the fixture shows look %d with its head shown %s" % [Looks.look_shown(who), Looks.head_visible(who)])
	q.kit.need(problems, _k.firing.size() == mark and who.head.rotation.y == yaw and who.state == Turret.State.DESTROYED, "a fallen Turret fired %d Shots and its head turned %.4f rad" % [_k.firing.size() - mark, who.head.rotation.y - yaw])
	_k.free_arena()
	q.kit.verdict("still_fights", problems, "in each look the head turned at the data's rate and the Shots came one cadence apart and all hit (%s); at the fall the head went with the rest and a fallen Turret fired nothing in %d ticks" % [" | ".join(notes), WATCH])


## The hit points to take off a whole Turret to leave it in a look: none for the whole one, else just
## below the fraction of that look.
func _taken_for(who: Turret, look: int) -> float:
	if look == 0:
		return 0.0
	return who.stats.max_hit_points - Looks.DAMAGED_BELOW[look - 1] * who.stats.max_hit_points + Looks.JUST_BELOW


## The quarter turn in one look: the head's yaw every tick for two swings after a Motorbike is put
## 90 degrees off the rest heading. Returns the note.
func _turn(who: Turret, look: int, problems: PackedStringArray) -> String:
	var q: Quick = _k.w.s.q
	var per_tick: float = who.stats.turn_rate / float(Engine.physics_ticks_per_second)
	var mark: int = _k.firing.size()
	await _k.stage(1, Quick.MOTORBIKE, _at(CROSS, 0.0), Vector3.BACK)
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
	q.kit.need(problems, biggest <= per_tick + 0.000001 and full >= turned - 1 and turned > 0, "look %d: the head turned at most %.6f rad a tick (the rate allows %.6f), at the full rate in %d of the %d ticks it turned" % [look, biggest, per_tick, full, turned])
	q.kit.need(problems, is_equal_approx(absf(yaws.back()), PI / 2.0), "look %d: the head ended %.4f rad round, not a quarter turn" % [look, yaws.back()])
	var first: Dictionary = _k.firing[mark] if _k.firing.size() > mark else {}
	var swing: int = int(first["frame"]) - _k.staged_frame if not first.is_empty() else -1
	q.kit.need(problems, not first.is_empty() and absi(swing - SWING_TICKS) <= SWING_SLACK and float(first["error"]) <= who.stats.aim_tolerance, "look %d: the first Shot left %d ticks after the Motorbike appeared, a swing is %d" % [look, swing, SWING_TICKS])
	return "a quarter turn at %.4f rad/s, first Shot after %d ticks" % [who.stats.turn_rate, swing]


## The cadence in one look: a Truck standing on the rest heading takes CADENCES cadences of Shots, all
## one cadence apart, every one a hit. Returns the note.
func _fire(who: Turret, look: int, cadence: int, problems: PackedStringArray) -> String:
	var q: Quick = _k.w.s.q
	var mark: int = _k.firing.size()
	who.head.rotation = Vector3.ZERO
	await _k.stage(1, Quick.TRUCK, _at(0.0, -AHEAD), Vector3.BACK)
	await q.kit.advance(CADENCES * cadence + cadence / 2)
	var rows: Array[Dictionary] = []
	for index: int in range(mark, _k.firing.size()):
		rows.append(_k.firing[index])
	var gaps: Array[int] = []
	for index: int in range(1, rows.size()):
		gaps.append(int(rows[index]["frame"]) - int(rows[index - 1]["frame"]))
	var ended: int = 0
	var landed: int = 0
	for row: Dictionary in rows:
		ended += 1 if int(row["end_frame"]) >= 0 else 0
		landed += 1 if int(row["end_frame"]) >= 0 and _k.hit(row, 1) else 0
	q.kit.need(problems, rows.size() >= CADENCES and gaps.all(func(gap: int) -> bool: return gap == cadence) and ended >= CADENCES - 1 and landed == ended, "look %d: %d Shots %s ticks apart (the data: %d), %d of the %d that had landed hit the Truck" % [look, rows.size(), gaps, cadence, landed, ended])
	return "%d Shots %d ticks apart, all %d that had landed hit" % [rows.size(), cadence, ended]
