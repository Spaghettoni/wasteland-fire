extends RefCounted
## Scenario pads_showcase of the split screen evidence harness (split_screen_harness.gd): the
## frames of Story 032, windowed. It connects two pads through the scene's PadAssignment (a run has
## no real pads) and saves the whole window at each moment, as a PNG in the folder named by the
## environment variable PADS_SHOTS:
##  01 the launch, keyboard only: both choice panels name the keys, as before.
##  02 pad 0 connected: Player 1's notice says "Controller connected", its choice panel names the
##     stick and A; Player 2's still the keys.
##  03 both pads: both panels name the stick and A.
##  04 driving: both Units in play after A on both pads, Player 1 on a full right trigger.
##  05 the Round-over screen (staged: its show is called with Player 1 as the winner, as a Round's
##     end would), naming "R or Menu".
##  06 pad 0 disconnected mid-Round: Player 1's notice says "Controller disconnected".
## Implements: production/epics/wasteland-fire/story-032-xbox-controllers.md AC-5 and AC-6 (the
## frames). Tooling only: nothing under src/ depends on this file.
## Run: PADS_SHOTS=<folder> godot --path . --windowed --resolution 1280x720 \
##     res://tools/evidence/split_screen_harness.tscn -- --scenario=pads_showcase

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
## The shared helpers (check_kit.gd): ticks, verdicts.
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

## The Players choose with the pads.
const OWN_CHOICE: bool = true
## Keeps the notice lines (see pads.gd).
const MINES: bool = true
## The camera the build ships with, the view from above.
const SHIPPED_CAMERA: bool = true
## The pads' device IDs.
const PAD_1: int = 0
const PAD_2: int = 1
## Ticks waited before a frame, so the picture has settled.
const SETTLE_TICKS: int = 20
## Ticks Player 1 drives before frame 04.
const DRIVE_TICKS: int = 90
## Ticks waited for the Units after both chose.
const SPAWN_WAIT_TICKS: int = 240

var _h: Harness
var _kit: Kit
var _folder: String = ""
var _saved: PackedStringArray = PackedStringArray()


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_folder = OS.get_environment("PADS_SHOTS")
	var pads: PadAssignment = _h.split.get_node("%PadAssignment") as PadAssignment
	var controller: MatchController = _h.split.match_controller
	await _kit.advance(SETTLE_TICKS)
	await _save("01-launch-keyboard-hints")
	pads.connect_pad(PAD_1)
	await _kit.advance(SETTLE_TICKS)
	await _save("02-pad-1-connected-notice-and-pad-hint")
	pads.connect_pad(PAD_2)
	await _kit.advance(SETTLE_TICKS)
	await _save("03-both-pads-pad-hints")
	for device: int in [PAD_1, PAD_2]:
		_button(device, JOY_BUTTON_A, true)
		await _kit.advance(1)
		_button(device, JOY_BUTTON_A, false)
	var waited: int = 0
	while waited < SPAWN_WAIT_TICKS and not (controller.is_alive(0) and controller.is_alive(1)):
		await _kit.advance(1)
		waited += 1
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _kit.advance(DRIVE_TICKS)
	await _save("04-driving-on-the-right-trigger")
	_axis(PAD_1, JOY_AXIS_TRIGGER_RIGHT, 0.0)
	pads.disconnect_pad(PAD_1)
	await _kit.advance(SETTLE_TICKS)
	await _save("06-pad-1-disconnected-notice")
	for n: int in [1, 2]:
		var screen: RoundOverScreen = _h.split.get_node("Views/Player%dView/SubViewport/Player%dRoundOver" % [n, n]) as RoundOverScreen
		screen._show_result(0)
	pads.connect_pad(PAD_1)
	await _kit.advance(SETTLE_TICKS)
	await _save("05-round-over-r-or-menu-staged")
	_kit.verdict("S1_frames", PackedStringArray() if _saved.size() == 6 else PackedStringArray(["%d frames saved" % _saved.size()]),
		"saved to %s: %s" % [_folder, ", ".join(_saved)])
	_h.finish("frames=%d" % _saved.size())


func _save(label: String) -> void:
	await RenderingServer.frame_post_draw
	if _folder.is_empty():
		return
	var image: Image = _h.get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [_folder, label]
	if image != null and image.save_png(path) == OK:
		_saved.append(label)


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
