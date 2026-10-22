extends RefCounted
## Scenario pad_back of the split screen evidence harness (split_screen_harness.gd): a pad's B on the Round-over screen goes
## back to the map choice (Story 038's way back; Story 047: Martin, 2026-10-22, "b na zvolenie dalsej mapy nefunguje").
## Player 1 delivers Player 2's Flag on Map 01, the Round is over, then pad 0 (connected through PadAssignment) presses B.
## CHECK lines: B1 the Round is over and the launch scene's MapChoiceReturn is in the tree; B2 B on the pad leaves for the map
## choice (the map choice scene is the current scene a few frames on).
## Implements: production/epics/wasteland-fire/story-047-shadows-and-pad-back.md AC-2.
## Tooling only: nothing under src/ depends on this file.
## Run: godot --headless --fixed-fps 60 --path . res://tools/evidence/split_screen_harness.tscn -- --scenario=pad_back

const M2: GDScript = preload("res://tools/evidence/split_screen/map_02_kit.gd")

const FLAG_OPEN: bool = true
const MAP_CHOICE: bool = true
const STICK_DRIVE: bool = true
const FIRE_HEIGHTS: bool = true
const SECONDARY: bool = true
const PAD_1: int = 0
const SETTLE_TICKS: int = 10

var _m: M2


func run(harness: Node) -> void:
	_m = M2.new(harness)
	var problems: PackedStringArray = PackedStringArray()
	var pads: PadAssignment = _m.split.get_node("PadAssignment") as PadAssignment
	pads.connect_pad(PAD_1)
	var flag: Flag = _m.field.player_2_base.flag
	await _m.put(0, M2.MOTORBIKE, flag.global_position, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	await _m.put(0, M2.MOTORBIKE, _m.field.player_1_base.zone.global_position, Vector3.FORWARD)
	await _m.kit.advance(SETTLE_TICKS)
	var over: bool = _m.controller.is_round_over()
	var back_node: bool = _m.split.get_node_or_null("MapChoiceReturn") != null
	_m.kit.need(problems, over and back_node, "Round over %s, MapChoiceReturn %s" % [over, back_node])
	_m.kit.verdict("B1_round_over", problems, "Round over %s; MapChoiceReturn in the tree %s" % [over, back_node])
	var problems_2: PackedStringArray = PackedStringArray()
	var tree: SceneTree = _m.h.get_tree()
	var before: String = String(tree.current_scene.name) if tree.current_scene != null else ""
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = PAD_1
		event.button_index = JOY_BUTTON_B
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		Input.parse_input_event(event)
		for _frame: int in 3:
			await tree.physics_frame
	for _frame: int in 10:
		await tree.process_frame
	var choice_up: bool = false
	for node: Node in tree.root.get_children():
		if node is MapChoice:
			choice_up = true
	var after: String = String(tree.current_scene.name) if tree.current_scene != null else ""
	_m.kit.need(problems_2, choice_up, "after B the scenes under the root are %s (current %s, before %s)" % [tree.root.get_children().map(func(n: Node) -> String: return String(n.name)), after, before])
	_m.kit.verdict("B2_pad_b_goes_back", problems_2, "after pad 0's B: the map choice is up %s (current scene '%s', before '%s')" % [choice_up, after, before])
	_m.h.finish("pads=1")
