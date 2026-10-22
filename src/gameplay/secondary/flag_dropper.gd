class_name FlagDropper
extends Node
## The Motorbike's secondary weapon (Story 044; Martin, 2026-10-22: "pri moto drop flag ked je to
## aktualne"): while the Player's Unit carries a Flag, the secondary key drops it where the Unit's
## tail is. The Flag rules decide everything else: MatchController.request_flag_drop() applies it
## in its next tick, the Flag lies DROPPED like one whose Carrier was destroyed, and the Unit that
## dropped it does not pick it up again until it has been 5 m away from it (MatchRules
## flag_release_metres, FlagRules).
##
## Implements: production/epics/wasteland-fire/story-044-secondaries-recharge.md AC-4.
##
## The secondary key is the action <prefix>lay_mine (see NitroBooster), read on its press. Only a
## Unit carrying a Flag has it; for every other the key does what its type does (the Mines, the
## nitro, the smoke) and this node nothing.

const _SUFFIX: String = "lay_mine"

## The Round's rules, which own the Flags. Required.
@export var match_controller: MatchController
## The Player whose key this is (0 for Player 1). Required.
@export_range(0, 1, 1) var player_index: int = 0
## The Player's action prefix (p1_, p2_). Required.
@export var action_prefix: StringName = &""

var _action: StringName


func _ready() -> void:
	if match_controller == null or action_prefix.is_empty():
		push_error("FlagDropper '%s': match_controller and action_prefix must be set, so no Flag can be dropped." % name)
		set_physics_process(false)
		return
	_action = StringName(String(action_prefix) + _SUFFIX)
	if not InputMap.has_action(_action):
		push_error("FlagDropper '%s': Input Map action '%s' does not exist." % [name, _action])
		set_physics_process(false)


## True while the Player's Unit carries a Flag it could drop now.
func can_drop() -> bool:
	return match_controller.is_carrying(player_index)


func _physics_process(_delta: float) -> void:
	if can_drop() and Input.is_action_just_pressed(_action):
		match_controller.request_flag_drop(player_index)
