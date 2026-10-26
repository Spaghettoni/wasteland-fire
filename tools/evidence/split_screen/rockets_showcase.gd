extends RefCounted
## Scenario rockets_showcase of the split screen evidence harness (split_screen_harness.gd): the retained frame of Story 061 on
## Map 02's open middle with the shipped data. Player 1's Buggy fires high (Left Shift) at Player 2's Gyrocopter 30 m ahead, which
## fires low back at it: red rockets go up, yellow Shots come down. One moment, rockets_and_shots, read when at least one rocket
## and one yellow Shot are in flight. A SPLIT line with frame=, the number of the PNG that shows it in a --write-movie recording.
## A moment whose premise does not hold prints one failing CHECK named premise.
## Implements: production/epics/wasteland-fire/story-061-rockets-and-turrets.md, Test Evidence. Tooling only.
## Run: godot --path . --windowed --resolution 1280x720 --rendering-driver vulkan \
##     --write-movie shots/rockets.png res://tools/evidence/split_screen_harness.tscn -- --scenario=rockets_showcase

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const MAP_SCENE: String = "res://src/gameplay/maps/map_02/map_02.tscn"
const OWN_BASE_SWAP: bool = true
const BASE_DEFENCES: bool = true
const TURRETS: bool = true
const HEIGHTS: bool = true
const AMMO: bool = true
const RESOURCE_BARS: bool = true
const TURRET_SEES_FLYING: bool = true
const ROTORS: bool = true
const BUSHES: bool = true
const FIRE_HEIGHTS: bool = true
const SHIPPED_CAMERA: bool = true
const FULL_THROTTLE: bool = true
const CLOSE_CHASE: bool = true
const WATCHDOG_SECONDS: float = 120.0
const MOMENT_FRAME_LAG: int = 1
const AHEAD: float = 30.0
const LIMIT_TICKS: int = 240
const HOLD_TICKS: int = 30
const AT_LEAST: int = 1

var _m: M2
var _problems: PackedStringArray = []


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var start: Vector3 = M2.at(M2.CENTRE.x, M2.CENTRE.y + AHEAD / 2.0)
	await _m.put(1, M2.GYROCOPTER, start + Vector3.FORWARD * AHEAD, Vector3.BACK)
	await _m.put(0, M2.BUGGY, start, Vector3.FORWARD)
	await _m.kit.advance(HOLD_TICKS)
	_shift(true)
	_m.h.set_key(_m.h.fire_key(1), true)
	var read: bool = false
	for _tick: int in LIMIT_TICKS:
		await _m.kit.tick()
		var rockets: int = 0
		var shots: int = 0
		for item: Variant in _m.h.get_tree().get_nodes_in_group(&"shots"):
			var node: Node = item as Node if is_instance_valid(item) else null
			if node == null:
				continue
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var file: String = node.scene_file_path.get_file()
			rockets += 1 if file == "shot_rocket.tscn" else 0
			shots += 1 if file == "shot.tscn" else 0
		if rockets >= AT_LEAST and shots >= AT_LEAST:
			print("SPLIT %s t=%.3f frame=%d moment=rockets_and_shots rockets=%d yellow=%d" % [
				_m.h.scenario, _m.h.time(), Engine.get_process_frames() - MOMENT_FRAME_LAG, rockets, shots])
			read = true
			break
	_shift(false)
	_m.h.set_key(_m.h.fire_key(1), false)
	_m.kit.need(_problems, read, "rockets_and_shots: never %d rockets and %d yellow Shots in flight at once" % [AT_LEAST, AT_LEAST])
	await _m.kit.advance(HOLD_TICKS)
	if not _problems.is_empty():
		_m.kit.verdict("premise", _problems, "rockets_and_shots")
	_m.h.finish("map=map_02")


## A real Left Shift key event: Player 1's high fire.
func _shift(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = KEY_LOCATION_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
