class_name NitroBooster
extends Node
## The Buggy's nitro (Story 042; Martin, 2026-10-22: "skusme nitro"): the secondary key gives the
## Unit nitro_seconds of nitro_speed_share times its top speed and acceleration forward, then
## nitro_cooldown_seconds before it can be fired again. Only a type whose stats give nitro_seconds
## has it; for every other type the key does something else (the Truck's Mines, the Gyrocopter's
## smoke) or nothing, and this node does nothing.
##
## Implements: production/epics/wasteland-fire/story-042-secondary-weapons.md AC-2, AC-6.
## Vocabulary: CONTEXT.md (Secondary weapon, Unit).
##
## The secondary key is the action <prefix>lay_mine (E for Player 1, Comma for Player 2, a pad's
## LT), named so since story 014. Read on its press. Each new Unit starts with the nitro ready. The
## node ticks before the Unit (process_physics_priority one below it), so Unit.boost_speed() bites in
## the same tick.

## Emitted when the nitro starts, ends or is ready again: the HUD reads state() and seconds_left().
signal nitro_changed

enum State { NONE, READY, BOOSTING, COOLING }

const PRIORITY_OFFSET: int = -1
const _SUFFIX: String = "lay_mine"

## The Unit the nitro drives. Required.
@export var unit: Unit
## The Player's action prefix (p1_, p2_). Required.
@export var action_prefix: StringName = &""

var _action: StringName
var _state: State = State.NONE
var _ends_at: float = 0.0
var _clock: float = 0.0
var _in_play: bool = false
var _type: StringName = &""


func _ready() -> void:
	if unit == null or action_prefix.is_empty():
		push_error("NitroBooster '%s': unit and action_prefix must be set, so there is no nitro." % name)
		set_physics_process(false)
		return
	_action = StringName(String(action_prefix) + _SUFFIX)
	if not InputMap.has_action(_action):
		push_error("NitroBooster '%s': Input Map action '%s' does not exist." % [name, _action])
		set_physics_process(false)
		return
	process_physics_priority = unit.process_physics_priority + PRIORITY_OFFSET


## NONE (the Unit's type has no nitro or no Unit is in play), READY, BOOSTING or COOLING.
func state() -> State:
	return _state


## Seconds left of the nitro (BOOSTING) or of the cooldown (COOLING); 0 otherwise.
func seconds_left() -> float:
	return maxf(_ends_at - _clock, 0.0) if _state == State.BOOSTING or _state == State.COOLING else 0.0


## How charged the nitro is (Story 044's bar): it drains from 1 to 0 while BOOSTING, fills from 0 to
## 1 while COOLING, is 1 when READY and 0 for a type with none.
func charge() -> float:
	match _state:
		State.READY:
			return 1.0
		State.BOOSTING:
			return clampf(seconds_left() / maxf(unit.stats.nitro_seconds, 0.001), 0.0, 1.0)
		State.COOLING:
			return clampf(1.0 - seconds_left() / maxf(unit.stats.nitro_cooldown_seconds, 0.001), 0.0, 1.0)
	return 0.0


func _physics_process(delta: float) -> void:
	_clock += delta
	_follow_unit()
	if _state == State.NONE:
		return
	var stats: UnitStats = unit.stats
	if _state == State.READY and Input.is_action_just_pressed(_action):
		_state = State.BOOSTING
		_ends_at = _clock + stats.nitro_seconds
		nitro_changed.emit()
	if _state == State.BOOSTING:
		if _clock >= _ends_at:
			_state = State.COOLING
			_ends_at = _clock + stats.nitro_cooldown_seconds
			nitro_changed.emit()
		else:
			unit.boost_speed(stats.nitro_speed_share)
	elif _state == State.COOLING and _clock >= _ends_at:
		_state = State.READY
		nitro_changed.emit()


## A new Unit (a spawn, a respawn, a Swap) starts with the nitro ready if its type has one.
func _follow_unit() -> void:
	var in_play: bool = is_instance_valid(unit) and unit.is_alive
	var type: StringName = unit.stats.type_id if in_play and unit.stats != null else &""
	if in_play == _in_play and type == _type:
		return
	_in_play = in_play
	_type = type
	var has_nitro: bool = in_play and unit.stats.nitro_seconds > 0.0
	_state = State.READY if has_nitro else State.NONE
	nitro_changed.emit()
