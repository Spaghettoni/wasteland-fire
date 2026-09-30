class_name SplitScreen
extends Control
## The Story 002 launch scene: two side-by-side views of one shared 3D world, one Motorbike, one
## chase camera and one keyboard layout per Player, both Players driving at once.
##
## Implements: design/game-brief.md build-order item 2 (Split screen for two: two side-by-side
## viewports, one Unit and one fixed keyboard layout per Player, both driving at once) and
## production/epics/wasteland-fire/story-002-split-screen.md AC-1 to AC-7. Vocabulary: CONTEXT.md
## (Player, Unit, Motorbike, Map).
##
## The scene holds the pieces. This script only puts each Player's Unit on its start marker, once,
## when the scene is ready: the spawn of DrivingToy, done for two Players. Where a Unit starts is
## data, the marker's position and facing, asked of the field rather than found by node path, so
## nothing here knows a coordinate. The layout of the scene:
##   SplitScreen (this Control, filling the window)
##     World (Node3D): the field, both Units and both PlayerDriveInputs
##     Views (HBoxContainer): a SubViewportContainer per Player, each holding a SubViewport that
##       holds that Player's ChaseCamera
##     Divider (ColorRect): a thin line drawn over the seam between the two views
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
## Godot 4.7 does not tell two keyboards apart, and it moved the keyboard's device ID from 0 to
## InputEvent.DEVICE_ID_KEYBOARD, so nothing in this project compares InputEvent.device with 0,
## and this script reads no input.
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

## The field both Units drive on. It carries the two start markers: player_start for Player 1 and
## player_2_start for Player 2. It sits under World, so it is in the shared world.
@export var field: GreyboxField

## The Unit Player 1 drives. It sits under World, beside Player 1's PlayerDriveInput.
@export var player_1_unit: Unit

## The Unit Player 2 drives. It sits under World, beside Player 2's PlayerDriveInput.
@export var player_2_unit: Unit

## The camera that chases Player 1's Unit. It sits in the SubViewport of Player 1's view.
@export var player_1_camera: ChaseCamera

## The camera that chases Player 2's Unit. It sits in the SubViewport of Player 2's view.
@export var player_2_camera: ChaseCamera


func _ready() -> void:
	var missing: String = _first_unassigned()
	if not missing.is_empty():
		var reason: String = "The field (with both its start markers), both Units and both cameras must all be assigned."
		push_error("SplitScreen '%s': %s is not assigned, so no Unit is placed. %s" % [name, missing, reason])
		return
	_spawn_unit(player_1_unit, field.player_start, player_1_camera)
	_spawn_unit(player_2_unit, field.player_2_start, player_2_camera)


## The name of the first required reference that is not assigned, or an empty string when all
## seven are: the five exports and the field's two start markers.
func _first_unassigned() -> String:
	if field == null:
		return "field"
	if field.player_start == null:
		return "field.player_start"
	if field.player_2_start == null:
		return "field.player_2_start"
	if player_1_unit == null:
		return "player_1_unit"
	if player_2_unit == null:
		return "player_2_unit"
	if player_1_camera == null:
		return "player_1_camera"
	if player_2_camera == null:
		return "player_2_camera"
	return ""


## Puts a Unit on its start marker and its camera behind it. The order of a teleport, and a spawn
## is one, matters: set the transform first, then reset the Unit's motion and physics
## interpolation, then snap the camera. The other order streaks the Unit across the map for a few
## frames.
func _spawn_unit(unit: Unit, marker: Marker3D, camera: ChaseCamera) -> void:
	unit.global_transform = marker.global_transform
	unit.reset_motion()
	camera.snap_to_target()
