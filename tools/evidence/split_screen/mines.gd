extends RefCounted
## Scenario mines of the split screen evidence harness (split_screen_harness.gd): the Truck's Mines of Story 014 AC-1
## to AC-9, played with real keys on the shipped data and Map 01. This script holds mines_data (what the scenes, the
## data, the Input Map, the texts and the README say), mines_lint (no number is a constant in code) and
## bad_data_refused (a forgotten line of data is refused by name) and no_engine_noise; the modules it runs, in this order, hold the rest: mines_lay.gd (the lay and the count: AC-1,
## AC-2), mines_arm.gd (arming, the blink, going live, both views: AC-3, AC-4), mines_kill.gd (what a live Mine
## destroys and what it leaves alone: AC-4), mines_where.gd (the no-mine areas, open ground, the refusals: AC-5),
## mines_stay.gd (what stays when a Truck goes, no cap: AC-7), mines_rounds.gd (a Mine's kill in the Round, the
## restart: AC-6, AC-7) and mines_doubles.gd (the double losses: AC-6). One Round, played on after each check; the
## Mines are cleared between the modules. Tooling only. Implements: production/epics/wasteland-fire/
## story-014-truck-mines.md AC-1 to AC-9. Every number comes from the game's data; the scenario types only its test
## inputs and the story's values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=mines

const Kit14: GDScript = preload("res://tools/evidence/split_screen/mines_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Lay: GDScript = preload("res://tools/evidence/split_screen/mines_lay.gd")
const Arm: GDScript = preload("res://tools/evidence/split_screen/mines_arm.gd")
const Kill: GDScript = preload("res://tools/evidence/split_screen/mines_kill.gd")
const Where: GDScript = preload("res://tools/evidence/split_screen/mines_where.gd")
const Layout: GDScript = preload("res://tools/evidence/split_screen/mines_layout.gd")
const Extra: GDScript = preload("res://tools/evidence/split_screen/mines_extra.gd")
const Stay: GDScript = preload("res://tools/evidence/split_screen/mines_stay.gd")
const Rounds: GDScript = preload("res://tools/evidence/split_screen/mines_rounds.gd")
const Doubles: GDScript = preload("res://tools/evidence/split_screen/mines_doubles.gd")
## The data this story adds, by path.
const SETTINGS_PATH: String = "res://src/gameplay/mines/data/mine_settings.tres"
const MINE_SCENE: String = "res://src/gameplay/mines/mine.tscn"
const SOURCE_DIRS: Array[String] = ["res://src/gameplay/mines"]
const SOURCE_FILES: Array[String] = ["res://src/ui/hud/mine_count.gd", "res://src/ui/hud/player_notice.gd"]

## This scenario makes every choice itself, with its own keys, on the build as it ships, with the Mines, the Turrets, the
## Flag Walls and their side spots, the swap and the view from above.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const MINES: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 30, &"buggy": 30, &"truck": 30, &"gyrocopter": 30}
## Simulated seconds: the lays, the arming waits, the runs and the Rounds.
const WATCHDOG_SECONDS: float = 2400.0
## The story's values, the test inputs of mines_data.
const ARMING_SECONDS: float = 3.0
const BLINK_SECONDS: float = 0.5
const LIT_FRACTION: float = 0.5
const TRIGGER_RADIUS: float = 0.8
const APPROACH: float = 11.0
const OPEN_MASK: int = 97
const PROBE_FLOOR: float = 0.1
const PROBE_TOP: float = 20.0
const FLASH_SECONDS: float = 0.3
const REFUSAL_SECONDS: float = 1.5
const TRUCK_LOAD: int = 5
const DROP: Vector3 = Vector3(0.0, 0.0, 3.4)
const TEXTS: Array[String] = ["Mines %d / %d", "No Mines in or near a Base", "No room for a Mine here", "No Mines left"]
## The combinations the keyboard-ghosting tool lists for the lay keys (Story 014 AC-8).
const GHOST_ROWS: Array[String] = ["P1 throttle+left+right+lay_mine", "P2 throttle+left+right+lay_mine",
	"P1 throttle+right+fire+lay_mine", "P2 throttle+left+fire+lay_mine", "P1 throttle+lay_mine / P2 throttle+lay_mine"]
## What UnitStats.first_problem() and MineSettings.first_problem() say of a Truck with no drop point and of settings
## with no open-ground layer.
const NO_DROP_PROBLEM: String = "mine_drop_offset is zero while mine_capacity is above zero"
const NO_MASK_PROBLEM: String = "open_ground_mask names no layer"
## Number literals the lint lets through: the integers 0 and 1 and the floats 0.0, 1.0 and 2.0 (a half is a half).
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0, 2.0]

var _k: Kit14
var _q: Object
var _measured: PackedStringArray = []


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. MINES_ONLY (an environment
## variable of a run by hand) names modules, "lay,arm", to run on their own.
func run(harness: Node) -> void:
	_k = Kit14.new(harness)
	_q = _k.w.s.q
	await _k.w.s.both_play()
	_mines_data()
	_mines_lint()
	_bad_data()
	var only: String = OS.get_environment("MINES_ONLY")
	for module: GDScript in [Lay, Layout, Arm, Kill, Where, Extra, Stay, Rounds, Doubles]:
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("mines_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		await _k.clear_mines()
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.is_empty() and warnings.is_empty(), "the engine logged %d errors and %d warnings: %s %s" % [errors.size(), warnings.size(), errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: Mines laid, armed, blinked, spent, freed by the restart, refused, placed by the tool and destroyed under Units, Shots and Turrets" % [errors.size(), warnings.size()])
	_k.close()
	harness.finish("mines=7 %s" % " ".join(_measured))


## mines_data (AC-1, AC-2, AC-3, AC-5, AC-8, AC-9): what the data, the scenes, the Input Map, the texts and the README
## say, each against the story's numbers.
func _mines_data() -> void:
	var problems: PackedStringArray = []
	var settings: MineSettings = load(SETTINGS_PATH) as MineSettings
	_q.kit.need(problems, settings != null and settings.first_problem().is_empty(), "the settings do not load or are unusable: %s" % (settings.first_problem() if settings != null else "null"))
	if settings != null:
		_q.kit.need(problems, is_equal_approx(settings.arming_seconds, ARMING_SECONDS) and is_equal_approx(settings.blink_period_seconds, BLINK_SECONDS) and is_equal_approx(settings.blink_lit_fraction, LIT_FRACTION), "arming %s, blink %s, lit %s" % [settings.arming_seconds, settings.blink_period_seconds, settings.blink_lit_fraction])
		_q.kit.need(problems, is_equal_approx(settings.trigger_radius, TRIGGER_RADIUS) and is_equal_approx(settings.approach_past_zone, APPROACH) and settings.open_ground_mask == OPEN_MASK, "radius %s, approach %s, mask %d" % [settings.trigger_radius, settings.approach_past_zone, settings.open_ground_mask])
		_q.kit.need(problems, is_equal_approx(settings.probe_floor, PROBE_FLOOR) and is_equal_approx(settings.probe_top, PROBE_TOP) and is_equal_approx(settings.flash_seconds, FLASH_SECONDS), "probe %s to %s, flash %s" % [settings.probe_floor, settings.probe_top, settings.flash_seconds])
	var loads: PackedStringArray = []
	for index: int in _q.controller.unit_types().size():
		var stats: UnitStats = _q.units.stats(index)
		loads.append("%s=%d" % [stats.type_id, stats.mine_capacity])
		var truck: bool = index == Quick.TRUCK
		_q.kit.need(problems, stats.mine_capacity == (TRUCK_LOAD if truck else 0), "%s carries %d" % [stats.type_id, stats.mine_capacity])
		_q.kit.need(problems, (stats.mine_drop_offset == DROP) if truck else true, "the Truck's drop offset is %s" % stats.mine_drop_offset)
	var scratch: Node3D = Node3D.new()
	_q.harness.add_child(scratch)
	var first: Mine = (load(MINE_SCENE) as PackedScene).instantiate() as Mine
	var second: Mine = (load(MINE_SCENE) as PackedScene).instantiate() as Mine
	scratch.add_child(first)
	scratch.add_child(second)
	var disc: CylinderMesh = (first.body as MeshInstance3D).mesh as CylinderMesh
	var drawn: float = disc.top_radius * first.body.scale.x
	var top: float = first.body.position.y + disc.height / 2.0
	var bottom: float = first.body.position.y - disc.height / 2.0
	_q.kit.need(problems, is_equal_approx(drawn, TRIGGER_RADIUS) and is_equal_approx((first.trigger_shape.shape as CylinderShape3D).radius, TRIGGER_RADIUS), "the disc is drawn %.3f m wide in radius, the trigger %.3f" % [drawn, (first.trigger_shape.shape as CylinderShape3D).radius])
	_q.kit.need(problems, top >= 0.03 and bottom >= 0.02, "the disc spans %.3f to %.3f m above the ground" % [bottom, top])
	_q.kit.need(problems, first.is_in_group(&"mines") and first.collision_layer == 0 and first.collision_mask == 2 and first.monitoring, "the Mine's group %s, layer %d, mask %d" % [first.is_in_group(&"mines"), first.collision_layer, first.collision_mask])
	_q.kit.need(problems, first.trigger_shape.shape != second.trigger_shape.shape and (first.body as MeshInstance3D).mesh == (second.body as MeshInstance3D).mesh, "two Mines share a trigger shape or do not share the disc's mesh")
	_q.kit.need(problems, not first.flash.visible and ((first.flash as MeshInstance3D).mesh.material as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "the flash is shown or shaded")
	scratch.queue_free()
	var keys: PackedStringArray = []
	for player: int in 2:
		var action: StringName = &"p1_lay_mine" if player == 0 else &"p2_lay_mine"
		var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
		var key: InputEventKey = events[0] as InputEventKey if events.size() == 1 else null
		_q.kit.need(problems, key != null and key.physical_keycode == Kit14.LAY_KEYS[player], "%s is bound to %s" % [action, events])
		keys.append(OS.get_keycode_string(key.physical_keycode) if key != null else "none")
		for other: StringName in InputMap.get_actions():
			if other != action and String(other).begins_with("p"):
				for event: InputEvent in InputMap.action_get_events(other):
					_q.kit.need(problems, not (event is InputEventKey and (event as InputEventKey).physical_keycode == Kit14.LAY_KEYS[player]), "%s shares the lay key of Player %d" % [other, player + 1])
	var notice: PlayerNotice = _k.notice(0)
	var label: MineCount = _k.count_label(0)
	_q.kit.need(problems, notice.none_left_text == TEXTS[3] and notice.near_base_text == TEXTS[1] and notice.no_room_text == TEXTS[2] and is_equal_approx(notice.refusal_seconds, REFUSAL_SECONDS), "the notice texts %s, %s, %s and %s s" % [notice.none_left_text, notice.near_base_text, notice.no_room_text, notice.refusal_seconds])
	_q.kit.need(problems, label.format == TEXTS[0] and _k.notice(1).none_left_text == TEXTS[3] and _k.count_label(1).format == TEXTS[0], "the Mines line's format is '%s'" % label.format)
	for text: String in TEXTS:
		var key_names: PackedStringArray = keys.duplicate()
		key_names.append_array(PackedStringArray(["Press", "key"]))
		for key_name: String in key_names:
			_q.kit.need(problems, not text.contains(key_name) or key_name.length() < 2, "the text '%s' names a key (%s)" % [text, key_name])
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	_q.kit.need(problems, readme.contains("| Lay a Mine (Truck) | E | Comma |"), "the README's Controls table has no row naming the lay keys")
	var ghost: GDScript = load("res://tools/evidence/input_ghosting_check.gd") as GDScript
	var names: Array = []
	for row: Dictionary in ghost.get_script_constant_map()["COMBINATIONS"]:
		names.append(row["name"])
	for row_name: String in GHOST_ROWS:
		_q.kit.need(problems, names.has(row_name), "the keyboard-ghosting tool lacks '%s'" % row_name)
	_measured.append("loads=%s" % ",".join(loads))
	_q.kit.verdict("mines_data", problems, "mine_settings.tres holds arming 3 s, a blink of 0.5 s lit for half, a trigger of 0.8 m, an approach of 11 m, the open-ground mask 97 probed 0.1 to 20 m and a 0.3 s flash; the Truck carries 5 and drops 3.4 m behind its origin and the other types carry none (%s); a Mine is an Area3D on no layer watching units alone, in the group mines, with its own trigger shape, a disc drawn 0.8 m in radius 0.03 to 0.07 m above the ground sharing one mesh and a hidden unshaded flash; p1_lay_mine is E and p2_lay_mine is Comma, used by no other action; the four texts are in the scenes and name no key; the README's Controls table names the keys; the ghosting tool lists the five lay-key combinations" % ", ".join(loads))


## mines_lint (AC-9): no number is a constant in code. Every code line of the Mines' scripts, the Mines line and the notice,
## comments, quoted text and the editor's range hints (@export_range(...)) taken out, is read for number literals other than LINT_INTEGERS and LINT_FLOATS.
func _mines_lint() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
	var quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
	var hint: RegEx = RegEx.create_from_string(r"@export_range\([^)]*\)")
	var paths: PackedStringArray = []
	for dir: String in SOURCE_DIRS:
		for file: String in DirAccess.get_files_at(dir):
			if file.ends_with(".gd"):
				paths.append(dir.path_join(file))
	paths.append_array(PackedStringArray(SOURCE_FILES))
	var lines: int = 0
	for path: String in paths:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = hint.sub(quoted.sub(line, "", true).get_slice("#", 0), "", true)
			lines += 0 if code.strip_edges().is_empty() else 1
			for hit: RegExMatch in literal.search_all(code):
				var text: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(text)) if text.contains(".") else LINT_INTEGERS.has(int(text))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [path.get_file(), text, code.strip_edges()])
			for type_name: String in ["motorbike", "buggy", "truck", "gyrocopter"]:
				_q.kit.need(problems, not code.contains("&\"%s\"" % type_name) and not code.contains("type_id =="), "%s names a Unit type: %s" % [path.get_file(), code.strip_edges()])
	_measured.append("lint_lines=%d" % lines)
	_q.kit.verdict("mines_lint", problems, "%d code lines of the Mines' scripts, the Mines line and the notice hold no number other than 0, 1, 0.0, 1.0 and 2.0 (a half), and no branch names a Unit type" % lines)


## bad_data_refused (AC-9; the engine review's finding 2): a forgotten line of data is one named refusal, never a silent
## change of the rule. A Truck whose .tres lost its drop point would lay every Mine under its own origin, and settings
## whose .tres lost the open-ground mask would read every place as open ground: first_problem() names both, and passes
## the shipped data and a type that carries no Mine.
func _bad_data() -> void:
	var problems: PackedStringArray = []
	var truck: UnitStats = _q.units.stats(Quick.TRUCK)
	var no_drop: UnitStats = truck.duplicate() as UnitStats
	no_drop.mine_drop_offset = Vector3.ZERO
	var none_carried: UnitStats = no_drop.duplicate() as UnitStats
	none_carried.mine_capacity = 0
	_q.kit.need(problems, truck.first_problem().is_empty() and none_carried.first_problem().is_empty(), "the shipped Truck reads '%s' and a type with no Mines and no drop point '%s'" % [truck.first_problem(), none_carried.first_problem()])
	_q.kit.need(problems, no_drop.first_problem() == NO_DROP_PROBLEM, "a Truck with no drop point reads '%s'" % no_drop.first_problem())
	var no_mask: MineSettings = (load(SETTINGS_PATH) as MineSettings).duplicate() as MineSettings
	no_mask.open_ground_mask = 0
	_q.kit.need(problems, no_mask.first_problem() == NO_MASK_PROBLEM, "settings with no open-ground layer read '%s'" % no_mask.first_problem())
	_q.kit.verdict("bad_data_refused", problems, "UnitStats.first_problem(), which MatchController asks of every type before a Round and Unit.spawn() of the type it is handed, refuses a Truck whose drop point is zero ('%s') and passes the shipped Truck and a type that carries no Mine; MineSettings.first_problem(), which every Mine and MineLayer asks in _ready(), refuses an open-ground mask that names no layer ('%s')" % [NO_DROP_PROBLEM, NO_MASK_PROBLEM])
