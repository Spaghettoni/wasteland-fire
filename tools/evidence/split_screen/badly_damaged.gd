extends RefCounted
## Scenario badly_damaged of the split screen evidence harness (split_screen_harness.gd): a Unit at or below a
## fraction of its hit points is badly damaged (Story 017 AC-1 to AC-7), on the shipped data and Map 01 with the
## Flag Walls, the Turrets with their looks, the Mines, the swap at the own Base, the view from above and the
## explosions, every Player's act a real key event or a real Shot. This script holds the order and the engine
## noise; the modules it runs, in this order, hold the checks: badly_damaged_edges.gd (the edge by real Shots,
## a Turret's Shot: AC-1). One Round, played on after each check. Tooling only. Implements:
## production/epics/wasteland-fire/story-017-badly-damaged-units.md AC-1 to AC-7. Every number comes from the
## game's data; the scenario types only its test inputs and the story's values.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=badly_damaged

const Kit17: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_kit.gd")
const Edges: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_edges.gd")
const Speed: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_speed.gd")
const Burn: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_burn.gd")
const Ford: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_ford.gd")
const Smoke: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_smoke.gd")
const Ends: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_ends.gd")
const Round: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_round.gd")
const Turret: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_turret.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/badly_damaged_data.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the swap at the own Base,
## the view from above, the Flag Walls and their side spots, the Turrets with their looks, the Mines, the
## explosions and the badly damaged state.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 80, &"buggy": 80, &"truck": 80, &"gyrocopter": 80}
## Simulated seconds this scenario may take: every flow waits for a respawn of about 3 s.
const WATCHDOG_SECONDS: float = 3000.0
## The warning the physics engine logs when the machine is overloaded (Jolt's job system is out of jobs: "This should not happen"): a property of the load, never of the
## build, which the regression tool leaves out of the outputs it compares as well, so it is counted apart and never fails the check.
const JOLT_LOAD_WARNING: String = "Jolt Physics job system exceeded the maximum number of jobs"

var _k: Kit17
var _measured: PackedStringArray = []


## Plays the modules of the class doc, then the engine noise check and the RESULT line. The runner awaits this
## coroutine. BADLY_ONLY (an environment variable of a run by hand) names modules, "edges,speed", to run on
## their own.
func run(harness: Node) -> void:
	_k = Kit17.new(harness)
	await _k.e.t.w.s.both_play()
	_before_a_state()
	var only: String = OS.get_environment("BADLY_ONLY")
	for module: GDScript in [Edges, Speed, Burn, Ford, Smoke, Ends, Round, Turret, Data]:
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("badly_damaged_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		await _k.e.clear_mines()
		harness.release_all()
	_noise()
	_k.close()
	harness.finish("changes=%d %s" % [_k.changes.size(), " ".join(_measured)])


## no_smoke_node_before_a_state: the Round has begun, both Players have chosen and their Units spawned, and not one smoke node exists: it is
## instanced on the first tick of a state, never when a Model is built.
func _before_a_state() -> void:
	var problems: PackedStringArray = []
	_k.q.kit.need(problems, _k.smoke_nodes() == 0 and _k.smoke(0) == null and _k.smoke(1) == null and _k.changes.is_empty(), "%d smoke nodes and %d changes before any state" % [_k.smoke_nodes(), _k.changes.size()])
	_k.q.kit.verdict("no_smoke_node_before_a_state", problems, "both Players chose and spawned (%d spawns): no BadlyDamagedSmoke in the tree, none under either Unit's Model, no change signalled" % _k.q.units.spawns.size())


## no_engine_noise: the engine logged no error and no warning but the ones a check expected (a refused
## spawn, a refused note): each expected text takes one log line out, and nothing may be left.
func _noise() -> void:
	var problems: PackedStringArray = []
	var errors: Array[String] = _k.q.tokens.engine_log.errors.duplicate()
	var warnings: Array[String] = _k.q.tokens.engine_log.warnings.duplicate()
	var load_warnings: int = warnings.size()
	warnings = warnings.filter(func(line: String) -> bool: return not line.contains(JOLT_LOAD_WARNING))
	load_warnings -= warnings.size()
	_account(problems, errors, _k.e.expected_errors, "error")
	_account(problems, warnings, _k.e.expected_warnings, "warning")
	_k.q.kit.need(problems, errors.is_empty() and warnings.is_empty(), "the engine logged %d unexpected errors and %d unexpected warnings: %s %s" % [errors.size(), warnings.size(), errors, warnings])
	var left_out: String = "" if load_warnings == 0 else ", %d Jolt load warnings left out" % load_warnings
	_k.q.kit.verdict("no_engine_noise", problems, "unexpected errors=%d warnings=%d over every Round of the scenario (%d expected errors and %d expected warnings accounted for%s)" % [errors.size(), warnings.size(), _k.e.expected_errors.size(), _k.e.expected_warnings.size(), left_out])


## Takes one line out of `lines` for each expected text, adding a problem for one that was never logged.
func _account(problems: PackedStringArray, lines: Array[String], expected: Array[String], what: String) -> void:
	for wanted: String in expected:
		var found: int = -1
		for index: int in lines.size():
			if found < 0 and lines[index].contains(wanted):
				found = index
		_k.q.kit.need(problems, found >= 0, "the expected %s '%s' was never logged" % [what, wanted])
		if found >= 0:
			lines.remove_at(found)
