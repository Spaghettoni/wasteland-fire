class_name PlayerDriveInput
extends Node
## Turns one Player's keyboard actions into drive commands for a Unit.
##
## Implements: design/game-brief.md build-order item 1 (Driving toy) and
## production/epics/wasteland-fire/story-001-driving-toy.md AC-2 (W and S throttle, A and D
## steer for Player 1). Vocabulary: CONTEXT.md (Player, Unit).
##
## The four Input Map actions are the prefix plus throttle, reverse, steer_left and steer_right,
## declared in project.godot. Gameplay code names actions, never keys. Nothing here is specific
## to one Player: the prefix is data, injected by the scene that owns the Player (driving_toy.tscn
## holds Player1DriveInput with p1_ beside the Motorbike; Story 002 adds a Player2DriveInput with
## p2_ beside its Unit). It is deliberately not part of a Unit scene, and it has no default: a
## node without a prefix pushes an error and drives nothing, so the value is always stored in the
## scene and a forgotten one cannot bind two Players to the same keys without a word.
##
## Sign convention, the same as Unit.set_drive_input(): throttle +1 is forward, steer +1 is left.
##
## Ordering: the command has to reach the Unit before the Unit moves in the same physics tick,
## or the Unit reacts one tick late. Tree order cannot promise that, because a parent is
## processed before its children and this node may sit anywhere relative to the Unit. So _ready()
## sets process_physics_priority one below the Unit's own (lower runs first). Input is read in
## _physics_process, never _process, as physics interpolation requires.

## Added to the Unit's process_physics_priority so this node runs just before it.
const PRIORITY_OFFSET: int = -1

const _SUFFIX_THROTTLE: String = "throttle"
const _SUFFIX_REVERSE: String = "reverse"
const _SUFFIX_STEER_LEFT: String = "steer_left"
const _SUFFIX_STEER_RIGHT: String = "steer_right"

## The Unit this node drives. Assign it before this node enters the tree.
@export var unit: Unit

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

var _throttle_action: StringName
var _reverse_action: StringName
var _steer_left_action: StringName
var _steer_right_action: StringName


func _ready() -> void:
	if unit == null:
		push_error("PlayerDriveInput '%s': unit is not assigned, so nothing is driven." % name)
		set_physics_process(false)
		return
	if action_prefix.is_empty():
		push_error("PlayerDriveInput '%s': action_prefix is empty, so nothing is driven. Set the Player's prefix (p1_, p2_) in the scene." % name)
		set_physics_process(false)
		return
	_throttle_action = _action_name(_SUFFIX_THROTTLE)
	_reverse_action = _action_name(_SUFFIX_REVERSE)
	_steer_left_action = _action_name(_SUFFIX_STEER_LEFT)
	_steer_right_action = _action_name(_SUFFIX_STEER_RIGHT)
	var actions: Array[StringName] = [_throttle_action, _reverse_action, _steer_left_action, _steer_right_action]
	for action: StringName in actions:
		if not InputMap.has_action(action):
			push_error("PlayerDriveInput '%s': Input Map action '%s' does not exist." % [name, action])
			set_physics_process(false)
			return
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(unit):
		return
	unit.set_drive_input(
		Input.get_axis(_reverse_action, _throttle_action),
		Input.get_axis(_steer_right_action, _steer_left_action))


func _action_name(suffix: String) -> StringName:
	return StringName(String(action_prefix) + suffix)
