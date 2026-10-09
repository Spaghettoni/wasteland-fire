class_name PlayerMineInput
extends Node
## Turns one Player's lay key into a request to that Player's MineLayer.
##
## Implements: production/epics/wasteland-fire/story-014-truck-mines.md AC-1 (one press of the lay
## key, E for Player 1 and Comma for Player 2, lays one Mine, and a key held down lays one Mine,
## not one per tick) and AC-8 (the lay keys are Input Map actions, p1_lay_mine and p2_lay_mine);
## design/rules.md "Turrets, Flag Walls and Mines". Vocabulary: CONTEXT.md (Player, Mine, Truck).
##
## The one Input Map action is the prefix plus lay_mine, declared in project.godot. Gameplay code
## names actions, never keys. Like PlayerFireInput, the prefix is data, stored in the scene that
## owns the Player (split_screen.tscn: p1_ and p2_), and it has no default: a node without a prefix
## pushes an error and reads nothing, so a forgotten one cannot bind two Players to the same key
## without a word. The action name is cached once, in _ready().
##
## Edge-triggered, as PlayerMatchInput's keys are: Input.is_action_just_pressed in
## _physics_process, never _process, so one press makes one request however long the key is held.
## There is no arming guard like the fire key's: the lay key confirms no choice, so a press can
## never be a stray lay. Whether the Unit is a Truck in play, whether it has a Mine left and
## whether the place allows one are the MineLayer's to say, not this node's.
##
## Ordering: _ready() sets process_physics_priority one below the MineLayer's own (lower runs
## first), so a press reaches the layer in the tick it is read. The MineLayer must come before this
## node among its siblings, so that its _ready() has set its own priority (split_screen.tscn keeps
## the MineLayers ahead of the lay inputs).

## Added to the MineLayer's process_physics_priority so this node runs just before it.
const PRIORITY_OFFSET: int = -1

const _SUFFIX_LAY_MINE: String = "lay_mine"

## The MineLayer this node requests Mines from. Assign it before this node enters the tree.
@export var mine_layer: MineLayer

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

var _action: StringName = &""


func _ready() -> void:
	if mine_layer == null:
		push_error("PlayerMineInput '%s': mine_layer is not assigned, so no Mine is laid." % name)
		set_physics_process(false)
		return
	if action_prefix.is_empty():
		push_error("PlayerMineInput '%s': action_prefix is empty, so no Mine is laid. Set the Player's prefix (p1_, p2_) in the scene." % name)
		set_physics_process(false)
		return
	_action = StringName(String(action_prefix) + _SUFFIX_LAY_MINE)
	if not InputMap.has_action(_action):
		push_error("PlayerMineInput '%s': Input Map action '%s' does not exist." % [name, _action])
		set_physics_process(false)
		return
	process_physics_priority = mine_layer.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if is_instance_valid(mine_layer) and Input.is_action_just_pressed(_action):
		mine_layer.request_lay()
