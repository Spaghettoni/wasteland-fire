extends RefCounted
## Scenario destruction of the split screen evidence harness (split_screen_harness.gd): Story 003 AC-2
## to AC-5, AC-7 and AC-8, played with real key events (Tab, Enter, 1, 2) and judged from the
## MatchController's signals and the Units' own state. Player 1 drives off its Base, takes debug damage
## until destroyed and waits for the respawn tick by tick. This file judges that first destruction and
## the delay (the delay is data: a second wait under another one); destruction_cycles.gd holds the checks
## of the rest of the Round (five cycles, a debug key while waiting and with its gate at zero, Player 2
## untouched, the Self-destruct keys of both Players), destruction_edges.gd the checks the verification
## added (Player 2's own respawn, a wait across a pause, a destruction at speed, keys held down) and
## blocked_spawn.gd the two about a respawn that falls due while another Unit stands on the spawn point (one
## that lands on a spare spawn point on the due tick, one with every spot taken that waits for the spawn point
## to free). Seventeen CHECK lines in all. Every number comes from the game's data; the scenario types only
## the test inputs named in its constants.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-2 to AC-5, AC-7
## and AC-8. Tooling only: nothing under src/ depends on this file. The shared constants and helpers are
## check_kit.gd and wait_log.gd.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=destruction

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## One destruction (wait.gd).
const Wait: GDScript = preload("res://tools/evidence/split_screen/wait.gd")
## The record of the scenario (wait_log.gd).
const Log: GDScript = preload("res://tools/evidence/split_screen/wait_log.gd")
## The checks of the rest of the Round (destruction_cycles.gd).
const Cycles: GDScript = preload("res://tools/evidence/split_screen/destruction_cycles.gd")
## The checks the verification added (destruction_edges.gd).
const Edges: GDScript = preload("res://tools/evidence/split_screen/destruction_edges.gd")
## The checks of a respawn that falls due while another Unit stands on the spawn point (blocked_spawn.gd).
const Blocked: GDScript = preload("res://tools/evidence/split_screen/blocked_spawn.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## The second delay is the data's delay times this: the test that the delay is data.
const OTHER_DELAY_FACTOR: float = 0.5

var _harness: Harness
var _kit: Kit
var _log: Log


## Runs the scenario; the code order is the CHECK order. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_log = Log.new(harness, _kit)
	_kit.on_tick = _log.sample_open
	_log.start()
	await _kit.advance(Kit.START_TICKS)
	_log.note_play()
	for track: UnitTrack in _harness.tracks:
		track.begin()
	_check_hit_points_data()
	await _log.drive(Harness.PLAYER_1, &"drive_away")
	var first: Wait = await _check_debug_damage_steps()
	await _log.wait_respawn(first)
	if first.spawned_tick < 0:
		_harness.check("first_respawn", false, "no respawn after the first destruction (destroyed at tick %d)" % first.destroyed_tick)
		_harness.finish("reason=no_first_respawn")
		return
	_log.reference_ticks = first.length()
	_check_leaves_play(first)
	_check_respawn_state(first)
	await _check_drives_after_respawn()
	await _check_respawn_delay(first)
	await _play_the_rest()
	_harness.phase = &"end"
	_harness.print_progress()
	_harness.finish("respawn_ticks=%d unit_destroyed=%d/%d unit_spawned=%d/%d" % [
		_log.reference_ticks, _log.destroyed[0], _log.destroyed[1], _log.spawned[0], _log.spawned[1]])


## The checks of destruction_cycles.gd, destruction_edges.gd and blocked_spawn.gd, in CHECK order. Player 2's
## own respawn comes after the independence check, which asserts that Player 2 has not moved. The two blocked
## respawns (a spare spawn point on the due tick, then every spot taken) park Player 2's Unit on Player 1's
## spawn point and send it home after. The two that leave Player 1 driving or damaged (a destruction at speed,
## keys held down) come last.
func _play_the_rest() -> void:
	var cycles: Cycles = Cycles.new(_kit, _log)
	var edges: Edges = Edges.new(_kit, _log)
	var blocked: Blocked = Blocked.new(_kit, _log)
	await cycles.check_unlimited()
	await cycles.check_damage_while_dead()
	await cycles.check_debug_gating()
	await cycles.check_independence()
	await edges.check_player_2_respawn()
	await cycles.check_self_destruct()
	await blocked.check_blocked_spawn()
	await blocked.check_blocked_waits()
	await edges.check_paused_wait()
	await edges.check_destroyed_at_speed()
	await edges.check_held_keys()


## AC-2: every Unit's stats give it hit points above zero and it starts with all of them.
func _check_hit_points_data() -> void:
	var problems: PackedStringArray = []
	var detail: PackedStringArray = []
	for index: int in _log.units.size():
		var unit: Unit = _log.units[index]
		var max_hp: float = unit.stats.max_hit_points
		_kit.need(problems, max_hp > 0.0 and is_equal_approx(unit.hit_points, max_hp),
			"player_%d not at full hit points above 0" % (index + 1))
		detail.append("player_%d max_hit_points=%.1f (%s) hit_points=%.1f" % [
			index + 1, max_hp, unit.stats.resource_path.get_file(), unit.hit_points])
	_kit.verdict("hit_points_data", problems, " | ".join(detail))


## AC-2 and AC-8: key 1 takes debug_damage off Player 1's Unit n times, n = ceil(max / damage) - 1, and
## it is alive with the hit points left; one more press destroys it: one unit_destroyed for Player 1,
## none for Player 2, whose Unit is untouched. Returns the wait that opened.
func _check_debug_damage_steps() -> Wait:
	var unit: Unit = _log.units[Harness.PLAYER_1]
	var second: Unit = _log.units[Harness.PLAYER_2]
	var damage: float = _log.controller.rules.debug_damage
	var max_hp: float = unit.stats.max_hit_points
	var presses: int = ceili(max_hp / damage) - 1 if damage > 0.0 else 0
	var problems: PackedStringArray = []
	var levels: PackedStringArray = []
	_kit.need(problems, damage > 0.0, "rules.debug_damage is %.1f: the debug keys are off" % damage)
	for press: int in range(1, presses + 1):
		await _kit.press_settled(Kit.KEYS_DEBUG_1)
		levels.append("%.1f" % unit.hit_points)
		_kit.need(problems, unit.is_alive and is_equal_approx(unit.hit_points, max_hp - float(press) * damage),
			"after press %d: hit_points %.1f alive=%s" % [press, unit.hit_points, unit.is_alive])
	var pressed_at: int = await _kit.press_settled(Kit.KEYS_DEBUG_1)
	var wait: Wait = _log.open_wait(Harness.PLAYER_1)
	var destroyed: Array[int] = _log.destroyed
	_kit.need(problems, not unit.is_alive and is_zero_approx(unit.hit_points) and destroyed[0] == 1 and destroyed[1] == 0,
		"last press: alive=%s hit_points=%.1f unit_destroyed %d/%d (expected 1/0)" % [
			unit.is_alive, unit.hit_points, destroyed[0], destroyed[1]])
	var moved: float = (_harness.tracks[Harness.PLAYER_2] as UnitTrack).moved()
	_kit.need(problems, second.is_alive and is_equal_approx(second.hit_points, second.stats.max_hit_points)
		and moved <= Log.STILL_LIMIT, "Player 2's Unit was touched")
	_kit.verdict("debug_damage_steps", problems, ("max_hit_points=%.1f debug_damage=%.1f: %d presses leave hit_points [%s] alive "
		+ "(expected %.1f); press %d destroys it, %d tick after the key; unit_destroyed %d/%d; player_2 hit_points=%.1f alive=%s") % [
			max_hp, damage, presses, ", ".join(levels), max_hp - float(presses) * damage, presses + 1,
			wait.destroyed_tick - pressed_at, destroyed[0], destroyed[1], second.hit_points, second.is_alive])
	return wait


## AC-2: the destroyed Unit leaves play: every sample from the signal to the tick before the respawn
## found it hidden, on no collision layer or mask, off the physics tick, at rest and not alive, and the
## controller saying the same.
func _check_leaves_play(wait: Wait) -> void:
	var problems: PackedStringArray = []
	_kit.need(problems, wait.in_play == 0 and not wait.seconds.is_empty(),
		"%d of %d samples had the Unit in play" % [wait.in_play, wait.seconds.size()])
	_kit.verdict("leaves_play", problems, ("%d samples (the signal, then every tick of the %d-tick wait): is_alive=false visible=false "
		+ "collision_layer=0 collision_mask=0 physics_processing=false velocity=0 speed=0 "
		+ "controller_is_alive=false; samples that broke it=%d") % [
			wait.seconds.size(), wait.length(), wait.in_play])


## AC-1 and AC-3: the respawned Unit is on Player 1's Base in full working order, and the camera has
## snapped back to its offset: the tick before, it still sat where the wreck was.
func _check_respawn_state(wait: Wait) -> void:
	var problems: PackedStringArray = []
	var detail: String = _log.read_spawn(Harness.PLAYER_1, problems)
	var away: float = wait.wreck.distance_to(_log.bases[Harness.PLAYER_1].spawn_point.global_position)
	_kit.need(problems, away >= Log.MOVE_MIN_DISTANCE and wait.camera_gap > Kit.SPAWN_TOLERANCE,
		"the wreck lay on the Base or the camera was already there")
	_kit.verdict("respawn_state", problems, ("%s | the wreck lay %.2f m from the Base and the camera %.2f m from its offset point "
		+ "there the tick before") % [detail, away, wait.camera_gap])


## AC-3: a Unit that respawned is driven by the throttle again.
func _check_drives_after_respawn() -> void:
	var drove: Vector2 = await _log.drive(Harness.PLAYER_1, &"drive_after_respawn")
	var problems: PackedStringArray = []
	_kit.need(problems, drove.x > 0.0 and drove.y >= Log.MOVE_MIN_DISTANCE, "the respawned Unit did not drive")
	_kit.verdict("drives_after_respawn", problems, ("throttle held %.1f s after the respawn: speed=%.3f m/s (above 0) "
		+ "moved=%.3f m (at least %.1f)") % [Log.DRIVE_SECONDS, drove.x, drove.y, Log.MOVE_MIN_DISTANCE])


## One measurement of respawn_delay: the wait in ticks against round(delay * tick rate), and the
## seconds_until_respawn samples falling every tick from the delay to zero. Adds to problems. The
## expected length is the runner's ticks_in(), written independently of the controller's own rule.
func _delay_line(label: String, wait: Wait, delay: float, problems: PackedStringArray) -> String:
	var expected: int = _harness.ticks_in(delay)
	var falling: bool = wait.seconds.size() > 1
	for index: int in range(1, wait.seconds.size()):
		falling = falling and wait.seconds[index] < wait.seconds[index - 1]
	var from_s: float = wait.seconds[0] if not wait.seconds.is_empty() else -1.0
	var to_s: float = wait.seconds[-1] if not wait.seconds.is_empty() else -1.0
	_kit.need(problems, wait.spawned_tick >= 0 and absi(wait.length() - expected) <= Kit.TICK_SLACK,
		"%s: %d ticks, expected %d +-%d" % [label, wait.length(), expected, Kit.TICK_SLACK])
	_kit.need(problems, falling and is_equal_approx(from_s, delay) and is_zero_approx(to_s),
		"%s: seconds_until_respawn must fall every tick from %.3f to 0" % [label, delay])
	return ("%s delay=%.3f s: unit_destroyed at tick %d, unit_spawned at tick %d = %d ticks (round(delay * %d) = %d); "
		+ "seconds_until_respawn %.4f falling to %.4f over %d samples") % [
			label, delay, wait.destroyed_tick, wait.spawned_tick, wait.length(), Engine.physics_ticks_per_second,
			expected, from_s, to_s, wait.seconds.size()]


## AC-3: the wait is the delay in MatchRules, in ticks and in seconds_until_respawn, and it is data: the
## same measurement under a duplicate of the rules with another delay follows that delay. The
## controller's rules are put back afterwards.
func _check_respawn_delay(first: Wait) -> void:
	var problems: PackedStringArray = []
	var original: MatchRules = _log.controller.rules
	var detail: String = _delay_line("data", first, original.respawn_delay_seconds, problems)
	var other: MatchRules = original.duplicate() as MatchRules
	other.respawn_delay_seconds = original.respawn_delay_seconds * OTHER_DELAY_FACTOR
	_log.controller.rules = other
	var second: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	await _log.wait_respawn(second)
	_log.controller.rules = original
	detail += " | " + _delay_line("duplicate rules", second, other.respawn_delay_seconds, problems)
	_kit.need(problems, _log.controller.rules == original
		and not is_equal_approx(original.respawn_delay_seconds, other.respawn_delay_seconds),
		"the rules were not restored, or the two delays do not differ")
	_kit.verdict("respawn_delay", problems, detail)
