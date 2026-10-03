extends RefCounted
## Scenario token_choice of the split screen evidence harness (split_screen_harness.gd): Story 008's
## choice from the Tokens left (AC-3, and AC-5 for the types that run out), on a stock of Motorbike
## 3, Buggy 1, Truck 1, Gyrocopter 1 for each Player (STOCK_COUNTS), played with real key events
## (Tab and Enter Self-destruct, A, D and Right steer the cursor, Space and Period confirm and
## shoot, R restarts) and judged from the controller, both PlayerChoiceInputs and both choice
## panels. One Round walks it with nine destructions: Player 1's Truck (Tab alone, 16 steer presses,
## then the Buggy), Player 2's Gyrocopter shot dead (its fire key goes down inside the destruction's
## step), Player 2's first Motorbike (to change to the Truck), Player 1's Buggy and Player 2's Truck
## by Tab and Enter in one step, Player 1's Gyrocopter by Tab and Space in one step, then Player 1's
## three Motorbikes with nothing else left (the last by Tab and Space on the all-zero tick, which
## ends the Round), and R. Eight CHECK lines, every number measured. Each panel reading, inside the
## handler of every signal (the Token already taken) and a frame later, is judged against a model of
## the rule: a type with no Token is dim, and the slot under the cursor is marked only while its
## type has Tokens. The expected Tokens (the stock less the destructions made) are kept by the
## scenario, not read from the controller.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-3 and AC-5.
## Tooling only: nothing under src/ depends on this file. Helpers: token_choice_kit.gd, token_kit.gd
## and check_kit.gd.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=token_choice
##
## Kills: the wrong implementation each check fails, check by check.
##  T11  counts read once and never refreshed; the other Player's count shown; a restart that leaves
##       the old counts; a count typed in code.
##  T12  the slot under the cursor marked at 0 Tokens; a dim style without the dim text colour (or
##       the reverse, or on one label only); a colour removed instead of set, so the text takes the
##       theme's (a red Label theme is on the panel during the sweeps); the dim never undone at a
##       restart; the wrong slot, or the other Player's panel, dimmed.
##  T13  choose() without the Token guard, or the guard in the panel's input only; a cursor that
##       rests on a type with none; a steer key that skips in one direction only or fails to wrap; a
##       guard that reads the other Player's Tokens.
##  T14  the snap after the key read (the press swallowed); no snap; a snap that goes down, or to
##       the lowest type, or emits twice, or only when a key is pressed.
##  T15  a steer press with only the Motorbike open that moves the cursor off it or emits for no
##       move.
##  T16  the exhausted type chosen in its own destruction's step; a respawn timer restarted by the
##       choice; the exhausted slot undimmed during the countdown.
##  T17  one cursor for both Players; a guard that reads the other Player's Tokens; a Unit spawned
##       before its bench has settled; a respawn delay restarted by the choice.
##  T-ALLZERO  an unbounded cursor search (the process hangs, so no watchdog of the runner can
##             fire); a cursor moved to -1 or a choice accepted with no Token left; the panel left
##             over the Round-over screen; an engine ERROR or WARNING.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, real keys, the duel.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## This scenario's helpers (token_choice_kit.gd): the choice trail, the panel model, the steer
## sweep.
const ChoiceKit: GDScript = preload("res://tools/evidence/split_screen/token_choice_kit.gd")

## The Token stock the runner builds for this scenario, type_id to count, for each Player.
const STOCK_COUNTS: Dictionary = {&"motorbike": 3, &"buggy": 1, &"truck": 1, &"gyrocopter": 1}
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## The types as indexes into the data (T11 checks the data's order).
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }
## The checks as printed, by the short id the code uses, in numeric order with T-ALLZERO last.
const NAMES: Dictionary[StringName, String] = {&"T11": "T11_panel_counts", &"T12": "T12_zero_type_dimmed_unmarked",
	&"T13": "T13_zero_type_unchoosable", &"T14": "T14_first_tick_snap", &"T15": "T15_only_motorbike",
	&"T16": "T16_exhausted_by_this_destruction", &"T17": "T17_both_choose_same_tick", &"T-ALLZERO": "T-ALLZERO_last_motorbike_no_hang"}
## Presses of each steer key in a sweep: twice the number of Unit types.
const SWEEP_PRESSES: int = 8
## The steer presses tried with only the Motorbike open: A, D, both at once, D, A.
const IDLE_STEERS: Array = [[&"previous"], [&"next"], [&"previous", &"next"], [&"next"], [&"previous"]]
## Ticks the Round-over screen is watched after the all-zero tick.
const WATCH_TICKS: int = 10

## The runner, the check helpers, the Story 008 helpers and this scenario's own.
var _h: Harness
var _kit: Kit
var _tk: Tokens
var _ck: ChoiceKit
## The Tokens each Player must have now (the stock less the destructions made so far), the rows the
## Round started with, the type_ids of the data in order and the ticks a wait for a Unit may take.
var _rows: Array = []
var _start: Array = []
var _ids: Array[StringName] = []
var _limit: int = 0
## Per check: the problems and the measured notes; the checks whose evidence is complete; why the
## run stopped early, if it did; how many panel readings were judged and how many of them showed the
## two Players' panels different.
var _problems: Dictionary[StringName, PackedStringArray] = {}
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _closed: Array[StringName] = []
var _stopped: String = ""
var _readings: int = 0
var _differing: int = 0


## Runs the scenario; the phases are in the order of the Round. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_ck = ChoiceKit.new(_kit, _tk)
	var row: Array[int] = []
	for stats: UnitStats in _tk.controller.unit_types():
		_ids.append(stats.type_id)
		row.append(int(STOCK_COUNTS.get(stats.type_id, 0)))
	_start = [row, row.duplicate()]
	_rows = [row.duplicate(), row.duplicate()]
	_limit = _h.ticks_in(_tk.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	for id: StringName in NAMES:
		_problems[id] = PackedStringArray()
		_notes[id] = PackedStringArray()
	await _kit.advance(Kit.START_TICKS)
	_check_start()
	var phases: Array[Callable] = [_truck, _gyro_shot, _double_destruction, _gyro_destruct, _only_motorbike, _last_motorbike, _restart]
	for phase: Callable in phases:
		if _stopped.is_empty():
			_h.phase = StringName(String(phase.get_method()).trim_prefix("_"))
			_h.print_progress()
			await phase.call()
	await _kit.advance(2)
	_run_wide()
	_report()


## T11 and T12 at the start: the data's types, both stocks, both panels shown with the counts.
func _check_start() -> void:
	var seen: Dictionary = _tk.state()
	var shown: bool = _tk.units.panels[0].visible and _tk.units.panels[1].visible
	_need(&"T11", _ids == Tokens.Units.TYPE_IDS and seen["counts"] == _start and shown, "types %s, Tokens %s (expected %s) or a panel hidden at the start" % [_ids, seen["counts"], _start])
	_judge(seen, "start")
	_note(&"T11", "start: %s | %s" % [_ck.describe(seen, 0), _ck.describe(seen, 1)])


## Player 1's Truck (the last) Self-destructs, the cursor on it (T16, T12, T13, T14): it cannot be
## chosen in that step, the cursor snaps to the Gyrocopter, 16 steer presses skip it, and the Buggy
## chosen later appears on the delay counted from the destruction.
func _truck() -> void:
	if not _require(&"T16", await _tk.spawn(0, Type.TRUCK) and await _tk.spawn(1, Type.GYROCOPTER), "the Truck (p1) or the Gyrocopter (p2) did not appear"):
		return
	var refusal: Dictionary = {}
	_ck.arm(0, func() -> void: refusal.merge(_probe(0, Type.TRUCK)))
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	if not _require(&"T16", made["gone"].size() == 1, "Tab destroyed %d Units" % made["gone"].size()):
		return
	var frame: int = _snap(&"T14", "Tab on the Truck", made["mark"], 0, Type.GYROCOPTER, -1, 0)
	_spent_reading(made["gone"][0], 0, Type.TRUCK, "Truck destroyed", _spend(0, Type.TRUCK))
	var kept: bool = refusal.get("accepted", true) == false and refusal.get("choosing") == true and refusal.get("chosen") == -1 and refusal.get("frame") == frame
	for check: StringName in [&"T13", &"T16"]:
		_need(check, kept, "choose(Truck) inside the destruction's step: %s" % [refusal])
	await _sweeps(0, "countdown after the Truck")
	_refused("after the sweeps", 0, [Type.TRUCK])
	await _kit.press_settled(Tokens.keys(&"previous", 0))
	var cursor: int = _tk.units.panels[0].choice_input.cursor
	await _kit.press_settled(Tokens.keys(&"fire", 0))
	var ready: Dictionary = _tk.state()
	_judge(ready, "ready")
	var chosen: int = _ck.first_frame(made["mark"], &"chosen", 0)
	_need(&"T16", cursor == Type.BUGGY and _ck.since(made["mark"], &"chosen", 0).size() == 1 and _ck.since(made["mark"], &"chosen", 0)[0]["type"] == Type.BUGGY and ready["looks"][0][Type.TRUCK] == "dim" and not ready["looks"][0].has("cursor"), "A over the spent Truck left the cursor on %d; choices %s; ready state %s" % [cursor, _ck.since(made["mark"], &"chosen", 0), _ck.describe(ready, 0)])
	_require(&"T16", await _tk.units.wait_alive(0, _limit) >= 0, "the Buggy did not appear")
	var wait: int = _ck.first_frame(made["mark"], &"spawned", 0) - frame
	var expected: int = _h.ticks_in(_tk.controller.rules.respawn_delay_seconds)
	_need(&"T16", absi(wait - expected) <= Kit.TICK_SLACK and _tk.units.units[0].type_id == _ids[Type.BUGGY], "the Buggy appeared %d ticks after the destruction, expected %d +-%d" % [wait, expected, Kit.TICK_SLACK])
	_note(&"T16", "Truck destroyed f%d, choose(Truck) in that step -> %s; Buggy chosen f%d (%d ticks in), ready state %s; spawned %d ticks after the destruction (round(%.1f x %d) = %d, +-%d)" % [frame, refusal.get("accepted"), chosen, chosen - frame, _ck.describe(ready, 0), wait, _tk.controller.rules.respawn_delay_seconds, Engine.physics_ticks_per_second, expected, Kit.TICK_SLACK])
	_closed.append(&"T16")


## Player 2's Gyrocopter, the cursor on it, is shot dead by Player 1's Buggy (T14, T12): its fire
## key goes down inside the step, and the choice input reads it a frame later.
func _gyro_shot() -> void:
	var units: Array[Unit] = _tk.units.units
	if not _require(&"T14", units[0].is_alive and units[1].is_alive and units[1].type_id == _ids[Type.GYROCOPTER], "the Gyrocopter (p2) or the Buggy (p1) is not in play"):
		return
	await _tk.stage_duel(1)
	_ck.arm(1, func() -> void: _h.set_key(_h.fire_key(1), true))
	var made: Dictionary = await _destroy(_tk.shoot.bind(0))
	_h.set_key(_h.fire_key(1), false)
	if not _require(&"T14", made["gone"].size() == 1, "the Shot (node added in frame %d) destroyed %d Units" % [made["result"], made["gone"].size()]):
		return
	var frame: int = _snap(&"T14", "Shot kill, fire key down in the destruction's step", made["mark"], 1, Type.MOTORBIKE, Type.MOTORBIKE, 1)
	_spent_reading(made["gone"][0], 1, Type.GYROCOPTER, "Shot kill", _spend(1, Type.GYROCOPTER))
	_note(&"T14", "the Shot node was added in f%d and killed in f%d" % [made["result"], frame])


## Tab and Enter in one step on Player 1's Buggy and Player 2's Truck (T17): both snap in that
## frame.
func _double_destruction() -> void:
	if not _require(&"T17", await _tk.units.wait_alive(1, _limit) >= 0, "Player 2's Motorbike did not appear"):
		return
	await _tk.destruct(1)
	_spend(1, Type.MOTORBIKE)
	if not _require(&"T17", await _tk.spawn(1, Type.TRUCK), "Player 2's Truck did not appear"):
		return
	var made: Dictionary = await _destroy(_kit.press_settled.bind(Kit.KEYS_DESTRUCT_BOTH))
	var gone: Array = made["gone"]
	if not _require(&"T17", gone.size() == 2 and gone[0]["now"]["frame"] == gone[1]["now"]["frame"], "Tab and Enter in one step destroyed %d Units" % gone.size()):
		return
	_spent_reading(gone[0], 0, Type.BUGGY, "p1 Buggy", _spend(0, Type.BUGGY))
	_spent_reading(gone[1], 1, Type.TRUCK, "p2 Truck", _spend(1, Type.TRUCK))
	var frame: int = _snap(&"T17", "Tab+Enter", made["mark"], 0, Type.GYROCOPTER, -1, 0)
	_need(&"T17", _snap(&"T17", "Tab+Enter", made["mark"], 1, Type.MOTORBIKE, -1, 0) == frame, "the two destructions are in different frames")
	await _pair_and_choice(made["mark"], frame)


## Then (T17, T13): the Buggy is refused to Player 1 and accepted for Player 2 in one step; Player 1
## steers and chooses the Gyrocopter; both Units appear on their delay.
func _pair_and_choice(mark: int, frame: int) -> void:
	var stopped: Array[bool] = _refused("p1 (Buggy and Truck spent) while p2 still has its Buggy", 0, [Type.BUGGY, Type.TRUCK])
	var taken: Array[bool] = _ck.try_choose(1, [Type.BUGGY])
	_need(&"T17", stopped == [false, false] and taken == [true] and _tk.controller.chosen_type_index(1) == Type.BUGGY and _tk.controller.is_choosing(0), "in one step p1's choose(Buggy) answered %s and p2's %s; p2 chose %d" % [stopped, taken, _tk.controller.chosen_type_index(1)])
	await _sweeps(0, "countdown with the Buggy and the Truck spent")
	await _kit.press_settled(Tokens.keys(&"fire", 0))
	var alive: bool = await _tk.units.wait_alive(0, _limit) >= 0 and await _tk.units.wait_alive(1, _limit) >= 0
	var waits: PackedInt32Array = [_ck.first_frame(mark, &"spawned", 0) - frame, _ck.first_frame(mark, &"spawned", 1) - frame]
	var expected: int = _h.ticks_in(_tk.controller.rules.respawn_delay_seconds)
	var types: Array = _tk.units.units.map(func(unit: Unit) -> StringName: return unit.type_id)
	_need(&"T17", alive and absi(waits[0] - expected) <= Kit.TICK_SLACK and absi(waits[1] - expected) <= Kit.TICK_SLACK and types == [_ids[Type.GYROCOPTER], _ids[Type.BUGGY]], "the Units %s appeared %s ticks after the destruction, expected %d +-%d" % [types, waits, expected, Kit.TICK_SLACK])
	_note(&"T17", "Tab+Enter in f%d: both destroyed in that frame, cursors to the Gyrocopter and the Motorbike; one step later choose(Buggy) -> p1 %s, p2 %s; Gyrocopter (p1) and Buggy (p2) appeared %s ticks after the destruction (round(delay x %d) = %d)" % [frame, stopped, taken, waits, Engine.physics_ticks_per_second, expected])


## Player 1's Gyrocopter, the cursor on it, Self-destructs, the fire key pressed in the same step.
func _gyro_destruct() -> void:
	if not _require(&"T14", _tk.units.units[0].type_id == _ids[Type.GYROCOPTER] and _tk.units.panels[0].choice_input.cursor == Type.GYROCOPTER, "Player 1 does not drive the Gyrocopter with the cursor on it"):
		return
	var made: Dictionary = await _destroy(_kit.press_settled.bind(_keys(0, [&"destruct", &"fire"])))
	if not _require(&"T14", made["gone"].size() == 1, "Tab destroyed %d Units" % made["gone"].size()):
		return
	_snap(&"T14", "Tab + fire key in one step", made["mark"], 0, Type.MOTORBIKE, Type.MOTORBIKE, 0)
	_spent_reading(made["gone"][0], 0, Type.GYROCOPTER, "Self-destruct", _spend(0, Type.GYROCOPTER))
	_closed.append(&"T14")


## Only Motorbike Tokens left (T15): the steer keys move nothing, other types are refused, fire
## chooses.
func _only_motorbike() -> void:
	if not _require(&"T15", await _tk.units.wait_alive(0, _limit) >= 0 and _tk.units.units[0].type_id == _ids[Type.MOTORBIKE], "Player 1's Motorbike did not appear"):
		return
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	if not _require(&"T15", made["gone"].size() == 1, "Tab destroyed %d Units" % made["gone"].size()):
		return
	var seen: Dictionary = made["gone"][0]["now"]
	var after: Array = _spend(0, Type.MOTORBIKE)
	_need(&"T15", seen["counts"] == after and seen["cursor"][0] == Type.MOTORBIKE and seen["looks"][0] == PackedStringArray(["cursor", "dim", "dim", "dim"]) and seen["fonts"][0] == PackedStringArray(["normal", "dim", "dim", "dim"]), "after the Motorbike's destruction: %s, Tokens %s" % [_ck.describe(seen, 0), seen["counts"]])
	var mark: int = _ck.mark()
	for actions: Array in IDLE_STEERS:
		await _kit.press_settled(_keys(0, actions))
	var cursor: int = _tk.units.panels[0].choice_input.cursor
	_need(&"T15", _ck.since(mark, &"cursor").is_empty() and cursor == Type.MOTORBIKE and _tk.controller.is_choosing(0) and _tk.controller.chosen_type_index(0) == -1, "%d steer presses moved the cursor to %d (%d cursor_moved), choosing %s" % [IDLE_STEERS.size(), cursor, _ck.since(mark, &"cursor").size(), _tk.controller.is_choosing(0)])
	_refused("only the Motorbike has Tokens", 0, [Type.BUGGY, Type.TRUCK, Type.GYROCOPTER])
	await _kit.press_settled(Tokens.keys(&"fire", 0))
	var picks: Array[Dictionary] = _ck.since(mark, &"chosen")
	var up: bool = await _tk.units.wait_alive(0, _limit) >= 0
	_need(&"T15", picks.size() == 1 and picks[0]["type"] == Type.MOTORBIKE and up, "fire did not put the Motorbike in play: choices %s, in play %s" % [picks, up])
	_note(&"T15", "after the Motorbike's destruction: %s; %d steer presses (A, D, A+D, D, A) -> %d cursor_moved, cursor %d; fire -> the Motorbike chosen and in play" % [_ck.describe(seen, 0), IDLE_STEERS.size(), _ck.since(mark, &"cursor").size(), cursor])
	_closed.append(&"T15")


## Player 1's second Motorbike goes, then its last one, with the fire key pressed in the same step
## (T-ALLZERO): the Round ends in that frame, nothing is chosen.
func _last_motorbike() -> void:
	await _tk.destruct(0)
	_spend(0, Type.MOTORBIKE)
	if not _require(&"T-ALLZERO", await _tk.spawn(0, Type.MOTORBIKE), "Player 1's last Motorbike did not appear"):
		return
	var made: Dictionary = await _destroy(_kit.press_settled.bind(_keys(0, [&"destruct", &"fire"])))
	var over: Array[Dictionary] = _tk.events_of(&"over", made["events"])
	if not _require(&"T-ALLZERO", made["gone"].size() == 1 and over.size() == 1, "the last Motorbike's destruction gave %d unit_destroyed and %d round_over" % [made["gone"].size(), over.size()]):
		return
	var seen: Dictionary = made["gone"][0]["now"]
	var tail: Array = _ck.trail.slice(made["mark"])
	var kinds: Array = tail.map(func(entry: Dictionary) -> StringName: return entry["kind"])
	_need(&"T-ALLZERO", seen["counts"] == _spend(0, Type.MOTORBIKE) and seen["looks"][0] == PackedStringArray(["dim", "dim", "dim", "dim"]) and seen["cursor"][0] == Type.MOTORBIKE and not seen["over"] and kinds == [&"destroyed", &"over"] and tail[0]["shown"][0] and tail[1]["shown"] == [false, false], "inside the handler: %s, Tokens %s, over %s; signals since the press %s, panels shown at each %s" % [_ck.describe(seen, 0), seen["counts"], seen["over"], kinds, tail.map(func(entry: Dictionary) -> Array: return entry["shown"])])
	await _kit.advance(WATCH_TICKS)
	var c: MatchController = _tk.controller
	var shown: bool = _tk.units.panels[0].visible or _tk.units.panels[1].visible
	_need(&"T-ALLZERO", over[0]["arg"] == 1 and over[0]["now"]["frame"] == seen["frame"] and c.is_round_over() and c.winner_index() == 1 and _h.get_tree().paused and not shown, "round_over(%d) in f%d, unit_destroyed in f%d; over=%s winner=%d paused=%s a panel shown %s" % [over[0]["arg"], over[0]["now"]["frame"], seen["frame"], c.is_round_over(), c.winner_index(), _h.get_tree().paused, shown])
	_note(&"T-ALLZERO", "Tab + fire key on the last Motorbike: inside the handler %s; round_over(%d) in the same frame f%d, which hid the panel (shown %s inside the handler, %s at round_over), tree paused, no cursor move, no choice (signals %s), engine log empty" % [_ck.describe(seen, 0), over[0]["arg"], over[0]["now"]["frame"], tail[0]["shown"][0], tail[1]["shown"][0], kinds])
	_closed.append(&"T-ALLZERO")


## R (T12, T11, T17): full stocks, no dim; both fire keys in one step, both Units appear after the
## bench.
func _restart() -> void:
	var mark: int = _ck.mark()
	var restarted: bool = await _tk.restart()
	var seen: Dictionary = _tk.state()
	_judge(seen, "after R")
	var plain: bool = not seen["looks"][0].has("dim") and not seen["looks"][1].has("dim") and seen["fonts"] == [ChoiceKit.model_fonts(_start[0]), ChoiceKit.model_fonts(_start[1])]
	_need(&"T11", restarted and seen["counts"] == _start and seen["panels"] == [_tk.count_texts(0, _start[0]), _tk.count_texts(1, _start[1])], "after R: restarted %s, Tokens %s, panels %s, expected the stock %s" % [restarted, seen["counts"], seen["panels"], _start])
	_need(&"T12", plain and _tk.units.panels[0].visible and _tk.units.panels[1].visible, "after R: %s | %s" % [_ck.describe(seen, 0), _ck.describe(seen, 1)])
	_note(&"T12", "after R: %s | %s" % [_ck.describe(seen, 0), _ck.describe(seen, 1)])
	var both: Array[Key] = _keys(0, [&"fire"])
	both.append_array(_keys(1, [&"fire"]))
	await _kit.press_settled(both)
	var alive: bool = await _tk.units.wait_alive(0, GarageQueue.SPAWN_SETTLE_TICKS) >= 0 and await _tk.units.wait_alive(1, GarageQueue.SPAWN_SETTLE_TICKS) >= 0
	var start: int = _ck.first_frame(mark, &"started")
	var waits: PackedInt32Array = [_ck.first_frame(mark, &"spawned", 0) - start, _ck.first_frame(mark, &"spawned", 1) - start]
	_need(&"T17", alive and waits == PackedInt32Array([GarageQueue.SPAWN_SETTLE_TICKS, GarageQueue.SPAWN_SETTLE_TICKS]), "after R, both fire keys in one step: the Units appeared %s frames after the restart, expected %d each (the bench settle)" % [waits, GarageQueue.SPAWN_SETTLE_TICKS])
	_note(&"T17", "R in f%d, both fire keys in one step: both Units appeared %s frames after the restart (bench settle %d)" % [start, waits, GarageQueue.SPAWN_SETTLE_TICKS])
	_closed.append(&"T17")


## Makes a cause of a destruction (a coroutine Callable) and waits for its unit_destroyed: returns
## the trail and event marks before it ("mark", "events"), the destructions ("gone") and the
## "result".
func _destroy(cause: Callable) -> Dictionary:
	var made: Dictionary = {"mark": _ck.mark(), "events": _tk.events.size()}
	made["result"] = await cause.call()
	await _tk.wait_for(&"destroyed", made["events"])
	made["gone"] = _tk.events_of(&"destroyed", made["events"])
	return made


## T14 (T17 for two Players): the Player's destruction since `mark` was followed `gap` frames later
## (0: a Self-destruct, which runs before the choice input; 1: a Shot's kill, after it) by one
## cursor move to `to_type` and, when `chosen_type` is not -1, one choice of it with Tokens left.
## Returns its frame.
func _snap(check: StringName, label: String, mark: int, player: int, to_type: int, chosen_type: int, gap: int) -> int:
	var found: Array[Dictionary] = []
	var seq: Array[StringName] = []
	for entry: Dictionary in _ck.trail.slice(mark):
		if entry["player"] == player and [&"destroyed", &"cursor", &"chosen"].has(entry["kind"]):
			found.append(entry)
			seq.append(entry["kind"])
	var want: Array[StringName] = [&"destroyed", &"cursor"]
	if chosen_type >= 0:
		want.append(&"chosen")
	var frame: int = found[0]["frame"] if not found.is_empty() else -1
	var ok: bool = seq == want and found[1]["type"] == to_type and found[1]["frame"] == frame + gap
	if ok and chosen_type >= 0:
		ok = found[2]["type"] == chosen_type and found[2]["frame"] == frame + gap and found[2]["left"] > 0
	_need(check, ok, "%s: p%d expected %s (cursor to %d%s, %d frames after the destruction), got %s" % [label, player + 1, want, to_type, "" if chosen_type < 0 else ", choice of %d" % chosen_type, gap, found])
	_note(check, "%s: p%d %s" % [label, player + 1, " ".join(found.map(func(entry: Dictionary) -> String: return "%s%s@f%d" % [entry["kind"], "" if entry["type"] < 0 else "(%d)" % entry["type"], entry["frame"]]))])
	return frame


## T13: 8 presses of each steer key stop where the ring of the open types says, never on a type with
## none; a red Label Theme is on the panel meanwhile, so the colours read afterwards (T12) must be
## the scene's.
func _sweeps(player: int, label: String) -> void:
	var from: int = _tk.units.panels[player].choice_input.cursor
	var mark: int = _ck.mark()
	var odd: Theme = Theme.new()
	odd.set_color(&"font_color", &"Label", Color.RED)
	_tk.units.panels[player].theme = odd
	var back: PackedInt32Array = await _ck.sweep(player, &"previous", SWEEP_PRESSES)
	var forth: PackedInt32Array = await _ck.sweep(player, &"next", SWEEP_PRESSES)
	var want_back: PackedInt32Array = ChoiceKit.ring_stops(_rows[player], from, -1, SWEEP_PRESSES)
	var want_forth: PackedInt32Array = ChoiceKit.ring_stops(_rows[player], want_back[-1], 1, SWEEP_PRESSES)
	var spent: Array[int] = []
	for type_index: int in _rows[player].size():
		if _rows[player][type_index] <= 0:
			spent.append(type_index)
	var on_spent: int = 0
	for stop: int in back + forth:
		on_spent += 1 if spent.has(stop) else 0
	var moves: int = _ck.since(mark, &"cursor", player).size()
	_judge(_tk.state(), label)
	_tk.units.panels[player].theme = null
	_need(&"T13", back == want_back and forth == want_forth and on_spent == 0 and moves == 2 * SWEEP_PRESSES, "%s: A x%d from %d stopped at %s (model %s), D x%d at %s (model %s), %d stops on a type with none %s, %d cursor_moved" % [label, SWEEP_PRESSES, from, back, want_back, SWEEP_PRESSES, forth, want_forth, on_spent, spent, moves])
	_note(&"T13", "%s (Tokens %s, none left of %s): A x%d from %d -> %s, D x%d -> %s, one cursor_moved a press (%d), no stop on a type with none" % [label, _rows[player], spent, SWEEP_PRESSES, from, back, SWEEP_PRESSES, forth, moves])


## T13: a direct choose() of types the Player has no Token of changes nothing. Returns the answers.
func _refused(label: String, player: int, types: Array[int]) -> Array[bool]:
	var mark: int = _ck.mark()
	var answers: Array[bool] = _ck.try_choose(player, types)
	var c: MatchController = _tk.controller
	var picked: int = _ck.since(mark, &"chosen").size()
	_need(&"T13", not answers.has(true) and c.is_choosing(player) and c.chosen_type_index(player) == MatchController.NO_CHOICE and picked == 0, "%s: choose(p%d, %s) answered %s; choosing=%s chosen=%d, %d unit_chosen" % [label, player + 1, types, answers, c.is_choosing(player), c.chosen_type_index(player), picked])
	_note(&"T13", "%s: choose(p%d, %s) -> %s, still choosing, nothing chosen" % [label, player + 1, types, answers])
	return answers


## A direct choose() of the type, with what the controller says of the Player and the frame it was
## in.
func _probe(player: int, type_index: int) -> Dictionary:
	var accepted: bool = _tk.controller.choose(player, type_index)
	return {"accepted": accepted, "choosing": _tk.controller.is_choosing(player), "chosen": _tk.controller.chosen_type_index(player), "frame": Engine.get_physics_frames()}


## T11 (the Tokens) and T12: the reading inside a unit_destroyed handler, the cursor still on the
## type just spent: the Tokens are `rows`, its slot is dim in style and in both labels, and none is
## marked.
func _spent_reading(ev: Dictionary, player: int, type_index: int, label: String, rows: Array) -> void:
	var seen: Dictionary = ev["now"]
	var looks: PackedStringArray = seen["looks"][player]
	_need(&"T11", seen["counts"] == rows, "%s: the Tokens inside the handler are %s, expected %s" % [label, seen["counts"], rows])
	_need(&"T12", seen["cursor"][player] == type_index and looks[type_index] == "dim" and seen["fonts"][player][type_index] == "dim" and not looks.has("cursor"), "%s: with the cursor on the spent type %d the panel reads %s" % [label, type_index, _ck.describe(seen, player)])
	_note(&"T12", "%s: %s" % [label, _ck.describe(seen, player)])


## The Tokens the controller must show after a Unit of this type of this Player is destroyed.
func _spend(player: int, type_index: int) -> Array:
	_rows = Tokens.charged(_rows, player, type_index)
	return _rows


## T11 and T12 against the model for one state() reading: each panel's count lines are the format of
## the Tokens and, when it is shown, its styles and text colours are the model's.
func _judge(seen: Dictionary, label: String) -> void:
	_readings += 1
	_differing += 1 if seen["panels"][0] != seen["panels"][1] else 0
	for player: int in Kit.PLAYERS:
		var row: Array = seen["counts"][player]
		_need(&"T11", seen["panels"][player] == _tk.count_texts(player, row), "%s: p%d panel reads %s but its Tokens are %s" % [label, player + 1, seen["panels"][player], row])
		var shown: bool = not seen["over"] and (seen["choosing"][player] or seen["chosen"][player] >= 0)
		var looks: PackedStringArray = ChoiceKit.model_looks(row, seen["cursor"][player], seen["choosing"][player])
		_need(&"T12", not shown or (seen["looks"][player] == looks and seen["fonts"][player] == ChoiceKit.model_fonts(row)), "%s: %s, expected %s %s" % [label, _ck.describe(seen, player), looks, ChoiceKit.model_fonts(row)])


## The checks that span the run: every reading against the model (T11, T12), no accepted choice of a
## type with none (T13), no engine ERROR or WARNING (T-ALLZERO).
func _run_wide() -> void:
	for event: Dictionary in _tk.events:
		for key: String in ["now", "later"]:
			if not event[key].is_empty():
				_judge(event[key], "%s of %s p%d f%d" % [key, event["kind"], event["arg"] + 1, event["now"]["frame"]])
	var empty: Array = _ck.trail.filter(func(entry: Dictionary) -> bool: return entry["kind"] == &"chosen" and entry["left"] <= 0)
	_need(&"T13", empty.is_empty(), "choices of a type with no Token left were accepted: %s" % [empty])
	_note(&"T13", "all %d choices of the run were of a type with Tokens left" % _ck.since(0, &"chosen").size())
	_note(&"T11", "%d readings (every signal of the run inside its handler and a frame later, and the explicit ones): both panels equal the format of the controller's Tokens; the two Players' panels differed in %d" % [_readings, _differing])
	_need(&"T11", _differing > 0, "the two Players' panels never differed")
	_need(&"T-ALLZERO", _tk.engine_log.errors.is_empty() and _tk.engine_log.warnings.is_empty(), "the engine logged errors %s and warnings %s" % [_tk.engine_log.errors, _tk.engine_log.warnings])
	if _stopped.is_empty():
		_closed.append_array([&"T11", &"T12", &"T13"])


## The keys of these actions (&"destruct", &"fire", &"previous", &"next") for a Player, in one step.
func _keys(player: int, actions: Array) -> Array[Key]:
	var keys: Array[Key] = []
	for action: StringName in actions:
		keys.append_array(Tokens.keys(action, player))
	return keys


## Adds a problem to a check unless the condition holds.
func _need(check: StringName, holds: bool, problem: String) -> void:
	_kit.need(_problems[check], holds, problem)


## _need() for a fact the rest of the run stands on: when it fails the run stops after this phase.
func _require(check: StringName, holds: bool, problem: String) -> bool:
	_need(check, holds, problem)
	if not holds and _stopped.is_empty():
		_stopped = problem
	return holds


## Adds a measured note to a check.
func _note(check: StringName, text: String) -> void:
	_notes[check].append(text)


## Prints the eight verdicts (a check whose evidence was not completed fails) and the RESULT line.
func _report() -> void:
	_tk.close()
	for id: StringName in NAMES:
		if not _closed.has(id):
			_problems[id].append("the run stopped before this check's evidence was complete (%s)" % _stopped)
		_kit.verdict(NAMES[id], _problems[id], " | ".join(_notes[id]))
	_h.phase = &"end"
	_h.finish("destroyed=%d chosen=%d cursor_moves=%d spawned=%d readings=%d errors=%d warnings=%d" % [
		_tk.events_of(&"destroyed").size(), _ck.since(0, &"chosen").size(), _ck.since(0, &"cursor").size(), _tk.events_of(&"spawned").size(),
		_readings, _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])
