extends RefCounted
## One stretch of a scripted scenario: hold these keys for this long. The step gives the whole key
## state: the Player it names holds the throttle and steer keys, everyone else has every key up.
##
## Shared by the runner (split_screen_harness.gd: apply and run_step) and by the scenarios that
## drive. Loaded with a preload constant: nothing under tools/ declares a class_name, so the class
## cache stays clean. Tooling only: nothing under src/ depends on this file.

## Name printed in the SPLIT lines and used in check names.
var label: StringName
## Length in seconds.
var seconds: float
## PLAYER_1 or PLAYER_2 of the runner, or its BOTH (-1): whose keys are held.
var player: int
## Throttle key held: 1 is W or Up, -1 is S or Down, 0 is neither.
var throttle: int
## Steer key held: 1 is A or Left, -1 is D or Right, 0 is neither.
var steer: int


func _init(step_label: StringName, step_seconds: float, step_player: int, step_throttle: int, step_steer: int) -> void:
	label = step_label
	seconds = step_seconds
	player = step_player
	throttle = step_throttle
	steer = step_steer
