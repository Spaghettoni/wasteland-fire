extends RefCounted
## The checks of the destruction scenario (destruction.gd) that play the rest of the Round after the
## first destruction: AC-4 (five cycles), AC-2 and AC-8 (a debug key while waiting, the debug key gated
## by data), AC-7 (Players are independent) and AC-5 (the Self-destruct keys of both Players). Five
## CHECK lines: unlimited, damage_while_dead, debug_gating, independence, self_destruct.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-2, AC-4, AC-5,
## AC-7 and AC-8. Made by destruction.gd with the shared kit and record. Tooling only: nothing under src/
## depends on this file.

## The runner, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## One destruction (wait.gd).
const Wait: GDScript = preload("res://tools/evidence/split_screen/wait.gd")
## The record of the scenario (wait_log.gd).
const Log: GDScript = preload("res://tools/evidence/split_screen/wait_log.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## Destroy-and-respawn cycles of the unlimited check.
const CYCLES: int = 5
## Fractions of the first wait after which an extra key press is made inside a wait (damage_while_dead,
## self_destruct); the first one is also the gap between the two staggered Self-destructs.
const PRESS_AGAIN_FRACTIONS: Array[float] = [0.15, 0.35]

var _kit: Kit
var _log: Log


func _init(check_kit: Kit, record: Log) -> void:
	_kit = check_kit
	_log = record


## AC-4: CYCLES destroy-and-respawn cycles in a row by Player 1's Self-destruct key, every wait as long
## as the first and every respawn on the Base at full hit points, with the signals counted.
func check_unlimited() -> void:
	var problems: PackedStringArray = []
	var lengths: PackedStringArray = []
	var destroyed: int = _log.destroyed[0]
	var spawned: int = _log.spawned[0]
	for cycle: int in range(1, CYCLES + 1):
		var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
		await _log.wait_respawn(wait)
		var state: PackedStringArray = []
		_log.read_spawn(Harness.PLAYER_1, state)
		lengths.append(str(wait.length()))
		_kit.need(problems, wait.length() == _log.reference_ticks and state.is_empty(),
			"cycle %d: %d ticks (expected %d) %s" % [cycle, wait.length(), _log.reference_ticks, "; ".join(state)])
	var added_destroyed: int = _log.destroyed[0] - destroyed
	var added_spawned: int = _log.spawned[0] - spawned
	_kit.need(problems, added_destroyed == CYCLES and added_spawned == CYCLES,
		"unit_destroyed +%d unit_spawned +%d (expected %d each)" % [added_destroyed, added_spawned, CYCLES])
	_kit.verdict("unlimited", problems, ("%d cycles: ticks per wait [%s] (first wait %d); unit_destroyed +%d unit_spawned +%d; every respawn "
		+ "on the Base at full hit points, collision restored, camera snapped") % [
			CYCLES, ", ".join(lengths), _log.reference_ticks, added_destroyed, added_spawned])


## AC-2 and AC-8: a debug key pressed while the Unit waits does nothing: no second unit_destroyed, hit
## points stay zero, the respawn comes on the same tick as without it, at full hit points.
func check_damage_while_dead() -> void:
	var problems: PackedStringArray = []
	var unit: Unit = _log.units[Harness.PLAYER_1]
	var destroyed: int = _log.destroyed[0]
	var spawned: int = _log.spawned[0]
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	for gap: int in _press_gaps():
		await _kit.advance(gap)
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
		_kit.need(problems, not unit.is_alive and is_zero_approx(unit.hit_points),
			"a debug press while waiting left alive=%s hit_points=%.1f" % [unit.is_alive, unit.hit_points])
	await _log.wait_respawn(wait)
	var added_destroyed: int = _log.destroyed[0] - destroyed
	_kit.need(problems, added_destroyed == 1 and _log.spawned[0] - spawned == 1,
		"unit_destroyed +%d unit_spawned +%d (expected 1 each)" % [added_destroyed, _log.spawned[0] - spawned])
	_kit.need(problems, _log.unit_emits[0] == _log.destroyed[0],
		"the Unit emitted destroyed %d times and the controller counted %d: a press while waiting must not emit" % [
			_log.unit_emits[0], _log.destroyed[0]])
	_kit.need(problems, wait.length() == _log.reference_ticks and is_equal_approx(unit.hit_points, unit.stats.max_hit_points),
		"the wait was %d ticks (expected %d), hit_points after it %.1f" % [wait.length(), _log.reference_ticks, unit.hit_points])
	_kit.verdict("damage_while_dead", problems, ("%d debug presses while waiting: unit_destroyed +%d, hit_points 0 throughout, wait %d ticks "
		+ "(expected %d), hit_points after the respawn %.1f") % [
			PRESS_AGAIN_FRACTIONS.size(), added_destroyed, wait.length(), _log.reference_ticks, unit.hit_points])


## AC-8: with debug_damage at 0.0 the debug key changes no hit points; put back, it does. The zero is a
## duplicate of the rules on Player 1's PlayerMatchInput, which reads the value every tick.
func check_debug_gating() -> void:
	var unit: Unit = _log.units[Harness.PLAYER_1]
	var input: PlayerMatchInput = _match_input(unit)
	if input == null:
		_kit.verdict("debug_gating", PackedStringArray(["no PlayerMatchInput reads Player 1's Unit"]), "")
		return
	var problems: PackedStringArray = []
	var original: MatchRules = input.rules
	var gated: MatchRules = original.duplicate() as MatchRules
	gated.debug_damage = 0.0
	var before: float = unit.hit_points
	var destroyed: int = _log.destroyed[0]
	input.rules = gated
	await _kit.press_settled(Kit.KEYS_DEBUG_1)
	await _kit.press_settled(Kit.KEYS_DEBUG_1)
	var gated_hp: float = unit.hit_points
	input.rules = original
	await _kit.press_settled(Kit.KEYS_DEBUG_1)
	_kit.need(problems, is_equal_approx(gated_hp, before) and unit.is_alive and _log.destroyed[0] == destroyed,
		"with debug_damage 0.0 the key changed hit_points to %.1f" % gated_hp)
	_kit.need(problems, is_equal_approx(unit.hit_points, before - original.debug_damage),
		"with the rules put back one press gave %.1f (expected %.1f)" % [unit.hit_points, before - original.debug_damage])
	_kit.verdict("debug_gating", problems, ("hit_points %.1f; rules.debug_damage=0.0: two presses of key 1 leave %.1f; put back to %.1f: "
		+ "one press leaves %.1f (expected %.1f)") % [before, gated_hp, original.debug_damage, unit.hit_points, before - original.debug_damage])


## AC-7: Players are independent. Through every Player 1 destruction so far Player 2's Unit stayed
## alive, at full hit points and where it was, with no signal of its own; then key 2 damages Player 2's
## Unit and leaves Player 1's hit points alone.
func check_independence() -> void:
	var problems: PackedStringArray = []
	var first: Unit = _log.units[Harness.PLAYER_1]
	var second: Unit = _log.units[Harness.PLAYER_2]
	var track: UnitTrack = _log.harness.tracks[Harness.PLAYER_2]
	var max_hp: float = second.stats.max_hit_points
	_kit.need(problems, second.is_alive and is_equal_approx(second.hit_points, max_hp) and track.moved() <= Log.STILL_LIMIT
		and absf(track.yaw_total) <= Log.STILL_LIMIT and _log.destroyed[1] == 0 and _log.spawned[1] == 0,
		"Player 2's Unit or signals changed while Player 1 cycled")
	var detail: String = ("through %d Player 1 destructions and %d respawns: player_2 alive=%s hit_points=%.1f/%.1f moved=%.6f m "
		+ "yaw change=%.6f rad unit_destroyed=%d unit_spawned=%d") % [
			_log.destroyed[0], _log.spawned[0], second.is_alive, second.hit_points, max_hp, track.moved(), track.yaw_total,
			_log.destroyed[1], _log.spawned[1]]
	var first_hp: float = first.hit_points
	await _kit.press_settled(Kit.KEYS_DEBUG_2)
	var expected: float = max_hp - _log.controller.rules.debug_damage
	_kit.need(problems, is_equal_approx(second.hit_points, expected) and is_equal_approx(first.hit_points, first_hp),
		"key 2 gave Player 2 %.1f (expected %.1f) and Player 1 %.1f (was %.1f)" % [second.hit_points, expected, first.hit_points, first_hp])
	_kit.verdict("independence", problems, detail + (" | key 2: player_2 hit_points=%.1f (expected %.1f), "
		+ "player_1 hit_points=%.1f (was %.1f)") % [second.hit_points, expected, first.hit_points, first_hp])


## AC-5: Tab destroys Player 1's Unit and Enter Player 2's, within Kit.TICK_SLACK ticks of the press and
## each without touching the other; the key pressed again during a wait changes nothing; both at once
## give two timers that end on the same tick; two Self-destructs a fraction of a wait apart
## (PRESS_AGAIN_FRACTIONS[0]) each wait the full delay from their own destruction. Every wait is as
## long as the first.
func check_self_destruct() -> void:
	var destroyed: int = _log.destroyed[0] + _log.destroyed[1]
	var spawned: int = _log.spawned[0] + _log.spawned[1]
	var played: Dictionary[String, Variant] = await _play_self_destructs()
	var problems: PackedStringArray = []
	var waits: Array[Wait] = played["waits"]
	var detail: String = _judge_starts(played, problems) + _judge_waits(waits, problems)
	var added: int = _log.destroyed[0] + _log.destroyed[1] - destroyed
	var added_spawns: int = _log.spawned[0] + _log.spawned[1] - spawned
	_kit.need(problems, added == waits.size() and added_spawns == waits.size(),
		"unit_destroyed +%d unit_spawned +%d (expected %d each: the extra presses changed nothing)" % [added, added_spawns, waits.size()])
	_kit.need(problems, _log.unit_emits[0] == _log.destroyed[0] and _log.unit_emits[1] == _log.destroyed[1],
		"the Units emitted destroyed %d/%d times and the controller counted %d/%d: an extra press must not emit" % [
			_log.unit_emits[0], _log.unit_emits[1], _log.destroyed[0], _log.destroyed[1]])
	_kit.verdict("self_destruct", problems, "%s; unit_destroyed +%d unit_spawned +%d; the Units' own destroyed signals %d/%d, the controller's %d/%d" % [
		detail, added, added_spawns, _log.unit_emits[0], _log.unit_emits[1], _log.destroyed[0], _log.destroyed[1]])


## The key sequence of the Self-destruct check: Tab with extra presses inside the wait, Enter, both
## keys at once, then two staggered ones. Returns the six waits in that order ("waits"), the ticks from
## each first key to its destruction ("lag_tab", "lag_enter") and whether the other Player's Unit was
## alive just after each ("second_alive", "first_alive").
func _play_self_destructs() -> Dictionary[String, Variant]:
	var played: Dictionary[String, Variant] = {}
	var gaps: Array[int] = _press_gaps()
	var at_tab: int = _log.harness.ticks
	var tab: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	played["second_alive"] = _log.units[Harness.PLAYER_2].is_alive
	for gap: int in gaps:
		await _kit.advance(gap)
		await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	await _log.wait_respawn(tab)
	var at_enter: int = _log.harness.ticks
	var enter: Wait = await _log.kill(Kit.KEYS_DESTRUCT_2, Harness.PLAYER_2)
	played["first_alive"] = _log.units[Harness.PLAYER_1].is_alive
	await _log.wait_respawn(enter)
	await _kit.press_settled(Kit.KEYS_DESTRUCT_BOTH)
	var both_1: Wait = _log.open_wait(Harness.PLAYER_1)
	var both_2: Wait = _log.open_wait(Harness.PLAYER_2)
	await _log.wait_respawn(both_1)
	await _log.wait_respawn(both_2)
	var stagger_1: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	await _kit.advance(gaps[0])
	var stagger_2: Wait = await _log.kill(Kit.KEYS_DESTRUCT_2, Harness.PLAYER_2)
	await _log.wait_respawn(stagger_1)
	await _log.wait_respawn(stagger_2)
	var six: Array[Wait] = [tab, enter, both_1, both_2, stagger_1, stagger_2]
	played["waits"] = six
	played["lag_tab"] = tab.destroyed_tick - at_tab
	played["lag_enter"] = enter.destroyed_tick - at_enter
	return played


## Judges the first two Self-destructs: each key destroyed its own Player's Unit within the slack and the
## other Unit stayed alive. Adds to problems and returns the numbers.
func _judge_starts(played: Dictionary[String, Variant], problems: PackedStringArray) -> String:
	var waits: Array[Wait] = played["waits"]
	var tab: Wait = waits[0]
	var enter: Wait = waits[1]
	var lag_tab: int = played["lag_tab"]
	var lag_enter: int = played["lag_enter"]
	var second_alive: bool = played["second_alive"]
	var first_alive: bool = played["first_alive"]
	_kit.need(problems, tab.destroyed_tick >= 0 and lag_tab >= 0 and lag_tab <= Kit.TICK_SLACK and second_alive,
		"Tab: destroyed %d ticks after the press (allowed 0 to %d), player_2 alive=%s" % [lag_tab, Kit.TICK_SLACK, second_alive])
	_kit.need(problems, enter.destroyed_tick >= 0 and lag_enter >= 0 and lag_enter <= Kit.TICK_SLACK and first_alive,
		"Enter: destroyed %d ticks after the press (allowed 0 to %d), player_1 alive=%s" % [lag_enter, Kit.TICK_SLACK, first_alive])
	return ("Tab destroyed Player 1 %d tick(s) after the press and Enter destroyed Player 2 %d after (allowed %d), the other Unit "
		+ "alive both times; ") % [lag_tab, lag_enter, Kit.TICK_SLACK]


## Judges the six waits: each as long as the first, both-at-once ending together, the staggered pair
## apart by the same ticks at both ends. Adds to problems and returns the numbers.
func _judge_waits(waits: Array[Wait], problems: PackedStringArray) -> String:
	var lengths: PackedStringArray = []
	for wait: Wait in waits:
		lengths.append(str(wait.length()))
		_kit.need(problems, wait.length() == _log.reference_ticks,
			"a wait of player_%d lasted %d ticks (expected %d)" % [wait.player + 1, wait.length(), _log.reference_ticks])
	var both_1: Wait = waits[2]
	var both_2: Wait = waits[3]
	_kit.need(problems, both_1.destroyed_tick == both_2.destroyed_tick and both_1.spawned_tick == both_2.spawned_tick,
		"both at once did not end together")
	var apart_destroyed: int = waits[5].destroyed_tick - waits[4].destroyed_tick
	var apart_spawned: int = waits[5].spawned_tick - waits[4].spawned_tick
	_kit.need(problems, apart_destroyed == apart_spawned and apart_spawned > 0,
		"staggered: destroyed %d ticks apart, respawned %d apart" % [apart_destroyed, apart_spawned])
	return ("waits in ticks [tab with %d extra presses, enter, both p1, both p2, staggered p1, staggered p2] = [%s] (first wait %d); "
		+ "both at once: destroyed at tick %d/%d, respawned at tick %d/%d; staggered: destroyed %d ticks apart, respawned %d apart") % [
			PRESS_AGAIN_FRACTIONS.size(), ", ".join(lengths), _log.reference_ticks, both_1.destroyed_tick, both_2.destroyed_tick,
			both_1.spawned_tick, both_2.spawned_tick, apart_destroyed, apart_spawned]


## The ticks to wait before each extra key press inside a wait: PRESS_AGAIN_FRACTIONS of the first
## wait, so the presses stay inside a wait whatever delay the data gives.
func _press_gaps() -> Array[int]:
	var gaps: Array[int] = []
	for fraction: float in PRESS_AGAIN_FRACTIONS:
		gaps.append(maxi(roundi(fraction * float(_log.reference_ticks)), 1))
	return gaps


## The PlayerMatchInput that reads the keys of a Unit, or null.
func _match_input(unit: Unit) -> PlayerMatchInput:
	for node: Node in _log.harness.split.find_children("*", "", true, false):
		if node is PlayerMatchInput and (node as PlayerMatchInput).unit == unit:
			return node as PlayerMatchInput
	return null
