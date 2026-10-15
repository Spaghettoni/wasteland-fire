extends RefCounted
## What a fallen field panel lets through, for the garage_scrap_walls scenario (Story 019 AC-4): field_breach (a Unit
## and a Shot through the breach of a field wall's lane panel, the three other panels standing; a lay beside or in a
## standing field panel refused with "No room for a Mine here" and laid once it has fallen, and the Mine destroys the
## Buggy that drives over it). Run by garage_scrap_walls.gd. Tooling only. Every number comes from the game's data; the
## scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## A Shot fired through a breach must end this far past the near face of the wall it crossed, metres.
const THROUGH: float = 1.0
## Metres from the field wall's axis where the drop points of the lays lie: 0.5 m outside the outer face, in the
## footprint (0.75 m in) and 0.5 m inside the inner face; a Mine's reach is 0.8 m.
const DROPS: Array[float] = [13.75, 12.5, 10.25]
const ROOM_TEXT: String = "No room for a Mine here"
const QUIET_LIMIT: int = 200
const DRIVE_LIMIT: int = 420
const SPENT_WAIT: int = 60
const DEATH_REACH: float = 4.5
const DROP_TOLERANCE: float = 0.01

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _field_breach()


## field_breach (AC-4): see the class doc.
func _field_breach() -> void:
	var problems: PackedStringArray = []
	var drives: int = 0
	var order: Array = [[[Kit19.WEST, Kit19.EAST], [true, false]], [[Kit19.WEST, Kit19.EAST], [false, true]],
		[[Kit19.EAST, Kit19.WEST], [true, false]], [[Kit19.EAST, Kit19.WEST], [false, true]]]
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.TRUCK]:
		for entry: Array in order:
			drives += 2
			await _k.drive_pair(type_index, entry[0], entry[1], problems)
	var shot_note: String = await _shot_through(problems)
	var laid: PackedStringArray = await _mines(problems)
	_q.kit.need(problems, _q.units.stats(Quick.TRUCK).collision_size.x < Kit19.LENGTHS[Kit19.WEST], "the Truck (%.2f m wide) does not fit a field breach (%.2f m)" % [_q.units.stats(Quick.TRUCK).collision_size.x, Kit19.LENGTHS[Kit19.WEST]])
	measured.append("field_drives=%d" % drives)
	_q.kit.verdict("field_breach", problems, "%d drives at full throttle, a Motorbike, a Buggy and a Truck of each Player through the breach of the lane panel of each field wall (the 3 m gap; the Truck is %.2f m wide), from outside and from the middle of the Map (one Player each way, so that the two never cross), no wall contact, %.0f m past the far face, the other three panels standing and each blocking a ray; %s; %s" % [
		drives, _q.units.stats(Quick.TRUCK).collision_size.x, Kit19.PAST_FIELD, shot_note, "; ".join(laid)])
	await _k.restore_all()


## A Shot fired from outside the west field wall at its fallen lane panel flies through (its end lies past the inner face).
func _shot_through(problems: PackedStringArray) -> String:
	var run: int = Kit19.WEST
	await _k.restore_all()
	_k.panel(0, run, Kit19.LANE[run]).destroy()
	await _k.k.stage(0, Quick.BUGGY, _k.spot(0, run, Kit19.LANE[run], Kit19.OUTER_FACES[run] + 8.0), -_k.outward(0, run))
	await _q.kit.advance(_k.k.m.w.longest_cadence())
	var end: Vector3 = await _k.k.m.w.shoot(0)
	var along: float = _k.along_out(0, run, end)
	_q.kit.need(problems, end != Vector3.INF and along <= Kit19.INNER_FACES[run] - THROUGH, "the Shot through the west breach ended at %.2f m from the axis, not past the inner face (%.2f)" % [along, Kit19.INNER_FACES[run]])
	return "a Shot fired from outside at the fallen west panel flew through (it ended %.1f m on, past the inner face at %.2f)" % [Kit19.INNER_FACES[run] - along, Kit19.INNER_FACES[run]]


## Waits until the notice line of Player 1 is hidden (a refusal stays about 1.5 s).
func _quiet() -> void:
	for _tick: int in QUIET_LIMIT:
		if _k.k.m.note(0) == "hidden":
			return
		await _q.kit.tick()


## A new Truck of Player 1 stands beside the west wall's lane panel, with its drop point `drop` metres from the Map's
## axis along the wall's outward direction, and presses E: {laid, reason, note, left, record, drop}.
func _press(drop: float) -> Dictionary:
	var run: int = Kit19.WEST
	var behind: float = _q.units.stats(Quick.TRUCK).mine_drop_offset.z
	var from_outside: bool = drop >= Kit19.OUTER_FACES[run] - 1.0
	await _quiet()
	await _k.k.m.revive(0)
	await _k.k.m.put(0, Quick.TRUCK, _k.spot(0, run, Kit19.LANE[run], drop + behind if from_outside else drop - behind), _k.outward(0, run) * (1.0 if from_outside else -1.0))
	var truck: Unit = _q.units.units[0]
	var laid: int = _k.k.m.laid.size()
	var refused: int = _k.k.m.refused[0].size()
	var record: Dictionary = await _k.k.m.lay(0)
	return {"laid": _k.k.m.laid.size() > laid, "reason": int(_k.k.m.refused[0][-1].x) if _k.k.m.refused[0].size() > refused else -1, "note": _k.k.m.note(0),
		"left": _k.k.m.layers[0].mines_left, "record": record, "drop": truck.global_transform * truck.stats.mine_drop_offset}


## The lays at the west wall's lane panel (see the class doc): each drop point refused while the panel stands and laid
## once it has fallen; then a Buggy drives through the breach over the Mines.
func _mines(problems: PackedStringArray) -> PackedStringArray:
	var run: int = Kit19.WEST
	var load_size: int = _q.units.stats(Quick.TRUCK).mine_capacity
	var target: Structure = _k.panel(0, run, Kit19.LANE[run])
	var notes: PackedStringArray = []
	var records: Array[Dictionary] = []
	await _k.restore_all()
	await _k.k.m.clear_mines()
	for drop: float in DROPS:
		var got: Dictionary = await _press(drop)
		_q.kit.need(problems, not got["laid"] and got["reason"] == MineLayer.Refusal.NO_ROOM and got["note"] == ROOM_TEXT and got["left"] == load_size, "drop point %.2f m out, panel standing: %s" % [drop, {"laid": got["laid"], "reason": got["reason"], "note": got["note"], "left": got["left"]}])
	target.destroy()
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	for drop: float in DROPS:
		var got: Dictionary = await _press(drop)
		var off: float = _k.k.m.place_of(got["record"]).distance_to(got["drop"]) if got["laid"] else INF
		_q.kit.need(problems, got["laid"] and got["left"] == load_size - 1 and got["note"] == "hidden" and off <= DROP_TOLERANCE, "drop point %.2f m out, panel fallen: laid %s, %s left, note '%s', %.3f m from the drop point" % [drop, got["laid"], got["left"], got["note"], off])
		records.append(got)
	notes.append("a Truck's E key with its drop point 0.5 m outside the wall, in its footprint and 0.5 m inside it was refused with \"%s\" while the lane panel stood (%d refusals) and laid a Mine at each drop point once it had fallen (%d Mines)" % [ROOM_TEXT, DROPS.size(), records.size()])
	await _q.kit.advance(_k.k.m.LIVE_WAIT)
	var half: float = _q.units.stats(Quick.BUGGY).collision_size.z / 2.0
	await _k.k.stage(1, Quick.BUGGY, _k.spot(0, run, Kit19.LANE[run], _k.start_out(run, half, true)), -_k.outward(0, run))
	var buggy: Unit = _q.units.units[1]
	var died: Vector3 = Vector3.INF
	for _tick: int in DRIVE_LIMIT:
		_q.harness.drive(1, 1, 0)
		await _q.kit.tick()
		if not buggy.is_alive:
			died = buggy.global_position
			break
	_q.harness.release_all()
	var first: Dictionary = records[0]
	var gone: int = await _k.k.m.wait_gone(first["record"], SPENT_WAIT)
	var at: float = _k.along_out(0, run, died) if died != Vector3.INF else INF
	_q.kit.need(problems, died != Vector3.INF and absf(at - DROPS[0]) <= DEATH_REACH and gone >= 0, "the Buggy was destroyed %s at %.2f m from the axis (the first Mine lay at %.2f), that Mine gone at tick %d" % [died != Vector3.INF, at, DROPS[0], gone])
	notes.append("a live Mine in the breach destroyed the Buggy that drove through over it, %.2f m from the first Mine" % absf(at - DROPS[0]))
	await _k.k.m.clear_mines()
	return notes
