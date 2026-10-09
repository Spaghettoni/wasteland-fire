class_name Turret
extends Structure
## An automatic gun of one Base: it turns its barrel toward the other Player's Unit, leads it, and
## fires at it at its own cadence for as long as the Unit is in reach and in sight. Nobody drives,
## builds, repairs or captures it; it has hit points, falls into rubble when they are gone, and
## comes back at the restart (everything a Structure does, which it extends). While one of a Base's
## Turrets stands, the other Player cannot take that Base's Flag (FlagRules reads locks_flag).
##
## Implements: production/epics/wasteland-fire/story-013-turrets.md AC-1 (a solid body outside the
## Gate), AC-2 (what it aims at, how far it reaches and what hides a target), AC-3 (the barrel turns
## at a set rate toward the point where its Shot will meet the target, and it fires only on that
## point, one Shot every interval), AC-4 (hit points, no friendly damage, the rubble), AC-6 (a kill
## is a destruction like any other: the Shot does it, nothing here), AC-7 (the restart) and AC-9
## (every number is TurretStats); design/rules.md "Turrets, Flag Walls and Mines". Vocabulary:
## CONTEXT.md (Turret, Player, Unit, Shot).
##
## Wired, not searched. SplitScreen hands each Turret, with arm(), the other Player's Unit (one node
## per Player for the whole Round, retyped in place), the node its Shots are added under (World,
## where the Weapons put theirs) and the Round's MatchRules (the shooting height, the layers that
## stop a Shot and the damage matrix). A Turret never armed stays idle and logs nothing: the Map
## scene alone has no Players. It reads its target's position and velocity and asks it is_alive, and
## connects to nothing: new code never listens to Unit.destroyed (tokens_data counts its links).
##
## States, the table complete. A tick may take a Turret through several rows (a target that appears
## with the barrel already on it and the cadence ready: IDLE to AIMING to FIRING and back to AIMING,
## all in one tick); between ticks only the state a tick ends in is seen, and a `fired` listener
## reads FIRING. Reach, sight and path are measured from the aimed muzzle, where its Shot will leave
## once the barrel is on the aim: the Turret's centre plus the horizontal direction to the aim point
## times muzzle_forward, at the shooting height. Never from the barrel's current muzzle, which for a
## target beside or behind a resting barrel reads up to twice muzzle_forward too far.
##   IDLE      -> AIMING     the target is in play (Unit.is_alive), its aim point is within
##                           weapon_range of the aimed muzzle and the target is in sight
##   AIMING    -> IDLE       the target is not in play, or no longer in reach or in sight
##   AIMING    -> FIRING     on a tick when the barrel is within aim_tolerance of the aim point, the
##                           path is clear and the cadence has run out
##   FIRING    -> AIMING     on that same tick, after one Shot
##   any state -> DESTROYED  hit points reach 0 (Structure.destroy())
##   DESTROYED -> IDLE       restore()
## The barrel stays where it was while IDLE: nothing turns it home between targets.
##
## The aim point is where the target will be when the Shot arrives, for a target that holds its
## velocity (the intercept of its position and velocity against the Shot's speed, which leaves
## muzzle_forward from the centre: intercept_time()). The velocity is get_real_velocity(), the
## motion of the target's last move, never current_speed, which a Unit pinned against a wall keeps.
## A target no Shot can catch, or whose aim point is out of reach, is not fired on. The barrel turns
## turn_rate times the tick's delta, clamped to the error, so a tracked aim point sits exactly on
## it.
##
## Sight and path. Two ray queries from the aimed muzzle, built as the Shot builds its own, the
## Turret's own body excluded and hit_from_inside true. The sight ray goes to the target's centre at
## the shooting height on the Shot's mask plus sight_extra_mask (the cliffs: a cliff hides a target
## although every Shot passes through cliffs) and must meet the target first; so whatever stops a
## Shot hides a target, a wall, the cover, a Flag Wall, the other Turret or another Unit, and so
## does a cliff. The path ray goes to the aim point on the Shot's mask alone, the target excluded
## too, and must meet nothing. The Flag has no body, so neither ray stops at it.
##
## Order and cadence. The tick runs one above the target's physics priority (as a Weapon runs one
## above its Unit), so it reads where the target stands after its own move of the tick. The cadence
## counts the Turret's own ticks (fire_interval_seconds rounded as the Weapon rounds it), so the
## Round-over pause freezes it, which Engine.get_physics_frames() would not. A Shot is added under
## the shots node and launched in the same tick with launch_from() (see Shot), owned by this
## Turret's Player, so it ends on that Player's own pieces and takes nothing off them, and takes its
## damage from the matrix like a Unit's. What it destroys, the Shot destroys, in its own tick, which
## runs before this one: a Turret destroyed in a tick fires nothing in that tick.
##
## Coming back. restore() (Structure's) also puts the head at its rest yaw, straight out of the
## Gate, and resets its physics interpolation, because World draws physics transforms interpolated
## and the head would otherwise swing across one frame at the restart; it readies the cadence and
## returns to IDLE.

## The states of the class doc's table.
enum State { IDLE, AIMING, FIRING, DESTROYED }

## Added to the target's process_physics_priority so this node runs just after it.
const PRIORITY_OFFSET: int = 1

## Ticks the target has already moved, at the Shot's first test, beyond the ones the flight time
## counts: the Shot added in this tick first moves in the next, after the target's move of that
## tick, so none (measured by the turrets scenario). The lead shifts the target's start back by this
## many ticks of its velocity.
const LAUNCH_LAG_TICKS: int = 0

## Speeds this close to the Shot's, m/s squared, make the intercept's quadratic a straight line.
const _FLAT: float = 0.000001

## Emitted in the tick a Shot has been launched, with the Shot. For display and the evidence:
## nothing in the game listens to it.
signal fired(shot: Shot)

## The part that turns: the yaw pivot of the barrel and the dome, a child of the Turret. Its rest
## heading, rotation zero, is straight out of the Gate (the Turret's own -Z). Required.
@export var head: Node3D

## The Shot scene (combat/shot.tscn) this Turret instances for every Shot. Required.
@export var shot_scene: PackedScene

## What it last aimed at, world space at the shooting height; Vector3.INF while it has no aim. For
## display and the evidence.
var aim_point: Vector3 = Vector3.INF

## How far, in metres at the aim point, the barrel was from the aim at the last tick it aimed; INF
## while it has no aim. For display and the evidence.
var aim_error: float = INF

## The state of the class doc's table: DESTROYED whenever the piece does not stand. Read-only:
## assigning to it pushes an error and changes nothing.
var state: State:
	get:
		return _state if is_standing else State.DESTROYED
	set(_value):
		push_error("Turret '%s': state is read-only. It follows the class doc's table." % name)

var _data: TurretStats
var _target: Unit
var _shots_parent: Node
var _rules: MatchRules
var _state: State = State.IDLE
## This Turret's own count of physics ticks, and the one from which the next Shot may be fired; zero
## lets the first aimed tick fire.
var _ticks: int = 0
var _next_fire: int = 0


func _ready() -> void:
	super._ready()
	_data = stats as TurretStats
	if type_id.is_empty():
		set_physics_process(false)
		return
	if _data == null:
		push_error("Turret '%s': stats is not a TurretStats, so it never aims or fires." % name)
		set_physics_process(false)
		return
	if head == null or shot_scene == null:
		push_error("Turret '%s': head and shot_scene must both be assigned, so it never aims or fires." % name)
		set_physics_process(false)


## One tick of the class doc's table: nothing while it has fallen, otherwise the target read, the aim
## point, reach and sight, the barrel turned and, when everything holds, one Shot.
func _physics_process(delta: float) -> void:
	if not is_standing:
		return
	_ticks += 1
	if _rules == null or not is_instance_valid(_target) or not _target.is_alive:
		_idle()
		return
	var aim: Vector3 = _aim_point()
	if aim == Vector3.INF:
		_idle()
		return
	var muzzle: Vector3 = _aimed_muzzle(aim)
	if muzzle.distance_to(aim) > _data.weapon_range or not _sees(muzzle):
		_idle()
		return
	_state = State.AIMING
	aim_point = aim
	_turn_toward(aim, delta)
	aim_error = _error_at(aim)
	if _ticks >= _next_fire and aim_error <= _data.aim_tolerance and _path_clear(muzzle, aim):
		_state = State.FIRING
		_fire()
		_state = State.AIMING


## Hands the Turret what it needs to do anything: the Unit it fires at (the other Player's), the
## node its Shots are added under (World) and the Round's MatchRules. Call it once, before the Round
## begins; a Turret never armed stays idle. The Turret's tick then runs one above the target's.
func arm(target: Unit, shots_parent: Node, rules: MatchRules) -> void:
	if rules == null or rules.damage_matrix == null:
		push_error("Turret '%s': the rules or their damage matrix are not assigned, so it never aims or fires." % name)
		set_physics_process(false)
		return
	_target = target
	_shots_parent = shots_parent
	_rules = rules
	if target != null:
		process_physics_priority = target.process_physics_priority + PRIORITY_OFFSET


## Structure's destroy(), then the aim forgotten: a Turret that fell has none (aim_point and
## aim_error read INF again until it is restored and has a target).
func destroy() -> void:
	super.destroy()
	aim_point = Vector3.INF
	aim_error = INF


## Brings the Turret back whole and ready (class doc): the head at its rest yaw with no swing across
## the restart, the cadence ready, IDLE, then Structure's restore(), so that a listener of
## `restored` finds a Turret that is whole all through.
func restore() -> void:
	if head != null:
		head.rotation = Vector3.ZERO
		head.reset_physics_interpolation()
	_next_fire = 0
	_state = State.IDLE
	aim_point = Vector3.INF
	aim_error = INF
	super.restore()


## The time in seconds a Shot that leaves `muzzle` metres from the Turret's centre at `speed` takes
## to meet a target that starts `offset` metres from the centre (horizontal) and holds `velocity`,
## or -1.0 when it never does: the smallest t of |offset + velocity * t| = muzzle + speed * t, zero
## when the target is already inside the muzzle's circle. Pure: the same inputs give the same
## answer.
static func intercept_time(offset: Vector2, velocity: Vector2, muzzle: float, speed: float) -> float:
	var c: float = offset.length_squared() - muzzle * muzzle
	if c <= 0.0:
		return 0.0
	var a: float = velocity.length_squared() - speed * speed
	var b: float = offset.dot(velocity) - muzzle * speed
	if absf(a) < _FLAT:
		return -c / (2.0 * b) if b < 0.0 else -1.0
	var discriminant: float = b * b - a * c
	if discriminant < 0.0:
		return -1.0
	var root: float = sqrt(discriminant)
	var best: float = INF
	for t: float in [(-b - root) / a, (-b + root) / a]:
		if t >= 0.0 and t < best:
			best = t
	return best if best < INF else -1.0


## The point the Shot will meet the target at, horizontal and at the shooting height, or
## Vector3.INF when no Shot can meet it.
func _aim_point() -> Vector3:
	var velocity: Vector3 = _target.get_real_velocity()
	var offset: Vector3 = _target.global_position - global_position
	var lag: float = float(LAUNCH_LAG_TICKS) / float(Engine.physics_ticks_per_second)
	var start: Vector2 = Vector2(offset.x, offset.z) - Vector2(velocity.x, velocity.z) * lag
	var heading: Vector2 = Vector2(velocity.x, velocity.z)
	var t: float = intercept_time(start, heading, _data.muzzle_forward, _data.shot_speed)
	if t < 0.0:
		return Vector3.INF
	var meet: Vector2 = start + heading * t
	return Vector3(global_position.x + meet.x, _rules.shooting_height, global_position.z + meet.y)


## Where a Shot leaves once the barrel is on the aim: the centre, muzzle_forward toward the aim
## point, at the shooting height.
func _aimed_muzzle(aim: Vector3) -> Vector3:
	var flat: Vector3 = Vector3(aim.x - global_position.x, 0.0, aim.z - global_position.z)
	var toward: Vector3 = flat.normalized() if flat.length_squared() > 0.0 else -global_transform.basis.z
	return global_position + toward * _data.muzzle_forward + Vector3.UP * _rules.shooting_height


## True when the sight ray from the muzzle to the target's centre meets the target first.
func _sees(muzzle: Vector3) -> bool:
	var centre: Vector3 = Vector3(_target.global_position.x, _rules.shooting_height, _target.global_position.z)
	var excluded: Array[RID] = [get_rid()]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			muzzle, centre, _rules.shot_collision_mask | _data.sight_extra_mask, excluded)
	query.hit_from_inside = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit["collider"] == _target


## True when nothing a Shot stops at lies between the muzzle and the aim point, the target aside.
func _path_clear(muzzle: Vector3, aim: Vector3) -> bool:
	var excluded: Array[RID] = [get_rid(), _target.get_rid()]
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			muzzle, aim, _rules.shot_collision_mask, excluded)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Turns the head toward the aim point by at most turn_rate times the delta, about the Turret's up
## axis, in the Turret's own frame (the Map may turn the whole Turret).
func _turn_toward(aim: Vector3, delta: float) -> void:
	var local: Vector3 = to_local(aim)
	var wanted: float = atan2(-local.x, -local.z)
	var step: float = _data.turn_rate * delta
	head.rotation.y += clampf(angle_difference(head.rotation.y, wanted), -step, step)


## How far the barrel's line passes from the aim point, in metres, or INF when the aim point lies
## behind the barrel.
func _error_at(aim: Vector3) -> float:
	var facing: Vector3 = _barrel_facing()
	var to_aim: Vector3 = Vector3(aim.x - global_position.x, 0.0, aim.z - global_position.z)
	if facing.dot(to_aim) <= 0.0:
		return INF
	return absf(facing.cross(to_aim).y)


## The barrel's horizontal facing in world space, the head's -Z.
func _barrel_facing() -> Vector3:
	var facing: Vector3 = -head.global_transform.basis.z
	facing.y = 0.0
	return facing.normalized()


## Launches one Shot from the barrel's muzzle along the barrel and starts the cadence. The Shot is
## added to the shots node and launched in this tick, as Shot requires.
func _fire() -> void:
	var instance: Node = shot_scene.instantiate()
	var shot: Shot = instance as Shot
	if shot == null:
		if instance != null:
			instance.free()
		push_error("Turret '%s': shot_scene '%s' is not a Shot scene, so it fires nothing." % [name, shot_scene.resource_path])
		set_physics_process(false)
		return
	var facing: Vector3 = _barrel_facing()
	var muzzle: Vector3 = global_position + facing * _data.muzzle_forward + Vector3.UP * _rules.shooting_height
	_shots_parent.add_child(shot)
	shot.launch_from(get_rid(), type_id, player_index, muzzle, facing, _data.damage,
			_data.shot_speed, _data.weapon_range, _rules.damage_matrix, _rules.shot_collision_mask)
	_next_fire = _ticks + maxi(roundi(_data.fire_interval_seconds * Engine.physics_ticks_per_second), 1)
	fired.emit(shot)


## The target is not in play, or not in reach or sight: nothing aimed, nothing turns.
func _idle() -> void:
	_state = State.IDLE
	aim_point = Vector3.INF
	aim_error = INF
