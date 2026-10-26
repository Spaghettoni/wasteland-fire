class_name ControlsSettings
extends Resource
## What the Controls screen lets the Players change, where the change is kept, and the names it
## shows (Story 060; Martin, 2026-10-26: "moznost nastavit ovladanie. aj pre keyboard aj ovladace. a
## aby tam bolo aj default co ich revertne. na zaciatku v menu, kde si volime timy"). One file,
## data/controls_settings.tres; ControlBindings reads it.
##
## Implements: production/epics/wasteland-fire/story-060-controls-settings.md AC-1 (the actions),
## AC-4 (what cannot be bound) and AC-5 (the file). Vocabulary: CONTEXT.md (Input source).
##
## The actions are named by their suffix after a Player's prefix (throttle becomes p1_throttle), as
## PadLayout's bindings are. The Round's own keys and buttons (restart, back, the menus) are not
## among them, so no setting can leave a Player without a way out of a screen.

## The action suffixes the screen lists, in its order. Required.
@export var actions: PackedStringArray = PackedStringArray()

## The name the screen shows for each action, in the order of actions (through tr()). Required, one
## per action.
@export var action_names: PackedStringArray = PackedStringArray()

## Where the Players' changes are kept between launches (a ConfigFile). Required.
@export var save_path: String = ""

## How many pad inputs one action may take (the stick and the D-pad both steer). At least 1.
@export_range(1, 4, 1) var pad_slots: int = 2

## Physical keys no action may take: they work the screens (Escape goes back).
@export var reserved_keys: PackedInt32Array = PackedInt32Array()

## Pad buttons no action may take: the Round's restart (Menu) and the guide button.
@export var reserved_buttons: PackedInt32Array = PackedInt32Array()

## The name of each pad button, by JoyButton index (0 is A). A button past the list is shown by its
## number through button_format.
@export var button_names: PackedStringArray = PackedStringArray()

## The name of a pad button the list does not name; one %d placeholder for its index.
@export var button_format: String = ""

## The name of each axis direction, at index axis * 2 for the negative direction (left, up) and
## axis * 2 + 1 for the positive one (right, down, a trigger pulled), JoyAxis order: left stick x and
## y, right stick x and y, left trigger, right trigger.
@export var axis_names: PackedStringArray = PackedStringArray()

## How far a stick or a trigger must move for the screen to take it as the new input.
@export_range(0.1, 0.95, 0.05) var capture_threshold: float = 0.6


## The name the screen shows for a pad binding's input.
func pad_input_name(kind: PadBinding.Kind, button: int, axis: int, direction: int) -> String:
	if kind == PadBinding.Kind.BUTTON:
		if button >= 0 and button < button_names.size():
			return button_names[button]
		return button_format % button
	var index: int = axis + axis + (1 if direction > 0 else 0)
	if index >= 0 and index < axis_names.size():
		return axis_names[index]
	return button_format % index


## What is wrong with the settings, as a sentence, or an empty string.
func first_problem() -> String:
	if actions.is_empty():
		return "actions is empty"
	if action_names.size() != actions.size():
		return "action_names has %d names for %d actions" % [action_names.size(), actions.size()]
	if save_path.is_empty():
		return "save_path is not set"
	if button_format.count("%d") != 1:
		return "button_format '%s' does not hold exactly one %%d" % button_format
	return ""
