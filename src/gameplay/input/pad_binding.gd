class_name PadBinding
extends Resource
## One input of a pad bound to one action: a button, or one direction of an axis (a stick pushed
## left, a trigger pulled), and the name the hints show for it ("A", "View", "Left stick left").
##
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-3 (the pad layout
## is data: which button or axis each action takes) and AC-7 (no button index or axis in code).
## Vocabulary: CONTEXT.md (Input source).
##
## A PadLayout holds a list of these. The action is named by its suffix after a Player's prefix
## (throttle becomes p1_throttle for Player 1), or, with shared on, by the whole name of an action
## every Player shares (round_restart). make_event() builds the InputEvent for one pad: its device
## is the pad's, so the Input Map matches it for that pad alone and never for the other Player's.

## How the input is read: a button pressed or released, or an axis moved in one direction.
enum Kind { BUTTON, AXIS }

## The action's suffix after the Player's prefix (throttle, fire, self_destruct), or, with shared
## on, the whole name of the action (round_restart). Required.
@export var action_suffix: StringName = &""

## On: action_suffix is the whole name of an action every Player shares, with no prefix in front.
@export var shared: bool = false

## Whether this is a button or an axis direction.
@export var kind: Kind = Kind.BUTTON

## The button, when kind is BUTTON (JOY_BUTTON_A, JOY_BUTTON_BACK...). Required for a button.
@export var button: JoyButton = JOY_BUTTON_INVALID

## The axis, when kind is AXIS (JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_RIGHT...). Required for an axis.
@export var axis: JoyAxis = JOY_AXIS_INVALID

## The axis direction that presses the action, when kind is AXIS: 1 for right, down or a trigger
## pulled, -1 for left or up. Required for an axis (0 is not a direction).
@export_range(-1, 1, 1) var axis_direction: int = 0

## The name the hints show for this input ("A", "View", "Left stick left"). Looked up with tr() by
## the hints. Required, with no default: the text is data and never a literal in code.
@export var display_name: String = ""


## The whole action name for a Player with this prefix: the prefix and the suffix, or the suffix
## alone for a shared action.
func action_for(prefix: StringName) -> StringName:
	if shared:
		return action_suffix
	return StringName(String(prefix) + String(action_suffix))


## A new InputEvent of this input on the given pad's device, for InputMap.action_add_event().
func make_event(device: int) -> InputEvent:
	if kind == Kind.BUTTON:
		var button_event := InputEventJoypadButton.new()
		button_event.device = device
		button_event.button_index = button
		return button_event
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = axis
	motion.axis_value = float(axis_direction)
	return motion


## True when the other binding reads the same physical input (the same button, or the same axis in
## the same direction), whatever action it is bound to.
func same_input(other: PadBinding) -> bool:
	if other.kind != kind:
		return false
	if kind == Kind.BUTTON:
		return other.button == button
	return other.axis == axis and other.axis_direction == axis_direction


## What is wrong with this binding, as a sentence, or an empty string when nothing is.
func first_problem() -> String:
	if action_suffix.is_empty():
		return "a binding has no action_suffix"
	if display_name.is_empty():
		return "the binding of '%s' has no display_name" % action_suffix
	if kind == Kind.BUTTON and button == JOY_BUTTON_INVALID:
		return "the button binding of '%s' names no button" % action_suffix
	if kind == Kind.AXIS:
		if axis == JOY_AXIS_INVALID:
			return "the axis binding of '%s' names no axis" % action_suffix
		if axis_direction == 0:
			return "the axis binding of '%s' has no direction (1 or -1)" % action_suffix
	return ""
