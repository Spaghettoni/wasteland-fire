extends RefCounted
## Scenario ammo_buildings of the split screen evidence harness (split_screen_harness.gd): the ammunition buildings and no Mines at the
## supply zones, Story 024 AC-1 to AC-5, played with real keys on the shipped data and Map 01. This script files the whole run's
## no_engine_noise; the modules it runs, in this order, hold the rest: ammo_buildings_data.gd (every value is data, the buildings and
## zones in the scene, the lists handed on: AC-1, AC-5), _places.gd (the places and clearances, the Turrets' reach: AC-1), _cover.gd (the
## building stops ground Units and every kind of Shot, blocks a Turret's sight ray, takes no damage, and the Gyrocopter flies over it:
## AC-1), _look.gd (the marking, the views, the kinds told apart: AC-1), _measure.gd (the fill, the noise and the latency the story
## asks to measure first), _rate.gd (the fill time of every type at every ammunition zone, ammo only: AC-2), _stopped.gd (what counts as
## stopped: AC-2), _both.gd (both Players at once, either building, a zone never runs dry: AC-2), _gyro.gd (the Gyrocopter from its
## Base: AC-3), _lifecycle.gd (a Unit destroyed in a zone, the pause, R: AC-2) and _mines.gd (no Mine at any of the four zones: AC-4).
## One Round, played on after each check; a module that ends a Round presses R before it ends, and modules_leave_a_fresh_round fails if
## one ends otherwise. AMMOB_ONLY=data,rate (an environment variable of a run by hand) runs named modules alone. Tooling only.
## Implements: production/epics/wasteland-fire/story-024-ammunition-buildings.md AC-1 to AC-5. Every number comes from the game's data;
## the scenario types only its test inputs and the story's values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=ammo_buildings

const Kit24: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Rate: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_rate.gd")
const Stopped: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_stopped.gd")
const Both: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_both.gd")
const Gyro: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_gyro.gd")
const Mines: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_mines.gd")
const Cover: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_cover.gd")
const Places: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_places.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_data.gd")
const Lifecycle: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_lifecycle.gd")
const Look: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_look.gd")
const Measure: GDScript = preload("res://tools/evidence/split_screen/ammo_buildings_measure.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the ammunition buildings and the Fuel
## building, the ammunition and the full start, the crash, the Heights, the Wall Panels of every Base, Garage and field wall, the
## Turrets with their looks, the Mines, the Flag Walls and their side spots, the explosions, the badly damaged state, the swap and the
## view from above.
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
const FUEL_BUILDING: bool = true
const AMMO_BUILDINGS: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 80, &"buggy": 80, &"truck": 80, &"gyrocopter": 80}
## Simulated seconds: the loads fired away (20 s each), the fills, the stays, the Rounds.
const WATCHDOG_SECONDS: float = 6000.0

var _k: Kit24
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors and warnings this script causes on purpose, for the noise check.
var _expected_errors: int = 0
var _expected_warnings: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. AMMOB_ONLY (an environment variable of
## a run by hand) names modules, "measure,rate", to run on their own.
func run(harness: Node) -> void:
	_k = Kit24.new(harness)
	_q = _k.q()
	await _k.a().swap().play(0, Quick.MOTORBIKE)
	await _k.a().swap().play(1, Quick.MOTORBIKE)
	_k.mines().make_arena()
	var selected: PackedStringArray = OS.get_environment("AMMOB_ONLY").split(",", false)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	for module: GDScript in _modules():
		var wanted: bool = selected.is_empty()
		for part: String in selected:
			wanted = wanted or module.resource_path.ends_with("ammo_buildings_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += int(step.get("expected_errors")) if step.get("expected_errors") != null else 0
		_expected_warnings += int(step.get("expected_warnings")) if step.get("expected_warnings") != null else 0
		_q.harness.release_all()
		await _k.mines().clear_mines()
		var controller: MatchController = _k.a().swap().controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.a().k.flags().carrying(0) and not _k.a().k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.a().k.flags().carrying(0), _k.a().k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("ammo_buildings_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.size() == _expected_warnings, "the engine logged %d errors (%d expected) and %d warnings (%d expected): %s" % [errors.size(), _expected_errors, warnings.size(), _expected_warnings, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario" % [errors.size(), warnings.size()])
	_k.mines().free_arena()
	_k.close()
	harness.finish("ammo_buildings=1 %s" % " ".join(_measured))


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Data, Places, Look, Measure, Rate, Stopped, Both, Gyro, Mines, Cover, Lifecycle]
