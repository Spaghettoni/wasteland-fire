class_name ChaseCamera
extends Camera3D
## A camera that trails a target from behind and above and follows it smoothly.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy: chase camera) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-5 (follows smoothly with no
## visible jitter at 60 fps; camera updated in _process, physics interpolation enabled). Its feel
## values (offset, follow sharpness, look height) are data in a ChaseCameraSettings .tres, never
## script defaults, per the coding standards and the reasoning in UnitStats.
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

## Cosine of the angle from the up axis beyond which the camera counts as looking straight down
## (about 2.5 degrees). There the up axis cannot orient the view, so the target's forward
## direction is used instead. This guards the look-at maths; it is not a feel value.
const STRAIGHT_DOWN_LIMIT: float = 0.999

## The node to chase, normally a Unit. Assign it before this node enters the tree.
@export var target: Node3D

## Where the camera sits and how it follows (a ChaseCameraSettings .tres, for example
## chase_camera_settings.tres). Required: the camera neither follows nor snaps without it, or
## with follow_sharpness not above zero (_can_follow() gates both). Assign it before this node
## enters the tree. The resource is shared, so never write to it at runtime.
@export var settings: ChaseCameraSettings

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


## True while there are settings with a follow_sharpness above zero and a target in the tree.
func _can_follow() -> bool:
	return settings != null and settings.follow_sharpness > 0.0 \
		and is_instance_valid(target) and target.is_inside_tree()


## Moves the camera the given fraction (0 to 1) of the way to its offset from the target
## transform, then aims it at the point look_height above the target.
func _follow(target_transform: Transform3D, weight: float) -> void:
	var desired: Vector3 = target_transform.origin + target_transform.basis * settings.offset
	global_position = global_position.lerp(desired, weight)
	var focus: Vector3 = target_transform.origin + Vector3.UP * settings.look_height
	var view: Vector3 = focus - global_position
	if is_zero_approx(view.length_squared()):
		return
	var up: Vector3 = Vector3.UP
	if absf(view.normalized().dot(Vector3.UP)) > STRAIGHT_DOWN_LIMIT:
		up = -target_transform.basis.z
	look_at(focus, up)
