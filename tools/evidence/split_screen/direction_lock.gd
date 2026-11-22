extends RefCounted
## Scenario direction_lock of the split screen evidence harness (split_screen_harness.gd): Story 069, the stick's direction
## lock (Martin, 2026-11-22: "ked cuvam a otacam sa packou na ovladaci, zrazu z toho ze cuvam dolava napr, sa pri jemnom
## pohybe stane ze idem dolava dopredu"). Pad 0 is connected through the launch scene's PadAssignment and driven with
## InputEventJoypadMotion events. CHECK lines:
##  L1 the slip: reversing with the stick down and left, the stick slid to left and a little up (past full_throttle_from,
##     short of switch_from) keeps the Unit reversing; pushed up past switch_from it drives forward.
##  L2 the release: reversing, then the stick held left only (a spot turn) for longer than release_seconds, then left and a
##     little up: the Unit drives forward.
##  L3 the keyboard: reversing on S, then W: forward at once.
## Implements: production/epics/wasteland-fire/story-069-burn-looks-direction-lock.md AC-3 and AC-4. Tooling only.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=direction_lock

const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")
const Kit: GDScript = preload("res://tools/evidence/split_screen/check_kit.gd")

const STICK_DRIVE: bool = true
const FULL_THROTTLE: bool = true
const DIRECTION_LOCK: bool = true
const FIRE_HEIGHTS: bool = true
const MINES: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const MAP_CHOICE: bool = true
const PAD_1: int = 0
const REVERSE_TICKS: int = 30
const SLIP_TICKS: int = 20
const SETTLE_TICKS: int = 10
## The little lean up: halfway between full_throttle_from and switch_from.
const SLIP_SHARE: float = 0.5
## The release wait past release_seconds, ticks.
const RELEASE_MARGIN: int = 6

var _h: Harness
var _kit: Kit
var _pads: PadAssignment
var _unit: Unit
var _drive: PlayerDriveInput


func run(harness: Node) -> void:
	_h = harness as Harness
	_kit = Kit.new(_h)
	_pads = _h.split.get_node("PadAssignment") as PadAssignment
	_unit = _h.split.player_1_unit
	for node: Node in _h.split.find_children("*", "", true, false):
		var drive: PlayerDriveInput = node as PlayerDriveInput
		if drive != null and drive.unit == _unit:
			_drive = drive
	_pads.connect_pad(PAD_1)
	await _kit.advance(2)
	await _check_slip()
	await _check_release()
	_pads.disconnect_pad(PAD_1)
	await _check_keys()
	_h.finish("switch_from=%.2f release=%.2fs" % [_drive.switch_from, _drive.release_seconds])


func _slip() -> float:
	var from: float = _pads.layout.full_throttle_from
	return from + (_drive.switch_from - from) * SLIP_SHARE


func _check_slip() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var start: Transform3D = _unit.global_transform
	_stick(-0.7, 0.7)
	await _kit.advance(REVERSE_TICKS)
	var reversing: float = _unit.current_speed
	_stick(-1.0, -_slip())
	await _kit.advance(SLIP_TICKS)
	var slipped: float = _unit.current_speed
	_stick(-0.3, -0.95)
	await _kit.advance(SLIP_TICKS * 2)
	var pushed: float = _unit.current_speed
	await _put_back(start)
	_kit.need(problems, reversing < 0.0, "not reversing with the stick down and left (%.2f m/s)" % reversing)
	_kit.need(problems, slipped < 0.0, "the slip to %.2f up turned it forward (%.2f m/s)" % [_slip(), slipped])
	_kit.need(problems, pushed > 0.0, "pushed up 0.95 it still reverses (%.2f m/s)" % pushed)
	_kit.verdict("L1_the_slip", problems, "reversing %.2f m/s; stick left and %.2f up: %.2f m/s; pushed up 0.95: %.2f m/s" % [reversing, _slip(), slipped, pushed])


func _check_release() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var start: Transform3D = _unit.global_transform
	_stick(-0.7, 0.7)
	await _kit.advance(REVERSE_TICKS)
	_stick(-1.0, 0.0)
	await _kit.advance(int(_drive.release_seconds * Engine.physics_ticks_per_second) + RELEASE_MARGIN)
	_stick(-1.0, -_slip())
	await _kit.advance(SLIP_TICKS)
	var after: float = _unit.current_speed
	await _put_back(start)
	_kit.need(problems, after > 0.0, "after the spot turn, left and %.2f up still reverses (%.2f m/s)" % [_slip(), after])
	_kit.verdict("L2_the_release", problems, "reverse, a spot turn past %.2f s, then left and %.2f up: %.2f m/s" % [_drive.release_seconds, _slip(), after])


func _check_keys() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var start: Transform3D = _unit.global_transform
	var back: Key = _key_of(&"p1_reverse")
	var forth: Key = _key_of(&"p1_throttle")
	_h.set_key(back, true)
	await _kit.advance(REVERSE_TICKS)
	var reversing: float = _unit.current_speed
	_h.set_key(back, false)
	_h.set_key(forth, true)
	await _kit.advance(SLIP_TICKS * 2)
	var forward: float = _unit.current_speed
	_h.set_key(forth, false)
	await _put_back(start)
	_kit.need(problems, reversing < 0.0 and forward > 0.0, "S %.2f then W %.2f m/s" % [reversing, forward])
	_kit.verdict("L3_the_keyboard", problems, "S %.2f m/s, then W %.2f m/s" % [reversing, forward])


func _put_back(start: Transform3D) -> void:
	_stick(0.0, 0.0)
	await _kit.advance(int(_drive.release_seconds * Engine.physics_ticks_per_second) + RELEASE_MARGIN)
	_unit.global_transform = start
	_unit.reset_motion()
	await _kit.advance(SETTLE_TICKS)


func _stick(x: float, y: float) -> void:
	for pair: Array in [[JOY_AXIS_LEFT_X, x], [JOY_AXIS_LEFT_Y, y]]:
		var motion := InputEventJoypadMotion.new()
		motion.device = PAD_1
		motion.axis = pair[0]
		motion.axis_value = pair[1]
		Input.parse_input_event(motion)


func _key_of(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key: InputEventKey = event as InputEventKey
		if key != null:
			return key.physical_keycode
	return KEY_NONE
