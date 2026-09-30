class_name Unit
extends CharacterBody3D
## An arcade, kinematic body: what a Player drives (the Motorbike now, the Buggy later).
##
## Unit is the ground-vehicle model (Motorbike, Buggy): _ready() refuses to drive without
## ground_snap_length, and gravity applies off the floor. The Gyrocopter (Story 005) needs its own
## movement model behind the same set_drive_input() / reset_motion() / current_speed surface;
## PlayerDriveInput.unit is typed Unit, so Story 005 decides between a shared base class and a
## subclass. Nothing here pre-builds either.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-2 (throttle, steer, coast to a
## stop), AC-3 (kinematic CharacterBody3D that never tips, bounces or sticks on the flat plane)
## and AC-4 (every feel value comes from a UnitStats resource). Vocabulary: CONTEXT.md.
##
## Driven by command, not by input: the Unit never reads a key or an Input action and keeps no
## singleton state. Whoever drives it (PlayerDriveInput for a Player, later a bot or a test)
## calls set_drive_input(); the Unit applies the latest command in its next _physics_process.
##
## Movement model, once per physics tick with that tick's delta:
##   1. Speed is a signed scalar along the facing direction. It moves toward the throttle target
##      (max_speed forward, reverse_max_speed backward) at acceleration, at braking while the
##      throttle opposes the direction of travel, and toward zero at coast_deceleration when no
##      throttle is held.
##   2. Steering turns the Unit about the up axis at steer * turn_rate * speed fraction, where
##      the speed fraction is |speed| / max_speed (0 to 1). The turn reverses while rolling
##      backward and vanishes at a standstill, so the Unit cannot pivot on the spot.
##   3. Horizontal velocity is the facing direction times speed. Gravity is added only while
##      airborne, then move_and_slide() moves and slides the body.
##   4. The speed is a command, not a measurement: a Unit held against a wall keeps it, which is
##      what lets a pinned Unit still turn at full rate and steer itself free. The one exception
##      is a blocked Unit (touching a wall and moving slower than stats.blocked_speed along its
##      facing, either way) whose throttle is then pushed the other way: it drops the held speed
##      to zero at once and pulls away, instead of first braking off a speed it never had.
##      Measured 2026-09-30 on the greybox field with the tuned Motorbike stats (max_speed 24,
##      braking 36, blocked_speed 0.5; the Story 001 evidence doc keeps the run): reverse after a
##      head-on hit moves the Unit after 2 ticks, against 42 with blocked_speed 0 (braking off the
##      held speed, then the first tick of reverse). Wall slides and the steer-out of a pin never
##      take this path: it fires only when the throttle is pushed against the held speed, and both
##      keep the throttle forward (the walls scenario of the evidence harness covers them).
##
## Ground handling: the body stays in the default GROUNDED motion mode with every other
## CharacterBody3D setting at its default except floor_snap_length and wall_min_slide_angle,
## both copied from the stats' Controller group in _ready(). Nothing here writes the height or
## the pitch and roll by hand, and there is no unstick code: velocity along the facing direction
## slides along walls and recovers from corners. A hit within wall_min_slide_angle of head-on
## stops the Unit dead (the stats' wall_min_slide_angle_degrees; on Godot 4.7.2 with Jolt this
## applies in GROUNDED mode, contrary to the class reference, which says it only affects
## FLOATING: measured 2026-09-30, see UnitStats.wall_min_slide_angle_degrees). Walls must be at
## least 1 m thick.
##
## What the Story 001 evidence harness verified under Jolt: walls and corners on the flat greybox
## field only. Slopes were NOT covered (the field is flat; slopes arrive with the Map in Story
## 007). A throwaway preflight probe on 2026-09-30, not retained, found that the flat-fronted box
## collider in motorbike.tscn climbs 20, 25 and 30 degree ramps but stops dead at the base of 35,
## 40 and 44 degree ones, although floor_max_angle is 45 degrees. No slope scenario exists yet;
## Story 007 must add one to tools/evidence before any Map slope exceeds 30 degrees. Until then
## keep Map slopes at 30 degrees or under, or swap the collider for a chamfered convex hull and
## re-test.
##
## Physics interpolation: the Unit moves only inside _physics_process and leaves its own
## physics_interpolation_mode at INHERIT, so it is interpolated for rendering.

## Largest magnitude of a normalised drive axis (throttle or steer): commands are held to -1..1.
const AXIS_LIMIT: float = 1.0

## Feel values and controller settings for this Unit type (a UnitStats .tres, for example
## motorbike_stats.tres). Required: the Unit will not drive without it, or with max_speed or
## ground_snap_length not above zero. Assign it before the Unit enters the tree. The resource is
## shared, so never write to it at runtime.
@export var stats: UnitStats

## The drive speed along the facing direction in metres per second: positive forward, negative
## in reverse. Read-only: assigning to it pushes an error and changes nothing; it moves only
## through set_drive_input() and the physics tick. It is the speed the Unit is commanding, not
## the speed it achieves: a Unit pressed against a wall with the throttle still held into it
## keeps its drive speed while its real motion is zero (read get_real_velocity() for that), and
## drops it to zero the moment the throttle is pushed the other way (movement model, step 4).
var current_speed: float:
	get:
		return _speed
	set(_value):
		push_error("Unit '%s': current_speed is read-only. Drive the Unit with set_drive_input()." % name)

var _speed: float = 0.0
var _throttle: float = 0.0
var _steer: float = 0.0
## True after a physics tick in which the Unit touched a wall and its real speed along its facing
## was under stats.blocked_speed; read by the next tick's _next_speed().
var _blocked: bool = false


func _ready() -> void:
	if stats == null or stats.max_speed <= 0.0 or stats.ground_snap_length <= 0.0:
		push_error("Unit '%s': stats is missing, or its max_speed or ground_snap_length is not above zero, so it will not drive." % name)
		set_physics_process(false)
		return
	if motion_mode != MOTION_MODE_GROUNDED:
		push_warning("Unit '%s': motion_mode is not GROUNDED, but the ground handling assumes it." % name)
	floor_snap_length = stats.ground_snap_length
	wall_min_slide_angle = deg_to_rad(stats.wall_min_slide_angle_degrees)


func _physics_process(delta: float) -> void:
	_speed = _next_speed(delta)
	rotate_y(_yaw_rate() * delta)
	var facing: Vector3 = -global_transform.basis.z.normalized()
	velocity.x = facing.x * _speed
	velocity.z = facing.z * _speed
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_blocked = is_on_wall() and absf(get_real_velocity().dot(facing)) < stats.blocked_speed


## Sets the drive command the Unit applies from its next physics tick until it is called again.
## Both values are clamped to -1..1. Throttle: +1 is full forward, -1 is full reverse.
## Steer: +1 turns left, -1 turns right. Call it before the Unit's own physics tick (see
## PlayerDriveInput) so the command lands in the same tick.
func set_drive_input(throttle: float, steer: float) -> void:
	_throttle = clampf(throttle, -AXIS_LIMIT, AXIS_LIMIT)
	_steer = clampf(steer, -AXIS_LIMIT, AXIS_LIMIT)


## Stops the Unit dead after a teleport: zeroes speed, velocity, the held command and the blocked
## flag, and resets physics interpolation so the render does not streak across the map. Set the
## new global_transform FIRST and call this second; the other order streaks. Use it for spawn,
## respawn and every other jump.
func reset_motion() -> void:
	_speed = 0.0
	_throttle = 0.0
	_steer = 0.0
	_blocked = false
	velocity = Vector3.ZERO
	if is_inside_tree():
		reset_physics_interpolation()


## Speed after this tick, per the movement model in the class doc: step 4 first (a blocked Unit
## throttled the other way starts from zero), then step 1.
func _next_speed(delta: float) -> float:
	var speed: float = _speed
	if _blocked and signf(_throttle) * signf(speed) < 0.0:
		speed = 0.0
	if is_zero_approx(_throttle):
		return move_toward(speed, 0.0, stats.coast_deceleration * delta)
	var top_speed: float = stats.max_speed if _throttle > 0.0 else stats.reverse_max_speed
	var opposing: bool = signf(_throttle) * signf(speed) < 0.0
	var rate: float = stats.braking if opposing else stats.acceleration
	return move_toward(speed, top_speed * _throttle, rate * delta)


## Yaw rate in radians per second, positive turning left: steer scaled by the speed fraction and
## flipped while rolling backward. Zero at a standstill.
func _yaw_rate() -> float:
	var speed_fraction: float = minf(absf(_speed) / stats.max_speed, 1.0)
	return _steer * stats.turn_rate * speed_fraction * signf(_speed)
