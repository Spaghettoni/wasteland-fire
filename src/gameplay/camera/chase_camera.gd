class_name ChaseCamera
extends Camera3D
## A camera that trails a target from behind and above, or looks down on it from almost straight
## above, and follows it smoothly.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy: chase camera) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-5 (follows smoothly with no
## visible jitter at 60 fps; camera updated in _process, physics interpolation enabled). Its feel
## values (offset, follow sharpness, look height, and since Story 010 the pitch, distance and
## look-ahead of a view from above) are data in a ChaseCameraSettings .tres, never script defaults,
## per the coding standards and the reasoning in UnitStats. Story 010
## (production/epics/wasteland-fire/story-010-camera-from-above.md AC-1 to AC-5) adds the view from
## above as one more settings resource: nothing about how the camera follows changes, only where
## the settings put it, and the settings of a camera can be swapped at any time (PlayerCameraInput
## does it on a key): the smoothing carries the camera from one view to the other.
##
## This is the manual camera of Godot's physics interpolation guide
## (docs.godotengine.org/en/4.7/tutorials/physics/interpolation/advanced_physics_interpolation.html).
## The target moves in _physics_process, on the physics tick, while the camera is drawn every
## rendered frame, so the camera has to follow where the target is DRAWN, not where its last
## physics tick left it. Each of these five rules is load-bearing:
##   1. The camera is independent of the target's branch: _ready() sets top_level, so a moving
##      parent cannot carry it. Place it beside the target, not under it.
##   2. Its own physics_interpolation_mode is OFF, set in _ready(). It already moves once per
##      rendered frame, and interpolating it as well would smooth it twice.
##   3. It moves only in _process(), never in _physics_process().
##   4. It reads the target with get_global_transform_interpolated(), the transform the target
##      is drawn with this frame. global_transform is the last physics tick and makes the camera
##      jump once per tick. That call is expensive and meant for special cases such as cameras,
##      so it is used here and nowhere else.
##   5. The follow is smoothed with 1 - exp(-settings.follow_sharpness * delta), which feels the
##      same at any frame rate.
##
## A Unit faces -Z, so an offset with a positive z puts the camera behind it.
##
## The frame the camera follows in is the target's own while settings.follow_rotation is true (the
## view turns with the Unit) and the world's while it is false (the view keeps its heading).

## Cosine of the angle from the up axis beyond which the camera counts as looking straight down
## (about 2.5 degrees). There the up axis cannot orient the view, so the followed frame's forward
## direction is used instead (the target's, or the world's -Z when settings.follow_rotation is
## false). This guards the look-at maths; it is not a feel value.
const STRAIGHT_DOWN_LIMIT: float = 0.999

## Every one of the engine's 20 visual layers: the cull mask of a camera that hides none. It is the
## Camera3D default, so a camera on settings with no hidden_layers draws what it always drew.
const ALL_VISUAL_LAYERS: int = 0xFFFFF

## The node to chase, normally a Unit. Assign it before this node enters the tree.
@export var target: Node3D

## Where the camera sits and how it follows (a ChaseCameraSettings .tres, for example
## chase_camera_settings.tres, or above_camera_settings.tres for the view from above). Required:
## the camera neither follows nor snaps without it, or with follow_sharpness not above zero
## (_can_follow() gates both). Assign it before this node enters the tree; assigning another one
## later changes the view, and the smoothing moves the camera there (no snap); the layers the new
## settings hide (hidden_layers) stop being drawn at once. The resource is shared, so never write
## to it at runtime.
@export var settings: ChaseCameraSettings:
	set(value):
		settings = value
		_apply_hidden_layers()

## True from a snap until the next _process(): the snap has already placed the camera for this
## frame, and in the frame of a teleport the interpolated transform can still show the old place.
var _skip_next_follow: bool = false


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if target == null:
		push_error("ChaseCamera '%s': target is not assigned, so the camera will not follow." % name)
	if settings == null or settings.follow_sharpness <= 0.0:
		push_error("ChaseCamera '%s': settings is missing or its follow_sharpness is not above zero, so the camera will not follow." % name)
		set_process(false)


func _process(delta: float) -> void:
	if _skip_next_follow:
		_skip_next_follow = false
		return
	if not _can_follow():
		return
	var smoothing: float = 1.0 - exp(-settings.follow_sharpness * delta)
	_follow(target.get_global_transform_interpolated(), smoothing)


## Puts the camera at its full offset from the target and aims it, with no smoothing, then holds
## it there for one frame. Call it once the camera is inside the tree, right after the target is
## teleported (a spawn is one) and after that target's physics interpolation is reset; the
## smoothing would otherwise drag the camera across the map.
##
## It reads the target's global_transform instead of the interpolated one, and it skips the next
## _process() follow. Measured 2026-09-30 on Godot 4.7.2 (the Story 001 evidence doc keeps the
## run): after a teleport made from _process, get_global_transform_interpolated() still returns
## the old place for the rest of that frame, so following in that frame pulls the camera back
## toward where the target was. A teleport made inside a physics tick does not show this, and the
## skip costs it nothing.
func snap_to_target() -> void:
	if not _can_follow():
		return
	_follow(target.global_transform, 1.0)
	_skip_next_follow = true


## Draws every visual layer except those the settings hide (settings.hidden_layers).
func _apply_hidden_layers() -> void:
	cull_mask = ALL_VISUAL_LAYERS if settings == null else ALL_VISUAL_LAYERS & ~settings.hidden_layers


## True while there are settings with a follow_sharpness above zero and a target in the tree.
func _can_follow() -> bool:
	return settings != null and settings.follow_sharpness > 0.0 \
		and is_instance_valid(target) and target.is_inside_tree()


## Moves the camera the given fraction (0 to 1) of the way to where the settings put it, then aims
## it at the look point: look_height above the target and look_ahead metres ahead of it along the
## followed frame's heading. The height is added in the world's up on purpose, as it always was, so
## a chase view (no look-ahead) computes exactly what it did before Story 010.
func _follow(target_transform: Transform3D, weight: float) -> void:
	var frame: Basis = target_transform.basis if settings.follow_rotation else Basis.IDENTITY
	var desired: Vector3 = target_transform.origin + frame * settings.local_offset()
	global_position = global_position.lerp(desired, weight)
	var focus: Vector3 = target_transform.origin + Vector3.UP * settings.look_height \
		+ frame * Vector3(0.0, 0.0, -settings.look_ahead)
	var view: Vector3 = focus - global_position
	if is_zero_approx(view.length_squared()):
		return
	var up: Vector3 = Vector3.UP
	if absf(view.normalized().dot(Vector3.UP)) > STRAIGHT_DOWN_LIMIT:
		up = -frame.z
	look_at(focus, up)
