extends RefCounted
## The lifecycle for the tyre_tracks scenario (Story 026 AC-4), real keys and the game's own flows on Map 01, every row the watch's
## (tyre_tracks_watch.gd). In every window the same audit reads each row: a Unit's tyres stroke only when the Unit was alive and on the floor after
## the tick before and alive after the one before that, as the same type, never farther than the jump step, and each stroke is where the tyre
## touched the ground. The windows: bench_then_spawn (a Unit benched at speed and put in play again 1.5 m ahead, inside the jump step, so only
## the "was alive the tick before" rule can stop a line from where it was to where it appears, and it stands still for ten ticks: not one stroke),
## teleport (an alive Unit put 40 m away while it rolls: no stroke on the tick of the jump, and the strokes after it start at the new place),
## off_the_floor (a Unit put 6 m up and driven while it falls: no stroke while it is not on the floor, strokes after it lands), swap (a real Swap
## at the own Base, a Buggy swapped for a Truck (four tyres in both, so only the type tells them apart): put in, the Self-destruct key, the choice keys,
## the new Unit driven off: its benched ticks draw nothing and no line joins the Garage to where it appears) and destroyed (a real Self-destruct outside the Base while rolling, the wait for the respawn, the choice keys, the
## new Unit driven: nothing while it is destroyed), destroyed_in_motion (a Unit destroyed AFTER its own tick, so it has moved in the very tick that
## destroys it: nothing is drawn for that last move, which the node reads one tick later when the Unit is no longer alive) and retyped_alive (a Buggy put in
## play again as a Truck without being benched first, four tyres in both, 1.5 m ahead: the type is all that tells the two apart, and no stroke joins them).
## Run by tyre_tracks.gd. Tooling only. Every number comes from the game's data; the scenario
## types only its test inputs.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")


## A node that destroys a Unit on the first tick it runs after being armed, after every Unit's own tick and before the watch reads the rows (physics priority
## above the Units' and just below the watch's): the Unit has moved in the tick that destroys it, which a destruction by a key, called before the Unit's tick,
## never does, and the row of that tick already shows it destroyed.
class Killer extends Node:
	## The Unit to destroy.
	var unit: Unit
	## Set to true to destroy the Unit on this node's next tick.
	var armed: bool = false

	func _init() -> void:
		process_physics_priority = 99

	func _physics_process(_delta: float) -> void:
		if armed:
			armed = false
			unit.destroy()


## Where Player 1 stands to start a case (the open middle of the Map's salt flat, facing east); Player 2 at the mirror across x = 0 facing west.
const OPEN: Vector3 = Vector3(-22.0, 0.0, -16.0)
## Ticks a Unit rolls before the event of a case, and the ticks the case watches after it.
const ROLL_TICKS: int = 40
const AFTER_TICKS: int = 60
## Metres ahead of where a benched Unit stood that it is put in play again: inside the jump step, so the jump guard cannot be what stops the line.
const SPAWN_AHEAD: float = 1.5
## Where an alive Unit is put to jump (world x, z of Player 1), and how high a Unit is put to fall (metres).
const JUMP_TO: Vector3 = Vector3(-62.0, 0.0, -16.0)
const DROP_HEIGHT: float = 6.0
## Ticks of a standing Unit watched after a spawn, and the least benched ticks a window must hold to count as one.
const STAND_TICKS: int = 10
const BENCHED_TICKS: int = 3
## How many rows back a stroke of a slow roll may start (Kit26.SLOW_ROLL_ROWS).
const SLOW_ROLL_ROWS: int = Kit26.SLOW_ROLL_ROWS

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit26
var _q: Quick
var _jump_step: float


func _init(kit: Kit26) -> void:
	_k = kit
	_q = kit.q()
	_jump_step = kit.tracks().settings.jump_step


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.walls().turrets_down()
	await _bench_then_spawn()
	await _teleport()
	await _off_the_floor()
	await _swap()
	await _destroyed()
	await _destroyed_in_motion()
	await _retyped_alive()


## Both Players' Units at rest as Motorbikes at the open spots, then `ticks` of throttle held by both.
func _rolling(ticks: int) -> void:
	await _k.stage(Quick.MOTORBIKE, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])
	_k.begin_rows()
	await _k.run([Kit26.plan([[ticks, 1, 0]]), Kit26.plan([[ticks, 1, 0]])])


## bench_then_spawn (AC-4): see the class doc.
func _bench_then_spawn() -> void:
	await _rolling(ROLL_TICKS)
	var unit: Unit = _q.units.units[0]
	var at: Transform3D = unit.global_transform
	unit.leave_play()
	await _q.kit.advance(BENCHED_TICKS)
	unit.spawn(Transform3D(at.basis, at.origin - at.basis.z * SPAWN_AHEAD))
	await _q.kit.advance(STAND_TICKS)
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	var last: Array[Dictionary] = []
	for index: int in range(rows.size() - STAND_TICKS, rows.size()):
		last.append_array(Kit26.strokes_of(rows[index], 0))
	_q.kit.need(audit["problems"], last.is_empty(), "%d strokes in the %d ticks the new Unit stood still after its spawn" % [last.size(), STAND_TICKS])
	_q.kit.need(audit["problems"], int(audit["benched"]) >= BENCHED_TICKS and SPAWN_AHEAD < _jump_step, "premise: %d benched Unit-ticks, the spawn %.2f m from where it was benched, the jump step %.2f m" % [audit["benched"], SPAWN_AHEAD, _jump_step])
	_q.kit.verdict("bench_then_spawn", audit["problems"], "Player 1's Motorbike benched at speed and put in play again %.1f m ahead (inside the jump step of %.1f m), standing still for %d ticks: no stroke joins the two places; the audit read %d rows with %d strokes and %d benched Unit-ticks" % [SPAWN_AHEAD, _jump_step, STAND_TICKS, rows.size(), audit["strokes"], audit["benched"]])


## teleport (AC-4): see the class doc. The tool puts the Unit between two ticks, so the tracks see the new place on the very tick that follows, one
## row sooner than the rows show: the strokes of the rows from the put on are judged by where they are (none near the old place, the first two
## rows none at all), and their ends are judged only once the Unit has rolled on from rest for a while.
func _teleport() -> void:
	await _rolling(ROLL_TICKS)
	var unit: Unit = _q.units.units[0]
	var old: Vector2 = Vector2(unit.global_position.x, unit.global_position.z)
	var put_row: int = _k.watch.rows.size()
	_q.harness.place(unit, Transform3D(Basis.IDENTITY.rotated(Vector3.UP, -PI / 2.0), JUMP_TO), _q.units.cameras[0])
	await _k.run([Kit26.plan([[AFTER_TICKS, 1, 0]]), Kit26.plan([[AFTER_TICKS, 1, 0]])])
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step, put_row + SLOW_ROLL_ROWS)
	var jump: float = old.distance_to(Vector2(JUMP_TO.x, JUMP_TO.z))
	var near: int = 0
	var jumped: int = 0
	for index: int in range(put_row, rows.size()):
		for stroke: Dictionary in Kit26.strokes_of(rows[index], 0):
			near += 1 if (stroke["from"] as Vector2).distance_to(old) < jump / 2.0 or (stroke["to"] as Vector2).distance_to(old) < jump / 2.0 else 0
			jumped += 1 if index <= put_row + 1 else 0
	_q.kit.need(audit["problems"], near == 0 and jumped == 0 and jump > _jump_step, "after the put (row %d, %.0f m, jump step %.1f m): %d strokes near the old place, %d in the first two rows" % [put_row, jump, _jump_step, near, jumped])
	_q.kit.verdict("teleport", audit["problems"], "Player 1's Motorbike, rolling, put %.0f m away between two ticks (the jump step is %.1f m): the two rows after the put drew no stroke, none of the %d strokes of the window ends or starts near the old place, and every other stroke is where its tyre touched the ground" % [jump, _jump_step, audit["strokes"]])


## off_the_floor (AC-4): see the class doc.
func _off_the_floor() -> void:
	await _k.stage(Quick.MOTORBIKE, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])
	var up: Vector3 = Vector3(OPEN.x, DROP_HEIGHT, OPEN.z)
	_k.begin_rows()
	_q.harness.place(_q.units.units[0], Transform3D(Basis.IDENTITY.rotated(Vector3.UP, -PI / 2.0), up), _q.units.cameras[0])
	await _k.run([Kit26.plan([[AFTER_TICKS * 2, 1, 0]]), Kit26.plan([[AFTER_TICKS * 2, 1, 0]])])
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	var after: int = 0
	for index: int in range(2, rows.size()):
		after += Kit26.strokes_of(rows[index], 0).size() if Kit26.explained(rows, index, 0) else 0
	_q.kit.need(audit["problems"], int(audit["airborne"]) >= AFTER_TICKS / 2 and after > 0, "premise: %d Unit-ticks off the floor, %d strokes of Player 1 once it landed" % [audit["airborne"], after])
	_q.kit.verdict("off_the_floor", audit["problems"], "Player 1's Motorbike put %.0f m up and driven while it fell: %d Unit-ticks off the floor drew nothing, and %d strokes followed once it was down" % [DROP_HEIGHT, audit["airborne"], after])


## swap (AC-4): see the class doc.
func _swap() -> void:
	var swap_kit: Object = _k.swap()
	await _k.stage(Quick.BUGGY, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])
	_k.begin_rows()
	var latency: int = await swap_kit.zone_latency(0)
	await swap_kit.enter_pressing(0, latency, 0)
	await swap_kit.play(0, Quick.TRUCK)
	await _k.run([Kit26.plan([[AFTER_TICKS, 1, 0]]), Kit26.plan([[AFTER_TICKS, 0, 0]])])
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	var types: PackedStringArray = []
	for row: Dictionary in rows:
		var type_id: String = String(((row["stats"] as Array)[0] as UnitStats).type_id)
		if types.is_empty() or types[types.size() - 1] != type_id:
			types.append(type_id)
	_q.kit.need(audit["problems"], int(audit["benched"]) >= BENCHED_TICKS and types.size() == 2, "premise: %d benched Unit-ticks, the types seen %s" % [audit["benched"], types])
	_q.kit.verdict("swap", audit["problems"], "a real Swap at Player 1's own Base (put in, Self-destruct, the choice keys; the types seen %s), the new Unit driven off: %d rows, %d strokes, %d benched Unit-ticks, no stroke outside the audit's rule" % [", ".join(types), rows.size(), audit["strokes"], audit["benched"]])


## destroyed (AC-4): see the class doc.
func _destroyed() -> void:
	var swap_kit: Object = _k.swap()
	await _k.stage(Quick.MOTORBIKE, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])
	swap_kit.flags.teleport(0, swap_kit.outside_point(0), swap_kit.gate_way(0))
	await _q.kit.advance(ROLL_TICKS)
	_k.begin_rows()
	await _k.run([Kit26.plan([[ROLL_TICKS, 1, 0]]), Kit26.plan([[ROLL_TICKS, 0, 0]])])
	await _q.kit.press_settled(Kit26.Tokens.keys(&"destruct", 0))
	await _q.kit.advance(AFTER_TICKS)
	await _k.mines().revive(0)
	await _k.run([Kit26.plan([[AFTER_TICKS, 1, 0]]), Kit26.plan([[AFTER_TICKS, 0, 0]])])
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	_q.kit.need(audit["problems"], int(audit["benched"]) >= AFTER_TICKS, "premise: only %d destroyed Unit-ticks" % audit["benched"])
	_q.kit.verdict("destroyed", audit["problems"], "a real Self-destruct outside Player 1's Base while it rolled, the wait for the respawn and the choice keys, the new Unit driven: %d rows, %d strokes, %d Unit-ticks destroyed, none drew" % [rows.size(), audit["strokes"], audit["benched"]])


## destroyed_in_motion (AC-4): see the class doc.
func _destroyed_in_motion() -> void:
	await _rolling(ROLL_TICKS)
	var unit: Unit = _q.units.units[0]
	var killer: Killer = Killer.new()
	killer.unit = unit
	_q.harness.add_child(killer)
	killer.armed = true
	await _q.kit.advance(STAND_TICKS)
	killer.queue_free()
	var rows: Array[Dictionary] = _k.end_rows()
	await _k.mines().revive(0)
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	var killed: int = -1
	for index: int in range(1, rows.size()):
		if killed < 0 and (rows[index - 1]["alive"] as Array)[0] and not (rows[index]["alive"] as Array)[0]:
			killed = index
	var moved: float = Kit26.contact(rows[killed], 0, 0).distance_to(Kit26.contact(rows[killed - 1], 0, 0)) if killed > 0 else 0.0
	_q.kit.need(audit["problems"], killed > 0 and moved > _k.tracks().settings.min_step and int(audit["benched"]) >= STAND_TICKS - 2, "premise: destroyed at row %d, moved %.4f m in that tick, %d destroyed Unit-ticks" % [killed, moved, audit["benched"]])
	_q.kit.verdict("destroyed_in_motion", audit["problems"], "Player 1's Motorbike, rolling, destroyed after its own tick (it moved %.3f m in the tick that destroyed it): the %d rows held %d strokes, none of them for that move or after it" % [moved, rows.size(), audit["strokes"]])


## retyped_alive (AC-4): see the class doc.
func _retyped_alive() -> void:
	await _k.stage(Quick.BUGGY, [OPEN, Quick.mirrored(OPEN)], [Vector3.RIGHT, Vector3.LEFT])
	_k.begin_rows()
	await _k.run([Kit26.plan([[ROLL_TICKS, 1, 0]]), Kit26.plan([[ROLL_TICKS, 0, 0]])])
	var unit: Unit = _q.units.units[0]
	var at: Transform3D = unit.global_transform
	unit.spawn(Transform3D(at.basis, at.origin - at.basis.z * SPAWN_AHEAD), _q.units.stats(Quick.TRUCK))
	await _q.kit.advance(STAND_TICKS)
	var rows: Array[Dictionary] = _k.end_rows()
	var audit: Dictionary = Kit26.audit(rows, _jump_step)
	var after: int = 0
	for index: int in range(rows.size() - STAND_TICKS, rows.size()):
		after += Kit26.strokes_of(rows[index], 0).size()
	var types: PackedStringArray = []
	for row: Dictionary in rows:
		var type_id: String = String(((row["stats"] as Array)[0] as UnitStats).type_id)
		if types.is_empty() or types[types.size() - 1] != type_id:
			types.append(type_id)
	_q.kit.need(audit["problems"], after == 0 and types.size() == 2 and int(audit["benched"]) == 0, "%d strokes in the %d ticks after the retype, types %s, %d benched Unit-ticks" % [after, STAND_TICKS, types, audit["benched"]])
	_q.kit.verdict("retyped_alive", audit["problems"], "Player 1's Buggy put in play again as a Truck, never benched, %.1f m ahead (types seen %s): the Unit stood still for %d ticks and drew no stroke, though both have four tyres; the audit read %d rows with %d strokes" % [SPAWN_AHEAD, ", ".join(types), STAND_TICKS, rows.size(), audit["strokes"]])

