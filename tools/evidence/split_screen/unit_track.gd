extends RefCounted
## Follows one Unit through a phase: where it started, how far it is from there, how far it has
## turned and the top speed it reached. Yaw is summed tick by tick, so a turn of more than half a
## circle does not wrap.
##
## Shared by the runner (split_screen_harness.gd), which keeps one track per Player and updates both
## after every physics tick, and by the scenarios that read them. Loaded with a preload constant:
## nothing under tools/ declares a class_name. Tooling only: nothing under src/ depends on this file.

## The Unit followed.
var unit: Unit
## Where the phase began.
var start: Vector3 = Vector3.ZERO
## Turn since the phase began, radians, positive is left.
var yaw_total: float = 0.0
## Highest drive speed since the phase began, m/s.
var speed_max: float = 0.0
var _last_yaw: float = 0.0


func _init(tracked: Unit) -> void:
	unit = tracked
	begin()


## Starts a new phase from the Unit's present place and heading.
func begin() -> void:
	start = unit.global_position
	yaw_total = 0.0
	speed_max = 0.0
	_last_yaw = heading()


## Adds the tick that just finished.
func update() -> void:
	var yaw: float = heading()
	yaw_total += angle_difference(_last_yaw, yaw)
	_last_yaw = yaw
	speed_max = maxf(speed_max, unit.current_speed)


## Straight-line distance from where the phase began, metres.
func moved() -> float:
	return start.distance_to(unit.global_position)


## Heading in radians: 0 faces -Z, positive turns left. The Unit's basis z axis is (sin, 0, cos)
## of its yaw.
func heading() -> float:
	var back: Vector3 = unit.global_transform.basis.z
	return atan2(back.x, back.z)
