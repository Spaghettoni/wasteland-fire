extends RefCounted
## Scenario tyre_tracks of the split screen evidence harness (split_screen_harness.gd): the tracks the ground Units' tyres leave, Story 026 AC-1 to AC-7,
## played with real keys on the shipped data and Map 01. This script holds what is watched over the whole run (no_engine_noise) and runs the modules,
## in this order: tyre_tracks_data.gd (data, tyres_match_blender, tyres_touch_the_ground, ground_surfaces: AC-1, AC-2, AC-3, AC-5), tyre_tracks_lint.gd
## (refusals, globals_default, lint: AC-6, AC-7), tyre_tracks_strokes.gd (lines, quad_widths, reverse, gyrocopter_none: AC-1), tyre_tracks_turns.gd
## (steady_turn, slow_roll, spot_turn: AC-1), tyre_tracks_lifecycle.gd (bench_then_spawn, teleport, off_the_floor, swap, destroyed, destroyed_in_motion,
## retyped_alive: AC-4) and tyre_tracks_round.gd (fade_arithmetic, clock, round_over_pause, restart_clears, hand_off, published: AC-3, AC-7). One Round, played on after each check; a module that wins a Round presses R before it ends,
## and modules_leave_a_fresh_round fails if one ends otherwise. TYRES_ONLY=data,strokes (an environment variable of a run by hand) runs named modules
## alone. Tooling only. Implements: production/epics/wasteland-fire/story-026-tyre-tracks.md AC-1 to AC-7. Every number comes from the game's data;
## the scenario types only its test inputs and the story's values. What a headless run cannot see (the drawn texture, the ground's look, a track's end
## against the drawn tyre) is for tyre_tracks_showcase and tyre_tracks_fps, windowed. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=tyre_tracks

const Kit26: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_data.gd")
const Lint: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_lint.gd")
const Strokes: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_strokes.gd")
const Turns: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_turns.gd")
const Lifecycle: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_lifecycle.gd")
const Round: GDScript = preload("res://tools/evidence/split_screen/tyre_tracks_round.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Heights, the Wall Panels of every Base, Garage and field
## wall, the Turrets with their looks, the Mines, the Flag Walls and their side spots, the explosions, the badly damaged state, the swap and the view
## from above, the rotors, and the tyre tracks.
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
const TYRE_TRACKS: bool = true
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the runs, the destructions, the Rounds.
const WATCHDOG_SECONDS: float = 3000.0

var _k: Kit26
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. TYRES_ONLY (an environment variable of a run by hand)
## names modules, "data,strokes", to run on their own.
func run(harness: Node) -> void:
	_k = Kit26.new(harness)
	_q = _k.q()
	await _k.choose([Quick.MOTORBIKE, Quick.MOTORBIKE])
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("TYRES_ONLY")
	for module: GDScript in _modules():
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("tyre_tracks_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.mines().clear_mines()
		_q.kit.need(slate, not _q.controller.is_round_over() and not _k.flags().carrying(0) and not _k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), _q.controller.is_round_over(), _k.flags().carrying(0), _k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("tyre_tracks_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: ground Units driven, turned, reversed, spawned, swapped, destroyed and restarted with their tyres drawing tracks" % [errors.size(), warnings.size()])
	_k.close()
	harness.finish(" ".join(_measured))


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Data, Lint, Strokes, Turns, Lifecycle, Round]
