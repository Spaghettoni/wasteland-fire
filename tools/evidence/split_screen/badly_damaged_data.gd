extends RefCounted
## The state is data (Story 017 AC-7): the fraction and the share of each of the four types in its .tres (0.2 and 0.5), and the hit points the
## state begins at come to exactly 8, 20, 44 and 14; UnitStats.first_problem() refuses a fraction outside 0 to under 1 and, while the fraction is
## above 0, a share outside above 0 to 1, a NaN included, and Unit.spawn() leaves a Unit as it is when it is handed such stats; no number is a
## literal in the code that does the work (the smoke script, the Unit's state and speed, the Model's wiring); the smoke's look is read back from its
## scene, a bad one is one named error and shows nothing; the four Blender models carry the scene and the kit models do not; and the links of
## Unit.destroyed are what the Round put there (the Model listens to badly_damaged_changed alone). Run by badly_damaged.gd. Tooling only.
## Implements: production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-7.

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Units: GDScript = preload("res://tools/evidence/split_screen/unit_kit.gd")

## The story's numbers: the hit points the state begins at per type and the starting fraction and share (the data are read against them).
const EDGES: Array[float] = [8.0, 20.0, 44.0, 14.0]
const STARTING_FRACTION: float = 0.2
const STARTING_SHARE: float = 0.5
## The stats files of the four types, in the order of the data, and the kit model scenes the models could be put back to.
const STATS_PATHS: Array[String] = ["motorbike", "buggy", "truck", "gyrocopter"]
const STATS_DIR: String = "res://src/gameplay/units/data/%s_stats.tres"
const KIT_SCENES: String = "res://src/gameplay/units/models/%s_kit_model.tscn"
## The code that does the work, by file and function (an empty list: the whole file).
const LINTED: Dictionary = {
	"res://src/gameplay/effects/badly_damaged_smoke.gd": [],
	"res://src/gameplay/units/unit.gd": ["_is_badly_damaged", "_approach_speed", "apply_damage", "destroy", "leave_play"],
	"res://src/gameplay/units/models/unit_model.gd": ["_connect_smoke", "_on_badly_damaged_changed", "_instance_smoke"],
}
## The numbers the lint lets through.
const ALLOWED: Array[String] = ["0", "1", "0.0", "1.0"]

var measured: PackedStringArray = []
var _k: Kit17
var _q: Quick
var _literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
var _quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")


func _init(kit: Kit17) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	_data_read_back()
	await _bad_data_refused()
	_no_numbers_in_code()
	await _smoke_scene()
	_links()


## data_read_back: the numbers are in each of the four files, and the edge comes to the story's hit points exactly.
func _data_read_back() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for type: int in 4:
		var stats: UnitStats = _q.units.stats(type)
		var text: String = FileAccess.get_file_as_string(STATS_DIR % STATS_PATHS[type])
		_q.kit.need(problems, text.contains("badly_damaged_fraction = %s" % STARTING_FRACTION) and text.contains("badly_damaged_speed_share = %s" % STARTING_SHARE), "%s: the file does not hold both lines" % STATS_PATHS[type])
		_q.kit.need(problems, stats.badly_damaged_fraction == STARTING_FRACTION and stats.badly_damaged_speed_share == STARTING_SHARE and stats.first_problem().is_empty(), "%s: loaded %s and %s (%s)" % [STATS_PATHS[type], stats.badly_damaged_fraction, stats.badly_damaged_speed_share, stats.first_problem()])
		_q.kit.need(problems, stats.max_hit_points * stats.badly_damaged_fraction == EDGES[type], "%s: %s x %s is %s, not %s" % [STATS_PATHS[type], stats.max_hit_points, stats.badly_damaged_fraction, stats.max_hit_points * stats.badly_damaged_fraction, EDGES[type]])
		notes.append("%s %s x %s = %s" % [STATS_PATHS[type], stats.max_hit_points, stats.badly_damaged_fraction, stats.max_hit_points * stats.badly_damaged_fraction])
	_q.kit.verdict("data_read_back", problems, "fraction %s and share %s in each .tres; the edges, exactly in doubles: %s" % [STARTING_FRACTION, STARTING_SHARE, ", ".join(notes)])


## bad_data_refused: first_problem() names the field; a type with no fraction needs no share; Unit.spawn() leaves a Unit alone.
func _bad_data_refused() -> void:
	var problems: PackedStringArray = []
	var refused: Array[Array] = [[-0.1, 0.5, "badly_damaged_fraction"], [1.0, 0.5, "badly_damaged_fraction"], [1.5, 0.5, "badly_damaged_fraction"], [NAN, 0.5, "badly_damaged_fraction"],
		[0.2, 0.0, "badly_damaged_speed_share"], [0.2, -0.5, "badly_damaged_speed_share"], [0.2, 1.5, "badly_damaged_speed_share"], [0.2, NAN, "badly_damaged_speed_share"]]
	var accepted: Array[Array] = [[0.0, 0.0], [0.0, NAN], [0.2, 1.0], [0.99, 0.01]]
	var base: UnitStats = _q.units.stats(Quick.BUGGY)
	for case: Array in refused:
		var copy: UnitStats = base.duplicate() as UnitStats
		copy.badly_damaged_fraction = case[0]
		copy.badly_damaged_speed_share = case[1]
		_q.kit.need(problems, copy.first_problem().contains(case[2]), "fraction %s share %s: '%s' does not name %s" % [case[0], case[1], copy.first_problem(), case[2]])
	for case: Array in accepted:
		var copy: UnitStats = base.duplicate() as UnitStats
		copy.badly_damaged_fraction = case[0]
		copy.badly_damaged_speed_share = case[1]
		_q.kit.need(problems, copy.first_problem().is_empty(), "fraction %s share %s refused: '%s'" % [case[0], case[1], copy.first_problem()])
	await _k.e.fresh()
	var unit: Unit = _k.unit(1)
	var bad: UnitStats = base.duplicate() as UnitStats
	bad.badly_damaged_speed_share = 0.0
	var before: Array = [unit.stats, unit.global_transform, unit.hit_points, unit.is_alive]
	_k.e.expected_errors.append("badly_damaged_speed_share")
	unit.spawn(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 50.0)), bad)
	_q.kit.need(problems, [unit.stats, unit.global_transform, unit.hit_points, unit.is_alive] == before, "spawn() with unusable stats changed the Unit")
	_q.kit.verdict("bad_data_refused", problems, "%d broken copies of the Buggy's stats are named by first_problem(), %d usable ones (no fraction with a NaN share, a share of 1, a fraction of 0.99) are not, and spawn() with a share of 0 pushed one error and left the Unit as it was" % [refused.size(), accepted.size()])


## no_numbers_in_code: the lint over the code that does the work.
func _no_numbers_in_code() -> void:
	var problems: PackedStringArray = []
	var counted: int = 0
	for path: String in LINTED:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		var wanted: Array = LINTED[path]
		var inside: bool = wanted.is_empty()
		for index: int in lines.size():
			var line: String = lines[index]
			if not wanted.is_empty() and line.begins_with("func "):
				inside = wanted.has(line.trim_prefix("func ").get_slice("(", 0))
			if not inside:
				continue
			var code: String = _quoted.sub(line, "", true).get_slice("#", 0)
			if code.strip_edges().is_empty() or code.strip_edges().begins_with("@export"):
				continue
			counted += 1
			for hit: RegExMatch in _literal.search_all(code):
				_q.kit.need(problems, ALLOWED.has(hit.get_string()), "%s:%d holds the number %s" % [path.get_file(), index + 1, hit.get_string()])
	_q.kit.verdict("no_numbers_in_code", problems, "the %d code lines of the smoke script and of the state, speed and wiring functions hold no number but 0 and 1 (and 0.0, 1.0)" % counted)


## smoke_look_is_the_scene's: the four Blender models carry the scene and the kit models do not; the scene's numbers are read back; a bad one is
## one named error and shows nothing.
func _smoke_scene() -> void:
	var problems: PackedStringArray = []
	var scene: PackedScene
	for type: int in 4:
		var model: UnitModel = _q.units.stats(type).model.instantiate() as UnitModel
		var kit: UnitModel = (load(KIT_SCENES % STATS_PATHS[type]) as PackedScene).instantiate() as UnitModel
		_q.kit.need(problems, model.smoke_scene != null and (scene == null or model.smoke_scene == scene) and kit.smoke_scene == null, "%s: the mesh model's smoke_scene is %s, the kit model's %s" % [STATS_PATHS[type], model.smoke_scene, kit.smoke_scene])
		scene = model.smoke_scene
		model.free()
		kit.free()
	var smoke: BadlyDamagedSmoke = scene.instantiate() as BadlyDamagedSmoke
	var material: StandardMaterial3D = smoke.puff_template.material_override as StandardMaterial3D
	_q.kit.need(problems, smoke.puffs_per_second > 0.0 and smoke.puff_lifetime_seconds > 0.0 and smoke.rise_speed > 0.0 and smoke.puff_radius > 0.0 and smoke.puff_growth > 0.0 and smoke.fade_start_fraction >= 0.0 and material.albedo_color.a > 0.0, "a number of the scene is not set")
	_q.kit.need(problems, smoke.puff_template.top_level and smoke.puff_template.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and not smoke.puff_template.visible, "the Puff template is not top_level, shadowless and hidden")
	var look: String = "%s a second, %s s, rises %s m/s, radius %s m x %s, fades from %s of its life, colour %s" % [smoke.puffs_per_second, smoke.puff_lifetime_seconds, smoke.rise_speed, smoke.puff_radius, smoke.puff_growth, smoke.fade_start_fraction, material.albedo_color]
	smoke.free()
	var broken: BadlyDamagedSmoke = scene.instantiate() as BadlyDamagedSmoke
	broken.puffs_per_second = 0.0
	_k.e.expected_errors.append("puffs_per_second")
	_k.unit(0).add_child(broken)
	broken.start()
	_q.kit.need(problems, not broken.is_smoking() and broken.puffs().is_empty(), "a smoke with no amount smokes")
	_k.unit(0).remove_child(broken)
	broken.free()
	await _q.kit.advance(1)
	_q.kit.verdict("smoke_look_is_the_scenes", problems, "the four mesh models carry badly_damaged_smoke.tscn and the four kit models do not; its look: %s; with no amount it pushed one error and showed nothing" % look)


## destroyed_links_unchanged: nothing of this story listens to Unit.destroyed, and each Unit's Model is its one listener to the state.
func _links() -> void:
	var problems: PackedStringArray = []
	var notes: PackedStringArray = []
	for player: int in Kit17.Kit.PLAYERS:
		var unit: Unit = _k.unit(player)
		var on_destroyed: int = 0
		for link: Dictionary in unit.destroyed.get_connections():
			var target: Object = (link["callable"] as Callable).get_object()
			on_destroyed += 1
			_q.kit.need(problems, not (target is UnitModel) and not (target is BadlyDamagedSmoke), "Player %d: %s listens to destroyed" % [player + 1, target])
		var models: int = 0
		for link: Dictionary in unit.badly_damaged_changed.get_connections():
			var target: Object = (link["callable"] as Callable).get_object()
			if target is UnitModel:
				models += 1
				_q.kit.need(problems, (target as Node).get_parent() == unit and target == unit.get_node(String(Unit.MODEL_NODE_NAME)), "Player %d: a model that is not the current one listens" % (player + 1))
		_q.kit.need(problems, models == 1, "Player %d: %d models listen to the state" % [player + 1, models])
		notes.append("Player %d: %d links on destroyed (the Round's), %d model on the state" % [player + 1, on_destroyed, models])
	_q.kit.verdict("destroyed_links_unchanged", problems, " | ".join(notes))
