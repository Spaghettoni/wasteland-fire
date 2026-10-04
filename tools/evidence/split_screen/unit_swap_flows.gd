extends RefCounted
## The second half of scenario unit_swap (unit_swap.gd): what a swap must not decide and what is
## data, played with real keys on the Round after the one Player 1 lost. swap_vs_delivery: Player 1
## brings Player 2's Flag into its own Base and presses Self-destruct on the very tick the zone
## reports it, and the delivery wins before any swap; swap_vs_homecoming: Player 1 brings its own
## Flag home and presses on the tick the zone reports it, and the Flag is re-seated before the swap,
## which then takes nothing; swap_vs_destruction: a Gyrocopter whose tank runs dry on the tick of
## the press crashes and stays destroyed; swap_hint: a stranded Unit at home shows the
## swap text with its Player's own key, the text follows the Unit across its gate within three ticks
## and the key then swaps it; swap_data: with the swap switched off the same press destroys, every
## Base zone watches every type's physics layer, and a Round whose zone does not watch the
## Gyrocopter's layer is refused. A key set at a tick's start acts on the next tick (the runner's own
## rule), so the presses of the first three checks are timed from a measured zone latency: the zone
## reports a Unit put inside a fixed number of ticks later, and the key is set so that it acts on the
## tick the zone first reports it, the tick of the delivery or the homecoming.
## Implements: production/epics/wasteland-fire/story-011-unit-swap-at-own-base.md AC-2 to AC-5.
## Tooling only. Loaded by unit_swap.gd with a preload constant.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 007 helpers (map_kit.gd): the settle ticks after a teleport.
const Map: GDScript = preload("res://tools/evidence/split_screen/map_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 008 helpers (token_kit.gd): real keys, the engine log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## The Story 011 helpers (unit_swap_kit.gd).
const Swap: GDScript = preload("res://tools/evidence/split_screen/unit_swap_kit.gd")

## The share of its tank a Gyrocopter's copy spawns with: one Fuel unit, under a second of hovering.
const GYRO_TANK: float = 0.01
## The share a ground Unit's copy spawns with: dry within a second standing.
const SMALL_TANK: float = 0.005
## Fuel units under one tick's burn at which the next tick empties the tank.
const FUEL_EPS: float = 0.0001
## Ticks a hint is given to follow a Unit across its gate: the zone's report (about two) and a frame.
const HINT_TICKS: int = 3

## The words of the hint while the key swaps the Unit, as the story states them (AC-4); %s is the key.
const SWAP_TEXT: String = "Out of Fuel! Press %s to swap your Unit"

## The ticks the zone takes to report a Unit put inside its Base, measured once at the start of run().
var _latency: int = 0

## The engine errors this script causes on purpose (the refused Round of swap_data), for the noise
## check.
var expected_errors: int = 0

var _s: Swap


func _init(kit: Swap) -> void:
	_s = kit


## Restarts the Round, then the five checks in order. A coroutine: await it.
func run() -> void:
	await _s.restart_and_play()
	_latency = await _s.zone_latency(0)
	await _delivery()
	await _s.restart_and_play()
	await _homecoming()
	await _crash()
	await _hints()
	await _data()
	var noise: PackedStringArray = []
	var errors: Array[String] = _s.q.tokens.engine_log.errors
	var warnings: Array[String] = _s.q.tokens.engine_log.warnings
	_s.q.kit.need(noise, errors.size() == expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), expected_errors, warnings])
	_s.q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d, the refusal of swap_data accounts for %d" % [errors.size(), warnings.size(), expected_errors])


## Player `player` takes the other Player's Flag with real drive keys: placed 6 m in front of the
## Flag on its Base's gate side, facing it, and driven in until it is carried. A coroutine.
func _steal(player: int) -> void:
	var foe: int = 1 - player
	_s.flags.approach(player, _s.q.units.bases[foe].flag_seat.global_position, _s.gate_way(foe))
	await _s.q.kit.advance(Map.SETTLE_TICKS)
	await _s.flags.drive_until(player, 1, Swap.CRUISE, func() -> bool:
		return _s.controller.flag_status(player) == MatchController.FlagStatus.CARRYING_ENEMY)


## Player 1 carries Player 2's Flag into its own Base, put just inside its walls, with the Self-destruct
## key set to act on the first tick the zone reports it: the delivery of that tick wins the Round and
## no swap is made. AC-3.
func _delivery() -> void:
	var problems: PackedStringArray = []
	var before: Array = _s.q.tokens.counts()
	var swaps_before: int = _s.swaps.size()
	await _steal(0)
	_s.q.kit.need(problems, _s.controller.flag_status(0) == MatchController.FlagStatus.CARRYING_ENEMY, "Player 1 never took Player 2's Flag")
	var press_tick: int = await _s.enter_pressing(0, _latency, 0)
	var won: Vector2i = _s.flags.round_overs[-1] if not _s.flags.round_overs.is_empty() else Vector2i(-1, -1)
	_s.q.kit.need(problems, won == Vector2i(0, press_tick), "Round won %s, the press acted on tick %d" % [won, press_tick])
	_s.q.kit.need(problems, _s.swaps.size() == swaps_before and _s.controller.is_alive(0), "a swap was made (%d) or the Unit was put away" % (_s.swaps.size() - swaps_before))
	_s.q.kit.need(problems, _s.q.tokens.counts() == before, "the Token counts changed %s -> %s" % [before, _s.q.tokens.counts()])
	_s.q.kit.verdict("swap_vs_delivery", problems, "the key acted on tick %d, the tick the zone first reported the Carrier (%d ticks after it was put in): the Round was won on tick %d by Player 1 with %d swaps and the counts as before" % [press_tick, _latency, won.y, _s.swaps.size() - swaps_before])


## Player 2 takes Player 1's Flag and Self-destructs outside Player 1's gate, so the Flag drops there;
## Player 1 picks it up and is put inside its Base with the key set to act on the first tick the zone
## reports it: that tick re-seats the Flag and only then swaps the Unit, which takes nothing. AC-3.
func _homecoming() -> void:
	var problems: PackedStringArray = []
	await _steal(1)
	_s.flags.teleport(1, _s.outside_point(0), _s.gate_way(0))
	await _s.q.kit.advance(Swap.OUT_SETTLE_TICKS)
	await _s.q.tokens.destruct(1)
	var flag: Flag = _s.flags.flags[0]
	_s.q.kit.need(problems, not _s.flags.drops.is_empty() and _s.flags.drops[-1].x == 0, "Player 1's Flag did not drop at Player 2's wreck")
	var picked: int = _s.flags.pick_ups.size()
	_s.flags.teleport(0, flag.global_position, _s.gate_way(0))
	_s.q.kit.need(problems, await _s.wait_until(func() -> bool: return _s.flags.pick_ups.size() > picked), "Player 1 never picked its own Flag up")
	var before: Array = _s.q.tokens.counts()
	var since: int = _s.order.size()
	var tick: int = await _s.enter_pressing(0, _latency, 0)
	var expected: PackedStringArray = ["%d seated 0" % tick, "%d swapped 0" % tick]
	_s.q.kit.need(problems, _s.order.slice(since) == expected, "events %s, expected %s" % [_s.order.slice(since), expected])
	_s.q.kit.need(problems, flag.state == Flag.State.AT_HOME and _s.controller.flag_status(0) == MatchController.FlagStatus.OWN_AT_HOME, "the Flag is %s, status %s" % [_s.flags.state_name(0), _s.flags.status_name(0)])
	_s.q.kit.need(problems, _s.controller.is_choosing(0) and _s.q.tokens.counts() == before, "Player 1 choosing %s, counts %s -> %s" % [_s.controller.is_choosing(0), before, _s.q.tokens.counts()])
	_s.q.kit.verdict("swap_vs_homecoming", problems, "the key acted on tick %d, the tick the zone first reported the Carrier of its own Flag: %s; the Flag stands on its seat, nothing was carried away and the counts are as before" % [tick, ", ".join(_s.order.slice(since))])


## Player 1's Gyrocopter, with a copy of its stats that has one Fuel unit, hovers dry; the key is set
## two ticks before the tank empties, so it acts on the tick the Unit crashes in (its own tick, before
## the controller's), and the swap finds nobody in play. AC-2.
func _crash() -> void:
	var problems: PackedStringArray = []
	await _s.play(0, Quick.GYROCOPTER)
	var pose: Array[Vector3] = _s.spawn_pose(0)
	await _s.q.put(0, _s.q.small_tank(Quick.GYROCOPTER, GYRO_TANK), pose[0], pose[1])
	var unit: Unit = _s.q.units.units[0]
	var burn: float = unit.stats.fuel_use_idle / float(Engine.physics_ticks_per_second)
	_s.q.kit.need(problems, await _s.wait_until(func() -> bool: return unit.fuel <= 2.0 * burn + FUEL_EPS), "the tank never came to its last two ticks (%.4f Fuel)" % unit.fuel)
	var before: Array = _s.q.tokens.counts()
	var swaps_before: int = _s.swaps.size()
	var destroyed_before: int = _s.count("destroyed")
	var last: float = unit.fuel
	await _s.q.kit.press_settled(Tokens.keys(&"destruct", 0))
	_s.q.kit.need(problems, _s.count("destroyed") == destroyed_before + 1 and _s.swaps.size() == swaps_before, "%d destructions and %d swaps announced" % [_s.count("destroyed") - destroyed_before, _s.swaps.size() - swaps_before])
	_s.q.kit.need(problems, not _s.controller.is_alive(0) and _s.controller.is_choosing(0) and _s.controller.seconds_until_respawn(0) > 0.0, "alive %s, choosing %s, wait %.2f s" % [_s.controller.is_alive(0), _s.controller.is_choosing(0), _s.controller.seconds_until_respawn(0)])
	_s.q.kit.need(problems, _s.q.tokens.counts() == Tokens.charged(before, 0, Quick.GYROCOPTER), "counts %s, expected %s" % [_s.q.tokens.counts(), Tokens.charged(before, 0, Quick.GYROCOPTER)])
	_s.q.kit.verdict("swap_vs_destruction", problems, "the Gyrocopter had %.4f Fuel (one tick's burn is %.4f) when the key was set to act on the tick it emptied: it crashed, the Gyrocopter Token went %d -> %d, the %.2f s wait runs and no swap was made" % [last, burn, before[0][Quick.GYROCOPTER], _s.q.tokens.counts()[0][Quick.GYROCOPTER], _s.controller.seconds_until_respawn(0)])


## Both Players' Units stand stranded in their own Base: each hint says swap, with that Player's own
## key; Player 1's Unit is carried out of its gate and the text becomes the Self-destruct one within
## HINT_TICKS, and back in the swap one; the key then swaps it and the hint goes. AC-4.
func _hints() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	await _s.play(0, Quick.MOTORBIKE)
	await _s.play(1, Quick.BUGGY)
	for player: int in Kit.PLAYERS:
		var pose: Array[Vector3] = _s.spawn_pose(player)
		var type_index: int = Quick.MOTORBIKE if player == 0 else Quick.BUGGY
		await _s.q.put(player, _s.q.small_tank(type_index, SMALL_TANK), pose[0], pose[1])
		_s.q.kit.need(problems, await _s.wait_until(func() -> bool: return _s.q.units.units[player].is_stranded), "p%d never ran dry" % (player + 1))
		await _s.q.kit.advance(HINT_TICKS)
		notes.append(_hint_reading(player, true, "at home", problems))
	var pose_out: Array[Vector3] = _s.spawn_pose(0)
	_s.flags.teleport(0, _s.outside_point(0), _s.gate_way(0))
	await _s.q.kit.advance(HINT_TICKS)
	notes.append(_hint_reading(0, false, "carried out of its gate", problems))
	_s.flags.teleport(0, pose_out[0], pose_out[1])
	await _s.q.kit.advance(HINT_TICKS)
	notes.append(_hint_reading(0, true, "carried back in", problems))
	var swaps_before: int = _s.swaps.size()
	await _s.q.tokens.destruct(0)
	_s.q.kit.need(problems, _s.swaps.size() == swaps_before + 1 and not _s.q.hints[0].visible, "the key swapped %d times, hint shown %s" % [_s.swaps.size() - swaps_before, _s.q.hints[0].visible])
	_s.q.kit.verdict("swap_hint", problems, " | ".join(notes) + " | the key swapped the Unit and the hint went")


## One hint's reading: shown, with the swap text (at home) or the Self-destruct text (elsewhere) and
## that Player's own key. Returns the line for the detail text and adds the problems.
func _hint_reading(player: int, at_home: bool, where: String, problems: PackedStringArray) -> String:
	var hint: SelfDestructHint = _s.q.hints[player]
	var key: String = OS.get_keycode_string(Tokens.keys(&"destruct", player)[0])
	var expected: String = hint.tr(hint.swap_format if at_home else hint.format) % key
	_s.q.kit.need(problems, hint.visible and hint.text == expected, "p%d %s: shown %s '%s', expected '%s'" % [player + 1, where, hint.visible, hint.text, expected])
	_s.q.kit.need(problems, not at_home or hint.text == SWAP_TEXT % key, "p%d %s: the story's words are '%s', the hint reads '%s'" % [player + 1, where, SWAP_TEXT % key, hint.text])
	return "p%d %s '%s'" % [player + 1, where, hint.text]


## The swap is data: its switch off, the same press at home destroys and the hint says Self-destruct;
## every zone watches every type's layer; a zone that does not is refused at begin().
func _data() -> void:
	var problems: PackedStringArray = []
	var rules: MatchRules = _s.controller.rules
	for player: int in Kit.PLAYERS:
		var zone: Area3D = _s.q.units.bases[player].zone
		for stats: UnitStats in rules.unit_types:
			_s.q.kit.need(problems, (zone.collision_mask & stats.collision_layer) != 0, "p%d's zone (mask %d) does not watch the %s layer %d" % [player + 1, zone.collision_mask, stats.type_id, stats.collision_layer])
	rules.own_base_swap = false
	await _s.q.kit.advance(HINT_TICKS)
	var off_text: String = _hint_reading(1, false, "swap off", problems)
	var before: Array = _s.q.tokens.counts()
	var swaps_before: int = _s.swaps.size()
	var destroyed_before: int = _s.count("destroyed")
	await _s.q.tokens.destruct(1)
	_s.q.kit.need(problems, _s.count("destroyed") == destroyed_before + 1 and _s.swaps.size() == swaps_before and _s.q.tokens.counts() == Tokens.charged(before, 1, Quick.BUGGY), "swap off: %d destructions, %d swaps, counts %s" % [_s.count("destroyed") - destroyed_before, _s.swaps.size() - swaps_before, _s.q.tokens.counts()])
	rules.own_base_swap = true
	var refusal: String = _refused_round(problems)
	_s.q.kit.verdict("swap_data", problems, "masks %s | %s, then the press destroyed and took a Token | refusal: %s" % [
		[_s.q.units.bases[0].zone.collision_mask, _s.q.units.bases[1].zone.collision_mask], off_text, refusal])


## begin() of a throwaway MatchController while Player 1's zone watches only the units layer: the Round
## does not begin and the one error names the Gyrocopter. The zone's mask is put back. Returns the text.
func _refused_round(problems: PackedStringArray) -> String:
	var zone: Area3D = _s.q.units.bases[0].zone
	var mask: int = zone.collision_mask
	var units: Array[Unit] = _s.q.units.units.duplicate()
	var bases: Array[Base] = _s.q.units.bases.duplicate()
	var cameras: Array[ChaseCamera] = _s.q.units.cameras.duplicate()
	var throwaway: MatchController = MatchController.new()
	throwaway.name = "Throwaway"
	throwaway.rules = _s.controller.rules
	var errors_before: int = _s.q.tokens.engine_log.errors.size()
	zone.collision_mask = 2
	throwaway.begin(units, bases, cameras, _s.q.harness.split.field.token_stock)
	zone.collision_mask = mask
	expected_errors += 1
	var text: String = ""
	if _s.q.tokens.engine_log.errors.size() == errors_before + 1:
		text = _s.q.tokens.engine_log.errors[-1]
	_s.q.kit.need(problems, text.contains("zone") and text.contains("Gyrocopter") and not throwaway.is_alive(0) and not throwaway.is_choosing(0), "the refusal read '%s'" % text)
	throwaway.free()
	return text
