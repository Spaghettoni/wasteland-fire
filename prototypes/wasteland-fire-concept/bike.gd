# PROTOTYPE - NOT FOR PRODUCTION
# Question: Is the two-Player split-screen Water Canister run fun on one keyboard?
# Date: 2026-09-30
extends CharacterBody3D

signal destroyed(bike)

const MAX_SPEED := 24.0
const ACCEL := 20.0
const BRAKE := 36.0
const COAST := 12.0
const REVERSE_MAX := 9.0
const TURN_RATE := 2.8
const RESPAWN_SECONDS := 3.0

var player := 1
var home := Vector3.ZERO
var home_yaw := 0.0
var mount: Marker3D
var speed := 0.0
var alive := true
var carrying = null
var respawn_left := 0.0
var bot_active := false
var bot_target := Vector3.INF
var _last_pos := Vector3.ZERO
var _stuck_frames := 0
var _unstick_frames := 0
var _layer_restore_frames := 0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _layer_restore_frames > 0:
		_layer_restore_frames -= 1
		if _layer_restore_frames == 0:
			collision_layer = 1
			collision_mask = 1
	var p := "p%d_" % player
	if Input.is_action_just_pressed(p + "selfdestruct"):
		die()
		return
	var throttle := Input.get_action_strength(p + "throttle") - Input.get_action_strength(p + "reverse")
	var steer := Input.get_action_strength(p + "left") - Input.get_action_strength(p + "right")
	if bot_active:
		var c := _bot_controls()
		throttle = c.x
		steer = c.y
	if throttle > 0.0:
		speed = move_toward(speed, MAX_SPEED * throttle, ACCEL * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, REVERSE_MAX * throttle, BRAKE * delta)
	else:
		speed = move_toward(speed, 0.0, COAST * delta)
	var dir_sign := 1.0 if speed >= 0.0 else -1.0
	var turn := steer * TURN_RATE * clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * dir_sign
	rotate_y(turn * delta)
	velocity = -global_transform.basis.z * speed
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	for i in get_slide_collision_count():
		var other = get_slide_collision(i).get_collider()
		if other is CharacterBody3D and other != self:
			_contact(other)


func _bot_controls() -> Vector2:
	if bot_target == Vector3.INF:
		return Vector2.ZERO
	# Stuck recovery: two kinematic bikes that meet head-on block each other; back off and turn.
	if _unstick_frames > 0:
		_unstick_frames -= 1
		return Vector2(-1.0, 1.0)
	if global_position.distance_to(_last_pos) < 0.03 and bot_target.distance_to(global_position) > 2.0:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
	_last_pos = global_position
	if _stuck_frames > 20:
		_stuck_frames = 0
		_unstick_frames = 30
		print("UNSTICK P", player, " at ", global_position)
		return Vector2(-1.0, 1.0)
	var to := bot_target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 1.5:
		return Vector2.ZERO
	var fwd := -global_transform.basis.z
	var angle := fwd.signed_angle_to(to.normalized(), Vector3.UP)
	var steer := clampf(angle / 0.5, -1.0, 1.0)
	var throttle := 1.0 if absf(angle) < 1.2 else 0.4
	if dist < 15.0:
		throttle = minf(throttle, maxf(dist / 15.0, 0.15))   # arrive: brake into the target instead of overshooting
	return Vector2(throttle, steer)


# Contact rule (stand-in for combat until story 005): if exactly one of the two bikes
# is a Carrier, that Carrier is destroyed and drops the canister.
func _contact(other) -> void:
	if not other.alive:
		return
	if carrying != null and other.carrying == null:
		die()
	elif carrying == null and other.carrying != null:
		other.die()


func die() -> void:
	if not alive:
		return
	alive = false
	speed = 0.0
	collision_layer = 0
	collision_mask = 0
	if carrying != null:
		carrying.drop()
	visible = false
	respawn_left = RESPAWN_SECONDS
	print("DESTROYED P", player)
	destroyed.emit(self)


func _process(delta: float) -> void:
	if alive:
		return
	respawn_left -= delta
	if respawn_left <= 0.0:
		respawn()


func respawn() -> void:
	global_position = home
	rotation = Vector3(0, home_yaw, 0)
	speed = 0.0
	alive = true
	visible = true
	_layer_restore_frames = 2   # collision comes back two physics frames after the teleport (Jolt sweeps kinematic moves)
	print("RESPAWN P", player)
