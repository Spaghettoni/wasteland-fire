extends RefCounted
## Scenario explosions of the split screen evidence harness (split_screen_harness.gd): the explosion a destroyed
## Unit plays (Story 016 AC-1 to AC-9), on the shipped data and Map 01 with the Flag Walls, the Turrets with their
## looks, the Mines, the swap at the own Base and the view from above, every Player's act a real key event. This
## script holds the order and the engine noise; the modules it runs, in this order, hold the checks:
## explosions_none.gd (what plays none: the Round's start, a Swap, a respawn, a second hit, a falling Structure, a
## refused note, the benches of R: AC-2), explosions_data.gd (the shipped scene and its hook, the data read back, bad
## settings refused, the lint: AC-9), explosions_causes.gd (every way of destroying a Unit, every type it can happen to:
## AC-1, AC-4, AC-5's size, AC-6), explosions_double.gd (a Mine and a Shot on one Unit in one tick: AC-1),
## explosions_where.gd (where it stands, over cover and a cliff, and that it stays: AC-4), explosions_picture.gd (what it
## is made of and each piece's ticks: AC-3, AC-5, AC-9), explosions_through.gd (a Unit, a Shot and a Flag go through it:
## AC-3) and explosions_round.gd (the Round with it playing, the pause, R: AC-2, AC-7). One Round, played on after each
## check. Tooling only. Implements: production/epics/wasteland-fire/story-016-unit-explosions.md AC-1 to AC-9. Every
## number comes from the game's data; the scenario types only its test inputs and the story's values.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=explosions

const Kit16: GDScript = preload("res://tools/evidence/split_screen/explosions_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/explosions_data.gd")
const Causes: GDScript = preload("res://tools/evidence/split_screen/explosions_causes.gd")
const Nones: GDScript = preload("res://tools/evidence/split_screen/explosions_none.gd")
const Where: GDScript = preload("res://tools/evidence/split_screen/explosions_where.gd")
const Picture: GDScript = preload("res://tools/evidence/split_screen/explosions_picture.gd")
const Through: GDScript = preload("res://tools/evidence/split_screen/explosions_through.gd")
const Double: GDScript = preload("res://tools/evidence/split_screen/explosions_double.gd")
const Rounds: GDScript = preload("res://tools/evidence/split_screen/explosions_round.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the swap at the own Base,
## the view from above, the Flag Walls and their side spots, the Turrets with their looks, the Mines and the
## explosions.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 80, &"buggy": 80, &"truck": 80, &"gyrocopter": 80}
## Simulated seconds this scenario may take: every flow waits for a respawn of about 3 s.
const WATCHDOG_SECONDS: float = 3000.0

var _k: Kit16
var _measured: PackedStringArray = []


## Plays the modules of the class doc, then the engine noise check and the RESULT line. The runner awaits this
## coroutine. EXPLOSIONS_ONLY (an environment variable of a run by hand) names modules, "causes,none", to run on
## their own.
func run(harness: Node) -> void:
	_k = Kit16.new(harness)
	await _k.t.w.s.both_play()
	var only: String = OS.get_environment("EXPLOSIONS_ONLY")
	for module: GDScript in [Nones, Data, Causes, Double, Where, Picture, Through, Rounds]:
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("explosions_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		await _k.clear_mines()
	_noise()
	_k.close()
	harness.finish("explosions=%d %s" % [_k.blasts.size(), " ".join(_measured)])


## no_engine_noise: the engine logged no error and no warning but the ones a check expected (a refused scene, a
## refused note): each expected text takes one log line out, and nothing may be left.
func _noise() -> void:
	var problems: PackedStringArray = []
	var errors: Array[String] = _k.q.tokens.engine_log.errors.duplicate()
	var warnings: Array[String] = _k.q.tokens.engine_log.warnings.duplicate()
	_account(problems, errors, _k.expected_errors, "error")
	_account(problems, warnings, _k.expected_warnings, "warning")
	_k.q.kit.need(problems, errors.is_empty() and warnings.is_empty(), "the engine logged %d unexpected errors and %d unexpected warnings: %s %s" % [errors.size(), warnings.size(), errors, warnings])
	_k.q.kit.verdict("no_engine_noise", problems, "unexpected errors=%d warnings=%d over every Round of the scenario (%d expected errors and %d expected warnings accounted for), with %d Explosions played" % [errors.size(), warnings.size(), _k.expected_errors.size(), _k.expected_warnings.size(), _k.blasts.size()])


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
