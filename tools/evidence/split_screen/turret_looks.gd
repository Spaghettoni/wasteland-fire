extends RefCounted
## Scenario turret_looks of the split screen evidence harness (split_screen_harness.gd): the Turret's
## damaged looks and its growth, Story 015 AC-1 to AC-4, AC-7 and AC-8, played with real keys on the
## shipped data and Map 01. This script holds clearances, bad_looks, older_turrets and
## no_engine_noise; the modules it runs, in this order, hold the rest: turret_looks_data.gd
## (looks_data), turret_looks_stages.gd (stages and kept), turret_looks_fight.gd (still_fights),
## turret_looks_growth.gd (growth: the band measured from the mesh files, AC-8), then story 013's
## turrets_clear.gd (exits, turns, inbound and solid, now on the grown Turret) and turrets_aim.gd
## (targets, reach, sight and path: the aim and the sight stay). One Round, played on after each
## check; the stages module ends with a restart. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=turret_looks
## Implements: production/epics/wasteland-fire/story-015-turret-damage-looks.md. Tooling only. Every
## number comes from the game's data; the scenario types only its test inputs and the story's values.

## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## The Story 009 helpers (quick_fix_kit.gd): the type indices.
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
## The Story 013 helpers (turrets_kit.gd).
const Kit13: GDScript = preload("res://tools/evidence/split_screen/turrets_kit.gd")
## The Story 015 helpers (turret_looks_kit.gd) and the modules this scenario runs.
const Looks: GDScript = preload("res://tools/evidence/split_screen/turret_looks_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/turret_looks_data.gd")
const Stages: GDScript = preload("res://tools/evidence/split_screen/turret_looks_stages.gd")
const Fight: GDScript = preload("res://tools/evidence/split_screen/turret_looks_fight.gd")
const Growth: GDScript = preload("res://tools/evidence/split_screen/turret_looks_growth.gd")
## Story 013's modules, run on the grown Turret: the clearances and the solid, the aim and the sight.
const Clear: GDScript = preload("res://tools/evidence/split_screen/turrets_clear.gd")
const Aim: GDScript = preload("res://tools/evidence/split_screen/turrets_aim.gd")
## An older scenario that keeps the Turrets and declares no TURRET_LOOKS: what the strips are run for.
const Older: GDScript = preload("res://tools/evidence/split_screen/turrets.gd")
## The launch scene the strips are run on, the data and the frozen scene they are read against.
const SPLIT_PATH: String = "res://src/gameplay/split_screen/split_screen.tscn"
const STATS_PATH: String = "res://src/gameplay/defences/data/turret_stats.tres"
const FROZEN_PATH: String = "res://tools/evidence/frozen/turret_story_013.tscn"

## This scenario makes every choice itself, with its own keys.
const OWN_CHOICE: bool = true
## It runs with the swap, the camera, the Flag Walls and side spots, the Turrets and the Turret's
## looks the build ships with.
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
## Tokens enough that the destructions, the Swaps and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the runs to the fall, the Swaps, the clearance runs and the aim checks.
const WATCHDOG_SECONDS: float = 3000.0
## The clearances story 013 measured on the 1.8 m drum (AC-4), by type (Motorbike, Buggy, Truck,
## Gyrocopter), and how far a measured one may differ from them.
const STORY_013: Dictionary = {
	"exits": [4.30, 4.10, 3.80, 4.20], "around": [3.07, 2.99, 3.57, 3.38], "across": [0.76, 0.61, 3.72, 4.37],
	"lanes": [4.30, 4.10, 3.80, 4.20], "lines": [2.54, 2.34, 2.04, 2.44]}
const CLEARANCE_TOLERANCE: float = 0.01
## Where a Turret built wrong is put while it is tested: far under Base B, out of reach (Base-local).
const ASIDE: Vector3 = Vector3(0.0, -50.0, -16.0)
## The drum's collider height of the Turret of Story 013, metres.
const FROZEN_COLLIDER: float = 1.8

var _k: Kit13
## The engine errors this script causes on purpose (five Turrets built wrong), for the noise check.
var _expected_errors: int = 0
var _measured: PackedStringArray = []


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_k = Kit13.new(harness)
	await _k.w.s.both_play()
	var data: Object = Data.new(_k)
	await data.run()
	var stages: Object = Stages.new(_k)
	await stages.run()
	var fight: Object = Fight.new(_k)
	await fight.run()
	var growth: Object = Growth.new(_k)
	await growth.run()
	await _clearances()
	var aim: Object = Aim.new(_k)
	await aim.run()
	await _bad_looks()
	_older_turrets()
	for step: Object in [data, stages, fight, growth, aim]:
		_measured.append_array(step.measured)
	var q: Quick = _k.w.s.q
	var errors: Array[String] = q.tokens.engine_log.errors
	var warnings: Array[String] = q.tokens.engine_log.warnings
	var noise: PackedStringArray = []
	q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario, the %d of them that bad_looks causes on purpose (a Turret built with a drum or a steel short or empty, and stats with the fractions out of order) accounted for" % [errors.size(), warnings.size(), _expected_errors])
	_k.close()
	harness.finish("turret_looks=10 %s" % " ".join(_measured))


## clearances (AC-4): story 013's drives on the grown Turret (turrets_clear.gd: its four checks print
## as they did, exits, turns, inbound and solid), and every least gap it measured against the ones
## story 013 measured on the 1.8 m drum, within 0.01 m.
func _clearances() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var clear: Object = Clear.new(_k)
	await clear.run()
	_measured.append_array(clear.measured)
	var seen: Dictionary = {}
	for entry: String in clear.measured:
		var parts: PackedStringArray = entry.split("=")
		var values: Array[float] = []
		for pair: String in parts[1].split("/"):
			values.append(float(pair.get_slice(":", 1)))
		seen[parts[0]] = values
	var worst: float = 0.0
	for key: String in STORY_013:
		var wanted: Array = STORY_013[key]
		var got: Array = seen.get(key, [])
		q.kit.need(problems, got.size() == wanted.size(), "%s: %d gaps measured, story 013 measured %d" % [key, got.size(), wanted.size()])
		for index: int in mini(got.size(), wanted.size()):
			worst = maxf(worst, absf(float(got[index]) - float(wanted[index])))
			q.kit.need(problems, absf(float(got[index]) - float(wanted[index])) <= CLEARANCE_TOLERANCE, "%s[%d]: %.2f m on the grown Turret, %.2f m on the 1.8 m drum" % [key, index, got[index], wanted[index]])
	q.kit.verdict("clearances", problems, "every least gap of exits, turns (near and across), the lanes and the 45-degree lines read the same as story 013's on the 1.8 m drum within %.2f m (largest difference %.3f m): %s" % [CLEARANCE_TOLERANCE, worst, clear.measured])


## bad_looks (AC-7): a Turret whose list of drums or of steels is short or has an empty slot logs one
## error and shows only its whole look, and its dome and barrel their own steel, until it falls; stats
## with the fractions out of order are refused with one error and the piece shows its whole look.
## Each is built from the shipped scene, put far under Base B and freed.
func _bad_looks() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var world: Node = q.harness.split.get_node("World")
	var errors: Array[String] = q.tokens.engine_log.errors
	var start: int = errors.size()
	var made: int = 0
	var cases: Array[String] = ["a list of drums that lost its second", "a list of drums with an empty slot", "a list of steels that lost its second", "a list of steels with an empty slot"]
	for index: int in cases.size():
		var piece: Turret = q.harness.turret_scene.instantiate() as Turret
		var drums: Array[Node3D] = [piece.damaged_looks[0]]
		var steels: Array[Material] = [piece.worn_steel[0]]
		if index == 1:
			drums.append(null)
		if index == 3:
			steels.append(null)
		if index < 2:
			piece.damaged_looks = drums
		else:
			piece.worn_steel = steels
		world.add_child(piece)
		piece.global_position = _k.w.point(1, ASIDE)
		_expected_errors += 1
		made += 1
		piece.apply_damage(piece.hit_points - Looks.JUST_BELOW)
		var hurt: int = Looks.look_shown(piece)
		var dressed: bool = Looks.head_dressed(piece, 0, null) and Looks.head_visible(piece)
		piece.apply_damage(piece.hit_points)
		q.kit.need(problems, errors.size() - start == made and hurt == 0 and dressed and Looks.look_shown(piece) == -1 and not Looks.head_visible(piece), "a Turret with %s: %d errors in all, look %d and dressed %s at %.1f hit points, look %d fallen" % [cases[index], errors.size() - start, hurt, dressed, Looks.JUST_BELOW, Looks.look_shown(piece)])
		world.remove_child(piece)
		piece.free()
	var bad: TurretStats = (load(STATS_PATH) as TurretStats).duplicate() as TurretStats
	var reversed: Array[float] = [Looks.DAMAGED_BELOW[1], Looks.DAMAGED_BELOW[0]]
	bad.damaged_below = reversed
	var refused: Turret = q.harness.turret_scene.instantiate() as Turret
	refused.stats = bad
	world.add_child(refused)
	refused.global_position = _k.w.point(1, ASIDE)
	_expected_errors += 1
	made += 1
	q.kit.need(problems, errors.size() - start == made and refused.type_id == &"" and not refused.is_standing and Looks.look_shown(refused) == 0, "stats with the fractions out of order: %d errors in all, type '%s', standing %s, look %d" % [errors.size() - start, refused.type_id, refused.is_standing, Looks.look_shown(refused)])
	world.remove_child(refused)
	refused.free()
	q.kit.verdict("bad_looks", problems, "a Turret with a list of drums or of steels short or with an empty slot logged one error each and showed only its whole look (dome and barrel in their own steel) until it fell; stats with the fractions out of order were refused with one error and the piece showed its whole look")


## older_turrets (AC-7, R18; the proof of the strips): both strips run on a freshly instanced launch
## scene for an older scenario that keeps the Turrets and declares no TURRET_LOOKS, and what they
## leave is read: each Turret an instance of the frozen scene of story 013 with its collider 1.8 m
## tall, no fraction in the data and no damaged look, listed in its Base's structures with its band
## among the Base's color_meshes and painted in the Base's Team material, no entry left on a freed
## Turret. The shared fractions are put back at once, so the Round under test never sees them empty.
func _older_turrets() -> void:
	var problems: PackedStringArray = []
	var q: Quick = _k.w.s.q
	var stats: TurretStats = load(STATS_PATH) as TurretStats
	var saved: Array[float] = []
	for fraction: float in stats.damaged_below:
		saved.append(fraction)
	var warnings_before: int = q.tokens.engine_log.warnings.size()
	var fresh: SplitScreen = (load(SPLIT_PATH) as PackedScene).instantiate() as SplitScreen
	q.harness._apply_turret_looks_data_off(Older)
	q.harness._apply_turret_looks_off(fresh, Older)
	var emptied: bool = stats.damaged_below.is_empty()
	stats.damaged_below = saved
	var count: int = 0
	for base: Base in [fresh.field.player_1_base, fresh.field.player_2_base]:
		for child: Node in base.get_node("Turrets").get_children():
			var turret: Turret = child as Turret
			count += 1
			var shape: CylinderShape3D = (turret.get_node("CollisionShape3D") as CollisionShape3D).shape as CylinderShape3D
			q.kit.need(problems, turret.scene_file_path == FROZEN_PATH and is_equal_approx(shape.height, FROZEN_COLLIDER) and turret.damaged_looks.is_empty() and turret.worn_steel.is_empty(), "%s of %s is '%s' with a collider %.2f m tall and %d damaged looks, not the frozen Turret" % [turret.name, base.name, turret.scene_file_path, shape.height, turret.damaged_looks.size()])
			q.kit.need(problems, base.structures.has(turret), "%s is not in %s's structures" % [turret.name, base.name])
			var band: MeshInstance3D = turret.get_node("Look/Head/Band") as MeshInstance3D
			var listed: bool = false
			var all_valid: bool = true
			for entry: Variant in base.color_meshes:
				listed = listed or entry == band
				all_valid = all_valid and is_instance_valid(entry)
			q.kit.need(problems, all_valid, "%s has a color_meshes entry on a freed node" % base.name)
			if all_valid:
				base._paint_color_meshes()
			q.kit.need(problems, listed and band.material_override == base.color_material, "%s's band is listed %s and wears %s, not its Base's Team material" % [turret.name, listed, band.material_override])
		for structure: Variant in base.structures:
			q.kit.need(problems, is_instance_valid(structure), "%s has a structures entry on a freed node" % base.name)
	q.kit.need(problems, emptied and count == 4 and q.tokens.engine_log.warnings.size() == warnings_before, "the data strip left %s (emptied %s), %d Turrets replaced, %d warnings" % [stats.damaged_below, emptied, count, q.tokens.engine_log.warnings.size() - warnings_before])
	fresh.free()
	q.kit.verdict("older_turrets", problems, "for an older scenario (%s) the strips left the shared damaged_below empty and the four Turrets of a freshly instanced launch scene instances of the frozen scene (a collider %.1f m tall, no damaged look, no steel), listed in their Base's structures, their bands among its color_meshes and painted with its Team material, no entry on a freed node and no warning" % [Older.resource_path.get_file(), FROZEN_COLLIDER])
