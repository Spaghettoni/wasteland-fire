extends RefCounted
## The refusals, the defaults and the lint for the tyre_tracks scenario (Story 026 AC-6 and AC-7): refusals (TyreTrackSettings.first_problem() and
## UnitStats.first_problem() name each fault of the data, a width that is not above zero, a missing tyre, a place that is not a number, an empty area or
## texture, a negative hold, a fade or a jump step that is not above zero, each with its own sentence, and pass the shipped data; and a tracks node given
## unusable settings logs one error and draws, sends and ticks nothing), globals_default (project.godot declares the four global shader parameters the
## node sends, the strength in the default of the look is 0 so that a Map with no tracks node shows none, the defaults divide by nothing, and the ground
## shader declares each of them with its type; the brush ignores the colour of its vertices) and lint (no number other than 0, 1, 0.0, 1.0 and 2.0, a half,
## in a code line of the four new scripts, the brush shader's lines and the ground shader's tracks lines but in named constants, no branch names a Unit
## type, and SplitScreen's hand-off searches no tree and asks no singleton). Run by tyre_tracks.gd. Tooling only. Every number comes from the game's files;
## the scenario types only its test inputs.

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The settings faults: [property, bad value, the sentence first_problem() gives].
const SETTINGS_FAULTS: Array = [
	["area_size", Vector2(0.0, 92.2), "area_size is not above zero in both X and Z"],
	["area_size", Vector2(294.0, -1.0), "area_size is not above zero in both X and Z"],
	["texture_size", Vector2i(0, 1284), "texture_size is not above zero in both X and Y"],
	["darkness", 1.5, "darkness is not from 0 to 1"], ["darkness", -0.1, "darkness is not from 0 to 1"], ["darkness", NAN, "darkness is not from 0 to 1"],
	["rut_depth", -0.01, "rut_depth is below zero"], ["rut_depth", NAN, "rut_depth is below zero"],
	["rut_reach", 0.0, "rut_reach is not above zero"], ["rut_reach", NAN, "rut_reach is not above zero"],
	["smoothing", 2.0, "smoothing is not from 0 to 1"],
	["rim_pixels", 0.0, "rim_pixels is not above zero"],
	["hold_seconds", -1.0, "hold_seconds is below zero"], ["hold_seconds", NAN, "hold_seconds is below zero"],
	["fade_seconds", 0.0, "fade_seconds is not above zero"], ["fade_seconds", -5.0, "fade_seconds is not above zero"], ["fade_seconds", NAN, "fade_seconds is not above zero"],
	["jump_step", 0.0, "jump_step is not above zero"],
	["min_step", 2.0, "min_step is not from 0 to under jump_step"], ["min_step", -0.1, "min_step is not from 0 to under jump_step"],
	["area_origin", Vector2(NAN, 0.0), "area_origin is not a number"]]
## The files the lint reads: the new scripts, the brush shader, the ground shader, the scene that hands the node on.
const SCRIPTS: PackedStringArray = ["res://src/gameplay/maps/tyre_tracks.gd", "res://src/gameplay/maps/tyre_track_painter.gd", "res://src/gameplay/maps/tyre_track_settings.gd", "res://src/gameplay/units/tyre_contact.gd"]
const BRUSH: String = "res://src/gameplay/maps/canvas_env_tyre_track.gdshader"
const GROUND: String = "res://src/gameplay/maps/spatial_env_ground.gdshader"
const SPLIT_SCREEN: String = "res://src/gameplay/split_screen/split_screen.gd"
## The numbers a code line may hold, integers and floats (2.0 is a half).
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0, 2.0]
## What a hand-off may not use to find the node.
const SEARCHES: PackedStringArray = ["get_node", "find_child", "get_tree", "get_nodes_in_group", "get_singleton", "$", "%"]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit26
var _q: Quick


func _init(kit: Kit26) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	await _refusals()
	_globals_default()
	_lint()


## refusals (AC-6): see the class doc. The unusable settings make the node log one error, counted in expected_errors.
func _refusals() -> void:
	var problems: PackedStringArray = []
	var tracks: TyreTracks = _k.tracks()
	var shipped: TyreTrackSettings = tracks.settings
	_q.kit.need(problems, shipped.first_problem().is_empty(), "the shipped settings read '%s'" % shipped.first_problem())
	for fault: Array in SETTINGS_FAULTS:
		var copy: TyreTrackSettings = shipped.duplicate() as TyreTrackSettings
		copy.set(fault[0], fault[1])
		_q.kit.need(problems, copy.first_problem() == fault[2], "%s = %s reads '%s', expected '%s'" % [fault[0], fault[1], copy.first_problem(), fault[2]])
	var stats: UnitStats = _q.units.stats(Quick.MOTORBIKE)
	_q.kit.need(problems, stats.first_problem().is_empty(), "the shipped Motorbike reads '%s'" % stats.first_problem())
	var cases: Array = [["width -0.1", 0, "tyres[0] width is not above zero"], ["width 0", 0, "tyres[0] width is not above zero"], ["width NAN", 0, "tyres[0] width is not above zero"],
		["offset NAN", 1, "tyres[1] offset is not a finite number"], ["missing", 0, "tyres[0] is missing"]]
	for case: Array in cases:
		var copy: UnitStats = stats.duplicate() as UnitStats
		var tyres: Array[TyreContact] = []
		for tyre: TyreContact in stats.tyres:
			tyres.append(tyre.duplicate() as TyreContact)
		match String(case[0]):
			"width -0.1":
				tyres[case[1]].width = -0.1
			"width 0":
				tyres[case[1]].width = 0.0
			"width NAN":
				tyres[case[1]].width = NAN
			"offset NAN":
				tyres[case[1]].offset = Vector2(NAN, 0.0)
			"missing":
				tyres[case[1]] = null
		copy.tyres = tyres
		_q.kit.need(problems, copy.first_problem() == case[2], "%s reads '%s', expected '%s'" % [case[0], copy.first_problem(), case[2]])
	var node: TyreTracks = load("res://src/gameplay/maps/tyre_tracks.tscn").instantiate() as TyreTracks
	var broken: TyreTrackSettings = shipped.duplicate() as TyreTrackSettings
	broken.fade_seconds = 0.0
	node.settings = broken
	var sent: Array[StringName] = []
	node.published.connect(func(parameter: StringName, _value: Variant) -> void: sent.append(parameter))
	_q.harness.add_child(node)
	expected_errors += 1
	await _q.kit.advance(2)
	_q.kit.need(problems, not node.is_physics_processing() and sent.is_empty() and node.strokes.is_empty(), "the node with unusable settings still ticks (%s), sent %s or made strokes" % [node.is_physics_processing(), sent])
	_q.harness.remove_child(node)
	node.free()
	_q.kit.verdict("refusals", problems, "%d faults of the settings, five of a tyre and the shipped data each read as their own sentence or as none; a tracks node given a fade of zero logged its one error and then ticked, sent and drew nothing" % [SETTINGS_FAULTS.size() + 1 + cases.size()])


## globals_default (AC-7): see the class doc.
func _globals_default() -> void:
	var problems: PackedStringArray = []
	var types: Dictionary = {TyreTracks.MAP_GLOBAL: "sampler2D", TyreTracks.AREA_GLOBAL: "vec4", TyreTracks.LOOK_GLOBAL: "vec4", TyreTracks.CLOCK_GLOBAL: "vec4"}
	var ground: String = FileAccess.get_file_as_string(GROUND)
	for parameter: StringName in types:
		var key: String = "shader_globals/%s" % parameter
		var entry: Dictionary = ProjectSettings.get_setting(key, {}) as Dictionary
		_q.kit.need(problems, ProjectSettings.has_setting(key) and entry.get("type") == types[parameter], "project.godot does not declare %s as a %s: %s" % [parameter, types[parameter], entry])
		_q.kit.need(problems, RegEx.create_from_string("global uniform %s %s\\b" % [types[parameter], parameter]).search(ground) != null, "the ground shader does not declare global uniform %s %s" % [types[parameter], parameter])
	var look: Vector4 = (ProjectSettings.get_setting("shader_globals/%s" % TyreTracks.LOOK_GLOBAL, {}) as Dictionary).get("value", Vector4.ONE)
	var area: Vector4 = (ProjectSettings.get_setting("shader_globals/%s" % TyreTracks.AREA_GLOBAL, {}) as Dictionary).get("value", Vector4.ZERO)
	var clock: Vector4 = (ProjectSettings.get_setting("shader_globals/%s" % TyreTracks.CLOCK_GLOBAL, {}) as Dictionary).get("value", Vector4.ZERO)
	_q.kit.need(problems, look.w == 0.0, "the default strength is %s: a Map with no tracks node would show tracks" % look.w)
	_q.kit.need(problems, area.z > 0.0 and area.w > 0.0 and clock.z > 0.0, "the defaults divide by nothing: area size %s x %s, fade %s" % [area.z, area.w, clock.z])
	var brush: String = FileAccess.get_file_as_string(BRUSH)
	var reads: int = 0
	for line: String in brush.split("\n"):
		reads += line.get_slice("//", 0).count("COLOR")
	_q.kit.need(problems, reads == 1, "the brush shader names COLOR %d times in its code (once: the colour it writes)" % reads)
	_q.kit.verdict("globals_default", problems, "project.godot declares %s as %s; the default strength is %.0f (off) and the defaults divide by nothing (area %s x %s, fade %s); the ground shader declares all four and the brush shader names COLOR once, to write it" % [", ".join(types.keys()), ", ".join(types.values()), look.w, area.z, area.w, clock.z])


## The code of a file's lines with comments, quoted text and the editor's range hints taken out.
static func _code(line: String, is_shader: bool) -> String:
	var quoted: RegEx = RegEx.create_from_string("\"(?:\\\\.|[^\"\\\\])*\"")
	var hint: RegEx = RegEx.create_from_string("@export_range\\([^)]*\\)")
	return hint.sub(quoted.sub(line, "", true).get_slice("//" if is_shader else "#", 0), "", true)


## lint (AC-6): see the class doc.
func _lint() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string("(?<![\\w.])\\d+(?:\\.\\d+)?(?![\\w.])")
	var lines: int = 0
	var files: Array[Array] = []
	for path: String in SCRIPTS:
		files.append([path, false, false])
	files.append([BRUSH, true, false])
	files.append([GROUND, true, true])
	for entry: Array in files:
		for line: String in FileAccess.get_file_as_string(entry[0]).split("\n"):
			var code: String = _code(line, entry[1])
			var tracks_line: bool = not entry[2] or (RegEx.create_from_string("tyre_track|track_|\\bmark\\b|\\brise\\b|\\breach\\b").search(code) != null and not code.strip_edges().begins_with("const "))
			lines += 1 if tracks_line and not code.strip_edges().is_empty() else 0
			for hit: RegExMatch in literal.search_all(code if tracks_line else ""):
				var text: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(text)) if text.contains(".") else LINT_INTEGERS.has(int(text))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [String(entry[0]).get_file(), text, code.strip_edges()])
			var raw: String = line.get_slice("//" if entry[1] else "#", 0)
			for type_name: String in ["motorbike", "buggy", "truck", "gyrocopter"]:
				_q.kit.need(problems, not raw.contains("\"%s\"" % type_name) and not code.contains("type_id =="), "%s names a Unit type: %s" % [String(entry[0]).get_file(), raw.strip_edges()])
	var split: String = FileAccess.get_file_as_string(SPLIT_SCREEN)
	var start: int = split.find("func _hand_tyre_tracks")
	var body: String = split.substr(start, split.find("\n\n\n", start) - start) if start >= 0 else ""
	_q.kit.need(problems, not body.is_empty(), "SplitScreen has no _hand_tyre_tracks()")
	for search: String in SEARCHES:
		_q.kit.need(problems, not body.contains(search), "SplitScreen's hand-off uses '%s'" % search)
	_measured_lines(lines)
	_q.kit.verdict("lint", problems, "%d code lines of the four new scripts, the brush shader and the ground shader's tracks lines hold no number other than 0, 1, 0.0, 1.0 and 2.0 (a half) outside named constants and no branch names a Unit type; SplitScreen's hand-off names no search of the tree and no singleton" % lines)


func _measured_lines(count: int) -> void:
	measured.append("lint_lines=%d" % count)
