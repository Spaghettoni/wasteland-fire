class_name PlayerMatchInput
extends Node
## Turns one Player's Round keys into calls on that Player's Unit: Self-destruct, and the
## debug-damage key while MatchRules.debug_damage is above zero.
##
## Implements: production/epics/wasteland-fire/story-003-bases-destruction-respawn.md AC-5
## (Self-destruct: one key per Player destroys that Player's own Unit immediately, and the Unit then
## goes through the normal respawn path) and AC-8 (until weapons arrived in Story 005, a debug key
## applied damage to the local Unit, gated so it can be switched off); design/game-brief.md MVP
## feature 3 (a Self-destruct action so a stranded Unit can respawn). Vocabulary: CONTEXT.md
## (Player, Unit).
##
## The two Input Map actions are the prefix plus self_destruct and debug_damage, declared in
## project.godot. Gameplay code names actions, never keys. Like PlayerDriveInput, the prefix is
## data, stored in the scene that owns the Player (split_screen.tscn: p1_ and p2_), and it has no
## default: a node without a prefix pushes an error and reads nothing, so a forgotten one cannot
## bind two Players to the same keys without a word.
##
## It acts on the Unit and on nobody else: unit.destroy() and unit.apply_damage(). It does not
## know the MatchController. The Unit emits destroyed and the controller reacts (signals up, calls
## down), so Self-destruct and a lost fight take the same path to the same respawn (AC-5) and this
## node adds no second way to start one. A key pressed while the Unit is already destroyed does
## nothing, because destroy() and apply_damage() ignore a Unit that is not alive: mashing the key
## cannot queue a second respawn.
##
## Both keys are edge-triggered: one press acts once and a held key does not repeat. The edge is
## read in _physics_process, never _process, like the drive input. An action reads as just pressed
## on one physics tick per press, for events injected between ticks, so a key held down for longer
## than a whole wait still acts once.
##
## The debug key is gated by data, and Self-destruct does not depend on it. While
## rules.debug_damage is zero the debug key does nothing, its action is not read, and _ready() does
## not require the action to exist, so Story 005 switches it off by setting the value to zero and
## may then delete the action from project.godot. While the value is above zero the action is
## expected: a missing one is an error at _ready(), and it costs only the debug key, because
## Self-destruct is read whenever its own action exists. The only things that make this node read
## nothing at all are wiring faults, each an error at _ready(): no Unit, no rules, no prefix or no
## self_destruct action.
##
## Ordering: _ready() sets process_physics_priority one below the Unit's own (lower runs first),
## as PlayerDriveInput does, so a Self-destruct lands before the Unit's own tick of the same
## physics tick and not one tick after it.

## Added to the Unit's process_physics_priority so this node runs just before it.
const PRIORITY_OFFSET: int = -1

const _SUFFIX_SELF_DESTRUCT: String = "self_destruct"
const _SUFFIX_DEBUG_DAMAGE: String = "debug_damage"

## The Unit this node acts on. Assign it before this node enters the tree.
@export var unit: Unit

## The tuning values: rules.debug_damage is the hit points one debug-damage press takes off the
## Unit, and zero switches the debug key off. Required. The resource is shared, so never write to
## it at runtime.
@export var rules: MatchRules

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

var _self_destruct_action: StringName
var _debug_damage_action: StringName
## True while the debug-damage key is read: rules.debug_damage is above zero and its action exists.
## Decided once, in _ready().
var _debug_enabled: bool = false


func _ready() -> void:
	if unit == null:
		push_error("PlayerMatchInput '%s': unit is not assigned, so nothing is read." % name)
		set_physics_process(false)
		return
	if rules == null:
		push_error("PlayerMatchInput '%s': rules is not assigned, so nothing is read." % name)
		set_physics_process(false)
		return
	if action_prefix.is_empty():
		push_error("PlayerMatchInput '%s': action_prefix is empty, so nothing is read. Set the Player's prefix (p1_, p2_) in the scene." % name)
		set_physics_process(false)
		return
	_self_destruct_action = _action_name(_SUFFIX_SELF_DESTRUCT)
	_debug_damage_action = _action_name(_SUFFIX_DEBUG_DAMAGE)
	if not InputMap.has_action(_self_destruct_action):
		push_error("PlayerMatchInput '%s': Input Map action '%s' does not exist." % [name, _self_destruct_action])
		set_physics_process(false)
		return
	_debug_enabled = rules.debug_damage > 0.0 and InputMap.has_action(_debug_damage_action)
	if rules.debug_damage > 0.0 and not _debug_enabled:
		push_error("PlayerMatchInput '%s': Input Map action '%s' does not exist, but rules.debug_damage is above zero, so the debug-damage key does nothing. Self-destruct still works." % [name, _debug_damage_action])
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(unit):
		return
	if Input.is_action_just_pressed(_self_destruct_action):
		unit.destroy()
	if _debug_enabled and Input.is_action_just_pressed(_debug_damage_action):
		unit.apply_damage(rules.debug_damage)


func _action_name(suffix: String) -> StringName:
	return StringName(String(action_prefix) + suffix)
