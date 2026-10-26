extends SceneTree
## The Pick a side screen's evidence (Story 048), driven by real key and pad events, in a runner of its own like the map
## choice's. CHECK lines and one RESULT line, in the harness's format:
##  L1 the screen: the project opens on it; nobody has joined; the line says how to join.
##  L2 joining by moving: A (Keyboard 1) joins Orange, pad 0's stick right joins Teal, Right (Keyboard 2) joins Teal, pad 1's
##     D-pad left joins Orange; a fifth device (pad 2) is refused.
##  L3 moving and leaving: Keyboard 2's Left steps it to the middle and on to Orange, Right twice back to Teal; pad 1's B, not
##     ready, takes it out, and its D-pad left brings it back to Orange.
##  L4 ready and start: A, C, Slash and A (the shipped Fire keys, Story 060) make all four ready; the map choice opens with the lineup Keyboard 1, pad 1
##     (Orange) and pad 0, Keyboard 2 (Teal).
##  L5 into the match: Space on the map choice starts it with four Players, four views in two columns, the Teams [0, 0, 1, 1].
##  L6 one against one: a fresh screen, A and Right (the two keyboard halves) and their confirms start a match of two Players
##     in the two views of before.
## With --frames=<folder> (windowed only) it saves the screen at each step.
## Implements: production/epics/wasteland-fire/story-048-four-players.md AC-1, AC-2.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --path . -s res://tools/evidence/lobby/pick_side_check.gd

const PICK_SCENE: String = "res://src/ui/lobby/pick_side.tscn"
const SETTLE_FRAMES: int = 10
## How long past the screen's start delay the runner waits for the map choice.
const START_MARGIN_SECONDS: float = 0.5

var _checks: int = 0
var _failed: int = 0
var _frames: String = ""


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_frames = arg.trim_prefix("--frames=")
	_run.call_deferred()


func _run() -> void:
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var pick: PickSide = await _open()
	var problems: PackedStringArray = PackedStringArray()
	_need(problems, main == PICK_SCENE, "the project opens on %s" % main)
	_need(problems, _counts(pick) == [0, 0, 0], "lists %s" % [_counts(pick)])
	_check("L1_screen", problems, "main scene %s; lists %s; line '%s'" % [main, _counts(pick), pick.status_label.text])
	await _save("pick-01-empty.png")

	problems = PackedStringArray()
	await _key(KEY_A)
	await _pad_axis(0, 1.0)
	await _key(KEY_RIGHT)
	await _pad_button(1, JOY_BUTTON_DPAD_LEFT)
	await _pad_button(2, JOY_BUTTON_DPAD_LEFT)
	_need(problems, _counts(pick) == [2, 0, 2], "lists %s" % [_counts(pick)])
	_check("L2_join_by_moving", problems, "after A, pad 0 stick right, Right, pad 1 D-pad left, pad 2 D-pad left: lists %s (Orange, middle, Teal)" % [_counts(pick)])
	await _save("pick-02-four-joined.png")

	problems = PackedStringArray()
	var trail: Array = []
	await _key(KEY_LEFT)
	trail.append(_counts(pick))
	await _key(KEY_LEFT)
	trail.append(_counts(pick))
	await _key(KEY_RIGHT)
	await _key(KEY_RIGHT)
	trail.append(_counts(pick))
	await _pad_button(1, JOY_BUTTON_B)
	trail.append(_counts(pick))
	await _pad_button(1, JOY_BUTTON_DPAD_LEFT)
	trail.append(_counts(pick))
	_need(problems, trail == [[2, 1, 1], [3, 0, 1], [2, 0, 2], [1, 0, 2], [2, 0, 2]], "lists %s" % [trail])
	_check("L3_move_and_leave", problems, "Left, Left, Right Right, pad 1 B, pad 1 D-pad left: %s" % [trail])

	problems = PackedStringArray()
	await _key(KEY_C)
	await _key(KEY_SLASH)
	await _pad_button(0, JOY_BUTTON_A)
	await _save("pick-03-three-ready.png")
	await _pad_button(1, JOY_BUTTON_A)
	await create_timer(pick.start_delay_seconds + START_MARGIN_SECONDS).timeout
	await _wait(SETTLE_FRAMES)
	var choice: MapChoice = current_scene as MapChoice
	var devices: Array[int] = []
	var teams: Array[int] = []
	if choice != null and choice.lineup != null:
		devices = choice.lineup.devices
		teams = choice.lineup.teams
	_need(problems, choice != null and devices == [-2, 1, 0, -3] and teams == [0, 0, 1, 1], "scene %s, lineup %s %s" % [current_scene, devices, teams])
	_check("L4_ready_and_start", problems, "all four ready: the map choice is the scene %s with the lineup devices %s, Teams %s" % [choice != null, devices, teams])
	await _save("pick-04-map-choice.png")

	problems = PackedStringArray()
	await _key(KEY_SPACE)
	await _wait(SETTLE_FRAMES)
	var split: SplitScreen = current_scene as SplitScreen
	var units: int = split.all_units().size() if split != null else 0
	var columns: bool = split != null and split.get_node_or_null("Views/OrangeColumn") != null and split.get_node_or_null("Views/TealColumn") != null
	var split_teams: Array[int] = []
	if split != null:
		for player: int in units:
			split_teams.append(split.match_controller.team_of(player))
	_need(problems, units == 4 and columns and split_teams == [0, 0, 1, 1], "Units %d, columns %s, Teams %s" % [units, columns, split_teams])
	_check("L5_into_the_match", problems, "Space on the map choice: %d Players, two columns %s, Teams %s" % [units, columns, split_teams])
	await _wait(60)
	await _save("pick-05-match-four-players.png")
	if split != null:
		split.queue_free()
	await _wait(SETTLE_FRAMES)

	problems = PackedStringArray()
	pick = await _open()
	await _key(KEY_A)
	await _key(KEY_RIGHT)
	await _key(KEY_C)
	await _key(KEY_SLASH)
	await create_timer(pick.start_delay_seconds + START_MARGIN_SECONDS).timeout
	await _wait(SETTLE_FRAMES)
	choice = current_scene as MapChoice
	if choice != null:
		await _key(KEY_SPACE)
		await _wait(SETTLE_FRAMES)
	split = current_scene as SplitScreen
	var two: int = split.all_units().size() if split != null else 0
	var no_columns: bool = split != null and split.get_node_or_null("Views/OrangeColumn") == null and split.get_node_or_null("Views/Player2View") != null
	_need(problems, two == 2 and no_columns, "Units %d, views of before %s" % [two, no_columns])
	_check("L6_one_against_one", problems, "the two keyboard halves: %d Players, the two views of before %s" % [two, no_columns])
	print("RESULT pick_side %s checks=%d failed=%d" % ["ok" if _failed == 0 else "fail", _checks, _failed])
	quit(0 if _failed == 0 else 1)


func _counts(pick: PickSide) -> Array[int]:
	return [pick.orange_list.get_child_count(), pick.middle_list.get_child_count(), pick.teal_list.get_child_count()]


func _open() -> PickSide:
	var pick: PickSide = (load(PICK_SCENE) as PackedScene).instantiate() as PickSide
	var own: ControlsSettings = pick.controls_settings.duplicate() as ControlsSettings
	own.save_path = "user://evidence_no_controls.cfg"
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


func _pad_axis(device: int, value: float) -> void:
	for amount: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = device
		event.axis = JOY_AXIS_LEFT_X
		event.axis_value = amount
		Input.parse_input_event(event)
		await _wait(2)


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
	print("CHECK pick_side %s %s %s%s" % [check_name, "PASS" if problems.is_empty() else "FAIL", detail, "" if problems.is_empty() else " | PROBLEMS: " + "; ".join(problems)])
