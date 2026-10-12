extends RefCounted
## What the state does to the Turrets' aim, recorded for the author (Story 017 AC-6), pinning no outcome: a Buggy crosses the front of a fixture Turret
## of the shipped scene on open ground at full speed, whole, badly damaged from the start at half of it, and brought into the state by the Turret's
## own first Shot while it crosses (the same copy of its stats with hit points enough to live through the Shots), 20 m and 30 m out; the Shots the
## Turret fired, how many hit and the speed it was read at are listed. The Turret leads by the real motion (it follows a slowed Unit at once), so a
## slowed Unit is easier to meet; while a Unit slows the lead aims ahead of it, and a slowed Unit spends longer in the Turret's reach. Run by
## badly_damaged.gd. Tooling only. Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-6.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

## The distances east of the fixture a Buggy crosses at, the three ways it crosses, and the metres a crossing starts before and ends after the
## fixture's line.
const DISTANCES: Array[float] = [20.0, 30.0]
const MODES: Array[String] = ["whole", "slowed from the start", "slowed by the first Shot"]
const KEYS: Array[String] = ["whole", "start", "first"]
const RUN: float = 55.0
## Hit points of the Buggy's copy, and the fraction that puts the state on at the first 100 hit points lost.
const COPY_HIT_POINTS: float = 1000.0
const COPY_FRACTION: float = 0.9
const COPY_LOSS: float = 100.0
## Ticks a crossing may take, and the ticks waited after it for the last Shot to end.
const LIMIT_TICKS: int = 600
const TAIL_TICKS: int = 60

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	var rows: PackedStringArray = []
	var problems: PackedStringArray = []
	_k.t.make_arena(0)
	for distance: float in DISTANCES:
		var cells: PackedStringArray = []
		for mode: String in MODES:
			var seen: Dictionary = await _cross(distance, mode)
			_q.kit.need(problems, seen["shots"] > 0 and seen["speed"] > 0.0, "%s at %s m: %d Shots" % [mode, distance, seen["shots"]])
			cells.append("%s %d of %d Shots hit (%.1f m/s at the end)" % [mode, seen["hits"], seen["shots"], seen["speed"]])
			measured.append("turret_%s_%dm=%d/%d" % [KEYS[MODES.find(mode)], int(distance), seen["hits"], seen["shots"]])
		rows.append("%s m out: %s" % [distance, ", ".join(cells)])
	_k.t.free_arena()
	_q.kit.verdict("turret_hits_recorded", problems, "a Buggy crossing a Turret's front at full speed and badly damaged at half of it, recorded and not pinned: %s" % " | ".join(rows))


## One pass: the Buggy copy from RUN metres before the fixture's line to RUN after it at `distance` east of it, the throttle held, in a mode of MODES
## (the last brings it into the state the tick after the fixture's first Shot was fired). The Shots the fixture fired, those that hit, and the real
## speed at the end.
func _cross(distance: float, mode: String) -> Dictionary:
	var stats: UnitStats = _q.small_tank(Quick.BUGGY, 1.0)
	stats.max_hit_points = COPY_HIT_POINTS
	stats.badly_damaged_fraction = COPY_FRACTION
	await _k.t.clear(1)
	var heading: Vector3 = Vector3(0.0, 0.0, 1.0)
	await _q.put(1, stats, Kit13.ARENA_CENTRE + Vector3(distance, 0.0, -RUN), heading)
	var unit: Unit = _k.unit(1)
	if mode == MODES[1]:
		unit.apply_damage(COPY_LOSS)
	var start: Vector3 = unit.global_position
	var mark: int = _k.t.firing.size()
	var speed: float = 0.0
	for _tick: int in LIMIT_TICKS:
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
		if mode == MODES[2] and not unit.is_badly_damaged and _k.t.firing.size() > mark:
			unit.apply_damage(COPY_LOSS)
		speed = unit.get_real_velocity().length()
		if (unit.global_position - start).dot(heading) >= 2.0 * RUN:
			break
	_q.harness.release_all()
	await _q.kit.advance(TAIL_TICKS)
	var hits: int = 0
	var shots: int = _k.t.firing.size() - mark
	for record: Dictionary in _k.t.firing.slice(mark):
		hits += 1 if _k.t.hit(record, 1) else 0
	return {"shots": shots, "hits": hits, "speed": speed}
