extends RefCounted
## The Round flows of the flag_walls scenario, part two (Story 012 AC-5 and AC-7): owner_return (a
## Flag dropped inside a breached box is taken by its owner's Motorbike through the breach and
## seated on that same tick; one dropped against the outside of a standing Flag Wall is taken from
## that side, and a Unit inside the box does not touch it) and reset (a fallen or hurt Flag Wall
## stays as it is, look included, through a destruction, a respawn and a Swap; R brings back all
## eight, whole, solid and in the whole look, with both Units benched and both Flags seated at that
## moment, and the restored box stops the Motorbike again). Run by flag_walls_flows.gd. Implements:
## production/epics/wasteland-fire/story-012-flag-walls.md AC-5, AC-7 and AC-9. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs.

## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## Metres out of a face where a Carrier is put to drop the Flag against it, the centre of a
## Motorbike pressed against it (its half-length) and a hair more.
const AGAINST: float = 1.35
## Ticks a Unit inside a box is watched for touching a Flag outside it.
const WATCH_TICKS: int = 30
## Hit points taken off a Flag Wall that the reset must refill: 30 of 40 left, below the first
## damaged look's fraction, so the hurt wall shows that look until R.
const HURT: float = 10.0

## The engine errors this script causes on purpose.
var expected_errors: int = 0

var _w: Walls
## What each round_started found, read in a handler connected after the Structures' own restore:
## {alive, flags_home, walls_whole}.
var _starts: Array[Dictionary] = []


func _init(kit: Walls) -> void:
	_w = kit
	_w.s.controller.round_started.connect(_on_round_started)


## owner_return, then reset. A coroutine: await it.
func run() -> void:
	await _owner_return()
	await _reset()


## owner_return (AC-7): Player 2 breaches Player 1's Garage-side Flag Wall, takes Player 1's Flag
## and Self-destructs (Enter) inside the box; Player 1's Motorbike drives in through the breach and
## its own Flag is picked up and seated on that same tick. Then Player 2 takes it again and
## Self-destructs pressed against the outside of the standing Gate-side Flag Wall: a Unit of Player
## 1 inside the box does not touch the Flag, and from outside the Gate-side face the Motorbike takes
## it and seats it.
func _owner_return() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var flag: Flag = _w.s.flags.flags[0]
	_w.wall(0, Walls.GARAGE).destroy()
	await q.kit.advance(Walls.SETTLE)
	q.kit.need(problems, await _w.take_flag(1, 0, Walls.GARAGE), "Player 2 never took Player 1's Flag through the breach")
	await q.tokens.destruct(1)
	var inside: Vector3 = _w.bases[0].to_local(flag.global_position) - Walls.SEAT
	q.kit.need(problems, flag.state == Flag.State.DROPPED and absf(inside.x) < Walls.FACE and absf(inside.z) < Walls.FACE, "Player 1's Flag is %s at %s, not dropped inside the box" % [_w.s.flags.state_name(0), inside])
	await _w.s.play(1, Quick.MOTORBIKE)
	var since: int = _w.s.order.size()
	await _w.face(0, Quick.MOTORBIKE, 0, Walls.GARAGE, Walls.FACE + Walls.RUN_UP)
	var seats: int = _w.s.flags.seats.size()
	await _w.s.flags.drive_until(0, 1, Swap.CRUISE, func() -> bool: return _w.s.flags.seats.size() > seats)
	var events: PackedStringArray = _w.s.order.slice(since)
	var picked: Array = Array(events).filter(func(line: String) -> bool: return line.contains("picked 0 by 0"))
	var seated: Array = Array(events).filter(func(line: String) -> bool: return line.contains("seated 0"))
	q.kit.need(problems, picked.size() == 1 and seated.size() == 1 and String(picked[0]).get_slice(" ", 0) == String(seated[0]).get_slice(" ", 0), "pick-up and seating: %s" % [events])
	q.kit.need(problems, flag.state == Flag.State.AT_HOME and _w.status_text(0) == q.units.huds[0].home_text and not _w.wall(0, Walls.GARAGE).is_standing, "Flag %s, HUD '%s', the breach stood %s" % [_w.s.flags.state_name(0), _w.status_text(0), _w.wall(0, Walls.GARAGE).is_standing])
	var note: String = "dropped inside the breached box, taken by its owner through the breach and seated on tick %s (%s)" % [String(seated[0]).get_slice(" ", 0) if not seated.is_empty() else "?", ", ".join(events)]
	note += " | " + await _outside_a_standing_wall(problems)
	q.kit.verdict("owner_return", problems, note)


## The second half of owner_return: Player 2 takes Player 1's Flag again, is put pressed against the
## outside of the standing Gate-side Flag Wall and Self-destructs there; Player 1's Motorbike put at
## the seat inside the box does not touch the Flag; put outside the Gate-side face it takes the Flag
## and seats it. Returns the note.
func _outside_a_standing_wall(problems: PackedStringArray) -> String:
	var q: Quick = _w.s.q
	var flag: Flag = _w.s.flags.flags[0]
	q.kit.need(problems, await _w.take_flag(1, 0, Walls.GARAGE), "Player 2 never took the Flag the second time")
	var face_z: float = Walls.SEAT.z - Walls.FACE
	_w.s.flags.teleport(1, _w.point(0, Vector3(0.0, 0.0, face_z - AGAINST)), _w.way(0, Vector3.BACK))
	await q.kit.advance(Walls.SETTLE)
	await q.tokens.destruct(1)
	await _w.s.play(1, Quick.MOTORBIKE)
	_w.s.flags.teleport(0, _w.point(0, Walls.SEAT), _w.way(0, Vector3.BACK))
	var reached: bool = false
	for _tick: int in WATCH_TICKS:
		await q.kit.tick()
		reached = reached or _w.s.flags.touching(0, 0)
	var gap: float = _w.bases[0].to_local(flag.global_position).z - face_z
	q.kit.need(problems, flag.state == Flag.State.DROPPED and not reached and _w.wall(0, Walls.GATE).is_standing, "the Flag is %s %.2f m outside the Gate-side face; a Unit inside the box touched it: %s" % [_w.s.flags.state_name(0), -gap, reached])
	_w.s.flags.teleport(0, _w.point(0, Vector3(0.0, 0.0, face_z - AGAINST - 3.0)), _w.way(0, Vector3.BACK))
	var seats: int = _w.s.flags.seats.size()
	await _w.s.flags.drive_until(0, 1, Swap.CRUISE, func() -> bool: return _w.s.flags.seats.size() > seats)
	q.kit.need(problems, flag.state == Flag.State.AT_HOME, "the Flag dropped outside the standing Flag Wall was not taken from that side (%s)" % _w.s.flags.state_name(0))
	return "dropped %.2f m outside the standing Gate-side Flag Wall, a Unit at the seat inside the box did not touch it in %d ticks, and from outside it was taken and seated" % [-gap, WATCH_TICKS]


## reset (AC-5): one Flag Wall stays fallen and one stays hurt through a destruction and respawn and
## a Swap; Player 2 then wins by the breach and R brings back all eight whole, solid and drawn, with
## both Units benched and both Flags seated when the Round starts, and the restored box stops the
## Motorbike.
func _reset() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var down: Structure = _w.wall(0, Walls.GARAGE)
	var hurt: Structure = _w.wall(1, Walls.LEFT)
	hurt.apply_damage(HURT)
	_w.s.flags.teleport(1, _w.s.outside_point(1), _w.s.gate_way(1))
	await q.kit.advance(Walls.SETTLE)
	await q.tokens.destruct(1)
	await _w.s.play(1, Quick.BUGGY)
	q.kit.need(problems, not down.is_standing and is_equal_approx(hurt.hit_points, Walls.HIT_POINTS - HURT) and _w.look_shown(down) == -1 and _w.look_shown(hurt) == 1, "after a destruction and a respawn: fallen standing %s (look %d), hurt %.1f (look %d)" % [down.is_standing, _w.look_shown(down), hurt.hit_points, _w.look_shown(hurt)])
	await _w.s.enter(0)
	await _w.s.wait_swappable(0)
	await q.tokens.destruct(0)
	await _w.s.play(0, Quick.MOTORBIKE)
	q.kit.need(problems, not down.is_standing and is_equal_approx(hurt.hit_points, Walls.HIT_POINTS - HURT) and _w.look_shown(down) == -1 and _w.look_shown(hurt) == 1, "after a Swap: fallen standing %s (look %d), hurt %.1f (look %d)" % [down.is_standing, _w.look_shown(down), hurt.hit_points, _w.look_shown(hurt)])
	q.kit.need(problems, await _w.take_flag(1, 0, Walls.GARAGE), "Player 2 never took the Flag through the breach")
	await _w.back_out(1, 0, Walls.GARAGE)
	q.kit.need(problems, await _w.deliver(1) and q.controller.winner_index() == 1, "Player 2 did not win by the breach")
	var starts: int = _starts.size()
	await _w.restart()
	q.kit.need(problems, _starts.size() == starts + 1 and _starts[-1]["alive"] == [false, false] and _starts[-1]["flags_home"] and _starts[-1]["walls_whole"], "when the Round started again: %s" % [_starts.back() if not _starts.is_empty() else {}])
	var whole: int = 0
	for wall: Structure in _w.all():
		whole += 1 if wall.is_standing and is_equal_approx(wall.hit_points, Walls.HIT_POINTS) and wall.collision_layer == 64 and wall.collision_mask == 0 and _w.look_shown(wall) == 0 else 0
	q.kit.need(problems, whole == 8, "%d of 8 Flag Walls are whole after R" % whole)
	await _w.face(1, Quick.MOTORBIKE, 0, Walls.GARAGE, Walls.FACE + Walls.RUN_UP)
	q.harness.drive(1, 1, 0)
	var touched: bool = false
	for _tick: int in 90:
		await q.kit.tick()
		touched = touched or _w.s.flags.touching(0, 1) or _w.carrying(1)
	q.harness.drive(1, 0, 0)
	q.kit.need(problems, not touched and absf(_w.along(1, 0, Walls.GARAGE) - (Walls.FACE + 1.3)) <= 0.1, "the restored box did not stop the Motorbike (touched %s, %.2f m out)" % [touched, _w.along(1, 0, Walls.GARAGE)])
	q.kit.verdict("reset", problems, "a fallen Flag Wall (stayed down, rubble) and a hurt one (%.0f of %.0f, its first damaged look) stayed as they were through a destruction, a respawn and a Swap; R brought back all %d whole (40 hit points, layer 64, the whole look alone: damaged looks and rubble hidden) with both Units benched and both Flags seated when the Round started; the restored box stopped the Motorbike again" % [
		Walls.HIT_POINTS - HURT, Walls.HIT_POINTS, whole])


## Reads the Round's state when it starts (round_started): neither Unit in play, both Flags at home,
## every Flag Wall whole. Connected after SplitScreen's own restore, so the walls are back by now.
func _on_round_started() -> void:
	var walls_whole: bool = true
	for wall: Structure in _w.all():
		walls_whole = walls_whole and wall.is_standing and is_equal_approx(wall.hit_points, Walls.HIT_POINTS)
	_starts.append({"alive": [_w.s.controller.is_alive(0), _w.s.controller.is_alive(1)],
		"flags_home": _w.s.flags.flags[0].state == Flag.State.AT_HOME and _w.s.flags.flags[1].state == Flag.State.AT_HOME,
		"walls_whole": walls_whole})
