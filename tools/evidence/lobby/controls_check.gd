extends SceneTree
## The Controls screen's evidence (Story 060), driven by real key and pad events on the Pick a side screen, in a runner of its
## own like pick_side_check.gd. It keeps its controls in a file of its own (FILE), removed before and after. CHECK lines and
## one RESULT line, in the harness's format:
##  C1 the screen: C on Pick a side opens it; the table holds the defaults (Fire: Space, Period, A, RT; Throttle: W, Up,
##     Stick up, nothing in the second pad column).
##  C2 a key: Down four times and Enter choose Fire for Keyboard 1; F takes it.
##  C3 a key in use: Fire for Keyboard 1, then W: Fire takes W and Throttle takes Fire's old key, F; then Up, Keyboard 2's
##     Throttle: Fire for Keyboard 1 takes Up and Keyboard 2's Throttle takes W, so no key is on two actions.
##  C4 the pad: Fire's first pad slot, then X: Fire takes X. Secondary's first pad slot, then RT pulled: Secondary takes RT
##     and Fire's second slot, which had RT, takes LT. Menu is refused (kept for the menus); Delete empties Fire's second slot;
##     Delete on Throttle's only pad input is refused.
##  C5 kept: the file holds it; controls read fresh from the file are the same.
##  C6 Default: the Default button puts every control back, in the table and in the file.
##  C7 into the match: Fire for Keyboard 1 set to F and Fire's pad input to X again, Escape closes the screen; Pick a side
##     names the new keys; Keyboard 1 joins Orange and pad 0 Teal, F and pad A make them ready, Space starts the match: Player
##     1's Fire takes F (not Space) and, pad 0 connected, Player 2's Fire takes the pad's X (not A).
## With --frames=<folder> (windowed only) it saves the screens.
## Implements: production/epics/wasteland-fire/story-060-controls-settings.md AC-1 to AC-6.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --path . -s res://tools/evidence/lobby/controls_check.gd

const PICK_SCENE: String = "res://src/ui/lobby/pick_side.tscn"
const FILE: String = "user://evidence_controls.cfg"
const SETTLE_FRAMES: int = 10
const START_MARGIN_SECONDS: float = 0.5
## The rows of the table (ControlsSettings.actions) and its columns.
const THROTTLE: int = 0
const FIRE: int = 4
const SECONDARY: int = 6
const KB1: int = 0
const KB2: int = 1
const PAD: int = 2
const PAD_ALSO: int = 3

var _checks: int = 0
var _failed: int = 0
var _frames: String = ""


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = arg.trim_prefix("--frames=")
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	var pick: PickSide = await _open()
	var problems: PackedStringArray = PackedStringArray()
	await _key(KEY_C)
	var screen: ControlsScreen = pick.controls_screen()
	var opened: bool = screen != null and screen.is_inside_tree()
	_need(problems, opened, "C did not open the Controls screen")
	if not opened:
		_check("C1_the_screen", problems, "no screen")
		_finish()
		return
	await _wait(SETTLE_FRAMES)
	var fire_row: Array[String] = _row(screen, FIRE)
	var throttle_row: Array[String] = _row(screen, THROTTLE)
	_need(problems, fire_row == ["Space", "Period", "A", "RT"], "Fire %s" % [fire_row])
	_need(problems, throttle_row == ["W", "Up", "Stick up", "—"], "Throttle %s" % [throttle_row])
	_check("C1_the_screen", problems, "C opened it; Fire %s; Throttle %s; status '%s'" % [fire_row, throttle_row, screen.status_text()])
	await _save("controls-01-defaults.png")

	problems = PackedStringArray()
	for _step: int in FIRE:
		await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	var listening: bool = screen.is_listening()
	await _save("controls-02-listening.png")
	await _key(KEY_F)
	await _calm()
	_need(problems, listening, "Enter on Fire did not start listening")
	_need(problems, screen.cell_text(FIRE, KB1) == "F", "Fire for Keyboard 1 shows %s" % screen.cell_text(FIRE, KB1))
	_check("C2_a_key", problems, "Down x4, Enter: listening %s; F: Fire %s; status '%s'" % [listening, _row(screen, FIRE), screen.status_text()])

	problems = PackedStringArray()
	await _key(KEY_ENTER)
	await _key(KEY_W)
	await _calm()
	var after_w: Array = [screen.cell_text(FIRE, KB1), screen.cell_text(THROTTLE, KB1)]
	var moved_line: String = screen.status_text()
	await _key(KEY_ENTER)
	await _key(KEY_UP)
	await _calm()
	var after_up: Array = [screen.cell_text(FIRE, KB1), screen.cell_text(THROTTLE, KB1), screen.cell_text(THROTTLE, KB2)]
	_need(problems, after_w == ["W", "F"], "after W: Fire, Throttle %s" % [after_w])
	_need(problems, after_up == ["Up", "F", "W"], "after Up: Fire, Throttle, Keyboard 2's Throttle %s" % [after_up])
	_check("C3_a_key_in_use", problems, "W: Fire, Throttle %s ('%s'); Up: Fire, Throttle, Keyboard 2's Throttle %s ('%s')" % [after_w, moved_line, after_up, screen.status_text()])
	await _save("controls-03-moved.png")

	problems = PackedStringArray()
	screen.listen(FIRE, PAD)
	await _pad_button(0, JOY_BUTTON_X)
	await _calm()
	var fire_x: Array[String] = _row(screen, FIRE)
	screen.listen(SECONDARY, PAD)
	await _calm()
	await _pad_axis(0, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	var secondary_rt: Array[String] = _row(screen, SECONDARY)
	var fire_lt: Array[String] = _row(screen, FIRE)
	await _calm()
	screen.listen(FIRE, PAD)
	await _pad_button(0, JOY_BUTTON_START)
	var menu_line: String = screen.status_text()
	var after_menu: Array[String] = _row(screen, FIRE)
	await _calm()
	screen.listen(FIRE, PAD_ALSO)
	await _key(KEY_DELETE)
	var emptied: Array[String] = _row(screen, FIRE)
	await _calm()
	screen.listen(THROTTLE, PAD)
	await _key(KEY_DELETE)
	var kept: Array[String] = _row(screen, THROTTLE)
	var kept_line: String = screen.status_text()
	_need(problems, fire_x[PAD] == "X", "Fire after X %s" % [fire_x])
	_need(problems, secondary_rt[PAD] == "RT" and fire_lt[PAD_ALSO] == "LT", "after RT: Secondary %s, Fire %s" % [secondary_rt, fire_lt])
	_need(problems, after_menu == fire_lt, "Menu changed Fire to %s" % [after_menu])
	_need(problems, emptied[PAD_ALSO] == "—" and emptied[PAD] == "X", "after Delete Fire %s" % [emptied])
	_need(problems, kept[PAD] == "Stick up", "Throttle after Delete %s" % [kept])
	_check("C4_the_pad", problems, "X: Fire %s; RT: Secondary %s, Fire %s; Menu: '%s'; Delete: Fire %s; Delete on Throttle: %s '%s'" % [
		fire_x, secondary_rt, fire_lt, menu_line, emptied, kept, kept_line])
	await _save("controls-04-pad.png")

	problems = PackedStringArray()
	var fresh: ControlBindings = ControlBindings.create(pick.controls_settings, pick.pad_layout)
	fresh.path = FILE
	var read: bool = fresh.load_saved()
	var fresh_fire: String = ControlBindings.key_name(fresh.key_of("p1_", "fire"))
	var fresh_pad: Array = fresh.pad_of("fire").map(func(binding: PadBinding) -> String: return binding.display_name)
	var fresh_secondary: Array = fresh.pad_of("lay_mine").map(func(binding: PadBinding) -> String: return binding.display_name)
	_need(problems, FileAccess.file_exists(FILE) and read, "the file %s was not written or read" % FILE)
	_need(problems, fresh_fire == "Up" and fresh_pad == ["X"] and fresh_secondary == ["RT"], "read back: Fire %s, pad %s, Secondary %s" % [fresh_fire, fresh_pad, fresh_secondary])
	_check("C5_kept", problems, "the file read fresh: Keyboard 1's Fire %s, Fire's pad %s, Secondary's pad %s" % [fresh_fire, fresh_pad, fresh_secondary])

	problems = PackedStringArray()
	screen.default_button.pressed.emit()
	await _wait(SETTLE_FRAMES)
	var back_fire: Array[String] = _row(screen, FIRE)
	var back_throttle: Array[String] = _row(screen, THROTTLE)
	var again: ControlBindings = ControlBindings.create(pick.controls_settings, pick.pad_layout)
	again.path = FILE
	again.load_saved()
	_need(problems, back_fire == ["Space", "Period", "A", "RT"] and back_throttle == ["W", "Up", "Stick up", "—"], "after Default Fire %s, Throttle %s" % [back_fire, back_throttle])
	_need(problems, again.is_default(), "the file after Default does not hold the defaults")
	_check("C6_default", problems, "Default: Fire %s, Throttle %s; the file holds the defaults %s; '%s'" % [back_fire, back_throttle, again.is_default(), screen.status_text()])
	await _save("controls-05-default.png")

	problems = PackedStringArray()
	await _calm()
	screen.listen(FIRE, KB1)
	await _key(KEY_F)
	await _calm()
	screen.listen(FIRE, PAD)
	await _pad_button(0, JOY_BUTTON_X)
	await _calm()
	await _key(KEY_ESCAPE)
	await _wait(SETTLE_FRAMES)
	var closed: bool = pick.controls_screen() == null
	await _key(KEY_A)
	await _pad_axis(0, JOY_AXIS_LEFT_X, 1.0)
	var line_ready: String = pick.status_label.text
	await _save("controls-06-pick-side.png")
	await _key(KEY_F)
	await _pad_button(0, JOY_BUTTON_A)
	await create_timer(pick.start_delay_seconds + START_MARGIN_SECONDS).timeout
	await _wait(SETTLE_FRAMES)
	if current_scene is MapChoice:
		await _key(KEY_SPACE)
		await _wait(SETTLE_FRAMES)
	var split: SplitScreen = current_scene as SplitScreen
	var p1_fire: Array[String] = []
	var p2_fire: Array[String] = []
	if split != null:
		var pads: PadAssignment = split.get_node_or_null("PadAssignment") as PadAssignment
		if pads != null:
			pads.connect_pad(0)
		p1_fire = _events(&"p1_fire")
		p2_fire = _events(&"p2_fire")
	_need(problems, closed, "Escape did not close the screen")
	_need(problems, line_ready.contains("F"), "Pick a side's line '%s' does not name F" % line_ready)
	_need(problems, split != null, "the match did not start (scene %s)" % current_scene)
	_need(problems, p1_fire.has("key F") and not p1_fire.has("key Space"), "Player 1's Fire %s" % [p1_fire])
	_need(problems, p2_fire.has("pad 2") and not p2_fire.has("pad 0"), "Player 2's Fire %s" % [p2_fire])
	_check("C7_into_the_match", problems, "closed %s; Pick a side: '%s'; in the match Player 1's Fire %s, Player 2's (pad 0) %s" % [closed, line_ready, p1_fire, p2_fire])
	if split != null:
		split.queue_free()
	_finish()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	print("RESULT controls %s checks=%d failed=%d" % ["ok" if _failed == 0 else "fail", _checks, _failed])
	quit(0 if _failed == 0 else 1)


## The texts of a row's cells, in column order.
func _row(screen: ControlsScreen, row: int) -> Array[String]:
	var out: Array[String] = []
	for column: int in screen.column_count():
		out.append(screen.cell_text(row, column))
	return out


## The action's events in short: "key <name>" or "pad <button>".
func _events(action: StringName) -> Array[String]:
	var out: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			out.append("key " + ControlBindings.key_name(event as InputEventKey))
		elif event is InputEventJoypadButton:
			out.append("pad %d" % (event as InputEventJoypadButton).button_index)
	return out


func _open() -> PickSide:
	var pick: PickSide = (load(PICK_SCENE) as PackedScene).instantiate() as PickSide
	var own: ControlsSettings = pick.controls_settings.duplicate() as ControlsSettings
	own.save_path = FILE
	pick.controls_settings = own
	root.add_child(pick)
	current_scene = pick
	await _wait(SETTLE_FRAMES)
	return pick


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(2)


func _pad_button(device: int, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = device
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(2)


func _pad_axis(device: int, axis: JoyAxis, value: float) -> void:
	for amount: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = axis
		event.axis_value = amount
		Input.parse_input_event(event)
		await _wait(2)


## Waits past the screen's quiet time after a press is taken.
func _calm() -> void:
	await create_timer(0.45).timeout


func _wait(frames: int) -> void:
	for _frame: int in frames:
		await process_frame


func _save(file: String) -> void:
	if _frames.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path: String = _frames.path_join(file)
	root.get_texture().get_image().save_png(path)
	print("FRAME %s" % path)


func _need(problems: PackedStringArray, holds: bool, problem: String) -> void:
	if not holds:
		problems.append(problem)


func _check(check_name: String, problems: PackedStringArray, detail: String) -> void:
	_checks += 1
	if not problems.is_empty():
		_failed += 1
	print("CHECK controls %s %s %s%s" % [check_name, "PASS" if problems.is_empty() else "FAIL", detail, "" if problems.is_empty() else " | PROBLEMS: " + "; ".join(problems)])
