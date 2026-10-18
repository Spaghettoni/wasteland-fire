extends RefCounted
## Scenario pads of the split screen evidence harness (split_screen_harness.gd): Xbox controllers
## (Story 032), on Map 01 with the shipped data, every pad input a real InputEventJoypadButton or
## InputEventJoypadMotion pushed through Input.parse_input_event with a pad's device ID. A headless
## run has no pads, so the scenario connects and disconnects them through the scene's
## PadAssignment (connect_pad(), disconnect_pad()), the calls Input.joy_connection_changed makes.
## The Players choose their first Unit with the pads (OWN_CHOICE). CHECK lines, every number
## measured:
##  P1 keyboard first: before any pad, every hint names the keys exactly as before, and no action
##     carries a pad event (AC-6, AC-8).
##  P2 the assignment: pad 0 goes to Player 1, pad 1 to Player 2, a third pad and a pad already
##     assigned go to nobody; each Player's actions carry the layout's events on that Player's
##     device and still their keyboard keys; the pad's actions take the layout's dead zone (AC-1,
##     AC-3, AC-7).
##  P3 one pad, one Player: every input of the layout, pressed on pad 0, presses its action of
##     Player 1 and no action of Player 2, and the reverse on pad 1; the shared restart action is
##     pressed by either (AC-2, AC-3).
##  P4 the hints: with pad 0 alone Player 1's choice hint and Self-destruct key name the pad's
##     inputs and Player 2's still the keys; with both, both name the pad; the restart line names
##     the key and the pad's button (AC-6).
##  P5 the choice: a push of the stick moves the Player's cursor one type, a stick held for half a
##     second still one, the D-pad one, and the other Player's cursor never; A confirms, and both
##     Units come into play (AC-4).
##  P6 analog drive: a full right trigger on pad 0 drives Player 1's Unit forward and leaves Player
##     2's where it stands; half a trigger gives the strength the dead zone leaves (recorded); the
##     stick on pad 1 turns Player 2's Unit and not Player 1's (AC-2, AC-3).
##  P7 A, X, Y, View: A fires Player 1's Weapon (its ammo drops) and not Player 2's, Y steps Player
##     1's camera and not Player 2's, X is read by Player 1's Mine input (a Motorbike lays none: the
##     action alone is checked), View destroys Player 1's Unit (a Self-destruct) and not Player 2's
##     (AC-2, AC-3).
##  P8 a pad that goes: pad 0 disconnected with its trigger held leaves no action held and the Unit
##     slows; Player 1's notice says "Controller disconnected" and the hints name the keys again; a
##     keyboard key held through the disconnect stays held; reconnected, pad 0 goes back to Player 1
##     and the notice says "Controller connected" (AC-5).
##  P9 the clean-up: when a PadAssignment leaves the tree, the Input Map is what project.godot made
##     it (no pad event, the dead zones back) (AC-8).
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-1 to AC-8.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn \
##     -- --scenario=pads

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, key presses, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The Players choose their first Unit here, with the pads.
const OWN_CHOICE: bool = true
## Keeps the PlayerNotice lines, which say when a pad comes or goes (the runner frees them for a
## scenario that declares neither TURRETS nor MINES). The Motorbike lays no Mine, so nothing else
## of the Mines shows.
const MINES: bool = true
## The layout the scene's PadAssignment gives every pad.
const LAYOUT_PATH: String = "res://src/gameplay/input/data/pad_layout.tres"
## The pads' device IDs in this run: Player 1's, Player 2's, and a third that belongs to nobody.
const PAD_1: int = 0
const PAD_2: int = 1
const PAD_3: int = 2
## The Players' prefixes, in Player order.
const PREFIXES: Array[StringName] = [&"p1_", &"p2_"]
## The hints as they read before Story 032, with the keys of project.godot.
const KEY_CHOICE_HINTS: Array[String] = ["A / D to choose, Space to confirm", "Left / Right to choose, Period to confirm"]
const KEY_DESTRUCT_NAMES: Array[String] = ["Tab", "Enter"]
## What the hints read for a Player with a pad (pad_layout.tres, unit_choice.tscn).
const PAD_CHOICE_HINT: String = "Stick left / Stick right to choose, A to confirm"
const PAD_DESTRUCT_NAME: String = "View"
const KEY_RESTART_LINE: String = "Press R to play again"
const PAD_RESTART_LINE: String = "Press R or Menu to play again"
## The notices (player_notice.tscn).
const NOTICE_CONNECTED: String = "Controller connected"
const NOTICE_DISCONNECTED: String = "Controller disconnected"
## A trigger pulled halfway.
const HALF: float = 0.5
## Ticks a stick or trigger is held.
const HOLD_TICKS: int = 30
## Ticks the throttle is held to drive.
const DRIVE_TICKS: int = 60
## Ticks waited for the Units to come into play after both chose.
const SPAWN_WAIT_TICKS: int = 240
## A Unit that did not move moved less than this, metres.
const STILL_METRES: float = 0.01
## A Unit that turned turned more than this, radians.
const TURNED_RADIANS: float = 0.05
## A strength compared with what the dead zone predicts.
const STRENGTH_TOLERANCE: float = 0.001
## Player 1's throttle key (project.godot p1_throttle).
const KEY_THROTTLE_1: Key = KEY_W

var _h: Harness
var _kit: Kit
var _pads: PadAssignment
var _layout: PadLayout
var _controller: MatchController
var _units: Array[Unit] = []
var _choices: Array[PlayerChoiceInput] = []
var _choice_hints: Array[Label] = []
var _destruct_hints: Array[SelfDestructHint] = []
var _round_over: RoundOverScreen
var _notices: Array[PlayerNotice] = []
var _weapons: Array[Weapon] = []
var _camera_inputs: Array[PlayerCameraInput] = []
var _log: ErrorCount = ErrorCount.new()


## Counts the engine's errors and warnings while the scenario runs.
class ErrorCount extends Logger:
	var errors: int = 0
	var warnings: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
		else:
			errors += 1


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	OS.add_logger(_log)
	_collect()
	await _kit.advance(2)
	_check_keyboard_first()
	_check_assignment()
	_check_hints()
	await _check_choice()
	await _check_drive()
	await _check_buttons()
	await _check_disconnect()
	# Last before the clean-up: a tap read on its frame still counts as a press in Godot 4.7, so
	# the presses of every input confirm choices and fire; nothing after reads the Round.
	await _check_isolation()
	await _check_cleanup()
	OS.remove_logger(_log)
	_h.finish("pads=%d errors=%d warnings=%d" % [2, _log.errors, _log.warnings])


func _collect() -> void:
	var split: SplitScreen = _h.split
	_pads = split.get_node("%PadAssignment") as PadAssignment
	_layout = load(LAYOUT_PATH) as PadLayout
	_controller = split.match_controller
	_units = [split.player_1_unit, split.player_2_unit]
	_weapons = [split.player_1_weapon, split.player_2_weapon]
	for n: int in [1, 2]:
		_choices.append(split.get_node("%%Player%dChoiceInput" % n) as PlayerChoiceInput)
		var view: Node = split.get_node("Views/Player%dView/SubViewport" % n)
		_choice_hints.append(view.get_node("Player%dUnitChoice" % n).get_node("%HintLabel") as Label)
		_destruct_hints.append(view.get_node("Player%dSelfDestructHint" % n) as SelfDestructHint)
		_notices.append(view.get_node("Player%dNotice" % n) as PlayerNotice)
		_camera_inputs.append(split.get_node("World/Player%dCameraInput" % n) as PlayerCameraInput)
	_round_over = split.get_node("Views/Player1View/SubViewport/Player1RoundOver") as RoundOverScreen


## The pad events on an action: [device, event text] pairs.
func _pad_events(action: StringName) -> Array:
	var found: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			found.append([event.device, event.as_text()])
	return found


func _key_events(action: StringName) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			count += 1
	return count


## The pad events on the game's actions: every action but the engine's own ui_ actions, which
## project settings bind to pads by default.
func _all_pad_events() -> int:
	var count: int = 0
	for action: StringName in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			count += _pad_events(action).size()
	return count


func _check_keyboard_first() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var seen: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var hint: String = _choice_hints[player].text
		var key: String = _destruct_hints[player]._key_name()
		seen.append("p%d choice '%s', destruct '%s'" % [player + 1, hint, key])
		_kit.need(problems, hint == KEY_CHOICE_HINTS[player], "p%d choice hint is '%s'" % [player + 1, hint])
		_kit.need(problems, key == KEY_DESTRUCT_NAMES[player], "p%d destruct key is '%s'" % [player + 1, key])
	var restart: String = _round_over._restart_text()
	seen.append("restart '%s'" % restart)
	_kit.need(problems, restart == KEY_RESTART_LINE, "restart line is '%s'" % restart)
	_kit.need(problems, _all_pad_events() == 0, "%d pad events in the Input Map" % _all_pad_events())
	_kit.need(problems, _pads.pad_of(0) == PadAssignment.NO_PAD and _pads.pad_of(1) == PadAssignment.NO_PAD, "a Player has a pad")
	_kit.verdict("P1_keyboard_first", problems, "; ".join(seen) + "; pad events in the Input Map: %d" % _all_pad_events())


func _check_assignment() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var first: int = _pads.connect_pad(PAD_1)
	var hints_p2_keys: String = _choice_hints[1].text
	# Pad 0 again while Player 2 still has no pad: it must not take Player 2's place.
	var again: int = _pads.connect_pad(PAD_1)
	var second: int = _pads.connect_pad(PAD_2)
	var third: int = _pads.connect_pad(PAD_3)
	_kit.need(problems, first == 0, "pad %d went to %d" % [PAD_1, first])
	_kit.need(problems, second == 1, "pad %d went to %d" % [PAD_2, second])
	_kit.need(problems, third == PadAssignment.NO_PAD, "pad %d went to %d" % [PAD_3, third])
	_kit.need(problems, again == PadAssignment.NO_PAD, "pad %d assigned twice (%d)" % [PAD_1, again])
	var lines: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var device: int = [PAD_1, PAD_2][player]
		for binding: PadBinding in _layout.bindings:
			if binding.shared:
				continue
			var action: StringName = binding.action_for(PREFIXES[player])
			var events: Array = _pad_events(action)
			var devices: Array = events.map(func(pair: Array) -> int: return pair[0])
			_kit.need(problems, devices.has(device) and devices.count(device) == devices.size(),
				"%s carries pad events of devices %s" % [action, devices])
			_kit.need(problems, _key_events(action) >= 1, "%s lost its keyboard key" % action)
			_kit.need(problems, is_equal_approx(InputMap.action_get_deadzone(action), _layout.deadzone),
				"%s dead zone %s" % [action, InputMap.action_get_deadzone(action)])
		var throttle: StringName = StringName(String(PREFIXES[player]) + "throttle")
		lines.append("%s: %s + %d key" % [throttle, _pad_events(throttle), _key_events(throttle)])
	var restart_events: Array = _pad_events(RoundRestartInput.ACTION_RESTART)
	lines.append("round_restart: %s" % [restart_events])
	_kit.need(problems, restart_events.size() == 2, "round_restart carries %d pad events" % restart_events.size())
	_kit.need(problems, not _pads.button_name(0, &"fire").is_empty(), "Player 1 has no pad button name")
	_kit.verdict("P2_assignment", problems, "connect %d -> %d, %d -> %d, %d -> %d, %d again (Player 2 still free) -> %d | %s | p2 choice hint while only p1 had a pad: '%s'" % [
		PAD_1, first, PAD_2, second, PAD_3, third, PAD_1, again, " | ".join(lines), hints_p2_keys])


## Presses one binding's input on a pad: a button down, or the axis at full in its direction.
func _push(device: int, binding: PadBinding, pressed: bool, amount: float = 1.0) -> void:
	if binding.kind == PadBinding.Kind.BUTTON:
		var button := InputEventJoypadButton.new()
		button.device = device
		button.button_index = binding.button
		button.pressed = pressed
		button.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(button)
	else:
		_axis(device, binding.axis, binding.axis_direction * amount if pressed else 0.0)


func _axis(device: int, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = device
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _button(device: int, button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _binding(suffix: StringName, kind: PadBinding.Kind) -> PadBinding:
	for binding: PadBinding in _layout.bindings:
		if binding.action_suffix == suffix and binding.kind == kind:
			return binding
	return null


func _check_isolation() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var tested: int = 0
	for player: int in 2:
		var device: int = [PAD_1, PAD_2][player]
		for binding: PadBinding in _layout.bindings:
			_push(device, binding, true)
			var own: StringName = binding.action_for(PREFIXES[player])
			var other: StringName = binding.action_for(PREFIXES[1 - player])
			_kit.need(problems, Input.is_action_pressed(own), "%s on pad %d does not press %s" % [binding.display_name, device, own])
			if not binding.shared:
				_kit.need(problems, not Input.is_action_pressed(other), "%s on pad %d presses %s" % [binding.display_name, device, other])
			_push(device, binding, false)
			_kit.need(problems, not Input.is_action_pressed(own), "%s on pad %d leaves %s held" % [binding.display_name, device, own])
			tested += 1
	await _kit.advance(1)
	_kit.verdict("P3_one_pad_one_player", problems, "%d inputs pressed and released, %d per pad, each read by its own Player's action only (round_restart by both)" % [tested, tested / 2])


func _check_hints() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var seen: PackedStringArray = PackedStringArray()
	for player: int in 2:
		var hint: String = _choice_hints[player].text
		var key: String = _destruct_hints[player]._key_name()
		seen.append("p%d choice '%s', destruct '%s'" % [player + 1, hint, key])
		_kit.need(problems, hint == PAD_CHOICE_HINT, "p%d choice hint is '%s'" % [player + 1, hint])
		_kit.need(problems, key == PAD_DESTRUCT_NAME, "p%d destruct is '%s'" % [player + 1, key])
	var restart: String = _round_over._restart_text()
	seen.append("restart '%s'" % restart)
	_kit.need(problems, restart == PAD_RESTART_LINE, "restart line is '%s'" % restart)
	_kit.verdict("P4_hints", problems, "; ".join(seen))


func _check_choice() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var start: Array[int] = [_choices[0].cursor, _choices[1].cursor]
	# One push of the stick right on pad 0, released.
	_axis(PAD_1, JOY_AXIS_LEFT_X, 1.0)
	await _kit.advance(1)
	_axis(PAD_1, JOY_AXIS_LEFT_X, 0.0)
	await _kit.advance(2)
	var after_push: Array[int] = [_choices[0].cursor, _choices[1].cursor]
	# The stick held for half a second.
	_axis(PAD_1, JOY_AXIS_LEFT_X, 1.0)
	await _kit.advance(HOLD_TICKS)
	_axis(PAD_1, JOY_AXIS_LEFT_X, 0.0)
	await _kit.advance(2)
	var after_hold: Array[int] = [_choices[0].cursor, _choices[1].cursor]
	# The D-pad left, twice, back to the start.
	for _i: int in 2:
		_button(PAD_1, JOY_BUTTON_DPAD_LEFT, true)
		await _kit.advance(1)
		_button(PAD_1, JOY_BUTTON_DPAD_LEFT, false)
		await _kit.advance(2)
	var after_dpad: Array[int] = [_choices[0].cursor, _choices[1].cursor]
	_kit.need(problems, after_push[0] == start[0] + 1, "a push moved p1 from %d to %d" % [start[0], after_push[0]])
	_kit.need(problems, after_hold[0] == after_push[0] + 1, "a held stick moved p1 from %d to %d" % [after_push[0], after_hold[0]])
	_kit.need(problems, after_dpad[0] == start[0], "two D-pad lefts left p1 at %d" % after_dpad[0])
	_kit.need(problems, after_push[1] == start[1] and after_hold[1] == start[1] and after_dpad[1] == start[1], "p2's cursor moved: %s %s %s" % [after_push, after_hold, after_dpad])
	# A on both pads confirms the Motorbike at the cursor's start.
	for device: int in [PAD_1, PAD_2]:
		_button(device, JOY_BUTTON_A, true)
		await _kit.advance(1)
		_button(device, JOY_BUTTON_A, false)
		await _kit.advance(1)
	var waited: int = 0
	while waited < SPAWN_WAIT_TICKS and not (_controller.is_alive(0) and _controller.is_alive(1)):
		await _kit.advance(1)
		waited += 1
	_kit.need(problems, _controller.is_alive(0) and _controller.is_alive(1), "the Units did not come into play in %d ticks" % SPAWN_WAIT_TICKS)
	_kit.verdict("P5_choice", problems, "cursors start %s, one push %s, held %d ticks %s, two D-pad lefts %s; A on both pads: both in play after %d ticks" % [
		start, after_push, HOLD_TICKS, after_hold, after_dpad, waited])


func _check_drive() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var from: Array[Vector3] = [_units[0].global_position, _units[1].global_position]
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _kit.advance(DRIVE_TICKS)
	var moved: Array[float] = [_units[0].global_position.distance_to(from[0]), _units[1].global_position.distance_to(from[1])]
	var full: float = Input.get_action_strength(&"p1_throttle")
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, HALF)
	await _kit.advance(1)
	var half: float = Input.get_action_strength(&"p1_throttle")
	var half_axis: float = Input.get_axis(&"p1_reverse", &"p1_throttle")
	var predicted: float = inverse_lerp(_layout.deadzone, 1.0, HALF)
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var rest: float = Input.get_action_strength(&"p1_throttle")
	_kit.need(problems, moved[0] > STILL_METRES, "p1's Unit moved %.3f m on a full trigger" % moved[0])
	_kit.need(problems, moved[1] < STILL_METRES, "p2's Unit moved %.3f m on p1's trigger" % moved[1])
	_kit.need(problems, is_equal_approx(full, 1.0), "full trigger strength %.3f" % full)
	_kit.need(problems, absf(half - predicted) < STRENGTH_TOLERANCE and is_equal_approx(half_axis, half), "half trigger strength %.3f, axis %.3f, predicted %.3f" % [half, half_axis, predicted])
	_kit.need(problems, is_zero_approx(rest), "released trigger strength %.3f" % rest)
	# The stick on pad 1 turns Player 2's Unit only.
	await _kit.advance(DRIVE_TICKS)
	var headings: Array[float] = [_units[0].global_rotation.y, _units[1].global_rotation.y]
	_axis(PAD_2, JOY_AXIS_LEFT_X, -1.0)
	await _kit.advance(HOLD_TICKS)
	_axis(PAD_2, JOY_AXIS_LEFT_X, 0.0)
	await _kit.advance(1)
	var turned: Array[float] = [absf(angle_difference(headings[0], _units[0].global_rotation.y)), absf(angle_difference(headings[1], _units[1].global_rotation.y))]
	_kit.need(problems, turned[1] > TURNED_RADIANS, "p2's Unit turned %.3f rad on its stick" % turned[1])
	_kit.need(problems, turned[0] < TURNED_RADIANS, "p1's Unit turned %.3f rad on p2's stick" % turned[0])
	_kit.verdict("P6_analog_drive", problems, "full RT on pad %d for %d ticks: p1 moved %.2f m, p2 %.3f m, strength %.3f | half RT: strength %.3f (inverse_lerp of the dead zone %.2f gives %.3f), get_axis %.3f | released %.3f | stick left on pad %d for %d ticks: p2 turned %.3f rad, p1 %.3f rad" % [
		PAD_1, DRIVE_TICKS, moved[0], moved[1], full, half, _layout.deadzone, predicted, half_axis, rest, PAD_2, HOLD_TICKS, turned[1], turned[0]])


func _check_buttons() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var shots: Array[Node] = []
	var note_shot: Callable = func(node: Node) -> void:
		if node is Shot:
			shots.append(node)
	_h.get_tree().node_added.connect(note_shot)
	_button(PAD_1, JOY_BUTTON_A, true)
	await _kit.advance(2)
	_button(PAD_1, JOY_BUTTON_A, false)
	await _kit.advance(1)
	_h.get_tree().node_added.disconnect(note_shot)
	var from_p1: int = shots.filter(func(shot: Node) -> bool:
		return is_instance_valid(shot) and shot.global_position.distance_to(_units[0].global_position) < shot.global_position.distance_to(_units[1].global_position)).size()
	_kit.need(problems, shots.size() >= 1, "A on pad %d fired no Shot" % PAD_1)
	_kit.need(problems, from_p1 == shots.size(), "%d of %d Shots are nearer Player 2's Unit" % [shots.size() - from_p1, shots.size()])
	var settings_before: Array = [_h.split.player_1_camera.settings, _h.split.player_2_camera.settings]
	_button(PAD_1, JOY_BUTTON_Y, true)
	await _kit.advance(1)
	_button(PAD_1, JOY_BUTTON_Y, false)
	await _kit.advance(1)
	var settings_after: Array = [_h.split.player_1_camera.settings, _h.split.player_2_camera.settings]
	_kit.need(problems, settings_after[0] != settings_before[0], "Y on pad %d did not step p1's camera" % PAD_1)
	_kit.need(problems, settings_after[1] == settings_before[1], "Y on pad %d stepped p2's camera" % PAD_1)
	_button(PAD_1, JOY_BUTTON_X, true)
	var mine_read: bool = Input.is_action_just_pressed(&"p1_lay_mine") or Input.is_action_pressed(&"p1_lay_mine")
	var mine_other: bool = Input.is_action_pressed(&"p2_lay_mine")
	await _kit.advance(1)
	_button(PAD_1, JOY_BUTTON_X, false)
	_kit.need(problems, mine_read and not mine_other, "X on pad %d: p1_lay_mine %s, p2_lay_mine %s" % [PAD_1, mine_read, mine_other])
	_button(PAD_1, JOY_BUTTON_BACK, true)
	await _kit.advance(1)
	_button(PAD_1, JOY_BUTTON_BACK, false)
	await _kit.advance(2)
	var alive: Array[bool] = [_controller.is_alive(0), _controller.is_alive(1)]
	_kit.need(problems, not alive[0] and alive[1], "View on pad %d: alive %s" % [PAD_1, alive])
	_kit.verdict("P7_buttons", problems, "A: %d Shots, %d of them at Player 1's Unit | Y: p1 camera stepped %s, p2 %s | X: p1_lay_mine %s, p2_lay_mine %s | View: alive %s" % [
		shots.size(), from_p1, settings_after[0] != settings_before[0], settings_after[1] != settings_before[1], mine_read, mine_other, alive])
	# Player 1 chooses again with A, for the drive of P8.
	await _kit.advance(1)
	_button(PAD_1, JOY_BUTTON_A, true)
	await _kit.advance(1)
	_button(PAD_1, JOY_BUTTON_A, false)
	var waited: int = 0
	while waited < SPAWN_WAIT_TICKS and not _controller.is_alive(0):
		await _kit.advance(1)
		waited += 1


func _check_disconnect() -> void:
	var problems: PackedStringArray = PackedStringArray()
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _kit.advance(DRIVE_TICKS)
	var speed_held: float = _units[0].velocity.length()
	var gone: int = _pads.disconnect_pad(PAD_1)
	var held_after: bool = Input.is_action_pressed(&"p1_throttle")
	var strength_after: float = Input.get_action_strength(&"p1_throttle")
	await _kit.advance(DRIVE_TICKS)
	var speed_later: float = _units[0].velocity.length()
	var notice_gone: String = _notices[0].text if _notices[0].visible else "(hidden)"
	var notice_other: String = _notices[1].text if _notices[1].visible else "(hidden)"
	var hint_key: String = _destruct_hints[0]._key_name()
	_kit.need(problems, gone == 0, "disconnect returned %d" % gone)
	_kit.need(problems, not held_after and is_zero_approx(strength_after), "p1_throttle held %s, strength %.3f after the disconnect" % [held_after, strength_after])
	_kit.need(problems, speed_later < speed_held, "speed %.2f -> %.2f after the disconnect" % [speed_held, speed_later])
	_kit.need(problems, notice_gone == NOTICE_DISCONNECTED, "p1 notice '%s'" % notice_gone)
	_kit.need(problems, notice_other != NOTICE_DISCONNECTED, "p2 notice '%s'" % notice_other)
	_kit.need(problems, hint_key == KEY_DESTRUCT_NAMES[0], "p1 destruct key '%s' with no pad" % hint_key)
	_kit.need(problems, _pad_events(&"p1_throttle").is_empty(), "p1_throttle keeps pad events %s" % [_pad_events(&"p1_throttle")])
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	# A keyboard key held through a reconnect and a disconnect stays held.
	var back: int = _pads.connect_pad(PAD_1)
	await _kit.advance(1)
	var notice_back: String = _notices[0].text if _notices[0].visible else "(hidden)"
	_h.set_key(KEY_THROTTLE_1, true)
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _kit.advance(1)
	_pads.disconnect_pad(PAD_1)
	var key_held: bool = Input.is_action_pressed(&"p1_throttle")
	await _kit.advance(1)
	_h.set_key(KEY_THROTTLE_1, false)
	await _kit.advance(1)
	var key_released: bool = not Input.is_action_pressed(&"p1_throttle")
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	var back_again: int = _pads.connect_pad(PAD_1)
	_kit.need(problems, back == 0 and back_again == 0, "pad %d came back to %d, then %d" % [PAD_1, back, back_again])
	_kit.need(problems, notice_back == NOTICE_CONNECTED, "p1 notice on reconnect '%s'" % notice_back)
	_kit.need(problems, key_held, "the W key held through the disconnect was released")
	_kit.need(problems, key_released, "p1_throttle stayed held after W came up")
	_kit.verdict("P8_pad_goes", problems, "RT held %d ticks: speed %.2f; disconnect -> Player %d, p1_throttle held %s strength %.3f, speed %d ticks later %.2f; notices p1 '%s', p2 '%s'; p1 destruct key '%s' | reconnect -> Player %d, notice '%s' | W held through a disconnect: p1_throttle %s, released with W %s | reconnect -> Player %d" % [
		DRIVE_TICKS, speed_held, gone, held_after, strength_after, DRIVE_TICKS, speed_later, notice_gone, notice_other, hint_key, back, notice_back, key_held, key_released, back_again])


func _check_cleanup() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var deadzone_before: float = InputMap.action_get_deadzone(&"p1_fire")
	_pads.disconnect_pad(PAD_1)
	_pads.disconnect_pad(PAD_2)
	var after_disconnects: int = _all_pad_events()
	var restored: float = InputMap.action_get_deadzone(&"p1_fire")
	# A second PadAssignment holding a pad, then freed with the pad still assigned.
	var extra := PadAssignment.new()
	extra.layout = _layout
	extra.action_prefixes = PREFIXES.duplicate()
	_h.add_child(extra)
	extra.connect_pad(PAD_3)
	var while_held: int = _all_pad_events()
	_h.remove_child(extra)
	extra.free()
	var after_free: int = _all_pad_events()
	_kit.need(problems, after_disconnects == 0, "%d pad events left after both disconnects" % after_disconnects)
	_kit.need(problems, while_held > 0, "the extra assignment added no event")
	_kit.need(problems, after_free == 0, "%d pad events left after the node left the tree" % after_free)
	_kit.need(problems, is_equal_approx(restored, InputMap.action_get_deadzone(&"p2_fire")) and not is_equal_approx(restored, 0.0), "p1_fire dead zone %s -> %s" % [deadzone_before, restored])
	_kit.verdict("P9_cleanup", problems, "pad events after both disconnects %d; a freed PadAssignment holding pad %d: %d events while held, %d after; p1_fire dead zone %.2f -> %.2f" % [
		after_disconnects, PAD_3, while_held, after_free, deadzone_before, restored])
