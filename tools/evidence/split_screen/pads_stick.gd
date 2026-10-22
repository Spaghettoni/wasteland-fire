extends RefCounted
## Scenario pads_stick of the split screen evidence harness (split_screen_harness.gd): on a pad the left stick drives and the
## triggers fire (Story 040). Pads are connected through the launch scene's PadAssignment (connect_pad()) and driven with
## InputEventJoypadMotion / Button events pushed through Input.parse_input_event with the pad's device ID. CHECK lines:
##  S1 forward and back on the stick: pad 0's stick pushed up drives Player 1's Unit forward (p1_throttle at full), pulled down
##     drives it backward (p1_reverse), half up gives the analog strength past the dead zone; Player 2's Unit stays still.
##  S2 the triggers fire: the right trigger, the left trigger and A each fire Player 1's Weapon; neither trigger presses
##     throttle or reverse any more.
##  S3 the stick still steers and chooses: pushed left it turns the Unit; the choice hint still reads "Stick left / Stick right
##     to choose, A to confirm".
##  S4 the data: pad_layout.tres binds throttle to the stick up, reverse to the stick down, fire to A, RT and LT, and its
##     first_problem() finds nothing for either Player.
## Implements: production/epics/wasteland-fire/story-040-left-stick-drives.md AC-1 to AC-4.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=pads_stick

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

const STICK_DRIVE: bool = true
## The shipped layout binds RB to the high fire (Story 041), whose actions the runner keeps only for this opt-in.
const FIRE_HEIGHTS: bool = true
const MINES: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const MAP_CHOICE: bool = true
const LAYOUT_PATH: String = "res://src/gameplay/input/data/pad_layout.tres"
const PAD_1: int = 0
const DRIVE_TICKS: int = 60
const HOLD_TICKS: int = 30
const FIRE_TICKS: int = 20
const HALF: float = 0.5
const STILL_METRES: float = 0.01
const TURNED_RADIANS: float = 0.05
const STRENGTH_TOLERANCE: float = 0.001
const CHOICE_HINT: String = "Stick left / Stick right to choose, A to confirm"
## What each action's pad inputs must be: [kind, axis or button, direction], by action suffix.
const WANT: Dictionary = {
	&"throttle": [[PadBinding.Kind.AXIS, JOY_AXIS_LEFT_Y, -1]],
	&"reverse": [[PadBinding.Kind.AXIS, JOY_AXIS_LEFT_Y, 1]],
	&"fire": [[PadBinding.Kind.BUTTON, JOY_BUTTON_A, 0], [PadBinding.Kind.AXIS, JOY_AXIS_TRIGGER_RIGHT, 1], [PadBinding.Kind.AXIS, JOY_AXIS_TRIGGER_LEFT, 1]],
}

var _h: Harness
var _kit: Kit
var _pads: PadAssignment
var _units: Array[Unit] = []


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_pads = _h.split.get_node("PadAssignment") as PadAssignment
	_units = [_h.split.player_1_unit, _h.split.player_2_unit]
	_check_data()
	_pads.connect_pad(PAD_1)
	await _kit.advance(2)
	_check_hint()
	await _check_drive()
	await _check_fire()
	_pads.disconnect_pad(PAD_1)
	_h.finish("pads=1")


func _check_drive() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var start: Transform3D = _units[0].global_transform
	var other: Vector3 = _units[1].global_position
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _kit.advance(DRIVE_TICKS)
	var full: float = Input.get_action_strength(&"p1_throttle")
	var forward: float = (_units[0].global_position - start.origin).dot(-start.basis.z)
	_axis(JOY_AXIS_LEFT_Y, -HALF)
	await _kit.advance(1)
	var half: float = Input.get_action_strength(&"p1_throttle")
	var predicted: float = inverse_lerp(_pads.layout.deadzone, 1.0, HALF)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _kit.advance(DRIVE_TICKS)
	var mark: Transform3D = _units[0].global_transform
	_axis(JOY_AXIS_LEFT_Y, 1.0)
	await _kit.advance(DRIVE_TICKS)
	var back_strength: float = Input.get_action_strength(&"p1_reverse")
	var backward: float = (_units[0].global_position - mark.origin).dot(mark.basis.z)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _kit.advance(1)
	var rest: float = Input.get_action_strength(&"p1_throttle") + Input.get_action_strength(&"p1_reverse")
	var other_moved: float = _units[1].global_position.distance_to(other)
	_kit.need(problems, is_equal_approx(full, 1.0) and forward > STILL_METRES, "stick up: strength %.3f, moved %.2f m forward" % [full, forward])
	_kit.need(problems, absf(half - predicted) < STRENGTH_TOLERANCE, "half up: strength %.3f, predicted %.3f" % [half, predicted])
	_kit.need(problems, is_equal_approx(back_strength, 1.0) and backward > STILL_METRES, "stick down: reverse %.3f, moved %.2f m backward" % [back_strength, backward])
	_kit.need(problems, is_zero_approx(rest), "released: %.3f" % rest)
	_kit.need(problems, other_moved < STILL_METRES, "Player 2's Unit moved %.3f m" % other_moved)
	# Left on the stick turns the Unit.
	var heading: float = _units[0].global_rotation.y
	_axis(JOY_AXIS_LEFT_X, -1.0)
	await _kit.advance(HOLD_TICKS)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	await _kit.advance(1)
	var turned: float = absf(angle_difference(heading, _units[0].global_rotation.y))
	_kit.need(problems, turned > TURNED_RADIANS, "stick left turned %.3f rad" % turned)
	_kit.verdict("S1_stick_drives", problems, "stick up %d ticks: strength %.3f, %.2f m forward; half up %.3f (predicted %.3f); stick down %d ticks: reverse %.3f, %.2f m backward; released %.3f; Player 2 moved %.3f m; stick left %d ticks turned %.3f rad" % [
		DRIVE_TICKS, full, forward, half, predicted, DRIVE_TICKS, back_strength, backward, rest, other_moved, HOLD_TICKS, turned])


func _check_fire() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var weapon: Weapon = _h.split.player_1_weapon
	var lines: PackedStringArray = PackedStringArray()
	for input: Array in [["RT", JOY_AXIS_TRIGGER_RIGHT], ["LT", JOY_AXIS_TRIGGER_LEFT], ["A", -1]]:
		var before: int = weapon.shots_left
		var moved_by: float = 0.0
		var start: Vector3 = _units[0].global_position
		var drive_pressed: bool = false
		if input[1] == -1:
			_button(JOY_BUTTON_A, true)
		else:
			_axis(input[1], 1.0)
		for _tick: int in FIRE_TICKS:
			await _kit.tick()
			drive_pressed = drive_pressed or Input.is_action_pressed(&"p1_throttle") or Input.is_action_pressed(&"p1_reverse")
		if input[1] == -1:
			_button(JOY_BUTTON_A, false)
		else:
			_axis(input[1], 0.0)
		await _kit.advance(2)
		moved_by = _units[0].global_position.distance_to(start)
		var fired: int = before - weapon.shots_left
		_kit.need(problems, fired > 0, "%s fired %d Shots" % [input[0], fired])
		_kit.need(problems, not drive_pressed, "%s pressed throttle or reverse" % input[0])
		lines.append("%s: %d Shots, drive pressed %s, moved %.2f m" % [input[0], fired, drive_pressed, moved_by])
	_kit.verdict("S2_triggers_fire", problems, "; ".join(lines))


func _check_hint() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var hint: String = _pads.layout.name_for(&"steer_left") + " / " + _pads.layout.name_for(&"steer_right") + " to choose, " + _pads.layout.name_for(&"fire") + " to confirm"
	_kit.need(problems, hint == CHOICE_HINT, "the pad's choice hint reads '%s'" % hint)
	_kit.verdict("S3_choice_hint", problems, "the layout names for the choice hint: '%s'" % hint)


func _check_data() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var layout: PadLayout = load(LAYOUT_PATH) as PadLayout
	var found: Dictionary = {}
	for binding: PadBinding in layout.bindings:
		if WANT.has(binding.action_suffix):
			var entry: Array = [binding.kind, binding.axis if binding.kind == PadBinding.Kind.AXIS else binding.button, binding.axis_direction if binding.kind == PadBinding.Kind.AXIS else 0]
			if not found.has(binding.action_suffix):
				found[binding.action_suffix] = []
			found[binding.action_suffix].append(entry)
	for suffix: StringName in WANT:
		_kit.need(problems, found.get(suffix, []) == WANT[suffix], "%s is bound to %s" % [suffix, found.get(suffix, [])])
	for prefix: StringName in [&"p1_", &"p2_"]:
		var problem: String = layout.first_problem(prefix)
		_kit.need(problems, problem.is_empty(), "%s: %s" % [prefix, problem])
	_kit.verdict("S4_data", problems, "throttle %s, reverse %s, fire %s; first_problem empty for p1_ and p2_" % [found.get(&"throttle"), found.get(&"reverse"), found.get(&"fire")])


func _axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = PAD_1
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _button(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = PAD_1
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
