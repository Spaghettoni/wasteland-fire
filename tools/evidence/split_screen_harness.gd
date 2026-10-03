extends Node
## Evidence harness runner for the split screen launch scene (Story 002, and the scenarios Story 003 adds):
## runs one named scenario against split_screen.tscn and prints machine-readable lines, so the acceptance
## criteria are backed by a run.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria and Test
## Evidence. Tooling only: nothing under src/ depends on this file; it couples to src/ by instancing
## split_screen.tscn and reading the exported members of SplitScreen.
##
## Scenarios, chosen with --scenario=NAME (after the "--"): layout, isolation, simultaneous, showcase, fps,
## bases, destruction, countdown, respawn_showcase, canister_run, hud, round_over, canister_showcase
## and, since Story 005, units, weapons, gyro, choice and units_showcase; since Story 006, fuel,
## fuel_cans and fuel_showcase; since Story 007, on Map 01, map_layout, map_edges, map_ford,
## map_bases, map_cover, map_showcase, map_legibility and map_fps.
## Each is a script under tools/evidence/split_screen/,
## a RefCounted with `func run(harness: Node) -> void`, a coroutine this runner awaits; its top says what it
## proves and how to run it. SCENARIOS maps the name to the script, so a new scenario is a script and one
## line there. A scenario reaches this script, DriveStep, UnitTrack and check_kit.gd through preload
## constants (nothing under tools/ declares a class_name, so they are PascalCase: the style guide's exception to
## SCREAMING_SNAKE for a constant that holds a class) and uses only the public members below.
##
## The harness plays the keyboard: every drive command is a real InputEventKey pushed through
## Input.parse_input_event with the physical keycode of the key, so the Input Map, PlayerDriveInput and
## the Unit run as under a real keyboard. Gameplay code names actions, never keys; tools are the only place
## key codes appear. Events carry InputEvent.DEVICE_ID_KEYBOARD (16), the id Godot 4.7 gives a keyboard, and
## Input.use_accumulated_input is off, so an event acts at once (measured on 4.7.2; Story 002 evidence doc).
## A window that loses focus makes the engine release every pressed key, so the runner checks its
## record of held keys against the engine's (Input.is_physical_key_pressed()) in set_key() and
## after every tick, and presses a dropped key again (TD-009); a headless run never loses focus.
##
## Time is simulated: scenarios await the physics_frame signal and count ticks, so the numbers are the same
## at any frame rate and a headless --fixed-fps 60 run is faster than real time. The continuation after
## physics_frame runs before the nodes' _physics_process of that tick (measured on 4.7.2), so a key pressed
## there reaches PlayerDriveInput in the same tick and what is read there is the previous tick.
##
## The Unit choice (Story 005): a Round now starts with both Units benched and both Players choosing
## a type, and a destroyed Unit comes back only once its Player has chosen again. The runner is the
## one place that makes the choice for a scenario, with real presses of the fire keys: before run()
## it confirms the type at the cursor's start, the Motorbike, for both Players and waits until both
## Units are in play (confirm_choices(); raw physics_frame awaits that do not count in ticks, so a
## scenario still starts at t=0 with both Units on their spawn points), unless the scenario script
## declares const OWN_CHOICE: bool = true; and for the scenarios written before the choice existed
## (LEGACY_SCENARIOS) it makes the choice again after every destruction, the first type of the data,
## by the controller's own choose() and with no key (an injected key acts one tick later, measured
## on 4.7.2 (the Story 005 evidence doc keeps the run), and a fire key still down on the tick the
## Unit appears fires its weapon; the direct call is in before any due frame), so their respawns
## come after the delay exactly as before the choice existed. Each fire key the runner holds for
## confirm_choices() is released on the tick the controller accepts the choice, so it is up again
## before the Unit appears a tick or more later (the bench settle), and no stray shot is fired at a
## spawn. A scenario of Story 005 or later chooses with its own keys after a destruction; round_over
## and canister_showcase, which restart the Round, call confirm_choices() after the restart key. The
## legacy scenarios also run on the data they were measured with (_apply_legacy_data(), on the
## shared resources before the scene is instanced): the Motorbike's placeholder 100 hit points, the
## debug damage of 25 and the Motorbike's old collision mask, which the shipped data changed in
## Story 005 (40 hit points, the debug keys off, the cliffs_water layer in the mask); a scenario of
## Story 005 or later runs on the shipped data. Since Story 006 the legacy scenarios and those of
## Story 005 (STORY_005_SCENARIOS) also run with no Fuel burn (_apply_no_fuel_data(): every type's
## fuel_use is LEGACY_FUEL_USE, zero, on the same shared resources), a guard for a run long enough
## for the shipped burn rate to empty a tank and stop or crash its Unit; their Units still get a
## tank at every spawn, and a scenario of Story 006 or later runs on the shipped Fuel data.
##
## The Map (Story 007). The launch scene's World now holds Map 01 as its first child (the node
## Map, src/gameplay/maps/map_01/map_01.tscn), and every scenario written before it was measured
## on the 80 m greybox composition: the greybox field with its two Bases, the terrain stand-ins
## and the five greybox Fuel Cans. For those (GREYBOX_SCENARIOS) the runner rebuilds that
## composition inside the freshly instanced launch scene, before it enters the tree and begins the
## Round (_apply_greybox_composition()), with the nodes, names and tree order their outputs were
## measured with, and gives every Unit type back its greybox model (_apply_greybox_models(), on
## the shared UnitStats before the scene is instanced), so the outputs stay what they were; a
## scenario of Story 007 or later is not listed and runs on Map 01. A scenario script may declare
## const WATCHDOG_SECONDS: float, in simulated seconds, for a watchdog of its own when a run across
## Map 01 needs longer.
##
## Output: SPLIT <scenario> t=<seconds> key=value ... (progress), CHECK <scenario> <check name> PASS|FAIL
## <detail> and exactly one last RESULT <scenario> ok|fail checks=<n> failed=<n> key=value ...; then quit with
## exit code 0 when every check passed, 1 when one failed, 2 for a missing or unknown scenario. TD-003
## (docs/tech-debt-register.md) is paid by Story 003; this runner is still coroutine-based with run-wide counters (TD-001).

## The launch scene under test.
const SPLIT_SCENE: PackedScene = preload("res://src/gameplay/split_screen/split_screen.tscn")

## Prefix of the user argument that names the scenario.
const SCENARIO_ARGUMENT: String = "--scenario="

## The scenarios, name to script, in the order of the header. Each script is a RefCounted with
## run(harness: Node) -> void, a coroutine. A new scenario is its script and one line here.
const SCENARIOS: Dictionary[StringName, GDScript] = {
	&"layout": preload("res://tools/evidence/split_screen/layout.gd"),
	&"isolation": preload("res://tools/evidence/split_screen/isolation.gd"),
	&"simultaneous": preload("res://tools/evidence/split_screen/simultaneous.gd"),
	&"showcase": preload("res://tools/evidence/split_screen/showcase.gd"),
	&"fps": preload("res://tools/evidence/split_screen/fps.gd"),
	&"bases": preload("res://tools/evidence/split_screen/bases.gd"),
	&"destruction": preload("res://tools/evidence/split_screen/destruction.gd"),
	&"countdown": preload("res://tools/evidence/split_screen/countdown.gd"),
	&"respawn_showcase": preload("res://tools/evidence/split_screen/respawn_showcase.gd"),
	&"canister_run": preload("res://tools/evidence/split_screen/canister_run.gd"),
	&"hud": preload("res://tools/evidence/split_screen/hud.gd"),
	&"round_over": preload("res://tools/evidence/split_screen/round_over.gd"),
	&"canister_showcase": preload("res://tools/evidence/split_screen/canister_showcase.gd"),
	&"units": preload("res://tools/evidence/split_screen/units.gd"),
	&"weapons": preload("res://tools/evidence/split_screen/weapons.gd"),
	&"gyro": preload("res://tools/evidence/split_screen/gyro.gd"),
	&"choice": preload("res://tools/evidence/split_screen/choice.gd"),
	&"units_showcase": preload("res://tools/evidence/split_screen/units_showcase.gd"),
	&"fuel": preload("res://tools/evidence/split_screen/fuel.gd"),
	&"fuel_cans": preload("res://tools/evidence/split_screen/fuel_cans.gd"),
	&"fuel_showcase": preload("res://tools/evidence/split_screen/fuel_showcase.gd"),
	&"map_layout": preload("res://tools/evidence/split_screen/map_layout.gd"),
	&"map_edges": preload("res://tools/evidence/split_screen/map_edges.gd"),
	&"map_ford": preload("res://tools/evidence/split_screen/map_ford.gd"),
	&"map_bases": preload("res://tools/evidence/split_screen/map_bases.gd"),
	&"map_cover": preload("res://tools/evidence/split_screen/map_cover.gd"),
	&"map_showcase": preload("res://tools/evidence/split_screen/map_showcase.gd"),
	&"map_legibility": preload("res://tools/evidence/split_screen/map_legibility.gd"),
	&"map_fps": preload("res://tools/evidence/split_screen/map_fps.gd"),
}

## The shared step class (drive_step.gd): keys held for a time.
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd): follows one Unit through a phase.
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## Exit code when a check failed.
const EXIT_FAILED: int = 1
## Exit code for a missing or unknown scenario.
const EXIT_USAGE: int = 2
## A scenario still running after this many simulated seconds has hung (a script error stops a
## coroutine without a word): the watchdog prints a failing RESULT and quits. A scenario script
## that declares its own (WATCHDOG_CONSTANT) gets that instead.
const WATCHDOG_SECONDS: float = 120.0
## The constant a scenario script may declare (const WATCHDOG_SECONDS: float = ...) for a watchdog
## of its own, in simulated seconds; a value that is not a number above zero is ignored.
const WATCHDOG_CONSTANT: StringName = &"WATCHDOG_SECONDS"

## Player 1's index, into the tracks and the layouts.
const PLAYER_1: int = 0
## Player 2's index, into the tracks and the layouts.
const PLAYER_2: int = 1
## Stands for both Players in a DriveStep: both layouts are held at once.
const BOTH: int = -1

## Physical keys of Player 1's layout, in the order of SLOT_*: the p1_ Input Map actions are bound to these.
const PLAYER_1_KEYS: Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
## Physical keys of Player 2's layout, in the order of SLOT_*: the p2_ Input Map actions are bound to these.
const PLAYER_2_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
## Physical key of Player 1's fire action (p1_fire): the choice confirm, and the weapon's trigger.
const PLAYER_1_FIRE_KEY: Key = KEY_SPACE
## Physical key of Player 2's fire action (p2_fire).
const PLAYER_2_FIRE_KEY: Key = KEY_PERIOD
## The scenarios written before Story 005's Unit choice, which expect both Units in play when they
## start and a destroyed Unit back after the delay with no key of theirs: for them the runner makes
## a destroyed Player's choice again at once (_on_legacy_destroyed()). A scenario of Story 005 or
## later is not listed and chooses with its own keys after a destruction.
const LEGACY_SCENARIOS: Array[StringName] = [&"layout", &"isolation", &"simultaneous", &"showcase",
	&"fps", &"bases", &"destruction", &"countdown", &"respawn_showcase", &"canister_run", &"hud",
	&"round_over", &"canister_showcase"]
## The type the runner chooses for a legacy scenario's destroyed Player: the first of the data, the
## Motorbike, what every Unit was before Story 005.
const LEGACY_TYPE_INDEX: int = 0
## The shared Motorbike stats: the one resource motorbike.tscn and match_rules.tres both use (one
## cached object), so a value written here before the launch scene is instanced reaches the Units
## and the rules.
const MOTORBIKE_STATS_PATH: String = "res://src/gameplay/units/data/motorbike_stats.tres"
## The Motorbike's collision mask the legacy scenarios were measured with: the map and units layers,
## the scene's own, before the data added the cliffs_water layer that the typed spawn now applies
## (the destruction scenario prints the mask; the legacy lanes never reach that layer's bodies).
const LEGACY_MOTORBIKE_COLLISION_MASK: int = 3
## The Motorbike's hit points the legacy scenarios were measured with: Story 003's placeholder 100,
## before the shipped data took the design's 40 (Story 005 AC-2); their debug-key presses, respawns
## and HUD readings count on it, and two of them print it in a CHECK line.
const LEGACY_MOTORBIKE_HIT_POINTS: float = 100.0
## The shared match rules: the one resource split_screen.tscn hands the MatchController and both
## PlayerMatchInputs (one cached object), so a value written here before the launch scene is
## instanced reaches them all.
const MATCH_RULES_PATH: String = "res://src/gameplay/match/data/match_rules.tres"
## The debug damage the legacy scenarios were measured with: a quarter of the placeholder hit
## points, before the shipped data set it to zero, the gate of Story 003 AC-8 that switches the
## debug keys off now that Story 005 brings weapons. PlayerMatchInput reads the gate once, in its
## _ready(), so the value must be in before the scene is instanced.
const LEGACY_DEBUG_DAMAGE: float = 25.0
## The Fuel burn rate every scenario written before Story 006 was measured with (LEGACY_SCENARIOS
## and STORY_005_SCENARIOS; _apply_no_fuel_data()): their Units get a tank at every spawn and
## nothing burns it, so a long run never empties one, which would stop a ground Unit and crash a
## Gyrocopter (Story 006 AC-1 gave every type a fuel_use).
const LEGACY_FUEL_USE: float = 0.0
## The scenarios of Story 005, written after the Unit choice and before Fuel: they run on the
## shipped data except the Fuel burn rate, which the runner sets to LEGACY_FUEL_USE for them as for
## LEGACY_SCENARIOS (_apply_no_fuel_data()).
const STORY_005_SCENARIOS: Array[StringName] = [&"units", &"weapons", &"gyro", &"choice",
	&"units_showcase"]
## The constant a scenario script declares (const OWN_CHOICE: bool = true) to make the first choice
## of the Round itself: the runner then presses no fire key before run().
const OWN_CHOICE_CONSTANT: StringName = &"OWN_CHOICE"
## Raw physics ticks confirm_choices() waits for the chosen Units to appear before it gives up: the
## bench settle, the key's tick and margin.
const CHOICE_LIMIT_TICKS: int = 120
## The scenarios written before Story 007, each measured on the 80 m greybox composition (the
## greybox field with its two Bases, the terrain stand-ins and the five greybox Fuel Cans): the
## runner rebuilds that composition for them (_apply_greybox_composition()), so their outputs stay
## what they were. fps, Story 002's windowed frame-rate tool, was measured on the greybox field too
## and keeps it. A scenario that is not listed runs on the main composition, Map 01.
const GREYBOX_SCENARIOS: Array[StringName] = [&"layout", &"isolation", &"simultaneous",
	&"showcase", &"fps", &"bases", &"destruction", &"countdown", &"respawn_showcase",
	&"canister_run", &"hud", &"round_over", &"canister_showcase", &"units", &"weapons", &"gyro",
	&"choice", &"units_showcase", &"fuel", &"fuel_cans", &"fuel_showcase"]
## The greybox field the older scenarios were measured on: Story 001's flat 80 m field with the two
## Bases of Story 003. It extends MapField, so the launch scene takes it as its field.
const GREYBOX_FIELD_SCENE: PackedScene = preload("res://src/gameplay/maps/greybox_field.tscn")
## The terrain stand-ins of Story 005 (the 4 m cliff block and the water strip).
const TERRAIN_STAND_INS_SCENE: PackedScene = preload("res://src/gameplay/maps/terrain_stand_ins.tscn")
## The five greybox Fuel Cans of Story 006.
const GREYBOX_FUEL_CANS_SCENE: PackedScene = preload("res://src/gameplay/maps/greybox_fuel_cans.tscn")
## The Token stock every Map holds (Story 007 AC-9): the greybox field gets it too, so the stock
## reads the same (the source's example) whichever composition runs.
const TOKEN_STOCK_PATH: String = "res://src/gameplay/maps/data/token_stock.tres"
## Player 1's colour as the older scenarios were measured with it (Story 002's body material): the
## launch scene gives Player 1's Unit the Team Orange of Story 007, and the runner puts this back as
## its team_material for the greybox composition.
const PLAYER_1_BODY_MATERIAL: Material = preload("res://src/gameplay/split_screen/data/player_1_body_material.tres")
## Player 2's colour as the older scenarios were measured with it, put back in place of the Team
## Teal of Story 007 (see PLAYER_1_BODY_MATERIAL).
const PLAYER_2_BODY_MATERIAL: Material = preload("res://src/gameplay/split_screen/data/player_2_body_material.tres")
## The greybox model of each Unit type (by UnitStats.type_id) the older scenarios were measured
## with: the shipped data points UnitStats.model at the concept-kit models of Story 007, and the
## runner puts these back for GREYBOX_SCENARIOS (_apply_greybox_models()).
const GREYBOX_MODELS: Dictionary[StringName, PackedScene] = {
	&"motorbike": preload("res://src/gameplay/units/models/motorbike_model.tscn"),
	&"buggy": preload("res://src/gameplay/units/models/buggy_model.tscn"),
	&"truck": preload("res://src/gameplay/units/models/truck_model.tscn"),
	&"gyrocopter": preload("res://src/gameplay/units/models/gyrocopter_model.tscn"),
}

## Position of the throttle key in a layout (PLAYER_1_KEYS, PLAYER_2_KEYS).
const SLOT_THROTTLE: int = 0
## Position of the reverse key in a layout.
const SLOT_REVERSE: int = 1
## Position of the steer-left key in a layout.
const SLOT_STEER_LEFT: int = 2
## Position of the steer-right key in a layout.
const SLOT_STEER_RIGHT: int = 3

## Window size AC-1 asks for, pixels. A headless run has no real window (it starts at 64 x 64), so
## there the harness sets the window to this size before a scenario looks.
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
## Ticks each reset waits, with every key up, before the tracks start counting.
const SETTLE_TICKS: int = 5
## Corridor starts (isolation, simultaneous), metres. Player 1 faces -Z, Player 2 faces +Z.
const CORRIDOR_1_START: Vector3 = Vector3(-10.0, 0.0, 20.0)
## Player 2's corridor start, metres (see CORRIDOR_1_START).
const CORRIDOR_2_START: Vector3 = Vector3(10.0, 0.0, -20.0)
## Half the side of the playfield, metres (the inner faces of the four walls, greybox_field.tscn).
const FIELD_HALF_EXTENT: float = 40.0

## The scenario running, from --scenario=NAME: the second word of every SPLIT, CHECK and RESULT line.
var scenario: StringName = &""
## The launch scene under test: the field, both Units and both cameras a scenario reads.
var split: SplitScreen
## One track per Player, in the order of PLAYER_1 and PLAYER_2, updated after every tick.
var tracks: Array[UnitTrack] = []
## Name of the stretch running, printed in the SPLIT lines. apply() sets it from the step.
var phase: StringName = &"start"
## Ticks between SPLIT progress lines; 0 prints none.
var report_ticks: int = 0
## Physics ticks simulated so far. Simulated time is this over the tick rate; read it, do not set it.
var ticks: int = 0
## The Players whose unit_spawned signal arrived before the scenario started, in the order it came:
## the start of the Round. MatchController.begin() runs inside add_child(split), before any scenario
## exists to connect to it, and the spawns follow the runner's confirm_choices() a few ticks later,
## so the runner listens from before begin() until both spawns have arrived and keeps the log here.
## Empty for a scenario that declares OWN_CHOICE.
var round_start_spawns: Array[int] = []
## Closest the two Units' origins came since the run began, metres.
var separation_min: float = INF
## The least room any Unit's origin left to a wall since the run began, metres.
var wall_clearance_min: float = INF
## Which physical keys the harness holds down now, so an event is sent only on a change; set_key()
## and _reassert_held_keys() check it against the engine's own key state (TD-009).
var _held: Dictionary[int, bool] = {}
## One flag per Player: true while the runner itself holds that Player's fire key for a choice
## (confirm_choices()). That key is released on the tick the controller accepts the choice; a fire
## key a scenario holds is never touched.
var _choice_key_held: Array[bool] = [false, false]
var _ticks_per_second: int = 60
## The running scenario's watchdog, simulated seconds (_scenario_watchdog_seconds()).
var _watchdog_seconds: float = WATCHDOG_SECONDS
var _checks: int = 0
var _failed: int = 0
var _finished: bool = false


func _ready() -> void:
	_ticks_per_second = Engine.physics_ticks_per_second
	scenario = _read_scenario()
	if not SCENARIOS.has(scenario):
		# quit() only takes effect after the current frame, so nothing else may run first.
		_finished = true
		print("RESULT %s fail checks=0 failed=0 reason=unknown_scenario %s" % [
			"none" if scenario.is_empty() else String(scenario), _usage()])
		get_tree().quit(EXIT_USAGE)
		return
	Input.use_accumulated_input = false
	_watchdog_seconds = _scenario_watchdog_seconds(SCENARIOS[scenario])
	get_tree().create_timer(_watchdog_seconds).timeout.connect(_on_watchdog)
	if LEGACY_SCENARIOS.has(scenario):
		_apply_legacy_data()
	if LEGACY_SCENARIOS.has(scenario) or STORY_005_SCENARIOS.has(scenario):
		_apply_no_fuel_data()
	if GREYBOX_SCENARIOS.has(scenario):
		_apply_greybox_models()
	split = SPLIT_SCENE.instantiate() as SplitScreen
	if GREYBOX_SCENARIOS.has(scenario):
		_apply_greybox_composition(split)
	if split.match_controller != null:
		split.match_controller.unit_spawned.connect(_on_round_start_spawn)
		split.match_controller.unit_chosen.connect(_on_choice_confirmed)
	add_child(split)
	_run()


## Runs the chosen scenario as a coroutine: after the first frame, so the window and the layout
## exist, then the Players' first choice (confirm_choices(), unless the script declares OWN_CHOICE),
## then the scenario script's run(), which awaits physics ticks. The log of the Round's start
## (round_start_spawns) is closed before run(), so a respawn is never taken for it, and a legacy
## scenario gets its re-choice after every destruction from here on.
func _run() -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		get_window().size = WINDOW_SIZE
	var script: GDScript = SCENARIOS[scenario]
	if not bool(script.get_script_constant_map().get(OWN_CHOICE_CONSTANT, false)):
		await confirm_choices()
	if split.match_controller != null:
		if split.match_controller.unit_spawned.is_connected(_on_round_start_spawn):
			split.match_controller.unit_spawned.disconnect(_on_round_start_spawn)
		if LEGACY_SCENARIOS.has(scenario):
			split.match_controller.unit_destroyed.connect(_on_legacy_destroyed)
	tracks.append(UnitTrack.new(split.player_1_unit))
	tracks.append(UnitTrack.new(split.player_2_unit))
	var entry: RefCounted = script.new()
	await entry.run(self)


## Gives the scenarios written before Story 005 (LEGACY_SCENARIOS) the data they were measured with,
## on the shared resources and before the launch scene is instanced, so that their outputs stay what
## they were while the shipped data changes: on motorbike_stats.tres the Motorbike's collision mask
## (LEGACY_MOTORBIKE_COLLISION_MASK) and hit points (LEGACY_MOTORBIKE_HIT_POINTS), on
## match_rules.tres the debug damage (LEGACY_DEBUG_DAMAGE), which the shipped data sets to zero so
## the debug keys are off in the game (the code stays, gated by the data). Each resource that fails
## to load is an error and is skipped. A scenario of Story 005 or later runs on the shipped data.
func _apply_legacy_data() -> void:
	var motorbike: UnitStats = load(MOTORBIKE_STATS_PATH) as UnitStats
	if motorbike == null:
		push_error("split_screen_harness: %s did not load as UnitStats, so the legacy Motorbike data is not applied." % MOTORBIKE_STATS_PATH)
	else:
		motorbike.collision_mask = LEGACY_MOTORBIKE_COLLISION_MASK
		motorbike.max_hit_points = LEGACY_MOTORBIKE_HIT_POINTS
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the legacy debug damage is not applied." % MATCH_RULES_PATH)
		return
	rules.debug_damage = LEGACY_DEBUG_DAMAGE


## Gives the scenarios written before Story 006 (LEGACY_SCENARIOS and STORY_005_SCENARIOS) the Fuel
## burn rate they were measured with, before the launch scene is instanced: LEGACY_FUEL_USE on every
## UnitStats of match_rules.tres's unit_types, the shared resources the Units spawn with (one cached
## object per type). Their Units still get a tank at every spawn and burn nothing, so their outputs
## stay what they were. Rules that fail to load are an error, and nothing is applied.
func _apply_no_fuel_data() -> void:
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the legacy Fuel burn rate is not applied." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null:
			stats.fuel_use = LEGACY_FUEL_USE


## Rebuilds the greybox composition inside a freshly instanced launch scene, for GREYBOX_SCENARIOS,
## before it enters the tree (SplitScreen._ready() begins the Round when it does): frees World's
## Map at once (remove_child() and free(), so none of its nodes stays in a node group for a frame),
## instances the greybox field, the terrain stand-ins and the greybox Fuel Cans under their old
## names at World child indices 0, 1 and 2 (the tree order the outputs were measured with), gives
## the field the Token stock, makes the new nodes owned by the launch scene and points split.field
## at the greybox field: the export was resolved to the Map when the scene was instanced, so it
## would dangle once the Map is freed. It also gives both Units back the Player body materials the
## older outputs were measured with as their team_material (PLAYER_1_BODY_MATERIAL,
## PLAYER_2_BODY_MATERIAL), in place of the Team materials of Story 007 the launch scene sets
## (Story 007 AC-11: those two files stay as they are for the greybox composition).
func _apply_greybox_composition(root: SplitScreen) -> void:
	var world: Node3D = root.get_node("World") as Node3D
	var map: Node = world.get_node("Map")
	world.remove_child(map)
	map.free()
	var field: GreyboxField = GREYBOX_FIELD_SCENE.instantiate() as GreyboxField
	field.name = &"GreyboxField"
	field.unique_name_in_owner = true
	field.token_stock = load(TOKEN_STOCK_PATH) as TokenStock
	var terrain: Node = TERRAIN_STAND_INS_SCENE.instantiate()
	terrain.name = &"TerrainStandIns"
	var fuel_cans: Node = GREYBOX_FUEL_CANS_SCENE.instantiate()
	fuel_cans.name = &"FuelCans"
	var stand_ins: Array[Node] = [field, terrain, fuel_cans]
	for index: int in stand_ins.size():
		world.add_child(stand_ins[index])
		world.move_child(stand_ins[index], index)
		stand_ins[index].owner = root
	root.field = field
	root.player_1_unit.team_material = PLAYER_1_BODY_MATERIAL
	root.player_2_unit.team_material = PLAYER_2_BODY_MATERIAL


## Gives every UnitStats of match_rules.tres's unit_types back its greybox model (GREYBOX_MODELS,
## by type_id) for GREYBOX_SCENARIOS, on the shared resources before the launch scene is instanced,
## as _apply_no_fuel_data() does for the Fuel: the units scenario prints each model's bounds, and
## the launch scene's warm-up and every spawn then instance the models the outputs were measured
## with. A type with no greybox model keeps its own; rules that fail to load are an error.
func _apply_greybox_models() -> void:
	var rules: MatchRules = load(MATCH_RULES_PATH) as MatchRules
	if rules == null:
		push_error("split_screen_harness: %s did not load as MatchRules, so the greybox models are not applied." % MATCH_RULES_PATH)
		return
	for stats: UnitStats in rules.unit_types:
		if stats != null and GREYBOX_MODELS.has(stats.type_id):
			stats.model = GREYBOX_MODELS[stats.type_id]


## Logs a unit_spawned that arrives before the scenario starts: the start of the Round
## (round_start_spawns).
func _on_round_start_spawn(player_index: int) -> void:
	round_start_spawns.append(player_index)


## The physical key of a Player's fire action: Space for Player 1, Period for Player 2.
func fire_key(player: int) -> Key:
	return PLAYER_1_FIRE_KEY if player == PLAYER_1 else PLAYER_2_FIRE_KEY


## Makes every Player who is choosing confirm the type at its cursor (the Motorbike, where nothing
## has moved the cursor) with a real press of that Player's fire key, and waits, in raw physics
## ticks that do not count in ticks, until those Players' Units are in play, at most
## CHOICE_LIMIT_TICKS; each key is released on the tick the controller accepts the choice
## (_on_choice_confirmed()), a tick or more before the Unit appears (the bench settle), and any
## still held at the end is released then. A Player who is not choosing (in play, or with a standing
## choice) gets no key, so a weapon is never fired by this. The runner's one place for the first
## choice: before run(), unless the scenario declares OWN_CHOICE, and after a restart, where
## round_over and canister_showcase call it. A CHECK fails when the Units did not appear. A
## coroutine: await it.
func confirm_choices() -> void:
	var controller: MatchController = split.match_controller
	if controller == null:
		return
	var pending: Array[int] = []
	for player: int in [PLAYER_1, PLAYER_2]:
		if controller.is_choosing(player):
			pending.append(player)
			_choice_key_held[player] = true
			set_key(fire_key(player), true)
	var left: int = CHOICE_LIMIT_TICKS
	while left > 0 and not _all_alive(controller, pending):
		await get_tree().physics_frame
		left -= 1
	for player: int in pending:
		_choice_key_held[player] = false
		set_key(fire_key(player), false)
	if not _all_alive(controller, pending):
		check("choice", false, "the chosen Units did not appear within %d physics ticks: alive p1=%s p2=%s" % [
			CHOICE_LIMIT_TICKS, controller.is_alive(PLAYER_1), controller.is_alive(PLAYER_2)])


## True when every listed Player's Unit is in play.
func _all_alive(controller: MatchController, players: Array[int]) -> bool:
	for player: int in players:
		if not controller.is_alive(player):
			return false
	return true


## The controller accepted a choice: the fire key the runner held for it goes up on this very tick,
## before the fire input reads it. A key the runner does not hold for a choice is left alone.
func _on_choice_confirmed(player_index: int, _type_index: int) -> void:
	if player_index >= 0 and player_index < _choice_key_held.size() and _choice_key_held[player_index]:
		_choice_key_held[player_index] = false
		set_key(fire_key(player_index), false)


## A legacy scenario's Unit was destroyed: the runner makes that Player's choice at once,
## LEGACY_TYPE_INDEX (the Motorbike), by the controller's own choose() and with no key, inside the
## destruction's own tick. The choice is in before the due frame however short the delay, so the
## respawn comes exactly when it did before the choice existed, and no fire key is down when the
## Unit appears (a held one stays unarmed until released: PlayerFireInput). Connected to
## unit_destroyed for LEGACY_SCENARIOS only.
func _on_legacy_destroyed(player_index: int) -> void:
	if is_instance_valid(split) and split.match_controller != null:
		split.match_controller.choose(player_index, LEGACY_TYPE_INDEX)


## The scenario named by --scenario=NAME among the user arguments, or an empty name.
func _read_scenario() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SCENARIO_ARGUMENT):
			return StringName(argument.trim_prefix(SCENARIO_ARGUMENT))
	return &""


## The watchdog of a scenario, simulated seconds: the WATCHDOG_SECONDS constant its script
## declares (WATCHDOG_CONSTANT) when that is a number above zero, else the runner's own
## WATCHDOG_SECONDS.
func _scenario_watchdog_seconds(script: GDScript) -> float:
	var declared: Variant = script.get_script_constant_map().get(WATCHDOG_CONSTANT, WATCHDOG_SECONDS)
	if (typeof(declared) == TYPE_FLOAT or typeof(declared) == TYPE_INT) and float(declared) > 0.0:
		return float(declared)
	return WATCHDOG_SECONDS


## The usage line: the tool name, then SCENARIO_ARGUMENT and the names of SCENARIOS separated by "|".
func _usage() -> String:
	var names: PackedStringArray = []
	for scenario_name: StringName in SCENARIOS:
		names.append(String(scenario_name))
	return "usage: split_screen_harness.tscn -- " + SCENARIO_ARGUMENT + "|".join(names)


## Whole physics ticks in a time, at least one.
func ticks_in(seconds: float) -> int:
	return maxi(1, roundi(seconds * _ticks_per_second))


## Simulated seconds since the scenario began.
func time() -> float:
	return float(ticks) / float(_ticks_per_second)


## Waits the given number of physics ticks, sampling both Units after each one; each tick first
## presses again any held key the engine dropped (_reassert_held_keys(), TD-009). A coroutine:
## await it.
func advance_ticks(count: int) -> void:
	for _tick: int in count:
		await get_tree().physics_frame
		_reassert_held_keys()
		ticks += 1
		_sample()


## Waits the given simulated seconds. A coroutine: await it.
func advance(seconds: float) -> void:
	await advance_ticks(ticks_in(seconds))


## Updates both tracks and the run-wide minimums after a tick; prints a progress line when one is due.
func _sample() -> void:
	for track: UnitTrack in tracks:
		track.update()
		var at: Vector3 = track.unit.global_position
		wall_clearance_min = minf(wall_clearance_min, FIELD_HALF_EXTENT - maxf(absf(at.x), absf(at.z)))
	separation_min = minf(separation_min,
		tracks[PLAYER_1].unit.global_position.distance_to(tracks[PLAYER_2].unit.global_position))
	if report_ticks > 0 and ticks % report_ticks == 0:
		print_progress()


## Prints one SPLIT line with both Units' place, drive speed and turn since the phase began.
func print_progress() -> void:
	var first: UnitTrack = tracks[PLAYER_1]
	var second: UnitTrack = tracks[PLAYER_2]
	print("SPLIT %s t=%.3f phase=%s p1_x=%.2f p1_z=%.2f p1_speed=%.2f p1_yaw=%.1f "
		% [scenario, time(), phase, first.unit.global_position.x, first.unit.global_position.z,
			first.unit.current_speed, rad_to_deg(first.yaw_total)]
		+ "p2_x=%.2f p2_z=%.2f p2_speed=%.2f p2_yaw=%.1f"
		% [second.unit.global_position.x, second.unit.global_position.z,
			second.unit.current_speed, rad_to_deg(second.yaw_total)])


## Presses or releases one physical key by pushing a real key event through the Input singleton,
## the way the OS does. Sends nothing when the key is already in that state, both in the runner's
## record (_held) and in the engine (Input.is_physical_key_pressed()): a window that loses focus
## makes the engine release every pressed key while the record still holds them, and the
## comparison sends the key again instead of trusting the record (TD-009,
## docs/tech-debt-register.md). advance_ticks() re-asserts every held key after each tick too.
func set_key(key: Key, pressed: bool) -> void:
	if _held.get(key, false) == pressed and Input.is_physical_key_pressed(key) == pressed:
		return
	_held[key] = pressed
	_send_key(key, pressed)


## Pushes one real key event for a physical key through the Input singleton, on the keyboard's
## device (InputEvent.DEVICE_ID_KEYBOARD), as the OS would.
func _send_key(key: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	event.device = InputEvent.DEVICE_ID_KEYBOARD
	Input.parse_input_event(event)


## Presses again every key the runner holds (_held) that the engine no longer reports as pressed
## (TD-009): a window focus change releases every pressed key in the engine, and a held throttle
## or steer would otherwise stay up for the rest of its step. Nothing is sent while the two agree,
## which is every tick of a run that never loses focus (every headless run), so such a run sends
## exactly the events it sent before. It runs right after each physics_frame of advance_ticks(),
## before the nodes' _physics_process of that tick, so a key pressed again acts in that tick.
func _reassert_held_keys() -> void:
	for key: int in _held.keys():
		if _held[key] and not Input.is_physical_key_pressed(key as Key):
			_send_key(key as Key, true)


## Holds one Player's throttle and steer keys: throttle 1 forward, -1 reverse; steer 1 left, -1
## right; 0 releases the pair.
func drive(player: int, throttle: int, steer: int) -> void:
	var keys: Array[Key] = PLAYER_1_KEYS if player == PLAYER_1 else PLAYER_2_KEYS
	set_key(keys[SLOT_THROTTLE], throttle > 0)
	set_key(keys[SLOT_REVERSE], throttle < 0)
	set_key(keys[SLOT_STEER_LEFT], steer > 0)
	set_key(keys[SLOT_STEER_RIGHT], steer < 0)


## Sets the whole key state of a step and names the phase after it: its Player (or both) holds the
## step's keys, the other has every key up.
func apply(step: DriveStep) -> void:
	phase = step.label
	for player: int in [PLAYER_1, PLAYER_2]:
		if step.player == BOTH or step.player == player:
			drive(player, step.throttle, step.steer)
		else:
			drive(player, 0, 0)


## Releases every key of both layouts.
func release_all() -> void:
	drive(PLAYER_1, 0, 0)
	drive(PLAYER_2, 0, 0)


## Holds the step's keys for its length. A coroutine: await it.
func run_step(step: DriveStep) -> void:
	apply(step)
	await advance(step.seconds)


## Teleports a Unit and snaps its camera, in the order a spawn uses: transform first, then
## reset_motion(), then snap_to_target().
func place(unit: Unit, where: Transform3D, camera: ChaseCamera) -> void:
	unit.global_transform = where
	unit.reset_motion()
	camera.snap_to_target()


## The corridor start of a Player: x = -10 facing -Z for Player 1, x = +10 facing +Z for Player 2.
func corridor_transform(player: int) -> Transform3D:
	if player == PLAYER_1:
		return Transform3D(Basis.IDENTITY, CORRIDOR_1_START)
	return Transform3D(Basis(Vector3.UP, PI), CORRIDOR_2_START)


## A reset of both Units to their corridors with every key up: teleport, wait SETTLE_TICKS, then
## start both tracks from where the Units stand. A coroutine: await it.
func reset_to_corridors() -> void:
	release_all()
	place(split.player_1_unit, corridor_transform(PLAYER_1), split.player_1_camera)
	place(split.player_2_unit, corridor_transform(PLAYER_2), split.player_2_camera)
	await advance_ticks(SETTLE_TICKS)
	for track: UnitTrack in tracks:
		track.begin()


## Prints one CHECK line and counts it.
func check(check_name: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failed += 1
	print("CHECK %s %s %s %s" % [scenario, check_name, "PASS" if passed else "FAIL", detail])


## Prints the one RESULT line, releases the keys and quits: exit code 0 when no check failed, 1
## otherwise. The fields are the scenario's own key=value numbers. A scenario ends with it, once.
func finish(fields: String) -> void:
	if _finished:
		return
	_finished = true
	release_all()
	var line: String = "RESULT %s %s checks=%d failed=%d t=%.3f" % [
		scenario, "ok" if _failed == 0 else "fail", _checks, _failed, time()]
	if not fields.is_empty():
		line += " " + fields
	print(line)
	get_tree().quit(0 if _failed == 0 else EXIT_FAILED)


## Fires when the scenario has not finished in its watchdog time (_watchdog_seconds, the runner's
## WATCHDOG_SECONDS unless the scenario declares its own): a hung coroutine fails loudly.
func _on_watchdog() -> void:
	if _finished:
		return
	check("watchdog", false, "the scenario did not finish within %.0f simulated seconds" % _watchdog_seconds)
	finish("reason=watchdog")
