class_name RoundRestartInput
extends Node
## Turns the Round-restart key into a call on the MatchController: while the Round is over, one
## press of the round_restart action restarts it; while the Round runs, the key does nothing.
##
## Implements: production/epics/wasteland-fire/story-004-water-canister-and-win.md AC-6 (the
## Round-over screen offers restart on a key; restart resets both Units, both Flags, hit points
## and the HUD and starts a new Round); design/game-brief.md MVP feature 4. Vocabulary: CONTEXT.md
## (Round, Player).
##
## One action for both Players, round_restart in project.godot, with no Player prefix: the Round is
## over for both and either may start the next. Gameplay code names the action, never the key; the
## Round-over screen reads the bound key's name from the Input Map to show it, and tools are the
## only place key codes appear.
##
## It acts on the MatchController and on nothing else: match_controller.restart(), which seats the
## Flags, benches the Units with their Players choosing, unpauses the tree and emits
## round_started. It owns no state, so a
## press is read fresh every tick: is_round_over() is asked first, and the action only while the
## Round is over, so a press during play reaches nothing (restart() itself would refuse it with a
## warning; it is never asked).
##
## It runs while the tree is paused. The end of a Round (a delivery, a loss or a double loss)
## freezes the game with get_tree().paused = true, and
## this node is the one that must still hear the key, so the owning scene stores process_mode
## ALWAYS on it (split_screen.tscn); Input.is_action_just_pressed() works while paused, and the
## edge is read in _physics_process, as every input node of this project does: one press acts
## once, on the tick after the event, and a held key does not repeat (the Story 004 evidence doc
## keeps the measurement).

## The Input Map action that restarts a Round that is over (project.godot: round_restart).
const ACTION_RESTART: StringName = &"round_restart"

## The node that owns the Round: asked is_round_over() every tick and told restart() on the key.
## Required: without it this node pushes an error and reads nothing.
@export var match_controller: MatchController


func _ready() -> void:
	if match_controller == null:
		push_error("RoundRestartInput '%s': match_controller is not assigned, so the restart key reads nothing." % name)
		set_physics_process(false)
		return
	if not InputMap.has_action(ACTION_RESTART):
		push_error("RoundRestartInput '%s': Input Map action '%s' does not exist, so the restart key reads nothing." % [name, ACTION_RESTART])
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(match_controller):
		return
	if match_controller.is_round_over() and Input.is_action_just_pressed(ACTION_RESTART):
		match_controller.restart()
