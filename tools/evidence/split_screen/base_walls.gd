extends RefCounted
## Scenario base_walls of the split screen evidence harness (split_screen_harness.gd): the Base walls of Story
## 018 AC-1 to AC-7 and AC-9, which are Wall Panels, played with real keys on the shipped data and Map 01. This
## script holds panels_data (what the scenes and data say: 60 panels where AC-1 puts them, flush, the towers,
## the Gate, the zone and the lists unchanged, no code of their own) and no_engine_noise; the modules it runs,
## in this order, hold the rest: base_walls_moves.gd (spawn_exits and stops: AC-1, AC-2), base_walls_over.gd
## (gyro_over: AC-2), base_walls_damage.gd (damage, turret_shots and looks: AC-3), base_walls_breach.gd
## (layer_timing and breach: AC-4), base_walls_gate.gd (breach_swap, breach_delivery and breach_lock: AC-4, R11),
## base_walls_sight.gd (turret_sight: AC-5), base_walls_mines.gd (mines_at_the_walls: AC-6) and
## base_walls_round.gd (stays_down and restore: AC-7). One Round, played on after each check; a module that
## wins a Round presses R before it ends, and modules_leave_a_fresh_round fails if one ends otherwise. Tooling
## only. Implements:
## production/epics/wasteland-fire/story-018-base-wall-panels.md AC-1 to AC-7 and AC-9. Every number comes from
## the game's data; the scenario types only its test inputs and the story's values. Run: godot --headless
## --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=base_walls

const Kit18: GDScript = preload("res://tools/evidence/split_screen/base_walls_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Moves: GDScript = preload("res://tools/evidence/split_screen/base_walls_moves.gd")
const Over: GDScript = preload("res://tools/evidence/split_screen/base_walls_over.gd")
const Damage: GDScript = preload("res://tools/evidence/split_screen/base_walls_damage.gd")
const Breach: GDScript = preload("res://tools/evidence/split_screen/base_walls_breach.gd")
const Gate: GDScript = preload("res://tools/evidence/split_screen/base_walls_gate.gd")
const Sight: GDScript = preload("res://tools/evidence/split_screen/base_walls_sight.gd")
const Mines: GDScript = preload("res://tools/evidence/split_screen/base_walls_mines.gd")
const Round: GDScript = preload("res://tools/evidence/split_screen/base_walls_round.gd")
## The data this story reads: the Flag Walls' stats, which every panel shares (R10).
const STATS_PATH: String = "res://src/gameplay/defences/data/flag_wall_stats.tres"
## The scene of each run's panels, in the order of the kit's runs.
const SCENES: Array[String] = ["wall_panel_back", "wall_panel_side", "wall_panel_side", "wall_panel_gate", "wall_panel_gate"]
const SCENE_DIR: String = "res://src/gameplay/defences/"

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Wall Panels, the
## Turrets with their looks, the Mines, the Flag Walls and their side spots, the explosions, the badly damaged
## state, the swap and the view from above.
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
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the drives, the Shots, the Rounds.
const WATCHDOG_SECONDS: float = 3000.0
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.001
## The physics layers: the Map's, and the cover the panels stand on.
const MAP_LAYER: int = 1
const COVER_LAYER: int = 64
## The corner tower's size, its centre height and its places in a Base's frame (AC-1: they stay as they are),
## and the zone's size.
const TOWER_SIZE: Vector3 = Vector3(4.3, 6.0, 4.3)
const TOWER_PLACES: Dictionary = {"TowerGateLeft": Vector3(-16, 3, -15), "TowerGateRight": Vector3(16, 3, -15),
	"TowerBackLeft": Vector3(-16, 3, 15), "TowerBackRight": Vector3(16, 3, 15)}
const ZONE_SIZE: Vector3 = Vector3(29.4, 4.0, 27.5)
## The Gate's half width: the Gate walls' inner ends stand at |x| 5.5 (an 11 m opening).
const GATE_HALF: float = 5.5
## The structures a Base lists: 4 Flag Walls, 2 Turrets and its 30 panels (AC-9).
const LISTED: int = 36

var _k: Kit18
var _q: Object
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. WALLS_ONLY (an
## environment variable of a run by hand) names modules, "moves,over", to run on their own.
func run(harness: Node) -> void:
	_k = Kit18.new(harness)
	_q = _k.m.w.s.q
	await _k.m.w.s.both_play()
	_panels_data()
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("WALLS_ONLY")
	for module: GDScript in [Moves, Over, Damage, Breach, Gate, Sight, Mines, Round]:
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("base_walls_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.m.clear_mines()
		var controller: MatchController = _k.m.w.s.controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.m.w.carrying(0) and not _k.m.w.carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.m.w.carrying(0), _k.m.w.carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("base_walls_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: panels hit, hurt, felled, driven through, flown over, restored, with Mines laid in their breaches; the panels built wrong on purpose account for %d" % [errors.size(), warnings.size(), _expected_errors])
	_k.close()
	harness.finish("panels=60 falls=%d %s" % [_k.falls.size(), " ".join(_measured)])


## panels_data (AC-1, AC-3, AC-9): 30 panels a Base in the five runs under Walls, each the size the story gives
## its run, flush with its neighbours and in the old walls' footprint, on layer 64 with mask 0, with the Flag
## Walls' stats, owned by their Base's Player and listed in its structures; the towers, the Gate, the zone and
## the Garage as they were; every run a plain node with no script, every panel the shipped Structure script.
func _panels_data() -> void:
	var problems: PackedStringArray = []
	var rules: MatchRules = _q.controller.rules
	var gaps: float = 0.0
	var meshes: Array = []
	var shapes: Array = []
	var count: int = 0
	var fractions: Array[float] = [0.8, 0.35]
	var centres: Array = [[], []]
	for base_index: int in Kit18.Kit.PLAYERS:
		var base: Base = _k.m.w.bases[base_index]
		var walls: Node = base.get_node("Walls")
		var names: PackedStringArray = []
		for child: Node in walls.get_children():
			names.append(String(child.name))
		var order: PackedStringArray = PackedStringArray(Kit18.RUN_NAMES + ["TowerGateLeft", "TowerGateRight", "TowerBackLeft", "TowerBackRight"])
		_q.kit.need(problems, names == order, "%s: Walls holds %s, not %s" % [base.name, names, order])
		_q.kit.need(problems, base.structures.size() == LISTED, "%s lists %d Structures, not %d" % [base.name, base.structures.size(), LISTED])
		for run: int in Kit18.RUN_NAMES.size():
			var holder: Node = walls.get_node_or_null(Kit18.RUN_NAMES[run])
			_q.kit.need(problems, holder != null and holder.get_class() == "Node3D" and holder.get_script() == null and holder.get_child_count() == Kit18.COUNTS[run], "%s/%s is not a plain Node3D with %d panels" % [base.name, Kit18.RUN_NAMES[run], Kit18.COUNTS[run]])
			var edge: float = Kit18.STARTS[run]
			for index: int in Kit18.COUNTS[run]:
				var panel: Structure = _k.panel(base_index, run, index)
				count += 1
				var label: String = "%s/%s/Panel%d" % [base.name, Kit18.RUN_NAMES[run], index + 1]
				if panel == null:
					_q.kit.need(problems, false, label + " is missing")
					continue
				_q.kit.need(problems, base.structures.has(panel) and panel.player_index == base_index and panel.is_standing, "%s: listed %s, player_index %d, standing %s" % [label, base.structures.has(panel), panel.player_index, panel.is_standing])
				_q.kit.need(problems, panel.collision_layer == COVER_LAYER and panel.collision_mask == 0, "%s: layer %d mask %d" % [label, panel.collision_layer, panel.collision_mask])
				_q.kit.need(problems, panel.stats != null and panel.stats.resource_path == STATS_PATH and panel.type_id == &"flag_wall" and is_equal_approx(panel.hit_points, Kit18.HIT_POINTS)
						and panel.stats.damaged_below == fractions, "%s: stats %s, type %s, %s hit points" % [label, panel.stats.resource_path if panel.stats != null else "none", panel.type_id, panel.hit_points])
				_q.kit.need(problems, panel.get_script() != null and panel.get_script().resource_path.ends_with("defences/structure.gd") and panel.scene_file_path == SCENE_DIR + SCENES[run] + ".tscn", "%s: script %s, scene %s" % [label, panel.get_script(), panel.scene_file_path])
				var box: AABB = _k.extent(base_index, panel)
				var length: float = box.size.x if Kit18.ALONG[run].x != 0.0 else box.size.z
				var across: float = box.size.z if Kit18.ALONG[run].x != 0.0 else box.size.x
				var low: float = box.position.x if Kit18.ALONG[run].x != 0.0 else box.position.z
				_q.kit.need(problems, absf(length - Kit18.LENGTHS[run]) <= TOLERANCE and absf(across - Kit18.DEPTH) <= TOLERANCE and absf(box.position.y) <= TOLERANCE and absf(box.end.y - Kit18.HEIGHT) <= TOLERANCE, "%s is %.4f long, %.4f deep and %.4f to %.4f high" % [label, length, across, box.position.y, box.end.y])
				_q.kit.need(problems, absf(low - edge) <= TOLERANCE, "%s starts %.5f along the run, the previous one ended at %.5f" % [label, low, edge])
				gaps = maxf(gaps, absf(low - edge))
				edge = low + length
				var o: Vector3 = Kit18.OUTWARD[run]
				var near: float = minf(absf((box.position * o).x + (box.position * o).z), absf((box.end * o).x + (box.end * o).z))
				var far: float = maxf(absf((box.position * o).x + (box.position * o).z), absf((box.end * o).x + (box.end * o).z))
				_q.kit.need(problems, absf(near - Kit18.INNER_FACES[run]) <= TOLERANCE and absf(far - Kit18.OUTER_FACES[run]) <= TOLERANCE, "%s stands %.4f to %.4f m from the axis, not %.1f to %.1f" % [label, near, far, Kit18.INNER_FACES[run], Kit18.OUTER_FACES[run]])
				var mesh: MeshInstance3D = panel.get_node_or_null("Mesh") as MeshInstance3D
				_q.kit.need(problems, mesh != null and absf((mesh.global_transform * mesh.get_aabb()).end.y - Kit18.HEIGHT) <= TOLERANCE and mesh.get_parent() == panel, "%s is drawn by a direct Mesh child %s tall" % [label, (mesh.global_transform * mesh.get_aabb()).end.y if mesh != null else -1.0])
				if mesh != null and not meshes.has(mesh.mesh):
					meshes.append(mesh.mesh)
				var shape: Shape3D = (panel.get_node("CollisionShape3D") as CollisionShape3D).shape
				if not shapes.has(shape):
					shapes.append(shape)
				centres[base_index].append((panel.get_node("CollisionShape3D") as CollisionShape3D).global_position)
			_q.kit.need(problems, absf(edge - (Kit18.STARTS[run] + Kit18.LENGTHS[run] * Kit18.COUNTS[run])) <= TOLERANCE, "%s/%s ends at %.5f along the run" % [base.name, Kit18.RUN_NAMES[run], edge])
		for tower_name: String in TOWER_PLACES:
			var tower: StaticBody3D = walls.get_node_or_null(tower_name) as StaticBody3D
			var shape: CollisionShape3D = tower.get_node("CollisionShape3D") as CollisionShape3D if tower != null else null
			_q.kit.need(problems, tower != null and tower.collision_layer == MAP_LAYER and (shape.shape as BoxShape3D).size == TOWER_SIZE and tower.position.is_equal_approx(TOWER_PLACES[tower_name]), "%s/%s changed" % [base.name, tower_name])
		var zone_box: BoxShape3D = (base.zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		_q.kit.need(problems, zone_box.size == ZONE_SIZE and (base.zone.collision_mask & COVER_LAYER) == 0 and (base.flag.pickup_zone.collision_mask & COVER_LAYER) == 0, "%s: the zone is %s (mask %d) or the Flag's touch (mask %d) watches the panels' layer" % [base.name, zone_box.size, base.zone.collision_mask, base.flag.pickup_zone.collision_mask])
		var gate_inner: float = INF
		for run: int in [Kit18.GATE_LEFT, Kit18.GATE_RIGHT]:
			for index: int in Kit18.COUNTS[run]:
				var box: AABB = _k.extent(base_index, _k.panel(base_index, run, index))
				gate_inner = minf(gate_inner, minf(absf(box.position.x), absf(box.end.x)))
		_q.kit.need(problems, absf(gate_inner - GATE_HALF) <= TOLERANCE, "%s: the Gate walls' inner ends stand at |x| %.4f, not %.1f" % [base.name, gate_inner, GATE_HALF])
		_q.kit.need(problems, base.first_spawn_problem().is_empty(), "%s: spawn problem '%s'" % [base.name, base.first_spawn_problem()])
		for garage_name: String in ["GarageBack", "GarageSideLeft", "GarageSideRight"]:
			var garage: StaticBody3D = base.get_node_or_null("Garage/" + garage_name) as StaticBody3D
			_q.kit.need(problems, garage != null and garage.collision_layer == MAP_LAYER and (garage.get_script() == null), "%s/Garage/%s changed (story 019's)" % [base.name, garage_name])
	_q.kit.need(problems, count == 60 and meshes.size() == 3 and shapes.size() == 3, "%d panels with %d meshes and %d shapes: the panels of a length share theirs" % [count, meshes.size(), shapes.size()])
	var worst_mirror: float = 0.0
	for centre: Vector3 in centres[0]:
		var nearest: float = INF
		for other: Vector3 in centres[1]:
			nearest = minf(nearest, Quick.mirrored(centre).distance_to(other))
		worst_mirror = maxf(worst_mirror, nearest)
	_q.kit.need(problems, worst_mirror <= TOLERANCE * 10.0, "a panel of Base A has no mirror image among Base B's: the worst is %.4f m off" % worst_mirror)
	var matrix: DamageMatrix = rules.damage_matrix
	var listed: Array = matrix.multipliers.keys().filter(func(key: StringName) -> bool: return String(key).ends_with(">flag_wall"))
	_q.kit.need(problems, listed == [&"motorbike>flag_wall"] and matrix.multipliers[&"motorbike>flag_wall"] == 0.0 and matrix.default_multiplier == 1.0, "matrix rows against a Flag Wall: %s, default %s" % [listed, matrix.default_multiplier])
	for stats: UnitStats in rules.unit_types:
		_q.kit.need(problems, (stats.spot_mask & COVER_LAYER) == 0, "%s's spot test (mask %d) counts the panels' layer" % [stats.type_id, stats.spot_mask])
	_measured.append("panels_data=60 worst_gap=%.6f" % gaps)
	_q.kit.verdict("panels_data", problems, "2 Bases x 30 panels (8 back, 8 + 8 side, 3 + 3 Gate wall) under Walls, each 2 m tall and 1.3 m deep, %s long, flush end to end from tower to tower and to the Gate posts (worst seam %.6f m), on layer 64 with mask 0, %s (type flag_wall, 40 hit points, looks below 0.8 and 0.35), owned by their Base's Player and listed in structures (%d each), sharing 3 meshes and 3 shapes, Base B's mirroring Base A's across x = 0 to %.4f m; the four corner towers (4.3 x 6 x 4.3 m on the map layer), the 11 m Gate, the zone (29.4 x 4 x 27.5 m), the Garage's walls and the spawn spots as they were; every run a plain Node3D, every panel the shipped structure.gd with no code of its own; the matrix has no new row" % [
		"3.4625 / 3.2125 / 2.7833 m", gaps, STATS_PATH.get_file(), LISTED, worst_mirror])
