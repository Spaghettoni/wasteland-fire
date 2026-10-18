class_name PadAssignment
extends Node
## Gives each Player a pad: the first connected pad belongs to Player 1, the second to Player 2,
## and every action under that Player's prefix takes the pad layout's inputs on that pad's device
## alone, beside the keyboard keys project.godot binds. A third pad belongs to nobody.
##
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-1 (pads in
## connection order, the keyboard still working), AC-2 (a pad acts for its own Player only), AC-3
## (the layout), AC-5 (pads that come and go mid-Round) and AC-7 (the layout is data, refused with
## one error when broken, the keyboard still working then); design/rules.md "Camera and controls".
## Vocabulary: CONTEXT.md (Player, Input source).
##
## Why the Input Map. Every gameplay input node reads actions under its Player's prefix and never a
## key (PlayerDriveInput, PlayerFireInput, PlayerMineInput, PlayerMatchInput, PlayerChoiceInput,
## PlayerCameraInput), and the drive already reads analog strengths. So a pad needs no new input
## code: this node adds the layout's InputEvents to those actions with the pad's device set, and the
## Input Map matches an event whose device is set for that device alone, which keeps two pads apart.
## Nothing else in the game knows a pad exists, except the hints, which ask button_name() what to
## show.
##
## The Input Map is the engine's, shared by everything, so this node owns exactly what it added and
## nothing else: the events it added (_added, per Player) and the dead zones it changed
## (_deadzone_before, per action, restored once no pad event is left on the action). The keyboard
## events of project.godot are never touched. When the node leaves the tree it takes all of it
## back, so a scene freed and instanced again (an evidence run) finds the Input Map as project.godot
## made it.
##
## States per Player, two: no pad -> pad (connect_pad: the first Player without one, in Player
## order), pad -> no pad (disconnect_pad: its events go at once and every action it held is
## released, unless a keyboard key of that action is still down, so a Unit does not keep its
## throttle from a pad that is gone). A device already assigned is not assigned twice. The engine's
## Input.joy_connection_changed drives both at runtime; the pads already connected when the node
## enters the tree are assigned in Input.get_connected_joypads() order. Evidence scenarios call
## connect_pad() and disconnect_pad() directly, as a headless run has no pads.

## A pad was given to a Player or taken from one; the hints read button_name() again.
signal pads_changed

## The pad of this Player connected (the Player's notice says so).
signal pad_connected(player_index: int)

## The pad of this Player disconnected (the Player's notice says so).
signal pad_disconnected(player_index: int)

## No pad: the value pad_of() returns for a Player without one.
const NO_PAD: int = -1

## The layout every Player's pad gets (pad_layout.tres). Required: without it, or with a layout
## first_problem() refuses, the node pushes one error and assigns no pad, and the keyboard works as
## before.
@export var layout: PadLayout

## The Players' action prefixes, in Player order: the scene stores [p1_, p2_]. Required.
@export var action_prefixes: Array[StringName] = []

## Each Player's pad device, NO_PAD for none, in Player order.
var _pads: Array[int] = []

## Each Player's added events, in Player order: Array of [action, event] pairs.
var _added: Array[Array] = []

## The dead zone each action had before a pad event was first added to it, by action.
var _deadzone_before: Dictionary[StringName, float] = {}

## False when the exports or the layout were refused at _ready(): nothing is assigned then.
var _usable: bool = false


func _ready() -> void:
	var problem: String = _first_problem()
	if not problem.is_empty():
		push_error("PadAssignment '%s': %s, so no pad is used and the keyboard works as before." % [name, problem])
		return
	_usable = true
	for index: int in action_prefixes.size():
		_pads.append(NO_PAD)
		_added.append([])
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device: int in Input.get_connected_joypads():
		connect_pad(device)


func _exit_tree() -> void:
	if not _usable:
		return
	for player_index: int in _pads.size():
		_take_back(player_index)
		_pads[player_index] = NO_PAD
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


## Gives the pad to the first Player without one and returns that Player's index, or returns -1
## when the pad is already assigned, every Player has one, or the node is not usable.
func connect_pad(device: int) -> int:
	if not _usable or _pads.has(device):
		return NO_PAD
	var player_index: int = _pads.find(NO_PAD)
	if player_index < 0:
		return NO_PAD
	_pads[player_index] = device
	for binding: PadBinding in layout.bindings:
		var action: StringName = binding.action_for(action_prefixes[player_index])
		if not _deadzone_before.has(action):
			_deadzone_before[action] = InputMap.action_get_deadzone(action)
		InputMap.action_set_deadzone(action, layout.deadzone)
		var event: InputEvent = binding.make_event(device)
		InputMap.action_add_event(action, event)
		_added[player_index].append([action, event])
	pad_connected.emit(player_index)
	pads_changed.emit()
	return player_index


## Takes the pad from its Player and returns that Player's index, or -1 when no Player has it.
func disconnect_pad(device: int) -> int:
	if not _usable:
		return NO_PAD
	var player_index: int = _pads.find(device)
	if player_index < 0:
		return NO_PAD
	_take_back(player_index)
	_pads[player_index] = NO_PAD
	pad_disconnected.emit(player_index)
	pads_changed.emit()
	return player_index


## The pad device of the Player, or NO_PAD.
func pad_of(player_index: int) -> int:
	if player_index < 0 or player_index >= _pads.size():
		return NO_PAD
	return _pads[player_index]


## True when any Player has a pad.
func any_pad() -> bool:
	return _pads.any(func(device: int) -> bool: return device != NO_PAD)


## The name of the pad input bound to the action suffix (or shared action name) for this Player,
## or an empty string when the Player has no pad or the layout binds nothing to it.
func button_name(player_index: int, action_suffix: StringName) -> String:
	if pad_of(player_index) == NO_PAD:
		return ""
	return layout.name_for(action_suffix)


## The name of the pad input bound to a shared action (round_restart), or an empty string when no
## Player has a pad.
func shared_button_name(action: StringName) -> String:
	if not any_pad():
		return ""
	return layout.name_for(action)


## Removes every event this node added for the Player, releases the actions they could hold, and
## restores an action's dead zone once no pad event is left on it.
##
## Measured on 4.7.2 (Story 032 evidence): InputMap.action_erase_event() releases the whole action,
## a keyboard key that holds it included, and the engine does not press it again while the key
## stays down. So every key that is down on an action this takes events from is pressed again once,
## through the Input like a real key, after the erase: a held throttle stays held, and the key's
## real release then releases the action. A key held at that very moment reads as freshly pressed.
func _take_back(player_index: int) -> void:
	var pairs: Array = _added[player_index].duplicate()
	_added[player_index].clear()
	var held_keys: Array[Key] = []
	for pair: Array in pairs:
		var action: StringName = pair[0]
		for key: Key in _held_keys(action):
			if not held_keys.has(key):
				held_keys.append(key)
		InputMap.action_erase_event(action, pair[1])
		if _deadzone_before.has(action) and not _has_pad_event(action):
			InputMap.action_set_deadzone(action, _deadzone_before[action])
			_deadzone_before.erase(action)
	for key: Key in held_keys:
		var press := InputEventKey.new()
		press.device = InputEvent.DEVICE_ID_KEYBOARD
		press.physical_keycode = key
		press.pressed = true
		Input.parse_input_event(press)


## The keyboard keys bound to the action that are down now.
func _held_keys(action: StringName) -> Array[Key]:
	var held: Array[Key] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and Input.is_physical_key_pressed(key_event.physical_keycode):
			held.append(key_event.physical_keycode)
	return held


## True when any Player's added events still include one on the action.
func _has_pad_event(action: StringName) -> bool:
	for pairs: Array in _added:
		for pair: Array in pairs:
			if pair[0] == action:
				return true
	return false


## What is wrong with the exports and the layout, as a sentence, or an empty string.
func _first_problem() -> String:
	if layout == null:
		return "layout is not assigned"
	if action_prefixes.is_empty():
		return "action_prefixes is empty (store the Players' prefixes, p1_ and p2_, in the scene)"
	for prefix: StringName in action_prefixes:
		if prefix.is_empty():
			return "a prefix in action_prefixes is empty"
		var problem: String = layout.first_problem(prefix)
		if not problem.is_empty():
			return "the pad layout for %s: %s" % [prefix, problem]
	return ""


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		connect_pad(device)
	else:
		disconnect_pad(device)
