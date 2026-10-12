extends RefCounted
## The edge of the badly damaged state (Story 017 AC-1), reached by real Shots of the other Player's Unit,
## every key a real event: each of the four types is brought to the first Shot at or below its edge, and
## not one Shot before. With the starting 0.2 the Buggy left at exactly 20 by sixteen Motorbike Shots is in
## the state and at 25 after fifteen is not, the Motorbike at 5 after seven Motorbike Shots and not at 10
## after six, the Truck at 20 after eight Truck Shots and not at 45 after seven, the Gyrocopter at 10 after
## twelve Motorbike Shots and not at 15 after eleven. The state begins in the physics frame of the hit
## (the hit points' change and the state's come in one frame, the state's right after), and a Turret's Shot
## begins it as well. Run by badly_damaged.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-1.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")

## The cases: attacker type, victim type, the Shots that bring the victim to the edge and the hit points
## it has then, and the hit points one Shot earlier. These are the story's numbers, not the data's.
const CASES: Array[Dictionary] = [
	{"name": "motorbike_by_motorbike", "attacker": Quick.MOTORBIKE, "victim": Quick.MOTORBIKE, "shots": 7, "at": 5.0, "before": 10.0},
	{"name": "buggy_by_motorbike", "attacker": Quick.MOTORBIKE, "victim": Quick.BUGGY, "shots": 16, "at": 20.0, "before": 25.0},
	{"name": "truck_by_truck", "attacker": Quick.TRUCK, "victim": Quick.TRUCK, "shots": 8, "at": 20.0, "before": 45.0},
	{"name": "gyrocopter_by_motorbike", "attacker": Quick.MOTORBIKE, "victim": Quick.GYROCOPTER, "shots": 12, "at": 10.0, "before": 15.0},
]

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	await _edges()
	await _turret()


## edge_by_real_shots: each case, Shot by Shot.
func _edges() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for case: Dictionary in CASES:
		await _k.face_off(case["attacker"], case["victim"])
		var victim: Unit = _k.unit(1)
		var mark: int = _k.changes.size()
		var note: String = "%s: " % case["name"]
		for shot: int in int(case["shots"]) - 1:
			_q.kit.need(problems, await _k.fire(0) > 0.0, "%s: Shot %d did not land" % [case["name"], shot + 1])
		_q.kit.need(problems, victim.hit_points == float(case["before"]), "%s: %s hit points one Shot short of the edge, not %s" % [case["name"], victim.hit_points, case["before"]])
		_q.kit.need(problems, not victim.is_badly_damaged and _k.changes.size() == mark and not _k.smoking(1), "%s: badly damaged (or a change, or smoke) one Shot short of the edge" % case["name"])
		note += "%s hp, not in the state, " % victim.hit_points
		var hit_mark: int = _k.hits.size()
		_q.kit.need(problems, await _k.fire(0) > 0.0, "%s: the Shot at the edge did not land" % case["name"])
		_q.kit.need(problems, victim.hit_points == float(case["at"]), "%s: %s hit points at the edge, not %s" % [case["name"], victim.hit_points, case["at"]])
		var made: Array[Dictionary] = _k.changes_of(1, mark)
		_q.kit.need(problems, made.size() == 1 and made[0]["state"] == true and victim.is_badly_damaged, "%s: %d changes at the edge (%s)" % [case["name"], made.size(), made])
		if made.size() == 1:
			var landed: Dictionary = _k.hits[hit_mark] if _k.hits.size() > hit_mark else {}
			_q.kit.need(problems, not landed.is_empty() and landed["frame"] == made[0]["frame"] and float(landed["hp"]) == float(case["at"]), "%s: the state began in frame %s, the hit in %s" % [case["name"], made[0]["frame"], landed.get("frame", -1)])
			_q.kit.need(problems, made[0]["hp"] == float(case["at"]) and made[0]["badly"], "%s: the handler saw %s hp, badly=%s" % [case["name"], made[0]["hp"], made[0]["badly"]])
		_q.kit.need(problems, _k.edge_of(_q.units.TYPE_IDS.find(victim.type_id)) >= float(case["at"]) and float(case["before"]) > _k.edge_of(_q.units.TYPE_IDS.find(victim.type_id)), "%s: the edge of the data is not between %s and %s" % [case["name"], case["before"], case["at"]])
		note += "%s hp after Shot %d: the state began in the frame of the hit" % [victim.hit_points, case["shots"]]
		notes.append(note)
	_q.kit.verdict("edge_by_real_shots", problems, " | ".join(notes))


## turret_shot_begins_it: a Turret's Shot (12) takes a Buggy from 32 to exactly 20, the edge, and begins the
## state in the frame of its hit.
func _turret() -> void:
	var problems: PackedStringArray = []
	await _k.e.fresh()
	var turret: Turret = _k.t.turret(0, Kit13.RIGHT)
	var forward: Vector3 = _k.t.w.way(0, Vector3.FORWARD)
	await _k.t.stage(1, Quick.BUGGY, _k.t.ahead(turret, 0, _k.e.TURRET_AHEAD), -forward)
	var victim: Unit = _k.unit(1)
	var mark: int = _k.changes.size()
	var hit_mark: int = _k.hits.size()
	victim.apply_damage(victim.hit_points - 32.0)
	_q.kit.need(problems, _k.changes.size() == mark and not victim.is_badly_damaged, "the tool's damage to 32 began the state")
	for _wait: int in _k.e.KILL_WAIT:
		if victim.is_badly_damaged or not victim.is_alive:
			break
		await _q.kit.tick()
	var made: Array[Dictionary] = _k.changes_of(1, mark)
	_q.kit.need(problems, victim.is_alive and victim.hit_points == 20.0 and victim.is_badly_damaged, "a Turret's Shot left the Buggy at %s (alive %s)" % [victim.hit_points, victim.is_alive])
	_q.kit.need(problems, made.size() == 1 and made[0]["state"] == true and made[0]["frame"] == _k.hits[-1]["frame"] and _k.hits.size() > hit_mark, "the Turret's hit and the state were not in one frame: %s" % [made])
	_q.kit.verdict("turret_shot_begins_it", problems, "a Buggy at 32 hit points in front of Base A's right Turret was left at %s by its 12-point Shot, exactly the edge, and the state began in the frame of that hit" % victim.hit_points)
