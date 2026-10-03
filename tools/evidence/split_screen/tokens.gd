extends RefCounted
## Scenario tokens of the split screen evidence harness (split_screen_harness.gd): Story 008's Token
## stock as data and what a destruction costs (AC-1, AC-2, AC-5, AC-9), on Map 01 with its real
## stock. One Round walks all of it with real key events and ten destructions. Player 1 loses a
## Motorbike and a Buggy to its Self-destruct, a Motorbike to a Shot from Player 2's Truck, and its
## remaining Motorbikes to Tab (the last is the loss; R restarts). Player 2 loses the Truck to
## Enter, a Gyrocopter to a Fuel crash and two Motorbikes to Player 1's Shots (the second with Enter
## pressed for the Shot's lethal frame). Eight CHECK lines, every number measured, the expected
## counts read from the Map's stock resource and never typed. Shared helpers: token_kit.gd,
## check_kit.gd, unit_kit.gd.
## Implements: production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1, AC-2, AC-5
## and AC-9. Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=tokens
##
## Kills: the wrong implementation each check fails, check by check.
##  T01a  counts not copied from the stock (all 0), a Player left out, counts under the wrong type,
##        no count on the HUD or the choice panel at the start.
##  T02   a ledger aliasing stock.counts (a Token taken writes through to the shared resource); a
##        restart that refills from a worn stock or does not refill.
##  T05   a Token taken at the spawn or at the choice instead of at the destruction.
##  T06   a Token taken after unit_destroyed is emitted, or twice; a HUD or panel refreshed late.
##  T07   a Token of the wrong type (always the first), charged to the killer of a Shot or to both
##        Players.
##  T08   a Fuel crash that takes no Token, takes another type's, or ends the Round.
##  T09   a Self-destruct while benched, choosing or waiting that costs a Token; a bench or restart
##        that takes one; a Token taken twice for a Unit that a Self-destruct and a Shot reach in
##        one frame; an engine ERROR or WARNING.
##  T10   one ledger for both Players; a destruction that moves the other Player's counts, HUD line
##        or panel.

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 008 helpers (token_kit.gd): readings, the signal record, choices, the duel.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")

## The runner keeps the Map's own Token stock (data/token_stock.tres) for this scenario.
const USE_MAP_STOCK: bool = true
## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## Simulated seconds before the watchdog: ten destructions, each followed by a respawn delay.
const WATCHDOG_SECONDS: float = 300.0
## The types the scenario chooses, as indexes into the data (T01a checks the data's order).
enum Type { MOTORBIKE, BUGGY, TRUCK, GYROCOPTER }
## The checks as printed, by the short id the code uses, in the design's order.
const NAMES: Dictionary[StringName, String] = {&"T01a": "T01a_start_from_data", &"T02": "T02_shared_stock_untouched",
	&"T05": "T05_not_at_spawn", &"T06": "T06_at_destruction_tick", &"T07": "T07_charged_type_and_player",
	&"T08": "T08_fuel_crash", &"T09": "T09_no_cost_when_not_alive", &"T10": "T10_players_independent"}
## Ticks a Unit stays in play before its count is read: a second and a half.
const IN_PLAY_TICKS: int = 90
## Ticks a Gyrocopter may fly with the throttle held before the run gives up.
const FLY_LIMIT_TICKS: int = 1500
## A Fuel crash comes within this many ticks of the burn the data gives (a burn starts on the first
## tick the Unit moves).
const CRASH_SLACK_TICKS: int = 2

var _h: Harness
var _kit: Kit
var _tk: Tokens
var _stock: TokenStock
## The Map's stock counts copied by value at the start, the rows it gives both Players, the type_ids
## of the data in order, the events index and the state before the cause being made (_destroy()).
var _snapshot: Dictionary[StringName, int] = {}
var _start: Array = []
var _ids: Array[StringName] = []
var _mark: int = 0
var _before: Dictionary = {}
## Per check: the problems and the measured notes; the checks whose evidence is complete; why the
## run stopped early, if it did; the ticks the Gyrocopter flew.
var _problems: Dictionary[StringName, PackedStringArray] = {}
var _notes: Dictionary[StringName, PackedStringArray] = {}
var _closed: Array[StringName] = []
var _stopped: String = ""
var _crash_ticks: int = -1


## Runs the scenario; the phases are in the order of the Round. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(harness)
	_tk = Tokens.new(harness, _kit)
	_stock = _h.split.field.token_stock
	_snapshot = Tokens.counts_copy(_stock)
	_start = _tk.rows_of(_stock)
	for stats: UnitStats in _tk.controller.unit_types():
		_ids.append(stats.type_id)
	for id: StringName in NAMES:
		_problems[id] = PackedStringArray()
		_notes[id] = PackedStringArray()
	await _kit.advance(Kit.START_TICKS)
	_check_start()
	var phases: Array[Callable] = [_benched_keys, _first_series, _shot_kill, _truck_and_gyrocopter, _double_source, _loss_and_restart]
	for phase: Callable in phases:
		if _stopped.is_empty():
			await phase.call()
	_report()


## T01a: both Players start with the Map's stock in the controller, on the HUD and on the panel.
func _check_start() -> void:
	var seen: Dictionary = _tk.state()
	_need(&"T01a", _ids == Tokens.Units.TYPE_IDS and _tk.carrier_index() == Type.MOTORBIKE and _stock.counts.size() == _ids.size() and _start[0].max() > 0, "types %s, carrier %d or the stock's %d keys are not what the scenario expects" % [_ids, _tk.carrier_index(), _stock.counts.size()])
	_need(&"T01a", seen["counts"] == _start, "the controller's Tokens %s are not the Map's stock %s" % [seen["counts"], _start])
	_need(&"T01a", _tk.shows(seen, _start) and _tk.units.panels[0].visible and _tk.units.panels[1].visible, "the HUD lines %s or panels %s do not show %s, or a panel is hidden" % [seen["hud"], seen["panels"], _start])
	_note(&"T01a", "stock %s (%s) -> Tokens p1=%s p2=%s | HUD \"%s\" \"%s\" | panels %s %s" % [_snapshot, _stock.resource_path.get_file(), seen["counts"][0], seen["counts"][1], seen["hud"][0], seen["hud"][1], seen["panels"][0], seen["panels"][1]])
	_closed.append(&"T01a")


## T09, benched: Tab and Enter while both Players choose and nothing is in play cost nothing.
func _benched_keys() -> void:
	var seen: int = _tk.events.size()
	await _kit.press_settled(Kit.KEYS_DESTRUCT_BOTH)
	var gone: int = _tk.events_of(&"destroyed", seen).size()
	_need(&"T09", gone == 0 and _tk.counts() == _start, "Tab and Enter while benched: unit_destroyed %d, Tokens %s" % [gone, _tk.counts()])
	_note(&"T09", "benched (both choosing, nothing in play): Tab+Enter -> unit_destroyed %d, Tokens still the stock: %s" % [gone, _tk.counts() == _start])


## T05 for Player 1's Motorbike and Player 2's Truck: in play they are not subtracted (the count is
## the stock's while they live); the Motorbike's Self-destruct takes one Token, and only then.
func _first_series() -> void:
	if not _require(&"T05", await _tk.spawn(0, Type.MOTORBIKE) and await _tk.spawn(1, Type.TRUCK), "Player 1's Motorbike or Player 2's Truck did not appear"):
		return
	await _kit.advance(IN_PLAY_TICKS)
	var spawned: Array[Dictionary] = _tk.events_of(&"spawned")
	_need(&"T05", spawned.size() == 2 and spawned[0]["now"]["counts"] == _start and spawned[1]["now"]["counts"] == _start and _tk.shows(_tk.state(), _start), "a Unit in play was subtracted: Tokens %s, %s at the spawns" % [_tk.counts(), spawned.map(func(event: Dictionary) -> Array: return event["now"]["counts"])])
	_note(&"T05", "Motorbike (p1) and Truck (p2) %d ticks in play: Tokens still %s, HUD \"%s\"" % [IN_PLAY_TICKS, _tk.counts(), _tk.hud_line(0)])
	await _destroy(&"T05", 0, Type.MOTORBIKE, "Tab on the Motorbike", _tk.destruct.bind(0))
	await _countdown_series()


## T05, T07 and T09 in Player 1's countdown: Tab while it chooses and while its choice stands costs
## nothing, a choice costs nothing, the Buggy in play is not subtracted, and its own Self-destruct
## takes one Buggy Token and nothing else.
func _countdown_series() -> void:
	var after: Array = _tk.counts()
	var seen: int = _tk.events.size()
	for _press: int in 3:
		await _tk.destruct(0)
	var chosen: bool = await _tk.choose(0, Type.BUGGY)
	await _tk.destruct(0)
	var cost: int = _tk.events_of(&"destroyed", seen).size()
	_need(&"T09", cost == 0 and _tk.counts() == after and chosen, "Tab while choosing, waiting or with a choice standing: unit_destroyed %d, Tokens %s" % [cost, _tk.counts()])
	_need(&"T05", chosen and _tk.counts() == after and _tk.controller.chosen_type_index(0) == Type.BUGGY, "the choice made in the countdown changed a count: %s" % [_tk.counts()])
	_note(&"T09", "p1 choosing, then choice standing, in the countdown: 3 Tabs, a choice, a Tab -> unit_destroyed %d, Tokens still %s" % [cost, _tk.counts()[0]])
	if not _require(&"T05", await _tk.units.wait_alive(0, _h.ticks_in(_tk.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS) >= 0, "the Buggy did not appear"):
		return
	await _kit.advance(IN_PLAY_TICKS)
	_need(&"T05", _tk.counts() == after and _tk.shows(_tk.state(), after) and _tk.units.units[0].type_id == _ids[Type.BUGGY], "the Buggy in play was subtracted: Tokens %s" % [_tk.counts()])
	_note(&"T05", "a choice in the countdown cost nothing; Buggy %d ticks in play: buggy still %d, HUD \"%s\"" % [IN_PLAY_TICKS, _tk.counts()[0][Type.BUGGY], _tk.hud_line(0)])
	_closed.append(&"T05")
	await _destroy(&"T07", 0, Type.BUGGY, "Tab on the Buggy", _tk.destruct.bind(0))


## T07: Player 1's next Motorbike is shot dead by Player 2's Truck (a real fire key, 10 m): its own
## count falls, the Truck's Player pays nothing.
func _shot_kill() -> void:
	if not _require(&"T07", await _tk.spawn(0, Type.MOTORBIKE), "Player 1's Motorbike did not appear"):
		return
	await _tk.stage_duel(0)
	var added: int = await _destroy(&"T07", 0, Type.MOTORBIKE, "Shot from Player 2's Truck", _tk.shoot.bind(1))
	_need(&"T07", added >= 0 and _tk.units.units[1].type_id == _ids[Type.TRUCK] and _tk.units.units[1].is_alive, "the Shot did not come from a live Truck (Shot node added in frame %d)" % added)
	_closed.append(&"T07")


## T10 and T08: Player 2's Truck Self-destructs (Player 1's reading stays), then its Gyrocopter
## flies with the throttle held until its tank is dry and it crashes.
func _truck_and_gyrocopter() -> void:
	await _destroy(&"T10", 1, Type.TRUCK, "Enter on the Truck", _tk.destruct.bind(1))
	_closed.append(&"T10")
	if not _require(&"T08", await _tk.spawn(1, Type.GYROCOPTER), "Player 2's Gyrocopter did not appear"):
		return
	var unit: Unit = _tk.units.units[1]
	var tank: float = unit.fuel
	var expected: int = _h.ticks_in(tank / unit.stats.fuel_use)
	var shots: int = _tk.shot_frames.size()
	await _destroy(&"T08", 1, Type.GYROCOPTER, "Fuel crash", _fly.bind(1))
	var over: bool = _tk.controller.is_round_over() or not _tk.events_of(&"over").is_empty()
	_need(&"T08", absi(_crash_ticks - expected) <= CRASH_SLACK_TICKS and _tk.shot_frames.size() == shots and not over, "crash after %d ticks (the data gives %d), %d Shots, round over %s" % [_crash_ticks, expected, _tk.shot_frames.size() - shots, over])
	_note(&"T08", "throttle held %d ticks (%.1f Fuel at %.1f/s = %d ticks +-%d), %d Shots fired; the Round runs: round over %s" % [_crash_ticks, tank, unit.stats.fuel_use, expected, CRASH_SLACK_TICKS, _tk.shot_frames.size() - shots, over])
	_closed.append(&"T08")


## T09, two sources on one Unit: Player 2's Motorbike is shot dead by Player 1's Motorbike alone
## (the control: the Shot's lethal frame), then again with its own Self-destruct pressed so that it
## acts in that same frame: one Token each time.
func _double_source() -> void:
	if not _require(&"T09", await _tk.spawn(0, Type.MOTORBIKE), "Player 1's Motorbike did not appear"):
		return
	var landed: PackedInt32Array = []
	for with_key: bool in [false, true]:
		if not _require(&"T09", await _tk.spawn(1, Type.MOTORBIKE), "Player 2's Motorbike did not appear"):
			return
		await _tk.stage_duel(1)
		var cause: Callable = _shoot_and_press.bind(0, 1) if with_key else _tk.shoot.bind(0)
		var added: int = await _destroy(&"T09", 1, Type.MOTORBIKE, "Shot%s on the Motorbike" % (" and Enter on its lethal frame" if with_key else " alone"), cause)
		var found: Array[Dictionary] = _tk.events_of(&"destroyed", _mark)
		landed.append(found[0]["now"]["frame"] - added if found.size() == 1 else -1)
	_need(&"T09", landed == PackedInt32Array([Tokens.LETHAL_LEAD + 1, Tokens.LETHAL_LEAD + 1]), "the destructions landed %s frames after the Shot node, not both %d" % [landed, Tokens.LETHAL_LEAD + 1])
	_note(&"T09", "destroyed %s frames after the Shot node (alone, then with Enter pressed for that frame): one Token each" % [landed])


## Player 1 spends its remaining Motorbikes (the Motorbike in play is the first; the last is the
## loss) and R restarts the Round.
func _loss_and_restart() -> void:
	var left: int = _tk.counts()[0][Type.MOTORBIKE]
	for cycle: int in left:
		if cycle > 0 and not _require(&"T02", await _tk.spawn(0, Type.MOTORBIKE), "Player 1's Motorbike did not appear"):
			return
		await _destroy(&"T06", 0, Type.MOTORBIKE, "Tab on Motorbike %d of the last %d" % [cycle + 1, left], _tk.destruct.bind(0))
	_require(&"T02", _tk.controller.is_round_over() and _tk.events_of(&"over").size() == 1, "Player 1's last Motorbike did not end the Round")
	var over: int = _tk.events.size()
	var restarted: bool = await _tk.restart()
	await _kit.advance(2)
	_after_restart(restarted, over)


## T02 for the refill, T09 for the bench and the restart: after R both stocks equal the Map's, no
## Unit was destroyed, both Players choose; the shared stock never changed; the engine log is clean.
func _after_restart(restarted: bool, over: int) -> void:
	var seen: Dictionary = _tk.state()
	var destroyed: int = _tk.events_of(&"destroyed", over).size()
	_need(&"T02", restarted and _tk.shows(seen, _start) and not seen["over"] and not seen["paused"], "the restart did not refill both Players to the stock: Tokens %s, over %s" % [seen["counts"], seen["over"]])
	_need(&"T09", restarted and seen["counts"] == _start and destroyed == 0 and seen["choosing"] == [true, true], "the bench or the restart cost a Token or destroyed a Unit: Tokens %s" % [seen["counts"]])
	_check_stock()
	_need(&"T09", _tk.engine_log.errors.is_empty() and _tk.engine_log.warnings.is_empty(), "the engine logged errors %s and warnings %s" % [_tk.engine_log.errors, _tk.engine_log.warnings])
	_note(&"T09", "the loss and R cost nothing: unit_destroyed %d after round_over, Tokens %s; engine log: %d errors, %d warnings" % [destroyed, seen["counts"], _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])
	_closed.append_array([&"T09", &"T02", &"T06"])


## T02: the shared stock equals its start snapshot (and the file) at every event of the Round and
## after the restart.
func _check_stock() -> void:
	var worn: int = 0
	for event: Dictionary in _tk.events:
		worn += 0 if event["now"]["stock"] == _snapshot and event["later"].get("stock") == _snapshot else 1
	var live: Dictionary[StringName, int] = Tokens.counts_copy(_stock)
	var fresh: TokenStock = ResourceLoader.load(_stock.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as TokenStock
	var disk: Variant = fresh.counts if fresh != null else "unreadable"
	_need(&"T02", worn == 0 and live == _snapshot and disk == _snapshot, "the shared stock changed: %d events saw it differ from %s; now %s; on disk %s" % [worn, _snapshot, live, disk])
	_note(&"T02", "stock %s unchanged at all %d events (%d destructions) and after R: live %s, on disk %s; R refilled Tokens to %s" % [_snapshot, _tk.events.size(), _tk.events_of(&"destroyed").size(), live, disk, _tk.counts()])


## Makes one cause of a destruction (a coroutine Callable: a key, a Shot, a flight), waits for the
## unit_destroyed it brings and judges it (_charged()); returns what the cause returned.
func _destroy(check: StringName, player: int, type_index: int, label: String, cause: Callable) -> Variant:
	_mark = _tk.events.size()
	_before = _tk.state()
	var result: Variant = await cause.call()
	await _tk.wait_for(&"destroyed", _mark)
	_charged(check, player, type_index, label)
	return result


## The shooter fires one Shot and the presser's Self-destruct is pressed so that it acts on the
## Shot's lethal frame (token_kit.gd, LETHAL_LEAD): returns the frame the Shot node was added in.
func _shoot_and_press(shooter: int, presser: int) -> int:
	var added: int = await _tk.shoot(shooter)
	await _tk.press_on(added + Tokens.LETHAL_LEAD, Tokens.keys(&"destruct", presser))
	return added


## Holds the Player's throttle until its Unit is gone (a flying Unit crashes when its tank is dry);
## counts the ticks in _crash_ticks.
func _fly(player: int) -> void:
	_h.drive(player, 1, 0)
	for count: int in FLY_LIMIT_TICKS:
		if _tk.units.units[player].is_alive:
			await _kit.tick()
			_crash_ticks = count + 1
	_h.drive(player, 0, 0)


## The newest destruction against the state before its cause: one unit_destroyed for the Player, of
## the type; the Tokens inside the handler, a frame later and now are those before with one Token of
## that type less (the check), and so are both HUD lines and both panels in the handler and a frame
## later (T06); the other Player's counts, HUD line and panel are as they were (T10).
func _charged(check: StringName, player: int, type_index: int, label: String) -> void:
	var found: Array[Dictionary] = _tk.events_of(&"destroyed", _mark)
	var event: Dictionary = found[0] if found.size() == 1 else {"arg": -1, "type": &"", "now": {}, "later": {}}
	_require(check, event["arg"] == player and event["type"] == _ids[type_index], "%s: expected one unit_destroyed for Player %d's %s, got %d" % [label, player + 1, _ids[type_index], found.size()])
	var before: Array = _before["counts"]
	var wanted: Array = Tokens.charged(before, player, type_index)
	var seen: Array = [event["now"].get("counts"), event["later"].get("counts"), _tk.counts()]
	_need(check, seen == [wanted, wanted, wanted], "%s: Tokens %s in the handler, %s a frame later, %s now; expected %s" % [label, seen[0], seen[1], seen[2], wanted])
	var other: int = 1 - player
	for key: String in ["now", "later"]:
		var shown: Dictionary = event[key]
		_need(&"T06", _tk.shows(shown, wanted), "%s, %s: HUD %s, panels %s; expected Tokens %s" % [label, key, shown.get("hud"), shown.get("panels"), wanted])
		_need(&"T10", shown.get("counts", [[], []])[other] == before[other] and shown.get("hud", ["", ""])[other] == _before["hud"][other] and shown.get("panels", [PackedStringArray(), PackedStringArray()])[other] == _before["panels"][other], "%s: Player %d's Tokens, HUD or panel moved (%s)" % [label, other + 1, key])
	var read: Dictionary = event["now"]
	if check != &"T06":
		_note(check, "%s: p%d %s -> %s" % [label, player + 1, before[player], wanted[player]])
	_note(&"T06", "%s: inside the handler p%d's Tokens %s, HUD \"%s\", panel %s" % [label, player + 1, read.get("counts", [[], []])[player], read.get("hud", ["", ""])[player], read.get("panels", [PackedStringArray(), PackedStringArray()])[player]])
	if check != &"T10":
		_note(&"T10", "%s: p%d %s -> %s, p%d stays %s \"%s\"" % [label, player + 1, before[player], wanted[player], other + 1, before[other], _before["hud"][other]])


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


## Prints the eight verdicts in the design's order (a check whose evidence was not completed fails)
## and the RESULT line.
func _report() -> void:
	_tk.close()
	for id: StringName in NAMES:
		if not _closed.has(id):
			_problems[id].append("the run stopped before this check's evidence was complete (%s)" % _stopped)
		_kit.verdict(NAMES[id], _problems[id], " | ".join(_notes[id]))
	_h.finish("destroyed=%d spawned=%d shots=%d round_over=%d round_started=%d crash_ticks=%d errors=%d warnings=%d" % [
		_tk.events_of(&"destroyed").size(), _tk.events_of(&"spawned").size(), _tk.shot_frames.size(),
		_tk.events_of(&"over").size(), _tk.events_of(&"started").size(), _crash_ticks, _tk.engine_log.errors.size(), _tk.engine_log.warnings.size()])
