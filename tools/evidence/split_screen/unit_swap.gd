extends RefCounted
## Scenario unit_swap of the split screen evidence harness (split_screen_harness.gd): the Unit swap
## at the own Base (Story 011 AC-1 to AC-5), played with real keys on the shipped data and Map 01.
## One Round, three Token stocks of three: each Player swaps its Unit at home with the Self-destruct
## key, every type once, the Gyrocopter included, and chooses the next type (swap_at_home, with the
## screens in swap_screens: the choice panel opened in that Player's view only with the counts as
## they were, no countdown, the HUD's Tokens line unchanged, the other Player driving on); Player 1
## then Self-destructs one tick before the zone reports its Unit (the entry window, measured), in the
## open and inside the other Player's Base (destruct_elsewhere: each destroys, takes a Token and
## starts the delay); Player 1 swaps on its last Motorbike without losing, chooses the Motorbike
## again, and loses the Round by Self-destructing it outside (last_motorbike). The flag, crash, hint and data checks are in
## unit_swap_flows.gd, which this script runs after the Round is lost and restarted. Ten CHECK
## lines in all, plus no_engine_noise.
## Implements: production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md AC-1 to AC-5.
## Tooling only. Every number comes from the game's data; the scenario types only its test inputs.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=unit_swap

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 008 helpers (token_kit.gd): real keys, the signal record, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd).
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")
## The flag, crash, hint and data checks (unit_swap_flows.gd).
const Flows: GDScript = preload("res://tools/evidence/split_screen/unit_swap_flows.gd")

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap the shipped rules turn on (the runner turns it off for every other scenario).
const OWN_BASE_SWAP: bool = true
## And on the camera the build ships with.
const SHIPPED_CAMERA: bool = true
## The Token stock the runner builds for this scenario: three of every type, so each Player can
## spend Tokens in the checks below and the second Motorbike Self-destruct of Player 1 loses.
const STOCK_COUNTS: Dictionary = {&"motorbike": 3, &"buggy": 3, &"truck": 3, &"gyrocopter": 3}
## Simulated seconds: the Round has several respawn delays of three seconds in it.
const WATCHDOG_SECONDS: float = 400.0
## Ticks the other Player drives before a swap in which it must play on.
const PLAYS_ON_LEAD: int = 10

var _s: Swap


## Plays the Round of the class doc, then the CHECK lines and the RESULT line. The runner awaits this
## coroutine.
func run(harness: Node) -> void:
	_s = Swap.new(harness)
	await _s.both_play()
	await _every_type()
	await _elsewhere()
	await _last_motorbike()
	var flows: Flows = Flows.new(_s)
	await flows.run()
	_s.close()
	harness.finish("swaps=%d spawns=%d zone_latency_ticks=%s over=%s %s expected_errors=%d" % [_s.swaps.size(),
		_s.spawned.size(), _latency_range(), _s.controller.is_round_over(), _s.q.engine_counts(), flows.expected_errors])


## The least and most ticks the zone took to report a Unit after its spawn tick, "min-max".
func _latency_range() -> String:
	return "%d-%d" % [_s.latencies.min(), _s.latencies.max()] if not _s.latencies.is_empty() else "none"


## Each Player swaps four Units in a row, one of every type, choosing the next type after each; the
## Motorbike it ends with is the one it started with. AC-1 and AC-4.
func _every_type() -> void:
	var problems: PackedStringArray = []
	var screens: PackedStringArray = []
	var notes: PackedStringArray = []
	var next_types: Array[int] = [Quick.BUGGY, Quick.TRUCK, Quick.GYROCOPTER, Quick.MOTORBIKE]
	for player: int in Kit.PLAYERS:
		for step: int in next_types.size():
			var tag: String = "p%d %s" % [player + 1, _s.q.units.units[player].type_id]
			var swapped_at: int = await _swap_once(player, tag, step == 0 and player == 0, problems, screens)
			var played: int = await _s.play(player, next_types[step])
			notes.append("%s swapped, then %s in %d ticks (zone %d)" % [tag, _s.q.units.stats(next_types[step]).type_id,
				_s.spawned[-1]["tick"] - swapped_at, played])
			_judge_spawn(player, next_types[step], tag, swapped_at, problems)
	_s.q.kit.verdict("swap_at_home", problems, "%d swaps, every type once for each Player, the Gyrocopter included: %s" % [
		_s.swaps.size(), " | ".join(notes)])
	_s.q.kit.verdict("swap_screens", screens, "at each swap, read inside the handler: the swapping Player's panel open with the counts as before, the other Player's hidden, no countdown, the HUD's Tokens line unchanged; Player 2 drove on through Player 1's first swap")


## One real Self-destruct press of a Unit at home: what the Round and the screens must show two ticks
## later. Returns the tick the swap was announced on (-1000 when none was).
func _swap_once(player: int, tag: String, plays_on: bool, problems: PackedStringArray, screens: PackedStringArray) -> int:
	var tokens: Tokens = _s.q.tokens
	var before: Dictionary = tokens.state()
	var destroyed_before: int = _s.count("destroyed")
	var swaps_before: int = _s.swaps.size()
	var other: Unit = _s.q.units.units[1 - player]
	if plays_on:
		_s.q.harness.drive(1 - player, 1, 0)
		await _s.q.kit.advance(PLAYS_ON_LEAD)
	var other_from: Vector3 = other.global_position
	await tokens.destruct(player)
	if plays_on:
		_s.q.harness.drive(1 - player, 0, 0)
		_s.q.kit.need(screens, other.global_position.distance_to(other_from) > 0.0 and not _s.q.harness.get_tree().paused,
			"%s: the other Player did not drive on through the swap" % tag)
	_s.q.kit.need(problems, _s.swaps.size() == swaps_before + 1, "%s: %d swaps announced for one press" % [tag, _s.swaps.size() - swaps_before])
	_s.q.kit.need(problems, _s.count("destroyed") == destroyed_before, "%s: a destruction was announced" % tag)
	if _s.swaps.size() <= swaps_before:
		return -1000
	var swap: Dictionary = _s.swaps[-1]
	var unit: Unit = _s.q.units.units[player]
	var after: Dictionary = tokens.state()
	_s.q.kit.need(problems, bool(swap["choosing"]) and not bool(swap["alive"]), "%s: in the handler choosing=%s alive=%s" % [tag, swap["choosing"], swap["alive"]])
	_s.q.kit.need(problems, after["counts"] == before["counts"] and swap["counts"] == before["counts"], "%s: the Token counts changed %s -> %s" % [tag, before["counts"], after["counts"]])
	_s.q.kit.need(problems, _s.on_a_spawn_point(player) and not unit.visible and unit.collision_layer == 0, "%s: not benched on its spawn point (visible %s, layer %d)" % [tag, unit.visible, unit.collision_layer])
	_s.q.kit.need(problems, is_zero_approx(float(swap["wait_s"])) and is_zero_approx(_s.controller.seconds_until_respawn(player)), "%s: a respawn wait of %s s runs" % [tag, swap["wait_s"]])
	_s.q.kit.need(screens, bool(swap["panel"]) and not bool(swap["other_panel"]) and not bool(swap["countdown"]), "%s: panel %s, other Player's panel %s, countdown %s" % [tag, swap["panel"], swap["other_panel"], swap["countdown"]])
	_s.q.kit.need(screens, swap["hud"] == before["hud"][player], "%s: the HUD's Tokens line '%s' was '%s'" % [tag, swap["hud"], before["hud"][player]])
	_s.q.kit.need(screens, swap["panel_counts"] == tokens.count_texts(player, before["counts"][player]), "%s: panel counts %s, expected %s" % [tag, swap["panel_counts"], tokens.count_texts(player, before["counts"][player])])
	return int(swap["tick"])


## The Unit that appeared after a swap: the chosen type, in the Garage, at the full hit points and the
## spawn tank of its type, and sooner than a respawn delay.
func _judge_spawn(player: int, type_index: int, tag: String, swapped_at: int, problems: PackedStringArray) -> void:
	var stats: UnitStats = _s.q.units.stats(type_index)
	var spawn: Dictionary = _s.spawned[-1]
	var tank: float = stats.fuel_capacity * clampf(stats.spawn_fuel_fraction, 0.0, 1.0)
	_s.q.kit.need(problems, int(spawn["player"]) == player and spawn["type"] == stats.type_id, "%s: the Unit that appeared was %s" % [tag, spawn["type"]])
	_s.q.kit.need(problems, is_equal_approx(float(spawn["hp"]), stats.max_hit_points) and is_equal_approx(float(spawn["fuel"]), tank),
		"%s: appeared with %s hp and %s Fuel, not %s and %s" % [tag, spawn["hp"], spawn["fuel"], stats.max_hit_points, tank])
	_s.q.kit.need(problems, _s.on_a_spawn_point(player), "%s: the new Unit is not on a spawn point of its Base" % tag)
	_s.q.kit.need(problems, int(spawn["tick"]) - swapped_at < _s.q.harness.ticks_in(_s.controller.rules.respawn_delay_seconds), "%s: %d ticks from the swap to the Unit, the respawn delay is %d" % [
		tag, int(spawn["tick"]) - swapped_at, _s.q.harness.ticks_in(_s.controller.rules.respawn_delay_seconds)])


## Player 1 Self-destructs where a swap is not allowed: on the very tick its Unit appears (the zone has
## not reported it yet), in the open outside its gate, and inside Player 2's Base. Each destroys, takes
## a Token of its type and starts the delay. AC-2.
func _elsewhere() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	notes.append(await _entry_window(problems))
	if not _s.controller.is_alive(0):
		await _s.play(0, Quick.MOTORBIKE)
	_move_out(0, _s.outside_point(0))
	await _s.q.kit.advance(Swap.OUT_SETTLE_TICKS)
	notes.append(await _destruct("in the open", Quick.MOTORBIKE, problems))
	await _s.play(0, Quick.BUGGY)
	_move_out(0, _s.base_point(1, Vector3(9.0, 0.0, -3.0)))
	_s.q.kit.need(problems, await _s.wait_until(func() -> bool: return _s.q.units.bases[1].zone.overlaps_body(_s.q.units.units[0])), "the Buggy was never reported inside Player 2's zone")
	notes.append(await _destruct("inside Player 2's Base", Quick.BUGGY, problems))
	_s.q.kit.verdict("destruct_elsewhere", problems, "%s; zone latency after a spawn %s ticks" % [" | ".join(notes), _latency_range()])
	await _s.play(0, Quick.MOTORBIKE)


## Player 1's Unit is put inside its Base: the zone reports it a fixed number of ticks later (measured),
## and a key that acts before then is still a Self-destruct. With a latency of two or more ticks a press
## one tick early destroys the Unit; with one there is no such press, and the note says so.
func _entry_window(problems: PackedStringArray) -> String:
	var latency: int = await _s.zone_latency(0)
	_s.q.kit.need(problems, latency >= 1, "the zone never reported a Unit put inside its Base")
	if latency < 2:
		return "entry: the zone reports a Unit put in %d tick later, so no press is early enough to destroy it" % latency
	var before: Array = _s.q.tokens.counts()
	var swaps_before: int = _s.swaps.size()
	var destroyed_before: int = _s.count("destroyed")
	await _s.enter_pressing(0, latency, -1)
	return _judged("a press acting one tick before the zone reports the Unit (latency %d)" % latency, Quick.MOTORBIKE, before, swaps_before, destroyed_before, problems)


## Puts Player 1's Unit on the ground at a place facing away from its Base.
func _move_out(player: int, at: Vector3) -> void:
	_s.flags.teleport(player, at, _s.gate_way(player))


## One Self-destruct of Player 1's Unit that must destroy it: the zone does not report the Unit inside
## its own Base (the first case is the tick after the Unit appeared, the zone not having reported it
## yet), the destruction announced, no swap, one Token of the type spent and nothing else, the full
## delay running and the countdown showing. Returns the line for the detail text.
func _destruct(where: String, type_index: int, problems: PackedStringArray) -> String:
	var before: Array = _s.q.tokens.counts()
	var swaps_before: int = _s.swaps.size()
	var destroyed_before: int = _s.count("destroyed")
	_s.q.kit.need(problems, not _s.controller.can_swap(0), "%s: the Unit is reported inside its own Base, so a press would swap it" % where)
	await _s.q.tokens.destruct(0)
	return _judged(where, type_index, before, swaps_before, destroyed_before, problems)


## What a Self-destruct that was not a swap must have done to Player 1, read after the press: the
## destruction announced, no swap, one Token of the type spent and nothing else, the full delay running
## and the countdown showing. Returns the line for the detail text.
func _judged(where: String, type_index: int, before: Array, swaps_before: int, destroyed_before: int, problems: PackedStringArray) -> String:
	var tokens: Tokens = _s.q.tokens
	var delay: float = _s.controller.rules.respawn_delay_seconds
	_s.q.kit.need(problems, _s.count("destroyed") == destroyed_before + 1 and _s.swaps.size() == swaps_before, "%s: %d destructions and %d swaps announced" % [where, _s.count("destroyed") - destroyed_before, _s.swaps.size() - swaps_before])
	_s.q.kit.need(problems, tokens.counts() == Tokens.charged(before, 0, type_index), "%s: counts %s, expected %s" % [where, tokens.counts(), Tokens.charged(before, 0, type_index)])
	_s.q.kit.need(problems, _s.controller.seconds_until_respawn(0) > delay - 0.1 and _s.q.units.countdowns[0].visible, "%s: %.2f s of delay, countdown shown %s" % [where, _s.controller.seconds_until_respawn(0), _s.q.units.countdowns[0].visible])
	return "%s: destroyed, Token %s %d -> %d, %.2f s wait" % [where, _s.q.units.stats(type_index).type_id, before[0][type_index], tokens.counts()[0][type_index], _s.controller.seconds_until_respawn(0)]


## Player 1 plays its last Motorbike, swaps it at home (no loss, the Motorbike chosen again), then
## Self-destructs the new one outside: the Round is lost and Player 2 wins. AC-1, AC-2 and AC-4.
func _last_motorbike() -> void:
	var problems: PackedStringArray = []
	var tokens: Tokens = _s.q.tokens
	for _spend: int in 2:
		if tokens.counts()[0][Quick.MOTORBIKE] > 1:
			_move_out(0, _s.outside_point(0))
			await _s.q.kit.advance(Swap.OUT_SETTLE_TICKS)
			await tokens.destruct(0)
			await _s.play(0, Quick.MOTORBIKE)
	_s.q.kit.need(problems, tokens.counts()[0][Quick.MOTORBIKE] == 1, "Player 1 does not hold its last Motorbike Token: %s" % [tokens.counts()[0]])
	var before: Array = tokens.counts()
	var swaps_before: int = _s.swaps.size()
	await tokens.destruct(0)
	_s.q.kit.need(problems, _s.swaps.size() == swaps_before + 1 and not _s.controller.is_round_over() and tokens.counts() == before, "the swap of the last Motorbike: %d swaps, over=%s, counts %s" % [_s.swaps.size() - swaps_before, _s.controller.is_round_over(), tokens.counts()])
	_s.q.kit.need(problems, _s.q.units.panels[0].visible and _s.controller.can_choose(0, Quick.MOTORBIKE), "the Motorbike cannot be chosen again after the swap (panel %s)" % _s.q.units.panels[0].visible)
	await _s.play(0, Quick.MOTORBIKE)
	_move_out(0, _s.outside_point(0))
	await _s.q.kit.advance(Swap.OUT_SETTLE_TICKS)
	await tokens.destruct(0)
	_s.q.kit.need(problems, _s.controller.is_round_over() and _s.controller.winner_index() == 1 and tokens.counts()[0][Quick.MOTORBIKE] == 0, "the Self-destruct outside: over=%s winner=%d Motorbike Tokens %d" % [_s.controller.is_round_over(), _s.controller.winner_index(), tokens.counts()[0][Quick.MOTORBIKE]])
	_s.q.kit.need(problems, not _s.controller.can_swap(0) and not _s.controller.can_swap(1), "can_swap() is true after the Round is over (Player 2's Unit is in play inside its Base): %s %s" % [_s.controller.can_swap(0), _s.controller.can_swap(1)])
	_s.q.kit.verdict("last_motorbike", problems, "swapped at home with 1 Motorbike Token left: the Round ran on, the count stayed 1 and the Motorbike was chosen again; Self-destructed outside: Round over, Player 2 wins, Player 1 has %d Motorbike Tokens, and nobody can swap once the Round is over" % tokens.counts()[0][Quick.MOTORBIKE])
