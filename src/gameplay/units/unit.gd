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
## Implements: design/game-brief.md build-order item 1 (Driving toy) and MVP feature 3 (Bases,
## destruction and respawn); production/epics/wasteland-fire/story-001-driving-toy.md AC-2
## (throttle, steer, coast to a stop), AC-3 (kinematic CharacterBody3D that never tips, bounces
## or sticks on the flat plane) and AC-4 (every feel value comes from a UnitStats resource);
## production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-2 (hit points from
## the data, destroyed at zero), AC-3 (what a respawn needs from the Unit: spawn()) and AC-5
## (Self-destruct: destroy()); production/epics/wasteland-fire/story-004-water-canister-and-win.md
## AC-2 (whether this Unit may carry the Water Canister is data, can_carry and carry_offset from
## UnitStats, never a type check) and AC-7 (hit_points_changed, the hit points the HUD shows);
## design/rules.md "Destruction, respawn and unit swap" and "Handling the Water Canister".
## Vocabulary: CONTEXT.md.
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
##
## Hit points, destruction and respawn: the Unit spawns with stats.max_hit_points. apply_damage()
## subtracts from them and destroy() ends the Unit at once (Self-destruct); the hit that takes
## them to zero takes the same path. A destroyed Unit leaves play: hidden, no collision with
## anything (layer and mask zeroed, put back from the values saved in _ready()), no physics tick,
## motion and held drive command zeroed. It stays in the tree, so its camera and its owner keep
## their references, and spawn() puts the same body back anywhere: hit points refilled, collision
## restored, motion reset. The Unit decides nothing beyond that: it emits `destroyed` once and
## calls nobody, so what a destruction means and when the Unit respawns is the Round's business
## (MatchController). A Unit is alive with full hit points at _ready(), so the Story 001 sandbox
## needs no spawn(). One that refused to drive in _ready() is never alive: destroy() and
## apply_damage() ignore it and spawn() leaves it alone.
##
## Carrying (Story 004): whether this Unit may pick up the Water Canister, and where it rides, is
## the Unit type's data (UnitStats.can_carry and carry_offset: true and a tail mount for the
## Motorbike, false and zero for a type that never carries), exposed read-only as can_carry and
## carry_offset and never a type check in code (AC-2). The Unit does none of the carrying: the
## Round rules (MatchController) read the two values, reparent the canister under the Unit at
## carry_offset and drop it where the Unit is destroyed. The Unit never calls the canister, the
## MatchController or another Unit, and does not know it is a Carrier. Hit points are shown, not
## polled: hit_points_changed fires once per change (apply_damage(), destroy(), spawn()) with the
## value and the maximum, so a HUD can listen without reading the Unit every frame (AC-7).
##
## Leaving play. With collision layer and mask both zero the body neither collides nor is collided
## with, so the other Unit drives through a wreck and a Unit put down on one is not pushed, and
## nothing logs. PROCESS_MODE_DISABLED does the same but made Jolt log 'Parameter "space" is null'
## when destroy() ran inside the Unit's own physics tick (a preflight probe, not retained), so it is
## not used. This state holds on every tick of a wait. Consequences for Stories 004 and 005: an
## Area3D zone on the zones layer watches the layer that destroy() zeroes and spawn() restores, so
## it sees a Unit leave after destroy() and enter after spawn(), a physics tick or so later (measure
## it before relying on the tick); and a Player still holding the throttle when the Unit respawns
## drives off at once, because PlayerDriveInput keeps writing the command to the hidden Unit and
## reset_motion() zeroes it only once.
##
## Respawning onto another Unit. The collider is 1.0 m tall, so a Unit put down inside another one
## is pushed out along the shallowest axis, and when the horizontal overlap is deeper than that
## metre the shallowest axis is the vertical one: in the Story 003 preflight a Unit spawned exactly
## on a live one ended under the floor, one spawned a metre in front of it was thrown into the air
## and one beside it perched on its roof (a throwaway probe, no numbers kept). is_spot_taken() is
## the exact test, so whoever spawns the Unit (MatchController) puts it on a free spot instead: a
## spare spawn point of the Base on the tick the spawn point is found taken, or, while every spot is
## taken, no spot at all until one frees. Put down on a free spot, the Unit lands on the floor, on
## the spot it was given.

## Emitted once, when a live Unit is destroyed: its hit points reached zero, or destroy() was
## called. The Unit has already left play when it fires (is_alive is false, hit_points is zero),
## and nothing follows the emit, so a handler may call spawn() on the Unit at once. It is emitted
## in the context of whoever called destroy() or apply_damage(): a tick, never a physics signal
## handler (see apply_damage()).
signal destroyed

## Emitted once per change of hit_points, with the new value and stats.max_hit_points: after a hit
## the Unit survives (apply_damage()), with zero when it is destroyed (the lethal hit and
## destroy() share one path and emit once, after the Unit left play and right before
## `destroyed`), and with the refill when it spawns (spawn()). Never for an ignored call. It is
## for display (Story 004 AC-7, the HUD): a handler shows the numbers and does not act on the Unit.
signal hit_points_changed(hit_points: float, max_hit_points: float)

## Largest magnitude of a normalised drive axis (throttle or steer): commands are held to -1..1.
const AXIS_LIMIT: float = 1.0

## Feel values, controller settings and hit points for this Unit type (a UnitStats .tres, for
## example motorbike_stats.tres). Required: the Unit will not drive without it, or with max_speed,
## ground_snap_length or max_hit_points not above zero. Assign it before the Unit enters the
## tree. The resource is shared, so never write to it at runtime.
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

## Hit points left: stats.max_hit_points when the Unit spawns, down to zero, which destroys it.
## Read-only: assigning to it pushes an error and changes nothing; it moves only through
## apply_damage(), destroy() and spawn().
var hit_points: float:
	get:
		return _hit_points
	set(_value):
		push_error("Unit '%s': hit_points is read-only. Change it with apply_damage(), destroy() or spawn()." % name)

## True while the Unit is in play: from _ready() on, until it is destroyed, and again after
## spawn(). False for a destroyed Unit and for one that refused to drive in _ready(). Read-only
## like hit_points: assigning to it pushes an error and changes nothing.
var is_alive: bool:
	get:
		return _is_alive
	set(_value):
		push_error("Unit '%s': is_alive is read-only. Change it with destroy() or spawn()." % name)

## Whether this Unit may pick up and carry a Water Canister: stats.can_carry, the Unit type's data
## (Story 004 AC-2; true for the Motorbike, never a type check). False while the Unit refused to
## drive in _ready() (invalid stats). Read-only: assigning to it pushes an error and changes
## nothing; change it in the UnitStats .tres.
var can_carry: bool:
	get:
		return stats.can_carry if _can_drive else false
	set(_value):
		push_error("Unit '%s': can_carry is read-only. It is the Unit type's data: UnitStats.can_carry." % name)

## Where a carried Water Canister rides, in this Unit's local space: stats.carry_offset, the Unit
## type's data (a tail mount for the Motorbike). Whoever carries (MatchController) places the
## canister's origin here. Vector3.ZERO while the Unit refused to drive in _ready(). Read-only:
## assigning to it pushes an error and changes nothing; change it in the UnitStats .tres.
var carry_offset: Vector3:
	get:
		return stats.carry_offset if _can_drive else Vector3.ZERO
	set(_value):
		push_error("Unit '%s': carry_offset is read-only. It is the Unit type's data: UnitStats.carry_offset." % name)

var _speed: float = 0.0
var _throttle: float = 0.0
var _steer: float = 0.0
## True after a physics tick in which the Unit touched a wall and its real speed along its facing
## was under stats.blocked_speed; read by the next tick's _next_speed().
var _blocked: bool = false
var _hit_points: float = 0.0
var _is_alive: bool = false
## True once _ready() accepted the stats. A Unit that refused to drive never becomes alive, and
## spawn() never wakes it.
var _can_drive: bool = false
## The collision layer and mask as authored, saved in _ready() and put back by spawn(): destroy()
## zeroes both to take the Unit out of the physics world.
var _play_collision_layer: int = 0
var _play_collision_mask: int = 0


func _ready() -> void:
	if stats == null or stats.max_speed <= 0.0 or stats.ground_snap_length <= 0.0 or stats.max_hit_points <= 0.0:
		push_error("Unit '%s': stats is missing, or its max_speed, ground_snap_length or max_hit_points is not above zero, so it will not drive." % name)
		set_physics_process(false)
		return
	if motion_mode != MOTION_MODE_GROUNDED:
		push_warning("Unit '%s': motion_mode is not GROUNDED, but the ground handling assumes it." % name)
	floor_snap_length = stats.ground_snap_length
	wall_min_slide_angle = deg_to_rad(stats.wall_min_slide_angle_degrees)
	_play_collision_layer = collision_layer
	_play_collision_mask = collision_mask
	_hit_points = stats.max_hit_points
	_is_alive = true
	_can_drive = true


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


## Takes hit points off a live Unit: subtracts amount, never below zero, and destroys the Unit
## when none are left (Story 003 AC-2). A hit the Unit survives emits hit_points_changed once; the
## lethal hit emits it once from destroy(), with zero. Ignored when amount is zero, negative or NaN
## and when the Unit is not alive (nothing is emitted), so a destroyed Unit cannot be destroyed
## twice. The debug-damage key calls it until weapons (Story 005) do. Call it from a physics tick
## or from _process, never from an Area3D or body signal handler: the Round's handler of
## `destroyed` reparents the canister a Carrier held (WaterCanister.drop_at()), and the physics
## server refuses a reparent of a node holding an Area3D while it flushes those signals, so the
## canister would stay a hidden child of the wreck. A projectile records its hit in body_entered
## and applies it on its own tick.
func apply_damage(amount: float) -> void:
	if not _is_alive or not (amount > 0.0):
		return
	_hit_points = maxf(_hit_points - amount, 0.0)
	if _hit_points <= 0.0:
		destroy()
		return
	hit_points_changed.emit(_hit_points, stats.max_hit_points)


## Destroys a live Unit at once, whatever its hit points: Self-destruct (Story 003 AC-5) and the
## last hit of apply_damage() take this same path. The Unit leaves play (see the class doc), then
## hit_points_changed is emitted once, with zero, then `destroyed`, once. Does nothing when the
## Unit is not alive. Call it from a tick, never from a physics signal handler (apply_damage()).
func destroy() -> void:
	if not _is_alive:
		return
	_is_alive = false
	_hit_points = 0.0
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	reset_motion()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	destroyed.emit()


## Puts the Unit in play at the given transform: the first spawn of a Round and every respawn use
## this one call (Story 003 AC-1, AC-3). The Unit must be in the tree. It sets global_transform
## first and then calls reset_motion() (the teleport order), refills hit_points to
## stats.max_hit_points, shows the Unit, puts its collision back and turns its physics tick on. It
## works on a destroyed Unit and on one still alive (the first spawn), and emits hit_points_changed
## once, with the refill, and nothing else. Call it inside a physics tick, in the same tick as
## ChaseCamera.snap_to_target(): from _process the frame of the teleport still draws the Unit at
## the wreck while the camera has already moved. A Unit that refused to drive in _ready() stays out
## of play: this pushes an error and changes nothing, so it never wakes a Unit whose stats are
## invalid.
func spawn(at: Transform3D) -> void:
	if not _can_drive:
		push_error("Unit '%s': spawn() ignored: the Unit refused to drive in _ready() (see that error), so it stays where it is and out of play." % name)
		return
	global_transform = at
	reset_motion()
	_hit_points = stats.max_hit_points
	_is_alive = true
	visible = true
	collision_layer = _play_collision_layer
	collision_mask = _play_collision_mask
	set_physics_process(true)
	hit_points_changed.emit(_hit_points, stats.max_hit_points)


## True when another Unit stands where this one would overlap it if spawn(at) were called now: a
## body on this Unit's own collision layer (the Units layer, saved in _ready()) overlaps this Unit's
## collision shape placed at `at`. Only bodies count: not zones, not the map, and never this Unit
## itself. MatchController asks it before every respawn, at the Base's spawn point and, when that is
## taken, at each spare spawn point in turn, and puts the Unit only where it is false, because a
## Unit put down inside another one is thrown through the floor or into the air (class doc). Call it
## inside a physics tick (it queries the physics space). False for a Unit without a collision shape
## or outside the tree.
func is_spot_taken(at: Transform3D) -> bool:
	var shape_node: CollisionShape3D = _find_shape_node()
	if shape_node == null or shape_node.shape == null or not is_inside_tree():
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var excluded: Array[RID] = [get_rid()]
	query.shape = shape_node.shape
	query.transform = at * (global_transform.affine_inverse() * shape_node.global_transform)
	query.collision_mask = _play_collision_layer
	query.exclude = excluded
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


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


## The first CollisionShape3D child, or null: the shape is_spot_taken() moves to the spawn point.
func _find_shape_node() -> CollisionShape3D:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null
