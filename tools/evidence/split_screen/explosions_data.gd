extends RefCounted
## What the data, the scenes and the scripts say (Story 016 AC-9, AC-1's hook): shipped_scene (split_screen.tscn sets the
## explosion scene, and SplitScreen listens to the Round for it once, never to Unit.destroyed), settings_data (the
## ExplosionSettings .tres read back, each number the story's or the build's), bad_settings_refused (first_problem() names
## a forgotten or broken line, an Explosion with bad settings plays nothing and frees itself with one error, a blast of no
## size likewise), explosions_lint (no number but 0, 1, 0.0, 1.0 and 2.0 in the Explosion's code and nothing random in the
## effects folder or in the hook) and no_team_colour_in_code. Run by explosions.gd. Tooling only. Implements:
## production/epics/wasteland-fire/story-016-unit-explosions.md AC-9 and AC-5's neutral colours.

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const SETTINGS_PATH: String = "res://src/gameplay/effects/data/explosion_settings.tres"
const SPLIT_SCENE: String = "res://src/gameplay/split_screen/split_screen.tscn"
const MINE_SCENE: String = "res://src/gameplay/mines/mine.tscn"
const SOURCE_FILES: Array[String] = ["res://src/gameplay/effects/explosion.gd"]
const EFFECT_FILES: Array[String] = ["res://src/gameplay/effects/explosion.gd", "res://src/gameplay/effects/explosion_settings.gd", "res://src/gameplay/split_screen/split_screen.gd"]
## The story's values (and where the build moved them): the test inputs of settings_data.
const LIFETIME: float = 2.0
const FLASH_SECONDS: float = 0.1
const FIREBALL_SECONDS: float = 0.6
const FIREBALL_RADIUS_FACTOR: float = 0.7
const SWELL_FRACTION: float = 0.333
const CHUNKS: int = 6
const SPEED_RANGE: Vector2 = Vector2(3.0, 6.0)
const GRAVITY: float = 9.8
const PUFFS: int = 3
const SMOKE_SECONDS: float = 1.8
const SMOKE_RISE: float = 1.0
const SMOKE_GROWTH: float = 2.5
const CHUNK_COLOUR: Color = Color(0.18, 0.18, 0.2, 1.0)
## The smoke's colour as built: the story's alpha of 0.6, three puffs stacked, left a Flag dropped at the wreck too dim to read.
const SMOKE_COLOUR: Color = Color(0.22, 0.22, 0.22, 0.4)
## The fireball's colours as built: the story's orange read as Team Orange beside Player 1's colour in the first recording.
const FIREBALL_START: Color = Color(1.0, 0.85, 0.3, 1.0)
const FIREBALL_END: Color = Color(0.4, 0.07, 0.03, 1.0)
## Number literals the lint lets through: the integers 0 and 1 and the floats 0.0, 1.0 and 2.0 (a half is a half).
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0, 2.0]
## Words that mean a random number, which no effect may use.
const RANDOM_WORDS: Array[String] = ["rand", "Random", "shuffle"]

var measured: PackedStringArray = []
var _k: Kit16
var _q: Quick


func _init(kit: Kit16) -> void:
	_k = kit
	_q = kit.q


func run() -> void:
	_shipped_scene()
	_settings_data()
	_bad_settings_refused()
	await _bad_scene_plays_nothing()
	_lint()


func _shipped_scene() -> void:
	var problems: PackedStringArray = []
	var split: SplitScreen = _q.harness.split
	_q.kit.need(problems, split.explosion_scene != null and split.explosion_scene.resource_path == Kit16.SCENE_PATH, "the running scene's explosion_scene is %s" % split.explosion_scene)
	var fresh: SplitScreen = (load(SPLIT_SCENE) as PackedScene).instantiate() as SplitScreen
	_q.kit.need(problems, fresh.explosion_scene != null and fresh.explosion_scene.resource_path == Kit16.SCENE_PATH, "split_screen.tscn does not set explosion_scene")
	fresh.free()
	var links: int = 0
	var frees: int = 0
	for link: Dictionary in _q.controller.unit_destroyed.get_connections():
		links += 1 if (link["callable"] as Callable).get_object() == split and (link["callable"] as Callable).get_method() == &"_explode" else 0
	for link: Dictionary in _q.controller.round_started.get_connections():
		frees += 1 if (link["callable"] as Callable).get_object() == split and (link["callable"] as Callable).get_method() == &"_free_explosions" else 0
	_q.kit.need(problems, links == 1 and frees == 1, "SplitScreen has %d links on unit_destroyed and %d on round_started for the explosions" % [links, frees])
	var unit_links: int = 0
	for unit: Unit in _q.units.units:
		for link: Dictionary in unit.destroyed.get_connections():
			unit_links += 1 if (link["callable"] as Callable).get_object() == split else 0
	_q.kit.need(problems, unit_links == 0, "SplitScreen is linked to Unit.destroyed %d times" % unit_links)
	_q.kit.verdict("shipped_scene", problems, "split_screen.tscn sets explosion_scene (%s); SplitScreen has one link on the Round's unit_destroyed and one on round_started for the explosions and none on any Unit's destroyed signal" % Kit16.SCENE_PATH)


func _settings_data() -> void:
	var problems: PackedStringArray = []
	var s: ExplosionSettings = load(SETTINGS_PATH) as ExplosionSettings
	_q.kit.need(problems, s != null and s.first_problem().is_empty(), "the settings do not load or are unusable: %s" % (s.first_problem() if s != null else "null"))
	if s == null:
		_q.kit.verdict("settings_data", problems, "no settings")
		return
	_q.kit.need(problems, is_equal_approx(s.lifetime_seconds, LIFETIME) and is_equal_approx(s.flash_seconds, FLASH_SECONDS) and is_equal_approx(s.fireball_seconds, FIREBALL_SECONDS), "lifetime %s, flash %s, fireball %s" % [s.lifetime_seconds, s.flash_seconds, s.fireball_seconds])
	_q.kit.need(problems, is_equal_approx(s.fireball_radius_factor, FIREBALL_RADIUS_FACTOR) and is_equal_approx(s.fireball_swell_fraction, SWELL_FRACTION), "fireball radius %s, swell %s" % [s.fireball_radius_factor, s.fireball_swell_fraction])
	_q.kit.need(problems, s.chunk_directions.size() == CHUNKS and s.chunk_speeds.size() == CHUNKS and s.chunk_size_factors.size() == CHUNKS and is_equal_approx(s.chunk_gravity, GRAVITY), "%d chunks, gravity %s" % [s.chunk_directions.size(), s.chunk_gravity])
	for index: int in s.chunk_speeds.size():
		_q.kit.need(problems, s.chunk_speeds[index] >= SPEED_RANGE.x and s.chunk_speeds[index] <= SPEED_RANGE.y and s.chunk_directions[index].y > 0.0, "chunk %d: speed %s, direction %s (up and out)" % [index, s.chunk_speeds[index], s.chunk_directions[index]])
	_q.kit.need(problems, s.smoke_offsets.size() == PUFFS and is_equal_approx(s.smoke_seconds, SMOKE_SECONDS) and is_equal_approx(s.smoke_rise_speed, SMOKE_RISE) and is_equal_approx(s.smoke_growth, SMOKE_GROWTH), "%d puffs, %s s, rise %s, growth %s" % [s.smoke_offsets.size(), s.smoke_seconds, s.smoke_rise_speed, s.smoke_growth])
	var mine: Mine = (load(MINE_SCENE) as PackedScene).instantiate() as Mine
	var mine_colour: Color = ((mine.flash as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D).albedo_color
	mine.free()
	_q.kit.need(problems, s.flash_colour.is_equal_approx(mine_colour), "the flash is %s, a Mine's flash %s" % [s.flash_colour, mine_colour])
	_q.kit.need(problems, s.chunk_colour.is_equal_approx(CHUNK_COLOUR) and s.smoke_colour.is_equal_approx(SMOKE_COLOUR) and s.fireball_colour_start.is_equal_approx(FIREBALL_START) and s.fireball_colour_end.is_equal_approx(FIREBALL_END), "colours %s %s %s %s" % [s.chunk_colour, s.smoke_colour, s.fireball_colour_start, s.fireball_colour_end])
	_q.kit.verdict("settings_data", problems, "explosion_settings.tres reads back: %.1f s in all, a %.1f s flash in a Mine's pale yellow, a %.1f s fireball of %.1f of the type's side (swell %.3f of its time) from %s to %s, %d chunks thrown up and out at %.0f to %.0f m/s under %.1f m/s², %d puffs of %.1f s rising %.1f m/s growing %.1f times in %s" % [s.lifetime_seconds, s.flash_seconds, s.fireball_seconds, s.fireball_radius_factor, s.fireball_swell_fraction, s.fireball_colour_start, s.fireball_colour_end, s.chunk_directions.size(), SPEED_RANGE.x, SPEED_RANGE.y, s.chunk_gravity, s.smoke_offsets.size(), s.smoke_seconds, s.smoke_rise_speed, s.smoke_growth, s.smoke_colour])


## One broken copy of the shipped settings per entry: [what is broken, the words its problem must hold].
func _bad_settings_refused() -> void:
	var problems: PackedStringArray = []
	var shipped: ExplosionSettings = load(SETTINGS_PATH) as ExplosionSettings
	var cases: Array[Array] = [["lifetime_seconds", 0.0, "lifetime_seconds"], ["flash_seconds", LIFETIME * 2.0, "flash_seconds"], ["fireball_swell_fraction", 1.0, "fireball_swell_fraction"],
		["fireball_start_scale", 0.0, "fireball_start_scale"], ["chunk_gravity", 0.0, "chunk_gravity"], ["smoke_seconds", LIFETIME + 0.5, "smoke ends after the lifetime"],
		["smoke_stagger_seconds", LIFETIME, "last puff"], ["lifetime_seconds", NAN, "lifetime_seconds"], ["fireball_radius_factor", NAN, "must be above zero"]]
	for entry: Array in cases:
		var broken: ExplosionSettings = shipped.duplicate() as ExplosionSettings
		broken.set(entry[0], entry[1])
		_q.kit.need(problems, broken.first_problem().contains(entry[2]), "%s = %s reads '%s', not '%s'" % [entry[0], entry[1], broken.first_problem(), entry[2]])
	var short: ExplosionSettings = shipped.duplicate() as ExplosionSettings
	short.chunk_speeds = short.chunk_speeds.slice(1)
	var nowhere: ExplosionSettings = shipped.duplicate() as ExplosionSettings
	var directions: PackedVector3Array = nowhere.chunk_directions.duplicate()
	directions[2] = Vector3.ZERO
	nowhere.chunk_directions = directions
	var invisible: ExplosionSettings = shipped.duplicate() as ExplosionSettings
	invisible.smoke_colour = Color(invisible.smoke_colour, 0.0)
	_q.kit.need(problems, short.first_problem().contains("same length") and nowhere.first_problem().contains("points nowhere") and invisible.first_problem().contains("no alpha"), "tables: '%s' | '%s' | '%s'" % [short.first_problem(), nowhere.first_problem(), invisible.first_problem()])
	_q.kit.need(problems, shipped.first_problem().is_empty(), "the shipped settings read '%s'" % shipped.first_problem())
	_q.kit.verdict("bad_settings_refused", problems, "first_problem() passes the shipped settings and names each of %d broken copies (a zero lifetime, a flash longer than the life, a swell of 1, a zero start scale, no gravity, smoke past the lifetime, a stagger that begins a puff after the end, NaN, tables of unequal length, a direction pointing nowhere, an invisible colour)" % (cases.size() + 3))


## An Explosion with bad settings plays nothing: one named error in _ready() and the node frees itself when blasted; a
## blast of no size likewise.
func _bad_scene_plays_nothing() -> void:
	var problems: PackedStringArray = []
	var scene: PackedScene = load(Kit16.SCENE_PATH) as PackedScene
	var world: Node = _q.units.units[0].get_parent()
	var broken: ExplosionSettings = (load(SETTINGS_PATH) as ExplosionSettings).duplicate() as ExplosionSettings
	broken.lifetime_seconds = 0.0
	var bad: Explosion = scene.instantiate() as Explosion
	bad.settings = broken
	_k.expected_errors.append("so it plays nothing")
	world.add_child(bad)
	bad.blast(Vector3.ZERO, 1.0, 0.0)
	var empty: Explosion = scene.instantiate() as Explosion
	_k.expected_errors.append("not above zero, so it plays nothing")
	world.add_child(empty)
	empty.blast(Vector3.ZERO, 0.0, 0.0)
	await _q.kit.advance(Kit16.SETTLE)
	_q.kit.need(problems, not is_instance_valid(bad) or not bad.is_inside_tree(), "the Explosion with bad settings is still in the tree")
	_q.kit.need(problems, not is_instance_valid(empty) or not empty.is_inside_tree(), "the Explosion blasted with no size is still in the tree")
	_q.kit.need(problems, _k.playing().is_empty(), "%d Explosions play" % _k.playing().size())
	_q.kit.verdict("bad_scene_plays_nothing", problems, "an Explosion whose settings fail logged one named error in _ready() and freed itself when blasted, and one blasted with no size likewise: neither played a tick (two errors expected and accounted for)")


func _lint() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
	var quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
	var lines: int = 0
	for path: String in SOURCE_FILES:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = quoted.sub(line, "", true).get_slice("#", 0)
			lines += 0 if code.strip_edges().is_empty() else 1
			for hit: RegExMatch in literal.search_all(code):
				var text: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(text)) if text.contains(".") else LINT_INTEGERS.has(int(text))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [path.get_file(), text, code.strip_edges()])
			_q.kit.need(problems, not code.contains("team_material") and not code.contains("type_id"), "%s names a Team colour or a Unit type: %s" % [path.get_file(), code.strip_edges()])
	for path: String in EFFECT_FILES:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = quoted.sub(line, "", true).get_slice("#", 0)
			for word: String in RANDOM_WORDS:
				_q.kit.need(problems, not code.contains(word), "%s holds '%s' in '%s'" % [path.get_file(), word, code.strip_edges()])
	measured.append("lint_lines=%d" % lines)
	_q.kit.verdict("explosions_lint", problems, "the %d code lines of explosion.gd hold no number other than 0, 1, 0.0, 1.0 and 2.0 (a half), no Team colour and no Unit type, and the effects' scripts and SplitScreen's hook hold nothing random" % lines)
