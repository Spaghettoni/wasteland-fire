extends RefCounted
## What the tokens_data scenario needs beyond token_kit.gd: the refusals of MatchController.begin()
## tried on a throwaway controller handed the LIVE Units, Bases and cameras (variants(), refuse():
## ONE error that names the problem, no signal, nothing moved, no connection added, no state left),
## and the lint of Token literals (scan(), flags(), self_test(); tokens_data.gd says what it
## covers). Make one with TokensDataKit.new(harness, tokens). Tooling only: nothing under src/
## depends on this file.

## The runner this kit is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared Story 008 helpers (token_kit.gd): the live Units, Bases, cameras, record and log.
const Tokens: GDScript = preload("res://tools/evidence/split_screen/token_kit.gd")
## A key the stock lists that no Unit type has: the typo of the Motorbike's id.
const UNKNOWN_KEY: StringName = &"motorbyke"
## The name of the second Unit type that can carry the Flag, in the two-carrier refusal.
const SECOND_CARRIER: String = "Second carrier"
## The folders the lint reads, where the Token logic and its display live (AC-9: no count is a
## constant in code).
const LINT_DIRS: PackedStringArray = ["res://src/gameplay/match", "res://src/ui/hud"]
## The integer literals the lint lets through on any line (0 and 1 comparisons).
const LINT_ALLOWED: Array[int] = [0, 1]
## Lines the lint must flag (true) or pass (false): it is shown to see a hardcoded count.
const LINT_CASES: Dictionary[String, bool] = {"return count_of(player_index, _carrier_id) <= 5": true,
	"counts[stats.type_id] = 5": true, "const MOTORBIKE_TOKENS: int = 5": true,
	"var left: int = tokens_left(0, 2) + 3": true, "return count_of(player_index, _carrier_id) <= 0": false,
	"if tokens_left(player, type) > 1:": false, "# a loss at tokens_left(player, type) >= 5": false,
	"push_error(\"count_of is 5\")": false, "const SPAWN_SETTLE_TICKS: int = 3": false,
	"if tokens_format.count(\"%\") < 2:": false}

## The token kit this kit is handed.
var tk: Tokens
## The runner.
var harness: Harness
var _emitted: Array[String] = []
var _quoted: RegEx = RegEx.create_from_string(r"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'")
var _literal: RegEx = RegEx.create_from_string(r"(?<![\w.])\d+(?![\w.])")
var _accessor: RegEx = RegEx.create_from_string(r"\b(?:tokens_left|count_of|can_choose|has_lost|take|counts|_counts|stock|token_stock|_token_stock|_ledger|TokenLedger|TokenStock|carrier_type_index)\b")
var _declaration: RegEx = RegEx.create_from_string(r"(?i)^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:const|var)\s+\w*(?:token|stock|count)")


## Keeps the runner and the token kit (the live Units, Bases, cameras, record and engine log).
func _init(harness_node: Node, tokens: Tokens) -> void:
	harness = harness_node as Harness
	tk = tokens


## The refusals as {label, stock, rules, wants}: `fixture` (type_id to count) changed one way each,
## the first being the Motorbike at 0. wants are texts the one error must hold, read from the data.
## A variant that changes the types gets a copy of the rules with its own unit_types.
func variants(fixture: Dictionary) -> Array[Dictionary]:
	var live: MatchRules = tk.controller.rules
	var types: Array[UnitStats] = live.unit_types
	var carrier: UnitStats = types[tk.carrier_index()]
	var other: UnitStats = types.filter(func(stats: UnitStats) -> bool: return not stats.can_carry)[0]
	var doubled: Array[UnitStats] = types.duplicate()
	doubled.append(other.duplicate() as UnitStats)
	var second: UnitStats = other.duplicate() as UnitStats
	second.type_id = &"second_carrier"
	second.display_name = SECOND_CARRIER
	second.can_carry = true
	var pair: Array[UnitStats] = types.duplicate()
	pair.append(second)
	var nameless: UnitStats = other.duplicate() as UnitStats
	nameless.type_id = &""
	var blank: Array[UnitStats] = types.duplicate()
	blank[types.find(other)] = nameless
	var uncarried: Array[UnitStats] = []
	uncarried.assign(types.filter(func(stats: UnitStats) -> bool: return not stats.can_carry))
	var no_key: Dictionary = {carrier.type_id: null}
	return [_variant("Motorbike at 0", {carrier.type_id: 0}, fixture, live, [carrier.display_name]),
		_variant("no stock", null, fixture, live, ["Token stock"]),
		_variant("negative count", {other.type_id: -1}, fixture, live, [String(other.type_id)]),
		_variant("carrier key missing", no_key, fixture, live, [carrier.display_name]),
		_variant("no type can carry", no_key, fixture, _rules_of(uncarried), ["carry"]),
		_variant("unknown key", {UNKNOWN_KEY: 3}, fixture, live, [String(UNKNOWN_KEY)]),
		_variant("duplicate type_id", {}, fixture, _rules_of(doubled), [String(other.type_id), "[%d]" % types.find(other), "[%d]" % types.size()]),
		# The stock has no key for it: held, the key would be refused first, as one no type has.
		_variant("type without type_id", {other.type_id: null}, fixture, _rules_of(blank), ["no type_id", "unit_types[%d]" % types.find(other), other.display_name]),
		_variant("two carrier types", {}, fixture, _rules_of(pair), [carrier.display_name, SECOND_CARRIER])]


## begin() with the variant's stock and rules, twice, on a throwaway controller in the tree that is
## given the live Units, Bases and cameras; then judged. {problems (empty when the refusal is as
## asked), message (the error of the first call), errors (how many each call logged), signals (how
## many the throwaway emitted), listened (how many signals it was listened to on)}. The second call
## shows that the first left no state behind: it refuses in the same words.
func refuse(variant: Dictionary) -> Dictionary:
	var before: Array = tk.units.units.map(_probe)
	var seen: int = tk.events.size()
	var warnings: int = tk.engine_log.warnings.size()
	var node: MatchController = MatchController.new()
	node.name = &"Throwaway"
	node.rules = variant["rules"]
	harness.add_child(node)
	var listened: int = _listen(node)
	var first: Array[String] = _begin(node, variant)
	var second: Array[String] = _begin(node, variant)
	var after: Array = tk.units.units.map(_probe)
	var state: Array = [node.is_choosing(0), node.is_choosing(1), node.is_alive(0), node.is_alive(1), node.is_round_over(), node.tokens_left(0, 0), node.carrier_type_index()]
	harness.remove_child(node)
	node.free()
	var problems: PackedStringArray = []
	_expect(problems, first.size() == 1 and second.size() == 1, "%d errors, then %d on the repeat, instead of one each: %s %s" % [first.size(), second.size(), first, second])
	_expect(problems, first == second, "the repeat refused in other words: %s" % [second])
	for want: String in variant["wants"]:
		_expect(problems, not first.is_empty() and first[0].contains(want), "the error does not name '%s'" % want)
	_expect(problems, listened > 0 and tk.engine_log.warnings.size() == warnings and _emitted.is_empty(), "it warned or emitted %s (listening on %d signals)" % [_emitted, listened])
	_expect(problems, after == before and tk.events.size() == seen, "a live Unit or the live controller changed: %s -> %s" % [before, after])
	_expect(problems, state == [false, false, false, false, false, 0, -1], "the throwaway began something: choosing/alive/over/tokens/carrier %s" % [state])
	return {"problems": problems, "message": first[0] if first.size() == 1 else "", "errors": [first.size(), second.size()], "signals": _emitted.size(), "listened": listened}


## The number of connections on each live Unit's destroyed signal now, Player 1 first.
func links() -> Array:
	return tk.units.units.map(func(unit: Unit) -> int: return unit.destroyed.get_connections().size())


## Reads the lint's folders: {files, code (lines with code), literals (integer literals other than
## 0 and 1 in code), flagged (file:line of each that sits on a line which names a Token count),
## others (file=value of each literal that does not)}.
func scan() -> Dictionary:
	var found: Dictionary = {"files": 0, "code": 0, "literals": 0}
	var flagged: PackedStringArray = []
	var others: PackedStringArray = []
	for dir: String in LINT_DIRS:
		for path: String in _scripts_under(dir):
			found["files"] += 1
			var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
			for index: int in lines.size():
				var code: String = _code_of(lines[index])
				var big: PackedStringArray = _big_literals(code)
				found["code"] += 0 if code.strip_edges().is_empty() else 1
				found["literals"] += big.size()
				if flags(lines[index]):
					flagged.append("%s:%d" % [path.get_file(), index + 1])
				for value: String in big:
					others.append("%s=%s" % [path.get_file(), value])
	found["flagged"] = flagged
	found["others"] = others
	return found


## True when the line, comments and quoted text left out, holds an integer literal other than 0 and
## 1 and names a Token count (tokens_left, count_of, a counts member, a stock ... or a declaration
## whose name holds token, stock or count).
func flags(line: String) -> bool:
	var code: String = _code_of(line)
	return not _big_literals(code).is_empty() and (_accessor.search(code) != null or _declaration.search(code) != null)


## The lines of LINT_CASES that flags() answers wrongly (empty when the lint sees what it must).
func self_test() -> PackedStringArray:
	var wrong: PackedStringArray = []
	for line: String in LINT_CASES:
		if flags(line) != LINT_CASES[line]:
			wrong.append(line)
	return wrong


## One begin() of the throwaway with the variant's stock: the texts of the errors it logged.
func _begin(node: MatchController, variant: Dictionary) -> Array[String]:
	var logged: int = tk.engine_log.errors.size()
	node.begin(tk.units.units, tk.units.bases, tk.units.cameras, variant["stock"])
	var found: Array[String] = []
	found.assign(tk.engine_log.errors.slice(logged))
	return found


## Gives a throwaway controller a listener on every signal it declares itself (not Node's) and
## returns how many that is.
func _listen(node: MatchController) -> int:
	_emitted.clear()
	var listened: int = 0
	for entry: Dictionary in node.get_signal_list():
		if not ClassDB.class_has_signal(&"Node", entry["name"]):
			var note: Callable = _emitted.append.bind(String(entry["name"]))
			node.connect(entry["name"], note.unbind(entry["args"].size()) if entry["args"].size() > 0 else note)
			listened += 1
	return listened


## A copy of the live rules with its own unit_types (the shared array is never written).
func _rules_of(types: Array[UnitStats]) -> MatchRules:
	var copy: MatchRules = tk.controller.rules.duplicate() as MatchRules
	copy.unit_types = types
	return copy


## One refusal: the fixture changed by `changes` (null removes a key; null instead: no stock).
func _variant(label: String, changes: Variant, fixture: Dictionary, rules: MatchRules, wants: Array[String]) -> Dictionary:
	var counts: Dictionary = fixture.duplicate()
	for key: Variant in (changes if changes != null else {}):
		if changes[key] == null:
			counts.erase(key)
		else:
			counts[key] = changes[key]
	return {"label": label, "stock": Tokens.stock(counts) if changes != null else null, "rules": rules, "wants": wants}


## What a refusal must leave of a live Unit: where it is and how it is, and its destroyed links.
func _probe(unit: Unit) -> Dictionary:
	return {"at": unit.global_transform, "alive": unit.is_alive, "visible": unit.visible, "hp": unit.hit_points,
		"layers": [unit.collision_layer, unit.collision_mask], "links": unit.destroyed.get_connections().size()}


## Adds a problem unless the condition holds.
func _expect(problems: PackedStringArray, holds: bool, problem: String) -> void:
	if not holds:
		problems.append(problem)


## A line of code without its quoted text and its comment.
func _code_of(line: String) -> String:
	return _quoted.sub(line, "", true).get_slice("#", 0)


## The integer literals other than LINT_ALLOWED in a line of code, as written.
func _big_literals(code: String) -> PackedStringArray:
	var big: PackedStringArray = []
	for hit: RegExMatch in _literal.search_all(code):
		if not LINT_ALLOWED.has(int(hit.get_string())):
			big.append(hit.get_string())
	return big


## The .gd files in a folder and below it, by path.
func _scripts_under(dir: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			paths.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		paths.append_array(_scripts_under(dir.path_join(sub)))
	paths.sort()
	return paths
