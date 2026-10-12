extends RefCounted
## What destroys a Unit and what then plays (Story 016 AC-1, AC-4, AC-5's size, AC-6): every way of destroying a
## Unit the Round counts is made on the shipped data and Map 01, for each type it can happen to, with real keys
## where a Player acts, and each one must play exactly one Explosion, in the very physics tick of the destruction,
## for the Player whose Unit it was, centred on that Unit's model raised by its type's collision_center (and
## inside the model's drawn box), sized from the type's box. shots_explode and turret_shots_explode (the four
## types), mines_explode (the three ground types, and a Mine that takes two Units plays two, the Mine's own flash
## showing beside the explosion: AC-6), self_destruct_explodes (the four types, outside the own Base),
## fuel_crash_explodes (the Gyrocopter running dry), direct_destroy_explodes (a tool's Unit.destroy(), story
## 021's stand-in: the four types) and size_follows_the_type. Run by explosions.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-016-unit-explosions.md AC-1, AC-4, AC-5 and AC-6. Every number comes
## from the game's data; the scenario types only its test inputs.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The explosion's data, by path.
const SETTINGS_PATH: String = "res://src/gameplay/effects/data/explosion_settings.tres"
## The types in the order of the Round's list, and the ground ones.
const TYPES: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK, Quick.GYROCOPTER]
const GROUND: Array[int] = [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]
## Ticks a flow lets pass after its destruction, to see that no second Explosion comes.
const QUIET_TICKS: int = 10

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick
## The fireball's radius on the tick of each type's destruction, by type index (from the shot flows).
var _fireballs: Dictionary = {}
var _flashes: Dictionary = {}


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _shots()
	await _turrets()
	await _mines()
	await _self_destructs()
	await _fuel_crash()
	await _direct()
	_size_follows_the_type()


## One destruction against the criteria (the class doc): the problems it finds are added.
func _judge(problems: PackedStringArray, label: String, d: Dictionary, victim: int, type_index: int) -> void:
	_q.kit.need(problems, not d.is_empty(), "%s: no destruction came" % label)
	if d.is_empty():
		return
	var b: Dictionary = d["blast"]
	_q.kit.need(problems, int(d["player"]) == victim and d["type"] == _q.units.stats(type_index).type_id, "%s: Player %d's %s was destroyed" % [label, int(d["player"]) + 1, d["type"]])
	_q.kit.need(problems, not b.is_empty(), "%s: no Explosion came on the tick of the destruction" % label)
	if b.is_empty():
		return
	_q.kit.need(problems, int(b["tick"]) == int(d["tick"]) and int(b["frame"]) == int(d["frame"]), "%s: the Explosion entered in tick %d (frame %d), the destruction came in tick %d (frame %d)" % [label, int(b["tick"]), int(b["frame"]), int(d["tick"]), int(d["frame"])])
	_q.kit.need(problems, int(b["player"]) == victim, "%s: the Explosion was made for Player %d" % [label, int(b["player"]) + 1])
	var centre: Vector3 = d["centre"]
	var expected: Vector3 = d["expected"]
	_q.kit.need(problems, centre.distance_to(expected) <= Kit16.TOLERANCE, "%s: the Explosion's centre %s is %.4f m from the model raised by the box's middle %s" % [label, centre, centre.distance_to(expected), expected])
	var box: AABB = d["box"]
	_q.kit.need(problems, box.grow(Kit16.TOLERANCE).has_point(centre), "%s: the centre %s is outside the model's drawn box %s" % [label, centre, box])


## The record of the destruction `index` after a mark, and the number of Explosions since the mark once the
## flow has been quiet for QUIET_TICKS.
func _quiet_count(mark: Vector2i) -> int:
	await _q.kit.advance(QUIET_TICKS)
	return _k.blasts.size() - mark.x


func _one(problems: PackedStringArray, label: String, count: int, expected: int) -> void:
	_q.kit.need(problems, count == expected, "%s: %d Explosions came, not %d" % [label, count, expected])


## An enemy Shot kills a Unit of each type (the shooter is Player 1's Motorbike, the real fire key).
func _shots() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for type_index: int in TYPES:
		var mark: Vector2i = _k.mark()
		var d: Dictionary = await _k.shot_kill(type_index)
		_judge(problems, "Shot at the %s" % _q.units.stats(type_index).type_id, d, 1, type_index)
		_one(problems, "Shot at the %s" % _q.units.stats(type_index).type_id, await _quiet_count(mark), 1)
		if not d.is_empty():
			_fireballs[type_index] = float(d["fireball"])
			_flashes[type_index] = float(d["flash"])
			seen.append("%s@%d" % [d["type"], int(d["frame"])])
	_q.kit.verdict("shots_explode", problems, "Player 1's one real Shot killed Player 2's Unit (one hit point left) of each type, %s: one Explosion each, in the tick of the destruction, for Player 2, centred on the model raised by the box's middle and inside the model's drawn box" % ", ".join(seen))


## A Turret's Shot kills a Unit of each type 15 m ahead of Base A's right Turret.
func _turrets() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for type_index: int in TYPES:
		var mark: Vector2i = _k.mark()
		var shots: int = _k.t.firing.size()
		var d: Dictionary = await _k.turret_kill(type_index)
		_judge(problems, "Turret's Shot at the %s" % _q.units.stats(type_index).type_id, d, 1, type_index)
		_one(problems, "Turret's Shot at the %s" % _q.units.stats(type_index).type_id, await _quiet_count(mark), 1)
		_q.kit.need(problems, _k.t.firing.size() > shots, "no Turret fired at the %s" % _q.units.stats(type_index).type_id)
		if not d.is_empty():
			seen.append("%s@%d" % [d["type"], int(d["frame"])])
	_q.kit.verdict("turret_shots_explode", problems, "Base A's right Turret killed Player 2's Unit (one hit point left) of each type, %s: one Explosion each, in the tick of the destruction" % ", ".join(seen))


## A live Mine takes a Unit of each ground type; one Mine takes two Units and plays two Explosions; the Mine's own
## flash shows beside the explosion (AC-6).
func _mines() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for type_index: int in GROUND:
		var mark: Vector2i = _k.mark()
		var d: Dictionary = await _k.mine_kill(type_index)
		var label: String = "Mine under the %s" % _q.units.stats(type_index).type_id
		_judge(problems, label, d, 1, type_index)
		_one(problems, label, await _quiet_count(mark), 1)
		_q.kit.need(problems, _k.last_mine["state"] == Mine.State.SPENT and bool(_k.last_mine["flash"]) and int(_k.last_mine["explosions"]) >= 1, "%s: the Mine's flash showed %s, its state %s, with %s Explosions playing" % [label, _k.last_mine["flash"], _k.last_mine["state"], _k.last_mine["explosions"]])
		await _k.clear_mines()
		if not d.is_empty():
			seen.append("%s@%d" % [d["type"], int(d["frame"])])
	_q.kit.verdict("mines_explode", problems, "a live Mine under Player 2's %s took it: one Explosion each, in the tick of the destruction, and in the following tick the Mine was spent with its own 0.3 s flash showing while the explosion played (AC-6)" % ", ".join(seen))
	problems = []
	var pair_mark: Vector2i = _k.mark()
	var first: Dictionary = await _k.mine_kill(Quick.MOTORBIKE, true)
	var count: int = await _quiet_count(pair_mark)
	_one(problems, "one Mine under two Motorbikes", count, 2)
	var second: Dictionary = _k.destroyed[pair_mark.y + 1] if _k.destroyed.size() > pair_mark.y + 1 else {}
	_judge(problems, "the first Motorbike of the Mine", first, 0, Quick.MOTORBIKE)
	_judge(problems, "the second Motorbike of the Mine", second, 1, Quick.MOTORBIKE)
	if not first.is_empty() and not second.is_empty():
		_q.kit.need(problems, int(first["frame"]) == int(second["frame"]) and (first["centre"] as Vector3).distance_to(second["centre"]) > 1.0, "the two Explosions came in frames %d and %d, %.2f m apart" % [int(first["frame"]), int(second["frame"]), (first["centre"] as Vector3).distance_to(second["centre"])])
	await _k.clear_mines()
	_q.kit.verdict("mine_takes_two_plays_two", problems, "one live Mine took Player 1's and Player 2's Motorbikes standing either side of it in one tick (%d frames apart): two destructions, %d Explosions, each at its own Unit" % [int(second["frame"]) - int(first["frame"]) if not first.is_empty() and not second.is_empty() else -1, count])


## Player 2's Self-destruct key outside its Base, for each type.
func _self_destructs() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for type_index: int in TYPES:
		var mark: Vector2i = _k.mark()
		var d: Dictionary = await _k.self_destruct(type_index)
		_judge(problems, "Self-destruct of the %s" % _q.units.stats(type_index).type_id, d, 1, type_index)
		_one(problems, "Self-destruct of the %s" % _q.units.stats(type_index).type_id, await _quiet_count(mark), 1)
		if not d.is_empty():
			seen.append("%s@%d" % [d["type"], int(d["frame"])])
	_q.kit.verdict("self_destruct_explodes", problems, "Player 2's real Self-destruct key, outside its Base, destroyed its %s: one Explosion each, in the tick of the destruction" % ", ".join(seen))


## A Gyrocopter that runs dry crashes, and that is a destruction like any other.
func _fuel_crash() -> void:
	var problems: PackedStringArray = []
	var mark: Vector2i = _k.mark()
	var d: Dictionary = await _k.fuel_crash()
	_judge(problems, "the Gyrocopter's Fuel crash", d, 1, Quick.GYROCOPTER)
	_one(problems, "the Gyrocopter's Fuel crash", await _quiet_count(mark), 1)
	_q.kit.verdict("fuel_crash_explodes", problems, "a Gyrocopter spawned with %.1f%% of its tank ran dry over the middle of the Map and crashed (frame %d): one Explosion, in the tick of the crash, at the model it was drawn with" % [Kit16.SMALL_TANK * 100.0, int(d["frame"]) if not d.is_empty() else -1])


## A tool's direct Unit.destroy() of a Unit in play (story 021's crash into a Tall piece ends there), for each type.
func _direct() -> void:
	var problems: PackedStringArray = []
	var seen: PackedStringArray = []
	for type_index: int in TYPES:
		var mark: Vector2i = _k.mark()
		var d: Dictionary = await _k.direct_destroy(type_index)
		_judge(problems, "destroy() of the %s" % _q.units.stats(type_index).type_id, d, 1, type_index)
		_one(problems, "destroy() of the %s" % _q.units.stats(type_index).type_id, await _quiet_count(mark), 1)
		if not d.is_empty():
			seen.append("%s@%d" % [d["type"], int(d["frame"])])
	_q.kit.verdict("direct_destroy_explodes", problems, "a tool's Unit.destroy() of Player 2's %s in play: one Explosion each, in the tick of the destruction, with no cause named anywhere" % ", ".join(seen))


## Every type explodes the same way but for its size: the fireball and the flash on the tick of the destruction
## are the data's factors of the larger horizontal side of the type's box, and a Truck's is larger than a
## Buggy's, a Buggy's than a Motorbike's and a Motorbike's than a Gyrocopter's.
func _size_follows_the_type() -> void:
	var problems: PackedStringArray = []
	var settings: ExplosionSettings = load(SETTINGS_PATH) as ExplosionSettings
	var rows: PackedStringArray = []
	for type_index: int in TYPES:
		var stats: UnitStats = _q.units.stats(type_index)
		var side: float = maxf(stats.collision_size.x, stats.collision_size.z)
		var fireball: float = settings.fireball_radius_factor * settings.fireball_start_scale * side
		var flash: float = settings.flash_radius_factor * side
		_q.kit.need(problems, absf(float(_fireballs.get(type_index, -1.0)) - fireball) <= Kit16.TOLERANCE, "the %s's fireball began at %.4f m, the data says %.4f" % [stats.type_id, float(_fireballs.get(type_index, -1.0)), fireball])
		_q.kit.need(problems, absf(float(_flashes.get(type_index, -1.0)) - flash) <= Kit16.TOLERANCE, "the %s's flash was %.4f m, the data says %.4f" % [stats.type_id, float(_flashes.get(type_index, -1.0)), flash])
		rows.append("%s=%.3f" % [stats.type_id, float(_fireballs.get(type_index, -1.0))])
	var truck: float = float(_fireballs.get(Quick.TRUCK, 0.0))
	var buggy: float = float(_fireballs.get(Quick.BUGGY, 0.0))
	var motorbike: float = float(_fireballs.get(Quick.MOTORBIKE, 0.0))
	var gyrocopter: float = float(_fireballs.get(Quick.GYROCOPTER, 0.0))
	_q.kit.need(problems, truck > buggy and buggy > motorbike and motorbike > gyrocopter, "the fireballs are not ordered by size: %s" % [rows])
	measured.append("fireball_start_m=%s" % "/".join(rows))
	_q.kit.verdict("size_follows_the_type", problems, "the fireball's first radius and the flash's radius are the data's factors of each type's larger box side (%s fireball metres), a Truck's larger than a Buggy's, a Buggy's than a Motorbike's, a Motorbike's than a Gyrocopter's, no type named in code" % " ".join(rows))
