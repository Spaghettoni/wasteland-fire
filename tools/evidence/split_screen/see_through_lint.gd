extends RefCounted
## The lint of the see_through scenario (Story 027 AC-5): no_number_in_code (no number other than 0, 1, 0.0 and 1.0 is a constant in a code line of the two new scripts,
## the colour grade's tool, and the functions the story changed in Unit, UnitModel, ChaseCamera and SplitScreen, and no branch names a Unit type; the silhouette is made, and its layers handed
## to the cameras, with no search of the scene tree and no singleton, so the copies take their Player's layer from the settings when the Unit is given its Player and
## nothing else). Run by see_through.gd.
## Tooling only. Every number comes from the game's files; the scenario types only its test inputs.

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")

## The whole files the lint reads: the new scripts and the colour grade's tool.
const LINT_FILES: Array[String] = [
	"res://src/gameplay/units/models/silhouette_settings.gd", "res://src/gameplay/units/models/unit_silhouette.gd", "res://tools/colour_grade/build_colour_grade_lut.gd"]
## The functions of older scripts that the story changed: [file, function].
const LINT_FUNCTIONS: Array[Array] = [
	["res://src/gameplay/units/unit.gd", "_swap_model"], ["res://src/gameplay/units/unit.gd", "_dress_silhouette"],
	["res://src/gameplay/units/models/unit_model.gd", "_add_mesh"], ["res://src/gameplay/camera/chase_camera.gd", "_apply_hidden_layers"],
	["res://src/gameplay/split_screen/split_screen.gd", "_hand_silhouette_layers"]]
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0]
## What the silhouette may not use to find a node: it is handed the model and the Player.
const SEARCHES: PackedStringArray = ["get_node", "find_child", "get_tree", "get_nodes_in_group", "get_singleton", "$"]

var measured: PackedStringArray = []
var expected_errors: int = 0
var _k: Kit27
var _q: Quick


func _init(kit: Kit27, _at_start: Dictionary) -> void:
	_k = kit
	_q = kit.q()


## The checks, in order. A coroutine: await it.
func run() -> void:
	_no_number_in_code()


## The code of a source file with the comments, quoted text and the editor's range hints taken out, line by line.
func _code_lines(text: String) -> PackedStringArray:
	var quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
	var hint: RegEx = RegEx.create_from_string(r"@export_range\([^)]*\)")
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		lines.append(hint.sub(quoted.sub(line, "", true).get_slice("#", 0), "", true))
	return lines


## The lines of a function of a script, from its `func` line to the line before the next top-level line.
func _function_text(text: String, function_name: String) -> String:
	var found: PackedStringArray = []
	var inside: bool = false
	for line: String in text.split("\n"):
		if line.begins_with("func %s(" % function_name):
			inside = true
		elif inside and not line.is_empty() and not line.begins_with("\t") and not line.begins_with("#"):
			inside = false
		if inside:
			found.append(line)
	return "\n".join(found)


## no_number_in_code (AC-5): see the class doc.
func _no_number_in_code() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
	var unique_name: RegEx = RegEx.create_from_string(r"%[A-Za-z_]")
	var sources: Dictionary = {}
	for path: String in LINT_FILES:
		sources[path.get_file()] = FileAccess.get_file_as_string(path)
	for entry: Array in LINT_FUNCTIONS:
		sources["%s %s" % [String(entry[0]).get_file(), entry[1]]] = _function_text(FileAccess.get_file_as_string(entry[0]), entry[1])
	var lines: int = 0
	for source_name: String in sources:
		var text: String = sources[source_name]
		_q.kit.need(problems, not text.is_empty(), "%s is empty or missing" % source_name)
		for code: String in _code_lines(text):
			lines += 0 if code.strip_edges().is_empty() else 1
			for hit: RegExMatch in literal.search_all(code):
				var number: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(number)) if number.contains(".") else LINT_INTEGERS.has(int(number))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [source_name, number, code.strip_edges()])
			for type_name: String in ["motorbike", "buggy", "truck", "gyrocopter"]:
				_q.kit.need(problems, not code.contains("&\"%s\"" % type_name) and not code.contains("type_id =="), "%s names a Unit type: %s" % [source_name, code.strip_edges()])
			if source_name.begins_with("unit_silhouette") or source_name.ends_with("_dress_silhouette") or source_name.ends_with("_hand_silhouette_layers"):
				for search: String in SEARCHES:
					_q.kit.need(problems, not code.contains(search), "%s uses '%s': %s" % [source_name, search, code.strip_edges()])
				_q.kit.need(problems, unique_name.search(code) == null, "%s looks a node up by its unique name: %s" % [source_name, code.strip_edges()])
	measured.append("lint_lines=%d" % lines)
	_q.kit.verdict("no_number_in_code", problems, "%d code lines of the two new scripts, the colour grade's tool and the five functions the story changed hold no number other than 0, 1, 0.0 and 1.0, no branch names a Unit type, and the silhouette's own code (UnitSilhouette, Unit._dress_silhouette() and SplitScreen._hand_silhouette_layers()) searches no tree and asks no singleton" % lines)
