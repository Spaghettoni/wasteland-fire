class_name Shot
extends Node3D
## One projectile in flight: fired by a Weapon, it flies straight along one direction at one speed,
## at the shooting height every Unit shares, until it meets a Unit, a wall or the end of its range,
## and applies its damage to the Unit or Structure it meets, scaled by the damage matrix.
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
## comes through launch(), or launch_from() for a shooter that is not a Unit: the shooter (its RID
## is excluded from the hit test, and its type_id and player_index are recorded at launch, so a
## shooter destroyed or retyped mid-flight changes nothing), the origin
## (the muzzle), the direction (the shooter's facing), the damage (UnitStats.damage), the speed
## (shot_speed), the range (weapon_range), the matrix (MatchRules.damage_matrix) and the layers that
## stop it (MatchRules.shot_collision_mask: the map, the units, the gyrocopters and the cover
## layers, never the cliffs_water layer, so a shot passes over cliffs and water and stops at walls,
## at the Map's cover and at Units). A benched or destroyed Unit sits on layer zero and is never
## hit. A Gyrocopter flies over the cover (Story 009) but fires and is hit at the one shooting
## height: with its muzzle over a piece it fires from inside the piece, so its shot is a hit on the
## cover on its first tick, and a shot at a Gyrocopter over cover meets the cover's face first.
##
## Flight and hit test, once per physics tick with that tick's delta: the shot advances
## speed * delta along its direction, never beyond its range, and tests the segment it covers with
## one PhysicsDirectSpaceState3D.intersect_ray (hit_from_inside true, the shooter excluded). A
## muzzle starting inside a wall (a Unit stopped flush against it) or inside another Unit's
## collider is a hit on the first tick, which is why the shooter must be excluded. On a hit the
## shot is moved to the hit position, a target that meets the contract below takes
## apply_damage(damage * multiplier), and the shot frees itself; at the end of its range it frees
## itself. Measured on 4.7.2: no tunnelling at 60 m/s and 60 Hz in 200 of 200 hits (the Story 005
## evidence doc keeps the run).
##
## The damage contract (Story 012, production/epics/wasteland-fire/story-012-flag-walls.md AC-3).
## Any collider on the mask ends the shot, and the shot damages the ones that pass a test any body
## can pass, with no cast to Unit: the collider offers apply_damage(); it has a type_id that is a
## StringName (the key of the matrix, a UnitStats' or a StructureStats'); and it is not the
## shooter's own Player's, that is its player_index (read with get(), and -1 when it has none)
## differs from the shooter's, or one of the two is below 0. A Unit and a Structure meet it; a
## wall, the cover, a body with no type_id and a piece of the shooter's own Player are a stop with
## no damage. Damage between Units is what it was: a Unit with no Player (-1) is nobody's.
##
## Why the damage is applied from this node's own physics tick, and never from an Area3D's
## body_entered: Story 004's hand-off. Unit.apply_damage() may destroy the Unit, and the Round's
## handler of `destroyed` reparents the Flag a Carrier held; the physics server refuses that
## reparent while it flushes the area and body signals, and the Flag would stay a hidden child
## of the wreck. There is no Area3D here and no signal handler: the ray query, the damage and the
## free all happen inside _physics_process. The process_mode stays INHERIT, so a paused tree (the
## Round over) freezes every shot in flight.
##
## The visual is a small bright unshaded box (shot.tscn) laid along -Z; launch() turns the node so
## -Z is the direction of flight. Nothing here is a gameplay value: the numbers all come through
## launch() from UnitStats and MatchRules.

var _shooter_rid: RID
var _shooter_type: StringName = &""
## The Player the shooter belongs to (Unit.player_index), or -1 for a shooter no Player owns.
var _shooter_player_index: int = -1
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
		_damage_target(hit["collider"] as Object)
		queue_free()
		return
	global_position = to
	_travelled += step
	if _travelled >= _max_range:
		queue_free()


## Applies the shot's damage to what it ended on, when that is something it may damage (the class
## doc's contract): the collider offers apply_damage(), it has a type_id that is a StringName (the
## key of the matrix; DamageMatrix.multiplier() takes typed arguments, so a body without one would
## be a script error at the hit) and it does not belong to the shooter's own Player. Anything else
## is a stop with no damage, and nothing is logged. A local is never named owner: a Node has one.
func _damage_target(collider: Object) -> void:
	if collider == null or not collider.has_method(&"apply_damage"):
		return
	var type_value: Variant = collider.get(&"type_id")
	if typeof(type_value) != TYPE_STRING_NAME:
		return
	var target_type: StringName = type_value
	var player_value: Variant = collider.get(&"player_index")
	var target_player: int = int(player_value) if typeof(player_value) == TYPE_INT else -1
	if _shooter_player_index >= 0 and target_player == _shooter_player_index:
		return
	collider.call(&"apply_damage", _damage * _matrix.multiplier(_shooter_type, target_type))


## Starts the flight of a Unit's shot. Call it in the physics tick that added this node to the tree,
## right after add_child(): the shooter (never hit by this shot; its RID, type_id and player_index
## are read now, for the hit test, the matrix and the owner test), the origin (the muzzle, world
## space), the direction (normalised here; the shooter's facing), the damage the shot carries, its
## speed in m/s, the range in metres it flies at most, the damage matrix and the collision mask of
## the layers that stop it. One call to launch_from().
func launch(shooter: Unit, origin: Vector3, direction: Vector3, damage: float, speed: float,
		max_range: float, matrix: DamageMatrix, mask: int) -> void:
	launch_from(shooter.get_rid(), shooter.type_id, shooter.player_index, origin, direction,
			damage, speed, max_range, matrix, mask)


## Starts the flight of a shot whose shooter is anything with a body, a type and a Player (a Unit
## through launch(); a Turret will call it directly, Story 013). Call it in the physics tick that
## added this node to the tree, right after add_child(). shooter_rid is excluded from the hit test,
## shooter_type is the attacker's key in the matrix and shooter_player_index is the Player whose
## own pieces this shot leaves untouched (-1 for none: it then damages everything it meets). The
## rest is launch()'s. Places the node at the origin facing the direction and resets its physics
## interpolation, so the first drawn frame is at the muzzle. A null matrix is one error and the shot
## frees itself: only Weapon._ready() checks it for a Unit's shots, and the hit would call it.
func launch_from(shooter_rid: RID, shooter_type: StringName, shooter_player_index: int,
		origin: Vector3, direction: Vector3, damage: float, speed: float, max_range: float,
		matrix: DamageMatrix, mask: int) -> void:
	if matrix == null:
		push_error("Shot: the damage matrix is not assigned, so the shot is not launched and frees itself.")
		queue_free()
		return
	_shooter_rid = shooter_rid
	_shooter_type = shooter_type
	_shooter_player_index = shooter_player_index
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
