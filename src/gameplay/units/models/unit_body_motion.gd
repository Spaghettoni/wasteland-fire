class_name UnitBodyMotion
extends Node
## Makes a Unit's drawn body move as a vehicle's does: it squats back when the Unit speeds up and
## dives when it slows, leans out of a turn (or into it, for a Gyrocopter that banks), and bobs over
## the ground while it drives. A picture only: it turns and lifts its parent Model, never the Unit,
## its collider, its Shots or its tyres' tracks.
##
## A child of the Model (UnitModel); each physics tick it reads the parent Unit's real velocity and
## heading, works out the acceleration along and across the Unit, and moves the Model's tilt toward a
## target with a spring (stiffness) and a damper (damping), so the body overshoots a little and
## settles, as on springs. The Model's pose is set in the physics tick, so World's interpolation
## draws it smoothly. A Unit out of play, or a Model that rises over cliffs (an evidence-only frozen
## model), is left at rest.
##
## Every value is data, exports of the model scene.

## Degrees of pitch per m/s^2 along the Unit (positive: nose up when speeding up, a car's squat;
## negative: nose down, a Gyrocopter's).
@export var pitch_per_accel: float = 0.5
## Degrees of roll per m/s^2 across the Unit (positive: leans out of the turn, a car's; negative:
## banks into it, a Gyrocopter's).
@export var roll_per_accel: float = 0.6
## Largest tilt either way, degrees.
@export var max_pitch: float = 4.0
@export var max_roll: float = 5.0
## The spring and damper of the tilt (1/s^2 and 1/s).
@export var stiffness: float = 120.0
@export var damping: float = 11.0
## Height above the Unit's floor the body tilts about, metres.
@export var pivot_height: float = 0.6
## Bob over the ground at full speed: metres up and down, and degrees of extra pitch and roll, on a
## wave whose crests are bump_spacing metres apart along the way driven.
@export var bump_height: float = 0.03
@export var bump_tilt: float = 0.8
@export var bump_spacing: float = 2.3
## The speed, m/s, at which the bob is full.
@export var full_speed: float = 14.0

var _model: Node3D
var _unit: Unit
var _rest: Vector3 = Vector3.ZERO
var _scale: Vector3 = Vector3.ONE
var _ready_pose: bool = false
var _pitch: float = 0.0
var _roll: float = 0.0
var _pitch_rate: float = 0.0
var _roll_rate: float = 0.0
var _last_forward_speed: float = 0.0
var _last_heading: float = 0.0
var _has_last: bool = false
var _travelled: float = 0.0


func _ready() -> void:
	_model = get_parent() as Node3D
	_unit = _model.get_parent() as Unit if _model != null else null
	var model: UnitModel = _model as UnitModel
	if _unit == null or (model != null and model.rise_over_cliffs):
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if delta <= 0.0:
		return
	if not _ready_pose:
		_rest = _model.position
		_scale = _model.scale
		_ready_pose = true
	if not _unit.is_alive:
		_has_last = false
		_pitch = 0.0
		_roll = 0.0
		_pitch_rate = 0.0
		_roll_rate = 0.0
		_pose(0.0, 0.0, 0.0)
		return
	var frame: Basis = _unit.global_transform.basis.orthonormalized()
	var velocity: Vector3 = _unit.get_real_velocity()
	velocity.y = 0.0
	var forward: Vector3 = -frame.z
	forward.y = 0.0
	forward = forward.normalized()
	var forward_speed: float = velocity.dot(forward)
	var heading: float = atan2(forward.x, forward.z)
	var along: float = 0.0
	var across: float = 0.0
	if _has_last:
		along = (forward_speed - _last_forward_speed) / delta
		var turn: float = wrapf(heading - _last_heading, -PI, PI) / delta
		across = forward_speed * turn
	_last_forward_speed = forward_speed
	_last_heading = heading
	_has_last = true
	# A teleport (a spawn, a place) or a crash reads as a huge acceleration: a cap keeps it a jolt.
	along = clampf(along, -40.0, 40.0)
	across = clampf(across, -40.0, 40.0)
	var target_pitch: float = clampf(along * pitch_per_accel, -max_pitch, max_pitch)
	var target_roll: float = clampf(-across * roll_per_accel, -max_roll, max_roll)
	_pitch_rate += (stiffness * (target_pitch - _pitch) - damping * _pitch_rate) * delta
	_roll_rate += (stiffness * (target_roll - _roll) - damping * _roll_rate) * delta
	_pitch = clampf(_pitch + _pitch_rate * delta, -max_pitch * 1.5, max_pitch * 1.5)
	_roll = clampf(_roll + _roll_rate * delta, -max_roll * 1.5, max_roll * 1.5)
	var speed: float = velocity.length()
	_travelled += speed * delta
	var share: float = clampf(speed / maxf(full_speed, 0.01), 0.0, 1.0)
	var w: float = TAU * _travelled / maxf(bump_spacing, 0.01)
	var bob: float = bump_height * share * (0.6 * sin(w) + 0.4 * sin(w * 2.37 + 1.3))
	var bump_pitch: float = bump_tilt * share * sin(w * 1.13 + 0.4)
	var bump_roll: float = bump_tilt * share * 0.7 * sin(w * 0.71 + 2.1)
	_pose(_pitch + bump_pitch, _roll + bump_roll, bob)


func _pose(pitch_degrees: float, roll_degrees: float, lift: float) -> void:
	var turn: Basis = Basis.from_euler(Vector3(deg_to_rad(pitch_degrees), 0.0, deg_to_rad(roll_degrees)))
	var pivot: Vector3 = Vector3.UP * pivot_height
	_model.transform = Transform3D(turn.scaled_local(_scale),
			_rest + pivot - turn * pivot + Vector3.UP * lift)
