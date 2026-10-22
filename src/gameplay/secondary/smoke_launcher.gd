class_name SmokeLauncher
extends Node
## The Gyrocopter's smoke screen (Story 042; Martin, 2026-10-22: "velka dymova clona - gyro bude v
## strede a nikto nebude vediet kam poleti"; story 044, the same day: "nech sa spravi pred gyro, nech
## trva 3 sek a tiez sa nabija ale 15s"): the secondary key drops a SmokeCloud SmokeSettings.ahead
## metres in front of the Unit, along its heading, so it flies into it; then the launcher recharges
## for the type's smoke_cooldown_seconds. A new Unit of a type with smoke starts ready. For every
## other type this node does nothing.
##
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-3,
## story-044-secondaries-recharge.md AC-2 and AC-5.
##
## The secondary key is the action <prefix>lay_mine (see NitroBooster), read on its press. The cloud
## is added under the Unit's parent, where the Shots and the Mines go.

## Emitted when a cloud is dropped and when the launcher is ready again.
signal smoke_changed

const _SUFFIX: String = "lay_mine"

## The Unit that drops the smoke. Required.
@export var unit: Unit
## The Player's action prefix (p1_, p2_). Required.
@export var action_prefix: StringName = &""
## smoke_cloud.tscn, whose root is a SmokeCloud. Required.
@export var cloud_scene: PackedScene
## The clouds' numbers, for how far ahead one is dropped. Required.
@export var settings: SmokeSettings

var _action: StringName
var _cooldown: float = 0.0
var _left: float = 0.0
var _in_play: bool = false
var _type: StringName = &""


func _ready() -> void:
	if unit == null or action_prefix.is_empty() or cloud_scene == null or settings == null:
		push_error("SmokeLauncher '%s': unit, action_prefix, cloud_scene and settings must be set, so there is no smoke." % name)
		set_physics_process(false)
		return
	_action = StringName(String(action_prefix) + _SUFFIX)
	if not InputMap.has_action(_action):
		push_error("SmokeLauncher '%s': Input Map action '%s' does not exist." % [name, _action])
		set_physics_process(false)


## True while the Unit in play has a smoke screen (its type's smoke_cooldown_seconds above zero).
func has_smoke() -> bool:
	return _cooldown > 0.0


## How charged the launcher is, 0 just after a drop to 1 when ready; 0 for a type with no smoke.
func charge() -> float:
	if not has_smoke():
		return 0.0
	return clampf(1.0 - _left / _cooldown, 0.0, 1.0)


## True when the next press drops a cloud.
func is_ready() -> bool:
	return has_smoke() and _left <= 0.0


func _physics_process(delta: float) -> void:
	_follow_unit()
	if not has_smoke():
		return
	if _left > 0.0:
		_left = maxf(_left - delta, 0.0)
		if _left <= 0.0:
			smoke_changed.emit()
		return
	if not Input.is_action_just_pressed(_action):
		return
	var cloud: SmokeCloud = cloud_scene.instantiate() as SmokeCloud
	if cloud == null:
		push_error("SmokeLauncher '%s': cloud_scene is not a SmokeCloud scene." % name)
		return
	unit.get_parent().add_child(cloud)
	var heading: Vector3 = -unit.global_transform.basis.z
	heading.y = 0.0
	cloud.drop(unit.global_position + heading.normalized() * settings.ahead)
	_left = _cooldown
	smoke_changed.emit()


func _follow_unit() -> void:
	var in_play: bool = is_instance_valid(unit) and unit.is_alive
	var type: StringName = unit.stats.type_id if in_play and unit.stats != null else &""
	if in_play == _in_play and type == _type:
		return
	_in_play = in_play
	_type = type
	_cooldown = maxf(unit.stats.smoke_cooldown_seconds, 0.0) if in_play else 0.0
	_left = 0.0
	smoke_changed.emit()
