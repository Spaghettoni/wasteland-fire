extends RefCounted
## Scenario tokens_data of the split screen evidence harness (split_screen_harness.gd): Story 008's
## Token stock as DATA (AC-1, AC-2, AC-4, AC-9) on a fixture that differs from Map 01's in every
## count: motorbike 2, buggy 0, truck 7, gyrocopter 1 (STOCK_COUNTS; the runner builds the stock).
## Two Rounds with real key events (steer and fire choose, Tab destroys, R restarts). Both Players
## start with the fixture on the controller, the HUD and the panel; with both Motorbikes in play
## begin() is refused nine ways, each twice, on a throwaway MatchController handed the live Units,
## Bases and cameras (no call of the scenario is meant to go through on them); Player 1 then spends
## a Motorbike, a Unit of a type the data does not know, a Truck (the controller now holds a copy of
## the rules with the types in reverse order and half the respawn delay, which stays in it to the
## end of the second Round) and its last Motorbike, which ends the Round. R restarts it under the
## copy, so the ledger's start() reads the types in reverse order, and a second Round runs to its
## end: the Gyrocopter, the type listed first in the copy, and then the Motorbike twice. Six CHECK
## lines, every number measured, the expected counts read from the fixture.
## Shared helpers: tokens_data_kit.gd, token_kit.gd, check_kit.gd, unit_kit.gd.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1, AC-2,
## AC-4 and AC-9. Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=tokens_data
##
## The lint of T33 is a plain text scan of every .gd under src/gameplay/match and src/ui/hud, line
## by line, quoted text and comments left out. It flags an integer literal other than 0 and 1 on a
## line that names a Token count (tokens_left, count_of, can_choose, has_lost, take, counts, stock,
## the ledger or the stock types) or declares a name holding token, stock or count. It cannot see a
## literal on another line than the name (a variable given a 5 and used later), a number written
## 0x5, 1_000 or 5.0, a literal handed to a format, a count in a .tscn or .tres (where data belongs)
## or a file outside the two folders; the Round judges the rest, on counts the code cannot guess.
##
## Kills: the wrong implementation each check fails, check by check.
##  T01b  counts copied from anything but the fixture (the Map's numbers, a constant, a type or a
##        Player left out); a HUD line or panel that does not show them at the start or at R (R
##        reads them in the order of the types listed then); a dim applied only after a count
##        changes; a cursor that leaves the Motorbike because the Buggy beside it is empty.
##  T03   a begin() that benches, connects, emits or sets state before refusing a stock with no
##        Motorbike Token; two errors; an error that does not name the Motorbike; one that begins.
##  T04   one of the eight stocks and rules accepted (an unknown key, a duplicate type_id, a type
##        without a type_id, two carrier types ...) or refused with two errors, a text that does
##        not name the problem, one text for all of them, or a side effect.
##  T33   a count or the loss threshold written as a number in the code (a 5 for the starting
##        count or the loss, or any literal beside a Token count even if no run reaches it); a
##        Round that does not end on the destruction of the fixture's last Motorbike (never, a
##        frame late, or only while the Motorbike is listed first) or ends earlier; a respawn
##        delay that is not the rules' (the copy of the rules in T35 has half of it).
##  T34   a Unit of a type the data does not know that takes a Token (the Motorbike's included),
##        ends the Round, is not warned about once, or logs an error.
##  T35   with the types in reverse order: a ledger or a count read by position in unit_types()
##        and not by type_id (a destroyed Truck charged to another type); the carrier assumed at
##        index 0 by carrier_type_index() or by the HUD; a start() at R that takes the first type
##        of the list for the carrier or keeps the place the carrier had; a loss read at the first
##        place of the list (the copy lists the Gyrocopter first: the HUD line then reads
##        Gyrocopter and its one Token ends the Round).

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, choices, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The refusals and the lint (tokens_data_kit.gd).
const Data: GDScript = preload("res://tools/evidence/split_screen/tokens_data_kit.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## The Token stock the runner builds for this scenario (type_id to count); not Map 01's anywhere.
const STOCK_COUNTS: Dictionary = {&"motorbike": 2, &"buggy": 0, &"truck": 7, &"gyrocopter": 1}
## Map 01's own stock, to show the fixture differs from it in every count.
const MAP_STOCK_PATH: String = "res://src/gameplay/maps/data/token_stock.tres"
## The types as indexes into the data's order (T01b checks the order): good while the controller
## lists them that way, which ends when T35's copy of the rules goes in.
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }
## The checks as printed, by the short id the code uses, in the design's order.
const NAMES: Dictionary[StringName, String] = {&"T01b": "T01b_start_from_data",
	&"T03": "T03_refuses_no_carrier_token", &"T04": "T04_refusal_variants",
	&"T33": "T33_data_not_constants", &"T34": "T34_unknown_type_destroyed", &"T35": "T35_rules_swap"}
## A type id the data and the stock do not hold: the Unit T34 destroys is of this type.
const UNKNOWN_TYPE_ID: StringName = &"hovercraft"
## Ticks both Units stand in play before the refusals are tried.
const IN_PLAY_TICKS: int = 30
## T35 gives its copy of the rules this share of the respawn delay, as the destruction scenario's.
const OTHER_DELAY_FACTOR: float = 0.5

var _h: Harness
var _kit: Kit
var _tk: Tokens
var _data: Data
var _stock: TokenStock
var _original: MatchRules
## The type_ids of the data in order, and the respawn delay in force at each of Player 1's
## destructions.
var _ids: Array[StringName] = []
var _delays: Array[float] = []
var _problems: Dictionary[StringName, PackedStringArray] = {}
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _closed: Array[StringName] = []
var _stopped: String = ""
var _lint: Dictionary = {}
var _refusals: int = 0
## The warnings the engine log held when T35's copy of the rules went into the controller.
var _warned: int = 0


## Runs the scenario; the phases are in the order of the Round. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_data = Data.new(harness, _tk)
	_stock = _h.split.field.token_stock
	_original = _tk.controller.rules
	for stats: UnitStats in _tk.controller.unit_types():
		_ids.append(stats.type_id)
	for id: StringName in NAMES:
		_problems[id] = PackedStringArray()
		_notes[id] = PackedStringArray()
	_check_start()
	_check_lint()
	await _kit.advance(Kit.START_TICKS)
	var phases: Array[Callable] = [_in_play, _refuse, _first_motorbike, _unknown_type,
		_swapped_rules, _last_motorbike, _restart, _swapped_round]
	for phase: Callable in phases:
		if _stopped.is_empty():
			await phase.call()
	_report()


## T01b at the first frame (and T33's Truck x7 and dim Buggy): both Players choosing with the
## fixture on the controller, the HUD and the panel, the Buggy dim, the cursor on the Motorbike.
func _check_start() -> void:
	var seen: Dictionary = _tk.state()
	var map_stock: TokenStock = load(MAP_STOCK_PATH) as TokenStock
	var differs: PackedStringArray = []
	for id: StringName in STOCK_COUNTS:
		differs.append("%s %d/%d" % [id, STOCK_COUNTS[id], map_stock.count_of(id) if map_stock != null else -1])
		_need(&"T01b", map_stock != null and map_stock.count_of(id) != STOCK_COUNTS[id], "the fixture's %s equals the Map's: a wrong stock could not be told from it" % id)
	_need(&"T01b", _ids == Tokens.Units.TYPE_IDS and _tk.carrier_index() == Type.MOTORBIKE, "the data's types %s or its carrier %d are not the order the scenario expects" % [_ids, _tk.carrier_index()])
	_need(&"T01b", _stock != null and _stock.counts.size() == STOCK_COUNTS.size(), "the Map's field does not hold the fixture")
	_need(&"T03", _tk.controller.unit_types().all(func(stats: UnitStats) -> bool: return not stats.display_name.is_empty()), "a Unit type has no display_name: the refusals could not name it")
	_need(&"T01b", _reads_fixture(seen, true).is_empty(), "at the first frame: " + _reads_fixture(seen, true))
	var truck: String = seen["panels"][0][Type.TRUCK]
	var buggy: String = seen["looks"][0][Type.BUGGY]
	_need(&"T33", truck == _tk.count_texts(0, _fixture()[0])[Type.TRUCK] and buggy == "dim", "the Truck slot reads %s and the Buggy slot is %s" % [truck, buggy])
	_note(&"T01b", "frame %d, fixture/Map %s: Tokens p1=%s p2=%s | HUD \"%s\" \"%s\" | panels %s | looks %s %s | cursor %s" % [seen["frame"], ", ".join(differs), seen["counts"][0], seen["counts"][1], seen["hud"][0], seen["hud"][1], seen["panels"][0], seen["looks"][0], seen["looks"][1], seen["cursor"]])
	_note(&"T33", "Truck slot %s and Buggy slot %s from the first frame (fixture truck %d, buggy %d)" % [truck, buggy, STOCK_COUNTS[_ids[Type.TRUCK]], STOCK_COUNTS[_ids[Type.BUGGY]]])


## T33, the lint: no integer literal other than 0 and 1 on a line that names a Token count in
## src/gameplay/match and src/ui/hud; and the lint flags the shapes of a hardcoded count.
func _check_lint() -> void:
	_lint = _data.scan()
	var wrong: PackedStringArray = _data.self_test()
	_need(&"T33", _lint["files"] > 0 and _lint["code"] > 0, "the lint read no code")
	_need(&"T33", _lint["flagged"].is_empty(), "integer literals on a line that names a Token count: %s" % [_lint["flagged"]])
	_need(&"T33", wrong.is_empty(), "the lint answers wrongly for: %s" % [wrong])
	_note(&"T33", "lint: %d files, %d code lines, %d integer literals other than 0 and 1 (%s), %d on a line that names a Token count; self-test %d of %d lines right" % [_lint["files"], _lint["code"], _lint["literals"], ", ".join(_lint["others"]), _lint["flagged"].size(), Data.LINT_CASES.size() - wrong.size(), Data.LINT_CASES.size()])


## After the start ticks (Kit.START_TICKS) the first frame still reads as the fixture; then both
## Players choose the Motorbike with their keys and stand in play.
func _in_play() -> void:
	_need(&"T01b", _reads_fixture(_tk.state(), true).is_empty(), "%d ticks in: %s" % [Kit.START_TICKS, _reads_fixture(_tk.state(), true)])
	if _require(&"T03", await _tk.spawn(0, Type.MOTORBIKE) and await _tk.spawn(1, Type.MOTORBIKE), "a Motorbike did not appear"):
		await _kit.advance(IN_PLAY_TICKS)


## T03 and T04: begin() refused on a throwaway controller with the live Units, one error each call.
func _refuse() -> void:
	var list: Array[Dictionary] = _data.variants(STOCK_COUNTS)
	var errors: Array = []
	var signals: Array[int] = []
	var listened: int = 0
	for index: int in list.size():
		var check: StringName = &"T03" if index == 0 else &"T04"
		var made: Dictionary = _data.refuse(list[index])
		for problem: String in made["problems"]:
			_problems[check].append("%s: %s" % [list[index]["label"], problem])
		errors.append(made["errors"])
		signals.append(made["signals"])
		listened = made["listened"]
		_note(check, "%s -> \"%s\"" % [list[index]["label"], made["message"]])
		list[index]["message"] = made["message"]
	_refusals = list.size()
	await _kit.advance(2)
	var seen: Dictionary = _tk.state()
	var texts: Dictionary = {}
	for index: int in range(1, list.size()):
		texts[list[index]["message"]] = true
	_need(&"T03", seen["alive"] == [true, true] and seen["choosing"] == [false, false] and seen["counts"] == _fixture() and _tk.events_of(&"started").is_empty(), "the live Round changed: alive %s choosing %s Tokens %s" % [seen["alive"], seen["choosing"], seen["counts"]])
	_need(&"T04", _tk.engine_log.errors.size() == 2 * _refusals and _tk.engine_log.warnings.is_empty(), "the engine log holds %d errors and %d warnings after %d refusals, each made twice" % [_tk.engine_log.errors.size(), _tk.engine_log.warnings.size(), _refusals])
	_need(&"T04", texts.size() == _refusals - 1, "the %d refusals of T04 gave only %d different texts" % [_refusals - 1, texts.size()])
	_note(&"T04", "%d refusals, each made twice: errors per call %s, signals %s of %d listened to, the live Units' destroyed links %s unchanged; engine log %d errors %d warnings; %d different texts; live Units alive 2 ticks later %s" % [_refusals, errors, signals, listened, _data.links(), _tk.engine_log.errors.size(), _tk.engine_log.warnings.size(), texts.size(), seen["alive"]])
	_closed.append_array([&"T03", &"T04"])


## T33, the first half: Player 1's first Motorbike is destroyed by Tab and costs one Token; the
## Round runs on with the Motorbikes the fixture gives, less one.
func _first_motorbike() -> void:
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	var wanted: Array = Tokens.charged(made["before"], 0, Type.MOTORBIKE)
	_need(&"T33", made["before"] == _fixture(), "with both Motorbikes in play Tokens are %s, not the fixture %s (a Token is taken at the destruction)" % [made["before"], _fixture()])
	_judge(&"T33", made, 0, _ids[Type.MOTORBIKE], wanted, "Tab on the first Motorbike")
	_need(&"T33", not _tk.controller.is_round_over() and _tk.events_of(&"over").is_empty(), "the Round ended with a Motorbike Token left (%d)" % wanted[0][Type.MOTORBIKE])
	_note(&"T33", "Tab on Player 1's first Motorbike: Tokens %s -> %s, the Round runs" % [made["before"][0], _tk.counts()[0]])


## T34: a Unit of a type outside the data (the Truck's stats with another type_id), put over
## Player 1's Truck by a tool, is destroyed with one Motorbike Token left: one warning, no Token,
## no loss.
func _unknown_type() -> void:
	if not _require(&"T34", await _tk.spawn(0, Type.TRUCK), "Player 1's Truck did not appear"):
		return
	var alien: UnitStats = _tk.units.stats(Type.TRUCK).duplicate() as UnitStats
	alien.type_id = UNKNOWN_TYPE_ID
	_tk.units.units[0].spawn(_tk.units.units[0].global_transform, alien)
	_tk.units.cameras[0].snap_to_target()
	await _kit.advance(Tokens.Units.SETTLE_TICKS)
	var warned: int = _tk.engine_log.warnings.size()
	var failed: int = _tk.engine_log.errors.size()
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	var last: String = _tk.engine_log.warnings[-1] if _tk.engine_log.warnings.size() > warned else ""
	_need(&"T34", made["before"][0][Type.MOTORBIKE] == 1, "Player 1 had %d Motorbike Tokens, not the one that makes a wrong take a loss" % made["before"][0][Type.MOTORBIKE])
	_judge(&"T34", made, 0, UNKNOWN_TYPE_ID, made["before"], "Tab on the Unit of type %s" % UNKNOWN_TYPE_ID)
	_need(&"T34", _tk.engine_log.warnings.size() == warned + 1 and last.contains(String(UNKNOWN_TYPE_ID)), "%d warnings (the last \"%s\"), not one that names '%s'" % [_tk.engine_log.warnings.size() - warned, last, UNKNOWN_TYPE_ID])
	_need(&"T34", _tk.engine_log.errors.size() == failed and not _tk.controller.is_round_over() and _tk.events_of(&"over").is_empty(), "an error was logged or the Round ended")
	_note(&"T34", "a Unit of type %s destroyed with 1 Motorbike Token left: Tokens stay %s, warning \"%s\", the Round runs (over %s)" % [UNKNOWN_TYPE_ID, _tk.counts()[0], last, _tk.controller.is_round_over()])
	_closed.append(&"T34")


## T35, the first half: Player 1's Truck is destroyed while the controller holds a copy of the rules
## with the types in reverse order and half the delay, which stays in it to the end of the second
## Round: the Truck's count falls and no other, read by type_id, and the carrier is found where the
## Motorbike is listed now.
func _swapped_rules() -> void:
	if not _require(&"T35", await _tk.spawn(0, Type.TRUCK), "Player 1's Truck did not appear"):
		return
	var reversed: Array[UnitStats] = []
	reversed.assign(_original.unit_types)
	reversed.reverse()
	var copy: MatchRules = _original.duplicate() as MatchRules
	copy.unit_types = reversed
	copy.respawn_delay_seconds = _original.respawn_delay_seconds * OTHER_DELAY_FACTOR
	var charged: Array[Dictionary] = [_by_id(0), _by_id(1)]
	charged[0][_ids[Type.TRUCK]] -= 1
	_warned = _tk.engine_log.warnings.size()
	_tk.controller.rules = copy
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	var inside: Array[Dictionary] = [_by_id(0), _by_id(1)]
	var carrier: int = _tk.controller.carrier_type_index()
	var motorbike: StringName = _ids[Type.MOTORBIKE]
	_need(&"T35", made["count"] == 1 and made["event"]["type"] == _ids[Type.TRUCK], "expected one destruction of a Truck, got %d" % made["count"])
	_need(&"T35", inside == charged, "by type_id Tokens are %s, expected %s (one Truck less, nothing else)" % [inside, charged])
	_need(&"T35", carrier >= 0 and reversed[carrier].type_id == motorbike and _tk.controller.tokens_left(0, carrier) == charged[0][motorbike], "carrier_type_index() %d or its count is wrong in the reversed order" % carrier)
	_need(&"T35", _tk.hud_line(0) == _tk.hud_text(0, charged[0][motorbike]) and _tk.hud_line(1) == _tk.hud_text(1, charged[1][motorbike]), "the HUD lines \"%s\" \"%s\" do not show the Motorbike Tokens %s" % [_tk.hud_line(0), _tk.hud_line(1), charged])
	_note(&"T35", "types listed as %s, delay %.2f s: Truck destroyed -> by id P1 %s, carrier index %d" % [reversed.map(func(stats: UnitStats) -> StringName: return stats.type_id), copy.respawn_delay_seconds, inside[0], carrier])


## T33, the second half: Player 1's last Motorbike Token goes with Tab, under the copy of the rules
## (the Motorbike is listed last in it): the Round ends on that frame, after exactly the
## destructions the fixture gives, and Player 2 wins with its stock whole.
func _last_motorbike() -> void:
	if not _require(&"T33", await _tk.spawn(0, _tk.carrier_index()), "Player 1's Motorbike did not appear"):
		return
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	var over: Array[Dictionary] = _tk.events_of(&"over")
	var winners: Array = over.map(func(event: Dictionary) -> int: return event["arg"])
	var frames: Array = over.map(func(event: Dictionary) -> int: return event["now"]["frame"])
	var lost: int = _tk.events_of(&"destroyed").filter(func(event: Dictionary) -> bool: return event["arg"] == 0 and event["type"] == _ids[Type.MOTORBIKE]).size()
	var fixture: int = STOCK_COUNTS[_ids[Type.MOTORBIKE]]
	var frame: Variant = made["event"]["now"].get("frame")
	var mine: Dictionary = _by_id(0)
	_need(&"T33", winners == [1] and _tk.controller.is_round_over() and _tk.controller.winner_index() == 1, "round_over came with the winners %s, the Round over %s" % [winners, _tk.controller.is_round_over()])
	_need(&"T33", lost == fixture and frames == [frame], "the Round ended after %d Motorbike destructions on frames %s, the fixture gives %d on frame %s" % [lost, frames, fixture, frame])
	_need(&"T33", _tk.counts()[1] == _fixture()[1] and mine[_ids[Type.MOTORBIKE]] == 0 and mine[_ids[Type.TRUCK]] == STOCK_COUNTS[_ids[Type.TRUCK]] - 1, "Tokens after the loss %s" % [mine])
	_note(&"T33", "Round over after %d Motorbike destructions (fixture %d), on the frame of the destruction (%s), winner Player %d; Tokens by type_id p1=%s p2=%s" % [lost, fixture, frame, _tk.controller.winner_index() + 1, mine, _by_id(1)])


## R, with the copy of the rules still in the controller (T35): start() reads the types in reverse
## order. Both stocks are the fixture again (T01b at the round_started handler and a frame later,
## the Buggy dim again), the carrier is the Motorbike where it is listed now (T35), and each
## respawn took the delay in force (T33).
func _restart() -> void:
	var seen: int = _tk.events.size()
	var restarted: bool = await _tk.restart()
	await _kit.advance(2)
	var started: Array[Dictionary] = _tk.events_of(&"started", seen)
	_need(&"T01b", restarted and started.size() == 1 and _tk.units.panels[0].visible and _tk.units.panels[1].visible, "R did not restart the Round with both panels showing")
	for key: String in ["now", "later"]:
		var problem: String = _reads_fixture(started[0][key], false) if not started.is_empty() else "no round_started"
		_need(&"T01b", problem.is_empty(), "at R (%s): %s" % [key, problem])
	var read: Dictionary = started[0]["now"] if not started.is_empty() else {"frame": -1, "counts": "-", "looks": ["-", "-"], "cursor": "-"}
	_note(&"T01b", "R under T35's copy (types in reverse order): round_started on frame %d reads Tokens %s, looks %s %s, cursors %s" % [read["frame"], read["counts"], read["looks"][0], read["looks"][1], read["cursor"]])
	_need(&"T33", _tk.counts() == _fixture(), "R left Tokens %s, the fixture is %s" % [_tk.counts(), _fixture()])
	_check_swapped_start(started)
	_check_delays()
	_closed.append_array([&"T01b", &"T33"])


## T35 at R, where start() ran on the list in reverse order: the Motorbike is not listed first, the
## controller names it the carrier at the place it is listed now, and both HUD lines read its Tokens
## in the round_started handler, a frame later and now.
func _check_swapped_start(started: Array[Dictionary]) -> void:
	var listed: int = _tk.carrier_index()
	var carrier: int = _tk.controller.carrier_type_index()
	var motorbike: StringName = _ids[Type.MOTORBIKE]
	var want: Array = [_tk.hud_text(0, STOCK_COUNTS[motorbike]), _tk.hud_text(1, STOCK_COUNTS[motorbike])]
	var lines: Array = []
	if not started.is_empty():
		lines = [started[0]["now"]["hud"], started[0]["later"]["hud"], [_tk.hud_line(0), _tk.hud_line(1)]]
	_need(&"T35", listed > 0, "the Motorbike is listed at %d in the copy, not after the first place: the swap shows nothing at R" % listed)
	_need(&"T35", carrier == listed and carrier >= 0 and _tk.controller.unit_types()[carrier].type_id == motorbike, "after R carrier_type_index() is %d, the Motorbike is listed at %d" % [carrier, listed])
	_need(&"T35", lines == [want, want, want], "after R the HUD lines are %s, expected %s three times" % [lines, want])
	_note(&"T35", "R under the copy: carrier_type_index() %d, the Motorbike listed at %d, HUD lines %s" % [carrier, listed, want])


## T33: from each of Player 1's destructions to its next spawn is the respawn delay in force at the
## destruction, in ticks as the runner counts them.
func _check_delays() -> void:
	var gone: Array[Dictionary] = _tk.events_of(&"destroyed").filter(func(event: Dictionary) -> bool: return event["arg"] == 0)
	var back: Array[Dictionary] = _tk.events_of(&"spawned").filter(func(event: Dictionary) -> bool: return event["arg"] == 0)
	var lengths: PackedInt32Array = []
	var expected: PackedInt32Array = []
	for index: int in mini(back.size() - 1, gone.size()):
		lengths.append(back[index + 1]["now"]["frame"] - gone[index]["now"]["frame"])
		expected.append(_h.ticks_in(_delays[index]))
		_need(&"T33", absi(lengths[index] - expected[index]) <= Kit.TICK_SLACK, "respawn %d took %d ticks, the delay in force (%.2f s) gives %d" % [index + 1, lengths[index], _delays[index], expected[index]])
	_need(&"T33", lengths.size() == gone.size() - 1, "%d respawns were measured after %d destructions" % [lengths.size(), gone.size()])
	_note(&"T33", "respawn ticks %s against the delays in force %s s = %s" % [lengths, _delays.slice(0, lengths.size()), expected])


## T35, the second half: the Round R started under the copy runs to its end with Player 1's
## destructions: the Gyrocopter (listed first, one Token) ends nothing, the Motorbike's first Token
## leaves the Round running and its last ends it. The rules are put back after that.
func _swapped_round() -> void:
	var mark: int = _tk.events.size()
	var first: int = STOCK_COUNTS[_tk.units.stats(0).type_id]
	_need(&"T35", first == 1, "the type listed first has %d Tokens in the fixture: one destruction does not empty it" % first)
	for type_index: int in [0, _tk.carrier_index(), _tk.carrier_index()]:
		if not await _swapped_step(type_index, mark):
			return
	var left: Array[Dictionary] = [_by_id(0), _by_id(1)]
	_tk.controller.rules = _original
	var back: Array = _tk.counts()
	var rows: Array = [_row(left[0]), _row(left[1])]
	_need(&"T35", [_by_id(0), _by_id(1)] == left and back == rows, "with the rules put back Tokens are %s, expected %s" % [back, rows])
	_need(&"T35", _tk.engine_log.warnings.size() == _warned and _original.unit_types.map(func(stats: UnitStats) -> StringName: return stats.type_id) == _ids, "a warning was logged or the shared rules changed")
	_note(&"T35", "rules put back: P1 %s P2 %s" % [back[0], back[1]])
	_closed.append(&"T35")


## One destruction of T35's second Round: Player 1 chooses the type at type_index of the list in
## force, it appears and goes with Tab. It costs one Token of its type_id and nothing else, and the
## Round ends when, and only when, that emptied the Motorbike, with Player 2 the winner. False when
## the Unit did not appear (the run stops).
func _swapped_step(type_index: int, mark: int) -> bool:
	var type_id: StringName = _tk.units.stats(type_index).type_id
	if not _require(&"T35", await _tk.spawn(0, type_index), "Player 1's %s did not appear in the second Round" % type_id):
		return false
	var made: Dictionary = await _destroy(_tk.destruct.bind(0))
	var wanted: Array = Tokens.charged(made["before"], 0, type_index)
	var ends: bool = wanted[0][type_index] == 0 and type_id == _ids[Type.MOTORBIKE]
	var seen: Array = [_tk.controller.is_round_over(), _tk.events_of(&"over", mark).map(func(event: Dictionary) -> int: return event["arg"]), _tk.controller.winner_index()]
	var expected: Array = [true, [1], 1] if ends else [false, [], MatchController.NO_WINNER]
	_need(&"T35", made["count"] == 1 and made["event"]["type"] == type_id and _tk.counts() == wanted, "second Round, %s destroyed: %d destructions, Tokens %s, expected %s" % [type_id, made["count"], _tk.counts(), wanted])
	_need(&"T35", seen == expected, "second Round, %s destroyed: Round over, round_over winners and winner_index() are %s, expected %s" % [type_id, seen, expected])
	_note(&"T35", "second Round: %s destroyed -> P1 %s, %s" % [type_id, _by_id(0), "Round over, Player 2 wins" if ends else "the Round runs"])
	return true


## One destruction: `cause` (a coroutine Callable: a key) is made and the unit_destroyed it brings
## is waited for. {before: the Tokens before, event: the one event, count: how many}; the respawn
## delay in force is filed in _delays.
func _destroy(cause: Callable) -> Dictionary:
	var mark: int = _tk.events.size()
	var before: Array = _tk.counts()
	_delays.append(_tk.controller.rules.respawn_delay_seconds)
	await cause.call()
	await _tk.wait_for(&"destroyed", mark)
	var found: Array[Dictionary] = _tk.events_of(&"destroyed", mark)
	return {"before": before, "event": found[0] if found.size() == 1 else {"arg": -1, "type": &"", "now": {}, "later": {}}, "count": found.size()}


## A destruction judged: one unit_destroyed for the Player, of the type; the Tokens in the handler,
## a frame later and now are `wanted`; the HUD lines and panels show them as the counts say.
func _judge(check: StringName, made: Dictionary, player: int, type_id: StringName, wanted: Array, label: String) -> void:
	var event: Dictionary = made["event"]
	_need(check, made["count"] == 1 and event["arg"] == player and event["type"] == type_id, "%s: expected one unit_destroyed for Player %d's %s, got %d" % [label, player + 1, type_id, made["count"]])
	var seen: Array = [event["now"].get("counts"), event["later"].get("counts"), _tk.counts()]
	_need(check, seen == [wanted, wanted, wanted], "%s: Tokens %s in the handler, %s a frame later, %s now; expected %s" % [label, seen[0], seen[1], seen[2], wanted])
	for key: String in ["now", "later"]:
		_need(check, _tk.shows(event[key], wanted) and _drawn(event[key], player), "%s, %s: HUD %s, panels %s, looks %s do not show %s" % [label, key, event[key].get("hud"), event[key].get("panels"), event[key].get("looks"), wanted])


## "" when a state() shows the fixture for both Players: Tokens, HUD lines, panel counts, the panel
## drawn as the counts say, both choosing, none alive; `first`: the cursor on the Motorbike.
func _reads_fixture(seen: Dictionary, first: bool) -> String:
	var want: Array = _fixture()
	if seen.get("counts") != want or not _tk.shows(seen, want):
		return "Tokens %s, HUD %s, panels %s; the fixture is %s" % [seen.get("counts"), seen.get("hud"), seen.get("panels"), want]
	for player: int in Kit.PLAYERS:
		var cursor: int = seen["cursor"][player]
		if not _drawn(seen, player) or want[player][cursor] == 0 or (first and cursor != Type.MOTORBIKE):
			return "Player %d: looks %s fonts %s cursor %d" % [player + 1, seen["looks"][player], seen["fonts"][player], cursor]
	return "" if seen["choosing"] == [true, true] and seen["alive"] == [false, false] else "choosing %s alive %s" % [seen["choosing"], seen["alive"]]


## True when a Player's panel in a state() is drawn as its counts and cursor say: a slot with no
## Token dim (its text too), the slot under the cursor marked, every other slot plain.
func _drawn(seen: Dictionary, player: int) -> bool:
	var counts: Array = seen.get("counts", [[], []])[player]
	var looks: PackedStringArray = []
	var fonts: PackedStringArray = []
	for index: int in counts.size():
		looks.append("dim" if counts[index] == 0 else "cursor" if index == seen["cursor"][player] else "plain")
		fonts.append("dim" if counts[index] == 0 else "normal")
	return not counts.is_empty() and seen["looks"][player] == looks and seen["fonts"][player] == fonts


## A row of Tokens in the order of the types the controller lists now: the fixture's, or a
## dictionary's by type_id.
func _row(counts_by_id: Dictionary = STOCK_COUNTS) -> Array[int]:
	var row: Array[int] = []
	for stats: UnitStats in _tk.controller.unit_types():
		row.append(int(counts_by_id.get(stats.type_id, 0)))
	return row


## The fixture's rows for both Players, in the order of the types the controller lists now.
func _fixture() -> Array:
	return [_row(), _row()]


## A Player's Tokens by type_id, whatever order the controller lists the types in now.
func _by_id(player: int) -> Dictionary:
	var found: Dictionary = {}
	var types: Array[UnitStats] = _tk.controller.unit_types()
	for index: int in types.size():
		found[types[index].type_id] = _tk.controller.tokens_left(player, index)
	return found


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


## Prints the six verdicts in the design's order (a check whose evidence was not completed fails)
## and the RESULT line.
func _report() -> void:
	_tk.controller.rules = _original
	_tk.close()
	for id: StringName in NAMES:
		if not _closed.has(id):
			_problems[id].append("the run stopped before this check's evidence was complete (%s)" % _stopped)
		_kit.verdict(NAMES[id], _problems[id], " | ".join(_notes[id]))
	_h.finish("refusals=%d errors=%d warnings=%d destroyed=%d spawned=%d round_over=%d round_started=%d lint_files=%d lint_literals=%d" % [
		_refusals, _tk.engine_log.errors.size(), _tk.engine_log.warnings.size(), _tk.events_of(&"destroyed").size(), _tk.events_of(&"spawned").size(),
		_tk.events_of(&"over").size(), _tk.events_of(&"started").size(), _lint.get("files", 0), _lint.get("literals", 0)])
