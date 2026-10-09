extends RefCounted
## What stays of a Mine when its Truck goes (Story 014 AC-7): a Mine stays where it lies, in its owner's colour and still
## live, when its Truck is destroyed and when it is swapped away at the own Base, and the new Truck lays on beside it;
## nothing caps how many Mines lie on the Map (three full loads of five lay on and stay). R's removal of every Mine is
## mines_rounds.gd's. Real keys. Tooling only. Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-7.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")

## Open flat ground on Map 01 (the lay module's), and three lanes of it for the loads, five Mines each, 3 m apart.
const SPOT: Vector3 = Vector3(-30.0, 0.0, -2.0)
const LANE_X: float = -46.0
const LANE_STEP: float = 3.0
const LANES_Z: Array[float] = [-17.0, -14.0, -11.0]
const LOADS: int = 3

var measured: PackedStringArray = []
var _k: Kit14
var _q: Object


func _init(kit: Kit14) -> void:
	_k = kit
	_q = kit.w.s.q


func run() -> void:
	await _stay_when_destroyed()
	await _stay_when_swapped()
	await _no_cap()


## A Truck laid a Mine and is destroyed outside its Base: the Mine stays live, in the owner's colour; the next Truck lays beside it.
func _stay_when_destroyed() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, SPOT + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	await _q.kit.advance(Kit14.LIVE_WAIT)
	await _q.tokens.destruct(0)
	_q.kit.need(problems, not _q.controller.is_alive(0) and _k.line(0) == "hidden", "the Truck was not destroyed (alive %s, line '%s')" % [_q.controller.is_alive(0), _k.line(0)])
	_q.kit.need(problems, is_instance_valid(mine) and mine.is_inside_tree() and mine.state == Mine.State.LIVE and mine.player_index == 0, "the Mine after its Truck was destroyed: state %d, owner %d" % [mine.state, mine.player_index])
	_q.kit.need(problems, mine.body.material_override == _q.units.units[0].team_material and mine.body.visible, "the Mine lost its owner's colour or went dark")
	await _q.tokens.spawn(0, Quick.TRUCK)
	_q.kit.need(problems, mine.state == Mine.State.LIVE and _k.layers[0].mines_left == 5, "after the respawn the Mine is %d and the new Truck's load %d" % [mine.state, _k.layers[0].mines_left])
	_q.kit.verdict("mine_stays_when_its_truck_is_destroyed", problems, "a live Mine stayed live, in Player 1's colour, after its Truck was destroyed outside the Base (a Self-destruct) and after the next Truck came in with a full load of 5")


## A Mine laid a moment ago (still arming) stays when its Truck is swapped away at the own Base.
func _stay_when_swapped() -> void:
	var problems: PackedStringArray = []
	await _k.revive(0)
	await _k.put(0, Quick.TRUCK, SPOT + Vector3(3.4, 0.0, 14.0), Vector3.RIGHT)
	var record: Dictionary = await _k.lay(0)
	var mine: Mine = record["mine"] as Mine
	_k.w.s.flags.teleport(0, _k.w.s.inside_point(0), _k.w.s.into_base(0))
	await _k.w.s.wait_swappable(0)
	var tokens: Array = _q.tokens.counts()
	var left_at_swap: int = _k.layers[0].mines_left
	await _q.tokens.destruct(0)
	_q.kit.need(problems, _q.controller.is_choosing(0) and _q.tokens.counts() == tokens, "the Swap did not put the Truck away for free (choosing %s)" % _q.controller.is_choosing(0))
	_q.kit.need(problems, mine.state == Mine.State.ARMING and mine.player_index == 0 and mine.is_inside_tree(), "the Mine after the Swap: state %d, owner %d" % [mine.state, mine.player_index])
	await _q.kit.advance(Kit14.LIVE_WAIT)
	_q.kit.need(problems, mine.state == Mine.State.LIVE, "the Mine did not go live after the Swap (state %d)" % mine.state)
	await _q.tokens.spawn(0, Quick.TRUCK)
	_q.kit.need(problems, left_at_swap == 4 and _k.layers[0].mines_left == 5 and _k.layers[0].capacity == 5 and _k.line(0) == "Mines 5 / 5", "the Truck swapped away had %d left; the Truck chosen after it has %d / %d, the line '%s'" % [left_at_swap, _k.layers[0].mines_left, _k.layers[0].capacity, _k.line(0)])
	_q.kit.verdict("mine_stays_when_its_truck_is_swapped", problems, "a Mine laid by a Truck that was then put away by a Swap at the own Base (no Token) stayed, kept arming and went live on schedule; the Truck chosen after the Swap came with 5 (Mines 5 / 5), the one swapped away having had 4 left")


## Three full loads lay: fifteen more Mines, none refused for the number on the Map.
func _no_cap() -> void:
	var problems: PackedStringArray = []
	var standing: int = _q.harness.get_tree().get_nodes_in_group(&"mines").size()
	var laid: int = 0
	var refusals: int = _k.refused[0].size()
	for load_index: int in LOADS:
		await _k.revive(0)
		await _k.put(0, Quick.TRUCK, Vector3(LANE_X, 0.0, LANES_Z[load_index]) + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
		for index: int in 5:
			_k.w.s.flags.teleport(0, Vector3(LANE_X + LANE_STEP * index, 0.0, LANES_Z[load_index]) + Vector3(3.4, 0.0, 0.0), Vector3.RIGHT)
			await _q.kit.advance(Kit14.SETTLE)
			var before: int = _k.laid.size()
			await _k.lay(0)
			laid += _k.laid.size() - before
	var after: int = _q.harness.get_tree().get_nodes_in_group(&"mines").size()
	_q.kit.need(problems, laid == LOADS * 5 and after == standing + laid, "%d Mines laid, %d in the group (%d before)" % [laid, after, standing])
	_q.kit.need(problems, _k.refused[0].size() == refusals, "%d presses were refused" % (_k.refused[0].size() - refusals))
	measured.append("mines_on_map=%d" % after)
	_q.kit.verdict("no_cap_on_the_mines", problems, "three loads of five laid fifteen more Mines in a row, %d on the Map in all, none refused for their number" % after)
