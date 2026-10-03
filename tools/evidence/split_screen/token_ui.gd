extends RefCounted
## Scenario token_ui of the split screen evidence harness (split_screen_harness.gd): what Story 008
## puts on the screens (AC-6, AC-7), on Map 01 with its real stock, played with real key events.
## Four Rounds, each ended another way and restarted with R: Player 1 loses (its Truck destroyed
## twice, which turns that slot dim, then its five Motorbikes); Player 2 delivers Player 1's Flag
## after both Players spent Tokens; both Players lose their last Motorbike on one frame; Player 2
## loses. Five CHECK lines, every expected text built from the scenes' exports and the Map's stock
## resource, never typed. T28 builds a PlayerHud and a UnitChoice on throwaway MatchControllers
## (not begun; begin() refused for no stock and for no Token of the carrier type): the two ERROR
## lines it puts on stderr are those refusals. Helpers: token_kit.gd, token_ui_kit.gd, check_kit.gd.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-6, AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=token_ui
##
## Kills, check by check:
##  T25  a HUD line refreshed at the spawn, in _process, after the signal or not at all (stale
##       inside the unit_destroyed handler); a line bound to the cursor's or the driven Unit's type
##       and not the carrier's; a line that follows the other Player's destruction; a hidden line.
##  T26  a restart that fills the stock after round_started (the HUD reads stale counts), takes a
##       Token or fills too little; a line not read again at round_started or left hidden.
##  T28  a line indexing the types with the carrier's -1 (it paints the last type's name before
##       begin()), not hidden before begin() or after a refused begin(); a panel shown then; a
##       refusal that logs more or less than one ERROR.
##  T29  'Player 0 wins!' for a double loss; nobody_text for a single loss; always the same Player;
##       a restart line without the bound key; a screen in one view only; a choice panel left up.
##  T30  a restart that leaves the Round-over screen up, the tree paused, the stock short or
##       unfilled (a loss at once), a Flag away or a dimmed slot dim, the Players not choosing, a
##       Unit that appears late, a round_over on the first tick or an engine ERROR or WARNING.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, real-key choices and restarts.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The readers of the Story 008 UI scenarios (token_ui_kit.gd).
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## The runner keeps the Map's own Token stock (data/token_stock.tres) for this scenario.
const USE_MAP_STOCK: bool = true
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## Simulated seconds before the watchdog: the run takes about 54 of them (25 destructions, each
## followed by a respawn delay; RESULT t= and destroyed=).
const WATCHDOG_SECONDS: float = 300.0
## The types as indexes into the data (the premise checks the data's order).
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }
## The checks as printed, by the short id the code uses, in the design's order.
const NAMES: Dictionary[StringName, String] = {&"T25": "T25_hud_on_destruction_tick", &"T26": "T26_hud_restart",
	&"T28": "T28_hud_before_begin", &"T29": "T29_round_over_texts", &"T30": "T30_restart_after_each_end"}
## Ticks beyond the bench settle that a Unit may take to appear after the fire keys (design 14).
const APPEAR_SLACK: int = 2

var _h: Harness
var _kit: Kit
var _tk: Tokens
var _ui: UiKit
## The Map's stock as rows (the initial data), the type ids in order, the carrier's index.
var _start: Array = []
var _ids: Array[StringName] = []
var _carrier: int = -1
## Per check: the problems and the measured notes; why the run stopped early, if it did.
var _problems: Dictionary[StringName, PackedStringArray] = {}
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _stopped: String = ""
## What each round_over showed inside its handler; how many there were before this Round; this
## Round's destructions as "player type cursor p1-line/p2-line" (the lines read in the handler).
var _overs: Array[Dictionary] = []
var _over_mark: int = 0
var _seen: PackedStringArray = []


## Runs the scenario: the premise, T28, then the four Rounds. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_ui = UiKit.new(_tk)
	_start = _tk.rows_of(_h.split.field.token_stock)
	_carrier = _tk.carrier_index()
	for stats: UnitStats in _tk.controller.unit_types():
		_ids.append(stats.type_id)
	for id: StringName in NAMES:
		_problems[id] = PackedStringArray()
		_notes[id] = PackedStringArray()
	_tk.controller.round_over.connect(func(winner: int) -> void: _overs.append({"winner": winner, "paused": _h.get_tree().paused,
			"lines": [_tk.over_lines(0), _tk.over_lines(1)]}))
	await _kit.advance(Kit.START_TICKS)
	_require(&"T25", _ids == Tokens.Units.TYPE_IDS and _carrier == Type.MOTORBIKE and _start[0][Type.TRUCK] >= 2, "the data's types %s, the carrier %d or the Truck's Tokens are not what the scenario expects" % [_ids, _carrier])
	var phases: Array[Callable] = [_hud_before_begin, _lose_player_1, _deliver_player_2, _lose_both, _lose_player_2]
	for phase: Callable in phases:
		if _stopped.is_empty():
			await phase.call()
	_report()


## T28: a HUD and a choice panel for Player 1 on throwaway controllers with the live rules, Units,
## Bases and cameras: one never begun, one whose begin() is refused for no stock, one refused for
## a stock without a Token of the carrier type.
func _hud_before_begin() -> void:
	var counts: Dictionary = {}
	for stats: UnitStats in _tk.controller.unit_types():
		counts[stats.type_id] = 0 if stats.can_carry else 1
	await _idle_screens("never begun", false, null, "")
	await _idle_screens("no stock", true, null, "no Token stock")
	await _idle_screens("no carrier Token", true, Tokens.stock(counts), _tk.controller.unit_types()[_carrier].display_name)


## One throwaway controller, asked to begin with the stock when `try_begin` (the engine log must
## then hold exactly the one error naming `error` and no warning); its screens are read three ticks
## after they are built.
func _idle_screens(label: String, try_begin: bool, stock: TokenStock, error: String) -> void:
	var controller: MatchController = MatchController.new()
	controller.name = "Throwaway"
	controller.rules = _tk.controller.rules
	_h.add_child(controller)
	var errors: int = _tk.engine_log.errors.size()
	var warnings: int = _tk.engine_log.warnings.size()
	if try_begin:
		controller.begin(_tk.units.units, _tk.units.bases, _tk.units.cameras, stock)
	var logged: Array[String] = _tk.engine_log.errors.slice(errors)
	_need(&"T28", logged.size() == int(try_begin) and (logged.is_empty() or logged[0].contains(error)) and _tk.engine_log.warnings.size() == warnings,
			"%s: begin() logged %s, expected %d error line naming '%s'; new warnings: %d" % [label, logged, int(try_begin), error, _tk.engine_log.warnings.size() - warnings])
	var host: Node = _ui.idle_screens(controller)
	await _kit.advance(3)
	var tokens: Label = host.find_child("TokensLabel", true, false) as Label
	var choice: UnitChoice = host.find_child("UnitChoice", true, false) as UnitChoice
	var named: PackedStringArray = []
	for node: Node in host.find_children("*", "Label", true, false):
		for stats: UnitStats in controller.unit_types():
			if (node as Label).is_visible_in_tree() and (node as Label).text.contains(stats.display_name):
				named.append((node as Label).text)
	var shown: String = "Tokens label visible=%s '%s', panel visible=%s, carrier_type_index %d" % [tokens.visible, tokens.text, choice.visible, controller.carrier_type_index()]
	_need(&"T28", named.is_empty() and not tokens.visible and tokens.text.is_empty() and not choice.visible and controller.carrier_type_index() == -1
			and controller.tokens_left(0, 0) == 0 and not controller.can_choose(0, 0), "%s; visible labels naming a Unit type: %s" % [shown, named])
	_notes[&"T28"].append("%s (begin() logged %s): %s" % [label, logged, shown])
	host.free()
	controller.free()


## Round one: Player 1 loses. Its Truck is destroyed twice (the line stays the Motorbike's with
## the cursor on the Truck, and the Truck's slot goes dim), then its five Motorbikes.
func _lose_player_1() -> void:
	await _respawn(1, Type.MOTORBIKE)
	await _respawn(0, Type.TRUCK)
	await _replace(0, Type.TRUCK, Type.TRUCK)
	await _replace(0, Type.TRUCK, Type.MOTORBIKE)
	await _run_down([0], _start[0][Type.MOTORBIKE])
	await _end_round("Player 1's last Motorbike", 1)


## Round two: both Players spend Tokens (Player 2 a Truck too), then Player 2's Motorbike takes
## Player 1's Flag and brings it into its own Base: put on the Flag, then into the zone, by the
## runner's place(); the Round's own pick-up and delivery follow within three ticks (measured).
func _deliver_player_2() -> void:
	await _replace(0, Type.MOTORBIKE, Type.MOTORBIKE)
	await _replace(1, Type.MOTORBIKE, Type.TRUCK)
	await _replace(1, Type.TRUCK, Type.MOTORBIKE)
	var flag: Flag = _tk.units.bases[0].flag
	var thief: Unit = _tk.units.units[1]
	var mark: int = _tk.events.size()
	_h.place(thief, _tk.units.pose(flag.global_position, Vector3.LEFT), _tk.units.cameras[1])
	await _kit.advance(Harness.SETTLE_TICKS)
	var took: bool = flag.carrier == thief
	_h.place(thief, _tk.units.pose(_tk.units.bases[1].zone.global_position, Vector3.RIGHT), _tk.units.cameras[1])
	var won: bool = await _tk.wait_for(&"over", mark)
	_require(&"T29", took and won, "Player 2 did not take Player 1's Flag (%s) and deliver it (%s)" % [took, won])
	await _end_round("Player 2's delivery", 1)


## Round three: both Players lose their last Motorbike on one frame (Tab and Enter together).
func _lose_both() -> void:
	await _run_down([0, 1], _start[0][Type.MOTORBIKE])
	await _end_round("both last Motorbikes on one frame", MatchController.NO_WINNER)


## Round four: Player 2 loses its five Motorbikes (the winner line names Player 1 this time).
func _lose_player_2() -> void:
	await _run_down([1], _start[1][Type.MOTORBIKE])
	await _end_round("Player 2's last Motorbike", 0)


## The Player's Unit of the type is destroyed with its Self-destruct key and the next type chosen.
func _replace(player: int, type_index: int, next_type: int) -> void:
	await _destroy([player], type_index)
	await _respawn(player, next_type)


## Chooses the type for the Player with its real keys and waits until the Unit is in play.
func _respawn(player: int, type_index: int) -> void:
	if _stopped.is_empty():
		_require(&"T25", await _tk.spawn(player, type_index), "player %d's %s did not appear" % [player + 1, _ids[type_index]])


## The Motorbikes of the Players are destroyed together `count` times, each followed by the choice
## of the next one except the last (that one ends the Round).
func _run_down(players: Array[int], count: int) -> void:
	for cycle: int in count:
		await _destroy(players, Type.MOTORBIKE)
		if cycle < count - 1:
			for player: int in players:
				await _respawn(player, Type.MOTORBIKE)


## T25: the HUD lines with the Unit in play (the Motorbike's, whatever type drives and wherever the
## cursor rests), then the Players' Self-destruct keys together and the lines inside the
## unit_destroyed handler and a frame later: one Token less of the type, every other line unchanged
## (with two Players at once the first handler cannot know the second: only its own is judged).
func _destroy(players: Array[int], type_index: int) -> void:
	if not _stopped.is_empty():
		return
	var keys: Array[Key] = []
	var expected: Array = _tk.counts()
	var before: Array = [_tk.hud_text(0, expected[0][_carrier]), _tk.hud_text(1, expected[1][_carrier])]
	for player: int in players:
		keys.append(Tokens.keys(&"destruct", player)[0])
		expected = Tokens.charged(expected, player, type_index)
	var mark: int = _tk.events.size()
	var cursor: int = _tk.units.panels[players[0]].choice_input.cursor
	_need(&"T25", _tk.state()["hud"] == before, "the %s in play, cursor on %d: HUD lines %s, expected %s" % [_ids[type_index], cursor, _tk.state()["hud"], before])
	await _kit.press_settled(keys)
	await _tk.wait_for(&"destroyed", mark)
	var found: Array[Dictionary] = _tk.events_of(&"destroyed", mark)
	var want: Array = [_tk.hud_text(0, expected[0][_carrier]), _tk.hud_text(1, expected[1][_carrier])]
	_need(&"T25", found.size() == players.size() and _labels_shown(), "%d unit_destroyed for %d Players, lines shown: %s" % [found.size(), players.size(), _labels_shown()])
	for event: Dictionary in found:
		var player: int = event["arg"]
		var now: Array = event["now"].get("hud", ["", ""])
		_need(&"T25", event["type"] == _ids[type_index] and (now == want if players.size() == 1 else now[player] == want[player]) and event["later"].get("hud") == want,
				"player %d's %s (cursor on %d): HUD lines %s in the handler and %s a frame later, expected %s" % [player + 1, _ids[type_index], cursor, now, event["later"].get("hud"), want])
		_seen.append("p%d %s c%d %s/%s" % [player + 1, event["type"], cursor, now[0].get_slice(": ", 1), now[1].get_slice(": ", 1)])


## T29: one round_over with the winner and the tree paused, the choice panels hidden, both views
## reading the winner line or nobody_text and the restart line with the bound key, in the handler
## and at rest; then R (T26, T30), and the next Round's record begins.
func _end_round(label: String, winner: int) -> void:
	if not _stopped.is_empty():
		return
	var record: Dictionary = _overs[-1] if _overs.size() == _over_mark + 1 else {"winner": -2, "paused": false, "lines": [PackedStringArray(), PackedStringArray()]}
	_need(&"T29", record["winner"] == winner and record["paused"] and _tk.controller.is_round_over() and _tk.controller.winner_index() == winner,
			"%s: %d round_over this Round, the last for %d (paused %s); the controller says over=%s winner=%d" % [label, _overs.size() - _over_mark, record["winner"], record["paused"], _tk.controller.is_round_over(), _tk.controller.winner_index()])
	var views: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var want: PackedStringArray = _ui.expected_lines(player, winner)
		var rest: PackedStringArray = _tk.over_lines(player)
		_need(&"T29", record["lines"][player] == want and rest == want and not _tk.units.panels[player].visible and (winner != MatchController.NO_WINNER or not "".join(rest).contains("Player")),
				"%s: player %d's view reads %s in the handler and %s at rest, expected %s (choice panel shown: %s)" % [label, player + 1, record["lines"][player], rest, want, _tk.units.panels[player].visible])
		views.append("p%d '%s' / '%s'" % [player + 1, rest[0] if rest.size() == 2 else "hidden", rest[1] if rest.size() == 2 else ""])
	_notes[&"T29"].append("%s: round_over(%d), tree paused, choice panels hidden, %s" % [label, winner, " ".join(views)])
	_notes[&"T25"].append("%s: HUD counts p1/p2 inside the handler (c = the cursor's type): %s" % [label, ", ".join(_seen)])
	await _restart(label)
	_over_mark = _overs.size()
	_seen = PackedStringArray()


## R. T26: one round_started whose handler (and the frame after, and rest) already reads the Map's
## full count on both lines. T30: the Round runs again with the Map's stock, the Flags home, both
## Players choosing and the screens as at a start; then, the cursors steered to the Motorbike, both
## fire keys together: each Unit appears within SPAWN_SETTLE_TICKS plus APPEAR_SLACK ticks, with no
## round_over and no engine ERROR or WARNING since R.
func _restart(label: String) -> void:
	var mark: int = _tk.events.size()
	var logged: int = _tk.engine_log.errors.size() + _tk.engine_log.warnings.size()
	var restarted: bool = await _tk.restart()
	await _kit.advance(2)
	var seen: Dictionary = _tk.state()
	var started: Array[Dictionary] = _tk.events_of(&"started", mark)
	var full: Array = [_tk.hud_text(0, _start[0][_carrier]), _tk.hud_text(1, _start[1][_carrier])]
	var handler: Array = started[0]["now"].get("hud", []) if started.size() == 1 else []
	_need(&"T26", restarted and started.size() == 1 and handler == full and started[0]["later"].get("hud") == full and seen["hud"] == full and _labels_shown(),
			"%s: R gave %d round_started; HUD lines %s in its handler; state at rest %s; expected %s" % [label, started.size(), handler, seen["hud"], full])
	_notes[&"T26"].append("%s: round_started tick %s, a frame later and at rest the same" % [label, handler])
	var problems: PackedStringArray = _problems[&"T30"]
	var tag: String = label + ": "
	_kit.need(problems, restarted and started.size() == 1 and not seen["paused"] and not seen["over"] and seen["winner"] == MatchController.NO_WINNER and seen["counts"] == _start
			and seen["hud"] == full and seen["choosing"] == [true, true] and seen["alive"] == [false, false], "%safter R %s, expected the Map's stock %s" % [tag, seen, _start])
	_kit.need(problems, _tk.over_lines(0).is_empty() and _tk.over_lines(1).is_empty() and _ui.flags_home().is_empty(), "%sa Round-over screen is shown, or %s" % [tag, _ui.flags_home()])
	for player: int in Kit.PLAYERS:
		_kit.need(problems, _ui.panel_clean(player, _start[player]).is_empty(), tag + _ui.panel_clean(player, _start[player]))
		await _ui.steer_to(player, Type.MOTORBIKE)
	var alive: Array[int] = await _ui.fire_both()
	await _kit.advance(Harness.SETTLE_TICKS)
	var limit: int = MatchController.SPAWN_SETTLE_TICKS + APPEAR_SLACK
	var messages: int = _tk.engine_log.errors.size() + _tk.engine_log.warnings.size() - logged
	_kit.need(problems, alive[0] >= 0 and alive[1] >= 0 and alive[0] <= limit and alive[1] <= limit, "%sthe Units were in play after %s ticks (limit %d)" % [tag, alive, limit])
	_kit.need(problems, _tk.events_of(&"over", mark).is_empty() and messages == 0, "%s%d round_over and %d engine messages since R" % [tag, _tk.events_of(&"over", mark).size(), messages])
	_notes[&"T30"].append("%s: R -> unpaused, not over, Tokens %s, Flags home, both choosing, no Round-over screen, panels %s | %s (cursors %s); fire keys -> in play after %s ticks (limit %d), no round_over, %d engine messages" % [
		label, _start[0], ",".join(seen["looks"][0]) + " " + ",".join(seen["panels"][0]), ",".join(seen["looks"][1]) + " " + ",".join(seen["panels"][1]), seen["cursor"], alive, limit, messages])


## True when both Players' Tokens lines are shown.
func _labels_shown() -> bool:
	return _ui.tokens_label(0).is_visible_in_tree() and _ui.tokens_label(1).is_visible_in_tree()


## Adds a problem to a check unless the condition holds.
func _need(check: StringName, holds: bool, problem: String) -> void:
	_kit.need(_problems[check], holds, problem)


## _need() for a fact the rest of the run stands on: when it fails the run stops after this phase.
func _require(check: StringName, holds: bool, problem: String) -> void:
	_need(check, holds, problem)
	if not holds and _stopped.is_empty():
		_stopped = problem


## Prints the five verdicts in the design's order (T28 runs first; the others fail when the run
## stopped early) and the RESULT line.
func _report() -> void:
	_tk.close()
	for id: StringName in NAMES:
		if not _stopped.is_empty() and id != &"T28":
			_problems[id].append("the run stopped before this check's evidence was complete (%s)" % _stopped)
		_kit.verdict(NAMES[id], _problems[id], " | ".join(_notes[id]))
	_h.finish("destroyed=%d started=%d over=%d errors=%d warnings=%d" % [_tk.events_of(&"destroyed").size(), _tk.events_of(&"started").size(),
		_overs.size(), _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])
