class_name UnitDust
extends Node
## The dust a driving Unit kicks up behind its tyres: soft sandy puffs born at each tyre's contact
## (UnitStats.tyres) as the Unit moves, more the faster it goes, that drift up, grow and fade where
## they were left, so a Unit at speed trails a plume. A picture only.
##
## A child of the Model, with an FxParticles child (the puffs, top_level, so they stay in the world).
## Each physics tick it reads the parent Unit's real speed and emits rate_per_speed puffs a second per
## m/s above min_speed, shared over the tyres. A Unit out of play, or a type with no tyres (the
## Gyrocopter), kicks up none. Every value is data, exports of the model scene and of its pool.

## The pool the puffs are drawn from.
@export var puffs: FxParticles
## Below this speed, m/s, no dust.
@export var min_speed: float = 2.0
## Puffs a second per m/s above min_speed, for the whole Unit.
@export var rate_per_speed: float = 2.2
## Height above the ground a puff is born at, metres.
@export var birth_height: float = 0.15
## How fast a puff is thrown back and up, as a share of the Unit's speed and in m/s.
@export var throw_back: float = 0.15
@export var throw_up: float = 0.7

var _unit: Unit
var _carry: float = 0.0
var _next_tyre: int = 0


func _ready() -> void:
	var model: Node = get_parent()
	_unit = model.get_parent() as Unit if model != null else null
	if _unit == null or puffs == null:
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not _unit.is_alive or _unit.stats == null or _unit.stats.tyres.is_empty():
		_carry = 0.0
		return
	var velocity: Vector3 = _unit.get_real_velocity()
	velocity.y = 0.0
	var speed: float = velocity.length()
	if speed <= min_speed:
		_carry = 0.0
		return
	_carry += (speed - min_speed) * rate_per_speed * delta
	var frame: Transform3D = _unit.global_transform
	var tyres: Array[TyreContact] = _unit.stats.tyres
	var rng: RandomNumberGenerator = puffs.rng()
	while _carry >= 1.0:
		_carry -= 1.0
		var tyre: TyreContact = tyres[_next_tyre % tyres.size()]
		_next_tyre += 1
		var at: Vector3 = frame * Vector3(tyre.offset.x + rng.randf_range(-0.1, 0.1), 0.0, tyre.offset.y)
		at.y += birth_height
		var thrown: Vector3 = -velocity * throw_back + Vector3.UP * throw_up * rng.randf_range(0.5, 1.0)
		thrown += Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.4, 0.4))
		puffs.emit(at, thrown)
