class_name PlayerChoiceInput
extends Node
## Turns one Player's choice keys into a cursor over the Unit types and a call on the
## MatchController: while that Player is choosing, the steer keys move the cursor to the previous
## and the next type and the fire key confirms the type under it.
##
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-6 (at
## every spawn the Player chooses the Unit type in their own viewport with their own keys before
## the Unit appears, with every type available); design/game-brief.md MVP feature 5; design/rules.md
## "Tokens and the Garage". Vocabulary: CONTEXT.md (Player, Unit, Garage).
##
## The three Input Map actions are the prefix plus steer_left, steer_right and fire, declared in
## project.godot: the same keys that steer and shoot the Unit, which is out of play while its
## Player chooses, so nothing else reads them then (a starting binding of Story 005; the
## bindings are data). Gameplay code names actions, never keys. Like PlayerDriveInput, the prefix
## is data, stored in the scene that owns the Player (split_screen.tscn: p1_ and p2_), and it has
## no default: a node without a prefix, a controller or a Player index pushes an error and reads
## nothing, so a forgotten one cannot bind two Players to the same keys without a word. The action
## names are cached once, in _ready().
##
## It acts on the MatchController and on nothing else: match_controller.choose(player_index,
## cursor), which accepts or refuses (signals up, calls down). It asks is_choosing(player_index)
## first and reads the keys only while that holds, so the keys do nothing for a Player in play or
## with a standing choice, and unit_types() for the count the cursor wraps over. It owns one thing,
## the cursor: an index into unit_types(), 0 at the start (the first type of the data) and kept
## across a destruction, a spawn and a restart, so a Player who keeps choosing the same type
## confirms with one press; the choice panel (a UI node) reads it and listens to cursor_moved, and
## this node never reads the panel.
##
## Every key is edge-triggered: one press acts once and a held key does not repeat, read with
## Input.is_action_just_pressed in _physics_process, never _process, like the other input nodes,
## so the fire key a Player still holds from its previous Unit cannot confirm the next type at
## once; a press is read on one physics tick, and that is the tick on which choose() is called.
## A left and a right press on the same tick cancel out (two cursor_moved emits, the cursor back).
##
## Ordering: _ready() sets process_physics_priority one below the MatchController's own (lower
## runs first), so a confirm lands in the controller's tick of the same physics tick, and the Unit
## may appear on the tick of the press.

## The cursor moved to another type: the index into unit_types() it now points at. Emitted on
## every step, also when it wraps.
signal cursor_moved(type_index: int)

## Added to the MatchController's process_physics_priority so this node runs just before it.
const PRIORITY_OFFSET: int = -1

const _SUFFIX_STEER_LEFT: String = "steer_left"
const _SUFFIX_STEER_RIGHT: String = "steer_right"
const _SUFFIX_FIRE: String = "fire"

## The node that owns the Round: asked is_choosing() and unit_types() every tick and told
## choose() on the fire key. Required: without it this node pushes an error and reads nothing.
@export var match_controller: MatchController

## The Player this node chooses for: 0 is Player 1. Required, with no valid default: the owning
## scene stores it.
@export var player_index: int = -1

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

## The type the keys point at: an index into match_controller.unit_types(), 0 at the start, moved
## by the steer keys while the Player is choosing and kept otherwise. Read-only: assigning to it
## pushes an error and changes nothing; it moves only through the keys.
var cursor: int:
	get:
		return _cursor
	set(_value):
		push_error("PlayerChoiceInput '%s': cursor is read-only. It moves with the Player's steer keys." % name)

var _cursor: int = 0
var _steer_left_action: StringName
var _steer_right_action: StringName
var _fire_action: StringName


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PlayerChoiceInput '%s': %s, so no choice is read." % [name, problem])
		set_physics_process(false)
		return
	process_physics_priority = match_controller.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(match_controller) or not match_controller.is_choosing(player_index):
		return
	var count: int = match_controller.unit_types().size()
	if count <= 0:
		return
	if Input.is_action_just_pressed(_steer_left_action):
		_cursor = posmod(_cursor - 1, count)
		cursor_moved.emit(_cursor)
	if Input.is_action_just_pressed(_steer_right_action):
		_cursor = posmod(_cursor + 1, count)
		cursor_moved.emit(_cursor)
	if Input.is_action_just_pressed(_fire_action):
		match_controller.choose(player_index, _cursor)


## What is wrong with the exports and the Input Map, as a sentence, or an empty string when nothing
## is. Caches the three action names on the way.
func _first_problem() -> String:
	if match_controller == null:
		return "match_controller is not assigned"
	if player_index < 0:
		return "player_index is not set (store 0 for Player 1 or 1 for Player 2 in the scene)"
	if action_prefix.is_empty():
		return "action_prefix is empty (store the Player's prefix, p1_ or p2_, in the scene)"
	_steer_left_action = _action_name(_SUFFIX_STEER_LEFT)
	_steer_right_action = _action_name(_SUFFIX_STEER_RIGHT)
	_fire_action = _action_name(_SUFFIX_FIRE)
	for action: StringName in [_steer_left_action, _steer_right_action, _fire_action]:
		if not InputMap.has_action(action):
			return "Input Map action '%s' does not exist" % action
	return ""


func _action_name(suffix: String) -> StringName:
	return StringName(String(action_prefix) + suffix)
