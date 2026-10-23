class_name MapChoiceReturn
extends Node
## Back to the map choice from a Round that is over (Story 038, Martin 2026-10-21: a key on the
## Round-over screen that goes back to the map choice).
##
## Implements: production/epics/wasteland-fire/story-038-map-02-and-map-choice.md AC-10.
## Vocabulary: CONTEXT.md (Map choice, Round).
##
## It reads the shared action round_back (project.godot: Esc on the keyboard, B on every pad) only
## while the Round is over, as RoundRestartInput reads the restart, so in play the key does
## nothing. Then it unpauses the tree (the Round-over screen pauses it), instances the map choice
## from map_choice_path, adds it to the root as the current scene and frees the launch scene this
## node belongs to (the PadAssignment gives the pads' events back as it leaves the tree). The map
## choice's scene is named by path, not as a PackedScene: the map choice holds this launch scene,
## and a scene that held the map choice back would be a cycle. It runs while the tree is paused
## (process_mode ALWAYS in split_screen.tscn).

## The shared action that goes back to the map choice.
const ACTION_BACK: StringName = &"round_back"

## The MatchController whose Round must be over before the key does anything.
@export var match_controller: MatchController

## The map choice scene, by path: res://src/ui/map_choice/map_choice.tscn.
@export_file("*.tscn") var map_choice_path: String = ""

## The scene to free when going back: the launch scene this node sits in. Required.
@export var launch_root: Node

var _leaving: bool = false


func _ready() -> void:
	if match_controller == null or launch_root == null or map_choice_path.is_empty():
		push_error("MapChoiceReturn '%s': match_controller, launch_root and map_choice_path must be set, so the key goes nowhere." % name)
		set_physics_process(false)
		return
	if not InputMap.has_action(ACTION_BACK):
		push_error("MapChoiceReturn '%s': Input Map action '%s' does not exist, so the key goes nowhere." % [name, ACTION_BACK])
		set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if _leaving or not is_instance_valid(match_controller):
		return
	if match_controller.is_round_over() and Input.is_action_just_pressed(ACTION_BACK):
		go_back()


## Leaves the match for the map choice: unpause, add the map choice as the current scene, free the
## launch scene. Does nothing a second time.
func go_back() -> void:
	if _leaving:
		return
	var scene: PackedScene = load(map_choice_path) as PackedScene
	if scene == null:
		push_error("MapChoiceReturn '%s': %s did not load as a scene, so the match goes on." % [name, map_choice_path])
		return
	_leaving = true
	var tree: SceneTree = get_tree()
	tree.paused = false
	var choice: Node = scene.instantiate()
	var split: SplitScreen = launch_root as SplitScreen
	if choice is MapChoice and split != null:
		(choice as MapChoice).lineup = split.lineup
	tree.root.add_child(choice)
	tree.current_scene = choice
	launch_root.queue_free()
