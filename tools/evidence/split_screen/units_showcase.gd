extends RefCounted
## Scenario units_showcase of the split screen evidence harness (split_screen_harness.gd): about
## 40 s for the retained screenshots of Story 005's Unit choice, the four Units and their weapons.
## Both views open on the choice panels with the cursors moving (Player 1 steps right twice and
## back, Player 2 steps right twice to the Truck); both confirm, and each Unit stands on its Base
## and then drives. Both are put down facing each other 16 m apart: Player 1's Motorbike fires a
## burst at the Truck, the Truck fires back and destroys it, and Player 1's view shows the countdown
## with the panel, the cursor moved to the Buggy and the ready line. Player 1 then cycles through
## the Buggy, the Truck and the Gyrocopter by Self-destruct and the real choice (D and Space during
## the countdown), each shown on its Base and driving; the Gyrocopter is put down west of the water
## strip and drives across it to the field wall. Every key is a real event (A, D, W, the arrows,
## Space, Period, Tab). No checks in a normal run: it ends with RESULT ok; a run that did not reach
## its steps prints one failing CHECK named premise, so an empty recording cannot pass as evidence.
##
## SPLIT lines come every 0.5 s and at every choice, spawn, destruction and Round signal (an event=
## field): both Units' type, place, hit points and alive flag, the Round state and frame=, the
## main-loop iterations so far (in a --write-movie run the number of the next PNG, one per
## iteration, 60 a second). The runner makes no choice for this scenario (OWN_CHOICE); the shipped
## data. Tooling only: nothing under src/ depends on this file.
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md, Test Evidence
## (retained frames of the selection UI and of all four Units in play).
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/show.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=units_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys and the ticks.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the signal record, the waits, the fire key.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## Interval between progress lines, seconds.
const REPORT_SECONDS: float = 0.5
## The pauses of the choreography, by phase name, seconds: the moments a screenshot is taken at.
const HOLDS: Dictionary[StringName, float] = {&"panels": 3.5, &"cursor": 0.6, &"spawned": 2.5, &"driving": 2.0,
	&"placed": 0.5, &"countdown": 0.7, &"cursor_moved": 0.4, &"crossing": 3.5, &"end": 3.0}
## Where the Motorbike stands for the exchange: 8 m west of the middle of the field, at z = 2,
## facing the Truck.
const EXCHANGE_1: Vector3 = Vector3(-8.0, 0.0, 2.0)
## Where the Truck stands for the exchange: 8 m east of the middle, 16 m from the Motorbike, facing
## it.
const EXCHANGE_2: Vector3 = Vector3(8.0, 0.0, 2.0)
## Seconds the Motorbike's trigger is held at the Truck.
const BURST_SECONDS: float = 1.0
## The longest the Truck's trigger is held at the Motorbike before the step gives up, seconds.
const KILL_LIMIT_SECONDS: float = 2.5
## The Gyrocopter's run: from here east across the water strip (x 26 to 34) to the wall.
const WATER_START: Vector3 = Vector3(18.0, 0.0, 0.0)
## The water strip's far face, x: the Gyrocopter has crossed once it is farther east.
const WATER_FAR_X: float = 34.0
## Ticks a spawn after a confirm may take (the delay, plus slack).
const SPAWN_SLACK_TICKS: int = 60

var _harness: Harness
var _kit: Kit
var _units: Units
var _report_ticks: int = 1
## Ticks each step took, by step name, in order; -1 when it gave up.
var _steps: Dictionary[StringName, int] = {}
## The farthest east the Gyrocopter got on its run.
var _crossed_x: float = -INF


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_kit.on_tick = _note_tick
	_report_ticks = _harness.ticks_in(REPORT_SECONDS)
	_connect_lines(_units.controller)
	_line("")
	await _hold(&"panels")
	for keys: Array[Key] in [Kit.KEYS_NEXT_1, Kit.KEYS_NEXT_1, Kit.KEYS_PREVIOUS_1,
			Kit.KEYS_PREVIOUS_1, Kit.KEYS_NEXT_2, Kit.KEYS_NEXT_2]:
		await _kit.press_settled(keys)
		await _hold(&"cursor")
	await _confirm_both()
	await _hold(&"spawned")
	await _drive(&"driving", [Harness.PLAYER_1, Harness.PLAYER_2])
	_harness.phase = &"placed"
	_harness.place(_units.units[0], _units.pose(EXCHANGE_1, Vector3.RIGHT), _units.cameras[0])
	_harness.place(_units.units[1], _units.pose(EXCHANGE_2, Vector3.LEFT), _units.cameras[1])
	await _hold(&"placed")
	_harness.phase = &"p1_fires"
	await _units.hold_fire(Harness.PLAYER_1, _harness.ticks_in(BURST_SECONDS))
	await _fire_until_destroyed(&"p2_fires", Harness.PLAYER_2, Harness.PLAYER_1)
	await _choose_during_countdown(&"p1_buggy")
	await _drive(&"driving", [Harness.PLAYER_1, Harness.PLAYER_2])
	await _cycle(&"p1_truck")
	await _drive(&"driving", [Harness.PLAYER_1])
	await _cycle(&"p1_gyrocopter")
	_harness.place(_units.units[0], _units.pose(WATER_START, Vector3.RIGHT), _units.cameras[0])
	await _hold(&"placed")
	await _drive(&"crossing", [Harness.PLAYER_1])
	await _hold(&"end")
	_harness.phase = &"end"
	_line("")
	_finish()


## Prints a progress line, with its event named, at every choice, spawn, destruction and Round
## signal.
func _connect_lines(controller: MatchController) -> void:
	controller.unit_chosen.connect(func(player: int, type_index: int) -> void: _line("p%d_chose_%s" % [player + 1, Units.TYPE_IDS[type_index]]))
	controller.unit_spawned.connect(func(player: int) -> void: _line("p%d_spawned_as_%s" % [player + 1, _units.units[player].type_id]))
	controller.unit_destroyed.connect(func(player: int) -> void: _line("p%d_destroyed" % (player + 1)))
	controller.round_started.connect(func() -> void: _line("round_started"))
	controller.round_over.connect(func(winner: int) -> void: _line("round_over_p%d_wins" % (winner + 1)))


## Both Players confirm the type at their cursors with the runner's real presses (released on the
## tick each choice is accepted); files the spawns that followed, or -1.
func _confirm_both() -> void:
	_harness.phase = &"both_choose"
	var before: int = _units.spawns.size()
	await _harness.confirm_choices()
	_steps[&"both_choose"] = _units.spawns.size() - before if _units.controller.is_alive(0) and _units.controller.is_alive(1) else -1


## Holds the throttle, with a light left steer, of the Players for the phase's seconds.
func _drive(phase: StringName, players: Array[int]) -> void:
	_harness.phase = phase
	for _tick: int in _harness.ticks_in(HOLDS[phase]):
		for player: int in players:
			_harness.drive(player, 1, 1 if phase == &"driving" else 0)
		await _kit.tick()
		_crossed_x = maxf(_crossed_x, _units.units[0].global_position.x) if phase == &"crossing" else _crossed_x
	_harness.release_all()


## Holds a Player's fire key until the other Player's Unit is destroyed, at most KILL_LIMIT_SECONDS;
## files the ticks, or -1.
func _fire_until_destroyed(step: StringName, shooter: int, target: int) -> void:
	_harness.phase = step
	_steps[step] = -1
	_harness.set_key(_harness.fire_key(shooter), true)
	for count: int in range(1, _harness.ticks_in(KILL_LIMIT_SECONDS) + 1):
		await _kit.tick()
		if not _units.units[target].is_alive:
			_steps[step] = count
			break
	_harness.set_key(_harness.fire_key(shooter), false)


## Player 1, out of play with the countdown shown, moves its cursor to the next type and confirms
## during the countdown, then waits for the Unit; files the ticks from the confirm, or -1.
func _choose_during_countdown(step: StringName) -> void:
	_harness.phase = step
	await _hold(&"countdown")
	await _kit.press_settled(Kit.KEYS_NEXT_1)
	await _hold(&"cursor_moved")
	await _kit.press_settled(Kit.KEYS_FIRE_1)
	var delay_ticks: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	_steps[step] = await _units.wait_alive(Harness.PLAYER_1, delay_ticks + SPAWN_SLACK_TICKS)
	await _hold(&"spawned")


## Player 1 Self-destructs and chooses the next type during the countdown.
func _cycle(step: StringName) -> void:
	_harness.phase = step
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	await _choose_during_countdown(step)


## Holds every key up for the phase's seconds (HOLDS), under its name.
func _hold(phase: StringName) -> void:
	_harness.phase = phase
	await _kit.advance(_harness.ticks_in(HOLDS[phase]))


## After every tick the kit waits: prints a progress line when one is due.
func _note_tick() -> void:
	if _harness.ticks % _report_ticks == 0:
		_line("")


## Prints one SPLIT line: time, main-loop iterations, phase, both Units' type, place, hit points and
## alive flag, the Round state and the event when there is one.
func _line(event: String) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units.units[player]
		fields.append("p%d_type=%s p%d_x=%.2f p%d_z=%.2f p%d_hp=%.0f p%d_alive=%s" % [player + 1, unit.type_id, player + 1, unit.global_position.x,
			player + 1, unit.global_position.z, player + 1, unit.hit_points, player + 1, unit.is_alive])
	print("SPLIT %s t=%.3f frame=%d phase=%s %s round=%s%s" % [_harness.scenario, _harness.time(), Engine.get_process_frames(), _harness.phase,
		" ".join(fields), "OVER" if _units.controller.is_round_over() else "RUNNING", "" if event.is_empty() else " event=" + event])


## Prints the failing premise check when the run did not reach its steps (a step that gave up,
## Player 1 not seen as all four types, Player 2 not a Truck, the Motorbike not destroyed by the
## Truck's shots, no hit on the Truck, the Gyrocopter not across the water), then the RESULT line.
func _finish() -> void:
	var steps: PackedStringArray = []
	var missed: PackedStringArray = []
	for step: StringName in _steps:
		steps.append("%s:%d" % [step, _steps[step]])
		if _steps[step] < 0:
			missed.append(String(step))
	var p1_types: Array[StringName] = []
	var p2_truck: bool = false
	for index: int in _units.spawns.size():
		if _units.spawns[index].x == Harness.PLAYER_1 and not p1_types.has(_units.spawn_types[index]):
			p1_types.append(_units.spawn_types[index])
		p2_truck = p2_truck or (_units.spawns[index].x == Harness.PLAYER_2 and _units.spawn_types[index] == Units.TYPE_IDS[2])
	var truck_hit: bool = _units.units[1].hit_points < _units.units[1].stats.max_hit_points
	var crossed: bool = _crossed_x > WATER_FAR_X
	if not (missed.is_empty() and p1_types.size() == Units.TYPE_IDS.size() and p2_truck and truck_hit and crossed and _units.destroyed.size() == 3):
		_harness.check("premise", false, "the run did not reach its steps: missed=[%s] p1_types=%s (expected all %d) p2_truck=%s truck_hit=%s destroyed=%d (3) crossed_x=%.2f (over %.0f)" % [
			",".join(missed), p1_types, Units.TYPE_IDS.size(), p2_truck, truck_hit, _units.destroyed.size(), _crossed_x, WATER_FAR_X])
	_harness.finish("steps=%s p1_types=%s p2_truck=%s truck_hp=%.0f/%.0f shots=%d destroyed=%d crossed_x=%.2f separation_min=%.2f wall_clearance_min=%.2f" % [
		",".join(steps), p1_types, p2_truck, _units.units[1].hit_points, _units.units[1].stats.max_hit_points, _units.shots.size(), _units.destroyed.size(),
		_crossed_x, _harness.separation_min, _harness.wall_clearance_min])
