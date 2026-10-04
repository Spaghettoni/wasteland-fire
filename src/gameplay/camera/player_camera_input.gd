class_name PlayerCameraInput
extends Node
## Turns one Player's camera key into a change of that Player's view: one press steps their
## ChaseCamera to the next settings resource of the list views, and after the last one comes the
## first.
##
## Implements: production/epics/wasteland-fire/story-010-camera-from-above.md AC-4 (each Player can
## switch their own view between the view from above and the chase camera of Stories 001 to 009
## with one key, at any time in a Round, so the friends can compare both in one playtest; the other
## Player's view does not change) and AC-5 (the list of views is data in the scene, the key is in
## the Input Map). Vocabulary: CONTEXT.md (Player, View).
##
## The one Input Map action is the prefix plus camera, declared in project.godot. Gameplay code
## names actions, never keys. Like PlayerDriveInput, the prefix is data, stored in the scene that
## owns the Player (split_screen.tscn: p1_ and p2_), and it has no default: a node without a prefix
## pushes an error and reads nothing, so a forgotten one cannot bind two Players to the same key
## without a word.
##
## It acts on the camera and on nothing else: it assigns the next ChaseCameraSettings to
## camera.settings and the camera's own smoothing carries it from one view to the other, so
## nothing snaps. The key is edge-triggered, read in _physics_process like every input node of this
## project: one press steps once and a held key does not repeat. The next view is found from the
## settings the camera has now (the position of that resource in views), so a camera that has been
## given settings outside the list (an evidence run's chase camera) goes to the first view of the
## list on its first press. The first view of the list is the one the Round starts in: the scene
## stores the same resource on the camera. A Player's choice stays through a restart of the Round,
## which this node does not know about; and while the tree is paused, at the end of a Round, it
## reads nothing, and neither does the camera move.

const _SUFFIX_CAMERA: String = "camera"

## The camera this Player's key steers. Required: without it this node pushes an error and reads
## nothing. It sits in the Player's own view, so the other Player's view never changes.
@export var camera: ChaseCamera

## The views the key steps through, in order, each a ChaseCameraSettings .tres with a follow
## sharpness above zero (the first one is the view the Round starts in). Required: a list with
## no view, or with an empty or unusable entry, is an error and the key reads nothing. A list of one
## view changes nothing.
@export var views: Array[ChaseCameraSettings] = []

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

var _action: StringName


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PlayerCameraInput '%s': %s, so the camera key reads nothing." % [name, problem])
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(_action):
		next_view()


## Steps the camera to the next view of the list, or to the first when its settings are not in the
## list. Does nothing without a camera or with an empty list. This is what a press of the key does.
func next_view() -> void:
	if not is_instance_valid(camera) or views.is_empty():
		return
	camera.settings = views[(views.find(camera.settings) + 1) % views.size()]


## What is wrong with this node's wiring, or an empty string when it is usable. Also sets the
## cached action name.
func _first_problem() -> String:
	if camera == null:
		return "camera is not assigned"
	if views.is_empty():
		return "views is empty"
	for view: ChaseCameraSettings in views:
		if view == null or view.follow_sharpness <= 0.0:
			return "a view in views is missing or its follow_sharpness is not above zero"
	if action_prefix.is_empty():
		return "action_prefix is empty (set the Player's prefix, p1_ or p2_, in the scene)"
	_action = StringName(String(action_prefix) + _SUFFIX_CAMERA)
	if not InputMap.has_action(_action):
		return "Input Map action '%s' does not exist" % _action
	return ""
