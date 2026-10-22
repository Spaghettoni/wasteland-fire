extends RefCounted
## Scenario see_through of the split screen evidence harness (split_screen_harness.gd): the light, the colour and the see-through
## silhouette of a Player's own Unit of Story 027 AC-1 to AC-5, AC-7 (AC-6 and the looks are the windowed light_showcase and
## light_fps), played with real keys on the shipped data and Map 01, headless. This script holds what is watched over the whole
## run (no_engine_noise) and runs the modules, in this order: see_through_data.gd (settings_data, project_layers, environment_data,
## greybox_untouched, grade_data, lut_file, settings_refused: AC-1, AC-2, AC-3, AC-5), see_through_cameras.gd (cameras: AC-4),
## see_through_copies.gd (copies, passes, turning_parts, small_things: AC-4), see_through_life.gd (benched_at_start, life,
## retype, respawn_cost, undressed: AC-4) and see_through_lint.gd (no_number_in_code: AC-5). One Round, played on after each check. SEE_ONLY=data,copies
## (an environment variable of a run by hand) runs named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-027-light-colour-and-silhouette.md AC-1 to AC-5. Every number comes from the game's
## data; the scenario types only its test inputs and the story's values. A headless run draws nothing, so what a silhouette
## looks like (and that the other Player's view shows none) is the windowed light_showcase's. Run: godot --headless
## --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=see_through

const Kit27: GDScript = preload("res://tools/evidence/split_screen/see_through_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/see_through_data.gd")
const Cameras: GDScript = preload("res://tools/evidence/split_screen/see_through_cameras.gd")
const Copies: GDScript = preload("res://tools/evidence/split_screen/see_through_copies.gd")
const Life: GDScript = preload("res://tools/evidence/split_screen/see_through_life.gd")
const Lint: GDScript = preload("res://tools/evidence/split_screen/see_through_lint.gd")

## Both Players, in the order of the controller's indices (0 is Player 1).
const PLAYERS: Array[int] = [0, 1]

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Heights, the Wall Panels of every Base,
## Garage and field wall, the Turrets with their looks, the Mines, the Flag Walls and their side spots, the explosions, the badly
## damaged state, the swap, the view from above, the Gyrocopter's crash, the ammo, the Fuel and ammunition buildings, the rotors, the tyre tracks and the silhouette.
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
const ROTORS: bool = true
const TYRE_TRACKS: bool = true
const SEE_THROUGH: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the staging, the flights, the destructions.
const WATCHDOG_SECONDS: float = 1800.0

var _k: Kit27
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. SEE_ONLY (an environment variable of a
## run by hand) names modules, "data,copies", to run on their own.
func run(harness: Node) -> void:
	_k = Kit27.new(harness)
	_q = _k.q()
	var swap_kit: Object = _k.k.k.swap()
	var at_start: Dictionary = _state_at_start()
	for player: int in PLAYERS:
		await swap_kit.play(player, Kit27.GYRO)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("SEE_ONLY")
	for module: GDScript in _modules():
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("see_through_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k, at_start)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.k.k.mines().clear_mines()
		var controller: MatchController = swap_kit.controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.k.k.flags().carrying(0) and not _k.k.k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen or changed world" % [module.resource_path.get_file(), controller.is_round_over(), _k.k.k.flags().carrying(0), _k.k.k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("see_through_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world) or with a Flag taken" % [ran.size(), ",".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: Units of all four types staged, destroyed, swapped and respawned with their silhouettes" % [errors.size(), warnings.size()])
	_k.close()
	harness.finish(" ".join(_measured))


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Data, Cameras, Copies, Life, Lint]


## What the Round looks like before either Player has chosen a type: each Player's Unit alive or not, visible or not, its model and its
## silhouette copies (the Life module's benched_at_start reads it).
func _state_at_start() -> Dictionary:
	var state: Dictionary = {}
	for player: int in PLAYERS:
		var unit: Unit = _k.unit(player)
		state[player] = {"alive": unit.is_alive, "visible": unit.visible, "model": _k.model_of(player) != null, "copies": _k.copies_of(player).size()}
	return state
