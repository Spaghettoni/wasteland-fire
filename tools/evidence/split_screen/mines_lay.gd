extends RefCounted
## The lay and the count of the Story 014 scenario mines: AC-1 (one press of the lay key lays one Mine
## just behind the Truck's tail, clear of it whether it stands or turns on the spot; a held key lays
## one; a stranded Truck lays; the other types lay none and show nothing; the key does nothing while
## the Player chooses or waits) and AC-2 (a new Truck has five, at the first spawn, at a respawn
## and after a Swap; each lay takes one; with none left a press lays nothing and the notice says so;
## the Mines line shows in that Player's view only, while a Truck is in play). Real keys through the
## Input Map. Tooling only. Implements: production/epics/wasteland-fire/story-014-truck-mines.md.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## Open ground on Map 01, clear of everything for 20 m round it (the probe's map): the Truck stands here
## facing east, so its drop point lies 3.4 m west of it.
const SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
## Ticks a Mine arms (3 s at 60 ticks a second) and a few more.
const LIVE_WAIT: int = 190
## A full turn on the spot at the Truck's 0.45 rad/s is 840 ticks; the check holds the key longer.
const TURN_TICKS: int = 900
## The Mine's drop point behind the Truck's origin and the trigger's radius, as the data say.
const DROP: float = 3.4
const RADIUS: float = 0.8

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit14
var _q: Object


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	await _swap_to_truck()
	await _lay()
	await _turns()
	await _held_key()
	await _stranded()
	await _others()
	await _out_of_play()
	await _count()
	await _player_two()


## P1 swaps its Motorbike at its own Base and chooses a Truck with real keys: a new Truck after a Swap.
func _swap_to_truck() -> void:
	var problems: PackedStringArray = []
	await _q.tokens.destruct(0)
	_q.kit.need(problems, _k.line(0) == "hidden", "the line shows while the Player chooses: %s" % _k.line(0))
	var mark: int = _k.changes[0].size()
	var ok: bool = await _q.tokens.spawn(0, Quick.TRUCK)
	_q.kit.need(problems, ok and _q.units.units[0].type_id == &"truck", "no Truck came into play")
	_q.kit.need(problems, _k.layers[0].mines_left == 5 and _k.layers[0].capacity == 5, "the load is %d / %d" % [_k.layers[0].mines_left, _k.layers[0].capacity])
	_q.kit.need(problems, _k.changes[0].size() == mark + 1 and _k.changes[0][mark].x == 5, "the count was reported %s since the swap" % [_k.changes[0].slice(mark)])
	_q.kit.need(problems, _k.line(0) == "Mines 5 / 5" and _k.line(1) == "hidden", "the lines read '%s' and '%s'" % [_k.line(0), _k.line(1)])
	_q.kit.verdict("swap_brings_a_load", problems, "a Truck chosen after a Swap at home comes with 5 Mines, shown as 'Mines 5 / 5' in its Player's view and not in the other's (the Motorbike's view shows none)")


## One press, one Mine, just behind the tail, on the ground, in the Player's colour.
func _lay() -> void:
	var problems: PackedStringArray = []
	_k.w.s.flags.teleport(0, SPOT, Vector3.RIGHT)
	await _q.kit.advance(Kit14.SETTLE)
	var truck: Unit = _q.units.units[0]
	var before: int = _k.laid.size()
	var record: Dictionary = await _k.lay(0)
	_q.kit.need(problems, not record.is_empty() and _k.laid.size() == before + 1, "one press laid %d Mines" % (_k.laid.size() - before))
	if record.is_empty():
		_q.kit.verdict("lays_behind_the_tail", problems, "no Mine")
		return
	var at: Vector3 = _k.place_of(record)
	var expected: Vector3 = truck.global_transform * Vector3(0.0, 0.0, DROP)
	_q.kit.need(problems, at.distance_to(expected) <= 0.01, "the Mine lies at %s, %.3f m from %s" % [at, at.distance_to(expected), expected])
	_q.kit.need(problems, is_zero_approx(at.y), "the Mine is %.3f m off the ground" % at.y)
	var mine: Mine = record["mine"] as Mine
	_q.kit.need(problems, mine.player_index == 0 and mine.body.material_override == truck.team_material, "the Mine is not Player 1's, in its Team material")
	var gap: float = _k.gap(truck, at, RADIUS)
	_q.kit.need(problems, absf(gap - (DROP - 2.2 - RADIUS)) <= 0.01, "the standing Truck's box is %.3f m from the trigger" % gap)
	_q.kit.need(problems, _k.layers[0].mines_left == 4 and _k.line(0) == "Mines 4 / 5", "the count reads %d and the line '%s'" % [_k.layers[0].mines_left, _k.line(0)])
	_q.kit.need(problems, int(_k.changes[0][-1].z) == int(record["tick"]), "the count was reported on tick %d, the Mine entered on %d" % [_k.changes[0][-1].z, record["tick"]])
	measured.append("drop_gap=%.3f" % gap)
	_q.kit.verdict("lays_behind_the_tail", problems, "one press of E laid one Mine at the Unit's transform times (0, 0, 3.4), on the ground, in Player 1's Team material, with the Truck's box %.3f m (the data say 0.4) clear of the trigger, and the count 5 -> 4 on the tick it entered" % gap)


## Clear of the Truck while it turns on the spot: the live Mine never sets off its own Truck.
func _turns() -> void:
	var problems: PackedStringArray = []
	var truck: Unit = _q.units.units[0]
	var mine: Mine = _k.last()["mine"] as Mine
	await _q.kit.advance(LIVE_WAIT)
	_q.kit.need(problems, mine.state == Mine.State.LIVE, "the Mine is not live after %d ticks" % LIVE_WAIT)
	var least: float = INF
	_q.harness.drive(0, 0, 1)
	for _tick: int in TURN_TICKS:
		await _q.kit.tick()
		least = minf(least, _k.gap(truck, mine.global_position, RADIUS))
	_q.harness.drive(0, 0, 0)
	_q.kit.need(problems, truck.is_alive and mine.state == Mine.State.LIVE, "the Truck turning on the spot set its own Mine off (alive=%s state=%d)" % [truck.is_alive, mine.state])
	_q.kit.need(problems, least > 0.0, "the least gap while turning is %.3f m" % least)
	measured.append("turn_gap=%.3f" % least)
	_q.kit.verdict("clear_while_turning", problems, "a Truck turning on the spot for %d ticks (a full turn and more) beside its own live Mine never touched it: least gap %.3f m (computed 0.094: the corner's 2.51 m against 3.4 m less the 0.8 m trigger), and it lived" % [TURN_TICKS, least])


## A key held down lays one Mine, however long.
func _held_key() -> void:
	var problems: PackedStringArray = []
	_k.w.s.flags.teleport(0, SPOT + Vector3(0.0, 0.0, 12.0), Vector3.RIGHT)
	await _q.kit.advance(Kit14.SETTLE)
	var before: int = _k.laid.size()
	_q.harness.set_key(Kit14.LAY_KEYS[0], true)
	await _q.kit.advance(120)
	_q.harness.set_key(Kit14.LAY_KEYS[0], false)
	await _q.kit.advance(2)
	_q.kit.need(problems, _k.laid.size() == before + 1, "the key held for 120 ticks laid %d Mines" % (_k.laid.size() - before))
	_q.kit.need(problems, _k.layers[0].mines_left == 3, "the count is %d" % _k.layers[0].mines_left)
	_q.kit.verdict("held_key_lays_one", problems, "E held for 120 ticks laid one Mine, the count 4 -> 3 (a press is an edge, not a level)")


## A Truck with an empty tank lays like any other.
func _stranded() -> void:
	var problems: PackedStringArray = []
	await _k.put_stranded(0, SPOT + Vector3(0.0, 0.0, -14.0), Vector3.RIGHT)
	var truck: Unit = _q.units.units[0]
	_q.kit.need(problems, truck.is_stranded and truck.fuel <= 0.0, "the Truck is not stranded")
	var before: int = _k.laid.size()
	var record: Dictionary = await _k.lay(0)
	_q.kit.need(problems, _k.laid.size() == before + 1 and not record.is_empty(), "the stranded Truck laid %d Mines" % (_k.laid.size() - before))
	_q.kit.need(problems, _k.layers[0].mines_left == 4 and _k.layers[0].capacity == 5, "the new Truck's load reads %d / %d (a new Truck, 5, less this lay)" % [_k.layers[0].mines_left, _k.layers[0].capacity])
	_q.kit.verdict("stranded_truck_lays", problems, "a Truck with an empty tank (is_stranded) laid one Mine, the count of a new Truck 5 -> 4")


## The Motorbike, the Buggy and the Gyrocopter lay none, and nothing shows.
func _others() -> void:
	var problems: PackedStringArray = []
	var before: int = _k.laid.size()
	var refused: int = _k.refused[0].size()
	for type_index: int in [Quick.MOTORBIKE, Quick.BUGGY, Quick.GYROCOPTER]:
		await _k.put(0, type_index, SPOT + Vector3(0.0, 0.0, 14.0), Vector3.RIGHT)
		await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
		var name: String = String(_q.units.units[0].type_id)
		_q.kit.need(problems, _k.laid.size() == before, "%s laid a Mine" % name)
		_q.kit.need(problems, _k.refused[0].size() == refused, "%s's press was refused with a reason" % name)
		_q.kit.need(problems, _k.line(0) == "hidden" and _k.note(0) == "hidden", "%s shows '%s' and '%s'" % [name, _k.line(0), _k.note(0)])
		_q.kit.need(problems, _k.layers[0].mines_left == 0 and _k.layers[0].capacity == 0, "%s reports a load %d / %d" % [name, _k.layers[0].mines_left, _k.layers[0].capacity])
	_q.kit.verdict("other_types_lay_none", problems, "a Motorbike, a Buggy and a Gyrocopter pressing E laid nothing, were refused nothing, showed no Mines line and no notice and reported a load of 0 / 0")


## The key does nothing while the Player chooses, and while it waits to respawn after a destruction.
func _out_of_play() -> void:
	var problems: PackedStringArray = []
	await _k.put(0, Quick.TRUCK, SPOT, Vector3.RIGHT)
	var before: int = _k.laid.size()
	var tokens_before: int = _q.controller.tokens_left(0, Quick.TRUCK)
	var destroyed: int = _q.units.destroyed.size()
	await _q.tokens.destruct(0)
	_q.kit.need(problems, _q.controller.is_choosing(0) and not _q.controller.is_alive(0), "the Player is not choosing after its Truck was destroyed")
	_q.kit.need(problems, _q.units.destroyed.size() == destroyed + 1 and _k.changes[0][-1] == Vector3i(0, 0, _q.units.destroyed[-1].y), "the line went with %s, the destruction was on tick %s" % [_k.changes[0][-1], _q.units.destroyed[-1].y])
	_q.kit.need(problems, _q.controller.tokens_left(0, Quick.TRUCK) == tokens_before - 1, "the Self-destruct outside the Base took %d Truck Tokens" % (tokens_before - _q.controller.tokens_left(0, Quick.TRUCK)))
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	_q.kit.need(problems, _k.laid.size() == before and _k.note(0) == "hidden" and _k.line(0) == "hidden", "a press while choosing laid %d, showed '%s' and '%s'" % [_k.laid.size() - before, _k.note(0), _k.line(0)])
	await _q.tokens.choose(0, Quick.TRUCK)
	var wait: float = _q.controller.seconds_until_respawn(0)
	_q.kit.need(problems, wait > 0.0 and not _q.controller.is_alive(0), "the Player does not wait to respawn (%.2f s)" % wait)
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	_q.kit.need(problems, _k.laid.size() == before and _k.line(0) == "hidden" and _k.note(0) == "hidden", "a press while waiting laid %d, line '%s'" % [_k.laid.size() - before, _k.line(0)])
	await _q.units.wait_alive(0, 400)
	_q.kit.need(problems, _k.layers[0].mines_left == 5 and _k.line(0) == "Mines 5 / 5", "the respawned Truck reads %d, '%s'" % [_k.layers[0].mines_left, _k.line(0)])
	_q.kit.verdict("no_lay_out_of_play", problems, "E pressed while the Player chose a Unit after a destruction and while it waited %.1f s for the chosen one laid nothing and showed nothing; the Mines line went on the very tick the Truck was destroyed; the respawned Truck came with 5 (Mines 5 / 5)" % wait)


## Five lays, the sixth refused with "No Mines left", and the refills.
func _count() -> void:
	var problems: PackedStringArray = []
	_k.w.s.flags.teleport(0, SPOT + Vector3(-10.0, 0.0, 6.0), Vector3.RIGHT)
	await _q.kit.advance(Kit14.SETTLE)
	_q.kit.need(problems, _k.layers[0].mines_left == 5 and _k.line(0) == "Mines 5 / 5", "a Truck that spawned after waiting reads %d, '%s'" % [_k.layers[0].mines_left, _k.line(0)])
	var texts: PackedStringArray = []
	for index: int in 5:
		_k.w.s.flags.teleport(0, SPOT + Vector3(-10.0 + 6.0 * index, 0.0, 6.0), Vector3.RIGHT)
		await _q.kit.advance(Kit14.SETTLE)
		await _k.lay(0)
		texts.append(_k.line(0))
	_q.kit.need(problems, texts == PackedStringArray(["Mines 4 / 5", "Mines 3 / 5", "Mines 2 / 5", "Mines 1 / 5", "Mines 0 / 5"]), "the line read %s" % [texts])
	var before: int = _k.laid.size()
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	_q.kit.need(problems, _k.laid.size() == before and _k.layers[0].mines_left == 0, "the sixth press laid %d Mines" % (_k.laid.size() - before))
	_q.kit.need(problems, _k.refused[0][-1].x == MineLayer.Refusal.NONE_LEFT, "the refusal is %s" % [_k.refused[0][-1]])
	_q.kit.need(problems, _k.note(0) == "No Mines left" and _k.note(1) == "hidden", "the notice lines read '%s' and '%s'" % [_k.note(0), _k.note(1)])
	_q.kit.need(problems, _k.line(0) == "Mines 0 / 5", "the line reads '%s'" % _k.line(0))
	_q.kit.verdict("count_and_none_left", problems, "five lays read Mines 4 / 5 to 0 / 5, the sixth press laid nothing, kept the count, and said \"No Mines left\" on that Player's notice line only")


## Player 2's Truck lays with Comma, in Player 2's own view.
func _player_two() -> void:
	var problems: PackedStringArray = []
	await _q.tokens.destruct(1)
	await _q.tokens.spawn(1, Quick.TRUCK)
	_k.w.s.flags.teleport(1, SPOT + Vector3(30.0, 0.0, 20.0), Vector3.LEFT)
	await _q.kit.advance(Kit14.SETTLE)
	_q.kit.need(problems, _k.line(1) == "Mines 5 / 5" and _k.line(0) != "Mines 5 / 5", "the lines read '%s' and '%s'" % [_k.line(0), _k.line(1)])
	var record: Dictionary = await _k.lay(1)
	_q.kit.need(problems, not record.is_empty() and _k.owner_of(record) == 1, "Comma laid no Mine of Player 2's")
	if not record.is_empty():
		var truck: Unit = _q.units.units[1]
		var expected: Vector3 = truck.global_transform * Vector3(0.0, 0.0, DROP)
		_q.kit.need(problems, _k.place_of(record).distance_to(expected) <= 0.01, "the Mine lies %.3f m from the drop point" % _k.place_of(record).distance_to(expected))
		var mine: Mine = record["mine"] as Mine
		_q.kit.need(problems, mine.body.material_override == truck.team_material, "the Mine is not in Player 2's Team material")
	_q.kit.need(problems, _k.line(1) == "Mines 4 / 5", "Player 2's line reads '%s'" % _k.line(1))
	_q.kit.verdict("player_two_lays_with_comma", problems, "Player 2's Truck, chosen after a Swap, laid one Mine with Comma at its drop point in Teal's material, 'Mines 5 / 5' to 'Mines 4 / 5' in its own view")
