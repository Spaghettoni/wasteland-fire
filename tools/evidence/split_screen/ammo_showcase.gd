extends RefCounted
## Scenario ammo_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 022 on Map 01
## with the shipped data and view from above, every key a real key event. Eight moments, each read where its premise holds: rows (a
## new Motorbike's "Ammo 100 / 100" in one view, a new Truck's "Ammo 25 / 25" beside "Mines 5 / 5" in the other), firing (the
## Truck's key held part-way through its load, "Ammo 14 / 25", a Shot in the air), firing_chase (the same hold in the chase view),
## last_shot (a Buggy's "Ammo 0 / 50" with "Out of ammo" on the notice line), worn (a Buggy with a low tank and 40 of 50 Shots), choosing
## (its Self-destruct: the choice panel shown, the line hidden), new_unit (the Buggy chosen next: a full Fuel bar and "Ammo 50 / 50") and
## round_over (a Motorbike that spent seven Shots delivers the Flag: the Round-over screen over "Ammo 93 / 100"). A SPLIT line per
## moment with frame=, the number of the PNG that shows it in a --write-movie recording, and what the moment's premise reads. No CHECK
## in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty or
## false recording cannot pass as evidence. AMMO_MOMENTS (an environment variable of a run by hand) names the moments to play, "rows,firing".
## Implements: production/epics/wasteland-fire/story-022-ammo-and-full-start.md, Test Evidence (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/ammo.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo_showcase

const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
const UiKit: GDScript = preload("res://tools/evidence/split_screen/token_ui_kit.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
## Tokens enough that the destructions of the moments never end the Round.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 900.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## Ticks a moment holds before it is read, so the frame shows a settled view.
const HOLD_TICKS: int = 20
## Where each Player stands for the moments: on the salt flat on its own side of the Map, clear of both Bases, the cover and the
## Fuel Cans (the kits' lane spots, 170 m apart), so that nothing stands between a camera and its subject; Player 1 faces east and
## Player 2 west, both across the Map.
## Shots the Truck has left when the hold is read, and then once more in the chase view.
const TRUCK_LEFT: int = 14
const TRUCK_LEFT_CHASE: int = 12
## Shots the worn Buggy spends, the share of a tank it starts with, and the Shots the Motorbike spends before the Round ends.
const WORN_SPENT: int = 10
const WORN_TANK: float = 0.4
const CARRIER_SPENT: int = 7
## The physical key that steps Player 2's camera through its views (only tools name key codes).
const CAMERA_KEY_2: Key = KEY_SLASH

var _k: Kit22
var _q: Quick
var _ui: UiKit
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _wanted: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit22.new(harness)
	_q = _k.q()
	_ui = UiKit.new(_q.tokens)
	_wanted = OS.get_environment("AMMO_MOMENTS").split(",", false)
	await _k.swap().play(0, Quick.MOTORBIKE)
	await _k.swap().play(1, Quick.TRUCK)
	await _q.kit.advance(HOLD_TICKS)
	await _rows()
	await _firing()
	await _last_shot()
	await _worn_choosing_new()
	await _round_over()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d shots=%d %s" % [_moments.size(), _k.shots.size(), _q.engine_counts()])


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Whether a named group of moments plays in this run.
func _plays(group: String) -> bool:
	return _wanted.is_empty() or _wanted.has(group)


## A Player's spot and facing for the moments (the class doc says why).
func _spot(player: int) -> Vector3:
	return Quick.LANE_SPOT if player == 0 else Quick.mirrored(Quick.LANE_SPOT)


func _face(player: int) -> Vector3:
	return Vector3.RIGHT if player == 0 else Vector3.LEFT


## rows: Player 1's new Motorbike and Player 2's new Truck on the flat, both with their whole loads.
func _rows() -> void:
	if not _plays("rows"):
		return
	await _k.k.walls().park(0)
	await _k.mines().put(0, Quick.MOTORBIKE, _spot(0), _face(0))
	await _k.mines().put(1, Quick.TRUCK, _spot(1), _face(1))
	await _q.kit.advance(HOLD_TICKS)
	_need(_k.line(0) == "Ammo 100 / 100" and _k.line(1) == "Ammo 25 / 25" and _k.mines().line(1) == "Mines 5 / 5" and _k.mines().line(0) == "hidden", "rows: the lines read '%s', '%s' and '%s' (the Motorbike's Mines line '%s')" % [_k.line(0), _k.line(1), _k.mines().line(1), _k.mines().line(0)])
	_line("rows", "line_p1='%s' line_p2='%s' mines_p2='%s'" % [_k.line(0), _k.line(1), _k.mines().line(1)])


## firing: Player 2's Truck holds its key; read part-way through the load in the view from above and once more in the chase view.
func _firing() -> void:
	if not _plays("firing"):
		return
	await _k.mines().put(0, Quick.MOTORBIKE, _spot(0), _face(0))
	await _k.mines().put(1, Quick.TRUCK, _spot(1), _face(1))
	_q.harness.set_key(_q.harness.fire_key(1), true)
	while _k.weapon(1).shots_left > TRUCK_LEFT:
		await _q.kit.tick()
	await _q.kit.advance(3)
	_need(_k.line(1) == "Ammo %d / 25" % TRUCK_LEFT and _k.line(0) == "Ammo 100 / 100" and not _q.harness.get_tree().get_nodes_in_group(&"shots").is_empty(), "firing: the lines read '%s' and '%s', Shots in the air %d" % [_k.line(1), _k.line(0), _q.harness.get_tree().get_nodes_in_group(&"shots").size()])
	_line("firing", "line_p2='%s' line_p1='%s' in_the_air=%d" % [_k.line(1), _k.line(0), _q.harness.get_tree().get_nodes_in_group(&"shots").size()])
	await _q.kit.press_settled([CAMERA_KEY_2] as Array[Key])
	while _k.weapon(1).shots_left > TRUCK_LEFT_CHASE:
		await _q.kit.tick()
	await _q.kit.advance(3)
	_need(_k.line(1) == "Ammo %d / 25" % TRUCK_LEFT_CHASE, "firing_chase: the line reads '%s'" % _k.line(1))
	_line("firing_chase", "line_p2='%s'" % _k.line(1))
	_q.harness.set_key(_q.harness.fire_key(1), false)
	await _q.kit.press_settled([CAMERA_KEY_2] as Array[Key])
	await _q.kit.advance(HOLD_TICKS)


## last_shot: Player 1's new Buggy holds its key through its whole load; read three ticks after the last Shot.
func _last_shot() -> void:
	if not _plays("last_shot"):
		return
	await _k.mines().put(1, Quick.MOTORBIKE, _spot(1), _face(1))
	await _k.mines().put(0, Quick.BUGGY, _spot(0), _face(0))
	_q.harness.set_key(_q.harness.fire_key(0), true)
	while _k.weapon(0).shots_left > 0:
		await _q.kit.tick()
	await _q.kit.advance(3)
	_q.harness.set_key(_q.harness.fire_key(0), false)
	_need(_k.line(0) == "Ammo 0 / 50" and _k.note(0) == "Out of ammo" and _k.note(1) == "hidden", "last_shot: the line reads '%s', the notices '%s' and '%s'" % [_k.line(0), _k.note(0), _k.note(1)])
	_line("last_shot", "line_p1='%s' notice_p1='%s' notice_p2='%s'" % [_k.line(0), _k.note(0), _k.note(1)])
	await _q.kit.advance(HOLD_TICKS)


## worn, choosing and new_unit: a Buggy with a low tank and ten Shots spent, its Self-destruct, and the Buggy chosen next.
func _worn_choosing_new() -> void:
	if not _plays("worn"):
		return
	await _k.mines().put_stats(0, _q.small_tank(Quick.BUGGY, WORN_TANK), _spot(0), _face(0))
	await _k.fire_n(0, WORN_SPENT)
	await _q.kit.advance(HOLD_TICKS)
	var worn_fuel: float = _k.unit(0).fuel
	_need(_k.line(0) == "Ammo 40 / 50" and worn_fuel < _k.unit(0).fuel_capacity * WORN_TANK, "worn: the line reads '%s' with %.1f Fuel" % [_k.line(0), worn_fuel])
	_line("worn", "line_p1='%s' fuel=%.1f of %.0f" % [_k.line(0), worn_fuel, _k.unit(0).fuel_capacity])
	await _q.tokens.destruct(0)
	await _q.kit.advance(HOLD_TICKS * 2)
	_need(_q.units.panels[0].visible and _k.line(0) == "hidden", "choosing: the panel is shown %s and the line reads '%s'" % [_q.units.panels[0].visible, _k.line(0)])
	_line("choosing", "panel=%s line_p1='%s'" % [_q.units.panels[0].visible, _k.line(0)])
	await _q.tokens.spawn(0, Quick.BUGGY)
	await _q.kit.advance(HOLD_TICKS)
	var started: Dictionary = _k.spawn_since(0, _k.spawned.size() - 1)
	_need(_k.line(0) == "Ammo 50 / 50" and is_equal_approx(float(started["fuel"]), _k.unit(0).fuel_capacity) and _k.unit(0).fuel >= worn_fuel * 2.0, "new_unit: the line reads '%s', the Unit started with %.1f Fuel and has %.1f" % [_k.line(0), started["fuel"], _k.unit(0).fuel])
	_line("new_unit", "line_p1='%s' started_with=%.1f fuel=%.1f of %.0f" % [_k.line(0), started["fuel"], _k.unit(0).fuel, _k.unit(0).fuel_capacity])


## round_over: Player 2's Motorbike spends seven Shots, takes Base A's Flag and delivers it: the screen shows over the kept count.
func _round_over() -> void:
	if not _plays("round_over"):
		return
	await _k.mines().put(1, Quick.MOTORBIKE, _spot(1), _face(1))
	await _k.fire_n(1, CARRIER_SPENT)
	await _k.k.walls().restore_all(true)
	await _k.k.walls().turrets_down()
	_k.k.flags().wall(0, Walls.GATE).destroy()
	await _q.kit.advance(Walls.SETTLE)
	var taken: bool = await _k.k.flags().take_flag(1, 0, Walls.GATE)
	await _k.k.flags().back_out(1, 0, Walls.GATE)
	var delivered: bool = await _k.k.flags().deliver(1)
	await _q.kit.advance(HOLD_TICKS)
	var screen: RoundOverScreen = _ui.over_screen(1)
	_need(taken and delivered and screen != null and screen.visible and _k.line(1) == "Ammo 93 / 100", "round_over: taken %s, delivered %s, screen %s, the line reads '%s'" % [taken, delivered, screen != null and screen.visible, _k.line(1)])
	_line("round_over", "line_p2='%s' screen=%s" % [_k.line(1), screen != null and screen.visible])
	await _k.k.flags().restart()
