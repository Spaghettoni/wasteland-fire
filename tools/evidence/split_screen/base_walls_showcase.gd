extends RefCounted
## Scenario base_walls_showcase of the split screen evidence harness (split_screen_harness.gd): the retained
## frames of Story 018 on Map 01 with the shipped data, every key a real key event. Each Player stands at its own
## Base, so its view shows that Base and no Turret fires at it. Dressed states of the Base walls (whole, the back
## wall's panels at the first and at the second damaged look beside whole ones, breached with rubble in the back
## wall, a side wall and each Gate wall) are read from the viewpoints that show them, in the view from above and in
## the chase view (the Q and Slash keys step both). In each view then the moments that need action: a Truck through
## a Gate-wall breach, a Gyrocopter over a side wall, a Turret's Shot through a breach at a Truck in the yard and a
## Mine in a side wall's breach; and last both Bases whole again after a Round with panels fallen and hurt and the
## restart key. A SPLIT line per moment with frame=, the number of the PNG that shows it in a --write-movie
## recording. No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one
## failing CHECK named premise, so an empty or false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-018-base-wall-panels.md, Test Evidence (retained frames). Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/walls.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=base_walls_showcase

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd): the views' settings files and the ticks a moment holds.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")

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
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 900.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The viewpoints, Base-local, each Player at its own Base: where the Unit stands and the way it faces.
const VIEWS: Dictionary = {
	"gate": [Vector3(0.0, 0.0, -24.0), Vector3.BACK],
	"yard": [Vector3(-9.0, 0.0, -6.0), Vector3.BACK],
	"back": [Vector3(-8.7, 0.0, 19.5), Vector3.FORWARD],
	"side": [Vector3(-21.5, 0.0, -6.5), Vector3.RIGHT],
	"gate_in": [Vector3(-9.7, 0.0, -8.0), Vector3.FORWARD]}
## Hit points taken off a panel for each damaged look (30 and 12 of 40 left), the Mine's place in a side breach
## (metres from the axis), the Turret's Shot is read this far inside the yard face, and the Gyrocopter's model must
## have risen over the 2 m top by this much, metres.
const HURT: Array[float] = [10.0, 28.0]
const MINE_OUT: float = 15.75
const SHOT_PAST: float = 1.5
const RISEN: float = 0.2

var _k: Kit18
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit18.new(harness)
	_q = _k.q()
	await _k.m.w.s.both_play()
	for pass_index: int in 2:
		var name: String = "above" if pass_index == 0 else "chase"
		await _states(name)
		await _truck_through(name)
		await _gyro_over(name)
		await _shot_through(name)
		await _mine_in_breach(name)
		if pass_index == 0:
			await _switch_views()
	await _after_r()
	if not _problems.is_empty():
		_q.kit.verdict("premise", _problems, " | ".join(_moments))
	_k.close()
	harness.finish("moments=%d" % _moments.size())


## Prints a moment's line with its frame and what it reads, and files the moment.
func _line(moment: String, reads: String) -> void:
	_moments.append(moment)
	print("SPLIT %s t=%.3f frame=%d moment=%s %s" % [_q.harness.scenario, _q.harness.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, moment, reads])


func _need(holds: bool, problem: String) -> void:
	_q.kit.need(_problems, holds, problem)


## Which view each Player's camera is on, by the settings file it carries.
func _views() -> PackedStringArray:
	var found: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		found.append(_q.units.cameras[player].settings.resource_path.get_file())
	return found


## Steps both views (Q for Player 1, Slash for Player 2) once and waits for the cameras to settle.
func _switch_views() -> void:
	var keys: Array[Key] = [KEY_Q, KEY_SLASH]
	await _q.kit.press_settled(keys)
	await _q.kit.advance(Looks.VIEW_TICKS)


## Each Player's Unit at a viewpoint of its own Base.
func _place(view: String) -> void:
	for player: int in Kit.PLAYERS:
		_k.m.w.s.flags.teleport(player, _k.m.w.point(player, VIEWS[view][0]), _k.m.w.way(player, VIEWS[view][1]))


## Each Player's Unit at a viewpoint of its own Base, then the moment held and read.
func _hold(moment: String, view: String, reads: String) -> void:
	_place(view)
	await _q.kit.advance(Looks.HOLD_TICKS)
	var alive: bool = _q.units.units[0].is_alive and _q.units.units[1].is_alive
	var want: String = Looks.ABOVE_FILE if moment.ends_with("above") else Looks.CHASE_FILE
	_need(alive and _views() == PackedStringArray([want, want]), "%s: Units alive %s, the cameras are on %s" % [moment, alive, _views()])
	_line(moment, "%s views=%s" % [reads, ", ".join(_views())])


## Every panel and Turret back (the Units first put in the yard, out of every wall), then the back wall's panels
## dressed by index ({index: 0 whole, 1 or 2 a damaged look, -1 fallen}, mirrored along the wall) and, when asked,
## a side wall's lane panel and the middle panel of each Gate wall fallen, at both Bases.
func _dress(back: Dictionary, side_down: bool, gate_down: bool) -> void:
	_place("yard")
	await _k.restore_all(true)
	for base_index: int in Kit.PLAYERS:
		for index: int in back:
			for place: int in [index, Kit18.COUNTS[Kit18.BACK] - 1 - index]:
				var panel: Structure = _k.panel(base_index, Kit18.BACK, place)
				if back[index] < 0:
					panel.destroy()
				elif back[index] > 0:
					panel.apply_damage(HURT[back[index] - 1])
		if side_down:
			_k.panel(base_index, Kit18.LEFT, Kit18.LANE[Kit18.LEFT]).destroy()
		if gate_down:
			for run: int in [Kit18.GATE_LEFT, Kit18.GATE_RIGHT]:
				_k.panel(base_index, run, _middle(run)).destroy()
	await _q.kit.advance(Looks.HOLD_TICKS)


## The dressed states and their viewpoints in the view the cameras are on.
func _states(name: String) -> void:
	await _dress({}, false, false)
	await _hold("whole_gate_" + name, "gate", "panels=60 looks=whole")
	await _hold("whole_yard_" + name, "yard", "panels=60 looks=whole")
	await _dress({1: 1}, false, false)
	await _hold("first_look_" + name, "back", "back-wall panels 2 and 7 at the first look beside whole ones: looks %d %d beside %d %d" % [_k.look_shown(_k.panel(0, Kit18.BACK, 1)), _k.look_shown(_k.panel(1, Kit18.BACK, 6)), _k.look_shown(_k.panel(0, Kit18.BACK, 0)), _k.look_shown(_k.panel(0, Kit18.BACK, 2))])
	_need(_k.look_shown(_k.panel(0, Kit18.BACK, 1)) == 1 and _k.look_shown(_k.panel(0, Kit18.BACK, 0)) == 0 and _k.look_shown(_k.panel(1, Kit18.BACK, 6)) == 1, "first_look_%s: the looks are not first beside whole" % name)
	await _dress({1: 2}, false, false)
	await _hold("second_look_" + name, "back", "back-wall panels 2 and 7 at the second look")
	_need(_k.look_shown(_k.panel(0, Kit18.BACK, 1)) == 2 and _k.look_shown(_k.panel(1, Kit18.BACK, 6)) == 2, "second_look_%s: the looks are not second" % name)
	await _dress({1: -1, 2: 1}, true, true)
	_need(not _k.panel(0, Kit18.BACK, 1).is_standing and not _k.panel(1, Kit18.LEFT, Kit18.LANE[Kit18.LEFT]).is_standing and not _k.panel(0, Kit18.GATE_LEFT, _middle(Kit18.GATE_LEFT)).is_standing and _k.look_shown(_k.panel(0, Kit18.BACK, 2)) == 1, "breaches_%s: the breaches or the looks beside them are not as dressed" % name)
	await _hold("back_breach_" + name, "back", "back-wall panels 2 and 7 fallen (rubble) with the first look beside them")
	await _hold("side_breach_" + name, "side", "the left side wall's lane panel fallen at both Bases")
	await _hold("gate_breach_" + name, "gate_in", "the middle panel of each Gate wall fallen at both Bases, a Turret to be seen through each")


## How far from its Base's axis, along a run's outward direction, a Player's Unit stands, metres.
func _along(player: int, run: int) -> float:
	return _k.m.w.bases[player].to_local(_q.units.units[player].global_position).dot(Kit18.OUTWARD[run])


## A Unit of a type for each Player is put outside the lane panel of a run of its own Base, facing in, and driven at
## full throttle until 6 m inside the yard face; the moment is the first tick `ready.call(player)` holds for both
## Players, read with `reads.call()`. A coroutine: await it.
func _cross(moment: String, type_index: int, run: int, ready: Callable, reads: Callable) -> void:
	var half: float = _q.units.stats(type_index).collision_size.z / 2.0
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.spot(player, run, Kit18.LANE[run], _k.start_out(run, half, true)))
		facings.append(-_k.outward(player, run))
	await _q.map.stage([type_index, type_index], spots, facings, true)
	var read: bool = false
	for _tick: int in 420:
		var here: int = 0
		for player: int in Kit.PLAYERS:
			_q.harness.drive(player, 1, 0)
			here += 1 if ready.call(player) else 0
		await _q.kit.tick()
		if here == 2 and not read:
			read = true
			_line(moment, reads.call())
		if read and _along(0, run) < Kit18.INNER_FACES[run] - 6.0:
			break
	_q.harness.release_all()
	_need(read, "%s: the Units were never both there" % moment)


## A Truck of each Player drives through the lane breach of its Base's right Gate wall; the moment is the tick both
## stand with their centres in the wall's thickness.
func _truck_through(name: String) -> void:
	await _dress({}, false, false)
	var run: int = Kit18.GATE_RIGHT
	for base_index: int in Kit.PLAYERS:
		_k.panel(base_index, run, Kit18.LANE[run]).destroy()
	var middle: float = (Kit18.INNER_FACES[run] + Kit18.OUTER_FACES[run]) / 2.0
	await _cross("truck_through_gate_breach_" + name, Quick.TRUCK, run, func(player: int) -> bool: return absf(_along(player, run) - middle) <= 0.3,
			func() -> String: return "both Trucks at the middle of the wall's thickness (%.2f m from the axis) at %.1f m/s" % [middle, _q.units.units[0].get_real_velocity().length()])


## A Gyrocopter of each Player flies over the left side wall of its Base; the moment is the tick both have their
## centres over the wall with their models risen over its 2 m top.
func _gyro_over(name: String) -> void:
	await _dress({}, false, false)
	var run: int = Kit18.LEFT
	await _cross("gyro_over_side_wall_" + name, Quick.GYROCOPTER, run, func(player: int) -> bool: return _along(player, run) >= Kit18.INNER_FACES[run] and _along(player, run) <= Kit18.OUTER_FACES[run] and Quick.model_box(_q.units.units[player]).position.y >= Kit18.HEIGHT + RISEN,
			func() -> String: return "both Gyrocopters over the wall, models %.2f m over its top" % (Quick.model_box(_q.units.units[0]).position.y - Kit18.HEIGHT))


@warning_ignore("integer_division")
func _middle(run: int) -> int:
	return Kit18.COUNTS[run] / 2


## The middle panel of each Base's right Gate wall has fallen and its left Turret is down: the other Player's Truck
## stands in the yard behind the right Turret facing it; the moment is the first tick a Turret's Shot is past the
## wall's inner face, through the breach.
func _shot_through(name: String) -> void:
	await _dress({}, false, false)
	var run: int = Kit18.GATE_RIGHT
	var spots: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	var facings: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
	for base_index: int in Kit.PLAYERS:
		_k.panel(base_index, run, _middle(run)).destroy()
		_k.turret(base_index, 0).restore()
		_k.turret(base_index, 1).restore()
		_k.turret(base_index, 0).destroy()
		var turret_at: Vector3 = _k.m.w.bases[base_index].to_local(_k.turret(base_index, 1).global_position)
		spots[1 - base_index] = _k.m.w.point(base_index, Vector3(turret_at.x, 0.0, -5.0))
		facings[1 - base_index] = _k.m.w.way(base_index, Vector3.FORWARD)
	await _q.map.stage([Quick.TRUCK, Quick.TRUCK], spots, facings, true)
	var mark: int = _k.fired.size()
	var read: bool = false
	for _tick: int in 420:
		await _q.kit.tick()
		for index: int in range(mark, _k.fired.size()):
			var shot: Variant = _k.fired[index]["shot"]
			if not read and is_instance_valid(shot) and (shot as Shot).is_inside_tree():
				var base: Base = _k.m.w.bases[0] if _k.fired[index]["turret"] in _k.turrets[0] else _k.m.w.bases[1]
				var local: Vector3 = base.to_local((shot as Shot).global_position)
				if local.z >= Kit18.INNER_FACES[Kit18.GATE_RIGHT] * -1.0 + SHOT_PAST:
					read = true
					_line("turret_shot_through_breach_" + name, "a Turret's Shot %.1f m inside the yard face, through the fallen panel, toward the Truck" % (local.z + Kit18.INNER_FACES[run]))
		if read:
			break
	await _q.kit.advance(Looks.HOLD_TICKS)
	_need(read, "turret_shot_through_breach_%s: no Shot ever flew through a breach" % name)


## The left side wall's lane panel has fallen at both Bases and a live Mine lies in the outer part of each breach;
## each Player stands outside its wall facing it.
func _mine_in_breach(name: String) -> void:
	_place("side")
	await _k.restore_all(true)
	for base_index: int in Kit.PLAYERS:
		_k.panel(base_index, Kit18.LEFT, Kit18.LANE[Kit18.LEFT]).destroy()
	for base_index: int in Kit.PLAYERS:
		await _k.m.place_mine(_k.spot(base_index, Kit18.LEFT, Kit18.LANE[Kit18.LEFT], MINE_OUT), base_index, base_index == 1)
	await _hold("mine_in_side_breach_" + name, "side", "a live Mine in the outer part of the left side wall's breach at each Base: %d Mines" % _k.m.standing().size())
	_need(_k.m.standing().size() == 2, "mine_in_side_breach_%s: %d Mines stand, not 2" % [name, _k.m.standing().size()])
	await _k.m.clear_mines()


## Panels fallen and hurt at both Bases, Player 1 wins the Round through Base A's Gate, R, both Players choose again
## and stand outside their Gates: every panel is whole.
func _after_r() -> void:
	await _dress({1: -1, 2: 1, 0: 2}, true, true)
	_k.turret(1, 0).destroy()
	_k.turret(1, 1).destroy()
	_k.m.w.wall(1, Walls.GATE).destroy()
	_need(await _k.m.w.take_flag(0, 1, Walls.GATE) and await _k.m.w.deliver(0) and _q.controller.is_round_over(), "after_r: the Round was not won by a delivery")
	await _q.kit.advance(Looks.HOLD_TICKS)
	_line("round_over_panels_kept", "Round over, %d panels fallen" % _k.every().filter(func(panel: Structure) -> bool: return not panel.is_standing).size())
	_need(await _q.tokens.restart(), "after_r: the restart key brought no new Round")
	await _k.m.w.s.both_play()
	await _hold("after_r_chase", "gate", "panels whole: %d of 60" % _k.every().filter(func(panel: Structure) -> bool: return panel.is_standing and _k.look_shown(panel) == 0).size())
	_need(_k.every().all(func(panel: Structure) -> bool: return panel.is_standing and _k.look_shown(panel) == 0), "after_r: a panel is not whole")
