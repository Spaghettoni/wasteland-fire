extends RefCounted
## The record the destruction scenario keeps (destruction.gd, destruction_cycles.gd and
## destruction_edges.gd share one): every unit_destroyed and unit_spawned of the controller as a Wait
## with its tick and one sample per tick, the Units, Bases and cameras of the launch scene, the
## collision layers the Units have in play, and the helpers all three files need (kill a Unit, wait
## for its respawn, drive a Unit, read a Unit just after a spawn).
##
## Ticks: a signal's tick is the runner's ticks when it arrives, so unit_spawned minus unit_destroyed
## is the length of a wait. A key injected between two ticks acts on the next one or the one after
## (Kit.TICK_SLACK). Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md
## AC-1 to AC-5, AC-7 and AC-8. Loaded with a preload constant (nothing under tools/ declares a
## class_name). Tooling only: nothing under src/ depends on this file.

## The runner this record is handed, loaded by path.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd).
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")
## One destruction (wait.gd).
const Wait: GDScript = preload("res://tools/evidence/split_screen/wait.gd")
## The shared step class (drive_step.gd).
const DriveStep: GDScript = preload("res://tools/evidence/split_screen/drive_step.gd")
## The shared track class (unit_track.gd).
const UnitTrack: GDScript = preload("res://tools/evidence/split_screen/unit_track.gd")

## How long a Unit holds the throttle to leave its Base, and again after a respawn, seconds.
const DRIVE_SECONDS: float = 1.0
## The longest a Unit may take to come to rest once the throttle is released, seconds.
const REST_LIMIT_SECONDS: float = 10.0
## A Unit that drove, or lay destroyed away from its Base, is at least this far from it, metres.
const MOVE_MIN_DISTANCE: float = 1.0
## A Unit that must stand still moves less than this (metres) and turns less than this (radians).
const STILL_LIMIT: float = 0.001

## The runner.
var harness: Harness
## The shared helpers of this scenario.
var kit: Kit
## The controller under test.
var controller: MatchController
## The Units of the launch scene, by Player.
var units: Array[Unit] = []
## The Bases of the launch scene, by Player.
var bases: Array[Base] = []
## The cameras of the launch scene, by Player.
var cameras: Array[ChaseCamera] = []
## The collision layer each Unit has in play, read at the start.
var play_layers: Array[int] = []
## The collision mask each Unit has in play, read at the start.
var play_masks: Array[int] = []
## The controller's unit_destroyed signals counted per Player since the scenario began.
var destroyed: Array[int] = [0, 0]
## The controller's unit_spawned signals counted per Player since the scenario began.
var spawned: Array[int] = [0, 0]
## The Units' own destroyed signals counted per Player since the scenario began: the controller ignores a
## second one for a Unit that is already waiting, so only this count shows a Unit that emitted twice.
var unit_emits: Array[int] = [0, 0]
## Every destruction so far, oldest first.
var waits: Array[Wait] = []
## Ticks of the first wait, under the data's delay: the length every later wait must have.
var reference_ticks: int = 0


func _init(harness_node: Node, check_kit: Kit) -> void:
	harness = harness_node as Harness
	kit = check_kit
	var split: SplitScreen = harness.split
	controller = split.match_controller
	units.assign([split.player_1_unit, split.player_2_unit])
	bases.assign([split.field.player_1_base, split.field.player_2_base])
	cameras.assign([split.player_1_camera, split.player_2_camera])


## Connects the controller's signals and each Unit's own destroyed signal. Call it once, before the
## first tick of the scenario.
func start() -> void:
	controller.unit_destroyed.connect(_on_unit_destroyed)
	controller.unit_spawned.connect(_on_unit_spawned)
	for index: int in units.size():
		units[index].destroyed.connect(_on_unit_emitted.bind(index))


## Notes the collision layer and mask each Unit has in play. Call it once the Units have settled.
func note_play() -> void:
	for unit: Unit in units:
		play_layers.append(unit.collision_layer)
		play_masks.append(unit.collision_mask)


## The Player's wait that has not ended, or an empty one when none is open.
func open_wait(player: int) -> Wait:
	for wait: Wait in waits:
		if wait.player == player and wait.spawned_tick < 0:
			return wait
	return Wait.new()


## Metres from a Player's camera to where it sits when it follows a Unit standing at a transform.
func camera_gap(player: int, at: Transform3D) -> float:
	var camera: ChaseCamera = cameras[player]
	return camera.global_position.distance_to(at.origin + at.basis * camera.settings.offset)


## One sample of a wait: the controller's seconds, whether the Unit is still in play, and the camera.
func sample(wait: Wait) -> void:
	var unit: Unit = units[wait.player]
	wait.seconds.append(controller.seconds_until_respawn(wait.player))
	var out: bool = not unit.is_alive and not unit.visible and unit.collision_layer == 0 \
		and unit.collision_mask == 0 and not unit.is_physics_processing() \
		and unit.velocity == Vector3.ZERO and is_zero_approx(unit.current_speed) \
		and not controller.is_alive(wait.player)
	wait.in_play += 0 if out else 1
	wait.camera_gap = camera_gap(wait.player, bases[wait.player].spawn_point.global_transform)


## Samples every open wait. The kit calls it after every tick (kit.on_tick).
func sample_open() -> void:
	for wait: Wait in waits:
		if wait.spawned_tick < 0:
			sample(wait)


## Presses keys that should destroy a Unit and returns the Player's wait that opened.
func kill(keys: Array[Key], player: int) -> Wait:
	await kit.press_settled(keys)
	return open_wait(player)


## Waits until the wait ends, or gives up Kit.RESPAWN_SLACK_TICKS past the longest it may take: the delay,
## plus extra_ticks for a check that holds a respawn up (every spot of the Base taken; blocked_spawn.gd).
func wait_respawn(wait: Wait, extra_ticks: int = 0) -> void:
	var limit: int = harness.ticks_in(controller.rules.respawn_delay_seconds) + extra_ticks + Kit.RESPAWN_SLACK_TICKS
	while wait.spawned_tick < 0 and limit > 0:
		await kit.tick()
		limit -= 1


## Holds a Player's throttle for DRIVE_SECONDS, releases it and waits for rest. Returns the speed at
## the end of the hold (x) and the distance covered in it (y).
func drive(player: int, label: StringName) -> Vector2:
	var unit: Unit = units[player]
	var track: UnitTrack = harness.tracks[player]
	track.begin()
	harness.apply(DriveStep.new(label, DRIVE_SECONDS, player, 1, 0))
	await kit.advance(harness.ticks_in(DRIVE_SECONDS))
	var held: Vector2 = Vector2(unit.current_speed, track.moved())
	harness.release_all()
	var limit: int = harness.ticks_in(REST_LIMIT_SECONDS)
	while not is_zero_approx(unit.current_speed) and limit > 0:
		await kit.tick()
		limit -= 1
	harness.print_progress()
	return held


## read_spawn_at() for the Base's own spawn point.
func read_spawn(player: int, problems: PackedStringArray) -> String:
	return read_spawn_at(player, bases[player].spawn_point.global_transform, problems)


## Adds to problems whatever is wrong with a Player's Unit just after a spawn at the given pose (on it
## facing its way, alive, visible, full hit points, collision as it was, physics on, at rest, camera back
## at its offset). Returns the numbers.
func read_spawn_at(player: int, spawn: Transform3D, problems: PackedStringArray) -> String:
	var unit: Unit = units[player]
	var error: float = unit.global_position.distance_to(spawn.origin)
	var facing: float = (-unit.global_transform.basis.z).dot(-spawn.basis.z)
	var gap: float = camera_gap(player, unit.global_transform)
	var tag: String = "player_%d" % (player + 1)
	kit.need(problems, error <= Kit.SPAWN_TOLERANCE and facing >= Kit.FACING_DOT_MIN,
		"%s not on its Base (%.3f m, dot %.4f)" % [tag, error, facing])
	kit.need(problems, unit.is_alive and unit.visible and controller.is_alive(player), "%s not alive and visible" % tag)
	kit.need(problems, is_equal_approx(unit.hit_points, unit.stats.max_hit_points), "%s hit points %.1f" % [tag, unit.hit_points])
	kit.need(problems, unit.collision_layer == play_layers[player] and unit.collision_mask == play_masks[player],
		"%s collision not restored" % tag)
	kit.need(problems, unit.is_physics_processing() and is_zero_approx(unit.current_speed), "%s physics off or speed not zero" % tag)
	kit.need(problems, gap <= Kit.SPAWN_TOLERANCE, "%s camera %.3f m from its offset point" % [tag, gap])
	return ("%s base_error=%.4f (max %.2f) facing_dot=%.4f hit_points=%.1f/%.1f alive=%s visible=%s layer=%d mask=%d "
		+ "(as before: %d/%d) physics_processing=%s speed=%.3f camera_gap=%.4f") % [
			tag, error, Kit.SPAWN_TOLERANCE, facing, unit.hit_points, unit.stats.max_hit_points, unit.is_alive, unit.visible,
			unit.collision_layer, unit.collision_mask, play_layers[player], play_masks[player],
			unit.is_physics_processing(), unit.current_speed, gap]


## Opens a wait for a destruction and takes its first sample, the full delay.
func _on_unit_destroyed(player_index: int) -> void:
	destroyed[player_index] += 1
	var wait: Wait = Wait.new()
	wait.player = player_index
	wait.destroyed_tick = harness.ticks
	wait.wreck = units[player_index].global_position
	waits.append(wait)
	sample(wait)


## Counts a spawn and closes the Player's open wait with the tick it came.
func _on_unit_spawned(player_index: int) -> void:
	spawned[player_index] += 1
	open_wait(player_index).spawned_tick = harness.ticks


## Counts a destroyed signal of a Unit itself, whatever the controller made of it.
func _on_unit_emitted(player_index: int) -> void:
	unit_emits[player_index] += 1
