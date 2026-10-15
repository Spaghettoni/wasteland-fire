extends RefCounted
## The data of the Story 022 scenario ammo: AC-7. Every value is data: each type's load in its UnitStats file (100, 50, 25 and 40,
## each 20 s of fire at the type's own interval) and the full start (a share of 1.0 of a 100-Fuel tank in the four files); the
## texts ("Ammo %d / %d" and "Out of ammo") in their scenes, naming no key, and the notice's time in the notice scene; no number is
## a constant in code (a lint of the Weapon, the Ammo line and the notice), and no branch names a Unit type; a forgotten or a
## negative line of data is refused by name. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-7.

const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")

## The story's values, by type index (Motorbike, Buggy, Truck, Gyrocopter): the test inputs of this module.
const LOADS: Array[int] = [100, 50, 25, 40]
## Seconds of continuous fire a load is (R1), the share of the tank a new Unit starts with, and the tank of every type.
const LOAD_SECONDS: float = 20.0
const START_SHARE: float = 1.0
const TANK: float = 100.0
## The texts and the notice's time the story gives.
const LINE_TEXT: String = "Ammo %d / %d"
const NOTICE_TEXT: String = "Out of ammo"
const NOTICE_SECONDS: float = 1.5
## The files whose code is linted, and the number literals the lint lets through: the integers 0 and 1 and the floats 0.0, 1.0 and
## 2.0 (a half is a half).
const LINT_FILES: Array[String] = ["res://src/gameplay/combat/weapon.gd", "res://src/ui/hud/ammo_count.gd", "res://src/ui/hud/player_notice.gd"]
const LINT_INTEGERS: Array[int] = [0, 1]
const LINT_FLOATS: Array[float] = [0.0, 1.0, 2.0]
## What first_problem() says of a negative load, and what the two labels say of their forgotten data.
const NEGATIVE_PROBLEM: String = "ammo_capacity is below zero"

## Facts measured, for the RESULT line.
var measured: PackedStringArray = []
var _k: Kit22
var _q: Quick


func _init(kit: Kit22) -> void:
	_k = kit
	_q = kit.q()


func run() -> void:
	_data()
	_lint()
	_bad_data()


## What the .tres files, the scenes and the Input Map say, each against the story's numbers.
func _data() -> void:
	var problems: PackedStringArray = []
	var loads: PackedStringArray = []
	for index: int in LOADS.size():
		var stats: UnitStats = _q.units.stats(index)
		loads.append("%s=%d" % [stats.type_id, stats.ammo_capacity])
		_q.kit.need(problems, stats.ammo_capacity == LOADS[index], "%s carries %d Shots, the story says %d" % [stats.type_id, stats.ammo_capacity, LOADS[index]])
		_q.kit.need(problems, is_equal_approx(float(stats.ammo_capacity) * stats.fire_interval_seconds, LOAD_SECONDS), "%s: a load is %.2f s of fire, not %.0f" % [stats.type_id, float(stats.ammo_capacity) * stats.fire_interval_seconds, LOAD_SECONDS])
		_q.kit.need(problems, is_equal_approx(stats.spawn_fuel_fraction, START_SHARE) and is_equal_approx(stats.fuel_capacity, TANK), "%s starts with %.2f of a %.0f tank" % [stats.type_id, stats.spawn_fuel_fraction, stats.fuel_capacity])
		var file: String = FileAccess.get_file_as_string(stats.resource_path)
		_q.kit.need(problems, file.contains("ammo_capacity = %d\n" % LOADS[index]) and file.contains("spawn_fuel_fraction = 1.0\n"), "%s does not hold the lines ammo_capacity = %d and spawn_fuel_fraction = 1.0" % [stats.resource_path.get_file(), LOADS[index]])
	for player: int in Kit22.Kit.PLAYERS:
		var label: AmmoCount = _k.count_label(player)
		var notice: PlayerNotice = _k.mines().notice(player)
		_q.kit.need(problems, label != null and label.format == LINE_TEXT and label.weapon == _k.weapon(player), "Player %d's Ammo line is %s" % [player + 1, "missing" if label == null else "'%s' of %s" % [label.format, label.weapon]])
		_q.kit.need(problems, notice != null and notice.weapon == _k.weapon(player) and notice.out_of_ammo_text == NOTICE_TEXT and is_equal_approx(notice.refusal_seconds, NOTICE_SECONDS), "Player %d's notice holds weapon %s, text '%s', %s s" % [player + 1, notice.weapon if notice != null else null, notice.out_of_ammo_text if notice != null else "", notice.refusal_seconds if notice != null else 0.0])
	var readme: String = FileAccess.get_file_as_string("res://README.md")
	_q.kit.need(problems, readme.contains(NOTICE_TEXT) and readme.contains("a full load of ammo"), "the README does not tell of the notice and of the full start")
	var key_names: PackedStringArray = ["Press", "key", "Space", "Period", "Fire"]
	for text: String in [LINE_TEXT, NOTICE_TEXT]:
		for key_name: String in key_names:
			_q.kit.need(problems, not text.contains(key_name), "the text '%s' names a key (%s)" % [text, key_name])
	measured.append("loads=%s" % ",".join(loads))
	_q.kit.verdict("ammo_data", problems, "the four UnitStats files hold ammo_capacity %s (each 20 s of fire at the type's own fire_interval_seconds) and spawn_fuel_fraction 1.0 of a 100-Fuel tank; both Ammo lines hold the format 'Ammo %%d / %%d' and the Player's own Weapon, both notices the text 'Out of ammo', 1.5 s and the Player's own Weapon, in the scenes; neither text names a key; the README tells of the notice and of the full start" % ", ".join(loads))


## No number is a constant in code. Every code line of the Weapon, the Ammo line and the notice, comments, quoted text and the
## editor's range hints taken out, is read for number literals other than LINT_INTEGERS and LINT_FLOATS, and for a Unit type's name.
func _lint() -> void:
	var problems: PackedStringArray = []
	var literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?:\.\d+)?(?![\w.])")
	var quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
	var hint: RegEx = RegEx.create_from_string(r"@export_range\([^)]*\)")
	var lines: int = 0
	for path: String in LINT_FILES:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var code: String = hint.sub(quoted.sub(line, "", true).get_slice("#", 0), "", true)
			lines += 0 if code.strip_edges().is_empty() else 1
			for hit: RegExMatch in literal.search_all(code):
				var text: String = hit.get_string()
				var allowed: bool = LINT_FLOATS.has(float(text)) if text.contains(".") else LINT_INTEGERS.has(int(text))
				_q.kit.need(problems, allowed, "%s: '%s' in '%s'" % [path.get_file(), text, code.strip_edges()])
			for type_name: String in ["motorbike", "buggy", "truck", "gyrocopter"]:
				_q.kit.need(problems, not code.contains("&\"%s\"" % type_name) and not code.contains("type_id =="), "%s names a Unit type: %s" % [path.get_file(), code.strip_edges()])
			_q.kit.need(problems, not code.contains("KEY_") and not code.contains("InputEventKey"), "%s names a key: %s" % [path.get_file(), code.strip_edges()])
	measured.append("ammo_lint_lines=%d" % lines)
	_q.kit.verdict("ammo_lint", problems, "%d code lines of the Weapon, the Ammo line and the notice hold no number other than 0, 1, 0.0, 1.0 and 2.0 (a half), no Unit type's name and no key" % lines)


## A forgotten or a negative line of data is one named refusal, never a silent change of the rule: a negative load is refused by
## UnitStats.first_problem() (which MatchController asks of every type and Unit.spawn() of the type it is handed), and the Ammo
## line and the notice refuse a missing Weapon, format or text and stay hidden.
func _bad_data() -> void:
	var problems: PackedStringArray = []
	var shipped: UnitStats = _q.units.stats(Quick.TRUCK)
	var negative: UnitStats = shipped.duplicate() as UnitStats
	negative.ammo_capacity = -1
	var none: UnitStats = shipped.duplicate() as UnitStats
	none.ammo_capacity = 0
	_q.kit.need(problems, shipped.first_problem().is_empty() and none.first_problem().is_empty(), "the shipped Truck reads '%s' and a type with no load '%s'" % [shipped.first_problem(), none.first_problem()])
	_q.kit.need(problems, negative.first_problem() == NEGATIVE_PROBLEM, "a negative load reads '%s'" % negative.first_problem())
	var line: AmmoCount = AmmoCount.new()
	var first: String = line._first_problem()
	line.weapon = _k.weapon(0)
	var second: String = line._first_problem()
	line.format = "Ammo %d"
	var third: String = line._first_problem()
	line.format = LINE_TEXT
	var fourth: String = line._first_problem()
	line.free()
	_q.kit.need(problems, first == "weapon is not assigned" and second.begins_with("format is not set") and third.contains("does not hold one %d placeholder") and fourth.is_empty(), "the Ammo line reads '%s', '%s', '%s' and '%s'" % [first, second, third, fourth])
	var real: PlayerNotice = _k.mines().notice(0)
	var notice: PlayerNotice = PlayerNotice.new()
	notice.match_controller = real.match_controller
	notice.player_index = real.player_index
	notice.message = real.message
	notice.weapon = _k.weapon(0)
	var no_text: String = notice._first_problem()
	notice.out_of_ammo_text = NOTICE_TEXT
	var no_time: String = notice._first_problem()
	notice.refusal_seconds = NOTICE_SECONDS
	var fine: String = notice._first_problem()
	notice.free()
	_q.kit.need(problems, no_text.begins_with("out_of_ammo_text is not set") and no_time.begins_with("refusal_seconds is not above zero") and fine.is_empty(), "the notice reads '%s', '%s' and '%s'" % [no_text, no_time, fine])
	_q.kit.verdict("bad_data_refused", problems, "UnitStats.first_problem() refuses a negative ammo_capacity ('%s') and passes the shipped Truck and a type with no load; the Ammo line refuses a missing Weapon, a missing format and a format with the wrong placeholders, and the notice a Weapon without its text and without its time, each by name, and both pass with their data" % NEGATIVE_PROBLEM)
