extends RefCounted
## What a Mine's kill does to the Round (Story 014 AC-6 and AC-7), in real Rounds on the shipped Map 01:
## carrier: Player 2's Motorbike takes Base A's Flag with its Turrets and a Flag Wall down, reverses out over
## a live Mine and is destroyed there, a Token taken, the Flag dropped at the wreck on the ground in sight and
## taken again by the next Motorbike, which brings it home. loss, with one Motorbike a Player: a Mine's kill of the
## last ends the Round in that physics tick with "Player 1 wins!", with a spent, a live and an arming Mine on the
## Map; the restart (R) removes every Mine, and the first Truck of the new Round has its full load. The double losses
## are mines_doubles.gd's. Real keys; a Mine placed by the tool where a Truck could not put it. Tooling only.
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-6 and AC-7.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Round14: GDScript = preload("res://tools/evidence/split_screen/mines_round_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## Where the flat of the Map is open for a Mine and a run: a Mine here, a run-up of 20 m to the west.
const KILL_SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
## Where a Truck stands in front of its own Gate so that a press is refused (the drop point lies in the approach).
const GATE_TRUCK: Vector3 = Vector3(-98.0, 0.0, 0.0)
## Where the Carrier's Mine lies, in front of Base A's Gate, just outside its no-mine approach.
const GATE_MINE: Vector3 = Vector3(-90.0, 0.0, 0.0)
const WRECK_TOLERANCE: float = 0.5
const FLAG_HEIGHT_MAX: float = 0.6

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object
var _r: Round14


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q
	_r = Round14.new(kit)


func run() -> void:
	await _carrier()
	await _loss_and_restart()


## carrier (AC-6): see the class doc.
func _carrier() -> void:
	var problems: PackedStringArray = []
	var flags: Object = _k.w.s.flags
	var flag: Flag = flags.flags[0]
	await _k.w.restore_all()
	_k.w.wall(0, Walls.GATE).destroy()
	for turret: Turret in [_k.w.bases[0].get_node("Turrets/TurretLeft") as Turret, _k.w.bases[0].get_node("Turrets/TurretRight") as Turret]:
		turret.destroy()
	await _q.kit.advance(Kit14.SETTLE)
	var record: Dictionary = await _k.live_mine(GATE_MINE, 0, Quick.LANE_SPOT)
	var mine: Mine = record["mine"] as Mine
	_q.kit.need(problems, mine.state == Mine.State.LIVE and _k.place_of(record).distance_to(GATE_MINE) < 0.01, "the Mine at the Gate is state %d at %s" % [mine.state, _k.place_of(record)])
	await _k.revive(1)
	_q.kit.need(problems, await _k.w.take_flag(1, 0, Walls.GATE), "Player 2's Motorbike did not take Base A's Flag")
	var mark: int = _q.tokens.events.size()
	var before: Array = _q.tokens.counts()
	var drops: int = flags.drops.size()
	await flags.drive_until(1, -1, Swap.CRUISE, func() -> bool: return not _q.units.units[1].is_alive)
	await _q.tokens.wait_for(&"destroyed", mark)
	var found: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	var wanted: Array = Tokens.charged(before, 1, Quick.MOTORBIKE)
	_q.kit.need(problems, found.size() == 1 and found[0]["arg"] == 1 and found[0]["type"] == &"motorbike", "the destruction of the Carrier: %d events" % found.size())
	_q.kit.need(problems, _q.tokens.counts() == wanted, "the Tokens after the Mine's kill were %s, not %s" % [_q.tokens.counts(), wanted])
	var wreck: Vector3 = flags.wrecks[-1] if not flags.wrecks.is_empty() else Vector3.INF
	var apart: float = Vector2(flag.global_position.x - wreck.x, flag.global_position.z - wreck.z).length()
	_q.kit.need(problems, mine.state == Mine.State.SPENT and absf(wreck.x - GATE_MINE.x) < 2.0, "the Mine's state %d, the wreck at %s" % [mine.state, wreck])
	_q.kit.need(problems, flags.drops.size() == drops + 1 and flag.state == Flag.State.DROPPED and apart <= WRECK_TOLERANCE and flag.global_position.y <= FLAG_HEIGHT_MAX and flag.is_visible_in_tree() and not _q.controller.is_round_over(), "the Flag after the kill: %d drops, %s, %.2f m from the wreck, %.2f m high, visible %s, Round over %s" % [flags.drops.size() - drops, flags.state_name(0), apart, flag.global_position.y, flag.is_visible_in_tree(), _q.controller.is_round_over()])
	await _k.revive(1)
	flags.teleport(1, flag.global_position + Vector3(-4.0, 0.0, 0.0), Vector3.RIGHT)
	var taken: bool = await flags.drive_until(1, 1, Swap.CRUISE, func() -> bool: return _k.w.carrying(1)) > 0
	_q.kit.need(problems, taken and flag.state == Flag.State.CARRIED, "the next Motorbike did not take the dropped Flag (%s)" % flags.state_name(0))
	var won: bool = taken and await _k.w.deliver(1)
	_q.kit.need(problems, won and _q.controller.winner_index() == 1, "Player 2 did not win by delivering the Flag taken from the wreck (won %s, winner %d)" % [won, _q.controller.winner_index()])
	measured.append("carrier=%d>%d" % [before[1][Quick.MOTORBIKE], wanted[1][Quick.MOTORBIKE]])
	_q.kit.verdict("carrier_on_a_mine", problems, "Player 2's Carrier, reversing out of Base A over a live Mine at the Gate's approach, was destroyed on it: Motorbike Tokens %d -> %d, the Flag dropped %.2f m from the wreck on the ground, in sight, the Round ran on, the next Motorbike took the Flag from the wreck and brought it home to win" % [before[1][Quick.MOTORBIKE], wanted[1][Quick.MOTORBIKE], apart])


## loss, then the restart: see the class doc.
func _loss_and_restart() -> void:
	var problems: PackedStringArray = []
	await _r.restart_with(Round14.LAST_MOTORBIKE)
	_q.kit.need(problems, _q.tokens.counts()[0][Quick.MOTORBIKE] == Round14.LAST_MOTORBIKE and _q.tokens.counts()[1][Quick.MOTORBIKE] == Round14.LAST_MOTORBIKE, "each Player has %s Motorbikes" % [_q.tokens.counts()])
	var parking: Vector3 = Quick.LANE_SPOT
	var killer: Dictionary = await _k.live_mine(KILL_SPOT, 0, parking)
	var far: Dictionary = await _k.live_mine(KILL_SPOT + Vector3(0.0, 0.0, 14.0), 0, parking)
	await _k.put(0, Quick.TRUCK, KILL_SPOT + Vector3(8.0 + 3.4, 0.0, 6.0), Vector3.RIGHT)
	var fresh: Dictionary = await _k.lay(0)
	var mark: int = _q.tokens.events.size()
	await _k.put(0, Quick.TRUCK, GATE_TRUCK, Vector3.LEFT)
	await _k.lay(0)
	_q.kit.need(problems, _k.note(0) == "No Mines in or near a Base", "the refusal that is to be showing when the Round ends reads '%s'" % _k.note(0))
	var seen: Dictionary = await _run_toward(1, KILL_SPOT, 4.0)
	await _r.wait_over()
	await _q.kit.advance(2)
	var states: Dictionary = {}
	for record: Dictionary in [killer, far, fresh]:
		var mine: Mine = record["mine"] as Mine
		states[mine.state] = int(states.get(mine.state, 0)) + 1
	var killed: Array[Dictionary] = _q.tokens.events_of(&"destroyed", mark)
	var overs: Array[Dictionary] = _q.tokens.events_of(&"over", mark)
	_q.kit.need(problems, killed.size() == 1 and overs.size() == 1 and killed[0]["now"]["frame"] == overs[0]["now"]["frame"] and _q.controller.winner_index() == 0, "the Mine's kill of the last Motorbike: %d destructions, %d Round ends, frames %s and %s, winner %d" % [killed.size(), overs.size(), killed[0]["now"]["frame"] if not killed.is_empty() else -1, overs[0]["now"]["frame"] if not overs.is_empty() else -1, _q.controller.winner_index()])
	_q.kit.need(problems, _r.screens() == PackedStringArray([Round14.WIN_TEXT % 1, Round14.WIN_TEXT % 1]), "the Round-over screens read %s" % [_r.screens()])
	_q.kit.need(problems, _k.note(0) == "hidden" and _k.note(1) == "hidden", "the notices at the Round's end read '%s' and '%s'" % [_k.note(0), _k.note(1)])
	_q.kit.need(problems, states == {Mine.State.SPENT: 1, Mine.State.LIVE: 1, Mine.State.ARMING: 1}, "the Mines at the Round's end by state: %s" % [states])
	measured.append("loss_frame=%d" % int(killed[0]["now"]["frame"]) if not killed.is_empty() else "loss_frame=-1")
	_q.kit.verdict("last_motorbike_on_a_mine_ends_the_round", problems, "a Mine's kill of Player 2's last Motorbike ended the Round in that physics frame (%d) with '%s' in both views, with a spent, a live and an arming Mine on the Map" % [int(killed[0]["now"]["frame"]) if not killed.is_empty() else -1, Round14.WIN_TEXT % 1])
	problems = []
	var before: int = _q.harness.get_tree().get_nodes_in_group(&"mines").size()
	var presses: int = _k.laid.size()
	await _q.kit.press_settled([Kit14.LAY_KEYS[0]] as Array[Key])
	_q.kit.need(problems, _q.controller.is_round_over() and _k.laid.size() == presses, "a press of E while the Round was over (%s) laid %d Mines" % [_q.controller.is_round_over(), _k.laid.size() - presses])
	await _q.tokens.restart()
	var after: int = _q.harness.get_tree().get_nodes_in_group(&"mines").size()
	_q.kit.need(problems, before == 3 and after == 0, "the Mines in the Map's group went %d -> %d at the restart" % [before, after])
	_q.kit.need(problems, _k.laid.filter(func(r: Dictionary) -> bool: return int(r["gone_tick"]) >= 0).size() >= 3, "fewer than three Mines left the tree")
	_q.kit.need(problems, _k.layers[0].mines_left == 0 and _k.layers[0].capacity == 0 and _k.line(0) == "hidden", "after R Player 1's load reads %d / %d, line '%s'" % [_k.layers[0].mines_left, _k.layers[0].capacity, _k.line(0)])
	var ok: bool = await _q.tokens.spawn(0, Quick.TRUCK)
	_q.kit.need(problems, ok and _k.layers[0].mines_left == 5 and _k.line(0) == "Mines 5 / 5", "the first Truck of the new Round reads %d, '%s'" % [_k.layers[0].mines_left, _k.line(0)])
	_q.kit.verdict("restart_removes_every_mine", problems, "a press of E while the Round was over laid nothing; R removed the spent, the live and the arming Mine (3 in the group -> 0, each left the tree) and the Mines line went; the first Truck of the new Round, chosen as Player 1's first Unit, came with 5 (Mines 5 / 5)")


## Player `player`'s Motorbike is put `run_up` m west of a place and driven east over it until it is destroyed or the Round is over.
func _run_toward(player: int, centre: Vector3, run_up: float = 20.0) -> Dictionary:
	await _k.revive(player)
	await _k.put(player, Quick.MOTORBIKE, centre + Vector3(-run_up, 0.0, 0.0), Vector3.RIGHT)
	_q.harness.drive(player, 1, 0)
	for _tick: int in 200:
		await _q.kit.tick()
		if not _q.units.units[player].is_alive or _q.controller.is_round_over():
			break
	_q.harness.drive(player, 0, 0)
	return {}


## Where the control and the Shot double stand: a Motorbike here, the other 4.2 m east of the first.
const SHOT_SPOT: Vector3 = Vector3(-30.0, 0.0, 12.0)
const SHOT_GAP: float = 4.2
## The Turret's range from its rest heading at which the victim stands.
const AHEAD: float = 15.0
