class_name MapChoiceHint
extends Label
## The line under the Round-over screen that names the key back to the map choice (Story 038):
## shown when a Round ends, hidden when one starts. The text is data of the scene.
##
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-10.

## The MatchController whose round_over shows the line and round_started hides it.
@export var match_controller: MatchController


func _ready() -> void:
	visible = false
	if match_controller == null:
		push_error("MapChoiceHint '%s': match_controller is not assigned, so the line never shows." % name)
		return
	match_controller.round_over.connect(func(_winner: int) -> void: visible = true)
	match_controller.round_started.connect(func() -> void: visible = false)
