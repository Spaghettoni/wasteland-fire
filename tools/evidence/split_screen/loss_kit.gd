extends RefCounted
## What the Story 008 `loss` scenario (loss.gd) shares beyond token_kit.gd, flag_kit.gd and
## check_kit.gd: the Rounds it plays (start_round(), to_last()), the judging of how one ended
## (finish_with()), of a destruction that left the Round running (lose_one()) and of the choices
## a finished Round refuses (refuses_choices()), the Flag runs on Map 01 (carry_to_gate(),
## deliver(): static, tokens_showcase.gd calls them too) and the filing of its checks (need(),
## note(), report()). Make one with LossKit.new(harness, kit, check_ids); report() releases the
## engine log. Tooling only: nothing under src/ depends on this file.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the settle time after a spawn.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, real-key choices and Shots.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 004 helpers (flag_kit.gd): the Flags' record and the moves.
const Flags: GDScript = preload("res://tools/evidence/split_screen/flag_kit.gd")
## Ticks a Round that ended is watched before it is judged, so a second signal would be in the
## record: half a second.
const OVER_WAIT_TICKS: int = 30
## A point on a Base's gate axis outside its gate, in the Base's frame (local -Z leads out): clear
## of the cover on Map 01, as map_bases.gd's raid start is.
const GATE_AXIS: Vector3 = Vector3(0.0, 0.0, -50.0)
## Drive speed of a delivery run, m/s: a tick moves 0.2 m, a Base's zone is 27.5 m deep.
const DELIVERY_CRUISE: float = 12.0

## The Story 008 kit: readings, events, the engine log, real-key choices, Shots and restarts.
var tk: Tokens
## The Story 004 kit: the Flags, the Bases and the moves.
var fk: Flags
## The index into unit_types() of the one type that can carry the Flag, read from the data.
var carrier: int = -1
## The rows the Map's stock gives both Players, read from its resource: [[Player 1], [Player 2]].
var start: Array = []
## The checks whose evidence is complete.
var closed: Array[StringName] = []
## The last finish_with(): the events index, the Tokens and the signal order's size before its
## cause.
var last: Dictionary = {}
var _h: Harness
var _kit: Kit
var _waits: Array[int] = []
var _order: PackedStringArray = []
var _problems: Dictionary[StringName, PackedStringArray] = {}
var _notes: Dictionary[StringName, PackedStringArray] = {}


## Makes the Story 008 and Story 004 records, reads the stock, connects the signal order and files
## an empty record for every check id.
func _init(harness_node: Node, check_kit: Kit, check_ids: Array) -> void:
	_h = harness_node as Harness
	_kit = check_kit
	tk = Tokens.new(_h, _kit)
	fk = Flags.new(_h, _kit)
	carrier = tk.carrier_index()
	start = tk.rows_of(_h.split.field.token_stock)
	for id: StringName in check_ids:
		_problems[id] = PackedStringArray()
		_notes[id] = PackedStringArray()
	tk.controller.flag_dropped.connect(func(index: int) -> void: _order.append("flag_dropped:%d" % index))
	tk.controller.unit_destroyed.connect(func(player: int) -> void: _order.append("destroyed:%d" % player))
	tk.controller.round_over.connect(func(winner: int) -> void: _order.append("over:%d" % winner))


## Adds a problem to a check unless the condition holds; returns the condition.
func need(check: StringName, holds: bool, problem: String) -> bool:
	_kit.need(_problems[check], holds, problem)
	return holds


## Adds a measured note to a check.
func note(check: StringName, text: String) -> void:
	_notes[check].append(text)


## Ticks a wait for a Unit to come into play may take: the respawn delay and the check kit's slack.
func wait_limit() -> int:
	return _h.ticks_in(tk.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS


## Presses the Self-destruct keys of the Players, in that order, on one tick (two ticks pass).
func destruct_together(players: Array[int]) -> void:
	var pressed: Array[Key] = []
	for player: int in players:
		pressed.append_array(Tokens.keys(&"destruct", player))
	await _kit.press_settled(pressed)


## Starts a Round: a Round that ended is restarted with R first, and at its start the Tokens must
## be the stock, both Players choosing, nothing over, no winner. Each Player then chooses its
## first type (`first`, `second`) with its real keys, and its Unit must be in play within
## SPAWN_SETTLE_TICKS + 2 ticks of the choice. Files the problems in `check`; true when both Units
## are in play.
func start_round(check: StringName, first: int, second: int) -> bool:
	var ended: bool = tk.controller.is_round_over()
	var ok: bool = not ended or await tk.restart()
	var fresh: bool = [tk.counts(), tk.controller.is_choosing(0), tk.controller.is_choosing(1)] == [start, true, true]
	var calm: bool = [tk.controller.is_round_over(), tk.controller.winner_index(), _h.get_tree().paused] == [false, MatchController.NO_WINNER, false]
	need(check, ok and fresh and calm, "Round start: was over %s, Tokens %s, the stock %s, winner %d" % [ended, tk.counts(), start, tk.controller.winner_index()])
	_waits.clear()
	for player: int in Kit.PLAYERS:
		ok = await tk.choose(player, first if player == 0 else second) and ok
		ok = await tk.units.wait_alive(player, wait_limit()) >= 0 and ok
		_waits.append(tk.units.spawns[-1].y - tk.units.chosen[-1].z if not tk.units.spawns.is_empty() else -1)
	var soon: int = MatchController.SPAWN_SETTLE_TICKS + 2
	need(check, ok and _waits.all(func(wait: int) -> bool: return wait >= 0 and wait <= soon), "Units in play %s, %s ticks after their choice (at most %d)" % [ok, _waits, soon])
	await _kit.advance(Units.SETTLE_TICKS)
	return ok


## Starts a Round with the carrier type for both Players and takes `players` to their last
## Motorbike: their Self-destructs on one tick and a new Motorbike for each, once less than the
## stock's count. `first`, when valid, is a coroutine that makes the first Self-destruct instead
## of the keys on one tick (loss.gd: a Carrier's). Files in `check` a problem unless the Motorbike
## Tokens fall one by one, the Round runs after each and every Unit is in play. True when all held.
func to_last(check: StringName, players: Array[int], first: Callable = Callable()) -> bool:
	var since: int = tk.events.size()
	var ok: bool = await start_round(check, carrier, carrier)
	var cycles: int = start[players[0]][carrier] - 1
	var limit: int = wait_limit()
	var seen: Array = []
	var keys: Callable = destruct_together.bind(players)
	var cause: Callable = first if first.is_valid() else keys
	for _cycle: int in cycles:
		await cause.call()
		cause = keys
		seen.append(players.map(func(player: int) -> int: return tk.counts()[player][carrier]))
		ok = ok and tk.events_of(&"over", since).is_empty() and not tk.controller.is_round_over()
		for player: int in players:
			ok = await tk.choose(player, carrier) and ok
		for player: int in players:
			ok = await tk.units.wait_alive(player, limit) >= 0 and ok
		await _kit.advance(Units.SETTLE_TICKS)
	var wanted: Array = range(1, cycles + 1).map(func(spent: int) -> Array: return players.map(func(player: int) -> int: return start[player][carrier] - spent))
	need(check, seen == wanted and ok, "Motorbike Tokens after each Self-destruct %s, expected %s, Round running, Units in play: %s" % [seen, wanted, ok])
	note(check, "Units in play %s ticks after their choice; Motorbike Tokens of Player %s after #1..#%d: %s, Round running" % [_waits, "/".join(players.map(func(player: int) -> String: return str(player + 1))), cycles, seen])
	return ok


## Makes the last cause of a Round's end (a coroutine Callable: a key, a Shot, a drive), waits for
## the destruction it brings (none when `lost` is empty) and OVER_WAIT_TICKS more, and judges it.
## Returns what the cause returned.
func finish_with(check: StringName, label: String, winner: int, lost: Array[int], cause: Callable,
		prefix: PackedStringArray = PackedStringArray()) -> Variant:
	last = {"mark": tk.events.size(), "order": _order.size(), "before": tk.counts()}
	var result: Variant = await cause.call()
	if not lost.is_empty():
		await tk.wait_for(&"destroyed", last["mark"])
	await _kit.advance(OVER_WAIT_TICKS)
	_judge(check, label, winner, lost, prefix)
	return result


## Judges the Round's end since the last cause: round_over once, carrying `winner`; every
## destruction in the physics frame of the announcement; the signals in the order prefix,
## destroyed:N for each Player of `lost`, over:winner; the Tokens as before less the carrier
## type's Token of each Player of `lost`; the Round over, won by `winner`, the tree paused
## (already inside the handler). Files the problems and one note.
func _judge(check: StringName, label: String, winner: int, lost: Array[int], prefix: PackedStringArray) -> void:
	var overs: Array[Dictionary] = tk.events_of(&"over", last["mark"])
	var over: Dictionary = overs[0] if overs.size() == 1 else {"arg": -2, "now": {}}
	var frames: Array = tk.events_of(&"destroyed", last["mark"]).map(func(event: Dictionary) -> int: return event["now"]["frame"])
	var wanted: PackedStringArray = prefix.duplicate()
	var rows: Array = last["before"]
	for player: int in lost:
		rows = Tokens.charged(rows, player, carrier)
		wanted.append("destroyed:%d" % player)
	wanted.append("over:%d" % winner)
	var seen: Dictionary = tk.state()
	var signals: PackedStringArray = _order.slice(last["order"])
	var announced: int = over["now"].get("frame", -1)
	var gap: int = announced - (frames.max() if not frames.is_empty() else announced)
	var facts: Array = [
		[overs.size() == 1 and over["arg"] == winner, "round_over came %d times, carrying %s" % [overs.size(), over["arg"]]],
		[frames.size() == lost.size() and frames.all(func(frame: int) -> bool: return frame == announced), "destructions in frames %s, round_over in %d" % [frames, announced]],
		[signals == wanted, "signals %s, expected %s" % [signals, wanted]],
		[seen["counts"] == rows, "Tokens %s, expected %s" % [seen["counts"], rows]],
		[seen["over"] and seen["winner"] == winner and seen["paused"] and over["now"].get("paused", false), "over %s, winner %d, paused %s, in the handler %s" % [seen["over"], seen["winner"], seen["paused"], over["now"].get("paused")]]]
	for fact: Array in facts:
		need(check, fact[0], "%s: %s" % [label, fact[1]])
	var timing: String = "%d frame(s) after the last destruction" % gap if not frames.is_empty() else "no destruction"
	note(check, "%s: Tokens %s -> %s, signals %s, round_over(%s) x%d, %s, over=%s paused=%s" % [
		label, last["before"], seen["counts"], signals, over["arg"], overs.size(), timing, seen["over"], seen["paused"]])


## Makes the cause of a destruction that leaves the Round running (a coroutine Callable: a key),
## waits for it and OVER_WAIT_TICKS more, and judges it: the signals in the order prefix,
## destroyed:`player`; the Tokens as before less the carrier type's Token of `player`; no
## round_over, the Round running and the tree not paused. Files the problems and one note.
func lose_one(check: StringName, label: String, player: int, cause: Callable,
		prefix: PackedStringArray = PackedStringArray()) -> void:
	last = {"mark": tk.events.size(), "order": _order.size(), "before": tk.counts()}
	await cause.call()
	await tk.wait_for(&"destroyed", last["mark"])
	await _kit.advance(OVER_WAIT_TICKS)
	var wanted: PackedStringArray = prefix.duplicate()
	wanted.append("destroyed:%d" % player)
	var rows: Array = Tokens.charged(last["before"], player, carrier)
	var seen: Dictionary = tk.state()
	var signals: PackedStringArray = _order.slice(last["order"])
	var overs: int = tk.events_of(&"over", last["mark"]).size()
	need(check, signals == wanted, "%s: signals %s, expected %s" % [label, signals, wanted])
	need(check, seen["counts"] == rows, "%s: Tokens %s, expected %s" % [label, seen["counts"], rows])
	need(check, overs == 0 and not seen["over"] and not seen["paused"] and seen["winner"] == MatchController.NO_WINNER,
		"%s: round_over x%d, over %s, paused %s, winner %d" % [label, overs, seen["over"], seen["paused"], seen["winner"]])
	note(check, "%s: Tokens %s -> %s, signals %s, round_over x%d, over=%s paused=%s" % [
		label, last["before"], seen["counts"], signals, overs, seen["over"], seen["paused"]])


## A Round that is over takes no choice (choose()'s doc): each Player that is choosing is offered
## every type it still has a Token of, from here because the pause keeps every key from the choice
## input, and none is accepted: no unit_chosen, no choice standing, nobody stops choosing. Files
## the problem and one note.
func refuses_choices(check: StringName, label: String) -> void:
	var game: MatchController = tk.controller
	var before: Dictionary = tk.state()
	var picked: int = tk.units.chosen.size()
	var offered: PackedStringArray = []
	var accepted: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		for type_index: int in game.unit_types().size():
			if before["choosing"][player] and game.can_choose(player, type_index):
				offered.append("Player %d %s" % [player + 1, game.unit_types()[type_index].type_id])
				if game.choose(player, type_index):
					accepted.append(offered[-1])
	var seen: Dictionary = tk.state()
	var standing: bool = seen["chosen"].all(func(type_index: int) -> bool: return type_index == MatchController.NO_CHOICE)
	need(check, not offered.is_empty() and accepted.is_empty() and standing and seen["choosing"] == before["choosing"] and tk.units.chosen.size() == picked,
		"%s: choose() accepted %s of %d offers (%s); chosen %s, choosing %s (was %s), unit_chosen +%d" % [
		label, accepted, offered.size(), offered, seen["chosen"], seen["choosing"], before["choosing"], tk.units.chosen.size() - picked])
	note(check, "%s: choose() refused all %d offers (%s); chosen %s, choosing %s as before, no unit_chosen" % [
		label, offered.size(), ", ".join(offered), seen["chosen"], seen["choosing"]])


## Player `thief` takes the Flag of Player `owner`: put down 6 m from it on the owner's gate side,
## the throttle held until the Round hands it over, at rest; then put down on the gate axis of Base
## `gate_index`, GATE_AXIS from its origin, facing in, the Flag riding along. True when it carries
## it. Static, on the Flags kit: tokens_showcase.gd runs the same steps with its own.
static func carry_to_gate(fk: Flags, thief: int, owner: int, gate_index: int) -> bool:
	fk.approach(thief, fk.flags[owner].global_position, -fk.bases[owner].global_transform.basis.z)
	await fk.kit.advance(Units.SETTLE_TICKS)
	await fk.drive_until(thief, 1, Flags.APPROACH_SPEED, fk.touching.bind(owner, thief))
	await fk.kit.advance(Kit.TICK_SLACK + 1)
	await fk.rest(thief)
	var base: Base = fk.bases[gate_index]
	fk.teleport(thief, base.to_global(GATE_AXIS), base.global_transform.basis.z)
	await fk.kit.advance(Units.SETTLE_TICKS)
	return fk.controller.flag_status(thief) == MatchController.FlagStatus.CARRYING_ENEMY and fk.flags[owner].state == Flag.State.CARRIED


## Drives a Player's Unit forward at DELIVERY_CRUISE until a round_over comes that was not there
## when it set off: the ticks, or -1. Static, on the Flags kit, like carry_to_gate().
static func deliver(fk: Flags, player: int) -> int:
	var seen: int = fk.round_overs.size()
	return await fk.drive_until(player, 1, DELIVERY_CRUISE, func() -> bool: return fk.round_overs.size() > seen)


## Prints the verdicts in the order of `names` (a check whose evidence was not closed fails) and
## releases the engine log.
func report(names: Dictionary[StringName, String]) -> void:
	tk.close()
	for id: StringName in names:
		if not closed.has(id):
			_problems[id].append("the phase stopped before this check's evidence was complete")
		_kit.verdict(names[id], _problems[id], " | ".join(_notes[id]))
