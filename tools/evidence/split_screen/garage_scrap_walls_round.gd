extends RefCounted
## stays_down and restore, for the garage_scrap_walls scenario (Story 019 AC-6). stays_down: a fallen Garage panel and a
## fallen field panel and two hurt ones (one at each damaged look), in both Garages and both field walls, stay exactly as
## they are, look included, through every key of both Players (Self-destruct apart), a destruction in a breach and the
## respawn, a Swap at home and a Flag dropped and taken back. restore: with Base A's Garage panels all fallen, Base B's
## fallen or hurt at either look, the field's likewise, a live Mine in a field breach and both Units standing in
## breaches (the Carrier, which won the Round there, in a Garage breach, and the other Player in a field breach), R
## brings every one of the 28 panels back whole (40 hit points, layer 64, the whole look alone) when the Round starts,
## both Units benched at the moment each of those two panels is restored, the Mine removed. Run by garage_scrap_walls.gd.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Wall that is broken to take the Flag.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd): the drive speed.
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## Hit points taken off a panel for each damaged look: 30 of 40 left (below the first fraction, 80%), 12 of 40 (below
## the second, 35%).
const HURT_FIRST: float = 10.0
const HURT_SECOND: float = 28.0
## The cover's physics layer, which a panel stands on.
const COVER_LAYER: int = 64
## Ticks a key is held for, and the ticks the Round has to end in once the Carrier stands in the Base's zone.
const KEY_HOLD: int = 12
const OVER_WAIT: int = 60
## Metres from the Map's axis where a Mine lies in the west field breach.
const MINE_OUT: float = 12.0

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit19
var _q: Quick
var _s: Object


func _init(kit: Kit19) -> void:
	_k = kit
	_q = kit.q()
	_s = kit.k.m.w.s


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _k.k.turrets_down()
	await _stays_down()
	await _restore()


## Every panel as the Round sees it: its place, hit points, look and whether it stands.
func _snapshot() -> PackedStringArray:
	var found: PackedStringArray = []
	for panel: Structure in _k.every():
		found.append("%s %.1f look %d standing %s" % [panel.get_path(), panel.hit_points, _k.k.look_shown(panel), panel.is_standing])
	return found


## No panel differs from the snapshot taken before.
func _same(label: String, before: PackedStringArray, problems: PackedStringArray) -> void:
	var now: PackedStringArray = _snapshot()
	var changed: PackedStringArray = []
	for index: int in mini(before.size(), now.size()):
		if before[index] != now[index]:
			changed.append("%s -> %s" % [before[index], now[index]])
	_q.kit.need(problems, changed.is_empty() and now.size() == before.size(), "%s: %d of %d panels differ: %s" % [label, changed.size(), before.size(), changed.slice(0, 3)])


## The keys of the input map, as physical codes: both Players' and the restart key, but Self-destruct (the Swap step
## presses it).
func _keys() -> Array[Key]:
	var found: Array[Key] = []
	for action: StringName in InputMap.get_actions():
		var name: String = String(action)
		if (name.begins_with("p1_") or name.begins_with("p2_") or name == "round_restart") and not name.contains("self_destruct"):
			for event: InputEvent in InputMap.action_get_events(action):
				var key: InputEventKey = event as InputEventKey
				if key != null:
					found.append(key.physical_keycode)
	return found


## The middle of a run's footprint at its lane panel, world.
func _in_breach(base_index: int, run: int) -> Vector3:
	return _k.spot(base_index, run, Kit19.LANE[run], (Kit19.INNER_FACES[run] + Kit19.OUTER_FACES[run]) / 2.0)


## stays_down (AC-6).
func _stays_down() -> void:
	var problems: PackedStringArray = []
	await _k.restore_all()
	var down: Array[Structure] = [_k.panel(0, Kit19.LEFT, Kit19.LANE[Kit19.LEFT]), _k.panel(0, Kit19.WEST, Kit19.LANE[Kit19.WEST])]
	var hurt: Array[Structure] = [_k.panel(1, Kit19.RIGHT, Kit19.LANE[Kit19.RIGHT]), _k.panel(0, Kit19.EAST, Kit19.LANE[Kit19.EAST])]
	for panel: Structure in down:
		panel.destroy()
	hurt[0].apply_damage(HURT_FIRST)
	hurt[1].apply_damage(HURT_SECOND)
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	var looks: Array[int] = [_k.k.look_shown(down[0]), _k.k.look_shown(down[1]), _k.k.look_shown(hurt[0]), _k.k.look_shown(hurt[1])]
	_q.kit.need(problems, looks == [-1, -1, 1, 2], "set up: the looks shown are %s, not rubble, rubble, first, second" % [looks])
	var before: PackedStringArray = _snapshot()
	await _k.k.stage(0, Quick.MOTORBIKE, _in_breach(0, Kit19.LEFT), _k.outward(0, Kit19.LEFT))
	_s.flags.teleport(1, _in_breach(0, Kit19.WEST), _k.outward(0, Kit19.WEST))
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	var keys: Array[Key] = _keys()
	for key: Key in keys:
		_q.harness.set_key(key, true)
		await _q.kit.advance(KEY_HOLD)
		_q.harness.set_key(key, false)
		await _q.kit.advance(2)
	_q.harness.release_all()
	await _k.k.m.revive(0)
	await _k.k.m.revive(1)
	_same("after %d keys, held for %d ticks each, with a Unit in a Garage breach and one in a field breach" % [keys.size(), KEY_HOLD], before, problems)
	_s.flags.teleport(1, _in_breach(0, Kit19.WEST), _k.outward(0, Kit19.WEST))
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	await _q.tokens.destruct(1)
	var destroyed: bool = not _q.units.units[1].is_alive
	await _s.play(1, Quick.BUGGY)
	_q.kit.need(problems, destroyed and _q.units.units[1].is_alive, "Player 2's Self-destruct in the field breach destroyed its Unit %s and the choice brought one back %s" % [destroyed, _q.units.units[1].is_alive])
	_same("after a destruction in a breach and the respawn", before, problems)
	await _s.enter(0)
	await _s.wait_swappable(0)
	await _q.tokens.destruct(0)
	await _s.play(0, Quick.MOTORBIKE)
	_same("after a Swap at home", before, problems)
	_k.k.m.w.wall(0, Walls.GATE).destroy()
	var took: bool = await _k.k.m.w.take_flag(1, 0, Walls.GATE)
	await _q.tokens.destruct(1)
	var dropped: bool = _s.flags.flags[0].state == Flag.State.DROPPED
	await _s.play(1, Quick.BUGGY)
	await _k.k.m.w.face(0, Quick.MOTORBIKE, 0, Walls.GATE, Walls.FACE + Walls.RUN_UP)
	var seats: int = _s.flags.seats.size()
	await _s.flags.drive_until(0, 1, Swap.CRUISE, func() -> bool: return _s.flags.seats.size() > seats)
	_q.kit.need(problems, took and dropped and _s.flags.flags[0].state == Flag.State.AT_HOME, "the Flag was taken %s, dropped %s and is %s after its owner took it back" % [took, dropped, _s.flags.state_name(0)])
	_same("after a Flag dropped and taken back", before, problems)
	measured.append("keys_swept=%d" % keys.size())
	_q.kit.verdict("stays_down", problems, "a fallen Garage panel (Base A's) and a fallen field panel (the west wall's) and a hurt one at each damaged look (30 and 12 of 40 hit points: Base B's Garage, the east field wall's) stayed exactly as they were, look included, through %d keys held %d ticks each (both Players' and R, which a Round still on ignores) with a Unit in a Garage breach and one in a field breach, a destruction in a breach and the respawn, a Swap at home, and a Flag dropped by a destroyed Carrier and taken back by its owner" % [keys.size(), KEY_HOLD])
	await _k.restore_all()


## restore (AC-6): see the class doc.
func _restore() -> void:
	var problems: PackedStringArray = []
	await _k.restore_all()
	var fallen: int = 0
	var first: int = 0
	var second: int = 0
	var every: Array[Structure] = _k.every()
	var watched: Array[Structure] = [_k.panel(0, Kit19.LEFT, Kit19.LANE[Kit19.LEFT]), _k.panel(0, Kit19.EAST, Kit19.LANE[Kit19.EAST])]
	for number: int in every.size():
		var panel: Structure = every[number]
		var base_a: bool = number < Kit19.COUNTS[Kit19.BACK] + 2 * Kit19.COUNTS[Kit19.LEFT]
		if base_a or number % 3 == 0 or watched.has(panel):
			panel.destroy()
			fallen += 1
		elif number % 3 == 1:
			panel.apply_damage(HURT_FIRST)
			first += 1
		else:
			panel.apply_damage(HURT_SECOND)
			second += 1
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	var shown: Dictionary = {-1: 0, 0: 0, 1: 0, 2: 0, -2: 0}
	for panel: Structure in every:
		shown[_k.k.look_shown(panel)] += 1
	_q.kit.need(problems, shown[-1] == fallen and shown[1] == first and shown[2] == second and shown[0] == 0 and shown[-2] == 0, "set up: looks shown %s for %d fallen, %d first, %d second" % [shown, fallen, first, second])
	var mine: Dictionary = await _k.k.m.place_mine(_k.spot(0, Kit19.WEST, Kit19.LANE[Kit19.WEST], MINE_OUT), 0)
	_k.k.m.w.wall(1, Walls.GATE).destroy()
	var carries: bool = await _k.k.m.w.take_flag(0, 1, Walls.GATE)
	var breach_a: Vector3 = _in_breach(0, Kit19.LEFT)
	_s.flags.teleport(0, breach_a, _k.outward(0, Kit19.LEFT))
	var over: bool = false
	for _wait: int in OVER_WAIT:
		await _q.kit.tick()
		over = _s.controller.is_round_over()
		if over:
			break
	var field_breach: Vector3 = _in_breach(0, Kit19.EAST)
	_s.flags.teleport(1, field_breach, _k.outward(0, Kit19.EAST))
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	var in_garage: bool = _k.along_out(0, Kit19.LEFT, _q.units.units[0].global_position) > Kit19.INNER_FACES[Kit19.LEFT] and _k.along_out(0, Kit19.LEFT, _q.units.units[0].global_position) < Kit19.OUTER_FACES[Kit19.LEFT]
	var in_field: bool = _k.along_out(0, Kit19.EAST, _q.units.units[1].global_position) > Kit19.INNER_FACES[Kit19.EAST] and _k.along_out(0, Kit19.EAST, _q.units.units[1].global_position) < Kit19.OUTER_FACES[Kit19.EAST]
	_q.kit.need(problems, carries and over and _s.controller.winner_index() == 0 and in_garage and in_field and not watched[0].is_standing and not watched[1].is_standing, "the Round: Flag taken %s, won %s (winner %d), the Carrier stands in the Garage wall's footprint %s and Player 2 in the field wall's %s, those two panels down %s and %s" % [carries, over, _s.controller.winner_index(), in_garage, in_field, not watched[0].is_standing, not watched[1].is_standing])
	var seen: Array[Dictionary] = []
	var note: Callable = func() -> void: seen.append({"alive": [_q.units.units[0].is_alive, _q.units.units[1].is_alive], "home": _s.flags.flags[0].state == Flag.State.AT_HOME and _s.flags.flags[1].state == Flag.State.AT_HOME})
	for panel: Structure in watched:
		panel.restored.connect(note)
	await _k.k.m.w.restart()
	for panel: Structure in watched:
		panel.restored.disconnect(note)
	_q.kit.need(problems, seen.size() == 2 and seen[0]["alive"] == [false, false] and seen[1]["alive"] == [false, false] and seen[0]["home"] and seen[1]["home"], "when the panels the Units stood in were restored: %s" % [seen])
	var whole: int = 0
	var closed: int = 0
	for base_index: int in Kit.PLAYERS:
		for run: int in Kit19.GARAGE_RUNS:
			for index: int in Kit19.COUNTS[run]:
				var panel: Structure = _k.panel(base_index, run, index)
				whole += 1 if _whole(panel) else 0
				closed += 1 if _k.ray(base_index, run, index) else 0
	for run: int in Kit19.FIELD_RUNS:
		for index: int in Kit19.COUNTS[run]:
			var panel: Structure = _k.panel(0, run, index)
			whole += 1 if _whole(panel) else 0
			closed += 1 if _k.ray(0, run, index) else 0
	_q.kit.need(problems, whole == 28 and closed == 28, "after R %d of 28 panels are whole and %d of 28 block a ray through their middle" % [whole, closed])
	_q.kit.need(problems, _k.k.m.standing().is_empty() and int(mine["gone_tick"]) >= 0 and _q.harness.get_tree().get_nodes_in_group(&"mines").is_empty(), "the Mine in the field breach is still there after R (gone at tick %d)" % int(mine["gone_tick"]))
	measured.append("restore_whole=%d" % whole)
	_q.kit.verdict("restore", problems, "with %d panels fallen, %d at the first damaged look and %d at the second (Base A's Garage all fallen), a live Mine in the west field breach, the Carrier standing in a Garage side-wall breach (it won the Round there) and Player 2 in an east field breach, R brought back all %d panels whole (40 hit points, layer 64, the whole look alone) and %d of 28 block a ray through their middle again; each of the two panels the Units stood in was restored with both Units already benched and both Flags seated; the Mine is gone" % [fallen, first, second, whole, closed])


## True for a panel that stands whole: 40 hit points, layer 64, mask 0 and the whole look alone.
func _whole(panel: Structure) -> bool:
	return panel.is_standing and is_equal_approx(panel.hit_points, Kit19.HIT_POINTS) and panel.collision_layer == COVER_LAYER and panel.collision_mask == 0 and _k.k.look_shown(panel) == 0
