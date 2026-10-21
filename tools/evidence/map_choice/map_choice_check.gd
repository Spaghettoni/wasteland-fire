extends SceneTree
## The map choice's evidence (Story 038): the launch screen as the game opens on it, driven by real key and pad events.
## A runner of its own, because the split screen harness instances the match itself. CHECK lines and one RESULT line, in the
## harness's format:
##  K1 the screen: the project opens on it; it shows a card for Map 01 and one for Map 02, each with its picture, the cursor
##     on the first.
##  K2 choosing: D and Right move the cursor right, A and Left left, wrapping round; a pad's D-pad and stick move it too.
##  K3 starting on the release: Space down leaves the screen up; Space up starts the match on the Map under the cursor (Map 02)
##     as the current scene and frees the screen.
##  K4 nothing carried over: in the match's first second both Players are still choosing, so the Space that started it did not
##     also confirm Player 1's Unit.
##  K5 the other Map: Enter on a fresh screen with the cursor on the first card starts Map 01.
## With --frames=<folder> (windowed only) it also saves the screen with each card chosen and the start of the match on Map 02.
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-1.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --path . -s res://tools/evidence/map_choice/map_choice_check.gd

const CHOICE_SCENE: String = "res://src/ui/map_choice/map_choice.tscn"
const MAP_PATHS: Array[String] = ["res://src/gameplay/maps/map_01/map_01.tscn", "res://src/gameplay/maps/map_02/map_02.tscn"]
const NAMES: Array[String] = ["Map 01", "Map 02"]
const SETTLE_FRAMES: int = 10
const MATCH_FRAMES: int = 60

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
	var choice: MapChoice = await _open()
	var problems: PackedStringArray = PackedStringArray()
	_need(problems, main == CHOICE_SCENE, "the project opens on %s" % main)
	var cards: Array[Node] = choice.cards_row.get_children()
	_need(problems, cards.size() == NAMES.size(), "%d cards" % cards.size())
	for index: int in choice.maps.size():
		var entry: MapEntry = choice.maps[index]
		_need(problems, entry.display_name == NAMES[index] and entry.scene.resource_path == MAP_PATHS[index] and entry.preview != null, "card %d: %s, %s, picture %s" % [index, entry.display_name, entry.scene.resource_path, entry.preview != null])
	_need(problems, choice.cursor == 0, "the cursor starts on card %d" % choice.cursor)
	_check("K1_screen", problems, "main scene %s; cards %s; cursor %d" % [main, [choice.maps[0].display_name, choice.maps[1].display_name], choice.cursor])
	await _save("choice-01-map-choice-map-01.png")

	problems = PackedStringArray()
	var trail: Array[int] = []
	for step: Array in [[KEY_D, 1], [KEY_RIGHT, 0], [KEY_A, 1], [KEY_LEFT, 0]]:
		await _key(step[0], true)
		await _key(step[0], false)
		trail.append(choice.cursor)
		_need(problems, choice.cursor == step[1], "after %s the cursor is on %d" % [OS.get_keycode_string(step[0]), choice.cursor])
	await _pad_button(JOY_BUTTON_DPAD_RIGHT)
	trail.append(choice.cursor)
	_need(problems, choice.cursor == 1, "after the D-pad right the cursor is on %d" % choice.cursor)
	await _pad_axis(-1.0)
	trail.append(choice.cursor)
	_need(problems, choice.cursor == 0, "after the stick left the cursor is on %d" % choice.cursor)
	await _pad_axis(1.0)
	trail.append(choice.cursor)
	_check("K2_choosing", problems, "D, Right, A, Left, D-pad right, stick left, stick right: %s" % [trail])
	await _save("choice-02-map-choice-map-02.png")

	problems = PackedStringArray()
	await _key(KEY_SPACE, true)
	var still_up: bool = is_instance_valid(choice) and choice.is_inside_tree() and not current_scene is SplitScreen
	await _key(KEY_SPACE, false)
	await _wait(SETTLE_FRAMES)
	var split: SplitScreen = current_scene as SplitScreen
	_need(problems, still_up, "the screen left on Space down")
	_need(problems, split != null and split.field != null and split.field.scene_file_path == MAP_PATHS[1], "the current scene is %s" % [current_scene])
	_need(problems, not is_instance_valid(choice), "the screen is still there")
	_check("K3_start_on_release", problems, "up after Space down %s; the match plays %s" % [still_up, split.field.scene_file_path if split != null else "nothing"])

	problems = PackedStringArray()
	await _wait(MATCH_FRAMES)
	var choosing: Array = [false, false]
	if split != null:
		choosing = [split.match_controller.is_choosing(0), split.match_controller.is_choosing(1)]
	_need(problems, choosing == [true, true], "choosing after a second: %s" % [choosing])
	_check("K4_nothing_carried", problems, "both Players choosing a second in: %s" % [choosing])
	await _save("choice-03-match-on-map-02.png")
	if split != null:
		split.queue_free()
	await _wait(SETTLE_FRAMES)

	problems = PackedStringArray()
	choice = await _open()
	await _key(KEY_ENTER, true)
	await _key(KEY_ENTER, false)
	await _wait(SETTLE_FRAMES)
	split = current_scene as SplitScreen
	_need(problems, split != null and split.field.scene_file_path == MAP_PATHS[0], "Enter started %s" % [current_scene])
	_check("K5_other_map", problems, "Enter on the first card plays %s" % (split.field.scene_file_path if split != null else "nothing"))
	print("RESULT map_choice %s checks=%d failed=%d" % ["ok" if _failed == 0 else "fail", _checks, _failed])
	quit(0 if _failed == 0 else 1)


func _open() -> MapChoice:
	var choice: MapChoice = (load(CHOICE_SCENE) as PackedScene).instantiate() as MapChoice
	root.add_child(choice)
	current_scene = choice
	await _wait(SETTLE_FRAMES)
	return choice


func _key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	await _wait(2)


func _pad_button(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = 0
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _wait(2)


func _pad_axis(value: float) -> void:
	for amount: float in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.device = 0
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
	print("CHECK map_choice %s %s %s%s" % [check_name, "PASS" if problems.is_empty() else "FAIL", detail, "" if problems.is_empty() else " | PROBLEMS: " + "; ".join(problems)])
