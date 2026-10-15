extends RefCounted
## The load of the Story 022 scenario ammo: AC-1. Each Unit type, put in the arena as a new Unit, holds its load from the
## data (Motorbike 100, Buggy 50, Truck 25, Gyrocopter 40 Shots, shown as "Ammo n / n" on the tick) and, with the fire key
## held from a full load by a real key event, fires the whole load at its own cadence (12, 24, 48 and 30 ticks apart at 60
## ticks a second, the last Shot 19.2 to 19.8 s after the first) and then nothing, for as long as the key is held. A Shot
## spends one Shot of the load and nothing else: the first and the last Shot of a load leave the same muzzle (the same place
## relative to the Unit). Tooling only. Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-1.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")

## The story's numbers, by type index (Motorbike, Buggy, Truck, Gyrocopter): the test inputs of this module.
const LOADS: Array[int] = [100, 50, 25, 40]
const CADENCES: Array[int] = [12, 24, 48, 30]
const LAST_AFTER_FIRST: Array[int] = [1188, 1176, 1152, 1170]
## The window the story gives the last Shot, seconds after the first (floats, not a Vector2: that holds 32-bit floats).
const WINDOW_MIN_SECONDS: float = 19.2
const WINDOW_MAX_SECONDS: float = 19.8
## Ticks the key stays held after the load is spent: nothing may come.
const QUIET_TICKS: int = 300
## How far the first and the last Shot's first sight may differ relative to the Unit, metres.
const MUZZLE_TOLERANCE: float = 0.0001

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	for type_index: int in LOADS.size():
		await _whole_load(type_index)


## One type: a new Unit with its full load, the key held through the load and 300 ticks beyond it.
func _whole_load(type_index: int) -> void:
	var problems: PackedStringArray = []
	var stats: UnitStats = _q.units.stats(type_index)
	var load_size: int = LOADS[type_index]
	await _k.arena_put(0, type_index)
	var gun: Weapon = _k.weapon(0)
	var unit: Unit = _k.unit(0)
	_q.kit.need(problems, stats.ammo_capacity == load_size and gun.shots_left == load_size and gun.capacity == load_size, "the new %s holds %d of %d Shots (the data say %d)" % [stats.type_id, gun.shots_left, gun.capacity, stats.ammo_capacity])
	_q.kit.need(problems, _k.line(0) == "Ammo %d / %d" % [load_size, load_size], "the Ammo line reads '%s' for a full load" % _k.line(0))
	var origin: Vector3 = unit.global_position
	var fired: Array[Dictionary] = await _k.hold(0, CADENCES[type_index] * load_size + QUIET_TICKS)
	_q.kit.need(problems, fired.size() == load_size, "the %s fired %d Shots from a load of %d" % [stats.type_id, fired.size(), load_size])
	if fired.size() < 2:
		_q.kit.verdict("full_load_%s" % stats.type_id, problems, "the %s fired %d Shots" % [stats.type_id, fired.size()])
		return
	var gaps: PackedInt32Array = []
	for index: int in range(1, fired.size()):
		gaps.append(int(fired[index]["frame"]) - int(fired[index - 1]["frame"]))
	var uneven: int = 0
	for gap: int in gaps:
		uneven += 0 if gap == CADENCES[type_index] else 1
	var span: int = int(fired[-1]["frame"]) - int(fired[0]["frame"])
	var seconds: float = float(span) / float(Engine.physics_ticks_per_second)
	_q.kit.need(problems, uneven == 0 and _k.cadence_ticks(type_index) == CADENCES[type_index], "%d of %d gaps differ from %d ticks (the data say %d)" % [uneven, gaps.size(), CADENCES[type_index], _k.cadence_ticks(type_index)])
	_q.kit.need(problems, span == LAST_AFTER_FIRST[type_index] and seconds >= WINDOW_MIN_SECONDS and seconds <= WINDOW_MAX_SECONDS, "the last Shot came %d ticks (%.3f s) after the first, expected %d ticks in %s to %s s" % [span, seconds, LAST_AFTER_FIRST[type_index], WINDOW_MIN_SECONDS, WINDOW_MAX_SECONDS])
	_q.kit.need(problems, gun.shots_left == 0 and gun.capacity == load_size and _k.line(0) == "Ammo 0 / %d" % load_size, "after the load the Weapon holds %d of %d and the line reads '%s'" % [gun.shots_left, gun.capacity, _k.line(0)])
	var tail: int = int(fired[-1]["frame"]) + QUIET_TICKS
	_q.kit.need(problems, Engine.get_physics_frames() >= tail, "the key was held only %d ticks beyond the last Shot" % (Engine.get_physics_frames() - int(fired[-1]["frame"])))
	var first_at: Vector3 = fired[0]["first"]
	var last_at: Vector3 = fired[-1]["first"]
	_q.kit.need(problems, unit.global_position.is_equal_approx(origin) and first_at != Vector3.INF and last_at != Vector3.INF and (first_at - last_at).length() <= MUZZLE_TOLERANCE, "the first Shot was first seen at %s and the last at %s from a Unit that stayed at %s" % [first_at, last_at, origin])
	var ahead: Vector3 = (first_at - origin)
	measured.append("%s_gap=%d" % [stats.type_id, CADENCES[type_index]])
	measured.append("%s_span=%d" % [stats.type_id, span])
	_q.kit.verdict("full_load_%s" % stats.type_id, problems, "a new %s holds %d Shots ('Ammo %d / %d' on the tick); with the key held it fired %d Shots %d ticks apart (all %d gaps), the last %d ticks (%.3f s) after the first, then nothing in the %d ticks the key stayed down, and the Weapon holds 0 of %d ('Ammo 0 / %d'); the first and the last Shot were first seen %.3f m ahead of the Unit, %.6f m apart" % [stats.type_id, load_size, load_size, load_size, fired.size(), CADENCES[type_index], gaps.size(), span, seconds, QUIET_TICKS, load_size, load_size, ahead.length(), (first_at - last_at).length()])
