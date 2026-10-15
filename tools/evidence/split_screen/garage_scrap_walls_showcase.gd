extends RefCounted
## Scenario garage_scrap_walls_showcase of the split screen evidence harness (split_screen_harness.gd): the retained
## frames of Story 019 on Map 01 with the shipped data, every key a real key event. Each Player stands at its own
## Base or, for the field, at its own side of the Map, so its view shows that and no Turret fires at it. Dressed states
## of the Garage walls (whole from inside and from the yard, a side panel at the first and at the second damaged look,
## a side panel beside a spawn spot fallen with a Truck on the spot and a Buggy's Shot through the breach) and of the
## walls in the field (whole, the first and second looks beside each other, a lane panel fallen with its rubble) are
## read from the viewpoints that show them, in the view from above and in the chase view (the Q and Slash keys step
## both); in each view then the moments that need action: a Gyrocopter on its Garage spot beside a wall (its drawn
## height), a Gyrocopter leaving the Garage over the back wall and a Truck through a field breach; and last both
## Garages and both field walls whole again after a Round with panels fallen and hurt and the restart key. A SPLIT line
## per moment with frame=, the number of the PNG that shows it in a --write-movie recording. No CHECK in a normal run:
## it ends with RESULT ok; a moment whose premise does not hold prints one failing CHECK named premise, so an empty or
## false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-019-garage-and-scrap-wall-panels.md, Test Evidence (retained frames).
## Tooling only. Run: godot --path . --windowed --resolution 1280x720 --write-movie shots/garage.png \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=garage_scrap_walls_showcase

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
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
const GARAGE_SCRAP_PANELS: bool = true
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 900.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The viewpoints: where the Unit stands and the way it faces. A Garage view is Base-local and each Player stands at its
## own Base; a field view is the west wall's for Player 1, mirrored across x = 0 for Player 2.
const GARAGE_VIEWS: Dictionary = {
	"garage_in": [Vector3(0.0, 0.0, 8.5), Vector3.BACK],
	"yard": [Vector3(10.5, 0.0, -3.0), Vector3.BACK]}
## The yard view faces the Garage wall on the side of the yard that is clear of the Base's decorative containers (drawn, no
## collider, in the camera's way): Base A's right wall from x 11.5, Base B's left wall from x -11.5, at the spawn spots' z.
const YARD_VIEW: String = "yard_in"
const YARD_X: float = 11.5
const YARD_Z: float = 5.0
## In a dress, the Garage wall of each Base that its yard view faces.
const YARD_WALL: int = 99
const FIELD_VIEWS: Dictionary = {
	"field_out": [Vector3(-23.0, 0.0, 13.5), Vector3.RIGHT],
	"field_in": [Vector3(-3.0, 0.0, 13.5), Vector3.LEFT]}
## Hit points taken off a panel for each damaged look (30 and 12 of 40 left); a Gyrocopter's model must have risen this
## far over a 2 m top; the Buggy's Shot is read inside the Garage wall's thickness.
const HURT: Array[float] = [10.0, 28.0]
const RISEN: float = 0.2
const GYRO_WAIT: int = 90
## The Buggy shoots at the Truck on the spot from the yard at this Base-local z, at an angle through the breach: the Base's
## dressing container (drawn, no collider) stands where the spot's own line leaves the Buggy hidden under it.
const SHOOTER_Z: float = 0.0

var _k: Kit19
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit19.new(harness)
	_q = _k.q()
	await _k.k.m.w.s.both_play()
	for pass_index: int in 2:
		var name: String = "above" if pass_index == 0 else "chase"
		await _garage_states(name)
		await _spot_breach(name)
		await _gyro_spots(name)
		await _gyro_leaving(name)
		await _field_states(name)
		await _truck_through_field(name)
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
	await _q.kit.press_settled([KEY_Q, KEY_SLASH] as Array[Key])
	await _q.kit.advance(Looks.VIEW_TICKS)


## The Garage wall of a Base the yard view faces: Base A's right wall, Base B's left one.
func _yard_wall(base_index: int) -> int:
	return Kit19.RIGHT if base_index == 0 else Kit19.LEFT


## Each Player's Unit at a viewpoint: a Garage view at its own Base, a field view at its own side of the Map.
func _place(view: String) -> void:
	for player: int in Kit.PLAYERS:
		if view == YARD_VIEW:
			var side: float = 1.0 if player == 0 else -1.0
			_k.k.m.w.s.flags.teleport(player, _k.k.m.w.point(player, Vector3(side * YARD_X, 0.0, YARD_Z)), _k.k.m.w.way(player, Vector3(-side, 0.0, 0.0)))
		elif GARAGE_VIEWS.has(view):
			_k.k.m.w.s.flags.teleport(player, _k.k.m.w.point(player, GARAGE_VIEWS[view][0]), _k.k.m.w.way(player, GARAGE_VIEWS[view][1]))
		else:
			var mirror: Vector3 = Vector3(1.0 if player == 0 else -1.0, 1.0, 1.0)
			_k.k.m.w.s.flags.teleport(player, FIELD_VIEWS[view][0] * mirror, FIELD_VIEWS[view][1] * mirror)


## Each Player's Unit at a viewpoint, then the moment held and read.
func _hold(moment: String, view: String, reads: String) -> void:
	_place(view)
	await _q.kit.advance(Looks.HOLD_TICKS)
	var alive: bool = _q.units.units[0].is_alive and _q.units.units[1].is_alive
	var want: String = Looks.ABOVE_FILE if moment.ends_with("above") else Looks.CHASE_FILE
	_need(alive and _views() == PackedStringArray([want, want]), "%s: Units alive %s, the cameras are on %s" % [moment, alive, _views()])
	_line(moment, "%s views=%s" % [reads, ", ".join(_views())])


## Every panel and Turret back (the Units first put at a viewpoint out of every wall), then the panels dressed:
## {run: {index: 0 whole, 1 or 2 a damaged look, -1 fallen}} for the Garage runs at both Bases and the field runs.
func _dress(dress: Dictionary) -> void:
	_place("yard")
	await _k.restore_all(true)
	for key: int in dress:
		for index: int in dress[key]:
			for base_index: int in ([0] if key != YARD_WALL and _k.is_field(key) else Kit.PLAYERS):
				var run: int = _yard_wall(base_index) if key == YARD_WALL else key
				var panel: Structure = _k.panel(base_index, run, index)
				if dress[key][index] < 0:
					panel.destroy()
				elif dress[key][index] > 0:
					panel.apply_damage(HURT[dress[key][index] - 1])
	await _q.kit.advance(Looks.HOLD_TICKS)


## The Garage walls: whole from inside and from the yard, then a side panel at each look beside whole ones.
func _garage_states(name: String) -> void:
	await _dress({})
	await _hold("garage_whole_inside_" + name, "garage_in", "Garage panels=20 looks=whole")
	await _hold("garage_whole_yard_" + name, YARD_VIEW, "Garage panels=20 looks=whole")
	await _dress({YARD_WALL: {1: 1}})
	await _hold("garage_first_look_" + name, YARD_VIEW, "the middle panel of the Garage wall on the yard side at the first look beside whole ones: looks %d %d beside %d %d" % [_k.k.look_shown(_k.panel(0, Kit19.RIGHT, 1)), _k.k.look_shown(_k.panel(1, Kit19.LEFT, 1)), _k.k.look_shown(_k.panel(0, Kit19.RIGHT, 0)), _k.k.look_shown(_k.panel(1, Kit19.LEFT, 2))])
	_need(_k.k.look_shown(_k.panel(0, Kit19.RIGHT, 1)) == 1 and _k.k.look_shown(_k.panel(1, Kit19.LEFT, 1)) == 1 and _k.k.look_shown(_k.panel(0, Kit19.RIGHT, 0)) == 0 and _k.k.look_shown(_k.panel(1, Kit19.LEFT, 2)) == 0, "garage_first_look_%s: the looks are not first beside whole" % name)
	await _dress({YARD_WALL: {1: 2}})
	await _hold("garage_second_look_" + name, YARD_VIEW, "the same panel at the second look")
	_need(_k.k.look_shown(_k.panel(0, Kit19.RIGHT, 1)) == 2 and _k.k.look_shown(_k.panel(1, Kit19.LEFT, 1)) == 2, "garage_second_look_%s: the looks are not second" % name)


## A Truck of Player 2 stands on the right spot of Base B (the Garage's side panel beside it fallen) and Player 1's
## Buggy stands in that Base's yard facing it at an angle; the Buggy fires, and the moment is the first tick its Shot is inside the
## wall's thickness, through the breach.
func _spot_breach(name: String) -> void:
	await _dress({Kit19.RIGHT: {0: -1}})
	var near: Structure = _k.panel(1, Kit19.RIGHT, 0)
	_need(not near.is_standing, "garage_breach_spot_%s: the panel beside the spot stands" % name)
	await _k.k.stage(1, Quick.TRUCK, _k.spot_point(1, Kit19.RIGHT), _k.k.m.w.way(1, Vector3.FORWARD))
	var at: Vector3 = _k.frame(1, Kit19.RIGHT) * Vector3(Kit19.OUTER_FACES[Kit19.RIGHT] + 4.5, 0.0, SHOOTER_Z)
	_q.units.retype(0, Quick.BUGGY, at, (_k.spot_point(1, Kit19.RIGHT) - at).normalized())
	await _q.kit.advance(Kit19.Kit18.SETTLE)
	await _q.kit.advance(_k.k.m.w.longest_cadence())
	var target: Unit = _q.units.units[1]
	var before: float = target.hit_points
	var mark: int = _q.units.shots.size()
	await _q.units.hold_fire(0, 1)
	var read: bool = false
	for _tick: int in 60:
		for index: int in range(mark, _q.units.shots.size()):
			var shot: Variant = _q.units.shots[index]
			if not read and is_instance_valid(shot) and (shot as Shot).is_inside_tree():
				var along: float = _k.along_out(1, Kit19.RIGHT, (shot as Shot).global_position)
				if along <= Kit19.OUTER_FACES[Kit19.RIGHT] - 0.2 and along >= Kit19.INNER_FACES[Kit19.RIGHT]:
					read = true
					_line("garage_breach_spot_" + name, "the Buggy's Shot %.2f m from the axis, inside the fallen panel's thickness, toward the Truck on the spot" % along)
		if read:
			break
		await _q.kit.tick()
	await _q.kit.advance(Looks.HOLD_TICKS)
	_need(read and target.hit_points < before, "garage_breach_spot_%s: the Shot was never in the breach (%s) or the Truck was not hit (%.0f of %.0f)" % [name, read, target.hit_points, before])


## Both Players destroy their Unit and choose a Gyrocopter with the real keys; it appears on its spot beside a Garage wall
## and the moment is GYRO_WAIT ticks after, with the model risen over the wall's top.
func _gyro_spots(name: String) -> void:
	await _dress({})
	for player: int in Kit.PLAYERS:
		await _k.k.m.revive(player)
		await _q.tokens.destruct(player)
	for player: int in Kit.PLAYERS:
		_need(await _q.tokens.spawn(player, Quick.GYROCOPTER), "gyro_on_spot_%s: Player %d's Gyrocopter did not appear" % [name, player + 1])
	await _q.kit.advance(GYRO_WAIT)
	var lows: Array[float] = [Quick.model_box(_q.units.units[0]).position.y, Quick.model_box(_q.units.units[1]).position.y]
	_need(lows[0] >= Kit19.HEIGHT + RISEN and lows[1] >= Kit19.HEIGHT + RISEN, "gyro_on_spot_%s: the models' lowest points are %.2f and %.2f" % [name, lows[0], lows[1]])
	_line("gyro_on_spot_" + name, "both Gyrocopters on their spawn spots beside a Garage wall, the models' lowest points %.2f and %.2f m up (the hover is 0.78)" % [lows[0], lows[1]])
	await _q.kit.advance(Looks.HOLD_TICKS)


## A Gyrocopter of each Player flies out of its Garage over the back wall; the moment is the tick both have their
## centres over the wall with their models risen over its 2 m top.
func _gyro_leaving(name: String) -> void:
	await _dress({})
	var half: float = _q.units.stats(Quick.GYROCOPTER).collision_size.z / 2.0
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.spot(player, Kit19.BACK, Kit19.LANE[Kit19.BACK], _k.start_out(Kit19.BACK, half, false)))
		facings.append(_k.outward(player, Kit19.BACK))
	await _q.map.stage([Quick.GYROCOPTER, Quick.GYROCOPTER], spots, facings, true)
	var read: bool = false
	for _tick: int in 420:
		var over: int = 0
		for player: int in Kit.PLAYERS:
			_q.harness.drive(player, 1, 0)
			var along: float = _k.along_out(player, Kit19.BACK, _q.units.units[player].global_position)
			over += 1 if along >= Kit19.INNER_FACES[Kit19.BACK] and along <= Kit19.OUTER_FACES[Kit19.BACK] and Quick.model_box(_q.units.units[player]).position.y >= Kit19.HEIGHT + RISEN else 0
		await _q.kit.tick()
		if over == 2 and not read:
			read = true
			_line("gyro_leaving_over_back_wall_" + name, "both Gyrocopters over the Garage's back wall, models %.2f m over its top" % (Quick.model_box(_q.units.units[0]).position.y - Kit19.HEIGHT))
		if read and _k.along_out(0, Kit19.BACK, _q.units.units[0].global_position) > Kit19.OUTER_FACES[Kit19.BACK] + 6.0:
			break
	_q.harness.release_all()
	_need(read, "gyro_leaving_over_back_wall_%s: the Gyrocopters were never both over the wall" % name)


## The walls in the field: whole, then the west one's and the east one's middle panels at the first and the second look
## beside whole ones, then the lane panel fallen with its rubble, each from the side a Player can see it from.
func _field_states(name: String) -> void:
	await _dress({})
	await _hold("field_whole_" + name, "field_out", "field panels=8 looks=whole")
	await _dress({Kit19.WEST: {1: 1, 2: 2}, Kit19.EAST: {1: 1, 2: 2}})
	await _hold("field_looks_" + name, "field_out", "panels 2 and 3 of each field wall at the first and second look beside whole ones: looks %d %d beside %d %d" % [_k.k.look_shown(_k.panel(0, Kit19.WEST, 1)), _k.k.look_shown(_k.panel(0, Kit19.WEST, 2)), _k.k.look_shown(_k.panel(0, Kit19.WEST, 0)), _k.k.look_shown(_k.panel(0, Kit19.WEST, 3))])
	_need(_k.k.look_shown(_k.panel(0, Kit19.WEST, 1)) == 1 and _k.k.look_shown(_k.panel(0, Kit19.WEST, 2)) == 2 and _k.k.look_shown(_k.panel(0, Kit19.EAST, 1)) == 1 and _k.k.look_shown(_k.panel(0, Kit19.EAST, 0)) == 0, "field_looks_%s: the looks are not as dressed" % name)
	await _dress({Kit19.WEST: {2: -1, 1: 1}, Kit19.EAST: {2: -1, 1: 1}})
	await _hold("field_breach_" + name, "field_out", "the lane panel of each field wall fallen (rubble) beside a first look and whole panels")
	_need(not _k.panel(0, Kit19.WEST, 2).is_standing and not _k.panel(0, Kit19.EAST, 2).is_standing, "field_breach_%s: the lane panels stand" % name)


## A Truck of each Player drives through the lane breach of the field wall on its side from outside; the moment is the
## tick both stand with their centres in the wall's thickness.
func _truck_through_field(name: String) -> void:
	await _dress({Kit19.WEST: {2: -1}, Kit19.EAST: {2: -1}})
	var half: float = _q.units.stats(Quick.TRUCK).collision_size.z / 2.0
	var runs: Array[int] = [Kit19.WEST, Kit19.EAST]
	var spots: Array[Vector3] = []
	var facings: Array[Vector3] = []
	for player: int in Kit.PLAYERS:
		spots.append(_k.spot(player, runs[player], Kit19.LANE[runs[player]], _k.start_out(runs[player], half, true)))
		facings.append(-_k.outward(player, runs[player]))
	await _q.map.stage([Quick.TRUCK, Quick.TRUCK], spots, facings, true)
	var middle: float = (Kit19.INNER_FACES[Kit19.WEST] + Kit19.OUTER_FACES[Kit19.WEST]) / 2.0
	var read: bool = false
	for _tick: int in 420:
		var here: int = 0
		for player: int in Kit.PLAYERS:
			_q.harness.drive(player, 1, 0)
			here += 1 if absf(_k.along_out(player, runs[player], _q.units.units[player].global_position) - middle) <= 0.3 else 0
		await _q.kit.tick()
		if here == 2 and not read:
			read = true
			_line("truck_through_field_breach_" + name, "both Trucks at the middle of the wall's thickness (%.2f m from the axis) at %.1f m/s" % [middle, _q.units.units[0].get_real_velocity().length()])
		if read and _k.along_out(0, Kit19.WEST, _q.units.units[0].global_position) < Kit19.INNER_FACES[Kit19.WEST] - 6.0:
			break
	_q.harness.release_all()
	_need(read, "truck_through_field_breach_%s: the Trucks were never both there" % name)


## Panels fallen and hurt everywhere, Player 1 wins the Round through Base A's Gate, R, both Players choose again and
## stand at a Garage, then at the field: every panel is whole.
func _after_r() -> void:
	await _dress({Kit19.BACK: {1: -1}, Kit19.LEFT: {1: -1, 0: 2}, Kit19.RIGHT: {1: -1, 2: 1}, Kit19.WEST: {2: -1, 1: 2}, Kit19.EAST: {2: -1, 1: 1}})
	for turret: Turret in _k.k.all_turrets():
		turret.destroy()
	_k.k.m.w.wall(1, Walls.GATE).destroy()
	_need(await _k.k.m.w.take_flag(0, 1, Walls.GATE) and await _k.k.m.w.deliver(0) and _q.controller.is_round_over(), "after_r: the Round was not won by a delivery")
	await _q.kit.advance(Looks.HOLD_TICKS)
	_line("round_over_panels_kept", "Round over, %d of 28 panels fallen" % _k.every().filter(func(panel: Structure) -> bool: return not panel.is_standing).size())
	_need(await _q.tokens.restart(), "after_r: the restart key brought no new Round")
	await _k.k.m.w.s.both_play()
	var whole: Callable = func(panel: Structure) -> bool: return panel.is_standing and _k.k.look_shown(panel) == 0
	await _hold("after_r_garage_chase", YARD_VIEW, "Garage panels whole: %d of 20" % _k.every().slice(0, 20).filter(whole).size())
	await _hold("after_r_field_chase", "field_out", "field panels whole: %d of 8" % _k.every().slice(20, 28).filter(whole).size())
	_need(_k.every().all(whole), "after_r: a panel is not whole")
