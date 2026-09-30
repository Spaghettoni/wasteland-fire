extends Control
## Keyboard-ghosting check for Story 002 (split screen for two): a scene the developer runs by hand
## on the real keyboard, to find out whether that keyboard delivers every key the two Players hold
## at once.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md AC-4 ("any keyboard-ghosting
## limit found on the dev keyboard is recorded in the evidence doc") and design/game-brief.md build
## order item 2 (two Players on one keyboard, both driving at once). Tooling only: nothing under src/
## depends on this file. Its only couplings to the game are the Input Map actions the game itself
## drives with (p1_ and p2_, declared in project.godot) and the two Body materials, in
## src/gameplay/split_screen/data/, whose colours the cells light in.
##
## Why a tool and not a test. A keyboard that cannot report a combination drops a key, or invents
## one, before the operating system ever sees it, so no injected event and no automated run can find
## the limit: only a human on the physical keyboard can measure it. This tool makes the measurement
## quick and its result citable.
##
## On screen:
##   - Two columns of four key cells each, laid out as the inverted T of the keys, each titled with
##     the Player's name and the keys its four actions are bound to. A cell lights, in
##     the colour of its Player's Motorbike, while its Input Map action is held, read with
##     Input.is_action_pressed: the path PlayerDriveInput takes, so what lights here is what the game
##     would drive with. The key name on a cell is read from the Input Map, not typed here.
##   - "Held now: N action(s)   Most at once: M": how many of the eight actions are held.
##   - The raw physical keys the window receives, from _input (OS.get_keycode_string of each event's
##     physical_keycode), and the most held at once. This is the keyboard's own report, before the
##     Input Map, so a phantom key or a swallowed key shows up here.
##   - A checklist of the six combinations both Players actually use (COMBINATIONS, below), each
##     turning green the first time all four of its keys are held at the same moment.
##
## Reading the result. A combination that never turns green while you hold its four keys has lost a
## key somewhere. If the raw line lists only three of the four keys, the keyboard or the operating
## system did not deliver the fourth: that combination is the keyboard-ghosting limit to record in
## production/qa/evidence/story-002-split-screen-evidence.md, with the keyboard's make and model. If
## the raw line lists all four but the Held count is lower, the Input Map lost it: that is a bug in
## project.godot, not in the keyboard.
##
## The result. Esc, the window close button, or --quit-after prints exactly one line to stdout and
## quits (Esc and the close button through finish(); --quit-after when the scene tree is torn down):
##   GHOST combos_seen=<n>/<total> missing=[<names>] max_actions_at_once=<m> max_raw_keys_at_once=<k>
## Copy it into the evidence doc. What is watched is data: COMBINATIONS and PLAYER_COLUMNS list
## Input Map action names, and the only key this script names is the one that quits (QUIT_KEY);
## every other key name on screen is read from the Input Map. It never reads InputEvent.device (AC-6): the
## layouts, not the devices, tell the Players apart.
##
## Self test. With the user argument --self-test (after the "--") the scene tests itself and waits
## for no key, so an unattended or headless run cannot hang. It pushes each combination's keys, read
## from the Input Map, through Input.parse_input_event as real key events (device
## InputEvent.DEVICE_ID_KEYBOARD), waits for the page to poll them, and requires that the line turns
## green, that exactly its cells light, that the raw-key line counts its keys and that the release
## clears all of it. First it holds all but one key of a combination and requires that the line does
## not turn green, so the test can fail. It prints one line in place of the GHOST line and quits,
## with exit code 0 when it passed and 1 when it did not:
##   GHOST SELF-TEST ok combos_seen=<n>/<total> max_actions_at_once=<m> max_raw_keys_at_once=<k>
##   GHOST SELF-TEST fail <what went wrong> | combos_seen=<n>/<total> ...
## It proves the tool's bookkeeping, not the keyboard: only a human on the physical keyboard can
## find a ghosting limit.
##
## Examples:
##   godot --path . res://tools/evidence/input_ghosting_check.tscn
##       By hand: hold each combination, press Esc, copy the GHOST line.
##   godot --headless --path . res://tools/evidence/input_ghosting_check.tscn -- --self-test
##       Unattended: prints GHOST SELF-TEST ok and exits 0 when the bookkeeping works.
##   godot --path . --windowed --resolution 1280x720 --write-movie shots/ghost.png --quit-after 60 \
##       res://tools/evidence/input_ghosting_check.tscn
##       A capture of the idle screen.

## The key that ends an interactive run and prints the summary.
const QUIT_KEY: Key = KEY_ESCAPE

## Player 1's Motorbike Body material: its albedo_color is the colour Player 1's cells light in.
const PLAYER_1_BODY_MATERIAL: StandardMaterial3D = preload(
		"res://src/gameplay/split_screen/data/player_1_body_material.tres")

## Player 2's Motorbike Body material: its albedo_color is the colour Player 2's cells light in.
const PLAYER_2_BODY_MATERIAL: StandardMaterial3D = preload(
		"res://src/gameplay/split_screen/data/player_2_body_material.tres")

## The two Players' columns, left to right. title names the Player; the column heading adds the
## keys its four actions are bound to, read from the Input Map, so a rebinding shows up. material is
## the Body material of that Player's Motorbike: a cell lights in its albedo_color, so the tool
## follows the two .tres files and holds no copy of the colours. Each cell watches one Input Map
## action; slot is its place in a grid of three columns by two rows, numbered 0 to 5 left to right
## and top to bottom, so that throttle (1) sits above steer left, reverse and steer right (3, 4, 5):
## the inverted T of W A S D and of the arrow keys.
const PLAYER_COLUMNS: Array[Dictionary] = [
	{
		"title": "Player 1",
		"material": PLAYER_1_BODY_MATERIAL,
		"cells": [
			{"action": &"p1_throttle", "slot": 1},
			{"action": &"p1_steer_left", "slot": 3},
			{"action": &"p1_reverse", "slot": 4},
			{"action": &"p1_steer_right", "slot": 5},
		],
	},
	{
		"title": "Player 2",
		"material": PLAYER_2_BODY_MATERIAL,
		"cells": [
			{"action": &"p2_throttle", "slot": 1},
			{"action": &"p2_steer_left", "slot": 3},
			{"action": &"p2_reverse", "slot": 4},
			{"action": &"p2_steer_right", "slot": 5},
		],
	},
]

## The combinations both Players actually use while driving, one line each on the checklist. name
## is what the line and the summary's missing list call it. actions are the Input Map actions that
## must all be held at the same moment: the two of Player 1, then the two of Player 2, four keys in
## all. The six are both Players on throttle steering the same way (two lines), both on throttle
## steering opposite ways (two lines), and both reversing while steering opposite ways (two lines).
## Add a line to check another pairing: the checklist and the summary follow this data.
const COMBINATIONS: Array[Dictionary] = [
	{
		"name": "P1 throttle+left / P2 throttle+left",
		"actions": [&"p1_throttle", &"p1_steer_left", &"p2_throttle", &"p2_steer_left"],
	},
	{
		"name": "P1 throttle+right / P2 throttle+right",
		"actions": [&"p1_throttle", &"p1_steer_right", &"p2_throttle", &"p2_steer_right"],
	},
	{
		"name": "P1 throttle+left / P2 throttle+right",
		"actions": [&"p1_throttle", &"p1_steer_left", &"p2_throttle", &"p2_steer_right"],
	},
	{
		"name": "P1 throttle+right / P2 throttle+left",
		"actions": [&"p1_throttle", &"p1_steer_right", &"p2_throttle", &"p2_steer_left"],
	},
	{
		"name": "P1 reverse+left / P2 reverse+right",
		"actions": [&"p1_reverse", &"p1_steer_left", &"p2_reverse", &"p2_steer_right"],
	},
	{
		"name": "P1 reverse+right / P2 reverse+left",
		"actions": [&"p1_reverse", &"p1_steer_right", &"p2_reverse", &"p2_steer_left"],
	},
]

## The window title.
const WINDOW_TITLE: String = "Wasteland Fire: keyboard ghosting check"

## The page title.
const TITLE: String = "Keyboard ghosting check"

## What the developer has to do. This is the text the developer reads when the scene opens.
const INSTRUCTIONS: String = (
		"Hold each combination for two seconds. Green means the keyboard delivered all four keys at once. "
		+ "Esc quits and prints the summary.")

## Heading of the checklist.
const COMBINATIONS_HEADING: String = "Combinations both Players use (four keys each)"

## The user argument (after the "--") that makes the scene test itself instead of waiting for a
## keyboard.
const SELF_TEST_ARGUMENT: String = "--self-test"

## Frames the self test waits after sending keys before it reads the page. Awaiting process_frame
## resumes before that frame's _process (measured on 4.7.2), so the first frame holds no poll that
## saw the keys yet and the second one does.
const SELF_TEST_FRAMES: int = 2

## Exit code of a self test that failed.
const EXIT_SELF_TEST_FAILED: int = 1

## Page background colour.
const BACKGROUND_COLOR: Color = Color(0.09, 0.10, 0.12)
## Colour of the main text.
const TEXT_COLOR: Color = Color(0.94, 0.95, 0.97)
## Colour of secondary text.
const DIM_TEXT_COLOR: Color = Color(0.74, 0.77, 0.82)
## Background of a key cell while its action is not held.
const IDLE_CELL_COLOR: Color = Color(0.19, 0.20, 0.24)
## Background of a checklist line whose combination has not been seen.
const IDLE_ROW_COLOR: Color = Color(0.15, 0.16, 0.19)
## Background of a checklist line whose combination has been seen (the green of "Green means...").
const SEEN_ROW_COLOR: Color = Color(0.14, 0.58, 0.28)
## Colour of an error message.
const ERROR_COLOR: Color = Color(1.0, 0.45, 0.40)

## Font sizes, in pixels, laid out for a 1280 x 720 window. This one is the page title's.
const TITLE_FONT_SIZE: int = 28
## Font size of body text.
const BODY_FONT_SIZE: int = 20
## Font size of a column title.
const COLUMN_TITLE_FONT_SIZE: int = 24
## Font size of the key name on a cell.
const CELL_KEY_FONT_SIZE: int = 22
## Font size of the action name on a cell.
const CELL_ACTION_FONT_SIZE: int = 13
## Font size of the "Held now" line.
const STATUS_FONT_SIZE: int = 26
## Font size of the checklist heading.
const HEADING_FONT_SIZE: int = 20

## Page layout, in pixels: the margin round the page.
const PAGE_MARGIN: int = 20
## The gap between the blocks of the page.
const PAGE_SEPARATION: int = 6
## The gap between the two columns.
const COLUMN_GAP: int = 24
## The gap between key cells.
const CELL_GAP: int = 8
## The gap between checklist lines.
const ROW_GAP: int = 4
## The corner radius of every panel.
const PANEL_CORNER_RADIUS: int = 6
## The inner margin of every panel.
const PANEL_CONTENT_MARGIN: float = 4.0
## The smallest a key cell may get.
const CELL_MIN_SIZE: Vector2 = Vector2(0.0, 56.0)
## The gap between the parts of one checklist line: its number, name, keys and status.
const ROW_LINE_SEPARATION: int = 16
## The width of the number at the left end of a checklist line.
const ROW_NUMBER_WIDTH: float = 24.0
## The width of the keys to hold on a checklist line.
const ROW_KEYS_WIDTH: float = 280.0
## The width of the status at the right end of a checklist line.
const ROW_STATUS_WIDTH: float = 150.0

## The key cells' grid: three columns by two rows, so six slots.
const GRID_COLUMNS: int = 3
## The number of slots in a Player's grid of key cells (three columns by two rows).
const GRID_SLOTS: int = 6

## The MarginContainer constants that set the four sides of the page margin.
const MARGIN_SIDES: Array[StringName] = [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]


## One key cell in a Player's column: the Input Map action it watches and the panel that lights.
class ActionCell extends RefCounted:
	## The Input Map action whose state the cell shows.
	var action: StringName = &""
	## The panel that holds the cell, added to the column's grid.
	var panel: PanelContainer = null
	## The panel's style; its background is the light.
	var style: StyleBoxFlat = null
	## Background while the action is held.
	var lit_color: Color = Color.WHITE
	## Background while it is not.
	var idle_color: Color = Color.BLACK
	## True while the action is held, as of the last poll.
	var lit: bool = false

	## Lights or darkens the cell. Does nothing when the state is unchanged.
	func set_lit(p_lit: bool) -> void:
		if p_lit == lit:
			return
		lit = p_lit
		style.bg_color = lit_color if lit else idle_color


## One line of the checklist: a combination of Input Map actions that must be held together.
class ComboRow extends RefCounted:
	## The name shown on the line and listed in the summary while the combination is missing.
	var combo_name: String = ""
	## The Input Map actions that must all be held at the same moment.
	var actions: Array[StringName] = []
	## True once every action was held in the same poll. Stays true.
	var seen: bool = false
	## How many of the actions were held in the last poll.
	var held_now: int = 0
	## The panel that holds the line, added to the checklist.
	var panel: PanelContainer = null
	## The panel's style; its background turns green when the combination is seen.
	var style: StyleBoxFlat = null
	## The status text at the right end of the line.
	var status_label: Label = null
	## Background while the combination has not been seen.
	var idle_color: Color = Color.BLACK
	## Background once it has.
	var seen_color: Color = Color.GREEN
	## The state the style shows, so the background is only touched when it changes.
	var shown_seen: bool = false

	## Brings the line's colour and status text up to date with seen and held_now.
	func refresh() -> void:
		if seen != shown_seen:
			shown_seen = seen
			style.bg_color = seen_color if seen else idle_color
		if seen:
			status_label.text = "ALL %d SEEN" % actions.size()
		elif held_now > 0:
			status_label.text = "%d/%d held" % [held_now, actions.size()]
		else:
			status_label.text = "waiting"


var _action_cells: Array[ActionCell] = []
var _combo_rows: Array[ComboRow] = []
var _held_label: Label = null
var _raw_label: Label = null
var _held_now: int = 0
var _max_actions_at_once: int = 0
## Physical keycodes of the keys held now, in the order they went down.
var _raw_keys_down: Array[int] = []
var _max_raw_keys_at_once: int = 0
var _summary_printed: bool = false


func _ready() -> void:
	get_window().title = WINDOW_TITLE
	var self_test: bool = OS.get_cmdline_user_args().has(SELF_TEST_ARGUMENT)
	var missing: PackedStringArray = _missing_actions()
	if not missing.is_empty():
		var names: String = ", ".join(missing)
		var message: String = "the Input Map has no action %s; both layouts are declared in project.godot" % names
		push_error("InputGhostingCheck: " + message)
		add_child(_make_label("ERROR: " + message, BODY_FONT_SIZE, ERROR_COLOR))
		set_process(false)
		if self_test:
			_end_self_test(PackedStringArray([message]))
		return
	_build_ui()
	if self_test:
		_run_self_test()


func _process(_delta: float) -> void:
	_poll_actions()


func _input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return
	var is_quit_key: bool = key_event.physical_keycode == QUIT_KEY or key_event.keycode == QUIT_KEY
	if key_event.pressed and not key_event.echo and is_quit_key:
		finish()
		return
	if key_event.echo:
		return
	_track_raw_key(key_event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		# A key released while another window has the focus is never reported here.
		_raw_keys_down.clear()
		_refresh_raw_label()


func _exit_tree() -> void:
	# The path of --quit-after, which tears the tree down without any request to quit.
	if not _summary_printed:
		_print_summary()


## The summary line: how many of the combinations were seen with all their keys held at once, which
## were not, and the most actions and the most raw keys held at once.
##
## Example: print(build_summary())
##   # GHOST combos_seen=5/6 missing=[P1 reverse+left / P2 reverse+right] max_actions_at_once=4 max_raw_keys_at_once=4
func build_summary() -> String:
	var missing: PackedStringArray = PackedStringArray()
	for row: ComboRow in _combo_rows:
		if not row.seen:
			missing.append(row.combo_name)
	return "GHOST combos_seen=%d/%d missing=[%s] max_actions_at_once=%d max_raw_keys_at_once=%d" % [
		combos_seen(), _combo_rows.size(), ", ".join(missing), _max_actions_at_once, _max_raw_keys_at_once]


## Ends the run: prints the summary line and quits. Esc and the window close button call it; it
## prints only once, however often it is called.
##
## Example: finish()  # what Esc and the window close button call
func finish() -> void:
	if _summary_printed:
		return
	_print_summary()
	get_tree().quit()


## How many of the combinations have had all their keys held at the same moment.
##
## Example: if combos_seen() == COMBINATIONS.size(): print("all combinations delivered")
func combos_seen() -> int:
	var seen_count: int = 0
	for row: ComboRow in _combo_rows:
		if row.seen:
			seen_count += 1
	return seen_count


## The names of the raw physical keys held now, in the order they went down, as the window receives
## them from the operating system.
##
## Example: print(raw_key_names())  # ["W", "A", "Up", "Left"]
func raw_key_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for code: int in _raw_keys_down:
		names.append(OS.get_keycode_string(code as Key))
	return names


## Prints the summary line, once.
func _print_summary() -> void:
	_summary_printed = true
	print(build_summary())


## The self test (--self-test), a coroutine. It pushes real key events through the Input singleton
## and requires the page to read them as it should: a combination held in full turns green, lights
## exactly its cells and counts its keys, a release clears all of it, and a combination held without
## one key does not turn green. Prints the one result line and quits.
func _run_self_test() -> void:
	if _combo_rows.is_empty():
		_end_self_test(PackedStringArray(["COMBINATIONS is empty, so there is nothing to test"]))
		return
	# Accumulated input would hold an event back until the next frame; off, it takes effect at once.
	var accumulated: bool = Input.use_accumulated_input
	Input.use_accumulated_input = false
	var failures: PackedStringArray = PackedStringArray()
	if combos_seen() != 0 or not _raw_keys_down.is_empty():
		failures.append("the page was not idle when the test began")
	failures.append_array(await _self_test_negative_control(_combo_rows[0]))
	for row: ComboRow in _combo_rows:
		failures.append_array(await _self_test_combination(row))
	failures.append_array(_self_test_totals())
	Input.use_accumulated_input = accumulated
	_end_self_test(failures)


## The negative control of the self test: all but the last key of a combination is not the
## combination, so its line must not turn green, and only the keys held may count. One text per
## problem, or an empty array.
func _self_test_negative_control(control: ComboRow) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var partial: Array[StringName] = []
	for index: int in control.actions.size() - 1:
		partial.append(control.actions[index])
	_send_keys(partial, true)
	await _wait_for_polls()
	if control.seen or control.held_now != partial.size() or _raw_keys_down.size() != partial.size():
		problems.append("%s: %d of %d keys held but seen=%s held_now=%d raw_keys=%d" % [
			control.combo_name, partial.size(), control.actions.size(), control.seen,
			control.held_now, _raw_keys_down.size()])
	_send_keys(partial, false)
	await _wait_for_polls()
	return problems


## One combination of the self test: held in full, the page must read it as it should
## (_held_problems), and the release must clear every held action and raw key. One text per
## problem, or an empty array.
func _self_test_combination(row: ComboRow) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	_send_keys(row.actions, true)
	await _wait_for_polls()
	problems.append_array(_held_problems(row))
	_send_keys(row.actions, false)
	await _wait_for_polls()
	if _held_now != 0 or not _raw_keys_down.is_empty():
		problems.append("%s: after the release %d actions and %d raw keys still count as held" % [
			row.combo_name, _held_now, _raw_keys_down.size()])
	return problems


## The totals of the self test, once every combination was held: every line turned green, and the
## most actions and raw keys counted at once equal the largest combination. One text per problem,
## or an empty array.
func _self_test_totals() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var most_keys: int = 0
	for row: ComboRow in _combo_rows:
		most_keys = maxi(most_keys, row.actions.size())
	if combos_seen() != _combo_rows.size():
		problems.append("only %d of %d combinations turned green" % [combos_seen(), _combo_rows.size()])
	if _max_actions_at_once != most_keys:
		problems.append("most actions at once is %d, expected %d" % [_max_actions_at_once, most_keys])
	if _max_raw_keys_at_once != most_keys:
		problems.append("most raw keys at once is %d, expected %d" % [_max_raw_keys_at_once, most_keys])
	return problems


## What is wrong with the page while a combination is held in full: one text per problem, or an
## empty array when it reads correctly.
func _held_problems(row: ComboRow) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if not row.seen or row.held_now != row.actions.size():
		problems.append("%s: all %d keys held but seen=%s held_now=%d" % [
			row.combo_name, row.actions.size(), row.seen, row.held_now])
	if _raw_keys_down.size() != row.actions.size():
		problems.append("%s: %d keys held but %d raw keys counted" % [
			row.combo_name, row.actions.size(), _raw_keys_down.size()])
	for cell: ActionCell in _action_cells:
		var expected: bool = row.actions.has(cell.action)
		if cell.lit != expected:
			problems.append("%s: cell %s lit=%s, expected %s" % [row.combo_name, cell.action, cell.lit, expected])
	return problems


## Pushes a key event for the key each action is bound to in the Input Map, down or up, through the
## Input singleton, the way the operating system delivers one.
func _send_keys(actions: Array[StringName], pressed: bool) -> void:
	for action: StringName in actions:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = _bound_key(action)
		event.pressed = pressed
		event.device = InputEvent.DEVICE_ID_KEYBOARD
		Input.parse_input_event(event)


## Waits SELF_TEST_FRAMES frames, so the page has polled the state the last event left.
func _wait_for_polls() -> void:
	for _frame: int in SELF_TEST_FRAMES:
		await get_tree().process_frame


## Prints the self test's one line, which stands in for the GHOST line, and quits: exit code 0 when
## nothing failed, EXIT_SELF_TEST_FAILED when something did.
func _end_self_test(failures: PackedStringArray) -> void:
	_summary_printed = true
	var passed: bool = failures.is_empty()
	var numbers: String = "combos_seen=%d/%d max_actions_at_once=%d max_raw_keys_at_once=%d" % [
		combos_seen(), _combo_rows.size(), _max_actions_at_once, _max_raw_keys_at_once]
	if passed:
		print("GHOST SELF-TEST ok " + numbers)
	else:
		print("GHOST SELF-TEST fail %s | %s" % ["; ".join(failures), numbers])
	get_tree().quit(0 if passed else EXIT_SELF_TEST_FAILED)


## The names of the watched actions the Input Map does not have. Reading an action that does not
## exist is an engine error every frame, so the scene checks first.
func _missing_actions() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for column_data: Dictionary in PLAYER_COLUMNS:
		var cells: Array[Dictionary] = []
		cells.assign(column_data["cells"])
		for cell_data: Dictionary in cells:
			var cell_action: StringName = cell_data["action"]
			if not InputMap.has_action(cell_action) and not missing.has(String(cell_action)):
				missing.append(String(cell_action))
	for combo: Dictionary in COMBINATIONS:
		var actions: Array[StringName] = []
		actions.assign(combo["actions"])
		for combo_action: StringName in actions:
			if not InputMap.has_action(combo_action) and not missing.has(String(combo_action)):
				missing.append(String(combo_action))
	return missing


## The physical key an Input Map action is bound to, or KEY_NONE when it has no key event.
func _bound_key(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event: InputEventKey = event as InputEventKey
		if key_event == null:
			continue
		if key_event.physical_keycode != KEY_NONE:
			return key_event.physical_keycode
		if key_event.keycode != KEY_NONE:
			return key_event.keycode
	return KEY_NONE


## The name of the key an Input Map action is bound to, as OS.get_keycode_string spells it.
func _key_text(action: StringName) -> String:
	var code: Key = _bound_key(action)
	if code == KEY_NONE:
		return "?"
	return OS.get_keycode_string(code)


## Reads every watched action once: lights the cells, counts the held ones, and turns a checklist
## line green the first time all its actions are held in the same poll.
func _poll_actions() -> void:
	var held: int = 0
	for cell: ActionCell in _action_cells:
		var down: bool = Input.is_action_pressed(cell.action)
		cell.set_lit(down)
		if down:
			held += 1
	_held_now = held
	_max_actions_at_once = maxi(_max_actions_at_once, held)
	_held_label.text = "Held now: %d action(s)   Most at once: %d" % [_held_now, _max_actions_at_once]
	for row: ComboRow in _combo_rows:
		var together: int = 0
		for action: StringName in row.actions:
			if Input.is_action_pressed(action):
				together += 1
		row.held_now = together
		if together == row.actions.size():
			row.seen = true
		row.refresh()


## Records a raw key going down or up, by physical keycode (the keycode when the physical one is
## unknown), and the most held at once.
func _track_raw_key(key_event: InputEventKey) -> void:
	var code: int = key_event.physical_keycode
	if code == KEY_NONE:
		code = key_event.keycode
	if code == KEY_NONE:
		return
	var index: int = _raw_keys_down.find(code)
	if key_event.pressed:
		if index == -1:
			_raw_keys_down.append(code)
	elif index != -1:
		_raw_keys_down.remove_at(index)
	_max_raw_keys_at_once = maxi(_max_raw_keys_at_once, _raw_keys_down.size())
	_refresh_raw_label()


## Rewrites the raw-keys line. Does nothing before the page is built, which is the state of the
## error path taken when the Input Map lacks an action.
func _refresh_raw_label() -> void:
	if _raw_label == null:
		return
	var names: PackedStringArray = raw_key_names()
	var shown: String = "none" if names.is_empty() else "  ".join(names)
	_raw_label.text = "Raw keys the window receives: %s   (%d now, most at once: %d)" % [
		shown, names.size(), _max_raw_keys_at_once]


## Builds the whole page from the data at the top of the script.
func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND_COLOR
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin_box: MarginContainer = MarginContainer.new()
	add_child(margin_box)
	margin_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in MARGIN_SIDES:
		margin_box.add_theme_constant_override(side, PAGE_MARGIN)

	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override(&"separation", PAGE_SEPARATION)
	margin_box.add_child(page)

	page.add_child(_make_label(TITLE, TITLE_FONT_SIZE, TEXT_COLOR))
	var instructions: Label = _make_label(INSTRUCTIONS, BODY_FONT_SIZE, DIM_TEXT_COLOR)
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(instructions)

	_build_columns(page)

	_held_label = _make_label("", STATUS_FONT_SIZE, TEXT_COLOR)
	page.add_child(_held_label)
	_raw_label = _make_label("", BODY_FONT_SIZE, DIM_TEXT_COLOR)
	page.add_child(_raw_label)

	page.add_child(_make_label(COMBINATIONS_HEADING, HEADING_FONT_SIZE, TEXT_COLOR))
	_build_checklist(page)

	_poll_actions()
	_refresh_raw_label()


## Builds the two Players' columns of key cells.
func _build_columns(parent: Control) -> void:
	var columns_box: HBoxContainer = HBoxContainer.new()
	columns_box.add_theme_constant_override(&"separation", COLUMN_GAP)
	parent.add_child(columns_box)
	for column_data: Dictionary in PLAYER_COLUMNS:
		var body_material: StandardMaterial3D = column_data["material"]
		var lit_color: Color = body_material.albedo_color
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override(&"separation", PAGE_SEPARATION)
		columns_box.add_child(column)
		var cells: Array[Dictionary] = []
		cells.assign(column_data["cells"])
		var keys: PackedStringArray = PackedStringArray()
		for cell_data: Dictionary in cells:
			keys.append(_key_text(cell_data["action"]))
		column.add_child(_make_label("%s: %s" % [column_data["title"], " ".join(keys)],
				COLUMN_TITLE_FONT_SIZE, TEXT_COLOR))

		var grid: GridContainer = GridContainer.new()
		grid.columns = GRID_COLUMNS
		grid.add_theme_constant_override(&"h_separation", CELL_GAP)
		grid.add_theme_constant_override(&"v_separation", CELL_GAP)
		column.add_child(grid)

		var slot_controls: Array[Control] = []
		slot_controls.resize(GRID_SLOTS)
		for cell_data: Dictionary in cells:
			var cell: ActionCell = _make_action_cell(cell_data["action"], lit_color)
			_action_cells.append(cell)
			slot_controls[cell_data["slot"]] = cell.panel
		for slot: int in GRID_SLOTS:
			var slot_control: Control = slot_controls[slot]
			if slot_control == null:
				slot_control = Control.new()
				slot_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(slot_control)


## Builds one key cell: the key name, large, and the Input Map action it watches, small.
func _make_action_cell(action: StringName, lit_color: Color) -> ActionCell:
	var cell: ActionCell = ActionCell.new()
	cell.action = action
	cell.lit_color = lit_color
	cell.idle_color = IDLE_CELL_COLOR
	cell.style = _make_panel_style(IDLE_CELL_COLOR)
	cell.panel = PanelContainer.new()
	cell.panel.custom_minimum_size = CELL_MIN_SIZE
	cell.panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.panel.add_theme_stylebox_override(&"panel", cell.style)
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 0)
	cell.panel.add_child(box)
	var key_label: Label = _make_label(_key_text(action), CELL_KEY_FONT_SIZE, TEXT_COLOR)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(key_label)
	var action_label: Label = _make_label(String(action), CELL_ACTION_FONT_SIZE, DIM_TEXT_COLOR)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(action_label)
	return cell


## Builds the checklist: one line per entry of COMBINATIONS.
func _build_checklist(parent: Control) -> void:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override(&"separation", ROW_GAP)
	parent.add_child(list)
	for index: int in COMBINATIONS.size():
		var row: ComboRow = _make_combo_row(index, COMBINATIONS[index])
		_combo_rows.append(row)
		list.add_child(row.panel)


## Builds one checklist line: its number, its name, the keys to hold (read from the Input Map) and
## its status.
func _make_combo_row(index: int, combo: Dictionary) -> ComboRow:
	var row: ComboRow = ComboRow.new()
	row.combo_name = combo["name"]
	row.actions.assign(combo["actions"])
	var key_names: PackedStringArray = PackedStringArray()
	for action: StringName in row.actions:
		key_names.append(_key_text(action))
	row.idle_color = IDLE_ROW_COLOR
	row.seen_color = SEEN_ROW_COLOR
	row.style = _make_panel_style(IDLE_ROW_COLOR)
	row.panel = PanelContainer.new()
	row.panel.add_theme_stylebox_override(&"panel", row.style)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override(&"separation", ROW_LINE_SEPARATION)
	row.panel.add_child(line)

	var number_label: Label = _make_label(str(index + 1), BODY_FONT_SIZE, DIM_TEXT_COLOR)
	number_label.custom_minimum_size = Vector2(ROW_NUMBER_WIDTH, 0.0)
	line.add_child(number_label)
	var name_label: Label = _make_label(row.combo_name, BODY_FONT_SIZE, TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var keys_label: Label = _make_label(" + ".join(key_names), BODY_FONT_SIZE, DIM_TEXT_COLOR)
	keys_label.custom_minimum_size = Vector2(ROW_KEYS_WIDTH, 0.0)
	line.add_child(keys_label)
	row.status_label = _make_label("waiting", BODY_FONT_SIZE, TEXT_COLOR)
	row.status_label.custom_minimum_size = Vector2(ROW_STATUS_WIDTH, 0.0)
	row.status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(row.status_label)
	return row


## A rounded, flat panel style of one colour.
func _make_panel_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.set_content_margin_all(PANEL_CONTENT_MARGIN)
	return style


## A Label of one size and colour.
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
