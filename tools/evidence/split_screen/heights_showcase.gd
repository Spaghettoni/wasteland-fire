extends RefCounted
## Scenario heights_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frames of Story 020 on Map 01
## with the shipped data, every key a real key event. Each Player stands at its own Base or at its own side of the Map (the
## mirror across x = 0), so that no Turret fires at it except where a moment is about a Turret. Both Players' Gyrocopters
## appear in their Garages (a real choice, by Self-destruct and the choice keys) and are then shown, in the view from above and in the
## chase view (the Q and Slash keys step both), standing over a Wall Panel of a Base wall, a Flag Wall, a wreck, a container, a cliff and a
## water channel, over a Truck (its antenna drawn into the gear) and through each other, driven into a corner tower, a water tower leg, a
## depot tank and a Turret and stopped there, firing (its tracer at 0.5 m) and shot at by a Turret from its raised head, between the water
## tower's legs under its tank, blown up in the air and smoking when badly damaged. A SPLIT line per moment with frame=, the number of the PNG
## that shows it in a --write-movie recording (HEIGHTS_PASS=above or chase, and HEIGHTS_MOMENTS=stand,stop,fire,end (any of them), environment
## variables of a run by hand, play one pass only and the named groups of moments only). No CHECK in a normal run: it ends with RESULT ok; a moment whose premise does not hold prints one failing
## CHECK named premise, so an empty or false recording cannot pass as evidence. Implements:
## production/epics/wasteland-fire/story-020-two-heights.md, Test Evidence (retained frames). Tooling only. Run: godot --path . --windowed
## --resolution 1280x720 --write-movie shots/heights.png res://tools/evidence/split_screen_harness.tscn -- --scenario=heights_showcase

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
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
const HEIGHTS: bool = true
## Tokens enough that the moments never end the Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 12, &"buggy": 12, &"truck": 12, &"gyrocopter": 12}
## Simulated seconds this scenario may take.
const WATCHDOG_SECONDS: float = 1200.0
## Main-loop iterations from a moment's line back to the PNG that shows it (tokens_showcase_kit.gd).
const MOMENT_FRAME_LAG: int = 1
## The moments' places. Base-local ones (each Player at its own Base): the Base's back wall panel, the Flag Wall at the Gate side of the
## water tower, and between the tower's Gate-side legs. World ones are Player 1's, Player 2 standing at the mirror across x = 0.
const BASE_WALL: Vector3 = Vector3(1.73, 0.0, 14.35)
const FLAG_WALL: Vector3 = Vector3(0.0, 0.0, -8.8)
const BETWEEN_LEGS: Vector3 = Vector3(0.0, 0.0, -7.0)
const WRECK: Vector3 = Vector3(-80.0, 0.0, 5.0)
const CONTAINER: Vector3 = Vector3(-58.0, 0.0, 0.0)
const CLIFF: Vector3 = Vector3(-15.0, 0.0, -22.0)
const CHANNEL: Vector3 = Vector3(-40.0, 0.0, 34.0)
## The middle of the Map, clear of both Bases' Turrets: where two Units meet, and the Truck and the pair of Gyrocopters stand.
const MIDDLE: Vector3 = Vector3(0.0, 0.0, -16.0)
const FIRE_APART: float = 10.0
## The Tall pieces a pair is driven into: [name, collider path, direction (world, Player 1's), the Gyrocopter's start, Player 2's start].
const STOPS: Array = [
	["stop_tower", "Base1/Walls/TowerGateLeft", Vector3.LEFT],
	["stop_leg", "Base1/WaterTower/LegGateLeft", Vector3.LEFT],
	["stop_tank", "Depot/FuelTanks/FuelTankSouth/Collider", Vector3.BACK],
	["stop_turret", "Base1/Turrets/TurretLeft", Vector3.LEFT]]
## Metres in front of a Turret the Gyrocopter it fires at stands, and how far beside the Turret the other Player's Gyrocopter stands (the
## Turret's own Player, whom it never fires at); the moment is the first tick a Shot of the Turret is within NEAR metres of its target, where
## the target's chase view sees the tracer under its gear.
const TURRET_RANGE: float = 14.0
const BESIDE: Vector3 = Vector3(1.0, 0.0, 4.0)
const NEAR: float = 5.0
## Ticks the flights may take, a Shot is let fly before its moment (a tracer 3.6 m ahead of a Gyrocopter's muzzle shows under its gear), and an
## explosion before its moment.
const DRIVE_LIMIT: int = 420
const SHOT_TICKS: int = 2
const BLAST_TICKS: int = 20
const SMOKE_TICKS: int = 60
## The share of its hit points a smoking Gyrocopter has left (the badly damaged state is at 20%).
const HURT_SHARE: float = 0.15

var _k: Kit20
var _q: Quick
var _problems: PackedStringArray = []
var _moments: PackedStringArray = []
var _pass: String = "above"


## Plays the moments, then the premise CHECK (only when one failed) and the RESULT line. A coroutine.
func run(harness: Node) -> void:
	_k = Kit20.new(harness)
	_q = _k.q()
	await _both_choose()
	_line("garage_spawn_above", "both Gyrocopters spawned in their Garages by the choice keys, the models' lowest points %.3f and %.3f m" % [Quick.model_bottom(_q.units.units[0]), Quick.model_bottom(_q.units.units[1])])
	await _q.kit.advance(Looks.HOLD_TICKS)
	var only: String = OS.get_environment("HEIGHTS_PASS")
	var moments: PackedStringArray = OS.get_environment("HEIGHTS_MOMENTS").split(",", false)
	for pass_index: int in 2:
		if only == "chase" and pass_index == 0:
			await _switch_views()
			continue
		if only == "above" and pass_index == 1:
			break
		_pass = "above" if pass_index == 0 else "chase"
		await _dress()
		if moments.is_empty() or moments.has("stand"):
			await _standing()
		if moments.is_empty() or moments.has("stop"):
			await _stops()
		if moments.is_empty() or moments.has("fire"):
			await _firing()
		if moments.is_empty() or moments.has("end"):
			await _end_states()
		if pass_index == 0:
			await _switch_views()
			await _swap_respawn()
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


## Both Players choose the Gyrocopter with their own keys at once: the next-type key for whichever cursor is not on it, then both fire keys.
func _both_choose() -> void:
	for _step: int in 8:
		var keys: Array[Key] = []
		for player: int in Kit.PLAYERS:
			if _q.units.panels[player].choice_input.cursor != Quick.GYROCOPTER:
				keys.append_array(Tokens.keys(&"next", player))
		if keys.is_empty():
			break
		await _q.kit.press_settled(keys)
	await _q.kit.press_settled(Tokens.keys(&"fire", 0) + Tokens.keys(&"fire", 1))
	for _wait: int in 400:
		if _q.controller.is_alive(0) and _q.controller.is_alive(1):
			break
		await _q.kit.tick()
	await _q.kit.advance(3)


## Both Players Self-destruct in their Garages (a Swap) and choose the Gyrocopter again.
func _swap_respawn() -> void:
	await _q.kit.press_settled(Tokens.keys(&"destruct", 0) + Tokens.keys(&"destruct", 1))
	await _both_choose()
	_need(_q.units.units[0].is_alive and _q.units.units[1].is_alive, "garage_spawn_chase: a Gyrocopter did not appear")
	_line("garage_spawn_chase", "both Gyrocopters spawned in their Garages after a Swap, the models' lowest points %.3f and %.3f m" % [Quick.model_bottom(_q.units.units[0]), Quick.model_bottom(_q.units.units[1])])
	await _q.kit.advance(Looks.HOLD_TICKS)


## Every piece and Turret back and both Players in play.
func _dress() -> void:
	for player: int in Kit.PLAYERS:
		await _k.k.k.m.revive(player)
	await _k.k.k.restore_all(true)


## A Base-local place and direction at Player `player`'s own Base.
func _base(player: int, local: Vector3) -> Vector3:
	return _k.k.k.m.w.point(player, local)


func _way(player: int, local: Vector3) -> Vector3:
	return _k.k.k.m.w.way(player, local)


## The mirror across x = 0, Player 2's side of the Map.
static func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Stages a pair as types at places facing ways, holds, checks that both are alive, in the pass's view, and that the Gyrocopters' models
## stand at the flying height; then the moment's line and a hold.
func _show(moment: String, types: Array[int], ats: Array[Vector3], faces: Array[Vector3], reads: String) -> void:
	await _q.map.stage(types, ats, faces, true)
	await _q.kit.advance(Looks.HOLD_TICKS)
	_finish(moment, reads)
	await _q.kit.advance(Looks.HOLD_TICKS)


## The checks and the line of a moment whose pair is in place (both Units in play unless `alive` is false).
func _finish(moment: String, reads: String, alive: bool = true) -> void:
	var want: String = Looks.ABOVE_FILE if _pass == "above" else Looks.CHASE_FILE
	var in_play: bool = _q.units.units[0].is_alive and _q.units.units[1].is_alive
	_need(in_play == alive and _views() == PackedStringArray([want, want]), "%s_%s: Units alive %s, the cameras are on %s" % [moment, _pass, in_play, _views()])
	for player: int in Kit.PLAYERS:
		if alive and _q.units.units[player].stats.can_fly:
			_need(absf(Quick.model_bottom(_q.units.units[player]) - _k.height) <= Kit20.TOLERANCE + Kit20.FLOAT_SLACK, "%s_%s: Player %d's model stands at %.4f m" % [moment, _pass, player + 1, Quick.model_bottom(_q.units.units[player])])
	_line("%s_%s" % [moment, _pass], "%s views=%s" % [reads, ", ".join(_views())])


## The Gyrocopters standing over each kind of low piece, over a Truck and through each other.
func _standing() -> void:
	var gyro: Array[int] = [Kit20.GYRO, Kit20.GYRO]
	var back: Vector3 = Vector3.BACK
	await _show("over_base_wall", gyro, [_base(0, BASE_WALL), _base(1, BASE_WALL)], [_way(0, back), _way(1, back)], "both Gyrocopters over a Wall Panel of their Base's back wall (2 m), the models %.2f m over its top" % (_k.height - 2.0))
	await _show("over_flag_wall", gyro, [_base(0, FLAG_WALL), _base(1, FLAG_WALL)], [_way(0, Vector3.FORWARD), _way(1, Vector3.FORWARD)], "both over the Flag Wall at the Gate side of the water tower")
	await _show("over_wreck", gyro, [WRECK, _mirror(WRECK)], [Vector3.RIGHT, Vector3.LEFT], "both over a wreck of their side of the Map")
	await _show("over_container", gyro, [CONTAINER, _mirror(CONTAINER)], [Vector3.BACK, Vector3.BACK], "both over a container")
	await _show("over_cliff", gyro, [CLIFF, _mirror(CLIFF)], [Vector3.FORWARD, Vector3.FORWARD], "both over the canyon's south wall")
	await _show("over_channel", gyro, [CHANNEL, _mirror(CHANNEL)], [Vector3.BACK, Vector3.BACK], "both over a water channel")
	await _show("over_truck", [Kit20.GYRO, Quick.TRUCK], [MIDDLE, MIDDLE], [Vector3.RIGHT, Vector3.RIGHT], "Player 1's Gyrocopter right over Player 2's Truck, the whip antenna drawn into its gear")
	_need(_q.units.units[0].global_position.distance_to(_q.units.units[1].global_position) <= 0.5, "over_truck_%s: the Gyrocopter is %.2f m from the Truck" % [_pass, _q.units.units[0].global_position.distance_to(_q.units.units[1].global_position)])
	await _show("over_truck_swapped", [Quick.TRUCK, Kit20.GYRO], [MIDDLE, MIDDLE], [Vector3.RIGHT, Vector3.RIGHT], "Player 2's Gyrocopter right over Player 1's Truck")
	await _show("through_each_other", gyro, [MIDDLE - Vector3.RIGHT * 0.5, MIDDLE + Vector3.RIGHT * 0.5], [Vector3.RIGHT, Vector3.LEFT], "two Gyrocopters nose to nose through each other, their models overlapping")
	var overlap: bool = Quick.model_box(_q.units.units[0]).intersects(Quick.model_box(_q.units.units[1]))
	_need(overlap, "through_each_other_%s: the two models do not overlap" % _pass)


## Both Gyrocopters driven into a Tall piece and held there: Player 2 at the mirror of Player 1's piece, or at the opposite face of the tank.
func _stops() -> void:
	var half: float = _q.units.stats(Kit20.GYRO).collision_size.z / 2.0
	var rows: Array[Dictionary] = _k.solid_rows(_k.map())
	for entry: Array in STOPS:
		var box: AABB = AABB()
		for row: Dictionary in rows:
			if row["path"] == entry[1]:
				box = row["shape_box"]
		var dir: Vector3 = entry[2]
		var reach: float = (absf(dir.x) * box.size.x + absf(dir.z) * box.size.z) / 2.0
		var centre: Vector3 = Vector3(box.get_center().x, 0.0, box.get_center().z)
		var first: Vector3 = centre - dir * (reach + Kit20.RUN_UP + half)
		var second: Vector3 = _mirror(first)
		var second_dir: Vector3 = _mirror(dir)
		if entry[0] == "stop_tank":
			second = centre + dir * (reach + Kit20.RUN_UP + half)
			second_dir = -dir
		await _q.map.stage([Kit20.GYRO, Kit20.GYRO], [first, second], [dir, second_dir], true)
		var rec: Dictionary = await _k.run_staged(0, DRIVE_LIMIT, func(u: Unit) -> bool: return _q.map.wall_contact(u), 1)
		for _tick: int in Looks.HOLD_TICKS:
			_q.harness.drive(0, 1, 0)
			_q.harness.drive(1, 1, 0)
			await _q.kit.tick()
		_q.harness.release_all()
		_need((rec["touches"] as Array).has(true) and _q.map.wall_contact(_q.units.units[0]) and _q.map.wall_contact(_q.units.units[1]), "%s_%s: a Gyrocopter did not stop against the piece" % [entry[0], _pass])
		_finish(entry[0], "both Gyrocopters stopped flush against the Tall piece (%s) by their bodies, the models (%.2f to %.2f m) beside its upper part" % [entry[1], _k.height, _k.band().y])
		await _q.kit.advance(Looks.HOLD_TICKS)


## Both Gyrocopters fire at each other down one row (the moment is two ticks after the Shots left, tracers in the air at the shooting
## height), and Base A's Turret fires from its raised head at Player 2's Gyrocopter in front of it.
func _firing() -> void:
	var left: Vector3 = MIDDLE + Vector3.LEFT * FIRE_APART
	var right: Vector3 = MIDDLE + Vector3.RIGHT * FIRE_APART
	await _q.map.stage([Kit20.GYRO, Kit20.GYRO], [left, right], [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.advance(_k.k.k.m.w.longest_cadence())
	for player: int in Kit.PLAYERS:
		_q.harness.set_key(_q.harness.fire_key(player), true)
	await _q.kit.advance(1)
	for player: int in Kit.PLAYERS:
		_q.harness.set_key(_q.harness.fire_key(player), false)
	await _q.kit.advance(SHOT_TICKS)
	var in_air: int = _q.harness.get_tree().get_nodes_in_group(&"shots").size()
	_need(in_air >= 2, "fire_gyros_%s: %d Shots in the air" % [_pass, in_air])
	_finish("fire_gyros", "both Gyrocopters' tracers in the air at the shooting height (%.1f m), %.2f m under their models (%d Shots)" % [_q.controller.rules.shooting_height, _k.height - _q.controller.rules.shooting_height, in_air])
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _k.k.k.restore_all(true)
	var turret: Turret = _k.k.k.turret(0, 0)
	var fired_before: int = _k.k.k.fired.size()
	await _q.map.stage([Kit20.GYRO, Kit20.GYRO], [turret.global_position + BESIDE, turret.global_position + Vector3.RIGHT * TURRET_RANGE], [Vector3.RIGHT, Vector3.LEFT], true)
	var near: bool = false
	for _tick: int in DRIVE_LIMIT:
		await _q.kit.tick()
		for record: Dictionary in _k.k.k.fired.slice(fired_before):
			var shot: Variant = record["shot"]
			near = near or (is_instance_valid(shot) and (shot as Shot).is_inside_tree() and (shot as Shot).global_position.distance_to(_q.units.units[1].global_position) <= NEAR)
		if near:
			break
	_need(near, "fire_turret_%s: no Shot of the Turret came within %.0f m of its target" % [_pass, NEAR])
	var barrel: AABB = Kit20.drawn_box(turret.get_node("Look/Head/Barrel")) as AABB
	_finish("fire_turret", "Base A's Turret firing from its raised head (barrel drawn %.2f to %.2f m) at Player 2's Gyrocopter %.0f m in front of it, the tracer at %.1f m; Player 1's Gyrocopter stands beside the Turret, which never fires at it" % [barrel.position.y, barrel.end.y, TURRET_RANGE, _q.controller.rules.shooting_height])
	await _q.kit.advance(Looks.HOLD_TICKS)


## Between the water tower's legs under its tank; smoking when badly damaged; blown up in the air.
func _end_states() -> void:
	await _dress()
	var gyro: Array[int] = [Kit20.GYRO, Kit20.GYRO]
	await _show("under_tank", gyro, [_base(0, BETWEEN_LEGS), _base(1, BETWEEN_LEGS)], [_way(0, Vector3.BACK), _way(1, Vector3.BACK)], "both Gyrocopters between their water tower's legs, its tank above them")
	await _q.map.stage(gyro, [MIDDLE + Vector3.LEFT * FIRE_APART, MIDDLE + Vector3.RIGHT * FIRE_APART], [Vector3.RIGHT, Vector3.LEFT], true)
	for player: int in Kit.PLAYERS:
		var unit: Unit = _q.units.units[player]
		unit.apply_damage(unit.hit_points - unit.stats.max_hit_points * HURT_SHARE)
	await _q.kit.advance(SMOKE_TICKS)
	_need(_q.units.units[0].is_badly_damaged and _q.units.units[1].is_badly_damaged, "smoking_%s: a Gyrocopter is not badly damaged" % _pass)
	_finish("smoking", "both Gyrocopters badly damaged (%.0f%% of their hit points), smoke rising from the top of their drawn bodies at the flying height" % (HURT_SHARE * 100.0))
	await _q.kit.advance(Looks.HOLD_TICKS)
	await _q.map.stage(gyro, [MIDDLE + Vector3.LEFT * FIRE_APART, MIDDLE + Vector3.RIGHT * FIRE_APART], [Vector3.RIGHT, Vector3.LEFT], true)
	await _q.kit.press_settled(Tokens.keys(&"destruct", 0) + Tokens.keys(&"destruct", 1))
	await _q.kit.advance(BLAST_TICKS)
	var blasts: int = _q.harness.split.find_children("*", "Explosion", true, false).size()
	_need(blasts >= 2, "explosions_%s: %d Explosions" % [_pass, blasts])
	_finish("explosions", "both Gyrocopters blown up where their models were drawn, in the air (%d Explosions)" % blasts, false)
	await _q.kit.advance(Looks.HOLD_TICKS)
