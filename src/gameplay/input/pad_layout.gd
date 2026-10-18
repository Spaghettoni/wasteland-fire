class_name PadLayout
extends Resource
## The pad layout every Player's pad gets: which button or axis each action takes, the dead zone of
## the sticks and triggers, and the names the hints show. One file, pad_layout.tres.
##
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-3 (the starting
## layout: right trigger throttle, left trigger reverse, left stick and D-pad steer, A fire, X lay a
## Mine, Y camera, View Self-destruct, Menu restart; analog with a dead zone) and AC-7 (every value
## is data; a layout with a missing or doubled action is refused with one error). Vocabulary:
## CONTEXT.md (Input source).
##
## first_problem(prefix) checks the layout against the Input Map as it stands: every action under
## the prefix must take at least one input, except the suffixes in unbound_suffixes (the debug-damage
## key gets no button), and no input may be bound to two different actions (one button that both
## fires and lays a Mine). Two inputs on one action are fine (the stick and the D-pad both steer).

## The bindings, in the order the hints read them: the first binding of an action names it.
@export var bindings: Array[PadBinding] = []

## The dead zone of every action a pad is bound to, while a pad is: the share of a stick's or a
## trigger's travel that does nothing, so a resting stick does not creep. A key's strength is 1
## whatever the dead zone, so the keyboard is untouched. Required, above zero and below one.
@export_range(0.0, 1.0, 0.01) var deadzone: float = 0.0

## Suffixes of actions under a Player's prefix that the pad deliberately leaves alone
## (debug_damage). Every other action under the prefix must take an input.
@export var unbound_suffixes: PackedStringArray = PackedStringArray()


## The display name of the first binding of the action suffix, or an empty string when none binds
## it.
func name_for(action_suffix: StringName) -> String:
	for binding: PadBinding in bindings:
		if binding != null and binding.action_suffix == action_suffix:
			return binding.display_name
	return ""


## What is wrong with the layout for a Player with this prefix, as a sentence, or an empty string
## when nothing is: a broken binding, an input bound to two actions, an action the binding names
## that the Input Map lacks, or an action under the prefix that no binding covers.
func first_problem(prefix: StringName) -> String:
	if deadzone <= 0.0 or deadzone >= 1.0:
		return "deadzone %s is not between 0 and 1" % deadzone
	if bindings.is_empty():
		return "the layout has no bindings"
	for index: int in bindings.size():
		var binding: PadBinding = bindings[index]
		if binding == null:
			return "binding %d is empty" % index
		var problem: String = binding.first_problem()
		if not problem.is_empty():
			return problem
		if not InputMap.has_action(binding.action_for(prefix)):
			return "the binding of '%s' names the action '%s', which the Input Map lacks" % [binding.action_suffix, binding.action_for(prefix)]
		for other_index: int in range(index + 1, bindings.size()):
			var other: PadBinding = bindings[other_index]
			if other != null and other.same_input(binding) and other.action_suffix != binding.action_suffix:
				return "'%s' is bound to both '%s' and '%s'" % [binding.display_name, binding.action_suffix, other.action_suffix]
	return _first_uncovered(prefix)


## The first action under the prefix that no binding covers and unbound_suffixes does not name, as
## a sentence, or an empty string.
func _first_uncovered(prefix: StringName) -> String:
	for action: StringName in InputMap.get_actions():
		var action_name: String = String(action)
		if not action_name.begins_with(String(prefix)):
			continue
		var suffix: String = action_name.substr(String(prefix).length())
		if unbound_suffixes.has(suffix):
			continue
		if name_for(StringName(suffix)).is_empty():
			return "no binding covers the action '%s' (bind it, or name '%s' in unbound_suffixes)" % [action_name, suffix]
	return ""
