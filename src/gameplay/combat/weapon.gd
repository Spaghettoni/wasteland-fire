class_name Weapon
extends Node
## The one weapon of a Unit: while its trigger is held it fires a Shot straight ahead along the
## Unit's heading, from the muzzle at the shooting height, at the Unit type's fire rate.
##
## Implements: design/game-brief.md MVP feature 5 (one weapon each that fires straight ahead at one
## height, so turning is aiming; the Carrier can shoot) and
## production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3 (every Unit has one
## weapon, fired with one key per Player, that fires straight ahead at the one shooting height all
## Units share; the fire rate and range are data), AC-4 (the shot carries the attacker's damage and
## the matrix) and AC-7 (the Carrier shoots like anyone: nothing here looks at the cargo);
## design/rules.md "Units". Vocabulary: CONTEXT.md (Player, Unit, Carrier).
##
## Driven by command, not by input, like the Unit: whoever holds the trigger (PlayerFireInput for
## a Player, later a bot or a test) calls set_trigger() every physics tick, and the weapon reads
## nothing from the Input singleton. One Weapon per Player's Unit, stored in split_screen.tscn
## beside the input nodes; it knows its Unit, the MatchRules and the Shot scene and nothing else.
##
## Every number is data: the damage, the fire interval, the range, the shot speed and the muzzle
## offset are the Unit's current UnitStats (read live, so a Unit respawned as another type fires
## that type's weapon from the same node), the shooting height and the layers that stop a shot
## are MatchRules (shooting_height, shot_collision_mask) and the multipliers are
## MatchRules.damage_matrix. The muzzle is the Unit's origin plus muzzle_forward along its facing
## (-Z of its basis) plus shooting_height up.
##
## Cadence, in physics frames, never seconds: a shot is fired on a tick when the trigger is held,
## the Unit is alive and Engine.get_physics_frames() has reached the next-fire frame; that frame
## is then set to now plus the interval in ticks, at least one. A held trigger gives exact spacing
## (a Buggy held for 3 s fired 8 shots exactly 24 ticks apart for its 0.4 s on 4.7.2; the Story
## 005 evidence doc keeps the run) and press-release-press cannot beat it. A destroyed or benched
## Unit fires nothing, and PlayerFireInput arms the trigger only once the key was seen up since the
## Unit came alive, so the confirm of a Unit choice (the same key) is never a shot.
##
## Ordering: _ready() sets process_physics_priority one above the Unit's own (higher runs later),
## so the muzzle is where the Unit stands after its own move of this tick, and PlayerFireInput
## sits one below this node, so a press reaches the weapon in the tick it is read. The Shot is
## added to the Unit's parent and launched in the same tick, as Shot requires; it then owns
## itself (and is where the damage is applied, from its own tick: see Shot). The process_mode
## stays INHERIT, so a paused tree stops the weapon with everything else.

## Added to the Unit's process_physics_priority so this node runs just after it.
const PRIORITY_OFFSET: int = 1

## The Unit this weapon belongs to. Assign it before this node enters the tree.
@export var unit: Unit

## The Round's tuning values: shooting_height, shot_collision_mask and damage_matrix. Required. The
## resource is shared, so never write to it at runtime.
@export var rules: MatchRules

## The Shot scene (shot.tscn) this weapon instances for every shot. Required.
@export var shot_scene: PackedScene

var _trigger: bool = false
## The physics frame from which the next shot may be fired; zero lets the first held tick fire.
var _next_fire_frame: int = 0


func _ready() -> void:
	if unit == null:
		push_error("Weapon '%s': unit is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if rules == null:
		push_error("Weapon '%s': rules is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if rules.damage_matrix == null:
		push_error("Weapon '%s': rules.damage_matrix is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	if shot_scene == null:
		push_error("Weapon '%s': shot_scene is not assigned, so it fires nothing." % name)
		set_physics_process(false)
		return
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if not _trigger or not is_instance_valid(unit) or not unit.is_alive:
		return
	var now: int = Engine.get_physics_frames()
	if now < _next_fire_frame:
		return
	_fire()
	var interval_ticks: int = roundi(
			unit.stats.fire_interval_seconds * Engine.physics_ticks_per_second)
	_next_fire_frame = now + maxi(interval_ticks, 1)


## Holds or releases the trigger: true fires at the cadence from this tick on, false stops. Call
## it every physics tick before this node's own tick (see PlayerFireInput); the value stays until
## the next call.
func set_trigger(held: bool) -> void:
	_trigger = held


## Fires one Shot from the muzzle along the Unit's facing with the Unit type's weapon values and
## the Round's, added to the Unit's parent and launched in this tick.
func _fire() -> void:
	var stats: UnitStats = unit.stats
	var facing: Vector3 = -unit.global_transform.basis.z.normalized()
	var muzzle: Vector3 = (unit.global_position + facing * stats.muzzle_forward
			+ Vector3.UP * rules.shooting_height)
	var instance: Node = shot_scene.instantiate()
	var shot: Shot = instance as Shot
	if shot == null:
		if instance != null:
			instance.free()
		push_error("Weapon '%s': shot_scene '%s' is not a Shot scene, so it fires nothing." % [
				name, shot_scene.resource_path])
		return
	unit.get_parent().add_child(shot)
	shot.launch(unit, muzzle, facing, stats.damage, stats.shot_speed, stats.weapon_range,
			rules.damage_matrix, rules.shot_collision_mask)
