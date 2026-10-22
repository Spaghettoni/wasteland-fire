class_name SmokeLauncher
extends Node
## The Gyrocopter's smoke screens (Story 042; Martin, 2026-10-22: "velka dymova clona - gyro bude v
## strede a nikto nebude vediet kam poleti"): the secondary key drops a SmokeCloud where the Unit
## is, while it has any left; each new Unit of a type with smoke_capacity comes with all of them.
## For every other type this node does nothing.
##
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-3, AC-6.
##
## The secondary key is the action <prefix>lay_mine (see NitroBooster), read on its press. The cloud
## is added under the Unit's parent, where the Shots and the Mines go.

## Emitted when the count of smoke screens left changes, with the count and the type's capacity.
signal smoke_changed(left: int, capacity: int)

const _SUFFIX: String = "lay_mine"

## The Unit that drops the smoke. Required.
@export var unit: Unit
## The Player's action prefix (p1_, p2_). Required.
@export var action_prefix: StringName = &""
## smoke_cloud.tscn, whose root is a SmokeCloud. Required.
@export var cloud_scene: PackedScene

var _action: StringName
var _left: int = 0
var _capacity: int = 0
var _in_play: bool = false
var _type: StringName = &""


func _ready() -> void:
	if unit == null or action_prefix.is_empty() or cloud_scene == null:
		push_error("SmokeLauncher '%s': unit, action_prefix and cloud_scene must be set, so there is no smoke." % name)
		set_physics_process(false)
		return
	_action = StringName(String(action_prefix) + _SUFFIX)
	if not InputMap.has_action(_action):
		push_error("SmokeLauncher '%s': Input Map action '%s' does not exist." % [name, _action])
		set_physics_process(false)


## Smoke screens left, and the type's capacity (0 for a type with none).
func smoke_left() -> int:
	return _left


func capacity() -> int:
	return _capacity


func _physics_process(_delta: float) -> void:
	_follow_unit()
	if _capacity <= 0 or _left <= 0 or not Input.is_action_just_pressed(_action):
		return
	var cloud: SmokeCloud = cloud_scene.instantiate() as SmokeCloud
	if cloud == null:
		push_error("SmokeLauncher '%s': cloud_scene is not a SmokeCloud scene." % name)
		return
	unit.get_parent().add_child(cloud)
	cloud.drop(unit.global_position)
	_left -= 1
	smoke_changed.emit(_left, _capacity)


func _follow_unit() -> void:
	var in_play: bool = is_instance_valid(unit) and unit.is_alive
	var type: StringName = unit.stats.type_id if in_play and unit.stats != null else &""
	if in_play == _in_play and type == _type:
		return
	_in_play = in_play
	_type = type
	_capacity = maxi(unit.stats.smoke_capacity, 0) if in_play else 0
	_left = _capacity
	smoke_changed.emit(_left, _capacity)
