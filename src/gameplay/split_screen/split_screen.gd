class_name SplitScreen
extends Control
## The launch scene: two side-by-side views of one shared 3D world, one Unit (the type its Player
## chooses), one chase camera and one keyboard layout per Player, both Players driving at once, each
## starting the Round at their own Base and respawning there when destroyed.
##
## Implements: design/game-brief.md build-order item 2 (Split screen for two: two side-by-side
## viewports, one Unit and one fixed keyboard layout per Player, both driving at once) and
## production/epics/wasteland-fire/story-002-split-screen.md AC-1 to AC-7. Since Story 003
## (production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-1, AC-3, AC-5 and
## AC-7) it also composes the Round: the MatchController and each Player's PlayerMatchInput.
## Vocabulary: CONTEXT.md (Player, Unit, Motorbike, Base, Map).
##
## The scene holds the pieces. This script only hands them to the MatchController, once, when the
## scene is ready: begin() gets the two Units, the two Bases from the field, the two cameras, in
## Player order, and the field's Token stock. Putting a Unit on its Base, at the start of the Round
## and at every respawn, is the MatchController's job (AC-1, AC-3); until Story 003 it was this
## script's (Story 002 put each Unit on its start marker: the spawn of DrivingToy, done for two
## Players). This scene stays the composition root because it is the one place that sees the field,
## both Units, both cameras and the controller together: it injects them, so the MatchController
## needs no node path and no singleton and can be built from stand-ins in a test. The world and the
## views stay here for the same reason: they are how the pieces are laid out and seen on the screen,
## which is this scene's business, and none of them depends on the Round. The layout of the scene:
##   SplitScreen (this Control, filling the window)
##     World (Node3D): the Map first (map_01.tscn: its ground, its two Bases and its Fuel Cans),
##       then both Units, both PlayerDriveInputs, both PlayerMatchInputs, both Weapons with their
##       PlayerFireInputs, both PlayerChoiceInputs and both PlayerCameraInputs
##     Views (HBoxContainer): a SubViewportContainer per Player, each holding a SubViewport that
##       holds that Player's ChaseCamera, respawn countdown, HUD, Unit choice panel and Round-over
##       screen
##     Divider (ColorRect): a thin line drawn over the seam between the two views
##     MatchController (Node): who is alive, who is choosing or waiting to respawn and the Round's
##       Flags
##     RoundRestartInput (Node): the restart key of a Round that is over; the last child
##
## The Map (production/epics/wasteland-fire/story-007-the-map.md AC-9 and its Map contract). field
## is typed MapField, the class every Map's root carries, so any Map scene can be World's field and
## replacing the Map scene needs no change here. This scene reads only the Map's two Bases and its
## Token stock and hands them to the MatchController; each Base brings its Flag, its zone, its pad
## and its SpawnPoint markers itself (Base). The Token stock (MapField.token_stock) goes to begin()
## as it is: the controller copies it for each Player and refuses a Map without a usable one, so
## this scene checks nothing about it
## (production/epics/wasteland-fire/story-008-tokens-garage-and-loss.md AC-1 and AC-9). The Map is
## World's first child (the node Map, unique name %Map), so a Map node that acts on the Units in its
## physics tick runs before the Units do, in every tick.
##
## One world, two views (AC-1, AC-2). World sits in the window's own World3D, outside both
## SubViewports, and neither SubViewport sets own_world_3d or a world_3d, so both render the
## window's World3D: the same field and the same two Units in one physics space, so the Units can
## meet. Each SubViewport holds exactly one current Camera3D, its Player's; the window's own
## viewport has none and draws only the containers. Views splits the window into two equal halves,
## 640 x 720 each in the project's 1280 x 720 window, with its theme separation set to 0 (the
## default 4 would make both views 638 wide); the Divider is an overlay that takes no layout
## space. In a larger window the canvas_items stretch mode (project.godot, Story 001) keeps the
## views at 640 x 720 and scales the picture up (the Story 002 evidence doc keeps the run).
##
## Physics interpolation (Story 001 AC-5, carried into this scene). A Control is OFF by default
## and a Node3D inherits its parent's mode, so a World left at INHERIT under this Control root
## would draw both Units at the physics tick rate on a faster display. World therefore sets the
## mode ON itself and the Units inherit it; the two ChaseCameras set themselves OFF, as
## ChaseCamera documents (measured on 4.7.2; the Story 002 evidence doc keeps the run).
##
## Input (AC-3 to AC-6). The Players are separated by Input Map layouts, not by devices: each
## PlayerDriveInput reads the actions under its own prefix (p1_ or p2_, declared in project.godot
## and stored in this scene), so each layout moves only its own Unit and holding both moves both.
## The Round's keys work the same way: each PlayerMatchInput reads the self_destruct and
## debug_damage actions under its own prefix and calls its own Unit (Story 003 AC-5, AC-8).
## Godot 4.7 does not tell two keyboards apart, and it moved the keyboard's device ID from 0 to
## InputEvent.DEVICE_ID_KEYBOARD, so nothing in this project compares InputEvent.device with 0,
## and this script reads no input.
##
## The views (Story 010, production/epics/wasteland-fire/story-010-camera-from-above.md AC-4 and
## AC-5). Each camera starts in the view from above (above_camera_settings.tres, the first entry of
## its Player's list of views) and its PlayerCameraInput, which reads that Player's p1_ or p2_camera
## key, steps it through the list: the view from above, then the chase view of Stories 001 to 009
## (chase_camera_settings.tres), then round again. The list, the two resources and the keys are data
## of this scene and of project.godot; the other Player's camera is never touched.
##
## Player colour. Each Unit is coloured on its Body mesh only, by a material_override on the
## instanced Body node in this scene (the Motorbike's mesh is one shared resource, so a material
## on the mesh would recolour both); the Nose keeps its cream, so the facing stays readable. Both
## Motorbike instances are marked editable in the .tscn, because the editor's save drops the
## overrides of an instance that is not, and the cross-branch references are %UniqueName paths,
## which the editor rewrites as relative paths on save (both measured on 4.7.2; the Story 002
## evidence doc keeps the runs).
##
## Performance (AC-7): both views render the shared world, so the frame and draw-call budgets in
## .claude/docs/technical-preferences.md are for the two together. Nothing here draws or updates
## per frame.
##
## Shots (Story 005). A Weapon adds its Shots under World and they belong to the node group
## SHOT_GROUP (shot.tscn stores it). A Round that ends pauses the tree with every shot in flight
## frozen, and restart() unpauses it, so this scene frees the whole group when the MatchController
## emits round_started: no shot of the Round before flies on into the next one and hits a Unit
## just chosen on its Base.
##
## Fuel Cans (Story 006). The Map brings its own Fuel Cans at fixed spots (Map 01's are in
## production/epics/wasteland-fire/story-007-the-map.md; Story 006 kept five greybox Cans in this
## scene until Map 01 replaced them). Each Can polls its own zone, refills the Unit that touches it
## and comes back on its own after its delay (FuelCan), and its root belongs to the node group
## FUEL_CAN_GROUP (fuel_can.tscn stores it), so this scene finds every Can of whichever Map is the
## field with no node path. The Round-over pause stops the Cans with the tree, so when the
## MatchController emits round_started again this scene calls restock() on the whole group: a
## Round that starts again has every Can back at its spot
## (production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-6).

## The node group every Shot in flight belongs to; _free_shots() frees it at every Round start.
const SHOT_GROUP: StringName = &"shots"

## The node group every Fuel Can belongs to; _restock_fuel_cans() brings the whole group back
## whenever a Round starts again.
const FUEL_CAN_GROUP: StringName = &"fuel_cans"

## The Map both Units drive on, typed MapField so any Map scene can be it (Story 007 AC-9). It
## carries the two Bases (player_1_base and player_2_base) where each Player's Unit starts the
## Round and respawns, and the Map's Token stock, which this scene hands to the MatchController
## with the Bases. It sits under World, so it is in the shared world.
@export var field: MapField

## The Unit Player 1 drives. It sits under World, beside Player 1's PlayerDriveInput.
@export var player_1_unit: Unit

## The Unit Player 2 drives. It sits under World, beside Player 2's PlayerDriveInput.
@export var player_2_unit: Unit

## The camera that chases Player 1's Unit. It sits in the SubViewport of Player 1's view.
@export var player_1_camera: ChaseCamera

## The camera that chases Player 2's Unit. It sits in the SubViewport of Player 2's view.
@export var player_2_camera: ChaseCamera

## The node that owns the Round's state: who is alive, the respawn timers and the Flags.
## _ready() hands it the Units, the Bases and the cameras. It sits after the views in this scene's
## root, with RoundRestartInput after it, and what the screen shows about the Round (the respawn
## countdown, the HUD and the Round-over screen) listens to it.
@export var match_controller: MatchController


func _ready() -> void:
	var missing: String = _first_unassigned()
	if not missing.is_empty():
		var reason: String = "The field (with both its Bases), both Units, both cameras and the MatchController must all be assigned."
		push_error("SplitScreen '%s': %s is not assigned, so the Round does not begin and no Unit is placed. %s" % [name, missing, reason])
		return
	var units: Array[Unit] = [player_1_unit, player_2_unit]
	var bases: Array[Base] = [field.player_1_base, field.player_2_base]
	var cameras: Array[ChaseCamera] = [player_1_camera, player_2_camera]
	_warm_up_models()
	match_controller.begin(units, bases, cameras, field.token_stock)
	match_controller.round_started.connect(_free_shots)
	match_controller.round_started.connect(_restock_fuel_cans)


## The name of the first required reference that is not assigned, or an empty string when all
## eight are: the six exports and the field's two Bases.
func _first_unassigned() -> String:
	if field == null:
		return "field"
	if field.player_1_base == null:
		return "field.player_1_base"
	if field.player_2_base == null:
		return "field.player_2_base"
	if player_1_unit == null:
		return "player_1_unit"
	if player_2_unit == null:
		return "player_2_unit"
	if player_1_camera == null:
		return "player_1_camera"
	if player_2_camera == null:
		return "player_2_camera"
	if match_controller == null:
		return "match_controller"
	return ""


## Instances each of the match's Unit types' model scenes once and frees it at once, before the
## Round begins (Story 007 AC-14): a model built from the author's concept kit (KitUnitModel) builds
## its meshes the first time its kit enters the tree, at a cost a spawn would show, and caches them
## (measured on 4.7.2; the Story 007 evidence doc keeps the run), so the builds fall here, hidden by
## the Round's start, and never at a spawn in the Round. Each model is under this scene for its
## build only: it is never drawn and prints nothing.
func _warm_up_models() -> void:
	for stats: UnitStats in match_controller.unit_types():
		if stats == null or stats.model == null:
			continue
		var model: Node = stats.model.instantiate()
		add_child(model)
		remove_child(model)
		model.free()


## Frees every Shot still in flight (the SHOT_GROUP nodes) when a Round starts or restarts, so the
## Round-over pause cannot carry a shot into the next Round. Each shot stops its tick first, so a
## shot queued to be freed cannot still hit something on the tick of the restart.
func _free_shots() -> void:
	for shot: Node in get_tree().get_nodes_in_group(SHOT_GROUP):
		shot.set_physics_process(false)
		shot.queue_free()


## Brings every Fuel Can (the FUEL_CAN_GROUP nodes) back at its spot when a Round starts again
## (Story 006 AC-6): FuelCan.restock() shows a taken Can and makes it available, and leaves an
## available one alone. A Can taken late in a Round would otherwise still be away when the next
## Round starts, until its own delay ran out.
func _restock_fuel_cans() -> void:
	for node: Node in get_tree().get_nodes_in_group(FUEL_CAN_GROUP):
		var fuel_can: FuelCan = node as FuelCan
		if fuel_can != null:
			fuel_can.restock()
