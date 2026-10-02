extends RefCounted
## Scenario fuel_showcase of the split screen evidence harness (split_screen_harness.gd): about
## 45 s for the retained screenshots of Story 006's Fuel, Fuel Cans and Fuel gauge. Both views
## open on the choice panels; Player 2 steps right twice to the Truck and both confirm (Player 1
## the Motorbike). The Truck is put down on a circle in the north-east quarter and drives it,
## throttle and left steer held, until its tank is empty; meanwhile the Motorbike, put down 28 m
## south-west of the middle Fuel Can facing it, drives straight through it with its gauge falling
## and the Can in view, takes it (the gauge refills, the Can is gone), and is put down inside the
## Truck's circle. The empty Truck coasts to rest, turns on the spot to face the Motorbike and
## fires a shot that hits; Player 1 Self-destructs, moves its cursor back to the Gyrocopter during
## the countdown and confirms, and the Gyrocopter flies from its Base (8 m north, then a left
## circle clear of every Can) until its tank is empty and it crashes: the countdown and the choice
## panel come up. Every key is a real event (Right, Space, Period, W, A, Up, Left, Tab). No checks
## in a normal run: it ends with RESULT ok; a run that did not reach its steps prints one failing
## CHECK named premise, so an empty recording cannot pass as evidence.
##
## SPLIT lines come every 0.5 s and at every choice, spawn, destruction and Fuel Can signal (an
## event= field): both Units' type, place, Fuel, hit points and alive flag, the Cans' states
## (cans=, FuelCan1 to FuelCan5, A available, T taken), the Round state and frame=, the main-loop
## iterations so far (in a --write-movie run the number of the next PNG). OWN_CHOICE; the shipped
## data, Fuel included. Tooling only: nothing under src/ depends on this file.
## Implements: production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md, Test Evidence
## (retained frames of AC-2 to AC-7); design/rules.md "Resources", "Destruction and respawn".
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/fuel.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=fuel_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): the keys, the ticks, the verdict.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 005 helpers (unit_kit.gd): the signal record, the screens, the fire key, the waits.
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")
## The Story 006 helpers (fuel_kit.gd): the Cans, the fuel_changed record, the drive onto a point.
const Fuel: GDScript = preload("res://tools/evidence/split_screen/fuel_kit.gd")

## This scenario makes the first choice itself: the runner presses no fire key before run().
const OWN_CHOICE: bool = true
## The Gyrocopter's index into the data (unit_kit.gd TYPE_IDS).
const GYROCOPTER: int = 3
## Interval between progress lines, seconds.
const REPORT_SECONDS: float = 0.5
## The pauses of the choreography, by phase name, seconds: the moments a screenshot is taken at.
const HOLDS: Dictionary[StringName, float] = {&"panels": 2.5, &"cursor": 0.5, &"spawned": 1.5,
	&"placed": 0.5, &"can_gone": 2.0, &"hit": 1.0, &"countdown": 0.7, &"cursor_moved": 0.5,
	&"gyro_spawned": 1.0, &"end": 3.0}
## Places, metres: approach (the Motorbike's start, 28 m south-west of the middle Can), through (7 m
## past that Can on the same line), circle (the Truck's circle's centre: the circle keeps clear of
## every Can, the walls, the water and the Bases) and wait (5 m west of it: the Motorbike waits
## there, its camera inside the circle, out of the Truck's way).
const SPOTS: Dictionary[StringName, Vector3] = {&"approach": Vector3(-19.8, 0.0, 19.8),
	&"through": Vector3(5.0, 0.0, -5.0), &"circle": Vector3(24.0, 0.0, -24.0),
	&"wait": Vector3(19.0, 0.0, -24.0)}
## Where on its circle (radius max_speed / turn_rate of the data) the Truck is put down, degrees
## from +X toward +Z around SPOTS circle: its run dry, about two laps and a quarter at full
## throttle, then ends west of the centre, so it comes to rest in open ground.
const TRUCK_START_DEGREES: float = 314.0
## Moves: cruise (m/s) and radius (m) of the Motorbike's drive at the through point, and
## gyro_turn_z (m): the Gyrocopter's left circle starts there, so it keeps every Can out.
const MOVE: Dictionary[StringName, float] = {&"cruise": 10.0, &"radius": 1.0, &"gyro_turn_z": 12.0}
## The most ticks a run dry, a coast, a turn on the spot or a flight may take before it gives up.
const LIMIT_TICKS: int = 1500
## Ticks a spawn after a confirm may take (the delay, plus slack).
const SPAWN_SLACK_TICKS: int = 60
## The least turn on the spot the empty Truck shows (x, radians) and the most it moves (y, m).
const TURN_PROOF: Vector2 = Vector2(0.3, 0.05)

var _harness: Harness
var _kit: Kit
var _units: Units
var _fuel: Fuel
var _fuel_cans: Array[FuelCan] = []
var _report_ticks: int = 1
## Ticks each step took, by step name, in order; -1 when it gave up.
var _steps: Dictionary[StringName, int] = {}
## The Fuel Player 1 gained by its first take of the middle Can (FuelCan1), -1.0 without one.
var _take_gain: float = -1.0
## Both Units' Fuel as the last tick left it, read before the next tick's nodes run.
var _fuel_seen: Array[float] = [0.0, 0.0]
## The tick the Truck's throttle went down for its run dry.
var _truck_start: int = 0
## The empty Truck's turn on the spot: radians turned (x) and metres moved (y).
var _turn: Vector2 = Vector2.ZERO
## The hit points the Truck's shot took from the Motorbike, -1.0 when none came.
var _damage: float = -1.0
## The Gyrocopter's hit points on the tick it went down, the zero-Fuel calls on that tick, and
## whether Player 1's countdown and choice panel were up just after it.
var _gyro_hp: float = -1.0
var _crash_zeros: int = 0
var _shown: bool = false


## Plays the choreography. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_kit = Kit.new(harness)
	_units = Units.new(harness, _kit)
	_fuel = Fuel.new(harness, _kit)
	_fuel_cans = _fuel.cans()
	_kit.on_tick = _note_tick
	_report_ticks = _harness.ticks_in(REPORT_SECONDS)
	_connect_lines()
	_line("")
	await _hold(&"panels")
	for _press: int in 2:
		await _kit.press_settled(Kit.KEYS_NEXT_2)
		await _hold(&"cursor")
	_harness.phase = &"both_choose"
	await _harness.confirm_choices()
	_steps[&"both_choose"] = _units.spawns.size() if _units.controller.is_alive(0) and _units.controller.is_alive(1) else -1
	await _hold(&"spawned")
	if not _fuel_cans.is_empty():
		await _through_the_can()
		await _truck_run()
		await _gyrocopter_flight()
	await _hold(&"end")
	_harness.phase = &"end"
	_line("")
	_finish()


## Prints a progress line, with its event named, at every choice, spawn, destruction and Fuel Can
## signal.
func _connect_lines() -> void:
	var controller: MatchController = _units.controller
	controller.unit_chosen.connect(func(player: int, type_index: int) -> void: _line("p%d_chose_%s" % [player + 1, Units.TYPE_IDS[type_index]]))
	controller.unit_spawned.connect(func(player: int) -> void: _line("p%d_spawned_as_%s" % [player + 1, _units.units[player].type_id]))
	controller.unit_destroyed.connect(func(player: int) -> void: _line("p%d_destroyed" % (player + 1)))
	for index: int in _fuel_cans.size():
		_fuel_cans[index].taken.connect(_on_taken.bind(index))
		_fuel_cans[index].restocked.connect(func() -> void: _line("%s_restocked" % _fuel_cans[index].name))


## Prints a take as it happens, in the Can's own tick; files Player 1's first gain from the middle
## Can (its Fuel now, the refill in, less its Fuel at the end of the last tick).
func _on_taken(unit: Unit, can_index: int) -> void:
	var player: int = _units.units.find(unit)
	if can_index == 0 and player == Harness.PLAYER_1 and _take_gain < 0.0:
		_take_gain = unit.fuel - _fuel_seen[player]
	_line("%s_taken_by_p%d" % [_fuel_cans[can_index].name, player + 1])


## The Truck is put down on its circle and the Motorbike 28 m short of the middle Can facing it;
## the Truck's throttle and left steer go down and stay down. The Motorbike drives through the Can
## at cruise with W, takes it, comes to rest and holds for the frames of the Can gone, then is put
## down at the wait spot facing west. Files the ticks of the drive, or -1 without the take.
func _through_the_can() -> void:
	_harness.phase = &"placed"
	var stats: UnitStats = _units.units[Harness.PLAYER_2].stats
	var angle: float = deg_to_rad(TRUCK_START_DEGREES)
	var start: Vector3 = SPOTS[&"circle"] + stats.max_speed / stats.turn_rate * Vector3(cos(angle), 0.0, sin(angle))
	_harness.place(_units.units[Harness.PLAYER_2], _units.pose(start, Vector3(sin(angle), 0.0, -cos(angle))), _units.cameras[1])
	_harness.place(_units.units[Harness.PLAYER_1], _units.pose(SPOTS[&"approach"], _fuel_cans[0].global_position - SPOTS[&"approach"]), _units.cameras[0])
	await _hold(&"placed")
	_harness.phase = &"p1_to_can"
	_truck_start = _harness.ticks
	_harness.drive(Harness.PLAYER_2, 1, 1)
	var drove: int = await _fuel.drive_to(Harness.PLAYER_1, SPOTS[&"through"], MOVE[&"cruise"], MOVE[&"radius"])
	await _fuel.coast(Harness.PLAYER_1, 0)
	_steps[&"p1_through_can"] = drove if _take_gain > 0.0 else -1
	await _hold(&"can_gone")
	_harness.place(_units.units[Harness.PLAYER_1], _units.pose(SPOTS[&"wait"], Vector3.LEFT), _units.cameras[0])


## The Truck keeps its keys down until its tank is empty, then lets the throttle go and, left steer
## still down, coasts to rest; it turns on the spot toward the Motorbike until it faces it and fires
## one shot (Period for one tick) that must hit. Files the ticks of the run dry (since its throttle
## went down) and of the turn, or -1, with the turn's angle and drift.
func _truck_run() -> void:
	_harness.phase = &"p2_runs_dry"
	var truck: Unit = _units.units[Harness.PLAYER_2]
	var target: Vector3 = _units.units[Harness.PLAYER_1].global_position
	_steps[&"p2_runs_dry"] = -1
	for _tick: int in LIMIT_TICKS:
		await _kit.tick()
		if truck.is_fuel_empty:
			_steps[&"p2_runs_dry"] = _harness.ticks - _truck_start
			break
	_line("p2_run_dry_ended")
	_harness.phase = &"p2_coasts"
	_harness.drive(Harness.PLAYER_2, 0, 1)
	for _tick: int in LIMIT_TICKS:
		if is_zero_approx(truck.current_speed):
			break
		await _kit.tick()
	_harness.phase = &"p2_turns"
	_harness.tracks[Harness.PLAYER_2].begin()
	_steps[&"p2_turns"] = -1
	for count: int in LIMIT_TICKS:
		var error: float = _fuel.heading_error(Harness.PLAYER_2, target)
		if absf(error) < Fuel.STEER_DEADBAND:
			_steps[&"p2_turns"] = count
			break
		_harness.drive(Harness.PLAYER_2, 0, int(signf(error)))
		await _kit.tick()
	_harness.drive(Harness.PLAYER_2, 0, 0)
	_turn = Vector2(_harness.tracks[Harness.PLAYER_2].yaw_total, _harness.tracks[Harness.PLAYER_2].moved())
	_harness.phase = &"p2_fires"
	await _units.hold_fire(Harness.PLAYER_2, 1)
	_damage = await _units.wait_hit(Harness.PLAYER_1)
	await _hold(&"hit")


## Player 1 Self-destructs (Tab), moves its cursor from the Motorbike back to the Gyrocopter (A
## wraps from the first type to the last) and confirms (Space) during the countdown; the Gyrocopter
## stands on its Base, then flies with W, north until it passes gyro_turn_z and from there with A
## too, until it is destroyed. Files the ticks of each step, or -1.
func _gyrocopter_flight() -> void:
	_harness.phase = &"p1_self_destructs"
	await _kit.press_settled(Kit.KEYS_DESTRUCT_1)
	_steps[&"p1_self_destructs"] = 0 if not _units.units[Harness.PLAYER_1].is_alive else -1
	await _hold(&"countdown")
	await _kit.press_settled(Kit.KEYS_PREVIOUS_1)
	await _hold(&"cursor_moved")
	await _kit.press_settled(Kit.KEYS_FIRE_1)
	var delay_ticks: int = _harness.ticks_in(_units.controller.rules.respawn_delay_seconds)
	_steps[&"p1_gyrocopter"] = await _units.wait_alive(Harness.PLAYER_1, delay_ticks + SPAWN_SLACK_TICKS)
	if _steps[&"p1_gyrocopter"] < 0:
		return
	await _hold(&"gyro_spawned")
	_harness.phase = &"p1_flies"
	var gyro: Unit = _units.units[Harness.PLAYER_1]
	var turning: bool = false
	_steps[&"p1_crash"] = -1
	for count: int in range(1, LIMIT_TICKS + 1):
		turning = turning or gyro.global_position.z <= MOVE[&"gyro_turn_z"]
		_gyro_hp = gyro.hit_points
		_harness.drive(Harness.PLAYER_1, 1, 1 if turning else 0)
		await _kit.tick()
		if not gyro.is_alive:
			_steps[&"p1_crash"] = count
			break
	_harness.release_all()
	_crash_zeros = _zeros_on(Harness.PLAYER_1, _fuel.last_tick(_units.destroyed, Harness.PLAYER_1))
	await _kit.advance(Kit.TICK_SLACK + 1)
	_shown = _units.countdowns[Harness.PLAYER_1].visible and _units.panels[Harness.PLAYER_1].visible


## Holds every key it does not drive as it is, for the phase's seconds (HOLDS), under its name.
func _hold(phase: StringName) -> void:
	_harness.phase = phase
	await _kit.advance(_harness.ticks_in(HOLDS[phase]))


## After every tick the kit waits: notes both Units' Fuel; prints a progress line when one is due.
func _note_tick() -> void:
	for player: int in Kit.PLAYERS:
		_fuel_seen[player] = _units.units[player].fuel
	if _harness.ticks % _report_ticks == 0:
		_line("")


## How many of a Player's fuel_changed said zero Fuel on a tick: two on the tick of a Fuel crash
## (the last burn, then destroy()), one on the tick of any other destruction.
func _zeros_on(player: int, tick: int) -> int:
	var zeros: int = 0
	for index: int in _fuel.changes.size():
		zeros += 1 if _fuel.changes[index] == Vector2i(player, tick) and _fuel.fuels[index] == 0.0 else 0
	return zeros


## Prints one SPLIT line: time, main-loop iterations, phase, both Units' type, place, Fuel, hit
## points and alive flag, the Cans' states, the Round state and the event when there is one.
func _line(event: String) -> void:
	var fields: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var unit: Unit = _units.units[player]
		var p: int = player + 1
		fields.append("p%d_type=%s p%d_x=%.2f p%d_z=%.2f p%d_fuel=%.2f p%d_hp=%.0f p%d_alive=%s" % [p, unit.type_id, p, unit.global_position.x,
			p, unit.global_position.z, p, unit.fuel, p, unit.hit_points, p, unit.is_alive])
	var cans: PackedStringArray = []
	for can: FuelCan in _fuel_cans:
		cans.append("A" if can.is_available else "T")
	print("SPLIT %s t=%.3f frame=%d phase=%s %s cans=%s round=%s%s" % [_harness.scenario, _harness.time(), Engine.get_process_frames(),
		_harness.phase, " ".join(fields), "".join(cans), "OVER" if _units.controller.is_round_over() else "RUNNING",
		"" if event.is_empty() else " event=" + event])


## Prints the failing premise check when the run did not reach its steps (a step that gave up; no
## spawn of the Motorbike and the Gyrocopter for Player 1 or of the Truck for Player 2; the middle
## Can not taken by Player 1 for Fuel; no turn on the spot; no hit, or destructions other than
## Player 1's two; no Fuel crash with the Gyrocopter unhurt, or no countdown and panel after it),
## then the RESULT line.
func _finish() -> void:
	var problems: PackedStringArray = []
	var steps: PackedStringArray = []
	for step: StringName in _steps:
		steps.append("%s:%d" % [step, _steps[step]])
		_kit.need(problems, _steps[step] >= 0, "step %s gave up" % step)
	var spawns: PackedStringArray = []
	for index: int in _units.spawns.size():
		spawns.append("p%d_%s" % [_units.spawns[index].x + 1, _units.spawn_types[index]])
	for cast: String in ["p1_motorbike", "p2_truck", "p1_gyrocopter"]:
		_kit.need(problems, spawns.has(cast), "no spawn %s" % cast)
	var lost: Vector2i = Vector2i(_units.destroyed.filter(func(record: Vector2i) -> bool: return record.x == 0).size(),
		_units.destroyed.filter(func(record: Vector2i) -> bool: return record.x == 1).size())
	_kit.need(problems, _take_gain > 0.0, "Player 1 took no Fuel from the middle Can")
	_kit.need(problems, absf(_turn.x) >= TURN_PROOF.x and _turn.y <= TURN_PROOF.y, "no turn on the spot")
	_kit.need(problems, _damage > 0.0 and lost == Vector2i(2, 0), "no hit, else destructions not 2/0")
	_kit.need(problems, _gyro_hp == _units.stats(GYROCOPTER).max_hit_points and _crash_zeros == 2 and _shown, "no Fuel crash")
	var detail: String = "steps=%s spawns=%s take_gain=%.2f truck_turn=%.1fdeg truck_moved=%.4f damage=%.1f destroyed=%d/%d gyro_hp=%.0f crash_zero_calls=%d countdown_and_panel=%s p1_fuel=%.2f p2_fuel=%.2f separation_min=%.2f wall_clearance_min=%.2f" % [
		",".join(steps), ",".join(spawns), _take_gain, rad_to_deg(_turn.x), _turn.y, _damage, lost.x, lost.y, _gyro_hp, _crash_zeros,
		_shown, _fuel.fuel(0), _fuel.fuel(1), _harness.separation_min, _harness.wall_clearance_min]
	if not problems.is_empty():
		_kit.verdict("premise", problems, "the run did not reach its steps: " + detail)
	_harness.finish(detail)
