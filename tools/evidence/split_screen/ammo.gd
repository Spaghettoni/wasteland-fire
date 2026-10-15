extends RefCounted
## Scenario ammo of the split screen evidence harness (split_screen_harness.gd): a load of ammunition per Unit type and a
## full start for every new Unit, Story 022 AC-1 to AC-7, played with real keys on the shipped data and Map 01. This script
## files the whole run's no_engine_noise; the modules it runs, in this order, hold the rest: ammo_load.gd (the whole load
## of each type at its cadence, then nothing: AC-1). One Round, played on after each check; a module that ends a Round
## presses R before it ends, and modules_leave_a_fresh_round fails if one ends otherwise. AMMO_ONLY=load (an environment
## variable of a run by hand) runs named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-022-ammo-and-full-start.md AC-1 to AC-7. Every number comes from the game's data;
## the scenario types only its test inputs and the story's values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo

const Kit22: GDScript = preload("res://tools/evidence/split_screen/ammo_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/ammo_data.gd")
const Load: GDScript = preload("res://tools/evidence/split_screen/ammo_load.gd")
const Empty: GDScript = preload("res://tools/evidence/split_screen/ammo_empty.gd")
const Start: GDScript = preload("res://tools/evidence/split_screen/ammo_start.gd")
const Deaths: GDScript = preload("res://tools/evidence/split_screen/ammo_deaths.gd")
const Line: GDScript = preload("res://tools/evidence/split_screen/ammo_line.gd")
const Notice: GDScript = preload("res://tools/evidence/split_screen/ammo_notice.gd")
const Apart: GDScript = preload("res://tools/evidence/split_screen/ammo_apart.gd")
const Rearm: GDScript = preload("res://tools/evidence/split_screen/ammo_rearm.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the ammunition and the full start, the
## crash, the Heights, the Wall Panels of every Base, Garage and field wall, the Turrets with their looks, the Mines, the Flag
## Walls and their side spots, the explosions, the badly damaged state, the swap and the view from above.
const OWN_CHOICE: bool = true
const OWN_BASE_SWAP: bool = true
const SHIPPED_CAMERA: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const TURRET_LOOKS: bool = true
const MINES: bool = true
const EXPLOSIONS: bool = true
const BADLY_DAMAGED: bool = true
const WALL_PANELS: bool = true
const GARAGE_SCRAP_PANELS: bool = true
const HEIGHTS: bool = true
const GYRO_CRASH: bool = true
const AMMO: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the loads fired down, the respawns, the Rounds.
const WATCHDOG_SECONDS: float = 4000.0

var _k: Kit22
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. AMMO_ONLY (an environment
## variable of a run by hand) names modules, "load,empty", to run on their own.
func run(harness: Node) -> void:
	_k = Kit22.new(harness)
	_q = _k.q()
	await _k.swap().play(0, Quick.TRUCK)
	await _k.swap().play(1, Quick.GYROCOPTER)
	_k.mines().make_arena()
	var selected: PackedStringArray = OS.get_environment("AMMO_ONLY").split(",", false)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	for module: GDScript in _modules():
		var wanted: bool = selected.is_empty()
		for part: String in selected:
			wanted = wanted or module.resource_path.ends_with("ammo_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_q.harness.release_all()
		await _k.mines().clear_mines()
		var controller: MatchController = _k.swap().controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.k.flags().carrying(0) and not _k.k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.k.flags().carrying(0), _k.k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("ammo_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: loads fired down by every type, guns pressed empty, new Units after every kind of destruction and every Swap, Mines laid beside empty guns, a Turret firing past any load" % [errors.size(), warnings.size()])
	_k.mines().free_arena()
	_k.close()
	harness.finish("ammo=1 %s" % " ".join(_measured))


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Start, Data, Load, Empty, Deaths, Line, Notice, Apart, Rearm]
