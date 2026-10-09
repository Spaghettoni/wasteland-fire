extends RefCounted
## Scenario flag_walls of the split screen evidence harness (split_screen_harness.gd): the Flag
## Walls of Story 012 AC-1 to AC-9, played with real keys on the shipped data and Map 01. This
## script holds walls_data (what the scenes and data say), layer_timing (the Measure first of the
## story: when a Structure that falls or is restored starts to answer queries), damage (what a Shot
## of each type takes off a Flag Wall, whose Shots spare which, and what a Shot does to a body that
## is not a Unit), flags_untouched and no_engine_noise. flag_walls_moves.gd runs spawn_and_exits and
## stops, then flag_walls_over.gd's gyro_over and flag_visible; flag_walls_looks.gd runs looks (the
## damaged looks, from damage's runs); flag_walls_flows.gd runs spots, closed, raids and breach,
## then flag_walls_returns.gd's owner_return and reset. One Round, played on after each check.
## Implements: production/epics/wasteland-fire/story-012-flag-walls.md AC-1 to AC-9. Tooling only.
## Every number comes from the game's data; the scenario types only its test inputs. Run: godot
## --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=flag_walls

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd).
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The movement checks (flag_walls_moves.gd) and the Round flows (flag_walls_flows.gd).
const Moves: GDScript = preload("res://tools/evidence/split_screen/flag_walls_moves.gd")
const Flows: GDScript = preload("res://tools/evidence/split_screen/flag_walls_flows.gd")
## The two bodies that are not Units (flag_walls_bodies.gd) and the damaged looks
## (flag_walls_looks.gd).
const Bodies: GDScript = preload("res://tools/evidence/split_screen/flag_walls_bodies.gd")
const Looks: GDScript = preload("res://tools/evidence/split_screen/flag_walls_looks.gd")
## The Map's scenario that lists the scripts a node of Map 01 may carry (SCRIPTS).
const MapLayout: GDScript = preload("res://tools/evidence/split_screen/map_layout.gd")
## The data this story adds, by path.
const STATS_PATH: String = "res://src/gameplay/defences/data/flag_wall_stats.tres"

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap the shipped rules turn on (a Unit is swapped at home in the flows), the
## camera the build ships with, and the Flag Walls and side spawn spots the Map ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
## Tokens enough that the raids, the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds: the damage, the drives out of sixteen spots, the raids and the restarts.
const WATCHDOG_SECONDS: float = 1500.0
## Metres out of the seat, along the Gate axis, where a shooter stands: outside the Gate walls.
const SHOT_FROM: float = 12.0
## Shots a Motorbike fires at a Flag Wall to show it takes nothing, however long it fires.
const MOTORBIKE_SHOTS: int = 12
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.01
## A Unit has moved when it has come this far, metres.
const MOVED: float = 0.01
## The physics layer the Flag Walls stand on (cover, value 64): nothing that watches Units may see
## it.
const COVER_LAYER: int = 64

var _w: Walls
## The engine errors this script causes on purpose (the Flag Walls built wrong in damage and looks),
## for the noise check.
var _expected_errors: int = 0
var _measured: PackedStringArray = []
## damage's runs to the fall, for the looks check: {type id: [[hit points, look shown], ...]}.
var _runs: Dictionary = {}


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_w = Walls.new(harness)
	await _w.s.both_play()
	var start_spots: bool = _w.on_first_spot(0) and _w.on_first_spot(1)
	_walls_data(start_spots)
	await _layer_timing()
	var moves: Moves = Moves.new(_w)
	await moves.run()
	await _damage()
	var looks: Looks = Looks.new(_w)
	await looks.run(_runs)
	_expected_errors += looks.expected_errors
	_flags_untouched()
	var flows: Flows = Flows.new(_w)
	await flows.run()
	var noise: PackedStringArray = []
	var errors: Array[String] = _w.s.q.tokens.engine_log.errors
	var warnings: Array[String] = _w.s.q.tokens.engine_log.warnings
	_w.s.q.kit.need(noise, errors.size() == _expected_errors + flows.expected_errors and warnings.is_empty(),
		"the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors + flows.expected_errors, warnings])
	_w.s.q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d, the Flag Walls built wrong on purpose (no stats; a list of looks short or with an empty slot; fractions out of order) account for %d" % [
		errors.size(), warnings.size(), _expected_errors + flows.expected_errors])
	_w.close()
	harness.finish("walls=8 falls=%d %s" % [_w.falls.size(), " ".join(_measured)])


## walls_data (AC-1, AC-6, AC-8): four Flag Walls per Base under Defences and in structures, on
## layer 64 with mask 0, their stats from the one .tres, their box where the story puts it, the
## matrix row and its default, the owners SplitScreen set, the Map's scripts and the Garage's spots.
func _walls_data(start_spots: bool) -> void:
	var problems: PackedStringArray = []
	var q: Quick = _w.s.q
	var rules: MatchRules = _w.s.controller.rules
	var extents: Array[String] = []
	for base_index: int in Kit.PLAYERS:
		var base: Base = _w.bases[base_index]
		var defences: Node = base.get_node_or_null("Defences")
		q.kit.need(problems, defences != null and base.structures.size() == 4, "%s: Defences %s, %d listed" % [base.name, defences, base.structures.size()])
		var box: AABB = AABB()
		for side: int in Walls.SIDE_NAMES.size():
			var wall: Structure = _w.wall(base_index, side)
			if wall == null or defences == null:
				q.kit.need(problems, false, "%s/%s is missing" % [base.name, Walls.SIDE_NAMES[side]])
				continue
			q.kit.need(problems, base.structures.has(wall) and wall.get_parent() == defences, "%s is not listed under Defences" % wall.name)
			q.kit.need(problems, wall.collision_layer == 64 and wall.collision_mask == 0, "%s: layer %d mask %d" % [wall.name, wall.collision_layer, wall.collision_mask])
			q.kit.need(problems, wall.stats != null and wall.stats.resource_path == STATS_PATH and wall.type_id == &"flag_wall"
					and is_equal_approx(wall.stats.max_hit_points, Walls.HIT_POINTS) and is_equal_approx(wall.hit_points, Walls.HIT_POINTS)
					and wall.is_standing, "%s: stats/type/hit points %s" % [wall.name, wall.type_id])
			q.kit.need(problems, wall.player_index == base_index, "%s: player_index %d, not %d" % [wall.name, wall.player_index, base_index])
			var shape: CollisionShape3D = wall.get_node("CollisionShape3D") as CollisionShape3D
			var part: AABB = shape.global_transform * AABB(-(shape.shape as BoxShape3D).size / 2.0, (shape.shape as BoxShape3D).size)
			box = part if side == 0 else box.merge(part)
			var mesh: MeshInstance3D = wall.get_node("Mesh") as MeshInstance3D
			q.kit.need(problems, absf((mesh.global_transform * mesh.get_aabb()).end.y - Walls.HEIGHT) <= TOLERANCE, "%s is drawn %.3f m tall" % [wall.name, (mesh.global_transform * mesh.get_aabb()).end.y])
			q.kit.need(problems, mesh.mesh.material == (base.get_node("Walls/WallBack/Mesh") as MeshInstance3D).mesh.material, "%s does not wear the Base walls' material" % wall.name)
		var want: AABB = base.global_transform * AABB(Vector3(-Walls.FACE, 0.0, Walls.SEAT.z - Walls.FACE), Vector3(2.0 * Walls.FACE, Walls.HEIGHT, 2.0 * Walls.FACE))
		q.kit.need(problems, box.position.distance_to(want.position) <= TOLERANCE and box.end.distance_to(want.end) <= TOLERANCE, "%s box %s, expected %s" % [base.name, box, want])
		extents.append("%s x %.1f..%.1f z %.1f..%.1f" % [base.name, box.position.x, box.end.x, box.position.z, box.end.z])
		q.kit.need(problems, (base.zone.collision_mask & COVER_LAYER) == 0 and (base.flag.pickup_zone.collision_mask & COVER_LAYER) == 0, "%s: the Base zone (mask %d) or the Flag's touch (mask %d) watches the Flag Walls' layer" % [base.name, base.zone.collision_mask, base.flag.pickup_zone.collision_mask])
		q.kit.need(problems, base.first_spawn_problem().is_empty() and q.units.units[base_index].player_index == base_index, "%s: spawn problem '%s', Unit player_index %d" % [base.name, base.first_spawn_problem(), q.units.units[base_index].player_index])
	var mirror: String = q.map.mirror(problems, 0.1)
	var spots: Array[Vector3] = [_w.bases[0].spawn_point.global_position, _w.bases[1].spawn_point.global_position]
	var spares: Array[Vector3] = [_w.bases[0].spare_spawn_points[0].global_position, _w.bases[1].spare_spawn_points[0].global_position]
	q.kit.need(problems, spots[0].distance_to(Vector3(-125.0, 0.0, -4.0)) <= TOLERANCE and spots[1].distance_to(Vector3(125.0, 0.0, -4.0)) <= TOLERANCE, "first spots %s, expected (-125, 0, -4) and (125, 0, -4)" % [spots])
	q.kit.need(problems, Quick.mirrored(spots[0]).distance_to(spots[1]) <= TOLERANCE and Quick.mirrored(spares[0]).distance_to(spares[1]) <= TOLERANCE and spots[0].distance_to(spares[0]) > 5.0, "spots do not mirror: %s %s" % [spots, spares])
	q.kit.need(problems, start_spots, "the Units did not start the Round on their first spots")
	for stats: UnitStats in rules.unit_types:
		q.kit.need(problems, (stats.spot_mask & COVER_LAYER) == 0, "%s's spot test (mask %d) counts the Flag Walls' layer" % [stats.type_id, stats.spot_mask])
	var matrix: DamageMatrix = rules.damage_matrix
	var listed: Array = matrix.multipliers.keys().filter(func(key: StringName) -> bool: return String(key).ends_with(">flag_wall"))
	q.kit.need(problems, listed == [&"motorbike>flag_wall"] and matrix.multipliers[&"motorbike>flag_wall"] == 0.0 and matrix.default_multiplier == 1.0, "matrix rows against a Flag Wall: %s, default %s" % [listed, matrix.default_multiplier])
	var allowed: Array = MapLayout.get_script_constant_map().get("SCRIPTS", [])
	for node: Node in q.map.map.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		q.kit.need(problems, script == null or allowed.has(script.resource_path), "%s carries %s, which map_layout does not allow" % [node.get_path(), script.resource_path if script != null else ""])
	q.kit.verdict("walls_data", problems, "%s | 8 Flag Walls on layer 64, mask 0, %s, %.0f hit points | %s | first spots (-125,0,-4) and (125,0,-4), spares mirrored | matrix: %s" % [
		" ; ".join(extents), STATS_PATH.get_file(), Walls.HIT_POINTS, mirror, listed])


## layer_timing (AC-4, AC-5; the story's Measure first): a mask-83 ray through a Flag Wall destroyed
## in the scenario's tick, in that tick and the next, and restored the same way; and a Motorbike
## driven at it, pressed against the face when it falls and approaching at speed when it is
## restored. The ticks are the measurement; the verdict is that the fallen piece blocks nothing from
## the next tick at the latest and the restored one blocks from the next tick at the latest.
func _layer_timing() -> void:
	var problems: PackedStringArray = []
	var wall: Structure = _w.wall(1, Walls.GATE)
	var q: Quick = _w.s.q
	q.kit.need(problems, _w.axis_blocked(1, Walls.GATE), "the standing Flag Wall does not block the ray")
	wall.destroy()
	var destroyed_same: bool = _w.axis_blocked(1, Walls.GATE)
	await q.kit.tick()
	var destroyed_next: bool = _w.axis_blocked(1, Walls.GATE)
	wall.restore()
	var restored_same: bool = _w.axis_blocked(1, Walls.GATE)
	await q.kit.tick()
	var restored_next: bool = _w.axis_blocked(1, Walls.GATE)
	q.kit.need(problems, not destroyed_next and restored_next, "the ray sees a fallen Flag Wall (next tick: %s) or no restored one (%s)" % [destroyed_next, restored_next])
	var unit: Unit = q.units.units[0]
	var base: Base = _w.bases[1]
	var face_z: float = Walls.SEAT.z - Walls.FACE
	await _w.face(0, Quick.MOTORBIKE, 1, Walls.GATE, Walls.FACE + 0.3 + unit.stats.collision_size.z / 2.0)
	_w.s.q.harness.drive(0, 1, 0)
	await q.kit.advance(6)
	var start: float = base.to_local(unit.global_position).z
	wall.destroy()
	await q.kit.tick()
	var first: float = base.to_local(unit.global_position).z - start
	await q.kit.tick()
	var second: float = base.to_local(unit.global_position).z - start
	q.kit.need(problems, second > MOVED, "a Motorbike pressed against the fallen Flag Wall moved %.4f m in its first tick and %.4f by the second: it is still held" % [first, second])
	q.harness.release_all()
	await q.kit.advance(Walls.SETTLE)
	await _w.face(0, Quick.MOTORBIKE, 1, Walls.GATE, Walls.RUN_UP + 4.0)
	_w.s.q.harness.drive(0, 1, 0)
	var gap: float = INF
	var restored_at: int = -1
	var blocked_after: float = INF
	for count: int in 90:
		await q.kit.tick()
		gap = (face_z - base.to_local(unit.global_position).z) - unit.stats.collision_size.z / 2.0
		if restored_at < 0 and gap <= unit.current_speed / 60.0 and gap > 0.0:
			wall.restore()
			restored_at = count
		elif restored_at >= 0 and count == restored_at + 1:
			blocked_after = face_z - base.to_local(unit.global_position).z - unit.stats.collision_size.z / 2.0
		elif restored_at >= 0 and count == restored_at + 3:
			break
	q.harness.release_all()
	q.kit.need(problems, _w.s.flags.pick_ups.is_empty(), "a Flag was picked up while the Flag Wall was timed")
	var end_gap: float = (face_z - base.to_local(unit.global_position).z) - unit.stats.collision_size.z / 2.0
	q.kit.need(problems, restored_at >= 0 and end_gap > -0.1 and end_gap < 0.2, "a Motorbike approaching at speed when the Flag Wall was restored ended %.3f m from the face (restored on tick %d)" % [end_gap, restored_at])
	_measured.append("ray_after_destroy=%s/%s ray_after_restore=%s/%s drive_first_tick_after_destroy=%.4f m restored_at_gap=%.3f m" % [
		destroyed_same, destroyed_next, restored_same, restored_next, first, blocked_after])
	q.kit.verdict("layer_timing", problems, "a ray on mask %d through the Gate-side Flag Wall of Base B: standing blocks; destroyed in the scenario's tick it answers %s in that tick and %s a tick later; restored it answers %s in that tick and %s a tick later (true means it still blocks); a Motorbike pressed against it moved %.4f m in the first tick after it fell and %.4f in the second; a Motorbike approaching at speed when it was restored ended %.3f m from the face" % [
		q.controller.rules.shot_collision_mask, destroyed_same, destroyed_next, restored_same, restored_next, first, second - first, end_gap])
	await _w.restore_all()


## damage (AC-3): at a Gate-side Flag Wall, one Shot of each type, from each Player, takes damage x
## the matrix's multiplier off the other Player's (12, 25, 15; the Motorbike's 0 emits nothing) and
## nothing off the Player's own; each Shot ends on the face; the Flag Wall falls on the Shot its hit
## points predict (the Motorbike's never); a body with apply_damage() and no type_id stops a Shot
## and is not asked to take damage; a Flag Wall with no stats logs one error when it enters the tree
## and nothing when a Shot ends on it.
func _damage() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	var q: Quick = _w.s.q
	var matrix: DamageMatrix = q.controller.rules.damage_matrix
	var face_z: float = Walls.SEAT.z - Walls.FACE
	for type_index: int in 4:
		var stats: UnitStats = q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		for player: int in Kit.PLAYERS:
			for target_base: int in [1 - player, player]:
				await _w.restore_all()
				var wall: Structure = _w.wall(target_base, Walls.GATE)
				await _w.face(player, type_index, target_base, Walls.GATE, SHOT_FROM)
				await q.kit.advance(_w.longest_cadence())
				var hits_before: int = _w.hits.size()
				var end: Vector3 = await _w.shoot(player)
				var want: float = per_shot if target_base != player else 0.0
				var label: String = "p%d %s at %s Flag Wall" % [player + 1, stats.type_id, "its own" if target_base == player else "the other Player's"]
				q.kit.need(problems, is_equal_approx(Walls.HIT_POINTS - wall.hit_points, want), "%s took %.2f, expected %.2f" % [label, Walls.HIT_POINTS - wall.hit_points, want])
				q.kit.need(problems, _w.hits.size() == hits_before + (1 if want > 0.0 else 0), "%s: %d hit_points_changed emitted" % [label, _w.hits.size() - hits_before])
				q.kit.need(problems, end != Vector3.INF and absf(_w.bases[target_base].to_local(end).z - face_z) <= TOLERANCE, "%s ended at %s, not on the face" % [label, end])
				q.kit.need(problems, _w.look_shown(wall) == (1 if want > 0.0 else 0), "%s: look %d shown after one Shot (AC-9)" % [label, _w.look_shown(wall)])
		notes.append("%s %.0f" % [stats.type_id, per_shot])
	for type_index: int in 4:
		var stats: UnitStats = q.units.stats(type_index)
		var per_shot: float = stats.damage * matrix.multiplier(stats.type_id, &"flag_wall")
		var predicted: int = ceili(Walls.HIT_POINTS / per_shot) if per_shot > 0.0 else -1
		await _w.restore_all()
		var wall: Structure = _w.wall(1, Walls.GATE)
		await _w.face(0, type_index, 1, Walls.GATE, SHOT_FROM)
		var falls_before: int = _w.falls.size()
		var hits_before: int = _w.hits.size()
		var fell_on: int = -1
		var seen: Array = []
		await q.kit.advance(_w.longest_cadence())
		for shot: int in range(1, (predicted if predicted > 0 else MOTORBIKE_SHOTS) + 1):
			if shot > 1:
				await q.kit.advance(_w.cadence(type_index))
			await _w.shoot(0)
			fell_on = shot if fell_on < 0 and not wall.is_standing else fell_on
			seen.append([wall.hit_points, _w.look_shown(wall)])
		_runs[stats.type_id] = seen
		q.kit.need(problems, fell_on == predicted and _w.falls.size() == falls_before + (1 if predicted > 0 else 0), "%s: the Flag Wall fell on shot %d (%d falls), expected %d" % [stats.type_id, fell_on, _w.falls.size() - falls_before, predicted])
		q.kit.need(problems, predicted > 0 or (wall.is_standing and _w.hits.size() == hits_before), "the Motorbike changed a Flag Wall after %d shots" % MOTORBIKE_SHOTS)
		notes.append("%s falls on shot %d" % [stats.type_id, predicted])
	await _w.restore_all()
	var bodies: Bodies = Bodies.new(_w)
	await bodies.run(problems, notes)
	_expected_errors += bodies.expected_errors
	q.kit.verdict("damage", problems, "per-shot damage and the shots to fall (%s): each Player's Shots of every type took the multiplier from the other Player's Gate-side Flag Wall and nothing from its own, and every Shot ended on the face" % ", ".join(notes))
	await _w.restore_all()


## flags_untouched: the checks before the flows moved no Flag and ended no Round, so every one of
## them was measured with both Flags on their seats.
func _flags_untouched() -> void:
	var problems: PackedStringArray = []
	var flags: Object = _w.s.flags
	_w.s.q.kit.need(problems, flags.pick_ups.is_empty() and flags.drops.is_empty() and flags.seats.is_empty() and flags.round_overs.is_empty() and not _w.s.controller.is_round_over(),
		"picked up %s, dropped %s, seated %s, over %s" % [flags.pick_ups, flags.drops, flags.seats, flags.round_overs])
	_w.s.q.kit.verdict("flags_untouched", problems, "no Flag was picked up, dropped or seated and no Round ended during walls_data, layer_timing, spawn_and_exits, stops, gyro_over, flag_visible and damage")
