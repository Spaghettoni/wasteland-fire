extends RefCounted
## Scenario garage_scrap_walls of the split screen evidence harness (split_screen_harness.gd): the Garage walls and
## the two scrap walls of Story 019 AC-1 to AC-6 and AC-8, which are Wall Panels, played with real keys on the
## shipped data and Map 01. This script holds panels_data (what the scenes and data say: 28 panels where AC-1 and
## AC-4 put them, flush, the Garage, the Map's list, the Cover and the lists unchanged or as the story has them) and
## no_engine_noise; the modules it runs, in this order, hold the rest: garage_scrap_walls_moves.gd
## (garage_unchanged, spawn_exits and stops: AC-1, AC-2), garage_scrap_walls_over.gd (drawn_height,
## gyro_over and stopped_by: AC-2), garage_scrap_walls_cover.gd (cover_unchanged: AC-5),
## garage_scrap_walls_damage.gd (damage and looks: AC-1, AC-3, AC-4), garage_scrap_walls_breach.gd
## (garage_exposed: AC-3), garage_scrap_walls_field.gd (field_breach: AC-4) and
## garage_scrap_walls_round.gd (stays_down and restore: AC-6). One Round, played on after each
## check; a module that wins a Round presses R before it ends, and modules_leave_a_fresh_round fails
## if one ends otherwise. GARAGE_ONLY=moves,over (an environment variable of a run by hand) runs
## named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-019-garage-and-scrap-wall-panels.md AC-1 to AC-6 and AC-8. Every number
## comes from the game's data; the scenario types only its test inputs and the story's values. Run: godot --headless
## --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=garage_scrap_walls

const Kit19: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Moves: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_moves.gd")
const Over: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_over.gd")
const Cover: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_cover.gd")
const Damage: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_damage.gd")
const Breach: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_breach.gd")
const Field: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_field.gd")
const Round: GDScript = preload("res://tools/evidence/split_screen/garage_scrap_walls_round.gd")
## The data this story reads: the Flag Walls' stats, which every panel shares (R10).
const STATS_PATH: String = "res://src/gameplay/defences/data/flag_wall_stats.tres"
const SCENE_DIR: String = "res://src/gameplay/defences/"

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Garage and field Wall
## Panels and the Base walls', the Turrets with their looks, the Mines, the Flag Walls and their side spots, the
## explosions, the badly damaged state, the swap and the view from above.
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
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the drives, the Shots, the Rounds.
const WATCHDOG_SECONDS: float = 3000.0
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.001
## The physics layers: the Map's, and the cover the panels stand on.
const MAP_LAYER: int = 1
const COVER_LAYER: int = 64
## The structures a Base lists: 4 Flag Walls, 2 Turrets, 30 Base-wall panels and the 10 of its Garage (AC-6); the
## Map's list of the field's panels (AC-5).
const LISTED: int = 46
const LISTED_BY_MAP: int = 8
## The Garage as it was (AC-1): its children in order, the floor's size and place, the dashes of its Marking and
## the spawn spots (Base-local), which the walls leave alone.
const GARAGE_CHILDREN: Array[String] = ["GarageFloor", "GarageBack", "GarageSideLeft", "GarageSideRight", "Marking"]
const FLOOR_SIZE: Vector2 = Vector2(12.0, 10.0)
const FLOOR_AT: Vector3 = Vector3(0.0, 0.03, 7.0)
const DASHES: int = 14
const SPOTS: Array[Vector3] = [Vector3(-4.0, 0.0, 5.0), Vector3(4.0, 0.0, 5.0)]
## The Cover as it is now (AC-5): the eight wrecks and the two containers, and nothing else.
const COVER_CHILDREN: Array[String] = ["Wrecks", "Containers"]
const WRECKS: int = 8
const CONTAINERS: int = 2

var _k: Kit19
var _q: Object
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. GARAGE_ONLY (an
## environment variable of a run by hand) names modules, "moves,over", to run on their own.
func run(harness: Node) -> void:
	_k = Kit19.new(harness)
	_q = _k.q()
	await _k.k.m.w.s.both_play()
	_panels_data()
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("GARAGE_ONLY")
	for module: GDScript in [Moves, Over, Cover, Damage, Breach, Field, Round]:
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("garage_scrap_walls_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.k.m.clear_mines()
		var controller: MatchController = _k.k.m.w.s.controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.k.m.w.carrying(0) and not _k.k.m.w.carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.k.m.w.carrying(0), _k.k.m.w.carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("garage_scrap_walls_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: panels hit, hurt, felled, driven through, flown over, restored, with Mines laid in their breaches; the panels built wrong on purpose account for %d" % [errors.size(), warnings.size(), _expected_errors])
	_k.close()
	harness.finish("panels=28 falls=%d %s" % [_k.falls.size(), " ".join(_measured)])


## panels_data (AC-1, AC-4, AC-5, AC-6, AC-8): the 10 panels a Base has in its Garage's three walls and the 8 the Map
## lists for its two field walls, each the size the story gives its run, flush with its neighbours and in the old
## walls' footprint, on layer 64 with mask 0, with the Flag Walls' stats, a Garage panel owned by its Base's Player
## and listed in its structures, a field panel owned by nobody (-1) and listed in the Map's list; the Garage's floor,
## Marking and spawn spots, the Base's lists and the Cover as the story has them; every run a plain node with no
## script, every panel the shipped Structure script.
func _panels_data() -> void:
	var problems: PackedStringArray = []
	var rules: MatchRules = _q.controller.rules
	var field_node: MapField = _q.harness.split.field
	var seen: Dictionary = {"meshes": [], "shapes": [], "gaps": 0.0, "count": 0, "garage": [[], []], "field": [[], []]}
	for base_index: int in Kit19.Kit.PLAYERS:
		var base: Base = _k.k.m.w.bases[base_index]
		var garage: Node = base.get_node("Garage")
		var names: PackedStringArray = []
		for child: Node in garage.get_children():
			names.append(String(child.name))
		_q.kit.need(problems, names == PackedStringArray(GARAGE_CHILDREN), "%s: Garage holds %s, not %s" % [base.name, names, GARAGE_CHILDREN])
		_q.kit.need(problems, base.structures.size() == LISTED, "%s lists %d Structures, not %d" % [base.name, base.structures.size(), LISTED])
		var floor_mesh: MeshInstance3D = garage.get_node_or_null("GarageFloor") as MeshInstance3D
		_q.kit.need(problems, floor_mesh != null and floor_mesh.position.is_equal_approx(FLOOR_AT) and (floor_mesh.mesh as PlaneMesh).size == FLOOR_SIZE, "%s: the Garage floor moved or changed size" % base.name)
		_q.kit.need(problems, garage.get_node("Marking").get_child_count() == DASHES, "%s: the Marking has %d dashes, not %d" % [base.name, garage.get_node("Marking").get_child_count(), DASHES])
		var spots: Array[Vector3] = [base.spawn_point.position, base.spare_spawn_points[0].position]
		_q.kit.need(problems, spots.has(SPOTS[0]) and spots.has(SPOTS[1]) and spots[0] != spots[1], "%s: the spawn spots are at %s, not %s" % [base.name, spots, SPOTS])
		_q.kit.need(problems, base.first_spawn_problem().is_empty(), "%s: spawn problem '%s'" % [base.name, base.first_spawn_problem()])
		_q.kit.need(problems, (base.zone.collision_mask & COVER_LAYER) == 0 and (base.flag.pickup_zone.collision_mask & COVER_LAYER) == 0, "%s: the zone (mask %d) or the Flag's touch (mask %d) watches the panels' layer" % [base.name, base.zone.collision_mask, base.flag.pickup_zone.collision_mask])
		for run: int in Kit19.GARAGE_RUNS:
			_run_data(base_index, run, problems, seen)
	for run: int in Kit19.FIELD_RUNS:
		_run_data(0, run, problems, seen)
	_q.kit.need(problems, field_node.neutral_structures.size() == LISTED_BY_MAP, "the Map lists %d Structures of no Base, not %d" % [field_node.neutral_structures.size(), LISTED_BY_MAP])
	var cover: Node = field_node.get_node("Cover")
	var cover_names: PackedStringArray = []
	for child: Node in cover.get_children():
		cover_names.append(String(child.name))
	_q.kit.need(problems, cover_names == PackedStringArray(COVER_CHILDREN), "Cover holds %s, not %s (the scrap walls are gone from it)" % [cover_names, COVER_CHILDREN])
	_q.kit.need(problems, cover.get_node("Wrecks").get_child_count() == WRECKS and cover.get_node("Containers").get_child_count() == CONTAINERS, "Cover holds %d wrecks and %d containers, not %d and %d" % [cover.get_node("Wrecks").get_child_count(), cover.get_node("Containers").get_child_count(), WRECKS, CONTAINERS])
	for body: Node in cover.find_children("*", "CollisionObject3D", true, false):
		_q.kit.need(problems, body is StaticBody3D and (body as StaticBody3D).collision_layer == COVER_LAYER and body.get_script() == null and not body is Structure, "Cover/%s is not a plain StaticBody3D on the cover layer" % cover.get_path_to(body))
	_q.kit.need(problems, seen["count"] == 28 and seen["meshes"].size() == 3 and seen["shapes"].size() == 3, "%d panels with %d meshes and %d shapes: the panels of a length share theirs" % [seen["count"], seen["meshes"].size(), seen["shapes"].size()])
	var worst_mirror: float = 0.0
	for pair: Array in [seen["garage"], seen["field"]]:
		_q.kit.need(problems, pair[0].size() == pair[1].size() and not pair[0].is_empty(), "a mirror pair holds %d and %d panels" % [pair[0].size(), pair[1].size()])
		for centre: Vector3 in pair[0]:
			var nearest: float = INF
			for other: Vector3 in pair[1]:
				nearest = minf(nearest, Quick.mirrored(centre).distance_to(other))
			worst_mirror = maxf(worst_mirror, nearest)
	_q.kit.need(problems, worst_mirror <= TOLERANCE * 10.0, "a panel has no mirror image across x = 0: the worst is %.4f m off" % worst_mirror)
	var matrix: DamageMatrix = rules.damage_matrix
	var rows: Array = matrix.multipliers.keys().filter(func(key: StringName) -> bool: return String(key).ends_with(">flag_wall"))
	_q.kit.need(problems, rows == [&"motorbike>flag_wall"] and matrix.multipliers[&"motorbike>flag_wall"] == 0.0 and matrix.default_multiplier == 1.0, "matrix rows against a Flag Wall: %s, default %s" % [rows, matrix.default_multiplier])
	for stats: UnitStats in rules.unit_types:
		_q.kit.need(problems, (stats.spot_mask & COVER_LAYER) == 0, "%s's spot test (mask %d) counts the panels' layer" % [stats.type_id, stats.spot_mask])
	_measured.append("panels_data=28 worst_gap=%.6f" % seen["gaps"])
	_q.kit.verdict("panels_data", problems, "2 Bases x 10 Garage panels (4 on the back wall, 3 + 3 on the sides) and 8 field panels (4 + 4) under Garage and FieldWalls, 28 in all, 2 m tall and 1 m (Garage) or 2.5 m (field) deep, 3.5 / 3.3333 / 3.0 m long, flush end to end from the first to the last (worst seam %.6f m), on layer 64 with mask 0, %s (type flag_wall, 40 hit points, looks below 0.8 and 0.35); a Garage panel owned by its Base's Player and listed in its structures (%d each), a field panel owned by nobody (-1) and listed in the Map's list (%d); sharing 3 meshes and 3 shapes; the Garages' floor (12 x 10 m), Marking (%d dashes) and spawn spots (%s) as they were, Base B's walls mirroring Base A's and the west field wall mirroring the east one across x = 0 to %.4f m; Cover holds the %d wrecks and %d containers and nothing else; every run a plain Node3D, every panel the shipped structure.gd with no code of its own; the matrix has no new row; no type's spot test sees the cover layer" % [
		seen["gaps"], STATS_PATH.get_file(), LISTED, LISTED_BY_MAP, DASHES, SPOTS, worst_mirror, WRECKS, CONTAINERS])


## One run's panels (see _panels_data): the run's node, then each panel's data and footprint; `seen` collects the
## shared meshes and shapes, the count, the worst seam and the panels' centres for the mirror check.
func _run_data(base_index: int, run: int, problems: PackedStringArray, seen: Dictionary) -> void:
	var field_run: bool = Kit19.is_field(run)
	var field_node: MapField = _q.harness.split.field
	var base: Base = _k.k.m.w.bases[base_index]
	var parent: Node = field_node if field_run else base
	var root_name: String = "Map" if field_run else base.name
	var holder: Node = parent.get_node_or_null(Kit19.RUN_PATHS[run])
	_q.kit.need(problems, holder != null and holder.get_class() == "Node3D" and holder.get_script() == null and holder.get_child_count() == Kit19.COUNTS[run], "%s/%s is not a plain Node3D with %d panels" % [root_name, Kit19.RUN_PATHS[run], Kit19.COUNTS[run]])
	var listed: Array[Structure] = field_node.neutral_structures if field_run else base.structures
	var fractions: Array[float] = [0.8, 0.35]
	var edge: float = Kit19.STARTS[run]
	var along_x: bool = Kit19.ALONG[run].x != 0.0
	for index: int in Kit19.COUNTS[run]:
		var target: Structure = _k.panel(base_index, run, index)
		var label: String = "%s/%s/Panel%d" % [root_name, Kit19.RUN_PATHS[run], index + 1]
		seen["count"] += 1
		if target == null:
			_q.kit.need(problems, false, label + " is missing")
			continue
		var owner_index: int = -1 if field_run else base_index
		_q.kit.need(problems, listed.has(target) and target.player_index == owner_index and target.is_standing, "%s: listed %s, player_index %d (expected %d), standing %s" % [label, listed.has(target), target.player_index, owner_index, target.is_standing])
		_q.kit.need(problems, target.collision_layer == COVER_LAYER and target.collision_mask == 0, "%s: layer %d mask %d" % [label, target.collision_layer, target.collision_mask])
		_q.kit.need(problems, target.stats != null and target.stats.resource_path == STATS_PATH and target.type_id == &"flag_wall" and is_equal_approx(target.hit_points, Kit19.HIT_POINTS) and target.stats.damaged_below == fractions, "%s: stats %s, type %s, %s hit points" % [label, target.stats.resource_path if target.stats != null else "none", target.type_id, target.hit_points])
		_q.kit.need(problems, target.get_script() != null and target.get_script().resource_path.ends_with("defences/structure.gd") and target.scene_file_path == SCENE_DIR + Kit19.SCENES[run] + ".tscn", "%s: script %s, scene %s" % [label, target.get_script(), target.scene_file_path])
		var box: AABB = _k.extent(base_index, run, target)
		var length: float = box.size.x if along_x else box.size.z
		var across: float = box.size.z if along_x else box.size.x
		var low: float = box.position.x if along_x else box.position.z
		_q.kit.need(problems, absf(length - Kit19.LENGTHS[run]) <= TOLERANCE and absf(across - Kit19.DEPTHS[run]) <= TOLERANCE and absf(box.position.y) <= TOLERANCE and absf(box.end.y - Kit19.HEIGHT) <= TOLERANCE, "%s is %.4f long, %.4f deep and %.4f to %.4f high" % [label, length, across, box.position.y, box.end.y])
		_q.kit.need(problems, absf(low - edge) <= TOLERANCE, "%s starts %.5f along the run, the previous one ended at %.5f" % [label, low, edge])
		seen["gaps"] = maxf(seen["gaps"], absf(low - edge))
		edge = low + length
		var o: Vector3 = Kit19.OUTWARD[run]
		var near: float = minf(absf((box.position * o).x + (box.position * o).z), absf((box.end * o).x + (box.end * o).z))
		var far: float = maxf(absf((box.position * o).x + (box.position * o).z), absf((box.end * o).x + (box.end * o).z))
		_q.kit.need(problems, absf(near - Kit19.INNER_FACES[run]) <= TOLERANCE and absf(far - Kit19.OUTER_FACES[run]) <= TOLERANCE, "%s stands %.4f to %.4f m from the axis, not %.2f to %.2f" % [label, near, far, Kit19.INNER_FACES[run], Kit19.OUTER_FACES[run]])
		var mesh: MeshInstance3D = target.get_node_or_null("Mesh") as MeshInstance3D
		_q.kit.need(problems, mesh != null and absf((mesh.global_transform * mesh.get_aabb()).end.y - Kit19.HEIGHT) <= TOLERANCE and mesh.get_parent() == target, "%s is drawn by a direct Mesh child %s tall" % [label, (mesh.global_transform * mesh.get_aabb()).end.y if mesh != null else -1.0])
		if mesh != null and not seen["meshes"].has(mesh.mesh):
			seen["meshes"].append(mesh.mesh)
		var shape_node: CollisionShape3D = target.get_node("CollisionShape3D") as CollisionShape3D
		if not seen["shapes"].has(shape_node.shape):
			seen["shapes"].append(shape_node.shape)
		var side: Array = seen["field"][run - Kit19.WEST] if field_run else seen["garage"][base_index]
		side.append(shape_node.global_position)
	_q.kit.need(problems, absf(edge - (Kit19.STARTS[run] + Kit19.LENGTHS[run] * Kit19.COUNTS[run])) <= TOLERANCE, "%s/%s ends at %.5f along the run" % [root_name, Kit19.RUN_PATHS[run], edge])
