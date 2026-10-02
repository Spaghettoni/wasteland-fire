class_name Unit
extends CharacterBody3D
## An arcade, kinematic body: what a Player drives. One body per Player, which takes the type the
## Player chose (the Motorbike, the Buggy, the Truck or the Gyrocopter) from a UnitStats at each
## spawn: feel values, controller settings, hit points, collider, collision layers and the greybox
## model (Story 005).
##
## Unit is the one body for every type, the Gyrocopter included (decided 2026-10-01): it drives on
## the floor in GROUNDED mode like the ground types, with the movement model below, and its model
## draws it hovering. What sets it apart is data alone, the collision layer and mask in its
## UnitStats: it crosses the cliffs_water layer that stops the ground types and passes through them
## (and they through it), so nothing here names a type. The one branch on can_fly is Fuel (Story
## 006, movement model step 5): a flying Unit whose tank runs dry crashes, while a ground Unit
## stops and can still turn on the spot. The separate movement model and the subclass this doc once
## left open to Story 005 were not needed.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy), MVP feature 3 (Bases,
## destruction and respawn) and MVP item 5 (the four Units);
## production/epics/wasteland-fire/story-001-driving-toy.md AC-2 (throttle, steer, coast to a
## stop), AC-3 (kinematic CharacterBody3D that never tips, bounces or sticks on the flat plane) and
## AC-4 (every feel value comes from a UnitStats resource);
## production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-2 (hit points from
## the data, destroyed at zero), AC-3 (what a respawn needs from the Unit: spawn()) and AC-5
## (Self-destruct: destroy()); production/epics/wasteland-fire/story-004-water-canister-and-win.md
## AC-2 (whether this Unit may carry the Water Canister is data, can_carry and carry_offset from
## UnitStats, never a type check) and AC-7 (hit_points_changed, the hit points the HUD shows);
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-1 (the four types are
## four UnitStats that spawn() applies to the same body: stats, collider, layers and silhouette
## from the data), AC-5 (the Gyrocopter crosses cliffs and water and passes through ground Units
## through the layer and mask in its data, and spawn spots are checked per type) and AC-8 (the
## silhouette is the type's model, painted with team_material, in both views; the hit points and
## their maximum come from the chosen type's data);
## production/epics/wasteland-fire/story-006-fuel-and-fuel-cans.md AC-1 to AC-5 and AC-8 (the
## tank from the type's data, burned only while moving; an empty ground Unit stops but turns and
## fires, an empty Gyrocopter crashes through destroy(), a spawn gives a fixed partial tank, and
## destroy() works at zero Fuel), AC-6 (refuel()) and AC-7 (fuel_changed, what the HUD shows);
## design/rules.md "Units", "Destruction and respawn" and "Resources". Vocabulary: CONTEXT.md.
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
##      backward and vanishes at a standstill, so the Unit cannot pivot on the spot (a ground
##      Unit with an empty tank is the exception, step 5).
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
##   5. Fuel (Story 006), first in the tick. A Unit has a tank once spawn() has run, while its
##      type's fuel_capacity is above zero (the driving toy's Unit never spawns and burns
##      nothing). The tank burns stats.fuel_use * delta on each tick that starts with a drive
##      speed that is not approximately zero: a Unit coasting to a stop burns until then, one held
##      against a wall with the throttle on keeps burning, one standing or hovering still burns
##      nothing. An empty ground Unit gets zero throttle in step 1 (it coasts to a standstill;
##      forward and reverse are ignored) and turns at steer * empty_turn_rate in step 2 at any
##      speed; it still fires and can self-destruct. An empty flying Unit calls destroy() (the
##      Fuel crash) and the rest of its tick does not run.
##
## Ground handling: the body stays in the default GROUNDED motion mode with every other
## CharacterBody3D setting at its default except floor_snap_length and wall_min_slide_angle,
## both copied from the stats' Controller group in _ready() and again by spawn() for a new type.
## Nothing here writes the height or the pitch and roll by hand, and there is no unstick code:
## velocity along the facing direction slides along walls and recovers from corners. A hit within
## wall_min_slide_angle of head-on stops the Unit dead (the stats' wall_min_slide_angle_degrees;
## on Godot 4.7.2 with Jolt this applies in GROUNDED mode, contrary to the class reference, which
## says it only affects FLOATING: measured 2026-09-30, see
## UnitStats.wall_min_slide_angle_degrees). Walls must be at least 1 m thick.
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
## anything (layer and mask zeroed, put back from the play values: the scene's own, saved in
## _ready(), or the type's, see Unit types below), no physics tick, motion and held drive command
## zeroed. It stays in the tree, so its camera and its owner keep their references, and spawn()
## puts the same body back anywhere: hit points refilled, collision restored, motion reset. The
## Unit decides nothing beyond that: it emits `destroyed` once and calls nobody, so what a
## destruction means and when the Unit respawns is the Round's business (MatchController). A Unit
## is alive with full hit points at _ready(), so the Story 001 sandbox needs no spawn(). One that
## refused to drive in _ready() is never alive: destroy() and apply_damage() ignore it and spawn()
## leaves it alone. destroy() and leave_play() empty the tank and spawn() gives the type's starting
## share of it (step 5), so dying is never a free refuel (Story 006 AC-5).
##
## Carrying (Story 004): whether this Unit may pick up the Water Canister, and where it rides, is
## the Unit type's data (UnitStats.can_carry and carry_offset: true and a tail mount for the
## Motorbike, false and zero for a type that never carries), exposed read-only as can_carry and
## carry_offset and never a type check in code (AC-2). The Unit does none of the carrying: the
## Round rules (MatchController) read the two values, reparent the canister under the Unit at
## carry_offset and drop it where the Unit is destroyed. The Unit never calls the canister, the
## MatchController or another Unit, and does not know it is a Carrier. Hit points are shown, not
## polled: hit_points_changed fires once per change (apply_damage(), destroy(), leave_play(),
## spawn()) with the value and the maximum, so a HUD can listen without reading the Unit every
## frame (AC-7). Fuel is shown the same way, through fuel_changed (Story 006 AC-7).
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
##
## Unit types (Story 005 AC-1, AC-8). The scene (motorbike.tscn) authors one type: its stats, its
## box collider, its collision layer and mask and its Body and Nose meshes, and _ready() applies
## nothing beyond that, so the driving toy and every Unit nobody spawns keep the scene as it is.
## spawn(at, new_stats) with a UnitStats turns the same node into that type before it puts it in
## play: stats, floor_snap_length and wall_min_slide_angle, the play collision layer and mask (the
## type's where they are not zero, else the scene's own, saved in _ready()), a new BoxShape3D of
## collision_size on the first CollisionShape3D child moved to collision_center (a new shape, never
## a write to the scene's, which is one sub-resource shared by every instance), and the model: the
## scene's own MeshInstance3D children are hidden and left in the tree, the previous Model child is
## removed and freed, the type's model scene is instanced as the last child named Model, and every
## MeshInstance3D under it in the "team_colour" group gets team_material as material_override (the
## Body, and the Truck's Cab). One node per Player, retyped in place, is the Story 004 hand-off:
## the HUD, the chase camera, both input nodes, the Round and a carried canister all hold the node.
## The physics space lags one tick behind a spawn: the swapped shape answers queries at once, the
## teleport and the restored layer and mask on the next tick (measured on 4.7.2; the Story 005
## evidence doc keeps the run), which is why the Round stamps a settle tick and never tests a spot
## on the tick another Unit spawns.
##
## Benching: leave_play() takes a live Unit out of play without a destruction (the Round uses it at
## the start of a Round and at a restart, while the Player chooses the next type): collision layer
## and mask zeroed first, then hidden, physics tick off, motion zeroed, hit points and Fuel zero,
## hit_points_changed then fuel_changed once each, with zero, and never `destroyed`. The order
## matters: a body whose mask changes while it overlaps a cliff is pushed under the floor, one
## benched or teleported first is not (measured; the Story 005 evidence doc keeps the run).
##
## Spot checks across types (Story 005 AC-5): is_spot_taken(at, for_stats) tests the given type's
## box and spot_mask (the units and gyrocopters layers in the data), so a Truck is checked as a
## Truck before it is spawned on a Motorbike's body, and a Gyrocopter parked on the spawn point is
## found although Units never collide with it.

## Emitted once, when a live Unit is destroyed: its hit points reached zero, or destroy() was
## called. The Unit has already left play when it fires (is_alive is false, hit_points is zero),
## and nothing follows the emit, so a handler may call spawn() on the Unit at once. It is emitted
## in the context of whoever called destroy() or apply_damage(): a tick, never a physics signal
## handler (see apply_damage()). Never emitted by leave_play().
signal destroyed

## Emitted once per change of hit_points, with the new value and stats.max_hit_points: after a hit
## the Unit survives (apply_damage()), with zero when it is destroyed (the lethal hit and
## destroy() share one path and emit once, after the Unit left play and right before
## `destroyed`), with zero when it is benched (leave_play()), and with the refill when it spawns
## (spawn(), with the maximum of the type it spawned as). Never for an ignored call. It is for
## display (Story 004 AC-7, the HUD): a handler shows the numbers and does not act on the Unit.
signal hit_points_changed(hit_points: float, max_hit_points: float)

## Emitted when the Fuel in the tank changes, with the new value and stats.fuel_capacity (Story 006
## AC-7, the HUD's Fuel gauge): once per tick the Unit burns Fuel, once when refuel() adds some,
## once with the starting tank at a spawn and once with zero when it is destroyed or benched,
## whatever it held (both right after hit_points_changed, and before `destroyed`). Never for an
## ignored call. For display: a handler shows the numbers and does not act on the Unit.
signal fuel_changed(fuel: float, capacity: float)

## Largest magnitude of a normalised drive axis (throttle or steer): commands are held to -1..1.
const AXIS_LIMIT: float = 1.0

## The node group a model scene puts its team-coloured meshes in (the Body; the Truck's Cab too):
## spawn() paints them with team_material. A scene convention, not a gameplay value.
const TEAM_COLOUR_GROUP: StringName = &"team_colour"

## Name of the child spawn() instances from UnitStats.model.
const MODEL_NODE_NAME: StringName = &"Model"

## Feel values, controller settings and hit points for this Unit type (a UnitStats .tres, for
## example motorbike_stats.tres). Required: the Unit will not drive without it, or with max_speed,
## ground_snap_length or max_hit_points not above zero. Assign it before the Unit enters the
## tree; spawn() replaces it with the chosen type's (Story 005). The resource is shared, so never
## write to it at runtime.
@export var stats: UnitStats

## The Player's body colour (Story 005 AC-8): split_screen.tscn stores the Player's body material
## here, the same one the scene's own Body shows through its material_override. spawn() paints
## every mesh of the type's model that is in the "team_colour" group with it as material_override;
## null leaves the model its own neutral colour.
@export var team_material: Material

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
## apply_damage(), destroy(), leave_play() and spawn().
var hit_points: float:
	get:
		return _hit_points
	set(_value):
		push_error("Unit '%s': hit_points is read-only. Change it with apply_damage(), destroy() or spawn()." % name)

## True while the Unit is in play: from _ready() on, until it is destroyed or benched, and again
## after spawn(). False for a destroyed or benched Unit and for one that refused to drive in
## _ready(). Read-only like hit_points: assigning to it pushes an error and changes nothing.
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

## Which type this Unit is: stats.type_id, the Unit type's data (Story 005; &"motorbike", &"buggy",
## &"truck" or &"gyrocopter" in the shipped data), for the damage matrix and for display. Empty
## while the Unit refused to drive in _ready(). Read-only: assigning to it pushes an error and
## changes nothing; the type changes through spawn() with a UnitStats.
var type_id: StringName:
	get:
		return stats.type_id if _can_drive else &""
	set(_value):
		push_error("Unit '%s': type_id is read-only. It is the Unit type's data: UnitStats.type_id." % name)

## Fuel in the tank, in Fuel units (Story 006): the type's starting share at each spawn, down while
## the Unit moves, up through refuel(), zero once destroyed or benched (full and never burned on a
## Unit nobody spawned). Read-only: assigning to it pushes an error and changes nothing.
var fuel: float:
	get:
		return _fuel
	set(_value):
		push_error("Unit '%s': fuel is read-only. Add Fuel with refuel(); it burns while the Unit moves." % name)

## The most Fuel the tank holds, the top of the Fuel gauge: stats.fuel_capacity, the Unit type's
## data (Story 006 AC-1); 0.0 while the Unit refused to drive in _ready(). Read-only: assigning to
## it pushes an error and changes nothing.
var fuel_capacity: float:
	get:
		return stats.fuel_capacity if _can_drive else 0.0
	set(_value):
		push_error("Unit '%s': fuel_capacity is read-only. It is the Unit type's data: UnitStats.fuel_capacity." % name)

## True while the Unit is alive, has a tank (it has spawned and its fuel_capacity is above zero)
## and no Fuel left (Story 006 AC-3): a ground Unit then cannot drive but still turns and fires.
## Read-only: assigning to it pushes an error and changes nothing.
var is_fuel_empty: bool:
	get:
		return _is_alive and _has_tank() and _fuel <= 0.0
	set(_value):
		push_error("Unit '%s': is_fuel_empty is read-only. Add Fuel with refuel()." % name)

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
## The collision layer and mask the Unit plays with, put back by spawn(): the scene's own, saved
## in _ready(), until spawn() applies a type whose collision_layer or collision_mask is not zero.
## destroy() and leave_play() zero the body's to take it out of the physics world.
var _play_collision_layer: int = 0
var _play_collision_mask: int = 0
## The collision layer and mask the scene authored, saved in _ready(): the play values fall back
## to them for a type whose collision_layer or collision_mask is zero.
var _scene_collision_layer: int = 0
var _scene_collision_mask: int = 0
## The type's model instanced by spawn() (the child named Model), or null while the scene's own
## meshes show.
var _model: Node3D
## Fuel in the tank, what fuel reads (Story 006): full from _ready(), then set by spawn(), burned
## by _burn_fuel(), added to by refuel() and zeroed by destroy() and leave_play().
var _fuel: float = 0.0
## True once spawn() has put the Unit in play (Story 006): from then on the Unit has a tank while
## its type's fuel_capacity is above zero. Never set on a Unit nobody spawns (the driving toy's).
var _has_spawned: bool = false


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
	_scene_collision_layer = collision_layer
	_scene_collision_mask = collision_mask
	_hit_points = stats.max_hit_points
	_fuel = stats.fuel_capacity
	_is_alive = true
	_can_drive = true


func _physics_process(delta: float) -> void:
	_burn_fuel(delta)
	if not _is_alive:
		return
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
## twice. A Shot calls it from its own physics tick (see Shot), and the debug-damage key still does
## while match_rules.debug_damage is above zero. Call it from a physics tick or from _process,
## never from an Area3D or body signal handler: the Round's handler of `destroyed` reparents the
## canister a Carrier held (WaterCanister.drop_at()), and the physics server refuses a reparent of
## a node holding an Area3D while it flushes those signals, so the canister would stay a hidden
## child of the wreck.
func apply_damage(amount: float) -> void:
	if not _is_alive or not (amount > 0.0):
		return
	_hit_points = maxf(_hit_points - amount, 0.0)
	if _hit_points <= 0.0:
		destroy()
		return
	hit_points_changed.emit(_hit_points, stats.max_hit_points)


## Adds Fuel up to the type's fuel_capacity and returns the amount added, emitting fuel_changed once
## (Story 006 AC-6: a Fuel Can calls it and is taken only when this is above zero). Returns 0.0 and
## does nothing for a Unit that is not alive, an amount not above zero (or NaN), a Unit without a
## tank and a full tank. Fuel above zero lets an empty Unit drive again at once, on this call. Call
## it from a tick; it changes no physics state.
func refuel(amount: float) -> float:
	if not _is_alive or not (amount > 0.0) or not _has_tank():
		return 0.0
	var room: float = stats.fuel_capacity - _fuel
	if not (room > 0.0):
		return 0.0
	var added: float = minf(amount, room)
	_fuel = stats.fuel_capacity if added >= room else _fuel + added
	fuel_changed.emit(_fuel, stats.fuel_capacity)
	return added


## Destroys a live Unit at once, whatever its hit points: Self-destruct (Story 003 AC-5; it works
## at zero Fuel, Story 006 AC-8), the last hit of apply_damage() and the Fuel crash of a flying
## Unit, called from its own tick (Story 006 AC-4), take this same path. The Unit leaves play (see
## the class doc) with its hit points and Fuel at zero, then hit_points_changed and fuel_changed
## are emitted once each, with zero, then `destroyed`, once. Does nothing when the Unit is not
## alive. Call it from a tick, never from a physics signal handler (apply_damage()).
func destroy() -> void:
	if not _is_alive:
		return
	_is_alive = false
	_hit_points = 0.0
	_fuel = 0.0
	visible = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	reset_motion()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	fuel_changed.emit(_fuel, stats.fuel_capacity)
	destroyed.emit()


## Takes a live Unit out of play without destroying it (Story 005: the Round benches both Units at
## the start of a Round and at a restart, while each Player chooses the next type). Collision
## layer and mask are zeroed first, then the Unit is hidden, its physics tick turned off, its
## motion and held drive command zeroed and its hit points and Fuel set to zero;
## hit_points_changed and then fuel_changed are emitted once each, with zero, and `destroyed`
## never, so the Round sees no destruction and no respawn wait starts. Does nothing when the Unit
## is not alive (benched, destroyed or refused to drive). spawn() puts the Unit back. Call it from
## a tick or from a _ready(), never from a physics signal handler (apply_damage()).
func leave_play() -> void:
	if not _is_alive:
		return
	_is_alive = false
	_hit_points = 0.0
	_fuel = 0.0
	collision_layer = 0
	collision_mask = 0
	visible = false
	set_physics_process(false)
	reset_motion()
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	fuel_changed.emit(_fuel, stats.fuel_capacity)


## Puts the Unit in play at the given transform: the first spawn of a Round and every respawn use
## this one call (Story 003 AC-1, AC-3). The Unit must be in the tree. With new_stats it first
## becomes that type (Story 005 AC-1, AC-8): a UnitStats whose first_problem() is not empty pushes
## an error and changes nothing, else stats, floor_snap_length and wall_min_slide_angle, the play
## collision layer and mask (the type's where not zero, else the scene's own), the collider (a new
## BoxShape3D of collision_size at collision_center on the first CollisionShape3D child, unless
## collision_size is zero) and the model (when model is not null: the scene's own meshes hidden,
## the previous Model freed, the type's scene instanced as the last child named Model, its
## "team_colour" meshes painted with team_material) are applied before the spawn proper. With
## new_stats null (the default) the Unit keeps its type and this behaves exactly as before Story
## 005. The spawn proper sets global_transform first and then calls reset_motion() (the teleport
## order), refills hit_points to stats.max_hit_points, gives the Unit its tank (Story 006 AC-5)
## with stats.fuel_capacity times spawn_fuel_fraction clamped to 0..1, whatever it held before (a
## fixed partial tank in the shipped data, so dying is never a free refuel), shows the Unit, puts
## the play collision layer and mask back after the teleport (a mask that changes while the body
## overlaps a cliff pushes it under the floor; the Story 005 evidence doc keeps the run) and turns
## its physics tick on. It works on a destroyed Unit, on a benched one (leave_play()) and on one
## still alive, and emits hit_points_changed once, with the refill and the new maximum, then
## fuel_changed once, with the starting tank and the capacity, and nothing else. Call it
## inside a physics tick, in the same tick as ChaseCamera.snap_to_target(): from _process the
## frame of the teleport still draws the Unit at the wreck while the camera has already moved. A
## Unit that refused to drive in _ready() stays out of play: this pushes an error and changes
## nothing, so it never wakes a Unit whose stats are invalid.
func spawn(at: Transform3D, new_stats: UnitStats = null) -> void:
	if not _can_drive:
		push_error("Unit '%s': spawn() ignored: the Unit refused to drive in _ready() (see that error), so it stays where it is and out of play." % name)
		return
	if new_stats != null:
		var problem: String = new_stats.first_problem()
		if not problem.is_empty():
			push_error(("Unit '%s': spawn() ignored: the UnitStats given is unusable (%s), so the "
					+ "Unit keeps its type, its place and its state.") % [name, problem])
			return
		_apply_type(new_stats)
	global_transform = at
	reset_motion()
	_hit_points = stats.max_hit_points
	_fuel = stats.fuel_capacity * clampf(stats.spawn_fuel_fraction, 0.0, 1.0)
	_has_spawned = true
	_is_alive = true
	visible = true
	collision_layer = _play_collision_layer
	collision_mask = _play_collision_mask
	set_physics_process(true)
	hit_points_changed.emit(_hit_points, stats.max_hit_points)
	fuel_changed.emit(_fuel, stats.fuel_capacity)


## True when another Unit stands where this one would overlap it if spawn(at, for_stats) were
## called now: a body on the layers of the spot mask overlaps the collision box placed at `at`.
## With for_stats null the box is this Unit's own collision shape and the mask its own play
## collision layer, as before Story 005. With for_stats given (the type about to be spawned, Story
## 005 AC-5) the box is that type's collision_size at collision_center and the mask its spot_mask
## (the units and gyrocopters layers in the data: a Gyrocopter parked on the spawn point is found
## although Units never collide with it); a zero collision_size falls back to this Unit's shape
## and a zero spot_mask to its play layer, so a Truck is checked as a Truck before it is put down
## on a Motorbike's body. Only bodies count: not zones, not the map, and never this Unit itself.
## MatchController asks it before every spawn, at the Base's spawn point and, when that is taken,
## at each spare spawn point in turn, and puts the Unit only where it is false, because a Unit put
## down inside another one is thrown through the floor or into the air (class doc). Call it inside
## a physics tick (it queries the physics space), and never on the tick another Unit spawned: the
## space shows its teleport and its restored layer one tick later. False for a Unit without a
## collision shape or outside the tree.
func is_spot_taken(at: Transform3D, for_stats: UnitStats = null) -> bool:
	var shape_node: CollisionShape3D = _find_shape_node()
	if shape_node == null or shape_node.shape == null or not is_inside_tree():
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var excluded: Array[RID] = [get_rid()]
	var shape: Shape3D = shape_node.shape
	var shape_offset: Transform3D = global_transform.affine_inverse() * shape_node.global_transform
	var mask: int = _play_collision_layer
	if for_stats != null:
		if for_stats.collision_size != Vector3.ZERO:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = for_stats.collision_size
			shape = box
			shape_offset = Transform3D(Basis.IDENTITY, for_stats.collision_center)
		if for_stats.spot_mask != 0:
			mask = for_stats.spot_mask
	query.shape = shape
	query.transform = at * shape_offset
	query.collision_mask = mask
	query.exclude = excluded
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Speed after this tick, per the movement model in the class doc: step 4 first (a blocked Unit
## throttled the other way starts from zero), then step 1. Every rule reads the effective
## throttle: the held one, or zero while the tank of a ground Unit is empty (step 5).
func _next_speed(delta: float) -> float:
	var throttle: float = 0.0 if _is_stranded() else _throttle
	var speed: float = _speed
	if _blocked and signf(throttle) * signf(speed) < 0.0:
		speed = 0.0
	if is_zero_approx(throttle):
		return move_toward(speed, 0.0, stats.coast_deceleration * delta)
	var top_speed: float = stats.max_speed if throttle > 0.0 else stats.reverse_max_speed
	var opposing: bool = signf(throttle) * signf(speed) < 0.0
	var rate: float = stats.braking if opposing else stats.acceleration
	return move_toward(speed, top_speed * throttle, rate * delta)


## Yaw rate in radians per second, positive turning left: steer scaled by the speed fraction and
## flipped while rolling backward, zero at a standstill; while the tank of a ground Unit is empty
## (step 5), steer * stats.empty_turn_rate at any speed, so it turns on the spot.
func _yaw_rate() -> float:
	if _is_stranded():
		return _steer * stats.empty_turn_rate
	var speed_fraction: float = minf(absf(_speed) / stats.max_speed, 1.0)
	return _steer * stats.turn_rate * speed_fraction * signf(_speed)


## Step 5 of the movement model (Story 006 AC-2, AC-4), first in the tick: a Unit with a tank, Fuel
## and a fuel_use above zero whose drive speed is not approximately zero (moving) burns
## stats.fuel_use * delta, clamped at zero (an approximately zero remainder is exactly zero, so the
## tank is empty on its nominal tick), and emits fuel_changed once. An empty flying Unit then calls
## destroy(), on every tick, so one spawned with an empty tank crashes at once.
func _burn_fuel(delta: float) -> void:
	if not _has_tank():
		return
	if _fuel > 0.0 and stats.fuel_use > 0.0 and not is_zero_approx(_speed):
		_fuel = maxf(_fuel - stats.fuel_use * delta, 0.0)
		if is_zero_approx(_fuel):
			_fuel = 0.0
		fuel_changed.emit(_fuel, stats.fuel_capacity)
	if stats.can_fly and _fuel <= 0.0:
		destroy()


## True while the Unit has a tank (Story 006): spawn() has run and its fuel_capacity is above zero.
func _has_tank() -> bool:
	return _has_spawned and stats.fuel_capacity > 0.0


## True while this ground Unit's tank is empty (Story 006 AC-3): no throttle, turns on the spot.
func _is_stranded() -> bool:
	return is_fuel_empty and not stats.can_fly


## Turns this body into the given type (Story 005 AC-1): the stats and the controller settings
## _ready() copies for the scene's type, the play collision layer and mask (the type's where not
## zero, else the scene's own), the collider (unless collision_size is zero) and the model (unless
## model is null). It writes neither collision_layer nor collision_mask of the body itself (spawn()
## applies the play values after the teleport) and emits nothing. The caller has checked
## first_problem().
func _apply_type(new_stats: UnitStats) -> void:
	stats = new_stats
	floor_snap_length = stats.ground_snap_length
	wall_min_slide_angle = deg_to_rad(stats.wall_min_slide_angle_degrees)
	_play_collision_layer = _scene_collision_layer
	_play_collision_mask = _scene_collision_mask
	if stats.collision_layer != 0:
		_play_collision_layer = stats.collision_layer
	if stats.collision_mask != 0:
		_play_collision_mask = stats.collision_mask
	if stats.collision_size != Vector3.ZERO:
		var shape_node: CollisionShape3D = _find_shape_node()
		if shape_node == null:
			push_error("Unit '%s': no CollisionShape3D child to take the type's collider." % name)
		else:
			var box: BoxShape3D = BoxShape3D.new()
			box.size = stats.collision_size
			shape_node.shape = box
			shape_node.position = stats.collision_center
	if stats.model != null:
		_swap_model(stats.model)


## Replaces the visual with the type's model scene (Story 005 AC-1, AC-8): the scene's own
## MeshInstance3D children are hidden and left in the tree, the previous Model child is removed
## from the tree before it is freed (so its name is free at once), and the new one is instanced as
## the LAST child, named Model, so the CollisionShape3D stays the first child (_find_shape_node()),
## then painted with team_material. A scene whose root is not a Node3D is refused with an error.
func _swap_model(model_scene: PackedScene) -> void:
	var instance: Node = model_scene.instantiate()
	if not (instance is Node3D):
		push_error("Unit '%s': UnitStats.model '%s' is not a Node3D scene, so the visual stays." % [
				name, model_scene.resource_path])
		instance.free()
		return
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	if _model != null:
		remove_child(_model)
		_model.queue_free()
		_model = null
	_model = instance as Node3D
	_model.name = MODEL_NODE_NAME
	add_child(_model)
	_paint_team_colour(_model)


## Paints every MeshInstance3D under `node` that is in TEAM_COLOUR_GROUP with team_material as
## material_override (the Body; the Truck's Cab), depth first. With team_material null the meshes
## keep the model's own neutral colour.
func _paint_team_colour(node: Node) -> void:
	if team_material == null:
		return
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.is_in_group(TEAM_COLOUR_GROUP):
			(child as MeshInstance3D).material_override = team_material
		_paint_team_colour(child)


## The first CollisionShape3D child, or null: the shape is_spot_taken() moves to the spawn point
## and spawn() gives the type's collider.
func _find_shape_node() -> CollisionShape3D:
	for child: Node in get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null
