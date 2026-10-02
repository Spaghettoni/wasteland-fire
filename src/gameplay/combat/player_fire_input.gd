class_name PlayerFireInput
extends Node
## Turns one Player's fire key into the trigger of that Player's Weapon.
##
## Implements: production/epics/wasteland-fire/story-005-three-units-and-triangle.md AC-3 (every
## Unit has one weapon, fired with one key per Player: the Input Map actions p1_fire and p2_fire)
## and AC-7 (the Carrier's key works like anyone's); design/game-brief.md MVP feature 5;
## design/rules.md "Units". Vocabulary: CONTEXT.md (Player, Unit).
##
## The one Input Map action is the prefix plus fire, declared in project.godot. Gameplay code
## names actions, never keys. Like PlayerDriveInput, the prefix is data, stored in the scene that
## owns the Player (split_screen.tscn: p1_ and p2_), and it has no default: a node without a prefix
## pushes an error and fires nothing, so a forgotten one cannot bind two Players to the same key
## without a word. The action name is cached once, in _ready().
##
## Level-triggered, not edge-triggered: every physics tick the weapon's trigger is set to whether
## the key is down (Input.is_action_pressed), and the Weapon's own cadence decides when a held key
## fires; a key mashed faster than the fire interval gains nothing. One guard sits on top: the
## trigger is armed only once the key has been seen up since the Unit came alive, because the fire
## key is also the key that confirms the Unit choice (PlayerChoiceInput), and a confirm must never
## be a shot from the spawn pose (a Truck's shot would reach the other Base's spawn point). A key
## held through a respawn therefore fires from the first tick after its release, not from the
## Unit's first live tick. The key is read in _physics_process, never _process, like the drive
## input.
##
## Ordering: _ready() sets process_physics_priority one below the Weapon's own (lower runs first),
## so a press lands in the weapon in the tick it is read, not one tick after. The Weapon must come
## before this node among its siblings, so that its _ready() has set its own priority
## (split_screen.tscn keeps the Weapons ahead of the fire inputs).

## Added to the Weapon's process_physics_priority so this node runs just before it.
const PRIORITY_OFFSET: int = -1

const _SUFFIX_FIRE: String = "fire"

## The Weapon this node holds the trigger of. Assign it before this node enters the tree.
@export var weapon: Weapon

## Prefix shared by this Player's Input Map actions, for example p1_. Required, with no default:
## the owning scene stores it. Read once, in _ready().
@export var action_prefix: StringName = &""

var _fire_action: StringName
## True once the fire key was seen up while the Unit is alive; cleared while the Unit is out of
## play, so the key that confirmed the choice never fires the shot of the spawn tick.
var _armed: bool = false


func _ready() -> void:
	if weapon == null:
		push_error("PlayerFireInput '%s': weapon is not assigned, so nothing is fired." % name)
		set_physics_process(false)
		return
	if action_prefix.is_empty():
		push_error("PlayerFireInput '%s': action_prefix is empty, so nothing is fired. Set the Player's prefix (p1_, p2_) in the scene." % name)
		set_physics_process(false)
		return
	_fire_action = StringName(String(action_prefix) + _SUFFIX_FIRE)
	if not InputMap.has_action(_fire_action):
		push_error("PlayerFireInput '%s': Input Map action '%s' does not exist." % [name, _fire_action])
		set_physics_process(false)
		return
	process_physics_priority = weapon.process_physics_priority + PRIORITY_OFFSET


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(weapon):
		return
	var pressed: bool = Input.is_action_pressed(_fire_action)
	if not is_instance_valid(weapon.unit) or not weapon.unit.is_alive:
		_armed = false
	elif not pressed:
		_armed = true
	weapon.set_trigger(pressed and _armed)
