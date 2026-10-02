class_name Shot
extends Node3D
## One projectile in flight: fired by a Weapon, it flies straight along one direction at one speed,
## at the shooting height every Unit shares, until it meets a Unit, a wall or the end of its range,
## and applies its damage to a Unit it meets, scaled by the damage matrix.
##
## Implements: design/game-brief.md MVP feature 5 (one weapon each that fires straight ahead at one
## height, so turning is aiming; the damage-multiplier matrix as data) and
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3 (a hit applies the
## attacker's damage, times the multiplier, to the Unit hit and never to the shooter; the range is
## data), AC-4 (damage taken is damage times matrix.multiplier(attacker type, target type), read
## from one data resource, no type named in code) and AC-7 (a Carrier's shot is a shot like any
## other: nothing here looks at the cargo); design/rules.md "Units". Vocabulary: CONTEXT.md.
##
## A projectile with a short flight, not hitscan (a starting choice of the Story 005 design, tuned
## in data): the Weapon instances this scene, adds it to the Unit's parent and calls launch() in the
## same physics tick (a shot placed one tick after add_child streaks from the world origin; launch()
## resets the physics interpolation), and from then on the shot owns itself. Everything it needs
## comes through launch(): the shooter (its RID is excluded from the hit test and its type_id
## recorded at launch, so a shooter destroyed or retyped mid-flight changes nothing), the origin
## (the muzzle), the direction (the shooter's facing), the damage (UnitStats.damage), the speed
## (shot_speed), the range (weapon_range), the matrix (MatchRules.damage_matrix) and the layers that
## stop it (MatchRules.shot_collision_mask: the map, the units and the gyrocopters layers, never the
## cliffs_water layer, so a shot passes over cliffs and water and stops at walls and at Units). A
## benched or destroyed Unit sits on layer zero and is never hit.
##
## Flight and hit test, once per physics tick with that tick's delta: the shot advances
## speed * delta along its direction, never beyond its range, and tests the segment it covers with
## one PhysicsDirectSpaceState3D.intersect_ray (hit_from_inside true, the shooter excluded). A
## muzzle starting inside a wall (a Unit stopped flush against it) or inside another Unit's
## collider is a hit on the first tick, which is why the shooter must be excluded. On a hit the
## shot is moved to the hit position, a Unit hit takes apply_damage(damage * multiplier), and the
## shot frees itself; at the end of its range it frees itself. Measured on 4.7.2: no tunnelling at
## 60 m/s and 60 Hz in 200 of 200 hits (the Story 005 evidence doc keeps the run).
##
## Why the damage is applied from this node's own physics tick, and never from an Area3D's
## body_entered: Story 004's hand-off. Unit.apply_damage() may destroy the Unit, and the Round's
## handler of `destroyed` reparents the canister a Carrier held; the physics server refuses that
## reparent while it flushes the area and body signals, and the canister would stay a hidden child
## of the wreck. There is no Area3D here and no signal handler: the ray query, the damage and the
## free all happen inside _physics_process. The process_mode stays INHERIT, so a paused tree (the
## Round over) freezes every shot in flight.
##
## The visual is a small bright unshaded box (shot.tscn) laid along -Z; launch() turns the node so
## -Z is the direction of flight. Nothing here is a gameplay value: the numbers all come through
## launch() from UnitStats and MatchRules.

var _shooter_rid: RID
var _shooter_type: StringName = &""
var _direction: Vector3 = Vector3.FORWARD
var _damage: float = 0.0
var _speed: float = 0.0
var _max_range: float = 0.0
var _matrix: DamageMatrix
var _mask: int = 0
## Metres flown so far; the shot ends when it reaches _max_range.
var _travelled: float = 0.0
## True after launch(): a shot that was never launched does nothing.
var _launched: bool = false


func _physics_process(delta: float) -> void:
	if not _launched:
		return
	var step: float = minf(_speed * delta, _max_range - _travelled)
	if step <= 0.0:
		queue_free()
		return
	var from: Vector3 = global_position
	var to: Vector3 = from + _direction * step
	var excluded: Array[RID] = [_shooter_rid]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, to, _mask, excluded)
	query.hit_from_inside = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		var target: Unit = hit["collider"] as Unit
		if target != null:
			target.apply_damage(_damage * _matrix.multiplier(_shooter_type, target.type_id))
		queue_free()
		return
	global_position = to
	_travelled += step
	if _travelled >= _max_range:
		queue_free()


## Starts the flight. Call it in the physics tick that added this node to the tree, right after
## add_child(): the shooter (never hit by this shot; its type_id is read now, for the matrix), the
## origin (the muzzle, world space), the direction (normalised here; the shooter's facing), the
## damage the shot carries, its speed in m/s, the range in metres it flies at most, the damage
## matrix and the collision mask of the layers that stop it. Places the node at the origin facing
## the direction and resets its physics interpolation, so the first drawn frame is at the muzzle.
func launch(shooter: Unit, origin: Vector3, direction: Vector3, damage: float, speed: float,
		max_range: float, matrix: DamageMatrix, mask: int) -> void:
	_shooter_rid = shooter.get_rid()
	_shooter_type = shooter.type_id
	_direction = direction.normalized()
	_damage = damage
	_speed = speed
	_max_range = max_range
	_matrix = matrix
	_mask = mask
	_travelled = 0.0
	global_transform = Transform3D(Basis.looking_at(_direction, Vector3.UP), origin)
	reset_physics_interpolation()
	_launched = true
