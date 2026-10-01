extends RefCounted
## Scenario layout of the split screen evidence harness (split_screen_harness.gd): AC-1, AC-2, AC-5
## and AC-6 of Story 002, read from the launch scene as it stands LAYOUT_SETTLE_TICKS ticks after it
## started. Nothing is driven. It checks the view sizes, one current camera per view, each camera's
## target, two Units and one field, one shared world and physics space, the world's physics
## interpolation (Story 001 AC-5's smooth chase, carried over), the start positions, and the eight
## Input Map actions and keys. Prints one SPLIT line with the window, then the CHECK lines.
##
## Implements: production/epics/wasteland-fire/story-002-split-screen.md, Acceptance Criteria.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=layout

## The runner this scenario is handed, loaded by path: nothing under tools/ declares a class_name.
const Harness: GDScript = preload("res://tools/evidence/split_screen_harness.gd")

## The size AC-1 asks of each Player's view, pixels: half the window wide, as tall as the window.
const VIEW_SIZE: Vector2i = Vector2i(640, 720)
## Device id of an Input Map event bound to every device (the editor's All Devices), which is what
## project.godot stores for all eight actions. 4.7 loads a stored device 0 as DEVICE_ID_KEYBOARD
## (16), so an event pinned to one device never equals this.
const ANY_DEVICE: int = -1
## Frames the scenario waits before reading sizes: they are valid from the first frame.
const LAYOUT_SETTLE_TICKS: int = 10
## The project setting that turns physics interpolation on for the whole game (project.godot).
const PHYSICS_INTERPOLATION_SETTING: String = "physics/common/physics_interpolation"
## A Unit on its marker is within this distance of it, metres.
const START_TOLERANCE: float = 0.05
## A Unit on its marker faces the marker's way: the dot product of the two facings is at least this.
const START_FACING_DOT: float = 0.999
## The two Units must start at least this far apart, metres.
const MIN_APART: float = 1.0

## The first part of an Input Map action name, one per Player: prefix + suffix.
const ACTION_PREFIXES: Array[String] = ["p1_", "p2_"]
## The last part of an Input Map action name, one per slot (the runner's SLOT_* order): prefix + suffix.
const ACTION_SUFFIXES: Array[String] = ["throttle", "reverse", "steer_left", "steer_right"]

var _harness: Harness
var _split: SplitScreen


## AC-1, AC-2, AC-5, AC-6: reads and checks the launch scene. The runner awaits this coroutine.
func run(harness: Node) -> void:
	_harness = harness as Harness
	_split = _harness.split
	await _harness.advance_ticks(LAYOUT_SETTLE_TICKS)
	var window: Window = _harness.get_window()
	var visible: Vector2 = _harness.get_viewport().get_visible_rect().size
	print("SPLIT layout t=%.3f window=%dx%d content_scale_size=%dx%d visible_rect=%dx%d display=%s" % [
		_harness.time(), window.size.x, window.size.y, window.content_scale_size.x, window.content_scale_size.y,
		int(visible.x), int(visible.y), DisplayServer.get_name()])
	_check_view_sizes()
	_check_current_cameras()
	_check_camera_targets()
	_check_node_counts()
	_check_shared_world()
	_check_shared_physics_space()
	_check_world_interpolation()
	_check_start_positions()
	_check_input_map()
	_harness.finish("window=%dx%d" % [window.size.x, window.size.y])


## The SubViewport a camera sits in, or null when it is in the window's own viewport.
func _view_of(camera: ChaseCamera) -> SubViewport:
	return camera.get_viewport() as SubViewport


## A node's name, or "null" for a missing node, for check details.
func _name_of(node: Node) -> String:
	return String(node.name) if node != null else "null"


## The Camera3D a SubViewport draws with, or null for a missing view.
func _camera_in(view: SubViewport) -> Camera3D:
	if view == null:
		return null
	return view.get_camera_3d()


## Every Camera3D in the tree that is current.
func _current_cameras() -> Array[Camera3D]:
	var current: Array[Camera3D] = []
	for node: Node in _harness.get_tree().root.find_children("*", "Camera3D", true, false):
		var camera: Camera3D = node as Camera3D
		if camera.current:
			current.append(camera)
	return current


## AC-1: each Player's view is a SubViewportContainer of exactly VIEW_SIZE holding a SubViewport of
## VIEW_SIZE, side by side from x = 0.
func _check_view_sizes() -> void:
	var passed: bool = true
	var detail: PackedStringArray = []
	var cameras: Array[ChaseCamera] = [_split.player_1_camera, _split.player_2_camera]
	for index: int in cameras.size():
		var view: SubViewport = _view_of(cameras[index])
		var container: SubViewportContainer = null
		if view != null:
			container = view.get_parent() as SubViewportContainer
		if container == null:
			passed = false
			detail.append("player_%d has no SubViewport in a SubViewportContainer" % (index + 1))
			continue
		var expected_x: float = float(index * VIEW_SIZE.x)
		var fits: bool = Vector2i(container.size) == VIEW_SIZE and view.size == VIEW_SIZE \
			and is_equal_approx(container.global_position.x, expected_x) \
			and is_zero_approx(container.global_position.y)
		passed = passed and fits
		detail.append("player_%d container=%dx%d at x=%.0f viewport=%dx%d expected=%dx%d at x=%.0f" % [
			index + 1, int(container.size.x), int(container.size.y), container.global_position.x,
			view.size.x, view.size.y, VIEW_SIZE.x, VIEW_SIZE.y, expected_x])
	_harness.check("view_sizes", passed, " | ".join(detail))


## AC-1: exactly two current Camera3D nodes, one in each SubViewport, none in the window's own
## viewport.
func _check_current_cameras() -> void:
	var current: Array[Camera3D] = _current_cameras()
	var view_1: SubViewport = _view_of(_split.player_1_camera)
	var view_2: SubViewport = _view_of(_split.player_2_camera)
	var in_view_1: Camera3D = _camera_in(view_1)
	var in_view_2: Camera3D = _camera_in(view_2)
	var in_root: Camera3D = _harness.get_viewport().get_camera_3d()
	var views_ok: bool = view_1 != null and view_2 != null and view_1 != view_2
	var cameras_match: bool = in_view_1 == _split.player_1_camera and in_view_2 == _split.player_2_camera
	var only_these: bool = current.size() == 2 and current.has(_split.player_1_camera) \
		and current.has(_split.player_2_camera)
	_harness.check("one_current_camera_per_view", views_ok and cameras_match and only_these and in_root == null,
		"current_cameras=%d player_1_view_camera=%s player_2_view_camera=%s root_viewport_camera=%s"
		% [current.size(), _name_of(in_view_1), _name_of(in_view_2), _name_of(in_root)])


## AC-1: each ChaseCamera follows its own Player's Unit.
func _check_camera_targets() -> void:
	var passed: bool = _split.player_1_camera.target == _split.player_1_unit \
		and _split.player_2_camera.target == _split.player_2_unit
	_harness.check("camera_targets", passed, "player_1_camera->%s (expected %s) player_2_camera->%s (expected %s)" % [
		_name_of(_split.player_1_camera.target), _name_of(_split.player_1_unit),
		_name_of(_split.player_2_camera.target), _name_of(_split.player_2_unit)])


## AC-2: two Motorbikes and one field in the whole tree, not two copies of the scene.
func _check_node_counts() -> void:
	var units: int = 0
	var fields: int = 0
	for node: Node in _harness.get_tree().root.find_children("*", "", true, false):
		if node is Unit:
			units += 1
		elif node is GreyboxField:
			fields += 1
	_harness.check("node_counts", units == 2 and fields == 1,
		"units=%d (expected 2) greybox_fields=%d (expected 1)" % [units, fields])


## AC-2: both SubViewports render the window's own World3D (one object, neither sets a world of its
## own). The detail prints the verdicts, not object ids, which change whenever the scene gains a node.
func _check_shared_world() -> void:
	var root_world: World3D = _harness.get_viewport().find_world_3d()
	var view_1: SubViewport = _view_of(_split.player_1_camera)
	var view_2: SubViewport = _view_of(_split.player_2_camera)
	if view_1 == null or view_2 == null:
		_harness.check("shared_world", false, "a camera is not inside a SubViewport")
		return
	var world_1: World3D = view_1.find_world_3d()
	var world_2: World3D = view_2.find_world_3d()
	var worlds_shared: bool = root_world != null and world_1 == root_world and world_2 == root_world
	var own_world_off: bool = not view_1.own_world_3d and not view_2.own_world_3d
	var world_3d_unset: bool = view_1.world_3d == null and view_2.world_3d == null
	_harness.check("shared_world", worlds_shared and own_world_off and world_3d_unset,
		"same_world=%s own_world_3d=%s/%s world_3d_set=%s/%s" % [
			worlds_shared, view_1.own_world_3d, view_2.own_world_3d, view_1.world_3d != null, view_2.world_3d != null])


## AC-2: both Units live in one physics space, the window's own. The detail prints the verdicts, not RIDs,
## which change whenever the scene gains a node.
func _check_shared_physics_space() -> void:
	var root_space: RID = _harness.get_viewport().find_world_3d().space
	var space_1: RID = _split.player_1_unit.get_world_3d().space
	var space_2: RID = _split.player_2_unit.get_world_3d().space
	var same_space: bool = space_1 == space_2 and space_1 == root_space
	_harness.check("shared_physics_space", space_1.is_valid() and same_space,
		"same_space=%s space_valid=%s" % [same_space, space_1.is_valid()])


## Story 001 AC-5 in the launch scene: both Units are drawn from their interpolated transforms, so
## they, and the ChaseCameras that follow where they are drawn, move smoothly on a display that does
## not run at the physics tick rate. A node is interpolated as the first explicit mode above it says
## (INHERIT asks the parent, and the top of the tree is ON), and a Control is OFF by default, so a
## Node3D below the Control root needs an ON of its own. The check reads those modes rather than the
## rendered motion, which a fixed-rate or headless run cannot show, and rather than
## is_physics_interpolated_and_enabled(), which reads true below a Control that turns it off
## (measured on 4.7.2; the Story 002 evidence doc keeps the run). The project setting must be on as well.
func _check_world_interpolation() -> void:
	var enabled: bool = bool(ProjectSettings.get_setting(PHYSICS_INTERPOLATION_SETTING, false))
	var passed: bool = enabled
	var detail: PackedStringArray = ["project_setting=%s" % enabled]
	var units: Array[Unit] = [_split.player_1_unit, _split.player_2_unit]
	for index: int in units.size():
		var decider: Node = _interpolation_decider(units[index])
		var mode: int = Node.PHYSICS_INTERPOLATION_MODE_ON
		var source: String = "the tree's default"
		if decider != null:
			mode = decider.physics_interpolation_mode
			source = "%s (%s)" % [decider.name, decider.get_class()]
		passed = passed and mode == Node.PHYSICS_INTERPOLATION_MODE_ON
		detail.append("player_%d unit mode=%s set by %s" % [index + 1, _mode_text(mode), source])
	_harness.check("world_interpolation", passed, " | ".join(detail) + " (every mode must be ON)")


## The node whose own mode decides how a node is interpolated: the node itself, or its nearest
## ancestor that does not say INHERIT. Null when every node up to the root says INHERIT.
func _interpolation_decider(node: Node) -> Node:
	var current: Node = node
	var inherit: int = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	while current != null and current.physics_interpolation_mode == inherit:
		current = current.get_parent()
	return current


## The name of a physics interpolation mode, for check details.
func _mode_text(mode: int) -> String:
	match mode:
		Node.PHYSICS_INTERPOLATION_MODE_ON:
			return "ON"
		Node.PHYSICS_INTERPOLATION_MODE_OFF:
			return "OFF"
	return "INHERIT"


## AC-2: each Unit stands on its own marker, facing the marker's way, and the two are apart.
func _check_start_positions() -> void:
	var markers: Array[Marker3D] = [_split.field.player_start, _split.field.player_2_start]
	var units: Array[Unit] = [_split.player_1_unit, _split.player_2_unit]
	var passed: bool = true
	var detail: PackedStringArray = []
	for index: int in units.size():
		var at: Vector3 = units[index].global_position
		var error: float = at.distance_to(markers[index].global_position)
		var facing_dot: float = (-units[index].global_transform.basis.z).dot(-markers[index].global_transform.basis.z)
		passed = passed and error <= START_TOLERANCE and facing_dot >= START_FACING_DOT
		detail.append("player_%d at (%.2f,%.2f,%.2f) marker_error=%.4f facing_dot=%.4f" % [
			index + 1, at.x, at.y, at.z, error, facing_dot])
	var apart: float = units[Harness.PLAYER_1].global_position.distance_to(units[Harness.PLAYER_2].global_position)
	passed = passed and apart > MIN_APART
	_harness.check("start_positions", passed,
		"%s | apart=%.2f m (must be more than %.0f)" % [" | ".join(detail), apart, MIN_APART])


## AC-5 and AC-6: the eight actions exist in the Input Map, each with exactly one key event on the
## expected physical key, and every event is bound to any device (ANY_DEVICE, -1). Prints each key
## with OS.get_keycode_string and each event's device.
func _check_input_map() -> void:
	for player: int in [Harness.PLAYER_1, Harness.PLAYER_2]:
		var keys: Array[Key] = Harness.PLAYER_1_KEYS if player == Harness.PLAYER_1 else Harness.PLAYER_2_KEYS
		var passed: bool = true
		var detail: PackedStringArray = []
		for slot: int in ACTION_SUFFIXES.size():
			var action: StringName = StringName(ACTION_PREFIXES[player] + ACTION_SUFFIXES[slot])
			var events: Array[InputEvent] = []
			if InputMap.has_action(action):
				events = InputMap.action_get_events(action)
			var key_event: InputEventKey = null
			if events.size() == 1:
				key_event = events[0] as InputEventKey
			if key_event == null:
				passed = false
				detail.append("%s=missing_or_not_one_key_event(%d events)" % [action, events.size()])
				continue
			var matches: bool = key_event.physical_keycode == keys[slot] and key_event.device == ANY_DEVICE
			passed = passed and matches
			detail.append("%s=%s(device=%d)%s" % [
				action, OS.get_keycode_string(key_event.physical_keycode), key_event.device,
				"" if matches else "!expected_%s_on_device_%d" % [OS.get_keycode_string(keys[slot]), ANY_DEVICE]])
		_harness.check("input_map_player_%d" % (player + 1), passed, " ".join(detail))
