extends RefCounted
## Scenario crash of the split screen evidence harness (split_screen_harness.gd): a Gyrocopter that flies into a Tall piece
## crashes, Story 021 AC-1 to AC-7, played with real keys on the shipped data and Map 01 (a throttle that is a share of full is
## a stick pressed that far, Input.action_press, wherever a check needs a speed between 0 and the top). This script files the
## whole run's no_engine_noise; the modules it runs, in this order, hold the rest: crash_spawn.gd (spawn_never and
## garage_exits: AC-5; it makes the Round's first spawn, with the throttle held, so it runs first), crash_tall.gd (tall_crashes,
## crash_costs, two_crashes_one_tick and reverse_crash: AC-1, AC-2), crash_edges.gd (only_stops, pinned, speed_edge, angle_edge and
## offset_edges: AC-3), crash_never.gd (floor_never, sea_edge_stops, low_pieces_pass, units_pass and ground_never: AC-4),
## crash_hit.gd (crash_with_a_hit and crash_with_an_empty_tank: AC-6), crash_frame.gd (the Round cases: AC-6) and crash_data.gd
## (the data: AC-7). One Round, played on after each check; a module that ends
## a Round presses R before it ends, and modules_leave_a_fresh_round fails if one ends otherwise. CRASH_ONLY=tall,edges (an
## environment variable of a run by hand) runs named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-021-gyrocopter-crash.md AC-1 to AC-7. Every number comes from the game's data and
## the meshes; the scenario types only its test inputs and the story's values. Run: godot --headless --fixed-fps 60 --path .
## res://tools/evidence/split_screen_harness.tscn -- --scenario=crash

const Kit21: GDScript = preload("res://tools/evidence/split_screen/crash_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Tall: GDScript = preload("res://tools/evidence/split_screen/crash_tall.gd")
const Edges: GDScript = preload("res://tools/evidence/split_screen/crash_edges.gd")
const Never: GDScript = preload("res://tools/evidence/split_screen/crash_never.gd")
const Spawn: GDScript = preload("res://tools/evidence/split_screen/crash_spawn.gd")
const Hit: GDScript = preload("res://tools/evidence/split_screen/crash_hit.gd")
const Frame: GDScript = preload("res://tools/evidence/split_screen/crash_frame.gd")
const Data: GDScript = preload("res://tools/evidence/split_screen/crash_data.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the crash, the Heights, the Wall Panels of
## every Base, Garage and field wall, the Turrets with their looks, the Mines, the Flag Walls and their side spots, the
## explosions, the badly damaged state, the swap and the view from above.
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
## Tokens enough that the destructions and the restarts never end a Round by a loss (crash_frame.gd sets a Round's Motorbikes
## itself for the loss cases and puts the stock back).
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the flights, the respawns, the Rounds.
const WATCHDOG_SECONDS: float = 4000.0

var _k: Kit21
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. CRASH_ONLY (an environment
## variable of a run by hand) names modules, "tall,edges", to run on their own.
func run(harness: Node) -> void:
	_k = Kit21.new(harness)
	_q = _k.q()
	var selected: PackedStringArray = OS.get_environment("CRASH_ONLY").split(",", false)
	if not (selected.is_empty() or selected.has("spawn")):
		for player: int in Kit21.Kit.PLAYERS:
			await _k.swap().play(player, Quick.GYROCOPTER)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	for module: GDScript in _modules():
		var wanted: bool = selected.is_empty()
		for part: String in selected:
			wanted = wanted or module.resource_path.ends_with("crash_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.mines().clear_mines()
		var controller: MatchController = _k.swap().controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.flags().carrying(0) and not _k.flags().carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.flags().carrying(0), _k.flags().carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("crash_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: Gyrocopters flown into every Tall kind and past the grazing offsets, stopped and spun against them, spawned flush against a leg, crashed on the tick a Round ended and swapped, shot and left without Fuel" % [errors.size(), warnings.size()])
	if not OS.get_environment("CRASH_LIST").is_empty():
		for record: Dictionary in _k.destroyed:
			print("DESTROYED p%d frame %d type %s at %s" % [int(record["player"]) + 1, record["frame"], record["type"], record["at"]])
	_k.close()
	harness.finish("crash_speed=%.1f destroyed=%d %s" % [_k.crash_speed(), _k.destroyed.size(), " ".join(_measured)])


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Spawn, Tall, Edges, Never, Hit, Frame, Data]
