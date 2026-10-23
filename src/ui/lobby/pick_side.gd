class_name PickSide
extends Control
## The first screen (Story 048; Martin, 2026-10-23: "nech tam je nieco v uvode ze pick a side. a ked
## pohnes packu/sipku rovno sa zaregistruje aj ovladac aj vyberie strana"): up to four Players join
## and pick a side, each on a pad or on a keyboard half, then the map choice opens with their lineup.
##
## Implements: production/epics/wasteland-fire/story-048-four-players.md AC-1, AC-2.
##
## Devices. The two keyboard halves are Player 1's and Player 2's keys of project.godot (read from the
## project settings, never from the InputMap, which a match rewrites): steer left and right move, fire
## confirms. A pad moves with its left stick or D-pad, confirms with A and goes back with B. Every
## device is read here from raw events: no PadAssignment is in this scene.
##
## A device's place: absent, ORANGE, MIDDLE or TEAL. From absent, left joins Orange and right joins Teal
## at once; then left and right step it Orange <-> Middle <-> Teal (Middle is joined but out of the
## Round). Confirm makes a Player on a side ready, back (B) makes a ready Player not ready, or takes a
## Player who is not ready out (absent). A Player who is ready does not move. At most MAX_PLAYERS devices
## join. When every Player on a side is ready and both sides have one, the map choice opens after
## start_delay_seconds with the Lineup (Orange in joining order, then Teal); anyone's move or back in
## that time stops it.

## Emitted when the lineup is complete and the map choice is about to open.
signal lineup_ready(lineup: Lineup)

enum Place { ORANGE, MIDDLE, TEAL }

## The map choice scene, whose root is a MapChoice. Required.
@export var map_choice_scene: PackedScene
## The columns the joined devices are listed in. Required.
@export var orange_list: VBoxContainer
@export var middle_list: VBoxContainer
@export var teal_list: VBoxContainer
## The line that says what to do or that the match starts.
@export var status_label: Label
## The look of a device's card: a Player not ready and one ready.
@export var card_style: StyleBox
@export var ready_style: StyleBox
## Seconds between the last confirm and the map choice.
@export_range(0.0, 10.0, 0.1) var start_delay_seconds: float = 1.0
## How far a stick must lean to count as a move (and come back under to count again).
@export_range(0.1, 0.95, 0.05) var stick_threshold: float = 0.6
## Texts, through tr(): the device names (%d is the pad's number, from 1), the ready mark, the status lines.
@export var keyboard_1_text: String = ""
@export var keyboard_2_text: String = ""
@export var pad_format: String = ""
@export var ready_suffix: String = ""
@export var join_text: String = ""
@export var need_sides_text: String = ""
@export var need_ready_text: String = ""
@export var starting_text: String = ""

## Every joined device in joining order: [device, Place, ready].
var _joined: Array[Array] = []
## Per pad, the stick's last side (-1, 0, 1), so one lean is one move.
var _stick_side: Dictionary[int, int] = {}
var _countdown: float = -1.0
var _started: bool = false
var _keys_1: Dictionary = {}
var _keys_2: Dictionary = {}


func _ready() -> void:
	if map_choice_scene == null or orange_list == null or middle_list == null or teal_list == null:
		push_error("PickSide '%s': map_choice_scene and the three lists must be set, so nobody can join." % name)
		set_process(false)
		set_process_input(false)
		return
	_keys_1 = _project_keys("p1_")
	_keys_2 = _project_keys("p2_")
	_refresh()


## The lineup of the Players on a side now (Orange first), playable or not.
func current_lineup() -> Lineup:
	var devices: Array[int] = []
	var teams: Array[int] = []
	for entry: Array in _joined:
		if entry[1] != Place.MIDDLE:
			devices.append(entry[0])
			teams.append(Lineup.ORANGE if entry[1] == Place.ORANGE else Lineup.TEAL)
	return Lineup.of(devices, teams)


## A device moves one step left (-1) or right (1): it joins on that side when absent.
func move(device: int, direction: int) -> void:
	if _started:
		return
	var index: int = _index_of(device)
	if index < 0:
		if _joined.size() >= Lineup.MAX_PLAYERS:
			return
		_joined.append([device, Place.ORANGE if direction < 0 else Place.TEAL, false])
	elif not _joined[index][2]:
		var place: int = clampi(int(_joined[index][1]) + direction, Place.ORANGE, Place.TEAL)
		_joined[index][1] = place
	_countdown = -1.0
	_refresh()


## A device confirms: a Player on a side is ready.
func confirm(device: int) -> void:
	if _started:
		return
	var index: int = _index_of(device)
	if index < 0 or _joined[index][1] == Place.MIDDLE:
		return
	_joined[index][2] = true
	_refresh()


## A device goes back: a ready Player is not ready any more, one who is not ready leaves.
func back(device: int) -> void:
	if _started:
		return
	var index: int = _index_of(device)
	if index < 0:
		return
	if _joined[index][2]:
		_joined[index][2] = false
	else:
		_joined.remove_at(index)
	_countdown = -1.0
	_refresh()


func _process(delta: float) -> void:
	if _started or _countdown < 0.0:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_start()


func _input(event: InputEvent) -> void:
	if _started:
		return
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if key.echo or not key.pressed:
			return
		for pair: Array in [[Lineup.KEYBOARD_1, _keys_1], [Lineup.KEYBOARD_2, _keys_2]]:
			var keys: Dictionary = pair[1]
			if _matches(key, keys, "steer_left"):
				move(pair[0], -1)
			elif _matches(key, keys, "steer_right"):
				move(pair[0], 1)
			elif _matches(key, keys, "fire"):
				confirm(pair[0])
			elif _matches(key, keys, "self_destruct"):
				back(pair[0])
			else:
				continue
			get_viewport().set_input_as_handled()
			return
		return
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		if not button.pressed:
			return
		match button.button_index:
			JOY_BUTTON_DPAD_LEFT:
				move(button.device, -1)
			JOY_BUTTON_DPAD_RIGHT:
				move(button.device, 1)
			JOY_BUTTON_A:
				confirm(button.device)
			JOY_BUTTON_B:
				back(button.device)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null and motion.axis == JOY_AXIS_LEFT_X:
		var side: int = 0
		if motion.axis_value <= -stick_threshold:
			side = -1
		elif motion.axis_value >= stick_threshold:
			side = 1
		var was: int = _stick_side.get(motion.device, 0)
		_stick_side[motion.device] = side
		if side != 0 and side != was:
			move(motion.device, side)
			get_viewport().set_input_as_handled()


func _index_of(device: int) -> int:
	for index: int in _joined.size():
		if _joined[index][0] == device:
			return index
	return -1


## Rebuilds the three lists and the status line, and starts the countdown when the lineup is complete.
func _refresh() -> void:
	for list: VBoxContainer in [orange_list, middle_list, teal_list]:
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()
	var lists: Array[VBoxContainer] = [orange_list, middle_list, teal_list]
	for entry: Array in _joined:
		lists[entry[1]].add_child(_card(entry))
	var lineup: Lineup = current_lineup()
	var all_ready: bool = true
	for entry: Array in _joined:
		if entry[1] != Place.MIDDLE and not entry[2]:
			all_ready = false
	var text: String = join_text
	if _joined.is_empty():
		text = join_text
	elif not lineup.is_playable():
		text = need_sides_text
	elif not all_ready:
		text = need_ready_text
	else:
		text = starting_text
		if _countdown < 0.0:
			_countdown = start_delay_seconds
	if status_label != null:
		status_label.text = tr(text)


func _card(entry: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var style: StyleBox = ready_style if entry[2] else card_style
	if style != null:
		card.add_theme_stylebox_override(&"panel", style)
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", CARD_FONT_SIZE)
	label.text = device_name(entry[0]) + (tr(ready_suffix) if entry[2] else "")
	card.add_child(label)
	return card


## The name a device is shown by: a keyboard half's, or the pad's number (device id + 1).
func device_name(device: int) -> String:
	if device == Lineup.KEYBOARD_1:
		return tr(keyboard_1_text)
	if device == Lineup.KEYBOARD_2:
		return tr(keyboard_2_text)
	return tr(pad_format) % (device + 1)


func _start() -> void:
	var lineup: Lineup = current_lineup()
	if not lineup.is_playable():
		_countdown = -1.0
		return
	var instance: Node = map_choice_scene.instantiate()
	var choice: MapChoice = instance as MapChoice
	if choice == null:
		push_error("PickSide '%s': the root of map_choice_scene is not a MapChoice, so the match does not start." % name)
		instance.free()
		return
	_started = true
	choice.lineup = lineup
	lineup_ready.emit(lineup)
	var tree: SceneTree = get_tree()
	tree.root.add_child(choice)
	tree.current_scene = choice
	queue_free()


func _matches(key: InputEventKey, keys: Dictionary, suffix: String) -> bool:
	for event: InputEventKey in keys.get(suffix, []):
		if event.physical_keycode == key.physical_keycode and event.physical_keycode != KEY_NONE:
			return true
	return false


## The key events project.godot gives the actions of a prefix, by action suffix (as SplitScreen's).
static func _project_keys(prefix: String) -> Dictionary:
	return SplitScreen._project_keys(prefix)


## The font size of a device's card.
const CARD_FONT_SIZE: int = 24
