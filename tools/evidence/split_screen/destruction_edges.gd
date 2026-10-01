extends RefCounted
## The checks the verification of Story 003 added to the destruction scenario (destruction.gd), apart from the two
## about a blocked respawn (blocked_spawn.gd): player_2_respawn (Player 2's own destruction and respawn, after
## driving it off its Base: the first destruction of the scenario is Player 1's, so an index slip in the
## controller's respawn path would pass without it), paused_wait (a tree paused for longer than the whole delay
## does not eat the wait: it ends the full delay after the unpause; see MatchController), destroyed_at_speed
## (a Unit destroyed while it drives, with the throttle still held, is at rest and out of play from the signal
## on) and held_keys (a Self-destruct key and the debug key held down act once per press, not once per tick).
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-2, AC-3, AC-4, AC-5,
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
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")

## The throttle is held until the Unit moves at this fraction of its top speed (stats.max_speed): the
## destruction must happen while it is moving.
const SPEED_FRACTION: float = 0.5
## The longest the throttle is held to get there, seconds.
const SPEED_LIMIT_SECONDS: float = 4.0
## A key held down for the held_keys check stays down this many ticks after the respawn it provoked.
const HELD_EXTRA_TICKS: int = 20
## The debug key is held down this many ticks.
const HELD_DEBUG_TICKS: int = 30
## The pause lasts the delay times this: longer than the whole wait, so a wait that ran on under the
## pause would be over before the unpause.
const PAUSE_DELAY_FACTOR: float = 1.2
## The pause begins this fraction of the first wait after the destruction.
const PAUSE_AFTER_FRACTION: float = 0.15

var _kit: Kit
var _log: Log
var _harness: Harness


func _init(check_kit: Kit, record: Log) -> void:
	_kit = check_kit
	_log = record
	_harness = record.harness


## AC-1, AC-3 and AC-7: Player 2 drives off its Base and comes to rest, then destroys itself with Enter:
## its wait is as long as the first, it is out of play throughout and it respawns on Player 2's own Base,
## facing its way, with its camera snapped there (the wreck and the camera were away from the Base).
func check_player_2_respawn() -> void:
	await _log.drive(Harness.PLAYER_2, &"p2_drive_away")
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_2, Harness.PLAYER_2)
	await _log.wait_respawn(wait)
	var problems: PackedStringArray = []
	var detail: String = _log.read_spawn(Harness.PLAYER_2, problems)
	var away: float = wait.wreck.distance_to(_log.bases[Harness.PLAYER_2].spawn_point.global_position)
	_kit.need(problems, wait.spawned_tick >= 0 and wait.in_play == 0 and wait.length() == _log.reference_ticks,
		"wait of %d ticks (expected %d), %d samples in play" % [wait.length(), _log.reference_ticks, wait.in_play])
	_kit.need(problems, away >= Log.MOVE_MIN_DISTANCE and wait.camera_gap > Kit.SPAWN_TOLERANCE,
		"the wreck lay on the Base or the camera was already there")
	_kit.verdict("player_2_respawn", problems, ("%s | the wreck lay %.2f m from the Base and the camera %.2f m from its offset "
		+ "point there the tick before") % [detail, away, wait.camera_gap])


## A wait across a pause: the tree is paused for PAUSE_DELAY_FACTOR times the delay, a little way into a
## wait. seconds_until_respawn() stays where it was while paused, nothing spawns while paused, the
## physics frame counter does advance (else the check proves nothing), and the Unit respawns the whole
## delay of unpaused time after its destruction: the wait is the first wait's length plus the pause.
func check_paused_wait() -> void:
	var problems: PackedStringArray = []
	var tree: SceneTree = _harness.get_tree()
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	var paused_after: int = maxi(roundi(PAUSE_AFTER_FRACTION * float(_log.reference_ticks)), 1)
	await _kit.advance(paused_after)
	var before: float = _log.controller.seconds_until_respawn(Harness.PLAYER_1)
	var pause_ticks: int = _harness.ticks_in(PAUSE_DELAY_FACTOR * _log.controller.rules.respawn_delay_seconds)
	var frames_at_pause: int = Engine.get_physics_frames()
	tree.paused = true
	var drift: float = 0.0
	for _i: int in pause_ticks:
		await _kit.tick()
		drift = maxf(drift, absf(_log.controller.seconds_until_respawn(Harness.PLAYER_1) - before))
	var frames_paused: int = Engine.get_physics_frames() - frames_at_pause
	var spawned_while_paused: bool = wait.spawned_tick >= 0
	tree.paused = false
	await _log.wait_respawn(wait)
	var expected: int = _log.reference_ticks + pause_ticks
	_kit.need(problems, frames_paused >= pause_ticks,
		"the physics frame counter advanced %d while %d ticks were paused" % [frames_paused, pause_ticks])
	_kit.need(problems, not spawned_while_paused, "the Unit respawned while the tree was paused")
	_kit.need(problems, is_zero_approx(drift), "seconds_until_respawn drifted by %.6f s while paused" % drift)
	_kit.need(problems, wait.spawned_tick >= 0 and wait.length() == expected,
		"the wait was %d ticks, expected %d (the first wait's %d plus %d paused)" % [wait.length(), expected, _log.reference_ticks, pause_ticks])
	_kit.verdict("paused_wait", problems, ("destroyed at tick %d; the tree paused for %d ticks from the %d-tick mark (the frame counter "
		+ "advanced %d), seconds_until_respawn frozen at %.4f (drift %.6f) with no spawn while paused; unit_spawned at tick %d = a wait of "
		+ "%d ticks (expected %d + %d paused = %d)") % [
			wait.destroyed_tick, pause_ticks, paused_after,
			frames_paused, before, drift, wait.spawned_tick, wait.length(), _log.reference_ticks, pause_ticks, expected])



## AC-2 and AC-5: a Unit destroyed while it drives. Player 1 holds the throttle until the Unit moves at
## SPEED_FRACTION of its top speed, then presses Tab with the throttle still held. From the signal on, every
## tick of the wait finds it at rest and out of play (the sampler of wait_log.gd reads velocity and speed), so
## a destroy() that left the motion alone fails: the Unit was moving. It respawns at rest on its Base.
func check_destroyed_at_speed() -> void:
	var problems: PackedStringArray = []
	var unit: Unit = _log.units[Harness.PLAYER_1]
	var wanted: float = SPEED_FRACTION * unit.stats.max_speed
	_harness.apply(DriveStep.new(&"p1_to_speed", SPEED_LIMIT_SECONDS, Harness.PLAYER_1, 1, 0))
	var limit: int = _harness.ticks_in(SPEED_LIMIT_SECONDS)
	while unit.current_speed < wanted and limit > 0:
		await _kit.tick()
		limit -= 1
	var speed: float = unit.current_speed
	var velocity: float = unit.velocity.length()
	var wait: Wait = await _log.kill(Kit.KEYS_DESTRUCT_1, Harness.PLAYER_1)
	_harness.release_all()
	await _log.wait_respawn(wait)
	_kit.need(problems, speed >= wanted and velocity > 1.0,
		"the Unit moved at %.2f m/s (velocity %.2f), not at the %.2f m/s wanted, when Tab was pressed" % [speed, velocity, wanted])
	_kit.need(problems, wait.destroyed_tick >= 0 and wait.in_play == 0 and wait.spawned_tick >= 0,
		"%d of %d samples of the wait had the Unit in play or moving" % [wait.in_play, wait.seconds.size()])
	var state: PackedStringArray = []
	var landed: String = _log.read_spawn(Harness.PLAYER_1, state)
	_kit.need(problems, state.is_empty(), "after the respawn %s" % "; ".join(state))
	_kit.verdict("destroyed_at_speed", problems, ("Tab pressed with the throttle held at %.2f m/s (velocity %.2f, wanted at least %.2f); "
		+ "%d samples from the signal to the respawn, %d of them with the Unit in play or moving | %s") % [
			speed, velocity, wanted, wait.seconds.size(), wait.in_play, landed])


## AC-5 and AC-8: keys held down act once per press. Tab held through a whole wait and past the respawn
## destroys the Unit once (the respawned Unit is not destroyed again, so one destroyed signal of the Unit
## and of the controller, one spawn, the Unit alive at the end), and Player 1's debug key held for
## HELD_DEBUG_TICKS takes off exactly one debug_damage.
func check_held_keys() -> void:
	var problems: PackedStringArray = []
	var unit: Unit = _log.units[Harness.PLAYER_1]
	var destroyed: int = _log.destroyed[0]
	var spawned: int = _log.spawned[0]
	var emits: int = _log.unit_emits[0]
	_set_keys(Kit.KEYS_DESTRUCT_1, true)
	await _kit.advance(_log.reference_ticks + HELD_EXTRA_TICKS)
	_set_keys(Kit.KEYS_DESTRUCT_1, false)
	await _kit.advance(Kit.TICK_SLACK + 1)
	var added: Array[int] = [_log.destroyed[0] - destroyed, _log.spawned[0] - spawned, _log.unit_emits[0] - emits]
	_kit.need(problems, added == [1, 1, 1] and unit.is_alive and is_equal_approx(unit.hit_points, unit.stats.max_hit_points),
		"Tab held for %d ticks gave unit_destroyed +%d unit_spawned +%d Unit signals +%d (expected 1 each), alive=%s hit_points=%.1f" % [
			_log.reference_ticks + HELD_EXTRA_TICKS, added[0], added[1], added[2], unit.is_alive, unit.hit_points])
	var before: float = unit.hit_points
	var expected: float = before - _log.controller.rules.debug_damage
	_set_keys(Kit.KEYS_DEBUG_1, true)
	await _kit.advance(HELD_DEBUG_TICKS)
	_set_keys(Kit.KEYS_DEBUG_1, false)
	await _kit.advance(Kit.TICK_SLACK + 1)
	_kit.need(problems, is_equal_approx(unit.hit_points, expected),
		"the debug key held for %d ticks left %.1f hit points, expected %.1f (one press)" % [HELD_DEBUG_TICKS, unit.hit_points, expected])
	_kit.verdict("held_keys", problems, ("Tab held %d ticks (a wait of %d and %d more): unit_destroyed +%d unit_spawned +%d the Unit's own signal +%d; "
		+ "the debug key held %d ticks: hit_points %.1f -> %.1f (one press takes %.1f)") % [
			_log.reference_ticks + HELD_EXTRA_TICKS, _log.reference_ticks, HELD_EXTRA_TICKS, added[0], added[1], added[2],
			HELD_DEBUG_TICKS, before, unit.hit_points, _log.controller.rules.debug_damage])


## Presses or releases a set of keys, without waiting.
func _set_keys(keys: Array[Key], down: bool) -> void:
	for key: Key in keys:
		_harness.set_key(key, down)
