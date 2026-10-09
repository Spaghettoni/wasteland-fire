extends RefCounted
## The Round flows of the flag_walls scenario, part one (Story 012 AC-1, AC-4 and AC-6): spots (a
## Unit appears on the Garage's first spot after a respawn and after a Swap, and on the spare while
## the other Player's Unit stands on the first), closed (with all four Flag Walls standing the other
## Player's Motorbike driven at each side of both boxes is stopped and the Flag's touch never
## reports it), raids (a Truck breaks the Gate-side Flag Wall with the Player's own fire key, two
## Shots, the Motorbike takes the Flag through the gap, backs out and delivers it: the win, then R)
## and breaches (each single Flag Wall down in turn, four sides at both Bases, lets the Motorbike
## take the Flag and drive out). flag_walls_returns.gd then runs owner_return and reset. Run by
## flag_walls.gd. Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-1, AC-4 and
## AC-6. Tooling only. Every number comes from the game's data; the scenario types only its test
## inputs.

## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed, the settle after a put-out.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The owner's return and the reset (flag_walls_returns.gd).
const Returns: GDScript = preload("res://tools/evidence/split_screen/flag_walls_returns.gd")

## Ticks a Motorbike driven at a closed box has to be stopped by it (1.5 s).
const CLOSED_TICKS: int = 90
## The Shots a Truck needs to break a Flag Wall (25 against 40 hit points), asserted below from the
## data.
const TRUCK_SHOTS: int = 2

## The engine errors the flows cause on purpose.
var expected_errors: int = 0

var _w: Walls


func _init(kit: Walls) -> void:
	_w = kit


## The flows, in order. A coroutine: await it.
func run() -> void:
	await _spots()
	await _closed()
	await _raids()
	await _breaches()
	var returns: Returns = Returns.new(_w)
	await returns.run()
	expected_errors += returns.expected_errors


## spots (AC-6): each Player's new Unit stands on the first spot after its Unit was destroyed
## outside its Base and chose again, and after a Swap; with the other Player's Unit put on the first
## spot, a Swap's new Unit stands on the spare.
func _spots() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	for player: int in Kit.PLAYERS:
		_w.s.flags.teleport(player, _w.s.outside_point(player), _w.s.gate_way(player))
		await q.kit.advance(Swap.OUT_SETTLE_TICKS)
		await q.tokens.destruct(player)
		await _w.s.play(player, Quick.BUGGY)
		q.kit.need(problems, _w.on_first_spot(player), "p%d: after a respawn the Unit is not on the first spot" % (player + 1))
		await _swap(player, Quick.MOTORBIKE)
		q.kit.need(problems, _w.on_first_spot(player), "p%d: after a Swap the Unit is not on the first spot" % (player + 1))
		var first: Marker3D = _w.bases[player].spawn_point
		_w.s.flags.teleport(1 - player, first.global_position, -first.global_transform.basis.z)
		await q.kit.advance(Walls.SETTLE)
		await _swap(player, Quick.BUGGY)
		var spare: Marker3D = _w.bases[player].spare_spawn_points[0]
		q.kit.need(problems, q.units.units[player].global_position.distance_to(spare.global_position) <= Kit.SPAWN_TOLERANCE, "p%d: with the first spot taken the new Unit is not on the spare" % (player + 1))
		await _w.park(1 - player)
	q.kit.verdict("spots", problems, "each Player's new Unit stood on the Garage's first spot after a respawn and after a Swap, and on the spare while the other Player's Unit stood on the first")


## Player `player` Swaps its Unit at home (Self-destruct inside its own Base) and chooses a type.
func _swap(player: int, type_index: int) -> void:
	await _w.s.enter(player)
	await _w.s.wait_swappable(player)
	await _w.s.q.tokens.destruct(player)
	await _w.s.play(player, type_index)


## closed (AC-1): with all four Flag Walls of a box standing, the other Player's Motorbike driven at
## each of its four sides is stopped at the face, the Flag's touch never reports it, nothing is
## picked up and the owner's HUD keeps its "at home" line while the raider's never shows "carry".
func _closed() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var stopped: PackedStringArray = []
	for base_index: int in Kit.PLAYERS:
		var raider: int = 1 - base_index
		for side: int in Walls.SIDE_NAMES.size():
			await _w.face(raider, Quick.MOTORBIKE, base_index, side, Walls.FACE + Walls.RUN_UP)
			var touched: bool = false
			var picked: bool = false
			q.harness.drive(raider, 1, 0)
			for _tick: int in CLOSED_TICKS:
				await q.kit.tick()
				touched = touched or _w.s.flags.touching(base_index, raider)
				picked = picked or _w.carrying(raider) or _w.status_text(raider) == q.units.huds[raider].carrying_text
			q.harness.drive(raider, 0, 0)
			var half: float = q.units.units[raider].stats.collision_size.z / 2.0
			var label: String = "%s side %s" % [_w.bases[base_index].name, Walls.SIDE_NAMES[side]]
			q.kit.need(problems, not touched and not picked and _w.s.flags.flags[base_index].state == Flag.State.AT_HOME, "%s: touched %s, carried %s, Flag %s" % [label, touched, picked, _w.s.flags.state_name(base_index)])
			q.kit.need(problems, absf(_w.along(raider, base_index, side) - (Walls.FACE + half)) <= 0.1, "%s: the Motorbike stopped %.2f m out of the seat, not %.2f" % [label, _w.along(raider, base_index, side), Walls.FACE + half])
			q.kit.need(problems, _w.status_text(base_index) == q.units.huds[base_index].home_text, "%s: the owner's HUD reads '%s'" % [label, _w.status_text(base_index)])
			stopped.append("%.2f" % _w.along(raider, base_index, side))
	q.kit.need(problems, _w.s.flags.pick_ups.is_empty(), "%d pick-ups with every Flag Wall standing" % _w.s.flags.pick_ups.size())
	q.kit.verdict("closed", problems, "8 drives at full throttle for %d ticks, one at each side of both boxes: stopped at the face (%s m from the seat), touching() false throughout, no pick-up, the owner's HUD 'at home' and the raider's never 'carry'" % [CLOSED_TICKS, ", ".join(stopped)])


## raids (AC-1, AC-4): per Player, a Truck breaks the other Player's Gate-side Flag Wall with that
## Player's fire key (TRUCK_SHOTS Shots), the rubble shows and a ray reaches the seat through the
## gap while the other three stand; its Motorbike drives in, is handed the Flag, backs out and
## delivers it.
func _raids() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var truck: UnitStats = q.units.stats(Quick.TRUCK)
	var shots: int = ceili(Walls.HIT_POINTS / (truck.damage * q.controller.rules.damage_matrix.multiplier(truck.type_id, &"flag_wall")))
	q.kit.need(problems, shots == TRUCK_SHOTS, "the data needs %d Truck shots, not %d" % [shots, TRUCK_SHOTS])
	var notes: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var foe: int = 1 - player
		var wall: Structure = _w.wall(foe, Walls.GATE)
		await _w.face(player, Quick.TRUCK, foe, Walls.GATE, 12.0)
		await q.kit.advance(_w.longest_cadence())
		for shot: int in TRUCK_SHOTS:
			await q.units.hold_fire(player, 1)
			await q.kit.advance(_w.cadence(Quick.TRUCK))
		var mesh: Node3D = wall.get_node("Mesh") as Node3D
		var rubble: Node3D = wall.get_node("Rubble") as Node3D
		q.kit.need(problems, not wall.is_standing and not mesh.visible and rubble.visible and wall.collision_layer == 0, "p%d: the Gate-side Flag Wall: standing %s, Mesh shown %s, rubble shown %s" % [player + 1, wall.is_standing, mesh.visible, rubble.visible])
		q.kit.need(problems, not _w.axis_blocked(foe, Walls.GATE) and _w.wall(foe, Walls.GARAGE).is_standing and _w.wall(foe, Walls.LEFT).is_standing and _w.wall(foe, Walls.RIGHT).is_standing, "p%d: a ray through the gap is blocked or another Flag Wall fell" % (player + 1))
		q.kit.need(problems, await _w.take_flag(player, foe, Walls.GATE), "p%d never took the Flag through the gap" % (player + 1))
		q.kit.need(problems, _w.status_text(player) == q.units.huds[player].carrying_text, "p%d: the HUD reads '%s'" % [player + 1, _w.status_text(player)])
		await _w.back_out(player, foe, Walls.GATE)
		q.kit.need(problems, await _w.deliver(player) and q.controller.winner_index() == player and q.tokens.over_lines(player)[0] == "Player %d wins!" % (player + 1), "p%d: the delivery did not win (over %s, winner %d, '%s')" % [player + 1, q.controller.is_round_over(), q.controller.winner_index(), q.tokens.over_lines(player)])
		notes.append("p%d: %d Truck Shots, rubble, the Motorbike carried the Flag out through the gap and won" % [player + 1, shots])
		await _w.restart()
	q.kit.verdict("raids", problems, " | ".join(notes))


## breaches (AC-4): each single Flag Wall down in turn (destroy(), for speed), the four sides at
## both Bases: the other Player's Motorbike drives in, is handed the Flag, reverses out and delivers
## it.
func _breaches() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var cases: int = 0
	for base_index: int in Kit.PLAYERS:
		var raider: int = 1 - base_index
		for side: int in Walls.SIDE_NAMES.size():
			_w.wall(base_index, side).destroy()
			await q.kit.advance(Walls.SETTLE)
			var label: String = "%s side %s down" % [_w.bases[base_index].name, Walls.SIDE_NAMES[side]]
			q.kit.need(problems, await _w.take_flag(raider, base_index, side) and _w.status_text(raider) == q.units.huds[raider].carrying_text, "%s: the Motorbike was not handed the Flag" % label)
			await _w.back_out(raider, base_index, side)
			q.kit.need(problems, _w.along(raider, base_index, side) >= Walls.FACE + 1.0, "%s: the Carrier did not back out (%.2f m from the seat)" % [label, _w.along(raider, base_index, side)])
			q.kit.need(problems, await _w.deliver(raider) and q.controller.winner_index() == raider, "%s: no delivery" % label)
			cases += 1
			await _w.restart()
	q.kit.verdict("breach", problems, "%d cases: with any one Flag Wall down (four sides, both Bases) the other Player's Motorbike drove in, was handed the Flag ('You carry the enemy Flag'), reversed out and delivered it" % cases)
