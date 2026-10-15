extends RefCounted
## Weapon.rearm(shots) and the type with no count, of the Story 022 scenario ammo (AC-1's "0 means unlimited", AC-7, and the
## call story 024's ammunition buildings will make; in this story only the scenario calls it, as a tool may). rearm() adds Shots
## up to the capacity through a carry that keeps the fraction: a zone giving 25 Shots a second calls it with 0.4167 every tick,
## a whole Shot comes every 2.4 calls and an empty Motorbike is full after exactly 240; a call that adds a Shot reports once; a
## full load, leaving play and a bigger amount than the room clear or cap the carry; a Unit out of play, a type with no count and
## an amount not above zero (or NaN) are refused. A type whose ammo_capacity is 0 fires without limit and says nothing. Tooling
## only. Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-1, AC-7 and the Implementation Notes.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## The zone's rate in Shots a second (the story's example) and the calls to fill an empty Motorbike.
const RATE: float = 25.0
const FILL_CALLS: int = 240
## Shots a Buggy fires before its rearms, and the amounts the carry tests give.
const SPENT: int = 30
const PART: float = 0.6
const BIG: float = 1000.0
const SMALL: float = 0.5
## How many equal parts make the Shot of the float test: ten tenths sum to 0.9999999999999999 in a float.
const TENTHS: int = 10
## Ticks a type with no count is fired at, more than the Buggy's whole load takes (50 Shots 24 ticks apart).
const UNLIMITED_TICKS: int = 1500

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	await _fills_through_the_carry()
	await _caps_and_clears()
	await _refuses()
	await _no_count()


## An empty Motorbike rearmed with 25 Shots a second, 0.4167 a tick: after n calls it holds the whole Shots of n x 25 / 60 (integer
## arithmetic), the 240th call fills it, and a report goes out exactly when a call added a Shot.
func _fills_through_the_carry() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.MOTORBIKE)
	await _k.empty_gun(0)
	var gun: Weapon = _k.weapon(0)
	var per_call: float = RATE / float(Engine.physics_ticks_per_second)
	var mark: int = _k.changes[0].size()
	var added: int = 0
	var wrong: PackedStringArray = []
	var first_fill: int = -1
	for n: int in range(1, FILL_CALLS + 6):
		var before: int = _k.changes[0].size()
		var got: int = gun.rearm(per_call)
		added += got
		var expected: int = mini(floori(float(n) * RATE / float(Engine.physics_ticks_per_second)), gun.capacity)
		if gun.shots_left != expected:
			wrong.append("call %d: %d Shots, expected %d" % [n, gun.shots_left, expected])
		if (_k.changes[0].size() - before) != (1 if got > 0 else 0):
			wrong.append("call %d: added %d, reports %d" % [n, got, _k.changes[0].size() - before])
		if gun.shots_left == gun.capacity and first_fill < 0:
			first_fill = n
		await _q.kit.tick()
	_q.kit.need(problems, wrong.is_empty(), "%d calls were wrong: %s" % [wrong.size(), wrong.slice(0, 3)])
	_q.kit.need(problems, first_fill == FILL_CALLS and added == gun.capacity, "the load was full at call %d (expected %d), %d Shots added in all" % [first_fill, FILL_CALLS, added])
	_q.kit.need(problems, _k.changes[0].size() - mark == gun.capacity and _k.line(0) == "Ammo 100 / 100", "%d reports for %d Shots, the line reads '%s'" % [_k.changes[0].size() - mark, gun.capacity, _k.line(0)])
	measured.append("rearm_fill_calls=%d" % first_fill)
	_q.kit.verdict("rearm_fills_through_the_carry", problems, "an empty Motorbike rearmed with %.4f a call (25 Shots a second) held n x 25 / 60 whole Shots after every call n, was full at call %d, took %d Shots in %d reports (one for each call that added a Shot), and its line read 'Ammo 100 / 100'" % [per_call, first_fill, added, _k.changes[0].size() - mark])


## A part of a Shot waits in the carry, ten tenths make a Shot (a float sum that lands just under 1), a bigger amount than the room is
## capped, a full load clears the carry, a Shot spent after a full load does not meet an old fraction, and leaving play clears it too.
func _caps_and_clears() -> void:
	var problems: PackedStringArray = []
	await _k.arena_put(0, Quick.BUGGY)
	var gun: Weapon = _k.weapon(0)
	await _k.fire_n(0, SPENT)
	var full: int = gun.capacity
	var tenths: PackedInt32Array = []
	for _tenth: int in TENTHS:
		tenths.append(gun.rearm(1.0 / float(TENTHS)))
	_q.kit.need(problems, tenths.count(1) == 1 and tenths[TENTHS - 1] == 1 and gun.shots_left == full - SPENT + 1, "%d tenths of a Shot gave %s and %d left" % [TENTHS, tenths, gun.shots_left])
	_q.kit.need(problems, gun.rearm(PART) == 0 and gun.shots_left == full - SPENT + 1, "a part of a Shot added Shots: %d left" % gun.shots_left)
	var mark: int = _k.changes[0].size()
	_q.kit.need(problems, gun.rearm(BIG) == SPENT - 1 and gun.shots_left == full and _k.changes[0].size() == mark + 1, "a bigger amount than the room did not fill the load once: %d left, %d reports" % [gun.shots_left, _k.changes[0].size() - mark])
	_q.kit.need(problems, gun.rearm(BIG) == 0 and _k.changes[0].size() == mark + 1, "a full load took Shots or reported")
	await _k.fire_n(0, 1)
	_q.kit.need(problems, gun.rearm(SMALL) == 0 and gun.shots_left == full - 1, "an old fraction was kept through the full load: %d left" % gun.shots_left)
	_q.kit.need(problems, gun.rearm(PART) == 1 and gun.shots_left == full, "half a Shot and 0.6 did not make one: %d left" % gun.shots_left)
	await _k.fire_n(0, 1)
	_q.kit.need(problems, gun.rearm(PART) == 0, "a part of a Shot added a Shot")
	await _k.arena_put(0, Quick.BUGGY)
	await _k.fire_n(0, 1)
	_q.kit.need(problems, gun.rearm(SMALL) == 0 and gun.shots_left == full - 1, "an old fraction was kept through a new Unit: %d left" % gun.shots_left)
	_q.kit.verdict("rearm_caps_and_clears_the_carry", problems, "0.6 of a Shot added none and waited; a call with 1000 filled the 30 missing Shots in one report, a full load took none and reported nothing; after a Shot spent, 0.5 added none (the fraction had gone with the full load) and 0.6 more made one; a new Unit started with no fraction")


## Refused: a Unit out of play, an amount not above zero (zero, negative, NaN), and a NaN does not poison what follows.
func _refuses() -> void:
	var problems: PackedStringArray = []
	var gun: Weapon = _k.weapon(0)
	var left: int = gun.shots_left
	var mark: int = _k.changes[0].size()
	for amount: float in [0.0, -2.0, NAN]:
		_q.kit.need(problems, gun.rearm(amount) == 0 and gun.shots_left == left and _k.changes[0].size() == mark, "rearm(%s) added Shots or reported" % amount)
	_q.kit.need(problems, gun.rearm(1.0) == 1 and gun.shots_left == left + 1, "a rearm after the NaN did not add its Shot: %d left" % gun.shots_left)
	await _k.fire_n(0, 1)
	var room_left: int = gun.shots_left
	var room_mark: int = _k.changes[0].size()
	_q.kit.need(problems, room_left < gun.capacity, "the gun has no room for the same-tick case: %d of %d" % [room_left, gun.capacity])
	_k.unit(0).leave_play()
	var same_tick: int = gun.rearm(BIG)
	_q.kit.need(problems, same_tick == 0 and gun.shots_left == room_left and _k.changes[0].size() == room_mark, "a Unit that left play this very tick was rearmed: %d added, %d left" % [same_tick, gun.shots_left])
	await _q.kit.advance(Kit14.OUT_TICKS)
	var out_mark: int = _k.changes[0].size()
	_q.kit.need(problems, gun.rearm(BIG) == 0 and gun.shots_left == 0 and _k.changes[0].size() == out_mark, "a Unit out of play was rearmed: %d left" % gun.shots_left)
	_q.kit.verdict("rearm_refuses", problems, "rearm() added nothing and reported nothing for 0, -2 and NaN (and a call after the NaN still added its Shot), for a Unit that left play in this very tick, before its Weapon had ticked, and for a Unit out of play (0 of 0, a hidden line)")


## A type whose ammo_capacity is 0 (the data without the line): its Weapon counts nothing, reports nothing, shows no line and fires
## without limit, as before the story; rearm() refuses it.
func _no_count() -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(Quick.BUGGY).duplicate() as UnitStats
	stats.ammo_capacity = 0
	await _k.k.walls().park(1)
	await _k.mines().put_stats(0, stats, Kit14.ARENA + Kit22.ARENA_SPOT, Vector3.RIGHT)
	var gun: Weapon = _k.weapon(0)
	var changes_mark: int = _k.changes[0].size()
	var empties_mark: int = _k.empties[0].size()
	var fired: Array[Dictionary] = await _k.hold(0, UNLIMITED_TICKS)
	_q.kit.need(problems, fired.size() > _q.units.stats(Quick.BUGGY).ammo_capacity, "the type with no count fired %d Shots in %d ticks, not more than a Buggy's load" % [fired.size(), UNLIMITED_TICKS])
	_q.kit.need(problems, gun.capacity == 0 and gun.shots_left == 0 and _k.line(0) == "hidden", "the type with no count holds %d of %d, the line reads '%s'" % [gun.shots_left, gun.capacity, _k.line(0)])
	_q.kit.need(problems, _k.changes[0].size() == changes_mark and _k.empties[0].size() == empties_mark, "the type with no count reported %d times and said it was out of ammo %d times" % [_k.changes[0].size() - changes_mark, _k.empties[0].size() - empties_mark])
	_q.kit.need(problems, gun.rearm(BIG) == 0, "rearm() gave Shots to a type with no count")
	var gaps: int = 0
	for index: int in range(1, fired.size()):
		gaps += 0 if int(fired[index]["frame"]) - int(fired[index - 1]["frame"]) == _k.cadence_ticks(Quick.BUGGY) else 1
	_q.kit.need(problems, gaps == 0, "%d gaps differ from the Buggy's cadence" % gaps)
	measured.append("unlimited_shots=%d" % fired.size())
	_q.kit.verdict("no_count_fires_as_before", problems, "a Buggy whose data has no ammo_capacity (0) fired %d Shots at its own cadence in %d ticks, more than the 50 of a load, held 0 of 0 with a hidden line, reported nothing, never said it was out of ammo and was refused by rearm()" % [fired.size(), UNLIMITED_TICKS])
