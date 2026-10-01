extends RefCounted
## Scenario canister_showcase of the split screen evidence harness (split_screen_harness.gd): about
## 45 s for the retained screenshots of Story 004's Water Canister run, the HUDs and the Round-over
## screen. Both Players idle on their Bases (both HUDs, both canisters in view). Player 2 parks
## west of the lane; Player 1 drives to Base 2, touches canister 2 and carries it (on its tail, its
## line reads carrying, Player 2's reads away), turns back east and stops; Player 1 presses its
## debug key until its Unit is destroyed, and the canister lies there while Player 1's view counts
## the respawn down. Player 2 recovers it and carries it home, re-seated as it enters its zone, then
## parks again. Player 1, back on its Base, steals it a second time, turns east and runs it into
## Base 1's zone: the Round-over screen in both views, the game frozen; the restart key puts
## everything back and the new Round idles. Every drive is real keys (W A S D, the arrows, the
## debug key 1 and the restart key), the throttle feathered under CRUISE_SPEED and the steer aimed
## at the step's target each tick, so no path is typed; the targets keep the two Units apart (the
## RESULT line carries their closest approach). No checks in a normal run: it ends with RESULT ok;
## a run that did not reach its steps (a drive that gave up, or a steal, recovery or win that never
## came) prints one failing CHECK named premise, so an empty recording cannot pass as evidence.
##
## SPLIT lines come every 0.5 s and at every Round and canister signal (an event= field). They
## carry both Units' positions, hit points and alive flags, each Player's canister status, both
## canisters' states, the Round state and frame=, the main-loop iterations so far: in a
## --write-movie run
## that is the number of the next PNG (one per iteration, 60 a second, so the PNG of time t is
## about t x 60; the renderer may skip a draw, so drawn frames would run behind the PNGs).
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md, Test Evidence
## (retained screenshots: both HUDs during play, a carry state, the Round-over screen). Tooling
## only: nothing under src/ depends on this file.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/show.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=canister_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the debug key and the Players.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 004 helpers (canister_kit.gd): the signal record and the names.
const Canisters: GDScript = preload("res://tools/evidence/split_screen/canister_kit.gd")

## Player 1: the thief, hit by its own debug key.
const THIEF: int = Harness.PLAYER_1
## Player 2: the owner of the canister the run is played with.
const OWNER: int = Harness.PLAYER_2
## The restart key: project.godot binds round_restart to it (tools are the only place key codes
## appear).
const KEYS_RESTART: Array[Key] = [KEY_R]
## Interval between progress lines, seconds.
const REPORT_SECONDS: float = 0.5
## Drive speed the throttle is feathered under, m/s: fast to watch, slow enough to stop on a pad.
const CRUISE_SPEED: float = 10.0
## A drive to a spot ends within this of it, metres (the Unit then brakes).
const ARRIVE_METRES: float = 2.5
## No steer while the target lies within this of the Unit's centre line, metres.
const STEER_DEADBAND_METRES: float = 1.0
## Ticks a step may take before it is given up (the premise check reports it).
const STEP_LIMIT_TICKS: int = 900
## Where Player 2 parks, west of the lane, out of every path Player 1 drives.
const PARK_SPOT: Vector3 = Vector3(-12.0, 0.0, 0.0)
## Where Player 1 stops with the stolen canister and is destroyed: east of the lane, off both zones.
const DROP_SPOT: Vector3 = Vector3(14.0, 0.0, -4.0)
## Where Player 1 turns east after its second steal, before the run home, clear of Player 2's park.
const WAYPOINT: Vector3 = Vector3(12.0, 0.0, -8.0)
## The pauses of the choreography, by phase name, seconds: the moments a screenshot is taken at.
const HOLDS: Dictionary[StringName, float] = {&"idle": 1.5, &"carry": 1.5, &"dropped": 1.5, &"recovered": 0.5,
	&"reseated": 1.0, &"round_over": 2.5, &"restarted": 2.5}

var _harness: Harness
var _kit: Kit
var _cans: Canisters
var _report_ticks: int = 1
## Ticks each drive step took, by step name, in order; -1 when it gave up.
var _steps: Dictionary[StringName, int] = {}


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_cans = Canisters.new(harness, _kit)
	_kit.on_tick = _note_tick
	_report_ticks = _harness.ticks_in(REPORT_SECONDS)
	_connect_lines(_cans.controller)
	_line("")
	await _hold(&"idle")
	await _go(&"p2_clears_lane", OWNER, PARK_SPOT)
	await _brake(OWNER)
	await _fetch(&"p1_steals", THIEF)
	await _brake(THIEF)
	await _hold(&"carry")
	await _go(&"p1_turns_back", THIEF, DROP_SPOT)
	await _brake(THIEF)
	await _destroy(&"p1_destroyed", THIEF)
	await _hold(&"dropped")
	await _fetch(&"p2_recovers", OWNER)
	await _hold(&"recovered")
	await _run_in(&"p2_carries_home", OWNER, func() -> bool: return not _cans.seats.is_empty())
	await _brake(OWNER)
	await _hold(&"reseated")
	await _go(&"p2_parks", OWNER, PARK_SPOT)
	await _brake(OWNER)
	await _wait_alive(&"p1_back", THIEF)
	await _fetch(&"p1_steals_again", THIEF)
	await _brake(THIEF)
	await _go(&"p1_turns_east", THIEF, WAYPOINT)
	await _run_in(&"p1_delivers", THIEF, func() -> bool: return not _cans.round_overs.is_empty())
	await _hold(&"round_over")
	_harness.phase = &"restart"
	await _kit.press_settled(KEYS_RESTART)
	await _hold(&"restarted")
	_harness.phase = &"end"
	_line("")
	_finish()


## Prints a progress line, with its event named, at every Round and canister signal.
func _connect_lines(controller: MatchController) -> void:
	controller.canister_picked_up.connect(func(carrier: int, index: int) -> void: _line("canister_%d_picked_up_by_p%d" % [index + 1, carrier + 1]))
	controller.canister_dropped.connect(func(index: int) -> void: _line("canister_%d_dropped" % (index + 1)))
	controller.canister_seated.connect(func(index: int) -> void: _line("canister_%d_seated" % (index + 1)))
	controller.round_over.connect(func(winner: int) -> void: _line("round_over_p%d_wins" % (winner + 1)))
	controller.round_started.connect(func() -> void: _line("round_started"))
	controller.unit_destroyed.connect(func(player: int) -> void: _line("p%d_destroyed" % (player + 1)))
	controller.unit_spawned.connect(func(player: int) -> void: _line("p%d_spawned" % (player + 1)))


## Drives a Player's Unit at the step's target each tick, the throttle feathered under CRUISE_SPEED
## and the steer toward the target when it lies off the centre line or behind, until done() holds
## after a tick or STEP_LIMIT_TICKS passed. Every key is up when it returns; files the ticks under
## the step's name, or -1.
func _drive(step: StringName, player: int, target: Callable, done: Callable) -> void:
	_harness.phase = step
	var unit: Unit = _cans.units[player]
	_steps[step] = -1
	for count: int in range(1, STEP_LIMIT_TICKS + 1):
		var local: Vector3 = unit.to_local(target.call())
		var steer: int = 0
		if local.z > 0.0 or absf(local.x) > STEER_DEADBAND_METRES:
			steer = 1 if local.x < 0.0 else -1
		_harness.drive(player, 1 if unit.current_speed < CRUISE_SPEED else 0, steer)
		await _kit.tick()
		if done.call():
			_steps[step] = count
			break
	_harness.drive(player, 0, 0)


## A drive to a spot: done within ARRIVE_METRES of it, on the ground plane.
func _go(step: StringName, player: int, spot: Vector3) -> void:
	var there: Callable = func() -> bool:
		var at: Vector3 = _cans.units[player].global_position
		return Vector2(at.x, at.z).distance_to(Vector2(spot.x, spot.z)) <= ARRIVE_METRES
	await _drive(step, player, func() -> Vector3: return spot, there)


## A drive at canister 2 (wherever it stands) until the Player's Unit carries it.
func _fetch(step: StringName, player: int) -> void:
	var canister: WaterCanister = _cans.canisters[OWNER]
	await _drive(step, player, func() -> Vector3: return canister.global_position,
		func() -> bool: return canister.carrier == _cans.units[player])


## A drive at the Player's own Base's spawn point until done() holds (a re-seat, or the win).
func _run_in(step: StringName, player: int, done: Callable) -> void:
	await _drive(step, player, func() -> Vector3: return _cans.bases[player].spawn_point.global_position, done)


## Holds the reverse key until the Unit's drive speed is not forward any more, then lets go.
func _brake(player: int) -> void:
	var unit: Unit = _cans.units[player]
	var limit: int = STEP_LIMIT_TICKS
	while unit.current_speed > 0.0 and limit > 0:
		_harness.drive(player, -1, 0)
		await _kit.tick()
		limit -= 1
	_harness.drive(player, 0, 0)


## Presses the Player's debug key, settled, until its Unit is destroyed (at most the presses the
## data needs); files the presses under the step's name, or -1 when the Unit survived them.
func _destroy(step: StringName, player: int) -> void:
	_harness.phase = step
	var unit: Unit = _cans.units[player]
	var damage: float = _cans.controller.rules.debug_damage
	var presses_max: int = ceili(unit.stats.max_hit_points / damage) if damage > 0.0 else 0
	var presses: int = 0
	while unit.is_alive and presses < presses_max:
		await _kit.press_settled(Kit.KEYS_DEBUG_1 if player == Harness.PLAYER_1 else Kit.KEYS_DEBUG_2)
		presses += 1
	_steps[step] = presses if not unit.is_alive else -1


## Waits, keys up, until the Player's Unit is alive (its respawn), within the delay and a slack;
## files the ticks waited under the step's name, or -1.
func _wait_alive(step: StringName, player: int) -> void:
	_harness.phase = step
	var limit: int = _harness.ticks_in(_cans.controller.rules.respawn_delay_seconds) + Kit.RESPAWN_SLACK_TICKS
	_steps[step] = -1
	for count: int in range(0, limit + 1):
		if _cans.controller.is_alive(player):
			_steps[step] = count
			return
		await _kit.tick()


## Holds every key up for the phase's seconds (HOLDS), under its name.
func _hold(phase: StringName) -> void:
	_harness.phase = phase
	await _kit.advance(_harness.ticks_in(HOLDS[phase]))


## After every tick the kit waits: prints a progress line when one is due.
func _note_tick() -> void:
	if _harness.ticks % _report_ticks == 0:
		_line("")


## Prints one SPLIT line: time, main-loop iterations, phase, both Units' place, hit points, alive flag and
## canister status, both canisters' states, the Round state and the event when there is one.
func _line(event: String) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _cans.units[player]
		fields.append("p%d_x=%.2f p%d_z=%.2f p%d_hp=%.0f p%d_alive=%s p%d_status=%s" % [player + 1, unit.global_position.x,
			player + 1, unit.global_position.z, player + 1, unit.hit_points, player + 1, unit.is_alive, player + 1,
			_cans.status_name(player)])
	var controller: MatchController = _cans.controller
	print("SPLIT %s t=%.3f frame=%d phase=%s %s canister_1=%s canister_2=%s round=%s winner=%d%s" % [
		_harness.scenario, _harness.time(), Engine.get_process_frames(), _harness.phase, " ".join(fields), _cans.state_name(0),
		_cans.state_name(1), "OVER" if controller.is_round_over() else "RUNNING", controller.winner_index(),
		"" if event.is_empty() else " event=" + event])


## Prints the failing premise check when the run did not reach its steps (a step that gave up, or
## not two steals, one recovery and the thief's win), then the RESULT line.
func _finish() -> void:
	var steps: PackedStringArray = []
	var missed: PackedStringArray = []
	for step: StringName in _steps:
		steps.append("%s:%d" % [step, _steps[step]])
		if _steps[step] < 0:
			missed.append(String(step))
	var steals: int = _picks_of(THIEF, OWNER)
	var recoveries: int = _picks_of(OWNER, OWNER)
	var winner: int = _cans.round_overs[0].x if not _cans.round_overs.is_empty() else MatchController.NO_WINNER
	if not (missed.is_empty() and steals == 2 and recoveries == 1 and winner == THIEF):
		_harness.check("premise", false, "the run did not reach its steps: missed=[%s] steals=%d (expected 2) recoveries=%d (1) winner=%d (%d)" % [
			",".join(missed), steals, recoveries, winner, THIEF])
	_harness.finish("steps=%s steals=%d recoveries=%d dropped=%d seated=%d round_over=%d winner=%d restarted=%d separation_min=%.2f wall_clearance_min=%.2f" % [
		",".join(steps), steals, recoveries, _cans.drops.size(), _cans.seats.size(), _cans.round_overs.size(), winner, _cans.round_started,
		_harness.separation_min, _harness.wall_clearance_min])


## The pick-ups of the canister of canister_index by the Unit of carrier in the record: the steals
## and the recoveries of the run.
func _picks_of(carrier: int, canister_index: int) -> int:
	return _cans.pick_ups.filter(func(pick: Vector3i) -> bool: return pick.x == carrier and pick.y == canister_index).size()
