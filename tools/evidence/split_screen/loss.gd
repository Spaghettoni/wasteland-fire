extends RefCounted
## Scenario loss of the split screen evidence harness (split_screen_harness.gd): the loss of the
## last Motorbike ends the Round and nothing else but a delivery does (Story 008 AC-4, AC-5, and
## the restart of AC-7), on Map 01 with its real Token stock and the data's respawn delay, played
## with real key events (Tab and Enter Self-destruct, Space and Period choose and shoot, R
## restarts) except two steps for which the pause of a finished Round leaves no key: choose() after
## the loss (T18) and Unit.destroy() on the survivor (T21) are called from here. Nine Rounds, seven
## CHECK lines, every number measured, the counts read from the stock resource. Helpers:
## loss_kit.gd, token_kit.gd, flag_kit.gd, check_kit.gd.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-4, AC-5, AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=loss
##
## The tree-order contract (T20). The loss is decided in the MatchController's tick, so every way of
## destroying a Unit must tick before it in the same physics frame: a Self-destruct
## (PlayerMatchInput, priority -1) and a Shot kill (the Shot is a child of World with priority 0,
## and World comes before the MatchController in the scene). The mixed Round puts both in one frame
## and asserts those priorities and positions, the signal order (destroyed:0 by the Self-destruct,
## destroyed:1 by the Shot, then round_over) and round_over(-1): a source moved behind the
## controller splits the double loss over two frames and fails T20.
##
## Kills: the wrong implementation each check fails. At every Round start, in every check: a restart
## that refills no stock or keeps the last winner, a Unit that waits out the respawn delay.
##  T18  the loss at one Motorbike Token left, one tick late or at the Player's next spawn; the
##       winner named by Player index; round_over twice or before the pause; the tree not paused;
##       a Token charged to the other Player; a choice accepted, or only stored, once the Round
##       is over.
##  T19  a loss only Player 1 can suffer; a loss only a Self-destruct causes; a Shot-kill loss
##       decided a tick late.
##  T20  a double loss won by the lower index or by Player 1, never announced or announced twice;
##       a Shot or a Self-destruct ticking behind the controller; the loss decided in the handler.
##  T21  the loss decided a tick late; a window merging close-but-different ticks into a double
##       loss; a pause that does not stop the other Player's key; a destruction after the end that
##       is not counted, not announced, or that changes the result.
##  T22  A, with Motorbike Tokens left: a Carrier's destruction that costs two Tokens or none, ends
##       the Round or sends the Flag home. B, the last Motorbike: the Flag still carried by the
##       wreck, sent home, or dropped after the signals; Flags not seated again by the restart.
##  T23  the loss when any type reaches 0, or when every combat type does.
##  T24  a delivery that no longer ends the Round or costs a Token; an empty ground tank that
##       destroys its Unit or loses the Round; an engine ERROR or WARNING anywhere in the run.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the settle time.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 008 helpers (token_kit.gd): keys, Shots, the lethal lead.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## This scenario's helpers (loss_kit.gd): Rounds, judging, Flag runs.
const Loss: GDScript = preload("res://tools/evidence/split_screen/loss_kit.gd")

## The runner keeps the Map's own Token stock (data/token_stock.tres) for this scenario.
const USE_MAP_STOCK: bool = true
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## Simulated seconds before the watchdog; the run takes about 170 of them.
const WATCHDOG_SECONDS: float = 600.0
## The checks as printed, by the short id the code uses, in the design's order.
const NAMES: Dictionary[StringName, String] = {&"T18": "T18_real_stock_to_zero", &"T19": "T19_p2_loses_and_by_fire",
	&"T20": "T20_double_loss", &"T21": "T21_adjacent_ticks", &"T22": "T22_loss_carrying_flag",
	&"T23": "T23_type_exhaustion_ends_nothing", &"T24": "T24_other_ends_unchanged"}
## Seconds an empty tank is watched with the throttle still held (T24).
const DRY_SECONDS: float = 10.0
## Ticks a tank may take to run dry before T24 gives up; the Motorbike's takes 1501 here.
const DRY_LIMIT_TICKS: int = 2400
## Where T24 pins a Unit against the back wall of its own Base, in the Base's frame (local +Z leads
## to the back wall), facing the wall.
const PIN_SPOT: Vector3 = Vector3(0.0, 0.0, 11.0)
## A dropped or seated Flag stands within this of its place, metres.
const PLACE_TOLERANCE: float = 0.05

var _h: Harness
var _kit: Kit
var _lk: Loss
var _tk: Tokens
var _shot: Array = []
var _from: int = 0


## Runs the seven phases in the design's order, each starting its own Round (T24 goes on in the
## Round T23 left); the runner awaits it.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_lk = Loss.new(harness, _kit, NAMES.keys())
	_tk = _lk.tk
	await _kit.advance(Kit.START_TICKS)
	var phases: Array[Callable] = [_t18, _t19, _t20, _t21, _t22, _t23, _t24]
	for phase: Callable in phases:
		await phase.call()
	_lk.report(NAMES)
	_h.finish("destroyed=%d spawned=%d shots=%d round_over=%d round_started=%d errors=%d warnings=%d" % [
		_tk.events_of(&"destroyed").size(), _tk.events_of(&"spawned").size(), _tk.shot_frames.size(),
		_tk.events_of(&"over").size(), _tk.events_of(&"started").size(), _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])


## T18: Player 1 Self-destructs Motorbikes with Tab; the Round runs through all but the last (the
## stock's count less one each time) and the last ends it in its own frame, Player 2 the winner.
## Once it is over, Player 1, who is choosing, is offered each type it has Tokens of: none is taken.
func _t18() -> void:
	_lk.note(&"T18", "stock %s read from %s" % [_lk.start[0], _h.split.field.token_stock.resource_path.get_file()])
	if await _lk.to_last(&"T18", [0]):
		await _lk.finish_with(&"T18", "Tab on the last Motorbike", 1, [0], _tk.destruct.bind(0))
		_lk.refuses_choices(&"T18", "after the loss")
	_lk.closed.append(&"T18")


## T19: Player 2 loses its last Motorbike to Enter (Player 1 wins), then, in a second Round, to one
## Shot of Player 1's on the Shot's lethal frame with no key of Player 2's (Player 1 wins).
func _t19() -> void:
	if await _lk.to_last(&"T19", [1]):
		await _lk.finish_with(&"T19", "A: Enter on Player 2's last Motorbike", 0, [1], _tk.destruct.bind(1))
	if not await _lk.to_last(&"T19", [1]):
		return
	await _tk.stage_duel(1)
	var shots: int = _tk.shot_frames.size()
	var added: int = await _lk.finish_with(&"T19", "B: Player 1's Shot on the last Motorbike (1 hit point)", 0, [1], _tk.shoot.bind(0))
	var hits: Array[Dictionary] = _tk.events_of(&"destroyed", _lk.last["mark"])
	var landed: int = hits[0]["now"]["frame"] - added if hits.size() == 1 else -1
	_lk.need(&"T19", _tk.shot_frames.size() == shots + 1 and landed == Tokens.LETHAL_LEAD + 1, "B: %d Shots, destruction %d frames after the Shot node" % [_tk.shot_frames.size() - shots, landed])
	_lk.note(&"T19", "B: one Shot, the destruction %d frames after its node was added, no Enter pressed" % landed)
	_lk.closed.append(&"T19")


## T20: both Players on their last Motorbike. Tab and Enter down on one tick, then in the other key
## order: one round_over(-1) each time. Then Tab and Player 1's lethal Shot on one frame (header).
func _t20() -> void:
	for swapped: bool in [false, true]:
		var players: Array[int] = [0, 1]
		if swapped:
			players.reverse()
		var keys: Array = players.map(func(player: int) -> String: return OS.get_keycode_string(Tokens.keys(&"destruct", player)[0]))
		if await _lk.to_last(&"T20", [0, 1]):
			await _lk.finish_with(&"T20", "%s down on one tick" % " then ".join(keys), -1, [0, 1], _lk.destruct_together.bind(players))
	if await _lk.to_last(&"T20", [0, 1]):
		await _tk.stage_duel(1)
		var added: int = await _lk.finish_with(&"T20", "mixed: Tab and Player 1's lethal Shot", -1, [0, 1], _shoot_and_press.bind(0, 0))
		_check_contract(added)
	_lk.closed.append(&"T20")


## Fires one Shot and presses the presser's Self-destruct to act on its lethal frame (token_kit.gd,
## LETHAL_LEAD); notes the Shot's priority and parent in flight. Returns the frame it was added in.
func _shoot_and_press(shooter: int, presser: int) -> int:
	var added: int = await _tk.shoot(shooter)
	var flying: Array[Node] = _h.get_tree().get_nodes_in_group(&"shots")
	_shot = [flying[0].process_physics_priority, flying[0].get_parent()] if flying.size() == 1 else []
	await _tk.press_on(added + Tokens.LETHAL_LEAD, Tokens.keys(&"destruct", presser))
	return added


## The contract of the header, read from the live scene: the PlayerMatchInputs run before the
## MatchController; the Shot has its priority under World, which comes first; both fell together.
func _check_contract(added: int) -> void:
	var world: Node = _h.split.get_node("World")
	var priority: int = _tk.controller.process_physics_priority
	var inputs: Array = world.find_children("*", "PlayerMatchInput", true, false).map(func(node: Node) -> int: return node.process_physics_priority)
	var landed: Array = _tk.events_of(&"destroyed", _lk.last["mark"]).map(func(event: Dictionary) -> int: return event["now"]["frame"] - added)
	var shot: String = "none" if _shot.size() != 2 else "%d under %s" % [_shot[0], _shot[1].name]
	var facts: Array = [
		[inputs.size() == 2 and inputs.max() < priority, "PlayerMatchInput priorities %s, MatchController %d" % [inputs, priority]],
		[_shot.size() == 2 and _shot[0] == priority and _shot[1] == world, "Shot %s, MatchController %d" % [shot, priority]],
		[world.get_index() < _tk.controller.get_index(), "World at %d, MatchController at %d" % [world.get_index(), _tk.controller.get_index()]],
		[landed == [Tokens.LETHAL_LEAD + 1, Tokens.LETHAL_LEAD + 1], "destructions %s frames after the Shot node" % [landed]]]
	for fact: Array in facts:
		_lk.need(&"T20", fact[0], "contract: %s" % fact[1])
	_lk.note(&"T20", "contract: PlayerMatchInput priority %s < MatchController %d = Shot %s; World is child %d of the scene, the MatchController child %d; destructions %s frames after the Shot node" % [inputs, priority, shot, world.get_index(), _tk.controller.get_index(), landed])


## T21: both Players on their last Motorbike; Tab down for a tick and Enter down for the next: the
## Round ends on Tab's frame, Player 1 the loser, and Enter, a tick later, destroys nothing. Then
## Player 2's Unit is destroyed from here, the Round being over (_destroyed_while_over()).
func _t21() -> void:
	if not await _lk.to_last(&"T21", [0, 1]):
		return
	var place: Vector3 = _lk.fk.units[1].global_position
	var ticks: Array[int] = []
	var presses: Callable = func() -> void:
		for player: int in Kit.PLAYERS:
			ticks.append(await _kit.press(Tokens.keys(&"destruct", player)))
	await _lk.finish_with(&"T21", "Tab at tick N, Enter at N+1", 1, [0], presses)
	var moved: float = _lk.fk.units[1].global_position.distance_to(place)
	var left: int = _tk.controller.tokens_left(1, _lk.carrier)
	_lk.need(&"T21", ticks[1] - ticks[0] == 1 and left == 1 and moved == 0.0 and _tk.controller.is_alive(1), "keys down at ticks %s; Player 2: %d Motorbike Tokens, moved %.3f m, alive %s" % [ticks, left, moved, _tk.controller.is_alive(1)])
	_lk.note(&"T21", "Tab down at tick N, Enter at N+%d; Player 2 keeps %d Motorbike Token, alive, moved %.3f m" % [ticks[1] - ticks[0], left, moved])
	await _destroyed_while_over()
	_lk.closed.append(&"T21")


## T21, once the Round is over: Player 2's Unit is destroyed from here, the one way left now that
## the pause keeps every key and every tick from it. The Round still counts and announces it (the
## MatchController's class doc): one more unit_destroyed and Player 2's last Motorbike Token gone,
## and the result as it was: Player 2 the winner, ONE round_over, the Round over, the tree paused.
func _destroyed_while_over() -> void:
	var mark: int = _tk.events.size()
	var before: Array = _tk.counts()
	_lk.fk.units[1].destroy()
	await _tk.wait_for(&"destroyed", mark)
	var hits: Array = _tk.events_of(&"destroyed", mark).map(func(hit: Dictionary) -> int: return hit["arg"])
	var after: Dictionary = _tk.state()
	var overs: int = _tk.events_of(&"over", _lk.last["mark"]).size()
	var facts: String = "unit_destroyed for Players %s, Tokens %s -> %s, round_over x%d, winner_index %d, over=%s paused=%s" % [
		hits.map(func(player: int) -> int: return player + 1), before, after["counts"], overs, after["winner"], after["over"], after["paused"]]
	var held: bool = hits == [1] and after["counts"] == Tokens.charged(before, 1, _lk.carrier) and overs == 1 and after["over"] and after["paused"] and after["winner"] == 1
	_lk.need(&"T21", held, "destroyed from here after the end: " + facts)
	_lk.note(&"T21", "then Player 2's Unit destroyed from here: " + facts)


## T22: Player 1's first Motorbike, every Motorbike Token still in hand, takes Player 2's Flag and
## Self-destructs on Base 2's gate axis (A); its last Motorbike does the same (B): the Flag drops
## at the wreck before the signals both times; B ends the Round and R seats both Flags again.
func _t22() -> void:
	if not await _lk.to_last(&"T22", [0], _carrier_first):
		return
	var flag: Flag = _lk.fk.flags[1]
	var carried: bool = await Loss.carry_to_gate(_lk.fk, 0, 1, 1)
	_lk.need(&"T22", carried and flag.carrier == _lk.fk.units[0], "B: the last Motorbike does not carry Player 2's Flag")
	await _lk.finish_with(&"T22", "B: Tab on the Carrier's last Motorbike", 1, [0], _tk.destruct.bind(0), PackedStringArray(["flag_dropped:1"]))
	var dropped: String = _dropped_at_wreck("B")
	var started: bool = await _tk.restart()
	await _kit.advance(Kit.TICK_SLACK)
	var homes: Array = Kit.PLAYERS.map(func(player: int) -> bool: return _at_home(player))
	_lk.need(&"T22", started and homes == [true, true], "after R: round_started %s, Flags at home %s" % [started, homes])
	_lk.note(&"T22", "%s; after R both Flags AT_HOME on their seats, status OWN_AT_HOME: %s" % [dropped, homes])
	_lk.closed.append(&"T22")


## T22 A, in place of the first Self-destruct of the Round: Player 1's first Motorbike takes
## Player 2's Flag, is put down on Base 2's gate axis and Tab destroys it with its other Motorbike
## Tokens in hand: one Token, the Flag dropped at the wreck before the signal, the Round running.
func _carrier_first() -> void:
	var carried: bool = await Loss.carry_to_gate(_lk.fk, 0, 1, 1)
	_lk.need(&"T22", carried and _lk.fk.flags[1].carrier == _lk.fk.units[0], "A: the first Motorbike does not carry Player 2's Flag")
	await _lk.lose_one(&"T22", "A: Tab on the Carrier's first Motorbike", 0, _tk.destruct.bind(0), PackedStringArray(["flag_dropped:1"]))
	_lk.note(&"T22", _dropped_at_wreck("A"))


## Player 2's Flag lies DROPPED at the latest wreck and rides on no Unit; files the problem and
## returns the note.
func _dropped_at_wreck(label: String) -> String:
	var flag: Flag = _lk.fk.flags[1]
	var wreck: float = flag.global_position.distance_to(_lk.fk.wrecks[-1] if not _lk.fk.wrecks.is_empty() else Vector3.INF)
	var seat: float = flag.global_position.distance_to(_lk.fk.bases[1].flag_seat.global_position)
	_lk.need(&"T22", flag.state == Flag.State.DROPPED and wreck <= PLACE_TOLERANCE and flag.get_parent() != _lk.fk.units[0], "%s: Flag %s, %.3f m from the wreck, parent %s" % [label, _lk.fk.state_name(1), wreck, flag.get_parent().name])
	return "%s: Flag 2 DROPPED %.3f m from the wreck, %.1f m from its seat" % [label, wreck, seat]


## True when a Player's Flag is AT_HOME on its Base's seat and the Player's status says so.
func _at_home(player: int) -> bool:
	var flag: Flag = _lk.fk.flags[player]
	var seated: bool = flag.global_position.distance_to(_lk.fk.bases[player].flag_seat.global_position) <= PLACE_TOLERANCE
	return flag.state == Flag.State.AT_HOME and seated and _tk.controller.flag_status(player) == MatchController.FlagStatus.OWN_AT_HOME


## T23: Player 1 spends every Token of every type but the Motorbike, one Self-destruct each, with
## all its Motorbike Tokens left: no Round end at any step, and the Motorbike can still be chosen.
func _t23() -> void:
	var types: int = _tk.controller.unit_types().size()
	var plan: Array[int] = []
	for type_index: int in range(types - 1, -1, -1):
		for _token: int in 0 if type_index == _lk.carrier else _lk.start[0][type_index]:
			plan.append(type_index)
	_from = _tk.events.size()
	if not await _lk.start_round(&"T23", plan[0], _lk.carrier):
		return
	var steps: PackedStringArray = []
	for index: int in plan.size():
		if not await _spend(plan, index, steps):
			return
	var row: Array = range(types).map(func(type_index: int) -> int: return _lk.start[0][type_index] if type_index == _lk.carrier else 0)
	var again: bool = _tk.controller.can_choose(0, _lk.carrier) and await _tk.spawn(0, _lk.carrier)
	_lk.need(&"T23", _tk.counts() == [row, _lk.start[1]] and again and _runs(), "Tokens %s (expected %s), Motorbike chosen %s" % [_tk.counts(), [row, _lk.start[1]], again])
	_lk.note(&"T23", "Tokens left after each Self-destruct: %s; Player 1 then has %s, round_over x%d, and the Motorbike was chosen and came into play: %s" % [", ".join(steps), row, _tk.events_of(&"over", _from).size(), again])
	_lk.closed.append(&"T23")


## One step of T23: Player 1 chooses the plan's type (the first is in play), Self-destructs it and
## notes the Token left; a problem if the Round is over or paused. False if the Unit did not come.
func _spend(plan: Array[int], index: int, steps: PackedStringArray) -> bool:
	if index > 0 and not _lk.need(&"T23", await _tk.spawn(0, plan[index]), "Player 1's type %d did not come up" % plan[index]):
		return false
	await _kit.advance(Units.SETTLE_TICKS)
	var seen: int = _tk.events.size()
	await _tk.destruct(0)
	await _tk.wait_for(&"destroyed", seen)
	steps.append("%s %d" % [_tk.controller.unit_types()[plan[index]].type_id, _tk.controller.tokens_left(0, plan[index])])
	_lk.need(&"T23", _runs(), "after %s the Round is over or paused" % steps[-1])
	return true


## True while the Round of T23 and T24 runs: not over, not paused, no round_over since it began.
func _runs() -> bool:
	return not _tk.controller.is_round_over() and not _h.get_tree().paused and _tk.events_of(&"over", _from).is_empty()


## T24, in the Round T23 left running: Player 2's Motorbike is held against the back wall of its
## Base with the throttle until the tank is empty and for DRY_SECONDS more (nothing destroyed, no
## Token gone); then Player 1 takes Player 2's Flag and delivers it: round_over(0) once, no Token
## spent.
func _t24() -> void:
	var alive: Array = Kit.PLAYERS.map(func(player: int) -> bool: return _tk.controller.is_alive(player))
	if not _lk.need(&"T24", alive == [true, true] and _runs(), "T23 left the Round over, paused or a Unit out of play: alive %s" % [alive]):
		return
	await _run_dry(1)
	var stolen: bool = await Loss.carry_to_gate(_lk.fk, 0, 1, 0)
	_lk.need(&"T24", stolen, "Player 1 does not carry Player 2's Flag")
	var ticks: int = await _lk.finish_with(&"T24", "delivery by Player 1, Tokens in play", 0, [], Loss.deliver.bind(_lk.fk, 0))
	var log: Array = [_tk.engine_log.errors, _tk.engine_log.warnings]
	_lk.need(&"T24", ticks > 0 and log == [[], []], "the delivery run took %d ticks, the engine logged %s" % [ticks, log])
	_lk.note(&"T24", "delivery ran %d ticks; engine log over the whole run: %d errors, %d warnings" % [ticks, log[0].size(), log[1].size()])
	_lk.closed.append(&"T24")


## T24's empty tank: the Player's Unit pinned against its Base's back wall, throttle held until
## `is_fuel_empty` and DRY_SECONDS more; it lives, nothing is destroyed, the Tokens are unchanged.
func _run_dry(player: int) -> void:
	var unit: Unit = _lk.fk.units[player]
	var base: Base = _lk.fk.bases[player]
	_lk.fk.teleport(player, base.to_global(PIN_SPOT), base.global_transform.basis.z)
	await _kit.advance(Units.SETTLE_TICKS)
	var tank: float = unit.fuel
	_h.drive(player, 1, 0)
	var burned: int = 0
	while not unit.is_fuel_empty and burned < DRY_LIMIT_TICKS:
		await _kit.tick()
		burned += 1
	var seen: int = _tk.events.size()
	var rows: Array = _tk.counts()
	await _kit.advance(_h.ticks_in(DRY_SECONDS))
	_h.drive(player, 0, 0)
	var calm: bool = unit.is_alive and _tk.events_of(&"destroyed", seen).is_empty() and _tk.counts() == rows and _runs()
	_lk.need(&"T24", unit.is_fuel_empty and calm, "tank empty %s, Unit alive %s, Round running %s, Tokens %s" % [unit.is_fuel_empty, unit.is_alive, _runs(), _tk.counts()])
	_lk.note(&"T24", "Player %d's %s pinned, throttle held: %.1f Fuel burned out in %d ticks, then %.0f s empty: alive, no unit_destroyed, Tokens %s unchanged, Round running" % [player + 1, unit.stats.display_name, tank, burned, DRY_SECONDS, rows])
