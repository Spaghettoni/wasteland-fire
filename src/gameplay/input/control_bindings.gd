class_name ControlBindings
extends RefCounted
## The Players' controls as they set them on the Controls screen (Story 060; Martin, 2026-10-26:
## "moznost nastavit ovladanie. aj pre keyboard aj ovladace. a aby tam bolo aj default co ich
## revertne"): one key per action for each of the two keyboard halves, and up to pad_slots pad
## inputs per action in the one layout every pad gets. Kept in a ConfigFile between launches.
##
## Implements: production/epics/wasteland-fire/story-060-controls-settings.md AC-2 (a key or a pad
## input taken for an action; one already in use moves to the action this one came from), AC-3
## (Default), AC-4 (reserved inputs refused) and AC-5 (kept between launches; a broken file is
## ignored for the defaults). Vocabulary: CONTEXT.md (Input source).
##
## Where it goes. The Pick a side screen loads it and hands it to the Lineup (Lineup.controls); the
## launch scene plays it: SplitScreen._apply_inputs() gives each keyboard half's Player the keys of
## keyboard_keys(), and PadAssignment takes pad_layout() as its layout. So no node reads the file or
## the Input Map of project.godot for a Player's keys but this. Without it (an evidence run, or
## Lineup.controls null) everything plays project.godot's keys and pad_layout.tres as before.
##
## The two keyboard halves are KEY_PREFIXES: p1_ is Keyboard 1 (W A S D...), p2_ Keyboard 2 (the
## arrows...). A key belongs to one action of one half at most, across both halves, so two Players at
## one keyboard never share a key; a pad input belongs to one action at most.

## The prefixes of the two keyboard halves, Keyboard 1 and Keyboard 2 (Lineup.KEYBOARD_1 and _2).
const KEY_PREFIXES: Array[String] = ["p1_", "p2_"]

## The file sections.
const _KEYBOARD: String = "keyboard"
const _PAD: String = "pad"
## The file's format: it holds only what differs from the defaults (Story 060, 2026-10-26). A file
## without it, written before, held every control and is ignored for the defaults.
const _META: String = "meta"
const _FORMAT_KEY: String = "format"
const _FORMAT: String = "changes"

## What may be set and how it is named. Read-only here.
var settings: ControlsSettings
## The file read and written: settings.save_path unless set otherwise (an evidence run's own).
var path: String = ""

## The shipped pad layout: the defaults of the pad, and the bindings of actions the screen does not
## list (the Round's restart).
var _default_layout: PadLayout
## The keys project.godot gives, by prefix, then by suffix: an InputEventKey or null.
var _default_keys: Dictionary = {}
## The keys now, as _default_keys.
var _keys: Dictionary = {}
## The pad inputs now, by suffix: an Array of PadBinding, at most settings.pad_slots.
var _pad: Dictionary = {}


## Controls at their defaults: ControlsSettings.default_keys, project.godot's keys for the actions it
## does not name; ControlsSettings.default_pad, the layout's pad inputs for the actions it does not
## name. Returns null, with
## one error, when the settings or the layout are missing or refused.
static func create(controls_settings: ControlsSettings, layout: PadLayout) -> ControlBindings:
	if controls_settings == null or layout == null:
		push_error("ControlBindings: settings or the pad layout is not assigned, so the controls cannot be set.")
		return null
	var problem: String = controls_settings.first_problem()
	if not problem.is_empty():
		push_error("ControlBindings: the settings are refused (%s), so the controls cannot be set." % problem)
		return null
	var bindings := ControlBindings.new()
	bindings.settings = controls_settings
	bindings.path = controls_settings.save_path
	bindings._default_layout = layout
	for prefix: String in KEY_PREFIXES:
		var project: Dictionary = SplitScreen._project_keys(prefix)
		var keys: Dictionary = {}
		for suffix: String in controls_settings.actions:
			var events: Array = project.get(suffix, [])
			keys[suffix] = events[0] if not events.is_empty() else null
			var shipped: Variant = controls_settings.default_keys.get(prefix + suffix, null)
			if shipped is Vector2i:
				var event := InputEventKey.new()
				event.physical_keycode = (shipped as Vector2i).x as Key
				event.location = (shipped as Vector2i).y as KeyLocation
				keys[suffix] = event
		bindings._default_keys[prefix] = keys
	bindings.reset()
	return bindings


## Every action back to its default key and pad inputs (the screen's Default). Saves nothing.
func reset() -> void:
	_keys = {}
	for prefix: String in KEY_PREFIXES:
		_keys[prefix] = (_default_keys[prefix] as Dictionary).duplicate()
	_pad = {}
	for suffix: String in settings.actions:
		_pad[suffix] = _default_pad(suffix)


## The default pad inputs of the action, at most pad_slots: ControlsSettings.default_pad's when it
## names the action, else the shipped layout's.
func _default_pad(suffix: String) -> Array:
	var slots: Array = []
	for binding: PadBinding in settings.default_pad:
		if binding != null and String(binding.action_suffix) == suffix and slots.size() < settings.pad_slots:
			slots.append(binding)
	if not slots.is_empty():
		return slots
	for binding: PadBinding in _default_layout.bindings:
		if binding != null and not binding.shared and String(binding.action_suffix) == suffix and slots.size() < settings.pad_slots:
			slots.append(binding)
	return slots


## The key of the action for a keyboard half, or null.
func key_of(prefix: String, suffix: String) -> InputEventKey:
	return (_keys.get(prefix, {}) as Dictionary).get(suffix, null)


## The pad inputs of the action, in slot order.
func pad_of(suffix: String) -> Array:
	return (_pad.get(suffix, []) as Array).duplicate()


## True when every key and pad input is the default one.
func is_default() -> bool:
	for prefix: String in KEY_PREFIXES:
		for suffix: String in settings.actions:
			if not _same_key(key_of(prefix, suffix), (_default_keys[prefix] as Dictionary)[suffix]):
				return false
	for suffix: String in settings.actions:
		if not _same_pad(_pad[suffix], _default_pad(suffix)):
			return false
	return true


static func _same_pad(now: Array, then: Array) -> bool:
	if now.size() != then.size():
		return false
	for index: int in now.size():
		if not (now[index] as PadBinding).same_input(then[index]):
			return false
	return true


## Gives the action of a keyboard half this key. A key another action holds (of either half) moves
## to the key this action had, so nothing is left without a key and no key does two things. Returns
## {"ok": bool, "reason": a sentence when refused, "moved": [prefix, suffix] of the action that took
## the old key, or []}.
func set_key(prefix: String, suffix: String, physical: Key, location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> Dictionary:
	if not _keys.has(prefix) or not settings.actions.has(suffix):
		return {"ok": false, "reason": "no such action", "moved": []}
	if settings.reserved_keys.has(int(physical)):
		return {"ok": false, "reason": "reserved", "moved": []}
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.location = location
	var old: InputEventKey = key_of(prefix, suffix)
	var moved: Array = []
	for other_prefix: String in KEY_PREFIXES:
		for other_suffix: String in settings.actions:
			if other_prefix == prefix and other_suffix == suffix:
				continue
			if _same_key(key_of(other_prefix, other_suffix), event):
				(_keys[other_prefix] as Dictionary)[other_suffix] = old
				moved = [other_prefix, other_suffix]
	(_keys[prefix] as Dictionary)[suffix] = event
	return {"ok": true, "reason": "", "moved": moved}


## Gives the action this pad input in the slot (0 first; a slot past the action's inputs adds one).
## An input another action holds moves to the input this slot had; when the slot had none and the
## other action would be left with none, it is refused. Returns as set_key(), "moved" holding
## [suffix] of the other action.
func set_pad(suffix: String, slot: int, kind: PadBinding.Kind, button: int, axis: int, direction: int) -> Dictionary:
	if not _pad.has(suffix) or slot < 0 or slot >= settings.pad_slots:
		return {"ok": false, "reason": "no such action", "moved": []}
	if kind == PadBinding.Kind.BUTTON and settings.reserved_buttons.has(button):
		return {"ok": false, "reason": "reserved", "moved": []}
	if kind == PadBinding.Kind.AXIS and direction == 0:
		return {"ok": false, "reason": "no direction", "moved": []}
	var binding := _binding(suffix, kind, button, axis, direction)
	for shared: PadBinding in _default_layout.bindings:
		if shared != null and not settings.actions.has(String(shared.action_suffix)) and shared.same_input(binding):
			return {"ok": false, "reason": "reserved", "moved": []}
	var slots: Array = _pad[suffix]
	slot = mini(slot, slots.size())
	var old: PadBinding = slots[slot] if slot < slots.size() else null
	var moved: Array = []
	for other_suffix: String in settings.actions:
		var others: Array = _pad[other_suffix]
		for index: int in others.size():
			if other_suffix == suffix and index == slot:
				continue
			if not (others[index] as PadBinding).same_input(binding):
				continue
			if other_suffix == suffix:
				others.remove_at(index)
				if index < slot:
					slot -= 1
				break
			if old == null:
				if others.size() == 1:
					return {"ok": false, "reason": "last input", "moved": [other_suffix]}
				others.remove_at(index)
			else:
				others[index] = _binding(other_suffix, old.kind, old.button, old.axis, old.axis_direction)
			moved = [other_suffix]
			break
	if slot < slots.size():
		slots[slot] = binding
	else:
		slots.append(binding)
	return {"ok": true, "reason": "", "moved": moved}


## Takes the pad input out of the slot. Refused (false) when it is the action's only one.
func clear_pad(suffix: String, slot: int) -> bool:
	var slots: Array = _pad.get(suffix, [])
	if slots.size() <= 1 or slot < 0 or slot >= slots.size():
		return false
	slots.remove_at(slot)
	return true


## The key events of a keyboard half by action suffix, as SplitScreen._project_keys() gives them:
## project.godot's, with each listed action's key replaced by the one set here.
func keyboard_keys(prefix: String) -> Dictionary:
	var keys: Dictionary = SplitScreen._project_keys(prefix)
	for suffix: String in settings.actions:
		var event: InputEventKey = key_of(prefix, suffix)
		keys[suffix] = [event] if event != null else []
	return keys


## The pad layout every pad gets: the shipped one with each listed action's inputs as set here, the
## other bindings (the Round's restart) as shipped.
func pad_layout() -> PadLayout:
	var layout: PadLayout = _default_layout.duplicate(false) as PadLayout
	var bindings: Array[PadBinding] = []
	var done: Array[String] = []
	for binding: PadBinding in _default_layout.bindings:
		var suffix: String = String(binding.action_suffix)
		if binding.shared or not settings.actions.has(suffix):
			bindings.append(binding)
		elif not done.has(suffix):
			done.append(suffix)
			for each: PadBinding in _pad[suffix]:
				bindings.append(each)
	for suffix: String in settings.actions:
		if not done.has(suffix):
			for each: PadBinding in _pad[suffix]:
				bindings.append(each)
	layout.bindings = bindings
	return layout


## The name of a key as the screen and the hints show it: the side first when it has one.
static func key_name(event: InputEventKey) -> String:
	if event == null:
		return ""
	var side: String = event.as_text_location()
	var key: String = event.as_text_physical_keycode()
	return key if side.is_empty() else "%s %s" % [side.capitalize(), key]


## Writes the controls that differ from the defaults to the file, so a later change of a default
## reaches every action nobody changed. Returns the ConfigFile's error.
func save() -> Error:
	var file := ConfigFile.new()
	file.set_value(_META, _FORMAT_KEY, _FORMAT)
	for prefix: String in KEY_PREFIXES:
		for suffix: String in settings.actions:
			var event: InputEventKey = key_of(prefix, suffix)
			if event != null and not _same_key(event, (_default_keys[prefix] as Dictionary)[suffix]):
				file.set_value(_KEYBOARD, prefix + suffix, {"key": int(event.physical_keycode), "side": int(event.location)})
	for suffix: String in settings.actions:
		if _same_pad(_pad[suffix], _default_pad(suffix)):
			continue
		var slots: Array = []
		for binding: PadBinding in _pad[suffix]:
			slots.append({"kind": int(binding.kind), "button": int(binding.button), "axis": int(binding.axis), "direction": binding.axis_direction})
		file.set_value(_PAD, suffix, slots)
	return file.save(path)


## Reads the controls from the file over the defaults. Returns false, keeping the defaults, when the
## file is missing or what it holds would leave a key on two actions or a pad layout PadLayout
## refuses; an entry it does not know is skipped.
func load_saved() -> bool:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return false
	reset()
	if file.get_value(_META, _FORMAT_KEY, "") != _FORMAT:
		return false
	for prefix: String in KEY_PREFIXES:
		for suffix: String in settings.actions:
			var entry: Variant = file.get_value(_KEYBOARD, prefix + suffix, null)
			if entry is Dictionary and (entry as Dictionary).has_all(["key", "side"]):
				var event := InputEventKey.new()
				event.physical_keycode = int(entry["key"]) as Key
				event.location = int(entry["side"]) as KeyLocation
				(_keys[prefix] as Dictionary)[suffix] = event
	for suffix: String in settings.actions:
		var entry: Variant = file.get_value(_PAD, suffix, null)
		if not (entry is Array) or (entry as Array).is_empty():
			continue
		var slots: Array = []
		for item: Variant in entry:
			if item is Dictionary and (item as Dictionary).has_all(["kind", "button", "axis", "direction"]) and slots.size() < settings.pad_slots:
				slots.append(_binding(suffix, int(item["kind"]) as PadBinding.Kind, int(item["button"]), int(item["axis"]), int(item["direction"])))
		if not slots.is_empty():
			_pad[suffix] = slots
	if not _first_problem().is_empty():
		push_warning("ControlBindings: the saved controls in %s are refused (%s), so the defaults play." % [path, _first_problem()])
		reset()
		return false
	return true


## What is wrong with the controls now, as a sentence, or an empty string: a key on two actions, or
## a pad layout PadLayout refuses for Player 1.
func _first_problem() -> String:
	var seen: Array[InputEventKey] = []
	for prefix: String in KEY_PREFIXES:
		for suffix: String in settings.actions:
			var event: InputEventKey = key_of(prefix, suffix)
			if event == null:
				continue
			for other: InputEventKey in seen:
				if _same_key(other, event):
					return "the key %s is on two actions" % key_name(event)
			seen.append(event)
	for suffix: String in settings.actions:
		for binding: PadBinding in _pad[suffix]:
			var problem: String = binding.first_problem()
			if not problem.is_empty():
				return problem
	return pad_layout().first_problem(KEY_PREFIXES[0])


func _binding(suffix: String, kind: PadBinding.Kind, button: int, axis: int, direction: int) -> PadBinding:
	var binding := PadBinding.new()
	binding.action_suffix = StringName(suffix)
	binding.kind = kind
	if kind == PadBinding.Kind.BUTTON:
		binding.button = button as JoyButton
	else:
		binding.axis = axis as JoyAxis
		binding.axis_direction = signi(direction)
	binding.display_name = settings.pad_input_name(kind, button, axis, signi(direction))
	return binding


static func _same_key(a: InputEventKey, b: InputEventKey) -> bool:
	if a == null or b == null:
		return a == b
	if a.physical_keycode != b.physical_keycode:
		return false
	var a_side: int = a.location
	var b_side: int = b.location
	return a_side == b_side or a_side == KEY_LOCATION_UNSPECIFIED or b_side == KEY_LOCATION_UNSPECIFIED
