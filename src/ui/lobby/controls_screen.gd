class_name ControlsScreen
extends Control
## The Controls screen, opened from Pick a side (Story 060; Martin, 2026-10-26: "moznost nastavit
## ovladanie. aj pre keyboard aj ovladace. a aby tam bolo aj default co ich revertne. na zaciatku v
## menu, kde si volime timy"): a table of the actions, a column per keyboard half and one per pad
## slot. Choose a cell, then press the key or the pad input it should take; Default puts every
## control back; Back closes it. Every change is written to the file at once.
##
## Implements: production/epics/wasteland-fire/story-060-controls-settings.md AC-1 to AC-3, AC-6.
##
## The screen only shows and asks: ControlBindings decides what a press does (a key in use moves to
## the action this one came from; reserved inputs are refused) and keeps the file. Moving between
## cells is the engine's focus with the ui_ actions (arrows, D-pad, left stick) and the mouse;
## ui_accept (Enter, Space, A) or a click chooses a cell; ui_cancel (Escape, B) goes back.
##
## States, two: browsing (focus moves, a cell chosen -> listening; Default; Back -> closed) and
## listening for one cell (a key, for a keyboard column, or a pad button, a stick or a trigger moved
## past ControlsSettings.capture_threshold, for a pad column -> taken, back to browsing; Escape or
## listen_seconds without one -> back to browsing unchanged; Delete or Backspace in a pad column ->
## that slot emptied, when the action keeps another). After a press is taken, input is swallowed for
## quiet_seconds, so the stick still held does not move the focus at once.

## The screen was closed with Back.
signal closed

## The controls shown and changed. Set before the screen enters the tree. Required.
var bindings: ControlBindings

## How long the screen waits for a press before it gives up.
@export_range(1.0, 30.0, 0.5) var listen_seconds: float = 6.0
## How long input is swallowed after a press is taken.
@export_range(0.0, 1.0, 0.05) var quiet_seconds: float = 0.3
## The cells' look: as they are, focused, and listening.
@export var cell_style: StyleBox
@export var focus_style: StyleBox
@export var listen_style: StyleBox
## The font size of the table.
@export_range(10, 40, 1) var cell_font_size: int = 18
## Texts, through tr(): the column heads, the buttons, the status lines (each %s the action's name,
## the column's head, or a key), the waiting mark.
@export var keyboard_1_head: String = ""
@export var keyboard_2_head: String = ""
@export var pad_head: String = ""
@export var pad_extra_head: String = ""
@export var default_text: String = ""
@export var back_text: String = ""
@export var browse_text: String = ""
@export var listen_key_format: String = ""
@export var listen_pad_format: String = ""
@export var taken_format: String = ""
@export var moved_format: String = ""
@export var reserved_text: String = ""
@export var last_input_text: String = ""
@export var cleared_format: String = ""
@export var reset_text: String = ""
@export var waiting_text: String = ""
@export var empty_text: String = ""
## The table and the status line, in the scene. Required.
@export var table: GridContainer
@export var status_label: Label
@export var default_button: Button
@export var back_button: Button

## The cells by [row, column]: column 0 and 1 the keyboard halves, 2 and on the pad slots.
var _cells: Dictionary = {}
## The cell listened for, [row, column], or [] while browsing.
var _listening: Array = []
var _listen_left: float = 0.0
var _quiet_left: float = 0.0
## Per pad axis (device * 10 + axis), whether it was past the threshold, so one move is one press.
var _axis_out: Dictionary = {}


func _ready() -> void:
	if bindings == null or table == null or status_label == null:
		push_error("ControlsScreen '%s': bindings, table and status_label must be set, so the screen shows nothing." % name)
		set_process(false)
		set_process_input(false)
		return
	_build()
	default_button.text = tr(default_text)
	back_button.text = tr(back_text)
	default_button.pressed.connect(reset_all)
	back_button.pressed.connect(close)
	_show(tr(browse_text))
	(_cells[[0, 0]] as Button).grab_focus.call_deferred()


## The number of columns: the two keyboard halves and the pad slots.
func column_count() -> int:
	return ControlBindings.KEY_PREFIXES.size() + bindings.settings.pad_slots


## The text a cell shows now.
func cell_text(row: int, column: int) -> String:
	return (_cells[[row, column]] as Button).text


## True while the screen waits for a press.
func is_listening() -> bool:
	return not _listening.is_empty()


## The status line now.
func status_text() -> String:
	return status_label.text


## Starts listening for the cell's new input (a click or ui_accept on it).
func listen(row: int, column: int) -> void:
	if not _cells.has([row, column]):
		return
	_listening = [row, column]
	_listen_left = listen_seconds
	_refresh()
	var action: String = tr(bindings.settings.action_names[row])
	if column < ControlBindings.KEY_PREFIXES.size():
		_show(tr(listen_key_format) % [action, _head(column)])
	else:
		_show(tr(listen_pad_format) % [action, _head(column)])


## Every control back to the defaults (the Default button), written to the file.
func reset_all() -> void:
	_listening = []
	bindings.reset()
	bindings.save()
	_refresh()
	_show(tr(reset_text))


## Writes the controls and closes the screen (the Back button, Escape or B while browsing).
func close() -> void:
	bindings.save()
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	_quiet_left = maxf(_quiet_left - delta, 0.0)
	if _listening.is_empty():
		return
	_listen_left -= delta
	if _listen_left <= 0.0:
		_listening = []
		_refresh()
		_show(tr(browse_text))


func _input(event: InputEvent) -> void:
	if _quiet_left > 0.0 and not (event is InputEventMouse):
		var still: InputEventJoypadMotion = event as InputEventJoypadMotion
		if still != null:
			_axis_out[still.device * 10 + int(still.axis)] = absf(still.axis_value) >= bindings.settings.capture_threshold
		get_viewport().set_input_as_handled()
		return
	if _listening.is_empty():
		if event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			close()
		return
	var row: int = _listening[0]
	var column: int = _listening[1]
	var suffix: String = bindings.settings.actions[row]
	var key: InputEventKey = event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		if key.physical_keycode == KEY_ESCAPE:
			_listening = []
			_refresh()
			_show(tr(browse_text))
			return
		if column < ControlBindings.KEY_PREFIXES.size():
			var prefix: String = ControlBindings.KEY_PREFIXES[column]
			_answer(bindings.set_key(prefix, suffix, key.physical_keycode, key.location), row, column)
		elif key.physical_keycode == KEY_DELETE or key.physical_keycode == KEY_BACKSPACE:
			var slot: int = column - ControlBindings.KEY_PREFIXES.size()
			if bindings.clear_pad(suffix, slot):
				bindings.save()
				_done(tr(cleared_format) % tr(bindings.settings.action_names[row]))
			else:
				_done(tr(last_input_text))
		return
	if column < ControlBindings.KEY_PREFIXES.size():
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			get_viewport().set_input_as_handled()
		return
	var slot_index: int = column - ControlBindings.KEY_PREFIXES.size()
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		if not button.pressed:
			return
		get_viewport().set_input_as_handled()
		_answer(bindings.set_pad(suffix, slot_index, PadBinding.Kind.BUTTON, button.button_index, JOY_AXIS_INVALID, 0), row, column)
		return
	var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion != null:
		var key_id: int = motion.device * 10 + int(motion.axis)
		var out: bool = absf(motion.axis_value) >= bindings.settings.capture_threshold
		var was: bool = _axis_out.get(key_id, false)
		_axis_out[key_id] = out
		get_viewport().set_input_as_handled()
		if out and not was:
			_answer(bindings.set_pad(suffix, slot_index, PadBinding.Kind.AXIS, JOY_BUTTON_INVALID, motion.axis, int(signf(motion.axis_value))), row, column)


## What ControlBindings answered for a press on the cell: the status line says it.
func _answer(result: Dictionary, row: int, column: int) -> void:
	var action: String = tr(bindings.settings.action_names[row])
	if not result["ok"]:
		_done(tr(last_input_text) if result["reason"] == "last input" else tr(reserved_text))
		return
	bindings.save()
	var moved: Array = result["moved"]
	if moved.is_empty():
		_done(tr(taken_format) % [action, _cell_value(row, column)])
		return
	var other_row: int = bindings.settings.actions.find(moved[-1])
	var other: String = tr(bindings.settings.action_names[other_row])
	if moved.size() == 2:
		other = "%s (%s)" % [other, _head(ControlBindings.KEY_PREFIXES.find(moved[0]))]
	_done(tr(moved_format) % [action, _cell_value(row, column), other])


func _done(line: String) -> void:
	_listening = []
	_quiet_left = quiet_seconds
	_refresh()
	_show(line)


func _show(line: String) -> void:
	status_label.text = line


func _head(column: int) -> String:
	var heads: Array[String] = [keyboard_1_head, keyboard_2_head]
	if column < heads.size():
		return tr(heads[column])
	if column == heads.size():
		return tr(pad_head)
	return tr(pad_extra_head)


## The value a cell stands for: the key's name, the pad input's name, or empty_text.
func _cell_value(row: int, column: int) -> String:
	var suffix: String = bindings.settings.actions[row]
	if column < ControlBindings.KEY_PREFIXES.size():
		var event: InputEventKey = bindings.key_of(ControlBindings.KEY_PREFIXES[column], suffix)
		return ControlBindings.key_name(event) if event != null else tr(empty_text)
	var slots: Array = bindings.pad_of(suffix)
	var slot: int = column - ControlBindings.KEY_PREFIXES.size()
	return tr((slots[slot] as PadBinding).display_name) if slot < slots.size() else tr(empty_text)


func _build() -> void:
	table.columns = column_count() + 1
	table.add_child(_label(""))
	for column: int in column_count():
		table.add_child(_label(_head(column), true))
	for row: int in bindings.settings.actions.size():
		table.add_child(_label(tr(bindings.settings.action_names[row])))
		for column: int in column_count():
			var cell := Button.new()
			cell.custom_minimum_size = Vector2(0, 0)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_theme_font_size_override(&"font_size", cell_font_size)
			for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
				if cell_style != null:
					cell.add_theme_stylebox_override(state, cell_style)
			if focus_style != null:
				cell.add_theme_stylebox_override(&"focus", focus_style)
			cell.pressed.connect(listen.bind(row, column))
			_cells[[row, column]] = cell
			table.add_child(cell)
	_refresh()


func _label(text: String, head: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", cell_font_size)
	if head:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(1, 1, 1, 0.7)
	return label


func _refresh() -> void:
	for cell_key: Array in _cells:
		var cell: Button = _cells[cell_key]
		var listening: bool = _listening == cell_key
		cell.text = tr(waiting_text) if listening else _cell_value(cell_key[0], cell_key[1])
		var style: StyleBox = listen_style if listening else cell_style
		if style != null:
			cell.add_theme_stylebox_override(&"normal", style)
