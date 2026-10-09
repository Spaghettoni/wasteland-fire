extends RefCounted
## Scenario turrets of the split screen evidence harness (split_screen_harness.gd): the Turrets of
## Story 013 AC-1 to AC-9, played with real keys on the shipped data and Map 01. This script holds
## turrets_data (what the scenes and data say) and no_engine_noise; the modules it runs, in this
## order, hold the rest: turrets_clear.gd (exits, turns, inbound and solid: AC-1), turrets_aim.gd
## (targets, reach and sight: AC-2), turrets_lead.gd (shot_timing, barrel and lead: AC-3),
## turrets_fall.gd (damage, friendly and fall: AC-4), turrets_rule.gd (lock and line: AC-5) and
## turrets_kills.gd (carrier, loss and double: AC-5 to AC-7, the restart among them). One Round,
## played on after each check; the last module leaves a new Round running.
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-1 to AC-9. Tooling only.
## Every number comes from the game's data; the scenario types only its test inputs and the story's
## values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=turrets

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 012 helpers (flag_walls_kit.gd): the Flag Walls' names and sizes.
const Walls: GDScript = preload("res://tools/evidence/split_screen/flag_walls_kit.gd")
## The Map's scenario that lists the scripts a node of Map 01 may carry (SCRIPTS).
const MapLayout: GDScript = preload("res://tools/evidence/split_screen/map_layout.gd")
## The barrel and the lead (turrets_lead.gd).
const Lead: GDScript = preload("res://tools/evidence/split_screen/turrets_lead.gd")
## Targets, reach and sight (turrets_aim.gd).
const Aim: GDScript = preload("res://tools/evidence/split_screen/turrets_aim.gd")
## The clearances and the solid (turrets_clear.gd).
const Clear: GDScript = preload("res://tools/evidence/split_screen/turrets_clear.gd")
## The damage and the fall (turrets_fall.gd).
const Fall: GDScript = preload("res://tools/evidence/split_screen/turrets_fall.gd")
## The hard rule and its line (turrets_rule.gd).
const Rule: GDScript = preload("res://tools/evidence/split_screen/turrets_rule.gd")
## The kills, the loss and the restart (turrets_kills.gd).
const Kills: GDScript = preload("res://tools/evidence/split_screen/turrets_kills.gd")
## A Unit scene a Turret can be armed with and the Unit freed under it (the refusals check).
const STRAY_UNIT: String = "res://src/gameplay/units/motorbike.tscn"
## The data this story adds, by path.
const STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap, the camera, the Flag Walls and side spots and the Turrets the build ships
## with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds: the clearance runs, the fights and the restarts.
const WATCHDOG_SECONDS: float = 2400.0
## The story's numbers, the test inputs of turrets_data: a Turret has 100 hit points, turns 90
## degrees a second and its Shot leaves 1.6 m from its centre.
const HIT_POINTS: float = 100.0
const TURN_DEGREES: float = 90.0
const MUZZLE_FORWARD: float = 1.6
const AIM_TOLERANCE: float = 0.25
## A Turret's drum is about this tall, metres (AC-1).
const DRUM_HEIGHT: float = 1.8
const SIGHT_EXTRA: int = 32
## The tolerance a measured place may differ from the data's by, metres.
const TOLERANCE: float = 0.01
## The notice's text, as the story decided it.
const NOTICE_TEXT: String = "Destroy the turrets first"

var _k: Kit13
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0
var _measured: PackedStringArray = []


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	await _k.w.s.both_play()
	_turrets_data()
	await _refusals()
	for module: GDScript in [Clear, Aim, Lead, Fall, Rule, Kills]:
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
	var noise: PackedStringArray = []
	var errors: Array[String] = _k.w.s.q.tokens.engine_log.errors
	var warnings: Array[String] = _k.w.s.q.tokens.engine_log.warnings
	_k.w.s.q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_k.w.s.q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario, the %d of them that refusals() causes on purpose (a Turret armed with rules that have no damage matrix) accounted for: the Turrets armed, destroyed, restored, hidden behind rock, fixtured in an arena and fired through" % [errors.size(), warnings.size(), _expected_errors])
	_k.close()
	harness.finish("turrets=4 %s" % " ".join(_measured))


## refusals (the engine review's two findings): a Turret handed rules that have no damage matrix says
## so once, with one engine error, and never aims or fires; one whose target was freed under it
## logs nothing and stays idle. Both Turrets are built here, at the arena, and freed again.
func _refusals() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var errors: Array[String] = q.tokens.engine_log.errors
	var world: Node = q.units.units[0].get_parent()
	var scene: PackedScene = load(Kit13.SCENE_PATH) as PackedScene
	var bare: MatchRules = q.controller.rules.duplicate() as MatchRules
	bare.damage_matrix = null
	var first: Turret = scene.instantiate() as Turret
	world.add_child(first)
	first.global_position = Kit13.ARENA_CENTRE
	var before: int = errors.size()
	first.arm(q.units.units[1], world, bare)
	var logged: int = errors.size() - before
	_expected_errors += logged
	await q.kit.advance(Kit13.SETTLE)
	q.kit.need(problems, logged == 1 and not first.is_physics_processing() and first.state == Turret.State.IDLE and first.aim_point == Vector3.INF, "arm() with rules that have no damage matrix logged %d errors and the Turret processes physics %s" % [logged, first.is_physics_processing()])
	world.remove_child(first)
	first.free()
	var stray: Unit = (load(STRAY_UNIT) as PackedScene).instantiate() as Unit
	var second: Turret = scene.instantiate() as Turret
	world.add_child(second)
	second.global_position = Kit13.ARENA_CENTRE
	second.arm(stray, world, q.controller.rules)
	stray.free()
	before = errors.size()
	await q.kit.advance(Kit13.SETTLE)
	q.kit.need(problems, errors.size() == before and second.is_physics_processing() and second.state == Turret.State.IDLE, "a Turret whose target was freed logged %d errors and is in state %s" % [errors.size() - before, Turret.State.keys()[second.state]])
	world.remove_child(second)
	second.free()
	q.kit.verdict("refusals", problems, "rules without a damage matrix: one engine error naming the Turret, no physics processing, idle; a target freed under an armed Turret: no error, idle")


## turrets_data (AC-1, AC-9): two Turrets per Base under Turrets and in structures, where the story
## puts them, mirror images, on the map layer with mask 0, their stats from the one .tres with the
## Buggy's weapon and the story's numbers, their Team-colour part wearing the Base's material, the
## Map's scripts, the matrix without a Turret row, and the notice Labels.
func _turrets_data() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var rules: MatchRules = _k.w.s.controller.rules
	var buggy: UnitStats = q.units.stats(Quick.BUGGY)
	var places: Array[String] = []
	for base_index: int in Kit13.NAMES.size():
		var base: Base = _k.w.bases[base_index]
		var group: Node = base.get_node_or_null("Turrets")
		q.kit.need(problems, group != null, "%s has no Turrets node" % base.name)
		for side: int in Kit13.NAMES.size():
			var who: Turret = _k.turret(base_index, side)
			if who == null:
				q.kit.need(problems, false, "%s/%s is missing" % [base.name, Kit13.NAMES[side]])
				continue
			q.kit.need(problems, base.structures.has(who) and who.get_parent() == group, "%s is not listed under Turrets" % who.name)
			q.kit.need(problems, who.collision_layer == 1 and who.collision_mask == 0, "%s: layer %d mask %d" % [who.name, who.collision_layer, who.collision_mask])
			q.kit.need(problems, who.player_index == base_index, "%s: player_index %d, not %d" % [who.name, who.player_index, base_index])
			var want: Vector3 = _k.place_of(base_index, side)
			q.kit.need(problems, who.global_position.distance_to(want) <= TOLERANCE, "%s stands at %s, expected %s" % [who.name, who.global_position, want])
			places.append("(%.0f, %.0f)" % [who.global_position.x, who.global_position.z])
			var drum: CollisionShape3D = who.get_node("CollisionShape3D") as CollisionShape3D
			var cylinder: CylinderShape3D = drum.shape as CylinderShape3D
			q.kit.need(problems, cylinder != null and is_equal_approx(cylinder.radius, Kit13.RADIUS) and cylinder.height >= DRUM_HEIGHT - TOLERANCE, "%s: drum %s" % [who.name, cylinder])
			var data: TurretStats = who.stats as TurretStats
			q.kit.need(problems, data != null and data.resource_path == STATS_PATH and who.type_id == &"turret", "%s: stats %s, type %s" % [who.name, who.stats, who.type_id])
			q.kit.need(problems, who.is_standing and is_equal_approx(who.hit_points, HIT_POINTS) and who.locks_flag and who.state == Turret.State.IDLE, "%s: standing %s, %.0f hit points, locks %s, state %s" % [who.name, who.is_standing, who.hit_points, who.locks_flag, who.state])
			if data != null:
				q.kit.need(problems, is_equal_approx(data.max_hit_points, HIT_POINTS) and is_equal_approx(data.damage, buggy.damage) and is_equal_approx(data.weapon_range, buggy.weapon_range) and is_equal_approx(data.shot_speed, buggy.shot_speed) and is_equal_approx(data.fire_interval_seconds, 2.0 * buggy.fire_interval_seconds), "%s's weapon is not the Buggy's with the interval doubled: %s" % [who.name, [data.damage, data.weapon_range, data.shot_speed, data.fire_interval_seconds]])
				q.kit.need(problems, is_equal_approx(data.turn_rate, deg_to_rad(TURN_DEGREES)) and is_equal_approx(data.muzzle_forward, MUZZLE_FORWARD) and is_equal_approx(data.aim_tolerance, AIM_TOLERANCE) and data.sight_extra_mask == SIGHT_EXTRA, "%s: turn %.4f, muzzle %.2f, tolerance %.2f, sight %d" % [who.name, data.turn_rate, data.muzzle_forward, data.aim_tolerance, data.sight_extra_mask])
			var band: MeshInstance3D = who.get_node("Look/Head/Band") as MeshInstance3D
			q.kit.need(problems, base.color_meshes.has(band) and band.material_override == base.color_material, "%s's band is not painted with the Base's Team material" % who.name)
			q.kit.need(problems, who.process_physics_priority == q.units.units[0].process_physics_priority + Turret.PRIORITY_OFFSET, "%s runs at priority %d" % [who.name, who.process_physics_priority])
	var mirror: String = q.map.mirror(problems, 0.1)
	var allowed: Array = MapLayout.get_script_constant_map().get("SCRIPTS", [])
	for node: Node in q.map.map.find_children("*", "", true, false):
		var script: Script = node.get_script() as Script
		q.kit.need(problems, script == null or allowed.has(script.resource_path), "%s carries %s, which map_layout does not allow" % [node.get_path(), script.resource_path if script != null else ""])
	var listed: Array = rules.damage_matrix.multipliers.keys().filter(func(key: StringName) -> bool: return String(key).contains("turret"))
	q.kit.need(problems, listed.is_empty() and rules.damage_matrix.default_multiplier == 1.0, "matrix rows with a Turret: %s, default %s" % [listed, rules.damage_matrix.default_multiplier])
	var notices: PackedStringArray = []
	for player: int in Kit.PLAYERS:
		var found: Array[Node] = q.units.cameras[player].get_viewport().find_children("*", "PlayerNotice", false, false)
		q.kit.need(problems, found.size() == 1 and (found[0] as PlayerNotice).player_index == player and not (found[0] as PlayerNotice).visible and (found[0] as PlayerNotice).text == NOTICE_TEXT, "view %d holds %d notices" % [player, found.size()])
		notices.append("%s" % [(found[0] as PlayerNotice).message if not found.is_empty() else "none"])
	q.kit.verdict("turrets_data", problems, "4 Turrets at %s, mirrored (%s), on layer 1 with mask 0, %s, the Buggy's weapon with the interval doubled, 100 hit points, a drum of radius %.1f, the Team-colour band painted by each Base, no Turret row in the matrix, the Map's scripts within map_layout's list, one notice per view (%s)" % [
		", ".join(places), mirror, STATS_PATH.get_file(), Kit13.RADIUS, ", ".join(notices)])
