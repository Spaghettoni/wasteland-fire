extends RefCounted
## Scenario heights of the split screen evidence harness (split_screen_harness.gd): the two Heights and the Gyrocopter's one
## flying height of Story 020 AC-1 to AC-9, played with real keys on the shipped data and Map 01. This script holds the
## flying height's watch over the whole run (height_every_tick: the lowest drawn point of a flying model on every tick
## it is in play, on its spawn tick, and no physics tick of the model's own) and no_engine_noise; the modules it runs, in
## this order, hold the rest: heights_scan.gd (scan, masks, tops and kit_fallback: AC-1, AC-3, AC-9),
## heights_spawn.gd (spawn_height: AC-2), heights_over.gd (cross_low and passes_through: AC-2, AC-4, AC-5),
## heights_tall.gd (tall_stops, under_the_tank and band: AC-5, AC-7), heights_shots.gd (shots_hit, shots_stopped and
## tracer: AC-6, AC-8) and heights_views.gd (views: AC-4). One Round, played on after each check; a module that wins a
## Round presses R before it ends, and modules_leave_a_fresh_round fails if one ends otherwise. HEIGHTS_ONLY=scan,spawn
## (an environment variable of a run by hand) runs named modules alone. Tooling only. Implements:
## production/epics/wasteland-fire/story-020-two-heights.md AC-1 to AC-9. Every number comes from the game's data and
## the meshes; the scenario types only its test inputs and the story's values. Run: godot --headless --fixed-fps 60
## --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=heights

const Kit20: GDScript = preload("res://tools/evidence/split_screen/heights_kit.gd")
const Quick: GDScript = preload("res://tools/evidence/split_screen/quick_fix_kit.gd")
const Scan: GDScript = preload("res://tools/evidence/split_screen/heights_scan.gd")
const Spawn: GDScript = preload("res://tools/evidence/split_screen/heights_spawn.gd")
const Over: GDScript = preload("res://tools/evidence/split_screen/heights_over.gd")
const Tall: GDScript = preload("res://tools/evidence/split_screen/heights_tall.gd")
const Shots: GDScript = preload("res://tools/evidence/split_screen/heights_shots.gd")
const Views: GDScript = preload("res://tools/evidence/split_screen/heights_views.gd")

## This scenario makes every choice itself, with its own keys, on the build as it ships: the Heights, the Wall Panels of
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
## Tokens enough that the destructions and the restarts never end a Round by a loss.
const STOCK_COUNTS: Dictionary = {&"motorbike": 60, &"buggy": 60, &"truck": 60, &"gyrocopter": 60}
## Simulated seconds: the drives, the Shots, the Rounds.
const WATCHDOG_SECONDS: float = 3000.0

var _k: Kit20
var _q: Quick
var _measured: PackedStringArray = []
## The engine errors this script causes on purpose, for the noise check.
var _expected_errors: int = 0


## Plays the checks of the class doc, then the RESULT line. The runner awaits this coroutine. HEIGHTS_ONLY (an
## environment variable of a run by hand) names modules, "scan,spawn", to run on their own.
func run(harness: Node) -> void:
	_k = Kit20.new(harness)
	_q = _k.q()
	var swap_kit: Object = _k.k.k.m.w.s
	for player: int in Kit20.Kit.PLAYERS:
		await swap_kit.play(player, Quick.GYROCOPTER)
	var slate: PackedStringArray = []
	var ran: PackedStringArray = []
	var only: String = OS.get_environment("HEIGHTS_ONLY")
	for module: GDScript in _modules():
		var wanted: bool = only.is_empty()
		for part: String in only.split(","):
			wanted = wanted or module.resource_path.ends_with("heights_%s.gd" % part)
		if not wanted:
			continue
		var step: Object = module.new(_k)
		await step.run()
		_measured.append_array(step.measured)
		_expected_errors += step.expected_errors
		_q.harness.release_all()
		await _k.k.k.m.clear_mines()
		var controller: MatchController = swap_kit.controller
		_q.kit.need(slate, not controller.is_round_over() and not _k.k.k.m.w.carrying(0) and not _k.k.k.m.w.carrying(1), "%s left the Round over (%s) or a Flag carried (%s, %s): the next module would start in a frozen world" % [module.resource_path.get_file(), controller.is_round_over(), _k.k.k.m.w.carrying(0), _k.k.k.m.w.carrying(1)])
		ran.append(module.resource_path.get_file().trim_prefix("heights_").trim_suffix(".gd"))
	_q.kit.verdict("modules_leave_a_fresh_round", slate, "after each of the %d modules that ran (%s) the Round was on and no Unit carried a Flag, so the next module did not start in a Round that was over (a frozen world, where a Turret that 'does not fire' proves nothing)" % [ran.size(), ", ".join(ran)])
	_height_every_tick()
	var noise: PackedStringArray = []
	var errors: Array[String] = _q.tokens.engine_log.errors
	var warnings: Array[String] = _q.tokens.engine_log.warnings
	_q.kit.need(noise, errors.size() == _expected_errors and warnings.is_empty(), "the engine logged %d errors (%d expected) and %s" % [errors.size(), _expected_errors, warnings])
	_q.kit.verdict("no_engine_noise", noise, "errors=%d warnings=%d over every Round of the scenario: Gyrocopters spawned, flown over every low kind and into every Tall one, shot at and shot, swapped, destroyed and restarted" % [errors.size(), warnings.size()])
	_k.close()
	harness.finish("flying_height=%.4f samples=%d %s" % [_k.height, _k.watch.samples, " ".join(_measured)])


## The modules, in the order they run (the class doc).
func _modules() -> Array[GDScript]:
	return [Scan, Spawn, Over, Tall, Shots, Views]


## height_every_tick (AC-2): over the whole run, on every tick a Gyrocopter was in play, the lowest point of its drawn model stood
## at the flying height (within 1 mm), it never rose or settled (no change from one tick to the next), its model did
## no physics tick, and on the tick each Gyrocopter was spawned (the controller's own tick, read inside it) it already
## stood there.
func _height_every_tick() -> void:
	var problems: PackedStringArray = []
	var watch: Node = _k.watch
	_q.kit.need(problems, watch.samples > 0, "no Gyrocopter was sampled")
	_q.kit.need(problems, watch.worst <= Kit20.TOLERANCE + Kit20.FLOAT_SLACK, "a lowest point stood %.5f m from the flying height %.4f" % [watch.worst, _k.height])
	_q.kit.need(problems, watch.biggest_step <= Kit20.TOLERANCE + Kit20.FLOAT_SLACK, "a Gyrocopter's lowest point moved %.5f m between two ticks" % watch.biggest_step)
	_q.kit.need(problems, watch.worst_model <= Kit20.FLOAT_SLACK and watch.biggest_model_step <= Kit20.FLOAT_SLACK, "the model stood %.6f m from its height over its own Unit and moved %.6f m between two ticks" % [watch.worst_model, watch.biggest_model_step])
	_q.kit.need(problems, watch.ticks_ticking == 0, "a flying model did a physics tick of its own on %d ticks" % watch.ticks_ticking)
	var latest: float = 0.0
	for read: Dictionary in watch.spawn_reads:
		latest = maxf(latest, absf(float(read["low"]) - _k.height))
	_q.kit.need(problems, not watch.spawn_reads.is_empty() and latest <= Kit20.TOLERANCE, "%d spawns read, the worst %.4f m from the flying height" % [watch.spawn_reads.size(), latest])
	for stray: Dictionary in watch.strays:
		print("STRAY tick %d p%d low %.4f at %s speed %.2f" % [stray["tick"], int(stray["player"]) + 1, stray["low"], stray["at"], stray["speed"]])
	_measured.append("spawns=%d worst=%.5f step=%.5f model=%.6f" % [watch.spawn_reads.size(), watch.worst, watch.biggest_step, watch.worst_model])
	_q.kit.verdict("height_every_tick", problems, "%d ticks with a Gyrocopter in play over the whole run: the lowest drawn point of its model stood at %.4f m above the floor within %.5f m on every one (the Unit's body floats up to its 1 mm safe margin; measured from the Unit's own origin the model stood within %.6f m), changed by at most %.5f m from one tick to the next (the model alone %.6f m), and its model did no physics tick on %d of them; on the %d spawn ticks read inside the controller's tick (the Round's first spawn, respawns and the spawns after a Swap) it stood within %.5f m of it" % [
		watch.samples, _k.height, watch.worst, watch.worst_model, watch.biggest_step, watch.biggest_model_step, watch.ticks_ticking, watch.spawn_reads.size(), latest])
