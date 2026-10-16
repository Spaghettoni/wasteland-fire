extends RefCounted
## Scenario rotors of the split screen evidence harness (split_screen_harness.gd): the Gyrocopter's turning main rotor and pusher
## propeller of Story 025 AC-1 to AC-8, played with real keys on the shipped data and Map 01. This script holds what is watched
## over the whole run (no_engine_noise) and runs the modules, in this order: rotors_data.gd (data, mesh_match, refusals, lint:
## AC-2, AC-3, AC-4, AC-5, AC-6), rotors_file.gd (file, frozen_copy, older_model: AC-5, AC-8), rotors_turn.gd (turn, strobe,
## out_of_play, round_over: AC-1, AC-4), rotors_prop.gd (propeller, propeller_badly_damaged: AC-3), rotors_paint.gd (paint, no_shadow: AC-2),
## rotors_band.gd (band, sweep: AC-5) and rotors_destroy.gd (destroy, smoke: AC-5). One Round, played on after each check; a module that
## wins a Round presses R before it ends, and modules_leave_a_fresh_round fails if one ends otherwise. ROTORS_ONLY=data,turn (an
## environment variable of a run by hand) runs named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-025-gyrocopter-rotor.md AC-1 to AC-8. Every number comes from the game's data and the
## meshes; the scenario types only its test inputs and the story's values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=rotors

const Kit25: GDScript = preload("res://tools/evidence/split_screen/rotors_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/rotors_data.gd")
const File: GDScript = preload("res://tools/evidence/split_screen/rotors_file.gd")
const Turn: GDScript = preload("res://tools/evidence/split_screen/rotors_turn.gd")
const Prop: GDScript = preload("res://tools/evidence/split_screen/rotors_prop.gd")
const Paint: GDScript = preload("res://tools/evidence/split_screen/rotors_paint.gd")
const Band: GDScript = preload("res://tools/evidence/split_screen/rotors_band.gd")
const Destroy: GDScript = preload("res://tools/evidence/split_screen/rotors_destroy.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Heights (the frozen Gyrocopter of
## Story 019 hovers 0.78 m up), the Wall Panels of every Base, Garage and field wall, the Turrets with their looks, the Mines, the
## Flag Walls and their side spots, the explosions, the badly damaged state, the swap and the view from above, and the rotors.
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
const ROTORS: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the flights, the destructions, the Rounds.
const WATCHDOG_SECONDS: float = 3000.0

var _k: Kit25
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. ROTORS_ONLY (an environment variable
## of a run by hand) names modules, "data,turn", to run on their own.
func run(harness: Node) -> void:
	_k = Kit25.new(harness)
	_q = _k.q()
	var swap_kit: Object = _k.k.swap()
	for player: int in Kit25.Kit.PLAYERS:
		await swap_kit.play(player, Kit25.GYRO)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("ROTORS_ONLY")
	for module: GDScript in _modules():
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("rotors_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.k.mines().clear_mines()
		var controller: MatchController = swap_kit.controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.k.flags().carrying(0) and not _k.k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.k.flags().carrying(0), _k.k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("rotors_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: Gyrocopters spawned, flown, swapped, destroyed and restarted, with their rotors and propellers turning" % [errors.size(), warnings.size()])
	_k.close()
	harness.finish(" ".join(_measured))


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Data, File, Turn, Prop, Paint, Band, Destroy]
