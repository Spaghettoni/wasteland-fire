extends RefCounted
## Scenario pads_data of the split screen evidence harness (split_screen_harness.gd): the pad
## layout is data and a broken one is refused (Story 032 AC-3 and AC-7). CHECK lines:
##  D1 the shipped layout: pad_layout.tres binds every action under p1_ and p2_ but debug_damage,
##     with the starting layout of AC-3 (RT throttle, LT reverse, the left stick and the D-pad
##     steer, A fire, X Mine, Y camera, View Self-destruct, Menu restart), and first_problem() finds
##     nothing for either prefix.
##  D2 refusals: a layout with no binding for lay_mine, one with A on both fire and lay_mine, one
##     with no dead zone, one whose binding has no name, one naming an action the Input Map lacks:
##     first_problem() names each.
##  D3 a refused layout: a PadAssignment given the doubled layout pushes one error, takes no pad and
##     adds nothing to the Input Map, and the keyboard keys are all still there.
##  D4 no number in code: the pad scripts hold no button index or axis number (the lint: every
##     integer literal in src/gameplay/input/*.gd is 0 or 1).
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-3 and AC-7.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=pads_data

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The shipped layout.
const LAYOUT_PATH: String = "res://src/gameplay/input/data/pad_layout.tres"
## The pad scripts the lint reads.
const SCRIPT_DIR: String = "res://src/gameplay/input/"
## The starting layout of AC-3: suffix -> the names of its inputs, in the layout's order.
const EXPECTED: Dictionary = {
	&"throttle": ["RT"], &"reverse": ["LT"], &"steer_left": ["Stick left", "D-pad left"],
	&"steer_right": ["Stick right", "D-pad right"], &"fire": ["A"], &"lay_mine": ["X"],
	&"camera": ["Y"], &"self_destruct": ["View"], &"round_restart": ["Menu"]}
## A pad device for the refused layout's attempt.
const PAD: int = 0

var _h: Harness
var _kit: Kit


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	var layout: PadLayout = load(LAYOUT_PATH) as PadLayout
	_check_shipped(layout)
	_check_refusals(layout)
	await _check_refused_assignment(layout)
	_check_lint()
	_h.finish("bindings=%d" % layout.bindings.size())


func _check_shipped(layout: PadLayout) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var found: Dictionary = {}
	for binding: PadBinding in layout.bindings:
		if not found.has(binding.action_suffix):
			found[binding.action_suffix] = []
		found[binding.action_suffix].append(binding.display_name)
	for suffix: StringName in EXPECTED:
		_kit.need(problems, found.get(suffix, []) == EXPECTED[suffix], "%s binds %s" % [suffix, found.get(suffix, [])])
	_kit.need(problems, found.size() == EXPECTED.size(), "the layout binds %d actions" % found.size())
	var p1: String = layout.first_problem(&"p1_")
	var p2: String = layout.first_problem(&"p2_")
	_kit.need(problems, p1.is_empty() and p2.is_empty(), "first_problem: '%s' / '%s'" % [p1, p2])
	_kit.need(problems, layout.unbound_suffixes == PackedStringArray(["debug_damage"]), "unbound %s" % layout.unbound_suffixes)
	_kit.verdict("D1_shipped_layout", problems, "%s; dead zone %.2f; unbound %s" % [found, layout.deadzone, layout.unbound_suffixes])


## A copy of the layout whose bindings are copies too, so a change does not reach the shipped one.
func _copy(layout: PadLayout) -> PadLayout:
	var copy: PadLayout = layout.duplicate() as PadLayout
	var bindings: Array[PadBinding] = []
	for binding: PadBinding in layout.bindings:
		bindings.append(binding.duplicate() as PadBinding)
	copy.bindings = bindings
	return copy


func _without(layout: PadLayout, suffix: StringName) -> PadLayout:
	var copy: PadLayout = _copy(layout)
	copy.bindings = copy.bindings.filter(func(binding: PadBinding) -> bool: return binding.action_suffix != suffix)
	return copy


func _doubled(layout: PadLayout) -> PadLayout:
	var copy: PadLayout = _copy(layout)
	for binding: PadBinding in copy.bindings:
		if binding.action_suffix == &"lay_mine":
			binding.button = JOY_BUTTON_A
	return copy


func _check_refusals(layout: PadLayout) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var no_zone: PadLayout = _copy(layout)
	no_zone.deadzone = 0.0
	var no_name: PadLayout = _copy(layout)
	no_name.bindings[0].display_name = ""
	var no_action: PadLayout = _copy(layout)
	no_action.bindings[0].action_suffix = &"jump"
	var cases: Dictionary = {
		"missing lay_mine": _without(layout, &"lay_mine").first_problem(&"p1_"),
		"A twice": _doubled(layout).first_problem(&"p1_"),
		"no dead zone": no_zone.first_problem(&"p1_"),
		"no name": no_name.first_problem(&"p1_"),
		"unknown action": no_action.first_problem(&"p1_")}
	var lines: PackedStringArray = PackedStringArray()
	for label: String in cases:
		lines.append("%s -> '%s'" % [label, cases[label]])
		_kit.need(problems, not String(cases[label]).is_empty(), "%s was accepted" % label)
	_kit.need(problems, String(cases["missing lay_mine"]).contains("p1_lay_mine"), "the missing action is not named")
	_kit.need(problems, String(cases["A twice"]).contains("fire") and String(cases["A twice"]).contains("lay_mine"), "the doubled input does not name both actions")
	_kit.verdict("D2_refusals", problems, " | ".join(lines))


## The pad events on the game's actions (not the engine's ui_ actions, which come with pads bound).
func _pad_event_count() -> int:
	var count: int = 0
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				count += 1
	return count


func _key_event_count() -> int:
	var count: int = 0
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				count += 1
	return count


func _check_refused_assignment(layout: PadLayout) -> void:
	var problems: PackedStringArray = PackedStringArray()
	var keys_before: int = _key_event_count()
	var log: ErrorCount = ErrorCount.new()
	OS.add_logger(log)
	var broken := PadAssignment.new()
	broken.layout = _doubled(layout)
	broken.action_prefixes = [&"p1_", &"p2_"]
	_h.add_child(broken)
	var taken: int = broken.connect_pad(PAD)
	await _kit.advance(1)
	OS.remove_logger(log)
	var pads: int = _pad_event_count()
	var keys_after: int = _key_event_count()
	_h.remove_child(broken)
	broken.free()
	_kit.need(problems, log.errors == 1, "%d errors pushed" % log.errors)
	_kit.need(problems, taken == PadAssignment.NO_PAD, "the refused layout took the pad for %d" % taken)
	_kit.need(problems, pads == 0, "%d pad events added" % pads)
	_kit.need(problems, keys_after == keys_before, "keyboard events %d -> %d" % [keys_before, keys_after])
	_kit.verdict("D3_refused_assignment", problems, "errors %d (%s); connect -> %d; pad events %d; keyboard events %d -> %d" % [
		log.errors, log.first, taken, pads, keys_before, keys_after])


func _check_lint() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var regex := RegEx.create_from_string("(?<![\\w.])(\\d+)(?![\\w.])")
	var read: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(SCRIPT_DIR):
		if not file.ends_with(".gd"):
			continue
		read.append(file)
		var lines: PackedStringArray = FileAccess.get_file_as_string(SCRIPT_DIR + file).split("\n")
		for index: int in lines.size():
			var code: String = lines[index].split("#")[0]
			if code.strip_edges().begins_with("##") or code.contains("\"") or code.strip_edges().begins_with("@export_range"):
				continue
			for found: RegExMatch in regex.search_all(code):
				if found.get_string(1) != "0" and found.get_string(1) != "1":
					problems.append("%s:%d %s" % [file, index + 1, found.get_string(1)])
	_kit.verdict("D4_no_number_in_code", problems, "read %s; integer literals other than 0 and 1 outside strings and the export ranges: %d" % [", ".join(read), problems.size()])


## Counts the engine's errors while a refused PadAssignment enters the tree.
class ErrorCount extends Logger:
	var errors: int = 0
	var first: String = ""

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type != ERROR_TYPE_WARNING:
			errors += 1
			if first.is_empty():
				first = (code + " " + rationale).strip_edges()
